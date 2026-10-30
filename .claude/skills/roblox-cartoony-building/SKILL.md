---
name: roblox-cartoony-building
description: Use when building or lighting a map, lobby, island, zone or prop pack for a kid-focused cartoony / low-poly Roblox game (simulator, +1, steal-style), or when a map looks flat, empty, grey, too green or too dark. Gives the layout order, prop budgets, Blender low-poly recipes and copy-ready lighting presets taken from the AI Video Library transcripts.
---

# Cartoony / low-poly maps and lighting

Sources: `AI Video Library/Video Notes/Cartoony building and lighting/` (8 transcript notes) and
`AI Video Library/16 Cartoony Kid-Appeal Checklist.md`. Deep numbers and reasons:
`reports/Cartoony Roblox building UI and animation.md`. Grep these for detail; don't read them whole.

## 1. Layout order (DeHapy "PRO maps", 1 hour build)
1. **Fix lighting first** (section 4). Default lighting makes every build decision wrong.
2. Base: one grass ground about **250x250** studs for a simulator hub.
3. Spawn at a corner or edge, never dead centre. A **circular path plus one wide main path** pulls new players outward.
4. Platforms for each point of interest (portals, eggs, shop). Paths at least 10 studs wide, smooth curves at one fixed angle.
5. Border wall (a row of about 5 parts, duplicated around the map). Dense, decorated edges hide the boundary.
6. **Big filler first, then small filler** (trees, rocks, grass tufts), then rock transitions where flat green meets platforms.
7. Colour accents last (waterfall, recoloured border near it) so the map isn't all one green.
8. Put the money features near spawn: shop, eggs, wheel spin, leaderboard, top pet. VIP gets its own area.
- Zones: **linear, zone by zone, gated** (zone 1, 2, 3 reusing the same code) beats a circular map (SyphoDev creature game).
- Gate worlds by two kinds of progress (rebirths **and** level) and show the next area's price across a gap.
- No empty patch bigger than about 30x30 studs; the spawn plaza stays calm.
- A human (or the owner) can rough out the world layout and let Claude map spawns and zones onto it; that split worked better than AI-only layout.

## 2. Style rules
- SmoothPlastic, faceted shapes, chamfered tops, trims at least 0.5 to 1 stud thick. Stay in one style.
- Saturate what players touch (75-100%), soften what they stand on (20-55%). 5-7 base colours per zone plus 1-2 accents.
- Make repeated tiles less cloned: randomise colour slightly and swap between 3-4 similar textures by script (Develuper).
- Overlapping parts flicker (Z-fighting): ask for a pass that fixes every overlap; anchor all props.

## 3. Low-poly props in Blender (budgets)
| Prop | Recipe | Source |
|---|---|---|
| Rock | Icosphere, 1 subdivision | Gamer M8 |
| Grass tuft | 3-vertex cones joined | Gamer M8 |
| Ground chunk | 8-vertex cylinder, 3 loop cuts; or rock body + thin grass cap as 2 MeshParts | Gamer M8, Vadez |
| Tree | 8-vertex trunk, 3 loop cuts, stacked 8-vertex cones | Gamer M8 |
| Stylized "Ghibli" tree | Leaf-card planes, normals transferred from a sphere (Face Corner, Custom Normals) | DatBoiEle |
| Pet | Beveled cube body, duplicated limbs, one shared palette texture; recolour by moving UVs | Sayzz |
| AI-made pet/character | Meshy image-to-3D, Adaptive remesh to about 3k tris (pets) / 6k (characters) | MrWonderHow |
- Export **FBX** (keeps separate colour parts; OBJ doesn't). Recalculate normals (Ctrl+N) before every export. Anchored on at import; it comes in huge, so scale in Studio.
- Hard-edged props (crates, pads, guns) are better modelled directly than via image-to-3D.
- Leaf-card trees: SurfaceAppearance AlphaMode Transparency, DoubleSided on, white RoughnessMap (no shine), run PixelFix on the leaf PNG or edges go black.
- Pretty foliage trick: a PointLight in the canopy tinted the leaf colour plus a dim blue one underneath. Keep Range small.
- See also the `blender-roblox-models` skill for the repo's own Blender pipeline.

## 4. Lighting presets
Modern Studio: `Lighting.LightingStyle = Soft`, `PrioritizeLightingQuality = true` (older videos say ShadowMap/Future; ignore that part).
Pick ONE preset, then tune by eye in a screenshot, in daylight and on a phone.

**A. Purple & yellow cartoon (Gamer M8, every number spoken)**
Ambient 200,160,225 · OutdoorAmbient 125,100,150 · Brightness 2 · ColorShift_Top 215,190,135 · ColorShift_Bottom black ·
EnvironmentDiffuseScale 0.3 · EnvironmentSpecularScale 0.25 · GlobalShadows on · ShadowSoftness 0.2 · ClockTime 14 ·
GeographicLatitude 40 · ExposureCompensation 0 · FogColor 200,170,250 · FogEnd 2500 ·
ColorCorrection Brightness 0.05, Contrast 0.1, Saturation 0.15.

**B. Soft bright low-poly (barjNET)**
Delete default sky/effects. Lighting.Brightness about 1, ColorCorrection Brightness pushed up, then Saturation 0.9 and
Contrast 0.15 to win the colour back. ExposureCompensation 0.1 (sunny outdoor). ShadowSoftness max.
Atmosphere Offset 25, low Density. Ambient/OutdoorAmbient warm orange; ClockTime near overhead.
Saturation 0.9 is strong: start lower if colours burn.

**C. Sunny stylized (DatBoiEle)**
Ambient dark blue, OutdoorAmbient blue, ColorShift_Top yellowish, lowered Environment scales, ExposureCompensation up a touch,
ColorCorrection about 0.05 steps.

Always:
- Atmosphere Density 0.3-0.4, Offset 0 (Develuper) unless using preset B. Default atmosphere is far too foggy.
- Bloom last, threshold about 0.9-1.0 so only neon glows.
- One ambient hue per zone (orange earthy, blue ice) is the theme dial.
- Mobile: keep post effects to Sky, ColorCorrection, Atmosphere, Bloom.

## 5. Check before showing the owner
- [ ] Screenshot from spawn: the main action, shop, leaderboard and first gate are visible.
- [ ] Not too dark, not foggy, not all green; plots/bases readable (SyphoDev's first map was too dark).
- [ ] No flicker, no floating or falling props.
- [ ] Ran through `AI Video Library/16 Cartoony Kid-Appeal Checklist.md` (Building, Color, Lighting, Performance).
