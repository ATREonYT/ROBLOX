# How the +1 soldier game in your video is built (2026-10-08)

Notes from the 53-second video you sent of another +1 game, which averages about 5,000 players. They cover how its map is laid out, how its systems work and what makes it look well made.

We take its craft, not its soldier theme: ours stays a hood game.

## 1. Map layout: one straight line
- **One spine.** The lobby is an outdoor plaza. A wide lavender studded walkway runs straight from the spawn to the Stage 1 gate, and every stage continues that same line.
  - From the spawn you can already see the Stage 1 gate at the end of the path, with its floating "STAGE 1 / Recommended Power: 0".
  - Short cross paths branch off the spine to each activity.
- **Spawn.** A grey studded square on the spine, with a dark crack/splat decal in its centre ("you landed here"). It is small and flat; there is no tower.
- **Between the paths:** bright lime studded grass.
- **The edge:** orange-brown studded cliffs with grass on top and blocky trees surround the plaza. You never see a void or a flat wall.
- **Activities, each a short walk off the spine, all visible from it:**
  - **Training lanes** (§3), to one side of the spine near the spawn.
  - **Gun stand** (§4): a stepped stand facing the spine.
  - **Egg dais:** a row of egg pedestals on a side path (Basic 10 wins, Basket 150, Cactus 1.5K, Ice 15K; plus a robux Aura Egg).
  - **Limited item:** one pedestal with a huge floating "OG Hyperlaser 0/100 left" and "ALWAYS 125% BETTER" text, plus a robux price.
  - **World 2 portal** in a corner with "BEAT WORLD 1 FIRST".
  - **Boards along the cliff foot:** "UPDATE + ADMIN ABUSE STARTS IN 1d 22h", "LIKE THE GAME! new code at 15K likes", codes, a group-reward chest, leaderboards.
- **Every stage is one short arena between two gates,** straight ahead.
  - **Ground:** a dark orange dirt path studded down the middle, and sandy studded ground beside it.
  - **Walls:** sandstone brick with grey studded concrete pillars.
  - **Props in small clusters at the sides,** never on the path: sandbags, barbed wire, watchtowers on truss legs, burning barrels, blocky cacti, palm trees, red/white barriers.
  - **Length:** about one screen long, so the next gate is always in view.

## 2. Gates and their pads (every stage)
- **The gate:**
  - two grey studded concrete pillars, each with a column of square holes;
  - a yellow/black hazard-striped beam across the top;
  - a hazard-striped barrier with a sign in the opening while closed.
- **Floating text in the opening:**
  - "STAGE N" in big white letters with a thick dark outline;
  - "Recommended" and "Power: X" in cyan under it.
- **While a wave is alive,** the sign in the gate reads "Defeat the wave first".
- **Two pads on the ground just before the gate:**
  - **Pink pad, left:** "+2 WINS / 2x Wins" (needs the gamepass).
  - **Yellow pad, right:** "+1 WIN / Return" (claim a win and go back to the lobby).
  - So every cleared stage is a natural "bank it and go home" point.

## 3. Training (their shooting range): a row of lanes
- **Lanes:** raised terracotta studded platforms, side by side, with ragged stepped (pixel) edges.
- **Each lane:**
  - walled by stacked sandbags at the sides and the back;
  - a target post with a red/white bullseye at the far end, on a round sandy base;
  - grass tufts and a little cactus on the lane.
