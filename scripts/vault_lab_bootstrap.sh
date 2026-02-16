#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-/dev/null}"
INIT_JSON_PATH="/root/vault-init.json"
APP_CREDS_PATH="/root/vault-app1-creds.json"

if ! command -v vault >/dev/null 2>&1; then
  echo "vault binary not found on this VM" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi

echo "Waiting for Vault API at ${VAULT_ADDR}..."
for _ in $(seq 1 60); do
  if curl -sS "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -sS "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; then
  echo "Vault API did not become reachable in time" >&2
  exit 1
fi

STATUS_JSON="$(vault status -format=json 2>/dev/null || true)"
if [[ -z "${STATUS_JSON}" ]]; then
  STATUS_JSON='{"initialized":false,"sealed":true}'
fi

INIT_STATUS="$(jq -r '.initialized // false' <<<"${STATUS_JSON}")"
if [[ "${INIT_STATUS}" != "true" ]]; then
  echo "Vault is uninitialized; running operator init..."
  vault operator init -key-shares=5 -key-threshold=3 -format=json > "${INIT_JSON_PATH}"
  chmod 600 "${INIT_JSON_PATH}"
  echo "Wrote init output to ${INIT_JSON_PATH}"
else
  if [[ ! -f "${INIT_JSON_PATH}" ]]; then
    echo "Vault already initialized, but ${INIT_JSON_PATH} not found." >&2
    echo "Provide unseal keys manually or restore init JSON first." >&2
    exit 1
  fi
fi

STATUS_JSON="$(vault status -format=json 2>/dev/null || true)"
SEALED_STATUS="$(jq -r '.sealed // true' <<<"${STATUS_JSON}")"
if [[ "${SEALED_STATUS}" == "true" ]]; then
  echo "Vault is sealed; unsealing with first 3 keys from ${INIT_JSON_PATH}..."
  for idx in 0 1 2; do
    key="$(jq -r ".unseal_keys_b64[${idx}]" "${INIT_JSON_PATH}")"
    vault operator unseal "${key}" >/dev/null
  done
fi

ROOT_TOKEN="$(jq -r '.root_token' "${INIT_JSON_PATH}")"
export VAULT_TOKEN="${ROOT_TOKEN}"

# Dev-only convenience: auto-export root token for all future shell sessions.
cat >/etc/profile.d/92-vault-dev-root-token.sh <<PROFILE
export VAULT_TOKEN="${ROOT_TOKEN}"
PROFILE
chmod 0644 /etc/profile.d/92-vault-dev-root-token.sh

if ! vault secrets list -format=json | jq -e 'has("secret/")' >/dev/null; then
  echo "Enabling KV v2 at secret/..."
  vault secrets enable -path=secret kv-v2 >/dev/null
fi

cat > /tmp/app-secrets-rw.hcl <<'POLICY'
path "secret/data/app/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "secret/metadata/app/*" {
  capabilities = ["read", "list", "delete"]
}
POLICY

vault policy write app-secrets-rw /tmp/app-secrets-rw.hcl >/dev/null

if ! vault auth list -format=json | jq -e 'has("approle/")' >/dev/null; then
  echo "Enabling AppRole auth..."
  vault auth enable approle >/dev/null
fi

vault write auth/approle/role/app1 \
  token_policies="app-secrets-rw" \
  token_ttl="1h" \
  token_max_ttl="4h" \
  secret_id_ttl="24h" \
  secret_id_num_uses=10 >/dev/null

ROLE_ID="$(vault read -field=role_id auth/approle/role/app1/role-id)"
SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/app1/secret-id)"
APP_TOKEN="$(vault write -field=token auth/approle/login role_id="${ROLE_ID}" secret_id="${SECRET_ID}")"

jq -n \
  --arg vault_addr "${VAULT_ADDR}" \
  --arg role_name "app1" \
  --arg role_id "${ROLE_ID}" \
  --arg secret_id "${SECRET_ID}" \
  --arg app_token "${APP_TOKEN}" \
  '{vault_addr: $vault_addr, role_name: $role_name, role_id: $role_id, secret_id: $secret_id, app_token: $app_token}' \
  > "${APP_CREDS_PATH}"
chmod 600 "${APP_CREDS_PATH}"

echo
echo "Bootstrap complete."
echo "- Vault init material: ${INIT_JSON_PATH}"
echo "- AppRole credentials: ${APP_CREDS_PATH}"
echo "- Auto token profile: /etc/profile.d/92-vault-dev-root-token.sh"
echo "- Root token (for lab): ${ROOT_TOKEN}"
echo
echo "Quick test (as AppRole token):"
echo "VAULT_TOKEN=\"${APP_TOKEN}\" vault kv put secret/app/config username='appuser' password='test123'"
echo "VAULT_TOKEN=\"${APP_TOKEN}\" vault kv get secret/app/config"
