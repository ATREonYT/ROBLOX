---
tags: [vice-bay, roblox, map, lessons]
updated: 2026-11-01
---
# Map building lessons (Vice Bay)

Back to [[00 Vice Bay]] · Sources: [[Art direction for the whole map]], [[hood_games_maps]], [[lighting_and_build_tech]], [[How to Build PRO Roblox Maps!]], plus the Vice Bay build itself.

## 1. Never lose work again
- **Save to a local file** (`File → Save to File As → ViceBay.rbxl`) as well as publishing. A cloud place you can't open during a Roblox outage is a place you can't recover.
- **Cmd+S after every big section.** Studio AutoSaves only exist if the place was saved at least once.
- **Keep the generator code in the vault** (`Vice Bay/src/build/`), not only inside the place. Then the whole map can be rebuilt by running the files in order.
- Don't keep important data in `_G` (the road network was kept there and vanished with the session). Store it in a ModuleScript or attributes.

## 2. Layout (what makes a map feel like a real city)
- **Spawn at the edge**, in the poorest zone, so progression pulls players across the map (hood → Habana/Wynwood → downtown → islands). This is the same rule simulator maps use: spawn in a corner, a grand main route toward the goal.
- **One spine road** players can't miss (Flagler / Coral Blvd), with districts hanging off it, and the next goal (the skyline) visible from spawn.
- **Each district must read differently with the signs hidden:** different street width, building height, materials and clutter, not just a colour swap.
- **Enclosure ratio:** buildings roughly as tall as the street is wide (1:1) feels like a city. Worse than 1:4 reads as car-oriented suburb, which is right for Coral County and wrong for downtown.
- **Scale:** 1 stud ≈ 0.28 m. Keep vertical scale real (10–12 studs per floor, 12–14 for ground-floor shops) and compress widths to about 60–70% (lots 14–20 wide).
- Hood blocks: a continuous street wall, **one gap per block face** (a fenced lot), a commercial corner, alleys behind.
- Big filler first (trees, rocks, big buildings), small filler after, so you don't overdo it.
- Roads must come first and buildings must be placed by the road network (never let buildings cut through roads: check overlap boxes at **road height**).

