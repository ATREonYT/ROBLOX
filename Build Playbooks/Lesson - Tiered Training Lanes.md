# Lesson: tiered training lanes (Oct 31, 2026)

Alex compared Stone Skipping's training lanes with ours in +1 Cannon Evolution. The stone lanes looked
better because they follow a few rules every time. Use these rules for any row of tiered stations
(training lanes, upgrade pads, worlds, zones).

## The rules
1. **One shape, cloned.** Build one lane model and clone it for every tier. Only the colour and the
   effects change, so the eye reads one system with tiers, not five separate things.
2. **The whole lane is the tier colour.** The floor is the tier colour, the rim a darker shade of it
   and a centre track a lighter tint. Avoid neutral wood with a thin coloured outline: from across
   the map only the colour tells the tiers apart.
3. **One label per lane, in the same spot.** Use one BillboardGui over each lane, the same size and
   height on every lane, with three lines stacked the same way:
   - a dark pill with an icon and the cost;
   - UNLOCKED in green or LOCKED in red, set for each player;
   - the reward, big ("10x SKILL", "5x POWER").
   Size the lines like the reference: the pill nearly as tall as the reward line, LOCKED about two
   thirds of it. Never use floating tiles or extra tags at different heights; they overlap.
4. **Less clutter.** Put the lanes on one open stud platform with clean gaps between them, and use a
   raised rim instead of ropes, posts and fences. Keep props around the edges.
5. **Higher tiers look fancier.** Keep tiers 1 and 2 plain, then add glow, then sparkles and shine.
   Give the last tier a black floor with neon lines. Sparkles stay soft (no flashing, at most 1
   flash per second).
6. **Side by side, facing you.** The lanes form a parallel row, all starting at the same line, so a
   player can compare every tier at once. Never stack them diagonally, where back lanes hide behind
   front ones.

## Round two: why ours still looked worse, and the fix (Oct 31)
Following the six rules was not enough. Alex said the lanes "still don't look as good", so we compared
them frame by frame with Stone Skipping. These were the real gaps:
- **Tall things in the lane.** A big dark cannon on a plinth and a standing target on legs filled every
  lane. The reference lane has nothing tall in it. The fix was to set the cannon low on the start pad, with
  no plinth and less than half the lane's inner width, and make the target a bullseye raft floating flat
  at the far end, leaning back 25 degrees towards the cannon.
- **No water.** Each reference lane is mostly a pool of light, bright water, from rim to rim. Ours was one
  flat plastic slab with a thin pale strip. The fix was a recessed pool that fills the lane from the
  cannon's nose to the far rim, with 2 lily pads.
  - Water must stay watery: light cyan to blue, leaning to the lane's hue only where it still looks like
    water (mint for green, violet for the black VIP lane).
  - Yellow or orange water looked like juice, and see-through Glass over a dark bed looked grey.
- **Stubby lanes, thin gaps.** Make lanes about 3 times longer than wide, with a walkway between them
  about half a lane wide.
- **The walkway colour has to contrast with every lane.** Our gold and orange lanes vanished into sand.
  The reference uses lavender; we used cool light stone (Alex wants the pirate look, not lavender).
- **The start pad is its own thing.** It is raised, tiled, a shade darker, with white L marks on the
  corners.
- **The rim is built from bricks.** Use segments about 4 studs long in two shades, with studs on top.
- **Lighting.** A late-afternoon sun threw long dark shadows over everything. Cartoony lighting is a high
  sun (ClockTime about 14), no cast shadows (GlobalShadows off), a bright warm OutdoorAmbient and mild
  saturation. Phones at low quality show no shadows anyway.
- **The label's line sizes.** The pill is about as wide as the label and LOCKED is about 55% of the power
  line's height.

## How +1 Cannon Evolution does it
- `cannon-evolution/src/tools/BuildWorld1.lua`:
  - `LanePlatform` is the stud platform;
  - `tierLook()` turns one base colour into floor, rim, track, pad and accent, with flags for glow,
    shine, sparkle and black;
  - `makeBooth()` builds the one lane model;
  - every lane has the same length, so the target is the same distance away.
- `cannon-evolution/src/tools/BuildRebirthSigns.lua` builds the label.
- `cannon-evolution/src/tools/BuildLighting.lua` sets the cartoony lighting.
- `cannon-evolution/src/client/GameClient/Effects.lua` sets LOCKED/UNLOCKED for each player.
- The cannon on each lane still differs per tier on purpose, because the cannons are the upgrades.
- Picture: `cannon-evolution/previews/lanes-vs-stone-skipping.jpg`.
