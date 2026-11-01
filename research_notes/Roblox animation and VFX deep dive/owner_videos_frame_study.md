---
tags: [research, animation, vfx, timing, stone-skipping, cannon-evolution, reference]
date: 2026-10-31
---

# +1 Stone Skipping: animation and VFX frame study (owner's videos)

The owner's recordings, studied frame by frame for **motion, effects, camera and UI timing**. Pacing and the tutorial flow are already in
`Build Playbooks/13 Beat Stone Skipping - Tutorial, Pacing and Feel.md`, so this note leaves them out.

**How it was measured:** a 1 fps contact sheet per video found the moments, then 30 fps sheets (one per frame) were cut
around each one. Frame numbers are at 30 fps, so 1 frame = 0.033 s. The phone clips run at 30 fps and the Mac recordings at 120 fps, sampled down to 30.
The tool is `frames/make_sheet.sh <video> <start s> <dur s> <fps> <cols>x<rows> <width> <out.jpg> [crop/transpose filter]`.

| # | Video | What it shows |
|---|---|---|
| V1 | `Screen Recording 2026-10-30 at 1.53.39 AM.mov` (21 s) | Shop open and scroll |
| V2 | `Screen Recording 2026-10-30 at 1.54.11 AM.mov` (33 s) | Playtime Rewards claims, Items/Pets/Titles panels |
| V3 | `uploads/hearth/4dfef7b4-…` (31 s, phone, rotate `transpose=2`) | High-level throw (2,552 m), biome changes, pickup at the end |
| V4 | `uploads/hearth/586d93de-…` (93 s) | Intro cutscene, tutorial, two throws, training, rebirth |
| V5 | `Screen Recording 2026-10-28 at 8.41.06 PM.mov` | Already in Playbook 13; only the landing cut was re-checked |

Contact sheets saved for reference (`frames/`), with a timestamp and frame number on every tile:
- `01_throw_windup_release_camera.jpg`: V4 41.10–41.87 s, the tap, wind-up, release and camera swing (crop of the centre).
- `02_skip_splash_plus1.jpg`: V4 42.10–42.87 s, two skips, the splash crown, ripple ring and "⚡+1".
- `03_cut_home_reward_throw_button.jpg`: V4 45.55–46.75 s, the hard cut home, "+1 🏆", the quest bar drop and the THROW button rise.
- `04_flight_end_pickup_ring_cut.jpg`: V3 26.40–27.17 s, the end of a long throw, the pickup ring burst and the cut home.
- `05_rebirth_white_fade_tutorial_complete.jpg`: V4 82.4–84.73 s, the white fade and the TUTORIAL COMPLETE pop.
- `06_shop_panel_pop_overshoot.jpg`: V1 0.90–2.07 s, the background blur and the panel scale pop with overshoot.

---

## 1. The throw (V4 40.5–41.9 s, and V4 46.9–47.7 s and V3 15.0–16.5 s as checks)

| Beat | Time (V4) | Frames | What moves | Easing |
|---|---|---|---|---|
| THROW button appears | 40.53 → 40.70 | 5 f (0.17 s) | Green pill rises from below the screen to just above the character's waist | Ease-out, **no overshoot** |
| Idle in zone | 40.70 → 41.10 | | Button sits still. Character idles | |
| Tap | 41.10 | | | |
| Button leaves | 41.10 → 41.20 | 3 f (0.1 s) | Slides straight down off screen | Ease-in |
| Stone in hand | 41.13 | 1 f | The stone simply appears in the right hand. **No spawn effect** | Instant |
| Camera lifts | 41.17 → 41.27 | 3 f | Camera rises a little and tilts down onto the thrower | Fast ease-out |
| Wind-up (anticipation) | 41.13 → 41.40 | 8 f (0.27 s) | Arm draws back, low and out to the side; torso turns away from the water | Ease-in (slow start, fast end) |
| Release (action) | 41.43 | 1–2 f | Stone leaves the hand flat and fast, with a thin **white speed streak** 2–3 frames long behind it | Instant |
| Follow-through | 41.43 → 41.60 | 5 f | Arm finishes across the body; character holds the pose | Hold |
| Camera follows stone | 41.37 → 41.80 | 13 f (0.43 s) | Camera pans and dollies **past the thrower toward the water**; the thrower leaves frame left at 41.73. On the second throw (47.5 s) the camera passes right through the character's shoulder | Ease-in-out, **no cut** |
| Counter appears | 41.20 | | "0 m" fades in at top centre, then counts from the release frame (1, 4, 6, 8, 11 … m) | Fade ~3 f |

