# Vault on GCE VM (Terraform)

This stack deploys a single-node Vault lab on a Google Compute Engine VM.

For repeat setup after `terraform apply`, use `VAULT_POST_APPLY_STEPS.md`.

## What it creates
- Dedicated VPC + subnet
- Firewall rules for SSH (22) and Vault API/UI (8200) from `admin_cidrs`
- Static public IP
- Service account for the VM
- Debian VM with Vault installed and managed by `systemd`
- Optional Cloud SQL Postgres instance for Vault database secrets testing

## Lab scope
This is intentionally a learning/testing setup:
- Single node
- `storage "file"`
- TLS disabled (`http://...:8200`)
- Auto-stop at `2:00 AM` daily (default, configurable timezone)

Do not use this profile as production Vault.

## Deploy
1. Authenticate:
   ```bash
   gcloud auth application-default login
   gcloud config set project <YOUR_PROJECT_ID>
   ```
2. Configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `terraform.tfvars` and set `admin_cidrs`.
3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Nightly Auto-Shutdown
- Default behavior is to stop the VM every day at `2:00 AM`.
- Timezone is controlled by `nightly_shutdown_time_zone` (default `America/Chicago`).
- Set `enable_nightly_shutdown = false` if you want it to stay on.

## Initialize and unseal Vault
1. SSH to the VM:
   ```bash
   $(terraform output -raw vault_ssh_command)
   ```
2. On the VM:
   ```bash
   export VAULT_ADDR=http://127.0.0.1:8200
   vault operator init
   vault operator unseal
   vault login
   vault status
   ```

## Access the UI
```text
http://<vault_public_ip>:8200
```

## Destroy
```bash
terraform destroy
```

## One-command Vault Bootstrap
After `terraform apply`, from `gcp_vault/`:
```bash
./scripts/run_vault_lab_bootstrap.sh
```

This runs a bootstrap script on the VM that initializes/unseals Vault (as needed) and creates baseline app auth/policy.

Lab credential files are stored on the VM at:
- `/root/vault-init.json`
- `/root/vault-app1-creds.json`

## Optional: Cloud SQL Integration Test
1. Enable Cloud SQL in `terraform.tfvars` and apply:
   ```hcl
   enable_cloudsql_integration = true
   ```
   ```bash
   terraform apply
   ```
2. Bootstrap Vault base config (if not already done):
   ```bash
   ./scripts/run_vault_lab_bootstrap.sh
   ```
3. Configure Vault database secrets engine for Cloud SQL:
   ```bash
   ./scripts/run_vault_cloudsql_integration.sh
   ```

This creates a Vault database config (`cloudsql-postgres`) and role (`app-dynamic-role`) and fetches sample dynamic credentials.
