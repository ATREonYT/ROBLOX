---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=4ojmHWn_rxY
creator: "Developer Dank"
video_id: "4ojmHWn_rxY"
---
# How to make Roblox Games Using Claude

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Build a "plus one" (+1 speed) game with Claude Code in small, separate requests instead of one giant prompt. Give it a reference screenshot for UI, ask it for feature ideas, and let it model simple props in Blender. Three short requests produced a full game using about 13% of the session limit.

## Tools and setup
- Claude Pro (the basic plan does not allow Claude Code). Codex is mentioned as an alternative but the video is Claude-only.
- Claude Code connected to Roblox Studio through its MCP (the creator says to search YouTube/TikTok for how to connect it).
- A free Roblox vector icon set (search Google for "free Roblox vector set"), downloaded and given to Claude as a file. Claude's memory can keep the icon set from another project.
- A reference screenshot taken inside an existing "plus one" Roblox game (the creator joined one called pebble jumps).
- Blender (installed; the creator did NOT install a Blender MCP and it still worked by asking Claude to model in Blender).
- Sponsor: ForgeGUI, a site for Roblox dev assets (icons, previews, code, sound, GUI) with its own MCP that connects to Claude or Codex.
- Roblox developer products (must be plugged in manually for the shop buttons to work).

## Step-by-step
1. [00:00] Get Claude Pro, pick an idea (here a "plus one" game), and connect Claude Code to Roblox Studio via MCP.
2. [01:00] Do NOT build the game in one query. Send a very short first prompt for the core mechanic (speed +1 per step, shown on screen). It took about 30 seconds and 1% of the limit.
3. [02:01] Search "plus one" in Roblox, join a good one, screenshot its UI, and give the screenshot to Claude with the UI prompt below. Ask for a level system and developer products at the same time.
4. [02:30] While Claude builds (about 4 minutes), note it pulls icons from your uploaded icon set (scroll icon, Roblox screen icon).
5. [03:01] Test: buttons all work. Balance the numbers yourself and plug in your developer products. Two requests used 5% of the 5-hour limit.
6. [03:30] Ask the AI for ideas for your current system (it has context of all scripts and the game). It suggested timed races.
7. [04:01] Build the race system (races every 2-3 minutes on a long straight track, speed decides distance before the timer ends, distance gives wins as a second currency). Put the UI at the bottom. Restart and test; races start by themselves.
8. [05:01] Total after three requests: 13% of the limit.
9. [06:02] Ask Claude to model a low-poly treadmill in Blender, import the model (resize, place, color it), then ask Claude to make treadmills add speed and color them. It made extra tracks unasked. Used 22% total.
10. [06:50] Join the game and run on the treadmill to verify the speed boost.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| First request cost | about 30 s, 1% of limit | Core +1 speed mechanic |
| UI request | about 4 min, 2 requests = 5% of the 5-hour usage | Includes levels and dev products |
| Race system | races every 2-3 minutes | Speed sets distance; distance gives wins |
| After race system | 13% of limit | Three requests total |
| After treadmill | 22% of limit | Blender model plus speed pads |
| Test speed | 10 thousand speed (bought) | Player was "super fast" in the test |

## Prompts and skills used
- Core mechanic (as said, the exact first prompt text is not captured by the captions): make it so every step gives +1 to speed and it is displayed on the screen.
- UI: "Make the interface exactly like this, but instead of skill, let there be speed. Also set up a level system and add products for developers." (with the reference screenshot attached)
- Ideas: asked the AI for ideas to play with the current system (it proposed timed races).
- Race: create a racing system with the interface at the bottom.
- 3D: "model a low-polygon treadmill in Blender", then make the treadmills add speed and color them.
- Links: ForgeGUI (link in the description of the video); free Roblox vector icon set (Google it).

## Gotchas and fixes
- Do not let AI do everything in one query; use it as a tool.
- AI is not good at architecture and interfaces yet, so always give references (screenshots, icon sets).
- Dev product buttons only work after you plug in real developer products.
- Numbers need manual balancing afterward.
- Race and Blender steps use noticeably more of the session limit (13% and 22% cumulative).

## Use it in our games
- Use the exact flow for +1 games: one tiny prompt for the "+1 speed per second/step" core, then a separate UI prompt with a reference screenshot of a top +1 game.
- Keep an icon set file in the project so Claude reuses a consistent look for every UI (inferred).
- Ask Claude for system ideas such as timed races with a second currency; a similar timed event could be added to steal-style games (inferred).
- Have Claude model simple low-poly pads or props in Blender (treadmills = speed pads) and then wire the gameplay effect in a second prompt.
- Budget usage by splitting requests: short mechanic prompts are cheap, UI and Blender prompts cost more.
