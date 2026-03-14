# GCP Auto-Unseal Practice Guide

Use this flow to verify and practice Vault auto-unseal in this lab setup.

1) Confirm Vault auto-unseal is configured
- In `terraform.tfvars`, keep:
  - `vault_auto_unseal_gcpkms_enabled = true`
  - `vault_gcpkms_keyring_location   = "us-central1"`
- Optional custom names:
  - `vault_gcpkms_key_ring_name`
  - `vault_gcpkms_crypto_key_name`

2) Deploy infrastructure
```bash
terraform init
terraform plan
terraform apply
```

3) Bootstrap Vault once
```bash
./scripts/run_vault_lab_bootstrap.sh
```

That does:
- init (if needed)
- unseal
- set up sample KV v2 policy
- create AppRole `app1` and write app credentials

Artifacts are written to `gcp_vault/artifacts/`:
- `vault-init.json`
- `vault-app1-creds.json`
- `vault-root-token.txt`
- `vault-dev.env`

4) Verify baseline state
```bash
source artifacts/vault-dev.env
vault status
```

Expected:
- `Initialized: true`
- `Sealed: false`

5) Force restart to test auto-unseal
- Restart the Vault pod:
```bash
kubectl -n vault get pods
kubectl -n vault delete pod <vault-pod-name>
kubectl -n vault get pods -w
```
- After pod becomes ready, re-check:
```bash
source artifacts/vault-dev.env
vault status
```

Expected after restart:
- `Sealed: false` (without running `vault operator unseal`)
- Vault returns and functions using the same root path/data

6) Optional validation by logs
```bash
kubectl -n vault logs -l app.kubernetes.io/name=vault --tail=200 | rg -i "gcpckms|unseal|autounseal"
```

Notes:
- Auto-unseal is for restart recovery and reduces manual unseal.
- Initial initialization is still required once per fresh Vault data store.
