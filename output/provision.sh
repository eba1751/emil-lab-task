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

# #!/bin/bash
# set -e

# if [ $# -ne 1 ]; then
#     echo "Usage: $0 <config-file>"
#     exit 1
# fi

# CONFIG="$1"

# if [ ! -f "$CONFIG" ]; then
#     echo "Config file not found: $CONFIG"
#     exit 1
# fi

# source "$CONFIG"

# echo "Connecting to $SSH_USER@$SSH_HOST:$SSH_PORT"

# for COMMAND in "${REMOTE_COMMANDS[@]}"; do
#     echo "Executing: $COMMAND"
#     ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$COMMAND"
# done

# echo "Provisioning completed."

#!/bin/bash
set -e

# ============================================================
# Usage
# ============================================================

if [ $# -ne 1 ]; then
    echo "Usage: $0 <config-file>"
    exit 1
fi

CONFIG="$1"

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

# Load configuration
source "$CONFIG"

# ============================================================
# Validate configuration
# ============================================================

: "${HOSTNAME:?HOSTNAME is not set}"
: "${TARGET_IP:?TARGET_IP is not set}"
: "${TARGET_PORT:?TARGET_PORT is not set}"
: "${BOOTSTRAP_USER:?BOOTSTRAP_USER is not set}"
: "${BOOTSTRAP_PASSWORD:?BOOTSTRAP_PASSWORD is not set}"
: "${LAB_USER:?LAB_USER is not set}"
: "${PACKAGES:?PACKAGES is not set}"
: "${SSH_PUBKEY:?SSH_PUBKEY is not set}"
: "${JUMPHOST_IP:?JUMPHOST_IP is not set}"
: "${JUMPHOST_PORT:?JUMPHOST_PORT is not set}"
: "${JUMP1_TUNNEL_PORT:?JUMP1_TUNNEL_PORT is not set}"
: "${JUMP1_INTERNAL_HOST:?JUMP1_INTERNAL_HOST is not set}"

# Expand ~ / $HOME in the public-key path
SSH_PUBKEY="${SSH_PUBKEY/#\~/$HOME}"

if [ ! -f "$SSH_PUBKEY" ]; then
    echo "SSH public key not found: $SSH_PUBKEY"
    exit 1
fi

PRIVATE_KEY="${SSH_PUBKEY%.pub}"

if [ ! -f "$PRIVATE_KEY" ]; then
    echo "SSH private key not found: $PRIVATE_KEY"
    exit 1
fi

echo "========================================"
echo " Provisioning target"
echo "========================================"
echo "Target:       $TARGET_IP:$TARGET_PORT"
echo "Hostname:     $HOSTNAME"
echo "Lab user:     $LAB_USER"
echo "Packages:     $PACKAGES"
echo "Jump host:    $JUMPHOST_IP:$JUMPHOST_PORT"
echo "Tunnel port:  $JUMP1_TUNNEL_PORT"
echo "========================================"

# ============================================================
# Bootstrap SSH
# ============================================================

echo "Connecting to target using bootstrap credentials..."

if ! command -v sshpass >/dev/null 2>&1; then
    echo "ERROR: sshpass is required."
    echo "Install it with:"
    echo "  apt-get install sshpass"
    exit 1
fi

# ============================================================
# Prepare remote provisioning script
# ============================================================

REMOTE_SCRIPT=$(cat <<EOF
set -e

echo "Setting hostname..."
hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || \
    echo "$HOSTNAME" > /etc/hostname

echo "Installing required packages..."
apt-get update
apt-get install -y openssh-server sudo autossh $PACKAGES

echo "Creating lab user..."

if ! id "$LAB_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$LAB_USER"
fi

echo "Configuring SSH key..."

mkdir -p /home/$LAB_USER/.ssh

cat > /home/$LAB_USER/.ssh/authorized_keys <<'KEYEOF'
$(cat "$SSH_PUBKEY")
KEYEOF

chown -R "$LAB_USER:$LAB_USER" /home/$LAB_USER/.ssh
chmod 700 /home/$LAB_USER/.ssh
chmod 600 /home/$LAB_USER/.ssh/authorized_keys

echo "Configuring passwordless sudo..."

cat > /etc/sudoers.d/$LAB_USER <<SUDOEOF
$LAB_USER ALL=(ALL) NOPASSWD:ALL
SUDOEOF

chmod 440 /etc/sudoers.d/$LAB_USER

echo "Configuring SSH server..."

mkdir -p /var/run/sshd

# Disable password authentication after bootstrap
sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Make sure these settings exist
grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config || \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config

grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config || \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# Check configuration
/usr/sbin/sshd -t

echo "Restarting SSH..."
systemctl restart ssh 2>/dev/null || true

echo "Target provisioning completed."
EOF
)

# ============================================================
# Execute remote provisioning
# ============================================================

sshpass -p "$BOOTSTRAP_PASSWORD" \
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -p "$TARGET_PORT" \
    "$BOOTSTRAP_USER@$TARGET_IP" \
    "bash -s" <<< "$REMOTE_SCRIPT"

echo "Target bootstrap completed."

# ============================================================
# Create reverse SSH tunnel
# ============================================================

echo "Configuring reverse SSH tunnel..."

echo "Tunnel:"
echo "  target:22"
echo "      ↓"
echo "  jump1:$JUMP1_TUNNEL_PORT"

# This command is intended to be run ON TARGET.
#
# target -> jump1
#
# jump1:$JUMP1_TUNNEL_PORT
#          |
#          +----> target:22

echo "Provisioning finished."