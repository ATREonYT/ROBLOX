# Stylized / cartoony "simulator-style" building techniques for Roblox (part-based, generated from Luau)

Source-access note for the report writer: the research sandbox's egress proxy blocked direct page fetches from devforum.roblox.com, create.roblox.com, roblox.fandom.com, en.wikipedia.org, reddit.com and several blogs. So the evidence comes in two strengths. Findings marked **[V]** were read first-hand: either from Roblox's official documentation source repo (github.com/Roblox/creator-docs, the same content that create.roblox.com/docs serves) or from data I parsed myself. Findings marked **[S]** come from search-engine result summaries of the linked page. Their wording and attribution are less certain (a summary can merge several results), so treat them as community consensus rather than exact quotes. Everything under "Inferences" is my own synthesis or recommendation for Hood and is not sourced.

## 1. What makes a Roblox build look professionally stylized/cartoony rather than amateur?

### Takeaway
Professional cartoony builds follow one consistent style. SmoothPlastic covers most surfaces, shapes are simple and chunky, curves are faceted (wedges, corner wedges, octagons), and colors are bright. Every large surface gets depth (trim, insets, extrusions, pillars, bevels). Repetition is deliberately varied, detail is concentrated around focal points, and empty flat ground is filled with clustered props. Everything is scaled against the 5-stud character, with an occasional oversized landmark for a sense of scale. Coplanar overlaps (z-fighting) are never left in the build.

