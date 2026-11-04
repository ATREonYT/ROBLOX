---
tags: [build-playbooks, realistic, references, atmosphere, lighting, textures, game-feel, hood, rp]
updated: 2026-11-01
---

# 41 Larp Reference Study - Atmosphere, Surfaces and Feel

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Lighting base: [[34 Realistic Lighting and Atmosphere]] · Textures: [[40 Realistic Texture Library - Hood and Downtown]] · Roads: [[36 Roads, Blocks and City Layout Kit]] · Life and sound: [[39 Living World - Traffic, NPCs and Ambience]]

Alex sent 49 screenshots of a realistic hood RP game on Nov 1, 2026 ("add these textures in… learn how to make the atmosphere look like this, and how to make the game feel the best possible"). They are saved at `references/larp/larp-HHMMSS.jpg` (1280 px copies; the originals are in the project files as `Larp Photos.zip`).

> **TL;DR**
> - **The look is 80% surfaces and 20% light.** Every ground surface carries stains, patches and wear, and every wall carries grime, an AC unit, a grille or a shutter. Clean flat parts are what make Roblox maps look like Roblox.
> - **Three moods in the photos:** clear blue day, pink-lavender hazy afternoon, and a purple foggy night. Ready presets for all three are in §3, with colours measured from the photos.
> - **Night = purple-blue fog + warm practical lights.** Lifted shadows (never pure black), dense fog from ~150 studs, warm doorways and shop glows, cool white streetlight cones.
> - **The "LA hood" silhouette comes from 6 things:** palms, wooden power poles with sagging wires, steel lattice pylons, rooftop billboards, a concrete flood channel with graffiti, and a freeway overpass.
> - **Feel:** minimal HUD, floating round icons over every job/shop, ProximityPrompt NPCs, realistic parked cars, seasonal props. See §8.
> - **Copy the look, never the game.** Their brand names (stores, cola, logos), map layout and UI art stay theirs. We make our own names, signs and graffiti. Kid-safe: we skip the weapon shop and anything gang-coded.

---

## 1. What is in the photos (shot list)

Times are the screenshot names. Use them to open the matching `references/larp/larp-<time>.jpg`.

| Group | Shots | What to study |
|---|---|---|
| Ground close-ups | 142023, 142034 | Teal-tinted parking asphalt with big pale peeling patches; parking bays painted over; sidewalk slabs with dark water streaks; crumbling asphalt edge |
| Hood houses at dusk | 142048, 142053 | Board-formed concrete house, rolling garage shutter, barred windows, overgrown grass, dead leaves and pumpkins, warm porch light vs cool dusk |
| Intersections | 142103, 142140, 142159, 142245, 142322, 142419, 142501, 142507, 143242, 143453, 143504 | Zebra crosswalks, yellow diagonal hatch boxes, lane arrows, stop bars, red curbs, curb ramps, tactile strips, hydrants, mast-arm traffic lights, patched wheel paths |
| Shops and strip malls | 142112, 142133, 142159, 142209, 142259, 142429, 142939, 143150, 143304, 143453 | Wall AC units on every unit, rusty awning bands, roll shutters, painted stucco in blue/pink/yellow/mint, big painted wordmarks, ATM + vending machine on walls |
| Billboards | 142140, 142147, 142209, 143242 | Rooftop billboards on rusty steel legs, posters peeling off to grey, one fully blank peeled board |
| Alley | 142330 | Painted blue-grey brick, two green rusted dumpsters with peeling stencil, stained cracked concrete, weeds |
| Flood channel | 142344, 142408, 142527, 143345 | Sloped concrete banks, big graffiti pieces on banks and floor, debris piles, dark water lines, culvert tunnel, bridge abutments |
| Roads and overpasses | 142448, 142516, 142718 | Arch underpass, concrete walls, huge oil/patch blotches, crack-seal outlines, grassy verges, lattice pylons both sides |
| Residential street | 142546, 142606, 142651 | Single-storey bungalows with dark low roofs, siding, brick veneer, chain-link front fences, FOR SALE signs, pickup parked on the lawn, power lines across the street |
| Gas station | 142636, 142651 | Green canopy on black steel, pumps, mini-mart, ice box |
| Park / vacant lot | 142801 | Tall dense 3D grass, bare dirt patches, curved path, retaining wall, low soft sun |
| Night set | 142845, 142853, 142902, 142913, 142939, 142950, 143000, 143006 | Purple fog, motel with balconies and glowing vending machine, lit doorway pools, convenience store glow, construction site with tower crane and orange tarps, streetlight cones, bollards |
| Beach boulevard | 143109, 143118 | Palm median in tall grass, green bike lane, beach umbrellas, ocean haze, pink sky |

