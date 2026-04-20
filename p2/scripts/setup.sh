#!/bin/bash
set -eo pipefail

readonly IP="192.168.56.110"
readonly NODE=$(hostname | tr '[:upper:]' '[:lower:]')
readonly CONF="/vagrant/conf"
readonly APPS="/vagrant/apps"

log(){ echo -e "\033[0;34m[P2]\033[0m $1"; }
ok(){  echo -e "\033[0;32m[OK]\033[0m $1"; }

sudo ufw disable 2>/dev/null || true
IFACE=$(ip -o -4 addr show | awk "/$IP/ {print \$2}")

if ! command -v k3s &>/dev/null; then
    export INSTALL_K3S_EXEC="server
        --node-name=$NODE
        --bind-address=$IP
        --advertise-address=$IP
        --node-ip=$IP
        --flannel-iface=$IFACE
        --write-kubeconfig-mode=644"
    curl -sfL https://get.k3s.io | sh -
fi

log "Waiting for node to be Ready.."
until sudo kubectl get node "$NODE" --no-headers 2>/dev/null | grep -q "Ready"; do
    sleep 2
done

mkdir -p "$CONF"
sudo cp /etc/rancher/k3s/k3s.yaml "$CONF/kubeconfig.yml"
sudo cp /var/lib/rancher/k3s/server/node-token "$CONF/node-token"
sudo sed -i "s/127.0.0.1/$IP/" "$CONF/kubeconfig.yml"
sudo chown -R vagrant:vagrant "$CONF"
sudo chmod 644 "$CONF/kubeconfig.yml" "$CONF/node-token"

log "Deploying apps.."
sudo kubectl apply -f "$APPS/"

log "Waiting for deployments to be available.."
sudo kubectl wait --for=condition=available deployment --all --timeout=240s

ok "Done!"
sudo kubectl get pods,ingress
