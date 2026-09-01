# Lab Task — README

A library that imitates SSHing to devices under test via a remotely managed lab server / host.

## Required sections

### 1. How to run the full setup end to end

1. After cloning the repo, go to "output" directory and run docker-compose.yml with "docker-compose up -d" 
2. Two containersare up and running - lab-jumphost and lab-target (device under test)
3. Tunneling works and ssh is accessible. Check accessibility with these 3 commands:
    ssh -p 2220 root@localhost   # direct SSH to jumphost (password: jumppass)
    ssh -p 2222 root@localhost   # direct SSH to target (password: targetpass)
    ssh -p 2205 root@localhost   # reaches target's SSH via the reverse tunnel through bridge
4. Next you nedd to provision target machine via the provision.sh script, it uses .conf files in "config' directory:
    a. Make provision.sh executable with "chmod a+x provision.sh"
    b. Run it with "./provision.sh config/<your conf file>"
    c. This will install packages on target machine
5. !!! Submitted after daedline !!! Run "./lab_health.sh" for some basic tests on DUT.

### 2. How you handled the systemd limitation in Docker

On the jump machine exec /usr/sbin/sshd -D — the exec replaces the shell process with sshd itself, so sshd becomes PID 1
On the target machine bash (running target-init.sh) is PID 1, with sshd as a child process.

During SSH harfening process "PAM/Docker interaction" was encountered and fixed by commenting it out.

### 3. Assumptions made

Containers are running manually by user. They will not auto-restart since "restart: unless-stopped" was not used in docker compose yml.

### 4. One thing you would improve or add given more time

Possible improvements:
1. Using a tool like Ansible wich is exactly for SSH based tasks can result in more modern and clrarer implementation.
2. Use python scripting with pytest instead (or in addition to lab-health.sh)
3. Use routing on the jump machine to connect to targets behind NAT.

With more time:
SSH hardening section was not implemented because time limitation.
Also "lab-health.sh" was not implemented.
