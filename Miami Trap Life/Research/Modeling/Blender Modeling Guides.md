---
tags: [miami-trap-life, research, modeling, blender, art, performance]
updated: 2026-11-03
---
# Blender modeling guides (from Alex's TikTok finds)

Back to [[00 Master Plan]] · Related: [[Gun Mechanics]], [[Model Sourcing Guide]], [[Interior Textures]], [[Map and Building Quality - Lessons]]

2026-11-03 · thread "Add Blender modeling guides to the vault". Source: 16 screenshots Alex saved from TikTok **@jodietess**, who shows a Roblox modeller's work plus the YouTube videos they learned from. Images are in `Modeling/Reference Images/`.

**Short answer:** the stylized look in those screenshots (chunky AK, toy blasters, pistol skins, swords, cute pets) is all **simple low-poly box modeling + flat colour or one small palette texture**. It's the cheapest kind of model for Roblox to load, and it's learnable in a weekend with the six videos below. For Miami Trap Life we want the same *workflow* but a grittier palette, and we keep every asset inside a triangle and texture budget so the game still loads fast on phones.

> How these summaries were made: YouTube blocks transcript downloads from here, so I couldn't watch the videos. Each summary comes from the video's title, chapters, description and thumbnail, plus what those standard Blender techniques are. Lines marked *(inferred)* are my best guess at what the video shows.

---

## 1. The six videos

Watch order for someone new to Blender: **5 → 2 → 6 → 3 → 1 (parts 1, 2, 4–6 only) → 4**.

| # | Video | Channel | Length | Link |
|---|---|---|---|---|
| 1 | Beginner Blender Tutorial (2026) | Blender Guru | ~4 h (8 parts) | https://www.youtube.com/watch?v=z-Xl9tGqH14 |
| 2 | The ULTIMATE Blender Modeling Guide for Noobs! (Make Assets For Games!) | SmartyRBX | 34:20 | https://www.youtube.com/watch?v=W337AL7n3dc |
| 3 | Blender Tutorial: Make Your First 3D Product Animation – Modeling, Part 1 | Sost cgTeCH | 14:59 | https://www.youtube.com/watch?v=l1TH8kvZiow |
| 4 | How To 3D model Any Roblox Character (Monkey D. Luffy) Part 1 | Chefo 3D | 34:08 | **Not found yet**, see below |
| 5 | Blender Is Easier Then You Think – Here's What You Need to Know! | RoBuilder | 6:52 | https://www.youtube.com/watch?v=QTnBCUqyUX0 |
| 6 | Beginner Modelling Tutorial Blender (TIE fighter) | CBaileyFilm | 23:06 | https://www.youtube.com/watch?v=SVl_tlbGrh4 |

### 1. Blender Guru, "Beginner Blender Tutorial (2026)" (the donut course)
The classic donut course, re-recorded for 2026 as one long video (uploaded 14 Jan 2026). Chapters: 0:00 basics · 28:16 basic modeling · 59:05 organic modeling · 1:30:13 materials · 2:03:46 texturing · 2:35:40 UV unwrapping · 3:09:26 scattering · 3:46:11 lighting and rendering.
- **Basics:** viewport navigation, Object vs Edit mode, move/rotate/scale (G/R/S) with axis locks (G then X/Y/Z), snapping, the N panel for exact sizes.
- **Basic and organic modeling:** start from a primitive (a torus), **Subdivision Surface** modifier, **proportional editing** (O) to push lumpy organic shapes, **Solidify** for thickness, shrinkwrap the icing onto the donut.
- **Materials and texturing:** the Principled BSDF (base colour, roughness, metallic), image textures, procedural noise.
- **UV unwrapping:** marking seams, unwrapping, checking stretching with a checker texture. *This is the chapter that matters most for Roblox*, because every textured MeshPart needs a clean UV map.
- **Scattering:** geometry nodes to scatter sprinkles.
- **Skip for Roblox:** sculpting detail, scattering and Cycles rendering. Roblox doesn't use Blender's renderer or materials, only the mesh, the UVs and the texture images you bake or paint.

