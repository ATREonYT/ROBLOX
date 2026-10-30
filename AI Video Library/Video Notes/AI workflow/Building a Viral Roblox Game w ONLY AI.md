---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=6oRy9dr4_iQ
creator: "tef"
video_id: "6oRy9dr4_iQ"
---
# Building a Viral Roblox Game w/ ONLY AI

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Part 2 of the "Bandit Beater" series (Blox Fruits-style bandit-beating RPG). The creator connects an MCP server between Claude Code and Roblox Studio, has Claude swap in a katana model, add a melee/sword start screen, colour-code NPC tiers, then hand-sculpts four islands with Studio's Terrain Editor and has Claude map NPCs onto them. Sword attachment/orientation stays broken throughout.

## Tools and setup
- Claude Code with an MCP server connected to Roblox Studio (added because viewers said it would make code smoother).
- Rojo (had to reconnect the Rojo server so Claude could edit scripts).
- Roblox Studio Toolbox (searched "katana", used a katana model that came with an animation).
- Roblox Studio Terrain Editor: Generate, Draw, Flatten, Move ("like an eraser") tools, Create Ocean.
- Part 1 base: basic NPCs, basic sword, basic UI already built.

## Step-by-step
1. [00:00] Recap: part 1 gave basic NPCs, sword and UI. Goals for this video: sword shop/"sword island" (gambling/rolling for swords), and the world (plain at start).
2. [01:01] Search Toolbox for "katana", spawn the model (it includes an animation).
3. [01:01] Prompt Claude Code to add the spawned katana plus animation in place of the self-made sword, and add a start screen where players pick sword or melee before spawning.
4. [02:01] Result: start screen worked, but Claude pulled the sword from the animation dummy and not the animation; sword glitched downward and looked like a gun.
5. [02:01] Fix attempt: delete the dummy from the workspace, re-prompt Claude to add the katana to the Roblox character.
6. [03:01] Prompt: fix animations, make sure the katana on the floor is the one used, spread out NPCs, colour-code bandit difficulty (green easiest, yellow grunts, orange harder, red hardest) and make quest NPCs white.
7. [04:03] Test: katana sideways in hand but works better; counter still works; Claude had to re-correct sword placement itself (slow).
8. [04:03] Plan world as three main islands (three bandit groups), no boats, maybe pathways between islands.
9. [04:03] Terrain Editor: click Generate and place the first island (first attempt generated a lava biome, deleted, retried).
10. [05:04] Use the Draw tool to draw island 1, Flatten tool to level, Move tool to reshape. Island 2 = white limestone (harder bandits), smaller because the gambling sword shop will go there.
11. [05:04] Set sea level (about 20, raised slightly so it does not sit over islands), click Create Ocean.
12. [06:05] Build island 3 from wood, island 4 from snow (all four islands hand-sculpted, "not using AI at this point").
13. [06:05] Prompt Claude: I built four islands, space the NPCs properly across them, spawn on the grass starter island, say which island is easiest/hardest, fix sword positioning.
14. [07:05] About 20 minutes later Claude had mapped the islands, assigned NPCs per island and added a new NPC level, Bandit Warlords.
15. [07:05] Playtest: grass island (Old Marcus quest: defeat five bandit rookies), limestone isle (captains), wood island (brutes, level 12+), snow island (warlords, Commander Frost, hardest). Sword still backwards/upside down.
16. [09:06] Wrap-up; next video: build the sword shop as the main power mechanic.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Sea level | about 20 | Raised slightly so it stays under island tops |
| NPC colour tiers | green, yellow, orange, red | Easiest to hardest; quest NPCs white |
| Brute zone level | level 12+ | Said aloud for wood island brutes |
| Claude run time (island mapping) | about 20 min | |
| Islands | 4 | grass, limestone, wood, snow |

## Prompts and skills used
- "Add the katana I just spawned in and the animation and try to sub it in for the katana that I made" plus "add a little start screen so players can choose if they want to be a sword or melee before they even spawn in."
- "Fix the animations a bit and make sure the katana on the floor is the katana we're using. Spread out the NPCs. Easiest bandits green, yellow grunts, orange harder, red [hardest]. Make the quest NPCs white."
- "I built the four islands; space out the NPCs properly on the island, make sure we spawn on the starter island (grasslands), [which island is easiest/hardest], and fix my sword positioning."
- No named skills; Rojo and MCP only.

## Gotchas and fixes
- Leaving the animation dummy in the workspace confused Claude (it used the dummy's sword). Fix: delete the dummy, keep only the katana model.
- Sword orientation (sideways, backwards, upside down, glitching downward) never fully fixed; creator says character is not mapped to the sword properly and will fix off-camera.
- Rojo needed reconnecting before Claude could edit scripts.
- Terrain Generate can produce odd biomes (lava); delete and redo.
- Islands need transport (bridges or similar); players could swim.

## Use it in our games
- Do not rely on a Toolbox model plus an animation dummy for held items; give Claude a single clean tool/model with explicit grip CFrame (inferred).
- Tier colouring of enemies (green to red) is an easy readable difficulty system for any zone-based sim or steal game (inferred).
- Hand-build the world layout yourself, then ask Claude to map spawn/zones onto it: the video's split of human world layout and AI placement worked well.
- For a +1 style sim, a gamble/roll shop island for gear (swords) is the creator's planned core loop (inferred application).
