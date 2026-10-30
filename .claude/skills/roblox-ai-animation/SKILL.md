---
name: roblox-ai-animation
description: Use when making character animations for a Roblox game (punch, slap, grab, carry, kick, emote, idle, celebration) with Claude, Blender or mocap, or when an animation looks stiff, slides, overrides walking or doesn't play in the live game. Gives timing values, pose structure, rig gotchas and the reference-video workflow from the AI Video Library transcripts.
---

# AI-made Roblox animations

Sources: `AI Video Library/Video Notes/Animation/` (SyphoDev R6+R15 skill, fwjelaa animation skill, Marionette mocap),
plus `VFX/` notes for animation markers. Repo rule: animations from the owner's files are raw KeyframeSequences;
see `CLAUDE.md` (Repo mechanics) for extract, preview and publish.

## 1. Best input: a reference VIDEO
- Give a short MP4 of the move (recorded on a phone or found online). fwjelaa: a video beat images by a lot.
- No video? Describe the move in one line with its length ("a half second punch") and the rig (R6 or R15).
- Keep old versions aside instead of deleting them, so the owner can compare in game.

## 2. Timing and poses
- Combat and grab moves: **0.33-0.7 s** (0.5 s is a good default). 1.5 s feels slow.
- 5 poses per hit: **idle, anticipation, contact, follow-through, recovery**.
- Idles and carry poses: animate **arms and torso only**, so the default walk still moves the legs.
  An idle with animated legs has higher priority and makes the character slide.
- Planted foot sliding: rotate the whole body so the hips turn over the planted foot.
- Walk cycles: last frame must match the first, or it won't loop.

## 3. Rigs
- R15: 15 joints (elbows, wrists, knees, ankles, waist). R6: 6 joints, no elbows or knees, so it's stiffer and big moves clip.
- Blender rigs: set the IK/FK switches to 0 (FK) or the FK bones look dead.
- Blender restores the rest pose on render, so trust the rendered images over the numbers. Always look at the preview frames.
- Roblox ignores Blender root motion: move the character by script.
- Mocap (Marionette): FBX export with armature + mesh selected, Animation on, **Add Leaf Bones off**. Scale down after import.

## 4. Hook effects to the animation
- Put named **animation event markers** at the contact frame and fire VFX, sounds and +1 popups from the marker, never from timers.
- When you shorten an animation, move its markers with the keyframes. Marker names must match the code exactly.
- Effects that follow a character are welded to HumanoidRootPart.

## 5. Shipping
- Test-uploaded animations don't play in the live game: they need publishing on the owner's account.
  Never invent animation IDs; leave them empty and add them to the owner's checklist.
- After each fix the owner asks for, write it into this skill so it isn't repeated.
- Budget: about 3 min per simple move with a good skill, 10-30 min per set.
