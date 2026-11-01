---
name: roblox-realistic-building
description: Use when building, lighting or dressing a realistic Roblox map (RP city, hood or worn city block, coastal town, roads, bridges, highways), or when a realistic map looks plastic, clean, empty, flat, foggy or lags on phones. Gives the build order, lighting presets, material and wear recipes, road and block numbers, foliage, mesh pipeline, phone budgets and living-world systems from Build Playbooks 33-39.
---

# Realistic maps (RP city, hood, coastal town)

Not for cartoony games: those use `roblox-cartoony-building`. Read the playbook rows you need; grep, don't read whole notes.

| Job | Open |
|---|---|
| Process, reading a reference, critic sheet, symptoms | `Build Playbooks/33 Realistic World Building Playbook.md` |
| Lighting presets (Command Bar code), day/night, graphics menu | `Build Playbooks/34 Realistic Lighting and Atmosphere.md` |
| MaterialVariant library, SurfaceAppearance, wear and graffiti | `Build Playbooks/35 Realistic Materials, Decals and Wear.md` |
| The 68 picked CC0 textures for hood and downtown, download and install scripts | `Build Playbooks/40 Realistic Texture Library - Hood and Downtown.md`, `Build Playbooks/realistic-kit/textures/` |
| Road widths, city plan, road and facade kits, power lines, furniture | `Build Playbooks/36 Roads, Blocks and City Layout Kit.md` |
| Terrain, water settings, trees, palms, bushes, scatter, wind | `Build Playbooks/37 Terrain, Water and Foliage.md` |
| Blender export, LOD, streaming, triangle and phone budgets, audit | `Build Playbooks/38 Mesh Pipeline, LOD and Mobile Budgets.md` |
| Ambient traffic, pedestrians, ambience audio, light culling | `Build Playbooks/39 Living World - Traffic, NPCs and Ambience.md` |
| Alex's reference pictures | `References/References - Realistic Worlds.md` (files in `Build Playbooks/references/realistic-worlds/`) |

## The rules that matter most
1. **Five layers on simple shapes, in order:** lighting, real-scale PBR materials, a reasoned wear layer, three-height foliage with wind, life (cars, people, sound). Build them on a blockout that already plays well.
2. **Lighting first:** `LightingStyle = Realistic`, `PrioritizeLightingQuality = true`, `EnvironmentDiffuseScale`/`EnvironmentSpecularScale` near 1, warm sun vs cool `OutdoorAmbient`, Atmosphere colour matched to the world. Presets in note 34 §3.
3. **Real scale:** vertical scale true (door 7–8, storey 10–12, kerb 0.6–0.8), horizontal compressed; `StudsPerTile` from the texture's real size (1 stud = 0.28 m).
4. **Wear has reasons:** patches over utility lines, stains under AC drips, tyre marks at turns, grime skirts on walls, graffiti only where people reach. Bake most wear into tile variants; loose decals only for hero spots.
5. **Reuse meshes, tint for variety:** import once, clone; `SurfaceAppearance.Color` and part Color tints are free. 512 textures by default.
6. **Phones:** shadows vanish below quality 4, so the scene must read by value; test at quality 1 on a real phone; ship a High/Medium/Low graphics menu.
7. **Golden slice:** one intersection plus one block face through all layers, side by side with the reference, fresh critic (note 33 §8), then show Alex, then roll out.
8. **Ours, not theirs, and kid-safe:** our own buildings, signs, names, graffiti; "hood" means worn architecture only, no gang, drug or crime iconography.
9. **Alex's Studio edits win:** read the live Studio copy first and merge; remind Alex to press Cmd+S after installs.

Every code block in notes 34–39 is marked "sketch, not yet run in Studio" until a golden slice proves it. When one is proven, change that line and record tuned values back in the note.
