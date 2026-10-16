# Minecraft server at mc.ola-vassbotn.no

This repository holds the setup for a Minecraft 26.3 server with Fabric.

## Current state

- The server runs on the Always Free A1 VM `minecraft` (VM.Standard.A1.Flex, 4 OCPU / 24 GB, Ubuntu 26.04) in `/opt/minecraft`, systemd unit `minecraft`.
- The server runs Fabric with Fabric API, Essential Commands (`/tpa` and `/nickname` only), LuckPerms, Lithium and BlueMap.
- Essential Commands uses the permissions API. Without a grant, each Essential Commands node needs op level 2. LuckPerms reads `config/luckperms/luckperms.conf`, but it keeps its data in `mods/luckperms`. The LuckPerms group `default` in `mods/luckperms/yaml-storage/groups/default.yml` grants the tpa nodes and `essentialcommands.nickname.self`.
- Essential Commands shows the nickname above the head of the player. A nickname can be the same as a Mojang username or the nickname of another player. The nametag is plain text with 16 characters at most. Other players see a new nickname after the player reconnects.
- The server also runs Share The Spare and Trade Cycling. Share The Spare uses the 26.2 build with the override in `config/fabric_loader_dependencies.json`.
- `server.properties` sets `view-distance=32`. Each player can choose a render distance up to 32 chunks. `simulation-distance=20` sets the distance in which the server ticks mobs, crops and redstone. It is the same for all players.
- The server sends the resource pack `https://mc.ola-vassbotn.no/resource-pack.zip` to each player. The pack is required: the server disconnects a player who declines it. The pack replaces the Cat music disc with "toad sings chandelier". The data pack `world/datapacks/cat-disc` sets the disc name to "Toad - Chandelier" and the song length to 212.9 seconds. Without the length, the jukebox stops the song after 185 seconds.
- The BlueMap mod replaces the BlueMap CLI and the `bluemap` unit. It renders in the server process.
- `https://mc.ola-vassbotn.no` shows a BlueMap map of the chunks that players visited, with live player positions. The map shows the Essential Commands nickname from `mc-nicknames` in place of the player name. Near the camera, a player shows as a 3D model with the skin from `mc-skins`.
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
- `cloud-init.yaml`: setup for the A1 VM. Java 25, Caddy, Fabric with the mods and their config, the non-default `server.properties` values, the `cat-disc` data pack, the BlueMap web panel, `mc-skins`, `mc-nicknames`, systemd units `minecraft`, `mcstatus` and `mc-backup`, firewall rule for 25565, 80 and 443.
- `ping.py`: Minecraft status ping. It prints the status as JSON. Run `python3 -I ping.py <host> 25565`. `provision.sh` copies it to `/usr/local/bin/ping.py` on the VM for `mcstatus`.
- `totp.py`: prints the current Oracle MFA code from a seed on stdin.
- `server-icon.svg`, `server-icon.png`: the server icon.
- `resource-pack.zip`: the resource pack with the new Cat disc song. `provision.sh` copies it to `/opt/bluemap/web/resource-pack.zip`. After a change, set its SHA-1 in `resource-pack-sha1` in `cloud-init.yaml` and on the VM.
- `.notes/oci-ids.env`: OCIDs of the Oracle resources. `provision.sh` reads it.
- `t3.json`, `scripts/worktree-cleanup.ts`, `.claude/settings.json`, `.codex/rules/default.rules`: setup for parallel agent work.

## Parallel work

Treat a task as done only when its changes are in a pull request and merged into `main`.
Treat a change that is live on the VM as not done until its pull request is merged.
Settle the thread and clean up immediately after the merge.
If a required step is blocked, report the current status and the blocker. Do not report the task as done.

