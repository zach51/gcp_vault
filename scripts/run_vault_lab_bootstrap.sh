#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${SCRIPT_DIR}/vault_lab_bootstrap.sh" ]]; then
  echo "Missing ${SCRIPT_DIR}/vault_lab_bootstrap.sh" >&2
  exit 1
fi

SSH_CMD="$(cd "${TF_DIR}" && terraform output -raw vault_ssh_command)"

echo "Running bootstrap on VM using: ${SSH_CMD}"
${SSH_CMD} --command 'sudo bash -s' < "${SCRIPT_DIR}/vault_lab_bootstrap.sh"

echo "Bootstrap finished. Opening interactive SSH session..."
exec ${SSH_CMD}
