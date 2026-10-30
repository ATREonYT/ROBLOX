---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=_PlYzgQyco8
creator: "Vadez"
video_id: "_PlYzgQyco8"
---
# LOW-POLY TERRAIN TUTORIAL [ROBLOX+BLENDER]

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Make a low-poly terrain chunk in Blender as two meshes (a rock "main" piece and a thinner "grass" cap), export each as FBX/OBJ, and stack them as two MeshParts in Studio. Cheap on lag, and you can build a whole map from MeshParts alone.

## Tools and setup
- Blender (default scene; delete cube, light, camera first).
- Roblox Studio on a blank baseplate; Insert Object > MeshPart.
- Export format: FBX or OBJ.
- Creator prefers MeshParts over Unions because a MeshPart can be scaled non-proportionally (left/right/up/down) while a Union scales on all sides.

## Step-by-step
1. [00:01] Open Blender, delete the cube, light and camera.
2. [00:01] Shift+A > Mesh > Plane.
3. [00:01] Tab into Edit Mode; hover near an edge and press Ctrl+R to add an edge loop (click once to position, click again to set). Repeat until the plane is divided as wanted. More subdivisions = more polys in the final mesh.
4. [01:01] With the Move tool, move vertices to shape the terrain piece. Avoid very inverted angles; they cause weird collision holes.
5. [01:01] Press A (select all), then E to extrude the plane down to the wanted depth. Press S to scale the selection (hold Shift for finer scale). Repeat E then S a couple more times until the shape is right.
6. [01:01] Press A, then Ctrl+N to recalculate outside normals. This is the "main" piece of the two-part mesh.
7. [01:01] File > Export > FBX or OBJ. Name it e.g. "mountain terrain" plus a number (so you can tell pieces apart).
8. [02:02] Grass piece: move the camera to look from below so the top stays flat, press B (border select), box-select all bottom points, press X to delete them.
9. [02:02] Press A, E to extrude, then S to scale down. Do this only once.
10. [02:02] Press A, Ctrl+N (flip/recalculate normals), then export again as FBX/OBJ. Name it the same as piece one with "G" appended to mark grass.
11. [02:02] In Studio: right click > Insert Object > MeshPart. Ctrl+D to duplicate it.
12. [03:02] Select one MeshPart > Properties > click the folder icon next to MeshId > open the mountain file. Click "No" on the import prompts and wait for the mesh to appear.
13. [03:02] On the other MeshPart do the same with the grass file (again click "No" on prompts).
14. [03:02] Scale/position the grass part so it sits on top of the mountain part.
15. [03:02] Name them "Grass" and the other for the rock; make sure both are Anchored.
16. [03:02] Color them: grass part green with Grass material; rock part a stony color/material.
17. [03:02] Select both and group them (name the model e.g. "Terrain"; the creator forgot to).
18. [04:03] Repeat with more shapes to build a scene purely from these MeshParts (the rest of the video is a timelapse).

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Blender shortcut: new mesh | Shift+A > Mesh > Plane | |
| Edge loop | Ctrl+R | click to place, click again to set |
| Extrude | E | |
| Scale | S (Shift for finer) | |
| Recalculate normals | Ctrl+N | do before every export |
| Delete bottom verts | B then X | for grass piece |
| Export formats | FBX or OBJ | |
| Studio Anchored | true | both parts |
| Grass part material/color | Grass, green | |
| Poly count / sizes | None stated in the video. | |

## Prompts and skills used
None. Shout-out to "IB main index registers" for tips (name as heard).

## Gotchas and fixes
- Very inverted angles create collision holes: keep the shape gently sloped.
- Studio shows import prompts when loading the mesh: click "No" each time.
- Normals must be recalculated/outward, otherwise mesh faces render wrong (inferred from why he does Ctrl+N each time).
- Grass piece only needs a single extrude-and-scale step.

## Use it in our games
- Build cartoony simulator islands/hills from a handful of reusable low-poly rock + grass MeshPart pairs, scaled non-uniformly to vary them (inferred).
- Use the two-part split (rock body + grass cap) so each piece can have its own material/color for stylized look (inferred).
- Keep poly count low by using few edge loops; good for steal-style maps with many players and many spawned items (inferred).
- Name and group terrain models (e.g. "Terrain") from the start so level layouts stay organised (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Light a Low Poly Map (Roblox Studio)]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to Model a Low Poly Roblox Pet (Blender Tutorial)]] · [[How to make AMAZING Low Poly Roblox Models]] · [[How to make CARTOON LIGHTING in Roblox Studio]] · [[Make Your Roblox Game Look 10x Better With Lighting]]
<!-- related:end -->
