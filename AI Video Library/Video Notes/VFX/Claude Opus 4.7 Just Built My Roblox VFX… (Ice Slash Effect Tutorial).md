---
tags: [roblox, video-notes, vfx]
source: https://www.youtube.com/watch?v=r-714VT-k1U
creator: "MrWonderHow"
video_id: "r-714VT-k1U"
---
# Claude Opus 4.7 Just Built My Roblox VFX… (Ice Slash Effect Tutorial)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Claude (Opus 4.7) generates an animated ice slash mesh and 16-frame texture sequence in Blender via MCP, then wires it into Roblox Studio via MCP as an animated-texture mesh on a sword swing. Add particles, sound, hitboxes, a freeze mechanic and bloom through iterative prompting.

## Tools and setup
- Claude app with model Opus 4.7.
- Blender MCP (connected and verified first).
- Roblox Studio with its MCP server enabled (a new feature); Claude connected to the project.
- Export formats: OBJ and FBX meshes, 16 PNG frames, a 4x4 flipbook, the .blend file.
- Roblox: Asset Manager (import textures), Home tab mesh import (manual), a dummy character and a water sword.

## Step-by-step
1. [00:07] Connect Blender MCP, set the model to Opus 4.7.
2. [00:30] Prompt Claude to create a slash VFX mesh with animated ice material, exported for Roblox. It makes a curved ribbon mesh with 16 frames at 24 FPS.
3. [01:07] Fix transparency and rendering issues by chatting. Claude renders the whole sequence. Uploading to the sandbox was slow, so tell it to export directly to the desktop.
4. [01:30] Create a new Roblox project, add a dummy and a water sword, enable the Studio MCP server, connect Claude.
5. [02:07] Asset Manager: import all 16 texture frames. Home tab: import the mesh manually.
6. [02:30] Claude offers flipbook or animated-texture mesh; choose animated textures since you have a mesh.
7. [02:45] Copy all 16 asset IDs and paste them into the frame module Claude created (tedious).
8. [03:00] Ask Claude how to equip the sword; choose dropping it on the ground and picking it up. Swing: no slash at first.
9. [03:08] Remove default particles, debug with Claude, screenshot errors and send them back. Issues fixed one by one: too small, not transparent, no glow, wrong direction.
10. [04:08] Ask for extra ice slash particles; they spawned in one spot, so say "spread it out, move it forward, cover the blade".
11. [04:30] Ask for sound effects, hit detection, enemies, and freeze on hit; pick real physics hitboxes when Claude asks. Enemies freeze for 2 seconds with ice effects.
12. [05:10] Ask for more glow: Claude adds bloom post-processing and raises intensity. Test at night.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Animation | 16 frames at 24 FPS | Ribbon mesh named "splash VFX" in captions |
| Flipbook | 4x4 | 16 frames |
| Freeze duration | 2 seconds | On enemy hit |
| Collision system | real physics hitboxes | Chosen over alternative |
| Setup type | animated texture mesh | Alternative offered: flipbook |
| Post-processing | bloom, intensity increased | No numbers stated |

## Prompts and skills used
- "I want to make a slash VFX for my sword. Create a nice mesh with animated ice / material and export everything so I can use it in Roblox Studio."
- Export fix: asked to export directly to the desktop instead of the sandbox.
- Particles: "Spread it out, move it forward, cover the blade."
- Final challenge: add sound effects, hit detection, enemies, and freeze the enemy when hit.
- Glow: make the slash glow more; add bloom and increase the intensity.
- No named skills or links.

## Gotchas and fixes
- Initial transparency and render problems: fixed by iterating with Claude.
- Sandbox upload was slow: export to desktop.
- Mesh import must be done by hand; 16 asset IDs must be copied manually into the frame module.
- No slash at first: remove default particles, debug, send screenshots of errors.
- Slash was too small, opaque, not glowing, and played in the wrong direction: fixed step by step.
- Particles all spawned in one place: tell Claude to spread and position them.

## Use it in our games
- A 16-frame 24 FPS Blender-rendered ribbon on a mesh is a cheap pattern for weapon swing trails in any melee or steal game (inferred).
- Use "freeze 2 seconds" style status effects for steal-game defense tools (inferred).
- Add bloom (post-processing) as the last step for punchy VFX, then test at night.
- Ask Claude to automate the ID pasting by giving it a module with a table of asset IDs, then fill it once.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[05 VFX]]
- More in VFX: [[Claude MCP + Codex Help me create Roblox Skill Cutscene in Minutes Roblox Studio MCP]] · [[How I Made Anime Dragon Skill in Roblox Studio Using Claude MCP]] · [[How to Make VFX in Roblox with AI (Claude Opus 5.5 + FREE SKILL)]]
<!-- related:end -->
