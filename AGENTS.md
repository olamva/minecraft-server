# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a vanilla Minecraft 26.3 server.

## Current state

- The server runs on the Always Free A1 VM `minecraft` (VM.Standard.A1.Flex, 4 OCPU / 24 GB, Ubuntu 26.04) in `/opt/minecraft`, systemd unit `minecraft`.
- `https://mc.ola-vassbotn.no` shows a BlueMap map of the chunks that players visited
- The timer `mc-backup` makes a snapshot of the world every 30 minutes when a player was online since the last snapshot. It keeps the last 48 snapshots in `/var/backups/minecraft`. `latest` points to the newest snapshot. Unchanged files are hard links.

## Rules

- Keep the cost at zero. Do not create resources outside the Oracle Always Free limits. The quota policy `always-free-only` and the budget `zero-cost` are the guardrails. Do not loosen them.
- Use the OCI CLI profile `API` (`OCI_CLI_PROFILE=API`).
- Use `ssh ubuntu@82.70.43.201` for the A1 VM.
- Send console commands with `ssh ubuntu@82.70.43.201 'sudo mc "<command>"'`. Read the output with `sudo journalctl -u minecraft -n 20`.
- Change the VM setup in `cloud-init.yaml` first. Then apply the same change on the running VM.

## Files

- `provision.sh`: launch, migration and resize loop for the A1 VM.
- `cloud-init.yaml`: setup for the A1 VM. Java 25, Caddy, BlueMap CLI with its config and web panel, systemd units `minecraft`, `bluemap`, `mcstatus` and `mc-backup`, firewall rule for 25565, 80 and 443.
- `ping.py`: Minecraft status ping. It prints the status as JSON. Run `python3 -I ping.py <host> 25565`. `provision.sh` copies it to `/usr/local/bin/ping.py` on the VM for `mcstatus`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.