## 3. Realism ("worn but cared for")
- The DevForum critique of hood maps: "too much green", buildings look "washed", roads need texture, graffiti on 3rd floors where nobody can reach, and "in-between well kept and decrepit". **Pick one level of wear per district and commit to it.**
- Hood: almost no grass. Use one tree pit or one garden lot per block. Colour comes from signs, cars and avatars, not from the buildings.
- **Graffiti only where a person can reach:** gates, poles, dumpsters, the lower 8 studs of walls.
- Cheapest honest wear: sidewalk joint lines, a manhole and a storm drain, one tar patch, window shades at different heights, trash bags at the curb, one roll-down gate down.
- Palette: about 60% greys (asphalt, concrete, trim), 30% wall colours, 10% accents. Too many bright colours together is the most common mistake.
- Parked cars: about 80% white, black, grey or silver.
- Facade "life" layer: window ACs on about 1 in 4 upper windows, satellite dishes, bars on ground-floor windows only, roller shades on about 1 in 4 windows, power lines (Miami has them; downtown doesn't).

## 4. Roblox rules (content safety)
- No gangs, drugs, alcohol, lotto or real brands. **Swap**: no "LIQUOR", "LOTTO", "PAWN", "BAIL BONDS" shop signs, and no gang tags ("LH GANG", "RIP …", "FREE …"). Use corner store, laundromat, barber, wings, phone repair, 99-cent store, tire shop and neutral art tags instead. (The first Vice Bay build used some of these; the rebuild removes them.)
- Check every graffiti image by eye before using it.

## 5. Lighting (the biggest single quality jump)
- `Lighting.Technology` can't be set from scripts, but **`Lighting.LightingStyle = Realistic` + `PrioritizeLightingQuality = true` = Future**, and those *can* be set from the builder (wrap in `pcall`, then check they stuck).
- Miami day preset (start here and tune by eye): ClockTime 14–15, GeographicLatitude 26, Brightness 3, warm ColorShift_Top (255,235,205), cool ColorShift_Bottom (150,175,210), Atmosphere Density 0.3 / Haze 1.5 with a warm colour, Bloom Threshold 0.9–1.0 so neon pops, ColorCorrection Saturation +0.05 to +0.12 (never negative).
- Golden hour / evening: ClockTime 17.2–17.8, ColorShift_Top (255,200,150).
- Don't mix legacy Fog with Atmosphere (Fog is ignored).
- Neon signs: one shadowless PointLight per sign cluster, Range 8–16. Turn shadows on for only 1–3 hero lights. Switch interior lights by distance from a LocalScript.

## 6. Performance (phones)
- StreamingEnabled with MinRadius 64, TargetRadius about 1024, ModelStreamingBehavior Improved, StreamOutBehavior Opportunistic.
- Reuse a small set of part sizes, materials and colours so instancing collapses draw calls. Budget: under about 1,000 draw calls and 1M triangles in view.
- Anchor everything. On trim and props: CanCollide, CanTouch, CanQuery off and CastShadow off. Wires as Beams, not parts.
- Group each building into its own Model (under about 64-stud extents) and set `LevelOfDetail = SLIM` on static buildings (Studio context only).
- Terrain grass blades poke through parts: use LeafyGrass or turn Decoration off; use Concrete for city ground.
- Persistent models permanently take memory: only make gameplay-critical things Persistent.

## 7. Technical gotchas hit during the Vice Bay build
| Problem | Fix |
|---|---|
| Terrain surfaces land at y = 2, not 0 (voxel grid), so roads were hidden | Ground level `L.G = 2`; build everything relative to it |
| River didn't carve | Carve Air centred on y 0 with size 8 |
| 14.7k road parts | Dash period 40, lights every 120, stop lines only downtown, fewer poles |
| Generated MaterialVariant looked bad (diamond pattern) | Check every variant by screenshot before using it; fall back to built-in Concrete/Plaster |
| Buildings overlapping roads | Lot overlap box at y 2–8 (road height), not 3–13 |
| Free-model trees had hidden scripts inside SurfaceAppearance | Clean every inserted asset to a whitelist of allowed classes; verify no Scripts remain |
| Decals didn't show with decal ids | Convert decal ids to image ids with `InsertService:LoadAsset` |
| `string.gsub` replacement containing `%` | Escape: `(src:gsub("%%","%%%%"))` |
| Raycast ground height returned 0 on a hill | Start the ray from y 400, above the terrain |
| Cached `require` | `require(module:Clone())` while developing |
| Invisible collidable leftovers | Delete parts with Transparency ≥ 1 that aren't hitboxes |

## 8. Lessons from the Miami Trap Life rebuild (2026-11-01)
- **Terrain height:** `FillBlock` up to y = 0 puts the rendered surface at **y = 2** (= `L.G`). Filling up to y = 2 puts it at y = 4, which buries every road part. Always raycast the terrain once to check.
- **A zero-height FillBlock errors** ("Extents cannot be empty"), so guard every slope loop.
- **Decoration parts are `CanQuery = false`,** so `GetPartBoundsInBox` can't see them. Every lot and landmark gets an invisible queryable `Footprint` part (`L.footprint`), otherwise the filler builds on top of parking lots.
- **Freshly uploaded textures** come back as `AssetFetchStatus.Failure` until Roblox moderation clears them (can take a while). The MaterialVariants are already wired, so they appear on their own once approved.
- **Part-built trees look bad.** Use realistic mesh vegetation (`ServerStorage/VBAssets`: PalmA/PalmB/PalmHero1-5, Oak, BushA/B, Bush1-5, Ferns). Strip every script from Creator Store models.
- **Hood ground** is dirt yards with patchy lawn (`ReplaceMaterial` Concrete→Ground, then small Ground→LeafyGrass boxes), never a concrete slab.
- **Districts must differ in everything:** asphalt variant, sidewalk variant, line style, poles vs. no poles, street trees vs. palms, light style, signal colour (sand-yellow in the hood, dark grey downtown).

## 9. Lessons from the detail pass (Nov 2026)
- **Blocked textures render dark grey.** Asset privacy blocks images uploaded by a *user* inside a *group* experience. The fix is to share access, or to point the variant at public Creator Store maps. Test with a coloured part on screen; `PreloadAsync` in Edit reports Failure even for public assets.
- **Water won't overwrite solid terrain.** `FillBlock(Water)` over existing Ground does nothing, so fill Air over the full depth first, then Water.
- **The WriteVoxels height convention** must match FillBlock-to-y0, where the surface renders at y=2. Use occupancy = clamp((H − 2 − yBottom)/4, 0, 1).
- **SurfaceGui text needs a few seconds** to appear after creation. Wait before taking screenshots, or text looks missing.
- **Count parts on Creator Store meshes.** The motor yacht was 1,137 parts. Strip small parts and welds (`YachtMotorLite` 226, `SedanLite` 64) and keep the hero copy only where it is seen up close.
- **Strip brands.** The sedan mesh had a real-brand badge and plate. Removing small parts dropped them, but always check.
- **Drivable water needs room.** A canal needs 30+ studs of clear fairway. Run docks parallel to the bank and leave berths empty for players.

## 10. Texture permissions in the group game (Nov 2026)
- **What happens:** any image owned by Alex's personal account renders flat grey in the group-owned experience. This covers uploaded PBR maps, MaterialVariants and AI-generated materials (VB_RoadClean, VB_RoadWorn, VB_Sidewalk). Output says: "The experience doesn't have access permission to use asset id … Click to share access".
- **Fix (owner, once):** click "Click to share access" in Studio's Output for each id. If it offers to grant every asset at once, take that. The alternative is Creator Dashboard → each image → Permissions → add the experience.
- **Then:** run `R.run("15_textures","restore")` to switch the realistic set back on.
- **Until then:** only public Creator Store textures (the MatPack sets) render. That's why the roads still use the brown, noisy public asphalt.
