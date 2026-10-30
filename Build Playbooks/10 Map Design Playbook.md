---
tags: [build-playbooks, map-design, level-design, lighting, art-direction]
updated: 2026-10-30
---

# 10 Map Design Playbook

Back to [[00 Build Router]] · Skill: `roblox-cartoony-building` · Numbers behind it: [[Brief - Worlds, Lighting and Performance]], `research_notes/Cartoony Roblox building UI and animation/building_stylized_techniques.md` §3, `research_notes/Tiered props VFX and vibrant maps/vibrant_maps.md` §2 · Owner's taste: [[09 Owner Taste Rules]]

**Goal (owner, Oct 30):** a popular-quality map from a minimal prompt. To get there:
1. pick a template (§2);
2. fill the zone table from the theme kit (§3);
3. follow the build recipe in order (§5);
4. pass the checklist (§7).

Every number below is a starting point; tune it by eye on a phone.

## 1. What front-page maps have in common
Measured from the owner's Stone Skipping recordings [M] and the repo research notes [R].

1. **One readable spine.** Stone Skipping has one straight river. Steal an Egg has one long biome corridor. The +1 games have one straight stage lane. You always know which way "further" is. [M][R]
2. **The lobby is a stage, not a diorama.** [M]
   - Tall blocky walls enclose it: terraced red/green checker voxels.
   - The floor is a lavender studded plaza with green zig-zag grass inlays.
   - A glowing **landmark at the back centre** (Stone Skipping's waterfall portal).
   - Everything you use stands in rows along the edges, facing you.
3. **Things you touch are loud, things you stand on are calm.** 75–100% saturation on pads, signs, eggs, the dock; 20–55% on floors and walls. [R]
4. **The payoff zone is unmistakable:** a yellow studded dock at the water's edge with **THROW ZONE painted in giant letters on the floor**. [M]
5. **Every zone along the spine has its own colour set and 2–3 hero props on the banks:** palm trees on the beach, cacti in the desert, pines and ice crystals in the snow. The bank colour changes too (checkered red/beige, then white/lavender in snow). [M]
6. **A painted sky:** a sunset gradient (orange to purple) with a huge stylised sun or moon low on the horizon, so every frame of the flight looks like a thumbnail. [M]
7. **Edges are dense, the centre is open.** The spawn plaza stays calm. No empty patch bigger than about 30×30 studs elsewhere. [R]

## 2. Pick a template
### A. "+1 Lane" (launch, throw, run for distance): +1 Stone Skipping, +1 Cannon Evolution
```text
        [far zones … each zone 1.3–1.4× longer than the last]
   ════════════════════  LANE (water / track), 60–120 studs wide  ════════════════════
        ▲ zone borders: see-through walls, name + stat needed, landmark on each bank
   ┌────┴───────────── LAUNCH DOCK (yellow, giant floor letters) ───────────┐
   │ TRAINING ROW (left)       SPAWN PLAZA (faces the dock)    SHOP/BALLS (right) │
   │ pads by rebirth           calm, 60–90 studs across        egg stands in a row │
   └──────────── back wall with the LANDMARK (portal/waterfall/Grand Cannon) ──────┘
```
- The lobby is about **160 × 120 studs** (spawn to dock 30–50 studs, a 2–3 s walk).
- The dock sits **at the water's edge, facing straight down the lane**, so the camera's first view is the lane.
- **Zone lengths grow geometrically.** Cannon Evolution's borders are at 152, 279, 443, 659, 938, 1298, 1770, 2384, 3180, 4213, 5559, 7308, 9580, 12532 and 16349 studs: about ×1.3–1.4 each, so every rebirth reaches about one new zone. [R build notes]
- Each zone's landmark is tall (40–120 studs) and **visible from the zone before**, so there's always something on the horizon.
- The training row goes on the left and the collection/shop row on the right (Cannon's lobby plan, Oct 30). Pads get bigger and glow more by tier, with a sign over each one showing the rebirths needed.

### B. Hub + gated zones (classic simulator)
- A hub about **250 × 250 studs**. Spawn at an edge, facing the main landmark. One wide main path plus a loop. [R skill §1]
- **The core stations are 30–80 studs from spawn** (a 2–5 s walk at 16 studs/s). Shop and eggs go on the way out of spawn.
- Zones in a line, behind gates **20–30 studs wide and 20+ tall**, with a price sign, a step up, and the next landmark peeking over. [R]

### C. Egg Run corridor (Steal an Egg family)
- A **base row** (one plot per player, 8–10 plots side by side) faces one **long corridor of biomes**. Each biome shows the speed it needs at its entrance.
- **Biome length grows as the needed stat jumps.** Steal an Egg: Forest 0 → Lake 900 → Desert 10K → … → Cosmic 700M. [W allthings.how]
- Danger rises the further you go (guardians), so the way home is the tension.

### D. Stage lane (+1 Speed / Superhero / Muscle)
- **A straight hallway of numbered stages**, each a gate that needs a stat, with a yellow pad at each stage end that pays and teleports you home. 15 stages per world. [R research note §1.3]

## 3. Zone theme kit (pick 5–15 in a row; light to dark, calm to wild)
Colours are RGB starting points. Ground and bank colours are calm; the accent is loud. Change the ambient per zone **on the client**.

| Theme | Ground / water | Bank or wall | Accent | Hero props (pick 3) | Landmark | Ambient tint |
|---|---|---|---|---|---|---|
| Meadow | 120,200,90 / 90,200,230 | 235,215,170 | 255,220,60 | round trees, flowers, fences | windmill | warm yellow |
| Beach | 245,225,160 / 70,210,230 | 240,140,110 + beige checker | 255,120,80 | palms, umbrellas, crabs, shells | lighthouse | peach |
| Mushroom | 140,200,110 / 110,190,220 | 200,160,220 | 255,80,120 | giant mushrooms, glow spores | mushroom house | pink |
| Desert | 235,190,120 / 60,190,210 | 210,130,80 | 60,200,120 | cacti, mesas, skulls, bones | red mesa arch | orange |
| Pirate | 220,190,140 / 40,150,200 | 120,90,70 wood | 240,70,60 | barrels, wrecks, flags, chests | shipwreck / skull rock | teal |
| Autumn | 200,150,90 / 70,170,200 | 170,90,60 | 255,150,40 | maple trees, pumpkins, leaves | fort wall | amber |
| Jungle | 70,170,80 / 60,180,170 | 120,140,80 | 255,210,60 | ferns, vines, totems | stone temple | green-gold |
| Snow | 240,245,255 / 150,210,240 | 200,200,235 | 90,180,255 | pines, ice crystals, igloos | ice castle | pale blue |
| Crystal | 170,150,230 / 120,200,255 | 110,90,170 | 80,255,230 | crystal clusters, glowing rocks | crystal spire | violet |
| Lava | 90,70,80 / 255,120,40 (lava) | 60,50,60 | 255,80,30 | obsidian rocks, ember vents | volcano | red-orange |
| Candy | 255,200,220 / 150,220,255 | 255,240,250 | 255,90,170 | lollipops, gumdrops, cake | candy castle | pink |
| Space / Sky | 60,60,120 or clouds 255,255,255 | 150,170,255 | 255,220,120 | planets, floating islands, stars | sky palace | gold / lilac |

Rules [R vibrant_maps colour budget]:
- About 60% of the screen is calm neutrals, 30% colour (walls and nature), and 10% loud accents.
- Shadows lean blue-purple via OutdoorAmbient, never grey.
- Near-black only on small details.
- One hero hue per zone.

## 4. Scale and spacing numbers
| Thing | Size |
|---|---|
| Character (R15) | ~5 studs tall; walk 16 studs/s |
| Main path | ≥ 10 studs (main 16–24, secondary 10–14) |
| Spawn plaza | 60–90 studs across, calm |
| Station or pad | 12–20 studs square, raised 0.5–1 stud, chamfered edge |
| Sign or billboard text | readable from 40 studs on a phone; letters ≥ 3 studs |
| Gate / zone wall | 20–30 wide, 20+ tall; see-through on a lane |
| Landmark | 40–120 studs tall; visible from spawn or from the zone before |
| Trims | 0.5–1 stud thick so they read on a phone |
| Empty patch max | ~30 × 30 studs (except the spawn plaza) |
| Floor letters (THROW ZONE) | 6–10 studs tall, painted flat, high contrast |

## 5. Build recipe (in this order; one Command Bar tool per step, saved in `<game>/src/tools/`)
Cannon Evolution's tools are the pattern: `BuildWorld1.lua`, `BuildLobbyExtras.lua`, `BuildLighting.lua`, `BuildWater.lua`, `BuildCartoonyMap.lua`, `BuildRebirthSigns.lua`. Each one is re-runnable and only touches its own folder.

1. **Lighting first** (`BuildLighting.lua`): preset A from the skill, or H1 from vibrant_maps. Atmosphere Density 0.3–0.4; Bloom threshold 0.9–1.0; ColorCorrection Saturation +0.15. Add a stylised Sky.
2. **Blockout:**
   - grey parts for the spine, lobby, dock, rows and zone borders, at the template's sizes;
   - **screenshot from spawn**: the landmark, the payoff zone, the shop and the first border must all be in view.
3. **Owner check #1:** send that one picture with the template drawn on it. Layout is cheap to change now and expensive later.
4. **Hero pieces:**
   - the dock with floor letters;
   - pads (one model, scaled and recoloured by tier);
   - egg stands;
   - the landmark.
   
   Use the owner's art or GLB if given (repo rule 8). Otherwise build blocky from parts (studs and chamfers) or use Blender for repeated props.
5. **Zones:** for each row of the theme table, add the bank colour, 3 hero props ×N along both banks (randomise scale ±15% and rotation), a landmark, a border wall with the name and needed stat, and an ambient tint.
6. **Filler:** big filler (cliffs, tree clumps) on the edges first, then small filler (rocks, tufts), then the colour accents last.
7. **Life:**
   - water ripples or caustics;
   - drifting clouds;
   - 1–2 ambient emitters per zone (leaves, snow, embers) at a low rate;
   - flags or banners that sway (client-side tweens).
8. **Performance pass:**
   - every decoration part Anchored, with CanCollide, CanTouch and CanQuery off;
   - CastShadow off on small parts;
   - reuse meshes;
   - aim for under 1,000 draw calls (Roblox's baseline).
   
   Pack big imports (the Cannon map went from 9,162 parts to 187).
9. **Screenshot test + phone test** (§7), then a side-by-side with the reference (repo rule 2).

## 6. Minimal prompt (fill the <>)
> Build the map for **<game>** with template **<A/B/C/D>** from `10 Map Design Playbook`. Zones in order: **<theme, theme, …>** from the theme kit. Landmark: **<thing>**. The owner's art: **<paths or "none">**. Reference: **<recording or picture>**. Follow the build recipe step by step. Stop after step 3 and show me the blockout from spawn.

That's enough because everything else (sizes, colours, lighting, order, checks) is in this note and the skill.

## 7. Map checklist
- [ ] From spawn: the landmark, the payoff/main action, shop, eggs and the first gate or border are in view without turning more than ~90°
- [ ] The first station is ≤ 15 s away; the payoff zone ≤ 3 s from spawn
- [ ] One spine; "further" is obvious
- [ ] Each zone has its own ground/bank colour, 3 hero props, a landmark and a sign with the stat needed
- [ ] Saturation budget: loud on things you touch, calm on things you stand on; no grey shadows
- [ ] No empty patch over ~30×30 studs; dense edges; no visible void or platform edge from normal camera angles
- [ ] Sky and lighting give a "thumbnail frame" on the payoff camera
- [ ] Phone: steady frame rate at low quality; decorations non-colliding; fewer than ~1,000 draw calls
- [ ] Owner taste: blocky, studded, cartoony; neon only where their art has it; bloom nearly off ([[09 Owner Taste Rules]])
