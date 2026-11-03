---
tags: [vice-bay, roblox, textures, materials]
updated: 2026-11-01
---
# Realistic texture plan for Vice Bay

Back to [[00 Vice Bay]] · Texture files: `realistic-textures/downloaded/<Name>/` (ColorMap, NormalMap, RoughnessMap; all CC0 from Poly Haven / ambientCG; list in `texture-manifest.json`). Builder: `realistic-textures/BuildMaterialVariants.lua`.

These replace the AI-generated materials from the first build, which were the weakest part of the look. Each becomes a MaterialVariant in `MaterialService/Realistic`. Never set "Override", so only the parts that name the variant change.

| Use in Vice Bay | Variants |
|---|---|
| Hood roads | HoodAsphaltCracked, HoodAsphaltFaded, AsphaltTarPatch (patch pieces), RoadDamagedB / HoodRoadPotholes (worst alleys only) |
| Habana / Wynwood roads | AsphaltWorn, AsphaltGranular |
| Downtown, I-95, causeways | DowntownAsphaltClean, AsphaltPlain, AsphaltAerialWide (wide roads, hides repeats) |
| Hood sidewalks | HoodSidewalkCracked, SidewalkWornStained, SidewalkCrackedB |
| Normal sidewalks / curbs | SidewalkConcrete, SidewalkSlabs, ConcretePlain |
| Downtown sidewalks, plazas | DowntownSidewalkTiles, DowntownPavers, HerringbonePavers, PlazaTiles, DowntownBrickPavers (crosswalks) |
| Hood walls (tint pink, mint, sand) | HoodStuccoWorn, HoodPlasterChipped, PlasterWorn, StuccoPinkWeathered, StuccoBlueWeathered, StuccoYellow, HoodCinderBlock, HoodPaintedBrick |
| Habana | StuccoBeige, StuccoWhite, RoofClayMission |
| Wynwood | DowntownBrickOld, BrickRedClassic, IndustrialWall, HoodPaintedBrickYellow |
| Downtown towers | DowntownPrecastPanel, DowntownConcreteFacade, DowntownStoneBlocks (bank, Exchange base), DowntownRender, DowntownGlassFacadeA/B (check they tile well), LobbyMarble (lobbies, interiors) |
| Suburb / villas / Coral County | StuccoSuburb, StuccoWhite, PlasterMossyHumid, RoofClayMission, RoofCeramic, RoofShinglesGrey, ConcreteDriveway |
| Shutters & metal | ShutterRusty, ShutterWorn, ShutterPainted, CorrugatedWorn, DumpsterGreenRust, MetalPaintedRusty, RustyGrate (fire escapes) |
| Port | ShippingContainer (tint per box), GravelLot, ParkingLotStained, MetalPlate |
| Bridges, I-95, channel | BridgeConcretePanels, OverpassConcrete, OverpassPrecast, ChannelWall |
| Ground | BeachSand / BeachSandB, CoralGravel, ParkDirt, LeafLitter, DirtLot, DryGround, MudLeaves (Glades), RockGrey / RockMossy (breakwater) |
| Marina | WoodPlanksOld (old pier), WoodPaintedDistressed |
| Palms | PalmBark, PalmBarkB |

**Uploading:** the images need Roblox asset ids. Options: (a) the Studio MCP `upload_image` tool with the Poly Haven URLs from the manifest; (b) Studio Asset Manager → Bulk Import the `downloaded` folder, then paste the ids into `BuildMaterialVariants.lua`.

**Check first:** a screenshot test of every variant on a 40×40 sample part before using it map-wide (lesson from the diamond-pattern sidewalk). The Larp-photo-matched ones (AsphaltTarPatch, SidewalkWornStained, Stucco*Weathered) are the closest to the hood reference screenshots.
