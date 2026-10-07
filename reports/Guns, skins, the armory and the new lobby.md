# Guns, skins, the armory and the new lobby (2026-10-07)

This pass covers seven changes:
- **Guns:** boxing became guns at shooting ranges.
- **Looks:** the 15 looks were rebuilt, from street kid to mafia boss. They are equipped from the EVOLVE menu, anywhere.
- **One stat:** the treadmills are removed, so the only stat is Power.
- **Lobby:** rebuilt from the two simulator-hall pictures you sent, as a bright hood warehouse.
- **Armory:** rebuilt like your hammer-shop picture.
- **Shoe boxes:** a dais at the back is set up for the unboxing feature to come.
- **Place file:** a ready-to-open Studio place.

Builder agents and fresh critic agents went round after round on every piece. Each piece was checked twice: in the preview look (effect textures uploaded) and in the built-in look (Roblox's own textures, which is what Studio shows today). Nothing here has run in Studio yet. It was checked with the offline harness, the unit tests and renders.

## Open it in Studio
**Option A: the ready-made place file** (easiest)
1. Get `hood/places/HoodEvolution.rbxl` from the branch, or use the copy sent in chat. Open it by double-clicking it, or with Studio → File → Open from File. It has every script and the map already built.
2. Press **Play**. You spawn in the middle of the lobby.

**Option B: your own place, with Rojo**
1. Pull the branch and let Rojo sync (`hood/default.project.json`).
2. In the Command Bar, run `require(game.ServerStorage.TheBlockV2).Build()`.
3. Press **Play**.

In Studio, your profile lives in memory only, so every Play starts at 0 Power. To try the later lanes, guns and looks:
1. While playing, switch the Command Bar to **Server**.
2. Run:
```lua
local D = require(game.ServerScriptService.HoodServer.DataService); local p = game.Players:GetPlayers()[1]; local d = D.get(p).Data; d.Rep = 30000; d.Cash = 30000; D.push(p)
```
To look around in edit mode, select `TheBlockV2` in the Explorer and press F. The map sits at x = 2400.

## The lobby, as you walk it
- **Spawn** is on the cross of the cyan-lined walkway in the middle of the hall. Chevrons point north to the **stage 1 door**, which has a "💪 10 POWER TO ENTER" screen. The locked **WORLD 2** door is beside it.
- **West wall: SHOOTING RANGE.** Eight lanes climb a red terrace from BAY 1 (free) to BAY 8 (gold). Each bay is a step higher, with red glass between them like the capsule row in your reference. New players get a floor trail and the hint "Go to the BOTTLE FENCE range and shoot!".
- **East side: the ARMORY.** Guns 1–5 float over big glowing hex pads on a studded deck. Guns 6–10 sit on a raised terrace behind, with stairs at both ends.
  - Each gun has a backboard and pad in its state colour: pink is locked, blue is owned, green is equipped.
  - Each gun has a name / xN / price nameplate.
  - Walk up and hold the prompt to buy with Cash or to equip. A better gun gives more Power per shot.
- **South wall: SHOE BOXES.** A smaller stepped dais holds common, rare, epic and legendary boxes, with a red high-top peeking out of the legendary one and a COMING SOON plate. It is decorative for now; `Lobby.Slots.ShoeBoxes` marks the spot for the unboxing feature.
- **Looks:** tap **EVOLVE** in the HUD anywhere to see all 15 looks and wear any you've unlocked. WEAR BEST LOOK puts on your best one.
- **The hood:**
  - a street-ball court with a hoop and kids;
  - graffiti murals: BLOCK BALLERS, STAY GOLD, GOOD VIBES, DREAM BIG, LEVEL UP!;
  - sneakers on a wire;
  - a dumpster behind chain-link, with cones and a hydrant;
  - the BLOCK AVE / HOOD ST sign;
  - a corner store with a soda cooler and ice pops;
  - a lowrider on a turntable;
  - the gold KINGPIN statue.
- **The warehouse:** a yellow overhead crane, skylights, loading-bay doors, brick and corrugated walls, and the TOP POWER and TOP CASH leaderboards.

## What changed

| Piece | What it is now | Where |
|---|---|---|
| **Shooting** | Each shot has a muzzle flash, tracer, sparks, shell casing, recoil and sounds (Roblox built-ins).<br>Targets swing, tip, spin, shatter (bottles) or fly (cans).<br>Each lane shows one running number ("+3.7K / 11 HITS").<br>Hold to fire on mouse, R2 or SHOOT.<br>The server pays `max(1, floor(rate × 0.1)) × gun multiplier`, only inside an unlocked shooter's box, at most 7 shots/s. | `Shoot.client`, `ShotRules`, `ShotSounds`, `GunTool`, `Juice`, `LobbyService`, `GunService` |
| **8 ranges** | Bottle Fence, Bullseye Lane, Hot Plates, Spinner Lane, Shadow Range, Ice Lane, Toxic Yard and Gold Range. Cartoon targets only, and each tier is clearly better than the last. | `TheBlockV2` (`code5/d2_stations`), `HoodVFX` |
| **15 looks** | Corner Kid, Runner, Lookout, Bandit, Hustler, Crook, Getaway Driver, Enforcer, OG, Shot Caller, Capo, Consigliere, Underboss, The Don, Kingpin.<br>Each look has a silhouette, a back and a prop you can read from 30 studs. Tiers 11 and up sparkle.<br>Equipping keeps your own skin tone and puts your avatar back on swap. Cards are in `hood/art/looks/`. | `SkinArt`, `Config/Skins`, `tools/blender/models/looks.py` |
| **EVOLVE menu** | Equips any unlocked look from anywhere. Shows WEAR BEST LOOK / NEED N MORE / FULLY EVOLVED. | `LobbyRules`, `LobbyService`, `HUD.client` |
| **Walk speed** | Comes from your look: 16 for the Corner Kid up to 24 for the Kingpin. | `Skins.walkSpeed`, `LobbyService` |
| **Armory** | Rebuilt like your reference on the east side: two rows, guns in profile, state-coloured pads and backboards, even nameplates. | `code5/d3_armory`, `Armory.client` |
| **Removed** | Treadmills and the Speed stat; saved Speed values still load. The EVOLUTIONS podium, since looks now live in the EVOLVE menu. The gamepass pads, which go in the UI later. | |
| **Tools** | `hood/tools/place/build_place.sh` builds the ready-to-open place file. The preview harness now follows Rojo's `.meta.json`, and the renderer respects MaxDistance. | `hood/tools/` |

## Critic scores (a fresh critic each time, 1–10; the preview and built-in looks scored the same)

| Piece | Final |
|---|---|
| Shooting ranges | Reads as a range 8, ladder 8, style 8, alive 8. Shot feel 8 apart from the sound, which needs your ears. |
| Skins | All six criteria 8. All 15 looks 8. |
| Lobby (whole room, final check) | 8 overall in both looks; look, layout, warehouse, clarity and colour 8 |
| Armory and shoe boxes | Labels 8, gameplay access 8, shoe-box dais 8, hall cohesion 8, looks good 8 (with the critic's tested backboard fix applied), match to your picture 7 (guns float side-on instead of standing upright) |

## Bugs the critics caught and we fixed
- The avatar stash kept every equipped character in server memory. This is fixed and covered by a test.
- Angled costume pieces came out 1.1–1.7× too big on players.
- Held fire aimed at targets that were already gone, and the "+N" numbers piled up.
- The Kingpin statue lost its hand and face with the new rigs.
- Gate text stacked up through the lobby door.

## Please check in Studio (about 20 minutes)
1. **Shot sounds.** Run `require(game.ReplicatedStorage.Shared.ShotSounds).demo()` in the Command Bar, then check:
   1. Any "Failed to load" line in Output? `SoundService.Shots` shows which file each layer uses.
   2. Does the pistol sound like a gun, and different from the HUD click?
   3. Hold the Minigun on the gold lane for 5 s: is there a drone or clicking?
   4. Are dings cut off on the lava or shadow lanes?
   5. Do glass, pop, tin and barrel each sound different?
   6. Is the gold ding confusable with the stage chime?
   7. Is the balance OK against the music, and on phone speakers?

   If any sound is wrong, paste Creator Store sound ids into `ShotSounds.SOUNDS`, or send them to Claude.
2. **Avatars.** Equip looks with a dynamic-head avatar and with an Rthro body, then check for:
   - a double face;
   - your skin colour not staying;
   - floating pieces when you jump or emote;
   - leftovers after you swap looks or respawn.
3. **Look and feel.**
   - The neon bloom.
   - The armory pads and backboards under real lighting.
   - The floor trail for new players.
   - SHOOT and the EVOLVE menu on a phone, or in the device emulator.

## Uploads that make it look its best
Everything works before you upload anything: effects fall back to Roblox's built-in textures. To upload, use Studio → Asset Manager → Bulk Import, then paste the ids:

| Upload | Paste the ids into |
|---|---|
| `hood/art/vfx/*.png` | `HoodVFX.Textures` |
| `hood/art/icons3d/*.png` | `IconModels.Images` |
| `hood/art/renders/guns/*.png` | `GunModels.Images` |

Or send Claude the names and ids, and it will paste them in.

## Not built yet
- Shoe-box unboxing.
- The gamepass buttons in the UI (2x POWER, AUTO SHOOT, x2 CASH). You asked for these not yet.
- Other players can't see your shots.
- REWARDS, PVP and the server side of REBIRTH say "coming soon".

## Checked
- **Unit tests:** 83/83, including shooting, target picking, sound pools, equip rules, costume leaks and sizes, and walk speed.
- **Map:** the integration run finds 8 range zones plus the boss ring, 16 gates in order, 31 teleports and the spawn. A 1,000-Power player is stopped at gate 9. Every shooter's box, every gun's prompt, the shoe-box prompt and the exit can be reached on foot.
- **Ranges and armory:** 48 scripted range checks, GunService checks, and the armory client checks for prompts, repaint and re-stream all pass.
- **Place file:** checked by reading it back: 14,604 map parts, all anchored; the spawn is enabled; every script is present, with the unit test runner disabled.
