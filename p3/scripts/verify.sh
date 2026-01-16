#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

kubectl -n dev rollout status deploy/wil42-playground --timeout=120s
kubectl -n dev port-forward svc/wil42-playground 8888:8888 >/dev/null 2>&1 & sleep 2
RESPONSE=$(curl -s http://localhost:8888/ || true)
echo "$RESPONSE"

log "Verification complete"