## 2. Why it reads as real (the 12 rules)

1. **No surface is clean.** Asphalt has patches, oil blotches, lighter wheel paths and crack-seal lines. Sidewalks have dark streaks. Walls have grime that runs down from the roof edge. Use a base MaterialVariant + 1-3 decal layers ([[35 Realistic Materials, Decals and Wear]]).
2. **Patches are their own objects.** The dark rectangles with pale outlines (142259, 142718, 142853, 143429) are separate thin parts or decals over the road, not part of the road texture. Scatter 1-3 per road segment, rotated a few degrees.
3. **Big tiles, no visible repeat.** Roads use large textures (3-30 m real size). Our fix: `AsphaltAerialWide` for wide roads, plus two asphalt variants alternated per block.
4. **Every building has 3 "machine" props:** a wall AC unit, window grilles, and a roll shutter or security door. These alone make a box read as a hood building.
5. **Rusty metal trims:** awning bands, billboard legs, dumpsters and frames carry rust. One rust material used everywhere ties the scene together.
6. **Painted stucco in many colours,** all slightly desaturated and dirty: blue, pink/salmon, tan, yellow, mint, white. Same texture, different `Color` on the part (MaterialVariants take the part colour as a tint).
7. **Paint on the ground is bright and crisp** (white crosswalks, yellow hatch, red curbs) **but worn at the edges.** The contrast between fresh paint and dirty asphalt is a big part of the look.
8. **Vertical clutter overhead:** wires crossing every street, poles with transformers, mast-arm signals, cobra-head streetlights, pylons. Sky is never empty.
9. **Vegetation is dense and 3D:** tall grass clumps along fences and verges, broadleaf trees casting dappled shadows, palms in rows. Grass hides where parts meet the ground.
10. **Distance haze is always on.** Even the clearest shot fades the skyline into a pale haze. It sells scale and hides the map edge.
11. **Dark asphalt, pale concrete.** The value split (asphalt ~#21262f, sidewalk ~#a09aa8 in shade) is very strong. Keep asphalt dark.
12. **Life:** parked cars with real reflections, NPC pedestrians with prompts, quest rings on the ground, seasonal props (pumpkins, dead leaves).

## 3. Atmosphere: three presets measured from the photos

Colours below were sampled from the shots (sky band at 8-14% height, horizon band at 30-34%, ground at 80-95%). Use them as targets when tuning: put a screenshot of our map next to the reference and compare these zones.

| Shot | Sky top | Near horizon | Ground |
|---|---|---|---|
| 142419 clear day | #7a9bb8 | #7d7c76 | #726864 |
| 142651 day, high view | #bdc9d7 | #4d5554 | #21262f |
| 143109 pink afternoon | #9b919a | #81818a | #303722 |
| 143150 pink afternoon | #a28e94 | #3f3641 | #404153 |
| 142845 dusk motel | #6e6882 | #3d384c | #302c38 |
| 142853 foggy night | #4a4a63 | #373e57 | #10121c |
| 142950 night crane | #666077 | #353a54 | #101014 |
| 142053 dusk house | #585b7d | #3c353c | #373a36 |

What each mood is doing:
- **Clear day (most shots):** sun high, hard shadows (ShadowSoftness near 0), deep-blue sky fading to a pale cream-grey horizon, cumulus clouds, light haze on the skyline. Shade is slightly cool lilac.
- **Pink afternoon (143109-143150):** the whole sky is a desaturated pink-lavender, strong haze over the ocean, soft low-contrast light, long shadows.
- **Foggy night (142845-143006):** it is really "blue hour": the sky still glows purple, fog is dense and purple-blue, shadows are lifted to dark violet (never black), warm doorways and shop glows pop, streetlights make bright white cones on the road.

Add these three entries to the `P` table in the preset script in [[34 Realistic Lighting and Atmosphere]] §3 (same keys, same apply code). **Sketch, not yet run in Studio**: tune side by side with the shots above.

```lua
	LarpClearDay = { -- 142419, 142636, 143504
		ClockTime = 13.2, Latitude = 34, Brightness = 3, Exposure = 0,
		Ambient = Color3.fromRGB(78, 80, 96), Outdoor = Color3.fromRGB(135, 140, 165),
		Top = Color3.fromRGB(255, 244, 226), Bottom = Color3.fromRGB(55, 50, 50),
		Soft = 0.04, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.3, Offset = 0.12, Color = Color3.fromRGB(205, 208, 214), Decay = Color3.fromRGB(125, 150, 180), Glare = 0.4, Haze = 1.3 },
		CC = { Brightness = 0, Contrast = 0.06, Saturation = -0.06, Tint = Color3.fromRGB(250, 250, 255) },
		Bloom = { Intensity = 0.3, Size = 24, Threshold = 1.8 },
		Rays = { Intensity = 0.04, Spread = 0.5 },
		Clouds = { Cover = 0.5, Density = 0.65 },
	},
	LarpPinkAfternoon = { -- 143109, 143118, 143150
		ClockTime = 16.9, Latitude = 34, Brightness = 2.2, Exposure = 0.05,
		Ambient = Color3.fromRGB(80, 72, 86), Outdoor = Color3.fromRGB(150, 135, 160),
		Top = Color3.fromRGB(255, 225, 215), Bottom = Color3.fromRGB(60, 45, 50),
		Soft = 0.15, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.4, Offset = 0.08, Color = Color3.fromRGB(205, 185, 195), Decay = Color3.fromRGB(150, 128, 150), Glare = 1, Haze = 2.8 },
		CC = { Brightness = 0.01, Contrast = 0.03, Saturation = -0.12, Tint = Color3.fromRGB(255, 240, 245) },
		Bloom = { Intensity = 0.4, Size = 28, Threshold = 1.5 },
		Rays = { Intensity = 0.05, Spread = 0.7 },
		Clouds = { Cover = 0.35, Density = 0.5 },
	},
	LarpFoggyNight = { -- 142845, 142853, 142950, 143000
		ClockTime = 19.4, Latitude = 34, Brightness = 0.9, Exposure = 0.15,
		Ambient = Color3.fromRGB(46, 44, 66), Outdoor = Color3.fromRGB(88, 84, 120),
		Top = Color3.fromRGB(190, 180, 255), Bottom = Color3.fromRGB(25, 22, 35),
		Soft = 0.3, Diffuse = 0.9, Specular = 1,
		Atmo = { Density = 0.55, Offset = 0, Color = Color3.fromRGB(92, 88, 122), Decay = Color3.fromRGB(58, 60, 88), Glare = 0, Haze = 2.6 },
		CC = { Brightness = 0.02, Contrast = 0.04, Saturation = -0.15, Tint = Color3.fromRGB(232, 226, 255) },
		Bloom = { Intensity = 0.8, Size = 32, Threshold = 1.05 },
		Rays = { Intensity = 0, Spread = 0.5 },
		Clouds = { Cover = 0.75, Density = 0.8 },
	},
```

Tuning notes:
- **Night fog distance:** in 142853 the far palms are gone by ~150-200 studs, and nothing past ~400 studs reads. If `Density` 0.55 is not thick enough, raise it to 0.65 before touching `Haze`.
- **Never pure black:** the darkest ground in the night shots is ~#10121c and shade on walls is a readable violet. If shadows crush, raise `OutdoorAmbient`, not `Exposure`.
- **Day haze:** the skyline in 142408 and 142501 is clearly faded. If ours looks too sharp, raise `Haze` to 1.8.
- **Blend presets in the day-night cycle** in [[34 Realistic Lighting and Atmosphere]] §5: LarpClearDay (9-15h) → LarpPinkAfternoon (16-18h) → LarpFoggyNight (19-5h).

### Night practical lights (what makes 142913 and 142939 work)

| Light | Build | Settings to start |
|---|---|---|
| Doorway pool | `SpotLight` above each door, facing down + small warm Neon or emissive fixture | Color (255, 190, 120), Brightness 2, Range 14, Angle 100, Shadows off |
| Shop interior glow | `SurfaceLight` behind the glass facing out + bright interior shelves | Color (255, 240, 210), Brightness 1.5, Range 20 |
| Backlit sign band ("EASY CONVENIENCE" style) | `SurfaceGui` with `LightInfluence = 0` + `Brightness 2`, or emissive mask | Pick our own store names |
| Vending machine | Emissive front + `PointLight` | Color (170, 255, 140) or (150, 200, 255), Range 10 |
| Streetlight cone | `SpotLight` in the lamp head, facing down | Color (235, 240, 255), Brightness 3, Range 45, Angle 110; shadows on 1 lamp in 4 |
| Under-bridge light | `SpotLight` under the deck | Color (255, 220, 170), Range 30 |
| Clinic cross sign | Green emissive cross + `PointLight` (120, 255, 140) | Range 12 |

Rule from the shots: **warm light on people and doors, cool light on roads.** That warm-cool split is the mood.

## 4. Surface map: every surface in the photos → our MaterialVariant

All names are in `realistic-kit/textures/texture-manifest.json` ([[40 Realistic Texture Library - Hood and Downtown]]). The batch added for these photos is tagged `"batch": "larp-2026-11-01"`.

| Surface in the photos | Shots | Use | Tint (part Color) |
|---|---|---|---|
| Dark main road asphalt | 142448, 142516, 142606 | `AsphaltDarkFresh`, `HoodAsphaltCracked`, `AsphaltDarkB` | (60, 62, 70) |
| Wide boulevard asphalt | 142419, 143504 | `AsphaltAerialWide` (30 m tile) | (70, 72, 80) |
| Broken / potholed road | 142034, 143345 | `HoodRoadPotholes`, `RoadDamagedB` | default |
| Road patches (dark with pale outline) | 142259, 142718, 143429 | `AsphaltTarPatch` on a thin part 0.05 studs above the road + a pale outline decal | (45, 45, 52) |
| Parking lot asphalt | 142023, 142845 | `ParkingLotAsphalt`, `ParkingLotStained` | teal tint (70, 85, 82) for the 142023 look |
| Pale stained sidewalk | 142034, 142112, 142438 | `SidewalkWornStained`, `SidewalkConcrete`, `HoodSidewalkCracked` | (200, 196, 205) |
| Concrete aprons, driveways | 142103, 142245 | `LotConcreteWorn`, `ConcreteDriveway` | default |
| Flood channel banks and floor | 142344, 142408, 142527 | `ChannelConcreteDirty`, `ChannelConcreteDamaged`, walls `ChannelWall` | (190, 185, 190) |
| Overpass deck / footbridge | 142516, 143000, 143504 | `OverpassConcrete`, sides `OverpassPrecast` | default |
| Board-formed concrete house | 142048 | `BoardFormedConcrete` | (150, 150, 160) |
| Concrete-block house | 142053 | `HoodCinderBlock`, `CinderBlockB` | (130, 125, 115) |
| Tan stucco block with grime | 142140 | `StuccoBeige`, `HoodStuccoWorn` | (200, 150, 115) |
| Pink mission facade / motel | 142133, 142845 | `StuccoPinkWeathered` | (215, 165, 155) |
| Blue strip mall | 142209 | `StuccoBlueWeathered` | (120, 160, 210) |
| Yellow shop | 143304 | `StuccoYellow` | (220, 200, 90) |
| White stucco shops and walls | 142119, 142147, 143429 | `StuccoWhite`, `HoodStuccoCracked`, `PlasterWorn` | (225, 225, 228) |
| Dark navy body shop | 142259, 142322 | `HoodPaintedConcrete` | (45, 60, 95) |
| Blue-grey painted brick alley | 142330, 142159 | `HoodPaintedBrick`, `HoodBrickDark` | (95, 105, 140) |
| Red brick walk-up | 142245, 143242 | `BrickRedClassic`, `DowntownBrickRed` | default |
| Stone veneer base | 142429 | `DowntownStoneBlocks` | (150, 145, 140) |
| White wood siding | 142112, 142546 | `WoodPaintedDistressed`, `SidingBlue` tinted white | (230, 230, 230) |
| Teal / navy low roofs | 142112, 142546, 142651 | `RoofSlatesDark`, `RoofShinglesGrey` | (40, 70, 90) |
| Roll-down shutters | 142048, 142159, 142209 | `ShutterRusty`, `ShutterRustedB`, `ShutterWorn`, `ShutterPainted` | green (60, 110, 90) or grey |
| Rusty awning band, billboard legs | 142159, 142209, 142147 | `RustCoarse`, `RustySheet`, `MetalPaintedRusty` | default |
| Dumpsters, utility boxes | 142330, 143429 | `DumpsterGreenRust` | (60, 110, 60) |
| Chain-link fence | 142112, 142913 | `ChainLinkFence` (alpha) on a thin part | default |
| Palm trunks | everywhere | `PalmBark`, `PalmBarkB` | default |
| Street tree trunks | 142516, 142606 | `SycamoreBark`, `EucalyptusBark` | default |
| Lawns / verges | 142606, 143109 | Terrain Grass with `LawnGrassA/B/C` + `MaterialService` override | — |
| Bare dirt in lots / under cars | 142606, 142801 | `ParkDirt`, `DryGround`, `DirtLot` | — |
| Dead leaves | 142053 | `LeafLitter`, `DryLeaves` decal patches | — |
| Beach | 143109 | `BeachSand`, `BeachSandB` | — |
| Water leaks / grime runs | 142140, 142034 | `DecalWaterLeak`, `DecalWaterLeakB/C/D` | — |
| Road paint | all intersections | Our own decals (§6); `DecalRoadSymbols`, `DecalRoadLinesWorn` for worn variants | — |
| Graffiti | 142119, 142133, 142344 | **Our own art only.** `DecalGraffitiSet` must be checked piece by piece first (kid-safe) | — |

## 5. Props and set dressing (the build list)

Make each once as a model in `ServerStorage/Kit` and reuse. Counts per block are what the photos show.

| Prop | Seen in | Per block | Build notes |
|---|---|---|---|
| Wall AC condenser | every shop and house | 1 per unit / 2-3 per house | One mesh, fan grille, rust streak decal below it, a cable run to the roof |
| Window grilles | 142053, 142140, 142546 | every ground window | One thin mesh grid, `Metal`, dark |
| Roll-down shutter | 142048, 142159, 142209 | every shop | A box with the shutter MaterialVariant; the roll housing on top |
| Security door with grille | 142053 | houses | Mesh door + grille |
| Rusty awning band | 142159, 142209 | strip malls | Long thin part, `RustCoarse` |
| Rooftop billboard | 142140, 142147, 142209, 143242 | 1 per 2 blocks | Rusty steel legs + catwalk; poster as a `SurfaceAppearance` with a peel mask. Our own ad art (made-up products), one fully peeled blank |
| Dumpster pair | 142330, 142853, 143429 | alleys, behind stores | Green rusted, our own stencil text ("DRY WASTE" style) |
| Wooden power pole + transformer can | 142507, 142546 | every 30-40 studs on hood streets | See [[36 Roads, Blocks and City Layout Kit]] §5 for sagging wires |
| Steel lattice pylon | 142419, 142448, 142718 | along one corridor | One big mesh, it is the skyline signature; wires with a gentle sag |
| Mast-arm traffic light | all intersections | 4 per intersection | Arm over the lanes, 3-light head, backplate |
| Cobra-head streetlight | 142501, 142950 | every 40 studs on main roads | SpotLight inside (§3) |
| Fire hydrant | 142245, 143242, 143304 | 1 per corner | Small mesh, red or yellow |
| Yellow bollards | 142950, 143000, 143504 | rows on medians, store fronts | Cylinders, worn yellow paint |
| Tactile strip (orange) | 142950, 143453, 143504 | every crosswalk end on the boulevard | Thin part with a dotted texture |
| Red curb paint | 142112, 142140, 142322 | near hydrants and corners | Separate thin part on the curb top |
| FOR SALE sign | 142606, 142651, 143000 | 1-2 per residential street | Post + sign, our own realtor name |
| Pickup on the lawn, parked sedans | 142209, 142606, 143242 | 2-4 per street | Realistic car meshes with `SurfaceAppearance` paint (reflections) |
| Vending machine, ATM | 142845, 143304, 143504 | store fronts | Emissive fronts at night |
| Bus shelter with metro sign | 143453 | boulevard | Long canopy, bench, our own transit logo |
| Gas station canopy | 142636 | 1 per district | Green canopy on black steel, pumps, ice box |
| Construction site | 142950, 143429 | 1 downtown | Concrete frame, scaffold, orange tarps, tower crane (great skyline piece) |
| Debris piles | 142344, 143345 | channel floor | A few broken planks and trash bags; keep it light |
| Chain-link fences | 142112, 142546, 142913 | front yards, lots | Alpha texture on thin parts, tall grass along the base |
| Tall grass clumps | 142048, 142801, 142913 | along every fence and wall base | Terrain grass + mesh clumps; hides seams |
| Seasonal props | 142053, 143504 | spread around | Pumpkins and leaves now (Halloween); swap per season |

## 6. Road paint kit (sizes in studs, 1 stud = 0.28 m)

| Marking | Real size | Studs | How |
|---|---|---|---|
| Crosswalk bars (zebra) | 0.5 m wide, 3 m long, 0.5 m gaps | 1.8 wide, 10.7 long, 1.8 gap | Thin parts, `SmoothPlastic` white + worn-edge decal, or one tiled texture per crosswalk (better: 1 part) |
| Stop bar | 0.4 m | 1.4 | One part across the lanes |
| Lane line | 0.12 m wide, dashed 3 m on / 9 m off | 0.45 wide, 10.7 / 32 | Dashed by texture on one long part |
| Yellow hatch box (142245, 143453) | stripes 0.5 m at 45° | 1.8 | One part with a hatch texture, tinted mustard (200, 160, 60) at 60% opacity so the asphalt shows through |
| Turn arrows | 5 m long | 18 | Decal with alpha on a thin part |
| Bike lane green box (143118) | lane width | 5.4 wide | Green (60, 160, 80), slightly faded |
| Parking bay | 2.5 × 5 m | 9 × 18 | White lines 0.4 studs wide |

Rules: paint parts sit 0.02-0.05 studs above the road (no z-fighting), `CanCollide = false`, `CastShadow = false`. Make paint a little **worn** (a grunge decal on top, or roughness up) so it does not look like plastic. One texture per crosswalk keeps part counts low on phones.

## 7. Sound for this world (what you would hear in these shots)

Prefer Roblox licensed library sounds (Creator Store, Roblox-made). Do not invent IDs; search, preview and paste. Build with the Audio API ([[39 Living World - Traffic, NPCs and Ambience]] §4).

| Layer | Where | How |
|---|---|---|
| City bed (distant traffic, faint wind) | everywhere, 2D | One looping AudioPlayer, volume low; swap day and night versions |
| Freeway hum | near overpasses (142516, 142527) | AudioEmitter on the bridge, rolloff 40-200 studs |
| Power-line buzz | under pylons (142448) | Emitter per pylon, quiet, short range |
| AC unit hum | shop walls | Emitter on 1 in 3 AC units, range 15 studs |
| Birds (day) / crickets (night) | trees, lots | Crossfade by ClockTime |
| Palm and tree rustle | palms | Tied to GlobalWind strength |
| Store hum + door chime | store doors | Chime on a ProximityPrompt trigger |
| Vending machine buzz | night (142845) | Small emitter, range 10 |
| Channel trickle | flood channel | Emitter along the floor |
| Distant dog bark, car horn | random one-shots | Every 30-90 s, random position 100-200 studs away |
| Footsteps by material | player | Asphalt, concrete, grass, metal, wood sets |

Keep everything smooth and soft (see [[09 Owner Taste Rules]] Sound): no harsh or long sounds.

## 8. Making the game feel the best it can (lessons from the shots)

What the reference does that we should match or beat:
1. **Minimal HUD:** money top right, one tool slot bottom centre, one menu button left. Everything else lives in the world (see [[30 UI and UX Playbook]]).
2. **Floating round icons over every job, shop and house** (142159, 142651): a `BillboardGui` per place with a small circular icon, `MaxDistance` ~300, fading in with distance. This is how a player finds things in a big realistic map without a cluttered map UI. Make ours prettier: soft shadow, gentle bob, scale on approach.
3. **Interactive NPC pedestrians** with a ProximityPrompt (142133 "Rob pedestrian" in theirs). **Ours must be kid-safe:** talk, ask for directions, give a delivery job, hand out a quest. Never robbery.
4. **Quest marker ring on the ground** (143242): a glowing ring decal at the target, pulsing. Pair with a soft chime.
5. **Parked cars everywhere,** some driving (ambient traffic, note 39). Realistic meshes with reflective paint are a huge part of "this looks real".
6. **Day-night cycle with moods:** 24-30 real minutes for a full day; night lasts shorter than day. Lights switch on at dusk with a stagger (not all at once).
7. **Seasonal dressing:** pumpkins and leaves in autumn (their Nov 1 build). Swap per season to keep returning players noticing changes.
8. **Character scale against the world:** default Roblox avatars stand ~5 studs; doors 7-8 studs, kerbs 0.6 studs, lanes 13 studs. Wrong scale breaks realism faster than textures ([[36 Roads, Blocks and City Layout Kit]] §1).
9. **Camera:** default third-person, FOV 70, slightly lower camera offset for street-level drama; smooth zoom. Shoot thumbnails at golden hour and blue hour ([[28 Camera Playbook]]).
10. **Movement:** walk 12-14, jog 16-18 (sprint with a short stamina bar for RP feel). Footstep sounds by material. Small camera bob only while sprinting.
11. **Performance on phones** ([[38 Mesh Pipeline, LOD and Mobile Budgets]]): StreamingEnabled, one texture per crosswalk, props as reused meshes, local lights culled by distance, shadows only on hero lights. A beautiful map that stutters feels worse than a plain one.
12. **Polish beats:** money counter rolls up with a soft tick, doors open with a short creak, shops have a 0.2 s chime, interiors have one warm light each. See [[14 Premium Feel Playbook]] and [[06 Beat the Hits - Polish Playbook]].

## 9. Do not copy (and kid-safe)

- **Their names and logos stay theirs:** the store names, cola brand, jewelry store, auto shop, logo on the clothing store, the "binco"-style sign. Make our own (for example a corner store "Sunny Mart", a cola "Fizz Up"). Graffiti must be our own original pieces.
- **No weapon shop** ("Ammo City" in 142429), no robbery prompts, no gang tags or colours, no drug imagery.
- **Their layout and UI art are not ours.** We copy the look (wear, light, clutter), not their map.

## Sources
- Alex's 49 screenshots, Nov 1 2026 (`references/larp/`, project file `Larp Photos.zip`).
- Colour samples measured from those shots (§3 table).
- Textures: Poly Haven and ambientCG (CC0), listed in `realistic-kit/textures/texture-manifest.json`.
- Lighting properties and preset structure: [[34 Realistic Lighting and Atmosphere]] and its sources.
