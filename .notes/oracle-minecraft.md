# oracle-minecraft

## Goal

Run the vanilla Minecraft server on an Oracle Cloud Always Free VM at full capacity, with no `nice`. Move the world, whitelist and ops from the NTNU host. Point `mc.ola-vassbotn.no` at the VM with an A record at domene.no. Players join `mc.ola-vassbotn.no` directly.

## Established facts

<!-- append-only. each line cost time to learn. -->

- NTNU server: `~/minecraft` on loginstud04 (129.241.103.46), tmux session `mc`, Minecraft 26.3, Java 25. SSH needs `-i ~/.ssh/gitntntnu`.
- NTNU firewall blocks every inbound port except 22, on IPv4 and IPv6. Outbound 22 and 443 work.
- Whitelist is on. `SvckDucker` (d2d60030-d581-4253-aeed-02cd3d519889) is on it.
- Minecraft 26.3 server.jar: sha1 33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c, needs Java 25.
- `ola-vassbotn.no` uses ns1-3.dnsdomene.net. `mc.ola-vassbotn.no` has no record yet.
- DNS edits go through the `add-subdomain` skill: `codex exec -m gpt-6-sol --approve-for-me` with Computer Use on Arc.
- No `~/.oci` at start. Installed `oci-cli` 3.94.1 with brew. Log in with `oci session authenticate --region eu-stockholm-1 --profile-name DEFAULT`; it opens the browser.
- OCI account created 2026-10-06: cloud account (tenancy) `ola15`, home region eu-stockholm-1, user `ola@vassbotn.com`, free trial with credits plus Always Free. Tenant OCID is in the Gmail welcome mail.
- Oracle forces MFA enrollment at first login. Only Mobile App and FIDO are offered, no email. Enrolled the offline TOTP as "Ola Munthe's Phone-1"; seed is in macOS Keychain service `oracle-cloud-ola15-totp`. Code: `security find-generic-password -s oracle-cloud-ola15-totp -w | python3 -I totp.py`.
- IDCS sign-in uses Oracle JET `oj-input-text`. Typing into the inner input does not commit; set `document.getElementById('<id>').value` on the `OJ-INPUT-TEXT` element, then click the button by JS.
- CLI auth: `BROWSER=true oci session authenticate ...` prints the URL; the T3 preview browser can complete the localhost:8181 callback. Use `--auth security_token` on every call. Token lasts 60 min; `oci session refresh --profile DEFAULT` extends it.
- Trial limits: standard-a1-core-count 41, memory 277. Always Free covers only 4 OCPU / 24 GB, so the VM stays at that size.
- Stockholm has one AD: `UTTG:EU-STOCKHOLM-1-AD-1`. Image: Canonical-Ubuntu-26.04-aarch64-2026.08.17-0.
- Network ids, reserved IP id and instance id are in `.notes/oci-ids.env`. Reserved public IP: 82.70.43.201.
- `instance launch` returned 429 TooManyRequests twice within 20 min of signup. `launch.sh` retried every 60 s; `provision.sh` replaced it.
- After the 429s stopped, `instance launch` returns `InternalError: Out of host capacity.` for A1 4/24 in Stockholm (first at 14:38 local).
- OCI CLI retries 429 internally with backoff, so one launch call can take minutes.
- OCI CLI 3.94.1 has no `--wait-for-state` on `compute instance get`. It exits 2 with "No such option". `provision.sh` hid that error and failed at once after the A1 launch at 17:41. `provision.sh` now polls `lifecycle-state`. `public-ip update` and `instance action` accept `--wait-for-state`.
- `~/.ssh/known_hosts` on the Mac held a hashed `mc-relay` key for 82.70.43.201. After the IP move, `StrictHostKeyChecking=accept-new` refused the A1 VM, and `provision.sh` failed at the cloud-init step at 23:26. Hashed lines start with `|1|`, so `grep` for the IP misses them. Use `ssh-keygen -F <ip>` to find them and `ssh-keygen -R <ip>` to remove them.
- The A1 VM launches with `--assign-public-ip false`, so it has no internet until the reserved IP is attached. Cloud-init at first boot failed on all `apt` sources and on the `server.jar` download. Fix: attach the IP, then run `sudo cloud-init clean --logs --reboot`. The clean run makes new SSH host keys, so run `ssh-keygen -R <ip>` again.
- The A1 VM launched at 4 OCPU / 24 GB on 2026-10-06 17:41 local, in round 2 after the move to `~/Developer/minecraft-server`.
- DNS via codex: needs `--skip-git-repo-check` outside a git repo; `gpt-6-sol` is rejected for a ChatGPT account, use `gpt-6-luna`; Computer Use then fails with "Computer Use was not approved to use Arc" even with `--approve-for-me`.
- Quota policy `always-free-only` (tenancy): zero compute-core and compute-memory, A1 4 cores / 24 GB, block storage 200 GB. Verified: A1 available 4, E5 available 0.
- CLI profile `API` uses `~/.oci/minecraft_api_key.pem`. A new API key needs about 2 min before it authenticates.
- `provision.sh` runs in local tmux session `mc-provision` under `caffeinate -is`, logs to `.notes/provision.log`. It launches, attaches the IP, migrates the NTNU world and starts the server.
- codex exec cannot surface the Arc approval. A T3 `delegate_task` to codex gpt-6-luna with runtimeMode approval-required can, but Arc needs an open window, else `cgWindowNotFound`.
- DNS blocker 2026-10-06 15:40: the Mac screen is locked (CGSSessionScreenIsLocked true), so Computer Use sees no window; and Arc shows "cPanel Login", so the domene.no session has expired. The user must log in or add the record.
- `zero compute-core quotas` also zeroes the REGION-scope limits `standard-a1-core-regional-count` and `standard-a1-memory-regional-count`. Launch then fails with QuotaExceeded. The policy must also set both regional names to 4 and 24.
- A launch through a profile that inherits `security_token_file` from DEFAULT prints a warning to stderr. Keep stderr apart from stdout when you parse the instance OCID.
- DNS done by the user 2026-10-06 ~15:55: `mc.ola-vassbotn.no` A 82.70.43.201 on ns1-3 and 1.1.1.1.
- 16:01: all three sizes (4/24, 2/12, 1/6) returned Out of host capacity. One cascade round takes about 5 min because the CLI retries internally.
- Heap is `-XX:MaxRAMPercentage=80`, so it follows a later resize. `provision.sh` tries a resize to 4/24 every 10 min after DONE.
- An empty `oci ... list` prints nothing, not `[]`.
- Relay (2026-10-06 16:20): free VM.Standard.E2.1.Micro `mc-relay` (id `RELAY` in oci-ids.env) holds 82.70.43.201. NTNU tmux session `relay` runs `ssh -N -R 0.0.0.0:25565:localhost:25565 relay@82.70.43.201` with key `~/.ssh/mc_relay` in a reconnect loop. Ping to mc.ola-vassbotn.no works.
- Quota name `vm-standard-e2-1-micro-count` is not valid in `compute-core`; setting `standard-e2-micro-core-count` to 1 is enough, and the instance count then shows 1 available.
- Parallel launch calls from two loops cause 429 TooManyRequests.
- 2026-10-06 23:29: `provision.sh` logged DONE at 4 OCPU / 24 GB. The server runs on the A1 VM `minecraft` in `/opt/minecraft`, systemd unit `minecraft`. The NTNU server is stopped; `~/minecraft` on NTNU stays as a backup. At 23:32 the NTNU tmux `relay` was stopped and `mc-relay` was terminated with its boot volume.
- OCI CLI writes usage errors to stdout, not stderr, and exits 2. `compute instance terminate --wait-for-state` takes work request states (`SUCCEEDED`), not `TERMINATED`.
- The A1 VM has the 25565 ACCEPT rule twice in `INPUT`, from the two cloud-init runs. It does no harm.
- User approved Pay As You Go upgrade 2026-10-06 ~17:00. Budget `zero-cost` (amount 1, monthly) with ACTUAL and FORECAST alerts at 1% to ola@vassbotn.com. CLI path: `oci budgets budget budget create` / `oci budgets budget alert-rule create`.
- Upgrade page `https://cloud.oracle.com/invoices-and-orders/upgrade-and-payment?region=eu-stockholm-1` renders inside a same-origin iframe. It shows Plan type Free Tier, Account type Promo, and no payment method; a card must be added before "Upgrade your account". The user must enter the card.
- The IDCS session in the T3 preview tab survives; a later console login only asks for the TOTP.
- 2026-10-06 ~17:15: the user added a card and submitted the Pay As You Go upgrade. Console shows "Your upgrade is in progress"; Oracle emails on completion. Upgrade dialog needs Individual/Corporate, a tax payer ID or "Tax information is not available", and the Cloud Services Agreement checkbox.
- Git remote: bare repo `olamva@login.stud.ntnu.no:git/minecraft-server.git`. The repo sets `core.sshCommand` to `ssh -i ~/.ssh/gitntntnu`, because `~/.ssh/config` has no key for that host.
- The `aws` host 16.171.6.29 in `~/.ssh/config` does not answer on 22. No `aws` CLI.
- 2026-10-08: web map. BlueMap CLI 5.28 (sha256 c6868465…7ac2) reads 26.3 worlds. Minecraft 26.x keeps dimensions in `world/dimensions/minecraft/<dimension>` and player files in `world/players/{data,stats,advancements}`.
- World files are mode 640 and folders 751. Only the user `minecraft` can read them, so `bluemap` runs as `minecraft`.
- BlueMap `min-inhabited-time: 1` renders only chunks that a player was near. The server counts InhabitedTime for chunks within 128 blocks of a player. `view-distance=10` (160 blocks) covers that, so the map shows no chunk that a client did not get.
- BlueMap `remove-caves-below-y: 10000` with `cave-detection-ocean-floor: -5` removes faces without sky light that are more than 5 blocks below the ocean-floor heightmap. The Nether and End maps need `remove-caves-below-y: -10000`, because they have no sky light.
- BlueMap `webserver.conf` accepts `ip: "127.0.0.1"`. The generated template does not list the key. Missing keys take the defaults, so short config files work.
- The BlueMap webapp loads `scripts` and `styles` from `webapp.conf` after the maps load. `window.bluemap` has `maps`, `switchMap(id)`, `mapViewer.map.data.id` and `events` (event `bluemapMapChanged`).
- The first BlueMap render of the overworld (68 region files) takes about 1 h with 1 render thread at `Nice=19`.
- Caddy 2.6.2 from Ubuntu 26.04: the ZeroSSL fallback fails with `caddy_legacy_user_removed`. Let's Encrypt is the issuer that works.
- To apply new `write_files` entries on the running VM, copy `cloud-init.yaml` to `/tmp` and write the entries with `python3` and `yaml` (PyYAML 6.0.3 is on the VM).
- `oci network security-list get` prints kebab-case keys (`tcp-options`). `security-list update --ingress-security-rules` needs camelCase keys (`tcpOptions`) and replaces the whole list. Do not pipe the output of `get` into `update`. Write the full list in camelCase.
- BlueMap loads hires tiles only within the hires view distance (default 100 blocks). Past that it shows the lowres mesh, so detail appears only near the camera. `hires-slider-default: 200` in `webapp.conf` doubles it. A browser keeps its own value in localStorage key `bluemap-hiresViewDistance`.
- The lowres mesh has one vertex for each 10 texels at lod 1 (`PlaneGeometry` with `ceil(50 / lod)` segments for each tile). A no-data texel has height 0, so a cell between explored and unexplored land becomes a tall smeared wall. `status.js` patches the lowres fragment shader to discard each cell that has a no-data corner.
- InhabitedTime > 0 (2026-10-08): 11753 overworld chunks, x -2824..1784, z -3352..-8, median (-88, -1608). 1085 nether chunks, median (-40, -216). The End has no region files. Region files use deflate. To read InhabitedTime without an NBT parser, search the decompressed chunk for `04 00 0d "InhabitedTime"` and read the next 8 bytes.
- The BlueMap web server returns 204 for a missing tile. `status.js` greys out a dimension button when the four lod-3 tiles around 0,0 are all missing.
- A BlueMap restart keeps the render progress. With `render-thread-count: 3` the overworld render ETA drops from about 1.3 h to about 20 min.
- 2026-10-08 11:19: the user gave full access. The security list `SL` now has ingress for TCP 22, 25565, 80 and 443. After `systemctl reload caddy`, Caddy got a Let's Encrypt certificate at once. `https://mc.ola-vassbotn.no` serves the map, and HTTP redirects with 308.
- The first full render ran with `render-thread-count: 4` and `-Xmx4g` from a drop-in in `/run/systemd/system/bluemap.service.d/`. It ended at 11:15:58 (log line "Your maps are now all up-to-date!"). The drop-in is removed, and the setting is 3 threads and 2 GB again.
- Start position rule (user decision): a map starts at 0,0 when one of the four chunks at the origin is generated (`Status` `minecraft:full`). Otherwise it starts at the median of the visited chunks. `/usr/local/bin/bluemap-start-pos` writes `start-pos` into each map config as `ExecStartPre`, in about 5 s. The overworld origin is generated, but the nearest visited chunk is 147 blocks away. In the Nether, a visited chunk is 25 blocks from the origin.
- The status countdown uses the `Last-Modified` header of `status.json` (the BlueMap web server sends it, but it rejects HEAD with 400). The browser polls 11 s after that time, so the countdown goes from 10 to 1 in step with the server.
- The Claude auto-mode classifier blocks `oci network security-list update` as "Protected-Scope IaC Apply". The user must run it or allow it.
- UI decisions (user, 2026-10-08): no BlueMap menu and no Map-List button. A ⚙ card in our panel holds the Hi-res and Low-res sliders and Fullscreen. Dark, semi-transparent, rounded, system font, always dark. English only. Names only in the player list. On phones (BlueMap break 575.98 px), the top bar shows day/night, view mode, reset and compass, and hides x/z and the zoom buttons.
- `webapp.zip` in the BlueMap CLI jar has `assets/index-*.js.map` with the full Vue sources in `sourcesContent`. Read the sources there, not in the minified bundle.
- BlueMap writes `index.html` and `lang/` into the webroot only on the first start. Later starts do not rewrite them, so a changed `lang/settings.conf` is lost on a new VM. `status.js` forces English with `document.querySelector("#app").__vue_app__.config.globalProperties.$i18n.locale = "en"`.
- Zoom to cursor: `status.js` wraps `bluemap.mapControls.mouseZoom.update` and `touchZoom.update`. With zoom factor k and ground point X under the cursor, the new target is X + k(P - X). This is exact in perspective and flat view, because the flat view size is proportional to the distance. X comes from the ray at the height `controlsManager.lastPosition.y`, because `MapControls.update` sets `position.y` to -10000 before the zoom step. The + and - buttons also add to `mouseZoom.deltaZoom`, so a `pointerdown` clears the cursor point and they zoom to the center.
- `filter: drop-shadow` on `.control-bar` and `#zoom-buttons` stops `backdrop-filter` on their children. `status.css` sets `filter: none` and uses `box-shadow`.
- The phone top bar needs about 348 px. Below that width, the view-mode group is clipped.
- The T3 preview screenshot is at most 640x400, so a 1280x800 page shows at half size. Set `zoom: 2` on the inner `#app` to see the UI at full size.

## Open decisions

<!-- questions for the user. ask these before building, not after. -->

- User decision changed: upgrade to Pay As You Go, still zero cost via quota and budget alert. Upgrade submitted, waiting for Oracle to finish it.


## Dead ends

<!-- what was tried and did not work, and why. stops rediscovery. -->

- Direct connection to the NTNU host on 25565 over IPv4 and IPv6: firewall drops it.
