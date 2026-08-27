#!/usr/bin/env bash
# lab-health.sh — Health check for a provisioned lab machine.
#
# Run this at any time to verify the machine is in good shape.
# Output: one [OK] / [FAIL] line per check.
# Exit:   0 if all checks pass, 1 if any fail.
#
# Usage: ./lab-health.sh [config-file]
#
# TODO (candidate): implement all checks marked TODO below.
#       For each check, explain in your README:
#         - what you test and why
#         - what "pass" means and how you detect it
#         - any edge cases or Docker-specific caveats you ran into

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────

CONFIG="${1:-config/lab-target.conf}"
[[ -f "$CONFIG" ]] || { echo "ERROR: config not found: $CONFIG" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"

# Validate required variables are set in the config file
_required=(LAB_USER TARGET_IP TARGET_PORT SSH_PUBKEY JUMPHOST_IP JUMPHOST_TUNNEL_PORT)
_missing=()
for _v in "${_required[@]}"; do
    [[ -n "${!_v-}" ]] || _missing+=("$_v")
done
if [[ ${#_missing[@]} -gt 0 ]]; then
    echo "ERROR: the following variables must be set in $CONFIG:" >&2
    printf '  %s\n' "${_missing[@]}" >&2
    exit 1
fi

SSH_PUBKEY_PATH="${SSH_PUBKEY/#\~/$HOME}"
SSH_PRIVKEY="${SSH_PUBKEY_PATH%.pub}"

LAB_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p $TARGET_PORT"
lab() { ssh $LAB_OPTS -i "$SSH_PRIVKEY" "$LAB_USER@$TARGET_IP" "$@"; }

# ── Output helpers ─────────────────────────────────────────────────────────

GREEN="\033[0;32m" RED="\033[0;31m" RESET="\033[0m"
PASS=0; FAIL=0

ok()   { echo -e "  ${GREEN}[OK]${RESET}   $*"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}[FAIL]${RESET} $*"; ((FAIL++)) || true; }

# ── Connectivity pre-check ─────────────────────────────────────────────────

echo
echo "Lab Health Check — $LAB_USER@$TARGET_IP:$TARGET_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! ssh $LAB_OPTS -i "$SSH_PRIVKEY" -o BatchMode=yes "$LAB_USER@$TARGET_IP" true 2>/dev/null; then
    echo -e "${RED}[FAIL] Cannot connect as $LAB_USER — is the machine provisioned?${RESET}"
    exit 1
fi

# ── 1. Lab user ────────────────────────────────────────────────────────────

echo
echo "[ Lab User ]"
# TODO: verify the lab user is correctly set up.

# ── 2. SSH hardening ───────────────────────────────────────────────────────

echo
echo "[ SSH Hardening ]"
# TODO: verify the SSH daemon is securely configured.
# Hint: sshd -T prints the effective runtime config, including values from drop-in files.

# ── 3. Firewall ────────────────────────────────────────────────────────────

echo
echo "[ Firewall ]"
# TODO: verify ufw is correctly configured.
# Note: ufw cannot enforce rules in an unprivileged Docker container (no NET_ADMIN);
#       consider verifying the config files instead of 'ufw status'.

# ── 4. Tunnel process ──────────────────────────────────────────────────────

echo
echo "[ Tunnel Process ]"
# TODO: check that the reverse tunnel process is running.

# ── 5. Tunnel connectivity ─────────────────────────────────────────────────

echo
echo "[ Tunnel Connectivity ]"
# TODO: verify the machine is reachable through the jump host on port $JUMPHOST_TUNNEL_PORT.

# ── 6. Node.js ────────────────────────────────────────────────────────────

echo
echo "[ Node.js ]"
NODE_VER=$(lab "node --version 2>/dev/null" || echo "")
if [[ -n "$NODE_VER" ]]; then
    ok "node $NODE_VER"
else
    fail "Node.js not installed or not in PATH"
fi

# ── 7. Public IP ──────────────────────────────────────────────────────────

echo
echo "[ Public IP ]"
# TODO: fetch the machine's public IP and flag results that look suspicious.

# ── Summary ────────────────────────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}Result: All $PASS checks passed.${RESET}"
    exit 0
else
    echo -e "${RED}Result: $PASS passed, $FAIL failed.${RESET}"
    exit 1
fi

