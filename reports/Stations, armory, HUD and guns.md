# Stations, armory, HUD and guns (2026-10-06)

This pass recreates the aura-simulator design the user shared (training pads with heavy effects, a row of tools
on pedestals, and its HUD), translated to Hood: Aura → POWER, hammers → guns, MOG → EVOLVE. Four agents built
it in parallel; the lead fitted the pieces together. Nothing here has run in Studio yet: it was checked with
the offline harness, unit tests and renders.

## See it in Studio
1. Let Rojo sync, then rebuild the map from the Command Bar (the map changed):
   `require(game.ServerStorage.TheBlockV2).Build()`
2. Press Play. You spawn facing stage 1. The training stations are on your left, the ARMORY on your right
   and the EVOLVE booth behind you.

## What changed

| Piece | What it is | Where |
|---|---|---|
| **Training stations** | Every bag is now an aura station: a studded platform with a chevron deck and neon strips, a gantry with an "xN POWER" sign and three panels, and a low-poly boxing bag that sways while you train. Each tier adds an effect layer: dust and glow, mist, wisps, sparks, arcs, flames, god rays, gold glitter. The boss ring gets a rainbow champion aura. | `TheBlockV2.lua`, `Shared/HoodVFX.lua`, textures in `hood/art/vfx` |
| **Spawn plaza** | Wider. Three stations under a TRAIN HERE sign on the west side, the ARMORY on the east, and the EVOLVE booth at the back. Stages 6, 8, 10, 12 and 14 each have their station. | `TheBlockV2.lua` |
| **Armory** | Two rows of hexagon pedestals, five on each row. Each pedestal shows a gun that floats and spins, with its name, multiplier and price. Pink means locked, blue owned, green equipped. Walk up and hold the prompt to buy (Cash) or equip. The equipped gun hangs on your hip and multiplies every punch. | `GunService.server.lua`, `Armory.client.lua`, `Shared/GunRules.lua`, `Config/Guns.lua` |
| **HUD** | Laid out like the reference. Top left: Rebirth and Cash counters, a big SHOP button, and REBIRTH (with a % badge), REWARDS, PVP and EVOLVE buttons with 3D icons. Bottom centre: your headshot, Power and a LEVEL bar (your look). Top centre: the hint "Click / tap to train • xN Power • Evolve at …". Notices appear as toasts. Overhead tags show @username, look and Power. | `HUD.client.lua`, `UIKit.lua`, `Lobby.client.lua` |
| **Guns and icons** | 10 guns and 9 HUD icons made in Blender as low-poly, blocky, studded models. The same description is exported to Roblox parts, so the game shows exactly what was rendered. | `Shared/Models/GunModels.lua`, `IconModels.lua`, `hood/tools/blender/` |

## The gun ladder (Cash comes from first-time gate passes)

| Gun | Punch multiplier | Cash |
|---|---|---|
| Rusty Pistol | x1 | free |
| Snub Revolver | x2 | 20 |
| Street Uzi | x3 | 60 |
| Pump Shotgun | x4 | 200 |
| Tommy Gun | x6 | 600 |
| Block AK | x8 | 1,500 |
| Gold Deagle | x12 | 4,000 |
| Mini Gun | x16 | 10,000 |
| Neon Blaster | x24 | 18,000 |
| Diamond Cannon | x32 | 25,000 |

All of World 1's gates pay about 27K Cash in total, so the Diamond Cannon is an end-of-world goal. Prices and
multipliers are in `Config/Guns.lua`.

## Uploads that make it look its best
Everything works before anything is uploaded: effects fall back to Roblox's built-in textures, HUD icons show
as live 3D models, and guns are real parts. Uploading the images (Studio → Asset Manager → Bulk Import) and
pasting the ids makes effects softer and UI cheaper:

| Upload | Paste the ids into |
|---|---|
| `hood/art/vfx/*.png` (effect textures) | `HoodVFX.Textures` |
| `hood/art/icons3d/*.png` (HUD icons) | `IconModels.Images` |
| `hood/art/renders/guns/*.png` (gun cards) | `GunModels.Images` |

Or send the list of names and ids to Claude to paste them in. Optional: `hood/art/models/fbx/*.fbx` import as
MeshParts with Studio's 3D Importer (settings in `hood/tools/blender/README.md`); `hood/art/models/roblox/*.rbxmx`
can be dragged straight into Studio.

## Not built yet
SHOP passes and boosts, REBIRTH, REWARDS and PVP open their panels but say "coming soon": those systems come
later. The EVOLVE button works: it points the arrow at the booth.

## Skills and tools for next time
- `.claude/skills/roblox-vfx/`: how to build layered, tiered effects that stay cheap, with recipes and budgets.
- `.claude/skills/blender-roblox-models/`: how to model low-poly blocky props in Blender and get them into Roblox.
- `hood/tools/preview/`: the offline harness and renderer used to check all of this (README inside).

## Checked
- **Unit tests:** 61/61 pass (8 new gun tests).
- **Map:** the integration run finds all 9 training zones, 16 gates in order, 16 fight pads, 31 teleports,
  the EVOLVE point and the ring. A 1,000-Power player is stopped at gate 9. About 11,100 parts.
- **Guns and icons:** 2,516 model checks pass (pivot, sizes, part budget, muzzle direction), and the Roblox
  parts match the Blender renders side by side.
- **Gun buying:** 18 scripted server checks (buy, equip, too far, not enough Cash, bad ids, rate limit).
- **HUD:** scripted checks of every panel and button in the harness. No overlaps at 1920×1080, 1280×720 or
  on an 844×390 phone, including the PUNCH button.

## Worth a look in Studio
- The gun on your hip was only checked on a blocky test dummy, not a real R15 character.
- The gold (Foil) and diamond (glass) gun materials.
- How busy the top-tier station effects feel in play. The particle counts are budgeted (about 12 to 106 per
  station), but they haven't been timed on a phone.
