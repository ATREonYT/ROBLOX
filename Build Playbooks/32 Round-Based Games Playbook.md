---
tags: [build-playbooks, rounds, minigames, party, tag, hide-and-seek, horror-lite, obby-race, arena, kit/Rounds]
updated: 2026-11-01
---

# 32 Round-Based Games Playbook

Back to [[00 Build Router]] · Fun with friends: [[26 Fun and Roleplay Playbook]] · Ideas: [[Game Concepts - RP and Fun]] · Numbers: [[27 Studio Standard - One Sheet per Craft]] · Kit: `Shared/Rounds.luau` · Deep build: LihFolk `43 Genre Systems End to End/Arena Rounds with Teams and Spectating End to End.md`

**What this is.** Many of the "more fun" games Alex wants next play in rounds: party minigames, tag, hide-and-seek, mystery-role games, horror-lite runs, obby races and friendly arena fights. They all share one skeleton: **lobby → countdown → round → results → lobby**. This note gives that skeleton once (with tested code), then what changes per genre.

## 1. The round skeleton
| State | Length (start here) | What the player sees | What the server does |
|---|---|---|---|
| **Waiting** | until enough players | "Waiting for 1 more player…" and something to do in the lobby | Nothing starts with too few players |
| **Intermission** | 15 s (10–20) | The next mode or map, a vote, the lobby toys | Picks the map; cancels if players drop below the minimum |
| **Countdown** | 5 s (3–8) | "3, 2, 1, GO!" with a sound per number | Teleports players, gives roles and tools |
| **Playing** | 60–180 s | The goal, a timer, who's left | Checks every win or lose condition; ends early when one (or no) player is left |
| **Results** | 6 s (5–8) | Winners on a podium, rewards flying to the counter | Pays only real rounds (≥ 20 s, enough players at the start) |

Kit: `Rounds.new({ minPlayers, intermission, countdown, roundLength, results, joinInProgress, minPaidSeconds, endWhenAlive })`, ticked by the server; it returns events (`Intermission`, `Countdown`, `Started`, `Ended`, `EndedUnpaid`, `Cancelled`). Every round has an id, so a timer from an old round can never end a new one.

## 2. The rules that keep rounds fun
1. **Never wait with nothing to do.** The lobby has toys: a trampoline, a mini obby, a pet to pat, a leaderboard to look at. A bored kid leaves during intermission.
2. **Short rounds, many of them.** 1–3 minutes. Five quick rounds beat one long one, because each round is a fresh chance to win.
3. **Out doesn't mean bored.** Eliminated players spectate (a camera on a living player, switch with arrows) or play a small "ghost" job (cheer, drop balloons). They never stand in a box.
4. **Late joiners are welcome:** they can join in the first 10–20 s, otherwise they spectate and play the next round.
5. **Everyone gets something.** Winners get the big reward; everyone who played a full round gets a small one. Losing should still move a bar.
6. **Rotate.** A playlist of 3–6 modes or maps, with a vote of 3 in intermission, so the game feels new every few minutes.
7. **Fair roles.** A rare role (the seeker, the "it", the mystery role) is given by a fair rotation (whoever had it least), not by money. **Never sell a better chance of a role** to kids.
8. **No uncontested farming.** Rounds shorter than 20 s, or that started with fewer than the minimum, pay nothing (the kit marks them `EndedUnpaid`).

