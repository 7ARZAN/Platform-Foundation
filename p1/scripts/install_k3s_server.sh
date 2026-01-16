#!/bin/bash

set -eo pipefail

readonly SERVER_IP="192.168.56.110"
readonly NODE=$(hostname | tr '[:upper:]' '[:lower:]')
readonly CONF="/vagrant/conf"

log(){ echo -e "\033[0;34m[K3s-Server]\033[0m $1"; }
ok(){ echo -e "\033[0;32m[OK]\033[0m $1"; }

log "Init K3s Server on $NODE ($SERVER_IP) ..."

sudo ufw disable 2>/dev/null || true
IFACE=$(ip -o -4 addr list | grep "$SERVER_IP" | awk '{print $2}' | head -n1)

if ! command -v k3s &>/dev/null; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
	--node-name=$NODE \
	--bind-address=$SERVER_IP \
	--advertise-address=$SERVER_IP \
	--node-ip=$SERVER_IP \
	--flannel-iface=$IFACE \
	--write-kubeconfig-mode=644 \
	--tls-san=$SERVER_IP \
	--disable=traefik,servicelb" sh -
fi

log "Waiting for node registration ..."
until sudo k3s kubectl get node "$NODE" &>/dev/null; do sleep 2; done

mkdir -p "$CONF"
sudo cp /etc/rancher/k3s/k3s.yaml "$CONF/kubeconfig.yml"
sudo sed -i "s/127.0.0.1/$SERVER_IP/" "$CONF/kubeconfig.yml"
sudo cp /var/lib/rancher/k3s/server/node-token "$CONF/node-token"
sudo chown -R vagrant:vagrant "$CONF"
sudo chmod 644 "$CONF/kubeconfig.yml" "$CONF/node-token"

log "Deploying Background node auto labeler ..."
cat << 'EOF' | sudo tee /usr/local/bin/k3s-labeler.sh > /dev/null
#!/bin/bash

while true; do
    NODES=$(sudo k3s kubectl get nodes --no-headers | grep 'sw' | awk '$3 == "<none>" {print $1}')
    for N in $NODES; do
	sudo k3s kubectl label node "$N" node-role.kubernetes.io/worker=worker --overwrite >/dev/null 2>&1
    done
    sleep 10
done
EOF

sudo chmod +x /usr/local/bin/k3s-labeler.sh

cat << 'EOF' | sudo tee /etc/systemd/system/k3s-labeler.service > /dev/null
[Unit]
Description=K3s Node Labeler
After=k3s.service

[Service]
ExecStart=/usr/local/bin/k3s-labeler.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now k3s-labeler.service

ok "K3s Server Ready."
sudo k3s kubectl get nodes -o wide
