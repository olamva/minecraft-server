# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a vanilla Minecraft 26.3 server. Read `.notes/oracle-minecraft.md` before you change anything. It holds the facts that took time to establish, and the open decisions.

## Current state

- The server runs on the Always Free A1 VM `minecraft` (VM.Standard.A1.Flex, 4 OCPU / 24 GB, Ubuntu 26.04) in `/opt/minecraft`, systemd unit `minecraft`.
- The VM holds the reserved IP 82.70.43.201. The A record `mc.ola-vassbotn.no` points to it.
- `https://mc.ola-vassbotn.no` shows a BlueMap map of the chunks that players visited, a dimension switcher and the online players. `status.js` replaces BlueMap's menu with a ⚙ card (Hi-res, Low-res, Fullscreen), forces English, and zooms toward the cursor or the pinch point. Caddy (`/etc/caddy/Caddyfile`) proxies to the BlueMap web server on 127.0.0.1:8100. The unit `bluemap` renders and serves the map from `/opt/bluemap`. The unit `mcstatus` writes `/opt/bluemap/web/status.json` every 10 s. Each map starts at 0,0 when the origin chunks are generated, else at the median of the visited chunks. `/usr/local/bin/bluemap-start-pos` sets this before each BlueMap start.
- `mc-relay` is terminated. `cloud-init-relay.yaml` stays as a fallback.

## Rules

- Keep the cost at zero. Do not create resources outside the Oracle Always Free limits. The quota policy `always-free-only` and the budget `zero-cost` are the guardrails. Do not loosen them.
- Use the OCI CLI profile `API` (`OCI_CLI_PROFILE=API`).
- Use `ssh ubuntu@82.70.43.201` for the A1 VM.
- Send console commands with `ssh ubuntu@82.70.43.201 'sudo mc "<command>"'`. Read the output with `sudo journalctl -u minecraft -n 20`.
- Change the VM setup in `cloud-init.yaml` first. Then apply the same change on the running VM.
- Add each new fact that cost time to `.notes/oracle-minecraft.md`.

## Files

- `provision.sh`: launch, migration and resize loop for the A1 VM.
- `cloud-init.yaml`: setup for the A1 VM. Java 25, Caddy, BlueMap CLI with its config and web panel, systemd units `minecraft`, `bluemap` and `mcstatus`, firewall rule for 25565, 80 and 443.
- `cloud-init-relay.yaml`: setup for the terminated `mc-relay`.
- `ping.py`: Minecraft status ping. It prints the status as JSON. Run `python3 -I ping.py <host> 25565`. `provision.sh` copies it to `/usr/local/bin/ping.py` on the VM for `mcstatus`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.

## Git remote

The remote is the private GitHub repository `olamva/minecraft-server`. Clone it with:

```bash
git clone git@github.com:olamva/minecraft-server.git
```
