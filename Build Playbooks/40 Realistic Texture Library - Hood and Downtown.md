---
tags: [build-playbooks, realistic, textures, materials, materialvariant, cc0, hood, downtown]
updated: 2026-11-01
---

# 40 Realistic Texture Library - Hood and Downtown

Back to [[35 Realistic Materials, Decals and Wear]] · [[33 Realistic World Building Playbook]] · [[00 Build Router]]

**68 free, CC0 textures picked for a realistic RP city**, split into a worn **hood** look and a cleaner **downtown** look, plus shared roads, metal, roofs, ground and coast. Every one is CC0 (public domain, no credit needed, safe for a paid game) from **Poly Haven** or **ambientCG**. Write them in `<game>/art/LICENSES.md` anyway so we always know where a texture came from.

Files (all in `Build Playbooks/realistic-kit/textures/`):
- `texture-manifest.json`: every texture with source page, direct 1K map links, real-world size, StudsPerTile, base material and use. The single source of truth.
- `download_textures.sh`: run on the Mac (`sh download_textures.sh`); fetches every map into `downloaded/<VariantName>/ColorMap.png`, `NormalMap.png` (OpenGL), `RoughnessMap.png`, `MetalnessMap.png`.
- `BuildMaterialVariants.lua`: Command Bar script that adds the variants to `MaterialService/Realistic` from uploaded image IDs. It **only adds**: never changes existing variants and never turns on "Set as Override", so nothing already in a place changes look.

## How the picks were made
- **Real photo-scanned PBR** at 1K (Roblox shows 1024 well; bigger costs phones 4× memory per step, see [[38 Mesh Pipeline, LOD and Mobile Budgets]]).
- **OpenGL normals** (`nor_gl`), which is what Roblox expects.
- **Real size known**, so StudsPerTile = real metres ÷ 0.28 is exact. Roads and big walls may look better 1.2–1.5× larger in game (readable from a car); tune by eye next to a 5-stud avatar.
- **Hood = worn, cracked, stained, painted-over, rusty.** **Downtown = clean concrete, precast panels, red brick, stone, glass, marble, pavers.** Shared = roads, metal, roofs, ground.
- **Tintable where possible:** plasters and painted planks are greyish, so part `Color` gives pink, mint, blue and sand walls from one texture (the hood references use exactly that palette).
- **Kid-safe:** surfaces only. No texture contains graffiti, text, logos or imagery; graffiti stays our own art ([[35 Realistic Materials, Decals and Wear]] §5).

## The library

