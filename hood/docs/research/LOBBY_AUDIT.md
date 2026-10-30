# World 1 lobby audit (Oct 27, HEAD 0bf71fdb)

The owner, after playing in Studio: "The layout of the lobby isn't optimal", "It feels way too crowded".
This page only measures and proposes; nothing in the game has changed. The picture is
`lobby_audit_topdown.jpg` in this folder: our hall from above with the roof off, next to `ref_STILL_lobby_topdown_superhero.png`.

How it was measured: TheBlockV2 is built in the offline harness and every part inside the hall's inner walls
(x -86..86, z 6..100, north = -z, map frame) is put on a 1-stud grid. The hall's own shell is left out (walls, pilasters,
floor, roof, lamps, floor markings). "Standing" means a part's top is over 1.3 studs; "deck" means a raised platform
lower than that. The spawn is at (0, 45), facing north to the Stage 1 door (z 6).

## The short answer

- **The amount of open floor is not the main problem.** 54% of our floor is bare. The reference is roughly 55-60%,
  judged by eye (the reference says its spacing is approximate).
- **The problem is where things stand.**
  1. Our zones nearly touch each other: 1 to 4 studs apart, where the reference keeps them 15 to 25 apart.
  2. The north strip at the door is packed. Within 16 studs of the door stand 2 sale pads, the codes booth, the
     group chest, the spin wheel, the door lamps and the ranges' north row, so the aisle to the door is 10 studs wide.
  3. The spawn stands in a 24 x 24 clearing between two raised decks.
  4. The south half of the hall is much emptier (65% bare) than the north half (42%).
- **The view from the spawn is busy.** Everything you see first is on the way to the gate:
  - 8 objects and 7 text boards at eye height;
  - 11 objects and 14 text boards from the follow camera;
  - 8 stations within 35 studs.

  The reference's spawn view (`ref_W01.0`) shows about 6 objects and 3 or 4 world labels, low on the grass, around
  a wide path.
- **There is a lot of small detail:**
  - 3,052 parts;
  - about 95 different text strings (189 text lines, most drawn twice for the outline);
  - 41 lights and 73 particle emitters.

  The reference uses a few big chunky objects.

## Measurements

### Floor

