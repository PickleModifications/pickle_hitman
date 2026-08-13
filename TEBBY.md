# TEBBY.md - pickle_hitman

## Overview

`pickle_hitman` is a FiveM (GTA V multiplayer) resource that implements a full hitman/contract-killing system for roleplay servers. Players can place monetary bounties on other players (or auto-generated NPC targets) by interacting with in-world phone boxes. A hitman accepts the contract, tracks the target using a map blip, uses a facial-recognition camera to confirm identity, kills the target, then buries/disposes of the body at a designated burial site to collect the reward. The system supports ESX and QBCore frameworks through a bridge layer, and optionally integrates with a target/interaction system (ox_target, qb-target, qtarget) and a `pickle_xp` XP resource.

---

## Code Design

### Architecture

The resource follows the standard FiveM shared/client/server split enforced by `fxmanifest.lua`:

- **Shared scripts** – `config.lua`, locale files, and `core/shared.lua` (utility math/formatting functions). Loaded by both client and server.
- **Client scripts** – `core/client.lua` (interaction engine, NPC/prop spawning helpers, blip creation), `modules/main/client.lua` (app display, NUI callbacks, player init), `modules/hits/client.lua` (hit state machine, NPC scenario logic, body carry/vehicle interactions), `modules/camera/client.lua` (custom scoped camera for facial-recognition photo). All bridge clients are also loaded.
- **Server scripts** – `modules/main/server.lua` (player init, MySQL table creation, hit registry hydration from DB on start), `modules/hits/server.lua` (all authoritative hit logic: add/remove/accept/cancel/complete, NPC generation loop, player-drop cleanup). All bridge servers also loaded.
- **NUI** – A prebuilt React/Vite SPA in `nui/` (committed build artifacts; source is in `web/`). Communicates via `SendNUIMessage` / `RegisterNUICallback`.

### Main Data Flows

1. **Player join** → framework bridge fires `pickle_hitman:initializePlayer` → server sends current `HitRegistry`, identifier, and permissions to the client.
2. **Place hit** → NUI `addPlayerToHit` callback → `TriggerServerEvent("pickle_hitman:addPlayerToHit")` → server validates money/permissions, deducts money, calls `AddHitToRegistry` (broadcasts to all clients + SQL insert).
3. **Accept hit** → `pickle_hitman:acceptHit` server event → server validates cooldown/permissions, registers `HitmanPlayers[source]`, triggers `pickle_hitman:acceptHit` client event on hitman → client sets up `CurrentHit`, spawns blips, optionally spawns NPC ped.
4. **NPC hit tracking** → client creates the NPC ped locally, registers its net ID server-side via `pickle_hitman:setCurrentHitNPC` → server monitors health every 2 s; on death broadcasts `pickle_hitman:onTargetDeath`.
5. **Confirm kill** → client opens camera (`CameraLoop`), scans target, sets `CurrentHit.confirmedTarget = true` on facial match.
6. **Complete hit** → player carries body to burial site, presses E → `pickle_hitman:completeHit` event → server calls `CompleteHit`: adds money, sends webhook log, removes hit from registry and SQL.
7. **Discord webhooks** – `config_sv.lua` `ConfigSV.logFunction` sends embed POSTs for: `placeHit`, `acceptHit`, `removeHit`, `hitKilled`, `hitComplete`.

### Conventions

