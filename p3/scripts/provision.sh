#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure() {
  local cmd=$1; shift
  command -v "${cmd}" &>/dev/null && { log "${cmd} already installed"; return; }
  "$@" && log "${cmd} installed"
}

ensure docker  bash -c "curl -fsSL https://get.docker.com | sh -s -- --quiet && sudo usermod -aG docker ${USER}"
ensure k3d     bash -c "curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
ensure kubectl bash -c "
  VER=\$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -fsSLo /tmp/kubectl https://dl.k8s.io/release/\${VER}/bin/linux/amd64/kubectl
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl && rm /tmp/kubectl"
ensure argocd  bash -c "
  curl -fsSLo /tmp/argocd https://github.com/argoproj/argo-cd/releases/download/v3.2.3/argocd-linux-amd64
  sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd && rm /tmp/argocd"

log "Provision complete"

