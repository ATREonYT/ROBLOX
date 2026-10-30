---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=vkEXLmRAQgs
creator: "Develuper"
video_id: "vkEXLmRAQgs"
---
# Make Your Roblox Game Look 10x Better With Lighting

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
A workflow of lighting choices (realistic style, ambient tweaks, atmosphere, bloom, sun rays, skybox, color correction) plus two extras: a Highlight for a retro look and a script that randomizes textures and colors on map parts. Few exact numbers; mostly guidance.

## Tools and setup
- Roblox Studio Lighting, Atmosphere, Bloom, SunRays, ColorCorrection effects.
- Toolbox skyboxes (search by style).
- Highlight object applied to players via script (must not show through walls).
- Texture pack (pick 3 or 4 similar textures, copy their IDs).
- Creator may share lighting presets in the description.

## Step-by-step
1. [00:00] Switch the lighting style (Technology) to realistic/best shadows: "gives much better shadows and overall quality".
2. [00:00] Slightly raise Brightness and tweak the two ambient colors: Ambient (shadow tone) and OutdoorAmbient (outdoor light). Adjust time of day and sun angle.
3. [01:01] Atmosphere: Density between 0.3 and 0.4, Offset 0. Use a small amount of light-colored Glare and a little darker Haze for depth. (He removes fog in his own world.)
4. [01:01] Bloom: increase so bright objects stand out. Add SunRays, especially for late afternoon or sunset.
5. [02:02] Skybox: search the toolbox for the style you want.
6. [02:02] ColorCorrection: soft tone (very light blue), raise saturation per style, and add contrast for sharp, clean visuals.
7. [02:02] Optionally set the baseplate MaterialVariant to studs.
8. [03:02] Retro look: apply a Highlight to all players via script, configured not to show through walls (DepthMode occluded, inferred).
9. [03:02] Randomize textures: create a folder for map parts, add a script that gets the map, stores 3 or 4 texture IDs, detects all surfaces of each part, and applies random textures in a loop.
10. [03:02] Randomize colors: build a tone-variation palette and apply variations to each part's original color.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Atmosphere Density | 0.3 to 0.4 | |
| Atmosphere Offset | 0 | creator dislikes other values |
| Texture IDs to randomize | 3 or 4 similar | from a texture pack |
| Other values | not stated | brightness, bloom, sun rays, contrast said qualitatively only |

## Prompts and skills used
No AI prompts. Mentions lighting presets possibly in description; toolbox skybox search.

## Gotchas and fixes
- Highlight on players must be configured so it does not show through walls.
- Atmosphere looks confusing at first; keep density low and offset 0.
- Too much haze looks foggy; use a small amount.

## Use it in our games
- Atmosphere Density 0.3 to 0.4 with Offset 0 as a safe starting point for cartoony maps.
- Randomized texture and color-variation script makes repeated simulator tiles or plots feel less cloned.
- Highlight on the player (or on stolen items) could mark targets in steal-style games (inferred).
- Raise contrast and saturation in ColorCorrection to keep bright simulator maps crisp.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Light a Low Poly Map (Roblox Studio)]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to Model a Low Poly Roblox Pet (Blender Tutorial)]] · [[How to make AMAZING Low Poly Roblox Models]] · [[How to make CARTOON LIGHTING in Roblox Studio]] · [[LOW-POLY TERRAIN TUTORIAL ROBLOX+BLENDER]]
<!-- related:end -->
