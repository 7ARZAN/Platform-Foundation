#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
kubectl -n argocd port-forward svc/argocd-server 8081:443 >/dev/null 2>&1 & sleep 2

kubectl port-forward -n dev svc/wil42-playground 8888:8888 >/dev/null 2>&1 & sleep 2

PASSWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
argocd login localhost:8081 --username admin --password "$PASSWD" --insecure
argocd account update-password --current-password "$PASSWD" --new-password Passwd1337

log "Argo-CD installed and accessible at https://localhost:8081"
