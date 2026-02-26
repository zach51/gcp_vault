# Vault Post-Apply Steps (GKE Quick Runbook)

Use this after `terraform apply` in `gcp_vault/`.

Note: this stack is configured by default to scale the node pool to `0` during off-hours and restore it in the morning. If you run this runbook during scheduled downtime, Vault will be unavailable until scale-up occurs.

## 1. Configure kubectl
```bash
$(terraform output -raw gke_get_credentials_command)
```

## 2. Verify Vault pod/service
```bash
kubectl -n $(terraform output -raw vault_namespace) get pods
kubectl -n $(terraform output -raw vault_namespace) get svc
```

## 3. Port-forward Vault locally
```bash
kubectl -n $(terraform output -raw vault_namespace) \
  port-forward svc/$(terraform output -raw vault_service_name) 8200:8200
```

In a second terminal:
```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault status
```

## 4. First-time setup only (new Vault data)
```bash
vault operator init
vault operator unseal
vault operator unseal
vault operator unseal
vault login
vault status
```

## 5. Quick functionality test
```bash
vault secrets enable -path=secret kv-v2
vault kv put secret/demo username="zach" password="test123"
vault kv get secret/demo
```

## 6. One-command bootstrap (recommended)
From your local machine:
```bash
./scripts/run_vault_lab_bootstrap.sh
```
Or keep port-forward running after bootstrap:
```bash
./scripts/run_vault_lab_bootstrap.sh --keep-port-forward
```

Bootstrap outputs are written locally in `gcp_vault/artifacts/`:
- `vault-init.json`
- `vault-app1-creds.json`
