# Plan: Fabric with /tpa, Lithium and the BlueMap mod

Facts in this plan are from 2026-10-11.

## Already done

The gamerule `players_sleeping_percentage` is 50. The world stores it in `level.dat`. Do not change it.

## Goal

- All players can use `/tpa`, `/tpahere`, `/tpaccept` and `/tpdeny`.
- No player can use `/back`, `/home`, `/sethome`, `/warp`, `/spawn` or the other Essential Commands features.
- Lithium makes the server tick faster. Game behaviour stays vanilla.
- The BlueMap mod replaces the BlueMap CLI. The map at https://mc.ola-vassbotn.no shows live player positions.
- A click on a player in the panel makes the map follow that player.
- Optional, as a second step: a 3D player model that walks. See "Optional phase: 3D player model".
- Players keep the vanilla client. All mods are server-side only.

## Decisions

Do not change these decisions.

- Use Fabric, not Paper. Fabric keeps vanilla game behaviour and the vanilla world folder layout. `mc-backup`, `bluemap-start-pos` and the BlueMap map configs keep their paths.
- Keep the vanilla `server.jar` with its sha1 check. The Fabric launcher uses it through `-Dfabric.installer.server.gameJar=server.jar`. Without this option, the launcher downloads a second vanilla jar to `.fabric/server/26.3-server.jar`.
- Save each mod as a jar without a version in its name, for example `mods/lithium.jar`. An update then replaces the old jar. Two versions of one mod in `mods/` stop the server.
- Keep the rendered map. The mod uses `/opt/bluemap/data` and `/opt/bluemap/web` with absolute paths. BlueMap does not render the world again.
- Keep `mcstatus` and `ping.py`. Change `status.js` and `status.css` only as the "Web UI" section tells.
- Do not open new ports. Do not create OCI resources.

## Versions

| File | URL | Hash |
|---|---|---|
| `fabric-server-launch.jar` (loader 0.19.5, installer 1.1.2) | `https://meta.fabricmc.net/v2/versions/loader/26.3/0.19.5/1.1.2/server/jar` | sha256 `0b56ad54d762172e8b8748e467f584f071e4dedecd93dc336cf2c68837e790be` |
| `mods/fabric-api.jar` (0.162.0+26.3) | `https://cdn.modrinth.com/data/P7dR8mSH/versions/v2j28coa/fabric-api-0.162.0%2B26.3.jar` | sha512 `5ab70908952f1d2346d16b122ca31327f4055db59c279a1bc3c3c581ce359bb541cba15730f55b0727be7c7c4debc4a4412a183c228e0d4dea81c734f7b412ce` |
| `mods/essential-commands.jar` (0.42.0-mc26.3) | `https://cdn.modrinth.com/data/6VdDUivB/versions/KANmt7ie/essential_commands-0.42.0-mc26.3.jar` | sha512 `6edda40084a85446817e1c393f8ea0a386300762c553990ee2bf613a93623f883be752824635f3d7f1d2a89c7b247cc246afd18a1e0d293ff022433b301e180e` |
| `mods/lithium.jar` (0.26.2+mc26.3) | `https://cdn.modrinth.com/data/gvQqBUqZ/versions/xS0Q8LSi/lithium-fabric-0.26.2%2Bmc26.3.jar` | sha512 `4d7fee66132eedc71feab9390b92c95d7058edbdad0fecfac1d836a2950b97a7ca463afbede61c7ef361ce65e1f927ab9e89dde5bf2e0e0ce486afb5c5dbee40` |
| `mods/bluemap.jar` (5.29-fabric) | `https://cdn.modrinth.com/data/swbUV1cr/versions/SX74rxzP/bluemap-5.29-fabric.jar` | sha512 `032a96971437e43a3722d8d6c026aeb9837117e1a56521d017a68fce8bb5630ceffd98454672b9d6c589a1008fcd2ab4cd48f4af8fadf08755313b1e326bedb1` |

Essential Commands and BlueMap need Fabric API. Lithium needs no other mod.

Before you start, check for newer releases. If you change a version, change its hash too.

