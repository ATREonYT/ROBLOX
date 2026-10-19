# Stab, lunge and catch (motion and VFX)

Read before changing how the click stab, a catcher's lunge, the catch or getting up look. The rules behind them
(hit boxes, ranges, cooldowns, rescues): [round.md](round.md). Huss Valley's read, frame by frame:
`docs/knife-study.md` (section 4 for the catch). Players read "catch", never "kill".

## The stab (`Shared/StabMotion`, scripted until `Config/Animations.Stab` is uploaded)
- `Config/Round.Stab.Time` 0.40 s, Huss Valley's slash from `docs/knife-study.md`: no wind-up; the arm sweeps out to
  the right side, landing at ~0.07 s, held out (free arm pointing ahead) to 0.24 s, back by 0.40; trail on 0.02 to
  0.45 of it. The wrist snaps the blade flat into the sweep and the body leans in a little. The knife arm is raised
  by the run's hunch so it slashes level while sprinting. Written after the animations (Frame order 30), so it sits
  over the run.
- A Game Pass knife's trail is in its element's colours, lasts 0.17 s (`KnifeLook.TRAIL.ElementLifetime`) and tapers;
  Epic and up draw a thin crescent round the front and right of the catcher (`KnifeLook.ARC`: a Beam on two root
  attachments, gone in 0.2 s, never solid) and a pass knife throws half its element's burst (`KnifeBurst`).
- The Practice Bot's stab shows too: RoundService sends "Stab" `{ bot = true }` on a hit (and at most once a cooldown
  while it keeps trying); `Gameplay/Actions` plays it on the `HuzzBot` model.
- Spec `tests/StabMotion.spec`, video `docs/previews/stab.mp4` (`motion3d/stab_scene.luau`). Before/after film
  `docs/previews/stab-before-after.mp4` + `.jpg` (`motion3d/stab_fx_scene.luau`, `STAB_OLD` = the old module copied
  next to the new one). Honest: the arm change is small; the arc reads faintly in the render.

