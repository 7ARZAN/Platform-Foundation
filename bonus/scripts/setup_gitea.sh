#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests/gitea"

GT_USER="gitadmin"
GT_PASS="Gitea_Passw0rd1337"
NS="gitea"

log()  { echo -e "\033[0;32m[OK]\033[0m $1"; }
err()  { echo -e "\n\033[0;31m[ERROR]\033[0m $1"; exit 1; }

kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic gitea-pass -n "$NS" \
  --from-literal=password="$GT_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Applying Gitea manifests..."
kubectl apply -f "$MANIFESTS_DIR/pvc.yml"
kubectl apply -f "$MANIFESTS_DIR/deployment.yml"
kubectl apply -f "$MANIFESTS_DIR/service.yml"

log "Waiting for Pod to be Ready..."
kubectl wait --for=condition=Ready pod -l app=gitea -n "$NS" --timeout=300s

pkill -f "port-forward.*3000" 2>/dev/null || true
(while true; do
  kubectl port-forward svc/gitea 3000:3000 -n "$NS" --address 0.0.0.0 2>/dev/null
  sleep 1
done) &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

log "Waiting for Gitea API to be ready..."
MAX=60; COUNT=0
while true; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3000/api/v1/version" || echo "000")
  [ "$CODE" = "200" ] && break
  [ "$COUNT" -ge "$MAX" ] && err "Timeout waiting for Gitea API."
  echo -ne "\033[0;33m[WAIT]\033[0m HTTP $CODE | Elapsed: $((COUNT * 5))s\r"
  COUNT=$((COUNT + 1)); sleep 5
done
echo ""

AUTH_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
  "http://localhost:3000/api/v1/user" \
  -u "${GT_USER}:${GT_PASS}" || echo "000")

if [ "$AUTH_CODE" = "200" ]; then
  log "Admin user '$GT_USER' already exists (bootstrapped by GITEA_ADMIN_*)."
else
  log "Bootstrapping admin user via CLI (GITEA_ADMIN_* did not fire)..."
  GITEA_POD=$(kubectl get pod -n "$NS" -l app=gitea -o jsonpath='{.items[0].metadata.name}')
  set +e
  RESULT=$(kubectl exec -i -n "$NS" "$GITEA_POD" -- \
    su git -s /bin/sh 2>&1 << ADMINCMD
gitea admin user create \
  --admin \
  --username "${GT_USER}" \
  --password "${GT_PASS}" \
  --email "admin@gitea.local" \
  --must-change-password=false
ADMINCMD
  )
  set -e
  echo "$RESULT"
  if echo "$RESULT" | grep -qiE 'created|already exists'; then
    log "Admin user '$GT_USER' is ready."
  else
    err "CLI admin setup failed. Output: $RESULT"
  fi
fi

log "Gitea is up."
