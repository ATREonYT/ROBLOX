---
tags: [roblox, video-notes, game-design-business]
source: https://www.youtube.com/watch?v=TwCt67pQTe8
creator: "c dev"
video_id: "TwCt67pQTe8"
---
# I Made 4 Roblox Games with AI… Did I Get Rich?

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
A creator made four Roblox games over five months using AI for all the Lua. Results were small: best game Emotion Factory (tycoon, 29k lines of AI code, 87% likes) earned 349 Robux; all four earned 4,167 Robux (about $16) against $225 ad spend (profit about -$209). Lessons: Claude with Studio access works, copycat/low-effort ideas get few visits, and AI-written code breaks in odd ways.

## Tools and setup
- AI coding: Gemini 3 Pro and 3 Flash (weak: no 3D, bad UI, broken code); Claude Pro (big improvement). Claude connects to Roblox Studio, reads and edits scripts, starts playtests, and looks at the screen to verify.
- Blender (armor hand-modeled for Archer Heroes).
- AI also made footage, shorts and voice-overs.
- Roblox creator dashboard; Robux cash-out minimum 30,000 (creator has 574).

## Step-by-step
1. [00:00] Plan: spend time on ideas, art, fun; let AI write the Lua.
2. [00:00] Game 1 Needle Duels: copy of Dumpling Duels (hide needles, wear hats), built with Gemini; 11,000 visits then players left.
3. [01:00] Game 2 Climb Keyboard to Escape Brain Rot: title before game; about 3,500 visits.
4. [01:00] Game 3 Archer Heroes (boat survival): friends coding with Claude Pro; things worked; creator modeled armor by hand until last update then let Claude do the update; almost 17,000 visits, best game; coder left afterward.
5. [02:02] Game 4 Emotion Factory: factory tycoon where workers have personalities (yeller speeds belt, lazy does nothing, introvert better alone); 50 workers that buff or ruin neighbors. Started 9 October, built in under two weeks.
6. [03:03] Workflow: tell Claude what you want; it works inside Studio, tests and checks the screen. Game reached 29,000 lines, none hand-written.
7. [05:06] Update ideas after stability: weather events (cubes worth 10x), weather machine (gambling), raids stealing cubes through a portal, friend helpers, Halloween update.
8. [06:06] Results from the dashboard (see table).
9. [07:08] Ask for players: age-gated 16+ until 250 highly engaged players (has 11).

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Lua popularity | 16th, 9% | creator's cited ranking |
| Needle Duels visits | 11,000 | |
| Climb Keyboard visits | 3,500 | |
| Archer Heroes visits | almost 17,000 | best game |
| Emotion Factory code | 29,000 lines | |
| Emotion Factory workers | 50 | |
| Emotion Factory revenue | 349 Robux (about $1.30) | |
| All four games | 4,167 Robux (about $16) | |
| Ad spend | Needle Duels $40, Archer Heroes $153, Emotion Factory $32 = $225 | |
| Profit | about -$209 | |
| Like ratio | 87% (earlier games about 60%) | |
| Cash-out minimum | 30,000 Robux | creator has 574 |
| Local variable limit | 200 per function | bug cause |
| Weather event multiplier | 10x cube value | |
| Age-gate lift | needs 250 highly engaged players | has 11 |

## Prompts and skills used
- No literal prompts quoted. Approach: describe desired feature to Claude, which edits scripts in Studio, playtests and inspects the screen.

## Gotchas and fixes
- "Out of local registers" error: Lua allows 200 locals per function and the AI used them all; fix: put everything in one big shared table.
- Failed worker placement left an invisible unbuildable tile.
- Player left during save load but game still built their factory (ghost factory).
- Testing with real save data corrupted the creator's real save: added a switch to protect it.
- Lag from checking each cube against every other cube: now only nearby cubes.
- Exploit: looping the same cube past the Hacker helper repeatedly; fix: each cube gets only one roll.
- Copying an existing game and weak AI models gave few visits.

## Use it in our games
- Pair AI coding with Studio access (Claude reads scripts, playtests, screenshots) for fast iteration; watch Lua's 200-locals-per-function limit by using shared tables/modules (inferred).
- Gate test data: add a studio-test switch so playtests never touch real saves; handle player leaving mid-load.
- Use collection/progression with random events (weather 10x multiplier) and raids for steal-style loops.
- Do not rely on ad spend: this creator lost money; invest in originality and retention (like ratio improved with a fresh concept).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[10 Business, Monetization & Case Studies]] · [[15 Kid Appeal & Game Design]]
- Playbooks: [[01 Current Hits October 2026]] · [[02 Launch and Discovery Cheat Sheet]]
- More in Game design and business: [[My Roblox Game Made $43,292 (Here's Exactly How to Monetize Yours)]] · [[Roblox Game Design Explained Like You're 5 Yrs Old]] · [[Why 90% of Roblox Games Never Get Players]]
<!-- related:end -->
