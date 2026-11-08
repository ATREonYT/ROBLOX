---
tags: [chess-evolution, build-guide, game-feel, ui, lighting, duel]
updated: 2026-11-08
---

# +1 Chess Evolution: build guide (follow this)

Alex's verdict (Nov 8): Cannon Evolution's map looks good and its mechanics feel good; Chess Evolution feels far worse. This guide says what Cannon did that Chess didn't, and what Chess must copy. Every Studio or UI change to Chess follows it.

**Where things are**
- **The full vault Cannon was built from:** `~/Documents/GitHub/ROBLOX` (branch `claude/vault-everything`). It holds `CLAUDE.md`, `GAME-FEEL.md`, `VFX-ITEMS.md` and `Build Playbooks/` (start at `00 Build Router.md`). It also has the LihFolk Vault V2 in `LihFolk/LihFolk Vault V2/` (start at `ROUTER.md`) and the skills in `.claude/skills/`.
- The same Build Playbooks are on git branch `origin/claude/vault-all-notes` of the ATREonYT/ROBLOX repo.
- **Cannon code:** `~/Documents/GitHub/ROBLOX/cannon-evolution/src/`. Its history is in `reports/+1 Cannon Evolution build notes.md`.
- **Chess code** (newest): branch `origin/claude/project-thread-26r6uu`, `chess-evolution/src/`.
- **Reference notes:** [[00 Reference index (Nov 8)]] and [[Game feel findings for Chess Evolution (Nov 8)]].

## 0. Why Cannon came out better (the process, not just the code)
1. **It followed the router.** Cannon used `00 Build Router` → `Blueprint - Plus One Evolution` → the Sector Brief, with the `roblox-cartoony-ui` and `roblox-cartoony-building` skills loaded before building, and `GAME-FEEL.md` read first. Chess never loaded those two skills. Load them before touching UI or map.
2. **It used a golden slice and side-by-sides.** Cannon got one piece right against the reference, got a yes, then rolled it out, with one side-by-side picture per change (`CLAUDE.md` "How we build" 1–3). Do the same: no change is done without a same-framing side-by-side and a 30 fps clip for motion.
3. **One module per job.** Cannon has `GameClient/` with Kit, Sfx, HUD, Effects, Popups, Tutorial and others, each 70–1,200 lines. Chess is one 3,479-line `ChessClient.client.luau`, where fixes collide. New feel work goes into separate modules (see §7).
4. **Alex's rules were applied up front.** These are in `Build Playbooks/09 Owner Taste Rules.md`: small buttons, see-through panels with floating titles, no cast shadows, bloom nearly off, ASMR sounds, and no shake on repeat actions.

## 1. Lighting: copy Cannon's exactly
Chess (`MapBuilder.Light`) has cast shadows on, a dark ambient (110,110,120) and Saturation 0.18. That is why the studs look flat and grey next to the reference. Replace it with Cannon's `cannon-evolution/src/tools/BuildLighting.lua` values:

| Setting | Cannon (use this) | Chess now |
|---|---|---|
| ClockTime | 14.2 | 14.5 |
| Brightness | 2.5 | 2.6 |
| Ambient | (160,150,165) | (110,110,120) |
| OutdoorAmbient | (180,172,170) | (150,150,160) |
| ColorShift_Top / Bottom | (255,225,190) / (140,120,160) | not set |
| EnvironmentDiffuse / Specular | 1 / 0.3 | 0.6 / 0.3 |
| GlobalShadows | **false** (Alex, Oct 31) | **true** |
| LightingStyle | Soft, PrioritizeLightingQuality | not set |
| Atmosphere | Density 0.24, Offset 0.25, Color (255,225,190), Decay (150,200,255), Glare 0, Haze 0.05 | |
| ColorCorrection | Saturation **0.32**, Contrast 0.08, Brightness 0, Tint (255,250,240) | 0.18 / 0.06 / 0.03 |
| Bloom | Intensity 0.3, Size 8, Threshold 1.6 | 0.25 / 20 / 1.6 |
| SunRays | Intensity 0.03, Spread 0.6 | |
| Sky | SunAngularSize 13, no stars | |
| DepthOfField | off | off |

Back up the old Lighting children to ServerStorage first (the script does this as `OldLighting`). `GAME-FEEL.md` §9 says the ground should read mid-tone (about 0.6 brightness) with few blown-out pixels. Check this on a screenshot against the reference.

## 2. Pop-ups and juice (the biggest feel gap)
**Chess now:** `popGain` (ChessClient ~l.450) merges every gain within 0.6 s into **one label beside the HUD counter**. The reference shows **one "+N" per tap, in the world, at a random spot around the avatar** ([[Ref - Subscribers pop-up on tap]]).

