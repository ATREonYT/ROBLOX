# +1 Cannon Evolution: setup

Everything lives in `src/`. I install it straight into your open Studio place when your PC is on, so you don't need Rojo. `default.project.json` is there if you ever want it.

## Where each file goes

| File | In Studio |
|---|---|
| `src/shared/GameConfig.lua` | ReplicatedStorage > **GameConfig** (ModuleScript) |
| `src/shared/Icons.lua` | ReplicatedStorage > **Icons** (ModuleScript) |
| `src/server/GameServer.server.lua` | ServerScriptService > **GameServer** (Script) |
| `src/client/GameClient/init.client.lua` | StarterPlayerScripts > **GameClient** (LocalScript) |
| `src/client/GameClient/*.lua` (all others) | ModuleScripts **inside** GameClient, same names (Kit, Sfx, State, Popups, HUD, Effects, Shop, Cannons, Pets, Rebirth, Worlds, Upgrades, Missions, Rewards, Leaderboard, Settings) |
| `src/tools/BuildLobbyExtras.lua` | Command Bar, once. Builds the 4 egg stands by the Grand Cannon and the see-through area borders along the track (already run) |
| `src/tools/BuildRebirthSigns.lua` | Command Bar, once. Hangs a rebirth sign on the wall over each training area (rebirths needed, Power multiplier, locked/unlocked). Run it again after BuildWorld1, which brings back the old floating signs (already run) |
| `src/tools/BuildCannonBallStand.lua` | Command Bar, once. The 2-tier cannonball pedestal on the right wall of the lobby, built part for part from `models/GunStand_2Tiers.glb` (already run) |
| `src/tools/BuildWorld1.lua` | Paste into the Command Bar once. It builds the training stations, the Launch Zone by the Grand Cannon, the launch point and the spawn |

## Models the game looks for

- **ReplicatedStorage > Cannons**: your cannon models, named as in the pack (`Cannon01_Starter`, `Cannon02_Iron`, ..., `Cannon31_Hacker`). Import them with File > Import 3D. The stations and the Cannons panel use them. Until then the folder holds 25 part-built placeholder cannons (each has a `Placeholder` attribute); delete those when the real ones go in.
- **ReplicatedStorage > Pets**: pet models named by their key (`dog`, `cat`, `galaxy_cube`, ...).
- **ReplicatedStorage > Eggs**: egg models (`starter_egg`, `woodland_egg`, `nature_egg`, `ocean_egg`, `magic_egg`, `elemental_egg`, `celestial_egg`).

## Before publishing

1. **Gamepasses and products**: create them on the Creator Hub and paste the ids into `Config.Passes` and `Config.Products` in GameConfig. While an id is 0, purchases are free test buys in Studio and show "Soon" in the live game.
2. **Icons**: upload `icons/*.png` (Asset Manager > Bulk Import) and paste each `rbxassetid://` into Icons.lua. Until then the UI shows emoji fallbacks and the moving backgrounds use gradient stripes.
3. **Sounds**: the button sounds are in `assets/sfx/UI_*.ogg` (Kenney Interface Sounds, CC0; why each one: `tools/sfx/import_kenney.py`, listen: `previews/ui-sounds.ogg`). Upload them with Asset Manager > Bulk Import and paste each id into `Config.Sounds`. Until then Roblox's built-in sounds stand in, soft and low. Hatch already plays "Magic Burst 2" from Roblox's free licensed library.
4. Game Settings > Security: turn on **Studio Access to API Services** so saving works in Studio.

## How launching works

Like Stone Skipping: walk into the yellow **Launch Zone** in front of the Grand Cannon. The server works out the distance and cash from your Power, the Grand Cannon fires a cannonball that skims the water down the track, and your camera follows it low with a big metres counter, cash popping on every skip, and each area's name as the ball passes its see-through border. You step back out of the zone afterwards, so walking in again throws again. Keep **Workspace > StreamingEnabled** off (the map is small, about 900 parts) so the whole track is visible.

## Eggs

Walk up to an egg stand and the egg menu opens on that egg; walk away and it closes. There's room for the exclusive egg as a 5th stand: add its id to `EGGS` in BuildLobbyExtras.

## Codes

`RELEASE` (100 gems), `CANNON` (20 min of cash), `BOOM` (2x Power boost). Edit them in `Config.Codes`.

### Rebirth signs
The sign icon is `icons/RebirthSign.png`. Upload it as a Decal or Image, paste the id into `Icons.RebirthSign`, and every sign shows it. Until then they show 🔄.

## Tutorial
`GameClient/Tutorial.lua` runs the first-time guide: intro cutscene (guide waves, the
ball is chased through the worlds, the guide talks, camera glides over the pads),
then quest bar steps with a flowing arrow line: Train Power, Launch, Earn Cash,
Hatch an Egg, Rebirth Power/Cash, Rebirth Now, then TUTORIAL COMPLETE! and Daily Rewards.
- Every word it shows is in the `TEXT` table at the top.
- Set `REPLAY_IN_STUDIO = true` to watch it again on your own save in Studio.
- The guide character is built by GameServer into ReplicatedStorage.TutorialGuide.
