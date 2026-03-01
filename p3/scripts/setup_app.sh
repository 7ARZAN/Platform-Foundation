#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; NC="\033[0m"
log(){  echo -e "${GREEN}✅ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $1${NC}"; }

REPO_URL="https://github.com/7ARZAN/Platform-Foundation.git"
APP_NAME="wil42-playground"
MANIFESTS="$(dirname "$0")/../manifests/argocd/app.yml"

if argocd repo list | grep -q "$REPO_URL"; then
  warn "Repo already registered — skipping repo add"
else
  argocd repo add "$REPO_URL"
  log "Repo registered: $REPO_URL"
fi

kubectl apply -f "$MANIFESTS"

argocd app wait "$APP_NAME" --timeout 30 2>/dev/null || true
argocd app sync "$APP_NAME" --force --prune

log "Application '${APP_NAME}' registered and synced"
