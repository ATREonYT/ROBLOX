# Effects: Juice moments, abilities, the heartbeat, the girls' VFX, the showcase girl, effect pictures

Read before changing world effects for round moments, the abilities, the heartbeat, the girls' auras, the big showcase girl or
how effect pictures load. Knife effects: [knives.md](knives.md); the catch's red fill: [stab-lunge-catch.md](stab-lunge-catch.md);
the Secret cutscene: [secret-cutscene.md](secret-cutscene.md). How top VFX are built by code: `docs/vfx-guide.md`.

## Juice (`Gameplay/Juice`)
- One world effect per moment beside the message line (study gap 15): confetti on safe, a thin cut line and 10 sparks
  in the catcher's knife colour on a catch (the red read is RoundHud's red fill), a green ring lifting off the floor
  on a rescue, hearts and sparkles in the girl's rarity colour round the winner. The first runner safe each round gets
  "FIRST!" (RoundService `First` event; RoundHud).
- Shakes only for being caught (0.4), catching (0.4) and GO (none on a huss or lunge: HV has none).
- The screen edges glow red as a catcher comes within 40 studs (`HuzzDanger`, 1 Hz swell close up); getting caught
  tints your screen red for 0.7 s (`HuzzHit` ColorCorrection). Reduced Motion turns the shake and swell off.
- Smoke test: `smoke_feel_fx.luau` (harness).

## Abilities (`Gameplay/PowerEffects`, `Config/Powers.Fx`, the other game's ability timing)
- A glow builds (`Fx.WindUp` 0.25 s; Shield and Speed Boost 0.15 s, Invisible and Body Double 0.12, Glitchy 0.05),
  one bright frame (`Gameplay/Burst.flashOk`: at most one a second per screen), the effect 0.35 s, a 0.15 s fade; each
  ability glows in its own `Accent` (the colour on its card).
- **Shield** (blue, once per round): a bubble bursts out; a blocked stab pops it in a blue ring.
- **Speed Boost** (only while carrying her): a ring standing up behind you and white speed lines (the trail is the
  server's).
- **Invisible** (Lasts 4 s): a puff, then the body fades on every screen (`LocalTransparencyModifier`): others see it
  at `Seen` 0.88 with a slow shimmer (`Shimmer` 0.8 Hz, a soft swell, never a blink: "so it's fair"), you see
  yourself at `Self` 0.55; name tag and outline hide on other screens; still catchable.
- **Glitchy**: your own screen pushes you `Distance` 9 studs in `Time` 0.14 s (a LinearVelocity, so walls stop it);
  everyone sees two see-through ghosts (cyan and magenta) left behind sliding apart, and thin glitch slivers. No flicker.
- **Body Double**: every screen clones the runner (scripts, sounds and constraints removed, the root anchored) and runs
  the copy straight on with `RunMotion` legs, following the floor, for `Lasts` 3.5 s or until a wall, then it puffs.
  Only a look, on each screen.
- **Bear Trap** (owner Oct 19: "you throw the beartrap infront of you with a small animation"): the throw pose
  (`Config/Run.Cast.Throw`: the free arm swings back with the chest turning away, then whips forward; character
  attribute HuzzCastKind "Throw" from `Fx.BearTrap.Pose`), the trap (`Shared/BearTrap`, plain parts: two jaws of
  teeth, springs, a plate, a faint danger disc) leaves the left hand at the end of the wind-up, tumbles once along an
  arc (`Arc` 3.5 studs high), growing from 0.4 to full size, and lands where the server says, open, with a dust ring;
  a ring and a click when it arms. Caught: it snaps shut round the runner's feet in 0.08 s, holds, fades.
- **Slow Wave**: a ring gathers, then two rings run out (its slow lands when they do: PowerService waits
  `Fx.WindUp`); 16 pieces a ring, no haze, every ring's pieces moved with one `Workspace:BulkMoveTo` a frame
  (`Burst.bulkMove`).
- **Dive stun**: three cartoon stars circle slowly over a stunned catcher's head on every screen (character
  StunnedFrom / StunnedUntil), with the server's 💫 STUNNED badge; the body lies dazed ([stab-lunge-catch.md](stab-lunge-catch.md)).
- Each has a sound; others' abilities pop their name over them (root +7, clear of their name tag); during the wind-up
  the caster strikes a cast pose (both arms forward and up 60°, a 10° lean: `Run.Cast`, or the throw, drawn by
  `RunMotion` on everyone via `RunAnimator`, local attributes HuzzCastAt/Len/Kind); your card squashes on press and its
  rim glows in the ability's colour when the server takes it.