- **Tap to release = 0.33 s** (10 frames), the same in all three throws, at level 4 and at level 91. There is no hold-to-charge.
- **Tap to clean over-water shot = 0.7 s** (V4 throw 1), 0.65 s (throw 2) and 0.7 s (V3).
- **The HUD clears for the flight (V3):** at the release frame the left menu grid slides off left and the right pass cards slide off right in **4 f (0.13 s)**. The top bar (Auto Throw, event currency) and the bottom stat bar stay.
- **Sound (inferred from the audio level, V4):** the music drops to near silence for about **0.1 s exactly at release** (41.35–41.45 s), then comes back. It is a "breath" before the shot.

## 2. The flight and skips (V4 41.8–45.6 s, V3 16–26.5 s)

**Camera**
- A low chase camera behind and a little above the stone. The stone lands **at the same screen spot at every skip** (centre, about 60% down), so the camera is locked to the stone's forward position and does not lag.
- The camera keeps moving forward, so each splash slides out of the frame lower-left within 2 frames. The splash is seen briefly and then left behind.
- No FOV punch, shake or speed lines could be seen in any throw.

**Speed and the counter**
- Tutorial (V4, 220 m): about **70 m/s**, ticking every frame (9–10 m per 0.133 s). The **last 0.8 s eases out**: +7, +6, +7, +6, +4, +3, +1, then a stop at 220 m (45.13 s).
- High level (V3, 2,552 m): about **180 m/s** (+11 to +12 per frame pair), **steady to the end, then a dead stop** with no ease.
- Plain, bold white-and-yellow number at the top centre. **No scale pop on each tick**, and none at the end either.

**Skip rhythm:** one touchdown every **0.53–0.6 s** (18 frames apart in V4). The audio has a soft tick at each one (level peaks at 42.2, 42.8, 43.3 and 43.5 s).

**Splash (each skip, `02_skip_splash_plus1.jpg`)**
| Frame | What you see |
|---|---|
| f0 | Stone (a flat pink disc) dips; a tiny white puff appears under it |
| f1 | Puff grows |
| f2 | **White cartoon crown:** 3–5 chunky, rounded droplet blobs, about 1.5× the stone's width, plus one thin **flat ripple ring** on the water around it |
| f3 | Crown at its biggest (about 2× the stone); the ring has spread |
| f4–f5 | The camera passes it and it slides out of frame |

It is pure white with no colour or glow, and no particles fly far. **It lives about 0.15 s on screen** because the camera leaves it. The stone hops up and away toward the horizon on f2–f5.

**"⚡+1" popup**
- Appears **on the splash frame** (f2), just to the right of the splash. It is small (the height of the stone) and world-anchored, so it drifts down-screen as the camera moves on.
- It lives **0.5 s (15 f)** and then fades. There is no scale pop at this size.
- The Skill number in the bottom bar ticks **on the same frame**. A level-up during the flight shows "Level Up!" by the bar with a louder sound (audio peak at 43.85 s).
- At high level it reads "⚡+50" with the same motion.

**Area label:** the next area's name (a word with two palm icons) floats over the far shore. It grows from tiny to about 1.5× the counter's text size as the stone approaches, and ends up right beside the counter. In the high-level throw the water itself changes colour per area (blue, orange, white, pink).

**Flight end**
- The counter stops, then the shot **holds 0.5–0.6 s** on the water while the camera keeps drifting slowly forward (V4 45.13 → 45.60, V3 26.53 → 27.10).
- **Sound:** the audio fades down over about 0.4 s before the cut (45.2–45.6 s).
- **Pickup burst (V3 26.53 s):** the stone's end coincides with a floating pickup.
  - A **white ring shockwave** grows from 1.1× to 2.5× the pickup over 8 f (0.27 s), fading as it grows.
  - The pickup's top pops off in pieces that fly up over 0.3 s.

## 3. Landing back home (V4 45.6–46.9 s, V3 27.1–27.7 s, V5 5.2–5.8 s)