| | sq studs | share of the hall |
|---|---|---|
| Hall, inside the walls | 172 x 94 = 16,168 | 100% |
| Standing objects | 4,395 | 27% |
| Raised decks and platforms | 3,122 | 19% |
| **Bare floor** | | **54%** (lobby_metrics' "empty": 60%) |

By region:

| Region | Bare |
|---|---|
| North half (z 6-53) | 42% |
| South half (z 53-100) | 65% |
| South-east quarter | 67% |
| North strip at the door (z 6-22) | 59% |

Area by zone (standing + deck, sq studs):

| Zone | Standing | Deck | Total | Share of hall |
|---|---|---|---|---|
| Training ranges (9 bays, stand, lane lamps, head stage) | 1,862 | 1,314 | 3,176 | 20% |
| Armory + gun deck (the deck is shared with the head-lane extension) | 1,401 | 1,243 | 2,644 | 16% |
| Shoe boxes + dais | 590 | 99 | 689 | 4% |
| Leaderboards (3) | 200 | 22 | 222 | 1.4% |
| World 2 portal | 180 | 29 | 209 | 1.3% |
| Sale pads (2) | 75 | 178 | 253 | 1.6% |
| Codes booth + group chest | 52 | 56 | 108 | 0.7% |
| Spin wheel | 35 | 29 | 64 | 0.4% |
| Scenery in the hall (crates, hydrant, trees, door lamps) | 152 | 0 | 152 | 0.9% |

### What stands where now (4 studs per character; north = the door at the top)

```
  x -86 ................................. 0 ................................. 86
  .................rrxx.xxrr....N............   z 6   <- door: sale pads r/R, lamps x, chest N
  ...........nNn...rRR...RRr....NN.SS........         codes n/N, spin S: one line along the north wall
  ....tTTttTttTTtTTtRR...RRr....Nn.SS........
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....         T ranges on deck t, A armory on deck d
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  TTTTTTTTTTTTTTtTTT.......dAAAAAAAAdddd.....         head lane on the west wall
  TTTTTTtttttttttttd.......dAAAAAAAAdddd.....   z 45  <- spawn at the middle, between the two decks
  TTTTTTtttttttttttd.......dAAAAAAAAdddd.....
  TTTTTTTTTTTTTTtTTT.......dAAAAAAAAdddd.....
  .x..tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  .x..tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  ....tTTTTTTTTTTTTT.......dAAAAAAAAdddd.....
  ....tTTttTttTTtTTt.........................
  ...........WWW.............................         W portal
  ...........WWWW............................
  ...........WWWW..BBBBBBBBB.............L...         B shoe boxes on the dais, L leaderboards
  ...........WWWW.BBBBBBBBBBBLLL..LLL...LL...
  ...............BBBBBBBBBBBBLL...LLL...LL...
  ...............bBBBBBBBBBBBb..........L....
  .x...............BBBBBBBBB..x............x.
  ...........................................   z 100
```

### The walk from the spawn to the door

| Stretch | Clear width (studs) |
|---|---|
| Door mouth to z 22 | 10 (x -5..5, between the sale pads) |
| z 22-66 | 26-28 (between the training deck and the gun deck) |
| z 70-78 | 114-122 (open) |

The biggest clear square around the spawn is 24 x 24.

### Gaps between zones

The smallest bare gap between two zones, in studs. The reference keeps about 15-25, with a walk between its blocks.

| Studs | Zone pairs |
|---|---|
| 1 | armory deck to armory; deck to sale pads; deck to spin; deck to ranges; ranges to sale pads; ranges to the codes booth; ranges to the portal; sale pads to the door lamps; leaderboards to shoe boxes |
| 2 | deck to the north bays; deck to scenery |
| 3-4 | armory to the north bays, sale pads and spin; shoe boxes to the portal; ranges to scenery |
| 5-13 | everything else |

### Distance from the spawn

| Station | Studs |
|---|---|
| Armory | 19 |
| Range Pro | 25 |
| Range Starter | 28 |
| Sale pads | 34 |
| Shoe boxes (front) | 35 |
| Range Tape | 37 |
| North door | 39 |
| Range Heavy | 39 |
| Shoe boxes (each) | 44-46 |
| Codes | 48 |
| Leaderboard 1 | 49 |
| Range Street | 49 |
| World 2 portal | 50 |
| Group chest | 50 |
| Range Speed | 51 |
| Spin wheel | 59 |
| Range Gold | 62 |
| Leaderboard 2 | 63 |
| Range DoubleEnd | 63 |
| Range Head | 75 |
| Leaderboard 3 | 81 |

Stations closer than 12 studs to each other:
- the 4 shoe boxes, 10 apart (fine: one group);
- Leaderboard 1 and Shoe box 1, 11 apart (two different zones touching).

### Straight walks from the spawn that hit something

| Destination | Blocked by |
|---|---|
| Leaderboards 2 and 3 | the armory |
| World 2 portal | Range Pro |
| Ranges Gold, Street, Heavy | the RangeStand lane lamps (posts, caps, feet) and the nearer bays |
| Range Head | its stage and steps |
| Ranges DoubleEnd, Speed, Tape | the nearer bays |
| Shoe boxes | the dais steps (expected: it is a dais) |

### In view from the spawn, facing north to the gate

- **At eye height (5 up, 70° vertical field of view):** 8 objects (3 north bays, 4 sale-pad parts, 1 range) and 7 text boards.
- **From the follow camera (12 back, 9 up):** 11 objects (2 armory, 3 north bays, 4 sale-pad parts, 2 range) and 14 text boards.
- **lobby_metrics:** 2 labels drawn, 1 readable.
- **What the camera sees around the gate:** two sale pads with box models ("NEW", "3 PAIRS") flanking the gate, both chests, two lamp posts, the hazard barrier with the padlock, the codes booth with balloons, the first range's table of bottles, and the armory's stairs with a gun and the green "EQUIPPED" pad. The whole middle distance is full.

### Text in the hall

The text strings, most drawn twice (outline copies):
- 16 "Locked" and 9 "LOCKED", so every locked bay says it 2-3 times;
- 26 bay labels ("x1 Power" … "x32 Power", "1x" … "500x Power", "+48%" …);
- prices;
- 3 "Be the first to train!";
- 3 "BUSINESS DISTRICT";
- "BEST!", "NEW", "3 PAIRS", "TRAIN", "STAGE", "World 2";
- 6 "ONLY" ("ONLY 199", "ONLY 1,499").

Also check: **6 labels say "Label"**, the default text of an empty Roblox label. If any of them can show, it is a bug.

## What to remove, merge or move (worst first)

The floor gains are estimates in sq studs from the zone areas above.

1. **Clear the door's mouth (the focal point).** This has the biggest effect on what the player sees first.
   - Move the 2 sale pads out of the door's mouth. The owner's rule is "2 Robux pads by spawn", so they stay near the spawn, but beside the crossing rather than flanking the gate (see question A below).
   - Move the codes booth, group chest and spin wheel off the door line and well to the sides of the spine, each at least 25 studs from it. The reference keeps one chest north-west and two north-east.
   - Remove the 2 door lamp posts.
   - Gain: the door aisle goes from 10 studs to the full mouth (48), and the north strip from 59% to about 90% bare (about +400 in that strip). Objects seen from the spawn drop from 8 to about 3 at eye height.
2. **Space the zones out: at least 10 studs (a walk's width) between any two, now 1-4.**
   - Shift the crossing, the spawn and both decks 5 south (CrossZ 45 to 50). An open lawn of about 19 studs then opens between the door wall and the zones, as in the reference's band before the exit.
   - The shoe-box dais goes back against the south wall (front at about z 85).
   - Same floor, but no zone touches another. This is the "too crowded" feeling.
3. **Trim the gun deck to hug the armory.**
   - The deck runs x 14..64 for an armory of x 19..49. Its east 12 studs and the far shop end leave a raised slab that touches the north bays and the spin wheel.
   - Bring the deck in to about x 16..52, like the training deck's 2.2-stud rim, and the armory's scale from 1.1 to 1.0.
   - Gain: about +700. The spine corridor can widen by moving the armory 4-5 east into the freed space.
4. **Remove the RangeStand lane lamps** (posts, caps, bands, feet between the bays).
   - Their floor area is small, but they are what blocks the straight walks to three bays and they add a forest of verticals at eye height.
   - Gain: about +60, a big sightline gain.
5. **Put the leaderboards and the boss board in one column against the east wall**, facing the centre.
   - Now: an angled row from x 21 to 74 that touches the shoe boxes (1 stud) and sits behind the armory.
   - Gain: about +80 (no angled waste), and the south-east becomes one open field.
6. **Move the World 2 portal into the south-west corner beside the dais** (about x -60..-44, z 82..98), facing the crossing.
   - It now touches the ranges (1 stud), and Range Pro blocks the walk to it. In the reference it sits alone in the south-west.
7. **Merge the north reward stations' plinths.**
   - Codes, group chest and spin wheel stand on 3 separate plinths. Put the codes booth and the spin wheel on one plinth (north-east), and the group chest alone (north-west).
   - Gain: about +50.
8. **Remove the scenery inside the hall** (crates, hydrant, small trees). Props stay outside and along the walls only.
   - Gain: about +150.
9. **Cut the text and the sparkle.**
   - One padlock with the needed rebirths per locked bay, instead of 2-3 "Locked" labels.
   - No "ONLY" before prices. This is kid-safe wording (no pressure) and matches the rest of the game's honesty rules.
   - Fix or hide the 6 "Label" texts.
   - Particle emitters from 73 to about 20, in view only on the 2-3 things that should call you (the gate, the next goal).
   - Lights from 41 to about 20.
   - Not floor, but a large part of the busy look.

**Totals for options 1-8 inside today's hall:**
- floor gain about +1,000 sq studs;
- bare floor from 54% to about 60%;
- every zone at least 10 studs from the next;
- the north band and the door clear.

**Option B, the bigger fix:** make the hall 16 studs deeper (172 x 110, about +2,750 sq studs).
- Every gap can then be the reference's 15-25 studs, with about 66% bare floor.
- Two of the hall's files change: the shell's file (`e4_warehouse.lua`) and the plaza's file (`e3_plaza.lua`, `Lobby.Bounds`).
- After that, block_reach and integ_lobby need a re-run.
- The farthest leaderboard walk grows from 81 to about 90 studs.

What it can't fix (owner rules, so said honestly): the hall has walls and a closed roof, where the reference is open
sky over a ring of cliffs. That enclosure will always read a bit fuller than the reference at eye height. Keeping the
wall fields calm (fewer window panels and posters) is the only lever there.

## Proposed layout (option A: today's hall, 172 x 94; 4 studs per character)

```
  x -86 ................................. 0 ................................. 86
  ===================== [ STAGE 1 DOOR ] ======================  z 6
  .     (G)                    |    |                 [C  S]    .   G group chest (NW), C codes + S spin on one plinth (NE)
  .                            |    |                           .   open lawn before the door, nothing in the mouth
  .                            |    |                           .
  .                            |    |                           .   z 25: the zones start
  .  [T][T][T][T]              |    |      [  ARMORY   ]   [L]  .
  .  [T][T][T][T]              |    |      [  on a deck ]  [L]  .   L 3 leaderboards + boss board in a column
  .[H] = aisle ================+ X  +===== [  that hugs ]  [L]  .     on the east wall, facing the centre
  .  [T][T][T][T]          $   | SP |   $  [  it        ]  [B]  .   $ the 2 Robux pads by spawn, at the crossing
  .  [T][T][T][T]              |    |      [            ]       .
  .                            |    |                           .   z 75: the zones end
  .                            |    |                           .
  .   (portal)        [  shoe box dais : 4 boxes  ]             .   z 85-98: dais against the south wall,
  ================================================================   z 100   portal SW beside it
```

- Spawn (SP) at (0, 53), facing north. The crossing (X) at z 50; the spine 10 wide.
- Training: the same 2 rows of 4 full-length bays and the head lane, moved 5 south. No lane lamps.
- Armory: about 4 east, on a trimmed deck.
- The reference's 4 zones on 4 platforms off one cross path: training W (ours), evolutions E (our armory), eggs S
  (our shoe boxes), portal SW, leaderboards SE, chests N.

## Questions for the owner (one at a time, recommended first)

- **A. Where do the 2 Robux pads by spawn go?**
  1. Beside the crossing, low pads with no tall models, 8-10 studs from the spawn. (recommended; like the reference's "MOST OP!" pad)
  2. Behind the spawn, either side of the south walk.
  3. Only in the Store screen.
- **B. Keep today's hall size, or make it 16 studs deeper for more space between zones?**
  1. Deeper. (recommended if "still crowded" after option A)
  2. Keep the size.

## Where it's built (for whoever makes the change)

- `hood/tools/map/pieces/e3_plaza.lua`: the layout knobs (CrossZ, SpawnAt, PlazaGap, ArmoryX/Scale, the dais position, PortalPath, Bounds, the sale spots and north stations' positions).
- `hood/tools/map/pieces/e2_lobby.lua`: RangeStand (lane lamps), NorthBays, ShoeBoxDais, World2Corner, BoardCorner.
- `hood/tools/map/pieces/e4_warehouse.lua`: the hall's shell, if it grows.
- Then run `sh hood/tools/map/assemble.sh`, rebuild the place, and run all checks. integ_lobby, block_reach, place_gates, first30 and core_loop walk the lobby.

## After lobby round 1 (built on branch lobby-r1)

Changes 1-9 and the deeper hall (option B) are built in both worlds, because World 2's lobby shares the plan. The
picture is `hood/art/renders/lobby-r1/lobby_r1_vs_refs.jpg`: our spawn view (roof on) next to `ref_W01.0`, and our
top-down next to the reference top-down.

What changed from the proposal:
- The leaderboards stand in a short diagonal in the south-east, not a column on the east wall. On the east wall the armory would hide them from the spawn.
- The "Locked" labels stay. Each bay shows one, counted twice because of its outline copy, and it is the reference's lane style.
- The themed bays keep their weather effects.
- The training block moved 4 studs west so the Robux pads fit beside the crossing. The head lane's glass dome is now 10 studs long instead of 14, so it stays inside the west wall.

| | Before | After |
|---|---|---|
| Hall inside | 172 x 94 | 172 x 110 |
| Bare floor | 54% | 66% |
| Smallest gap between two zones | 1-4 studs | 10-11 studs |
| Gap from the Robux pads to the decks beside them | | 2-4 studs (they sit beside the crossing on purpose) |
| Door's mouth | 10 wide (sale pads, lamps) | empty, 48 wide |
| Spawn to the gate | 45 | 58 |
| Seen from the spawn at eye height: objects / text boards | 8 / 7 | 4 / 5 (the two Robux pads) |
| Seen from the follow camera: objects / text boards | 11 / 14 | 8 / 11 |
| Parts in the lobby (shell left out) | 3,052 | 2,965 |
| Text lines (most drawn twice for the outline) | 189 | 177 |
| Particle emitters | 73 | 52 |
| Lights | 41 | 34 |

What made the text-line count drop: the 6 "Label" boards were fixed, "ONLY" is gone from the prices in the world, and the lane lamps were removed.

Still worse than the reference:
- Straight walks from the spawn to leaderboards 2 and 3 still clip the armory's south-west corner. The south walk and the boards' path go round it.
- The Robux pads sit 2-4 studs from the decks beside them.
- The head lane's stage stands 0.4 studs off the west wall.
- The hall's walls and roof close in the view, where the reference has open sky.
