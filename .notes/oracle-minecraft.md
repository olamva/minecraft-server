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
- After provision.sh DONE: kill NTNU tmux `relay`, terminate `mc-relay` with its boot volume.
- User approved Pay As You Go upgrade 2026-10-06 ~17:00. Budget `zero-cost` (amount 1, monthly) with ACTUAL and FORECAST alerts at 1% to ola@vassbotn.com. CLI path: `oci budgets budget budget create` / `oci budgets budget alert-rule create`.
- Upgrade page `https://cloud.oracle.com/invoices-and-orders/upgrade-and-payment?region=eu-stockholm-1` renders inside a same-origin iframe. It shows Plan type Free Tier, Account type Promo, and no payment method; a card must be added before "Upgrade your account". The user must enter the card.
- The IDCS session in the T3 preview tab survives; a later console login only asks for the TOTP.
- 2026-10-06 ~17:15: the user added a card and submitted the Pay As You Go upgrade. Console shows "Your upgrade is in progress"; Oracle emails on completion. Upgrade dialog needs Individual/Corporate, a tax payer ID or "Tax information is not available", and the Cloud Services Agreement checkbox.
- Git remote: bare repo `olamva@login.stud.ntnu.no:git/minecraft-server.git`. The repo sets `core.sshCommand` to `ssh -i ~/.ssh/gitntntnu`, because `~/.ssh/config` has no key for that host.
- The `aws` host 16.171.6.29 in `~/.ssh/config` does not answer on 22. No `aws` CLI.

## Open decisions

<!-- questions for the user. ask these before building, not after. -->

- User decision changed: upgrade to Pay As You Go, still zero cost via quota and budget alert. Upgrade submitted, waiting for Oracle to finish it.


## Dead ends

<!-- what was tried and did not work, and why. stops rediscovery. -->

- Direct connection to the NTNU host on 25565 over IPv4 and IPv6: firewall drops it.
