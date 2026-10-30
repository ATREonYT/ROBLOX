---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=RNnUqomUaII
creator: "SyphoDev"
video_id: "RNnUqomUaII"
---
# Can AI Make an Entire Roblox Incremental Game? (Art, 3D Models, Code)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Explains the skills + MCP + API setup for Claude Code and runs it on an incremental game: research and plan, code-only core loop, then parallel UI, map, and 3D-model agents. First build was too dark with empty plots and needed a fix pass. The video ends before VFX/animation are shown.

## Tools and setup
- Claude Code, Roblox Studio MCP, Rojo.
- Skills for programming, map, UI, 3D modeling, animation, VFX.
- APIs: Cloudflare (image generation), free Kaggle GPU (open-source 3D generation), Roblox key (upload finished assets).
- Blender (decimation and baking).
- Studio settings: File, Experience Settings, Security, allow HTTP and the other toggles.

## Step-by-step
1. [00:00] Concept: don't make everything via code; give Claude separate workflows per discipline.
2. [04:00] Create a new experience in Studio, save to Roblox, set Experience Settings, Security, allow HTTP.
3. [05:03] Run `/create Roblox game` (incremental game, research the genre, create a game that can break out).
4. [06:05] Review the research output: Glowshroom Incremental. Review the genre data and pitch. Approve the plan.
5. [08:11] Approve ("this seems good"). Claude records approval and writes a handoff.md; copy the continue prompt, `/clear`, paste.
6. [10:14] Session 2 result: scripts and placeholder map/mushrooms; test plot claiming, tap spores, upgrades, offline gains.
7. [12:15] `/clear` then "continue with the development of the incremental game". 3D skill: concept image, Claude checks, Kaggle open-source model makes mesh (about 600k faces), Blender cuts about 60:1 and bakes detail as texture.
8. [13:18] UI skill: generate mock-ups, Claude compares with other Roblox UIs, then builds via code in screen UIs/frames. Agents run in parallel (meshes, UI, map).
9. [14:19] Map skill: generates meshes, plans the map, screenshots, fixes until playable.
10. [15:19] Review: 857 instances, 480 meshes, 9 meshes generated; map too dark, plots unclaimed, UI misplaced. Prompt a fix; check Rojo and MCP connected.
11. [16:24] After the fix: lighter, UI better, but plots show nothing; ask Claude why and to fix.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Genre stat | 4.5 million visits since March | for the genre |
| Immortality Incremental | 3,072 players, 270k favorites | example leader |
| Grass Incremental Simulator | 60K players [sic], 608K favorites, 151 players | caption unclear |
| Fruit Piece Incremental | stopped updating in May; 2 players of 4.9 million visits | died without updates |
| Mycelium twist | each other server player +10% speed, up to 50% | bloom triggers server spore storm |
| Spore storm | 2x production for 60 seconds | when anyone blooms |
| Mushroom types / upgrades | 5 types, 16 upgrades | owning 25/50/100 doubles that type |
| Bloom reset | seeds keep 10% of each, permanent 2x | goal: heart root at Bloom 10 |
| Raw 3D mesh | about 600k faces, cut about 60:1 | |
| Map build | 857 instances, 480 meshes | |

## Prompts and skills used
- "/create Roblox game. Make me an incremental game. Do the research on the genre and create a game that I can break out [sic]."
- Handoff: "continue with the development of the incremental game" after /clear.
- Fix prompt: "The lighting is far too dark. I can't see anything really at all, and the UI elements are not placed correctly. Please verify how it looks right now and fix accordingly."
- Follow-up: "The plots, nothing is spawning... have you just failed to implement something? If so, please fix."
- Skills: programming, map, UI, 3D modeling, animation, VFX, create-roblox-game.

## Gotchas and fixes
- Context window grows with every message; solve with a handoff.md and /clear between stages.
- Placeholders for UI/models/map are expected after the code phase.
- First map too dark; UI misplaced; plots empty; fixed by prompting with the exact complaint; verify Rojo and MCP connected before fixing.
- Raw 3D output too heavy; decimate then bake.

## Use it in our games
- Copy the incremental design: server-wide multiplier for more players plus a timed server event (e.g. 2x for 60 seconds) to encourage co-op in a +1 simulator.
- Prestige loop with partial keep (10% of each, permanent 2x) maps to rebirths (inferred).
- Keep the leaderboard as the social feature but add something that makes other players matter (the video's gap analysis).
- Check lighting and plot visibility in a screenshot test after every generation pass (inferred).
- Plan updates up front; the video notes games die without updates.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[01 Setup & Workflow]] · [[02 Full Game Builds]]
- Playbooks: [[Blueprint - Plus One Evolution]]
- More in AI workflow: [[Building Viral Roblox Game w AI (pretty easy)]] · [[Building a Viral Roblox Game w ONLY AI]] · [[Can AI Make an Entire Roblox Creature Capture Game (3D Models, Map, Code)]] · [[How Big Studios Develop on Roblox]] · [[How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)]] · [[How to make Roblox Games Using Claude]] · [[Roblox Studio Has Custom Skills Now (Here's How To Make One)]] · [[Superbullet × Claude Opus 5.5 Is INSANE for Roblox Development]]
<!-- related:end -->
