# Vault Post-Apply Steps (Quick Runbook)

Use this after `terraform apply` in `gcp_vault/`.

## 1. SSH to the VM
```bash
$(terraform output -raw vault_ssh_command)
```

## 2. Set Vault address and verify service
```bash
export VAULT_ADDR=http://127.0.0.1:8200
sudo systemctl status vault --no-pager
vault status
```

If Vault is not reachable:
```bash
sudo systemctl restart vault
sudo journalctl -u vault -n 100 --no-pager
```

## 3. First-time setup only (new Vault data)
Run once on a fresh environment:
```bash
vault operator init
```
- Save unseal keys and root token somewhere safe.

Then unseal with 3 different keys:
```bash
vault operator unseal
vault operator unseal
vault operator unseal
```

Login:
```bash
vault login
vault status
```

## 4. Quick functionality test
```bash
vault secrets enable -path=secret kv-v2
vault kv put secret/demo username="zach" password="test123"
vault kv get secret/demo
```

## 5. Open UI
From your local machine:
```text
http://<vault_public_ip>:8200
```

You can get the URL with:
```bash
terraform output -raw vault_url
```

## Optional: One-command bootstrap (recommended for repeat labs)
From your local machine:
```bash
./scripts/run_vault_lab_bootstrap.sh
```

This will SSH to the VM and automate:
- init (if needed)
- unseal (if needed)
- KV enable at `secret/`
- `app-secrets-rw` policy
- AppRole `app1`

Bootstrap outputs are written on the VM:
- `/root/vault-init.json`
- `/root/vault-app1-creds.json`

## Optional: Cloud SQL integration (Vault dynamic DB creds)
Prereq: `enable_cloudsql_integration = true` and `terraform apply` completed.

From your local machine:
```bash
./scripts/run_vault_cloudsql_integration.sh
```

This configures:
- `database/config/cloudsql-postgres`
- `database/roles/app-dynamic-role`

Generated sample credentials are saved on the VM at:
- `/root/vault-cloudsql-integration.json`

From the VM, you can mint fresh creds anytime:
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="$(jq -r '.root_token' /root/vault-init.json)"
vault read database/creds/app-dynamic-role
```
