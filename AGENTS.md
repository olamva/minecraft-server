# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a vanilla Minecraft 26.3 server. Read `.notes/oracle-minecraft.md` before you change anything. It holds the facts that took time to establish, and the open decisions.

## Current state

- A free Oracle VM `mc-relay` (VM.Standard.E2.1.Micro) holds the reserved IP 82.70.43.201. The A record `mc.ola-vassbotn.no` points to it.
- `provision.sh` runs on the Mac in the local tmux session `mc-provision`. It logs to `.notes/provision.log`. It retries an Always Free A1 VM, moves the IP and the world to it, starts the server, and resizes the VM to 4 OCPU / 24 GB.

## Rules

- Keep the cost at zero. Do not create resources outside the Oracle Always Free limits. The quota policy `always-free-only` and the budget `zero-cost` are the guardrails. Do not loosen them.
- Use the OCI CLI profile `API` (`OCI_CLI_PROFILE=API`).
- Add each new fact that cost time to `.notes/oracle-minecraft.md`.

## Files

- `provision.sh`: launch, migration and resize loop for the A1 VM.
- `cloud-init.yaml`: setup for the A1 VM. Java 25, systemd unit `minecraft`, firewall rule for 25565.
- `cloud-init-relay.yaml`: setup for `mc-relay`.
- `ping.py`: Minecraft status ping. Run `python3 -I ping.py <host> 25565`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.

## Git remote


```bash
```
