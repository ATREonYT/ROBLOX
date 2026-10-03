# +1 Hood Evolution, World 1: the map (2026-10-03)

`TheBlockV2` is rebuilt from the team's concept sheet ("+1 Hood Evolution, World 1"). This is map only:
the fight, boss and evolve systems come next. The first map (`TheBlock` / `SimulatorLobby`) is untouched.

```lua
require(game.ServerStorage.TheBlockV2).Build()
```

`Build` keeps the old copy in `ServerStorage` (`TheBlockV2_Before_<time>`), makes V2 the active map and
applies the `FrontPage` lighting. `SetActive(false)` and `HoodLighting.Restore()` undo both.

## Layout (spawn to boss)

| Area | What's there |
|---|---|
| Spawn plaza | Blue spawn circle. TRAIN HERE bar with red, blue and yellow bags; these are the Tire, Duct Tape and Street training stations. EVOLVE booth with a glowing doorway and a floating arrow. Benches, lanterns, hedges, trees |
| District 1 · 1–3 | Red brick block, dumpster and trash bags, crates on pallets |
| District 2 · 4–6 | Barber (striped awning, turning pole) facing the Grocery (green and yellow awning, produce stand), plus a laundry |
| District 3 · 7–9 | Orange basketball court across the whole walk: lines, two hoops, chain-link at both ends |
| District 4 · 10–12 | Tan apartment blocks with balconies |
| District 5 · 13–15 | Tan apartments, then the chain-link fence into the boss yard |
| Boss yard | Blue warehouse with a roll-up door, stacked shipping containers, crates, the BOSS pad with its green ring |
| Outside | Low wall, ring road with dashed lines, parked cars, trees |

- **Pads and banners:** every district has three glowing fight pads (red, blue, green, numbered) and a
  floating banner ("1 - 3" …).
- **One look per district:** each group of three stages shares one look, as asked.
- **Building rows:** buildings run shoulder to shoulder down both sides, fronts to the middle, with no
  gaps.

## Hooks for the gameplay that comes next

- **Fight pads:** tagged `HoodFightPad`, with attributes `Fight` (1–15) and `District` (1–5). The boss pad
  is `Fight` 16 with `Boss = true`. The same list, in walking order, is in `TheBlockV2.Fights`.
- **EVOLVE booth:** tagged `HoodEvolve`.
- **TRAIN HERE bags:** work with the existing training system (zones, lock silhouettes, punch hit
  points). The other six training stations aren't in this layout.
- **No stage walls:** progression will come from the fights, so StageService and HoodClient/Stages find
  no gates and stay idle.
- **No morph stand:** the map sets `MorphStand = false`. The lobby client then skips the stand prompts
  but keeps the HUD and training. Equipping looks will come back through the EVOLVE booth.

## Checked

- **Unit tests:** 52/52 pass. The Stage test now checks the 15 fights plus the boss in walking order.
- **Integration run:** V2 is active, the spawn is enabled, all 16 pads are tagged, and the booth is
  tagged. The Tire Bag trains at x2, 26 studs from spawn.
- **Overlap pass:** the containers no longer touch their neighbours. What's left are hidden back faces
  and the floating banners, which float on purpose.
- **Size:** about 4,400 parts.
