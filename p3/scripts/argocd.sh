#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly PORT=8081
readonly PASS="Passwd1337"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

kubectl -n argocd get deploy argocd-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}' \
  | grep -q "\-\-insecure" || {
    kubectl -n argocd patch deployment argocd-server --type=json \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'
    kubectl -n argocd rollout status deploy/argocd-server --timeout=120s
  }

pf_start argocd argocd-server "${PORT}:80"
sleep 2
poll_api "http://localhost:${PORT}/healthz" 60 5

if ! argocd login "localhost:${PORT}" --username admin --password "${PASS}" --plaintext &>/dev/null; then
  INITIAL=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)
  argocd login "localhost:${PORT}" --username admin --password "${INITIAL}" --plaintext
  argocd account update-password --current-password "${INITIAL}" --new-password "${PASS}"
  log "Password updated"
fi

log "ArgoCD ready → http://localhost:${PORT}  (admin / ${PASS})"
