---
tags: [build-playbooks, realistic, world-building, roleplay, maps, hood, city, coastal-town, start-here]
updated: 2026-11-01
---

# 33 Realistic World Building Playbook

Back to [[00 Build Router]] · RP game design: [[26 Fun and Roleplay Playbook]], [[Blueprint - Roleplay Town]] · Map layout basics: [[10 Map Design Playbook]] · References: [[References - Realistic Worlds]]

**Start here for any realistic map:** a hood or city block, a coastal town, a highway, an RP city. This note is the hub. It gives the process from empty baseplate to a finished map, how to read a realistic reference, and the critic sheet. The deep "how" lives in six companion notes:

| Craft | Note |
|---|---|
| Lighting, atmosphere, post effects, presets with code | [[34 Realistic Lighting and Atmosphere]] |
| PBR materials, MaterialVariants, decals, wear and graffiti | [[35 Realistic Materials, Decals and Wear]] |
| Roads, sidewalks, intersections, city blocks, modular kits | [[36 Roads, Blocks and City Layout Kit]] |
| Terrain, water, foliage, palms and wind | [[37 Terrain, Water and Foliage]] |
| Blender to Roblox, LODs, streaming, phone budgets | [[38 Mesh Pipeline, LOD and Mobile Budgets]] |
| Traffic, pedestrians, ambience sound, day and night | [[39 Living World - Traffic, NPCs and Ambience]] |
| The texture library (152 CC0 textures) with install scripts | [[40 Realistic Texture Library - Hood and Downtown]] |
| Alex's Larp photos decoded: measured presets, surface map, props, road paint, sound, feel | [[41 Larp Reference Study - Atmosphere, Surfaces and Feel]] |

Skill to load before building: `.claude/skills/roblox-realistic-building/SKILL.md`.

> **The one-paragraph version.** Realistic Roblox maps don't look real because of high-poly models. They look real because of **five layers stacked on simple shapes**: (1) Realistic lighting with a warm sun, cool shade and a hazy atmosphere that fades distance; (2) tiled PBR materials at the right real-world scale; (3) a wear layer of patches, cracks, stains, tyre marks and graffiti that breaks every repeat; (4) dense, varied plants at three heights that sway in the wind; (5) life: parked and moving cars, people, power lines, sound. Build the layers in that order on a blockout that already plays well, and budget for phones from day one.

---

## 1. What Alex's references show (read them before building)

Eight screenshots saved on 2026-11-01 in `Build Playbooks/references/realistic-worlds/`. Two families: a **sunny West Coast hood** (3 shots) and a **humid coastal Florida town** (5 shots). What each one teaches, in our words:

### 1.1 Hood family (hood-01 to hood-03)

![[Build Playbooks/references/realistic-worlds/hood-01-parking-lot-graffiti.jpg|600]]
![[Build Playbooks/references/realistic-worlds/hood-02-patched-street-and-canal.jpg|600]]
![[Build Playbooks/references/realistic-worlds/hood-03-intersection-storefronts.jpg|600]]

- **Asphalt is never one colour.** Large rectangular **patch decals** with a lighter, ragged border sit on darker asphalt. They're placed where real road crews cut: over utility lines, at lane centres, in front of driveways. This is the single biggest "real" signal in the hood shots. See [[35 Realistic Materials, Decals and Wear]] §4.
- **Concrete is mottled.** Sidewalks and walls carry big, soft, blotchy stains (water runoff, sun bleach), not small noise. The stain scale is large: 5 to 20 studs per blotch.
- **Graffiti is on walls people can reach,** at ground level and on the canal wall, in bright colours against faded paint. The tags are the most saturated thing in the scene.
- **Ground floors are busy, upper floors are plain.** Roll-up shutters, barred windows, AC boxes, rusted awning trims at street level; plain plaster above.
- **Palms and power lines carry the skyline.** Tall thin palms poke above flat roofs, and sagging wires cross every street. Both are cheap and both read "Southern California" instantly.
- **Kerbs are painted** (red no-parking strips), crosswalks are bold white bars, and a big yellow hatch box fills the intersection. Markings are crisp; the road under them is dirty. That contrast is what reads.
- **Rusty hydrants and trash** sit at kerb edges. Props are few but heavy and textured.
- **The HUD floats in the world:** round dark icon badges (job, shop, bank, hospital, petrol) hover over each place. That's a world-space wayfinding layer, see §6.
- **Lighting:** low warm sun, strong long shadows, light haze; overall slightly desaturated and warm. Shadows are sharp but not black.

