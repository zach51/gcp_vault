#!/usr/bin/env bash
set -euo pipefail

echo "This repository has moved to a GKE-first Vault deployment."
echo "Cloud SQL helper automation from the old VM workflow is no longer wired to Terraform outputs."
echo "Use manual Vault database secrets configuration if you still need Cloud SQL integration."
exit 1
