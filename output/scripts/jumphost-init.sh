#!/bin/bash
# jumphost-init.sh — Bootstrap script for the lab-jumphost container.
#
# Runs as the container's entrypoint on every start.
# The jump host is the public-facing SSH gateway; lab machines connect to it
# via reverse tunnel so developers can reach them without a direct route.
#
# Requirements:
#   - Install and start an SSH server
#   - Configure SSH to allow reverse tunnel forwarding (GatewayPorts, AllowTcpForwarding)
#   - Keep the container alive
#
# The jump host exposes two ports to the Docker host:
#   2220 — SSH management (you connect here to administer the jumphost)
#   2205 — reverse tunnel endpoint (traffic here is forwarded to lab-target:22)

# set -e

# # 1. Install SSH and sudo on the fly (since the base Ubuntu image is blank)
# echo "Installing OpenSSH server and sudo..."
# apt-get update && apt-get install -y openssh-server sudo

# # 2. Required runtime directory for the SSH daemon
# mkdir -p /var/run/sshd

# # 3. Create the user and set their password
# USER_NAME="myjump"
# USER_PASS="passwordeasy1234"

# if ! id "$USER_NAME" &>/dev/null; then
#     echo "Creating user: $USER_NAME"
#     useradd -rm -d /home/"$USER_NAME" -s /bin/bash "$USER_NAME"
#     echo "$USER_NAME:$USER_PASS" | chpasswd
#     usermod -aG sudo "$USER_NAME"
# fi

# # 4. Generate system host keys dynamically
# ssh-keygen -A

# # Configure SSH for reverse tunnels
# echo "Configuring SSH for reverse tunneling..."

# cat >> /etc/ssh/sshd_config <<EOF

# # Reverse SSH tunnel configuration
# AllowTcpForwarding yes
# GatewayPorts yes
# EOF

# echo "Checking SSH configuration..."
# /usr/sbin/sshd -t

# echo "Starting OpenSSH Server..."
# exec /usr/sbin/sshd -D

set -e

apt-get update
apt-get install -y openssh-server

mkdir -p /run/sshd
echo "root:jumppass" | chpasswd
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config
grep -q '^GatewayPorts' /etc/ssh/sshd_config || echo "GatewayPorts yes" >> /etc/ssh/sshd_config

exec /usr/sbin/sshd -D
