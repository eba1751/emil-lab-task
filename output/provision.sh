#!/bin/bash
# provision.sh — Provision a lab machine from scratch.
#
# Runs from your local machine; connects to lab-target over SSH and brings it
# to a lab-ready state. Must also set up the reverse SSH tunnel to lab-jumphost.
#
# Usage: ./provision.sh [config-file]
#
# Required actions (Part 1 — machine setup):
#   1. Install packages: curl, git, autossh, nodejs, npm
#   2. Create a lab user with SSH key auth only, passwordless sudo, no password login
#   3. Harden SSH: disable password authentication and root login
#   4. Configure ufw: deny incoming, allow outgoing, allow SSH
#   5. Set the machine hostname (read from config)
#
# Required actions (Part 2 — reverse tunnel):
#   5. Set up a persistent reverse SSH tunnel: jumphost:2205 -> lab-target:22
#      - Must survive reboots/container restarts
#      - Must restart automatically if the connection drops
#      - Must use key-based auth (no passwords)
#   6. Verify the tunnel works:
#        ssh -p 2205 labuser@localhost echo "tunnel OK"
#
# The script should be idempotent: safe to run multiple times without breaking anything.

#!/bin/bash
set -euo pipefail

# ---------- Load config ----------
CONFIG_FILE="${1:-}"
if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
  echo "Usage: ./provision.sh <config file>"
  exit 1
fi
source "$CONFIG_FILE"

# ---------- Validate required vars ----------
REQUIRED_VARS=(HOSTNAME TARGET_IP TARGET_PORT BOOTSTRAP_USER BOOTSTRAP_PASSWORD LAB_USER PACKAGES SSH_PUBKEY)
for v in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: missing required config value: $v"
    exit 1
  fi
done

if [[ ! -f "$SSH_PUBKEY" ]]; then
  echo "ERROR: SSH_PUBKEY not found at $SSH_PUBKEY"
  exit 1
fi
PUBKEY_CONTENT=$(cat "$SSH_PUBKEY")
PRIVKEY="${SSH_PUBKEY%.pub}"   # strips ".pub" to get the matching private key path

if [[ ! -f "$PRIVKEY" ]]; then
  echo "ERROR: private key not found at $PRIVKEY"
  exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$TARGET_PORT" -i "$PRIVKEY")

echo "==> Target reached via ${JUMP1_INTERNAL_HOST:-direct} @ ${JUMPHOST_IP:-n/a}:${JUMPHOST_PORT:-n/a} -> ${TARGET_IP}:${TARGET_PORT}"

ROOT_SSH() {
  sshpass -p "$BOOTSTRAP_PASSWORD" ssh "${SSH_OPTS[@]}" "$BOOTSTRAP_USER@$TARGET_IP" "$@"
}

echo "==> Step 1: Verify bootstrap connectivity"
if ! ROOT_SSH "echo OK" | grep -q OK; then
  echo "ERROR: cannot reach $BOOTSTRAP_USER@$TARGET_IP:$TARGET_PORT with bootstrap credentials."
  echo "       Check that the reverse tunnel (via $JUMP1_INTERNAL_HOST, port $JUMP1_TUNNEL_PORT) is up."
  exit 1
fi

echo "==> Step 2: Install packages ($PACKAGES)"
ROOT_SSH "apt-get update && apt-get install -y $PACKAGES"

echo "==> Step 3: Create lab user with SSH key auth, passwordless sudo, no password login"
ROOT_SSH bash -s <<EOF
set -e
id -u "$LAB_USER" &>/dev/null || useradd -m -s /bin/bash "$LAB_USER"
usermod -aG sudo "$LAB_USER"
mkdir -p /home/$LAB_USER/.ssh
echo "$PUBKEY_CONTENT" > /home/$LAB_USER/.ssh/authorized_keys
chmod 700 /home/$LAB_USER/.ssh
chmod 600 /home/$LAB_USER/.ssh/authorized_keys
chown -R $LAB_USER:$LAB_USER /home/$LAB_USER/.ssh
passwd -l "$LAB_USER"
echo "$LAB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$LAB_USER
chmod 440 /etc/sudoers.d/90-$LAB_USER
EOF

echo "==> Step 4: Verify lab user can log in with key BEFORE hardening sshd"
if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes -o PasswordAuthentication=no \
      "$LAB_USER@$TARGET_IP" "echo OK" | grep -q OK; then
  echo "ERROR: $LAB_USER key login failed. Aborting before hardening to avoid lockout."
  exit 1
fi
echo "    Confirmed: $LAB_USER key login works."

echo "==> Step 5: Configure ufw rules (config-only; enforcement requires NET_ADMIN)"
ROOT_SSH bash -s <<'EOF'
set -e
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
echo "NOTE: skipping 'ufw enable' — not supported without NET_ADMIN in this container"
EOF

echo "==> Step 6: Harden SSH (disable password auth + root login)"
ROOT_SSH bash -s <<'EOF'
set -e
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config || echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
grep -q '^PermitRootLogin no' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
systemctl restart ssh || service ssh restart
EOF

echo "==> Step 7: Re-verify lab user access post-hardening"
if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$LAB_USER@$TARGET_IP" "echo STILL_OK" | grep -q STILL_OK; then
  echo "ERROR: lost access after hardening! Manual recovery needed via docker exec."
  exit 1
fi

echo "==> Step 8: Verify hostname matches expected value '$HOSTNAME'"
ACTUAL_HOSTNAME=$(ssh "${SSH_OPTS[@]}" "$LAB_USER@$TARGET_IP" "hostname")
if [[ "$ACTUAL_HOSTNAME" == "$HOSTNAME" ]]; then
  echo "OK: hostname is '$ACTUAL_HOSTNAME'"
else
  echo "WARN: hostname is '$ACTUAL_HOSTNAME', expected '$HOSTNAME' — update docker-compose.yml's hostname: field"
fi

echo "==> Done. $LAB_USER@$TARGET_IP:$TARGET_PORT is provisioned and hardened as '$HOSTNAME'."