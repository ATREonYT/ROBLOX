# Lobby and map polish: the same style, a notch calmer (2026-10-08)

You asked for four things:
- keep the colours and the low-poly simulator style;
- remove the yellow lines and floor clutter;
- make the warehouse grey;
- rebuild the portals and objects so they look designed, the way other games frame them, instead of quickly made.

That is what this pass does.

A short-lived "calm" version (beige hall, muted streets, a dark armory showroom) was rolled back after you said it looked more AI-made.

## How it was done
1. **Research.** A research agent studied how Pet Simulator 99, Bee Swarm, Muscle Legends, Arm Wrestle Sim, Strongman Sim, Legends of Speed, Anime Defenders, Grow a Garden and Steal a Brainrot build their pieces:
   - portals, teleport pads and gates;
   - spawn points, shop pads and leaderboards;
   - reward chests and signs.

   It turned that into part-by-part low-poly recipes and a 10-point checklist: silhouette, layering, edge trim, one hue in three tones, framing, controlled glow, framed text, clear state, chunky parts, grounded and themed.
2. **Four builders worked at the same time:**
   - the hall and its objects;
   - portals and gates;
   - streets;
   - armory and ranges.
3. **Fresh critic agents** compared each round with the old look, the rejected calm look and the checklist. They also measured how loud the colours are on screen.
4. **Three rounds** in total.

## What changed

| Area | Now |
|---|---|
| **Warehouse** | **Shell:** floor, walkway, panels, walls and steel are now clean greys; the lavender, aqua and navy are gone, and brick and glass stay.<br>**Kept:** the range terrace is brick red again and the crane is grey. |
| **Floor clutter** | **Removed:** yellow safety lines, hazard collars and stripes, door tiles, floor chevrons, neon stair edges, the cyan panel outlines and the flat yellow pad.<br>**Instead:** panels sit behind a white kerb, and stairs have white lips. |
| **Colour** | **Kept:** every colour family.<br>**Toned:** the volume is down a notch. Loud colour is about 4–8% of the screen, down from about 15–20%, and glowing parts in the lobby fell from 743 to about 300. |
| **Spawn** | **Build:** a three-step octagon platform with a turning "+1" medallion and lamp posts.<br>**Facing:** you face BAY 1 and the exit, with a START HERE / BAY 1 FREE board over the free lane.<br>**LOBBY pad:** it puts you back facing the same way. |
| **Stage 1 exit** | **Build:** a framed red stage door with pillars, lanterns, a keystone and a "1" badge on top.<br>**Monitor:** it follows you, from "TRAIN AT THE RANGE FIRST" to "YOU CAN GO! WALK IN" to "STAGE 1 CLEARED". |
| **WORLD 2** | A blue stone arch with a swirling face, chained and padlocked, with one COMING SOON board. It stays muted while locked. |
| **Teleport pads** | Fast travel and every gate's LOBBY/FURTHEST pad are small octagon booths, with cream posts, a glowing ring and a medallion sign. |
| **Stage gates** | **Build:** all 16 have towers and a bridge with a number medallion.<br>**Requirement:** shown once, on a framed board. A new player sees "TRAIN AT THE RANGE"; after that it reads "NEED X MORE" with a progress bar.<br>**State:** the lamps turn green when you can pass, and the padlock shows only on your next gate. |
| **Lobby objects** | **Leaderboards:** on legs, with framed screens and crown toppers.<br>**Rewards:** the DAILY CRATE, LUCKY SHOT and VIP SAFE stand in one row on framed plinths.<br>**KINGPIN statue:** three shades of gold.<br>**Shoe boxes:** a booth with a striped canopy that says COMING SOON once. |
| **Armory** | **Kept:** the hammer-shop layout, two rows of big guns, and pink locked / blue owned / green equipped (softened).<br>**Pads:** each is a layered hex with a bevelled base, rim, glowing inner face and a framed state plate.<br>**Backboards:** one framed backboard per row. |
| **Ranges** | **Kept:** the same lane themes, a notch less loud.<br>**Removed:** the floor lines and decals; one raised kerb marks the firing line instead.<br>**Labels:** two lines, and only shown up close, so they don't run together.<br>**Lamps:** each lane has a red/green lamp. |
| **Streets** | **Kept:** the same district colours (red brick, violet, orange/clay, tan, blue), softer.<br>**Fight pads:** small boxing rings.<br>**District signs:** framed signs on a post instead of floating banners.<br>**Props:** chunkier.<br>**Boss ring:** gold, cream and red instead of rainbow. |
| **Lighting** | A new default, **HoodSoft**: the bright sunny look with a neutral grey shade (the old purple tint made grey look lavender) and gentler bloom. `HoodLighting.Apply('FrontPage')` still gives the old look. |

## Critic scores (out of 10, preview and built-in textures)

| Criterion | Round 1 | Round 2 |
|---|---|---|
| Style kept | 8.5 | 9 |
| Not too loud, still cheerful | 8 | 8 |
| Low-poly | 8.5 | 9 |
| Crafted portals and objects | 8 | 9 |
| Grey warehouse | 8.5 | 9 |
| Logic and clarity | 7 | 8.5 |

- On the 10-point checklist, every object scored 9 or 10 in round 2.
- Round 3 fixed the last details the round-2 critic listed. No critic re-scored round 3; it was checked with the builders' renders, the tests and the map check.

## Open it in Studio
- Open `hood/places/HoodEvolution.rbxl` (rebuilt with this pass) and press Play.
- Or, with Rojo, run `require(game.ServerStorage.TheBlockV2).Build()` in the Command Bar.

The test cheat from the last report still works. While playing, switch the Command Bar to Server and run:
```lua
local D = require(game.ServerScriptService.HoodServer.DataService); local p = game.Players:GetPlayers()[1]; local d = D.get(p).Data; d.Rep = 30000; d.Cash = 30000; D.push(p)
```

## Worth a look in Studio
The previewer can't show these exactly:
- the gate field turning green;
- the exit monitor changing at 10 Power;
- the armory pad glow in real lighting;
- the spotlights;
- the WORLD 2 swirl turning.

## Checked
- Unit tests: 83/83.
- Map check:
  - 16 gates in order, 16 fight pads, 31 teleports, 8 range zones;
  - the spawn enabled;
  - a 1,000-Power player is stopped at gate 9.
- The real gate script was run as a new player, part way, ready and cleared.
- The armory script was checked for buying, equipping and re-streaming.
- The map is about 15,400 parts, and the lobby dressing stays under its 2,500 budget.