### Cited Findings
- **Material/style baseline.** The cartoony, color-saturated style is usually achieved with SmoothPlastic, no decals or textures (or only very simple ones), and Lighting that makes the colors pop. Some builders blend textures in, but "smooth plastic should always make up the majority" to keep the low-poly look. **[S]** — [Stylized Low Poly (DevForum)](https://devforum.roblox.com/t/stylized-low-poly/3781693); [How to create a low poly look/vibe using ROBLOX studio blocks](https://devforum.roblox.com/t/how-to-create-a-low-poly-lookvibe-using-roblox-studio-blocks/278566)
- **Shape language for low-poly.** Low-poly styles use very few true circles or cylinders. Builders use octagons or even hexagons, and swapping cylinders for octagonal shapes is a recommended fix. Detail should be limited compared with realistic builds: "more cartoony and bright". **[S]** — [Tips before creating a low poly building](https://devforum.roblox.com/t/tips-before-creating-a-low-poly-building/288652); [General tips and advice when it comes to low poly builds?](https://devforum.roblox.com/t/general-tips-and-advice-when-it-comes-to-low-poly-builds/809506)
- In Roblox terms, "low poly" means using fewer bricks, which gives "a cartoony sort of feel". **[S]** — [Low-Polying Tutorial for Beginners: Low-Poly Basics](https://devforum.roblox.com/t/low-polying-tutorial-for-beginners-low-poly-basics/235354)
- **Cartoon principles cited by builders.** These include bold outlines, flat or no shading, a simplistic color palette, and bright scenery colors that contrast with characters. One builder's advice: "Use Smooth Plastic (Think of like a children's toy, it's always shiny smooth plastic.)" Cartoon houses use "a lot of uneven shapes". **[S]** — [How to achieve a cartoony styled game?](https://devforum.roblox.com/t/how-to-achieve-a-cartoony-styled-game/530900); [How to make the best cartoony feel](https://devforum.roblox.com/t/how-to-make-the-best-cartoony-feel/680546)
- **Outlines.** Mesh outlines are made by cloning a mesh at a slightly larger size with flipped normals or negative scale. This only works for meshes; inverted-hull meshes need Blender. **[S]** — [How to make a black outline](https://devforum.roblox.com/t/how-to-make-a-black-outline/482739); [What is this outline effect called…](https://devforum.roblox.com/t/what-is-this-outline-effect-called-and-how-can-it-be-achieved/1002032)
- **Highlight outlines.** A `Highlight` draws a silhouette outline plus a fill overlay. Studio displays at most **255** simultaneous Highlights on a client. A disabled Highlight still takes a slot, so delete Highlights you no longer need rather than disabling them. **[V]** — [Highlight API (creator-docs source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Highlight.yaml). The old limit was 31 before it was raised to 255. **[S]** — [Lights, Camera, More Highlights! (announcement)](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534)
- **Bevels and chamfers from primitives.** Beveled corners and edges are made with wedges. You split the part, put a wedge along the edge, and use more wedges for a rounder curve. Corner wedges are needed where two beveled edges meet. Union/Negate can also cut bevels, and the paid "Edge Bevel" plugin bevels edges and corners with a chosen radius. **[S]** — [How to make corners, bevels and curves? (DevForum)](https://devforum.roblox.com/t/how-to-make-corners-bevels-and-curves-specifically-from-classic-builds/3523451); [Edge Bevel (itch.io)](https://maxed-dev.itch.io/edge-bevel)
- **Depth and detail.**
  - Indents, bevels and extrusions add depth.
  - Edging or supports add character.
  - "A few brick slabs sprinkled on a building can make that building look 10x better."
  - PBR materials add detail without adding parts.
  - Use a Roblox character model (for example an R6 NPC) to check scale.

  **[S]** — [How to make builds look better - Advice](https://devforum.roblox.com/t/how-to-make-builds-look-better-advice/1816085); [Tips and Introductory Towards Roblox Building](https://devforum.roblox.com/t/tips-and-introductory-towards-roblox-building/1826639)
- **Breaking up flat walls.** Techniques builders recommend:
  - simple lines, pillars, bars, stripes and patterns
  - "tiny tiles"
  - columns on every corner
  - lights coming out of the wall
  - wedges on walls for curvature
  - engraved (unioned) insets and parts protruding from the wall
  - mixed window types, some detailed and some plain, to create variation and focal points
  - "rounded parts/anything non-flat"

  **[S]** — [How to put more detail on walls](https://devforum.roblox.com/t/how-to-put-more-detail-on-walls/636045); [How to fill up these walls with detail?](https://devforum.roblox.com/t/how-to-fill-up-these-walls-with-detail/617586)
- **Style consistency.** "If you want low poly, stay low poly." Mixing themes is a common mistake and hard to make look good. **[S]** — [Any tips on simulator map](https://devforum.roblox.com/t/any-tips-on-simulator-map/826579)
- **Scale against the character (official).**
  - Greyboxing exists partly to catch "assets with disproportionate scale to the user's character".
  - Roblox's sample deliberately adds one tower "much larger than the player to provide a sense of scale". Every other object is "about the size of the user's character", and the oversize piece creates intrigue.

  **[V]** — [Greybox your environment](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md); [Construct your world](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/construct-your-world.md)
- **Modular alignment and avoiding overlaps (official).**
  - Modular pieces need consistent pivots.
  - In the Modern City kit, every piece has a minimum length of 7.5 studs and lengths divisible by 7.5, "so every mesh can seamlessly align and connect without overlap even when you rotate them".
  - Worked example: a rotated 1-stud-thick wall moved in 5-stud increments ends up overlapping its neighbor by 0.5 studs.

  **[V]** — [Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md)
- **Reducing visible repetition (official).**
  - Overlay a grunge Decal or Texture on tiled walls.
  - Dress each module with props (fire escapes, window balconies, AC units, foliage): "Even just including a few decorative props can add a vast amount of storytelling."
  - Tileable textures should not contain a single standout element, which makes the repetition obvious.

  **[V]** — [Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md); [Develop polished assets](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/develop-polished-assets.md)
- **Z-fighting.** Z-fighting happens when two surfaces render in the same place. Community fixes are offsetting one part by about 0.001 studs ("hard to notice") or unioning the parts. Unions are noted as costly and can break collisions. Plugins exist to strip z-fighting automatically. **[S]** — [How to fix clipping - z fighting issue](https://devforum.roblox.com/t/how-to-fix-clipping-z-fighting-issue/735036); [Advanced Z-Fighting Remover plugin](https://devforum.roblox.com/t/advanced-z-fighting-remover-plugin/2833769); [Remove Z-Fighting via Intersections](https://devforum.roblox.com/t/remove-z-fighting-via-intersections-plugin/2865317). A 2025 engine-bug thread is titled "Parts randomly changed their size when using a Z-fighting prevention trick", which suggests tiny-offset tricks can be fragile; I could only see the title. — [DevForum bug report](https://devforum.roblox.com/t/parts-randomly-changed-their-size-when-using-a-z-fighting-prevention-trick/4007417)

### Inferences
Concrete rules for a code generator (my synthesis):

- **Chunky proportions.**
  - Make trims, frames, sills, cornices and railings at least 0.5–1 stud thick. Never use the 0.05–0.2-stud "realistic" detail, which reads as noise or vanishes at simulator camera distances and on phones.
  - Props should be about 1.3–2× real-world size relative to the 5-stud character: oversized lamps, mailboxes, hydrants, dumbbells, signs.
  - Keep a few hero landmarks (the gym and the shop) at 3–6× character-scale massing.
- **Silhouette first.** Every building or prop should read by its outline alone. Use stepped or stacked masses (plinth → body → cornice → roof parapet). Avoid single boxes. Vary roof heights between neighbors by 2–6 studs.
- **The "chamfered top" primitive is the single best cartoon upgrade** for platforms, stages, walls, curbs and sign boards. Recipe for a block of size (X, Y, Z) with bevel b, where b ≈ 8–15% of the smallest dimension and usually 0.5–1.5 studs:
  1. Core block (X, Y−b, Z).
  2. Top cap block (X−2b, b, Z−2b).
  3. Four WedgeParts (edge-length, b, b) along the top edges, sloping outward.
  4. Four CornerWedgeParts (b, b, b) at the corners.

  The same function with all 12 edges gives a fully chamfered block. Cap the result at roughly 9–13 parts per prop.
- **Faceted curves.**
  - Make columns, tree trunks, pots and lamp posts as 6- or 8-sided prisms: N thin blocks rotated 360/N, or two square blocks rotated 45° for an octagon.
  - Reserve the true Cylinder and Ball shapes for intentionally "bubbly" items: foliage, clouds, coins.
  - Do not mix both styles on the same object type.
- **Detail density hierarchy.**
  - Primary forms (ground, buildings, landmarks): about 60% of what the eye sees, mostly flat color.
  - Secondary detail (trim, windows, awnings, fences, curbs): placed on every vertical face that faces a play path.
  - Tertiary props (bins, cones, flowers, signs, crates): clustered in groups of 3–7 near entrances, corners, path edges and the spawn sight line.
  - Leave deliberate "quiet" areas (plain open plaza) so busy areas read. A rough density target is about 1 prop cluster per 15–25 studs of path edge.
- **Variation without chaos.** For every scattered instance:
  - Randomize yaw 0–360° for organic items.
  - Randomize scale ×0.8–1.25.
  - Tilt rocks and foliage 0–10°.
  - Jitter color by about ±4–8% value and ±0.01–0.02 hue around a palette base.
  - For buildings, randomize from a small set: 3–4 façade colors, 2–3 window styles, 2–3 roof or cornice variants, optional awning, AC unit, sign or plant.
  - Never place two identical variants adjacent to each other.
  - Keep the macro layout symmetric or radial for readability, but break symmetry in the props.
- **Z-fighting rules in code.**
  - Never leave two coplanar faces of different parts. Inset or outset decorative layers by at least 0.02–0.05 studs. I suggest 0.05 for safety rather than 0.001, given float-precision issues at large world coordinates and the bug report above.
  - When a trim overlaps a wall, make the trim protrude clearly (0.25+ studs) or sit flush in a recess.
  - Snap generated geometry to a 0.25- or 0.5-stud grid, with modules on 4/8/12-stud multiples, so seams close exactly.
  - Prefer exact abutment over overlap.

### Gaps
- I could not read any single authoritative stylized-building guide in full; DevForum was blocked. The numeric thresholds above (bevel %, trim thickness, prop scale multipliers, density per stud) are my heuristics, not sourced figures.
- I found no source quantifying "how much detail" top simulator maps use (parts per area, etc.).

## 2. Color and materials: palettes, SmoothPlastic vs Plastic, studs in modern Roblox

### Takeaway
Cartoony simulator palettes are rich and saturated, but saturation goes on accents and interactables while large surfaces get softer, slightly desaturated versions. That gives value contrast and avoids a "rainbow"/eye-strain look; a 60-30-10 split is the common heuristic. SmoothPlastic is the default cartoony material. In 2025–2026, Studs/Inlet SurfaceTypes still render visually: joining behavior is deprecated, not the visuals, and the studs appear only on Plastic material. They are no longer the default on new parts. The modern alternatives are a tiling `Texture` with a stud image or a `MaterialVariant`.

### Cited Findings
- **Color guidance from builders.**
  - Cartoony palettes need "rich" colors and should avoid pale, dull ones.
  - Bright "simulator" games favor high-saturation yellows, pinks and sky blues.
  - A common mistake is colors that are too bright or saturated, causing eye strain. Use desaturated versions for large surfaces (floors, walls, sky) to avoid a "rainbow effect".
  - Simulators use very simple textures and plastic materials with simplified low-poly models.

  **[S]** — [Suiting colours for builds](https://devforum.roblox.com/t/suiting-colours-for-builds/808280); [How could I make a cartoony type of building?](https://devforum.roblox.com/t/how-could-i-make-a-cartoony-type-of-building/866347); [Tips on building simulators](https://devforum.roblox.com/t/tips-on-building-simulators/264791). The summary did not say which thread made which point.
- Builders often push ColorCorrection saturation and bloom too far, which hurts the cartoony look. This is a lighting topic, mentioned here only because it interacts with part colors. **[S]** — [Cartoon Lighting Help](https://devforum.roblox.com/t/cartoon-lighting-help/3602579); [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686)
- **60-30-10 rule.** 60% primary (often neutral or soft), 30% secondary, 10% accent. **[S]** — [howtoguidedepot palette guide](https://howtoguidedepot.com/how-to-roblox-how-to-make-a-color-palette/) (low-authority site). DevForum's color-theory tutorial covers monochromatic, analogous and complementary palette types. **[S]** — [Game Development Theory 101](https://devforum.roblox.com/t/game-development-theory-101/457156)
- **General art theory.** Saturated colors advance and desaturated colors recede. Desaturating the background while keeping the foreground saturated is a fast way to create depth and hierarchy. **[S]** — [Russell Collection: color saturation](https://russell-collection.com/what-is-color-saturation-in-art/); [ColorFYI: value and contrast](https://colorfyi.com/blog/color-value-and-contrast/) (general art blogs, moderate authority)
- **Material defaults and MaterialVariant (official).**
  - The default material for a new Part is **Plastic**.
  - Custom tileable materials are `MaterialVariant` instances in `MaterialService`, with **StudsPerTile** and **Pattern** (`Enum.MaterialPattern` = Regular / Organic) properties.
  - A variant can be set as a **material override** so every part using the base material uses it. This is the only way to restyle terrain materials.
  - Naming advice: PascalCase starting with the base material (e.g., `GrassWet`).
  - Plastic and SmoothPlastic textures are "bundled with Studio" rather than exposed as asset IDs.

  **[V]** — [Materials (creator-docs)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/materials.md) / [create.roblox.com/docs/parts/materials](https://create.roblox.com/docs/parts/materials)
- **Textures (official).** A `Texture` repeats across a face, while a `Decal` stretches. `StudsPerTileU/V` set the tile size; `OffsetStudsU/V` shift or animate it; `Color3` tints (e.g., [255, 0, 100]); `Transparency` runs 0–1; `Face` selects the side. **[V]** — [Textures and decals](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/textures-decals.md)
- **SurfaceType status (official).**
  - "SurfaceType joining is deprecated, leaving only visual changes on the affected Part."
  - Studs = "Adds square studs across the surface"; Inlet = "square holes … where studs would be"; Universal = a checker of studs and inlets.
  - SmoothNoOutlines is "no longer relevant since outlines have been removed".
  - `BasePart.TopSurface` has no deprecation message.

  **[V]** — [SurfaceType enum](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/SurfaceType.yaml); [BasePart API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/BasePart.yaml)
- **2019 "Changes to Part Surfaces" announcement (Aug 19, 2019).** Stud, Inlet, Universal, Weld and Glue surface textures "will only appear on Plastic material parts, both in-game and in Studio". **[S]** — [Changes to Part Surfaces (DevForum announcement)](https://devforum.roblox.com/t/changes-to-part-surfaces/334420)
- **Studs today.**
  - Studs no longer appear on newly created parts or places, but can still be set from scripts or plugins, and the classic baseplate still shows them.
  - Today's studs are blank squares; the older versions carried an "R" logo or were 3D meshes.
  - The "Resurface" plugin bulk-converts surfaces to studs, inlets and so on.

  **[S]** — [Roblox wiki: Studs (surface)](https://roblox.fandom.com/wiki/Studs_(surface)); [Resurface plugin](https://create.roblox.com/store/asset/5070921519/Resurface-Convert-surfaces-to-studs-and-more); [How to add studs to my part?](https://devforum.roblox.com/t/how-to-add-studs-to-my-part/1236185)
- **Texture-based studs** (they work on any material, meshes and unions). The community method layers a grid image (`rbxassetid://6372755229`) and a stud image (`rbxassetid://18878365966`) as Textures. **[S, asset IDs not verified]** — [How to get stud texture?](https://devforum.roblox.com/t/how-to-get-stud-texture/4880386); [How to get back the old stud texture EASILY! (meshes & unions)](https://devforum.roblox.com/t/how-to-get-back-the-old-stud-texture-easily-includes-meshes-unions/3157449). A community "HD Stud Materials" MaterialVariant pack also exists. **[S, title only]** — [HD Stud Materials and Creation Pipeline](https://devforum.roblox.com/t/hd-stud-materials-and-creation-pipeline/2916846)
- **Verified Roblox BrickColor palette RGB values** (useful named anchors; parsed from the official BrickColor table). **[V]** — [BrickColor codes](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/BrickColor.yaml)

  | Group | Colors (R, G, B) |
  |---|---|
  | Greens | Bright green (75,151,75); Shamrock (91,154,76); Camo (58,125,21); Br. yellowish green (164,189,71); Medium green (161,196,140); Olivine (148,190,129); Mint (177,229,166); Moss (124,156,107); Earth green (39,70,45) |
  | Warm | Bright red (196,40,28); Persimmon (255,89,89); Salmon (255,148,148); Bright orange (218,133,65); Neon orange (213,115,61); Deep orange (255,176,0); Bright yellow (245,205,48); Daisy orange (248,217,109); Cool yellow (253,234,141); Gold (239,184,56) |
  | Browns / bricks | Nougat (204,142,105); Dark orange (160,95,53); Reddish brown (105,64,40); Brown (124,92,70); Pine Cone (108,88,75); Burnt Sienna (106,57,9); Brick yellow (215,197,154); Light brick yellow (240,213,160); Wheat (241,231,199); Sand red (149,121,119) |
  | Blues / purples / pinks | Bright blue (13,105,172); Electric blue (9,137,207); Cyan (4,175,236); Medium blue (110,153,202); Pastel light blue (175,221,255); Bright bluish green (0,143,156); Teal (18,238,212); Royal purple (98,37,209); Bright violet (107,50,124); Carnation pink (255,152,220); Hot pink (255,0,191); Light reddish violet (232,186,200) |
  | Neutrals | Institutional white (248,248,248); White (242,243,243); Light stone grey (229,228,223); Medium stone grey (163,162,165); Dark stone grey (99,95,98); Smoky grey (91,93,105); Black (27,42,53); Really black (17,17,17) |

  Note that Roblox's classic "Black" is a blue-black (27,42,53), not neutral.

### Inferences
- **Material rule for Hood.**
  - SmoothPlastic for about 85–95% of surfaces.
  - `Neon` only for small glowing accents: sign letters, lamp heads, gate barriers, "pressure pad" rings.
  - `Glass` or transparency 0.3–0.5 for windows if they are not opaque cartoon panes.
  - Optional realistic materials (Brick, Concrete, WoodPlanks) only as small "sprinkled" accents, or on the ground with a MaterialVariant at large StudsPerTile so the pattern stays bold and readable.
- **Studded "toy" look, if wanted.** Set `part.Material = Enum.Material.Plastic` and `part.TopSurface = Enum.SurfaceType.Studs`, keeping the other faces Smooth. This renders today but only on Plastic, and only on Part/WedgePart-style parts. For meshes, unions, or studs on SmoothPlastic, use a `Texture` (Face = Top, StudsPerTileU/V = 1 for 1-stud studs or 2 for chunkier ones, Color3 tinted to the part color, Transparency about 0.3–0.6). Use studs selectively, e.g., on boxing-ring floors, stage platforms and curb tops. Covering everything looks "classic Roblox", not "modern simulator".
- **Palette construction rule (HSV)** — a heuristic, not sourced:
  - Large surfaces (ground, roads, walls): S 20–55%, V 55–85%.
  - Mid elements (buildings, trees): S 45–75%, V 60–90%.
  - Accents and interactables (shop signs, gates, buttons, coins, pads): S 75–100%, V 90–100%, with complementary hues against their background.
  - Shade sides and recesses with hue shifted toward blue/purple and V −15–30%. Highlights shift toward yellow and V +10%.
  - Avoid pure greys and pure black. Tint neutrals warm (sidewalks) or cool (asphalt).
  - Limit each zone to about 5–7 base colors plus 1–2 accents.
- **Suggested Hood palette (hex; my proposal, built to the rule above).**

  | Element | Hex values |
  |---|---|
  | Asphalt | #4A4E5C |
  | Road lines | yellow #FFD84A; white #F4F1E8 |
  | Sidewalk / curb | sidewalk #CFC8B8; curb #E9E3D3 |
  | Rowhouse bricks | red #B8533D; orange #C9744C; maroon #9C4848; tan #D6A267; blue-grey painted #6F7FA6 |
  | Trims / cornices / frames | cream #F3E9D6; dark plum outline #3D3550 |
  | Windows | day glass #8FD8F8; lit #FFF1A8 |
  | Grass | #6CC24A / #57AE3E / #9BE05A |
  | Foliage | #5DBB3F, #7ED957, #3E9B3A |
  | Trunks | #8B5A3C |
  | Water | #4FC3F7, foam #E6F7FF |

  Zone accent colors:
  - gym: red #FF4B4B + gold #FFC93C
  - clothing shop: pink #FF7AC8 + cyan #43D3FF
  - stage / break walls: purple #9B5CFF + orange #FF9F1C
  - teleport / gates: neon cyan or green
- **Per-zone color identity.** Give each zone (spawn plaza, gym block, shopping street, stages) one dominant accent hue. Players should be able to recognize the zone from a distance and in thumbnails.

### Gaps
- I found no published, verified hex palettes taken from specific hit simulators (PS99, Bee Swarm, etc.). Any palette attributed to those games would need color-picking from screenshots, which I could not do here.
- The two stud asset IDs could not be verified, because create.roblox.com was blocked.
- I could not confirm whether Roblox has shipped any newer built-in "studs" material in 2025–2026; I found no evidence of one.

## 3. How hit-simulator lobbies are laid out: spawn, sight lines, hubs, shops, scale, guidance, gates

### Takeaway
Hit simulators use a central spawn hub that shows the core loop from the spawn camera: the main activity, shop, sell/upgrade and leaderboards are all within a few seconds' walk. Progression runs outward through a linear chain of themed zones separated by currency-locked gates. Players are guided by landmarks, in-world signs, glowing trails/arrows and bright interactables. Build the greybox first using real numbers (character about 5 studs tall, walk speed 16 studs/s, passages of at least 10 studs), then fill empty ground with prop clusters.

### Cited Findings
- **Movement and scale numbers (official).**
  - Default `WalkSpeed` is 16 studs/s.
  - Default `CharacterJumpHeight` is 7.2 studs.
  - A stud is about 28 cm.

  **[V]** — [Humanoid API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Humanoid.yaml); [StarterPlayer API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/StarterPlayer.yaml); [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)
- **Official greybox sizing.**
  - Every doorway and hallway is at least **10 studs wide** and every wall at least **10 studs tall**, so two players can pass and the camera can maneuver without clipping.
  - Transform snapping is set to **5 studs / 90°**.
  - Elevation "peaks and valleys" are used to control sight lines.
  - Spawn zones have **two exits** to avoid bottlenecks.

  **[V]** — [Greybox your environment](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md). The doc also says 10-stud walls stop jumping "with Roblox's default jump height of 5 studs", but the API default is 7.2 studs [V], so the doc is internally inconsistent; use 7.2.
- **Character size and doors.** The avatar is about 5 studs tall. One source suggests doors of 7–8 studs tall × 3 studs wide and rooms 10–12 studs high. **[S, low-authority aggregator]** — [socialagechecker: How tall is a Roblox character](https://socialagechecker.net/blog/how-tall-is-a-roblox-character/); [Playgama](https://playgama.com/blog/game-faqs/how-tall-is-a-roblox-character-in-feet-or-studs/). This conflicts with Roblox's own ≥10-stud passage guidance above. Realistic doors are too tight for crowded simulator lobbies.
- **Progression by elevation (official example).** Island Jump's platform heights rise by 8, 20, 35, 55, 81 and 110 studs. Any level needing an upgrade should sit at least 30 studs above the previous one. **[V]** — [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)
- **Guidance and onboarding (official).** Effective visual elements include "a bouncing arrow pointing at a button", "a glowing trail in the world that directs players to a destination", and "an in-world sign displaying a game's core loop". In *Color or Die*, the core-mechanic sign is placed "directly in players' line of sight" at their first pickup. Players skip text, so show rather than tell. **[V]** — [Onboarding techniques](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/onboarding-techniques.md)
- **Simulator map planning (community).**
  - Sketch the layout first, marking landmarks, paths, spawn points and zones.
  - Greybox, test, then layer detail.
  - A "horseshoe" shape lets players see the objective while working around obstacles; a circle leads back to the start.
  - Typical elements: shop, sell area, egg pods, KOTH, boss arena, portals.

  **[S]** — [Ruski's Tutorial #1 - How to design a map layout](https://devforum.roblox.com/t/ruskis-tutorial-1-how-to-design-a-map-layout/277853); [How do you make maps? (e.g. Open-World, Simulator)](https://devforum.roblox.com/t/how-do-you-make-maps-eg-open-world-simulator/1780074)
- **Center hub and fill (community).**
  - Put the spawn, leaderboards and a "step-on pad that opens the shop" in the center.
  - Add an AFK area, a power-up/rebirth shop area, and barriers around the whole map.
  - Fill empty space with rocks of different sizes and colors, grass and shrubs, rocky paths, mushrooms, benches, fountains, small ponds, flowers and crates.
  - Make trees and bushes CanCollide false if players keep bumping into them.

  **[S]** — [Simulator Map Suggestions](https://devforum.roblox.com/t/simulator-map-suggestions/1008279); [What should I add to fill space](https://devforum.roblox.com/t/what-should-i-add-to-fill-space-simulator-map/592273)
- **Lobby critiques (community).**
  - Oversized spawn pads crowd the central landmark ("if you shrank them… the central spire doesn't feel as crowded").
  - Fill empty spots with a small body of water, benches and pop-up shops or carts, plus flowers and bushes, "while still keeping an open feel".
  - Split shops into separate category shops for variety.

  **[S]** — [Lobby suggestions](https://devforum.roblox.com/t/lobby-suggestions/3736109); [Low poly-styled simulator lobby](https://devforum.roblox.com/t/low-poly-styled-simulator-lobby/683143); [Lobby layout seems crammed](https://devforum.roblox.com/t/lobby-layout-seems-crammed/3825272)
- **Beginner tutorial numbers.** Baseplate 200×5×200 in forest green, border walls rotated 45°, mushrooms in varied colors scattered around, rock paths. **[S]** — [How to Make A Simulator Map Part 1](https://devforum.roblox.com/t/how-to-make-a-simulator-map-part-1/1343396); video [YouTube TsPwsFh1JD4](https://www.youtube.com/watch?v=TsPwsFh1JD4)
- **Hit-game layouts** (secondary sources):
  - **Pet Simulator 99:** a linear sequence of themed zones unlocked with currency (World 1 has 99 zones, Meadow → Heaven gates), with Rebirth statues at areas 25, 50 and 75. **[S]** — [BIG Games DB: Areas](https://db.biggames.io/wiki/areas); [PS99 wiki: Areas](https://the-pet-simulator-99.fandom.com/wiki/Areas_(Pet_Simulator_99))
  - **Grow a Garden:** one large island with fenced garden plots (sources disagree: 6 plots, or 4 after a server-size change). Shops sit along the sides, with an event hub in the middle. The Seed Shop and "Sell Your Stuff" face the Gear, Pet and Cosmetics shops across the way. Each plot has a small decorative lake with rock borders, a big rock-mountain backdrop has a built-in staircase, and the outer edges are heavily decorated with trees, flowers, mushrooms, moss and rocks. **[S]** — [Grow a Garden wiki: Map](https://growagarden.fandom.com/wiki/Map); [Gameranx gear shop guide](https://gameranx.com/updates/id/543118/article/roblox-grow-a-garden-gear-shop-guide/)
  - **Steal a Brainrot:** 8 player bases lined up on both sides of a central studded red-carpet conveyor that runs between two tunnels. The shops (Item and Robux) sit next to the conveyor in the middle, so the conveyor is the focal point. **[S]** — [Sportskeeda map guide](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide); [Noleep red carpet guide](https://noleep.com/en/steal-a-brainrot-red-carpet-guide-all-brainrot-spawn-rates-tips/)
  - **Bee Swarm Simulator:** rectangular flower "fields" (patches) scattered across the map, color-coded red, blue and white. New players spawn near five free starter fields. **[S]** — [Bee Swarm wiki: Fields](https://bee-swarm-simulator.fandom.com/wiki/Fields)

### Inferences
Concrete Hood lobby template (my synthesis of the above):

- **Hub-and-spoke.**
  - Spawn plaza at the center, about 60–90 studs across, as an open "quiet" space with a small statue or fountain landmark.
  - Spawn locations face the primary landmark (the boxing gym façade with an oversized sign and glove).
  - From the spawn camera, the player should see the gym, the clothing shop, the leaderboards and the first breakable stage/wall without turning more than about 90°.
  - Spokes are 3–5 streets radiating to zones. Each street ends in a visible gate or landmark (a "weenie"), so every path has a destination.
- **Distances.**
  - Core loop stations (train → upgrade/sell → shop) within 30–80 studs of spawn, i.e., a 2–5 s walk at 16 studs/s.
  - Zones beyond the first sit 150–300+ studs out, with teleport pads in the hub.
  - Leaderboards stand next to the spawn and face it, at 12–20 studs tall so they are readable.
- **Path widths** (exaggerated cartoony scale):
  - Main street 24–32 studs total: road 16–20 plus sidewalks 4–6 each.
  - Secondary paths 10–14 studs; nothing under 10, per the Roblox guidance.
  - Doors on enterable buildings 8–12 studs tall × 6–10 wide; façade-only doors can be 7–8 × 4.
  - Building storeys 10–12 studs.
  - Rowhouse widths 16–24 studs each, so a block of 5–7 rowhouses has varied widths.
- **Gates between zones.** A big arch or wall cut (20–30 studs wide, 20+ tall) with:
  - a zone-colored Neon/transparent barrier part (CanCollide true until unlocked)
  - a BillboardGui or SurfaceGui price sign with a large icon and price
  - a short ramp or step up, so the next zone feels "higher"
  - a glimpse of the next zone's landmark visible over the wall
- **Guiding the eye.**
  - Key interactables get the highest saturation, Neon trim, and animated or bobbing icons.
  - Floor arrows or stripes on roads point to the next goal.
  - Optional Beam "glowing trail" from spawn to the current objective.
  - Big readable signage in 2–3 colors.
  - Ground color changes per zone, e.g., the gym block's sidewalk tinted red-brown and the shopping street's tinted pink-beige.
- **Fill rule.** No flat open area larger than about 30×30 studs without at least one prop cluster or landmark, except the intentional spawn plaza. Edges of the playable area get dense "backdrop" fill: taller buildings, trees, fences, a skyline of extra rowhouse façades. This hides map boundaries, which hit simulators do with mountains or heavy edge decoration.

### Gaps
- I found no first-hand teardown with measured dimensions of PS99, Grow a Garden, Muscle Legends, Strongman Simulator, Arm Wrestle Simulator or Anime Fighting Simulator lobbies (path widths, spawn-to-shop distances). The distances above are my recommendations.
- Muscle Legends, Strongman, Arm Wrestle and Anime Fighting Simulator layouts were not covered by any accessible source.

## 4. Prop and nature building: trees, bushes, rocks, clouds, water, fences, lamps, rowhouses

### Takeaway
Stylized foliage avoids "generic/AI" looks through irregular, layered clusters: several overlapping blobs of varied size and 2–3 related greens, with darker undersides and lighter tops, on tapered, slightly leaning trunks. Every instance is scattered with random scale, rotation and color. Low-poly props use faceted shapes (octagons and hexagons rather than cylinders). Buildings are modular, with consistent snapping and per-building variation from a small kit plus decorative props.

### Cited Findings
- **Stylized trees (Blender route; principles transfer).** Use as few planes or polygons as possible and put detail (branches, varied leaf size) in the texture. Leaves start as an ico-sphere with randomized vertices, or a UV sphere with proportional-edit noise and decimation; several such blobs are duplicated onto the tree. **[S]** — [Ultimate Guide to Stylized Trees on Roblox](https://devforum.roblox.com/t/ultimate-guide-to-stylized-trees-on-roblox/1124673); [How to make an amazing low poly tree](https://devforum.roblox.com/t/how-to-make-an-amazing-low-poly-tree/1483011); [Making a low poly tree in Blender](https://devforum.roblox.com/t/making-a-low-poly-tree-in-blender/1154974)
- **Parts-only trees.**
  - Duplicate a block, space it out, and rotate copies around a center to form a ring.
  - Duplicate and rotate the ring to form a spheroid.
  - Union it and squash or resize it to the desired canopy.
  - Sphere-cluster canopies are the other common no-Blender method.

  **[S]** — [How do you create stylized trees?](https://devforum.roblox.com/t/how-do-you-create-stylized-trees/1184253); [Efficiently building good looking trees (with CSG)](https://devforum.roblox.com/t/efficiently-building-good-looking-trees-with-csg/23976)
- **Low-poly terrain and rocks** use triangles and wedges. GapFill and "Atrazine's Terrain V2" are cited as the tools for the polygonal look. **[S]** — [Stylized Low Poly](https://devforum.roblox.com/t/stylized-low-poly/3781693)
- **Environment dressing seen in hits.** Grow a Garden has a decorative lake with rock borders in each plot, a rock-mountain backdrop with stairs, and outer edges heavily dressed with trees, flowers, mushrooms, moss and rocks. **[S]** — [Grow a Garden wiki: Map](https://growagarden.fandom.com/wiki/Map). Community fill lists: rocks of different size and color, shrubs, mushrooms, benches, fountains, ponds, flowers, crates. **[S]** — [What should I add to fill space](https://devforum.roblox.com/t/what-should-i-add-to-fill-space-simulator-map/592273)
- **Modular buildings (official).** Studio's Modern City template builds a whole downtown from reusable walls, windows and doors, then adds per-building props (fire escapes, window balconies, AC units, foliage) to make each one distinct. Modules use consistent corner pivots and 7.5-stud multiples. **[V]** — [Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md)
- **Planters, trims and tunnels (official).**
  - Planter variations in 'L' shapes, made by layering blocks with **white trim**.
  - Negate + Union to hollow planters or carve tunnels.
  - Props such as crates double as cover and visual variation.

  **[V]** — [Construct your world](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/construct-your-world.md); [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)
- **Clouds (official).** The `Clouds` object's **Density** runs from 0 (light, translucent) to 1 (heavy, dark); the tutorial uses values such as 0.5 and 0.285. **[V]** — [Construct your world](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/construct-your-world.md)
- **Windows and walls.** Vary window designs (some detailed, some plain), add pillars or columns at corners, stripes, and lights mounted on walls. **[S]** — [How to put more detail on walls](https://devforum.roblox.com/t/how-to-put-more-detail-on-walls/636045)

### Inferences
Part-based recipes for Hood (my synthesis; sizes relative to the 5-stud character):

- **Tree, not AI-ish.**
  - **Trunk:** 2–3 stacked octagonal or cylinder segments tapering from about 2.5 to 1.5 studs in diameter, 6–10 studs tall total. Lean 3–8° in a random direction. Add 1–2 short branch stubs at 30–45°. Color: warm brown, with a slightly darker bottom segment.
  - **Canopy:** 4–7 overlapping Ball parts (or blocks rotated 45° for a blocky style). One main blob of 9–13 studs, the others 45–80% of that size, offset asymmetrically upward and outward. Top blobs use the light green, side blobs the mid green, and the lowest or inner blobs the dark green (fake ambient occlusion). Squash some blobs on Y to 0.8–0.9×.
  - **Per instance:** scale ×0.75–1.3, random yaw, choose 1 of 3 canopy archetypes (round, tall/oval, wide/flat), hue jitter ±0.015.
  - **Placement:** in groups of 2–5 with spacing variance. Never in perfect rows except as deliberate street trees, and those still alternate size and variant.
  - Set CanCollide false on canopies and keep trunk collision.
- **Bush.** 2–4 flattened balls (Y 0.6–0.8) sunk 20–30% into the ground, 3–6 studs wide. Optional 3–5 tiny flower balls (0.6–1 stud) in an accent color on top.
- **Rocks.**
  - Clusters of 3: big, medium, small at about 1 : 0.6 : 0.35.
  - Each rock is a block or wedge combination rotated randomly (yaw 0–360°, tilt 5–25°) and sunk 25–40% into the ground.
  - Colors are cool greys tinted blue or purple with V variation ±8%.
  - Low-poly variant: use WedgePart/CornerWedgePart pairs for faceted tops.
- **Clouds** (if the dynamic Clouds object isn't used). 3–6 white SmoothPlastic flattened balls per cloud with CastShadow false, 20–60 studs long, at Y 150–300. Let them drift slowly.
- **Water (pond, canal, fountain).**
  - A thin SmoothPlastic part 0.2–0.5 studs below the bank top, color #4FC3F7, Transparency 0–0.2.
  - A lighter "foam" ring of thin parts or a Texture at the edge.
  - A rock or brick border with rounded or chamfered tops.
  - Optional slow `OffsetStudsU` texture scroll for ripples (uses the official Texture offset animation).
- **Fences.**
  - Posts every 4–6 studs, 0.6–1 stud thick, 3–4 studs tall, with chamfered or pointed tops (wedge caps).
  - 2 rails, each 0.4–0.6 thick.
  - Pickets white or cream for cartoon, chain-link or iron black-plum for the hood.
  - Jitter each post's height ±0.2 and tilt ±2° for hand-made charm.
- **Street lamps.**
  - Chunky octagonal post 1–1.5 studs thick, 12–16 studs tall, with a wider base plinth.
  - Oversized head (3–4 studs) in Neon or warm yellow, with a PointLight.
  - A curved arm made from 2–3 rotated blocks (Archimedes-style arc).
- **Brick rowhouse kit** (aimed at an iconic hood look):
  - **Body:** a darker plinth (1–2 studs) at the base, then storeys of 10–12 studs. Widths of 16–24 studs and 2–3 storeys vary per house.
  - **Cornice:** at each floor line and the roof, a cream band protruding 0.5–1 stud with a chamfered top. Add a heavier roof cornice with dentils (small blocks every 1.5–2 studs).
  - **Windows:**
    - Recessed openings (inset 0.4–0.6 studs) with a cream frame (0.5 studs), a protruding sill (0.5–0.75), and a lintel or arched head made from wedges.
    - 2–3 window styles per street.
    - Random states: lit/unlit, curtains (colored inner panel), an occasional AC unit or flower box.
  - **Entrance:** stoop stairs (3–5 steps of 1 stud rise) with side railings, a door 8–9 studs tall in a contrasting saturated color (teal, red, yellow), and a transom.
  - **Façade variation:**
    - Choose a brick color from 4–5 options and the trim color from 2.
    - Optionally add a painted stripe band, a fire escape (on every 3rd–4th house), a rooftop water tank or antenna, graffiti-style decals or murals (cartoon, bright), or a store sign on the ground floor.
    - Vary roof heights between neighbors.
    - "Sprinkle" a few protruding brick slabs (0.25–0.4 studs out) on some walls, per the "brick slabs" tip.
  - **Street props:** fire hydrant, mailbox, trash cans, cones, newspaper box, basketball hoop, benches, bus stop. All oversized about 1.3–1.6×, chunky, with chamfered tops.
- **Gym / shop / stage hero buildings.**
  - 1.5–2× the rowhouse height.
  - Unique silhouettes: the gym with a giant glove or dumbbell sign on the roof; the shop with a huge striped awning and mannequins in big windows.
  - Neon trim outlining the entrance.
  - A floor pad of accent color in front.

### Gaps
- I could not access a part-only stylized tree tutorial with exact numbers. All dimensions above are my recommendations.
- No accessible source covered cartoony part-based water in modern Roblox (part vs Terrain water for a stylized look).

## 5. Building workflow and tools pros use, and how to replicate them procedurally

### Takeaway
Pros greybox first on a snap grid, then refine. They use plugins for precise alignment (ResizeAlign), filling angled gaps with triangles (GapFill), arcs and circles (Archimedes), mirroring (Model Reflect), scattering props (Brushtool), bevels (Edge Bevel), surface conversion (Resurface) and z-fight cleanup. Each one maps to a small geometric helper function a Luau map generator can implement directly.

### Cited Findings
- **F3X (Building Tools by F3X)** replaces the move/scale/rotate tools with a floating toolkit: precise resizing, surface snapping, material and color painting, and a more robust undo history. **[S, low-authority aggregator]** — [Mastering Your Roblox Studio Building Tools](https://roblox-studio-building-tools.pages.dev/posts/roblox-studio-building-tools/)
- **Archimedes** builds perfect circles or arcs by duplicating a part at a set angle, used for circular towers, arches and winding roads. **[S]** — [Better Roblox Studio Plugin Architecture Tools](https://roblox-studio-plugin-architecture-tools.pages.dev/); [What are the BEST building plugins?](https://devforum.roblox.com/t/what-are-the-best-building-plugins/437266)
- **Stravant ResizeAlign** "aligns faces of parts via resizing": click a face on part A, then a face on part B, and A is resized flush. **[S]** — [Stravant - ResizeAlign (Creator Store)](https://create.roblox.com/store/asset/165534573/Stravant-ResizeAlign)
- **Stravant GapFill & Extrude** fills the gap between two selected edges with generated parts, typically for triangular holes between angled parts. **[S]** — [Stravant - GapFill & Extrude (Creator Store)](https://create.roblox.com/store/asset/165687726/Stravant-GapFill-Extrude)
- **Model Reflect** mirrors models over a chosen plane. **Brushtool 2.1** (by XAXA) "paints" models onto surfaces. **[S]** — [Medium: Top 10 Best Plugins On Roblox](https://medium.com/@molegul123/top-10-best-plugins-on-roblox-667fe93c05c0); [Trusted plugins for Roblox Studio (wiki user blog)](https://roblox.fandom.com/wiki/User_blog:BundleofYoy/Trusted_plugins_for_Roblox_Studio)
- **Edge Bevel** bevels part edges and corners with a chosen radius and bevel shape, one edge at a time. **[S]** — [Edge Bevel (itch.io)](https://maxed-dev.itch.io/edge-bevel). **Resurface** converts part surfaces to studs, inlets, etc. **[S]** — [Resurface (Creator Store)](https://create.roblox.com/store/asset/5070921519/Resurface-Convert-surfaces-to-studs-and-more). **Z-fighting removers** strip overlaps across models and folders. **[S]** — [Advanced Z-Fighting Remover](https://devforum.roblox.com/t/advanced-z-fighting-remover-plugin/2833769)
- **Official workflow.**
  - Greybox with simple parts and 5-stud/90° snapping, then refine.
  - Use the Align tool to give platforms a common base.
  - Use solid modeling (Negate/Union) for holes and tunnels.
  - Keep modular kits with consistent pivots.
  - Use Material Manager / MaterialVariant for custom tiling materials.

  **[V]** — [Greybox your environment](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md); [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md); [Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md); [Materials](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/materials.md)

### Inferences
Procedural equivalents for a Luau generator (my mapping):

| Plugin / technique | What it achieves | Code equivalent |
|---|---|---|
| Greybox + 5-stud snap | Correct scale and flow before detail | Phase 1: generate blockout from a layout table (zones, paths, footprints) snapped to a 1–5-stud grid. Validate widths ≥10 and walk times. Phase 2: run decoration passes over the same data. |
| ResizeAlign | Flush faces, no gaps or overlaps | Build parts from two corner points: `size = max - min`, `cframe = CFrame.new((min + max) / 2)`. Never "eyeball" sizes. |
| GapFill | Fill triangular gaps / low-poly terrain | A triangle-from-3-points helper using two WedgeParts (the well-known "draw triangle with wedges" algorithm). Use it for low-poly hills, rock facets and roof gables. |
| Archimedes | Arcs, circular plazas, curved roads, arches | For N segments over angle θ at radius r, segment length = 2·r·tan(θ/(2N)) (+ a small overlap). Place each at `CFrame.Angles(0, i*θ/N, 0) * CFrame.new(0, 0, -r)`. |
| Model Reflect | Symmetric layouts and buildings | Mirror positions across a plane and rebuild CFrames. Wedge orientation must be flipped, not negated. Apply symmetry only to macro layout, then re-randomize props. |
| Brushtool | Natural scattering of props, foliage, rocks | A Poisson-disc or jittered-grid sampler inside a region polygon. Raycast down for ground height, then apply random yaw, scale ×0.8–1.25 and tilt, pick a variant from a weighted list, and apply minimum-distance rules to paths, doors and gameplay pads. |
| Edge Bevel | Soft, toy-like edges | The `chamferTop(part, b)` / `chamferAll(part, b)` helpers described in section 1. |
| Resurface | Studs, inlets | `part.Material = Plastic; part.TopSurface = Enum.SurfaceType.Studs`, or add a `Texture` with a stud image. |
| Z-fighting remover | Clean overlaps | A post-pass that detects coplanar overlapping faces between generated parts (same normal and plane distance under 0.01) and nudges the decorative one outward by 0.05 or shrinks it. |
| Modular kit (official) | Fast variety with consistent seams | Define rowhouse modules on a fixed grid (e.g., 4-stud bays, 12-stud storeys), with a corner pivot convention, and assemble from seeded random choices. |

- Use a **seeded RNG** (`Random.new(seed)`) so maps are reproducible and can be tuned. Expose per-zone parameters (palette, density, variant weights).

### Gaps
- I could not verify plugin feature details from the official Creator Store pages, which were blocked. The descriptions come from search summaries and aggregator blogs.

## 6. Well-known tutorials and builders and their key lessons

### Takeaway
The most useful accessible teaching comes from two places. Roblox's official environment-art curriculum covers greybox → asset library → construct world, modular kits, repetition control and scale cues. Community DevForum guides on low-poly and simulator maps cover SmoothPlastic, faceted shapes, filling empty space, consistent style, and center hubs with shops and leaderboards. I could not reliably identify named "top simulator builders" with verifiable tutorial content.

### Cited Findings
- **Roblox Creator Hub, Environmental Art curriculum** (greybox, polished assets, asset library, construct your world) and **Assemble modular environments**. Key lessons:
  - Greybox with 10-stud minimum passages.
  - Use oversized landmarks for scale.
  - Use trims and tileable textures without standout elements.
  - Hide repetition with overlays and props.
  - Keep pivots consistent and lengths on fixed multiples (7.5 in Modern City).

  **[V]** — [Environmental art curriculum (source)](https://github.com/Roblox/creator-docs/tree/main/content/en-us/tutorials/curriculums/environmental-art); [Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md)
- **Roblox Core curriculum "Greybox a playable area"** teaches progression via height steps (8 → 110 studs) and simple primitives plus Negate/Union for visual variety. **[V]** — [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)
- **"How to Make A Simulator Map Part 1"** (DevForum, with a YouTube companion): a 200×5×200 green base, 45°-rotated border walls, colorful mushrooms, rock paths. **[S]** — [DevForum](https://devforum.roblox.com/t/how-to-make-a-simulator-map-part-1/1343396); [YouTube](https://www.youtube.com/watch?v=TsPwsFh1JD4)
- **"Roblox Studio Making A Low Poly MAP" (YouTube, Parts 1–4)** walks through building a large low-poly simulator map; I could not read the content. **[S, titles only]** — [Part 1](https://www.youtube.com/watch?v=wuqfAjr1Fvk); [Part 2](https://www.youtube.com/watch?v=Q3SjDIxmkMI); [Part 3](https://www.youtube.com/watch?v=_aSsffwPnKY); [Part 4](https://www.youtube.com/watch?v=Dc4hR0X5dEs)
- **"Ruski's Tutorial #1 - How to design a map layout"**: plan the layout, landmarks, paths and zones before building. Shape choices (horseshoe vs circle) steer player flow. **[S]** — [DevForum](https://devforum.roblox.com/t/ruskis-tutorial-1-how-to-design-a-map-layout/277853)
- **"Low-Polying Tutorial for Beginners"**: low poly means fewer bricks and a cartoony feel. **[S]** — [DevForum](https://devforum.roblox.com/t/low-polying-tutorial-for-beginners-low-poly-basics/235354)
- **"Ultimate Guide to Stylized Trees on Roblox"** (Blender-based): minimal geometry with detail carried in textures and leaf-size variety. **[S]** — [DevForum](https://devforum.roblox.com/t/ultimate-guide-to-stylized-trees-on-roblox/1124673)
- **"Game Development Theory 101"** covers color theory for builders (monochromatic, analogous, complementary). **[S]** — [DevForum](https://devforum.roblox.com/t/game-development-theory-101/457156). **"Planning your builds"** is a classic planning and reference tutorial; I could see only its title. **[S]** — [DevForum](https://devforum.roblox.com/t/planning-your-builds/121149)
- **Onboarding guidance (official)**: show, don't tell, using in-world signs in the line of sight, arrows and glowing trails. **[V]** — [Onboarding techniques](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/onboarding-techniques.md)

### Inferences
- The consistent lesson across official and community sources is a two-pass workflow: layout/greybox at correct scale first, then decoration. That maps naturally onto a code generator with separate "layout" and "dressing" passes driven by seeded randomness and palettes.

### Gaps
- I could not verify specific famous simulator-map builders, their portfolios, or YouTube channels and transcripts. The DevForum, YouTube and Reddit content was not directly readable, and I avoided paid transcript tools. The report should not name specific builders as authorities without further verification.
- The DevForum lessons above come from search summaries. Exact quotes and authors per thread are unverified.
