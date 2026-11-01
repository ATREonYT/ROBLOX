---
tags: [build-playbooks, standard, numbers, animation, vfx, camera, code, building, ui, sound, money, retention, pacing, corrections]
updated: 2026-11-01
---

# 27 Studio Standard: One Sheet per Craft

Back to [[00 Build Router]] · Owner rules: [[09 Owner Taste Rules]] · Earlier corrections: [[19 Animation and VFX Recipe Book]] Part 4 (C1–C19)

**What this is.** The vault has 25+ playbooks written over a week, and some numbers drifted between them. This sheet gives **every craft one home**: the rule, the numbers we use, the note that has the full recipe, and the test that proves it. **Where an older note disagrees with this sheet, this sheet wins**, unless Alex says otherwise (then fix this sheet the same day).

**Order of authority:**
1. Alex's word in the thread.
2. The repo `CLAUDE.md`.
3. [[09 Owner Taste Rules]].
4. For Roblox facts (APIs, limits, policies): the Sector Briefs. For our numbers, timings and taste: this sheet.
5. The other notes.
6. LihFolk.

## How to use it
- Starting a job: find the craft below, read its 6 lines, then open the recipe note it points to.
- Reviewing a build: run each craft's **Test** line. A craft passes when its test passes, not when it "looks fine".
- Labels: **[M]** measured on a reference, **[R]** Alex approved it, **[D]** Roblox docs, **[S]** suggested (our best guess; replace it with a measurement when we can).

---

## 1. Animation (characters and objects)
| | |
|---|---|
| **Rule** | Anticipation, then a fast strike, then a hold. Motion is fast, then stops dead. Repeat actions stay calm; big moments get the big poses. |
| **Numbers** | Strike 2–4 frames at 30 fps. Hold the end pose 4–8 f. PvE light attack wind-up 2–3 f; PvP 6–8 f startup (C17). Hit-stop: light **0**, medium 50 ms, heavy 66, finisher 75, ultimate 89; never over 120 ms; at most 140 ms of stop per 0.6 s (C2). Use the catch-up method: 0.12× speed for d, then 1.88× for d (C1). |
| **Objects** | Cannon recoil: the barrel slides back 0.15–0.25 of its length and pitches up 6–12° in 0.05–0.08 s, Expo Out (note 16 §3), then springs home (kit `Spring`). Squash and stretch only on rare tiers; normal shots have none [M, note 17 §1]. |
| **Owner** | Alex judges by eye on a 30 fps video, not stills. |
| **Recipe** | [[19 Animation and VFX Recipe Book]] (R1 catch-up hit-stop, R14 combo clip, R15 idle, R16 hit reaction); [[16 Pro Animation and VFX Playbook]] §5 (workflow); skill `roblox-ai-animation`. |
| **Test** | Count the frames on a 30 fps capture: strike ≤ 4 f, hold ≥ 4 f; hit-stop total per 0.6 s ≤ 140 ms; after 50 attacks, the track speed is exactly 1. |

