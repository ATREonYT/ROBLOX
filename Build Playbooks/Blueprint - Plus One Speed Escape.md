---
tags: [build-playbooks, blueprint, plus-one, speed, obby, escape]
updated: 2026-10-30
---

# Blueprint - Plus One Speed Escape

Back to [[00 Build Router]] · Family overview: [[01 Current Hits October 2026]]

**Code:** start from [[05 New Game Kit]] (`sh new-game-kit/tools/new_game.sh`); build only this blueprint's own loop.

**One line:** every step gives +1 speed, you try an obstacle course that gets harder to control the faster you are, finishing gives Wins, and Wins buy multipliers and unlock themed worlds.

Reference games: +1 Speed Keyboard Escape (a themed world in each title, 22-player servers, about 9-minute sessions), Punch to Escape!, +1 Speed Monkey Escape. Deep teardown: [[Teardown - +1 Speed Keyboard Escape]]. Prototype in this repo: `plus-one-speed/`.

> [!warning] Crowded family
> It fell about 61% from August to September 2026. Only enter with a strong twist and weekly worlds ready.

## 1. Pick the twist
- **Gain verb:** step, punch, jump, swing, eat.
- **Course object (must read in a 150 px thumbnail):** keyboard, candy, giant food, toys, a phone screen.
- **The catch:** more speed = harder to steer. Keep that; it's why failing still feels like progress.

## 2. Loop and first 60 seconds
```text
move ─► +1 speed per step ─► try the course ─► fall ─► back to start, but faster
                                    └─► finish ─► +Wins ─► multipliers / trails / next world
```
1. Spawn, walk: the speed counter climbs with a satisfying click sound per step.
2. The course starts right there. First attempt in under 10 s.
3. The first fall shows you're already faster. A treadmill or multiplier stand is in view.

## 3. Systems
| # | System | Note / code |
|---|---|---|
| 1 | Speed from distance actually moved, capped per tick, on the server | snippet in [[Teardown - +1 Speed Keyboard Escape]] |
| 2 | Checkpoints and stage saves | [[Obby Checkpoints and Stage Saves End to End]] |
| 3 | Finish → Wins, world unlocks | [[Rebirth and Prestige System End to End]] for the reset variant |
| 4 | Multipliers, trails, auras (equip slots) | [[Saved Inventory End to End]] |
| 5 | Anti-cheat against the player's own server speed, not a global cap | [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| 6 | Thick collisions so fast players don't tunnel through | [[Teardown - +1 Speed Keyboard Escape]] (Technical notes) |
| 7 | Leaderboard: top Wins / top Speed | [[Global Leaderboards End to End]] |
| 8 | Hide-others'-effects toggle for 22-player servers | [[Graphics and Performance Toggles for Low-End Devices]] |

## 4. Starting numbers (tune)
| Thing | Start |
|---|---|
| Speed per step | 1 per 4 studs moved, × multipliers |
| Server size | 16-22 |
| Course length | 60-90 s at the "right" speed for that world |
| Worlds at launch | 3, plus 1 new world per week |
| Wins per finish | 1 × world number × multiplier |
| Price ladder | trails and auras 19 to 2,999 Robux; many small items so every budget finds one |

## 5. Map, UI and money
- Course: one giant themed object, bright, readable from spawn; the finish is visible from the start.
- HUD: Speed (huge), Wins, a world button, a left column (Shop, Trails, Worlds, Rebirth).
- Money: fixed-price trails/auras, 2x speed, 2x wins, extra equip slots, skip-stage product. Mostly fixed price, so no odds needed.

## 6. Done when
- [ ] First attempt in under 10 s, first finish in under 3 minutes.
- [ ] Speed is credited by the server from real movement.
- [ ] Still fun at 10× speed (playtest every world at max speed).
