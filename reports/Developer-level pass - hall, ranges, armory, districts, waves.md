# Developer-level pass: hall, ranges, armory, districts, target waves (2026-10-08)

## What you asked for
- **Graphics:** they looked "way below average", so the brief was to study the references' shades and detail until the builds reach developer level.
- **Hood, not soldiers:** the game stays hood-themed. From the soldier game we take how it's built, how its map is laid out and how it operates.
- **Ranges and armory:** bring back the themed ranges, laid out flat rather than going up, and put the armory where it belongs.
- **Shoe boxes:** leave room at the back for them.
- **Your production spec:**
  - analyse the references;
  - audit the build;
  - set one art direction;
  - finish Stage 1 completely before repeating it;
  - give every area its own identity.

## What changed

| Area | Now |
|---|---|
| **Hall** | Shell redone in 2–3 tones with finished edges: windows set back into the wall with thick frames and sills, layered pillars with the neon channel, cornices, girders, panels with a checker pattern and the cyan outline. The spawn is a small square facing the Stage 1 door, and gate 1's text shows through the door. Boards along the walls: UPDATE SOON (codes), LIKE THE GAME (group-reward chest). |
| **Ranges** | The 8 themed lanes are back (stone, red, lava, arcane, shadow, frost, toxic, gold), now in one flat row on the left side as in the soldier game. The FREE lane is nearest the exit. Each label shows Unlocked/Locked, what it needs and a big "xN Power". Locked lanes go fully black. |
| **Armory** | On the stepped stand on the right side, where the soldier game puts its guns. Guns sit in two tiers of display bays (pegboard and a roller shutter) on layered hex pads. Each label shows the name, "xN Power", then the price or BUY / OWNED / EQUIPPED. You buy or equip by stepping onto the pad. |
| **Shoe boxes** | A finished dais at the back centre with 8 pedestals, kept clear for the coming feature. |
| **Boosts** | The gamepass pads have moved to the back-left corner under a BOOSTS sign. |
| **Streets** | Five districts that read differently with every sign hidden: The Block (1–3), Corner Shop (4–6), The Alley (7–9), The Courts (10–12), The Yards (13–15). Stage 1 was finished first, with a family of four different houses. |
| **Gates** | Studded concrete pillars, a hazard-striped beam and the pink haze wall from your street picture. Only your next gate shows its text. Pads in front: LOBBY (return) and FURTHEST. |
| **Target waves** (from the soldier game, kid-safe) | Each stage has a set of cartoon targets: boards, cans, cones, boomboxes, drums, signs, crates, tyres. Each has a health bar, and the top of the screen shows "🎯 N LEFT". The next gate reads "Clear the targets first" until the wave is down. Every district has its own set-up, such as the side-yard plywood range, crates outside the corner store, a plank over an alley dumpster, the courts' team bench and the loading dock. |
| **Goal chain** | 15 goals, from "Shoot at the FREE range" to "Clear the Boss Yard". Each shows "GOAL DONE!" and "NEXT GOAL: … – where to go" and pays a small Cash reward. |
| **Lighting** | New default preset, **HoodSun**: a side-lit afternoon sun with soft shadows, clouds and gentle bloom. It was tuned with a new preview renderer that was checked against real Roblox screenshots. |

## Checked
- **Unit tests:** 100/100, including 17 new ones for waves and goals.
- **Map check:**
  - 16 gates in order, 31 teleports, 8 range zones;
  - the spawn works;
  - a 1,000-Power player who has cleared the waves stops at gate 9.
- **Targets:** every one stands in its own stage, off the road, and clear of the street's buildings and props.
- **On foot:** every range, gun point, door and pad is reachable from the spawn, and no gap lets you walk round a gate.
- **Real scripts in the harness:**
  - **Armory:** BUY / OWNED / EQUIPPED, buying and equipping.
  - **Gates:** shut, "Clear the targets first", ready and cleared.
  - **Waves and goals:** shots, health, clearing, rewards and the goal moment.
- **Size:** the map is about 23,700 parts.

## Open it in Studio
- Open `hood/places/HoodEvolution.rbxl` (rebuilt with this pass) and press Play.
- Or, with Rojo, run `require(game.ServerStorage.TheBlockV2).Build()` in the Command Bar.

## Worth a look in Studio
The previews are close to Roblox, but they can't show:
- the real sky and clouds;
- the gate haze turning mint when you can pass;
- the floating "+N" numbers;
- the target health bars dropping;
- the GOAL DONE moment.

## Still to improve
- The Yards and Courts are thinner on detail than The Block.
- The containers are plain ribbed boxes.
- The three stages in each district share their main feature.
- Stages are 64 studs long, so the far end of a street looks closer than in your picture.
