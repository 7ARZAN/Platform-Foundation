#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; NC="\033[0m"
log(){  echo -e "${GREEN}✅ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $1${NC}"; }

ARGOCD_PORT=8081
ARGOCD_NEW_PASS="Passwd1337"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

if ! kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].args}' \
     | grep -q "\-\-insecure"; then
  kubectl -n argocd patch deployment argocd-server \
    --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'
  kubectl -n argocd rollout status deploy/argocd-server --timeout=120s
  log "ArgoCD configured for plain HTTP (--insecure)"
else
  warn "ArgoCD already in insecure mode — skipping patch"
fi

# Aggressively kill old port-forwards to avoid stale connections after pod recreations
pkill -f "kubectl.*port-forward.*${ARGOCD_PORT}" 2>/dev/null || true
sleep 2

# Forward to port 80 (HTTP)
kubectl -n argocd port-forward svc/argocd-server ${ARGOCD_PORT}:80 >/dev/null 2>&1 &
sleep 3

if ! lsof -iTCP:8888 -sTCP:LISTEN -t &>/dev/null; then
  kubectl port-forward -n dev svc/wil42-playground 8888:8888 >/dev/null 2>&1 &
  sleep 2
else
  warn "Port 8888 already in use — skipping port-forward"
fi

if argocd login localhost:${ARGOCD_PORT} \
     --username admin \
     --password "${ARGOCD_NEW_PASS}" \
     --plaintext 2>/dev/null; then
  log "Logged in with existing password"
else
  warn "Falling back to initial admin secret..."
  INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)
  argocd login localhost:${ARGOCD_PORT} \
    --username admin \
    --password "${INITIAL_PASS}" \
    --plaintext
  argocd account update-password \
    --current-password "${INITIAL_PASS}" \
    --new-password "${ARGOCD_NEW_PASS}"
  log "Password updated to Passwd1337"
fi

log "Argo-CD UI accessible at http://localhost:${ARGOCD_PORT}  (user: admin / Passwd1337)"