```sh
for s in fabric-api essential-commands lithium bluemap; do curl -sG "https://api.modrinth.com/v2/project/$s/version" --data-urlencode 'game_versions=["26.3"]' --data-urlencode 'loaders=["fabric"]' | python3 -I -c "import json,sys; v=json.load(sys.stdin)[0]; f=[f for f in v['files'] if f['primary']][0]; print('$s', v['version_number'], f['url'], f['hashes']['sha512'])"; done
curl -s https://meta.fabricmc.net/v2/versions/loader/26.3 | python3 -I -c 'import json,sys; print(json.load(sys.stdin)[0]["loader"]["version"])'
```

## Changes to `cloud-init.yaml`

### `minecraft.service`

Add the `ExecStartPre` line from `bluemap.service`. Change `ExecStart`:

```ini
ExecStartPre=-/usr/bin/python3 -I /usr/local/bin/bluemap-start-pos
ExecStart=/usr/bin/java -XX:InitialRAMPercentage=80 -XX:MaxRAMPercentage=80 -Dfabric.installer.server.gameJar=server.jar -jar fabric-server-launch.jar nogui
```

### `bluemap.service`

Remove the unit. Remove `bluemap.service` from the `systemctl enable` line.

### `bluemap-start-pos`

Change the glob to the new config path:

```python
for conf in glob.glob("/opt/minecraft/config/bluemap/maps/*.conf"):
```

### BlueMap config

Move every file from `/opt/bluemap/config/` to `/opt/minecraft/config/bluemap/`. Keep the three map configs as they are. Change these files:

`/opt/minecraft/config/bluemap/core.conf`. Use 2 render threads. The CLI had `Nice=19`, but the mod renders in the server process, so leave cores for the game.

```hocon
accept-download: true
data: "/opt/bluemap/data"
render-thread-count: 2
```

`/opt/minecraft/config/bluemap/webserver.conf`:

```hocon
webroot: "/opt/bluemap/web"
ip: "127.0.0.1"
```

`/opt/minecraft/config/bluemap/webapp.conf`:

```hocon
webroot: "/opt/bluemap/web"
hires-slider-default: 200
scripts: ["status.js"]
styles: ["status.css"]
```

`/opt/minecraft/config/bluemap/storages/file.conf`:

```hocon
storage-type: file
root: "/opt/bluemap/web/maps"
```

Do not write `plugin.conf`. The defaults show live player markers and hide players in spectator mode.

### Essential Commands config

Add `/opt/minecraft/config/EssentialCommands.properties`. Only `/tpa` stays on. The other `enable_*` keys are already `false` by default.

```properties
auto_afk_enabled=false
enable_afk=false
enable_back=false
enable_day=false
enable_delete_all_player_data=false
enable_enderchest=false
enable_extinguish=false
enable_feed=false
enable_fly=false
enable_gametime=false
enable_heal=false
enable_home=false
enable_invuln=false
enable_near=false
enable_nick=false
enable_night=false
enable_repair=false
enable_rtp=false
enable_rules=false
enable_spawn=false
enable_suicide=false
enable_top=false
enable_tpa=true
enable_warp=false
enable_wastebin=false
enable_workbench=false
```

### `runcmd`

Remove the two BlueMap CLI lines. Add these lines after the `server.jar` check:

```yaml
  - install -d -o minecraft -g minecraft /opt/minecraft/mods
  - curl -sSfLo /opt/minecraft/fabric-server-launch.jar https://meta.fabricmc.net/v2/versions/loader/26.3/0.19.5/1.1.2/server/jar
  - cd /opt/minecraft && echo "0b56ad54d762172e8b8748e467f584f071e4dedecd93dc336cf2c68837e790be  fabric-server-launch.jar" | sha256sum -c
  - curl -sSfLo /opt/minecraft/mods/fabric-api.jar https://cdn.modrinth.com/data/P7dR8mSH/versions/v2j28coa/fabric-api-0.162.0%2B26.3.jar
  - curl -sSfLo /opt/minecraft/mods/essential-commands.jar https://cdn.modrinth.com/data/6VdDUivB/versions/KANmt7ie/essential_commands-0.42.0-mc26.3.jar
  - curl -sSfLo /opt/minecraft/mods/lithium.jar https://cdn.modrinth.com/data/gvQqBUqZ/versions/xS0Q8LSi/lithium-fabric-0.26.2%2Bmc26.3.jar
  - curl -sSfLo /opt/minecraft/mods/bluemap.jar https://cdn.modrinth.com/data/swbUV1cr/versions/SX74rxzP/bluemap-5.29-fabric.jar
  - cd /opt/minecraft/mods && echo "5ab70908952f1d2346d16b122ca31327f4055db59c279a1bc3c3c581ce359bb541cba15730f55b0727be7c7c4debc4a4412a183c228e0d4dea81c734f7b412ce  fabric-api.jar" | sha512sum -c
  - cd /opt/minecraft/mods && echo "6edda40084a85446817e1c393f8ea0a386300762c553990ee2bf613a93623f883be752824635f3d7f1d2a89c7b247cc246afd18a1e0d293ff022433b301e180e  essential-commands.jar" | sha512sum -c
  - cd /opt/minecraft/mods && echo "4d7fee66132eedc71feab9390b92c95d7058edbdad0fecfac1d836a2950b97a7ca463afbede61c7ef361ce65e1f927ab9e89dde5bf2e0e0ce486afb5c5dbee40  lithium.jar" | sha512sum -c
  - cd /opt/minecraft/mods && echo "032a96971437e43a3722d8d6c026aeb9837117e1a56521d017a68fce8bb5630ceffd98454672b9d6c589a1008fcd2ab4cd48f4af8fadf08755313b1e326bedb1  bluemap.jar" | sha512sum -c
```

The existing `chown -R minecraft:minecraft /opt/minecraft /opt/bluemap` line gives the new files to the `minecraft` user.

### Web UI

Change `status.js` and `status.css`.

The live data adds these items to the page:

- A marker for each player, with the head and a name tag. The elements are `.bm-marker-player`, its `img` and `.bm-player-name`. BlueMap moves the markers in real time through server-sent events (`maps/<id>/live/sse`). BlueMap hides the marker of a player in a different dimension.
- A player list button in the BlueMap control bar. The rule `#app .control-bar > :has(~ .space.greedy)` in `status.css` already hides it, together with the menu button. Keep it hidden. The custom panel stays the only player list.

These items stay the same:

- The 5.29 web app changes only the tile cache in `TileLoader.js` and `LowresTileLoader.js`. The lowres shader that `cutWalls` patches has no change. The zoom and settings code in `status.js` needs no change.
- The panel reads `status.json` from `mcstatus` every 10 seconds. The markers move faster than the list. This is correct.

Make these changes:

1. Style the markers like the panel. Give `.bm-player-name` the `Minecraft` font, the `--theme-bg` background, `border-radius: .5em` and the blur of the panel. Keep the BlueMap rules for `distance-data`. They make the head smaller and hide the name when the camera is far away.
2. Follow a player from the panel. Make each row in `#mc-players` a `button`, so the `#mc-panel button` rules give the hover and `.active` styles. Change the `#mc-players > div` rule to `#mc-players > button`. On click, do the steps of `MarkerItem.vue` in BlueMap. This sketch is not tested:

   ```js
   const cm = bluemap.mapViewer.controlsManager;
   cm.controls?.stopFollowingPlayerMarker?.();
   let marker = bluemap.playerMarkerManager.getPlayerMarker(player.id);
   if (!marker || marker.data.foreign) {
     const map = await bluemap.findPlayerMap(player.id);
     if (!map) return;
     await bluemap.switchMap(map.data.id);
     marker = bluemap.playerMarkerManager.getPlayerMarker(player.id);
   }
   if (!marker?.visible) return;
   cm.controls?.followPlayerMarker?.(marker);
   cm.position.copy(marker.position);
   ```

   BlueMap stops the follow when the user moves the map. BlueMap also switches the map when the player goes to a different dimension (`followPlayerMarkerWorld` in `BlueMapApp.js`). In `tick()`, set `.active` on the row whose `player.id` is `cm.controls?.data?.followingPlayer?.data.playerUuid`. Then the mark goes away less than one second after the user moves the map. A spectator has no marker, so a click on a spectator does nothing.