### 1.2 Coastal family (coast-01 to coast-05)

![[Build Playbooks/references/realistic-worlds/coast-01-fire-station.jpg|600]]
![[Build Playbooks/references/realistic-worlds/coast-02-road-palms-barrier.jpg|600]]
![[Build Playbooks/references/realistic-worlds/coast-03-winding-road.jpg|600]]
![[Build Playbooks/references/realistic-worlds/coast-04-town-aerial-haze.jpg|600]]
![[Build Playbooks/references/realistic-worlds/coast-05-bridge-water-jetty.jpg|600]]

- **Foliage is the hero.** Dense dark-green bushes cover every gap; mid-height leafy trees break the line; tall leaning palms tower over everything. Three heights, everywhere. No bare ground shows.
- **Thick humid haze.** Atmosphere density is high, so the far town fades to a grey-green wall. This hides the map edge and makes the world feel huge. It's the opposite of the cartoony rule (Density 0.35).
- **Clean modern asphalt** with crisp double-yellow centre lines that curve smoothly. Roads follow splines, with concrete jersey barriers on the water side.
- **Buildings are believable types:** a brick-and-siding fire station with glass bay doors and wall lights, pastel stilt houses, flat-roof strip malls, a red two-storey shop. Each has one strong material contrast (brick vs siding, red vs white trim).
- **Shallow turquoise water** with rock breakwaters, channel markers (red and green), a wrecked boat, a pier restaurant and a long concrete bridge on piers. Props in the water sell the water.
- **Small real signs:** "35" speed limit signs, blank sign backs, painted bay hatching. Signs are the cheapest storytelling.
- **Lighting:** overcast-bright sky, soft sun, high ambient, wall lights glowing at dusk, gentle bloom on the white lights only.

**What to take, not copy:** the five-layer recipe, the scale of the wear, the density of foliage, the haze strategy, the believable building types. Make our own buildings, signs, names, textures and layout. (Project rule: learn polish from hits, bring our own look.)

---

## 2. Pick the realism level first (day 1)

