# Merge Dominion

Merge Dominion is an original Roblox PvE conquest MVP. Players recruit Level 1 soldiers, merge matching soldiers into Levels 2 and 3, and attack three progressively stronger enemy bases. The main base is always safe.

## Project structure

- `default.project.json` — Rojo project mapping.
- `src/ReplicatedStorage/Shared/GameConfig.lua` — balance, soldier stats, and enemy base definitions.
- `src/ReplicatedStorage/Shared/StateSchema.lua` — progression defaults and save-data sanitization.
- `src/ServerScriptService/Services/DataService.lua` — DataStore load/save lifecycle.
- `src/ServerScriptService/Services/CombatService.lua` — deterministic power comparison combat.
- `src/ServerScriptService/Services/WorldBuilder.lua` — runtime-generated arena, safe main base, and enemy bases.
- `src/ServerScriptService/Server.server.lua` — remotes, player actions, recruitment, merging, rewards, and passive income.
- `src/StarterPlayer/StarterPlayerScripts/Client.client.lua` — generated HUD and interaction controls.

## Open in Roblox Studio

1. Install the Rojo Studio plugin and the Rojo CLI.
2. From this repository, run `rojo serve`.
3. In Roblox Studio, connect the Rojo plugin to the served project and sync it.
4. Publish the place under your Roblox account before testing persistence. In **Game Settings → Security**, enable **Enable Studio Access to API Services** for DataStore testing.
5. Press Play. The server creates the entire arena and the client creates the HUD; no manual map or UI construction is required.

## MVP behavior

- Recruit costs 25 coins; players also receive 15 passive coins every 20 seconds.
- Two matching soldiers merge automatically into the next level, through Level 3.
- Combat compares total player attack to the target's fixed defender attack; ties win and outcomes are shown in the HUD.
- Victories mark the enemy base conquered and award its configured reward.
- Currency, soldier counts, and conquered base IDs are saved in `MergeDominion_MVP_v1`.

## Known testing notes

- DataStore persistence requires a published experience and Studio API Services enabled; otherwise the game falls back to a fresh in-memory session and logs the save/load warning.
- This repository does not include a binary `.rbxlx` place file; the Rojo project is the source of truth and generates all runtime Instances. Roblox Studio testing requires the Rojo plugin/CLI connection.
- The MVP intentionally omits PvP, trading, pets, complex animations, monetization, and large-scale troop simulation.
