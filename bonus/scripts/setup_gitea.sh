#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../p3/scripts/lib.sh"

readonly NS="gitea"
readonly GT_USER="gitadmin"
readonly GT_PASS="${GITEA_ADMIN_PASSWORD:-Gitea_Passw0rd1337}"
readonly MANIFESTS="${SCRIPT_DIR}/../manifests/gitea"

trap pf_cleanup EXIT

kubectl create ns "${NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic gitea-pass -n "${NS}" \
  --from-literal=password="${GT_PASS}" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${MANIFESTS}/pvc.yml" \
              -f "${MANIFESTS}/deployment.yml" \
              -f "${MANIFESTS}/service.yml"

log "Waiting for Gitea pod.."
kubectl wait --for=condition=Ready pod -l app=gitea -n "${NS}" --timeout=300s

pf_start "${NS}" gitea 3000:3000
sleep 3
poll_api "http://localhost:3000/api/v1/version" 60 5

if curl -sf "http://localhost:3000/api/v1/user" -u "${GT_USER}:${GT_PASS}" -o /dev/null; then
	log "Admin '${GT_USER}' confirmed"
else
	log "Bootstrapping admin via CLI.."
	pod=$(kubectl get pod -n "${NS}" -l app=gitea -o jsonpath='{.items[0].metadata.name}')
	result=$(kubectl exec -n "${NS}" "${pod}" -- su git -s /bin/sh -c "gitea admin user create --admin \
		--username '${GT_USER}' --password '${GT_PASS}' --email admin@gitea.local --must-change-password=false" 2>&1 || true)
	echo "Bootstrap output: ${result}"
	echo "${result}" | grep -qiE 'created|already exists' || err "Admin bootstrap failed"
	log "Admin '${GT_USER}' created"

fi

log "Gitea ready at http://localhost:3000"
