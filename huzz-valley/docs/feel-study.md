# Feel study: Huss Valley and the other game vs ours (Oct 17)

Measured from three videos with ffmpeg and Python: 1 fps contact sheets, 10 to 60 fps bursts cropped to the
character, single sharp frames for the UI, and colour stats on the 3D view with the UI left out.
- **HV**: Huss Valley gameplay, 62 s. It's the loop and feel reference.
- **OG**: the other game's lobby with the Soul Reaper stand, 7.5 s. It's the polish reference.
- **Ours**: the owner's Studio recording, 24.75 s (lobby, map vote, the old cutscene from 9 to 16 s, round start
  with the Practice Bot).

Screen fractions are of the game view. Ours is the Studio viewport (2200x1504, cropped out of the Studio window).

**Limits of this study (be honest):**
- Our recording has **no in-round run, no huss, no countdown and no catch**. For those, our numbers come from
  `Config/Run`, `Config/Round`, `Gameplay/Feel` and `Gameplay/RoundHud`, not from video.
- Studio renders in a window, so a Play test full screen may look a little different.
- HV's huss distance is an estimate (±30%), made from the ground sliding past the character.

Pictures (same scale, side by side):
- `previews/feel-run.jpg`: the run, 30 fps
- `previews/feel-huss.jpg`: HV's huss, frame by frame
- `previews/feel-cuts.jpg`: camera moves between shots
- `previews/feel-ui.jpg`: the top of the screen and the name tags
- `previews/feel-colour.jpg`: lighting and colour, with the stats
- `previews/feel-ability.jpg`: the other game's Soul Reaper slash

## What makes them feel good (short)
1. **A calm camera.**
   - HV's camera is locked to the character: it stays within ±2% of screen width, even in a huss.
   - No FOV pulse is visible, and speed lines show only during a huss.
   - Shot changes are quick swings of 0.2 to 0.3 s, then the shot holds.
2. **One big line of text, nothing in the middle.**
   - HV's message line is the loudest UI. It's coloured by event, swaps instantly, and floats with no panel.
   - The middle of the screen stays clear for your character.
3. **Mid-tone ground.**
   - HV's grass sits at brightness 0.54. OG's bright mint sits at 0.89, but its black outlines keep it crisp.
   - In both, characters and effects stand out against the ground.
4. **Moves that read in one glance.**
   - HV's run is hunched, with big arm swings at about 4.6 steps/s.
   - HV's huss is a crouched lean for about 0.3 s with white lines, then straight back to running.
5. **Effects with timing.**
   - OG's ability: wind-up 0.25 s, a 1-frame flash, the slash 0.35 s, fade 0.15 s.
   - Its colour runs from a white core to pink to purple edges, with bloom.
6. **People.**
   - HV has 12+ players with names, titles, "Lv · wins" and outfits.
   - Small pickups (green gems with a "+1") litter the field.
   - Downed players lie where they fell. The juice is small; the crowd does the work.

## 1. Movement
| | Huss Valley | Ours |
|---|---|---|
| Run cadence | ~4.6 steps/s (a full stride every 0.43 s, counted on 30 fps) | the pack Sprint at 28 studs/s, rate 1.12 (`RunAt` 25). Not measurable in the video (lobby jog only) |
| Run pose | hunched forward, head ahead of the hips, arms swing big front to back, knife arm low | lobby jog reads upright with arms out (feel-run.jpg). The round run wasn't recorded |
| Getting to full speed | looks instant (Roblox default): no visible build-up | `Sprint`: 9 to 28 studs/s, ~95% after `Ramp` 1.2 s |
| Stopping | instant stop, then idle (52.3 s: running to standing in 1 to 2 frames at 30 fps) | Roblox stop; the lean tips back up to 3° |
| Turning | eased: ~90° over ~0.35 s when not shift-locked; snaps to the camera in shift lock | Roblox AutoRotate plus a 7° max roll |
| Character size on screen | 33% of screen height standing, 25 to 28% running (crouch) | 25% standing (lobby and lineup) |
| Camera height | horizon at 30% from the top (a fairly flat view) | horizon at 17% in the lobby, so you look down ~9° more |
| Shift lock offset | character at 43 to 45% of screen width | shift lock in rounds (not in the clip) |
| FOV at sprint | no visible change | +11° at full sprint, lobby too (`Feel` SPRINT_FOV) |
| Speed lines | only during a huss | soft wind streaks round the edge near top speed, all the time |