3. Use the head images from BlueMap. When a player joins, BlueMap writes the head to `maps/<id>/assets/playerheads/<uuid>.png` for each map. Set `head.src` to this path for the current map. If the image does not load, use `assets/steve.png`. The panel and the markers then show the same head, and the page sends no requests to mc-heads.net.

## Changes on the running VM

Do the steps in this sequence.

1. Look at https://mc.ola-vassbotn.no or run `sudo mc list`. Wait until no player is online. If players are online, ask Ola first.
2. Stop the services: `sudo systemctl stop minecraft bluemap`.
3. Make a snapshot. `mc-backup` skips the snapshot when no player was online after the last one, so use rsync directly. The pruning in `mc-backup` only removes folders that start with `2`, so it keeps this snapshot.

   ```sh
   sudo rsync -a --link-dest=/var/backups/minecraft/latest /opt/minecraft/world/ /var/backups/minecraft/pre-fabric/
   ```

4. Download the launcher and the mods. Check each hash. Use the same commands as in `runcmd`.
5. Write the config files, `status.js` and `status.css` from `cloud-init.yaml` with `sudo install -D -o minecraft -g minecraft -m 644 /dev/stdin <path>`.
6. Update `/etc/systemd/system/minecraft.service` and `/usr/local/bin/bluemap-start-pos`.
7. Remove the CLI service:

   ```sh
   sudo systemctl disable bluemap
   sudo rm /etc/systemd/system/bluemap.service
   sudo systemctl daemon-reload
   ```

8. Fix the web root. Some files belong to uid 501 from a copy from macOS. The mod must write to this folder.

   ```sh
   sudo find /opt/bluemap/web -name '._*' -delete
   sudo chown -R minecraft:minecraft /opt/bluemap/web
   ```

9. Start the server: `sudo systemctl start minecraft`. Read `sudo journalctl -u minecraft -f`.
10. Do the checks below.
11. Remove the old CLI files: `sudo rm -r /opt/bluemap/bluemap-cli.jar /opt/bluemap/config`.
12. Remove `/var/backups/minecraft/pre-fabric` after Ola confirms that the game works.

## Checks

- The journal shows Fabric Loader 0.19.5 with `fabric-api`, `essential_commands`, `lithium` and `bluemap`.
- `/opt/minecraft/.fabric/server/` has no `26.3-server.jar`. This shows that the launcher uses the pinned `server.jar`.
- `sudo mc "help tpa"` shows the command. `sudo mc "help back"`, `help home`, `help warp` and `help spawn` show an error.
- Compare `/opt/minecraft/config/EssentialCommands.properties` with this plan. Essential Commands writes all keys to the file at the first start. If you see a new `enable_*` key, set it to `false`, except `enable_tpa`.
- `curl -s http://127.0.0.1:8100/settings.json` returns the BlueMap settings.
- https://mc.ola-vassbotn.no shows the old tiles immediately. The panel, the map buttons, the settings and the zoom toward the cursor work. The lowres walls stay cut.
- `curl -s https://mc.ola-vassbotn.no/maps/overworld/live/players.json` returns JSON with a `players` list.
- With a player online, check these items in a browser at desktop width and at phone width:
  - The marker shows on the correct map with the new style.
  - A click on the row follows the player, and the row is active.
  - A drag on the map stops the follow. Less than one second later, the row is not active.
  - A click on a player in a different dimension switches the map.
  - The panel shows the same head as the marker.
- The journal shows no full render of all maps.
- `sudo systemctl start mc-backup` ends without an error.
- Ask Ola to test in the game with a player that is not an operator: `/tpa`, `/tpaccept` and `/tpdeny`. Check that `/back` is an unknown command.

## Rollback

1. Stop `minecraft`.
2. Set `ExecStart` back to `-jar server.jar nogui`. Remove the `ExecStartPre` line.
3. Put back `bluemap.service`, `/opt/bluemap/bluemap-cli.jar`, `/opt/bluemap/config` and the old glob in `bluemap-start-pos`.
4. Start `minecraft` and `bluemap`.

The mods add no blocks or items, so the vanilla server loads the world.

## Optional phase: 3D player model

Do this phase only after the main change works. Do it in a separate pull request.

### Goal of the phase