| Level | Looks like | Lighting | Materials | Phone cost | Use for |
|---|---|---|---|---|---|
| **A. Stylised PBR** | Clean, soft, slightly toy-like | `Realistic` + light haze | Built-in materials + a few MaterialVariants, flat colours | Low | Kid RP towns that need 50 players on phones |
| **B. RP realistic** (Alex's references) | Believable street, dirty and lived-in | `Realistic`, warm sun, haze, Bloom/SunRays/CC | A full MaterialVariant library, SurfaceAppearance on hero props, a decal wear layer | Medium | Our target for the RP city |
| **C. Showcase photoreal** | Screenshot-only beauty | `Realistic`, DOF, heavy post | 1K-2K PBR on everything, custom meshes everywhere | High | Trailers and thumbnails, not gameplay maps |

**Default: level B on the street, level A for anything far away.** Build the street level at B, let the distance fall back to A through haze and simpler far meshes. Ship a graphics toggle (see [[34 Realistic Lighting and Atmosphere]] §6) so low-end phones can drop to A.

**Kid-safe "hood" framing (must pass, Alex's games are for kids):** a worn city neighbourhood is fine. Keep it to architecture and wear: graffiti art and tags, cracked roads, shutters, chain-link. **No** gang names or signs, drug references, real-world crime iconography, weapons painted on walls, or slurs in graffiti. Write all graffiti and shop signs ourselves. Check the Maturity questionnaire answers in [[Blueprint - Roleplay Town]] §0 before publishing.

---

## 3. The process, blockout to final (the order matters)

Each step ends with a screenshot from the **same 4 fixed cameras** (street level, kerb level, rooftop, aerial), saved to `<game>/previews/map-steps/`. Never skip ahead: wear on a bad layout is wasted work.

| # | Step | Done when | Time for one block |
|---|---|---|---|
| 0 | **Reference board.** Collect 10–20 real photos (Google Street View of the real place type) plus Alex's shots. Write a 3-line look brief: region, era, mood, time of day. | Brief agreed | 30 min |
| 1 | **Blockout.** Grey parts on a 4-stud grid: road widths, block sizes, building masses, spawn, jobs, garages. Play it on foot and in a car. | Drive and walk feels right; every job reachable in under 30 s by car | 2–4 h |
| 2 | **Lighting first pass.** Pick the preset ([[34 Realistic Lighting and Atmosphere]] §3). Everything after is judged under this light. | Grey blockout already looks moody | 15 min |
| 3 | **Kit pass.** Swap grey parts for kit pieces: road tiles, kerbs, sidewalk tiles, facade modules, roofs ([[36 Roads, Blocks and City Layout Kit]]). | No grey parts left on the street | 1–2 days |
| 4 | **Material pass.** Apply the MaterialVariant library; set StudsPerTile from real sizes ([[35 Realistic Materials, Decals and Wear]] §2). | No surface looks stretched or tiny | 2–4 h |
| 5 | **Wear pass.** Patches, cracks, stains, tyre marks, kerb paint, graffiti, grime at wall bottoms ([[35 Realistic Materials, Decals and Wear]] §4). | No 20×20-stud area is one clean colour | 1 day |
| 6 | **Foliage pass.** Ground cover, shrubs, mid trees, palms, wind ([[37 Terrain, Water and Foliage]]). | No bare dirt; skyline broken by trees | 1 day |
| 7 | **Set dressing.** Street furniture, utility poles and wires, signs, rooftop clutter, alley junk ([[36 Roads, Blocks and City Layout Kit]] §7). | Every corner tells a tiny story | 1 day |
| 8 | **Life pass.** Parked cars, traffic, pedestrians, ambience layers, day/night ([[39 Living World - Traffic, NPCs and Ambience]]). | Standing still for 10 s, something moves and something sounds | 1 day |
| 9 | **Lighting final.** Local lights (streetlights, wall packs, shop glow), dusk and night check, post effects. | Night is as readable as day | 2–4 h |
| 10 | **Performance pass.** Phone budget check ([[38 Mesh Pipeline, LOD and Mobile Budgets]] §5): draw calls, memory, frame time on a low-end phone. | 30+ fps on the low-end test phone at quality 1 | 2–4 h |
| 11 | **Fresh critic.** A new agent scores the 4 cameras against the reference with §8 below. Fix the worst three gaps. | Score ≥ 8/10 on each row | 1 h |

**Golden slice rule (repo rule 1):** do steps 0–11 on **one intersection and one block face** first and show Alex. Only then roll the kit out to the city.

---

## 4. Composition rules that make realistic maps read

1. **Big, medium, small.** Every view needs one big shape (a building, a bridge), several medium (trees, cars, poles), and lots of small (signs, cones, trash). Realistic maps fail when they're all medium.
2. **Value structure beats detail.** Squint at the screenshot: there should be a clear light area, mid, and dark. Dark shade under trees, mid road, bright sky and sunlit walls. If everything is mid-grey, fix lighting before adding detail.
3. **Contrast where the player looks.** Saturated colour (graffiti, a shop sign, a red fire station) goes on the things that matter; everything else stays muted. A realistic palette is about 80% desaturated.
4. **Break every straight line.** Roofs get AC units and tanks; kerbs get patches; walls get stains; tree lines get a taller palm every so often. Long, clean, straight edges scream "game".
5. **Edges of the world disappear into haze, terrain or trees,** never into a wall or void. Coastal: haze plus water. City: haze plus taller far blocks (cheap boxes with window textures).
6. **Every surface has a reason for its wear.** Stains under windows and AC drips, tyre marks at turns, patches over utility lines, worn paint where feet go, moss on the shaded side. Random wear looks fake; reasoned wear looks real.
7. **Repeat with variation.** Use one facade module 10 times, but change colour, signage, awnings and wear on each. Players see the change, the engine sees the same mesh (cheap).
8. **Leave breathing room.** Dense detail at the street, calmer upper floors, open sky. Real streets have quiet zones. Clutter everywhere feels abandoned (a real DevForum critique of a hood map: "too much trash and abandoned cars makes it feel like nobody lives there").
9. **Scale is sacred.** Doors 7–8 studs tall, storeys 10–12 studs, kerbs 0.5–0.7 studs, cars ~16 studs long. Wrong scale ruins realism faster than anything (numbers in [[36 Roads, Blocks and City Layout Kit]] §1).
10. **Motion and sound are part of the look.** A still, silent city looks like a screenshot. Wind on plants, cars, birds, a far siren (see [[39 Living World - Traffic, NPCs and Ambience]]).

---

## 5. Two ready look recipes

### 5.1 "Sunny West Coast hood" (like hood-01 to 03)
- Lighting: preset **Sunny Afternoon** ([[34 Realistic Lighting and Atmosphere]] §3.1), ClockTime 15.5–16.5.
- Palette: sand-pink plaster, pale blue-grey stucco, sun-faded mint, rust orange, dark grey asphalt.
- Materials: `AsphaltWorn`, `AsphaltPatched`, `ConcreteSidewalkTile`, `StuccoPaintedFaded`, `BrickPainted`, `MetalShutterCorrugated`, `ChainLink`.
- Wear: patch decals every 15–30 studs of road, stains on every wall bottom, graffiti on 1 in 3 ground walls and the canal.
- Plants: palms (tall, thin, slightly leaning), a few broad shade trees, dry grass tufts in cracks and lots.
- Props: power poles every 40–60 studs with sagging wires, AC boxes, roll-up shutters, barred windows, rusty hydrants, chain-link, a concrete flood channel.
- Sound: far freeway rumble bed, occasional car pass, dog bark, distant siren every 2–4 min, wind in palms.

### 5.2 "Humid coastal town" (like coast-01 to 05)
- Lighting: preset **Humid Coastal Overcast** ([[34 Realistic Lighting and Atmosphere]] §3.2), heavy haze.
- Palette: deep greens, pale grey asphalt, white trim, pastel yellows and blues, red brick, turquoise water.
- Materials: `AsphaltClean`, `ConcreteBarrier`, `BrickRed`, `SidingPainted`, `RoofShingleGrey`, `SandWet`, `RockCoastal`.
- Wear: light. Water streaks under barrier tops, moss on the shaded side, sand drifts at kerbs.
- Plants: very dense bushes (the hero), palms in loose rows, broad-leaf trees in between.
- Water: shallow turquoise terrain water with rock breakwaters, channel markers, a pier, a wreck.
- Sound: gulls, distant surf, cicadas or insects, palm rustle, a boat horn every few minutes.

---

## 6. The world-space icon HUD (seen in hood-01 to 03)

The references float round icon badges above every job, shop and service. For an RP city this is the best wayfinding there is:
- A `BillboardGui` per place, `AlwaysOnTop = true`, `LightInfluence = 0`, size in **scale units** so it stays a fixed screen size, `MaxDistance` 400–600.
- Dark round badge, white outline, a coloured pictogram (our own icons, never emoji, per [[09 Owner Taste Rules]]).
- Fade badges that overlap the screen centre so they don't hide the road; hide badges whose place is behind the camera.
- Show only the categories the player needs right now (a job filter), or the sky fills with icons.
- Full build notes for UI: [[30 UI and UX Playbook]].

---

## 7. Symptoms → fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| "Looks like Roblox, not real" | Default lighting or `Soft` style | Apply a preset; `LightingStyle = Realistic`; EnvironmentDiffuse/Specular 1 |
| Everything looks plastic | Built-in materials at default tiling, no roughness variety | MaterialVariant library with real roughness maps; [[35 Realistic Materials, Decals and Wear]] §2 |
| Roads look like a texture tile | One material, visible repeats | Patch and crack decals, two-scale overlay, rotate tiles 90°; [[35 Realistic Materials, Decals and Wear]] §3–4 |
| Map feels empty | No mid-height detail, no life | Trees, poles, parked cars, ambience; §4 rule 1 and 10 |
| Map feels like a junkyard | Too much trash, everything worn the same | Reasoned wear only; calm upper floors; §4 rules 6 and 8 |
| The edge of the world shows | Too-clear atmosphere | Raise Density and Haze; tall far boxes; terrain hills |
| Looks great in Studio, flat on phone | Shadows off below quality 4; detail in shadows | Design value structure that reads without shadows; test at quality 1 |
| Phone lags near downtown | Too many unique meshes, big textures, many lights with shadows | [[38 Mesh Pipeline, LOD and Mobile Budgets]] §5 |
| Trees look like paper | Leaf cards facing one way, no wind, wrong alpha mode | `AlphaMode = Transparency`, crossed cards, WindShake; [[37 Terrain, Water and Foliage]] §4 |
| Water looks like plastic | Wrong colour/transparency, no props in it | Turquoise shallow settings, rocks, markers, wreck; [[37 Terrain, Water and Foliage]] §3 |
| Graffiti looks pasted on | Too clean, wrong height, too many | Lower transparency at edges, put on reachable walls, 1 in 3 walls; [[35 Realistic Materials, Decals and Wear]] §5 |

---

## 8. Fresh-critic sheet (score each 0–10 from the 4 fixed cameras)

1. **Light:** warm/cool split, readable shadows, haze fades distance, no blown-out whites.
2. **Material scale:** bricks, tiles and asphalt grain at real size; nothing stretched.
3. **Wear:** every big surface broken up; wear has reasons; no clean 20×20 patch.
4. **Foliage:** three heights, no bare ground, skyline broken, plants move.
5. **Set dressing:** poles and wires, signs, street furniture, rooftop clutter; corners tell stories.
6. **Scale:** doors, kerbs, cars and storeys right next to an avatar.
7. **Edges:** no visible map edge or void from any street.
8. **Life:** something moves and sounds within 10 s of standing still.
9. **Phone:** 30+ fps at quality 1 on the low-end test phone; no pop-in at walking speed.
10. **Ours:** no copied building, sign, name or texture from the reference games.

Show Alex only when every row is 8+. Say which rows are below and why.

---

## Sources (checked 2026-11-01)

Roblox docs: [Enhance outdoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments), [SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance), [Materials](https://create.roblox.com/docs/parts/materials), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve), [Streaming](https://create.roblox.com/docs/workspace/streaming), [Global wind](https://create.roblox.com/docs/environment/global-wind), [Audio objects](https://create.roblox.com/docs/audio/objects), [Blender](https://create.roblox.com/docs/art/blender), [Terrain API](https://create.roblox.com/docs/reference/engine/classes/Terrain).
DevForum: [Creating a realistic city](https://devforum.roblox.com/t/creating-a-realistic-city/3053768), [Creating a realistic city: Tokyo edition](https://devforum.roblox.com/t/creating-a-realistic-city-tokyo-edition/3859433), [Hood style game map (feedback thread)](https://devforum.roblox.com/t/hood-style-game-map/2938255), [Hyper realistic lighting settings](https://devforum.roblox.com/t/hyper-realistic-lighting-settings/915802), [PBR materials tutorial](https://devforum.roblox.com/t/full-in-depth-tutorial-on-how-to-use-pbr-materials-to-create-realistic-objects-in-roblox/1574778), [Realistic alpha leaves](https://devforum.roblox.com/t/how-to-make-realistic-looking-alpha-leaves-for-realistic-building/684354), [Wind Shake](https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806), [Environmental audio](https://devforum.roblox.com/t/ambientsorcery%E2%80%99s-tutorial-1-creating-compelling-environmental-audio/3507022), [Simulating lots of traffic](https://devforum.roblox.com/t/most-effecient-way-to-simulate-a-lot-of-traffic/2164600).
Vault depth already in the repo (read for detail, don't duplicate): `LihFolk/LihFolk Vault V2/06 World Building and Art/`, `44 Materials and Surfaces/`, `07 Lighting VFX and Audio/`, `12 Performance Testing and Debugging/`, `25 Physics and Vehicles/`; street numbers in `research_notes/Front page feel and gamey stages/hood_games_maps.md`.
