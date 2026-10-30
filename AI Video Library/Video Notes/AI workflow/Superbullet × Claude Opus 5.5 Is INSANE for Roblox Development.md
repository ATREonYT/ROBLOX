---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=6aYkVVIcm48
creator: "SuperBullet"
video_id: "6aYkVVIcm48"
---
# Superbullet × Claude Opus 5.5 Is INSANE for Roblox Development

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Starting from Super Bullet's free Tap Simulator template, the creator feeds Claude Opus 5.5 ready-made Super Bullet system libraries (tutorial, admin panel, NPC, dialogue, pets, levels, movement, promo codes, fishing, inventory) one "quest" at a time, and has Claude adapt each to the existing game. Ends as a four-world game with a "game tree" map of all systems.

## Tools and setup
- Claude Opus 5.5 connected to Roblox Studio (a separate setup video is linked in the original description).
- Super Bullet: Roblox-specific AI with systems, libraries and templates. Libraries named: tutorial, admin panel, NPC, dialogue, pet, level, movement (sprint and slide), promo codes, fishing, inventory. Free to try; Tap Simulator template free.
- ChatGPT image used as a reference image for the game tree page.
- Roblox's built-in model generation tools for map assets.
- Giveaways of Super Bullet Pro and tokens mentioned.

## Step-by-step
1. [00:00] Start from the free Tap Simulator template (click, buy potions, rebirth). Rule: every addition must give the player something to do or improve existing content.
2. [01:00] Onboarding (D1 retention): pull Super Bullet's tutorial library; first it taught the wrong game, so send Claude back to adapt it from first click to first rebirth, including arrows pointing at shops.
3. [02:01] Game tree: give Claude a ChatGPT reference image, build a separate page synchronized with the game showing every potion, cost and boost; rescan as the game grows. Uses Super Bullet app icons.
4. [02:01] Admin panel: import Super Bullet's (kick, ban, gems) and have Claude customise it to the game's potions and systems for testing. Turn the tutorial off while testing.
5. [03:01] Map research: tell Claude to visit six Roblox games (including Pet Simulator, Bee Swarm Simulator) via computer control and study how maps lead players to goals. Takeaways: see the next area through a gate with the price shown; shops and machines sit beside the main route; a central landmark (giant sunflower).
6. [04:01] Rebuild the island: keep all systems, rebuild the map; Claude generates models with Roblox tools. Result "Sprout Hollow" with a giant lantern tree landmark, paths around trees, shops in their own spaces, mushrooms.
7. [04:01] Fix: items falling from the sky, Z-fighting overlapping surfaces; Claude toned down lighting, cleared space and anchored loose props.
8. [05:01] Remodel the template's second desert area into "Sunstone Dunes" and add a bridge visible across the gap.
9. [05:01] NPC and dialogue libraries: shopkeepers whose dialogue opens the existing shop; guide NPC "Lumi" for new players.
10. [06:01] Pet library connected to progression (hatch a bunny, click bonus), pets get their own branch in the game tree. New world "Honeycomb Cliffs" with its own egg; egg requires 10 rebirths (bypassed using the admin panel); gives Honey Bear pet.
11. [07:01] Level library: XP tied to everything. New themed world (clockwork orchard) requiring 25 rebirths and level 20.
12. [07:01] Progression too slow: expand potions (temporary boosts, brew leftover time and weaker potions into stronger ones); added mystery potion; up to 4x boosts.
13. [08:01] Studio closed without saving and lost the potion update; recovered by sending Claude through conversation history to reconstruct it.
14. [08:01] Movement library: sprint and slide; sprint unlocked after first rebirth and a gem-purchasable sprint speed upgrade, sold in Sunstone Dunes.
15. [09:01] Promo codes library (rewards a gem and a potion).
16. [09:01] Fishing: one small pond per island, fish tiers progress; catches feed existing XP and gems; later ponds harder with starter rod so better rods are worth buying. Inventory library adapted to hold catches and rods.
17. [11:01] Final QA: open a fresh Claude session, ask it to check start to finish whether all systems agree about unlocks and earnings (took about 2 hours), then bring back the tutorial and playtest.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Honeycomb Cliffs egg unlock | 10 rebirths | |
| Clockwork orchard unlock | 25 rebirths and level 20 | |
| Potion boosts | 2x up to 4x | Stronger boosts added |
| Sprint unlock | after first rebirth | Plus gem-bought sprint speed upgrade |
| Ponds | 1 per island (four total) | |
| Final QA session | about 2 hours | |
| Worlds at end | 4 | |

## Prompts and skills used
- Paraphrased: "Take someone from the very first click to where they first rebirth and show them what the shops feel along the way" (tutorial adaptation).
- "Keep all of our systems but completely rebuild the island we're actually using. I want to load into the same game and barely recognize it."
- "Visit six games including Pet Simulator and Bee Swarm Simulator and study how their maps get a new player towards something worth reaching."
- "Add one small pond on each island as well as different fish as we progress; connect catches directly into the game's existing XP and gem system."
- Super Bullet libraries as listed under Tools.

## Gotchas and fixes
- Imported tutorial taught a different game: redirect Claude to the target game.
- Claude built separate islands instead of rebuilding the one in use: change the plan with an explicit instruction.
- Tree models rough; sky-falling props and Z-fighting: reduce lighting, clear space, anchor props.
- Studio closed unsaved, losing an update: reconstruct from the Claude conversation history (also: save often).
- Hard to find an NPC selling an upgrade: ask Claude where it placed it.
- Boats were considered but dropped as scope creep.

## Use it in our games
- Use a "game tree" synced page to track every currency, boost and unlock across systems in a +1 simulator (inferred).
- Gating worlds by two kinds of progress (rebirths plus level) stops players from stacking one stat to skip content.
- Show the next area's price through a gate or across a gap and place machines beside the main route, as the Pet Simulator research found.
- Finish with a fresh-session QA pass asking whether systems agree about what a player has unlocked.
- Use an admin panel from the start to test gated content without grinding.

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[01 Setup & Workflow]] · [[02 Full Game Builds]]
- Playbooks: [[Blueprint - Plus One Evolution]]
- More in AI workflow: [[Building Viral Roblox Game w AI (pretty easy)]] · [[Building a Viral Roblox Game w ONLY AI]] · [[Can AI Make an Entire Roblox Creature Capture Game (3D Models, Map, Code)]] · [[Can AI Make an Entire Roblox Incremental Game (Art, 3D Models, Code)]] · [[How Big Studios Develop on Roblox]] · [[How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)]] · [[How to make Roblox Games Using Claude]] · [[Roblox Studio Has Custom Skills Now (Here's How To Make One)]]
<!-- related:end -->
