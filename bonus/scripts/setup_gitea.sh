#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../p3/scripts/lib.sh"

readonly NS="gitea"
readonly GT_PASS="${GITEA_ADMIN_PASSWORD:-Gitea_Passw0rd1337}"
readonly MANIFESTS="${SCRIPT_DIR}/../manifests/gitea"

trap pf_cleanup EXIT

kubectl create ns "${NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic gitea-pass -n "${NS}" \
  --from-literal=password="${GT_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${MANIFESTS}/pvc.yml" \
              -f "${MANIFESTS}/deployment.yml" \
              -f "${MANIFESTS}/service.yml"

log "Waiting for Gitea to be ready..."
kubectl wait --for=condition=Ready pod -l app=gitea -n "${NS}" --timeout=300s

pf_start "${NS}" gitea 3000:3000
sleep 3
poll_api "http://localhost:3000/api/v1/version" 60 5

if curl -sf "http://localhost:3000/api/v1/user" -u "gitadmin:${GT_PASS}" -o /dev/null; then
  log "Admin 'gitadmin' confirmed"
else
  pod=$(kubectl get pod -n "${NS}" -l app=gitea -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -n "${NS}" "${pod}" -- \
    gitea admin user create --admin \
      --username gitadmin --password "${GT_PASS}" \
      --email admin@gitea.local --must-change-password=false \
    || err "Admin bootstrap failed"
  log "Admin created via CLI"
fi

log "Gitea ready at http://localhost:3000"