- When the camera is near a player, the map shows a 3D Minecraft player model with the skin of the player. The model replaces the head icon. The name tag stays.
- The body turns with `yaw`. The head tilts with `pitch`.
- The arms and legs swing when the player moves. The swing is an estimate from the speed. It does not show what the player does.
- When the camera is far away, the map shows the head icon again.

### Facts

- BlueMap sends only `position` and `rotation` (`pitch`, `yaw`, `roll`) for each player, once each second. The interval is fixed in `MapRequestHandler.java`. `PlayerMarker` moves to each new position over one second, and it also animates `marker.data.rotation`.
- `window.BlueMap.Three` is the three.js module (0.186) of BlueMap. Use it. Do not load a second copy of three.js.
- Each player marker is an `Object3D` at the feet of the player plus 1.8 blocks. Get the markers from `bluemap.mapViewer.markers.markerSets.get("bm-players")?.markers.values()`. When the player is in a different dimension, BlueMap sets `marker.visible = false`. This also hides the children of the marker.
- `MapViewer` draws the markers after the terrain, with the depth buffer of the terrain. Terrain hides a mesh that is behind it. The marker scene has no lights, so use `MeshBasicMaterial`.
- When the camera does not move, `MapViewer` draws only 20 frames each second. `bluemap.mapViewer.redraw()` gives the full frame rate for one second.
- The Mojang profile API (`sessionserver.mojang.com`) sends no CORS headers, so the browser cannot read it. The server must get the skins.

### Skins on the server

Add `/usr/local/bin/mc-skins` to `write_files` in `cloud-init.yaml`. The script uses only the Python standard library. It does these steps:

1. Read `/opt/bluemap/web/status.json`. Stop without an error if the file is empty or the server is offline.
2. For each player in `players.sample`, skip the player if `/opt/bluemap/web/skins/<id>.png` is less than one day old.
3. Get `https://sessionserver.mojang.com/session/minecraft/profile/<id without dashes>`. Decode `properties[0].value` from base64. Read `textures.SKIN.url` and `textures.SKIN.metadata.model`. The model is `slim` or missing (classic).
4. Download the skin to `/opt/bluemap/web/skins/<id>.png`. Change `http:` to `https:` in the URL.
5. Write the model of each player to `/opt/bluemap/web/skins/models.json` as `{"<id>": "slim" | "classic"}`.
6. If a request fails, skip the player. Try again in the next run.

Run the script from the `mcstatus` loop:

```ini
ExecStart=/bin/sh -c 'while :; do python3 -I /usr/local/bin/ping.py localhost 25565 > /opt/bluemap/web/status.json; python3 -I /usr/local/bin/mc-skins; sleep 10; done'
```

### Model in `status.js`

Build the model from boxes. The units are skin pixels. Set the scale of the model group to `0.9375 / 16`, as Minecraft does, so the model is 1.875 blocks tall. Add the group to the marker at `y = -1.8`, so the feet are on the ground. The front of the model faces `+Z`, so the right side of the player is `-X`. With `yaw = 0`, the player looks south (`+Z`).

| Part | Size (w × h × d) | Base UV | Overlay UV | Overlay inflate | Center (x, y) | Pivot y |
|---|---|---|---|---|---|---|
| Head | 8 × 8 × 8 | 0, 0 | 32, 0 | 0.5 | 0, 28 | 24 |
| Body | 8 × 12 × 4 | 16, 16 | 16, 32 | 0.25 | 0, 18 | none |
| Right arm | 4 × 12 × 4 | 40, 16 | 40, 32 | 0.25 | -6, 18 | 22 |
| Left arm | 4 × 12 × 4 | 32, 48 | 48, 48 | 0.25 | 6, 18 | 22 |
| Right leg | 4 × 12 × 4 | 0, 16 | 0, 32 | 0.25 | -2, 6 | 12 |
| Left leg | 4 × 12 × 4 | 16, 48 | 0, 48 | 0.25 | 2, 6 | 12 |