- **Framework bridging**: all framework-specific calls (money, notifications, callbacks, identifiers) are wrapped in named functions (`ShowNotification`, `AddMoney`, `GetIdentifier`, etc.) defined per-framework in `bridge/esx/` or `bridge/qb/`. Guard at top of each file: `if GetResourceState('...') ~= 'started' then return end`.
- **NPC hit targets**: identified in `HitRegistry` with `target` keys prefixed `"npc:"`. This prefix is checked in multiple places (e.g. `string.sub(target, 1, 4) == "npc:"`) to prevent players from removing NPC contracts.
- **Permission callbacks** in `config.lua` (`Config.HitPermissions.*`) are Lua functions called with `(source, hit, processing)`. The `processing` boolean distinguishes a dry-check (false) from an actual enforcement call (true) — only consume resources / send notifications when `processing == true`.
- **Locale lookup**: `_L(key, ...)` in `locales/locale.lua`; missing keys return `"ERR_TRANSLATE_<key>_404"`. Language table keyed by `Config.Language` string.
- **Interaction engine**: `core/client.lua` provides `CreateInteraction`, `UpdateInteraction`, `DeleteInteraction` — a generic system that routes through target exports when `Config.UseTarget = true`, or falls back to proximity keypress + `lib.showTextUI` otherwise.

---

## Important Files

| Path | Purpose |
|------|---------|
| `fxmanifest.lua` | Resource manifest — declares all script load order, NUI page, escrow_ignore list |
| `config.lua` | All customer-editable settings: debug, distances, phone-box models, burial sites, hit permission callbacks, NPC target config, blip settings |
| `config_sv.lua` | Server-only settings: Discord webhook URLs and log embed definitions per event type |
| `core/shared.lua` | Utility functions shared by client and server: `lerp`, `v3`, `GetRandomInt`, `dprint`, `NumberWithCommas` |
| `core/client.lua` | Client utility functions: vehicle/NPC/prop spawners, blip builder, interaction engine (`CreateInteraction`/`DeleteInteraction`), proximity text UI loop |
| `modules/main/client.lua` | NUI registration, player init event handler, `SetAppDisplay`, `UpdatePermissions`, phonebox target zone registration |
| `modules/main/server.lua` | `pickle_hitman:initializePlayer` event, MySQL table creation + data hydration on start, `onResourceStart` restart broadcast |
| `modules/hits/client.lua` | All client-side hit lifecycle: accept, NPC ped spawn, scenario AI (flee/attack), carry/vehicle body interactions, `OnHitDeath`, blip refresh handling |
| `modules/hits/server.lua` | Authoritative hit state: `HitRegistry`, `HitInfo`, `HitmanPlayers`, `AddHitToRegistry`, `RemoveHitFromRegistry`, `CompleteHit`, NPC generator loop, player-drop cleanup |
| `modules/camera/client.lua` | Custom scoped camera loop for facial-recognition confirmation; controls zoom/pan, detects target visibility, sets `confirmedTarget` flag |
| `locales/locale.lua` | `_L()` helper and `Language` table loader |
| `locales/translations/en.lua` | English locale strings (the only shipped translation) |
| `bridge/esx/client.lua` | ESX client-side bridge: notifications, server callbacks, group checks, inventory fallback |
| `bridge/esx/server.lua` | ESX server-side bridge: identifier, money, callbacks, inventory helpers |
| `bridge/qb/client.lua` | QBCore client-side bridge (same interface as ESX bridge) |
| `bridge/qb/server.lua` | QBCore server-side bridge (same interface as ESX bridge) |
| `bridge/custom/client.lua` | Stub for unsupported frameworks (prints warning, no-ops) |
| `bridge/target/ox_target/client.lua` | ox_target integration: AddTargetModel, AddTargetZone, AddTargetNetworkId, global vehicle/player targets |
| `bridge/target/qb-target/client.lua` | qb-target integration (same interface) |
| `bridge/target/qtarget/client.lua` | qtarget integration (same interface) |
| `bridge/xp/client.lua` | Optional pickle_xp integration for level/XP data; guarded by `Config.XPEnabled` |
| `nui/index.html` | Entry point for the committed NUI build |
| `nui/assets/` | Compiled JS/CSS bundle for the overlay UI |
| `web/` | React + Vite source tree for the NUI (not built in-repo; build output committed to `nui/`) |
| `__INSTALL/Items/` | SQL/Lua item registration snippets for ox_inventory, ESX, QBCore |

---

## Intended Behaviors

