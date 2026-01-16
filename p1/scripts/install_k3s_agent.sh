#!/bin/bash
set -eo pipefail

readonly SERVER_IP="192.168.56.110"
readonly AGENT_IP="192.168.56.111"
readonly NODE=$(hostname | tr '[:upper:]' '[:lower:]')
readonly TOKEN_FILE="/vagrant/conf/node-token"

log(){ echo -e "\033[0;34m[K3s-Agent]\033[0m $1";}
ok(){ echo -e "\033[0;32m[OK]\033[0m $1";}

log "Init K3s Agent on $NODE ($AGENT_IP) ..."

sudo ufw disable 2>/dev/null || true
IFACE=$(ip -o -4 addr list | grep "$AGENT_IP" | awk '{print $2}' | head -n1)

log "Waiting for K3s Server at $SERVER_IP:6443 ..."
until nc -z "$SERVER_IP" 6443 2>/dev/null; do sleep 2; done

log "Retrieving registration token ..."
until [[ -s "$TOKEN_FILE" ]]; do sleep 2; done
TOKEN=$(sudo cat "$TOKEN_FILE" | tr -d '[:space:]')

if ! command -v k3s &>/dev/null; then
    log "Running K3s installer ..."
    curl -sfL https://get.k3s.io | K3S_URL="https://$SERVER_IP:6443" K3S_TOKEN="$TOKEN" \
	INSTALL_K3S_EXEC="agent \
	--node-name=$NODE \
	--node-ip=$AGENT_IP \
	--flannel-iface=$IFACE" sh -
fi

ok "K3s Agent is active. Baguette!"
