# Asset Pack Picks

These are picks from `LihFolk Vault V2 (imported)/LihFolk Asset Pack/`, made for [[Build List - LihFolk Upgrades]]. That folder is in `.gitignore`, so copy only what you use into the game.

**Script scan (2026-11-03):** 821 models are `.glb` files, which hold only meshes and textures and can't carry code. The 9 animation `.rbxmx` files contain only KeyframeSequence, Keyframe, Pose and marker items, with **no Script, LocalScript or ModuleScript**. Materials and skies are plain image files. Nothing in the pack runs code.

**Overall fit:** most of the pack is fantasy (swords, shields, cauldrons, banners, pine trees), so less than a quarter of it suits a Miami hood map. It has **no asphalt, palms, cars, AC units or street furniture**.

## Use these

| Need | Pick | Path | Owner |
|---|---|---|---|
| Golden-hour sky | `golden_hour_amber_003`, `golden_hour_peach_005` | `Skies/<id>/` | lighting |
| Night sky | `night_stars_navy_003`, `night_stars_indigo_004` | `Skies/<id>/` | lighting |
| Day sky (Miami blue) | `clear_day_cumulus_007`, `clear_day_azure_004` | `Skies/<id>/` | lighting |
| Brick walls (shops, alleys) | `brick_red_000`, `brick_brown_007`, `brick_white_004`, `brick_grey_003` | `Materials/brick/<id>/` | quality |
| Stucco-ish/stone walls | `stone_wall_sandstone_000`, `stone_wall_chalk_003` | `Materials/stone_wall/<id>/` | quality |
| Sidewalk/plaza | `cobble_grey_000`, `cobble_dark_004`, `tiles_terracotta_001` | `Materials/...` | quality |
| Shop/diner floors | `tiles_checker_002`, `tiles_cream_000` | `Materials/tiles/<id>/` | apartment/desk PC, quality |
| Lawns and hedges | `grass_lush_000`, `grass_dry_002`, `leaves_hedge_004` | `Materials/...` | quality |
| Roll-up doors, fences, rooftop sheet metal | `metal_plates_steel_000`, `metal_plates_painted_004`, `metal_plates_iron_001` | `Materials/metal_plates/<id>/` | quality |
| Pitched roofs (houses) | `roof_shingles_slate_000`, `roof_shingles_clay_001` | `Materials/roof_shingles/<id>/` | quality |
| Rooftop and alley clutter | `PipeRun_*`, `Valve_*`, `Crate_*`, `Barrel_*` | `Models/Kits/Props/` | quality |
| Trash and bottles on the street | `Bottle_*` | `Models/Kits/Props/` | quality |
| Fallback locomotion | `Walk`, `Run`, `Sprint`, `Idle` | `Animations/Locomotion/*.rbxmx` | animations |

Each material folder has `Color.png`, `Normal.png`, `Roughness.png` and `Metalness.png`. Load them into a `MaterialVariant` (see [[MaterialService and Custom Materials]]). Check `preview.jpg` first, and look at the contact sheets in `Materials/_sheets/` and `Skies/_sheets/`.

## Skip these
Weapons (swords, axes, shields), Emblems, Cauldron, Banner, Chest, the Arch/Pillar modular kit, lava, ice, gold, scifi panels, water caustics, the sword combat animations and the slash/ice VFX. `Dataset/` holds scored training attempts and is not meant for games.

## Still missing (make or source elsewhere)
- **Asphalt with markings and skid marks:** this is the top fix for the "flat black roads" problem. Make a MaterialVariant plus decals for crosswalks and lane lines.
- **Palm trees:** the pack has pine trees only.
- **Flat-roof kit:** AC units, vents, gravel/tar material, roof hatches and satellite dishes.
- **Street furniture:** hydrants, bus stops, street lamps, traffic lights and dumpsters.