### `"npc:"` prefix on NPC target identifiers
NPC-generated hits use `target` keys prefixed with `"npc:"` (e.g. `"npc:482917"`). Code in `modules/hits/server.lua` (`RegisterNetEvent("pickle_hitman:removeHit")`) explicitly blocks removal of NPC hits with `string.sub(target, 1, 4) == "npc:"`. This is **intentional** — NPC hits can only be removed by the server's own cleanup logic (via `RemoveHitFromRegistry`), not by player cancel actions.

### Permission callbacks called twice with different `processing` flags
`Config.HitPermissions.placeHits / acceptHits / cancelHits` are each called with `processing = false` first (dry-check for UI state) and `processing = true` later (actual enforcement, item removal, notifications). The double-call pattern is **intentional**: it allows the same function to both query state and act on it. Do not treat the `false` call as a bug causing duplicate inventory operations.

### `challengecoin` item consumed on hit placement, returned on cancel
In the default `Config.HitPermissions` callbacks: placing a hit removes one `challengecoin` from the placer; canceling returns it. This is a built-in gating mechanic. The item removal inside the permission callback (when `processing == true`) is **intentional and by design**.

### Webhook URL sentinel value `"DISCORD_WEBHOOK_HERE"`
In `config_sv.lua`, if a webhook's `url` equals the literal string `"DISCORD_WEBHOOK_HERE"`, the `logFunction` skips the HTTP call and prints to console instead. This is **intentional silent-disable behavior**, not a missing nil-check.

### `no_permission_hit` locale used for multiple permission types
The locale key `no_permission_hit` is reused for `placeHits`, `acceptHits`, and `cancelHits` denials. This is intentional consolidation — there is no per-permission string.

### NPC hit generation at startup ignores sync
On server start, `GenerateNPCHit(true, ignoreSync)` (with `ignoreSync = true`) pre-populates `HitRegistry` without broadcasting to clients — clients receive the full registry during `initializePlayer`. The second argument `ignoreSync` is passed but the function signature only declares one parameter (`ignoreSync`); `ignoreSync` inside the body refers to the first parameter. **This is a known quirk** — the call `GenerateNPCHit(true, ignoreSync)` passes `true` as the first argument; `ignoreSync` at call-site is a global that is `nil` at that point (unused). The behavior is still correct: `ignoreSync = true` suppresses the TriggerClientEvent.

### Escrow / compiled modules
`fxmanifest.lua` has an `escrow_ignore` block that excludes `modules/**/*.*` and `core/*.*` when the comment `-- Comment below if source --` section is active. In a release build, those modules may be escrow-encrypted. The source tree currently has them unencrypted (development/open-source mode).

### XP bridge is a no-op unless `Config.XPEnabled` is true
`bridge/xp/client.lua` returns immediately if `Config.XPEnabled` is falsy. `Config.XPEnabled` is not present in the default `config.lua`, so this bridge is always dormant unless the server operator adds that key.

---

