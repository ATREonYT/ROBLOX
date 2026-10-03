# Stylized prop modeling and tiered-upgrade visuals for "Hood" (Roblox, 2025–2026)

Research method and reliability:
- The egress proxy blocked fandom.com, miraheze.org, devforum.roblox.com, create.roblox.com, wikipedia.org, web.archive.org and paulbourke.net. Only GitHub was reachable.
- **[V]** means I read the claim in the primary source myself. Most of these come from the Roblox Creator Docs GitHub mirror (`Roblox/creator-docs`, commit `9f840b1`, dated 2026-10-02, so the docs are current).
- **[S]** means the claim comes only from a WebSearch result summary. I could not open the page, so treat these as unverified paraphrases. They may be stale or wrong in detail.
- Where I couldn't find a claim, it is listed under Gaps.

## 1. Tier/progression visual language in hit simulators

### Takeaway
Hit simulators don't rely on one visual cue to show that a tier is worth more. They stack several "channels" and add a new one at each big jump:
- a rarity color ladder (gray → green → blue → purple → orange/gold → red/pink → rainbow/celestial)
- material (dull/organic → metal → gold → glowing/rainbow)
- symbol count (stars)
- size
- particles and glow
- for the top tiers, constant motion or color-cycling (Grow a Garden's Rainbow, PS99's Rainbow/Shiny variants)

The biggest visual jump goes with the biggest value multiplier. In Grow a Garden, Gold is ×20 and Rainbow is ×50. I found no wiki with detailed visual specs per training-equipment tier, so the Hood-specific ladder below is my inference from these patterns.

