locals {
  cluster_name         = "${var.name_prefix}-gke"
  node_pool_name       = "${var.name_prefix}-pool"
  vpc_name             = "${var.name_prefix}-vpc"
  subnet_name          = "${var.name_prefix}-subnet"
  pods_range_name      = "${var.name_prefix}-pods"
  services_range_name  = "${var.name_prefix}-services"
  node_service_account = "${var.name_prefix}-gke-nodes"
  vault_storage_config = var.vault_storage_class == "" ? { enabled = true, size = var.vault_storage_size } : { enabled = true, size = var.vault_storage_size, storageClass = var.vault_storage_class }
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vault" {
  name                    = local.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vault" {
  name                     = local.subnet_name
  region                   = var.region
  network                  = google_compute_network.vault.id
  ip_cidr_range            = var.network_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range_name
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range_name
    ip_cidr_range = var.services_secondary_cidr
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = local.node_service_account
  display_name = "Vault GKE Node Pool Service Account"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "vault" {
  name                     = local.cluster_name
  location                 = var.region
  network                  = google_compute_network.vault.id
  subnetwork               = google_compute_subnetwork.vault.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  release_channel {
    channel = var.gke_release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_range_name
    services_secondary_range_name = local.services_range_name
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

resource "google_container_node_pool" "vault" {
  name       = local.node_pool_name
  location   = var.region
  cluster    = google_container_cluster.vault.name
  node_count = var.gke_node_count

  autoscaling {
    min_node_count = var.gke_min_node_count
    max_node_count = var.gke_max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.gke_node_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      workload = "vault"
    }
  }

  depends_on = [
    google_project_iam_member.gke_nodes_logging,
    google_project_iam_member.gke_nodes_monitoring,
    google_project_iam_member.gke_nodes_artifact_registry,
  ]
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.kubernetes_namespace
  }

  depends_on = [google_container_node_pool.vault]
}

resource "helm_release" "vault" {
  name             = var.vault_release_name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_helm_chart_version
  namespace        = kubernetes_namespace.vault.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      injector = {
        enabled = false
      }
      global = {
        tlsDisable = true
      }
      server = {
        image = {
          tag = var.vault_version
        }
        logLevel = var.vault_log_level
        standalone = {
          enabled = true
          config  = <<-EOT
            ui = true
            disable_mlock = true

            listener "tcp" {
              address         = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_disable     = 1
            }

            storage "file" {
              path = "/vault/data"
            }
          EOT
        }
        dataStorage = local.vault_storage_config
        service = {
          enabled                  = true
          type                     = "LoadBalancer"
          port                     = 8200
          loadBalancerSourceRanges = var.admin_cidrs
          annotations              = var.vault_service_annotations
        }
      }
      ui = {
        enabled     = true
        serviceType = "ClusterIP"
      }
    })
  ]

  depends_on = [kubernetes_namespace.vault]
}

data "kubernetes_service" "vault" {
  metadata {
    name      = var.vault_release_name
    namespace = var.kubernetes_namespace
  }

  depends_on = [helm_release.vault]
}
