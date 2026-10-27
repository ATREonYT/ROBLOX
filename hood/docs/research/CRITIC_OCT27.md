# Fresh critic, Oct 27 (HEAD 1c78434d)

I didn't build any of this. I judged it against `docs/refs/` and `refs/ui/`, the owner's rules (CLAUDE.md, RULES.md),
CRITIC_POINTS.md and LOOK_RECIPE.md.

**Pictures judged:**
- `art/renders/lobby-r1/lobby_r1_vs_refs.jpg`
- `ui-oct27/r7_shop_passes_luck_vs_refs.jpg` and `r7_shop_open_tabs_buy.mp4`
- `flow-oct27/sheet.png` and `first40.mp4` (frames pulled with ffmpeg)
- `round6-oct27/w2_districts_vs_plan.jpg`

**No new render was made.** The open questions (the floor colour, ViewportFrames, the real prices) can only be settled
in Studio, not by another preview.

**Sizes:** S = under an hour, one file. M = a few hours or several files. L = a day or more.

## Measurements

| What | Ours | Reference / rule |
|---|---|---|
| Lobby floor, spawn view (40-point grid) | **#B3C0DD, H 220, S 0.15-0.21**: lavender-blue, cool | CLAUDE.md: "a warm concrete floor"; the code's floorA is C(224,210,190), H 35, S 0.15 |
| Lobby floor, from above (roof off, sun) | **#D9D7D7, S 0.01**: neutral grey | warm |
| Walks | C(198,205,224), lavender, with blue border bands (#4C6DB8, S 0.59) | ref W01 path #A29DC0 (lavender is the ref's) |
| Whole frame, play (first40 t=3/9/22 s) | mean luminance 114-122, median S 0.48-0.58, 39-49 % of pixels S > 0.6 | ref W01: 139-146, 0.63-0.71, 51-57 % |
| Lobby spawn view (render) | median S 0.39, 37 % > 0.6 | W01 0.60, 50 % |
| Lobby top-down | median S 0.14, 16 % > 0.6 | ref top-down 0.65, 60 % |
| HUD size (share of screen width) | Shop 12.0 %, small menu buttons 5.3 %, level bar 31 %, product buttons 9.2 %, pass cards 12.1 % | ref_V2-02.0 / W01: 13.2 %, **7.8 %**, 35 %, 10.9 %, 12.7 % |
| HUD element count | about 17 controls | W01 about 22. **Our HUD is not more cluttered than the ref.** The clutter is world labels. |
| Near-white share | 0.4-1.5 % | W01 0.3-1.5 %. Fine. |

## The 15 worst gaps, worst first

**1. The lobby floor isn't warm. It reads cool lavender-blue indoors and plain grey from above.**
- Judged against: lobby_r1 spawn view and top-down, against CLAUDE.md "warm concrete" and ref W01's warm, saturated
  picture.
- Cause: the code colour is a pale beige, S 0.15. That's too weak to survive the PlusOne light: a blue sky fill
  (EnvironmentDiffuseScale 0.8), Ambient C(125,125,135), and a closed roof so the floor gets almost no warm sun.
  The lavender walks and blue bands add to the cool cast.
- Files: `tools/map/pieces/e4_warehouse.lua` (`Lobby.WHColors.floorA/B`), `e3_plaza.lua` (`walk`),
  `src/ServerStorage/HoodLighting.lua` (PlusOne `Ambient`).
- Fix:
  - floorA about C(238,202,152) and floorB about C(226,190,142) (S about 0.35, so it lands warm after the blue fill);
  - Ambient slightly warm, about C(132,128,122);
  - keep the walk lavender as the ref's path accent;
  - one Studio screenshot to confirm, since the preview's indoor light under a closed roof isn't calibrated.
- Size: S.

**2. Kid-safe break: hit flashes go faster than 1 per second.**
- Cause: `Juice.flash` turns a white Highlight on (FillTransparency 0.3, fades in 0.12 s) on every hit. Auto-fire is
  2 shots a second (ShotRules.AutoRate), and other players' shots count at 2.5 a second, so a target blinks white
  2-5 times a second. The rule is at most 1 flash a second.
- Files: `ReplicatedStorage/Shared/Juice.lua:187`, called from `Shoot.client.lua:217`, `WorldBoss.client.lua:195`,
  `Armory.client.lua:268`, and `Juice.lua:387`.
- Fix: a 1 s cooldown per model in `Juice.flash`. Between flashes, a soft tint (FillTransparency 0.65 or more,
  which reads as a tint, not a flash) or just the knock-back.
- Size: S.

**3. The first 3 seconds look broken.**
- What happens: the welcome glide starts outside the hall and flies through walls and signs: full-screen grey frames,
  then giant yellow "RA" letters (first40, 0.9-2 s). Before that, the loading screen is plain black with a small
  title and a thin bar.
- Cause: `Welcome.Behind = 8` and `Height = 16` put the camera 8 studs past the gate, outside the north wall that the
  warehouse shell added. The shell is newer than this setting.
- Files: `StarterPlayer/.../HoodClient/Welcome.client.lua:27-31,92`, `Loading.client.lua`.
- Fix: start inside the hall (in front of the gate, under the trusses at about 11 studs), or raycast the path and
  pull the start in. Give the loading screen the game's colour and the title logo.
- Size: S (camera), M (loading art).

**4. World labels collide with the HUD.**
- What happens: "Crown Box ⬡199" sits under the Rookie/Cash block. "STAGE / Recommended Pow…" and "The Grail Bundle"
  slide behind the x2 pass cards (first40 t=1-3 s, t=9 s, and the tile at 12 s).
- Judged against: ref W01, where the world labels stay in the middle band, clear of both HUD columns.
- Files: `Lobby.client.lua` billboards (MaxDistance, size), `tools/map/pieces/e2_lobby.lua` (label heights).
- Fix: MaxDistance about 30-35 for product and box labels; a smaller label size at distance (scale with distance,
  not fixed pixels).
- Size: S.

**5. The gate sign sits at camera height.**
- What happens: walking up, "Recommended Power: 10" grows to fill the top third of the screen, and the avatar covers
  the padlock (tile at 12-16 s).
- Judged against: ref W01, where "STAGE 1 / Recommended Power" is small and high over the gate.
  LOOK_RECIPE §24: titles high, 14+ studs.
- Files: `tools/map/pieces/e2_lobby.lua` (around line 2578, the gate sign), and the same rule in `f2_stages.lua`.
- Fix: raise the sign to the lintel top, 14 studs or more, and shrink it to about 0.6x. The padlock goes on the door
  at chest height, off the walk line.
- Size: S.

**6. Too many labels in the armory.**
- What happens: about 10 "xN Power" labels, prices, and LOCKED/EQUIPPED tags in one view, with back rows overlapping
  front rows ("x16 Power 10K" over "x6 Power 600"). Frame f26.
- Judged against: ref_V2-02.0, which shows 3 stands per view, each with one big "+6/Power" line and a small state word.
- Files: `tools/map/pieces/d3_armory.lua`, `Armory.client.lua`.
- Fix:
  - back-row labels MaxDistance about 20;
  - one line per stand (multiplier, price under it);
  - the state word only on the pad tag;
  - the same height for every label in a row.
- Size: S-M.

**7. The Featured shop card looks unfinished in every frame.**
- What happens: the Chrome Box art area is empty with dashed outlines. The odds row shows coloured splats instead of
  shoes. The x8/x3/x1 labels drift off their buttons ("x3" sits over the x8 button).
- Judged against: `refs/ui/owner_ui_windows_oct27.png` (Shop: a painted box, the real pets over each %) and
  ref_ui_shop_featured.
- Cause of the dashes: the preview's placeholder for a ViewportFrame (`tools/preview/ui/index.html:214`). The box may
  well render in Studio, but nobody has seen it.
- Files: `Store.client.lua` (featured card).
- Fix:
  - a pre-rendered 512 px PNG of the owner's box GLB instead of a ViewportFrame (sharper, and the preview can show it);
  - shoe icons over each %;
  - anchor each "xN / SAVE" label to its own button.
- Size: M.

**8. The x2 pass cards hide their own icons, and the price reads "ONLY ⬡ ?".**
- What happens: the cash stack, bolt and shoe are covered by the title text (hud_zoom from first40 t=31 s).
- Judged against: ref W01 and V2-02.0, where the icon breaks out of the card's top-right edge and the price is
  "ONLY ⬡79".
- The "?" was the owner's own request (brief 29 P5, `HUD.client.lua:133`), so it's not a bug. But to a new player it
  looks broken, and it sells less than the ref. Ask the owner one question before changing it.
- Files: `HUD.client.lua` (pass cards, `teaserPrice`).
- Fix: the icon at 1.2x, above the card's top-right corner; the title shifted left.
- Size: S.

**9. The Cash counter reads as a gain ("+0", "+25", "+30").**
- Cause: the lime "buy more" plus sits right between the icon and the number.
- Judged against: ref W01, where the + sits on the icon's corner and the number is clearly apart.
- Files: `HUD.client.lua:326-343` (`plus()` with the StatPill).
- Fix: move the plus to the pill's right end, or tuck it fully onto the icon's corner.
- Size: S.

**10. HUD buttons are smaller than the ref's.**
- The numbers: Shoes/Rebirth/Items/Skins take 5.3 % of the screen width against the ref's 7.8 %; the level bar 31 %
  against 35 %; the product buttons 9.2 % against 10.9 %.
- Small text ("Multiplier: x1", "Friend Boost", "Auto Fight") is about 9 px tall at 720p, which is small for phones.
- Judged against: ref_V2-02.0 and W01.
- Files: `HUD.client.lua` Spec.
- Fix: the small menu grid 1.35x, the bottom bar 1.12x, the small captions +3 px. Check in Studio's Device Emulator.
- Size: S.

**11. The camera is too low and flat.**
- What happens: the horizon sits at about 40-45 % in the spawn and lane views, so walls fill the picture and the floor
  plan can't be read. In a bay, the counter hides the avatar (t=9 s).
- Judged against: ref W01, where the camera is high and pitched about 30 degrees down, with the horizon at 15-20 %.
  This is CRITIC_POINTS #2, still open.
- Files: the camera setup (the default zoom and pitch at spawn).
- Fix: start zoom about 20 studs, pitch about -30 degrees. Lower the bay counters under the eye line.
- Size: S.

**12. The picture is darker and duller than the ref overall.**
- The numbers: mean luminance 114-122 against 139-146; median saturation 0.48-0.58 against 0.63-0.71.
- Judged against: PlusOne's own note, which targets the ref's mean of 145.
- Files: `HoodLighting.lua` PlusOne (`ExposureCompensation = -0.3`, grade `Saturation = 0.35`).
- Fix: Exposure -0.1, Saturation 0.45; re-measure toward 140 / 0.62. Do not go brighter than the ref: the owner said
  the bright look hurt their eyes.
- Size: S, plus one Studio check (the preview's tone curve isn't proven for indoors).

**13. Tiny props in the lane bays.**
- What happens: bottles and cans under 1 stud on the bay counters (t=9 s, lobby_r1 left).
- Judged against: CRITIC_POINTS #11 (nothing under 1.5 studs) and ref_STILL_training_lanes (one chunky prop per mat).
- Files: `tools/map/pieces/d2_stations.lua`.
- Fix: drop the small items and keep one 2-3 stud prop per bay.
- Size: S.

**14. The World 2 districts all look alike.**
- What happens: every district has the same road, the same hazard gate and the same lamp pairs. Each open gate shows
  the next gates behind it, a tunnel of identical gates. White pavements dominate.
- Judged against: the owner's plan frames in w2_districts_vs_plan. Each district has its own palette and dressing,
  dense side props, and one glowing portal closing the view.
- Files: `tools/map/city/f4_districts.lua`.
- Fix:
  - a ground and accent palette per district (sand for Construction, pink neon for Luxury, steel for Transit);
  - close the sightline behind each gate (a portal panel or a jog in the street) so only one gate shows;
  - more mid-height props along the kerbs.
- Size: M-L.

**15. The tutorial hint pills look cheap in stills.**
- What happens: the typewriter leaves fragments on screen ("G", "Now go f", "CASH buys guns and sho"). The pill is a
  small dark-grey box with text about 13 px tall at 720p.
- Judged against: ref_V4_tutorial_box_crops, which uses a white rounded frame round the target and bold readable words.
- Files: `ReplicatedStorage/Shared/TutorialRules.lua:194-213` (the typewriter), and the hint pill in
  `Onboarding.client.lua`/`Goals.client.lua`.
- Fix: show the whole line with a 0.25 s pop and fade instead of typing (RULES 25 asks for eased text). Pill 1.3x,
  with a white outline.
- Size: S.

## What's good (keep it)
- The shop matches the owner's mockup well: yellow header, tabs, chunky coloured cards, lime price buttons.
- The odds and the pity counter are shown ("Epic+ guaranteed in 8 opens", and the Lucky table, normal against lucky).
- The open motion has a visible scale pop and settle.
- HUD element count is below the ref's.
- Brick and pilaster walls and blue trusses read well, and the gate is the clear focal point from spawn.

## Kid-safe check
- **Break: hit flashes at 2-5 a second (gap 2).** Everything else passed.
- **Weekly Deal "5d 3h 53m":** a real rotation, the same for everyone (`Products.featuredAt`, Config/Products.lua:223).
  Fine. Keep "Weekly Deal!" and never copy the ref's "Limited Time!" pill.
- **Struck-out prices** (792 → 599, 297 → 249) equal 8 x 99 and 3 x 99, the real single price. Honest. A small
  "8 x 99" note would make that plain.
- **No stock counters or "only N left" found** in the client and shared code. The ref's "0/100 left" (W01) and
  "Next GUNSHIP boss fight in 3:22" are don't-copy unless real.
- **"ONLY ⬡ ?" (gap 8):** not dishonest, since Roblox's prompt shows the price. Still worth asking the owner whether
  kids should see the price up front.

## What the preview can't show (check in Studio)
- **ViewportFrames** (the dashed boxes): the Featured box art, the "NEW GUN!" gun view, and any 3D icons.
- **Indoor light under the closed roof:** the floor colour and the overall brightness (gaps 1 and 12).
- **The Robux sign glyph and its colour,** and real prices (the harness shows "?").
- **Text sharpness** (TextScaled blur), **phone scaling and safe areas** (gap 10), **particles, bloom and sounds**.