### 2. SmartyRBX, "The ULTIMATE Blender Modeling Guide for Noobs! (Make Assets For Games!)"
Roblox-focused (Jan 2025, 1.1M views). Aimed at making game assets and UGC; the description links a **colour palette** image. Thumbnail: cube → stylized tree.
- **Box modeling from a cube** *(inferred, it's the thumbnail)*: extrude (E), inset (I), loop cut (Ctrl+R), bevel (Ctrl+B), scale faces to shape, then add a few bevels so edges catch light.
- **Palette texturing** (the linked palette): one small image of colour squares; every face's UVs are scaled down and dropped onto a colour. Many models share **one** texture, so Roblox downloads it once. This is how the stylized gun packs in the screenshots are coloured.
- **Low-poly mindset:** only add edges where they change the silhouette. Flat shading or "shade auto smooth" instead of subdivision.
- **Getting it into Roblox** *(inferred)*: export FBX, import with the 3D Importer, check the scale.

### 3. Sost cgTeCH, "Make Your First 3D Product Animation – Modeling, Part 1"
Models a soda can from a reference image (Nov 2023). Part 2 covers materials and condensation.
- **Reference image in the background**, then match the profile: start with a cylinder, add loop cuts, and scale each edge loop to follow the can's outline (the neck, the rim, the bottom dome).
- **Supporting edge loops** next to hard edges so a Subdivision Surface keeps them sharp *(inferred, standard for this kind of product model)*.
- **For Roblox:** the "follow the outline with edge loops" trick is the fastest way to make round props: cans, bottles, fire hydrants, trash cans, rims and tyres. Use **12–16 sides** instead of 32+, and **apply** the subdivision at level 0–1 or skip it.

### 4. Chefo 3D, "How To 3D model Any Roblox Character (Monkey D. Luffy) Part 1"
34:08, about 14K views, about 2 months old in Alex's screenshot. **I couldn't find the link**: search engines don't index this small channel yet. To find it: search YouTube for `Chefo 3D Luffy Roblox` or open the channel from the TikTok. Send me the link and I'll add it.
- From the thumbnail *(inferred)*: a blocky Roblox-proportion character built in Blender, with clothing textures painted in **Photopea** (the "Pt" icon), front and back views.
- **For us:** useful later for custom NPCs (Patel, crew members) if we ever go past standard Roblox avatars. Not a priority: our NPCs already use R15 rigs and clothing.

### 5. RoBuilder, "Blender Is Easier Then You Think – Here's What You Need to Know!"
6:52 (Nov 2024, 314K views). Thumbnail: a sci-fi crate with "ONLY 5 BUTTONS".
- The pitch: you only need a handful of tools to model most game props *(inferred)*: **Extrude (E), Inset (I), Loop Cut (Ctrl+R), Bevel (Ctrl+B)**, plus **Grab/Scale/Rotate**. Everything in the gun screenshots can be made with these.
- Good first video because it's short and kills the "Blender is too hard" feeling.

### 6. CBaileyFilm, "Beginner Modelling Tutorial Blender" (TIE fighter)
Premiered 7 Dec 2023, 499K views. Builds a TIE fighter as a beginner hard-surface project (the full version is on Patreon).
- **Mirror modifier**: model one half, get the other free. Use this on every gun, car body and symmetrical prop.
- **Hard-surface habits** *(inferred)*: inset + extrude for panels, bevel for edges, solidify for thin wing panels, keep the model in clean separate pieces.
- Same channel, also worth it: "The ONLY 5 Modeling Tools You Need To Make ANYTHING in Blender" https://www.youtube.com/watch?v=kejQ8nX5YZA

---

## 2. What the screenshots show (`Reference Images/`)

| File | What it is | What to take from it |
|---|---|---|
| 01 Blocky hyena model in Studio | Voxel-style animal imported into Roblox Studio | Cubes + flat colours read clearly from far away and are almost free to render |
| 02 Batons, revolver and 1911 in Studio | Realistic-ish baton, revolver and a black 1911 pistol | The closest to **our** style: dark metal, simple shapes, one texture |
| 03 Stylized orb collectibles in Studio | Glossy decorated orbs/eggs | Collectible-item look; not our game |
| 04 Stylized AK in Blender | Chunky cartoon AK, yellow wood + purple metal, thick bevels | Box modeling + palette colours. Swap the palette for realistic tones and it's a hood-game AK |
| 05 Toy blaster pack | 15 bright toy guns | Shows a **pack**: one modeller, one palette, consistent style |
| 06 Pistol skin variants | Same pistol shape, many colours/finishes | **One mesh, many skins** = the cheapest way to sell cosmetics |
| 07 Rifle and shotgun pack in Blender | Rifles, shotguns, SMGs | Layout of a whole arsenal in one Blender file |
| 08 Cute character grid | 30+ cute blob characters | Pet/collectible style; not for us |
| 09 Elemental sword set | Ice, fire, vine and gold swords | Skin tiers: same silhouette, effects and colour make the rarity |
| 10 Handbag low-res vs real | Birkin bag at three levels of detail | Reference for low-poly vs detailed (and a possible shop prop) |
| 11–16 Video thumbnails | The six videos above | |

---

## 3. Blender → Roblox: the rules that matter

From Roblox's docs ([mesh specs](https://create.roblox.com/docs/art/modeling/specifications), [export requirements](https://create.roblox.com/docs/art/modeling/export-requirements), [texture specs](https://create.roblox.com/docs/art/modeling/texture-specifications)) plus standard practice.

**Hard limits**
- **20,000 triangles per mesh.** Bigger models must be split into several MeshParts.
- **One material per mesh.** Different materials (glass, tyres, body) = separate meshes, or one texture atlas.
- Textures up to 4096×4096, but **UV texture maps up to 1024×1024**. Formats: PNG, JPG, TGA, BMP.
- PBR through **SurfaceAppearance**: albedo, normal (OpenGL tangent-space), roughness, metalness.
- Watertight geometry, no zero-thickness faces; quads where possible, no n-gons.

**Blender FBX export** (File > Export > FBX)
1. Apply transforms first (Ctrl+A > All Transforms) and put the origin where you want the pivot (gun: the grip; door: the hinge; prop: the bottom centre).
2. Path Mode **Copy** + **Embed Textures** on.
3. Transform: **Apply Scalings = FBX Unit Scale**. If it imports 100× too big or small, set the scale to 0.01 (Roblox's own screenshot shows 0.01) and save the export as a **preset** so every asset uses the same settings.
4. Armature: turn off **Add Leaf Bones**. Turn off **Bake Animation** unless exporting an animation.
5. Import in Studio with the **3D Importer** and check the size against a 5-stud-tall character. Fix the scale once, then reuse the preset.
- OBJ also works for static meshes (that's what our car threads used), but FBX keeps the textures and pivots together.

**Texture sizes by object size** (Roblox's recommendation)
- ~5×5 studs → 256×256 · ~10×10 studs → 512×512 · ~20×20 studs → 1024×1024.
- A gun or a cup never needs more than 256–512. A palette texture can be **64×64**.

---

## 4. How this applies to Miami Trap Life

The goal is **assets that look custom but load like nothing**. Three rules sit over everything:
1. **Reuse meshes.** The same MeshId + same texture is loaded once and drawn cheaply, however many copies are on the map. 40 identical chairs cost about the same as one.
2. **Share textures.** One palette or atlas per family (guns, kitchen, store shelves) instead of a texture per object.
3. **Turn off physics on decoration.** Most of the load-time and lag cost on Roblox is collision and too many parts, not triangles.

### Guns
- **Style:** the box-modeling workflow from the screenshots (04, 06, 07), with a **realistic palette** (black polymer, gunmetal, worn wood, brass), not toy colours. Image 02 (the 1911) is the target look.
- **Budget:** **1,500–4,000 triangles** per gun, **one 512×512 texture** (or a shared 128×128 palette for the whole arsenal). Separate meshes only for parts that move: the **magazine** (reload animation) and the **slide or bolt** (kick when firing).
- **Pivot and attachments:** origin on the grip so it sits in the hand; add `Muzzle` and `Grip` attachments in Studio so [[Gun Mechanics]] can find the barrel end for tracers and flashes.
- **Skins** (image 06): one mesh, many textures or colour tints. Cheap to add, great for the store and rebirth rewards, and every skin reuses the same mesh download.
- **Settings:** `CanCollide`, `CanTouch` and `CanQuery` off on the gun parts, `CollisionFidelity = Box`, `Massless = true`. Hit detection already uses the character, not the gun.
- **Names:** made-up model names like our cars (no Glock or Draco trademarks), per [[Model Sourcing Guide]].

### Props for interiors (Food Mart, apartments, trap house, Royce's office)
- **Budget:** small props (cans, bottles, cups, phones) **50–300 tris**; furniture (chairs, beds, counters, shelves) **300–1,500 tris**; a whole room should stay under about **30,000–50,000 tris** total.
- **Round props:** the soda-can method (video 3) with **8–16 sides**: cans, bottles, trash bins, hydrants, bar stools.
- **Kitbash once, reuse everywhere:** make a 20–30 piece **interior kit** (shelf unit, fridge, counter, chair, table, bed, couch, TV, crates, boxes, posters) sharing **one 1024×1024 atlas**. Store shelves are filled with a few product meshes repeated hundreds of times, which is cheap because they're the same mesh.
- **Collision:** `CanCollide` off for anything smaller than knee height; big furniture gets an invisible Box part for collision instead of the mesh's own hull.
- **Streaming:** keep `StreamingEnabled` on and parent each interior to its own Model so it only loads when a player is near it.
- **Text and logos** (store signs, cereal boxes) go in the texture, never as modelled geometry or many SurfaceGuis.

### Cars
- We already have two bodies: `cars/Halcyon_body.obj` is **11,944 tris** (detailed) and `cars/Kestrel_body_lowpoly.obj` is **1,876 tris**. Both are under the 20k limit.
- **Budget per car:** body **6,000–12,000 tris**, each wheel **300–800** (one wheel mesh reused four times), windows as one separate mesh (glass material), interior 1,000–3,000 or skip it with tinted glass. Total about **15,000–25,000 tris**, split across meshes.
- **Mirror modifier** on the body (video 6), and model the wheel once.
- **Textures:** the paint is a `Color` on the MeshPart (or a tinted SurfaceAppearance) so **one mesh gives every paint colour** in the garage; only a small atlas for lights, grille and badges.
- **Far away:** set `RenderFidelity = Automatic` so Roblox uses lower detail at distance. Parked traffic cars can use the low-poly Kestrel-style body.
- **Physics:** the A-Chassis rig handles collision with simple parts; set the body mesh's `CollisionFidelity` to Box or Hull, never PreciseConvexDecomposition.

### Loading-speed checklist (every asset, before it goes in the game)
- [ ] Triangles under the budget above (Blender: Overlay > Statistics shows the count)
- [ ] Transforms applied, origin at the right pivot, exported with the saved preset
- [ ] One texture, the smallest size that looks right (256–512 for hand-held, 1024 max)
- [ ] Reuses an existing palette or atlas when possible
- [ ] `CollisionFidelity = Box` (or Hull for cars), `CanCollide`, `CanTouch`, `CanQuery` off on decoration
- [ ] No Unions (use MeshParts instead)
- [ ] Made-up names, no real brands or ripped models

---

## 5. Learning plan for Alex (about one week, an hour a day)
1. **Day 1:** video 5 (RoBuilder), then make a crate with only E, I, Ctrl+R, Ctrl+B.
2. **Day 2:** video 2 (SmartyRBX); make a palette-textured prop and get it into Studio at the right size.
3. **Day 3:** video 6 (CBaileyFilm); use the Mirror modifier to model a pistol from a side-view reference.
4. **Day 4:** video 3 (Sost cgTeCH); make a soda can and a trash bin at 12 sides.
5. **Day 5–6:** video 1, parts 1, 2, 4, 5 and 6 (Blender Guru): materials, textures and **UV unwrapping**. Give the pistol a proper 512 texture.
6. **Day 7:** an AK in the style of image 04 with a realistic palette, under 3,000 tris, imported and held by the character.
