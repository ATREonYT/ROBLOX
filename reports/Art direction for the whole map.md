# Art direction for the whole map (2026-10-08)

This answers your production spec: what the references actually do, what holds our build back (worst first), the rules every builder follows, and the plan. The plan is to finish Stage 1 completely first, then build five districts that each look different.

## 1. Reference analysis (what is actually visible)

### ref1_hall_a / ref1_hall_b: the lobby hall (interior)
- **Space:** about 240 × 180 studs, ceiling about 70; the avatar is about 5–6 studs.
  - From the spawn on the walkway cross, you see first: the centre-back PETS dais framed by the back wall's centre pillars (a), and the exit recess with the glowing Stage 1 doorway (b).
  - The axis is symmetric (walkways, wall bays). The activities are asymmetric: the capsule terrace on one side; the clone machine and gamepass pads on the other.
- **Walls:**
  - teal-blue wall planes between light-grey pillars;
  - each pillar is deep at the bottom and kinks slimmer above, with a navy channel carrying a white neon strip up its face (the main vertical rhythm);
  - big windows with THICK navy frames, a transom bar and pale-blue glass with white glint strokes; recessed, not flush;
  - small white wall lamps between bays.
- **Ceiling:** grey lattice trusses spanning the hall, with long white light bars hung on thin wires (the main light sources); the ceiling is in darker shade.
- **Floor:**
  - lavender studded plastic; an 18-wide walkway cross;
  - four big panels a shade darker with a fine tile grid, outlined by a cyan neon line;
  - a pale chevron on the walkway pointing to the exit;
  - studs read as texture at every distance.
- **Focal mass: the RED glass capsule terrace** (a, left; b, right):
  - stepped grey risers, each capsule a red translucent cylinder with a grey base and cap;
  - floating "+N Click / N Wins" stacks in small white outlined text;
  - the most saturated, densest object in the room. Everything else is pastel or neutral.
- **Back wall:**
  - the PETS sign: a white framed board with grey border on the centre pillar;
  - the egg dais on black-and-white checkered tiles with eggs on pedestals;
  - the cyan glass clone-machine booth with screens;
  - black-and-yellow hazard pillars;
  - small white information boards on stands.
- **Exit wall (b):**
  - a grey framed recess with a pale glass doorway showing the stage-1 street;
  - a green arched "coming soon" door with red-black striped arch;
  - small props: blue drums, a yellow kiosk, red posts.
- **Colour roles:**
  - neutrals for the shell (teal, grey, lavender);
  - saturated colour only on interactive objects (red capsules, cyan machine, yellow/blue pads, rarity text);
  - cyan neon as the "path and outline" accent.
- **Light:**
  - bright, cool, nearly shadowless interior;
  - bloom only on the neon strips and outlines;
  - glass reads by tint and glints, not reflections.
- **Signs and UI:**
  - floating text: bold rounded display font, thick dark outline, colour by meaning (green Robux/exclusive, gold Legendary, blue Rare…), 2–3 lines max;
  - physical signs only for area names (PETS, CLONE MACHINE as big cyan outlined words) and white framed boards.

### ref1_street: a stage street (exterior)
- **Camera:** about 13.6 studs up behind the player, looking down a straight road to the stage wall (solved by STREETS).
- **Cross-section:**
  - dark studded asphalt about 17 wide, with yellow 1×4 dashes;
  - grey studded sidewalks about 8 wide, raised slightly, with a kerb;
  - lime studded grass strips with small blue flowers and grass tufts;
  - a plank fence (alternating light and dark brown planks, ragged tops) along the yards;
  - two-storey red-brick buildings set back behind the fences.
- **Buildings:**
  - brick red with a slate-blue band between floors;
  - window units of four blue panes in grey frames with sills;
  - slate roofs with eaves;
  - blocks broken into bays with pilasters, NOT one flat wall.
- **Street furniture:**
  - tall navy street lamps with an arm and a small lit head;
  - stacked-cube trees (a dark trunk, three green cube tiers);
  - a green dumpster with its lid open;
  - hedges.
- **Light:**
  - a sunny day; the sun from camera-right, so the left facades are lit and the right ones in shade;
  - soft shadows;
  - a blue sky with clouds; light haze toward the far end.
- **Stage wall at the end:** translucent pink/white with floating "Stage N / Recommended Power: X". Magenta and yellow pads sit on the road just before it.

### ref_armory: the item shop pads
- A grey studded plinth with a stepped studded back wall.
- A row of pink hexagonal pads with glowing faces, the equipped one green.
- The item floats upright over each pad.
- Labels: the name in a gold/bronze gradient outline font, then "avatar icon ×N", then "trophy price" or EQUIPPED.
- A small state plate on each pad's front.

### The soldier game video (brief/video1/notes.md): layout and operation, not theme
- One straight spine from the spawn to the Stage 1 gate; activities off it; the next gate always in view.
- Training lanes in a row with the target at the far end; locked lanes as black silhouettes.
- A stand of coloured pads for guns; gates with STAGE N text and two pads; waves with "N LEFT"; a goal chain.
- Craft: studs everywhere, 2–3 tones per colour, finished edges, prop clusters at the path sides, side-lit sun.

