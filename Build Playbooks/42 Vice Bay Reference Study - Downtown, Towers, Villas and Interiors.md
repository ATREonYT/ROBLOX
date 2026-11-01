---
tags: [build-playbooks, realistic, references, downtown, interiors, villa, tower, lighting, rp]
updated: 2026-11-01
---

# 42 Vice Bay Reference Study - Downtown, Towers, Villas and Interiors

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Street-level hood study: [[41 Larp Reference Study - Atmosphere, Surfaces and Feel]] · Lighting base: [[34 Realistic Lighting and Atmosphere]] · Textures: [[40 Realistic Texture Library - Hood and Downtown]] · Meshes and budgets: [[38 Mesh Pipeline, LOD and Mobile Budgets]]

Alex sent `Vice Bay References.zip` on Nov 1, 2026 (165 pictures in 6 folders). Every file opened fine. 107 were repeats of what the vault already had, and **57 are new references**, saved at `references/vice-bay/` (1280 px copies).

| Folder in the zip | Files | What it is | New? |
|---|---|---|---|
| `larp/` | 49 | The Larp photos | Already in the vault ([[41 Larp Reference Study - Atmosphere, Surfaces and Feel]]) |
| `larp_chat/` | 50 | The same Larp photos again, plus 1 new: a tower with neon rings | 1 new (`neon-tower-chat_50.jpg`) |
| `earlier/` | 20 | 8 are the first reference shots (hood-01..03, coast-01..05); 2 Miami-style RP night shots with a car HUD; 9 penthouse interiors; 1 Studio error dialog | 11 new (error dialog skipped) |
| `city/` | 16 | LA-style downtown at day and sunset, plus a Roblox RP gas-station tutorial shot | 15 new (1 repeat of Larp 142034) |
| `tower/` | 10 | A modern corporate tower: lobby, security gates, terrace, reception, elevators | 10 new |
| `house/` | 20 | A modern villa: stone-and-white exterior, pool deck, kitchen, living, bedrooms | 20 new |

> **TL;DR**
> - **Four new looks the vault did not have yet:** sunset downtown (LA arts district), a glass corporate tower, a modern luxury villa with a pool, and dark realistic interiors lit by daylight.
> - **Sunset downtown = orange horizon, lit windows, dark streets.** The sky does the colour; the ground goes nearly black; warm windows and shop signs carry the scene. Preset in §3.
> - **Interiors look real when they are darker than outside.** Light comes through the glass as hard sun shafts with plant shadows. Lower interior ambient when the player walks in (§4).
> - **Luxury reads through materials:** black and white marble, wood veneer, stacked stone, brushed steel, PBR fabric, pool mosaic. 27 matching textures added (library now **179**).
> - **Murals, street-name signs, bus shelters, a parking garage and a plaza** make downtown feel like a real city, not a grid of boxes.
> - **The tower, villa and penthouse shots are other creators' showcase builds** (gallery arrows, "HARMONY TECH" watermark, "EXPAT." logo). Study them; never copy them or use leaked models. Buy a licensed Creator Store model only when its licence allows it, and that is Alex's call.
> - **Kid-safe:** the RP gas-station shot has a "Buy your first gun!" tutorial. We borrow the onboarding arrows, not the gun shop.

---

## 1. Downtown city (city_01 to city_15)

