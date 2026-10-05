# Merge Dominion

Merge Dominion is an original Roblox PvE conquest MVP. Players generate Level 1 soldiers, merge matching soldiers through Level 20, and physically travel from the Main Base or a stationed controlled city toward ten progressively stronger enemy cities. The Main Base is always safe.

## Project structure

- `default.project.json` — Rojo project mapping.
- `src/ReplicatedStorage/Shared/GameConfig.lua` — balance, Level 1–20 soldier stats, and enemy city definitions.
- `src/ReplicatedStorage/Shared/StateSchema.lua` — progression defaults and save-data sanitization.
- `src/ServerScriptService/Services/DataService.lua` — DataStore load/save lifecycle with an in-memory Studio fallback.
- `src/ServerScriptService/Services/CombatService.lua` — deterministic power comparison combat.
- `src/ServerScriptService/Services/WorldBuilder.lua` — runtime-generated large arena, safe Main Base, Soldier Yard, road network, checkpoints, decorations, ten enemy cities, and visible defender models.
- `src/ServerScriptService/Server.server.lua` — remotes, player actions, generated soldier characters, merging, rewards, and passive income.
- `src/StarterPlayer/StarterPlayerScripts/Client.client.lua` — generated HUD and interaction controls.

## Open in Roblox Studio

1. Install the Rojo Studio plugin and the Rojo CLI.
2. From this repository, run `rojo serve default.project.json`.
3. In Roblox Studio, connect the Rojo plugin to the served project and sync it.
4. To produce a local place file instead, run `rojo build default.project.json -o MergeDominion.rbxlx`, then open the newly generated `MergeDominion.rbxlx` in Roblox Studio.
5. Press **Play**. The server builds and validates the entire arena before it connects player initialization; the client creates the HUD. The generated place will not show the runtime-built arena while it is only in Edit mode.
6. In Play mode, the server Explorer should contain `Workspace > MergeDominionWorld`, including `ArenaGround`, `MainBase`, `SoldierYard`, `Checkpoints`, `PlayerSpawn`, and all ten city models. The `PlayerSpawn` is a collidable pad on the Main Base foundation, not a floating or non-collidable marker.
7. Publish the place under your Roblox account before testing persistence. In **Game Settings → Security**, enable **Enable Studio Access to API Services** for DataStore testing.

## MVP behavior

- Soldiers are generated automatically by the server; there is no manual recruit action.
- Two matching soldiers merge through Level 20; Level 20 cannot merge further. Merging is performed with the in-world soldier ProximityPrompts.
- Combat compares total player attack to the target's fixed defender attack; ties win and outcomes are shown in the HUD.
- Victories mark an enemy city conquered, award its configured reward, and unlock that city's passive income.
- Currency, Level 1–20 soldier counts, generation upgrades, and conquered city IDs are saved in `MergeDominion_MVP_v1`.

## Phase 2 world foundation

- The permanent Main Base is a distinct blue house with a spawn point, entrance, flag, and safe label.
- The Soldier Yard sits directly in front of the Main Base; generated soldier models appear there.
- A larger road network connects the Main Base to ten separated city territories across the map.
- Cities use progressively stronger visual defenses: multiple buildings, towers, city flags, signs, and themed colors.
- Trees, rocks, ground accents, and road borders provide visual separation without creating a large map.
- A solid ground floor keeps buildings, roads, Soldier Yard objects, and decorations grounded.
- Physical checkpoint markers are placed near the Main Base and before Ember Outpost, Stonewatch, and Frostkeep. They are prepared for a future respawn system but do not change respawn behavior yet.

## City conquest

- The world contains ten staged city zones: Ember Outpost, Stonewatch, Frostkeep, Sunspire, Nightfall Citadel, Ironvale, Moonharbor, Cindercrest, Verdant Reach, and Dragonspire.
- Each city is a distinct group of buildings with walls, gate, city sign, flag, configured defender composition, visible enemy soldier models, increasing difficulty, income, and a physical `E — Attack City` prompt.
- City victories are calculated by the server from the player's current Level 1–20 army and the configured defender army. A short server cooldown prevents attack spam.
- Pressing an attack prompt starts a server-controlled `Traveling` sequence. The existing player soldier models move together along the direct road route to the target city, then enter a short `Battling` presentation with highlighted/pulsing player and enemy models before the existing power calculation resolves.
- A defeat does not damage or conquer the permanent Main Base. It removes a temporary fraction of the player's soldiers, leaves surviving models stationed at the battle city, and reports the player/enemy power comparison.
- Conquered cities are stored in the existing `Conquered` state table and pay their configured income once per minute per player. The MENU shows each city's income and the total passive income per minute.
- A victory removes the visible enemy defenders, changes the city flag and gate to player colors, sets the city as a controlled base, and leaves the surviving player army stationed there instead of returning it to Main Base.
- The MENU reports the stationed soldier count, controlled-city income, and total passive income.

