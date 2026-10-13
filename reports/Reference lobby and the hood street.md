# The Block V2: reference lobby and a real hood street (2026-10-03)

The last pass went too far: too many colours, too much going on. This pass rebuilds `TheBlockV2` to match
the screenshots the team picked, then turns the stages into a hood that looks like an actual street.
The first map (`TheBlock` / `SimulatorLobby`) is untouched.

Build it from the Command Bar:

```lua
require(game.ServerStorage.TheBlockV2).Build()
```

`Build` keeps the old copy in `ServerStorage` (`TheBlockV2_Before_<time>`), makes V2 the active map and
applies the `FrontPage` lighting. `SetActive(false)` and `HoodLighting.Restore()` undo both.

## The lobby: copied from the screenshots

| In the screenshots | In V2 |
|---|---|
| Lime studded grass in big checker tiles | Lawn in 8-stud checker tiles, studs on top |
| Stepped brown cliffs with grass tops and blocky trees | 8-stud cliff columns in two alternating browns (the checkered faces), studded on every face. Grass caps overhang each open edge. Heights step unevenly, and trees sit on the ledges |
| Grey studded plaza with chunky diamond-plate trim | Blue-grey 4-stud checker plaza, diamond-plate trim where it meets the grass |
| White arrow trail to the first bag | Chevrons from the spawn to the free Tire Bag |
| Grey truss gallows with a barrel; colour only on the high tiers | Grey truss stations for the first four bags. Purple, cyan, green and gold sets for the last four. Locked ones still go black, like the reference |
| Three-row morph bleacher with cyan pads and price tags | Grey studded stand, 3 × 5 looks on white tiles with cyan glow squares. Labels read price / BUY / +gain |
| "SUPER OP" featured morphs beside the path | Kingpin and The Don, big, on glowing pedestals |
| Leaderboards, World 2 portal, chest, egg on a red pedestal, grey rubble, grass tufts | All present, pulled in close to the spawn |
| See-through pink stage wall: "Stage N / Recommended Power", magenta and yellow pads | Same wall across the street, in the Arcade font. Magenta pad: back to the lobby. Yellow pad: your furthest stage |

The lobby is 144 × 120 studs. The spawn faces the stations, and the Tire Bag is about 40 studs away. The
main walk runs straight into a short cliff canyon, and the Stage 1 wall sits at its end. Through the
wall you can already see the hood.

## The street: an actual hood

Built from `research_notes/Front page feel and gamey stages/hood_games_maps.md`. Those notes cover how
hood games and map kits build streets, real NYC dimensions and a 12-colour palette:

- **Palette:** asphalt, off-white trim, two concretes, red/brown/buff brick, iron, plus three accents
  (deli green, signal red, warm light). Each facade gets one accent at most. The stage wall is the only
  saturated thing in view.
- **Street:** 20-stud road with kerbs, 10-stud sidewalks with joints, a faded centre line, and a
  crosswalk behind every wall.
- **Buildings:** brick walk-ups with sills, lintels, cornices, ACs, fire escapes and water tanks;
  brownstones with stoops; storefronts with gates and awnings. All signs are invented and kid-safe
  (no liquor, lotto, guns or brands).

One block per stage, each named after its wall in `Maps.lua`:

| Stage | Block |
|---|---|
| 1 | The Block: Sunny Deli, a brownstone on moving day, fire escapes, a barbershop, the garden lot with the block's one mural |
| 2 | The Court: a fenced basketball cage with a handball wall, P.S. 48 opposite |
| 3 | Corner-store Avenue: laundromat, cell repair, wing spot, 99¢ store, a bus shelter, a double-parked box truck |
| 4 | Summer Block: porch rowhouses with striped awnings and an open hydrant spraying |
| 5 | Gas & Auto: a gas station with a mini mart; an auto shop and a yard with drums and tyres |
| 6 | Sidewalk-Shed Street: a green shed with posters and a pipe scaffold |
| 7 | Under the El: steel columns and the track overhead, food carts |
| 8 | Block Party: barricades, a DJ table with speakers, warm string lights |
| 9 | The Projects: brick towers on asphalt plazas, benches, a playground |
| 10 | The Station: the Champ Ring in the street, and Juniper St station (World 2, coming soon) |

## Gameplay hooks (unchanged contracts)

- Walls are tagged `HoodStageGate` and carry the same attributes as before (Stage, WallId, Required,
  Reward, LineZ, HalfWidth = 20). `Barrier`, `Status` and `PassFX` are what HoodClient/Stages drives.
- Pads are `HoodTeleport` prompts with targets `Lobby` and `Furthest`. StageService now reads the
  lobby spawn from the map's `LobbySpawn` attribute.
- The lobby still has `Training_<Id>` stations with `TrainingZone`, `Equipment`, `Sign` and HitPoint,
  plus `Morphs/Skin_<Id>` with `Interact` and `ServerLeaderboard`.
- `FrontPage` lighting now has Saturation 0.08 (was 0.25), so the brick doesn't go candy.

## Checked

- Unit tests: 52/52 pass. The Stage test now checks the lobby station spots instead of street segments.
- Integration run of the built map: V2 active, 10 walls in order, 15 morphs, 9 training zones (the
  Tire Bag trains at x2), 20 teleport prompts, leaderboard found.
- Overlap pass: the visible z-fights it found are fixed (kerb edge, stand tiers, a sign band, the el
  columns, a shelter clipping an awning). What's left are hidden back faces and the existing mannequin
  face decals.
- About 11,300 parts in all.

## For Studio

- The renderer used for the previews draws the Arcade font as Arial and studs as round bumps. Studio
  will show the pixel font on the walls.
- If the cliffs or grass read too saturated under your lighting, tweak `P.cliff` / `P.grassA` at the
  top of `TheBlockV2.lua`. The hood palette is the `H` table.
