# Effects: Juice moments, abilities, the heartbeat, the girls' VFX, the showcase girl, effect pictures

Read before changing world effects for round moments, the abilities, the heartbeat, the girls' auras, the big showcase girl or
how effect pictures load. Knife effects (by tier and theme, Huss Valley's restraint, `Shared/KnifeFx`, Oct 20):
[knives.md](knives.md), "Knife effects: the Huss Valley study", and the repo's `VFX-ITEMS.md` for any item; the catch's red fill: [stab-lunge-catch.md](stab-lunge-catch.md);
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
- **The look is the pre-rename one** (Oct 20, owner: "bring back the nice effects with the power ups, because right
  now it just looks like a bare copy, i mean just keep the same effects, change the name"): every ability in the old
  pink: white core, pink glow (`Fx.Glow`), purple edges (`Fx.Edge`), with hearts (emoji, no upload); the server's
  bubble and speed trail in `PowerService` PINK (255, 110, 190), the Love Trap's heart disc as the Bear Trap,
  "💘 STUCK!" and "😍" on a slowed runner, as Heart Shield, Rizz Rush, Love Trap and Charm Wave had. The new names and
  rules stay (Speed Boost only while carrying, the Bear Trap thrown). The cards keep their own `Accent` colours: before
  the renames (ed870f6) the cards had no colour per power at all (the kit's navy, pink only as the rim glow and the
  shield-on cover); the per-power colours came with his card pictures b and c (Oct 19), which the cards copy one to one.
- **Four beats, every ability** (Oct 20, owner: "right now they are kind of quick and feel cheap ... make them well
  made"): a wind-up you can read (`Fx.WindUp` 0.3 s by default: Speed Boost 0.18, Glitchy 0.1 to stay snappy, Banana
  Peel 0.22, Bear Trap 0.32, Invisible 0.35, Radar 0.4, Slow Wave 0.45; from 0.2 s up a ring gathers in at the feet and
  motes drift into the hand, with the quiet `power_charge` riser on the press), one bright frame (`Fx.Flash`;
  `Gameplay/Burst.flashOk`: at most one a second per screen), the effect (`Fx.Burst` 0.6 s), a clean end (`Fx.Fade`
  0.4 s: everything fades out or fizzles in a small ring with `power_end`, never just vanishes). The ability's own
  sound plays when the wind-up ends, not on the press. The server waits the same wind-up before the effect works
  (`HuzzServer/PowerService wind()`), so what you see is what happens, on every screen. Before Oct 20 the wind-up
  was 0.05 to 0.25 s and the effect 0.35 s.
- Improved Oct 20: Shield adds a second, slower ring and ends in a fizzle (ShieldEnd) instead of vanishing; Speed Boost
  adds a ground ring; Glitchy gets a short wind-up orb and a landing ring; Body Double ends in a puff of motes; the
  Invisible body fades back in with a small fizzle; the Bear Trap flies a touch slower (`Flight` 0.7) and fizzles when
  it runs out (TrapGone).
- **Shield** (was Heart Shield, once per round; once a game since Oct 24): the pink bubble bursts out with a ring and 💖 hearts; a blocked stab
  pops it in a pink ring with 💖 hearts.
- **Speed Boost** (was Rizz Rush; only while carrying her): a pink ring standing up behind you and white speed lines
  turning pink (the pink trail is the server's).
- **Invisible** (Lasts 4 s; new Oct 19, there was no old one): the pink glow, then on your own screen a shimmering
  pink bubble (6.4 studs) shrinks into the body with a ring, sparks and ✨; other screens get only a faint ring at the
  feet and a few sparks (Oct 20: the big bubble on everyone's screen pointed at who was vanishing; this is what the
  Oct 19 batch showed others, in pink). The body fades on every screen (`LocalTransparencyModifier`): others see it at `Seen` 0.88 with a slow
  shimmer (`Shimmer` 0.8 Hz, a soft swell, never a blink: "so it's fair"), you see yourself at `Self` (0.55 until Oct 22; now 1: owner, "make the invisible actually 1.00 invisible", so you
  are gone on your own screen too); name tag
  and outline hide on other screens; still catchable.
- **Glitchy**: a pink ring where you were; your own screen pushes you `Distance` 9 studs in `Time` 0.14 s (a
  LinearVelocity, so walls stop it); everyone sees two see-through ghosts (cyan and magenta) left behind sliding apart,
  thin glitch slivers, and sparks where you land. No flicker. Ghosts and afterimages are `Gameplay/Ghosts` copies:
  each part keeps its mesh (a classic hat's SpecialMesh, its picture cleared), so a hat ghosts as a hat, not as its
  Handle's plain box (critic Oct 20); `tests/PowerGhosts.spec`.
- **Body Double, Oct 22** (owner: "the clone double make it 0.00 invisible so its actually useful"): the copy is solid
  and plain on your own screen too (no pink shimmer, no see-through, no afterimages); `Powers.BodyDouble.Marked =
  true` brings the marks back. Below is how it was before.
- **Body Double**: a pink ring, sparks and ✨ where it starts; every screen clones the runner (scripts, sounds,
  constraints, its name tag and outline removed, the root anchored) and runs the copy straight on with `RunMotion`
  legs, following the floor, for `Lasts` 3.5 s or until a wall, a touch see-through (0.15) under a pink Highlight with
  a white outline that swells softly (one swell in 1.4 s, `DOUBLE_SWELL`), leaving a fading pink afterimage every
  1.2 s (`Config/Powers` `BodyDouble.AfterimageEvery`, never under 1 s: at 0.45 one popped about twice a second,
  critic Oct 20, kid-safe); then it puffs (ring, sparks, ✨). Oct 20 (coordinator, from the owner's "bare copy"): it
  was a plain copy, now it reads as an ability. Only a look, on each screen.
- **Bear Trap** (was Love Trap; owner Oct 19: "you throw the beartrap infront of you with a small animation"): the
  throw pose (`Config/Run.Cast.Throw`: the free arm swings back with the chest turning away, then whips forward;
  character attribute HuzzCastKind "Throw" from `Fx.BearTrap.Pose`), the trap leaves the left hand at the end of
  the wind-up: the old Love Trap exactly (`Shared/BearTrap`: a dark pink disc 2 x `Radius` across, a neon pink disc on
  it, a floating 💘 sign 1.2 studs up; Oct 20, "just keep the same effects, change the name": the metal toothed trap
  of the Oct 19 batch is gone, in the history at d6db14f). It spins flat along an arc (`Arc` 3.5 studs high), growing
  from 0.25 to full size, and lands where the server says: the Love Trap's pink ring slams out round it and settles
  to its size, with 💘 hearts; its neon disc is dim until it arms, then bright, with a purple ring. Caught: as the Love
  Trap, a pink ring closes in round the runner's feet and 💘 hearts pop (the server takes the disc away and shows
  "💘 STUCK!").
- **Slow Wave** (was Charm Wave): a pink ring gathers, then a pink and a purple ring run out with 💞 hearts (its slow
  lands when they do: PowerService waits `Fx.WindUp`), "😍" over each slowed runner. The old Charm Wave left no disc
  under slowed runners in any version (ece0c68 to ed870f6: only the badge); the pink disc in the old film's Charm Wave
  still is the Love Trap dropped earlier at the catcher's feet; 16 pieces a ring, no haze, every ring's pieces moved with one
  `Workspace:BulkMoveTo` a frame (`Burst.bulkMove`).
- **Banana Peel** (new Oct 20, runner, bought): tossed over the shoulder in a short arc and dropped `Back` 2.5 studs
  behind you, a yellow ring and 🍌 when it lands; it arms after `Arm` 0.4 s (its ring brightens). The first catcher on it
  slips: "🍌 SLIP!", three stars over the head (character SlipUntil), stuck and no stabbing for `Slip` 1.4 s (the
  Practice Bot trips too). Gone after 15 s with a small fizzle (PeelGone). One out at a time (`MaxOut`). Tell: it's
  big, yellow and glows. Counter: step round it.
- **Smoke Bomb** (new Oct 20, runner, bought): thrown down at your feet; 13 soft lilac balls swell into a cloud
  `Radius` 8 that breathes and thins out over `Lasts` 5 s. Inside it every runner's name tag and outline hide on
  everyone's screen, and catchers move at `Slow` 0.75. Tell: a big cloud. Counter: wait at its edge.
- **Radar** (new Oct 20, catcher, bought): a pink ring sweeps out to `Range` 70 in `Sweep` 0.9 s; each runner it reaches
  glows through walls for `Lasts` 4 s (a Highlight, AlwaysOnTop, a slow swell, no blinking) with a small ring at their
  feet and 📡. It only shows them. Counter: keep running.
- **Lasso** (new Oct 20, catcher, bought): the throw pose, then a rope with a loop flies straight ahead (`Speed` 70, up
  to `Range` 24). The first active runner it touches (never one in the start zone or frozen) is pulled `Pull` 7 studs
  in over `PullTime` 0.3 s (never closer than `MinGap` 4) and slowed (`Slow` 0.6) for `Hold` 0.6 s, with "YOINK!"; a
  Shield blocks it. The rope is 0.4 thick (critic Oct 20: 0.22 barely showed). The catch: the loop snaps tight round
  the waist (rope and loop white for a blink: a colour, not a flash), a ring slams out at the feet, "YOINK!" and a
  few sparks, `lasso_hit`; one short glow only through `Burst.flashOk`. A miss: the loop falls open to the floor with
  a dust ring, "MISSED" and `power_end`, lies a moment, then reels in. The pull is a LinearVelocity on the runner's
  own body, by their own screen (as Glitchy), so walls stop it; the server checks it (`PowerService` stepPulls,
  `AbilityRules.pulled`: at least 40% of the pull towards the catcher within the pull plus a round trip) and if their
  screen skipped it, pulls them itself through `PlaceService`. Neither side ever pulls a runner who is safe, caught or
  out, or after the run ends (`AbilityRules.pullHolds`: the screen lets go that frame; the server drops the pull, also
  when the round is cleared, or when it sent them a move just before the catch or since, which lets go of the pull on
  their screen too, `PlaceService.lastMoveAt`; sim Oct 20: a late pull dragged a runner back out of the safe zone).
  The check counts from the furthest back they were seen since the catch (a huss before their screen heard of it is
  fine), and the server's own pull starts from where they are.
  Tell: the wind-up and the rope. Counter: huss sideways.
- **Stun stars**: three cartoon stars circle slowly over the head of anyone stunned 1 s or more on every screen
  (character StunnedFrom / StunnedUntil), with the server's 💫 STUNNED badge. A dive's 0.4 s stun shows neither
  (Oct 20 15:13: the dive pops straight back up, [stab-lunge-catch.md](stab-lunge-catch.md)).
- Each has a sound; others' abilities pop their name over them (root +7, clear of their name tag); during the wind-up
  the caster strikes a cast pose (both arms forward and up 60°, a 10° lean: `Run.Cast`, or the throw, drawn by
  `RunMotion` on everyone via `RunAnimator`, local attributes HuzzCastAt/Len/Kind); your card squashes on press and its
  rim glows in the ability's colour when the server takes it.
- All plain neon parts (`Gameplay/Burst`: real rings of short pieces, glow orbs, world text), so nothing waits for an
  upload. Film: `motion3d/power_scene.luau` → `docs/previews/abilities-oct20.mp4` (all 11 in turn from a bystander's
  camera: the old ones improved, then Banana Peel with the slip, Smoke Bomb, Radar, Lasso with the pull; contact
  sheet at 2 frames a second `docs/previews/abilities-oct20-sheet.jpg`). The Oct 19 film `docs/previews/powers.mp4`. Old vs now: `docs/previews/powers-old-vs-now.jpg` (`tools/preview/powers_old_vs_now.py`: each power
  before the renames, as the Oct 19 batch left it, and now; the old film is `power_scene.luau` at ed870f6 with
  POWER_STILLS=1). Older sheet `docs/previews/abilities-sheet.jpg` (`tools/preview/powers_vs_og.py`, next to the other
  game's ability); the dive and stun: `docs/previews/dive-stun.mp4`.
- Not seen in Studio yet: all of the above. The film draws the Body Double's pink Highlight as a soft white fill (no
  coloured Highlight or outline offline). The card's picture is still his metal bear trap icon (picture b) while the
  thrown thing is the heart disc; "😍" over a runner slowed by a wave named Slow Wave is the old Charm Wave badge, kept
  as asked. Invisible, your screen vs everyone else's: `docs/previews/invisible-own-vs-others.jpg` (`power_scene.luau`
  with POWER_ME=1 films it as the runner sees it).

## The heartbeat (`Gameplay/Heartbeat`)
- Owner Oct 19: "add a heartbeat effect when someone gets closer" and "add a heartbeat sound when your screen turns
  red from people getting closer". A runner still in the round (Running / HeroRun, not in a cutscene): the nearest
  catcher or the Practice Bot inside `Far` 30 studs makes the screen's edges glow red (215, 24, 48), full at `Near` 8.
- Calm and kid-safe: one soft swell per beat (0.12 s up, eases back), `Rate` 0.75 to 1 beat a second (never more than
  one swell a second), the steady glow `Base` 0.22 + `Pulse` 0.33 at full strength, only the outer `Edge` 0.2 of the
  screen (0.12 at the sides); the level eases in and out, so a catcher appearing doesn't jump it. The beat clock
  (`Heartbeat.clock` / `tick`) never beats twice within `MinGap` 1 s and keeps counting while the glow is hidden (Oct
  19 evening, a fresh critic: it used to reset under level 0.01, so a catcher at the edge of `Far` beat on every rise).
- Built at runtime in PlayerGui (`HuzzHeartbeat`, DisplayOrder -1 under the HUD: a screen effect, nothing to edit in
  Studio). One heartbeat sound per beat, louder when closer ([sounds.md](sounds.md)).
- Spec `tests/Heartbeat.spec` (level, rate ≤ 1/s, swells ≤ 1/s, never solid, beats ≥ 1 s apart with the level
  flickering at the hide line); film `docs/previews/heartbeat.mp4`
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
- Only her root is anchored: every client plays the pack's Idle on her with feet swinging, a wave and a kick on top
  (`CarryAnimator`, `GirlMotion.showcase`, Oct 20: [animations.md](animations.md)) and hides the stand and its
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
- Abilities (Oct 20): the four new ones have glyph cards (🍌 💨 📡 🤠) until the owner sends pictures; their sounds are
  made here and wait for upload (`Config/SoundIds` ""; Roblox stand-ins meanwhile). The film draws Radar's pink glow
  as white and has no particle sparks. A cheating client could skip its own Lasso pull (the same as Glitchy and the
  huss). Smoke doesn't slow the Practice Bot.
- Not seen in Studio yet: the pickup's puff, sparkles and ring; the Juice bursts, the girls' effects with real uploads (every particle is a Roblox
  stand-in until `Config/ImageIds` is filled).

## Why it is this way / history
- **Abilities** (Oct 19 batch: "make simple lingo", "runner abilities (invisible, glitchy, body double", "bear trap you
  throw the beartrap infront of you with a small animation", "add a heartbeat effect when someone gets closer"). The
  four Oct 17 powers were pink and heart-themed (their sheet: `feel-powers-after.jpg`); the Oct 19 set took one colour
  each from its card, and the owner missed the old look (Oct 20: "bring back the nice effects with the power ups ...
  just keep the same effects, change the name"), so the effects are pink again and only the cards keep the colours.
  Invisible stays faintly visible on purpose ("so it's fair").
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
