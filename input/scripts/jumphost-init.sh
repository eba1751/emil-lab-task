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
