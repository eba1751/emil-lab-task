# SDK Lab Technician — Home Task

**Role:** SDK Lab Technician<br>
**Level:** Mid<br>
**Estimated time:** 3–4 hours (unassisted) · 1–2 hours (AI-assisted)

---

## Background

We run a small hardware test lab with Linux machines (x86_64 Mini PCs and Raspberry Pis). The machines sit behind a NAT router with no public IP — they cannot be reached directly from outside the network.

To reach the machines remotely, each one maintains a persistent reverse SSH tunnel to a jump host. Developers and CI connect through the jump host — they never touch the lab machines directly:

```
Developer / CI
      │
      │  ssh -p 2205 labuser@jumphost
      ▼
┌─────────────┐        reverse tunnel        ┌─────────────────┐
│  Jump Host  │ ◀──────────────────────────── │  Lab Machine    │
│             │                               │  (behind NAT)   │
└─────────────┘ ──────────────────────────── ▶└─────────────────┘
      │              forwarded to :22               │
      │                                             │
  reachable                                   not reachable
  from anywhere                               directly
```

When a new machine arrives, the lab technician provisions it from scratch and connects it to this infrastructure. **That's this task.**

---

## Environment

The lab is simulated using [Docker](https://docs.docker.com/get-docker/) (includes `docker compose`). We provide a minimal `docker-compose.yml` that wires two containers together:

| Container | Simulates | Host ports |
|-----------|-----------|------------|
| `lab-target` | Fresh lab machine (Ubuntu 24.04) | 2222 |
| `lab-jumphost` | Jump host | 2220 (SSH), 2205 (tunnel) |

Each container starts from a **bare `ubuntu:24.04` image** and runs an init script that you write. Think of the init scripts as having physical console access to a brand new machine for the first time — use them to get SSH accessible so your provisioning script can take over.

> ⚠️ Note: the environment may not support systemd out of the box. Handle this appropriately and explain your approach in the README.

---

## What We Provide

A starter kit with all files scaffolded. **Do not modify `docker-compose.yml`.**

| File | Status |
|------|--------|
| `docker-compose.yml` | Provided — do not modify |
| `config/lab-target.conf` | Provided — review and adjust if needed |
| `scripts/target-init.sh` | Scaffold — you implement |
| `scripts/jumphost-init.sh` | Scaffold — you implement |
| `provision.sh` | Scaffold — you implement |
| `lab-health.sh` | Scaffold — you implement |
| `README.md` | Template — you fill in |

Start the environment:
```bash
docker compose up -d
```

---

## Your Task

### Part 0 — Bootstrap

Write two init scripts that run inside the containers on startup:

**`scripts/target-init.sh`**
Prepare the target container so your provisioning script can connect to it.

**`scripts/jumphost-init.sh`**
Prepare the jump host container so the reverse tunnel can terminate there and be forwarded correctly.

These are the only entry point into otherwise blank containers — what you put in them is your call.

---

### Part 1 — Provision the machine

Write a script `provision.sh` that runs from your local machine, connects to `lab-target` over SSH, and brings it to a lab-ready state.

It must:

1. Install required packages: `curl`, `git`, `autossh`, `nodejs`, `npm`
2. Create a lab user of your choosing:
   - SSH key auth only
   - Passwordless sudo
   - No password login
3. Harden SSH:
   - Disable password authentication
   - Disable root login
4. Configure firewall (`ufw`):
   - Deny incoming
   - Allow outgoing
   - Allow SSH

   > ⚠️ Note: Docker containers run without `NET_ADMIN` capability, so `ufw` can configure rules but cannot enforce them at runtime. Handle this gracefully and explain your approach in the README.
5. Set the machine hostname

The script reads configuration from `config/lab-target.conf` (provided, pre-filled for the Docker environment). Review it before running.

---

### Part 2 — Reverse tunnel

Extend `provision.sh` or write a separate script to set up a **persistent reverse SSH tunnel** from `lab-target` to `lab-jumphost`.

Requirements:

1. The tunnel must forward `jumphost:2205 → lab-target:22`
2. It must:
   - Start automatically when the machine boots (or container starts)
   - Restart automatically if it drops
   - Use key-based auth — no passwords
3. After setup, verify the tunnel is working by connecting back through it:
```bash
ssh -p 2205 <your_lab_user>@localhost echo "tunnel OK"
```

> The jump host is reachable at `localhost:2220` from your local machine, and at `lab-jumphost:22` from inside the Docker network.

---

### Part 3 — Health check

Write a script `lab-health.sh` that runs from your local machine and connects to `lab-target` via SSH to verify it is in good shape.

It must check and report:

| Check | Pass condition |
|-------|---------------|
| Lab user exists | User present with sudo |
| SSH hardening | Password auth disabled, root login disabled |
| Firewall | ufw configured with correct default policies and SSH rule |
| Tunnel process | Reverse tunnel process running |
| Tunnel connectivity | Can reach machine via jump host on port 2205 |
| Node.js | Installed, print version |
| Public IP | Fetched and printed, flagged if ASN looks like a datacenter |

Output a clear `[OK]` / `[FAIL]` per check.
Exit with code `0` if all pass, `1` if any fail.

For the public IP / ASN check — use any free IP info API (e.g. `ipinfo.io`). Flag the result if the `org` field contains known datacenter keywords: `Google`, `Amazon`, `Microsoft`, `Cloudflare`, `DigitalOcean`, `Hetzner`, `OVH`.

---

## Deliverables

```
your-name-lab-task/
├── docker-compose.yml          # unmodified, provided by us
├── scripts/
│   ├── target-init.sh          # you implement
│   └── jumphost-init.sh        # you implement
├── provision.sh                # you implement
├── lab-health.sh               # you implement
├── config/
│   └── lab-target.conf         # provided, adjust if needed
└── README.md                   # you fill in
```

---

## README must include

1. How to run the full setup end to end
2. How you handled the systemd limitation in Docker
3. Any assumptions you made
4. One thing you would improve or add given more time

---

## What we're looking for

| Area | What we want to see |
|------|-------------------|
| **Does it run** | Full flow works: `docker compose up` → `provision.sh` → `lab-health.sh` all green |
| **Bootstrap scripts** | Show understanding of what needs to happen before provisioning can start |
| **Idempotency** | Running `provision.sh` twice doesn't break anything |
| **Error handling** | Failures are caught and reported clearly |
| **Tunnel** | Shows understanding of *why* reverse tunnel, not just *how* |
| **Health check** | Practical, actionable, correct exit codes |
| **systemd workaround** | Knows the limitation, handles it, explains it |
| **Code quality** | Readable, another technician could pick it up and maintain it |
| **README** | Clear, honest, shows judgment |

## What we're not looking for

- Perfect code
- A script that only works on one specific setup
- Copied snippets with no understanding of what they do

---

*Questions? Reach out — we're happy to clarify anything about the environment.*