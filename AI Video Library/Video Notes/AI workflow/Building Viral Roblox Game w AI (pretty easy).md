---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=Si8T9D-kPBY
creator: "tef"
video_id: "Si8T9D-kPBY"
---
# Building Viral Roblox Game w/ AI (pretty easy)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Part 1 of "Bandit Beater": the creator describes a Blox Fruits-style bandit-beating RPG to Claude Code in one summary prompt, then works through numbered milestones (XP/multiplier backbone, combat NPCs, quest NPCs, stat UI, zones) with Rojo syncing files into Studio. Playable prototype in about 2 hours with plenty of rough edges.

## Tools and setup
- Claude Code (set to "ultra code" mode; called the strongest game-building AI available).
- Rojo, to sync files into Roblox Studio (setup was painful at first).
- Roblox Studio, new experience named Bandit Beater.
- Usage limit was hit near the end.

## Step-by-step
1. [00:00] Pick the game: bandit beater (RPG where you beat bandits to level up), prototype goal, name "Bandit Beater".
2. [01:00] Write a game summary: two builds (sword build or melee/hands), attribute and XP system like existing Roblox RPGs, plus a quest-driven XP multiplier (e.g. first quest adds 0.1 multiplier each completion, harder quests add 0.5).
3. [02:00] Paste the summary into Claude Code and ask it to help build it in Studio. Claude asks what to build first and how much control to take; creator says do most of the work.
4. [03:00] Claude builds the XP and multiplier backbone and server logic. Set up Rojo, accept synced files, fix errors, test commands.
5. [04:01] Milestone 2 prompt: "combat, bandit NPCs, sword and melee builds, and stronger every hit mechanic". Result: bandit system, combat system, character system (max health from defense, sword on spawn).
6. [05:02] Test: sword looked like a stick, no animation, NPCs are blocks. Prompt: use a real sword model, NPCs that look like default avatars (bacon hair), regular katana, hit animation.
7. [06:03] Re-test: better sword animation, avatar bandits (black). Prompt: higher click rate for katana, Q as a dash (dash damages enemies you pass through).
8. [06:03] Milestone 3: quest NPCs you walk up to and accept "kill X bandits".
9. [07:03] After about 15 min: Q dash, katana combos, shorter time to kill, quest NPCs done. Test shows NPC trapping, quest kills not counting, quest NPCs inside the fight zone.
10. [08:04] Prompt fixes: count kills, move quest NPCs out of the fight zone, bandits only attack after being attacked then pursue (genuine bandit-game behaviour).
11. [09:04] Prompt: put quest UI on the left with the main menu (attributes, map, quest, shop buttons). Quest progress live-updates; completing a quest grants a multiplier.
12. [10:05] Milestone 4: more NPC levels, attribute UI. Result: Village Outskirts, Trade Road, Bandit Hill zones (bandit rookies, brutes, captains).
13. [11:05] Allocate stat points (sword points plus defense); damage reaches about 30 per hit, making brutes beatable.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Quest XP multiplier | 0.1 first quest, 0.5 harder quests | Example said aloud, per completion |
| Dash key | Q | Damages enemies in path with katana |
| Katana damage after stat points | about 30 per hit | After putting points into sword |
| Claude time per milestone | about 15 min | Milestone 3 |
| Quest | Defeat 5 bandit rookies (Old Marcus) | |
| Total build time | about 2 hours | |

## Prompts and skills used
- Milestone prompt: "Milestone two, combat bandit NPCs, sword and melee builds, and stronger every hit mechanic."
- "Use an actual sword model and NPC models instead of blocks... NPCs look like the default bacon hair... regular base katana model... an animation when we hit the enemy."
- "Higher click rate for our katana. Also I want Q to be a dash."
- "Make sure the bandits only start attacking me when I attack them first and then they'll constantly pursue me."
- "Put the quest UI to the left where the main menu will also be located with our attribute button, the map button, the quest button, and the shop button."
- Planned roadmap: M3 quest NPCs, M4 stat allocation UI, then areas and zones.

## Gotchas and fixes
- Rojo connection was hard; resolved by connecting and accepting synced files.
- Creator says Claude "sometimes lies", so always playtest after each milestone.
- Quest kills not counting, quest NPCs unreachable, bandits aggro-ing unprovoked, character appearing too tall: each fixed via follow-up prompts (tall character not explained).
- Bandits trapped by terrain, letting the player exploit them.
- Brutes took too long to kill until stat points were allocated.
- Sword model still needed fixing; usage limit nearly stopped milestone 4.

## Use it in our games
- Use the milestone-by-milestone prompt format ("Milestone N: X, Y, Z") to keep Claude scoped and testable (inferred).
- The video's "stronger every hit" plus XP multiplier from quests is a stacking-multiplier loop that maps directly to "+1 every hit/second" style progression (inferred).
- Playtest after each milestone and feed bugs back in short prompts; do not batch many untested features.
- A left-side menu column (attributes, map, quest, shop) is a ready HUD layout for a sim.
