#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MANIFESTS="${SCRIPT_DIR}/../manifests"

if k3d cluster list 2>/dev/null | grep -q "iot"; then
  log "Cluster 'iot' already present"
else
  k3d cluster create --config "${MANIFESTS}/cluster/k3d-config.yml"
  log "Cluster 'iot' created"
fi

kubectl config use-context k3d-iot
kubectl apply -f "${MANIFESTS}/argocd/namespace.yml"
kubectl apply -f "${MANIFESTS}/dev/namespace.yml"

log "Cluster ready"
