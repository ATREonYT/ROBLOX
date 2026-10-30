---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=jJtZmZ3Hz9k
creator: "SyphoDev"
video_id: "jJtZmZ3Hz9k"
---
# Can AI Make an Entire Roblox Creature Capture Game? (3D Models, Map, Code)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
SyphoDev runs his Claude Code pipeline (/create-roblox-game skill) to build a Pokemon-style creature catcher "Seasonlings" in stages: research and plan, gray-box core loop, map + UI, polish (animations, VFX, sound), then a real playtest. He approves each stage, clears the chat, and pastes a handoff prompt. Result: playable, rated about 6/10 by testers.

## Tools and setup
- Roblox Studio with Claude Code and the Studio MCP; his own free skills and an "asset factory kit" (780 meshes in this build) from a paid course.
- New experience published to Roblox; File, Experience Settings, Security: turn on HTTP requests and the other toggles so Claude can use the Roblox API to upload assets.
- Discord for playtester signups.

## Step-by-step
1. [00:00] Studio: New experience, publish to Roblox with a name, then Experience Settings, Security, enable HTTP requests (and the other toggles).
2. [01:02] Send `/create Roblox game` with: complete research and plan for a creature capture game where you catch and battle; every creature name, type and design must be its own invention (avoid IP/copyright clashes).
3. [01:02] Claude returns the concept: island with year tree and four groves; elements Sprout, Scorch, Rustle, Hush; throw a "snug seed" with catch chance shown before throw; 1v1 turn-based, 3 moves each, timing ring for perfect hit (server-graded); 12 original species, 3 per type (common/uncommon/rare); four Wardens (giant elder rares) to restart the year; names checked against other games; simulation data used for balance.
4. [03:04] Approve ("yes that's all good"); Claude gives a prompt to copy. Clear the chat and paste it (avoids "context rot" from a full context window).
5. [04:04] Next stage: gray-boxed core loop in Studio. Test: spawn, pick starter, area 1, train and catch, heal, summon Warden, beat to unlock the next section.
6. [07:04] Feedback: circular layout is limiting; request a straight line, spawn at one end, zones 1 to 6 in a row, each unlocked by beating the previous Warden (with a sketch image pasted). Reason: popular Roblox games do it, and each new zone reuses the same code so updates are easy.
7. [09:05] Review result, say "This seems good. Mark the section as done." Get a resume prompt, clear chat, paste.
8. [11:10] Next stage: UI + map. Uses 780 meshes from his asset factory kit. Review issues: overlapping parts, gray-box placeholders, oversized name labels, cramped UI panels.
9. [15:15] Send feedback prompt with screenshots (labels too big, panels crowded, zone bar too big, flicker between parts, gray arena). Claude fixes; he still finds labels too big and asks for smaller and mostly transparent.
10. [21:16] Next stage: animations, effects, sounds, Studio playtest. Then a multiplayer playtest with Discord testers on a fresh account.
11. [32:32] Beat the final boss, ask players to rate out of 10.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Species | 12 original, 3 per type | common/uncommon/rare |
| Elements | Sprout, Scorch, Rustle, Hush | seasons |
| Battle | 1v1 turn-based, 3 moves each | timing ring graded by server |
| Zones | 6 in a straight line | each unlocked by beating the Warden |
| Wild catch demo | catch rate 45%, level 5 | catch chance shown before throw |
| Meshes | 780 from asset factory kit | |
| Bosses | 4 Wardens originally | final fight has two bosses |
| Player ratings | about 2 to 7 /10 | author's estimate about 6 |

## Prompts and skills used
- "/create Roblox game. Complete the research and plan stage for a creature capture game where you can catch creatures and battle with them. Every creature name, type, and design in it must be its own invention. This is to make sure we don't infringe any IPs or copyrights from other similar games."
- "/great robots game [sic: create-roblox-game feedback]. I want one change to section two... the groves are laid out in a circle around the hub. Change the world to zone by zone in a straight line the way most popular Roblox games do it. Spawn at one end and then zones one to six in a row. Each zone is unlocked by beating the one before it. My sketch is the image pasted."
- Feedback prompt: name tags should sit above each creature's head, scale with distance, stay readable; panels crowded, give every element clear space; make zone bar smaller; fix flicker where parts overlap; wooden arena still gray.
- Skill: /create-roblox-game (research, design, assembly); MCP: Roblox Studio.

## Gotchas and fixes
- Context rot: clear chat after each stage and paste the generated handoff prompt.
- Circular map limited zones; switch to linear.
- Overlapping parts caused flicker; ask Claude to fix every place.
- Name labels too big and constant screen size; make world-scaled/smaller/transparent.
- Seed throws buggy at moving targets; creatures do not run to the enemy; music too loud; two players fighting one boss appears as two bosses (suggested: spawn client-side); Warden arenas reset healing oddly.
- He deliberately has the AI fix issues rather than fixing them himself.
- Roblox bot verification blocked a new test account.

## Use it in our games
- Use staged development with approval gates and a handoff prompt after each stage, clearing the chat to avoid context rot.
- Linear zone-by-zone layout with gated unlocks fits our simulators (zone 1, 2, 3 ... each reusing the same code); easy to add updates.
- Ask for a research stage that checks similar games and invents original names (steal-style games: original brainrot characters).
- Always attach screenshots to a feedback prompt and list each UI problem numerically (inferred).
- Show catch/steal chance before the action to keep it readable (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[01 Setup & Workflow]] · [[02 Full Game Builds]]
- Playbooks: [[Blueprint - Plus One Evolution]]
- More in AI workflow: [[Building Viral Roblox Game w AI (pretty easy)]] · [[Building a Viral Roblox Game w ONLY AI]] · [[Can AI Make an Entire Roblox Incremental Game (Art, 3D Models, Code)]] · [[How Big Studios Develop on Roblox]] · [[How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)]] · [[How to make Roblox Games Using Claude]] · [[Roblox Studio Has Custom Skills Now (Here's How To Make One)]] · [[Superbullet × Claude Opus 5.5 Is INSANE for Roblox Development]]
<!-- related:end -->
