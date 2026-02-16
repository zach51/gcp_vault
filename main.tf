locals {
  vault_name = "${var.name_prefix}-vm"
  cloudsql_allowed_cidrs = distinct(concat(
    var.admin_cidrs,
    ["${google_compute_address.vault_public_ip.address}/32"]
  ))
}

resource "google_project_service" "sqladmin" {
  count              = var.enable_cloudsql_integration ? 1 : 0
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vault" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vault" {
  name                     = "${var.name_prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.vault.id
  ip_cidr_range            = var.network_cidr
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.vault.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = ["vault"]
}

resource "google_compute_firewall" "allow_vault_api" {
  name    = "${var.name_prefix}-allow-vault"
  network = google_compute_network.vault.name

  allow {
    protocol = "tcp"
    ports    = ["8200"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = ["vault"]
}

resource "google_service_account" "vault_vm" {
  account_id   = "${var.name_prefix}-sa"
  display_name = "Vault Lab VM Service Account"
}

resource "google_project_iam_member" "vault_vm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vault_vm.email}"
}

resource "google_compute_address" "vault_public_ip" {
  name   = "${var.name_prefix}-ip"
  region = var.region
}

resource "google_compute_resource_policy" "nightly_stop" {
  count  = var.enable_nightly_shutdown ? 1 : 0
  name   = "${var.name_prefix}-nightly-stop"
  region = var.region

  instance_schedule_policy {
    vm_stop_schedule {
      schedule = "0 2 * * *"
    }

    time_zone = var.nightly_shutdown_time_zone
  }
}

resource "google_compute_instance" "vault" {
  name         = local.vault_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["vault"]
  resource_policies = var.enable_nightly_shutdown ? [
    google_compute_resource_policy.nightly_stop[0].self_link
  ] : []

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vault.id
    access_config {
      nat_ip = google_compute_address.vault_public_ip.address
    }
  }

  service_account {
    email  = google_service_account.vault_vm.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    apt-get update -y
    apt-get install -y curl unzip jq postgresql-client

    # Suppress non-fatal DBUS warnings in headless SSH/systemd sessions.
    cat >/etc/profile.d/90-dbus-null.sh <<'PROFILE'
    export DBUS_SESSION_BUS_ADDRESS=/dev/null
    PROFILE
    chmod 0644 /etc/profile.d/90-dbus-null.sh
    grep -q '^DBUS_SESSION_BUS_ADDRESS=' /etc/environment || echo 'DBUS_SESSION_BUS_ADDRESS=/dev/null' >> /etc/environment

    # Default Vault CLI to local HTTP listener for this lab environment.
    cat >/etc/profile.d/91-vault-addr.sh <<'PROFILE'
    export VAULT_ADDR=http://127.0.0.1:8200
    PROFILE
    chmod 0644 /etc/profile.d/91-vault-addr.sh

    VAULT_ZIP="vault_${var.vault_version}_linux_amd64.zip"
    curl -fsSL "https://releases.hashicorp.com/vault/${var.vault_version}/$${VAULT_ZIP}" -o "/tmp/$${VAULT_ZIP}"
    unzip -o "/tmp/$${VAULT_ZIP}" -d /usr/local/bin/
    chmod 0755 /usr/local/bin/vault

    useradd --system --home /etc/vault.d --shell /bin/false vault || true
    mkdir -p /etc/vault.d /opt/vault/data /var/log/vault
    chown -R vault:vault /etc/vault.d /opt/vault /var/log/vault

    EXTERNAL_IP=$(curl -s -H Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

    cat >/etc/vault.d/vault.hcl <<CONFIG
    ui = true
    disable_mlock = true

    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = "true"
    }

    storage "file" {
      path = "/opt/vault/data"
    }

    api_addr = "http://$${EXTERNAL_IP}:8200"
    cluster_addr = "http://127.0.0.1:8201"
    CONFIG

    cat >/etc/systemd/system/vault.service <<'SERVICE'
    [Unit]
    Description=HashiCorp Vault
    Documentation=https://developer.hashicorp.com/vault/docs
    Requires=network-online.target
    After=network-online.target

    [Service]
    User=vault
    Group=vault
    Environment=DBUS_SESSION_BUS_ADDRESS=/dev/null
    ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    KillSignal=SIGINT
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable vault
    systemctl start vault
  EOT

  depends_on = [google_project_iam_member.vault_vm_logging]
}

resource "random_password" "cloudsql_admin" {
  count   = var.enable_cloudsql_integration ? 1 : 0
  length  = 24
  special = true
}

resource "google_sql_database_instance" "cloudsql" {
  count               = var.enable_cloudsql_integration ? 1 : 0
  name                = var.cloudsql_instance_name
  region              = var.region
  database_version    = var.cloudsql_postgres_version
  deletion_protection = false

  settings {
    tier = var.cloudsql_tier

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      dynamic "authorized_networks" {
        for_each = {
          for idx, cidr in local.cloudsql_allowed_cidrs : idx => cidr
        }
        content {
          name  = "allow-${authorized_networks.key}"
          value = authorized_networks.value
        }
      }
    }
  }

  depends_on = [google_project_service.sqladmin]
}


### Only created if "enable_cloudsql_integration" is true in terraform.tfvars ###
resource "google_sql_database" "app" {
  count    = var.enable_cloudsql_integration ? 1 : 0
  name     = var.cloudsql_database_name
  instance = google_sql_database_instance.cloudsql[0].name
}

resource "google_sql_user" "vault_admin" {
  count    = var.enable_cloudsql_integration ? 1 : 0
  name     = var.cloudsql_admin_username
  instance = google_sql_database_instance.cloudsql[0].name
  password = random_password.cloudsql_admin[0].result
}