- **You stand at the near end and shoot the target.**
  - Each shot pops "+N" (the gun's power) at the target.
  - An "Auto" toggle appears while you are in a lane.
- **Label over each lane, high up:**
  - "Unlocked" (green) or "Locked" (red), small;
  - the requirement (rebirth icon + number);
  - "Nx Power" big, in a colour per tier: 1x white, 20x purple, 35x red, 50x and 250x blue; one lane costs robux ("ONLY 699").
- **Locked lanes render as pure black silhouettes.** The label stays readable over them. Locked and unlocked read instantly from far away.

## 4. The gun stand (their gun shop)
- **The stand:** a wide stepped stand of grey studded treads facing the walkway, with stairs at both ends.
- **Pads:** each tread carries a row of 5 coloured studded pads (yellow, green, cyan, red, pink…) with white rims.
- **One gun per pad,** shown in the hands of a character standing on it.
- **Label over each pad:**
  - the state word, small: Equipped (green), Owned (orange), Buy (blue), Locked (red);
  - "+N/Power" big in white;
  - the price with a trophy icon (bought with Wins).
- **Step on a pad** and an "E Equip" / "Buy" prompt appears.
- **Prices climb fast:** 150, 500, 1.6K, 4.5K, 12.5K, 40K, 100K, 300K… Power per shot: +3, +6, +10, +20, +40, +80, +120, +300, +800, +2.2K, +6.4K, +19K, +50K.

## 5. Economy and loop
- **Power** (bicep icon) is the main number. It goes up with every shot: the gun's +N × the lane's multiplier.
- **Wins** (trophy) come from clearing stages (+1 at the yellow pad, +2 with the gamepass). Wins buy guns and hatch eggs, and some eggs need a minimum ("You need 10 Wins to hatch this!", "NOT ENOUGH WINS").
- **Rebirths** unlock the better training lanes.
- **Level bar** ("Level 2 89/100") along the bottom centre.
- **Stages:**
  - Walk in and a wave of enemies stands on the path, each with a name tag and a red HP bar ("Guard 1 40/40", "120/120").
  - The top centre shows a skull counter "3 LEFT".
  - Clear the wave and the next gate opens.
  - Recommended Power rises per stage (0, 250, 1.5K…).
- **Goals chain** (top centre, big text):
  - "GOAL DONE! Wins Potion", then "NEXT GOAL: Hatch an egg - Eggs are in the lobby";
  - every goal names a reward AND where to go next.
- **Timed events:**
  - "Next GUNSHIP boss fight in 3:23 [SKIP]" on the top bar: a server-wide boss every few minutes;
  - "FREE AUTOWIN! Try AUTOWIN free for 15 min!";
  - "UPDATE + ADMIN ABUSE" countdown.
- **Monetisation everywhere, but tidy:**
  - right column: x2 Wins / x2 Power / x2 Speed gamepass buttons with "ONLY ⏣79/3/99";
  - bottom: +20K/+200K/+2M Power dev products;
  - Starter Pack, Playtime Rewards, a spin wheel ("Ready x1"), Missions 0/3, Friend Boost +0%, Recruit, Autowin timer;
  - left column: Shop, Pets, Rebirth (with a % ring), Items, Skins.

## 6. Graphics: what makes it look well made
1. **Studs on every horizontal surface and most walls:** paths, grass, dirt, cliffs, treads, pads, sandbags' bases. The stud grid gives every surface texture and scale for free.
2. **Few, saturated base colours, each in two or three shades:**
   - path lavender with a darker lavender edge;
   - grass lime with darker clumps;
   - cliffs orange-brown with a darker band and grass caps;
   - pads in pure primaries with white rims.
3. **Edges are always finished:** rims, kerbs, nosings, caps and pillar caps. No surface just stops.
4. **Chunky low-poly props built from stacked boxes,** with a clear silhouette (cactus, palm, watchtower, sandbags, barrel), placed in clusters of 2–5 at the sides.
5. **Lighting:**
   - bright sun from one side, so one side of every object is lit and the other in shade;
   - real soft shadows on the ground;
   - a blue sky with clouds;
   - light bloom on neon and pads only.
6. **Floating text is part of the look:**
   - thick dark outline;
   - one colour per meaning (green unlocked, red locked, cyan recommended, white numbers);
   - big, so it reads from across the plaza.
7. **Density:** every screen has 3–5 points of interest, and nothing is empty. Yet the walkway stays clear, so the route always reads.

## 7. What we take for the hood game (not the soldiers)
- **Keep:** our own theme. Hood characters, hood ranges, hood streets.
- **Take:**
  - the straight spine and the always-visible next goal;
  - the finished edges and stud density;
  - the two- and three-shade colour blocks;
  - side-of-path prop clusters;
  - the side-lit sunny lighting with shadows;
  - the label style (state word, big "xN Power", price);
  - locked stations as black silhouettes;
  - the "+1 WIN / Return" style pads at gates;
  - the goal chain that names the next place to go;
  - "N LEFT"-style progress counters.
- **Possible later features** (their mechanics, the user decides):
  - **Waves of opponents in stages:** kid-safe hood version, e.g. cardboard cut-out targets or rival crew mannequins that pop up, never real people.
  - **Win-claim pads** at each gate.
  - **A goal chain.**
  - **A timed boss event.**
  - **A limited item pedestal.**

## Frames
The montages in `reports/video_notes/` show each part:
- `hall_flow.jpg`: the lobby;
- `range_frames.jpg`: the gun stand;
- `train_flow.jpg`: the training lanes;
- `stage_flow.jpg`: gates and stages;
- `more_flow.jpg`: eggs, the limited item and goals.
