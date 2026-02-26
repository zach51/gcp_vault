#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACT_DIR="${TF_DIR}/artifacts"
KEEP_PORT_FORWARD=false

usage() {
  cat <<'EOF'
Usage: run_vault_lab_bootstrap.sh [--keep-port-forward]

Options:
  --keep-port-forward   Leave kubectl port-forward running after bootstrap.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-port-forward)
      KEEP_PORT_FORWARD=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${SCRIPT_DIR}/vault_lab_bootstrap.sh" ]]; then
  echo "Missing ${SCRIPT_DIR}/vault_lab_bootstrap.sh" >&2
  exit 1
fi

for cmd in terraform gcloud kubectl curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found: ${cmd}" >&2
    exit 1
  fi
done

cd "${TF_DIR}"

PROJECT_ID="$(terraform output -raw project_id)"
CLUSTER_NAME="$(terraform output -raw gke_cluster_name)"
ZONE="$(terraform output -raw gke_zone)"
NAMESPACE="$(terraform output -raw vault_namespace)"
SERVICE_NAME="$(terraform output -raw vault_service_name)"

echo "Configuring kube context for ${CLUSTER_NAME} (${ZONE})..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" >/dev/null

mkdir -p "${ARTIFACT_DIR}"

echo "Starting local port-forward to Vault service ${SERVICE_NAME} in namespace ${NAMESPACE}..."
kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE_NAME}" 8200:8200 >/tmp/vault-port-forward.log 2>&1 &
PF_PID=$!

cleanup() {
  if ps -p "${PF_PID}" >/dev/null 2>&1; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
    wait "${PF_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 40); do
  if curl -sS "http://127.0.0.1:8200/v1/sys/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -sS "http://127.0.0.1:8200/v1/sys/health" >/dev/null 2>&1; then
  echo "Vault API is not reachable via port-forward. Check /tmp/vault-port-forward.log" >&2
  exit 1
fi

INIT_JSON_PATH="${ARTIFACT_DIR}/vault-init.json" \
APP_CREDS_PATH="${ARTIFACT_DIR}/vault-app1-creds.json" \
VAULT_ADDR="http://127.0.0.1:8200" \
"${SCRIPT_DIR}/vault_lab_bootstrap.sh"

echo "Bootstrap finished. Artifacts written to ${ARTIFACT_DIR}."
echo "Quick load for Vault CLI:"
echo "source ${ARTIFACT_DIR}/vault-dev.env"

if [[ "${KEEP_PORT_FORWARD}" == "true" ]]; then
  trap - EXIT
  echo "Port-forward is still running (pid ${PF_PID})."
  echo "Use VAULT_ADDR=http://127.0.0.1:8200 in another terminal."
  wait "${PF_PID}"
fi
