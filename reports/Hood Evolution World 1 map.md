# +1 Hood Evolution, World 1: the map (2026-10-03)

`TheBlockV2` is World 1, built from the team's concept sheet ("+1 Hood Evolution, World 1"). The concept
had 5 districts; the map now has **15 stages**. Each district look repeats for 3 stages, and every stage
needs more Power to get in. The first map (`TheBlock` / `SimulatorLobby`) is untouched.

```lua
require(game.ServerStorage.TheBlockV2).Build()
```

`Build` keeps the old copy in `ServerStorage` (`TheBlockV2_Before_<time>`), makes V2 the active map and
applies the `FrontPage` lighting. `SetActive(false)` and `HoodLighting.Restore()` undo both.

## Layout (spawn to boss)

The street is one straight walk, about 1,130 studs long. Each stage is 64 studs long, with buildings
shoulder to shoulder down both sides and their fronts facing the middle.

| Stages | Look | What's there |
|---|---|---|
| Spawn | Plaza | Blue spawn circle. West: three aura training stations (Tire, Duct Tape, Street) under a TRAIN HERE sign. East: the ARMORY (10 guns on two rows of pedestals). Back: the EVOLVE booth. Benches, lanterns, hedges, trees |
| 1–3 | The Block | Red brick rows, dumpsters, trash bags, crates on pallets |
| 4–6 | Shop Street | Barber (turning pole) and Grocery in stage 4, then pizza, sneakers, ice cream, arcade, bakery and phone shops |
| 7–9 | The Courts | A basketball court across the walk (orange, then blue, then green), with hoops, goals and chain-link fences |
| 10–12 | The Apartments | Tan apartment blocks with balconies |
| 13–15 | The Yards | Warehouses, stacked shipping containers |
| Boss yard | — | Warehouse, container lot, the Champ Ring and the BOSS pad |

- **Telling the three apart:** stages in one look share the buildings but change the dressing, the pad
  colour (red, blue, green) and the props. Each look opens with a "DISTRICT k • a - b" banner.
- **Fight pads:** one numbered pad in the middle of every stage, plus the boss pad.

## Power to get in

Every stage opens behind a gate. The gate is a see-through wall showing the Power you need, and it only
lets you through once your Power (`Rep`) reaches that number. The first time through pays Cash (20% of
the requirement, at least 10).

| Stage | Power | Stage | Power | Stage | Power |
|---|---|---|---|---|---|
| 1 | 10 | 6 | 500 | 11 | 5,000 |
| 2 | 30 | 7 | 750 | 12 | 8,000 |
| 3 | 60 | 8 | 1,000 | 13 | 12,500 |
| 4 | 150 | 9 | 1,800 | 14 | 20,000 |
| 5 | 300 | 10 | 3,000 | 15 | 32,000 |
| | | | | Boss yard | 50,000 |

The numbers live in `STAGE_POWER` at the top of the layout section of `TheBlockV2.lua`, so they're easy to
tune after playtests.

## Training along the way

All 9 training bags are on the map. Three are at the spawn, and the next one waits in the stage whose gate
asks for exactly its Power. Each new bag works the moment you walk in. Every bag is an aura station (see
`reports/Stations, armory, HUD and guns.md`): its effects grow with the tier.

| Bag | Where | Needs | Power per hit |
|---|---|---|---|
| Tire, Duct Tape, Street | Spawn (TRAIN HERE) | 0 / 50 / 150 | x2 / x3 / x4 |
| Heavy | Stage 6 | 500 | x6 |
| Speed | Stage 8 | 1,000 | x8 |
| Double-End | Stage 10 | 3,000 | x12 |
| Pro | Stage 12 | 8,000 | x18 |
| Gold | Stage 14 | 20,000 | x25 |
| Champ Ring | Boss yard | 50,000 | x40 |

## Getting around

- **Teleports:** past every gate after the first there's a pad back to the spawn and a pad to the furthest stage you've
  opened. The spawn has a FURTHEST pad too.
- **EVOLVE booth:** walk up and press the prompt to equip the best look your Power has unlocked. The prompt
  shows the next look and the Power it needs. When a better look is ready, the guide arrow points at the
  booth ("EVOLVE HERE").

## Hooks for the gameplay that comes next

- **Fight pads:** tagged `HoodFightPad`, with attributes `Fight` (1–15), `Stage` and `District` (1–5). The
  boss pad is `Fight` 16 with `Boss = true`. The same list, in walking order, is in `TheBlockV2.Fights`.
- **Gates:** standard `HoodStageGate` models (`WallId` `HoodW1Stage1` … `HoodW1Stage16`), so StageService,
  the gate client and the teleports all work unchanged.
- **Exports:** `TheBlockV2.StagePower`, `StageLength`, `StageTop(i)` and `RouteTraining` for anything that
  needs the layout.
- **No morph stand:** the map sets `MorphStand = false`; looks are equipped at the EVOLVE booth instead.

## Art that still needs making

The models here are built from parts. The things that need real art (game icon, thumbnails, logo, HUD
icons, fighter outfits, effect textures, shop signs, murals, skybox, loading screen and a few hero models)
are listed with ready-to-paste prompts in the Claude Design brief, "Hood Evolution: Claude Design brief".

## Checked

- **Unit tests:** 53/53 pass. The Stage test checks the 15 fights plus the boss in walking order, that
  every stage needs more Power than the last, and that each route bag is usable as soon as you can enter
  its stage.
- **Integration run:** V2 is active; the 16 gates are in walking order with the Power above. The 9 training
  zones, 16 fight pads, 31 teleport pads, the EVOLVE point and the ring zone are all found. A 1,000-Power
  player is stopped at gate 9 and isn't pushed back at earlier gates.
- **Overlap pass:** a few tiny overlaps are left (roof edges, crate trim, ropes). The banners float on
  purpose.
- **Size:** about 11,100 parts (with the stations and the armory).
