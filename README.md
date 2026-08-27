# Getting Started

## 1. Read the task

See [TASK.md](TASK.md) for the full description.

## 2. Set up your submission repo

Create a **private** GitHub repo under your own account (e.g. `alice-lab-task`).

## 3. Clone this repo and re-point it

```bash
git clone <this-repo-url> alice-lab-task
cd alice-lab-task
git remote set-url origin git@github.com:alice/alice-lab-task.git
git push -u origin main
```

## Prerequisites

- [Docker Desktop](https://docs.docker.com/get-docker/) (includes `docker compose`)
- An SSH key pair at `~/.ssh/id_ed25519` (or adjust `SSH_PUBKEY` in `config/lab-target.conf`)

## 4. Do the work

The `input/` directory contains the starter files. Work from there:

```bash
cd input
docker compose up -d
# ... implement and run provision.sh and lab-health.sh
```

Commit your work to your repo as you go.

## 5. Submit

When you're done, invite [@vladislavs-brd](https://github.com/vladislavs-brd) as a collaborator on your repo and let us know.

---

*Questions? Reach out — we're happy to clarify anything about the environment.*
