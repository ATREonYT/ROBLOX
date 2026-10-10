# Playtest fixes: lighting, rebirths, your own avatar, Store UI (2026-10-09)

These changes come from your first Studio playtest. Before them:
- the lighting was too bright;
- Power ticked up on its own;
- the ranges weren't tied to rebirths;
- the costume looks hid your avatar;
- the armory was too big;
- the gamepasses were physical pads with an over-designed look.

## Lighting
- **Why the previews were wrong:** your Studio screenshot gave me a real frame to compare against. My preview renderer had been drawing the sun about 5× weaker than Roblox does, because Roblox adds the warm ColorShift_Top to the sunlight. That is why the previews looked fine while Studio was washed out white.
- **The fix:** the renderer is now matched to your Studio frame, and the game's lighting (`HoodSun`) has been retuned against it:
  - Brightness 2 → 0.32;
  - more neutral ambient light;
  - no haze;
  - glow only on neon.
- **Check it in Studio:** in the previews the hall walkway is now within a few shades of your hall pictures. Studio is the real test, so tell me if it still looks off. The old preset is kept as `HoodSun16`.

## Game logic
- **No automatic Power.** It only comes from shooting at the ranges and the street targets. One shot pays:
  `1 × lane × rebirth multiplier × gun × shoes` (doubled with the 2x Power pass).
- **Ranges unlock by rebirths:**

  | Lane | Rebirths | Power |
  |---|---|---|
  | BAY 1 | free | x1 |
  | BAY 2 | 2 | x2 |
  | BAY 3 | 4 | x3 |
  | BAY 4 | 6 | x5 |
  | BAY 5 | 8 | x8 |
  | BAY 6 | 10 | x12 |
  | BAY 7 | 12 | x18 |
  | BAY 8 | 14 | x25 |
  | Champ Ring | 16 | x40 |

  Labels read "Locked / 🔄 2 / x2 Power", and locked lanes are black.
- **Rebirth works:**
  - it needs 2K Power, then 7.5K, 21K, 50K, 120K and so on;
  - it resets your Power;
  - your multiplier goes up (1x → 2x → 3x…);
  - you keep Cash, guns, shoes and every stage you've cleared;
  - you walk a little faster with each rebirth.
- **Your own avatar:** the costume looks, EVOLVE and the "NEW LOOK" banners are gone. Your name tag shows your name, Power and rebirths. Shoes go on your own character.
- **Goals:** 20 now, including rebirth and lane goals. The armory goal points to the stand on the right of the hall.
- **Repeatable Cash:** cleared targets come back after 20 seconds and pay a little Cash again.

### Pacing (simulated, focused player)
| Milestone | Time |
|---|---|
| Stage 1 | 41 s |
| First gun | 1 min 18 |
| First shoe box | 3 min 23 |
| First rebirth | 6 min 56 |
| BAY 2 | 11 min 47 |
| Stage 10 | 31 min |
| Boss yard | 2 h 05 |
| Champ Ring | 3 h 28 |

About 74% of play time is spent at the ranges. A casual player takes about 1.5× as long.

## UI
- **HUD**, styled after your reference:
  - square studded buttons with 3D icons: Store, Rebirth, Shoes, Guns, Rewards;
  - offer cards on the right;
  - a Multiplier / Power / rebirth bar with Robux power packs at the bottom.
- **Store window:** every pass and product in one place.
  - Gamepasses: 2x Power, 2x Cash, Auto Shoot, Lucky, Triple Open, +1 Shoe Slot.
  - VIP banner.
  - Power packs, Cash packs, timed boosts.
- **Rebirth window**, like your picture: Rebirth n → n+1, Nx → (N+1)x, the reset warning, a progress bar and the Rebirth button.

## Map
- **Armory:** about 70% of its old size, still on the stepped stand on the right.
- **Hall:** the gamepass trophy pads and the BOOSTS sign are gone. That corner now has a small shoe-box delivery, with pallets, cartons and a hand truck by the loading door.
- **Champ Ring:** the boss yard's ring bleachers still have 36 simple spectator figures. They come from a file I was asked not to edit; say if they should go.

## To set up the gamepasses
1. **Create the passes** on create.roblox.com → your experience → Monetization → Passes:
   - DoubleRep (2x Power), DoubleCash, VIP, AutoShoot, Lucky, TripleOpen, ExtraEquip.
2. **Create the developer products:**
   - PowerPack1–3, SmallCash, MediumCash, LargeCash, RepBoost2x, RepBoost3x, BlockParty, SkipRebirth.
3. **Paste the IDs** into `hood/src/ReplicatedStorage/Shared/Config/Products.lua`, and set the prices there to match the website.
4. **Until then,** each card shows its price and "Coming soon".
5. **Not wired yet:** Auto Shoot, Lucky, Triple Open and +1 Shoe Slot stay "Coming soon" even with an ID, because their effects aren't built yet.

## Checked
- Unit tests: 135/135.
- Map check: 16 gates, 31 teleports, 8 ranges.
- A 1,000-Power player now passes gates 1–4, because gate Power was retuned for the new pacing.
- Target waves: no problems and no overlaps.
- The real scripts ran together in the test harness:
  - no Power from standing still;
  - locked lanes pay nothing;
  - rebirth resets Power and keeps everything else;
  - five rebirth clicks at once give exactly one rebirth;
  - Store purchase prompts and receipt handling work in the test harness.

## Worth checking in Studio
- the lighting;
- real test purchases;
- the blur behind open windows;
- the FredokaOne font;
- the HUD on a phone.

## If the lighting still looks off in Studio
- **Apply the preset first.** The place file keeps whatever lighting was applied last. Run `require(game.ServerStorage.HoodLighting).Apply()` in the Command Bar, or rebuild the map.
- **Check the values:** Lighting should show Brightness 0.32, ColorShift_Top 255,236,210, LightingStyle Soft and ExposureCompensation 0.
- **Check the effects:** there should be one each of Atmosphere, Bloom and ColorCorrection. Delete any leftover extra ones.
- **Adjust the sun with Brightness, not ColorShift_Top.** Roblox adds ColorShift_Top to the sunlight, so changing it shifts everything.
  - Still too bright: set Brightness to 0.25, or ExposureCompensation to -0.3.
  - Too dull: set ExposureCompensation to +0.3.
- **If the ceiling glares round the light bars,** lower the PointLight Brightness on the RoofLampTube parts.
- **What you should see:**
  - Hall:
    - a lavender studded floor, not white;
    - darker lavender checker panels with crisp cyan outlines;
    - teal walls;
    - soft shadows;
    - no milky haze.
  - Streets:
    - warm, sunlit brick on the left and cool shade on the right;
    - saturated grass.
