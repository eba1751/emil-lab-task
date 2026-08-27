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
