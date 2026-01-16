#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"
NC="\033[0m"

log(){ echo -e "${GREEN}✅ $1${NC}"; }

if ! command -v docker >/dev/null; then
    sudo apt update -y
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    log "docker installed!"
else
    log "docker already present!"
fi

if ! command -v k3d >/dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    log "k3d installed!"
else
    log "k3d already present!"
fi

if ! command -v kubectl >/dev/null; then
    KUBECTL_VERSION="$(curl -sL https://dl.k8s.io/release/stable.txt)"
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

    EXPECTED=$(cat kubectl.sha256)
    ACTUAL=$(sha256sum kubectl | awk '{print $1}')
    if [ "$EXPECTED" = "$ACTUAL" ]; then
	log "kubectl checksum OK"
    else
	echo "kubectl checksum mismatch"
	exit 1
    fi

    sudo install -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl kubectl.sha256
    log "kubectl ${KUBECTL_VERSION} installed!"
else
    log "kubectl already present!"
fi

if ! command -v argocd >/dev/null; then
    ARGO_VERSION="v3.2.3"
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGO_VERSION}/argocd-linux-amd64"
    
    sudo install -m 0755 argocd /usr/local/bin/argocd
    rm argocd
    log "Argo-CD ! command line Interface ${ARGO_VERSION} installed!"
else
    log "Argo-CD already present!"
fi

log "Provision Script Complete!"
