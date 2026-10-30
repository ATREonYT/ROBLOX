---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=e0sG3Qj3uG0
creator: "Sayzz"
video_id: "e0sG3Qj3uG0"
---
# How to Model a Low Poly Roblox Pet (Blender Tutorial)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Short Blender tutorial for a cute low poly dog pet built from a beveled cube, duplicated parts, then UV-mapped to a color texture. The transcript is sparse (mostly captions of narration over visuals), so many specifics are not stated.

## Tools and setup
- Blender; Bevel modifier; UV Editing workspace; a color texture map (palette-style) applied to UVs.

## Step-by-step
1. [00:00] Start with a simple cube. Add a Bevel modifier right away for smooth rounded edges; adjust segments and offset to get the body shape.
2. [00:00] Paws: duplicate the body mesh and scale it down. Select the bottom of the paw and scale it up for a foot shape. Add a loop cut in the middle for detail.
3. [00:00] Tail: add another cube, pull out faces (extrude), rotate them to make a wagging curve.
4. [01:07] Apply the bevel modifier to keep the low poly style.
5. [01:07] Ears: rotate parts (rotation shortcut mentioned). Finish modeling, then apply all modifiers.
6. [02:14] Go to UV editing and generate the map. Add an outline to the texture and smooth the mesh edges for a cleaner look.
7. [02:14] Coloring: apply the texture to all other parts (paws, tail, ears) and scale the UVs onto different color sections of the texture so parts are not identical in color.

## Exact settings and values
None stated in the video.

## Prompts and skills used
- None.

## Gotchas and fixes
- Apply all modifiers before UV unwrapping.
- Scale UV islands onto different color areas of the texture so parts differ in color.
- Transcript is incomplete (captions broken/duplicated), so exact bevel numbers and UV steps are missing.

## Use it in our games
- Pet pipeline for simulators: bevel cube body, duplicated limbs, one small palette texture; recolor variants by moving UVs to other palette cells (inferred).
- A single shared palette texture keeps many pets in one material and cheap to render (inferred).
- Good basis for pet rarities by swapping UV color regions instead of making new textures (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Light a Low Poly Map (Roblox Studio)]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to make AMAZING Low Poly Roblox Models]] · [[How to make CARTOON LIGHTING in Roblox Studio]] · [[LOW-POLY TERRAIN TUTORIAL ROBLOX+BLENDER]] · [[Make Your Roblox Game Look 10x Better With Lighting]]
<!-- related:end -->
