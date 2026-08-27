# Lab Task — README

A library that imitates SSHing to devices under test via a remotely managed lab server / host.

## Required sections

### 1. How to run the full setup end to end

1. After cloning the repo, run docker-compose.yml
2. Two containersare up and running - lab-jumphost and lab-target (device under test)
3. Tunneling works and ssh is accessible.
4. Did not get to ssh-hardening section

### 2. How you handled the systemd limitation in Docker

I did not encounter it

### 3. Assumptions made

Different approaches exist from which file we want to install packages. Best approacj is to use a config (or ini file)

### 4. One thing you would improve or add given more time

SSH hardening section was not implemented because time limitation.
Also "lab-health.sh" was not implemented.