### Conflicts and the choice
| Question | Choice |
|---|---|
| Lobby: hall interior (refs a/b) vs outdoor plaza (video) | **Refs a/b for the lobby architecture, palette and light.** The video only gives the flow: a straight spine and the next goal visible. |
| Stages: brick street (ref1_street) vs desert arenas (video) | **ref1_street for the stages' architecture, materials and light.** The video gives arena composition (side clusters, next gate visible) and mechanics. |
| Gun display: armory hex pads (ref_armory) vs coloured pad stand (video) | **ref_armory's pads.** The video gives the label and state system. |
| Signs | **One system:** gameplay info is floating outlined text (refs a/b, street); physical framed boards only for area titles and leaderboards. |

## 2. Audit of our current build (largest problems first)
1. **Lighting and preview:**
   - our renders have no sun shadows, no sky clouds, faint studs and a grey cast, so everything reads flat;
   - real Roblox lighting would already look better than our previews;
   - the HoodSoft preset also has no strong side sun.

   Fixes: RENDER (fidelity) and HALL (presets).
2. **Flat surfaces:**
   - walls, floor panels, pillars, brick facades and pads are single-tone slabs;
   - the references have bands, trims, recesses, sills, lintels, mortar lines, darker bases and lighter caps.
3. **Hall focal mass missing:**
   - the reference's densest, most saturated object is the capsule terrace;
   - ours was a grey stand with small items. RANGES is putting the themed lanes back there.
4. **Repeated streets:**
   - all 15 stages are one street (BRIEF12 asked for that);
   - the spec now rules it out: areas must be distinguishable without signs.
5. **Stage depth compressed:** stages are 64 long, so the far wall sits at half the reference's distance.
6. **Sparse back wall and corners:**
   - the reference's back is dense (sign, dais, machine, hazard pillars, boards);
   - ours is thin.
7. **Signs:** mostly fixed in earlier passes. Keep one system and the minimum.

## 3. Art direction (all builders)
- **Style:** a classic studded Roblox simulator, built with care: chunky part-built forms; every surface in 2–3 tones; finished edges; saturated colour reserved for interaction.
- **Palette roles:**
  - **Environment:** hall lavender floor, teal walls, light-grey structure, navy frames; street dark asphalt, grey sidewalks, lime grass, brick red, slate blue, plank browns.
  - **Interaction:** saturated primaries with white rims and cyan neon outlines (stations, pads, doors).
  - **Rarity and state:** grey < green < blue < purple < orange < gold; state green = unlocked/equipped, red = locked, blue = owned, yellow = buy/next.
- **Materials:**
  - Plastic with studs on floors, ground, sidewalks, roads, grass and big walls;
  - SmoothPlastic on trims, frames, signs and machine bodies;
  - Glass (transparency 0.3–0.5) for capsules and windows;
  - Neon only for outlines, strips, pad faces and lamp heads.
  - No realistic textures or weathering.
- **Geometry and edges:**
  - sharp box edges; stepped pixel corners on platforms;
  - every object built as base + body + cap;
  - recesses of 0.4–1 stud for windows and doors; frames 0.6–1 stud thick;
  - cylinders only where the reference has round things (capsules, lamps, eggs, barrels).
  - Custom meshes are not needed: the references themselves are part-built. Guns use our existing GunModels.
- **Signs and UI:**
  - floating BillboardGui text in the display font (LuckiestGuy/Fredoka style) with a thick dark outline, colour by meaning, max 3 lines;
  - physical boards: white with a grey frame, mounted on a pillar or wall, never floating;
  - no frames on frames.
- **Lighting:**
  - **Outside:** a warm sun from one side, high afternoon, so one side of each street is lit and the other in shade; soft shadows; cool ambient; a blue sky with clouds; slight haze at distance; bloom only on Neon.
  - **Inside:** bright and cool, from the light bars; weak shadows; bloom on the neon strips and outlines.
- **Landmarks:**
  - **Hall:** the range terrace (east), the exit bay with the Stage 1 door and WORLD 2 (north), the shoe-box dais (back centre, reserved), the armory (south-west).
  - **World:** one landmark per district (below).

## 4. Representative section first: STAGE 1 (from the hall door to gate 2)
It holds:
- a representative building (the brick house family);
- the playable route (the road);
- the main interactive station (MECHANICS' target wave, plus GATES' gate 2 with its sign and pads);
- supporting props (fence, lamps, trees, dumpster, hedges);
- final materials, lighting and signage.

STREETS, GATES and MECHANICS finish it to production standard through stages A→H. RENDER's fidelity renderer judges it. The lead approves it before anything is repeated.

Stages 2–15 stay as they are until Stage 1 is signed off.

## 5. After Stage 1: a district family with spatial identity (each recognisable without signs)
| District | Stages | Spatial identity |
|---|---|---|
| The Block | 1–3 | The reference's residential brick street. Variation within it: setbacks, one house with a stoop, one with a porch, a side yard. |
| Corner Shop | 4–6 | A cross-street intersection with a corner store: awning, crates, ice box, a bike rack; shopfronts at ground level with flats above. |
| The Alley | 7–9 | A narrow alley between tall walls with an overhead connection (a walkway or bridge between buildings), fire escapes, bins, pipes and hanging wires. |
| The Courts | 10–12 | The street opens on one side to a fenced basketball court with hoops, benches and bleachers; buildings on one side only. |
| The Yards | 13–15 | Warehouses and containers, a loading dock, chain-link. |
| Boss yard | 16 | The finale. |

Each district uses the same kit language (studs, tones, trims) with different geometry. No colour swaps.