## 2. VFX
| | |
|---|---|
| **Rule** | Quiet normal actions, loud rare ones; each tier adds **one** new kind of layer. One hue plus white. Darken before the hit, then fast in, slow out. |
| **Numbers** | Burst particles live 0.2–0.6 s; lingering debris 0.5–1 s. LightEmission 1 only on the small hot core; bodies and smoke 0–0.3, dark layers 0 (note 16 §2); Brightness ≤ 6 for pack effects. Flash 1 frame **after** contact, about 0.6× the body's size (C4). Impact frames 1–3 frames, counted in rendered frames (C3). Phone particle target 150–300 live, hard cap 360 (C7). Lingering auras about 15 alive, 3–8/s per layer, Highlight FillTransparency 1 (C6). Flipbooks exactly 1024×1024, margins 16/12/8 px for 512/256/128 px cells (C19). |
| **Kid-safe** | At most **one** bright flash per second (an impact-frame burst counts as one), gated by `Emit.TryFlash()`; a dark two-tone version when flashes are off. |
| **Recipe** | [[11 VFX Moments Playbook]] (moments), [[17 Do It Like the Hits - Animation, VFX and Feel]] §2 (reveal ladder), [[22 Rare Shot VFX Spec from Alex's References]] (frame-timed rare shots), [[25 Rare Shot Cameras and Using a VFX Pack]] §3 (packs); skill `roblox-vfx`; kit `Emit`, `AnimeFX`, `LaunchFX`, `RareReveal`. |
| **Test** | On a 30 fps capture: flashes ≥ 1 s apart; the dip before a hit ≥ 4 frames; the fall after the peak 5–6 frames; ≥ 0.4 s of calm before the camera returns (note 22 §5). Live particles under 300 in the busiest moment (F9 → Memory). |

## 3. Camera
| | |
|---|---|
| **Rule** | Calm camera, busy world. The camera never shakes on repeated actions. Rare moments earn cuts; nothing spins fast; every scripted camera gives control back. |
| **Numbers** | Default FOV 70. Gameplay FOV moves ≤ +12° total (summed and capped); kid-safe ≤ 15° [S]. Dash pulse +9° (0.06 s in, 0.25 s out). Shake: kick on the hit frame, noise only after the freeze ends, decay 1.0–1.5 per second (C5), never above Bump; follows `Setting_ScreenShake` and Reduced Motion. Letterbox 8% of the screen height, sliding in over 0.25–0.35 s, with FOV compensation (C14). Ultimate: FOV punch in 0.12 s, hold 0.15–0.6 s, widen over 0.55 s, return blend 0.55 s (C15). Skip button after 1 s on reveals of 3 s or more. |
| **Owner** | Normal +1 flight: **side-on, ball flying up left to right** (09, Oct 31). |
| **Recipe** | [[28 Camera Playbook]] (all modes and cutscene grammar), [[25 Rare Shot Cameras and Using a VFX Pack]] §2 (per-tier plans), [[19 Animation and VFX Recipe Book]] (R22 follow camera, R13 ultimate cutscene, R3 shake). |
| **Test** | After 100 shots and 20 cutscenes, FOV, CameraType, CameraSubject and look direction are exactly as before; no cutscene camera ends inside a wall (raycast check in the test place). |

## 4. Code architecture
| | |
|---|---|
| **Rule** | The server owns every number that matters. The client asks; it never tells. One module per system, started in a fixed order, each wrapped so one failure can't stop the rest. |
| **Numbers** | Client scripts under **2 ms** per frame on a phone; server under about 5 ms per heartbeat at full player count. Every remote has a type check (`Net.T`) and a rate limit (`RateLimit`). Saves use session locking; "granted" only after the save. |
| **Patterns** | `Net` (typed remotes), `Flags` (live kill switches), `ErrorLog` (grouped errors), `Receipts` (one ProcessReceipt, once per PurchaseId), `PlayerData` (versioned saves with migrations), `Interact` (one server check for every "press E"). |
| **Recipe** | [[18 Studio-Level Development Playbook]] (architecture, networking, data, CI, worked examples A–D), [[12 Game Loop Logic Playbook]] (server/client template), [[24 Working Live in Studio - Saves, Turns and Hand Edits]] (installing into Alex's open Studio). |
| **Test** | `sh new-game-kit/tools/check.sh` is green, including "bad input at every remote" and "old saves still load"; the kid-safe check passes. |

## 5. Building and maps
| | |
|---|---|
| **Rule** | Blocky, studded, cartoony. Few parts, big shapes, one landmark per zone. The map tells the player where to go without words. |
| **Numbers** | Character about 5 studs tall, walk 16 studs/s. Main path 16–24 studs wide. Spawn plaza 60–90 studs. Station 12–20 studs square. Sign letters ≥ 3 studs; floor letters 6–10 studs. Landmark 40–120 studs tall. No empty patch over about 30×30 studs. Scene budget about 500 draw calls and 500k triangles. Cannon map: 9,162 → 187 parts was Alex's bar. |
| **Owner** | Neon only where Alex's picture has it; bloom nearly off; turquoise water with real ripple rings; one tiled texture beats many small parts. |
| **Recipe** | [[10 Map Design Playbook]] (templates, zone kit, build order), [[23 Training Lane Style Guide (Alex's Treadmill References)]] (stations), [[Lesson - Tiered Training Lanes]]; skill `roblox-cartoony-building`. |
| **Test** | Part count and draw calls checked in Studio; a phone-sized screenshot from spawn shows the next goal; the side-by-side with the reference is at the same angle and size. |

## 6. UI and UX
| | |
|---|---|
| **Rule** | A minimal UI on first load, revealed step by step. Small, premium buttons. Everything moves the same way. One message line. Alex's kit and icons as they are; no emoji in the final UI. |
| **Numbers** | Motion table: [[14 Premium Feel Playbook]] §4 (press 0.9 in 0.03–0.08 s then Back out 0.28 s; panel open 0.2–0.25 s Back, close 0.12 s; message line in 0.15 s, held 2–2.5 s, fades 0.3 s). Tap targets about 44 px on phones; desktop buttons can be smaller (Alex's call). Icons packed at ≥ 192 px. |
| **Recipe** | [[30 UI and UX Playbook]], [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]], [[14 Premium Feel Playbook]]; skill `roblox-cartoony-ui`; kit `HudStages`, `HudBuilder`. |
| **Test** | A new player sees at most 2 buttons for the first 30 s; every button uses the motion table; the phone screenshot has no overlapping parts and no clipped strokes. |

## 7. Sound
| | |
|---|---|
| **Rule** | Smooth and satisfying, never harsh. Short sounds. One sound per beat. Silence beats a bad stand-in. |
| **Numbers** | UI click 0.1–0.3 s; rewards, rebirth and hatch done by 0.6–0.8 s. A heavy hit has 4 layers (crack > 1 kHz, body about 200 Hz, a sub falling through 30–60 Hz over 200–400 ms, reverb on the body only); a normal shot uses 2 (crack and body). Random pitch ±3–6% on noisy repeats only, never on stings (C11). Pitch ladder: +1 semitone per repeat, capped at +12, reset after 1 s of quiet. Duck music 3–6 dB by tweening the Music group (C18). |
| **Sourcing** | Our own (`make_sfx.py`) or Roblox's licensed library. Never invent an ID (C10). |
| **Recipe** | [[29 Sound Playbook]], [[17 Do It Like the Hits - Animation, VFX and Feel]] §7, [[25 Rare Shot Cameras and Using a VFX Pack]] §4. |
| **Test** | Play 20 quick rewards in a row: no clipping, no two sounds on the same frame, and the ladder resets after a 1 s pause. |

## 8. Money and gamepasses
| | |
|---|---|
| **Rule** | Sell scale, speed, looks and control, never an unfair win. The paid top tier is a plain gamepass that looks best (never "VIP"). Prices are shown from `GetProductInfoAsync`, never hard-coded. |
| **Numbers** | Pack ladders: value per Robux rises with each step, and the top step's extra bonus isn't bigger than the one below (`Offers.Ladder`). Unasked offers: none in the first 3 minutes of a first session, 8 s between pop-ups, 1 per session for someone who never bought (2 for a buyer), 10 minutes after a "no thanks" (`Offers.CanShow`). A sale earns about 70% (`Offers.NetRobux`). |
| **Kid-safe** | No fake timers, scarcity or stock; paid random items show odds and a pity counter; anything not built yet says "Coming soon" and never prompts. |
| **Recipe** | [[21 Money and Retention at Studio Level]]; kit `Shop`, `Receipts`, `Offers`, `Odds`. |
| **Test** | Receipts spec green (once per PurchaseId, granted after save); kid-safe check green; every pass in the shop either works or says "Coming soon". |

## 9. Retention
| | |
|---|---|
| **Rule** | Give a reason to come back that is honest: progress waiting for you, a calendar gift, friends, a weekly update. Never guilt, never a fake countdown. |
| **Numbers** | Starting targets: D1 12–15%, D7 2–3%. Daily gifts on a calendar where missing a day **pauses** the streak instead of resetting it. Offline earnings shown on return. Updates on a fixed weekday. |
| **Recipe** | [[21 Money and Retention at Studio Level]] §5–6, [[20 Whole-Game Field Guide]] (symptoms → fixes); kit `DailyRewards`, `PlaytimeGifts`, `Quests`, `Codes`, `Income` (offline). |
| **Test** | Leave for a simulated day: the return screen shows what was earned and one clear next goal; the streak paused, not lost. |

## 10. Pacing
| | |
|---|---|
| **Rule** | The reference pace is the target. Something levels up about every second while training. The first reward lands before 60 s. |
| **Numbers** | First reward under 60 s on a phone; first purchase at about 55 s [M]; first rebirth at about 85–90 s [M] (Cannon's sim currently 106 s, note 20 §0); core loop understood in 2–5 minutes. Rare reveals: Rare 0.6, Epic 1.2, Legendary 2, Mythic 3, Secret 4.5 s (Divine 7 s in the rework) and under 10% of play time in total (C13). Reward chains under 8 s, tappable to speed up after the first beat. |
| **Recipe** | [[12 Game Loop Logic Playbook]] (loop families, formulas, pacing sim), [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]], [[Teardown - Stone Skipping]]; kit `tools/pace.luau`. |
| **Test** | `pace.luau` green; the first-session timeline (first reward, first buy, first rebirth) is within 15% of the reference. |

---

## 11. Clashes settled on Nov 1 (C20 onward; C1–C19 are in note 19 Part 4)
| # | Topic | What the notes said | Follow | Why |
|---|---|---|---|---|
| C20 | **Normal-shot flight camera** | 06 §2 and the Cannon build notes: a chase camera low behind the ball. 09 (Oct 31): side-on, the ball flies up left to right | **09** | Owner rules beat older notes. If Studio still has the chase camera, ask Alex once which one they want live |
| C21 | **FOV punch on a normal fire** | 06 §2: 70 → 74 → 70 over 0.25 s. 16 §4: 70 → 80–85. 17 §1 (measured): no zoom on a normal throw | **17: none on normal shots.** Epic and up get the zoom (17 §2); 16's numbers are the ceiling for Legendary and up | The measured reference is quiet on purpose; repeated zooms tire the eyes |
| C22 | **Shake decay** | 16 §4: trauma +0.4 decaying 0.5/s | **1.0–1.5/s** (C5) | 0.5/s keeps shaking for 0.8 s after every rare shot |
| C23 | **Highlight limit** | 15 §3: "Roblox caps Highlights at 31" | **255 engine limit; budget 3 decorative plus a pool of 8** (C9) | Outdated number |
| C24 | **Divine length** | 17 §2: top tier 4.5 s; 22 §4.3: Divine 5.0 s; the rework (Nov 1): 7 s with a slow orbit | **7 s for Divine only**, with Skip from 1 s, and only if Divine stays under 10% of play time | Alex asked for more screen time on the best shot; it's the rarest, so the budget holds |
| C25 | **Button size** | 06 §6: at least 44 px. 09: small, premium buttons (Cannon UI 18% smaller) | **Small on desktop, about 44 px on phones** | Both are right; phones keep near full size (09) |
| C26 | **Sound sourcing for pack sounds** | CLAUDE.md: make our own. The rare-shot rework used 5 sounds from Alex's licensed SFX pack | **Our own or Roblox-licensed; a pack Alex owns counts if its licence covers Roblox use** | The rule is about rights, not about who made the file |
| C27 | **Panel style** | Skill `roblox-cartoony-ui` §2: opaque toy panels, never see-through. 09 (Oct 30 style pass): see-through panels with floating titles and studded flat buttons, like Stone Skipping | **09 for Alex's games** | Owner taste beats a general guide; the skill's other rules (lip, stroke, colour meaning) still apply |

## 12. The ten-line review (paste into any "ready to show" message)
1. Animation: frame counts on a 30 fps capture are within §1.
2. VFX: ≤ 1 flash per second; the dip before the hit is ≥ 4 frames; particles < 300.
3. Camera: control is given back; no wall clipping; no shake on repeats.
4. Code: `check.sh` green.
5. Building: the part count and the phone screenshot from spawn are checked.
6. UI: the first 30 s show ≤ 2 buttons; the motion table is used.
7. Sound: no harsh clicks; one sound per beat.
8. Money: "Coming soon" for anything unbuilt; odds shown; no "VIP".
9. Retention: the return screen shows earnings and the next goal.
10. Pacing: the first reward is under 60 s on a phone.
