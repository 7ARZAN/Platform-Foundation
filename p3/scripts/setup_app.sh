#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

readonly REPO="https://github.com/7ARZAN/Platform-Foundation.git"
readonly APP="wil42-playground"
readonly MANIFEST="${SCRIPT_DIR}/../manifests/argocd/app.yml"

argocd repo list 2>/dev/null | grep -q "${REPO}" || { argocd repo add "${REPO}"; log "Repo registered"; }

kubectl apply -f "${MANIFEST}"
argocd app sync "${APP}" --force --prune
argocd app wait "${APP}" --health --timeout=120

log "App '${APP}' live"
