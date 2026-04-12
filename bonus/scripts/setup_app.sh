#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

NS="gitea"
GT_USER="gitadmin"
REPO_NAME="iot"
SOURCE_DIR="$SCRIPT_DIR/../../p3/manifests/dev"
LOCAL_URL="http://localhost:3000"

log()  { echo -e "\033[0;32m[OK]\033[0m $1"; }
warn() { echo -ne "\033[0;33m[WAIT]\033[0m $1\r"; }
err()  { echo -e "\n\033[0;31m[ERROR]\033[0m $1"; exit 1; }

GT_PASS=$(kubectl get secret gitea-pass -n "$NS" \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo "")
[ -z "$GT_PASS" ] && err "Secret 'gitea-pass' not found in namespace '$NS'."

pkill -f "port-forward.*3000" || true
(while true; do
  kubectl port-forward svc/gitea 3000:3000 -n "$NS" --address 0.0.0.0
  sleep 1
done) >/dev/null 2>&1 &
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
sleep 3

log "Polling Gitea API (HTTP 200 required)..."
MAX_RETRIES=60; COUNT=0
while true; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    "$LOCAL_URL/api/v1/version" -u "$GT_USER:$GT_PASS" || echo "000")
  if [ "$CODE" = "200" ]; then
    echo ""
    log "Gitea API is Ready."
    break
  fi
  warn "HTTP $CODE | Elapsed: $((COUNT * 10))s"
  [ "$COUNT" -eq "$MAX_RETRIES" ] && err "Timeout waiting for Gitea."
  COUNT=$((COUNT + 1)); sleep 10
done

set -e

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  "$LOCAL_URL/api/v1/repos/$GT_USER/$REPO_NAME" \
  -u "$GT_USER:$GT_PASS")
if [ "$HTTP_STATUS" != "200" ]; then
  log "Creating repository '$REPO_NAME'..."
  curl -s -X POST "$LOCAL_URL/api/v1/user/repos" \
    -u "$GT_USER:$GT_PASS" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$REPO_NAME\",\"private\":false,\"auto_init\":false}" > /dev/null
else
  log "Repository '$REPO_NAME' already exists, skipping creation."
fi

log "Pushing manifests..."
WORK_DIR=$(mktemp -d)
cp -r "$SOURCE_DIR"/. "$WORK_DIR/"
cd "$WORK_DIR"
git init -q -b main
git config user.email "admin@gitea.local"
git config user.name "Admin"
git add .
git commit -m "GitOps Bootstrap" -q
git push -f "http://$GT_USER:$GT_PASS@localhost:3000/$GT_USER/$REPO_NAME.git" main:main -q

log "Registering Application in ArgoCD..."
kubectl apply -f "$MANIFESTS_DIR/argocd/app.yml"
log "Workflow complete."

log "Exposing ArgoCD on port 8081..."
pkill -f "port-forward.*8081" 2>/dev/null || true
sleep 2
(while true; do
  kubectl port-forward svc/argocd-server 8081:80 -n argocd --address 0.0.0.0 2>/dev/null
  sleep 5
done) &

log "Waiting for ArgoCD to sync and deploy wil42-playground..."
until kubectl get deployment wil42-playground -n dev 2>/dev/null; do
  sleep 5
done
kubectl wait --for=condition=Available deployment/wil42-playground -n dev --timeout=120s

log "Exposing wil42-playground on port 8888 (auto-restart on pod changes)..."
pkill -f "port-forward.*8888" 2>/dev/null || true
sleep 2
(while true; do
  kubectl wait --for=condition=Ready pod -l app=wil42-playground -n dev --timeout=60s 2>/dev/null || true
  kubectl port-forward svc/wil42-playground 8888:8888 -n dev --address 0.0.0.0 2>/dev/null
  sleep 2
done) &

log "wil42 accessible at http://$(hostname -I | awk '{print $1}'):8888"
wait
