# Vault on GKE (Terraform)

This stack deploys a single-node Vault lab on a GKE cluster using the official HashiCorp Helm chart.

For repeat setup after `terraform apply`, use `VAULT_POST_APPLY_STEPS.md`.

## What it creates
- Dedicated VPC + subnet (+ secondary ranges for pods/services)
- Regional GKE cluster + managed node pool
- Kubernetes namespace for Vault
- Vault Helm release (`standalone` mode with persistent storage)
- Public LoadBalancer service for Vault API/UI on `8200`, restricted by `admin_cidrs`

## Lab scope
This is intentionally a learning/testing setup:
- Single Vault server (`standalone`)
- `storage "file"` on a PVC
- TLS disabled (`http://...:8200`)

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

It will:
- open a local port-forward to Vault (`127.0.0.1:8200`)
- initialize/unseal Vault (if needed)
- configure KV + sample AppRole
- save artifacts to `gcp_vault/artifacts/`

## Access the UI
If LoadBalancer IP is ready:
```bash
terraform output -raw vault_url
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