**Build it like this** (a new `Popups` module, client only):
- **Look:** a pooled BillboardGui, AlwaysOnTop, LightInfluence 0, MaxDistance 120, about 200×60 px. Use the Elo/Power icon at text height on the left, then "+N" in FredokaOne about 40 px, white, with a 3 px black UIStroke.
- **Spawn:** take the HumanoidRootPart position and add a random offset of x ±2.5, y from −1.5 to +3.5, z ±1 (camera-relative), so they land above the head, beside the body and at the feet.
- **Motion:** UIScale 1.5 → 1 over 0.18 s with Back (Cannon's `floatingText`, `Effects.lua` l.86). Rise 1.5 studs over 0.7 s with Quad Out. At 0.35 s, tween UIScale to 0.6 and fade text and stroke to 1 over 0.35 s.
- **Count:** one per accepted tap and one per auto-train tick, **never merged**. Pool 16 for your own character, cap 12 live and recycle the oldest. Other players get at most 3, and only within 60 studs.
- **Keep the HUD counter roll too:** tween a parented NumberValue over 0.35–0.6 s and bump the pill 1.12 → 1 in 0.2 s Back (`14 Premium Feel` §4).
- **Tap aura** while tapping or training: a thin spinning ring (a Beam or a ring decal on a flat part at the waist) in the set's colour, plus 2–3 gold sparkles at the feet with Emit(2) per tap. No camera move.

**Juice sizes** (`06 Beat the Hits` §2): use these and nothing louder.

| Size | Event | Recipe |
|---|---|---|
| XS | tap, button | Scale set to 0.9 instantly, then 0.28 s Back to 1 (`Kit.press`, Cannon `Kit.lua` l.227). Soft click 0.1 s, pitch +1 semitone per tap capped at +7, max 8 a second. No particles |
| S | gain, small buy | the pop-up above, 4–8 particles, a chip sound |
| M | level up, stage clear | a ground ring under the feet (Size 2 → 10, 0.45 s, white to tier colour), a "Level Up!" pop and a sparkle column Emit(16). No screen effect |
| L | Promote/Evolve, rebirth | dim the screen 40 %, a rotating sunburst, big Back-eased text, confetti (`Kit.confetti`), one white flash (at most 1 a second), a sting of 0.8 s or less, "Tap to continue" |

**Win reward:** 8–12 Wins icons burst out around the avatar, then each flies to the Wins counter over 0.45 s (Quad In), staggered 0.03 s. The counter pops 1.15 → 1 as each lands. Big "+N Wins" over the head: hold 0.8 s, fade 0.1 s (`17 Do It Like the Hits`).

## 3. Duel and tap battle
From the long recording ([[Ref - Long gameplay recording]]):
- **Layout:** a red mat with two dark plates. The player is on the left plate and the rival on the right, facing each other.
- **Title:** a huge white "Stage N" with a dark outline appears, then clears.
- **Tug bar:** a green-versus-red bar centred low on the screen, with both names above it and "Click Fast!" under it. The split point eases to the new value over 0.12 s (springs, not a tween per tap).
- **Camera:** blend from the current view in 0.25–0.42 s to a low view behind the player (about 3 studs up, 7 behind, both characters in frame). Keep it still during the tapping: no FOV pulse or shake per tap. Hand control back 0.25–0.45 s after the win beat (master prompt §5; `28 Camera Playbook`). One script owns the camera. Save and restore CameraType, CameraSubject, FOV and UI on finish, loss, death and leave.
- **Each tap:** the player's piece or avatar does a small lunge (0.08 s forward, 0.15 s back). A clock tick sound plays and the bar ticks. A pop-up appears over the player as in §2.
- **Win:** keep the existing glass smash (branch 83z6je: 0.08 s hit-stop, +3 FOV spring, trauma 0.35, no roll). It is an L moment, so it may shake; Reduced Motion turns that off. Fire the shards and the sound on impact, not when the result arrives. Use about 8 pooled client shards in a Debris collision group, faded within 3 s (`Destruction and Fracture`).
- **Loss:** one clear loss sound, the bar flashes red once, then Retry big and Leave small. Return to normal within 1 s.

## 4. UI style
Load `.claude/skills/roblox-cartoony-ui/SKILL.md` first. Cannon's `Kit.lua` is the working implementation: copy `Kit.press`, `Kit.pop`, `Kit.cascade`, `Kit.button`, `Kit.panel`, `Kit.confetti`, `Kit.shine` and `Kit.rays`.
- **Fonts:** FredokaOne for lines and Luckiest Guy for big words, each with a dark outline and a soft drop shadow (`GAME-FEEL.md` §7). Chess uses only FredokaOne.
- **Buttons:**
  - Fill: a gradient with a stud tile at 0.82 transparency, TileSize 30.
  - Lip: a dark strip 5 px tall along the bottom at 0.72 transparency.
  - Outline: black stroke 3 Outside, with a white stroke 6 Outside behind it (cartoony-ui §1).
  - Start small, since Alex asked for smaller buttons twice.
- **Panels** (`Kit.panel`): see-through glass at 0.3 transparency, a 3.5 px stroke and no header bar. The title floats on the top edge, the icon sits on the top-left corner and the X on the top-right. Close only with X.
- **Motion:**
  - Panel in: 0.26 s Back from 0.75. Panel out: 0.14 s Quad In.
  - Cards cascade in 25 ms apart, at most 12.
  - Hover: 1.05 over 0.3 s Back, with the icon tilted −8°. Unhover: 0.3–0.5 s Sine.
- **HUD:**
  - Keep the reference layout already matched on Nov 7: Hud.Palette in `HudBuilder.luau`, plus the measured Shop and Promote from branch 2m6kty.
  - The counter is the biggest text on screen.
  - The HUD reveals step by step through the tutorial (`13 Beat Stone Skipping`).
- **Never:** emoji, "VIP", red error boxes, fake timers or invented asset ids. Show "Coming soon" for anything not built yet.

## 5. Tutorial arrows
Chess's chevron chain (ChessClient ~l.1148 and l.3416) should be replaced by Cannon's dart chain (`Tutorial.lua` l.328–470), which matched Alex's reference:
- **Count and flow:** 30 darts, spaced 1.05 dart lengths on screen. They flow 2.5 darts a second toward the target.
- **Dart shape:** LEN 1.6, HALF 0.95, NOTCH 0.5, THICK 0.12. Each dart is white, with a dark copy 1.3× bigger behind it as the outline.
- **Facing:** flat to the screen like a sticker, on one straight line from you to the target, floating rather than on the ground.
- **Size:** darts grow in near you and shrink into the target.
- **Hidden:** while training, in a duel, or when the target is closer than 7 studs.
- **UI steps:** a pulsing ring around the button and a bouncing arrow icon under it (`Tutorial.lua` l.315).
- **Text:** every tutorial word lives in one `TEXT` table, and the quest line counts live ("Train 25 Elo (14/25)").

## 6. Animation
- **Treadmill:** the run cycle plays while you stand on the deck, with AnimationTrack speed tied to belt speed. The belt ramps in over 0.2–0.35 s, keeps moving between ticks and eases out on step-off. Auto-train ticks about 4 times a second while you stand there ([[Ref - Auto-run on treadmills]]).
- **Treadmill neon:** it breathes 0.8 ↔ 1.0 every 3 s (Cannon `LaneMotion.client.lua`). Machines far from the camera stay still. Nothing flashes.
- **Gallery pieces:** they bob 0.2–0.4 studs with offset phases, and the nameplate stays still.
- **Springs:** use them for anything that can be interrupted (UI pops, the tug bar, lunges), with these presets from `17`: Pop (0.45, 7), Bouncy (0.5, 5), Clean (1, 4). Run all cosmetic motion on the client.
- **R15 since Jan 2026:** characters use AnimationConstraint joints, not Motor6D. Layer lunges by multiplying onto `Transform` in PreSimulation (`17`).
- **Evolve/Promote:** the new form pops 0.2 → 1.1 → 1 over 0.35 s Back with rays behind it, only after the server confirms (`11 VFX Moments` §5).

## 7. What to reuse from Cannon (files)
| Cannon file | Use in Chess for |
|---|---|
| `src/tools/BuildLighting.lua` | lighting, as is (§1) |
| `src/client/GameClient/Kit.lua` | buttons, panels, press, pop, cascade, confetti, rays, shine (§4) |
| `src/client/GameClient/Sfx.lua` | pooled sounds, SoundGroups, pitch ladder, mute setting |
| `src/client/GameClient/Effects.lua` l.86–100 `floatingText`, `shockwave`, `pulseBooth` (≤1 a second) | pop-ups and hit rings (§2) |
| `src/client/GameClient/Popups.lua` | reward, level-up and hatch-style reveal screens |
| `src/client/GameClient/Tutorial.lua` l.315–470 | arrow chain and UI pointer (§5) |
| `src/client/LaneMotion.client.lua` | belt scroll and neon breathing |
| `.claude/skills/roblox-cartoony-building` | studded map pieces, if any map work is needed |

Cannon files are `.lua` written for its own `ctx`/`State`. Port the functions into Chess modules (`Shared/FeelKit.luau` already exists for some of this). Don't paste whole files.

## 8. Done when
- A side-by-side with the reference (same framing) exists for the HUD, a tapping pop-up burst, a treadmill, the duel and a win. A 30 fps clip exists for tapping and the duel.
- No shake or zoom on taps, at most 1 flash a second, and Reduced Motion removes shake and halves FOV moves.
- The `16 Cartoony Kid-Appeal Checklist` (AI Video Library) passes.
