# +1 Cannon Evolution: setup

Everything lives in `src/`. I install it straight into your open Studio place when your PC is on, so you don't need Rojo. `default.project.json` is there if you ever want it.

## Where each file goes

| File | In Studio |
|---|---|
| `src/shared/GameConfig.lua` | ReplicatedStorage > **GameConfig** (ModuleScript) |
| `src/shared/Icons.lua` | ReplicatedStorage > **Icons** (ModuleScript) |
| `src/server/GameServer.server.lua` | ServerScriptService > **GameServer** (Script) |
| `src/client/GameClient/init.client.lua` | StarterPlayerScripts > **GameClient** (LocalScript) |
| `src/client/GameClient/*.lua` (all others) | ModuleScripts **inside** GameClient, same names (Kit, Sfx, State, Popups, HUD, Effects, Shop, Cannons, Pets, PetFollow, Rebirth, Worlds, Upgrades, Missions, Rewards, Leaderboard, Settings) |
| `src/tools/BuildCannonMap.lua` | **New map (Oct 30).** Command Bar, once, right after Import 3D of `map/CannonMap.glb` (the light version of Alex's map: 187 pieces). Puts the import at the right size (2x the file since Oct 31: Alex found 1.3x still too miniature; launches stretch with it, see `Config.Map.Stretch`) and spot, sets collisions, gives the river the Stone Skipping water, moves a palm and the crate pile out of the booths' way, adds invisible edge walls round the island and dock, and stores the old map in ServerStorage.OldMaps. Then run BuildWorld1, BuildCannonBallStand, BuildLobbyExtras and BuildRebirthSigns again: they see the new map. Layout check: `python3 tools/map/plan_check.py map/CannonMap.glb out.jpg` (picture: `previews/new-map-plan.jpg`) |
| `src/tools/PlaceMapPatch.lua` | **Fills the map's holes (Oct 30).** Two volcano pieces of the first `CannonMap.glb` were over Roblox's 2048-stud limit, and two Aurora Peaks and two Igloo Camp pieces go over it once the map is built 2x bigger, so they get squashed. Import 3D `map/MapPatch.glb` (made by `tools/map/make_patch.py`), then run this in the Command Bar: it puts the 22 new pieces where the old ones belong and removes the squashed ones. `pack_map.py` now cuts long pieces itself, so a fresh pack doesn't need it. |
| `src/tools/BuildLobbyWalkways.lua` | **Pirate plank paths (Oct 31).** Command Bar, after BuildCannonMap and before BuildLobbyExtras. Keeps the map's own wooden paths (puts them back if an older run shelved them) and adds plank paths in the same style: a boardwalk along the booth fronts with three links, the west path past the eggs, and a link to the cannonball stand. Spots in `tools/map/lobby_plan.json`. |
| `src/tools/BuildEggPits.lua` | **Dug egg pits (Oct 31).** Command Bar, after BuildLobbyExtras. Reads the eggs where they stand (Alex's own spots), sinks each 0.8 studs and builds a dug pit round it: dirt banks with a studded grass rim sloping to the lawn, soil, loose earth and clods; close pits share one bank. In the middle of the half circle, a wider gold-rimmed spot with a soft light and a COMING SOON board for a Robux egg (nothing sold there yet). Kept in `workspace.EggPits`, apart from EggStands, so the banks never open an egg. Picture: `previews/egg-pits.jpg` |
| `src/tools/BuildLobbyDressing.lua` | **Pirate dressing (Oct 31).** Command Bar, after BuildLobbyExtras. Groups of the map's own crates and barrels, two more of its palms, ship's lanterns along the paths (all glow) and a TRAINING / LAUNCH / EGGS signpost by the spawn. Since Oct 31 (evening, vault notes 18-20) the lobby's hero is a 20-stud LAUNCH! arch over the dock path (fire bowls, gold bands, glowing strips, a big red sign), with festival flag strings on glowing poles along the path and bush-and-flower clumps at the plaza edges. |
| `src/tools/BuildLobbyExtras.lua` | Command Bar, once. Builds the 4 egg stands and the see-through area borders along the track (the client hides the borders except in flight). Since Oct 31 (evening) the eggs stand on the grass beside the dock path, between the spawn plaza and the cannonball stand: Starter at (-86, 22), then every 12 studs west; the free Robux spot is after the last egg (`eggSpot(#EGGS + 1)`). Every other egg label sits higher so they don't overlap from the spawn. |
| `src/tools/BuildRebirthSigns.lua` | Command Bar, after BuildWorld1. One label over the far end of each training lane, the same size and height on every lane, like Stone Skipping's: a dark pill with the rebirths needed (the Robux price in gold for the gamepass lane, which says GAMEPASS in gold instead of LOCKED, 1.3x bigger), then UNLOCKED in green or LOCKED in red (set for each player by Effects.lua), then the power, big ("5x POWER") (Oct 31, already run) |
| `src/tools/BuildCannonBallStand.lua` | Command Bar, once. The 2-tier cannonball pedestal on the right wall of the lobby, built part for part from `models/GunStand_2Tiers.glb` (already run) |
| `src/tools/BuildWorld1.lua` | Paste into the Command Bar once. It builds the training lanes, the Launch Zone by the Grand Cannon, the launch point and the spawn. The lanes follow Stone Skipping's rules (Oct 31): one lane model cloned for every tier, side by side on a stone stud platform, facing the plaza. Each lane is a long, low pool of light water (with lily pads) inside a brick rim in the tier colour. It has a raised tiled start pad with white corner marks, the cannon sitting low on the pad and a bullseye raft floating at the far end. Tiers 1–2 are plain, then glow, then shine and sparkles, with lanterns on the top tiers, and the gamepass lane (Dragon Cannon, 40x; no VIP wording anywhere, Alex Oct 31) is the fanciest: raised on a gold base with steps, a rainbow brick rim, a gold turntable, a soft gold light pillar, gold sparkles and lanterns. Every cannon sits on a display turntable. It also builds the TrainingShop board by lane 1 ("2x POWER ONLY R$399", tap to buy through the server's `purchase`). Then run BuildRebirthSigns for the labels and BuildCartoonyMap for the studs. Rules: `Build Playbooks/Lesson - Tiered Training Lanes.md` |
| `src/tools/BuildLighting.lua` | Command Bar, once. Bright cartoony lighting for the island (Alex, Oct 31: remove the shadows): a high sun, no cast shadows, a bright warm ambient, a light haze and a little bloom on neon (already run) |

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

Walk up to an egg stand and the egg menu opens on that egg; walk away and it closes. The new lobby's egg row sits beside the dock path, near the spawn and the cannonball stand, and keeps a free spot after the last egg for a Robux pet or egg (`eggSpot(#EGGS + 1)` in BuildLobbyExtras). Less walking (Oct 31): the Grand Cannon and Launch Zone sit 40 studs up the dock (`Config.Map.DockEnd`) and players walk at 20 (`Config.BASE_WALK_SPEED`, plus Speed upgrades).

Hatching: x1 always; x3 with the **Triple Open** pass and x8 with the **8x Open** pass (8x Open also unlocks x3). Both ids go in `Config.Passes`. The hatch popup is `Popups.Hatch`: three knocks with cracks, a glow that only turns blue/purple/gold if the pet inside really is that rare, the burst, pets popping out one by one, and a banner + confetti for Legendary and up. Tap to skip once the pets are out.

## Pets following you

`GameClient/PetFollow.lua`. Walking pets stay on the ground and hop along, rocking left and right in step with you; flying pets hover behind and bank into turns. Which pets fly is the `FLYING` list at the top; bunny and frog `hop` higher and penguin, chick, crab and turtle `waddle` (the `GAIT` list).

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

## Pet and egg pictures

Alex's drawn pictures (`design/egg_pet_ui_aligned.zip`) are in `icons/pets/<pet key>.png` and `icons/eggs/<egg id>.png`. Upload them and paste the ids into `Icons.lua` (`Pet_dog`, `Egg_Starter`, ...); the egg menu, hatch screen, reward popup and Pets inventory then show the picture instead of the 3D model. Matched by look; the less obvious ones: phoenix = red winged pet, void cube = purple crystal crown, shadow cube = dark purple cat, galaxy cube = purple ringed space cube, cosmo cube = blue ringed cube, golden wing = gold winged cube, royal cube = gold crown, corgi = orange and white pet, Woodland egg = green spotted, Nature egg = plant egg, Hacker egg = dark space egg, Secret egg = angel egg. Unused from the pack: octopus, jellyfish, cow, pig, wooden box, gold horned pet, lava egg, green scaly egg.
