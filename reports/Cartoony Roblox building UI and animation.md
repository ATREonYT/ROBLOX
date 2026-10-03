# Craft Hood Like a Toy, Not a Template

Front-page cartoony simulators look hand-made because every wall, button and motion obeys one small set of rules that never changes from screen to screen, and they earn because those rules serve a loop that brings players back on many separate days. In building, that means SmoothPlastic chunky shapes with faceted curves, depth on every surface that faces a path, soft large surfaces under saturated interactables, distances tuned to a 5-stud avatar walking 16 studs per second, and Soft lighting with a shadow-mapped sun. In UI, it means "toy" elements (an ink outline, a lit top, a darker lip and a hard shadow) generated from one token module with Roblox's 2025–26 UIStroke and UIShadow upgrades, the opposite of the translucent-panel, default-font, emoji-icon look players read as AI slop. In animation, it means anticipation, contact and settle, with all of a punch's feedback fired from one animation marker and all decorative motion run on the client. Hood's code is closer than it looks: `Balance.lua` already uses a geometric 2.1x wall curve, a flat +0.5 rebirth multiplier and a first wall inside 60 seconds. Three things fight the look today: `BlockBuilder` forces Realistic lighting with a desaturating color grade, `SimulatorLobby` streams the whole lobby as one Persistent model, and the Power HUD has one UICorner, no outline, gradient or shadow, and a Gotham font Roblox has removed. The money side shifted in 2026. Since June 15, Roblox's recommendation algorithm scores games over 28 days on play-through, early bounce, return days and playtime capped at 60 minutes ([DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)). By tracker counts the 2025 mega-hits have lost more than 99% of their peak players ([bloxquiz](https://www.bloxquiz.gg/stats/grow-a-garden/history)), and Roblox reports engagement moving away from "2025-vintage viral games" ([Roblox Q2 2026 letter](https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf)). Hood's polish budget therefore belongs where it cuts bounce and adds return days: the first wall break, the visible Crew, a HUD readable on a phone, and a weekly event. No hit game publishes its palette, lighting values or HUD measurements, so numbers marked as proposals below are starting points to tune on a real phone; values Roblox documents are cited.

## Chunky faceted shapes and quiet ground carry the cartoon look

### SmoothPlastic, facets and chamfers do most of the work

The cartoony simulator look rests on a narrow set of materials and shapes. DevForum builders agree on SmoothPlastic for most surfaces, with textures blended in sparingly; one guide says "smooth plastic should always make up the majority" of a low-poly build ([Stylized Low Poly](https://devforum.roblox.com/t/stylized-low-poly/3781693)). True circles are rare. Low-poly builders swap cylinders for octagons or hexagons and keep detail lighter than a realistic build would ([Tips before creating a low poly building](https://devforum.roblox.com/t/tips-before-creating-a-low-poly-building/288652)). One builder's shorthand is to treat everything like a children's toy, "always shiny smooth plastic", with deliberately uneven shapes on houses ([How to achieve a cartoony styled game?](https://devforum.roblox.com/t/how-to-achieve-a-cartoony-styled-game/530900)).

Flat walls are the amateur tell. The fixes builders cite are indents, bevels and extrusions, pillars on corners, stripes and tiny tiles, wall-mounted lights and mixed window styles. One adds that "a few brick slabs sprinkled on a building can make that building look 10x better" ([How to make builds look better](https://devforum.roblox.com/t/how-to-make-builds-look-better-advice/1816085); [How to put more detail on walls](https://devforum.roblox.com/t/how-to-put-more-detail-on-walls/636045)). Mixing styles is the other common failure: "if you want low poly, stay low poly" ([Any tips on simulator map](https://devforum.roblox.com/t/any-tips-on-simulator-map/826579)). These DevForum points come from search summaries rather than full threads, so treat them as community consensus, not exact quotes.

Roblox's own environment-art curriculum supplies the discipline behind that taste. Greyboxing exists partly to catch "assets with disproportionate scale to the user's character". The sample keeps every object about character-sized except one tower made "much larger than the player to provide a sense of scale" ([Greybox your environment](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md); [Construct your world](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/construct-your-world.md)). The Modern City kit makes every piece at least 7.5 studs long, in 7.5-stud multiples, so modules "seamlessly align and connect without overlap even when you rotate them". It hides repetition with grunge overlays and per-building props such as fire escapes and AC units, because "even just including a few decorative props can add a vast amount of storytelling" ([Assemble modular environments](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/modeling/assemble-modular-environments.md)). A tileable texture should contain no single standout element, which would expose the repeat ([Develop polished assets](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/develop-polished-assets.md)).

For Hood's Luau generator, those principles become numbers. We propose trims, sills, cornices and railings at least **0.5–1 stud** thick, because thinner detail vanishes at simulator camera distance on a phone. Street props should be roughly **1.3–2x real size** against the 5-stud avatar, and the boxing club and Drip Shop **3–6x character massing**. Every building should read by outline alone, stacked as plinth, body, cornice and parapet, with neighboring roofs varying by 2–6 studs.

The single most effective upgrade is a **chamfered-top primitive** for platforms, stages, curbs, walls and sign boards. It is a core block, a smaller top cap, four WedgeParts sloping outward around the cap, and CornerWedgeParts at the corners. A bevel of 8–15% of the smallest dimension (usually 0.5–1.5 studs) reads as toy-like and keeps each prop to about 9–13 parts. The sketch below is untested; it relies on a WedgePart sloping down toward its front (LookVector) face.

```lua
-- Chamfered top: core + cap + 4 edge wedges. Fill the four b x b x b corner notches with
-- CornerWedgeParts (check their orientation visually once, then reuse the CFrames).
local function chamferTop(parent: Instance, cf: CFrame, size: Vector3, b: number, props: {[string]: any})
	local function mk(class: string, s: Vector3, c: CFrame)
		local p = Instance.new(class)
		p.Size, p.CFrame, p.Anchored = s, c, true
		for k, v in props do p[k] = v end            -- Material, Color, CanQuery, CastShadow...
		p.Parent = parent
		return p
	end
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	mk("Part", Vector3.new(size.X, size.Y - b, size.Z), cf * CFrame.new(0, -b / 2, 0))           -- core
	mk("Part", Vector3.new(size.X - 2 * b, b, size.Z - 2 * b), cf * CFrame.new(0, hy - b / 2, 0)) -- cap
	for _, d in {Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis} do
		local along = if d.X ~= 0 then size.Z else size.X     -- edge runs perpendicular to d
		local reach = if d.X ~= 0 then hx else hz
		local pos = Vector3.new(0, hy - b / 2, 0) + d * (reach - b / 2)
		mk("WedgePart", Vector3.new(along - 2 * b, b, b), cf * CFrame.lookAt(pos, pos + d)) -- slope faces out
	end
end
```

Curves should be faceted to match. Use 6- or 8-sided prisms for columns, lamp posts, trunks and planters (an octagon is two square blocks rotated 45°). Reserve true Ball and Cylinder shapes for things meant to look bubbly: foliage, clouds and coins.

Outlines, a staple of cartoon art, are expensive on parts. Inverted-hull outlines need meshes built in Blender ([How to make a black outline](https://devforum.roblox.com/t/how-to-make-a-black-outline/482739)). The engine's `Highlight` caps out at **255 visible instances per client**, and disabled Highlights still hold a slot ([Highlight API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Highlight.yaml)). Hood should outline only the thing the player is about to touch, such as the next affordable bag, and create and destroy Highlights rather than toggling them.

### Scale every path to a 5-stud avatar walking 16 studs a second

Roblox's documented numbers anchor the layout. Default WalkSpeed is **16 studs per second**, default jump height is **7.2 studs**, and a stud is about 28 cm ([Humanoid API](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Humanoid.yaml); [Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)). The environment-art curriculum sets every doorway and hallway at least **10 studs wide** and every wall at least 10 studs tall, so two players can pass and the camera never clips. It also snaps greyboxes to 5 studs and 90°, uses elevation "peaks and valleys" to control sight lines, and gives every spawn zone **two exits** ([Greybox your environment](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/environmental-art/greybox-your-environment.md)). That page claims a default jump of 5 studs, contradicting the API's 7.2; use 7.2.

The core curriculum's Island Jump sample raises successive platforms to 8, 20, 35, 55, 81 and 110 studs, and any level gated behind an upgrade sits at least 30 studs above the last ([Greybox a playable area](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/core/building/greybox-a-playable-area.md)). Roblox's onboarding guide adds a guidance layer: a bouncing arrow on a UI button, "a glowing trail in the world that directs players to a destination", and an in-world sign of the core loop placed "directly in players' line of sight" ([Onboarding techniques](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/onboarding-techniques.md)).

Hit lobbies apply those rules in recognizable shapes. Pet Simulator 99 runs a linear chain of themed zones unlocked with currency, with rebirth statues at areas 25, 50 and 75 ([BIG Games DB](https://db.biggames.io/wiki/areas)). Grow a Garden puts fenced plots on one island, with the Seed Shop and "Sell Your Stuff" facing the Gear, Pet and Cosmetics shops across a central event hub. Its outer edges are dense with trees, flowers, mushrooms, moss and rocks ([Grow a Garden wiki: Map](https://growagarden.fandom.com/wiki/Map)). Steal a Brainrot lines eight bases along a studded red-carpet conveyor with the shops beside it, making the conveyor the focal point ([Sportskeeda](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide)). DevForum layout advice settles on a central hub holding spawn, leaderboards and a step-on pad that opens the shop. Empty ground gets rocks, shrubs, benches, ponds and crates, and tree canopies get CanCollide turned off when players keep bumping into them ([Simulator Map Suggestions](https://devforum.roblox.com/t/simulator-map-suggestions/1008279); [What should I add to fill space](https://devforum.roblox.com/t/what-should-i-add-to-fill-space-simulator-map/592273)).

For Hood we propose a hub-and-spoke layout sized as in the table below. From the arrival medallion, a player should see the boxing club, the Drip Shop, the leaderboard and the first wall without turning more than about 90°. Every spoke street should end in a visible gate or landmark, so each path leads somewhere. No open area larger than about 30×30 studs goes without a prop cluster, except the spawn plaza, which stays quiet so the busy areas read. The map edges get a dense backdrop of taller façades, trees and fences, which hides the boundary the way Grow a Garden's decorated rim does.

| Element | Proposed size | Reasoning |
|---|---|---|
| Spawn plaza | 60–90 studs across, open | One statue or fountain; contrast for the busy streets |
| Core loop (bag, wall, shop) | 30–80 studs from spawn | 2–5 second walk at 16 studs/s |
| Main street | 24–32 studs (road 16–20, sidewalks 4–6 each) | Exaggerated cartoon scale for crowds |
| Secondary paths | 10–14 studs | Never below Roblox's 10-stud minimum |
| Enterable doors | 8–12 tall × 6–10 wide | Façade-only doors can be 7–8 × 4 |
| Storeys / rowhouse widths | 10–12 studs / 16–24 studs | Vary per house so blocks don't tile |
| Zone gates | 20–30 wide, 20+ tall | Zone-colored Neon barrier, price sign, a step up, next landmark visible over the wall |
| Leaderboards | 12–20 studs tall, facing spawn | Readable on arrival |

### Saturate what players touch; soften what they stand on

Color carries more of the cartoon look than detail does. Builders ask for "rich" colors and bright saturated yellows, pinks and sky blues. They also warn that saturating large surfaces causes eye strain and a "rainbow effect", so floors, walls and sky take desaturated versions ([Suiting colours for builds](https://devforum.roblox.com/t/suiting-colours-for-builds/808280); [Tips on building simulators](https://devforum.roblox.com/t/tips-on-building-simulators/264791)). Art theory explains why: saturated colors advance and desaturated colors recede, so desaturating the background is the fastest way to build depth and hierarchy ([Russell Collection](https://russell-collection.com/what-is-color-saturation-in-art/)). Post-processing often undoes this, because builders push ColorCorrection saturation and bloom too far ([Cartoon Lighting Help](https://devforum.roblox.com/t/cartoon-lighting-help/3602579)). One detail from Roblox's BrickColor table matters for code: classic "Black" is a blue-black (27, 42, 53), not a neutral ([BrickColor codes](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/datatypes/BrickColor.yaml)).

We propose the HSV rule below for Hood's generator. Accents take hues complementary to their background. Shade recesses by shifting hue toward blue-purple and dropping value 15–30%, and light the tops by shifting hue toward yellow. Never use pure grey or pure black, and cap each zone at 5–7 base colors plus 1–2 accents. `Maps.lua` already gives each neighborhood an accent: gold for The Block, green for the Suburbs, blue for Uptown and orange for the Hills. The builder should carry that accent into sidewalk tint, gate barriers and signage, so each zone is recognizable from a distance and in thumbnails.

| Element | Saturation | Value |
|---|---|---|
| Large surfaces (ground, roads, walls) | 20–55% | 55–85% |
| Mid elements (buildings, trees) | 45–75% | 60–90% |
| Accents and interactables (signs, gates, bags, pads) | 75–100% | 90–100% |

| Element | Hex | Element | Hex |
|---|---|---|---|
| Asphalt | #4A4E5C | Trim / cornice cream | #F3E9D6 |
| Road lines | #FFD84A, #F4F1E8 | Dark plum outline | #3D3550 |
| Sidewalk / curb | #CFC8B8 / #E9E3D3 | Windows (day / lit) | #8FD8F8 / #FFF1A8 |
| Rowhouse bricks | #B8533D, #C9744C, #9C4848, #D6A267, #6F7FA6 | Grass | #6CC24A, #57AE3E, #9BE05A |
| Foliage | #5DBB3F, #7ED957, #3E9B3A | Trunks / water | #8B5A3C / #4FC3F7 |
| Boxing club accents | #FF4B4B + #FFC93C | Drip Shop accents | #FF7AC8 + #43D3FF |
| Stage walls | #9B5CFF + #FF9F1C | Gates | Neon cyan or green |

Materials follow the same restraint. Use SmoothPlastic for 85–95% of surfaces and Neon only for small glowing accents such as sign letters, lamp heads and pad rings. Use Brick or Concrete only as sprinkled accents, or on the ground through a `MaterialVariant` with a large StudsPerTile so the pattern stays bold. A MaterialVariant set as a material override restyles every part that uses its base material, and it is the only way to restyle terrain ([Materials](https://create.roblox.com/docs/parts/materials)).

### Studs belong on a few surfaces, not all of them

Studs survived Roblox's 2019 surface overhaul as visuals only. The enum documentation says SurfaceType joining "is deprecated, leaving only visual changes", and Studs still "adds square studs across the surface" ([SurfaceType enum](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/SurfaceType.yaml)). Since August 2019 those studs render only on **Plastic**, not SmoothPlastic ([Changes to Part Surfaces](https://devforum.roblox.com/t/changes-to-part-surfaces/334420)). New parts no longer get studs by default, but scripts can still set them. For meshes, unions or SmoothPlastic, the community layers a tiling `Texture` with a stud image ([How to get back the old stud texture](https://devforum.roblox.com/t/how-to-get-back-the-old-stud-texture-easily-includes-meshes-unions/3157449)). A Texture repeats where a Decal stretches, with `StudsPerTileU/V` setting the tile size and `Color3` tinting it ([Textures and decals](https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/textures-decals.md)).

The studded look is selling now. Grow a Garden uses "studded textures evocative of old-school Roblox games" ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)), and UI kits from the Steal a Brainrot era sell as "stud UI" ([BuiltByBit](https://builtbybit.com/tags/stud-ui/)). Covering everything in studs reads as classic Roblox rather than a modern simulator, though, and textures add draw calls. Hood should put studs on a few touchable surfaces such as the Champ Ring floor, stage platforms and curb tops. Either set `part.Material = Enum.Material.Plastic` with `part.TopSurface = Enum.SurfaceType.Studs`, or add a top-face Texture at 1–2 studs per tile, tinted to the part, at 0.3–0.6 transparency.

### Props, trees and rowhouses need seeded variation

Generated props look machine-made when they repeat exactly. Stylized-tree guides build canopies from several irregular blobs of varied size ([Ultimate Guide to Stylized Trees on Roblox](https://devforum.roblox.com/t/ultimate-guide-to-stylized-trees-on-roblox/1124673)). Builders who use only parts make canopies from rotated rings of blocks or from sphere clusters ([How do you create stylized trees?](https://devforum.roblox.com/t/how-do-you-create-stylized-trees/1184253)).

We propose these Hood recipes. A tree gets a trunk of 2–3 stacked octagonal segments, tapering from about 2.5 to 1.5 studs and leaning 3–8°. Its canopy is 4–7 overlapping balls: one main blob of 9–13 studs, the rest 45–80% of its size. Use light green on top, mid green on the sides and dark green underneath; the dark underside fakes ambient occlusion. Use three canopy shapes (round, tall, wide), placed in groups of 2–5 and never in perfect rows except deliberate street trees. Bushes are 2–4 flattened balls sunk 20–30% into the ground. Rocks come in big-medium-small trios at about 1 : 0.6 : 0.35, randomly tilted and sunk 25–40%. Every scattered instance takes a random rotation, a scale between 0.8 and 1.25 and a hue jitter of about ±0.015, and no two identical variants sit side by side.

The rowhouse kit follows the Modern City approach of reusable modules plus props. Each house gets a darker 1–2-stud plinth and 10–12-stud storeys. A cream cornice band protrudes 0.5–1 stud at each floor line, with dentils every 1.5–2 studs under the roof. Windows are recessed 0.4–0.6 studs, with a 0.5-stud frame and a protruding sill. The entrance is a stoop of 3–5 one-stud steps up to a door in a saturated contrast color. Variation comes from 4–5 brick colors, 2 trim colors and 2–3 window styles, plus a fire escape on every third or fourth house, rooftop tanks and antennas, ground-floor store signs and a few protruding brick slabs. Hero buildings run 1.5–2x rowhouse height, with silhouettes no neighbor shares: a giant glove on the boxing club roof, and a striped awning with mannequins in big windows on the Drip Shop.

Professional builders lean on plugins, and each one maps to a small function in a Luau generator. Hood's builder should implement these functions directly instead of placing parts by eye.

| Plugin | Generator equivalent |
|---|---|
| ResizeAlign ([Creator Store](https://create.roblox.com/store/asset/165534573/Stravant-ResizeAlign)) | Build every part from two corner points: `size = max - min`, `cframe = CFrame.new((min + max) / 2)` |
| GapFill ([Creator Store](https://create.roblox.com/store/asset/165687726/Stravant-GapFill-Extrude)) | Triangle-from-three-points with two WedgeParts, for gables, rock facets and low-poly mounds |
| Archimedes ([DevForum](https://devforum.roblox.com/t/what-are-the-best-building-plugins/437266)) | N segments over angle θ at radius r, each 2·r·tan(θ/2N) long, placed with `CFrame.Angles(0, i*θ/N, 0) * CFrame.new(0, 0, -r)` |
| Brushtool | Poisson-disc scatter inside a region, raycast to the ground, random yaw/scale/tilt, keep-out zones around paths, doors and pads |
| Z-fighting removers ([DevForum](https://devforum.roblox.com/t/advanced-z-fighting-remover-plugin/2833769)) | A post-pass that finds coplanar faces and pushes the decorative one out by 0.05 studs |

Z-fighting deserves its own rule. The community fix of nudging one part by about 0.001 studs is fragile; a 2025 bug report is titled "Parts randomly changed their size when using a Z-fighting prevention trick" ([DevForum](https://devforum.roblox.com/t/parts-randomly-changed-their-size-when-using-a-z-fighting-prevention-trick/4007417)). Hood's generator should snap geometry to a 0.25- or 0.5-stud grid and prefer exact abutment over overlap. It should push decorative layers out at least 0.05 studs, and make trims either protrude a clear 0.25+ studs or sit flush in a recess. A seeded `Random.new(seed)` makes every generated map reproducible.

## Soft light with a shadow-mapped sun suits a phone-first cartoon city

### Unified Lighting changed the vocabulary, and Hood picked the costly mode

Roblox replaced its lighting switch in 2025, so most older tutorials now use the wrong terms. `Lighting.Technology` is deprecated and "non-scriptable and only modifiable in Studio". Lighting is now two properties, `LightingStyle` (Soft or Realistic) and `PrioritizeLightingQuality` ([Lighting API](https://create.roblox.com/docs/reference/engine/classes/Lighting)). Soft is "a flat, retro-Roblox look with softer lights and shadows". Realistic is "the most advanced and realistic lighting and shadows Roblox can deliver" ([LightingStyle enum](https://create.roblox.com/docs/reference/engine/enums/LightingStyle)). Soft with `PrioritizeLightingQuality = true` draws sun shadows with shadow maps rather than voxels, which is the old ShadowMap mode; the old Future mode maps to Realistic plus true ([rbx-dom issue #637](https://github.com/rojo-rbx/rbx-dom/issues/637)).

Two cautions apply to a code-built game. The docs disagree on whether `LightingStyle` can be set from scripts. And Rojo's serializer can write the old Voxel value as empty, which Studio reads as the deprecated Compatibility mode (same issue). Set the style in the saved place and confirm it after publishing. Shadows also degrade with graphics quality and disappear entirely below quality level 4 ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)), so most phone players see a flat look whatever mode Hood picks.

For Hood, **Soft with `PrioritizeLightingQuality = true`** is the right default. It is officially the stylized look, it keeps crisp sun shadows on brick façades, and it holds those shadows longer as quality scales down. `BlockBuilder.SetLighting()` forces Realistic, whose main benefits, shadow-casting local lights and automatic indoor/outdoor detection, matter only inside the gym and shop.

Hood's post-processing also works against the cartoon target. `ColorCorrection.Saturation = -0.05` desaturates, where Roblox's own indoor sample uses +0.1 and community cartoon presets use +0.12 to +0.3 ([Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments); [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686)). A bloom threshold of 1 already limits bloom to pure white ([BloomEffect](https://create.roblox.com/docs/reference/engine/classes/BloomEffect)), so Hood's 1.2 leaves the neon signs dull. Every Ambient channel should stay at or below OutdoorAmbient, because the engine clamps OutdoorAmbient up to Ambient ([Lighting API](https://create.roblox.com/docs/reference/engine/classes/Lighting)). And brightness should come from exposure rather than `Brightness`, which lifts shadows into "unintentional murkiness" ([Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)).

The table compares Hood's current values, Roblox's stylized Island Jump sample ([Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)) and two proposed presets assembled from the documented ranges. The presets are starting points to tune by eye.

| Property | Hood today (`BlockBuilder`) | Island Jump sample | Proposed bright day | Proposed golden-hour Block |
|---|---|---|---|---|
| LightingStyle / PrioritizeLightingQuality | Realistic / unset | Realistic | Soft / true | Soft / true |
| ClockTime, latitude | 17.2, 28 | 9, 78 | 14, 35 | 17.2–17.8, 28 |
| Brightness / Exposure | 2.8 / 0.2 | not listed | 2.6 / 0.15 | 2.4–2.8 / 0.2 |
| Ambient / OutdoorAmbient | (109,115,126) / (145,149,153) | (16,16,16) / (134,158,190) | (120,120,135) / (150,150,160) | (100,95,115) / (150,135,140) |
| ColorShift Top / Bottom | (255,220,175) / (137,163,194) | (196,222,255) / not listed | (255,235,205) / (150,175,210) | (255,200,150) / (130,150,200) |
| Environment diffuse / specular | 0.65 / 0.65 | not listed | 0.3 / 0.2 | 0.3 / 0.2 |
| ShadowSoftness | 0.2 | 0 | 0.2 | 0.2 |
| Atmosphere density / offset / haze / glare | 0.28 / 0.12 / 1.6 / 0.25 | 0.375 / 0.17 / – / – | 0.3 / 0.2 / 0.5 / 0 | 0.3 / 0.15 / 1.6–2.0 / 0.3–0.5 |
| ColorCorrection contrast / saturation | 0.05 / −0.05 | not listed | 0.08 / 0.2 | 0.06 / 0.12 |
| Bloom intensity / threshold | 0.18 / 1.2 | not listed | 0.3 / 0.95 | 0.25 / 0.9–1.0 |
| SunRays intensity / spread | 0.035 / 0.65 | not listed | 0.02 / 0.3 | 0.03–0.04 / 0.6 |

### Neon glows but lights nothing, so pair it with cheap lights

Roblox's docs say a Neon part "will appear to glow brightly, although it will not actually emit any light" ([Light with props](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/light-with-props)). Community testing finds the glow depends on the color's HSV value, not its hue or saturation, and that Bloom scales its intensity ([Everything about Neon shader](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408)). The cheap cartoon recipe is a Neon sign in a bright, high-value color, plus at most one shadowless PointLight or SurfaceLight per sign cluster (range 8–16, brightness 1–2, warm). Range is capped at 120 studs, and raising Brightness does not widen the lit area ([Light sources](https://create.roblox.com/docs/effects/light-sources)). Roblox's performance guide names shadow-casting lights as a classic cost. It recommends turning off `Light.Shadows` where it isn't needed, shrinking range and angle, and switching lights off by room or distance ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). Hood should turn on shadows for only one to three hero lights, such as the Champ Ring spotlight.

### The sky and the street can move for almost nothing

Atmosphere controls distance haze. Glare needs Haze above 0, Decay tints the side of the sky away from the sun, and the legacy Fog properties are ignored once an Atmosphere exists ([Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere); [Lighting API](https://create.roblox.com/docs/reference/engine/classes/Lighting)). Three engine features add motion cheaply. Rotating `Sky.SkyboxOrientation` at 5° per second is documented as "a low-cost feature which works seamlessly across all platforms" ([Skyboxes](https://create.roblox.com/docs/environment/skybox)). Dynamic `Clouds` render only when parented under Terrain ([Dynamic clouds](https://create.roblox.com/docs/environment/clouds)). And `Workspace.GlobalWind` moves terrain grass, clouds and wind-affected particles together; the official gust script cycles from a base of (5, 0, 2) to gusts of (25, 0, 10) ([Global wind](https://create.roblox.com/docs/environment/global-wind)).

Particle emitters top out at **400 particles per second, 100 on mobile**, and Roblox advises keeping rates as low as possible ([Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)). Ambient life should therefore come from a few long-lifetime emitters at rates of 2–8 (leaves by trees, dust in the gym, sparks by the string lights) and from positional sounds. The existing neighbors and bodega cat should be animated on the client with `AnimationController`. One client loop running every half-second should switch all of these on and off by distance. For a classic pre-2019 tone, the official replacement for the deprecated Compatibility mode is Voxel lighting (Soft with `PrioritizeLightingQuality` off) plus a `ColorGradingEffect` with the Retro tonemapper ([Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology); [ColorGradingEffect](https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect)).

### Draw calls, streaming and collisions set the real budget

Roblox's design guide gives an example target of staying "below 1,000 draw calls and 1,000,000 triangles" on a baseline device. It warns that Studio's emulator "isn't accurate for memory usage" ([Design for performance](https://create.roblox.com/docs/performance-optimization/design)). Instancing collapses identical meshes that share a material into one draw call, while decals, textures and particles "don't batch well" ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). A part-built map should therefore reuse a small set of sizes, materials and colors rather than randomizing materials per part. Transparency values other than 0 or 1 cause overdraw ([Design for performance](https://create.roblox.com/docs/performance-optimization/design)).

Every static part should be anchored. Decoration should have `CanCollide`, `CanTouch` and `CanQuery` off; CanQuery only takes effect once CanCollide is off. Small anchored parts can safely use Box collision fidelity. Turning off `CastShadow` on small or distant details "can improve performance", and Roblox's own sample saw "almost no difference" visually ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). Hood's builder helpers should set these flags by default on trims, wires, sleepers and window frames; `SimulatorLobby.lua` already does this for wires and bulbs.

Streaming is where Hood's current structure fights the engine. Roblox's recommended baselines are StreamingMinRadius 64, StreamingTargetRadius 1024, ModelStreamingBehavior Improved, StreamOutBehavior Opportunistic, PauseOutsideLoadedArea and SLIM avatars enabled, all settable only in Studio ([Instance streaming](https://create.roblox.com/docs/workspace/streaming)). The streaming guide tells creators to break up large container models and keep each model's spatial extent "under ~64 cubic studs" so it streams in whole. It describes `Persistent` as "intended for very rare circumstances", because persistent models never stream out ([Streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques)).

Hood breaks both rules today. `SimulatorLobby.lua` builds the entire lobby as one `Persistent` model, and `BlockBuilder` marks the ground, the 725-stud elevated rail, the station and the train as persistent. The fix is to split the lobby into per-building models with default streaming and keep persistence for the few objects client scripts must find at join. That requires the client scripts that look up bags and mannequins to wait for streamed content, which is the WaitForChild-and-nil-check pass Roblox's streaming guide describes. Static rowhouses and shops then become candidates for `Model.LevelOfDetail = SLIM`, which merges parts into cloud-generated meshes with several detail levels for "static world geometry — buildings, props" ([SLIM](https://create.roblox.com/docs/workspace/streaming/slim)). SLIM requires streaming, a place saved to Roblox and Team Create, and it excludes anything modified at runtime.

## Sticker UI beats template UI because every decision is committed

### Slop is the average of every template

Design writers describe AI-generated interfaces as carrying "a fingerprint: the Inter typeface, an indigo-to-purple gradient, three rounded cards in a row" ([925 Studios](https://www.925studios.co/blog/ai-slop-design-tells)). Other tells are "a gray 1px border on every card", dark mode by default, and the same rounded corners and shadow on every button ([Developers Digest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it)). The root cause is not the tool but the absence of choices. Models output "the statistical average" of their training templates, and "the real cause of slop is no decision" ([VibeCodeKit](https://vibecodekit.dev/ai-slop-design)).

Roblox has its own version of the same failure. DevForum critiques flag icon padding that differs between the left and the top, uneven gaps that make UI "appear incomplete", and colors that ignore contrast ([Feedback on my UI](https://devforum.roblox.com/t/feedback-on-my-ui/753642); [My UI is bad](https://devforum.roblox.com/t/my-ui-is-bad-dont-know-how-to-fix/2154422)). The Roblox flavor of slop is a dark translucent panel with white Gotham or Builder text, one corner radius on everything, emoji as icons, `TextScaled` on every label, and buttons that don't react when pressed.

Hood's current HUD sits closer to that template than to a simulator. All three client UI scripts together (246 lines) use four UICorners, one UIStroke (in the Studio-only test panel), one UIScale, and no UIGradient or UIShadow. The Power HUD in `Lobby.client.lua` still sets `Enum.Font.GothamBold`. Across the repository, 14 references to `GothamBold` and `GothamBlack` now render as Montserrat, because Roblox removed Gotham and silently remaps it ([Font enum](https://create.roblox.com/docs/reference/engine/enums/Font)).

One DevForum reviewer argues that outlines "can make GUIs look old fashioned" ([Feedback on my UI](https://devforum.roblox.com/t/feedback-on-my-ui/753642)), which seems to contradict the cartoon recipe below. The two are compatible: thin, uniform 1-px black borders look dated, while thick, hue-matched outlines are a deliberate style.

| Slop tell | Hood's professional equivalent |
|---|---|
| Dark translucent panels, white default text | Opaque colored "material" panels (cardboard, sticker, signboard) with an ink outline and header strip |
| Emoji icons | Illustrated icons in one style: ink outline, 2–3 tone cel shading, white sticker border, one light direction |
| One font, `TextScaled` everywhere | 2–3 families on a 5-step type scale, fixed sizes multiplied by one UIScale |
| Gradients at random angles | Gradients only to show light from the top, at one angle, plus a special treatment for Legendary and above |
| Rows of identical centered buttons | One dominant call to action per screen, secondary actions smaller and quieter |
| Random spacing and radii | Spacing tokens 4/8/16/24/32 and radius tokens 8/16/24/pill, with padding inside a group no larger than the gap between groups ([Cieden](https://cieden.com/book/sub-atomic/spacing/spacing-best-practices)) |
| Color as decoration | Color as meaning: green confirm, red close, yellow primary, blue navigate, a rarity ladder for items |
| No pressed state | Hover, press (body drops onto lip) and disabled (desaturated, no shine) states on every button |

### Every element should look like a pressable toy

Front-page simulator UI reads as a sticker or toy rather than a window. One vendor describes the chunky cartoon style as "thick dark outlines, 16 px rounded corners, saturated primary colours, hard drop shadows, and playful oversized buttons", and says it works because "it reads instantly at small sizes on a phone" ([VizzBees](https://vizzbees.com/blog/roblox-ui-design-ideas)). That vendor sells AI UI generators, but its description matches the DevForum tutorial recipe for Photoshop layer styles. The recipe is an Outside stroke "typically between 6 and 15" pixels in a contrasting color, an Inner Shadow for depth and a Color Overlay, with every animated element exported as a separate image ([How to make UI styled for simulator](https://devforum.roblox.com/t/how-to-make-ui-styled-for-simulator-detailed-tutorial/2895762)).

The Pet Simulator team built its consistency on purpose. A BIG Games visual designer describes "standardizing silhouettes, gradients, lighting, and material treatments" and designing "modular, reusable UI components to support faster updates" ([sulle portfolio](https://sulle.ca/project/big-games)). That system carried 140+ weekly updates at up to 1.5M concurrent players ([Centio](https://centio.solutions/work/pet-simulator/)). Building UI from reusable components is what made weekly reskins possible.

Two benchmarks from outside Roblox sharpen the color logic. Clash Royale uses "white text with a dark outline" and "shiny push buttons that press down and beveled panels". It puts yellow on the most important functions, green on secondary ones and blue on backgrounds, and gives its most important bright elements animated highlights ([The Rookies](https://www.therookies.co/blog/education/game-design-ux-best-practices-detailed-breakdown-of-clash-royale)). Nintendo's Splatoon team made "icons high chroma to emphasize importance, while keeping background elements like modal windows low chroma" ([Haiiro](https://medium.com/haiiro-io/how-nintendo-designed-switch-and-splatoon-d1a14b9cc2de)). Roblox's own UI tutorial demonstrates the outline rule that separates pros from amateurs: its text stroke is a dark shade of the fill color, RGB 8, 78, 52 on a mint fill of 88, 218, 171, not black ([Implement designs in Studio](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/implement-designs-in-studio.md)).

As structure, every Hood button should carry three strokes and one shadow, all lit from one direction. An outer ink outline separates it from any 3D background. A colored body, lit from the top, sits on a darker bottom lip. A 1–2 px white inner highlight runs along the top edge at 30–50% opacity. A hard shadow drops straight down by a fixed distance. Pros add small details on top: a gloss band across the upper half of primary buttons, a pattern inside panels at 3–8% opacity, sparkles only on rare items, notification badges with their own outline, icons that overlap the panel edge, and sticker badges rotated a few degrees.

### Hood's token sheet commits to ink, cardboard, four function colors and one rarity ladder

The tokens below are a proposal; check every color pair for contrast on a phone. Panels default to warm cardboard rather than dark glass. Outlines use one near-black purple "ink" rather than pure black. Each function color has a top highlight, a base, a lip and a stroke shade, so every button is built from the same four values.

| Token | Top | Base | Lip | Stroke | Use |
|---|---|---|---|---|---|
| Ink | | #1C1830 | | | Outer outlines, text strokes on light panels, hard shadows |
| Cardboard | | #FFEFD2 | #C99A5B | Ink | Default panel body; inset wells #F4D9A8 |
| Asphalt | | #2B2E45 | | | Dark insets, list wells and progress tracks, with #FFD23F dashed "road line" accents |
| Brick | | #E2553D | #9C2F22 | Ink | Panel header strips, Hood brand accent |
| Green (buy, confirm, claim, Robux) | #8CF06A | #43C24A | #23802C | #123F17 | One green for all purchases, for trust |
| Yellow (primary CTA, Power) | #FFE76A | #FFC21A | #D57D00 | #5A2E00 | The one dominant action per screen |
| Red (close, cancel) | #FF8A8A | #FF4757 | #B01E35 | #4A0B16 | X buttons, destructive confirms |
| Blue (info, navigate, teleport) | #7CCBFF | #2F9BFF | #1A5FB4 | #0B2A55 | Walls, teleports, settings |
| Neon (rebirth, limited only) | | #FF3EA5 / #2EF2FF | | Outer glow | One or two screens at most |

Rarity colors are not the place to be original. In April 2026 Adopt Me switched to Common white, Uncommon green, Rare blue, Ultra-Rare purple and Legendary orange, explicitly "following Fortnite's rarity colors" ([X: @AMGlormies](https://x.com/AMGlormies/status/2043788065039163623)). That moved the biggest legacy Roblox game onto the ladder used across the industry. Pet Simulator 99 extends a similar ladder to 11 tiers ([Pet Simulator Wiki](https://pet-simulator.fandom.com/wiki/Rarities_(Pet_Simulator_99))). Hood's Crew and outfits should use the ladder below, with only Legendary and above animating so that motion stays special. Numbers use the standard simulator suffixes (K, M, B, T, Qa, Qi) with one decimal, so 12,345 becomes 12.3K ([BloxControl](https://bloxcontrol.com/guides/roblox-number-abbreviations-k-m-b-t-qa-qi-explained/)).

| Rarity | Color | Treatment |
|---|---|---|
| Common | #B8BEC8 | Static |
| Uncommon | #5BD45B | Static |
| Rare | #3D9BFF | Static |
| Epic | #A64DFF | Static |
| Legendary | #FFB020 | Gradient with a shine sweep |
| Mythic | #FF3B5C | Gradient with sparkles |
| Secret | Near-black card | Animated rainbow stroke and a unique sound |

Type is where Roblox games most often look generic. A DevForum thread calls Fredoka One so overused that players "associate it with slop Simulator/Obby/Tycoon games", while others defend it as the font of the bright, bubbly Roblox style ([DevForum font thread](https://devforum.roblox.com/t/whats-a-good-font-face-to-use-as-a-general-theme-for-a-game/2538479)); the problem is using it by default, not the font itself. Builder Sans replaces the removed Gotham, with weights up to Extra Bold but no Black ([Builder Sans](https://create.roblox.com/store/asset/16658221428/Builder-Sans)). A UIStroke on Luckiest Guy can leave small holes inside some letters ([UI Stroke creating hollow areas](https://devforum.roblox.com/t/ui-stroke-creating-hollow-areas/3283340)). Roblox ships fonts that suit a street theme, including Bangers, Permanent Marker, Bungee Inline and Shade, and Rubik Wet Paint ([font list](https://gist.github.com/cxmeel/38f6d9ba5dc5fd048489a37853bcaa87)).

Hood should use at most three families. Titles and calls to action get Luckiest Guy (test it for the stroke holes) or Bangers. Numbers and labels get Builder Sans Extra Bold. Permanent Marker is reserved for graffiti tags such as NEW, HOT or Crew nicknames, never numbers. Set fonts with `FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")`, the documented successor to the `Font` enum ([Font datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font)). Sizes should come from one five-step scale authored at a 1280×720 reference: for example 36 for modal titles, 28 for calls to action and big numbers, 22 for buttons and card titles, 18 for labels, and 14 for fine print, which phones should avoid.

### The street theme lives in the materials; the functional grammar stays standard

Hood's street identity should come from what panels are made of, not from bending the functional rules. We propose cardboard and paper panels with a slightly irregular 9-slice edge, with a strip of masking tape (cream #F3E6C4, rotated 5–8°) holding each header. Side buttons, Crew portraits and outfit badges become die-cut stickers: the illustration, then a 3–4 px white sticker border, a 2–3 px ink outline and a hard shadow. Section titles get a spray-paint tag behind them. Walls and teleports navigate through green street-sign plates ("1ST ST", "BLOCK 2"), and confirmation popups wear a yellow diamond warning sign. A neon-tube sign is reserved for the shop header and the rebirth screen. Chain-link, brick and asphalt patterns sit inside panels at 3–6% opacity, so they never compete with content, following Splatoon's low-chroma background rule.

Icon motifs should map to Hood's features: a fist or lightning bolt for Power, a banknote stack for Cash, a paw in a cap for Crew, a hanger with a hoodie for outfits, and a spray can for Rebirth. The leaderboard icon is a trophy on a chain, and the board itself becomes a brick "Wall of Fame" with gold, silver and bronze plaques.

The Drip Shop already does something hit games do: its 15 looks are worn by in-world mannequins with an E prompt. Grow a Garden's physical shops show that in-world storefronts let players "learn from other players' interactions" ([Medium: Design Tactics of GAG](https://medium.com/@rtxhyperion/the-design-tactics-of-grow-a-garden-rob-c48e9e2dc7fd)). Keep the mannequins and give them a branded prompt. Set `ProximityPrompt.Style = Custom` and render the prompt client-side on `PromptShown`, with a hold ring driven by `PromptButtonHoldBegan` ([ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt)).

Then add a catalog popup: a 5×3 grid on PC and a 3×5 scroll on phones. Each card shows a rarity backing, the look's name in the display font and a price pill with the Power icon. Owned looks get a green check sticker, and the equipped look gets yellow "WEARING" tape across the corner. Locked looks go grey with a padlock and the requirement. The selected card gets a thick yellow stroke, a slight scale-up and a live preview.

Icons are the one place to spend money on images. DevForum commission rates run 70–100 Robux per button, 1,000–2,000 per menu and 3,000+ for a full system ([Planey's portfolio](https://devforum.roblox.com/t/planeys-uiscripting-portfolio/3560776)). One studio budgeted 5,000 Robux for an icon set in the Pet Sim and Bubble Gum Sim style ([DevForum: Need 2D Icon Artist](https://devforum.roblox.com/t/need-2d-icon-artist-for-cartoon-simulator-pet-sim-bgs-style/4768916)). Keep every icon on a shared canvas (for example 256×256 with 16 px padding) so they share visual weight. Keep UI images at or under 512×512, minor ones under 256×256, packed into sprite sheets ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)).

### Respect thumbs, the top bar and the safe area

Roblox's UI curriculum sets the hard constraints. Interactive UI never goes in the bottom-left (thumbstick) or bottom-right (jump) corners. Related elements are grouped and shown only when relevant. Layouts stay balanced with left-to-right hierarchy, and are tested against both light and dark backgrounds ([Wireframe your layouts](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/wireframe-your-layouts.md); [Choose an art style](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/choose-an-art-style.md)). The reintroduced Roblox top bar is **58 px tall on desktop and 52 px on mobile** ([DevForum](https://devforum.roblox.com/t/reintroduction-of-the-topbar-messing-up-ui/3260927)). `ScreenGui.ScreenInsets = CoreUISafeInsets` is the default and the recommended value for interactive UI; `None` is only for non-interactive backgrounds ([ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)).

Roblox publishes no minimum touch-target size. Its own jump button is 70–72 px on screens whose short side is 500 px or less, and 120 px otherwise ([TouchJump.lua](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/scripts/PlayerScripts/StarterPlayerScripts/PlayerModule.module/ControlModule/TouchJump.lua)). Platform norms are 44×44 pt (Apple) and 48×48 dp (Material) ([LogRocket](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/)). Roblox recommends placing custom buttons relative to the jump button ([Position and size](https://create.roblox.com/docs/ui/position-and-size)). It also warns that a button 40% down the screen is reachable on a phone but "almost unreachable on a tablet" ([Test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware)).

We propose this Hood HUD. Currency pills run along the top under the top bar, with Power larger than Cash. Each pill's icon overlaps its left end, and a small green plus opens the shop on that currency's tab. A vertically centered left column holds 4–6 square sticker buttons (Drip Shop, Crew, Rebirth, Quests, Codes), with red badges when something is claimable. A right column holds Leaderboard, Settings and Walls. The bottom center, between the thumbstick and jump zones, holds the contextual action and the wall progress readout ("12 / 50 Power"); it is the only place for a button of 56 px or more.

Popups take 85–92% of a phone's width and 55–70% on PC, capped with a `UISizeConstraint`. Each sits over a 40–50% black dim, with a 44–56 px red X overlapping the top-right corner and a title ribbon overlapping the top edge. The idle HUD should cover no more than about 15–20% of a phone screen, with one popup open at a time. Roblox's guidance warns that small screens "can easily get overwhelmed with excessive buttons, screens, and text" ([UI and UX design](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/ui-ux-design.md)).

### Build from Frames and the 2025–26 modifiers; save images for illustration

Roblox's UI toolbox changed enough in 2025–26 that the old "frame behind a frame" tricks are obsolete. UIStroke gained `StrokeSizingMode` (thickness in pixels, or as a fraction of the parent's short side or the font size). It also gained `BorderStrokePosition` (Outer, Center, Inner), `BorderOffset`, a `ZIndex`, and support for several border strokes on one object ([UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke); [StrokeSizingMode](https://create.roblox.com/docs/reference/engine/enums/StrokeSizingMode)). The full-release announcement notes that "you no longer need to create invisible Frame instances for layered stroke effects" ([DevForum](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036)).

`UIShadow` adds native drop shadows with blur, offset, spread and a negative ZIndex, and it follows UICorner rounding, but it cannot shadow text glyphs or draw inset shadows ([UIShadow](https://create.roblox.com/docs/reference/engine/classes/UIShadow)). UICorner now has per-corner radii. The docs still call these beta while a DevForum thread is titled "[Full Release]", so verify in Studio before relying on them ([UICorner](https://create.roblox.com/docs/reference/engine/classes/UICorner); [DevForum](https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263)). UICorner itself costs "minimal to no impact" ([DevForum](https://devforum.roblox.com/t/uicorner-vs-rounded-image/1206815)). UIGradient gained Radial and Conical types, `Scale` and `TileMode`, which are documented but hidden in the Properties window ([UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient)). Images remain best for illustrated icons, stickers, tape and torn-cardboard panels. Use 9-slice (`ScaleType = Slice` with a `SliceCenter`) so corners never stretch ([9-slice](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/9-slice.md)).

The resulting hybrid is a token module plus factory functions that build each component from Frames. The untested sketch below builds a sticker button using the 2025–26 APIs above. Its ink-outlined container is the dark lip, and the lit body drops onto the lip when pressed.

```lua
-- UIKit/Theme.lua (excerpt)
local Theme = {
	Ink = Color3.fromHex("1C1830"),
	Yellow = { Top = Color3.fromHex("FFE76A"), Base = Color3.fromHex("FFC21A"),
	           Lip = Color3.fromHex("D57D00"), Stroke = Color3.fromHex("5A2E00") },
	Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	Radius = { S = UDim.new(0, 8), M = UDim.new(0, 16), L = UDim.new(0, 24), Pill = UDim.new(0.5, 0) },
	LipDepth = 6,
}

-- UIKit/StickerButton.lua (btn is parented last, so modifiers are created off-tree)
local function stickerButton(parent: GuiObject, text: string, c, size: Vector2)
	local btn = Instance.new("TextButton")                  -- container = dark lip + ink outline
	btn.AutoButtonColor, btn.Text = false, ""
	btn.Size, btn.BackgroundColor3 = UDim2.fromOffset(size.X, size.Y), c.Lip
	Instance.new("UICorner", btn).CornerRadius = Theme.Radius.M
	local ink = Instance.new("UIStroke", btn)
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ink.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	ink.Thickness, ink.Color = 3, Theme.Ink
	local shadow = Instance.new("UIShadow", btn)             -- hard drop shadow, straight down
	shadow.Offset, shadow.BlurRadius = UDim2.fromOffset(0, 4), UDim.new(0, 0)
	shadow.Color, shadow.Transparency, shadow.ZIndex = Theme.Ink, 0.4, -1

	local body = Instance.new("Frame")                      -- lit face sitting above the lip
	body.Size, body.BackgroundColor3 = UDim2.new(1, 0, 1, -Theme.LipDepth), Color3.new(1, 1, 1)
	Instance.new("UICorner", body).CornerRadius = Theme.Radius.M
	local fill = Instance.new("UIGradient", body)
	fill.Rotation, fill.Color = 90, ColorSequence.new(c.Top, c.Base)
	local rim = Instance.new("UIStroke", body)              -- inner highlight, fading top to bottom
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	rim.Thickness, rim.Color, rim.Transparency = 2, Color3.new(1, 1, 1), 0.5
	local rimFade = Instance.new("UIGradient", rim)
	rimFade.Rotation, rimFade.Transparency = 90, NumberSequence.new(0, 1)
	body.Parent = btn

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
	label.FontFace, label.TextSize, label.Text = Theme.Display, 28, text
	label.TextColor3 = Color3.new(1, 1, 1)
	local outline = Instance.new("UIStroke", label)         -- Contextual by default = text outline
	outline.Thickness, outline.Color = 2.5, c.Stroke
	label.Parent = body

	local pop = Instance.new("UIScale", btn)                -- hover/press juice without layout reflow
	btn.Parent = parent
	return btn, body, pop                                    -- press: tween body.Position to (0, 4)
end
```

Responsive scaling is the other foundation. Roblox recommends Scale for positioning, but warns that sizing by Scale "would render to a huge size on 4K TVs for console players". It points developers to `GuiService.ViewportDisplaySize` (Small, Medium, Large) instead of guessing from pixel counts ([Cross-platform development](https://create.roblox.com/docs/projects/cross-platform); [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)). The pattern that holds up is to author every element in Offset pixels at a reference resolution and pin elements to screen edges with Scale positions and AnchorPoints. Then multiply each ScreenGui's whole tree with one `UIScale`, which "proportionally scales the object and all of its children, including any applied appearance modifiers like UIStroke or UICorner" ([UIScale](https://create.roblox.com/docs/reference/engine/classes/UIScale)). The community BetterScale module does the same, with a 1280×720 default reference and a clamped range ([BetterScale](https://github.com/bloxlibs/BetterScale)). In the sketch below, the phone boost and the clamp are proposals; tune them so a 72 px design-size button never drops below about 44 px on a phone.

```lua
local GuiService = game:GetService("GuiService")
local REF = Vector2.new(1280, 720)

local function scaledRoot(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.BackgroundTransparency, root.AnchorPoint = 1, Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local s = Instance.new("UIScale", root)
	local function update()
		local abs = gui.AbsoluteSize                         -- already excludes core-UI insets
		local k = math.min(abs.X / REF.X, abs.Y / REF.Y)
		if GuiService.ViewportDisplaySize == Enum.DisplaySize.Small then k *= 1.25 end
		k = math.clamp(k, 0.6, 1.6)
		s.Scale = k
		root.Size = UDim2.fromScale(1 / k, 1 / k)            -- after scaling, root exactly fills the screen
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(update)
	update()
	root.Parent = gui
	return root
end
```

Text needs the same discipline. Roblox says "it's recommended that you avoid usage of TextScaled" in favor of `AutomaticSize`, keeping TextScaled for BillboardGuis ([TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)). Under a scaled root, fixed `TextSize` values from the type scale stay consistent, and `AutomaticSize = X` handles labels of varying length. Any `UITextSizeConstraint` minimum should stay at 9 or above ([Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)). Strokes stay on `FixedSize`, because UIScale already multiplies them; two open DevForum bug threads report UIScale mis-scaling strokes, so test on a device ([DevForum 4157250](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250)). RichText supports inline strokes for emphasis, such as `<stroke color="#5A2E00" thickness="2">+1.2K</stroke>` ([Rich text](https://create.roblox.com/docs/ui/rich-text)).

For architecture, a plain-Luau kit gets most of the benefit without a dependency. It has three pieces: the Theme module, factory functions that return an instance plus a small API (`:Set(value)`, `:Destroy()`), and value objects with changed signals so the HUD never polls for updates. Roblox's engine-level StyleSheet system is the strongest new option for tokens and button states. Its rules select elements by class, CollectionService tag, name and state (for example `TextButton:Hover`), and tokens live as `$Token` attributes. `SetPropertyTransitions` animates state changes, and built-in queries such as `@ViewportDisplaySizeSmall`, `@PreferredInputTouch` and `@ReducedMotionEnabledTrue` swap layouts without code ([UI styling](https://create.roblox.com/docs/ui/styling); [CSS comparisons](https://create.roblox.com/docs/ui/styling/css-comparisons)).

Roact is deprecated ([DevForum](https://devforum.roblox.com/t/roact-ui-framework-crash-course-deprecated/796618)). React-lua, Fusion and Vide are maintained reactive alternatives ([react-lua](https://github.com/jsdotlua/react-lua); [Fusion](https://github.com/dphfox/Fusion/blob/main/wally.toml); [Vide](https://github.com/centau/vide)), but they add a learning curve Hood doesn't need yet. If Hood mixes StyleSheet transitions with script tweens, each property must have exactly one owner, or the two will fight.

Input and world labels follow the same cross-platform logic. Branch on `UserInputService.PreferredInput`, which Roblox now recommends over `TouchEnabled` for devices with more than one kind of input, and listen for changes ([UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService)). Wire buttons to `Activated`, which fires on click, tap and gamepad A ([GuiButton](https://create.roblox.com/docs/reference/engine/classes/GuiButton)). When a menu opens on gamepad, select its primary button with `GuiService:Select` and a themed `SelectionImageObject` ([GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)). Bag price tags should be BillboardGuis sized in Offset, with `AlwaysOnTop`, `LightInfluence = 0` and a `MaxDistance` of roughly 60–120 studs. Roblox recommends limiting billboard distance outdoors and reducing the number of visible billboard labels ([BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui); [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)).

For Crew and outfit previews, a `ViewportFrame` needs its own Camera and lighting (`Ambient`, `LightColor`, `LightDirection`). It renders no shadows or post-processing and draws Neon and Glass at lowest quality ([ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame)). Animated rigs must sit in a `WorldModel`, which Roblox says to create only when shown and delete when unused ([WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel)). For the 15-look grid, show pre-rendered thumbnails on every card and one live ViewportFrame for the selected look.

### Five rules keep a lively HUD cheap

UI cost comes from re-rendering, not just from how many elements exist. First, split ScreenGuis by update rate. A ScreenGui's appearance is cached until any descendant changes and then recomputed ([ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)), so a shining button or ticking timer inside the main HUD re-renders the whole HUD every frame. Hood should separate static HUD, animated HUD, popups and toasts. Second, animate cheap properties. The MicroProfiler guide ties layout cost to elements "being resized or repositioned, such as those managed by UILayout and those tweened with TweenService", and effect cost to UIGradient and UICorner on text labels ([MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)). Motion should therefore animate UIScale, rotation, transparency and gradient offsets, not Size and Position.

Third, use CanvasGroups sparingly. They "consume extra texture memory" and render blank once past the memory cap ([CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup)), so they suit only fading whole popups. Fourth, never tween UIStroke thickness on text, which re-rasterizes the glyphs and flickers ([UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke)). Fifth, keep and reuse the HUD. ScreenGuis built from LocalScripts need `ResetOnSpawn = false`, which Hood already sets, or they are destroyed on every respawn ([On-screen UI containers](https://create.roblox.com/docs/ui/on-screen-containers)). Toasts, damage numbers and inventory cells should come from reusable pools rather than `Instance.new` per event.

## Anticipation, contact and settle: animation from keyframes to springs

### Roblox rewards animations that load once and fire on markers

The twelve principles from Thomas and Johnston's *The Illusion of Life* (1981) still define good motion ([Wikipedia](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation)), and each has a direct Roblox equivalent.

| Principle | Keyframed (Animation Editor) | Procedural (Luau) | Hood example |
|---|---|---|---|
| Squash and stretch | Faked on rigid R15 limbs with body lean and a hip drop | Volume-preserving scale on single-mesh pets and bags | Bag squashes on impact; pets squash on landing |
| Anticipation | 3–6 frames of wind-up | Brief reverse motion, Back In easing | Punch wind-up; wall creaks before it collapses |
| Follow-through and overlap | Offset limb keys by 1–3 frames | Underdamped springs | Bag keeps swinging; Crew trail behind |
| Slow in, slow out | Cubic or InOut easing | Exponential smoothing, critically damped springs | All camera, pet and UI motion |
| Arcs | Fists and heads travel in arcs | Bezier curves | Power orbs arc from the bag to the HUD |
| Exaggeration | Poses pushed past realistic | Bigger shake, scale pops, hit-stop | A mega punch every Nth hit |
| Timing | Fast strike, longer recovery | Durations and spring frequency | See the punch timings below |

Roblox's Animation Editor runs in seconds:frames at **30 fps**. Keys default to linear easing, which the docs call "stiff and robotic", and cubic, elastic and bounce easing are available per key. Loops don't interpolate from the last key back to the first, so a smooth loop needs the first keys duplicated at the end ([Animation Editor](https://create.roblox.com/docs/animation/editor)). Opening the Curve Editor converts the sequence to a CurveAnimation, and a quaternion-to-Euler conversion "is impossible to convert back" ([Curve Editor](https://create.roblox.com/docs/animation/curve-editor)).

At runtime, load animations through `Animator:LoadAnimation`, not the deprecated `Humanoid:LoadAnimation` ([Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)). Each call creates a new track, so cache tracks or look them up with `GetTrackByAnimationId` ([Animator](https://create.roblox.com/docs/reference/engine/classes/Animator)). Priorities run Core, Idle, Movement, Action, then Action2–4. The highest priority wins on each joint, and equal priorities blend, a common source of jitter ([AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack); [DevForum](https://devforum.roblox.com/t/why-do-my-animations-look-stiff/2947662)). Gameplay should hang off markers through `GetMarkerReachedSignal`, which replaces `KeyframeReached` ([Animation events](https://create.roblox.com/docs/animation/events)).

Two 2025–26 changes matter. New experiences give R15 characters `AnimationConstraint` joints instead of `Motor6D`. C0 and C1 are read-only and `IsA("Motor6D")` returns false, so procedural offsets must multiply into `.Transform` during `PreSimulation` ([AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)). And animations must be owned by the experience's owner; for group games, publish them to the group, or they fail with a "sanitized ID" error ([DevForum](https://devforum.roblox.com/t/failed-to-load-animation-with-sanitized-id-when-loading-group-owned-animations/3550557)).

Hood can start with Roblox's Cartoony animation package and replace the clips with custom ones later. Its IDs are run 742638842, walk 742640026, jump 742637942, idles 742637544, 742638445 and 885477856, fall 742637151 and climb 742636889. Swap them into the `Animate` script's Animation objects during `CharacterAppearanceLoaded` ([Use animations](https://create.roblox.com/docs/animation/using)). The new Animation Graph Editor builds blend trees driven at runtime by `track:SetParameter` ([Animation Graph Editor](https://create.roblox.com/docs/animation/graph-editor)).

### A punch feels heavy when every signal lands on one frame

Fighting games split an attack into startup, active and recovery frames. Jabs commonly start in about four frames at 60 fps, and a generic Tekken 8 jab runs 9 startup, 1 active and 17 recovery frames ([In Third Person](https://inthirdperson.com/2012/04/18/universal-fighting-game-guide-how-to-read-frame-data/); [Wavu Wiki](https://wavu.wiki/t/Frame)). Hit-stop means briefly freezing attacker and target at the moment of contact. It sells the collision and gives the eye time to register it ([critpoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/)). Smash Bros. director Masahiro Sakurai lengthens it with damage but avoids long freezes ([Source Gaming](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)). One game-feel guide suggests about **35 ms for light hits, 70 ms for heavy and 90 ms for perfect ones, capped near 120 ms**, beyond which it "reads as a dropped frame" ([Sword Arcade](https://swordarcade.xyz/guides/game-feel-hitstop-and-screen-shake/)).

Two well-known talks round this out. Vlambeer's "Art of Screenshake" uses different shake strengths, small for routine actions and large for real events ([Game Developer](https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games)). The "Juice it or lose it" talk defines juice, the layered feedback that makes a game feel responsive, as "tons of cascading action and response for minimal user input" ([GDC Vault](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose)). A later counter-talk warns that too much of it hurts immersion.

Converted to Roblox's 30 fps, we propose a basic Hood punch of 0.35–0.5 s. It has 4–6 frames of anticipation, a 2–3-frame strike eased Out, 0.04–0.09 s of hit-stop, then 5–8 frames of recovery that a new click can cancel, so mashing feels responsive. A mega punch every Nth hit stretches anticipation to 8–12 frames and hit-stop to 0.09–0.12 s. Avoid a slow strike with a fast recovery; it reads as floaty, the opposite of power. Every effect below fires on the client from a "Hit" marker on the punch track, while the server only validates the hit and awards Power.

| Layer | Recipe | Basis |
|---|---|---|
| Hit-stop | `track:AdjustSpeed(0)` for 0.04–0.06 s (0.09–0.12 s mega), freeze the bag spring too, then restore | Hit-stop guidance above |
| Camera shake | Bump preset: magnitude 2.5, roughness 4, fade in 0.1 s, out 0.75 s, scaled by tier | [RbxCameraShaker presets](https://github.com/Sleitnick/RbxCameraShaker/blob/master/src/CameraShaker/CameraShakePresets.lua) |
| Particles | Core flash (1, ~0.1 s), shockwave ring (1, 0.2–0.3 s), 8–14 spark streaks (VelocityParallel, Drag 8–10), 3–5 dust puffs; all `Enabled = false`, fired with `:Emit()` | Adapted from Roblox's burst recipe (Drag 10, Lifetime 0.2–0.6, Speed 20–40) ([Explosions VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)) |
| Flash | White `Highlight` faded over 0.1 s, then destroyed | 255-Highlight cap ([Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)) |
| Bag | Instant squash X/Z ×1.12, Y ×0.88, then an underdamped spring sway | Proposal |
| Sound | Same frame, pitch randomized 0.95–1.05 | Proposal |
| Number | "+123 Power" pops with Back Out over 0.15 s, rises 2–4 studs over 0.6–0.8 s, fades | Common DevForum pattern ([DevForum](https://devforum.roblox.com/t/how-to-implement-a-damage-indication-system/483161)) |

```lua
local RunService = game:GetService("RunService")

local function hitStop(tracks: {AnimationTrack}, duration: number)
	local saved = {}
	for i, tr in tracks do saved[i] = tr.Speed; tr:AdjustSpeed(0) end
	task.delay(duration, function()
		for i, tr in tracks do if tr.IsPlaying then tr:AdjustSpeed(saved[i]) end end
	end)
end

-- Procedural bag sway: model pivot at the hook, underdamped spring (2.5 Hz, damping ratio 0.3)
local base = bag:GetPivot()
local angle, vel = Vector3.zero, Vector3.zero
local FREQ, DAMP = 2.5, 0.3
local function hitBag(dirWorld: Vector3, strength: number)
	local d = base:VectorToObjectSpace(dirWorld)
	vel += Vector3.new(d.Z, 0, -d.X) * strength                -- angular impulse away from the puncher
end
RunService.PreRender:Connect(function(dt)
	local w = 2 * math.pi * FREQ
	vel += (-w * w * angle - 2 * DAMP * w * vel) * dt         -- semi-implicit Euler
	angle += vel * dt
	bag:PivotTo(base * CFrame.Angles(angle.X, 0, angle.Z))
end)
punchTrack:GetMarkerReachedSignal("Hit"):Connect(function()
	hitStop({punchTrack}, 0.05)
	hitBag(rootPart.CFrame.LookVector, 6)
	-- shake(tier); burst(tier, contactCFrame); flash(bag); playSfx(); popNumber(amount)
end)
```

A procedural spring on the client beats physics for training bags. It is deterministic, cheap and never desyncs. An unanchored bag on a rope replicates, costs simulation, and can be flung by exploiters if the client owns it. If physics is ever needed, the legacy movers such as BodyPosition and BodyVelocity are deprecated in favor of AlignPosition and LinearVelocity ([Mover constraints](https://create.roblox.com/docs/physics/mover-constraints#legacy-mover-conversion)). Custom shake code must restore the camera's CFrame each frame; the RbxUtil Shake module documents camera drift against Roblox's default camera scripts ([RbxUtil Shake](https://github.com/Sleitnick/RbxUtil/blob/main/modules/shake/init.luau)).

### Springs and exponential smoothing replace per-frame lerps

The most common procedural bug is calling `lerp(a, b, 0.1)` every frame, which behaves differently at 30, 60 and 240 fps. The frame-rate-independent form is `lerp(a, b, 1 - exp(-k·dt))`, which can also be expressed as a half-life ([Freya Holmér](https://www.classcentral.com/course/youtube-lerp-smoothing-is-broken-a-journey-of-decay-and-delta-time-293974)). Roblox now ships `TweenService:SmoothDamp`, which "simulat[es] a critically damped spring" (no overshoot) for numbers, vectors and CFrames ([TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)). For overshoot and wobble, Fraktality's `spr` takes a damping ratio and a frequency. Damping below 1 overshoots for "extra pop", and `(0.6, 4)` "overshoots, and wobbles" ([spr](https://github.com/Fraktality/spr)). Quenty's analytic Spring adds impulses and time skips ([Nevermore Spring](https://github.com/Quenty/NevermoreEngine/blob/main/src/spring/src/Shared/Spring.lua)).

We propose four starting presets: UI pops at 4 Hz with damping 0.5, pet follow at 2 Hz critically damped, bag wobble at 2.5 Hz with damping 0.3, and squash recovery at 5 Hz with damping 0.4. Each needs the right frame event: `PreRender` (which replaces `RenderStepped`) for client visuals, `PreSimulation` for layering offsets into joint `.Transform`, `PreAnimation` for adjusting tracks, and `Heartbeat` for server logic ([RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)). Move models with `PivotTo`, which replaces `SetPrimaryPartCFrame`. Move many parts at once with `Workspace:BulkMoveTo`, "a very fast way to move large numbers of parts" ([Model](https://create.roblox.com/docs/reference/engine/classes/Model); [WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot)). An `IKControl` of type LookAt with a `SmoothTime` around 0.12 turns the player's head and torso toward the bag while training, and turns Crew heads toward the player ([IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl)).

### Crew pets live on each client

Simulator pets are the classic performance trap, because every client renders everyone's pets. The DevForum consensus is to store only the equipped pet IDs on the server and move pets on each client, which stays smooth under server lag ([Render pets on the client or server?](https://devforum.roblox.com/t/render-pets-on-the-client-or-server/442739)). It also recommends turning CastShadow off, staying under roughly 300 loaded pets, and offering a setting that hides other players' pets ([Pet follow module](https://devforum.roblox.com/t/pet-follow-module-simulator-style/901913)); the 300 figure is one developer's advice, not a benchmark.

Each Crew model should be anchored with collisions, queries, touch and shadows off. A single `PreRender` loop places every pet in a semicircle behind its owner with frame-rate-independent smoothing. It adds a sine hover for flying pets or a bouncing hop for walkers, skips owners more than about 200 studs away, and commits all positions in one `BulkMoveTo` call.

```lua
RunService.PreRender:Connect(function(dt)
	table.clear(parts); table.clear(cfs)
	local cam, t = workspace.CurrentCamera.CFrame.Position, os.clock()
	for _, owner in activeOwners do
		local root = owner.rootPart
		if not root or (root.Position - cam).Magnitude > 200 then continue end
		local moving = root.AssemblyLinearVelocity.Magnitude > 1
		for i, pet in owner.pets do
			local a = math.pi * i / (#owner.pets + 1)                         -- semicircle slot
			local goal = root.CFrame * CFrame.new(math.cos(a) * 4, 0, 3 + math.sin(a) * 1.5)
			pet.cf = pet.cf:Lerp(goal, 1 - math.exp(-8 * dt))                 -- framerate-independent
			local y = if pet.flying then 2 + math.sin(t * 3 + i) * 0.35
				else math.abs(math.sin(t * (if moving then 9 else 2) + i)) * (if moving then 0.8 else 0.15)
			table.insert(parts, pet.root); table.insert(cfs, pet.cf * CFrame.new(0, y, 0))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
```

Polish comes from small exaggerations. Raycast walking pets down to the ground on stairs. Face the direction of movement while moving, and the player when idle. Squash single-mesh pets to about (1.12, 0.85, 1.12) on landing and spring them back. Have nearby Crew cheer-hop when the player's "Hit" marker fires. Rarity effects should cost more as rarity rises: nothing on Common, and a sparkle emitter at 2–4 particles per second on Rare. Epic gets an aura ring and a Trail. Legendary gets a Highlight outline (own and nearest pets only, given the 255 cap) plus flipbook particles, and Mythic a Beam halo with periodic bursts.

### UI motion is fast in, overshooting out, and rationed

Motion is part of the sticker style. The common Roblox popup tweens a `UIScale` from 0.7 to 1 with matching transparency tweens ([DevForum](https://devforum.roblox.com/t/how-do-i-make-this-kind-of-ui-popup-animation/1468785)). A shine sweep is a UIGradient whose bright band moves by tweening `Offset`, not `Rotation` ([4 UIGradient Animations](https://devforum.roblox.com/t/4-uigradient-animations-including-rainbow/557922)). Squash-and-stretch presses "crush wide and short, overshoot tall and thin on the way back, and settle" ([Valdemird](https://valdemird.com/blog/game-feel-on-the-web/)).

Roblox cautions that "excessive use of bright, moving elements might overwhelm and confuse players" ([UI and UX design](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/ui-ux-design.md)), so continuous motion belongs only on the primary call to action and on Legendary-and-up cards. When a second tween targets the same property, TweenService cancels the first ([TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)), which makes UIScale the natural single owner of press and pop effects. Respect `GuiService.ReducedMotionEnabled` by swapping Back and Elastic easing for short Quad fades ([GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)). The timings below are proposals drawn from common practice, and every one should be paired with a short sound.

| Interaction | Motion | Timing and easing |
|---|---|---|
| Hover (PC) | UIScale 1.0 → 1.05, highlight brightens | 0.12–0.15 s, Quad Out |
| Press | Body drops onto lip, or UIScale → 0.92 | 0.06–0.10 s, Quad Out |
| Release | Overshoot to 1.06, settle at 1.0 | 0.18–0.25 s, Back Out |
| Popup open | UIScale 0.8 → 1.0, dim 0 → 0.45 | 0.22–0.30 s, Back Out |
| Popup close | UIScale → 0.85 with fade | 0.12–0.18 s, Quad In; hide only if the tween completed |
| Currency gain | Number counts up (tween a NumberValue), icon pops to 1.25, "+1.2K" floater rises | Count 0.4–0.8 s, pop 0.15 s, floater ~0.8 s |
| Wall break or rebirth | Rotating burst rays, confetti, center card, rarity glow | 1.0–1.5 s, skippable |
| Shine sweep | Primary CTA and Legendary+ only | One 0.6–0.8 s sweep every 3–5 s |
| Notification badge | Wobble ±6° | Every 2–3 s |
| Tutorial arrow | Bob 8–12 px | 0.6–0.8 s loop, Sine InOut |

### World motion and VFX run on the client, in short bursts

Decorative world motion must stay off the server. Roblox's performance guide explains that "if TweenService is used to tween an object server side, the tweened property is replicated to each client every frame", which jitters with latency and wastes bandwidth. Leftover Animation Editor data inside cloned rigs also causes needless replication ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). Hood should tag spinners, bobbing pickups and signs with CollectionService and drive them from one client `PreRender` loop with distance culling and `BulkMoveTo`. Doors should open with client tweens using Back Out easing for a cartoon overshoot.

The stage walls are per-player progression, so their destruction belongs on the client too. On the final hit, shake the wall for 0.15–0.3 s with a crunch sound, then swap it for a handful of pre-cut chunks. DevForum advice favors pre-made fragments, and four or five big jagged pieces over per-brick physics ([Breaking Walls Effect](https://devforum.roblox.com/t/breaking-walls-effect/680293)). Unanchor the chunks with outward and upward velocity, burst dust, and run an explosion-strength shake. Then fade the chunks and clean up through `Debris`, which has a hard cap of 1,000 items and destroys the oldest instantly when exceeded ([Debris](https://create.roblox.com/docs/reference/engine/classes/Debris)). The train is the exception. If players ride it, it must move on the server with physics-friendly methods, and riders on anchored parts moved by CFrame need testing for friction.

Stylized Roblox VFX are mostly short `Emit(n)` bursts from a few emitters on one Attachment. The particle docs call Transparency fades "one of the most vital" properties and use LightEmission 1 for additive glow. They cap Lifetime at 20 s and emission at 400 particles per second (100 on mobile), and warn that large particles cost fill-rate and overlapping transparent particles cost overdraw. Flipbooks come in 2×2, 4×4 and 8×8 grids on sheets up to 1024×1024 and are switched off automatically on low-memory clients ([Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)). `TimeScale` slows an emitter, which extends hit-stop to VFX ([ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)). Beams draw a curved, textured strip between two attachments, useful for the onboarding trail and neon strips, and Trails follow moving attachments ([Beams](https://create.roblox.com/docs/effects/beams); [Trails](https://create.roblox.com/docs/effects/trails)).

We propose three more Hood recipes. A level-up burst combines a rising column, a ring at the feet and 20–30 stars falling in a fountain arc. A pickup sparkle is 6–10 tiny stars while the orb flies to the HUD on a Bezier arc. A rebirth aura is a slow ground ring, rising wisps and an optional Highlight, limited to the local player and the nearest few others.

The amateur tells are consistent: linear easing, no anticipation or follow-through, and actions blending with idles at equal priority. Loops hitch, and the default 0.1 s fade softens snappy actions (use 0.03–0.08 s for punches and 0.2–0.3 s for idles). Feet slide because animation speed doesn't match WalkSpeed. Every hit is identical, with no pitch or particle variation, and full-strength shake fires on every click. Idles have both arms moving as mirror images, and effects run on the server.

## Retention, not spectacle, now decides who earns

### The 2025 mega-hits spiked on simple loops, then lost 99% of their players

The 2025 breakouts shared a short list of traits. Grow a Garden launched on March 26, 2025. Jandel's studio bought into it at about 1,000 concurrent players, and it peaked at **22.3 million concurrent users** on August 23 ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden); [PC Gamer](https://www.pcgamer.com/games/survival-crafting/a-roblox-farming-game-made-by-a-teenager-in-like-three-days-had-8-9-million-players-online-at-the-same-time-steam-peaked-at-11-5-million-across-all-games-on-the-same-day/)). Naavik attributes its pull to crops that grow while players are offline, random mutations and loot packs, daily incentives, and gardens visible to other players, which turn private progress into status ([Naavik](https://naavik.co/digest/predicting-the-next-big-hits-on-roblox/)). Major updates landed on Saturdays behind a live "Admin Abuse" event of special weathers and rare restocks ([GaG Fandom](https://growagarden.fandom.com/wiki/Admin_Abuse)).

Steal a Brainrot made rarer characters generate more money per second and let rivals steal from unlocked bases. It ran weekend admin events and peaked near **25.8 million** ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)). Smaller hits show the same mechanics at lower scale. Blade Ball went from 500 to 285,000 concurrent players in a month on 15-second duels and particle effects that fit TikTok clips ([Naavik](https://naavik.co/digest/blade-ball-ugc-success/)). Dead Rails rode influencer traffic into Roblox's algorithm ([GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)).

The earnings are real but unevenly spread and poorly measured. Third-party revenue estimates for Steal a Brainrot differ tenfold: about $11M per month in one ([Creator Exchange](https://x.com/CreatorExc/status/1952868682096574520)) and $1.4M in another ([RoWatcher](https://rowatcher.com/games/7709344486/steal-a-brainrot)). Neither is reliable. The platform-wide numbers are firmer. Roblox paid about **$1.7B through DevEx** over twelve months; the **top ten creators averaged $65.7M each**, while the **median payout among 42,000+ creators was about $1,500** ([TechSpot](https://www.techspot.com/news/113855-roblox-top-creators-making-65-million-year-while.html)).

The spikes also faded. By late September 2026, trackers put Grow a Garden at roughly 40–80K average players ([bloxquiz](https://www.bloxquiz.gg/stats/grow-a-garden/history)). Together with Steal a Brainrot's reported ~205K, both have lost over 99% of their peak. Roblox's Q2 2026 letter reported daily active users down three straight quarters, to 123M. It described "a greater than expected shift of engagement from high monetizing, 2025-vintage viral games, to both new and evergreen games". That shift was made worse by an algorithm that "intentionally provides more impressions for highly retentive games at the expense of near term monetization" ([Q2 2026 Shareholder Letter](https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf)). The counterexample is Bee Swarm Simulator, running since 2018 on infrequent, large seasonal updates, which reached its highest player count in seven years during Beesmas 2025 ([Rolimons](https://www.rolimons.com/game/1537690962)).

### The algorithm now pays for return days, not clicks

Roblox's Recommended For You system ranks games on per-user averages, counted only from players who arrived through the recommendations themselves. Ad, friend and search traffic gets a game considered but does not count toward its score ([Discovery](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery.md); [Discovery FAQ](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery-faq.md)). The most important signals are play-through rate (how many players who see the game start it) and first-play bounce, which is penalized in two buckets: under 60 seconds and 61–180 seconds. Next come play days per user, measured at D1, D2–7 and D8–28, and playtime per user, capped at 60 minutes per game per day. Co-play days, session counts and spending follow behind.

Since the global rollout on June 15, 2026, these signals are measured over **28 days instead of seven**, and "qualified" play-through rate gave way to plain play-through plus bounce ([DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575); [lensblox](https://lensblox.com/blog/roblox-algorithm-change-2026-explained/)). Games whose metadata or place files resemble existing ones are "no longer prioritized" ([Discovery](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery.md)), which matters for a repository that also holds remakes. Roblox's advice is blunt: "If retention is low, focus on core gameplay first" ([Discovery FAQ](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery-faq.md)). Payouts reinforce the same habit loop. Creator Rewards pays 5 Robux per day for each active spender who plays 10+ minutes, but only if the game is among the first three they launch that day ([Creator Rewards](https://github.com/Roblox/creator-docs/blob/main/content/en-us/creator-rewards.md)).

| Retention, games with ≥1M monthly players (Aug 2025–Jul 2026) | Median | Top 1% |
|---|---|---|
| D1 | 10.3% | 22.2% |
| D7 | 1.6% | 9.1% |
| D30 | 0.5% | 4.7% |

Those figures come from the [GameAnalytics 2026 Roblox report](https://www.gameanalytics.com/reports/2026-roblox-report). A competing claim that simulators average 32% D1 is higher than GameAnalytics' top-1% figure and should not be used as a target ([bloxg](https://bloxg.com/statistics/roblox-retention-benchmarks)). Thumbnails still drive play-through. With 2–5 active thumbnails rotated per player, qualified play-through rose 8.5% on average in Roblox's testing, and by 50% in some games ([Thumbnails](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/thumbnails.md)). Since June 2026, though, a thumbnail that overpromises raises bounce, which is now penalized. Configs and Experiments let Hood change reward sizes, hint timing and prices live, and A/B test them ([DevForum](https://devforum.roblox.com/t/live-now-use-configs-and-experiments-to-grow-your-game-faster/4051385)).

### Hood's loop needs a first wall inside 90 seconds, a visible Crew and a Saturday Block Party

Roblox's first-time-user guidance comes down to three rules: a brief tutorial, "a joyful moment after users complete your core loop for the first time", and a preview of future progress ([Retention](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/retention.md)). Hood's `Balance.lua` already aims at them. It targets a first wall within 60 seconds, a first Crew at 144–216 seconds and a first rebirth at 600–900 seconds, with wall costs growing 2.1x per wall and a flat 0.5 multiplier added per rebirth. The flat rebirth bonus avoids the runaway numbers DevForum developers warn about with compounding formulas like `price * 1.1^rebirths` ([DevForum](https://devforum.roblox.com/t/good-formula-to-calculate-amount-needed-to-rebirth/1047686)). The gap is that walls, Crew, Cash and rebirth are not built yet. The first wall break is therefore the most valuable piece of art in the game. It should be a 10–15 second spectacle of chunk debris, a giant number, the Crew cheering and a Cash shower: both the "joyful moment" and the clip players share, the way Blade Ball's duels traveled on TikTok.

Return days come from systems rather than polish. We propose offline Power and Cash, claimable on login and capped at 8–12 hours (upgradable). Add a 7-day login calendar, three daily quests and one weekly quest. A gift ladder at 5, 10, 20 and 30 minutes of playtime carries new players past the 10-minute Creator Rewards threshold, and an opt-in notification tells players when the Power bank fills. Status comes from visibility, the trait Grow a Garden's public gardens supplied: Crew following each player, overhead rebirth or neighborhood tags, the Power leaderboard Hood already has, and a server-wide announcement for rare box pulls and big wall breaks. Co-play days come from a Power bonus for each friend in the server and a two-player bag.

On cadence, Roblox calls a weekly update ideal and monthly the minimum ([Monetization](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/index.md)). It recommends keeping each regular content update under three weeks of effort and placing new content at the end of progression for veteran players ([Content updates](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/content-updates.md)). Home-page traffic peaks on Saturdays ([Discovery](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery.md)). A weekly Saturday update plus a 30–60 minute "Block Party" event borrows the ritual both 2025 hits used.

### Monetize after retention, and make Crew boxes compliant from day one

Simulator storefronts mix one-time passes with repeatable developer products ([Passes](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/passes.md); [Developer products](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/developer-products.md)). Pet Simulator 99 prices Auto Farm at 175 Robux, Lucky at 275, VIP at 400, Magic Eggs at 1,200 and Huge Hunter at 3,250 ([Pet Simulator Fandom](https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99))). Arm Wrestle Simulator, the closest structural analog to Hood, sells a **249-Robux VIP pass that triples training earnings** ([Item Level Gaming](https://itemlevel.net/arm-wrestle-simulator-best-gamepasses-to-get/)).

The 2025–26 platform changes all depend on prices being read live rather than hard-coded. Regional pricing lifted spending 17% in Mexico, 26% in Brazil and 52% in the Philippines in testing ([Kidscreen](https://kidscreen.com/2025/04/22/roblox-launches-regional-pricing-to-help-creators-do-more-global-business/)). Managed Pricing enrolls new items by default, and prices hard-coded in the UI block it ([Managed pricing](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/managed-pricing.md); [Price optimization](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/price-optimization.md)). Roblox Plus subscribers get discounts that Roblox subsidizes, so hard-coded prices show them the wrong number ([Roblox Plus](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/roblox-plus.md)). Hood's shop UI must therefore read every price from `MarketplaceService:GetProductInfoAsync`. Rewarded video ads should give rewards worth 3–10 Robux and can never grant random items ([Rewarded video ads](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/rewarded-video-ads.md)).

| Item | Type | Proposed price (Robux) | Comparable |
|---|---|---|---|
| 2x Power | Pass | 149–249 | Arm Wrestle VIP (3x training), 249 |
| 2x Cash | Pass | 149–249 | — |
| Auto-Train | Pass | 99–175 | PS99 Auto Farm, 175 |
| VIP (chat tag, lounge, daily box, cosmetic look) | Pass | 299–400 | PS99 VIP, 400 |
| Extra Crew slots | Pass | 79 / 179 | Arm Wrestle storage passes, 79 / 179 |
| Lucky Boxes (boost shown as a number) | Pass | ~275 | PS99 Lucky, 275 |
| Timed 2x boosts, starter pack, skip a wall | Developer products | Starter ~49–99 | — |
| Monthly subscription (daily box, Power bonus, monthly look) | Subscription | ≥49 Robux or $2.99–4.99 | Robux subscriptions start at 49 ([Subscriptions](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/subscriptions.md)) |

Compliance decides how Crew boxes can be sold. Roblox's paid random items policy covers anything random bought with Robux, or with in-game currency that can be bought with Robux. It requires itemized odds summing to 100%, shown before purchase in a popup labeled with a word such as "Details". Luck boosts must be disclosed as numbers. And PolicyService checks (`ArePaidRandomItemsRestricted`, `IsPaidItemTradingAllowed`) need fallbacks such as a direct-purchase alternative ([Paid random items](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/paid-random-items.md)). In mid-2026 Roblox applied South Korea's disclosure rules worldwide ([TechTimes](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)).

If Crew boxes cost only earned Cash, and Cash is never sold, they fall outside the policy. The moment Hood sells Cash packs, box packs or a Lucky pass, every box becomes a paid random item. The simplest path is to show odds on every box from day one. Separately, Roblox's presentation rules for younger players forbid permanent "sales", resetting countdowns and copy such as "LAST CHANCE", recommending neutral copy like "View Item" ([Monetization](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/index.md)).

Audience access is the last gate. Roblox rolled out Kids accounts (ages 5–8) and Select accounts (9–15) in 2026. New games now launch to age-checked 16+ players only, until they log 250 plays by "highly engaged" age-checked players within 60 days. Creators also need ID verification, two-factor authentication, and either a two-month Plus subscription or a refundable 1,000-Robux fee ([Kids and Select](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/kids-and-select.md)). "Unplayable gambling content" pushes a game to the Moderate rating and out of Kids, while Mild violence means unrealistic depictions ([Content maturity](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/content-maturity.md)).

Hood should keep its boxing cartoony, with no realistic injury, and its "hood" theme free of weapons, gang, drug and casino references. It should plan a small Plays- or Engagement-objective ad budget to clear the 250-play gate, remembering that players acquired through ads never count toward recommendation signals ([Ads Manager](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/ads-manager.md); [Discovery FAQ](https://github.com/Roblox/creator-docs/blob/main/content/en-us/discovery-faq.md)). Share Links with LaunchData perks give influencers a reward to hand out. Once Hood averages 100+ daily players over 60 days, each new or lapsed player who arrives through such a link and plays 10+ minutes earns Hood 35% of their first $100 of spending ([Share links](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/share-links.md); [Creator Rewards](https://github.com/Roblox/creator-docs/blob/main/content/en-us/creator-rewards.md)).

## Conclusion

Across building, UI and animation, "hand-crafted" comes from consistency, not effort. A Roblox map, HUD and punch read as professional when they share one light direction (warm, from above), one value structure (quiet large surfaces, saturated things you touch) and one timing language (fast in, long settle). They read as generated when each element makes its own choices. Hood's code-first pipeline is an advantage most simulator teams lack. A single shared Theme module can hold the palette, radii, stroke weights, TweenInfos, spring presets and VFX tiers, and drive `SimulatorLobby`, the HUD and the impact effects at once. That turns BIG Games' weekly-reskin discipline into a data change rather than a redraw.

The 2026 algorithm change also reorders what polish is worth. Art that wins a click but not a return visit now lowers a game's ranking through bounce. Hood's most valuable visual work is whatever shortens the time to the first payoff and makes progress visible to others: the first wall break, the Crew trailing behind each player, and a HUD readable on a 5-inch phone. The cheapest fixes are a few lines each and should go first: Soft lighting with a positive grade and a bloom threshold at or below 1, a lobby split into separately streamed models, and Gotham replaced with explicit FontFaces. The UI kit and the punch impact come next. The Crew renderer and the box-odds plumbing should be in place before any Robux touches a box.