## 2. Huss / dash / roll (feel-huss.jpg)
| | Huss Valley (36.7 to 37.5 s) | Ours (from config) |
|---|---|---|
| Moving part | ~0.30 s (36.80 to 37.10) | 0.24 s push (`Dash.Time`) |
| Speed and distance | ~8 to 11 studs (estimate); the ground slides ~4x faster than in the run, then drops sharply | 72 studs/s for 0.24 s = **~17 studs** plus forward carry. Twice as far in less time, so it reads as a snap |
| Pose by frame | 36.80 drops ~13% lower (the silhouette goes from 0.30 to 0.26 of screen) and leans ~25 to 30° into the move, legs wide, arms tucked. Held to 37.10. Upright 37.17 to 37.20, running 37.30 | anim 0.45 s: blend in 0.06 s, out 0.18 s, `SideRoll` 24°, `SideSplay` 38°, `Crouch` 0.9 |
| Camera | steady, character ±2% on screen, no visible FOV kick | +9° FOV kick easing out, plus a camera shake on your own huss |
| Effects | 5 to 6 thin white horizontal lines trailing behind, ~20 to 25% of screen width, for 0.30 s. No dust seen | a short white trail |
| Back to running | ~0.2 s after the push ends; total move ~0.5 s | anim ends 0.45 s |
| Others' huss | the same lines show on other players (51.2 to 51.4 s) | trail only |

## 3. Countdowns, round text, transitions (feel-cuts.jpg, feel-ui.jpg)
| | Huss Valley | Ours |
|---|---|---|
| 3-2-1 | none in this clip: "survived the Hero attempt" holds 2.4 s, then "RUN! Reach the opposite safe side!" | code: numbers pop from 1.3x to 1 (Back, 0.35 s), hold 0.8 s, fade 0.35 s, size 110; "GO!" green 120 (not in the clip) |
| Message line size | box ~40% of screen width; text fills it (scaled): 2.2% of screen height for long white lines, 3.7% for short green ones | TextSize 19, **1.7% of screen height**, in a dark band 43% wide and 4% tall |
| Message colour | the text itself: white for news, green for safe or rescued, red for caught. Dark ~3 px outline, no panel | always white text; the colour sits only on a thin underline |
| Message change | **instant swap**: measured 0 frames of tween at 60 fps (27.57 to 27.58 s) | 1.12x to 1 Back pop over 0.3 s |
| Lines around it | "ROUND 01" green 1.2% above; "Safe · 0:21" white 1.1% below | a purple ROUND plate (24% wide, 8% tall), a RUNNER chip, IN A ROW pips, then the band |
| Top cluster | 8.8% of screen height, text only | **12.4%**, three stacked panels |
| Shot changes | lineup to front shot: one swing of 0.2 to 0.3 s with motion blur (11.50 to 11.75), then held 1.3 s; back the same way | 16.00 to 16.30: after the old cutscene, the camera **flies back through a wall and the sky in 0.3 s**. 20.15 to 20.75: a 0.6 s whip that **dives through your own player** to floor level and skims the ground |
| Big centre words | "HERO" in yellow above the chooser's head; nothing else in the middle | black italic banners ("C.C. is up for grabs!", "Practice Bot is the CATCHER!", "Map: Halloween") printed **right on your own name tag** |