## 3. What changes per genre
| Genre | Win condition | Roles | Round length | The cinematic moment | Watch out |
|---|---|---|---|---|---|
| **Party minigames** | Different per minigame (last on the platform, most coins, first to the top) | None | 45–90 s each | The podium with confetti | Each minigame teaches itself in one sentence and one picture |
| **Tag / freeze tag** | Survive the timer, or tag everyone | 1–2 "it" per 8 players | 90–150 s | The last runner, with a slow-motion tag | "It" must be faster or have a dash, or it's no fun |
| **Hide-and-seek** | Seekers find all hiders, or hiders survive | 1 seeker per 5–6 | 120–180 s (30 s to hide) | The final hider found, the camera swinging to them | Ban hiding spots out of the map; seeker gets hints after 60 s |
| **Mystery roles** (one secret role, one helper, everyone else innocent) | Find the secret player, or survive | Secret role 1 per 8–12; helper 1 | 120–180 s | The reveal of who it was, with a name card | Kid-safe: "tag out" and "capture" with silly effects, not violence; no blood |
| **Horror-lite run** | Reach the exit together | A friendly monster (NPC) chases | 3–6 min | The door opening at the end | No jump-scare screaming; a "less scary" setting; light, not dark rooms everywhere |
| **Obby race** | First to the end, or furthest in time | None | 60–180 s | The finish line slow-motion | `endWhenAlive = 0` so it doesn't end when one finisher is left |
| **Friendly arena** (foam swords, water blasters, dodgeball) | Most points, or last team | 2 teams | 90–150 s | The final hit, with an impact frame | Server-checked hits; respawn in 3 s so nobody waits long |

## 4. Rewards and progression across rounds
- **Small reward every round** (coins for playing, more for placing), plus **a win streak** that shows on the name tag.
- **Long goals:** a level from total rounds played, cosmetics unlocked by level (trails, emotes, victory dances), weekly quests ("Win 3 tag rounds").
- **Money:** sell looks (trails, victory dances, outfit packs), a private-server mode with custom rules, and maybe a "2x coins" pass. Never sell a better role chance or an unfair power in a competitive round.

## 5. Server must-haves (the bugs every round game ships with)
| Bug | Fix |
|---|---|
| An old round's timer ends a new round | Every timer checks its round id (the kit does this) |
| A player leaves mid-round and the round never ends | `Leave` on PlayerRemoving; the round checks who's left every tick |
| Players walk out of the arena or hide under the map | Kill planes below the map, invisible walls, and a server check that teleports out-of-bounds players back |
| Tools or roles leak into the next round | Clear tools, teams and attributes in Results, every time |
| Two people vote at once and the map flickers | Count votes on the server; announce the winner once |
| Spectators can still affect the round | Spectators are a separate team with no tools and no collision |

## 6. Worked example: a 6-player freeze-tag round
1. `Rounds.new({ minPlayers = 3, intermission = 15, countdown = 5, roundLength = 120, joinInProgress = 15, endWhenAlive = 0 })`. Freeze tag ends when everyone is frozen, so the game decides the end itself, not the "one left" rule.
2. **Intermission:** a vote between 3 maps; the lobby has a trampoline.
3. **Countdown:** pick 1 "it" fairly (whoever was "it" least); teleport runners to spread-out spawns and "it" to the centre, frozen for the 5 s.
4. **Playing:** "it" has a dash (cooldown 4 s). A tag is a server-checked touch within 6 studs (`Interact`-style distance check). A frozen runner turns to ice (a Highlight, no flash) and can be unfrozen by a friend standing next to them for 2 s.
5. **End:** all frozen ("it" wins) or the timer runs out (runners win). Results show a podium with a confetti burst and a "+25 coins" fly-in.
6. **Test:** with 4 test clients in Studio, run 10 rounds. No round starts with fewer than 3; a player leaving as "it" ends the round fairly (runners win, no pay if under 20 s); nobody keeps a tool after Results.

## 7. Checklist
- [ ] The lobby has something to do; intermission ≤ 20 s.
- [ ] Rounds 1–3 minutes; a playlist with a vote.
- [ ] Eliminated players spectate or have a ghost job.
- [ ] Roles are fair and never sold.
- [ ] Everyone who plays a full round earns something; short or empty rounds pay nothing.
- [ ] Old timers can't end new rounds; leaving is handled; tools are cleared each round.
- [ ] Kid-safe themes: tag out, capture, splash, not hurt.
