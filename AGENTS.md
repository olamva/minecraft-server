# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a Minecraft 26.3 server with Fabric.

## Current state

- The server runs on the Always Free A1 VM `minecraft` (VM.Standard.A1.Flex, 4 OCPU / 24 GB, Ubuntu 26.04) in `/opt/minecraft`, systemd unit `minecraft`.
- The server runs Fabric with Fabric API, Essential Commands (`/tpa` and `/nickname` only), Lithium and BlueMap.
- The server also runs Share The Spare and Trade Cycling. Share The Spare uses the 26.2 build with the override in `config/fabric_loader_dependencies.json`.
- The BlueMap mod replaces the BlueMap CLI and the `bluemap` unit. It renders in the server process.
- `https://mc.ola-vassbotn.no` shows a BlueMap map of the chunks that players visited, with live player positions. Near the camera, a player shows as a 3D model with the skin from `mc-skins`.
- The timer `mc-backup` makes a snapshot of the world every 30 minutes when a player was online since the last snapshot. It keeps the last 48 snapshots in `/var/backups/minecraft`. `latest` points to the newest snapshot. Unchanged files are hard links.

## Rules

- Keep the cost at zero. Do not create resources outside the Oracle Always Free limits. The quota policy `always-free-only` and the budget `zero-cost` are the guardrails. Do not loosen them.
- Use the OCI CLI profile `API` (`OCI_CLI_PROFILE=API`).
- Use `ssh ubuntu@82.70.43.201` for the A1 VM.
- Send console commands with `ssh ubuntu@82.70.43.201 'sudo mc "<command>"'`. Read the output with `sudo journalctl -u minecraft -n 20`.
- Change the VM setup in `cloud-init.yaml` first. Then apply the same change on the running VM.
- After a BlueMap update, delete `/opt/bluemap/web/index.html` before the restart. The mod writes its web app only when `index.html` is missing.
- Add only server-side mods. Players can use the vanilla client. Trade Cycling is the only exception: a player installs it on the client to get the trade cycling button. Do not tell players about Trade Cycling.

## Files

- `provision.sh`: launch, migration and resize loop for the A1 VM.
- `cloud-init.yaml`: setup for the A1 VM. Java 25, Caddy, Fabric with the mods and their config, the BlueMap web panel, `mc-skins`, systemd units `minecraft`, `mcstatus` and `mc-backup`, firewall rule for 25565, 80 and 443.
- `ping.py`: Minecraft status ping. It prints the status as JSON. Run `python3 -I ping.py <host> 25565`. `provision.sh` copies it to `/usr/local/bin/ping.py` on the VM for `mcstatus`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.