- For a `slim` model, the arms are 3 pixels wide, and the arm centers are at `x = ±5.5`.
- Put each head, arm and leg in a group at its pivot, so it turns around the neck, the shoulder or the hip.
- The overlay box is larger than the base box by the inflate value on each side.
- A part with UV origin `(u, v)` and size `w × h × d` uses these skin areas. Map each face of `BoxGeometry` to its area. The face order of `BoxGeometry` is `+X, -X, +Y, -Y, +Z, -Z`.

  | `BoxGeometry` face | Skin area | Origin | Size |
  |---|---|---|---|
  | `+X` | left side | `u + d + w, v + d` | d × h |
  | `-X` | right side | `u, v + d` | d × h |
  | `+Y` | top | `u + d, v` | w × d |
  | `-Y` | bottom | `u + d + w, v` | w × d |
  | `+Z` | front | `u + d, v + d` | w × h |
  | `-Z` | back | `u + 2d + w, v + d` | w × h |

- Load the skin with `Three.TextureLoader`. Set `magFilter` and `minFilter` to `NearestFilter`, `generateMipmaps` to `false` and `colorSpace` to `SRGBColorSpace`. Use `alphaTest: 0.5`. Use `side: DoubleSide` for the overlay.
- Some old skins are 64 × 32 pixels. For these skins, use the right arm and right leg areas for the left arm and left leg too, and draw no overlay except on the head.
- Load the skin texture once for each player, and keep it when the map changes. BlueMap makes new markers when the map changes.
- If a player has no skin file, keep the head icon.

### Animation in `status.js`

Run a `requestAnimationFrame` loop. On each frame, for each player marker:

1. If the marker has no model and the skin is loaded, build the model and add it to the marker.
2. Set the model `rotation.y` to `-yaw` and the head `rotation.x` to `pitch`, in radians, from `marker.data.rotation`.
3. Measure the horizontal speed from the change of `marker.position` since the last frame. Smooth the speed, because `PlayerMarker` eases each move.
4. Advance a walk phase with the speed. Turn the legs by `sin(phase) * amplitude` and the arms by the opposite angle. Set the amplitude to approximately 0.6 radians at walking speed (4.3 blocks each second). Make it smaller at lower speed and 0 when the player stands still. Tune it in the browser.
5. If the distance from `bluemap.mapViewer.camera.position` to the marker is less than 100 blocks, show the model and add the class `mc-model` to `marker.element`. Otherwise, hide the model and remove the class. Tune the distance in the browser.
6. If a model is visible, call `bluemap.mapViewer.redraw()`.

In `status.css`, hide `.bm-marker-player.mc-model img`.

### Changes on the running VM for the phase

1. Install `/usr/local/bin/mc-skins`, and make `/opt/bluemap/web/skins` for the `minecraft` user.
2. Update `/etc/systemd/system/mcstatus.service`. Run `sudo systemctl daemon-reload` and `sudo systemctl restart mcstatus`.
3. Install the new `status.js` and `status.css` in `/opt/bluemap/web`.

### Checks for the phase

- `/opt/bluemap/web/skins/` has a PNG for each online player, and `models.json` has each player.
- The browser sends no requests to Mojang or mc-heads.net. Look at the network tab.
- With a player online, check these items in a browser at desktop width and at phone width:
  - Zoom in on the player. The head icon changes to the model. The name tag stays above the head.
  - The face points where the player looks. The head tilts up and down.
  - The arms and legs swing when the player walks. They stop when the player stands still.
  - Terrain hides the model when the model is behind a hill or a wall.
  - A player with a `slim` skin has 3-pixel arms.
  - Zoom out. The model changes back to the head icon.
  - The map stays smooth on a phone.

## Finish

- Update `AGENTS.md`:
  - The server runs Fabric with Fabric API, Essential Commands (`/tpa` only), Lithium and BlueMap.
  - The BlueMap mod replaces the CLI and the `bluemap` unit.
  - Add only server-side mods. Players use the vanilla client.
- Make one pull request with the changes to `cloud-init.yaml` and `AGENTS.md`. Include the new `.papercuts/` reports.
- After the main change, ask Ola if you must do the optional phase now.
  - If yes, do the phase in a second pull request. Add `mc-skins` to the `cloud-init.yaml` line in `AGENTS.md`. Delete this file in that pull request.
  - If no, remove all sections of this file except "Optional phase: 3D player model" in the first pull request.
