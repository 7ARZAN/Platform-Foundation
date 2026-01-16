#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

argocd repo add https://github.com/7ARZAN/Platform-Foundation.git || true
kubectl apply -f "$(dirname "$0")/../manifests/argocd/app.yml"
argocd app sync wil42-playground

log "Application registered and synced"
