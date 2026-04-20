#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../p3/scripts/lib.sh"

readonly NS="gitea"
readonly GT_USER="gitadmin"
readonly REPO="iot"
readonly LOCAL_URL="http://localhost:3000"
readonly SOURCE_DIR="${SCRIPT_DIR}/../../p3/manifests/dev"
readonly ARGOCD_MANIFEST="${SCRIPT_DIR}/../manifests/argocd/app.yml"

GT_PASS=$(kubectl get secret gitea-pass -n "${NS}" \
  -o jsonpath='{.data.password}' | base64 --decode) \
  || err "Secret 'gitea-pass' not found"
[[ -z "${GT_PASS}" ]] && err "Secret 'gitea-pass' is empty"

pf_start "${NS}" gitea 3000:3000
sleep 3
poll_api "${LOCAL_URL}/api/v1/version" 60 5

if curl -sf "${LOCAL_URL}/api/v1/repos/${GT_USER}/${REPO}" \
     -u "${GT_USER}:${GT_PASS}" -o /dev/null; then
  log "Repo '${REPO}' already exists"
else
  curl -sf -X POST "${LOCAL_URL}/api/v1/user/repos" \
    -u "${GT_USER}:${GT_PASS}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${REPO}\",\"private\":false,\"auto_init\":false}" -o /dev/null
  log "Repo '${REPO}' created"
fi

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

cp -r "${SOURCE_DIR}/." "${work_dir}/"
git -C "${work_dir}" init -q -b main
git -C "${work_dir}" config user.email "admin@gitea.local"
git -C "${work_dir}" config user.name "Admin"
git -C "${work_dir}" add .
git -C "${work_dir}" commit -m "GitOps bootstrap" -q
git -C "${work_dir}" push -f \
  "http://${GT_USER}:${GT_PASS}@localhost:3000/${GT_USER}/${REPO}.git" main -q
log "Manifests pushed to Gitea"

kubectl apply -f "${ARGOCD_MANIFEST}"
log "ArgoCD Application registered"

log "Waiting for wil42-playground to deploy..."
until kubectl get deployment wil42-playground -n dev &>/dev/null; do sleep 5; done
kubectl wait --for=condition=Available deployment/wil42-playground -n dev --timeout=120s

pf_start argocd argocd-server 8081:80
pf_start dev wil42-playground 8888:8888

print_credentials
wait  # keep port-forwards alive
