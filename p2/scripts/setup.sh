#!/bin/bash
set -eo pipefail

readonly IP="192.168.56.110"
readonly NODE=$(hostname | tr '[:upper:]' '[:lower:]')
readonly APPS_DIR="/vagrant/apps"
readonly CONF="/vagrant/conf"

log(){ echo -e "\033[0;34m[K3S-P2]\033[0m $1"; }
ok(){ echo -e "\033[0;32m[OK]\033[0m $1"; }

sudo ufw disable 2>/dev/null || true
IFACE=$(ip -o -4 addr list | grep "$IP" | awk '{print $2}' | head -n1)

if ! command -v k3s &>/dev/null; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-name=$NODE \
	--bind-address=$IP \
	--advertise-address=$IP \
	--node-ip=$IP \
	--flannel-iface=$IFACE \
	--write-kubeconfig-mode=644" sh -
fi

log "Waiting for Cluster to Be Rdy ..."
until sudo kubectl get nodes | grep -q "$NODE"; do
    sleep 2;
done

mkdir -p "$CONF"
sudo cp /etc/rancher/k3s/k3s.yaml "$CONF/kubeconfig.yml"
sudo sed -i "s/127.0.0.1/$IP/" "$CONF/kubeconfig.yml"
sudo cp /var/lib/rancher/k3s/server/node-token "$CONF/node-token"
sudo chown -R vagrant:vagrant "$CONF"
sudo chmod 644 "$CONF/kubeconfig.yml" "$CONF/node-token"

log "Deploying Apps ..."
for app in "$APPS_DIR"/*.yml; do
    if [[ -f "$app" ]]; then
        log "Applying $app"
        sudo kubectl delete -f "$app" --ignore-not-found
        sudo kubectl apply -f "$app" || { echo "Failed on $app"; exit 1; }
    fi
done

ok "P2 Cluster and Apps Deployed Successfully!"
sudo kubectl get all
sudo kubectl get ingress