## 4. UI (feel-ui.jpg, feel-colour.jpg)
| | Huss Valley | Other game | Ours |
|---|---|---|---|
| Screen covered by solid UI (running) | ~5% | ~8% (lobby) | ~7% (round), ~9.5% (lobby with the Today's Girl window) |
| Currency | bottom left, 2 panels, each 16% wide and 5% tall, see-through dark | big "$0" 5% tall, green, thick black outline, no panel | bottom bar 20% wide, 4% tall |
| Side buttons | 3 small (MENU/EMOTE/AFK), ~3% wide and 5% tall, key letter in the corner | illustrated icons 4.4% wide, 7.7% tall, outlined labels, key letters | 4 buttons 5% wide, 7% tall |
| Ability or huss readout | ability card 13% x 8% at bottom centre; "PRESS SPACE TO DASH" plus a thin green bar 35% wide | "SPACE - ROLL" plus a READY bar 37% wide | DashReady tile (not in the clip) |
| Name tags | role title (team colour, 1.1%), name (white, 2.4 to 2.6%), "Lv. 6 · 8 wins" (grey, 1.1%). Own tag visible and faded | "Rookie" title 2%, name 3.5%, "Level 1 · Won: 0" 2% | RUNNER (blue, 2.4%), name 2.5%, Lv line. At 23.5 s the own tag is **6% tall** and runs into the top line |
| Font | rounded heavy sans, white or coloured fill, thick dark outline | chunky cartoon face, thick black outline | Gotham (owner's call) |

## 5. Lighting, filters, colour (feel-colour.jpg)
Mean over the 3D view with UI cut out (HV 7 running frames, OG 6 frames, ours 3 lobby and 5 round frames).
"Maxed" = the share of pixels with any colour channel at the top of the range.

| | HV round | OG lobby | Ours lobby | Ours round |
|---|---|---|---|---|
| Saturation | **0.72** | 0.63 | 0.61 | **0.56** |
| Brightness (HSV V) | 0.62 | 0.70 | 0.76 | **0.87** |
| Contrast (luma spread) | 0.17 | 0.24 | 0.28 | 0.21 |
| Maxed pixels | 15% (sky and clouds) | 7% | **48%** | **35%** |
| Ground colour | (25,136,84), V 0.54 | (41,227,144), V 0.89 | (247,162,46), **V 0.97** | (252,174,54), **V 0.99** |
| Ground texture contrast | 0.07 (studs faint) | 0.14 (crisp outlines) | 0.12 | 0.11 |
| Shadows | faint, short blobs | crisp, short | long dark shapes from lamp posts in the lobby | soft |
| Sky | Roblox blue with big white clouds, clear horizon | the same, a touch of glare | clear blue, no clouds in frame | clear blue |
| Glow | almost none | neon purple stand glows (bloom) | lanterns glow | start-line neon glows white and cyan |

Reading: our floor sits at the very top of the range, so lit and shaded sides look the same and the picture
goes flat. That's why it looked "bland" even after saturation went to +0.28. HV keeps the ground mid-tone, and
OG keeps it bright but under the top with crisp dark outlines. Part of this is the orange Halloween map itself;
the rest is `Config/Look` (Brightness 2.8, ExposureCompensation +0.15, warm ColorShift_Top).

## 6. Items and abilities (feel-ability.jpg)
The other game's Soul Reaper stand loops a demo every **1.35 s**:
1. A purple glow builds at the hand during a 0.25 s wind-up.
2. One white flash frame (~0.05 s).
3. A **pink-white crescent slash** sweeps for 0.35 s, ~40% of screen width at that distance.
4. It fades to purple for 0.15 s, and particles settle on the stand for ~0.1 s.
5. It rests for ~0.55 s, then loops.

Around the demo:
- **Colours**: white core, pink (~255,140,230), purple edges (~155,77,255), neon with bloom.
- **Title**: "SOUL REAPER" floats above it in big purple letters with a light outline.
- **Stand**: a glowing purple plinth with a price and "WALK UP TO GET IT".
- **Camera**: it never moves for the demo.

HV only shows its ability as a card ("ONE HIT SHIELD · WAIT FOR ROUND").

## 7. Small things that read as "made by people"
- **HV**:
  - collectible green gems on the field pop a "+1" when picked up (33.3 s);
  - downed players lie where they fell and teammates run over;
  - a crowd of 12 lines up shoulder to shoulder;
  - the role title on every tag;
  - "HERO" shows over the chooser;
  - the camera swing has motion blur.
- **OG**:
  - illustrated buttons with key letters;
  - a busy lobby: benches, billboards, a "content creator" sign, a demo stand;
  - every word has a thick outline.
- **Ours**: we have more effects than HV (rings, confetti, shakes, red tint, edge glow, FOV), but they pile up.
  The field looks empty with one player and a grey bot, and the prize girl over the map reads as a **dark green
  blob** 3.5% of screen tall with a star tag (18 s).

## Our visible problems (from the recording)
1. Banners print on your own name tag:
   - "Map: Halloween" at 2 to 4 s;
   - "C.C. is up for grabs!" at 18 s;
   - "Practice Bot is the CATCHER!" at 20 s.
2. The own tag is 6% of screen height at 23.5 s and collides with the top line ("RUNNER" ghosted behind it).
3. The message text is 1.7% of screen height, white, in a band, vs HV's 2.2 to 3.7% with coloured text and no panel.
4. The top cluster is 12.4% of screen height in three panels, vs HV's 8.8% text only.
5. The floor is blown out: brightness 0.87 vs HV 0.62, and 35 to 48% of pixels maxed vs 15%. Saturation 0.56 vs 0.72.
6. The camera flies through a wall and the sky (16.0 to 16.3 s), then dives through the player (20.2 to 20.75 s).
7. The camera sits higher and further back: the character is 25% of screen height vs 33%, and the horizon is at
   17% vs 30%.
8. The old cutscene: 7 s of a dark blue void, a light pillar and 1.0% text ("Something rare is coming"), with
   nothing to do.
9. The hero in the pick shot (23.5 s) has a thick white outline, and the cyan start-line glow cuts across their
   chest. HV's outlines are thin and dark blue.
10. The Today's Girl window covers the middle top of the screen and your tag in the lobby (19.5% x 22%).

## The 15 biggest gaps, ranked, with the change I'd make
1. **Nothing over your own character.**
   - Move centre banners to `Position = UDim2.fromScale(0.5, 0.27)`.
   - Use them only for 3-2-1, GO, SAFE, OUT and the win.
   - Send "X is up for grabs", "Bot is the catcher" and "Map: X" to the message line.
   - Hide the local player's own BillboardGui while a cinematic shot is on (`Enabled = false`), and set
     `MaxDistance` 80 on others.
2. **Make the message line HV's.**
   - Drop the dark band. Use a `TextLabel` with `Size = UDim2.fromScale(0.40, 0.04)`, `TextScaled = true`,
     `UITextSizeConstraint` Min 20 / Max 44, Gotham Heavy.
   - Colour the text itself: green `5BE07A` safe or rescued, red `FF5A5A` caught, white news.
     This changes the owner's "white text" call: HV does it for event lines, so ask the owner first.
   - Add a `UIStroke` 3 px, colour `0B1A12`, transparency 0.1.
   - Swap the text instantly; at most a 0.12 s 1.05-to-1 Quad pop.
   - Keep "ROUND 1" at 1.2% above it and "Runner · 0:21" at 1.2% below it, both text only.
3. **Bring the floor down from the top of the range.**
   - `Config/Look`:
     - Lighting.Brightness 2.8 to **2.0**;
     - ExposureCompensation +0.15 to **-0.1**;
     - ColorShift_Top to `255,250,240`;
     - ColorCorrection Contrast 0.14 to **0.08** (keep Saturation 0.2 to 0.28).
   - Per map, keep big floors at V ≤ 0.85: Halloween orange to about `226,128,44`.
   - Targets: maxed pixels < 15%, mean brightness 0.62 to 0.70, saturation ≥ 0.65 (check with the stats script
     in the study notes).
4. **Camera moves arc over, never through.**
   - Replace the fly-back after the cutscene with a 0.25 s fade through black (or a cut while the screen is covered).
   - Lineup shot changes: one `Quart` InOut swing of **0.25 s** that rises at least 4 studs above heads, then
     hold ≥ 1.2 s.
   - Raycast each camera path and push it up if it hits a part or a character.
5. **Frame like HV in rounds.**
   - Start zoom ~**12 studs**, camera pitch about -12° (horizon near 30% from the top), so the character is about
     a third of screen height.
   - Cap `CameraMaxZoomDistance` at ~22 during rounds.
6. **Calm the camera.**
   - SPRINT_FOV 11 to **0 to 3°**, DASH_FOV 9 to **≤ 3°**.
   - No wind streaks while running; speed lines only during a huss.
   - Shake only for your own catch or getting caught (≤ 0.3 studs, 0.25 s).
7. **The huss: longer and shorter-reaching.**
   - Push for **0.30 s** with velocity easing out (Quad Out) from **45 to 20 studs/s**, about 10 studs, then hand
     back to the run.
   - Pose: drop 13% (`Crouch`) and lean **25 to 30°** into the move, legs wide; hold to 0.30 s, upright by 0.38 s,
     running by 0.50 s.
   - Effect: 5 or 6 thin white lines behind the body (world-space `Beam`s or a `Trail`, width 0.08 studs,
     ~4 studs long), fading over 0.30 s, seen by everyone.
8. **Running starts almost at once.**
   - Keep the owner's "walk builds into a run" but make it quick: `StartSpeed` 9 to **16**, `Ramp` 1.2 to
     **0.5 s**.
   - The stop stays instant.
9. **A hunched run with big swings, everywhere.**
   - Check in Studio that the lobby run is the hunched pack Sprint (it read upright in the clip).
   - Aim for ~**4.6 steps/s** at runner speed: set `RunAt` so the loop plays one full stride per 0.43 s.
   - Arms swing front to back, not out to the sides (`ArmOut` 22 to ~10).
10. **A smaller top HUD.**
    - Turn the ROUND plate, chip and pips into plain outlined text, so the top cluster is ≤ 9% of screen height.
    - Hide the prize card while running (show it on the Results screen and in the lobby).
11. **Thin team outlines.**
    - `Highlight`: FillTransparency 1, OutlineTransparency **0.55**, team colour (blue runner, red catcher,
      yellow Hero).
    - Turn the start-line neon down (Transparency 0.4, no Bloom-strength white), so it doesn't slice the hero shot.
12. **Show the girls like a prize, not a blob.**
    - Put the showcase girl on a lit plinth with a 3D title in her rarity colour.
    - Give her a rim light (PointLight Brightness 1.5, Range 8) and play the pack idle.
    - Move the Today's Girl window to the left side, 18% wide, so the middle stays clear.
13. **Ability timing like the other game.**
    - For each power (Heart Shield, Rizz Rush, Love Trap, Charm Wave; Oct 19 renamed Shield, Speed Boost, Bear Trap,
      Slow Wave): wind-up 0.15 to 0.25 s, one flash frame
      (≤ 1 a second), main effect 0.3 to 0.4 s, fade 0.15 s.
    - Colour runs white core to theme colour to a darker edge, with Neon plus bloom.
    - The power's name pops once over the user (0.2 s Back).
14. **Cut the dead time.**
    - The void clip at 9 to 16 s is the old 7.5 s reveal build; the 14.5 s Secret cutscene replaced it.
    - Check the new one's first and last 0.5 s for the same fly-back through walls (gap 4).
    - Keep any "something is coming" text ≥ 3% of screen height.
15. **One effect per event, and more life.**
    - Keep the coloured message plus one small world effect (ring or confetti, not both plus shake plus tint).
    - Add HV-style pickups that pop "+1".
    - Fill the lobby: girls walking, dancers, a demo stand.

## What only Studio can show
- The real FOV, shift-lock feel and huss distance in play.
- Whether the round run is the hunched Sprint.
- How the lighting changes look on every map.
- The countdown and catch moments. None of these are in the owner's clip, so record one round full screen,
  including a huss, a catch and the 3-2-1, for the next comparison.