### Roads

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `HoodAsphaltCracked` | [asphalt_02](https://polyhaven.com/a/asphalt_02) (Poly Haven) | Asphalt | 3.0 m | 11 | Organic | Main hood streets: grey, cracked, tar lines |
| `HoodAsphaltFaded` | [asphalt_04](https://polyhaven.com/a/asphalt_04) (Poly Haven) | Asphalt | 4.04 m | 14 | Organic | Sun-bleached side streets and alleys |
| `HoodRoadPotholes` | [road_damaged](https://polyhaven.com/a/road_damaged) (Poly Haven) | Asphalt | 2.2 m | 8 | Organic | Worst blocks, alleys, vacant lots (use sparingly) |
| `AsphaltWorn` | [asphalt_03](https://polyhaven.com/a/asphalt_03) (Poly Haven) | Asphalt | 2.05 m | 7 | Organic | Everyday city road, parking lots |
| `DowntownAsphaltClean` | [asphalt_pit_lane](https://polyhaven.com/a/asphalt_pit_lane) (Poly Haven) | Asphalt | 2.0 m | 7 | Organic | New downtown avenues, highways, bridge deck |
| `AsphaltGranular` | [asphalt_07](https://polyhaven.com/a/asphalt_07) (Poly Haven) | Asphalt | 2.5 m | 9 | Organic | Coastal roads, shoulders |

### Sidewalks, plazas, lots

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `SidewalkConcrete` | [concrete_pavement](https://polyhaven.com/a/concrete_pavement) (Poly Haven) | Concrete | 1.8 m | 6 | Regular | Standard sidewalk slabs |
| `HoodSidewalkCracked` | [floor_pavement](https://polyhaven.com/a/floor_pavement) (Poly Haven) | Concrete | 2.0 m | 7 | Regular | Cracked hood sidewalks |
| `DowntownSidewalkTiles` | [concrete_pavement_03](https://polyhaven.com/a/concrete_pavement_03) (Poly Haven) | Concrete | 2.1 m | 8 | Regular | Downtown tiled sidewalks |
| `DowntownPavers` | [square_concrete_pavers](https://polyhaven.com/a/square_concrete_pavers) (Poly Haven) | Concrete | 1.8 m | 6 | Regular | Plazas, bank and hotel fronts |
| `SidewalkSlabs` | [concrete_tiles_02](https://polyhaven.com/a/concrete_tiles_02) (Poly Haven) | Concrete | 1.82 m | 7 | Regular | Alternate sidewalk slabs (mix with SidewalkConcrete) |
| `DowntownBrickPavers` | [herringbone_brick](https://polyhaven.com/a/herringbone_brick) (Poly Haven) | Brick | 1.8 m | 6 | Regular | Pedestrian streets, crosswalk inlays |
| `ConcreteDriveway` | [grooved_concrete_driveway](https://polyhaven.com/a/grooved_concrete_driveway) (Poly Haven) | Concrete | 1.8 m | 6 | Organic | Driveways, fire-station apron, ramps |
| `ParkingLotStained` | [garage_floor](https://polyhaven.com/a/garage_floor) (Poly Haven) | Concrete | 1.89 m | 7 | Organic | Garages, alleys, parking lots, gas station |
| `ConcreteStained` | [brushed_concrete_2](https://polyhaven.com/a/brushed_concrete_2) (Poly Haven) | Concrete | 2.5 m | 9 | Organic | Lots, flood channel floor, schoolyard |
| `LobbyMarble` | [floor_tiles_02](https://polyhaven.com/a/floor_tiles_02) (Poly Haven) | Marble | 4.0 m | 14 | Regular | Lobbies, bank floors, mall |
| `PlazaTiles` | [anti_skid_tiles](https://polyhaven.com/a/anti_skid_tiles) (Poly Haven) | CeramicTiles | 1.8 m | 6 | Regular | Outdoor plazas and steps |

### Hood walls

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `HoodStuccoWorn` | [painted_plaster_wall](https://polyhaven.com/a/painted_plaster_wall) (Poly Haven) | Plaster | 2.0 m | 7 | Organic | Main hood building walls (tint pink, mint, blue, sand) |
| `HoodPaintedConcrete` | [concrete_wall_004](https://polyhaven.com/a/concrete_wall_004) (Poly Haven) | Concrete | 2.0 m | 7 | Organic | Stained painted walls, liquor-store sides |
| `HoodConcreteDirty` | [concrete_wall_007](https://polyhaven.com/a/concrete_wall_007) (Poly Haven) | Concrete | 2.16 m | 8 | Organic | Grey dirty walls, flood channel sides, underpasses |
| `HoodStuccoCracked` | [cracked_concrete_wall](https://polyhaven.com/a/cracked_concrete_wall) (Poly Haven) | Plaster | 1.0 m | 4 | Organic | Old beige stucco with cracks |
| `HoodPlasterChipped` | [blue_plaster_wall](https://polyhaven.com/a/blue_plaster_wall) (Poly Haven) | Plaster | 2.0 m | 7 | Organic | Peeling paint walls (tint for any colour) |
| `HoodPlasterExposedBrick` | [damaged_plaster](https://polyhaven.com/a/damaged_plaster) (Poly Haven) | Plaster | 1.85 m | 7 | Organic | Hero walls: plaster falling off brick |
| `HoodPaintedBrick` | [painted_brick](https://polyhaven.com/a/painted_brick) (Poly Haven) | Brick | 1.8 m | 6 | Regular | Painted brick shops and corner stores |
| `HoodPaintedBrickYellow` | [painted_worn_brick](https://polyhaven.com/a/painted_worn_brick) (Poly Haven) | Brick | 1.8 m | 6 | Regular | Grungy painted brick, laundromat, barber |
| `HoodBrickDamaged` | [brick_wall_006](https://polyhaven.com/a/brick_wall_006) (Poly Haven) | Brick | 3.0 m | 11 | Regular | Old red brick apartments |
| `HoodCinderBlock` | [concrete_block_wall_03](https://polyhaven.com/a/concrete_block_wall_03) (Poly Haven) | Concrete | 1.81 m | 6 | Regular | Cinder-block walls, yard walls, garages |

### Downtown walls

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `StuccoSuburb` | [beige_wall_002](https://polyhaven.com/a/beige_wall_002) (Poly Haven) | Plaster | 3.0 m | 11 | Organic | Clean textured stucco for houses (tint) |
| `DowntownBrickRed` | [red_bricks_04](https://polyhaven.com/a/red_bricks_04) (Poly Haven) | Brick | 2.5 m | 9 | Regular | Clean red brick (fire station, offices) |
| `DowntownBrickOld` | [factory_brick](https://polyhaven.com/a/factory_brick) (Poly Haven) | Brick | 1.5 m | 5 | Regular | Old warehouses, lofts, train district |
| `DowntownPrecastPanel` | [concrete_slab_wall_02](https://polyhaven.com/a/concrete_slab_wall_02) (Poly Haven) | Concrete | 2.1 m | 8 | Regular | Office towers, parking garages |
| `DowntownConcreteFacade` | [concrete_tile_facade](https://polyhaven.com/a/concrete_tile_facade) (Poly Haven) | Concrete | 2.09 m | 7 | Regular | Modern grooved concrete facades |
| `DowntownRibbedConcrete` | [ribbed_concrete_wall](https://polyhaven.com/a/ribbed_concrete_wall) (Poly Haven) | Concrete | 2.0 m | 7 | Regular | Feature walls, stairwells, police station |
| `DowntownStoneBlocks` | [large_sandstone_blocks_01](https://polyhaven.com/a/large_sandstone_blocks_01) (Poly Haven) | Sandstone | 3.0 m | 11 | Regular | Bank, city hall, courthouse base |
| `DowntownRender` | [exterior_wall_cladding_03](https://polyhaven.com/a/exterior_wall_cladding_03) (Poly Haven) | Plaster | 1.96 m | 7 | Organic | Painted render on modern buildings |
| `BridgeConcretePanels` | [concrete_panels](https://polyhaven.com/a/concrete_panels) (Poly Haven) | Concrete | 8.0 m | 29 | Regular | Bridges, underpasses, retaining walls |

### Metal

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `ShutterRusty` | [rusty_metal_shutter](https://polyhaven.com/a/rusty_metal_shutter) (Poly Haven) | CorrodedMetal | 1.9 m | 7 | Regular | Roll-up shop shutters (hood) |
| `ShutterPainted` | [painted_metal_shutter](https://polyhaven.com/a/painted_metal_shutter) (Poly Haven) | Metal | 2.0 m | 7 | Regular | Roll-up shutters, garage doors |
| `CorrugatedWorn` | [worn_corrugated_iron](https://polyhaven.com/a/worn_corrugated_iron) (Poly Haven) | CorrodedMetal | 1.8 m | 6 | Regular | Fences, shacks, rooftop sheds |
| `CorrugatedRusty` | [rusty_corrugated_iron](https://polyhaven.com/a/rusty_corrugated_iron) (Poly Haven) | CorrodedMetal | 2.0 m | 7 | Regular | Rustier corrugated sheets |
| `ShippingContainer` | [container_side](https://polyhaven.com/a/container_side) (Poly Haven) | Metal | 1.94 m | 7 | Regular | Port containers (tint per container) |
| `MetalPaintedRusty` | [rusty_painted_metal](https://polyhaven.com/a/rusty_painted_metal) (Poly Haven) | CorrodedMetal | 2.2 m | 8 | Organic | Hydrants, dumpsters, poles, railings |
| `MetalPlate` | [metal_plate_02](https://polyhaven.com/a/metal_plate_02) (Poly Haven) | DiamondPlate | 2.0 m | 7 | Regular | Trucks, steps, ramps |
| `IndustrialWall` | [factory_wall](https://polyhaven.com/a/factory_wall) (Poly Haven) | Metal | 3.0 m | 11 | Regular | Warehouses, factories |
| `RoofBoxProfile` | [box_profile_metal_sheet](https://polyhaven.com/a/box_profile_metal_sheet) (Poly Haven) | Metal | 2.0 m | 7 | Regular | Warehouse and strip-mall roofs |

### Wood and roofs

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `WoodPaintedDistressed` | [distressed_painted_planks](https://polyhaven.com/a/distressed_painted_planks) (Poly Haven) | WoodPlanks | 1.6 m | 6 | Regular | Siding, porches, fences (tint) |
| `WoodPlanksOld` | [old_planks_02](https://polyhaven.com/a/old_planks_02) (Poly Haven) | WoodPlanks | 2.0 m | 7 | Regular | Boarded windows, old fences, pier deck |
| `RoofShinglesGrey` | [grey_roof_tiles](https://polyhaven.com/a/grey_roof_tiles) (Poly Haven) | RoofShingles | 3.0 m | 11 | Regular | Pitched house roofs (coastal look) |
| `RoofClayTiles` | [clay_roof_tiles_02](https://polyhaven.com/a/clay_roof_tiles_02) (Poly Haven) | ClayRoofTiles | 2.5 m | 9 | Regular | Spanish-style roofs (West Coast) |
| `RoofFlatBitumen` | [roof_07](https://polyhaven.com/a/roof_07) (Poly Haven) | Asphalt | 2.0 m | 7 | Organic | Flat roofs (check look; swap to bitumen if needed) |

### Ground and coast

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `DirtLot` | [dirt_floor](https://polyhaven.com/a/dirt_floor) (Poly Haven) | Ground | 2.07 m | 7 | Organic | Empty lots, yards |
| `GravelLot` | [gravel_ground_01](https://polyhaven.com/a/gravel_ground_01) (Poly Haven) | Pebble | 3.0 m | 11 | Organic | Rail yards, shoulders, rooftops |
| `BeachSand` | [coast_sand_03](https://polyhaven.com/a/coast_sand_03) (Poly Haven) | Sand | 3.0 m | 11 | Organic | Beaches |
| `RockGrey` | [gray_rocks](https://polyhaven.com/a/gray_rocks) (Poly Haven) | Rock | 1.8 m | 6 | Organic | Breakwaters, cliffs |
| `RockMossy` | [mossy_rock](https://polyhaven.com/a/mossy_rock) (Poly Haven) | Rock | 3.0 m | 11 | Organic | Damp shaded rocks |
| `MudDry` | [brown_mud_dry](https://polyhaven.com/a/brown_mud_dry) (Poly Haven) | Mud | 1.3 m | 5 | Organic | Dry mud patches, canal beds |

### Extra from ambientCG (zip downloads: glass towers, chain-link, road decals)

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Pattern | Use it for |
|---|---|---|---|---|---|---|
| `DowntownGlassFacadeA` | [Facade001](https://ambientcg.com/view?id=Facade001) (ambientCG) | Concrete | n/a | by eye | Regular | Reflective glass curtain wall (towers) |
| `DowntownGlassFacadeB` | [Facade006](https://ambientcg.com/view?id=Facade006) (ambientCG) | Concrete | n/a | by eye | Regular | Second glass tower facade |
| `DowntownTowerWindowsNight` | [Facade017](https://ambientcg.com/view?id=Facade017) (ambientCG) | Concrete | n/a | by eye | Regular | Window grid for far towers (has night lit version) |
| `ChainLinkFence` | [Fence003](https://ambientcg.com/view?id=Fence003) (ambientCG) | Concrete | n/a | by eye | Regular | Chain-link fence (alpha: use AlphaMode Transparency on a mesh) |
| `ChainLinkFenceB` | [Fence006](https://ambientcg.com/view?id=Fence006) (ambientCG) | Concrete | n/a | by eye | Regular | Second wire-mesh fence |
| `RoadAsphaltOld` | [Road012A](https://ambientcg.com/view?id=Road012A) (ambientCG) | Concrete | n/a | by eye | Regular | Old worn road with patches |
| `RoadAsphaltCrackedLayers` | [Road013A](https://ambientcg.com/view?id=Road013A) (ambientCG) | Concrete | n/a | by eye | Regular | Cracked layered asphalt |
| `PaintedPlasterBroken` | [PaintedPlaster006](https://ambientcg.com/view?id=PaintedPlaster006) (ambientCG) | Concrete | n/a | by eye | Regular | Broken painted plaster facade |
| `RoofingTilesSlate` | [RoofingTiles003](https://ambientcg.com/view?id=RoofingTiles003) (ambientCG) | Concrete | n/a | by eye | Regular | Clean slate roof tiles |
| `DecalManholeCover` | [ManholeCover011](https://ambientcg.com/view?id=ManholeCover011) (ambientCG) | Concrete | n/a | by eye | Regular | Manhole cover decal |
| `DecalRoadLinesYellow` | [RoadLines022A](https://ambientcg.com/view?id=RoadLines022A) (ambientCG) | Concrete | n/a | by eye | Regular | Road line decal (yellow) |
| `DecalWaterLeak` | [Leaking013A](https://ambientcg.com/view?id=Leaking013A) (ambientCG) | Concrete | n/a | by eye | Regular | Water streak / leak decal for walls |

## Ready-made combos

| Building or place | Walls | Trim / details | Ground |
|---|---|---|---|
| Hood corner store | `HoodPaintedBrick` (tint), `HoodStuccoWorn` above | `ShutterRusty`, `MetalPaintedRusty` bars | `HoodSidewalkCracked`, `HoodAsphaltCracked` |
| Hood apartment block | `HoodBrickDamaged` or `HoodStuccoWorn` (pink/blue tint) | `HoodPlasterExposedBrick` on one hero wall | `SidewalkConcrete`, `ConcreteStained` lot |
| Hood garage / auto shop | `HoodCinderBlock` | `ShutterPainted`, `CorrugatedWorn` lean-to | `ParkingLotStained` |
| Flood channel (hood-02) | `HoodConcreteDirty` sides | `ChainLinkFence` | `ConcreteStained`, `MudDry` |
| Downtown office tower | `DowntownPrecastPanel` base, `DowntownGlassFacadeA` above | `DowntownRibbedConcrete` stair core | `DowntownSidewalkTiles`, `DowntownAsphaltClean` |
| Bank / city hall | `DowntownStoneBlocks` | `LobbyMarble` inside | `DowntownPavers`, `PlazaTiles` steps |
| Fire station (coast-01) | `DowntownBrickRed` bay block + `WoodPaintedDistressed` (tint blue-grey) wing | `RoofShinglesGrey` | `ConcreteDriveway` apron |
| Warehouse / port | `IndustrialWall` or `DowntownBrickOld` | `RoofBoxProfile`, `ShippingContainer` | `GravelLot`, `ParkingLotStained` |
| West Coast house | `StuccoSuburb` (tint) | `RoofClayTiles` | `ConcreteDriveway`, terrain grass |
| Bridge / underpass | `BridgeConcretePanels` | `MetalPaintedRusty` railings | `DowntownAsphaltClean` |
| Beach | n/a | `RockGrey`, `RockMossy` breakwater | `BeachSand` |

## Getting them into Studio (3 steps)
1. **Download:** `sh download_textures.sh` on the Mac (a cloud session can't reach the texture sites; the Mac can).
2. **Upload:** Studio's Asset Manager → Bulk Import the `downloaded/` PNGs (or let Claude upload them through Studio). Moderation takes a few minutes.
3. **Build:** paste the image IDs into `BuildMaterialVariants.lua`, run it in the Command Bar, then **Cmd+S**. Apply a variant by setting a part's `MaterialVariant` to its name (Studio sets the base material).

## Honest notes
- The picks come from the source sites' tags, sizes and descriptions; **each still needs an in-Studio look** under the realistic lighting preset ([[34 Realistic Lighting and Atmosphere]]). Swap any that look wrong for a neighbour in the same Poly Haven category (lists at polyhaven.com/textures).
- Some metal sets may have no metalness map; the script skips missing maps.
- ambientCG real sizes aren't in its API: set StudsPerTile by eye.
- `RoofFlatBitumen` uses `roof_07`; if it reads wrong, try `bitumen` (very large scale) instead.