| Shot | What to study |
|---|---|
| city_01, city_02 | Freeway and rail viaduct on round concrete piers with graffiti along the girder; an art-deco concrete bridge with pylons and balustrades; lattice pylons; flat warehouse roofs full of HVAC boxes; the skyline fading into haze. (High-end render, maybe not Roblox: a target, not a promise) |
| city_03 | Rooftop panorama: brick warehouses, a rooftop billboard frame, rail yard, skyline. Streaky cirrus sky |
| city_04 | Under the freeway: huge deck with beams, rows of fluorescent tube lights, round piers, parked cars, yellow centre lines, loading doors, boxes, cones |
| city_05 | Sunset plaza from above: stepped plaza with palms, red accent ramps, a fountain, warm lamp dots, a bus, towers with lit windows, cranes |
| city_06 | Sunset parking lot: red-brick apartments with fire escapes, lit windows, murals, a glowing LED billboard, power poles, an overpass; ground nearly black |
| city_07 | Blue-hour downtown street: a huge portrait mural on a building side, a mosaic mural, stone office blocks with lit windows, blue street-name signs on mast arms, "BUS ONLY" lane text, bus shelter, newsstands |
| city_08 | Brick apartment corner with fire escapes, mural shop, pink-lit shop windows, wooden poles with many crossarms, double yellow centre line |
| city_09 | Art-deco clock tower on a brick block, patterned tile facade, outdoor dining with umbrellas, warm interiors, lit cobra-head streetlights |
| city_10 | Day: a downtown plaza with palms, red-pink concrete ramps and steps, a bus, a parking structure, the skyline |
| city_12 | Day: road beside a graffiti channel wall with a white tube railing, delivery van, brick warehouse, bike lane, shops with awnings |
| city_13 | Day: open parking garage (concrete decks, grey bands, a blue base with a mural and LOVE lettering), mast-arm signals with street-name signs |
| city_14 | Day: a white honeycomb-panel museum with a round canopy, red curb, bus stop, bike racks, newsstands, a mural on a far wall |
| city_15 | A 10-storey brick block with ground-floor cafes, a plaza with umbrellas, planters and trees, a steel diagrid canopy |
| city-game_gas_station | A Roblox RP game: chevron arrows on the road leading to a shop, left-side buttons (Shop, Crews, Invite, Teams), money and health bars, a floating JOB icon, purple-pink fog. **Gun tutorial: we never copy that** |

What makes downtown work (rules to build by):
1. **Every big blank wall gets a mural.** Murals are the cheapest way to make a city feel real and owned (city_07, city_08, city_13, city_14). Use our own art only: original portraits, patterns, our own brand names.
2. **Street furniture at every corner:** blue street-name signs on the signal mast arm, a bus shelter, newsstands, bins, bike racks, hydrants, red curbs.
3. **Vertical layers:** freeway decks, rail viaducts, footbridges and parking garages give height and shade. Under-deck spaces with fluorescent tubes (city_04) are great RP spots.
4. **Fire escapes on brick walk-ups** (city_06, city_08): one zig-zag mesh reused on every brick block.
5. **Lit windows at dusk:** a random 30-50% of windows glow warm. Use an emissive window mask in `SurfaceAppearance` (one mesh facade) rather than one Neon part per window.
6. **Landmarks:** a clock tower, a museum with an odd facade, a plaza, a tower with neon rings (`neon-tower-chat_50`). Players navigate by landmarks.
7. **Unbuilt towers as black boxes** (city_10, city_13) show how real builders block out first. Same as our golden-slice rule: block out, then replace.

## 2. Tower, villa and penthouse showcases (what luxury looks like)

### Corporate tower (tower_01 to tower_10)
- **Facade:** dark glass curtain wall with thin mullions and vertical fins, cantilevered podium floors with dark metal fascia, a taller angled tower above, and a round glass annex. Shot from below against a big sky (tower_05) for scale.
- **Entrance:** a white-roof guard kiosk, a vehicle barrier arm, bollards, cones and yellow-black tape, grey pavers, a landscaped strip, big logo letters.
- **Lobby:** black marble columns, pale polished stone floor, speed-gate turnstiles, a security arch with a folding table, glass walls, recessed downlights.
- **Upstairs:** a rooftop terrace with a white louvred pergola and warm cube lanterns; a lounge with grey sofas and a glass table; a reception desk of granite on black marble in front of wood-vein stone walls with vertical LED strips; brushed-steel elevator doors under an LED cove.
- **For RP:** a tower is a job hub (office jobs, security guard, receptionist). Gates and turnstiles make doors that open with a job badge.