- All plain neon parts (`Gameplay/Burst`: real rings of short pieces, glow orbs, world text), so nothing waits for an
  upload. Film: `motion3d/power_scene.luau` → `docs/previews/powers.mp4` (each ability in turn, the trap thrown, landing
  and snapping), sheet `docs/previews/abilities-sheet.jpg` (`tools/preview/powers_vs_og.py`, next to the other game's
  ability); the dive and stun: `docs/previews/dive-stun.mp4`.

## The heartbeat (`Gameplay/Heartbeat`)
- Owner Oct 19: "add a heartbeat effect when someone gets closer" and "add a heartbeat sound when your screen turns
  red from people getting closer". A runner still in the round (Running / HeroRun, not in a cutscene): the nearest
  catcher or the Practice Bot inside `Far` 30 studs makes the screen's edges glow red (215, 24, 48), full at `Near` 8.
- Calm and kid-safe: one soft swell per beat (0.12 s up, eases back), `Rate` 0.75 to 1 beat a second (never more than
  one swell a second), the steady glow `Base` 0.22 + `Pulse` 0.33 at full strength, only the outer `Edge` 0.2 of the
  screen (0.12 at the sides); the level eases in and out, so a catcher appearing doesn't jump it.
- Built at runtime in PlayerGui (`HuzzHeartbeat`, DisplayOrder -1 under the HUD: a screen effect, nothing to edit in
  Studio). One heartbeat sound per beat, louder when closer ([sounds.md](sounds.md)).