| Beat | After the cut | What happens |
|---|---|---|
| Hard cut | 0 (1 frame) | A wide shot from behind the player standing in the throw zone. **The win counter already shows the new value on the cut frame** (no count-up), and so does the event currency (470 → 500) |
| Reward text | 0 → 0.8 s | "+1 🏆" (V3: "+1.25K 🏆" with "+30 🍬" under it, smaller) floats a head-height above the character. It **appears instantly, with no pop**, and holds still |
| Quest bar | 0.03 → 0.17 s | Drops in from the top edge, 3–4 f, ease-out, no bounce |
| Side HUD (V3) | 0 → 0.2 s | The menu grid and pass cards slide back in from the edges |
| Sound | 0 → 1.3 s+ | Loud win jingle on the cut frame (the biggest audio peak in the clip) |
| Second cut | 0.5 s | Cut from the wide shot to the normal close follow camera (seen in V4, V3 and V5 at 0.5 s every time) |
| Text fades | 0.8 → 0.9 s | "+1 🏆" fades out in 3 f |
| Trophy burst | 0.9 → 1.25 s | 5–8 small trophy icons pop out around the head, float up and fade. They do **not** fly to the counter |
| THROW button | 0.87 → 1.03 s | Rises from below again (5 f, ease-out) |
| Distance (V3) | until next throw | The final "2,552 m" stays at the top of the screen |
| Confetti (V5) | 0.1 → 0.6 s | A few small green and cyan specks around the head |

So **a full throw loop is about 6 s**: 0.33 s throw, about 4 s flight, 0.5 s hold, 1 s reward, then THROW is back.

## 4. Training pad level-ups (V4 64.0–65.2 s)

- The character loops a short throw on the pad. **Skill ticks every 0.17–0.3 s** (+3 each), and a tiny "⚡+3" pops at the stone.
- **Bar:** the blue striped fill **jumps** to each new value (no tween you can see at 30 fps). On a level-up it empties to 0 on that same frame. The label above the bar switches to "Level Up! [x2]".
- **Confetti** starts 3–5 f after the level-up and bursts from the top of the head.
  - About 30 small flat rectangles in four colours: green, yellow, pink and cyan.
  - They shoot up and out, then flutter down.
  - They spread to about 3× the character's width and live 0.6–0.8 s.
  - Level-ups come every ~1 s, so the confetti almost never stops.

## 5. Rebirth → TUTORIAL COMPLETE (V4 83.2–84.4 s; refines Playbook 13 §1)