## The lunge (`Shared/StabMotion` `LEAP`, `play(rec, now, true)`)
- **Your own lunge plays the moment you press Space** (`Gameplay/Dash` calls `Actions.lungeLocal` before its hit
  check; the server's "Stab" echo within 0.8 s is ignored). Everyone else plays it from the server's "Stab" `{ lunge = true }`.
- **The whole body leaps** (it owns the root joint and the legs as well as the waist, head and arms, then hands them
  back by `LEAP.Up` 0.72 s): no crouch first (the push is already moving at 72), the take-off pose blends in over
  `In` 0.12 s (4 frames at 30 fps, so no pop); the body tips 18-22° into the leap about the hips, the lead knee drives
  up (left leg forward; the side's own leg on an A/D leap), the back leg pushes off long behind and tucks in the air.
- **The knife leads**: the arm reaches ahead, the blade level and pointing forward (`REACH`), the free arm back.
- **The slash lands when the knife reaches someone**: `StabMotion.slash` from `Dash` (your screen's hit check) or from
  the server's "Caught" (everyone else's, so it lines up with the runner's fall there); if it reaches no one, at
  `SlashBy` 0.14 s. The sweep goes from the reach out to the right in 0.07 s, then the click slash's overshoot, hold
  and return. The slash trail, `KnifeLook.ARC` crescent and the `KnifeBurst` start with the slash, not at take-off.
- **Landing**: at the hop's end (`StabMotion.air()` = 2 x Up / 196.2) the body drops into a low lunge, tipped ~34°
  into the leap, lead foot ahead, back knee low; the hips come down by exactly what keeps the feet on the floor
  (`lowestFoot`, from the joints' C0/C1, not the parts, which lag a frame). Held to `Out` 0.47 s.
- **Height** (`Config/Round.Lunge` Up 24): 0.245 s in the air, 1.5 studs. The push (72 to 40 over 0.38 s, 19 studs)
  and the hit box are the round's ([round.md](round.md)).
- **The leap's ribbon** (`KnifeLook.CATCH.Streak`, HV's lunge ribbon): a Trail between two points on the UpperTorso,
  white into the knife's colour (its `SlashColor`, else steel white), 0.14 s long (~8 studs at the leap's speed), on
  for the push only (`Gameplay/Actions`).
- Spec `tests/StabMotion.spec` (leans in, never back; knee ahead and back leg behind; knife ahead with the blade
  forward; slash within 0.08 s of reaching someone, at SlashBy otherwise, before landing; lands tipped >28° with the
  feet on the floor; sideways tips and leads with that leg; body parts turn at most 16°/frame at 60 fps and 30° at
  30 fps; every joint handed back). Film `docs/previews/knife-leap.mp4`.

## The catch
- **Red fill** on the caught runner (`Gameplay/RoundHud`, on their team Highlight, everyone's screen,
  `KnifeLook.CATCH.Fill` / `catchFill`): FillTransparency 0.12 for 0.07 s (HV's 2 solid frames), up to 0.6 by 0.25 s,
  gone by 0.42 s. The solid frames only through `Burst.flashOk` (one flash a second per screen), else the tint only.
  Then a **red outline while they lie down** (refreshHighlight: Runner + Downed = red).
- **Knife-colour touches** (`Gameplay/Juice`, one each per catch, calm): a thin cut line drawn on across the runner's
  back in 0.06 s and gone by 0.26 s (a Beam on their UpperTorso, so it falls with them) and 10 sparks, both in the
  catcher's knife colour. Your own screen keeps the red tint (`HuzzHit`) and the shakes (owner asked for shake).
- **The runner reacts, then falls with momentum** (`Shared/DownMotion`): the hit (`HIT`: in 0.1 s the back arches,
  head back, arms fly up and out, knees buckle; at its fullest before the body has tipped 10°, gone by 0.34 s), and
  the body slides on `Knockdown.Slide` 2.2 studs as it falls (fast, then settling). The server shortens the slide
  before a wall (`KnockdownService`: rays ahead at the waist and near the floor, and the field's invisible walls via
  `DownMotion.fieldSlide`; the character's `DownedSlide`); clients, the server's final placement, standing up and the
  rescue range all use it.
- Spec `tests/DownMotion.spec` (the hit at once, before the tip; slide fast at first and done by the landing; no
  slide = the old fall; no part over 45°/frame at 30 fps).
- Film `docs/previews/catch-before-after.mp4` (30 fps: side view, the catcher's camera, the runner's camera; before
  left, after right; full speed then 1/4 speed) and `catch-before-after.jpg`, from `motion3d/catch_scene.luau`
  (`CATCH_OLD=1` loads `StabMotionOld`/`DownMotionOld`: copy the old modules next to the new ones to re-render the
  before, then delete them; `CATCH_VIEW` = side / catcher / runner).
- Honest: not seen in Studio yet. The preview draws the red fill by recolouring the parts (Studio's Highlight fill is
  an overlay) and draws particles additively, so bursts over the sky look whiter than in Roblox. The run animation
  under the leap is the pack's, so the take-off blend in Studio starts from a mid-stride pose the spec doesn't test.

## Getting up (`DownMotion.rise`, `Gameplay/Knockdown`)
- The server stands a revived player up at once; the client tips the body back down about the feet and eases it up
  over 0.4 s (no pop). Spec `tests/DownMotion.spec`.

## Why it is this way / history
- **Stab, Oct 19** (owner: "better knife animations, not only during gameplay"): same timing and still no wind-up;
  the wrist snap, the lean, element trails, the arc and the burst were added then.
- **Lunge, knife pass 2, Oct 19** (owner: "give them a good vfx, make them have good animations, the leaping, the
  killing ... take your time"). Before, the lunge was the click slash at take-off with the legs still running, a
  0.18 s hop and a 35° waist dive only after landing, so it read as a stumble; and your own lunge waited for the
  server's echo (a round trip late).
- **Up 24, was 18**: at 18 the body was off the floor 0.18 s (5 frames) and 0.8 studs high, too short to show a
  take-off, a knife leading and a landing; HV's catcher is in the air ~0.4 s.
- **Catch**: the knife-colour cut line and 10 sparks replaced 30 red-and-white sparks (generic, and HV has none).
  Downed runners used to lose their outline. The runner used to stop dead from a sprint.
