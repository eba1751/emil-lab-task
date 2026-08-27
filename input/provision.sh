#!/usr/bin/env bash
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