## Army travel and controlled-base network

- The existing soldier inventory remains the only authoritative army; no duplicate inventory or NPC system was added.
- Persisted state now includes `ArmyLocation` and `ArmyStatus`. Valid statuses are `Idle`, `Traveling`, `Battling`, and `Stationed`; legacy saves default safely to `MainBase` and `Idle`.
- New attacks launch from the current army location. After a victory, the next attack can begin from the newly conquered city. After a defeat, surviving soldiers remain at the battle location and the position is retained for the next session.
- Generation and merging remain server-authoritative. During travel/battle, visual resynchronization waits until the sequence completes so the marching army is not teleported back by a timer tick.

## Automatic soldier progression

- Soldiers are generated by the server automatically, beginning at one Level 1 soldier every 60 seconds.
- The default maximum is 20 total soldiers across Levels 1–20. At capacity, generation pauses and resumes after merging frees a slot.
- Conquering enemy cities awards configured coin rewards. Those coins can purchase generation-speed upgrades: 60s, 50s, 40s, 30s, 20s, 15s, then 10s.
- The HUD shows the server-reported countdown, current interval, capacity, next upgrade cost, and upgrade control. There is no manual recruit button.

## Soldier interaction and movement polish

- Soldiers use lightweight stylized Roblox characters built from grouped Parts with built-in `SpecialMesh` geometry for rounded heads, helmets, torso, limbs, boots, armor, and equipment. Levels 1–5 progress from recruit/vest/sword/archer to vanguard gear; Levels 6–12 add advanced armor, weapons, emblems, and elite equipment; Levels 13–16 add commander capes and crests; Levels 17–19 add legendary aura styling; Level 20 is the unique Hero with a crown and sparkles.
- Each level has a distinct role name, color treatment, equipment progression, and floating identity card.
- Walk to a soldier and use the `E` ProximityPrompt to select it, then select another soldier of the same level to merge. The server validates ownership, level, and inventory before changing state.
- A successful merge removes both source models, creates the higher-level character, and emits a short lightweight particle burst at the merge location.
- Hold **Left Shift** to sprint. The sprint action also exposes a touch button through Roblox `ContextActionService`; releasing it returns movement to normal speed.
- The side panel is hidden by default behind a small `MENU` button so the world stays visible. It still contains currency, generation status, capacity, speed upgrade, merge instructions, enemy cities, city income, and battle results.

## Rojo build versus Play mode

`default.project.json` intentionally maps source scripts and modules into `ReplicatedStorage`, `ServerScriptService`, and `StarterPlayer`; it does not map a static `Workspace` model. `Server.server.lua` loads and runs `WorldBuilder.build()` before loading persistence or connecting player initialization. The builder creates the ground first, then the Main Base/Soldier Yard, cities and prompts, checkpoints, and finally the grounded `PlayerSpawn`; it validates every required object and retries once with a traceback if construction fails. Therefore `rojo build` creates a place containing the code, while the visible map is created at runtime after pressing **Play**.

If the world still does not appear, open **View → Output** immediately after pressing Play. Startup failures now use the `[MergeDominion]` prefix and report the failed world-build attempt or missing required object instead of failing silently.

## Studio DataStore behavior

- In an unpublished Studio place, the server automatically uses an in-memory progression state so the world, remotes, UI, and gameplay can run without DataStore access.
- If a published Studio session cannot access DataStore, the first failed operation switches the current server to the same in-memory fallback.
- Published Roblox games retain DataStore persistence when the service is available. To test persistence, publish the experience and enable **Game Settings → Security → Enable Studio Access to API Services**.

## Known testing notes

- DataStore persistence requires a published experience and Studio API Services enabled; otherwise the game falls back to a fresh in-memory session and logs the save/load warning.
- Static validation covers project mapping, required files, remote direction, state ownership, and Luau source review; actual Roblox API execution, Rojo synchronization, UI rendering, and DataStore behavior still require Roblox Studio.
- This repository does not include a binary `.rbxlx` place file; the Rojo project is the source of truth and generates all runtime Instances. Roblox Studio testing requires the Rojo plugin/CLI connection.
- Studio testing should verify the ten city models and visible `Defenders` folders, watch the soldier folder travel from Main Base or the current stationed city, observe the battle sequence, and confirm victory/defeat leaves the army at the destination.
- The MVP intentionally omits PvP, trading, pets, complex animations, monetization, and large-scale troop simulation.
