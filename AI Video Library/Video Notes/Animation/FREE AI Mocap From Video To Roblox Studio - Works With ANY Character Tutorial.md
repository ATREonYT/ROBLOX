---
tags: [roblox, video-notes, animation]
source: https://www.youtube.com/watch?v=Ypz0X6dhNQo
creator: "Marionette Mocap"
video_id: "Ypz0X6dhNQo"
---
# FREE AI Mocap From Video To Roblox Studio - Works With ANY Character Tutorial

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Turn a phone video into a Roblox animation: generate and clean the motion in Marionette, retarget onto any rig in Blender with the free Marionette plugin and live link, export FBX, then import into Roblox Studio and the Animation Editor.

## Tools and setup
- Marionette (suitless AI mocap from video; free version with unlimited free renders).
- Blender with the free Marionette Blender plugin (live link to Marionette).
- Roblox Studio: Import 3D tool, Avatar tab > Animation, Animation Editor.
- A phone video as the input. Works with any rig.
- Marionette YouTube channel has in-depth tutorials (advanced cleanup, full Blender plugin guide); Discord for updates.

## Step-by-step
1. [00:00] In Marionette, import the video and calibrate it.
2. [00:00] Drag the clip onto the timeline and run the automatic clean motion process. Optionally clean and edit manually here.
3. [00:00] In Blender with the Marionette plugin: select a controller on your character's rig, then pick the matching bone name in the plugin. Repeat for every controller that should move.
4. [01:00] With both apps open, press Connect. In Marionette choose "show preview in DCC" for a live preview on your character with live edits across both programs.
5. [01:00] When happy, press "copy to DCC". Animation data lands on the rig in Blender with smooth curves and keys, which you can refine in Blender.
6. [02:02] Export FBX from Blender: select both armature and mesh, animation on, scroll to Armature options and disable "Add Leaf Bones", press Export.
7. [02:02] In Roblox Studio, use Import 3D, open the FBX, default import settings, Import. The model may be huge; scale it down.
8. [02:02] To apply the animation: Avatar tab > Animation, click your character rig, then in the Animation Editor open the three-dot menu > Import from FBX and pick the same FBX.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| FBX export: objects | Armature and mesh both selected | |
| FBX export: Animation | On | |
| FBX export: Add Leaf Bones | Off | Under Armature options |
| Roblox import settings | Default | Scale the model down afterward |

## Prompts and skills used
None stated in the video (no AI text prompts). Tools named: Marionette, Marionette Blender plugin, Roblox Import 3D, Animation Editor "Import from FBX".

## Gotchas and fixes
- Imported model comes in very large: scale it down to fit the scene.
- Add Leaf Bones must be disabled or extra bones are added (said as a required export step).

## Use it in our games
- Record phone videos of dance/emote moves for brainrot characters and import them as R15/R6 animations (inferred).
- Use the same FBX-animation import flow for a unique "steal" grab or run animation (inferred).
- Combine with Blender retargeting so one mocap clip works across several character rigs in a simulator (inferred).
- Free tier with unlimited renders means cheap iteration on emotes for a +1 reward animation (inferred).
