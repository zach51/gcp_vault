# Vault on GKE (Terraform)

This stack deploys a single-node Vault lab on a GKE cluster using the official HashiCorp Helm chart.

For repeat setup after `terraform apply`, use `VAULT_POST_APPLY_STEPS.md`.

## What it creates
- Dedicated VPC + subnet (+ secondary ranges for pods/services)
- Zonal GKE cluster + managed node pool (cost-optimized default)
- Kubernetes namespace for Vault
- Vault Helm release (`standalone` mode with persistent storage)
- Public LoadBalancer service for Vault API/UI on `8200`, restricted by `admin_cidrs`

## Lab scope
This is intentionally a learning/testing setup:
- Single Vault server (`standalone`)
- `storage "file"` on a PVC
- TLS disabled (`http://...:8200`)
- Automatic daily off-hours scale-to-zero for cost savings (default `2:00 AM` down, `7:00 AM` up in `America/Chicago`)

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

## Connect kubectl to the cluster
```bash
$(terraform output -raw gke_get_credentials_command)
```

## Initialize and unseal Vault
Run the helper script from `gcp_vault/`:
```bash
./scripts/run_vault_lab_bootstrap.sh
```
Keep the local tunnel open after bootstrap:
```bash
./scripts/run_vault_lab_bootstrap.sh --keep-port-forward
```

It will:
- open a local port-forward to Vault (`127.0.0.1:8200`)
- initialize/unseal Vault (if needed)
- configure KV + sample AppRole
- save artifacts to `gcp_vault/artifacts/`

Quick CLI setup after bootstrap:
```bash
source artifacts/vault-dev.env
vault status
```

## Access the UI
If LoadBalancer IP is ready:
```bash
LB_IP="$($(terraform output -raw vault_lb_lookup_command))"
echo "http://${LB_IP}:8200"
```

You can also use local port-forward:
```bash
kubectl -n $(terraform output -raw vault_namespace) port-forward svc/$(terraform output -raw vault_service_name) 8200:8200
```
Then open `http://127.0.0.1:8200`.

## Destroy
```bash
terraform destroy
```

## Cost automation defaults
- `enable_scheduled_scale_down = true` by default.
- Terraform creates Cloud Scheduler jobs that scale the Vault node pool:
  - Down to `0` on `scheduled_scale_down_cron`
  - Up to `scheduled_daytime_node_count` on `scheduled_scale_up_cron`
- While scaled down, Vault is unavailable until the scheduled scale-up runs.

### Lowest-cost test profile (already in this repo)

- Keep a single node (`gke_node_count = 1`) with `e2-small` machine type.
- Keep it preemptible (`gke_preemptible_nodes = true`) for significant compute savings.
- Keep small disks (`gke_node_disk_size_gb = 20`, `vault_storage_size = 5Gi`) unless your test data needs more.
- Leave `enable_scheduled_scale_down = true` to auto-scale to `0` in off-hours.

## Optional auto-unseal with GCP KMS

- Auto-unseal with GCP KMS is enabled by default.
- Override `vault_auto_unseal_gcpkms_enabled = false` if you want to disable it.
- In a fresh GCP project, the first `terraform apply` may fail while Cloud KMS is still being enabled. Re-run `terraform apply` and the key resources will be created once the API is active.
- Optionally override:
  - `vault_gcpkms_key_ring_name` (defaults to `"{name_prefix}-vault-gcpkms-keyring"` when unset)
  - `vault_gcpkms_crypto_key_name` (defaults to `"{name_prefix}-vault-gcpkms-key"` when unset)
  - `vault_gcpkms_keyring_location` (default: `us-central1`)

For a step-by-step practice flow, see [AUTO_UNSEAL_PRACTICE.md](AUTO_UNSEAL_PRACTICE.md).
- Terraform will create the KMS key ring and key, grant the GKE node service account decrypt/encrypt access, and inject Vault `gcpckms` seal configuration.
- You should no longer need to run manual unseal after normal restarts; initial bootstrap still requires initialization once.
