---
tags: [roblox, video-notes, vfx]
source: https://www.youtube.com/watch?v=Pcz9I2TFmL0
creator: "MrWonderHow"
video_id: "Pcz9I2TFmL0"
---
# How I Made Anime Dragon Skill in Roblox Studio Using Claude MCP

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Breakdown of a Demon Slayer water dragon skill: custom face decal, sword Tool with Grip Editor, an AI-generated R15 combo animation with markers, a welded dragon head rig with a water trail, slam VFX from a toolbox kit, and Claude-written scripts for the player and the NPC.

## Tools and setup
- Roblox Studio with the MCP server enabled (galaxy icon, MCP server settings); also works with Claude, Cursor, Codex, Antigravity.
- Toolbox assets: R15 Tanjiro character (first result), "Demon Slayer Kit" (first result; sword, dragon, VFX), Muzan NPC (R6 version), a water trail texture asset.
- Grip Editor Tool plugin (free in the toolbox).
- Image editor (name lost in captions) with alpha channel, eraser, lasso, magic wand; ChatGPT for the original face image.
- Roblox Asset Manager, bulk import.

## Step-by-step
1. [00:00] Put the Tanjiro character into the workspace.
2. [00:30] Custom face: open Asset Manager images folder. Use a square 512x512 PNG, face scaled smaller and centered, keeping only eyes, nose, mouth. For a JPG: right-click layer, add alpha channel, then erase (lasso then Backspace; magic wand for big same-color areas). Export as PNG, never JPG.
3. [02:07] Bulk import the PNG, drag it onto the character's face. Works only with classic heads, not dynamic heads. Remove the old face decal; change head skin color to a yellow tone if the skin looks too white.
4. [03:07] Sword: copy it from the Demon Slayer Kit, add a Tool to the character, paste the sword in, move the Handle directly under the Tool, delete the empty model.
5. [04:10] Plugins tab, enable Grip Editor, select the Tool, and rotate/move the sword to the hand in the virtual preview.
6. [05:10] Enable the MCP server, open Claude, test the connection, then ask for the combat animation (prompt below).
7. [06:11] Speed up the animation by selecting all keyframes and dragging shorter, moving animation events with them. Right-click to add events: one when the slam begins, one named "finisher hit" when the dragon touches the ground.
8. [06:40] Dragon: from the kit take "constant flux dragon" (blue head). Copy into the character near the player.
9. [07:11] Create a MeshPart named "main head". Inside it add WeldConstraints (Part0 = main head, Part1 = each other dragon mesh). Add a Motor6D in HumanoidRootPart: Part0 = HumanoidRootPart, Part1 = Main Head.
10. [08:12] Animate the dragon head in the animation editor alongside the sword. Set Main Head transparency 1 and disable collision.
11. [08:40] Trail: Main Head gets an Attachment, inside it a Trail with the water trail texture ID. Add Attachment2 offset to set width; assign Attachment0 and Attachment1 in the trail.
12. [09:25] Make a "slam VFX" folder in the character: smoke from "mist upwards", water aura, a thunder beam recolored blue, extra thunder and mist.
13. [10:28] Claude writes "dragon anim controller" LocalScript in StarterCharacterScripts: plays the attack on left click, shows/hides dragon mesh and trail, triggers slam VFX on the finisher hit marker, welds VFX to HumanoidRootPart, plays roar sounds, handles cooldown.
14. [10:50] NPC: Muzan (R6), add hit VFX and finisher VFX ("mist twirl"), weld them to its HumanoidRootPart. Claude also writes the NPC combat controller (damage, slam damage, knockback force, execution timing, respawn) and the knockback/execution animations.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Face image size | 512 x 512 px PNG | Square, face small and centered |
| Face format | PNG only | JPG shows black background in Studio |
| Trail lifetime | 0.5 | Larger = longer trail |
| Trail MinLength | 0.1 | |
| Trail MaxLength | 0 | |
| Main Head transparency | 1 | Invisible controller part |
| Main Head collision | disabled | |
| Weld Part0 / Part1 | main head / other meshes | |
| Motor6D | Part0 HumanoidRootPart, Part1 Main Head | In HumanoidRootPart |
| Animation name | Tanjiro flux combo | In prompt |
| Animation markers | slam start, "finisher hit" | |
| Combo | 4 slashes, then spin with 2 full rotations, then falling slam | |

## Prompts and skills used
"Create a Roblox R15 sword combo animation named Tanjiro flux combo. The style should feel inspired by Demon Slayer combat, readable and smooth. The combo includes four slash chains, alternating directions from right to left and left to right. After the fourth slash, the character jumps into a spinning airborne attack with two full body rotations, then finally transitions into a falling vertical sword slam with a finisher hit animation marker on impact."

Claude was also used for the dragon anim controller script, NPC combat controller, and knockback/execution animations (no exact prompts given). Assets: Demon Slayer Kit, Grip Editor Tool, R15 Tanjiro, Muzan R6, water trail texture. Links are in the video description (MCP setup guides, dynamic-to-classic head tutorial).

## Gotchas and fixes
- JPG erase shows gray instead of transparency: add alpha channel; export as PNG or Studio shows black.
- Face stretches if not square, small and centered.
- Custom face decal works only on classic heads.
- Sword position is wrong after attaching: use Grip Editor.
- When shortening an animation, move the animation events with the keyframes.
- Splash VFX on the NPC is too small (to be scaled up later).
- Effects must be welded to HumanoidRootPart to follow the character or NPC.

## Use it in our games
- Use the invisible "main head" controller with Motor6D plus welds to animate a multi-mesh model (pets, brainrot characters) with one rig part (inferred).
- Let Claude generate base R15 animations from a text description with named markers, then trigger VFX and scripts from marker signals.
- Welded mist/aura folders triggered by a marker suit rebirth or purchase bursts in simulators (inferred).
- Trail with Attachment0/1, lifetime 0.5, is a simple speed-trail for +1 speed games (inferred).
