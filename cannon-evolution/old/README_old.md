# +1 Cannon Evolution – World 1 training stations

## Where each file goes in Studio
| File | Type | Location |
|---|---|---|
| GameConfig.lua | ModuleScript | ReplicatedStorage › GameConfig |
| GameServer.server.lua | Script | ServerScriptService › GameServer |
| GameClient.client.lua | LocalScript | StarterPlayer › StarterPlayerScripts › GameClient |
| BuildWorld1.lua | Run once in the Command Bar | (builds stations, LaunchPoint, moves spawn) |

Claude installs these directly when Studio is connected.

## The only manual step: import the 6 cannons
Studio can't receive meshes from Claude, so import these from your pack
(`exports/CannonCollection_GLB/1_Collection/`) with **File › Import 3D**:

1. Cannon01_Starter.glb
2. Cannon02_Iron.glb
3. Cannon03_Steel.glb
4. Cannon04_Heavy.glb
5. Cannon06_Industrial.glb
6. Cannon05_Golden.glb
7. Cannon19_Dragon.glb (gamepass station)

Leave the names as they are. Claude moves them into ServerStorage › TrainingCannons and builds the stations.

## How it plays
- Walk onto a station pad → you're locked in front of the cannon, it fires at the target every 0.8s, each hit gives Strength.
- Jump (or press Leave) to step off.
- Stations unlock with Rebirths: 0 / 2 / 4 / 6 / 8 / 10, giving +1 / +3 / +8 / +20 / +50 / +125 per shot.
- Dragon Cannon is the gamepass station (+40 per shot, usable from the start). Put your gamepass id in GameConfig (`GamePass = ...`); touching it prompts the purchase.
- Rebirth (button bottom-left, tap twice): resets Strength, +50% Strength per shot forever. Cost 250, then doubles each time.
- At the Grand Cannon, press E (LAUNCH!) → the more Strength, the further you fly along the map. Distance gives coins and a Best record.
- All numbers are in GameConfig.
