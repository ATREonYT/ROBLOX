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

## How +1 Cannon Evolution does it
- `cannon-evolution/src/tools/BuildWorld1.lua`:
  - `LanePlatform` is the stud platform;
  - `tierLook()` turns one base colour into floor, rim, track, pad and accent, with flags for glow,
    shine, sparkle and black;
  - `makeBooth()` builds the one lane model;
  - every lane has the same length, so the target is the same distance away.
- `cannon-evolution/src/tools/BuildRebirthSigns.lua` builds the label.
- `cannon-evolution/src/client/GameClient/Effects.lua` sets LOCKED/UNLOCKED for each player.
- The cannon on each lane still differs per tier on purpose, because the cannons are the upgrades.
- Picture: `cannon-evolution/previews/lanes-vs-stone-skipping.jpg`.
