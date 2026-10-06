# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a vanilla Minecraft 26.3 server. Read `.notes/oracle-minecraft.md` before you change anything. It holds the facts that took time to establish, and the open decisions.

## Current state

- The server runs on the Always Free A1 VM `minecraft` (VM.Standard.A1.Flex, 4 OCPU / 24 GB, Ubuntu 26.04) in `/opt/minecraft`, systemd unit `minecraft`.
- The VM holds the reserved IP 82.70.43.201. The A record `mc.ola-vassbotn.no` points to it.
- The NTNU server is stopped. `~/minecraft` on `login.stud.ntnu.no` stays as a backup of the world from 2026-10-06.
- `mc-relay` is terminated. `cloud-init-relay.yaml` stays as a fallback.

## Rules

- Keep the cost at zero. Do not create resources outside the Oracle Always Free limits. The quota policy `always-free-only` and the budget `zero-cost` are the guardrails. Do not loosen them.
- Do not print, log or commit a credential. The Oracle MFA seed is in the macOS Keychain, service `oracle-cloud-ola15-totp`. The OCI API key is in `~/.oci`.
- Use the OCI CLI profile `API` (`OCI_CLI_PROFILE=API`).
- Use `ssh -i ~/.ssh/gitntntnu olamva@login.stud.ntnu.no` for the NTNU host.
- Use `ssh ubuntu@82.70.43.201` for the A1 VM.
- Send console commands with `ssh ubuntu@82.70.43.201 'sudo mc "<command>"'`. Read the output with `sudo journalctl -u minecraft -n 20`.
- Add each new fact that cost time to `.notes/oracle-minecraft.md`.

## Files

- `provision.sh`: launch, migration and resize loop for the A1 VM.
- `cloud-init.yaml`: setup for the A1 VM. Java 25, systemd unit `minecraft`, firewall rule for 25565.
- `cloud-init-relay.yaml`: setup for the terminated `mc-relay`.
- `ping.py`: Minecraft status ping. Run `python3 -I ping.py <host> 25565`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.

## Git remote

The remote is a bare repository on the NTNU host. Clone it with:

```bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/gitntntnu" git clone olamva@login.stud.ntnu.no:git/minecraft-server.git
```
