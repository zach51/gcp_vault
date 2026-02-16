#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${SCRIPT_DIR}/vault_cloudsql_integration.sh" ]]; then
  echo "Missing ${SCRIPT_DIR}/vault_cloudsql_integration.sh" >&2
  exit 1
fi

cd "${TF_DIR}"

ENABLED="$(terraform output -raw cloudsql_instance_name 2>/dev/null || true)"
if [[ -z "${ENABLED}" ]]; then
  echo "Cloud SQL integration is not enabled in Terraform outputs."
  echo "Set enable_cloudsql_integration=true and apply first." >&2
  exit 1
fi

SSH_CMD="$(terraform output -raw vault_ssh_command)"
CLOUDSQL_HOST="$(terraform output -raw cloudsql_public_ip)"
CLOUDSQL_DB_NAME="$(terraform output -raw cloudsql_database_name)"
CLOUDSQL_ADMIN_USER="$(terraform output -raw cloudsql_admin_username)"
CLOUDSQL_ADMIN_PASSWORD="$(terraform output -raw cloudsql_admin_password)"

if [[ -z "${CLOUDSQL_HOST}" ]]; then
  echo "cloudsql_public_ip is empty. Wait for Cloud SQL provisioning, then retry." >&2
  exit 1
fi

CLOUDSQL_HOST_B64="$(printf '%s' "${CLOUDSQL_HOST}" | base64)"
CLOUDSQL_DB_NAME_B64="$(printf '%s' "${CLOUDSQL_DB_NAME}" | base64)"
CLOUDSQL_ADMIN_USER_B64="$(printf '%s' "${CLOUDSQL_ADMIN_USER}" | base64)"
CLOUDSQL_ADMIN_PASSWORD_B64="$(printf '%s' "${CLOUDSQL_ADMIN_PASSWORD}" | base64)"

echo "Configuring Vault database secrets engine for Cloud SQL via: ${SSH_CMD}"
{
  printf 'export CLOUDSQL_HOST_B64=%q\n' "${CLOUDSQL_HOST_B64}"
  printf 'export CLOUDSQL_DB_NAME_B64=%q\n' "${CLOUDSQL_DB_NAME_B64}"
  printf 'export CLOUDSQL_ADMIN_USER_B64=%q\n' "${CLOUDSQL_ADMIN_USER_B64}"
  printf 'export CLOUDSQL_ADMIN_PASSWORD_B64=%q\n' "${CLOUDSQL_ADMIN_PASSWORD_B64}"
  cat "${SCRIPT_DIR}/vault_cloudsql_integration.sh"
} | ${SSH_CMD} --command 'sudo bash -s'

echo "Done. Opening interactive SSH session..."
exec ${SSH_CMD}