### Cited Findings
**Rarity color ladders (convention, not a standard)**
- **Pet Simulator 99 at launch:** gray Basic, green Rare, blue Epic, orange Legendary, red Mythical, purple Exotic, pink Exclusive. Later updates added Divine (yellow), Superior (cyan), Celestial (pink and blue) and Secret (dark blue). **[S]** — [NamuWiki PS99 Pet](https://en.namu.wiki/w/Pet%20Simulator%2099!/%ED%8E%AB); [TV Tropes PS99](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/PetSimulator99); [petsimstats rarity](https://www.petsimstats.com/rarity/values)
- **PS99 also escalates the symbol, not just the color:** Rare 1 star, Epic 2 stars, Legendary 3 stars, Mythical a 4-pointed star, Exotic 2 four-pointed stars, Divine 3 four-pointed stars, Superior a shield/octogram, Celestial 2 octograms. **[S]** — same sources as above (the summary table may be partly reconstructed by the search tool; verify before copying)
- **Giant Simulator:** Common gray, Rare blue, Epic purple, Legendary orange, Mythic pink. **[S]** — [Giant Simulator Rarities (fandom)](https://roblox-giant-simulator.fandom.com/wiki/Rarities)
- **DevForum convention:** Common grey, Uncommon green, Rare blue, Epic bright purple, Legendary gold, Mythic violet/dark purple. Players already recognize this ladder, though "no single universal standard" exists. **[S]** — [Need help on selecting value colors (DevForum)](https://devforum.roblox.com/t/need-help-on-selecting-value-colors/793985); [Need tier list names (DevForum)](https://devforum.roblox.com/t/need-tier-list-names/761008)

**Material and variant escalation (gold → rainbow → shiny)**
- In Pet Simulator 99, every pet can hatch as regular, gold, rainbow or shiny. Huge pets get +0.3× (Golden), +0.9× (Rainbow) or +1× (Shiny) damage over normal. A rare-variant hit is announced server-wide in global chat. **[S]** — [Huge Pets (PS99)](https://pet-simulator.fandom.com/wiki/Huge_Pets_(Pet_Simulator_99)); [Gargantuan Pets (PS99)](https://pet-simulator.fandom.com/wiki/Gargantuan_Pets_(Pet_Simulator_99))
- **Grow a Garden mutations [S]:**
  - Gold: "textured golden with a bright glow", ×20 value.
  - Rainbow: 0.1% chance, ×50 value. The crop "continuously change[s] colors, emit[s] yellow particles and display[s] a rainbow above", with "a round halo of rainbow colors and sparkling particle effects".
  - Gold and Rainbow can't stack.
  - Other mutations are each one tint plus one particle type: Wet (dripping water particles), Chilled (blue frost tint plus frost particles), Zombified (green fog plus dripping green liquid), Disco (flashes red/pink/yellow/green/blue).
  - Sources: [Grow a Garden Wiki – Mutations](https://growagarden.miraheze.org/wiki/Mutations); [Theria Games – Rainbow](https://theriagames.com/guide/grow-a-garden-rainbow-mutation/); [TechWiser – All Mutations](https://techwiser.com/roblox-grow-a-garden-all-mutations-and-how-to-get-them/)
- **Arm Wrestle Simulator:** a "Golden Machine" turns pets gold (+50% boost). The top arm tier ("Buff Diamond", Omega rarity) uses the diamond material for the rarest item. The worlds escalate in theme: School → Space Gym → Beach → Nuclear Bunker → Dino → Void → Space Center. **[S]** — [holdtoreset AWS Gym](https://holdtoreset.com/arm-wrestle-simulator-gym/); [AWS Wiki (fandom)](https://aws-roblox.fandom.com/wiki/Arm_Wrestle_Simulator_Wiki); [Arms (fandom)](https://arm-wrestling-simulator.fandom.com/wiki/Arms)
- **Punch Wall:** glove tiers run from Basic to Legendary across 10+ tiers, starting Bronze → Silver → Gold → Platinum and beyond. This is the metal ladder used as a tier ladder. **[S]** — [Punch Wall codes/guide (progameguides)](https://progameguides.com/roblox/punch-wall-codes/); [kimik2.help Punch Wall guide](https://kimik2.help/)
- **Gym League gear** escalates by adding material and mythic motifs to a base object [S]:
  - Lifting Belt (Common) → Cowboy Belt (Rare) → Golden Lifting Belt (Epic) → Championship Belt (Legendary)
  - Grey Sweatband (Common) → Flame Sweatband (Rare)
  - Bird Wings (Common) → Angel Wings (Legendary) → Cursed Wings (Mythical)
  - Emperor Horns (Mythical)
  - Sources: [Try Hard Guides – Gym League Gear](https://tryhardguides.com/gym-league-gear-guide-how-to-get-and-rarity/); [progameguides – All Gear in Gym League](https://progameguides.com/roblox/all-gears-in-gym-league-and-how-to-get-them/)

**Zone and equipment escalation in strength simulators**
- **Muscle Legends [S]:**
  - Gyms unlock by rebirths: Frost Gym 1, Mythical Gym 5, Muscle King Gym 5, Eternal Gym 15, Legends Gym 30.
  - Frost Gym: "everything is frosted-like", with a huge chest and a Frost Crystal. Bench presses need 1K / 3K / 7.5K / 15K strength.
  - Mythical Gym: "multiple things like the other gyms, but better".
  - Eternal Gym: "larger treadmills, new Chests, new Auras, stronger Rocks, Eternal Machine".
  - Legends Gym: "electric effects on the portal", the "only statue that is glowing white", and two pet crystals.
  - Muscle King Gym: a one-person throne-style spot ("only 1 person can train") with the best machines.
  - Sources: [Frost Gym](https://muscle-legends.fandom.com/wiki/Frost_Gym); [Mythical Gym](https://muscle-legends.fandom.com/wiki/Mythical_Gym); [Eternal Gym](https://muscle-legends.fandom.com/wiki/Eternal_Gym); [Muscle King Gym](https://muscle-legends.fandom.com/wiki/Muscle_King_Gym); [Legends Gym](https://muscle-legends.fandom.com/wiki/Legends_Gym); [muscle-legends.wiki rebirth guide](https://muscle-legends.wiki/rebirth/muscle-legends-rebirths)
- **Muscle Legends rocks** are a tiered "punch target" ladder with requirements. A "Golden Rock" needs 5,000 durability at Legend Beach, and Frost Gym's "The Rock" needs 150K durability. **[S]** — [Rocks (fandom)](https://muscle-legends.fandom.com/wiki/Rocks); [Frost Gym](https://muscle-legends.fandom.com/wiki/Frost_Gym)
- **Strongman Simulator:** themed areas (Arcade Room, Kitchen, Stadium … The Castle as the final area), each with "a large object blocking the door" that you must drag out of the way. Later zones add squat bars, dumbbells and "longer running tracks". **[S]** — [Strongman Simulator (Roblox fandom)](https://roblox.fandom.com/wiki/The_Gang_Stockholm/Strongman_Simulator); [GameSkinny Strongman guide](https://www.gameskinny.com/tips/roblox-strongman-simulator-how-to-level-up-fast/); [Sportskeeda – 5 things about Strongman Simulator](https://www.sportskeeda.com/roblox-news/things-know-playing-roblox-strongman-simulator)
- **Generic simulator design advice:** "bigger swords, faster cars, more pets" create constant visible progression, and each rebirth should add visual change. **[S]**, low-authority marketing blog — [creation.dev simulator ideas](https://www.creation.dev/ideas/simulator)
- **Bee Swarm Simulator** tools progress by milestone (Golden Rake ~30 bees → Porcelain Dipper ~35 → Petal Wand 45+). I found no visual description. **[S]** — [Sportskeeda BSS progression](https://www.sportskeeda.com/roblox-news/bee-swarm-simulator-progression-guide)

**Engine features that implement each channel**
- Built-in base materials that suit a metal/gold/glow ladder include CorrodedMetal, DiamondPlate, Foil, ForceField, Glass, Metal and Neon. Neon and ForceField are "unique" materials bundled with Studio. Glass refraction is not supported on mobile. **[V]** — [creator-docs parts/materials.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/materials.md)
- `SurfaceAppearance` supports 5 PBR maps: color, normal, roughness, metalness and an **emissive mask** (with `EmissiveStrength` and `EmissiveTint`). The docs pitch the mask as "more artistic control than the all-or-nothing Neon material", e.g., "illuminated text". Marketplace items must keep EmissiveStrength at 0–40. **[V]** — [creator-docs art/modeling/surface-appearance.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/surface-appearance.md)
- `Lighting.EnvironmentSpecularScale` defaults to 0. Raising it "will make smooth objects reflect the environment and it is especially important to make metal look more realistic." **[V]** — [creator-docs Lighting.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Lighting.yaml)
- Shiny gold [S]: the Metal material doesn't use Reflectance, so use SmoothPlastic or Plastic with Reflectance. Set `EnvironmentDiffuseScale` and `EnvironmentSpecularScale` toward 1. A detailed skybox matters ("without a good skybox, metal can appear dull"). A semi-transparent glass shell over gold adds sheen. Sources: [Is it possible to make a part shiny gold? (DevForum)](https://devforum.roblox.com/t/is-it-possible-to-make-a-part-shiny-gold/1715930); [How to make metal more reflective? (DevForum)](https://devforum.roblox.com/t/how-to-make-metal-more-reflective/868239); [Roblox Desk – realistic metal](https://www.robloxdesk.com/how-to-make-metal-in-roblox-look-realistic/)
- `Highlight` now allows **255** simultaneous instances per client. A disabled Highlight still uses a slot, so delete Highlights you no longer need. `DepthMode` is AlwaysOnTop or Occluded. Older forum posts quoting a much lower cap are outdated. **[V]** — [creator-docs Highlight.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Highlight.yaml)

### Inferences
**Rules distilled from the games above** (my synthesis, not quoted):
1. **Stack channels and never change only one.** Each tier should differ in at least 2 of these: color, material, silhouette/size, ornament count, FX, stage/pedestal. At each "rarity break" (every 2–3 tiers) add one channel nobody had before, e.g. the first PointLight, then the first particles, then the first moving part, then hue-cycling. This mirrors PS99 adding symbols, and Grow a Garden adding glow, then particles, then a halo and color-cycling.
2. **Material ladder:** organic/junk (rubber, wood, rope, tape) → canvas/leather → chrome/steel → black-pro with metallic trim → gold → prismatic/rainbow Neon.
   - Hood's tier names already follow this, so keep diamond/crystal for accents on the Champ Ring rather than as a separate tier.
3. **Save the biggest visual jump for the biggest multiplier jump.**
   - Grow a Garden pairs Gold with ×20 and Rainbow with ×50.
   - Hood's Gold Bag (×25) and Champ Ring (×40) should be the first and only tiers with continuous motion plus full-body glow plus a halo or aura.
4. **Hood's cost steps fit genre norms.** Hood's ×2.5–3.3 cost steps (50→150→500→1K→3K→8K→20K→50K) look like Muscle Legends' bench ladder (1K→3K→7.5K→15K, about ×2–3). No change needed.
5. **The rarity color appears in four places:** the trim, the nameplate, the price label and the particle color. One color then reads from far away, even before the player can make out the material.

**Proposed Hood ladder** (inference; colors are suggestions picked to match the conventions above)

| # | Station (cost, mult) | Rarity color (RGB) | Body / materials | Frame / mount | Pedestal / stage | Light & FX | Motion |
|---|---|---|---|---|---|---|---|
| 1 | Tire Bag (free, ×2) | Common gray (158,158,158) | 3 stacked tires: near-black SmoothPlastic with tread blocks | Rough Wood gallows, Fabric rope, rusty CorrodedMetal bolts | Cracked concrete slab, flush with ground | None | Gentle swing only |
| 2 | Duct Tape Bag (50, ×3) | Uncommon green (76,217,100) | Faded brown/red leather bag + 3–4 silver Foil tape bands, one dangling tape strip | Scaffold pipe frame (Metal/CorrodedMetal) | Wooden pallet base | None (green nameplate only) | Swing |
| 3 | Street Bag (150, ×4) | Rare blue (64,156,255) | Fabric canvas bag, graffiti decals/stripes, chain hang | Street-sign/lamp-post style frame | Painted curb-style concrete base with blue edge stripe | Faint ground ring (thin Neon disc, 50% transparent) | Swing |
| 4 | Heavy Bag (500, ×6) | Epic purple (170,85,255) | Glossy red leather (SmoothPlastic, Reflectance ~0.05), white caps, stitched seams | Black steel gallows (Metal), 4 chrome chains → swivel | 0.5–1 stud DiamondPlate plinth with purple Neon edge strip | First **PointLight** under/behind bag (purple) | Swing + chain jiggle |
| 5 | Speed Bag (1K, ×8) | Exotic pink (255,90,200) | Teardrop leather speed bag | Wood rebound platform on chrome wall bracket/post | 1-step plinth, pink trim | Small sparkle particles on hit | Fast bob idle |
| 6 | Double-End Bag (3K, ×12) | Superior cyan (60,230,255) | Round leather ball | Floor + ceiling anchors, **Neon bungee cords** ("electric") | 2-step round plinth | Spark/electric particles, Beam cords | Bounce idle; first **orbiting part** (small ring) |
| 7 | Pro Bag (8K, ×18) | Mythic red/black (255,60,60) | Black leather, red/gold trim bands, logo plate, gold D-rings | Heavy industrial gallows with red Neon accents | 2–3 step stage with corner posts | Ember/flame particles, spotlight cone | Slow-rotating floor emblem |
| 8 | Gold Bag (20K, ×25) | Legendary gold (255,200,60) | Full gold (SmoothPlastic + Reflectance, or Metal/Foil + high EnvironmentSpecularScale) | Gold/white marble gallows | Round gold dais with steps | Sparkles, gold light, vertical Beam/god-ray, **floating gems** | Rotating halo ring + bobbing gems |
| 9 | Champ Ring (50K, ×40) | Celestial/rainbow (hue-cycle) | Ring canvas, belt hologram above | 4 corner posts, **hue-cycling Neon ropes**, turnbuckle pads | Raised 3-stud ring platform with apron + steps + spotlights | Confetti/fireworks on unlock, crowd lights, multiple Beams | Hue cycling + spinning belt |

### Gaps
- **Equipment visuals:** I couldn't open the fandom pages, so per-tier colors and materials for Muscle Legends, Strongman Simulator and Gym League equipment are unverified beyond the short summaries above.
- **Boxing games:** nothing found for Untitled Boxing Game, Boxing League or "Punch Simulator" bag tiers. Search only returned a Boxing League page saying its punching bag needs level 5+ ([fandom](https://boxing-league-roblox.fandom.com/wiki/Punching_Bag), [S]).
- **Sound:** I found no source on how hit simulators escalate sound by tier.
- **Bee Swarm:** no visual descriptions of the tool tiers.
- **Images:** I had no screenshots, so silhouette and size ratios between tiers in real games are unknown.

## 2. Modeling technique: parts vs unions vs MeshParts, mesh import specs, and procedural meshes

### Takeaway
For a code-first team, the realistic choices are:
1. **Parts-only:** cheapest, and fully authorable from Luau.
2. **Procedurally generated meshes:** generate them in a Studio plugin through `EditableMesh` and save them once as Mesh assets with `AssetService:CreateAssetAsync`. Alternatively, write `.gltf`/`.obj` files with a script and bring them in through the Importer.

Hard rules: 20k triangles per mesh, counter-clockwise winding, split normals for hard edges, and a 1 unit = 1 stud scale (use glTF, not FBX, to avoid the ~100× FBX scale problem). Building meshes with `EditableMesh` at runtime in a published game needs the owner to be ID-verified with an opt-in toggle, and it has client memory budgets, so it's a poor fit for static props.

### Cited Findings
**Mesh specs and import [V]**
- **Mesh specs:** individual meshes "can not exceed 20,000 triangles". Geometry must be **watertight** (no holes or backfaces), in quads "where possible" with **no N-gons**, and not 0-thickness. — [creator-docs art/modeling/specifications.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/specifications.md)
- **Importer formats:** `.fbx`, `.gltf` and `.obj`. Only "The `.fbx` and `.gltf` formats support multiple mesh objects and hierarchies, basic and PBR textures, … animation data, and vertex colors". So `.obj` is the bare-geometry path. — [creator-docs studio/importer.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/importer.md)
- **Importer settings:** Scale Unit (default **Studs**), Merge Meshes, Invert Negative Faces, Set Pivot to Scene Origin (default **enabled**), Use Imported Pivot (default enabled), Anchored (default **disabled**) and Ignore Vertex Colors. Objects named `*_Att` become Attachments. — same source, plus [parts/meshes.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/meshes.md)
- **FBX scale:** Blender's default FBX export imports "at an unexpectedly large scale". Fix it with Apply Scalings = **FBX Unit Scale** (recommended), or Scale 0.01, or Unit Scale 0.01. "Roblox Studio also supports GLTF (`.gltf`) formats which do not require these additional scaling configurations." Export axes: Forward = Z Forward, Up = Y Up (Blender); for Maya, Up Axis Y. — [creator-docs art/blender.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/blender.md); [export-requirements.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/export-requirements.md)
- **Vertex painting** is officially supported and recommended for stylized work. It colors meshes "without the need for UV mapping or image textures" and "can reduce texture memory usage and draw calls". — [creator-docs art/blender.md#vertex-painting](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/blender.md)

**Textures and SurfaceAppearance [V]**
- **Textures:** `.png/.jpg/.tga/.bmp`, up to 4096×4096. Suggested sizes are 256² for ~5×5-stud objects, 512² for 10×10 and 1024² for 20×20. Built-in Part materials show 1024² across an 8×8-stud face. A mesh can only have **one material**. Normal maps must be OpenGL tangent-space. — [creator-docs art/modeling/texture-specifications.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/texture-specifications.md)
- **Color tinting:** `SurfaceAppearance.Color` tinting "applies as a multiplier … authoring your original ColorMap in near-white grayscale colors creates the strongest tinting effect". Tinting "does not affect performance" and saves memory "by reusing a single color map with different tints".
- **AlphaMode options:**
  - **Overlay** (default): reveals `MeshPart.Color` where the map is transparent.
  - **Transparency**: cut-outs.
  - **TintMask**: tints only the areas the alpha marks.
- Source: [creator-docs art/modeling/surface-appearance.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/surface-appearance.md)

**MeshPart, collision and LOD [V]**
- **MeshPart texturing:** one `TextureID`, or PBR through a `SurfaceAppearance` child or a `MaterialVariant`. If both exist, SurfaceAppearance maps win. Setting TextureID can't override PBR.
- **RenderFidelity Automatic LOD:** highest detail under 250 studs, medium at 250–500, lowest beyond 500.
- **CollisionFidelity options:** Box, Hull, Default, PreciseConvexDecomposition, and Tunable (with a `CollisionPrecision` slider).
- Source: [creator-docs parts/meshes.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/meshes.md)
- **Scripted MeshParts:** `MeshPart.MeshId` is read-only. `AssetService:CreateMeshPartAsync(content, {CollisionFidelity, RenderFidelity, FluidFidelity})` is the scripted way to make a MeshPart from any mesh ID. — [creator-docs AssetService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AssetService.yaml)

**EditableMesh and scripted upload [V]**
- **What it is:** `EditableMesh` builds and edits meshes at runtime. Create it with `AssetService:CreateEditableMesh()` (blank) and show it with `CreateMeshPartAsync(Content.fromObject(em))` or `MeshPart:ApplyMesh()`.
- **Limits and publishing rules:**
  - 60,000 vertices and 20,000 triangles; a quad counts as 2 triangles.
  - Published games: "fails by default … you must be 13+ age verified and ID verified" and toggle **Enable Mesh / Image APIs** on the Creator Dashboard.
  - Strict client memory budgets apply; the server, Studio and plugins are unlimited.
- **Winding and normals:**
  - "The front of the face is visible when the vertices go counterclockwise around it."
  - Normals, UVs and colors are stored per face corner. Shared vertices produce smooth shading. Hard edges need new normal IDs per face, which the docs show with an `addSharpQuad` example (`AddNormal()` + `SetFaceNormals`).
  - New vertices default to UV (0,0) and white color.
- Source: [creator-docs EditableMesh.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableMesh.yaml)
- **Upload from a plugin:** `AssetService:CreateAssetAsync(object, assetType, …)` "can only be used in locally loaded plugins and uploads assets without prompting first". It accepts `Enum.AssetType.Mesh` with an `EditableMesh` root, `Model` with any Instance, and `Image` with an `EditableImage`. — [creator-docs AssetService.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AssetService.yaml)
- **Upload from outside Studio:** the Open Cloud Assets API "Model" type accepts `.fbx`, `.gltf`, `.glb`, `.rbxm`, `.rbxmx`. It imports "as a Model container containing one or more MeshPart objects", uploaded as packages. Only `.fbx` content can be updated in place. The raw "Mesh" type accepts only Roblox-downloaded mesh data. `.obj` is **not** an Open Cloud upload type. — [creator-docs cloud/guides/usage-assets.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-assets.md)

**SpecialMesh and Part limits [V]**
- `SpecialMesh` FileMesh vs MeshPart:
  - On a SpecialMesh, `Material` doesn't display and collision comes from the parent part.
  - MeshParts get CollisionFidelity and scale with `Size`.
  - SpecialMesh.MeshType options: Brick, Cylinder, FileMesh, Head, Sphere ("can be freely resized on all axis"), Wedge, and Torso ("due to be deprecated").
  - Source: [creator-docs SpecialMesh.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SpecialMesh.yaml)
- BasePart Size is capped at 2048 per axis. — [creator-docs BasePart.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/BasePart.yaml)

**CSG (unions) [V]**
- CSG needs watertight (closed, manifold, non-self-intersecting) input.
- In-game `GeometryService:UnionAsync/IntersectAsync/SubtractAsync` take options `{CollisionFidelity, RenderFidelity, SplitApart}`. SplitApart defaults to true, and results stay in the main part's coordinate space.
- The `rbxNegate` tag negates a part from script.
- `GeometryService:SweepPartAsync` (beta: "Solid Modeling On Meshes") sweeps a part through a CFrame list into a MeshPart.
- Testing `MeshPart.DoubleSided` shows whether a mesh is only a shell.
- Source: [creator-docs parts/solid-modeling.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/solid-modeling.md)

**OBJ format [V]**
- OBJ carries positions, normals and texcoords. Faces can have 3, 4 or more vertices, and loaders typically triangulate N-gons. — [tinyobjloader README (GitHub)](https://github.com/tinyobjloader/tinyobjloader)

**Community practice [S]**
- **Unions vs meshes:**
  - 2 parts are 2 draw calls, while a union of them is 1.
  - Unions "can glitch and even create more triangles".
  - Meshes win for repeated objects because the same mesh ID is reused and triangle counts can be optimized.
  - Advice: "Only use UnionOperations for one-time-use objects that are moderately complex"; make repeated pieces in Blender.
  - Sources: [Performance Question – Parts or Unions (DevForum)](https://devforum.roblox.com/t/performance-question-parts-or-unions/1360129); [Why Meshes Are Superior To Unions (DevForum)](https://devforum.roblox.com/t/why-meshes-are-superior-to-unions-and-how-to-easily-convert-them/625585); [Efficiency regarding MeshParts and Part count (DevForum)](https://devforum.roblox.com/t/efficiency-regarding-meshparts-and-part-count/246058)
- **Low-poly cartoon look in Blender:** Decimate modifier, **flat shading**, often no texture, bevels with **Ctrl+B**, assets made as pieces and assembled in Studio. — [Introduction to Low-Poly and Blender (DevForum)](https://devforum.roblox.com/t/introduction-to-low-poly-and-blender-how-to-create-an-island/424785); [Cartoonish low poly house (DevForum)](https://devforum.roblox.com/t/an-easy-and-simple-guide-to-modeling-a-cartoonish-low-poly-house/374471); [General tips for low poly builds (DevForum)](https://devforum.roblox.com/t/general-tips-and-advice-when-it-comes-to-low-poly-builds/809506)
- **Shading and normals fixes:** flat-shaded faces or edges marked sharp import as crisp edges. Flipped faces are fixed with Apply All Transforms (Ctrl+A) and Recalculate Normals (Shift+N). Negative scale or unapplied transforms flip normals. — [Mesh faces inverted (DevForum)](https://devforum.roblox.com/t/mesh-faces-inverted/1119127); [Roblox sees imported FBX as if normals flipped (DevForum)](https://devforum.roblox.com/t/roblox-sees-imported-fbx-as-if-its-normals-are-flipped/2429420); [Shading artifacts on mesh imported from Blender (DevForum)](https://devforum.roblox.com/t/shading-artifacts-on-mesh-imported-from-blender/3495472); [Imported Mesh is Very Shiny (DevForum)](https://devforum.roblox.com/t/imported-mesh-is-very-shiny/2334328)

### Inferences
**When to use what**
- **Parts:** anything boxy or cylindrical with fewer than ~40 pieces, and anything recolored per tier from code.
- **Unions:** a few one-off cutouts, such as the ring apron skirt with steps, or a hole through a gallows plate.
- **MeshParts:** organic or rounded hero shapes repeated across tiers: the bag body with bulge and seams, the speed-bag teardrop, glove, tire torus, swivel/D-ring hardware, turnbuckle pads. Reusing one mesh ID across 9 stations and recoloring by tier is the efficient path.

**Recommended code-first mesh pipeline for Hood**
1. Write a Luau Studio plugin, or a command-bar script, that builds each prop with `AssetService:CreateEditableMesh()` (no memory cap in Studio).
2. Upload each one once with `AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, …)` and record the returned asset IDs in a `MeshIds` ModuleScript under Rojo.
3. At runtime, create the props with `AssetService:CreateMeshPartAsync(Content.fromAssetId(id), {CollisionFidelity = Enum.CollisionFidelity.Box or Hull})`, or clone template MeshParts saved in a `.rbxm`.

This avoids runtime EditableMesh, and with it the ID-verification toggle and the client memory budget. It assumes `CreateMeshPartAsync` on a normal uploaded mesh asset doesn't need that toggle, which I haven't verified. Check the exact `CreateAssetAsync` request and return shape in AssetService.yaml before coding.

**Alternative: write files outside Roblox**
- Write `.gltf`/`.glb` (preferred) or `.obj` with Lune or Python.
- Import through the Studio Importer, or upload `.gltf/.glb/.fbx` through Open Cloud. Open Cloud doesn't accept `.obj`.
- glTF avoids the FBX ×100 scale trap and carries vertex colors; OBJ does not.

**Pitfalls checklist for generated meshes**
1. **Winding:** counter-clockwise front faces. Wrong winding makes the mesh look inside-out. Importer "Invert Negative Faces" helps only for negatively-scaled nodes.
2. **Normals:** provide explicit normals. For a cartoon/flat look, split vertices per face, or per smoothing group, so edges stay crisp. For a soft bag body, share vertices around the circumference but split at the caps and seams.
3. **Units:** author at 1 unit = 1 stud with Y-up. Bake the scale in rather than relying on export scale flags.
4. **Pivot:** the Importer sets the pivot to scene origin by default. Model each prop with its origin where it should hang or sit (top-center of a bag at the swivel, bottom-center of a pedestal), so code can place it by CFrame.
5. **UVs:** if no UVs are given, everything samples one texel. That's fine for vertex color or a flat `MeshPart.Color`, but supply UVs if you use a palette atlas or SurfaceAppearance.
6. **Watertight:** close the mesh (caps on cylinders) if you ever want CSG on it, and to avoid backface holes.
7. **Budget:** stay far under 20k triangles. A stylized bag needs ~300–1,500.
8. **Material:** one material per mesh, so make trims, chains and caps separate MeshParts or Parts. That also lets code recolor trim per tier.
9. **Collision:** use Box or Hull for props players punch, and keep the hit detection on a separate invisible box part.

**Cartoon look on meshes**
- Use chunky silhouettes and a small bevel (0.05–0.15 studs, 1–2 segments) on every hard edge so edges catch light.
- Flat or auto-smooth shading at about 30–40°.
- Use solid colors from a tiny palette: vertex colors, or a 256×256 palette atlas where each color is a flat swatch.
- For tier recolors from one texture, author the ColorMap near-white and set `SurfaceAppearance.Color` per tier. Use **TintMask** so only the trim takes the tier color.

### Gaps
- I couldn't verify whether `CreateMeshPartAsync` with a regular (non-editable) mesh asset ID needs the "Enable Mesh / Image APIs" toggle in published games. The docs I read tie the toggle to EditableMesh only.
- I found no official number for how many triangles "count" against draw-call batching, and no current official guidance on instancing identical MeshParts.
- I didn't check Rojo's support for `.rbxm` files with MeshParts, or how it handles MeshId on sync.
- I didn't fetch the official glTF 2.0 spec (khronos.org untested). The OBJ citation is a loader README, not the original spec.

## 3. How to model specific props: bags, frames, boxing ring, gym equipment

### Takeaway
What makes props read as "real" is hardware and construction:
- **heavy bag:** four top D-rings, a chain spider to a center swivel, end caps, seams, straps
- **speed bag:** teardrop bag under a wooden rebound platform on a steel bracket
- **double-end bag:** a ball tied to floor and ceiling with bungees and carabiners
- **boxing ring:** 4 ropes at standard heights, 16 turnbuckles, corner pads (1 red, 1 blue, 2 white), canvas, and an apron that sticks out past the ropes

For a cartoon look, keep the real parts but blow up the hardware (D-rings, chains, swivels, pads) to 2–3× real proportions, and use bulging silhouettes.

### Cited Findings
- **Heavy bag rigging:** "The chain attaches to the D-rings located at the top of your heavy bag, and the swivel then connects to the center of the chain assembly". Heavy bags "typically have four top D-rings", which are "welded steel D-rings with leather reinforcement". **[S]** — [Revgear Heavy Duty Chain & Swivel](https://revgear.com/products/heavy-duty-chain-and-swivel); [Title Boxing heavy bag accessories](https://www.titleboxing.com/punching-bags/heavy-bag-accessories)
- **Speed bag platform:** "heavy-duty steel frame … mounting on wood stud or concrete walls and features a finished wood platform". **[S]** — [Title Boxing heavy bag accessories](https://www.titleboxing.com/punching-bags/heavy-bag-accessories)
- **Double-end bag:** steel D-ring mounts "anchor double-end bags to both the floor and ceiling" with "bungees and carabiners" and metal swivel bearings. **[S]** — [Meister double-end D-ring kit](https://meisterelite.com/products/meister-double-end-speed-bag-d-ring-anchor-mounting-kit-w-bungees)
- **Other bag types [S]:**
  - Wrecking-ball/uppercut bag: teardrop or sphere, ~30×25 in, ~60 lb, used for uppercuts.
  - Banana bag: "thinner and longer" than a heavy bag, for low kicks.
  - Wall-mounted uppercut bag: "flat surface and an angled striking area".
  - Bags range from 2.5 ft to 6 ft long; heavy bags typically weigh 70–150 lb.
  - Sources: [Academy – Types of Punching Bags](https://www.academy.com/expert-advice/types-of-punching-bags); [KeenFighter – Types of Punching Bags](https://keenfighter.com/types-of-punching-bags/); [Ringside buyer's guide](https://blog.ringside.com/a-buyers-guide-to-punching-bags-what-style-is-right-for-you/); [Dick's punching bag buying guide](https://www.dickssportinggoods.com/protips/sports-and-activities/exercise-and-fitness/choose-right-punching-bag-workout)
- **Tire bag:** tires used for bags weigh 6–15 kg each. "Four regular size tires (about 23″ diameter) will weigh about 80–90 lbs." A tire stack can work as both an uppercut bag and a heavy bag. **[S]** — [6 Dragons Kung Fu – tire punching bag](https://www.6dragonskungfu.com/how-to-make-a-punching-bag-with-tires/); [CKA Power – tire heavy bag](https://ckapower.wordpress.com/2015/02/14/how-to-make-a-tire-heavy-bag/)
- **Boxing ring [S]:**
  - Four ropes under tension from turnbuckles; "A professional 4-rope ring has 16 turnbuckles; 4 in each corner".
  - Ropes about 4 cm thick at 40 / 70 / 100 / 130 cm, or about 1 in at 18 / 30 / 42 / 54 in.
  - Corner pads: red near-left, white far-left, blue far-right ("2 white, 1 red and 1 blue").
  - Non-slip canvas over the whole platform; apron extends 85 cm past the ropes.
  - AIBA ring: 6.10 m square inside the ropes, platform 100 cm high.
  - Sources: [Wikipedia – Boxing ring](https://en.wikipedia.org/wiki/Boxing_ring); [Deportrainer – Boxing ring parts](https://www.deportrainer.com/en/blog-deportrainer/78_boxing-ring-parts); [boxingringprofessional – specs](https://boxingringprofessional.com/pages/pages-understanding-professional-boxing-ring-specifications/); [CITS WA – Boxing dimensions](https://www.cits.wa.gov.au/sport-and-recreation/sports-dimensions-guide/boxing)
- **Scale reference from our earlier research:** pro cartoony builds scale everything against the ~5-stud character, use SmoothPlastic, chunky shapes, faceted curves and bright colors, and never leave coplanar overlaps. **[S]** — summarized in `research_notes/Cartoony Roblox building UI and animation/building_stylized_techniques.md` (citing DevForum and creator-docs)

### Inferences
**Size conversions** (inference; real proportions exaggerated for gameplay readability):
- Heavy bag body: 2.4–3 studs diameter, 5–6 studs tall, bottom at about 1.5 studs. The character's fists (~3 studs up) hit the middle third.
- Speed bag: 1.2 × 1.6-stud teardrop under a 4×3-stud platform at about 5.5 studs.
- Double-end ball: 1.6 studs at chest height, with bungees to a floor anchor and an overhead beam.
- Tire bag: 3–4 tires of 3.2-stud diameter × 1.2 width, stacked on a rope or chain.
- Ring: 24–28 studs inside the ropes, which is bigger than real (~17 studs) so several players fit. Platform 2.5–3 studs high, apron 2 studs, posts 6–7 studs. Ropes at 1.5 / 2.6 / 3.7 / 4.8 studs above the canvas, 0.35–0.45 studs thick (chunky).

**Detail kit that makes a bag read** (each item is 1–4 parts):
- Top and bottom end caps (a cylinder or a flattened sphere 1.05× the body diameter, in a contrasting color).
- 2–3 horizontal seam bands: thin cylinders 0.06 tall, +0.04 diameter, darker shade.
- 4 vertical seam lines: thin blocks 0.05 thick.
- A brand/logo plate (SurfaceGui text or Decal).
- 4 D-rings: torus mesh, or 2 thin cylinders, 0.5 studs.
- A 4-chain "spider" up to one swivel (Ball + Cylinder), then a single chain or eye-bolt to the frame.
- A strap band with buckle at mid-height.
- For lower tiers, worn patches, tape strips, a dangling tape end and stuffing poking out. Upper tiers get clean leather and gold hardware.

**Gallows/frame:** a square post, an L-arm with a diagonal brace (a 45° block) and a base plate, chunky at 0.8–1.2 studs. Lower tiers use wood planks with bolts; mid tiers black steel with welded corner gussets (wedges); high tiers gold or marble with Neon edge strips.

**Ring kit:**
- Platform with an apron skirt (dark color) and logo SurfaceGuis on all 4 skirt faces.
- 4 corner posts with padded covers in red, blue, white, white.
- 3 turnbuckle pads per corner on 3–4 rope rows.
- Ropes with 1–2 vertical "rope spacers" per side.
- Steps at one neutral corner, canvas with a center logo, and 4 overhead spotlights.

**Cartoon exaggeration rules:**
- Bulge the bag: middle 5–10% wider than the caps, made from stacked cylinders or a lathe mesh.
- Oversize the hardware 2–3×.
- Round everything that is round in real life (no 4-sided "cylinders").
- Use thick, simple shapes rather than many thin ones.
- Saturated color blocking: a body color, a cap/trim color and a metal color per station, plus the tier color as the accent.

### Gaps
- I found no source documenting how real heavy bags place their seams and stitching patterns, or what label/logo conventions they use. The detail kit above is design inference.
- I found no source on how existing Roblox boxing games model their rings or bags.

## 4. Making parts-only props look less blocky

### Takeaway
Roblox gives five Part shapes (Ball, Block, Cylinder, Wedge, CornerWedge) plus SpecialMesh shapes. The main tricks are:
- **Sphere SpecialMesh:** freely scalable on all axes, so you get ellipsoids and caps.
- **Edge-rotated blocks:** octagons and other faceted rings.
- **Wedge/CornerWedge bevels:** chamfered edges and corners.
- **Shell + cylinder rounding:** rounded-edge blocks.
- **Negate/union:** outline rims.

Keep coplanar faces apart to avoid z-fighting. Hold part budgets to a few dozen per bag station. Unions and meshes reduce draw calls for repeated shapes.

### Cited Findings
- `Part.Shape` (Enum.PartType) offers Ball, Block, Cylinder, plus Wedge and CornerWedge. **[V]** — [creator-docs Part.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Part.yaml)
- SpecialMesh `Sphere` "can be freely resized on all axis", unlike a Ball part. Other types are Cylinder, Wedge, Brick, Head, FileMesh, and Torso (to be deprecated). A SpecialMesh changes appearance only; collision stays the parent part's, and Material doesn't render on it. **[V]** — [creator-docs SpecialMesh.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SpecialMesh.yaml)
- **Octagon:** 8 parts (e.g., 2×2×2), each moved 2 studs and edge-rotated 45° in turn (F3X "edge rotation"). **[S]** — [Making a Octogon (DevForum)](https://devforum.roblox.com/t/making-a-octogon/1120802); [Problem with Octagon Mesh (DevForum)](https://devforum.roblox.com/t/problem-with-octagon-mesh/611889)
- **Rounded block:** a core block, plus thinner "shell" plates on each face, plus cylinders twice the shell depth along each edge, sunk until only ¼ sticks out. **[S]** — [How to make a rounded block (DevForum)](https://devforum.roblox.com/t/how-to-make-a-rounded-block/2387408)
- **Cylinder outline/rim:** duplicate the cylinder twice (one taller but narrower, one wider but shorter), negate the duplicates and union. **[S]** — [Ways to Create Outline on a cylinder (DevForum)](https://devforum.roblox.com/t/ways-to-create-outline-on-a-cylinder/1116612)
- **Bevels from wedges:** split the part, put wedges along the edges, and add corner wedges where two bevels meet. **[S]** — from our earlier notes, citing [How to make corners, bevels and curves (DevForum)](https://devforum.roblox.com/t/how-to-make-corners-bevels-and-curves-specifically-from-classic-builds/3523451)
- **Draw calls:** 2 parts are 2 draw calls; a union of them is 1. **[S]** — [Performance Question – Parts or Unions (DevForum)](https://devforum.roblox.com/t/performance-question-parts-or-unions/1360129)
- **Scripted CSG:** `GeometryService:UnionAsync(main, others, {CollisionFidelity, RenderFidelity, SplitApart})` lets code do CSG at build time. The `rbxNegate` tag performs negation from script. **[V]** — [creator-docs parts/solid-modeling.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/solid-modeling.md)
- **Swept shapes:** `GeometryService:SweepPartAsync(part, cframes)` makes a MeshPart shaped like the part dragged through the CFrames (e.g., a Ball swept along a spiral). It is **beta** ("Solid Modeling On Meshes"), so it may not run in live games yet. **[V]** — same source

### Inferences
Parts-only recipes (inference; verify in Studio):
- **Round bag body:**
  - Use a Cylinder part rotated so its axis is vertical. Roblox cylinders extend along their local X axis, which is practitioner knowledge; verify.
  - Stack 3 cylinders, middle 1.06× diameter, for the bulge.
  - Cap top and bottom with Ball parts that each carry a Sphere SpecialMesh scaled flat (e.g., Scale (1, 0.35, 1) relative to part size), or with slightly larger thin cylinders as cap rims.
- **Tire:**
  - Cylinder (dark gray, 1.2 wide × 3.2 diameter) plus a slightly smaller, darker cylinder 0.02 proud on each face for the sidewall.
  - Black rim insert cylinder.
  - Tread: 16–24 thin blocks rotated around the circumference (2π/N spacing, from code).
  - Hole: a black SmoothPlastic cylinder inset, or a negated cylinder unioned once at build time.
- **Chains:** alternating links of 2 thin blocks or small torus-like rings (a cylinder with Sphere SpecialMesh flattened), rotated 90° per link. For long runs, a `Beam` with a chain texture or a `RopeConstraint` (Visible) is cheaper.
- **Ropes (ring):** cylinders between posts, plus a sagging middle via 2–3 segments. Use Neon at tiers 8–9.
- **Faceted pedestals:** octagonal or dodecagonal plinths from N blocks rotated about Y, with each block's width set to `2·r·tan(π/N)` (code-generated), plus a wedge bevel ring on top.
- **Z-fighting:** never let two faces share a plane. Offset decals and trims by ≥0.01–0.02 studs, or make trims slightly larger (+0.04) than the surface they wrap.
- **Part budgets (rule of thumb):**
  - Tier 1–3 stations: ~25–50 parts.
  - Tier 4–7: ~50–90.
  - Gold Bag: ~100.
  - Champ Ring: ~150–250.
  - Static decorative clusters can be unioned once at build time with `GeometryService:UnionAsync` (one draw call). Keep tier-recolored trim as separate parts so code can still recolor it.
- **Shared detail parts:** build repeated parts (D-ring, swivel, turnbuckle pad, logo plate) from one Luau builder function, so all 9 stations share the same high-quality detail and only differ in palette, material and FX.

### Gaps
- I found no official Roblox guidance on part-count budgets per prop, and no current measured data on draw-call batching or instancing of identical Parts vs MeshParts in 2025–2026.
- The cylinder-axis orientation and the Sphere-SpecialMesh scale semantics come from practitioner knowledge, not docs I read (`DataModelMesh.Scale` details weren't checked).

## 5. Presentation of unlockable stations: pedestals, locked/unlocked states, teasers, in-world prices

### Takeaway
Hit simulators gate content with something physical and in-world: a portal costing rebirths (Muscle Legends), or a big object blocking the doorway (Strongman). The price is shown on a large, readable label. For Hood:
- **Locked bags:** dark or desaturated silhouettes, with padlock/chains and a tier-colored price label.
- **Next unlock:** only the next bag gets an attention cue (beam, bobbing arrow, progress bar). Further tiers stay mysterious.
- **On unlock:** a burst of FX.
- **Labels:** a BillboardGui for floating prices that face the camera, and a SurfaceGui on a pedestal plate for the diegetic nameplate.

### Cited Findings
- **Muscle Legends** gates gyms behind portals costing rebirths (Mythical Gym is "a portal to the gym that costs 5 rebirths"). The top gym's portal has "electric effects". **[S]** — [Mythical Gym](https://muscle-legends.fandom.com/wiki/Mythical_Gym); [Legends Gym](https://muscle-legends.fandom.com/wiki/Legends_Gym)
- **Muscle King Gym** is an exclusive single-occupant spot, a status display other players can see. **[S]** — [Muscle King Gym](https://muscle-legends.fandom.com/wiki/Muscle_King_Gym)
- **Strongman Simulator:** "each [area] with a large object blocking the door. Players need to pump themselves up to the point where they can drag these objects out of the way." The gate is itself the strength check. **[S]** — [Strongman Simulator (Roblox fandom)](https://roblox.fandom.com/wiki/The_Gang_Stockholm/Strongman_Simulator)
- **PS99** announces rare variant hits server-wide, which advertises high tiers to everyone. **[S]** — [Gargantuan Pets (PS99)](https://pet-simulator.fandom.com/wiki/Gargantuan_Pets_(Pet_Simulator_99))
- **Simulator gate label** ("Cash Needed: $400") as a SurfaceGui: the fix for small text was to *decrease* `SurfaceGui.PixelsPerStud` so text renders larger. **[S]** — [Large SurfaceGui text for simulator display (DevForum)](https://devforum.roblox.com/t/large-surfacegui-text-for-simulator-display/3083555)
- **PixelsPerStud:** "Higher values will cause the various GuiObjects within to appear smaller … lower values will cause objects to appear larger". Pick it "based on how far away you expect a player to view the SurfaceGui". A large pixel density on a big face can hurt performance. **[V]** — [creator-docs SurfaceGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SurfaceGui.yaml)
- **BillboardGui** exposes AlwaysOnTop, Brightness, DistanceLowerLimit/UpperLimit, LightInfluence, MaxDistance, StudsOffset and StudsOffsetWorldSpace. **SurfaceGui** exposes AlwaysOnTop, Brightness, LightInfluence, MaxDistance, PixelsPerStud and SizingMode. **[V]**, property names only — [BillboardGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/BillboardGui.yaml); [SurfaceGui.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SurfaceGui.yaml)
- **Highlight** (useful for silhouettes and outlines): FillTransparency, OutlineColor, DepthMode Occluded/AlwaysOnTop, 255 on-screen limit. **[V]** — [creator-docs Highlight.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Highlight.yaml)
- **Emissive masks** give glowing text or logos on a mesh (e.g., a glowing price or logo plate) without full-Neon surfaces. **[V]** — [creator-docs surface-appearance.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/art/modeling/surface-appearance.md)

### Inferences
**State recipe for each station** (inference; Hood already has "locked-bag silhouettes" per `hood/README.md`):
- **Locked, far tier (2+ tiers ahead):**
  - Silhouette: a Highlight with FillColor near-black, FillTransparency ~0.1–0.2, OutlineColor = tier color, DepthMode Occluded. Or set the bag parts to dark gray SmoothPlastic and disable FX.
  - Label: "???" plus the price in a BillboardGui (MaxDistance ~60–80, LightInfluence 0, AlwaysOnTop false).
  - Keep the pedestal and the tier-color trim visible so players can see the ladder of colors from spawn.
- **Locked, next tier (the teaser):**
  - Reveal the full-color model behind a translucent "glass" box (ForceField or Glass), or keep the silhouette but add chains wrapping the bag and a padlock part.
  - Add a pulsing tier-colored Beam/arrow above it.
  - Show a BillboardGui with "🔒 150 Power" and a progress bar (current/required) that updates live.
  - Optionally show a ghost preview of the multiplier ("x4").
- **Unlockable now:** the padlock shakes, the label turns green ("TAP TO UNLOCK" / "UNLOCKED!"), the beam brightens.
- **Unlock moment:**
  - Chains and padlock fall (unanchor + tween), a burst ParticleEmitter in the tier color, a sound, and a camera pulse.
  - The bag swings in from above or rises from the pedestal; the Highlight is removed.
  - Toast UI "NEW BAG: Street Bag x4".
  - Tier 8–9 unlocks could be announced server-wide, PS99-style.
- **BillboardGui vs SurfaceGui:**
  - BillboardGui suits price/requirement and "x-multiplier" labels that must read from any angle. Use StudsOffset of about 1.5–2 studs above the bag top, with DistanceUpper/LowerLimit to keep text a constant size.
  - SurfaceGui suits the permanent nameplate on the pedestal front (name, multiplier, tier stars) and logo plates. Use about 50 PixelsPerStud for readable-from-distance text, with LightInfluence 0 so it doesn't go dark at night.
- **Pedestals as tier signals:**
  - Raise height and step count with tier (flush → pallet → curb → plinth → 1-step → 2-step → stage → round gold dais → ring).
  - Add 1–3 stars or chevrons on the nameplate, PS99-style.
  - The pedestal trim strip should be the tier color, and Neon from tier 4 up.

### Gaps
- I couldn't view screenshots or videos of how Muscle Legends, Gym League or punch simulators present locked equipment in-world (silhouette vs padlock vs hologram). These recipes are generic best-practice inference.
- I found no data on which locked-state style converts or retains players best.
