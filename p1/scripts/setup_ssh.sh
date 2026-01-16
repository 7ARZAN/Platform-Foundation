#!/bin/bash
set -eo pipefail

readonly SHARED_KEYS="/vagrant/conf/ssh_keys"
readonly USERS=("root" "vagrant")

log(){ echo -e "\033[0;34m[SSH]\033[0m $1"; }
ok(){ echo -e "\033[0;34m[OK]\033[0m $1"; }

log "Configuring SSH cluster trust on $(hostname) ..."

sudo mkdir -p "$SHARED_KEYS"
sudo chmod 777 "$SHARED_KEYS"

if [[ ! -f "/home/vagrant/.ssh/id_ed25519" ]]; then
    sudo -u vagrant ssh-keygen -t ed25519 -f "/home/vagrant/.ssh/id_ed25519" -N "" -q
fi

sudo cp "/home/vagrant/.ssh/id_ed25519.pub" "$SHARED_KEYS/$(hostname).pub"
sudo chmod 644 "$SHARED_KEYS/$(hostname).pub"

if [[ "$(hostname)" == *S ]]; then
    log "Waiting for worker public key to appear ..."
    timeout 60 bash -c "until ls $SHARED_KEYS/*SW.pub >/dev/null 2>&1; do sleep 2; done" || log "Wait timed out"
fi

for username in "${USERS[@]}"; do
    HOME_DIR=$(getent passwd "$username" | cut -d: -f6)
    SSH_DIR="$HOME_DIR/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    sudo mkdir -p "$SSH_DIR"
    sudo touch "$AUTH_KEYS"

    for key in "$SHARED_KEYS"/*.pub; do
	[[ -f "$key" ]] && (sudo grep -qxf "$key" "$AUTH_KEYS" || sudo cat "$key" >> "$AUTH_KEYS")
    done

    sudo chown -R "$username:$username" "$SSH_DIR"
    sudo chmod 700 "$SSH_DIR"
    sudo chmod 600 "$AUTH_KEYS"

    cat <<EOF | sudo tee "$SSH_DIR/config" > /dev/null
    Host 192.168.56.*
    StrictHostKeyChecking accept-new
    IdentitiesOnly yes
    IdentityFile $HOME_DIR/.ssh/id_ed25519
    LogLevel ERROR
EOF

    sudo chown "$username:$username" "$SSH_DIR/config"
    sudo chmod 600 "$SSH_DIR/config"
done

ok "“SSH access is set up both ways for root and vagrant.”"
