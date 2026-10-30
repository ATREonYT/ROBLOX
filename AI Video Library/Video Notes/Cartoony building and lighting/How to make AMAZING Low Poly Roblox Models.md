---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=HCdEbF0f02A
creator: "Gamer M8"
video_id: "HCdEbF0f02A"
---
# How to make AMAZING Low Poly Roblox Models

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Beginner Blender walkthrough for a low poly asset pack: rock (icosphere), grass (cones joined), terrain chunk (two cylinders with loop cuts) and tree (cylinder trunk plus stacked cones). Export OBJ or FBX and import via Roblox Studio Import 3D, anchored.

## Tools and setup
- Blender (shortcuts: Shift+A add, Tab edit mode, S scale, R rotate, Shift+D duplicate, Ctrl+J join, Ctrl+R loop cut, Ctrl+B bevel, Alt+click edge loop, numpad 1 side view).
- Roblox Studio, Import 3D (Avatar/Home tab).
- Export format: OBJ or FBX (OBJ for rock; FBX needed for terrain/tree so top and bottom can be colored separately).

## Step-by-step
1. [00:00] Rock: Shift+A, Mesh, Ico Sphere; set subdivisions to 1. Scale on Y to make it wider, then on X.
2. [00:00] Tab into edit mode (vertex mode), delete the bottom vertex. Switch to edge mode, Alt+click a bottom edge loop, press F to fill for a flat bottom.
3. [00:00] Back to vertex mode, move points to shape the rock. Tab out.
4. [01:01] File, Export, Wavefront OBJ (or FBX), name it, export.
5. [01:01] In Studio: Import 3D, pick file, enable Anchored, Import. Then recolor.
6. [01:01] Grass: Add Cone, vertices 3, scale smaller, in edit mode move the top vertex up.
7. [02:03] Shift+D duplicate blades, move, scale smaller, rotate; vary them and tweak top points. Select all blades and Ctrl+J to join into one object. Export and import the same way.
8. [03:04] Terrain: Add Cylinder, vertices about 8. Numpad 1 side view, scale on Z (S Z) to height.
9. [03:04] Edit mode, Ctrl+R loop cut with 3 cuts. Edge mode, Alt+click top loops and scale, middle loop bigger.
10. [04:05] Add a second cylinder (8 vertices), bigger than first, then scale Z to shorter. Select top loop and bevel (Ctrl+B) for a rounded top. In vertex mode, select bottom vertices and pull them down for a grass-overhang look. Optional extra loop cut in the middle, scaled slightly out.
11. [05:06] Export as FBX (so top and bottom can be colored separately), import in Studio with Anchored. Creator notes it came out massive.
12. [05:06] Tree: Add Cylinder, 8 vertices, side view, scale to trunk height. Ctrl+R loop cuts (3), scale middle thinner, top thinner, bottom a bit bigger.
13. [06:07] Add Cone (8 vertices) for foliage, scale and Z-scale; Shift+D to stack smaller cones upward. In edge/vertex mode drag points down for droopy branch tips.
14. [07:08] Export FBX and import with Anchored.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Ico sphere subdivisions | 1 | rock |
| Grass cone vertices | 3 | blade |
| Terrain cylinder vertices | about 8 | |
| Terrain loop cuts | 3 | Ctrl+R |
| Tree trunk cylinder vertices | 8 | |
| Tree trunk loop cuts | 3 | |
| Foliage cone vertices | 8 | |
| Studio import option | Anchored on | |

## Prompts and skills used
- None (no AI). Tools only: Blender, Roblox Studio Import 3D.

## Gotchas and fixes
- Use FBX (not OBJ) if you want separate color parts like terrain top and bottom.
- Imported terrain came in very large; scale in Studio.
- Enable Anchored on import so assets do not fall.
- Alt+click an edge loop to select the whole loop; press F to fill holes.

## Use it in our games
- Build a small reusable cartoony prop pack (rocks, grass, trees, ground chunks) with 8-vertex cylinders and 3-vertex cones for cheap, consistent map decoration.
- Import with Anchored on and recolor in Studio so one mesh serves many biome colors (inferred).
- Use the low vertex counts as a mesh budget for map filler in simulators with many repeated props (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Light a Low Poly Map (Roblox Studio)]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to Model a Low Poly Roblox Pet (Blender Tutorial)]] · [[How to make CARTOON LIGHTING in Roblox Studio]] · [[LOW-POLY TERRAIN TUTORIAL ROBLOX+BLENDER]] · [[Make Your Roblox Game Look 10x Better With Lighting]]
<!-- related:end -->
