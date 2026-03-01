#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

GL_PASS="G!tL@b_P@ssw0rd1337"
API="http://localhost:8080/api/v4"
REPO="http://root:${GL_PASS}@localhost:8080/root/iot.git"

echo "Verifying GitLab API..."
for i in $(seq 1 120); do
  if curl -sf -u "root:${GL_PASS}" "$API/version" >/dev/null; then break; fi
  [ "$i" -eq 120 ] && echo "ERROR: API down." && exit 1
  sleep 5
done

curl -s -X POST "$API/projects" \
  -H "Content-Type: application/json" \
  -u "root:${GL_PASS}" \
  -d '{"name": "iot", "visibility": "public"}' >/dev/null || true

WORK_DIR=$(mktemp -d)
cp -r ../p3/manifests/dev/* "$WORK_DIR/"
cd "$WORK_DIR"

git init >/dev/null
git config user.email "admin@test.com"
git config user.name "Admin"
git add .
git commit -m "Init from p3" >/dev/null || true
git branch -M main

sleep 2
git remote add origin "$REPO"
git push -u origin main -f >/dev/null 2>&1 || true

rm -rf "$WORK_DIR"

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil42-playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitlab.gitlab.svc.cluster.local/root/iot.git
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

sleep 2
argocd app sync wil42-playground >/dev/null 2>&1 || true
log "Bonus application registered via local GitLab!"