Use one branch and one worktree for each task.
Start each task in a new T3 thread and its worktree.
Import the `Setup Worktree` action from `t3.json` in T3 project settings once.
Let T3 run the action for new worktrees. It updates the new branch to `origin/main`.
If T3 skips setup, run `git fetch origin main` and `git merge --ff-only origin/main` before edits.
Use the branch that T3 creates for the worktree. Rename it with `git branch -m` when needed. Do not create a second branch.
Create a new branch from the current `origin/main` only in a detached checkout.
Keep edits in the task worktree. Do not change another task's branch or worktree.
Coordinate changes to shared state with concurrent agents. Worktrees do not isolate this state:

- the main checkout at `/Users/olavassbotn/Developer/minecraft-server` and its `.git` directory, including the stash
- the A1 VM: `/opt/minecraft`, `/opt/bluemap`, `/usr/local/bin`, the systemd units and the server process
- the players on the server. A restart disconnects them.
- the Oracle Cloud resources, the quota policy `always-free-only` and the budget `zero-cost`
- GitHub settings and variables

## Pull requests

Create a pull request into `main` for each completed task. Do not merge a stack of pull requests.
Explain the change and report validation in the pull request description.
Run `pnpm test` before you push.
Review the final diff. Resolve review feedback within the task scope.
Resolve each review thread. Unresolved threads block auto-merge.
Fetch `origin/main` before you push. Merge it into the task branch if the branch is behind.
Enable auto-merge on your own PR with `gh pr merge --auto --merge` immediately after you push.
Do not wait for user review before you merge a PR without visual changes.
Let GitHub merge the PR when the required checks pass.
Run `gh pr checks --watch --fail-fast` to wait. Then run `gh pr view --json state,mergeStateStatus`.
If a check fails, fix the failure and push the correction. Auto-merge stays enabled for the new head commit.
If the state is `BEHIND`, merge `origin/main` into the task branch, resolve conflicts, and push.
Do not force-push, bypass branch protection, or merge with blocked checks. Do not use `gh pr merge --admin`.

## Visual review

Require explicit visual approval for changes to the map page beyond a minor correction.
Require approval for noticeable layout, navigation, typography, color, component styling, or responsive changes.
Treat an isolated correction that preserves the existing design as minor.
Require approval when the classification is unclear.
Use T3 preview tools first for web UI review and screenshots when they are available.
Call `mcp__t3_code__preview_snapshot` with `save: true`.
Embed each returned `screenshotPath` in the review message.
Copy other images to `~/.t3/userdata/attachments` before you embed them. T3 does not show images from `/tmp`.
For required review, capture the changed UI in the running app. Include the before and after states.
Show the screenshots to the user and ask for approval after the change is complete.
Do not enable auto-merge before the user approves the reviewed change.
Record the approval in the PR description. Treat a missing required approval as a blocker.
Request renewed approval if later changes materially alter the reviewed appearance.

## Deployment and cleanup

Apply changes to the VM by hand. No workflow deploys `main`.
Commit a change on the task branch before you apply it to the VM.
Compare each live file with `origin/main` before you overwrite it. Do not remove a live change that your branch does not contain.
Push the branch and open the pull request in the same turn as the VM change.
State in the pull request description which changes are live and which changes wait for a restart.
Start cleanup as soon as the PR state is `MERGED`.
Let GitHub delete the merged remote branch. Preserve thread history.
Stop every preview and background process that you started before the final response.
Create each temporary checkout, such as a visual review "before" state, with `git worktree add --detach` under `/tmp`.
Remove a temporary checkout with `git worktree remove <path>` after checking for local files.
After merge, run `pnpm worktree:cleanup . <pr-number> --branch-only --apply` in the task worktree.
This verifies the merged PR, detaches the checkout, and deletes the local task branch.
Keep the active T3 worktree and thread. Remove the worktree only after T3 stops.
Run `pnpm worktree:cleanup <path> <pr-number> --apply` from another checkout to remove an idle worktree.
Include the cleanup status in the final response.
Never force worktree removal. Preserve uncommitted files, ignored files that are not build output, and commits that are absent from `origin/main`.
