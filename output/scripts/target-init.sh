#!/bin/bash
# target-init.sh — Bootstrap script for the lab-target container.
#
# This script runs as the container's entrypoint (bash /init.sh) on every start.
# It must prepare the machine so that provision.sh can connect over SSH and take over.
#
# Requirements:
#   - Install and start an SSH server
#   - Create at least one account (or configure root) that provision.sh can log into
#   - Keep the container alive after setup (systemd is not available in bare Docker)
#
# Note: think of this script as having physical console access to a brand-new machine
# for the first time. You decide what credentials or keys allow the first SSH connection.

set -e

# 1. Install SSH and sudo on the fly (since the base Ubuntu image is blank)
echo "Installing OpenSSH server and sudo..."

apt-get update && apt-get install -y openssh-server sudo

# 2. Required runtime directory for the SSH daemon
mkdir -p /var/run/sshd

# 3. Create the user and set their password
USER_NAME="device1"
USER_PASS="passwordeasy1234"

if ! id "$USER_NAME" &>/dev/null; then
    echo "Creating user: $USER_NAME"
    useradd -rm -d /home/"$USER_NAME" -s /bin/bash "$USER_NAME"
    echo "$USER_NAME:$USER_PASS" | chpasswd
    usermod -aG sudo "$USER_NAME"
fi

# 4. Generate system host keys dynamically
ssh-keygen -A

# 5. Start SSH in the foreground to keep the container alive
echo "Starting OpenSSH Server..."
exec /usr/sbin/sshd -D