## Common Issues & Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Locale strings show as `ERR_TRANSLATE_<key>_404` | `Config.Language` does not match the key in `locales/translations/`. Only `"en"` is shipped. | Set `Config.Language = "en"` in `config.lua`, or add a matching translation file. |
| Resource fails to load / scripts missing | Folder is not named exactly `pickle_hitman`. The resource name is embedded in KVP keys (`pickle_hitman:position`), NUI URLs (`cfx-nui-pickle_hitman`), and event names. | Rename the resource folder to `pickle_hitman` exactly. |
| Phone-box interaction not appearing | `Config.UseTarget = true` but a supported target resource is not started, **or** `Config.UseTarget = false` but player is not within `Config.InteractDistance` | Confirm the target resource (ox_target / qb-target / qtarget) is started before `pickle_hitman`, or set `Config.UseTarget = false` for keypress mode. |
| `no_current_hit` notification on hit complete | The `pickle_hitman:completeHit` event is fired before the server's `HitmanPlayers` table registers the player (race condition on connect), or the hit was already cancelled server-side. | Ensure `pickle_hitman:initializePlayer` has fully round-tripped before triggering complete. |
| NPC target spawns but immediately despawns | `HitInfo[currentHitId]` is already set before `pickle_hitman:setCurrentHitNPC` fires (duplicate event), causing the server-side guard `if HitInfo[currentHitId] then return end` to block registration. | Only one player should accept a given NPC hit at a time; `maxNPCTargets` must be ≥ active hitmen. |
| Hit reward not paid out | `HitInfo[identifier].deceased` is never set to `true` — this happens if the entity health check loop (`Wait(2000)`) loses the entity before it reads `health <= 0`, or the player-kill event (`pickle_hitman:playerDied` client event) fires on a non-hit target. | Verify the NPC net ID is valid and the entity persists until death. Server-side health loop in `modules/hits/server.lua` is the primary detection path. |
| Discord webhooks not sending | URL left as `"DISCORD_WEBHOOK_HERE"` literal. | Replace all placeholder URLs in `config_sv.lua` with real Discord webhook URLs. |
| `challengecoin` not removed / returned | Inventory bridge not initialized (framework not detected). | Confirm ESX or QBCore is started before `pickle_hitman`; check console for the "not using a supported framework" print from `bridge/custom/`. |
| `GetMoney` / `AddMoney` errors on QBCore | Player object is nil (player not fully loaded when event fires). | Ensure `QBCore:Client:OnPlayerLoaded` event triggers `pickle_hitman:initializePlayer` — this is done in `bridge/qb/client.lua`; confirm QBCore is started first. |
| NUI overlay position resets | `GetResourceKvpString('pickle_hitman:position')` returns nil (KVP cleared or resource renamed). | The default position from `Config.DefaultPosition` is used as fallback — this is intended behavior, not a bug. |

---

## Conventions

- **Lua 5.4** (`lua54 'yes'` in manifest). Use `<const>`, `<close>`, integer division `//`, and bitwise operators freely.
- **Event naming**: `"pickle_hitman:<action>"` (all lowercase with underscores). Server events triggered from client use `TriggerServerEvent`; client events use `TriggerClientEvent`. Net events are registered with `RegisterNetEvent` then `AddEventHandler` (or the combined form for server-side).
- **Callback naming**: same `"pickle_hitman:<action>"` namespace; registered with `RegisterCallback` (bridge-provided) server-side, invoked with `ServerCallback` (bridge-provided) client-side.
- **NUI callbacks**: `RegisterNUICallback("<action>", function(data, cb) ... cb(result) end)` — always call `cb` to avoid NUI hangs.
- **Debug prints**: use `dprint(...)` (defined in `core/shared.lua`), never bare `print`. `dprint` is gated by `Config.Debug`.
- **Money formatting**: use `NumberWithCommas(value)` (returns `"$1,234"` format) for all player-facing reward strings.
- **Configuration changes**: user-editable settings belong in `config.lua` (client/shared) or `config_sv.lua` (server-only). Never hardcode server-specific values in module files.
- **Bridge functions**: all framework-specific calls must go through the bridge layer. Module files must never call `ESX.*` or `QBCore.*` directly.
- **`source` variable**: in `RegisterNetEvent` handlers on the server, `source` is the implicit global set by FiveM — capture it immediately as `local source = source` at the top of each handler (some handlers in `modules/hits/server.lua` do this; some rely on the global directly — follow the pattern of capturing locally for safety).
- **File structure**: new game feature modules go in `modules/<feature>/client.lua` and `modules/<feature>/server.lua`. The glob patterns `modules/**/client.lua` and `modules/**/server.lua` in the manifest pick them up automatically.
- **NUI source vs build**: the `web/` directory is the React source (TypeScript + Vite). The committed build output lives in `nui/`. **Do not build the NUI in CI/sandbox** — if UI source is changed, a GitHub Actions workflow should rebuild and commit `nui/` (none currently exists; one should be added if `web/` is modified).
