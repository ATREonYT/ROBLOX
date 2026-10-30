---
tags: [roblox, video-notes, animation]
source: https://www.youtube.com/watch?v=dlx_kf6jT08
creator: "SyphoDev"
video_id: "dlx_kf6jT08"
---
# How to Make Roblox Animations With AI (R6 + R15, Claude Opus 5.5)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Claude Code drives Blender in the background using a free "Roblox animation skill": it writes animation as joint-angle data (forward kinematics), renders frames, checks them, and builds the result into Studio through the MCP. A punch took about 3 minutes from one sentence.

## Tools and setup
- Claude Code (separate tutorial linked in the video).
- Blender (free; never opened manually, AI runs it).
- Free Roblox animation skill by SyphoDev (GitHub; access via his Discord; re-download, it was updated).
- Free community R15 rig for Blender (linked in description).
- Roblox Studio with Studio MCP enabled.
- Roblox Open Cloud API for uploading animations.
- Paid: his AI Roblox dev course (whole system, how he builds skills, matching moves from a reference).

## Step-by-step
1. [00:00] Install/prepare the five prerequisites above.
2. [01:00] Concept: an animation is poses over time; a punch is five poses (idle, anticipation, contact, follow-through, recovery). Claude writes each pose as a time plus an angle per joint in degrees.
3. [02:00] Blender renders each frame; Claude views the frames instead of trusting the numbers (rest pose gets restored on render and can contradict the data).
4. [02:00] Use FK only (not IK): IK can spin an upper arm 160 degrees in one frame.
5. [03:00] Use a plain gray dummy to judge motion.
6. [03:00] Time it for combat: about a third of a second to 0.7 s (a 1.5 s punch feels floaty).
7. [03:00] First-time rig: ask Claude to calibrate it. Four switches must be set to 0 (they ship as 1 = IK mode, which makes FK bones look dead); then all 12 FK bones work.
8. [04:00] Ask for the move, e.g. a half-second punch. Claude starts from a table of known-good angles, writes the spec and runs a preview pass (about 4 seconds).
9. [04:00] Review frames; fix issues (e.g. roundhouse kick: standing foot slid almost 3/4 of a stud). Claude detects this from per-frame numbers and shifts the body so hips turn over the planted foot.
10. [05:00] Final render as GIF; Claude pulls frames back from the GIF to verify. Punch: ~3 minutes total; kick: just over a minute in two passes.
11. [05:00] Before Studio, the skill checks Roblox poses each body part exactly as Blender did (caught a mirrored arm-twist bug).
12. [06:00] Claude writes a script and runs it in Studio via MCP; one animation per move; verifies each plays at its made length. A tiny key-binding script lets you press a key to play it. No upload needed for tests.
13. [07:01] For publishing, test animations don't work in live games: the skill uploads real animations via Open Cloud API.
14. [07:01] R6: put an R6 character in Studio (ask Claude to spawn a standard R6 dummy via MCP), Claude reads the 6 real joints and builds the 6 parts at real sizes and saves a rig file (one time only).
15. [08:03] Ask for a move (a sword slash). Claude rotates the 6 joints, renders from two angles, checks numbers; first pass clipped through the body, second pass fixed.
16. [09:04] Verify on a normal R6 character: parts matched render to within less than 1/10,000 of a stud. Build via one script through MCP like R15.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Punch poses | 5 | idle, anticipation, contact, follow-through, recovery |
| Combat move length | about 0.33 s to 0.7 s | 1.5 s feels slow; example used 0.5 s |
| IK/FK switches | 4 switches set to 0 | default 1 = IK mode |
| FK bones | 12 | become usable |
| Preview pass | about 4 seconds | |
| Punch total time | about 3 minutes | |
| Kick | just over a minute, 2 passes | standing foot slid almost 0.75 stud on pass 1 |
| IK failure example | upper arm spins 160 degrees | in one frame |
| R15 joints | 15 | elbows, wrists, knees, ankles, waist |
| R6 joints | 6 | no elbows/knees; hips on outside corners of the torso |
| Position match R6 | < 0.0001 stud | |

## Prompts and skills used
- "Calibrate" the rig; "a half second punch"; "a roundhouse kick"; "a sword slash style attack"; "spawn a standard R6 dummy through the MCP".
- Skill: SyphoDev's free Roblox animation skill (GitHub, Discord). Tell Claude what is wrong, then ask it to remember the fix so it improves over time.

## Gotchas and fixes
- Blender restores the rest pose on render, so numbers and images can disagree: check the images.
- IK/FK switches at 1 make FK bones look dead: set to 0.
- Planted foot sliding: move whole body so hips turn over the planted foot.
- Fighting stance idle with animated legs overrides the walk (higher priority) so the character slides: animate only arms and torso and let default walk move legs.
- Test animations don't work in live games: upload via Open Cloud.
- R6 is stiffer by nature; big R6 moves can clip through the body, weapon grips need extra passes.
- Always view the preview and tell Claude what is wrong.

## Use it in our games
- Generate simple pose-data animations (punch, wave, slap) for sim characters without the animation editor (inferred).
- Keep grab/steal animations short (about 0.33 to 0.7 s) so they feel snappy in steal-style games (inferred).
- Animate only upper body for carrying/holding idles so default walk still works with brainrot carry poses (inferred).
- Ask Claude to save every fix to the skill so quality compounds over time (as stated).
