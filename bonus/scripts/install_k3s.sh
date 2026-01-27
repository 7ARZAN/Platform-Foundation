#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}➡️  Checking K3s Installation...${NC}"

if [ -f /etc/systemd/system/k3s.service ]; then
    echo -e "${GREEN}✅ K3s is already installed.${NC}"
else
    echo -e "${BLUE}🚀 Installing K3s (No Docker Platform)...${NC}"
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --tls-san 192.168.56.120
fi

echo -e "${BLUE}⏳ Waiting for K3s Node to be Ready...${NC}"
sleep 10

COUNTER=0
MAX_RETRIES=60
set +e
while true; do
    if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        echo -e "${GREEN}✅ K3s Node is Ready!${NC}"
        break
    fi
    
    sleep 2
    ((COUNTER++))
    
    if [ $COUNTER -ge $MAX_RETRIES ]; then
        echo "❌ Timeout waiting for K3s node."
        exit 1
    fi
done
set -e

echo -e "${BLUE}➡️  Checking/Installing ArgoCD...${NC}"
if kubectl get namespace argocd >/dev/null 2>&1; then
     echo -e "${GREEN}✅ ArgoCD namespace exists.${NC}"
else
     kubectl create namespace argocd
     kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
     
     echo -e "${BLUE}⏳ Waiting for ArgoCD Server Deployment...${NC}"
     kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
     
     echo -e "${BLUE}🔧 Patching ArgoCD for Ingress (Insecure Mode)...${NC}"
     kubectl patch deployment argocd-server -n argocd --type strategic -p '{"spec": {"template": {"spec": {"containers": [{"name": "argocd-server", "command": ["/usr/local/bin/argocd-server", "--insecure"], "args": []}]}}}}'
     
     echo -e "${BLUE}⏳ Waiting for ArgoCD Restart...${NC}"
     kubectl rollout status deployment/argocd-server -n argocd
     
     echo -e "${GREEN}✅ ArgoCD Server is ready and patched.${NC}"
fi

echo -e "${GREEN}🎉 VM Provisioning Complete.${NC}"
