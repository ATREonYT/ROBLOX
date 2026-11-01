---
tags: [build-playbooks, realistic, textures, materials, materialvariant, cc0, hood, downtown]
updated: 2026-11-01
---

# 40 Realistic Texture Library - Hood and Downtown

Back to [[35 Realistic Materials, Decals and Wear]] · [[33 Realistic World Building Playbook]] · [[00 Build Router]]

**152 free, CC0 textures picked for a realistic RP city** (68 in the first pass, 84 more matched to Alex's Larp photos), split into a worn **hood** look and a cleaner **downtown** look, plus shared roads, metal, roofs, ground and coast. Every one is CC0 (public domain, no credit needed, safe for a paid game) from **Poly Haven** or **ambientCG**. Write them in `<game>/art/LICENSES.md` anyway so we always know where a texture came from.

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

## Batch 2: matched to Alex's Larp photos (84 more, Nov 1)

Picked surface by surface from the 49 Larp screenshots. Which variant matches which shot, plus the tint to use, is in [[41 Larp Reference Study - Atmosphere, Surfaces and Feel]] §4.

| Variant name | Source texture (CC0) | Base material | Real size | StudsPerTile | Style | Use it for |
|---|---|---|---|---|---|---|
| `RoadDamagedB` | [road_damaged_2](https://polyhaven.com/a/road_damaged_2) (Poly Haven) | Asphalt | 2.2 m | 8 | hood | Second broken-road set; mix with HoodRoadPotholes so damage does not repeat |
| `AsphaltDarkFresh` | [asphalt_06](https://polyhaven.com/a/asphalt_06) (Poly Haven) | Asphalt | 3.0 m | 11 | both | Dark, near-black asphalt like the Larp night streets |
| `AsphaltPlain` | [asphalt_01](https://polyhaven.com/a/asphalt_01) (Poly Haven) | Asphalt | 2.08 m | 7 | downtown | Calm, even asphalt for main boulevards |
| `ParkingLotAsphalt` | [asphalt_floor](https://polyhaven.com/a/asphalt_floor) (Poly Haven) | Asphalt | 2.35 m | 8 | both | Store and motel parking lots |
| `AsphaltTarPatch` | [tarred_gravel](https://polyhaven.com/a/tarred_gravel) (Poly Haven) | Asphalt | 2.2 m | 8 | hood | Tar-sealed patch pieces laid over road (the dark patches with pale outlines in the Larp photos) |
| `AsphaltAerialWide` | [aerial_asphalt_01](https://polyhaven.com/a/aerial_asphalt_01) (Poly Haven) | Asphalt | 30.0 m | 107 | both | Huge 30 m tile for wide roads and freeways; kills visible repeats |
| `SidewalkWornStained` | [concrete_floor_worn_001](https://polyhaven.com/a/concrete_floor_worn_001) (Poly Haven) | Concrete | 3.0 m | 11 | hood | Blotchy, oil-stained pale sidewalk (Larp 142438) |
| `SidewalkCrackedB` | [cracked_concrete](https://polyhaven.com/a/cracked_concrete) (Poly Haven) | Concrete | 2.0 m | 7 | hood | Cracked sidewalk second variant |
| `LotConcreteWorn` | [worn_concrete_floor](https://polyhaven.com/a/worn_concrete_floor) (Poly Haven) | Concrete | 2.0 m | 7 | hood | Worn concrete aprons, driveways and lots |
| `ConcretePlain` | [concrete](https://polyhaven.com/a/concrete) (Poly Haven) | Concrete | 4.0 m | 14 | both | Clean large-scale concrete for curbs, slabs and medians |
| `ChannelConcreteDirty` | [dirty_concrete](https://polyhaven.com/a/dirty_concrete) (Poly Haven) | Concrete | 3.0 m | 11 | hood | Flood channel floor and banks (Larp 142344) |
| `ChannelConcreteDamaged` | [concrete_floor_damaged_01](https://polyhaven.com/a/concrete_floor_damaged_01) (Poly Haven) | Concrete | 5.0 m | 18 | hood | Large damaged concrete for the channel bottom and empty lots |
| `ConcreteLayers` | [concrete_layers_02](https://polyhaven.com/a/concrete_layers_02) (Poly Haven) | Concrete | 2.0 m | 7 | hood | Layered, stained concrete for retaining walls |
| `OverpassConcrete` | [smooth_concrete_floor](https://polyhaven.com/a/smooth_concrete_floor) (Poly Haven) | Concrete | 2.0 m | 7 | downtown | Smooth concrete for overpass decks and footbridges |
| `OverpassPrecast` | [preconcrete_wall_001](https://polyhaven.com/a/preconcrete_wall_001) (Poly Haven) | Concrete | 4.0 m | 14 | both | Precast panel walls under bridges and freeway sides |
| `ChannelWall` | [concrete_wall_008](https://polyhaven.com/a/concrete_wall_008) (Poly Haven) | Concrete | 2.71 m | 10 | hood | Tall channel and underpass walls with water stains |
| `BoardFormedConcrete` | [wood_textured_concrete](https://polyhaven.com/a/wood_textured_concrete) (Poly Haven) | Concrete | 1.8 m | 6 | hood | Board-formed concrete walls (Larp 142048) |
| `CinderBlockB` | [concrete_block_wall](https://polyhaven.com/a/concrete_block_wall) (Poly Haven) | Concrete | 2.0 m | 7 | hood | Second cinder block for fences and garages |
| `StuccoWhite` | [white_stucco](https://polyhaven.com/a/white_stucco) (Poly Haven) | Plaster | 2.0 m | 7 | both | White stucco shops and houses |
| `StuccoBlueWeathered` | [blue_plaster_weathered](https://polyhaven.com/a/blue_plaster_weathered) (Poly Haven) | Plaster | 2.0 m | 7 | hood | Blue strip-mall stucco (Larp 142209) |
| `StuccoPinkWeathered` | [red_plaster_weathered](https://polyhaven.com/a/red_plaster_weathered) (Poly Haven) | Plaster | 2.0 m | 7 | both | Pink/salmon stucco for motels and mission-style blocks (Larp 142133, 142845) |
| `StuccoYellow` | [yellow_plaster_02](https://polyhaven.com/a/yellow_plaster_02) (Poly Haven) | Plaster | 2.0 m | 7 | hood | Yellow painted shops (Larp 143304) |
| `StuccoBeige` | [beige_wall_001](https://polyhaven.com/a/beige_wall_001) (Poly Haven) | Plaster | 3.0 m | 11 | both | Tan/terracotta stucco (Larp 142140) |
| `PlasterWorn` | [worn_plaster_wall](https://polyhaven.com/a/worn_plaster_wall) (Poly Haven) | Plaster | 1.8 m | 6 | hood | Heavily worn plaster |
| `PlasterCrackedB` | [worn_cracked_plaster](https://polyhaven.com/a/worn_cracked_plaster) (Poly Haven) | Plaster | 1.8 m | 6 | hood | Cracked plaster second variant |
| `StuccoGreyFine` | [grey_plaster](https://polyhaven.com/a/grey_plaster) (Poly Haven) | Plaster | 1.0 m | 4 | downtown | Fine grey render for apartment blocks |
| `PlasterMossyHumid` | [worn_mossy_plasterwall](https://polyhaven.com/a/worn_mossy_plasterwall) (Poly Haven) | Plaster | 1.8 m | 6 | coast | Humid Florida walls with moss and mildew |
| `HoodBrickDark` | [dark_brick_wall](https://polyhaven.com/a/dark_brick_wall) (Poly Haven) | Brick | 1.05 m | 4 | hood | Dark blue-grey brick (Larp alley 142330, shop bases 142159) |
| `BrickRedClassic` | [brick_wall_001](https://polyhaven.com/a/brick_wall_001) (Poly Haven) | Brick | 3.0 m | 11 | both | Classic red brick walk-ups (Larp 142245, 143242) |
| `BrickBrownOld` | [brick_wall_02](https://polyhaven.com/a/brick_wall_02) (Poly Haven) | Brick | 2.0 m | 7 | both | Older brown brick |
| `BrickMixed` | [mixed_brick_wall](https://polyhaven.com/a/mixed_brick_wall) (Poly Haven) | Brick | 1.7 m | 6 | hood | Mixed-colour brick for variety |
| `BrickBroken` | [broken_brick_wall](https://polyhaven.com/a/broken_brick_wall) (Poly Haven) | Brick | 1.8 m | 6 | hood | Broken brick for damaged corners |
| `ConcreteBrick` | [concrete_brick_wall_001](https://polyhaven.com/a/concrete_brick_wall_001) (Poly Haven) | Brick | 3.0 m | 11 | hood | Grey concrete-brick walls |
| `ShutterRustedB` | [rusted_shutter](https://polyhaven.com/a/rusted_shutter) (Poly Haven) | CorrodedMetal | 1.8 m | 6 | hood | Second rusty roll-down shutter |
| `ShutterWorn` | [worn_shutter](https://polyhaven.com/a/worn_shutter) (Poly Haven) | Metal | 1.37 m | 5 | hood | Worn painted shutter (tint green/blue like Larp 142159) |
| `CorrugatedPlain` | [corrugated_iron](https://polyhaven.com/a/corrugated_iron) (Poly Haven) | Metal | 1.12 m | 4 | hood | Clean corrugated sheet |
| `CorrugatedB` | [corrugated_iron_02](https://polyhaven.com/a/corrugated_iron_02) (Poly Haven) | Metal | 2.7 m | 10 | hood | Corrugated second variant |
| `DumpsterGreenRust` | [green_metal_rust](https://polyhaven.com/a/green_metal_rust) (Poly Haven) | CorrodedMetal | 1.0 m | 4 | both | Green painted metal with rust: dumpsters, utility boxes (Larp 142330) |
| `RustyGrate` | [rusty_metal_grid](https://polyhaven.com/a/rusty_metal_grid) (Poly Haven) | CorrodedMetal | 1.8 m | 6 | hood | Rusty grate for fire escapes and vents |
| `MetalBluePlate` | [blue_metal_plate](https://polyhaven.com/a/blue_metal_plate) (Poly Haven) | Metal | 2.5 m | 9 | both | Blue painted metal panels |
| `RustySheet` | [rusty_metal_sheet](https://polyhaven.com/a/rusty_metal_sheet) (Poly Haven) | CorrodedMetal | 2.0 m | 7 | hood | Rusty sheet for billboard backs and sheds |
| `RustCoarse` | [rust_coarse_01](https://polyhaven.com/a/rust_coarse_01) (Poly Haven) | CorrodedMetal | 2.2 m | 8 | hood | Heavy rust for billboard legs and old poles |
| `SidingBlue` | [blue_painted_planks](https://polyhaven.com/a/blue_painted_planks) (Poly Haven) | WoodPlanks | 1.0 m | 4 | hood | Blue painted wood siding |
| `SidingBlack` | [black_painted_planks](https://polyhaven.com/a/black_painted_planks) (Poly Haven) | WoodPlanks | 1.6 m | 6 | both | Dark painted siding |
| `FenceWoodRaw` | [raw_plank_wall](https://polyhaven.com/a/raw_plank_wall) (Poly Haven) | WoodPlanks | 1.87 m | 7 | hood | Raw plank fences |
| `FenceGreenRough` | [green_rough_planks](https://polyhaven.com/a/green_rough_planks) (Poly Haven) | WoodPlanks | 1.5 m | 5 | hood | Green rough boards |
| `RoofSlatesDark` | [roof_slates_02](https://polyhaven.com/a/roof_slates_02) (Poly Haven) | Slate | 3.0 m | 11 | hood | Dark tile roof with grid (Larp 142651) |
| `RoofClayMission` | [clay_roof_tiles](https://polyhaven.com/a/clay_roof_tiles) (Poly Haven) | ClayRoofTiles | 4.0 m | 14 | coast | Spanish clay tiles for Florida and mission buildings |
| `RoofCeramic` | [ceramic_roof_01](https://polyhaven.com/a/ceramic_roof_01) (Poly Haven) | ClayRoofTiles | 3.5 m | 12 | coast | Ceramic roof second variant |
| `RoofRedSlate` | [red_slate_roof_tiles_01](https://polyhaven.com/a/red_slate_roof_tiles_01) (Poly Haven) | Slate | 2.5 m | 9 | both | Red slate tiles |
| `PalmBark` | [palm_bark](https://polyhaven.com/a/palm_bark) (Poly Haven) | Wood | 1.86 m | 7 | both | Palm trunks |
| `PalmBarkB` | [palm_tree_bark](https://polyhaven.com/a/palm_tree_bark) (Poly Haven) | Wood | 1.3 m | 5 | both | Palm trunks second variant |
| `EucalyptusBark` | [eucalyptus_bark](https://polyhaven.com/a/eucalyptus_bark) (Poly Haven) | Wood | 1.81 m | 6 | hood | Eucalyptus trunks (LA street trees) |
| `SycamoreBark` | [bark_platanus](https://polyhaven.com/a/bark_platanus) (Poly Haven) | Wood | 1.5 m | 5 | both | Sycamore/plane tree trunks |
| `ParkDirt` | [park_dirt](https://polyhaven.com/a/park_dirt) (Poly Haven) | Ground | 3.0 m | 11 | both | Park paths and bare lawn patches (Larp 142801) |
| `DryGround` | [dry_ground_01](https://polyhaven.com/a/dry_ground_01) (Poly Haven) | Ground | 4.0 m | 14 | hood | Dry empty lots |
| `LeafLitter` | [forest_leaves_02](https://polyhaven.com/a/forest_leaves_02) (Poly Haven) | LeafyGrass | 3.0 m | 11 | both | Dead leaves under trees (Larp 142053) |
| `DryLeaves` | [dry_decay_leaves](https://polyhaven.com/a/dry_decay_leaves) (Poly Haven) | LeafyGrass | 2.0 m | 7 | both | Dry decaying leaves |
| `MudLeaves` | [brown_mud_leaves_01](https://polyhaven.com/a/brown_mud_leaves_01) (Poly Haven) | Mud | 1.3 m | 5 | coast | Wet mud with leaves for humid Florida |
| `DryMudField` | [dry_mud_field_001](https://polyhaven.com/a/dry_mud_field_001) (Poly Haven) | Mud | 3.0 m | 11 | hood | Cracked dry field |
| `GravelRoad` | [gravel_road](https://polyhaven.com/a/gravel_road) (Poly Haven) | Pebble | 2.0 m | 7 | hood | Gravel alleys and lot edges |
| `GravelLeaves` | [leaf_scattered_gravel](https://polyhaven.com/a/leaf_scattered_gravel) (Poly Haven) | Pebble | 1.8 m | 6 | both | Gravel with leaves |
| `CoralGravel` | [coral_gravel](https://polyhaven.com/a/coral_gravel) (Poly Haven) | Pebble | 2.0 m | 7 | coast | White coral gravel (Florida) |
| `BeachSandB` | [coast_sand_04](https://polyhaven.com/a/coast_sand_04) (Poly Haven) | Sand | 3.94 m | 14 | coast | Second beach sand (Larp 143109) |
| `HerringbonePavers` | [herringbone_pavement_02](https://polyhaven.com/a/herringbone_pavement_02) (Poly Haven) | Pavement | 2.48 m | 9 | downtown | Herringbone plaza pavers |
| `InterlockPavers` | [interlocking_concrete_pavers](https://polyhaven.com/a/interlocking_concrete_pavers) (Poly Haven) | Pavement | 1.8 m | 6 | downtown | Interlocking pavers |
| `BrickPavementB` | [brick_pavement](https://polyhaven.com/a/brick_pavement) (Poly Haven) | Pavement | 2.0 m | 7 | downtown | Brick pavement second variant |
| `LawnGrassA` | [Grass001](https://ambientcg.com/view?id=Grass001) (ambientCG) | Grass | not stated | by eye | both | Lawn grass ground for terrain grass areas |
| `LawnGrassB` | [Grass004](https://ambientcg.com/view?id=Grass004) (ambientCG) | Grass | not stated | by eye | both | Lawn grass second variant |
| `LawnGrassC` | [Grass005](https://ambientcg.com/view?id=Grass005) (ambientCG) | Grass | not stated | by eye | both | Lawn grass third variant |
| `RoadOldB` | [Road007](https://ambientcg.com/view?id=Road007) (ambientCG) | Asphalt | not stated | by eye | hood | Old road surface |
| `RoadWithLinesA` | [Road008A](https://ambientcg.com/view?id=Road008A) (ambientCG) | Asphalt | not stated | by eye | both | Road with lines painted in |
| `RoadWithLinesB` | [Road008B](https://ambientcg.com/view?id=Road008B) (ambientCG) | Asphalt | not stated | by eye | both | Road with lines, variant B |
| `AsphaltDarkB` | [Asphalt031](https://ambientcg.com/view?id=Asphalt031) (ambientCG) | Asphalt | not stated | by eye | both | Dark asphalt |
| `AsphaltGreyB` | [Asphalt033](https://ambientcg.com/view?id=Asphalt033) (ambientCG) | Asphalt | not stated | by eye | both | Grey asphalt |
| `DecalRoadSymbols` | [RoadLines019A](https://ambientcg.com/view?id=RoadLines019A) (ambientCG) | Asphalt | not stated | by eye | both | Road symbols and checker markings decal |
| `DecalRoadLinesWorn` | [RoadLines020B](https://ambientcg.com/view?id=RoadLines020B) (ambientCG) | Asphalt | not stated | by eye | both | Worn yellow lines decal |
| `DecalWaterLeakB` | [Leaking012A](https://ambientcg.com/view?id=Leaking012A) (ambientCG) | Concrete | not stated | by eye | both | Leak streak decal B |
| `DecalWaterLeakC` | [Leaking017B](https://ambientcg.com/view?id=Leaking017B) (ambientCG) | Concrete | not stated | by eye | both | Leak streak decal C |
| `DecalWaterLeakD` | [Leaking019A](https://ambientcg.com/view?id=Leaking019A) (ambientCG) | Concrete | not stated | by eye | both | Leak streak decal D |
| `DecalGraffitiSet` | [GraffitiSet001](https://ambientcg.com/view?id=GraffitiSet001) (ambientCG) | Concrete | not stated | by eye | hood | Graffiti decal set. CHECK EVERY PIECE BY EYE for kid-safety before use |
| `PaintedMetalA` | [PaintedMetal004](https://ambientcg.com/view?id=PaintedMetal004) (ambientCG) | Metal | not stated | by eye | both | Painted metal for poles, boxes, rails |
| `PaintedMetalB` | [PaintedMetal006](https://ambientcg.com/view?id=PaintedMetal006) (ambientCG) | Metal | not stated | by eye | both | Painted metal variant |
| `CorrugatedSteelB` | [CorrugatedSteel005](https://ambientcg.com/view?id=CorrugatedSteel005) (ambientCG) | Metal | not stated | by eye | hood | Corrugated steel |

**Quality:** every texture is the full PBR set (colour, OpenGL normal, roughness, and metalness for metals) at 1024 px. 1024 is the most Roblox uses for MaterialVariant maps, so bigger downloads would add memory on phones without adding detail on screen.

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

**Already done (Nov 1):** all 152 are uploaded (472 maps) and built as MaterialVariants in **Miami Trap Life** (place 95405231186296), in `MaterialService > Realistic`, with no overrides. Every image ID is in `realistic-kit/textures/texture-ids.json` (`{"VariantName": {"ColorMap": "rbxassetid://…", …}}`). For another place, reuse those IDs: no need to download or upload again. ambientCG variants with no real size got StudsPerTile 20 (roads), 4 (decals, fences) or 10 (the rest): check them by eye.

## Honest notes
- The picks come from the source sites' tags, sizes and descriptions; **each still needs an in-Studio look** under the realistic lighting preset ([[34 Realistic Lighting and Atmosphere]]). Swap any that look wrong for a neighbour in the same Poly Haven category (lists at polyhaven.com/textures).
- Some metal sets may have no metalness map; the script skips missing maps.
- ambientCG real sizes aren't in its API: set StudsPerTile by eye.
- `RoofFlatBitumen` uses `roof_07`; if it reads wrong, try `bitumen` (very large scale) instead.
