---
tags: [roblox, video-notes, animation]
source: https://www.youtube.com/watch?v=QWRjV_7u-XE
creator: "fwjelaa"
video_id: "QWRjV_7u-XE"
---
# How to Make Animations in Roblox with AI (Claude Opus 5.5 + FREE ANIMATION SKILL)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Claude can make R15/R6 combat animations straight into Studio over MCP. The biggest quality jump comes from giving it a **reference video (MP4)** of the moves rather than images, and from telling it to use Blender. The creator's free animation skill (from his Discord) adds structure and progress reporting, but a good reference video alone already gave usable results.

## Tools and setup
- Claude (Opus 5.5 per the title) with the **Roblox Studio MCP** server connected
- **Blender MCP** (installed via terminal; the skill's manual covers it)
- Creator's "Roblox animation" skill pack, shared free on his Discord (took him about 21 hours to make). It includes a sample animation pack: flurry punches, blocks, lunges, side lunges, falls, impact punches, idles, punches, sword and spear sets, in R15 and R6 versions
- A reference MP4 of real moves (he used a taekwondo M1 strikes clip)

## Step-by-step
1. [04:02] Create a new experience in Studio and **publish it first** (File > Publish, "Create"). Studio exits and reloads after publishing.
2. [04:02] Game Settings > Security: turn on **Allow HTTP Requests** and **Enable Studio Access to API Services**. Save.
3. [05:03] Confirm the MCP server shows connected and open.
4. [04:02] Prompt Claude with the MP4 path: make M1 taekwondo animations, do it in my open Roblox Studio so I can test right away.
5. [05:03] Add an instruction to **always use Blender for animations, models, etc.**
6. [06:03] Run 1 (no skill): Claude studied the video, built its own R15 pose-modification module in Studio, and made 4 M1 strikes plus a hit reaction and a test dummy. It took about half an hour.
7. [08:04] Result: low roundhouse with the right leg, a jumping backflip, a spinning jump kick, and a receiver hit reaction. It looked good.
8. [09:04] Run 2 (with the skill): "don't remove the current M1 animations, just put them aside; replace the M1s using the desktop video …; R15 or R6, choose for yourself; make it look clean, realistic and beautiful", with the skill attached.
9. [10:04] With the skill, Claude unpacked the kick animations, broke the clip into frames, drafted poses in Blender, checked every shot, and reported progress as a table. Two training dummies were placed for testing; damage and hit animations worked.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Allow HTTP Requests | On | Game Settings > Security |
| Enable Studio Access to API Services | On | Game Settings > Security |
| Time, new animation set without the skill | about 30 min | creator's estimate |
| Time with the skill | about 10 min per M1 animation | creator's estimate |
| Skill creation time | about 21 hours | creator's own skill |

## Prompts and skills used
- First run (paraphrased from the video): "I want you to do some cool taekwondo M1 animations so I can test them right away. I have provided you with an MP4 file. Please do it in my Roblox Studio. It is open now." Plus: "Always use Blender for animations, models, etc."
- Second run: "Don't remove the current M1 animations, just put them aside. Replace the M1 animations with the desktop video called 'show off all your taekwondo skills'. Do everything you can to make them better than they are now. R15 or R6 style, choose for yourself. Make it look clean, realistic and beautiful. I will give you a skill to use."
- Skill: the creator's "Roblox animations" skill (Discord, free; he asks for credit if you publish its output). It includes a manual covering Blender MCP install.

## Gotchas and fixes
- Publish the place before working, or the API and MCP features may not work (inferred from his "publish first" step).
- Images make worse references than a **video**. He was surprised how good the video-only result was.
- Without the skill Claude gives fewer progress updates. The skill makes it report what it's doing.
- In run 2 the M1 itself still looked off to him, though the other kicks were good. Expect to iterate per move.

## Use it in our games
- Record or find a short MP4 of each move (punch, slap, steal-grab, celebration) and give it to Claude as the reference instead of describing the motion.
- For steal-style games: make a "grab and run" carry animation and a hit-reaction from one reference clip, and test on two dummies like he did (inferred).
- Keep old animations aside instead of deleting them ("put them aside") so you can A/B them in-game.
- Budget about 10 to 30 minutes of Claude time per new animation set when planning a +1 game's combat or emote pass.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[06 Animation]]
- More in Animation: [[FREE AI Mocap From Video To Roblox Studio - Works With ANY Character Tutorial]] · [[How to Make Roblox Animations With AI (R6 + R15, Claude Opus 5.5)]]
<!-- related:end -->