- Spec `tests/Heartbeat.spec` (level, rate ≤ 1/s, swells ≤ 1/s, never solid); film `docs/previews/heartbeat.mp4`
  (`tools/preview/heartbeat_film.luau` + `heartbeat_film.py`: the module's own maths, a catcher walking in and away).

## The girls' effects (`AuraLook.girl` → `Gameplay/AuraFX`)
- For your companion, the round's girl and the prize; anchored to her and the floor like the pro references
  (`design/vfx/vysvex-green-reference.mp4`, ref3, Soul Reaper).
- A light pool + crisp ring flat under her feet (SurfaceGui circles on a thin part in `Workspace.HuzzAuraFX`, outside
  her model; it follows her lower foot, swells as she breathes, a highlight runs round the ring; on the prize it
  lights her stand top; hidden while carried or while `HuzzRevealing`).
- Flame tongues wrapped round her (Beams twisting up from her feet, curling in over her, staggered heights, the ring
  turning slowly, saturated, a white-hot inner ring behind her outline; outer ZOffset small, so they cross her legs
  but not her face), orbiting neon balls with Trails (trails off while she walks), trails on feet/hands only while she
  moves, puffs per stride, streaks rising off the floor, and a beat (draw in 0.35 s, flare, a ring runs out, sparkles;
  Mythic up a crescent slash) every 3.6/3.0/2.6 s.
- Carried: nothing on or from the floor (no pool, floor particles, puffs or foot trails). Streamed-out parts: Auras
  drops the effects and rebuilds them when she streams back.
- **Ladder:** Common = calm pool + 1 emitter; + ring (Uncommon); + runner, element, puffs, glow, 2 small calm tongues
  (Rare: same wrap and turn, end at her waist to chest, thin, soft, no core, no beat); + 1 orb, breathing, 3 small
  tongues (Epic); + big flames with a white-hot core, beat, 2 orbs, foot trails (Legendary, 6 emitters); + slash, hand
  glints/trails, 3 orbs (Mythic, 7); + two tones, crystals, butterflies, halo, 4 orbs (Secret, 9; budget 12). The prize
  gets at least the Rare look. Tongues: Legendary 4+1, Mythic 5+2, Secret 6+2, short and faint (outer alpha 0.4),
  soft lights, few streaks. Only the particles wait for uploads; everything else shows today.
- Worn auras: flame particles move with the body (inherit 0.95), small, half the rate, half the light. Your own aura
  when she's equipped ("Player") and worn auras keep the older emitter look.
- Spec: `check_girl_fx.luau` (budget, ladder, Rare/Epic tongues smaller and fewer than Legendary's, beat, pool follows,
  no per-frame instances). Tier row `motion3d/girl_tiers_scene.luau` + `tools/fx/girl_tiers_sheet.py` →
  `docs/previews/girl-vfx-tiers.jpg`. Film `motion3d/girl_vfx_scene.luau` → `docs/previews/girl-vfx.mp4`; sheet
  `tools/fx/girl_vfx_vs_ref.py` → `girl-vfx-vs-ref.jpg`.

## The pickup's effects (`Gameplay/CarryAnimator` pickupFx, `Gameplay/Burst`)
- Owner, Oct 19: "add the nice girl animations when they are picked up". Each screen near it (150 studs), once per
  pickup and only while it is happening (not for someone who joins mid-carry): a small puff of 8 sparkles in her
  rarity colour and white where she appears, then as she lands in his arms 14 sparkles round her and a soft ring at his
  feet (1.2 to 5 studs over 0.55 s, fading over its second half), in her rarity colour (the Secret's near-black is a
  pale glow instead, as on her showcase). No screen flash at all (kid-safe). The film draws them as sprites (a
  stand-in for Roblox's particles): `docs/previews/girl-pickup.mp4`. The motion: [animations.md](animations.md).

## The showcase girl (`GirlService.showcase`)
- The big showcase girl over the map stands on a small stand with a glowing band in her rarity colour (never wider
  than her stance; inside her Aura box, so the cutscene's bounds don't change), a key light low in front (-0.3 x her
  height, Brightness 1.5), a rim light behind, a soft glow up from the stand (short ranges, nothing above her), and her
  name big in her rarity colour over her head (1.8 studs x scale above it, so her head doesn't cut the line seen from
  below; a pixel floor so it reads from the far end; stars white).
- Only her root is anchored: every client plays the pack's Idle on her (`CarryAnimator`) and hides the stand and its
  lights during the Secret cutscene. Her aura glows softly (`AuraFX`: scale > 1.5 → small light). Your companion
  steps in and out behind a puff of sparkles (`Auras`).
- Smoke test: `tools/preview/smoke_showcase.luau` (harness).

## Effect pictures (`assets/fx`, `Shared/FxTexture`)
- Made by `tools/fx/make_fx.py`, guide `docs/vfx-guide.md`; they load through `Shared/FxTexture` from uploaded IDs.
  Until the owner uploads, stand-ins show and shapes gated by `FxTexture.ready` stay hidden (nothing is uploaded yet:
  `Config/ImageIds` is empty, so every particle in Studio is Roblox's sparkle/fire/smoke; the girls' pools, rings,
  flames, orbs and trails need no picture; their flames turn soft once `Fx/BeamGlow` is in).
- The cutscene's 9 (beam-glow, beam-ladder, lightning, butterfly, crystal, star-flare, rays, nebula, bokeh) are the
  owner's own art since Oct 17: one sheet `design/vfx/owner-vfx-sheet-oct17.png` cut by `tools/fx/cut_owner_sheet.py`
  (re-run it if he sends separate files; don't redraw them with make_fx.py).

## Honest gaps
- Not seen in Studio yet: the pickup's puff, sparkles and ring; the Juice bursts, the girls' effects with real uploads (every particle is a Roblox
  stand-in until `Config/ImageIds` is filled).

## Why it is this way / history
- **Abilities** (Oct 19 batch: "make simple lingo", "runner abilities (invisible, glitchy, body double", "bear trap you
  throw the beartrap infront of you with a small animation", "add a heartbeat effect when someone gets closer"). The
  four Oct 17 powers were pink and heart-themed (their sheet: `feel-powers-after.jpg`); the new set takes one colour
  each from its card so a glance tells them apart. Invisible stays faintly visible on purpose ("so it's fair").
- **Juice** came from the feel study (gap 15). Oct 17 round 2 (owner: "more cinematic", "less ui", "cutscenes dont cut
  out") added harder shakes, the danger glow and the red hit tint. The caught shake came down from 0.7: with the red
  tint, the words and the fall it stacked up too much. Knife pass 2 swapped the catch's 30 red-and-white sparks for
  the knife-colour cut line.
- **The girls' effects** (Oct 18, owner: "they still look strange and low quality ... they just float there"; a critic
  called the old flames "two thin pastel stalks"). Rare: the owner picked "Small flames". Then calmer (owner Oct 18,
  "a bit more lowkey for some"): fewer, shorter, fainter tongues. Worn auras inherit 0.95 because at 0.4 a running
  player trailed a long glowing band.
- **The showcase girl** (study gap 12: she read as a dark blob). The band stays inside her stance: "the rings hid her
  from below". Nothing lights her from above: "too much light shining down". The key light sits low in front because
  she read dark from the field; it came down from 2.2 to 1.5 on Oct 19 with the even lighting.
