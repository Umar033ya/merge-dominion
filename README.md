# Merge Dominion

Merge Dominion is an original Roblox PvE conquest MVP. Players recruit Level 1 soldiers, merge matching soldiers into Levels 2 and 3, and attack three progressively stronger enemy bases. The main base is always safe.

## Project structure

- `default.project.json` — Rojo project mapping.
- `src/ReplicatedStorage/Shared/GameConfig.lua` — balance, soldier stats, and enemy base definitions.
- `src/ReplicatedStorage/Shared/StateSchema.lua` — progression defaults and save-data sanitization.
- `src/ServerScriptService/Services/DataService.lua` — DataStore load/save lifecycle with an in-memory Studio fallback.
- `src/ServerScriptService/Services/CombatService.lua` — deterministic power comparison combat.
- `src/ServerScriptService/Services/WorldBuilder.lua` — runtime-generated arena, polished safe main base, Soldier Yard, roads, decorations, and enemy bases.
- `src/ServerScriptService/Server.server.lua` — remotes, player actions, recruitment, merging, rewards, and passive income.
- `src/StarterPlayer/StarterPlayerScripts/Client.client.lua` — generated HUD and interaction controls.

## Open in Roblox Studio

1. Install the Rojo Studio plugin and the Rojo CLI.
2. From this repository, run `rojo serve default.project.json`.
3. In Roblox Studio, connect the Rojo plugin to the served project and sync it.
4. To produce a local place file instead, run `rojo build default.project.json -o MergeDominion.rbxlx`, then open the newly generated `MergeDominion.rbxlx` in Roblox Studio.
5. Press **Play**. The server creates the entire arena and the client creates the HUD; no manual map or UI construction is required. The generated place will not show the runtime-built arena while it is only in Edit mode.
6. In Play mode, the server Explorer should contain `Workspace > MergeDominionWorld`, including `ArenaGround`, `MainBase`, `SoldierYard`, `Checkpoints`, and the three enemy-base models.
7. Publish the place under your Roblox account before testing persistence. In **Game Settings → Security**, enable **Enable Studio Access to API Services** for DataStore testing.

## MVP behavior

- Recruit costs 25 coins; players also receive 15 passive coins every 20 seconds.
- Two matching soldiers merge automatically into the next level, through Level 3.
- Combat compares total player attack to the target's fixed defender attack; ties win and outcomes are shown in the HUD.
- Victories mark the enemy base conquered and award its configured reward.
- Currency, soldier counts, and conquered base IDs are saved in `MergeDominion_MVP_v1`.

## Phase 2 world foundation

- The permanent Main Base is a distinct blue house with a spawn point, entrance, flag, and safe label.
- The Soldier Yard sits directly in front of the Main Base; generated soldier models appear there.
- A compact road network connects the Main Base to the three enemy-base approaches.
- Enemy bases retain the same gameplay data but gain progressively stronger visual defenses: larger keeps, taller towers, and brighter beacons.
- Trees, rocks, ground accents, and road borders provide visual separation without creating a large map.
- A solid ground floor keeps buildings, roads, Soldier Yard objects, and decorations grounded.
- Physical checkpoint markers are placed near the Main Base and before Ember Outpost, Stonewatch, and Frostkeep. They are prepared for a future respawn system but do not change respawn behavior yet.

## Rojo build versus Play mode

`default.project.json` intentionally maps source scripts and modules into `ReplicatedStorage`, `ServerScriptService`, and `StarterPlayer`; it does not map a static `Workspace` model. `WorldBuilder.lua` is required by `Server.server.lua` and runs `WorldBuilder.build()` when the server starts. Therefore `rojo build` creates a place containing the code, while the visible map is created at runtime after pressing **Play**. There are no duplicate or legacy world generators in this repository.

## Studio DataStore behavior

- In an unpublished Studio place, the server automatically uses an in-memory progression state so the world, remotes, UI, and gameplay can run without DataStore access.
- If a published Studio session cannot access DataStore, the first failed operation switches the current server to the same in-memory fallback.
- Published Roblox games retain DataStore persistence when the service is available. To test persistence, publish the experience and enable **Game Settings → Security → Enable Studio Access to API Services**.

## Known testing notes

- DataStore persistence requires a published experience and Studio API Services enabled; otherwise the game falls back to a fresh in-memory session and logs the save/load warning.
- Static validation covers project mapping, required files, remote direction, state ownership, and Luau source review; actual Roblox API execution, Rojo synchronization, UI rendering, and DataStore behavior still require Roblox Studio.
- This repository does not include a binary `.rbxlx` place file; the Rojo project is the source of truth and generates all runtime Instances. Roblox Studio testing requires the Rojo plugin/CLI connection.
- The MVP intentionally omits PvP, trading, pets, complex animations, monetization, and large-scale troop simulation.