| Beat | Time | Frames | Detail |
|---|---|---|---|
| Tap Rebirth | 83.20 | | The panel values switch to the after-state on the first fade frame ("Level 1 / Level 40", title "Rebirth") |
| White in | 83.27 → 83.47 | 6 f (0.2 s) | Linear to full white |
| White hold | 83.47 → 83.87 | 12 f (0.4 s) | |
| White out | 83.87 → 83.97 | 3 f (0.1 s) | Fast. The full HUD is already there behind it |
| Clean frame | 84.00 | 1 f | |
| Dim and pop | 84.07 → 84.40 | 10 f | The screen dims to about 60%. **TUTORIAL COMPLETE!** scales 0.5 → 0.9 (2 f) → **1.05 at 84.33** → 1.0 at 84.40: Back Out, about 0.33 s. The sub-lines (Rebirth #1, a big green **x2 SKILL**, a small "Tap to continue") arrive with it |
| Rays | ongoing | | About 16 alternating gold and clear wedges behind the text, turning slowly (about 20–30° a second, estimated) |

The game keeps running behind the overlay: the level bar still climbs. Playbook 13 said 0.25 s in, 0.5 s held and 0.3 s out; the frame count is **0.2 / 0.4 / 0.1**.

## 6. Panels and buttons (V1 shop, V2 Playtime Rewards)

**Open**
- The background **blur is on in 1 frame**, with no tween. Behind it the game freezes visually.
- The panel scales from the screen centre (frame numbers are 30 fps):

| Frame | Scale |
|---|---|
| f0 | 0.10 |
| f1 | 0.30 |
| f2 | 0.60 |
| f3 | 0.85 |
| f4 | 1.00 |
| f5–f7 | **1.08–1.12 overshoot** |
| by f10–f12 | settles to 1.0 |

  Total **about 0.33–0.4 s**: Back Out, peak at about 0.23 s. Shop (V1) and Playtime (V2) are identical.

**Press and claim (V2 4.3–5.5 s)**
- The hovered or pressed cell grows by about 5%.
- On the claim, the cell turns dark with a big green tick **in 1 frame** (no animation on the tick).
- A toast at the top ("Claimed +625 WINS!", with an icon) replaces the old one at once. It **holds 3–4 s**, then fades in 0.15 s (5 f).
- No flying icons were seen on a claim.

## 7. Intro cutscene camera (V4 0–24 s)

| Time | Shot | Camera |
|---|---|---|
| 0–2.6 | The "legend" NPC waves at spawn | Slow dolly back and drift; he shrinks in frame by about 30% over 2.6 s |
| 2.75 | Over his shoulder at the release | 1–2 frames, a hard cut |
| 3.0–5.6 | His stone (shown as a **thin white streak**, a trail with no visible body) skips across the first area's water | Low chase over the water, steady speed |
| 5.75 | **Cut to the next area** (snow) on a splash | The splash ring sits in the shot at the cut |
| 8.0 | **Cut to the next area** (purple) on a splash | The same again |
| 11.25 | Cut back to spawn: the NPC and the player | Static two-shot |
| 13–21 | Subtitles ("My first throw? It barely reached the water.", "Your turn. Start here."), each held 3–4 s | Pans across the training pads at 19–21 s |
| 22–24 | Back to the player; the HUD appears with the arrow chain on the ground | |

A Skip button sits bottom-right throughout. Each area shot lasts **2.25–2.75 s**, and every cut lands on a splash.

---

## 8. What we copy (mechanics and timing only, never their art, names or text)

Numbers for **+1 Cannon Evolution** (cannon → ball → river skips). Where `16 Pro Animation and VFX Playbook.md` §4 already gives a number, the reference says to keep or change it as noted.

**Launch**
1. **Tap to shot in 0.33 s.** Keep the cannon charge to **0.25–0.3 s** (the low end of §4's 0.25–0.45 s). With no hold-to-charge, one tap fires.
2. **The launch button slides up in 0.17 s (ease-out, no overshoot)** when the player is ready, and **drops away in 0.1 s** on tap. It comes back **0.9 s after landing**.
3. **Clear the side HUD for the flight:** side menus slide off in 0.13 s on the shot and back in 0.2 s on the cut home. The top bar and the Power bar stay.
4. **A 0.1 s audio duck at the shot** (music to about −20 dB for 3 frames, then the boom). It's cheap and it makes the shot land.

**Camera**

5. **Hold on the cannon, then follow without a cut.** Keep §4's 2–5 frame hold, then swing to the side-on chase in **0.4–0.45 s** (ease-in-out). Owner's call, Oct 31: side-on rather than behind.
6. **Lock the camera to the ball's forward position** so every skip lands at the same screen spot. Keep vertical follow soft (Alex wants the arc to read). Reference has no shake or FOV punch; ours (§4 FOV 70 → 80–85, trauma shake) is louder than theirs, so keep it at the low end: FOV +8, one shake at the shot only.
7. **End hold 0.5–0.6 s, then a hard cut home**, then a **second cut to the normal camera 0.5 s later**.

**Flight and skips**

8. **Splash** (two layers, both white):
   - a crown of 3–5 rounded blobs about 1.5–2× the ball's width, which peaks on frame 3 and is gone by 0.2–0.3 s (we see it longer side-on, so let it fade);
   - plus one flat ripple ring growing about 1× → 3× over 0.35 s.
   - Use built-in Roblox textures only. Smaller each skip (§4).
9. **"+1" popup on the splash frame**, beside the splash, world-anchored, ball-sized. It lives 0.5 s and fades. The Power number ticks on the same frame, with a soft tick sound and a rising pitch per skip (§4).
10. **Skip rhythm of about 0.55 s** in the early game. Faster spacing reads as rattling; slower reads as floaty.
11. **Counter:**
    - ticks every frame and stays plain (no per-tick pop);
    - **eases out over the last 0.8 s** for short throws;
    - for long throws it can stop dead.
    - Our §4 end "pop 0 → 1.2 → 1.0" is extra polish they don't have; keep it small (1.1).
12. **The area name grows as you approach it** and finishes next to the counter. This matches our area banners and gates, which stay as they are.
13. **A pickup on the water bursts with one white ring**, 1.1× → 2.5× over 0.27 s, fading as it grows.

**Landing home**

14. **Update the counters on the cut frame.** Show "+N" (the wins/cash icon) above the head **instantly**, hold it 0.8 s, and fade it in 0.1 s. Then let 5–8 small icons pop out and float up for 0.35 s (or fly them to the counter: our approved coin-fly, Playbook 13 F).
15. **The quest bar drops in from the top** in 0.1–0.13 s, ease-out.
16. **Win jingle on the cut frame.**
17. **The whole loop is about 6 s:** 0.33 throw, 3–4 flight, 0.5 hold, 1 reward, then the button is back.

**Training and level-up**

18. **Bar jumps, no slow tween.** On a level-up it empties on the same frame. Confetti fires 0.1–0.15 s later: about 30 flat rectangles in 4 colours, about 3× the character's width, living 0.6–0.8 s, at most 1 burst per second (kid-safe flash cap). Show the "Level Up! [xN]" streak label by the bar.

**Rebirth**

19. **White fade 0.2 in / 0.4 hold / 0.1 out** (one flash: kid-safe). Swap the values on the first fade frame. Then dim to 60% and pop the title **0.5 → 1.05 → 1.0 over 0.33 s**, with slow rays (about 25°/s, our own texture).

**Panels**

20. **Blur in 1 frame; panel scale 0.1 → 1.0 in 0.13 s, overshoot to 1.1 at about 0.23 s, settle by 0.35–0.4 s** (Back Out, or `spr` damping 0.5, frequency 5).
21. **Press:** hovered cells grow 5%; a claim swaps the cell in 1 frame.
22. **Toasts:** a new one replaces the old one at once, holds 3–4 s and fades in 0.15 s.

**Intro**

23. **A montage over the river:** a 2.5 s shot per area, each cut landing on a splash. Then a static two-shot for the line of dialogue, with Skip always visible. Ours is still longer (Playbook 13 C).

**Not seen in the reference:** squash and stretch on the stone, hit-stop, camera shake, coloured trails in gameplay, glow, bloom. Their game reads through **timing and the counter**, not effects. Our §4 extras (squash, hit-stop on records, trails) are allowed, but keep them at the low end so we don't look louder than the hit we copy.

**Limits of this study**
- The sheets come from screen recordings (V3 and V4 from a phone at 30 fps), so 1-frame events at 120 fps may be missed.
- Audio cues are inferred from level peaks over a music bed. The ray speed is an estimate.
- Character arm poses come from about 70-pixel-tall figures, so read them as directions, not exact angles.

---

## 9. Techniques in the video notes that Playbooks 15 and 16 don't have yet

These are from `AI Video Library/Video Notes/VFX/` and `Animation/`. The topics already covered (impact frames, markers, flipbooks, Highlight aura, mocap retime, the upper-body copy) are left out.

**Outlines and glow**
- **Outline-only Highlight:** `FillTransparency = 1` keeps just the black outline, for an anime enemy or a target. Playbook 15 only uses the filled aura Highlight. Local player only (the client limit is now 255 Highlights, not 31; keep one and toggle it).
- **Neon-material swap per stage:** pre-weld glowing copies of a part (for example hair in blue, yellow and purple, Material Neon) and toggle them on animation markers (charge start, charge pulse, impact). It works as a cheap tier glow for a cannon barrel or a skin.

**Moving effects**
- **Animated-texture mesh (not a flipbook):** a curved ribbon mesh whose TextureID cycles through 16 uploaded frames at 24 fps. It suits slash or swing trails, and the 16 asset IDs are pasted into a frame module.
- **Multi-mesh rigs:** an invisible "main head" MeshPart, the other meshes joined to it with WeldConstraints, and one Motor6D from HumanoidRootPart to the main head. The whole model then animates through one joint. Use it for pets or a flying dragon or cannon prop.
- **Trail settings that worked:**
  - Lifetime 0.5, MinLength 0.1, MaxLength 0;
  - width set by the offset of Attachment1 from Attachment0;
  - a water-trail texture.
- **Weld effect folders to HumanoidRootPart** so they follow the character or NPC; fire them from a marker.

**Charge cutscene stack**
- DepthOfField or blur on the background, SunRays, bloom, ColorCorrection, a custom skybox and a camera part placed facing both characters, then blur, shake and a flash at the strike.
- Playbook 15 §7 has the letterbox and the impact frame but not the DepthOfField/SunRays background treatment.
- **Test glow at night:** add bloom last, raise it, and check it in a dark scene.
- **"Spread it out, move it forward, cover the blade":** when particles all spawn in one spot, spread the emitter shape along the weapon.

**Making animations**
- **Move the event markers with the keyframes** whenever an animation is shortened (select all and drag).
- **FK only, never IK,** when AI writes joint angles: IK can flip an upper arm 160° in one frame. On a new Blender rig, set the 4 IK/FK switches to 0 first.
- **The five-pose structure** for any strike: idle, anticipation, contact, follow-through, recovery. A half-second punch is the default ask.
- **Fighting-stance idle:** animate only the arms and torso so the default walk still moves the legs. Otherwise the character slides. Playbook 16 has an upper-body copy for attacks but not this idle rule.
- **R6 limits:** no elbows or knees, so big R6 moves clip through the body, and tool grips need extra passes (use the Grip Editor plugin).
- **Custom face decals work only on classic heads,** not dynamic heads.
