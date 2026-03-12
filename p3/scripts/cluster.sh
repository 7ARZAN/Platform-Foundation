#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

cd "$(dirname "$0")/../manifests/cluster"

if ! k3d cluster list | grep -q "iot"; then
    k3d cluster create --config k3d-config.yml
    log "Cluster 'iot' created!"
else
    log "Cluster 'iot' already present!"
fi

kubectl config use-context k3d-iot

kubectl apply -f ../argocd/namespace.yml
kubectl apply -f ../dev/namespace.yml

log "Cluster Ready!"
