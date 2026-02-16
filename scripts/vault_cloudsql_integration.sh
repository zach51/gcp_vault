#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-/dev/null}"
INIT_JSON_PATH="/root/vault-init.json"
OUT_JSON_PATH="/root/vault-cloudsql-integration.json"

: "${CLOUDSQL_HOST_B64:?Missing CLOUDSQL_HOST_B64}"
: "${CLOUDSQL_DB_NAME_B64:?Missing CLOUDSQL_DB_NAME_B64}"
: "${CLOUDSQL_ADMIN_USER_B64:?Missing CLOUDSQL_ADMIN_USER_B64}"
: "${CLOUDSQL_ADMIN_PASSWORD_B64:?Missing CLOUDSQL_ADMIN_PASSWORD_B64}"

CLOUDSQL_HOST="$(printf '%s' "${CLOUDSQL_HOST_B64}" | base64 -d)"
CLOUDSQL_DB_NAME="$(printf '%s' "${CLOUDSQL_DB_NAME_B64}" | base64 -d)"
CLOUDSQL_ADMIN_USER="$(printf '%s' "${CLOUDSQL_ADMIN_USER_B64}" | base64 -d)"
CLOUDSQL_ADMIN_PASSWORD="$(printf '%s' "${CLOUDSQL_ADMIN_PASSWORD_B64}" | base64 -d)"

if [[ ! -f "${INIT_JSON_PATH}" ]]; then
  echo "Missing ${INIT_JSON_PATH}; run lab bootstrap first." >&2
  exit 1
fi

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI not found" >&2
  exit 1
fi

ROOT_TOKEN="$(jq -r '.root_token' "${INIT_JSON_PATH}")"
if [[ -z "${ROOT_TOKEN}" || "${ROOT_TOKEN}" == "null" ]]; then
  echo "Unable to read root token from ${INIT_JSON_PATH}" >&2
  exit 1
fi

export VAULT_TOKEN="${ROOT_TOKEN}"

SEALED="$(vault status -format=json | jq -r '.sealed')"
if [[ "${SEALED}" != "false" ]]; then
  echo "Vault is sealed. Unseal before configuring Cloud SQL integration." >&2
  exit 1
fi

if ! vault secrets list -format=json | jq -e 'has("database/")' >/dev/null; then
  echo "Enabling database secrets engine..."
  vault secrets enable database >/dev/null
fi

ROLE_NAME="app-dynamic-role"
DB_CONFIG_NAME="cloudsql-postgres"

vault write "database/config/${DB_CONFIG_NAME}" \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="${ROLE_NAME}" \
  connection_url="postgresql://{{username}}:{{password}}@${CLOUDSQL_HOST}:5432/postgres?sslmode=disable" \
  username="${CLOUDSQL_ADMIN_USER}" \
  password="${CLOUDSQL_ADMIN_PASSWORD}" >/dev/null

vault write "database/roles/${ROLE_NAME}" \
  db_name="${DB_CONFIG_NAME}" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE ${CLOUDSQL_DB_NAME} TO \"{{name}}\";" \
  revocation_statements="REVOKE CONNECT ON DATABASE ${CLOUDSQL_DB_NAME} FROM \"{{name}}\"; DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h" >/dev/null

CREDS_JSON="$(vault read -format=json "database/creds/${ROLE_NAME}")"
printf '%s\n' "${CREDS_JSON}" > "${OUT_JSON_PATH}"
chmod 600 "${OUT_JSON_PATH}"

echo "Cloud SQL integration configured."
echo "- Vault DB config: database/config/${DB_CONFIG_NAME}"
echo "- Vault DB role: database/roles/${ROLE_NAME}"
echo "- Sample dynamic creds saved to ${OUT_JSON_PATH}"
echo
jq -r '.data | "username=\(.username)\npassword=\(.password)\nlease_duration=\(.lease_duration)"' "${OUT_JSON_PATH}"
