---
tags: [roblox, video-notes, 3d-blender]
source: https://www.youtube.com/watch?v=RNLhnvXRylo
creator: "MrWonderHow"
video_id: "RNLhnvXRylo"
---
# I Built a Roblox Vehicle Combat Builder Game Using Claude Opus 4.8 MCP + Roblox Studio AI

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Full pipeline for a modular vehicle builder/combat prototype: ChatGPT concept art, Meshy (via "Mesh AI") image-to-3D with remesh, Blender cleanup, attachment-point folders in Studio, then Claude Opus 4.8 via Roblox Studio MCP builds the GUI, driving, combat, AI enemies, and effects in three phases.

## Tools and setup
- ChatGPT: concept art (multi-view low poly drawings).
- Mesh AI / Meshy 6 (latest model at the time): image-to-3D with multiple views, texture, remesh (fixed or adaptive; creator prefers adaptive).
- Blender: edit mode cleanup, FBX export.
- Roblox Studio and Roblox Studio MCP (config copied from Studio AI Assistant if not already in Claude Desktop settings > Developer tab).
- Claude Desktop, Claude Opus 4.8, a Claude project named "Vehicle Combat Builder" with a game design document.
- Asset Manager (bulk import preview images), free VFX packs from the toolbox (muzzle flashes, rockets, explosions).

## Step-by-step
1. [00:06] Concept: modular vehicle = chassis + turret on top + wheels.
2. [00:06] ChatGPT designs: chassis multi-view (no wheels), F1 variant (white/red), military variant; wheel designs (F1, off-road, chain); turret ideas (machine gun, dual rocket, railgun). Ask for clean multi-view drawings for easier modelling. Recolor if boring (rocket turret blue, railgun changed to red).
3. [02:08] Mesh AI: workspace > prepare four reference images with the main image first > Standard model type > Meshy 6 > enable multiple views and upload the rest > Generate.
4. [03:09] Click Texture. Initial results are very high poly (chassis about 400,000 triangles). Click Remesh, choose adaptive: about 6,000 triangles. Download FBX.
5. [03:09] Blender: import, Tab into edit mode, select any vertex on an unwanted wheel ring, hover and press L to select the linked mesh, X to delete. Repeat. Back to object mode. (F1 chassis also had four side mirrors to remove.)
6. [04:12] Export FBX: path mode Copy, embed textures on, selected objects on, scale 0.01.
7. [04:12] Generate remaining parts in Meshy. Turrets need no rig; rotate them in Studio.
8. [05:12] Studio: import one chassis, scale up, import a wheel, place it, duplicate three times. Import and place a turret.
9. [05:12] Attachment points: inside each chassis model make a "wheel points" folder with attachments (e.g. front left, etc.) positioned at wheel locations, and a turret folder with an attachment named "main turret". Repeat for each chassis.
10. [07:15] Final structure: Chassis folder (each with wheel points and turret points), Wheels folder, Turrets folder. Attachments are children of the chassis so they move with it.
11. [07:15] Connect MCP: Claude Desktop > settings > Developer tab shows the Roblox Studio MCP server; if absent, copy config from Studio AI Assistant into Claude's MCP config.
12. [08:28] Create the Claude project, add a game design doc with structure, objectives, and three phases. Verify connection.
13. [08:28] Phase 1: bulk import preview images in Asset Manager, copy all content IDs into Claude. Claude builds a selection GUI (chassis, wheel, turret selectors plus Spawn Vehicle). Vehicles assemble via attachment points.
14. [09:29] Phase 2: Claude adds VehicleSeat and driving. Report issues (launching into the air on collision, wheels not rotating, seat too high). Claude adds motor wheel rotation, suspension/physics, fixes seat position.
15. [10:29] Phase 3: dummy targets with HP bars, mouse-aimed turret rotation, projectiles, impact effects, per-turret fire rate, projectile type, damage. Fix vertical flip/stuck at high speed by reporting it.
16. [10:29] VFX: in each turret model create fire VFX, hit VFX, bullet VFX folders, fill with muzzle flashes, rocket models, explosions, positioned by attachments; Claude integrates them. Tame homing that is too aggressive.
17. [12:30] Polish: vehicle spawn effect, enemy AI vehicles following racetrack waypoints and engaging the player, buildings and trees, building colors, floating damage numbers, kill counter UI, crosshair colors, sound effects.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Meshy model | Meshy 6 | Standard model type, multiple views on |
| Raw chassis triangles | about 400,000 | Too high for Roblox |
| After adaptive remesh | about 6,000 triangles | "Perfectly acceptable for Roblox" |
| Reference images per chassis | 4 | Main image first |
| FBX path mode | Copy | |
| FBX embed textures | On | |
| FBX selected objects | On | |
| FBX scale | 0.01 | |
| Claude model | Opus 4.8 | |

## Prompts and skills used
- ChatGPT: "Draw for me a car shooter chassis in multiple views, no wheels, just chassis. Make it clear low poly without details, just multiple views."
- "Nice, draw for me another variant with different style like F1 for example."
- "Nice, now I want to make wheel. Let's design a wheel."
- "Okay, now I need suggestions for turret styles so I can put them on top and a machine gun or a rocket launcher would be okay, too."
- Claude prompts were not quoted; he reports problems in plain language and Claude fixes them.

## Gotchas and fixes
- Meshy added four wheel rings on a wheel-less chassis: delete with L-select and X in Blender.
- F1 chassis got four mirrors: removed in Blender.
- Machine gun turret icon missed in import left a blank GUI slot.
- Vehicle launched on collision, wheels static, seat too high: Claude added motors, suspension, fixed seat.
- Vehicle flipping vertically and stuck at high speed: fixed after report.
- Homing rockets too aggressive: later improved.

## Use it in our games
- Use attachment-point folders and a modular assembly (inferred) for pets/brainrot accessories: body + hat + aura attach to named attachments.
- Meshy image-to-3D then adaptive remesh to about 6k tris for steal-game characters (inferred).
- Keep a game design doc with phases in a Claude project so each prompt phase stays on scope.
- Asset Manager bulk import plus pasting IDs into Claude to auto-build a selection or shop GUI (inferred for our Store UI).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[04 Building, Maps & 3D Models]]
- More in 3D and Blender: [[How To Connect Claude To Blender (Blender MCP Setup)]] · [[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]]
<!-- related:end -->