### Modern villa (house_01 to house_20)
- **Exterior:** white flat roof slabs that overhang, rough stacked-stone walls and columns, a tall dark plank front door, black louvre screens, floor-to-ceiling glass, solar panels and AC units on the roof.
- **Garden:** an infinity pool with dark mosaic coping, wooden decks, white outdoor sofas, orange dining chairs, dark green shade sails, a slatted pergola casting stripe shadows, boulders, hedges in stone planters, bollard lights, lawn, a white wood fence.
- **Inside:** sage-green kitchen cabinets with copper pendant lamps and a green glossy mosaic backsplash; a faceted wood 3D wall panel; rattan pendants; hanging pothos plants; green velvet curtains; linen bedding with real folds; a black-grid glass shower; a freestanding green tub.
- **Why it reads expensive:** few colours (white, stone grey, warm wood, one accent green), big clean planes, and real material detail up close.

### Penthouse interiors (penthouse-ref_12 to ref_20, "HARMONY TECH" showcase)
- **The room is dark, the window is bright.** Interior shade is near black (#101010 to #484439 in the samples) while the ocean view is pale grey. That exposure gap is what makes it photographic.
- **Hard sun shafts** fall across wood floors and rough plaster walls, with plant shadows. The light source is the sun through glass, not a ceiling lamp.
- **Materials:** rough dark plaster, strong-grain warm wood floors, white marble waterfall island, black metal stair and rails, monochrome art.

### Miami-style RP at night (miami-night-ref_02, ref_03)
- Wide boulevards with **red bike lanes**, grassy medians, palms, cream mid-rise buildings with arches.
- Night is a clean dark navy with **warm lamp pools** on the road (no fog), traffic lights glowing.
- HUD to learn from: a top icon bar (car, phone, shop, gifts, settings), an in-game clock (08:33 PM), money ($1.29M), and a **car dashboard** at the bottom (fuel %, gear, MPH, TCS/ABS lights, indicators, a parking-brake hint). See §6.

## 3. Lighting presets from these shots

Colours sampled from the pictures (sky band at 10-16% height, horizon at 30-34%, ground at 80-90%):

| Shot | Sky top | Horizon | Ground |
|---|---|---|---|
| city_06 sunset lot | #c6bcc2 | #d9b99b | #0a080b |
| city_07 blue hour | #868395 | #756869 | #181319 |
| city_09 dusk | #423845 | #33242b | #2a1f21 |
| city_10 day | #9ba4ac | #888c8e | #403d3e |
| city_14 bright day | #d8ccc2 | #d5c5b4 | #786960 |
| house_18 villa evening | #c4c7cb | #535a60 | #8da2a5 (pool) |
| miami-night-ref_03 | #1e2024 | #322d30 | #252229 |
| penthouse-ref_12 interior | #101010 | #1c1c19 | #484439 |

Add these to the `P` table in [[34 Realistic Lighting and Atmosphere]] §3, next to the Larp presets from note 41. **Sketch, not yet run in Studio**: tune side by side with the shots.

```lua
	SunsetDowntown = { -- city_06, city_07, city_08
		ClockTime = 18.35, Latitude = 34, Brightness = 1.6, Exposure = 0.1,
		Ambient = Color3.fromRGB(40, 34, 44), Outdoor = Color3.fromRGB(95, 85, 110),
		Top = Color3.fromRGB(255, 190, 140), Bottom = Color3.fromRGB(30, 20, 30),
		Soft = 0.2, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.32, Offset = 0.2, Color = Color3.fromRGB(220, 175, 150), Decay = Color3.fromRGB(110, 100, 140), Glare = 4, Haze = 1.8 },
		CC = { Brightness = 0, Contrast = 0.12, Saturation = 0.05, Tint = Color3.fromRGB(255, 238, 230) },
		Bloom = { Intensity = 0.7, Size = 30, Threshold = 1.15 },
		Rays = { Intensity = 0.1, Spread = 0.7 },
		Clouds = { Cover = 0.35, Density = 0.5 },
	},
	VillaGoldenHour = { -- house_16, house_18, house_19
		ClockTime = 17.6, Latitude = 30, Brightness = 2.4, Exposure = 0,
		Ambient = Color3.fromRGB(70, 66, 70), Outdoor = Color3.fromRGB(140, 140, 150),
		Top = Color3.fromRGB(255, 220, 180), Bottom = Color3.fromRGB(50, 45, 40),
		Soft = 0.12, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(200, 200, 205), Decay = Color3.fromRGB(120, 130, 150), Glare = 1.5, Haze = 1.4 },
		CC = { Brightness = 0, Contrast = 0.08, Saturation = 0.02, Tint = Color3.fromRGB(255, 246, 236) },
		Bloom = { Intensity = 0.4, Size = 26, Threshold = 1.5 },
		Rays = { Intensity = 0.08, Spread = 0.6 },
		Clouds = { Cover = 0.3, Density = 0.5 },
	},
	MiamiClearNight = { -- miami-night-ref_02, ref_03
		ClockTime = 21, Latitude = 26, Brightness = 0.5, Exposure = 0.25,
		Ambient = Color3.fromRGB(22, 24, 34), Outdoor = Color3.fromRGB(50, 56, 80),
		Top = Color3.fromRGB(170, 185, 255), Bottom = Color3.fromRGB(10, 10, 18),
		Soft = 0.2, Diffuse = 0.8, Specular = 1,
		Atmo = { Density = 0.28, Offset = 0, Color = Color3.fromRGB(50, 50, 62), Decay = Color3.fromRGB(28, 30, 42), Glare = 0, Haze = 1 },
		CC = { Brightness = 0, Contrast = 0.1, Saturation = -0.05, Tint = Color3.fromRGB(235, 238, 255) },
		Bloom = { Intensity = 0.8, Size = 30, Threshold = 1.05 },
		Rays = { Intensity = 0, Spread = 0.5 },
		Clouds = { Cover = 0.2, Density = 0.4 },
	},
```

Tuning notes:
- **SunsetDowntown:** the sun sits just above the horizon behind the buildings, so streets fall into shade. If the ground looks muddy rather than dark, lower `OutdoorAmbient`; if the sky is not orange enough, raise `Atmosphere.Glare` and `Haze` before changing colours. Turn on window glow and shop signs at this preset.
- **MiamiClearNight** is the opposite of Larp's foggy night: thin atmosphere, black sky, and the lamp pools do all the work. Pick one night look per map, or use clear nights by default and foggy nights as a weather event.

## 4. Realistic interiors (what the penthouse and villa teach)

1. **Interiors are darker than outside.** When a player enters a building, tween the client's lighting to an "indoor" state over 0.5 s: lower `Ambient` and `OutdoorAmbient` (for example to 30 % of outdoor) and raise `ExposureCompensation` a little (+0.3) so the window stays bright. Trigger it with a zone part per interior. Tween back on exit. **Sketch, not yet run in Studio.**
2. **Let the sun in.** With `PrioritizeLightingQuality` on, sun shadows through window frames and plants are what sell the room. Put windows on the sun side and use real plant meshes near them.
3. **Few lamps, warm, shadows on the hero lamp only.** One warm `PointLight` or `SpotLight` per room (2700 K, Color 255, 200, 150), shadows on only the main one.
4. **Glass:** `Glass` material, Transparency 0.6-0.75, Reflectance 0.1-0.2, a thin dark frame. Curtain walls on towers are one mesh with a window-grid texture (`DowntownGlassFacadeA/B`), not hundreds of parts.
5. **Materials do the luxury:** marble (white veined for islands, black for columns), wood veneer walls, brushed steel doors, PBR fabric on sofas and beds, rugs. Use the interior textures in §5.
6. **Clutter with intent:** books, plants, vases, art, a throw on the sofa, towels. Interiors without small props look like showrooms; with them they look lived in.
7. **Budget:** interiors are the most expensive part on phones. Stream them (`ModelStreamingMode = Atomic` per interior model), keep them small, and only fully furnish hero interiors (player houses, the tower lobby). See [[38 Mesh Pipeline, LOD and Mobile Budgets]].

## 5. Textures added for these shots (27, batch `vicebay-2026-11-01`)

All CC0, full PBR sets at 1024 px, listed in `realistic-kit/textures/texture-manifest.json` and [[40 Realistic Texture Library - Hood and Downtown]].

| Surface in the shots | Variant |
|---|---|
| Villa stacked-stone walls and columns (house_01-03) | `VillaStackedSlate`, `VillaFieldstone`, `PlasteredStoneWall` |
| Pool deck, patio stone | `PatioStoneTiles`, `TravertineBeige`, `DeckPlanks` |
| Pool mosaic (house_16-19), shower mosaic (house_14) | `PoolMosaicBlue`, `PoolMosaicCyan`, `PoolMosaicBlack` |
| Penthouse and apartment floors (ref_16-20) | `InteriorLaminate`, `InteriorOakPlanks`, `InteriorParquet`, `WoodFloorClean`, `WoodFloorDarkParquet`, `WoodFloorPlanks` |
| Kitchen island, lobby floor (ref_16, tower_02) | `MarbleWhiteVeined`, `MarbleFloorTiles`, `OnyxWhite` |
| Lobby columns, reception base (tower_02, tower_09) | `MarbleBlackShiny`, `MarbleDarkGrey` |
| Sofas, bedding, curtains, office carpet | `FabricGreyCloth`, `FabricFineGrey`, `CarpetBeige` |
| Ceilings, white brick, polished concrete | `CeilingInterior`, `WhiteBrickInterior`, `PolishedConcreteFloor` |
| Tower podium and parking garage concrete (city_13) | `ConcreteWallTower` |

Already in the library and useful here: `DowntownGlassFacadeA/B`, `DowntownTowerWindowsNight` (lit windows), `DowntownBrickRed`, `BrickRedClassic` (walk-ups), `LobbyMarble`, `OverpassConcrete` and `OverpassPrecast` (viaducts), `ChannelWall` (city_12).

**Not uploaded yet:** these 27 still need the same download → upload → build pass as the first 152 (the Mac script handles it). Until then they exist only as links in the manifest.

## 6. Game feel ideas from these shots

- **Onboarding arrows on the road** (city-game_gas_station): a chain of chevrons from the spawn to the first goal, with a one-line task and a SKIP button. Ours point to a first job or the car dealer, never a weapon.
- **Car HUD** (miami-night-ref_02/03): speed in MPH, gear, fuel %, indicator arrows, a parking-brake hint ("Press P"). Small, bottom centre, only while driving.
- **In-game clock and money at the top**, with the day-night cycle. The clock makes night events (shop hours, street lights) readable.
- **Phone** as the main menu (jobs, map, messages, settings) fits RP better than a wall of buttons ([[30 UI and UX Playbook]]).
- **Job hubs in landmarks:** the tower (office, security), the parking garage (valet), the plaza (food stand), the villa district (pool cleaner, gardener). Every landmark should have a reason to visit.
- **Kid-safe:** no guns, no robbery. "Crews" are friend groups with colours we pick (never gang colours or names).

## 7. Do not copy

- The tower, villa and penthouse sets are other creators' paid or showcase builds ("EXPAT." logo, "HARMONY TECH" watermark, gallery arrows). Study the ideas; model our own. Never use leaked or ripped models.
- Their store names, logos, murals and street names stay theirs. Our streets get our own names; our murals are our own art.

## Sources
- Alex's `Vice Bay References.zip`, Nov 1, 2026 (new shots saved in `references/vice-bay/`).
- Colour samples measured from those shots (§3).
- Textures: Poly Haven and ambientCG (CC0), listed in the texture manifest.
