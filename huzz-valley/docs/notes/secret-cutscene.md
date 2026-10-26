# The Secret cutscene

Read before changing the Secret girl's reveal: its timeline, beams, camera, night look, sounds or streaming. Every
beat's time and the comparison with his reference (`design/vfx/ref3`): `docs/secret-beats.md`. Its sounds:
[sounds.md](sounds.md). Its effect pictures: [effects.md](effects.md).

## What it does
- `Shared/SecretReveal` (timeline, pure) + `Gameplay/SecretReveal` (effects, camera); the server sets `RevealAt` and
  the `Reveal` stage. Test in Studio with `Config/Round.StudioTestRarity = "Secret"`, or the admin panel's NEXT GAME
  ([economy.md](economy.md)). The Secret girls are **C.C. and Marin** (owner, Oct 17; `Config/GirlNames`).
- **10 s:** 3.4 s of beams building to the burst, ~4.2 s with her (lands, her NAME on screen 4.5 to 6.3, push into her
  face), ~1.9 s finale and rise, 0.5 s hand-back (a dip to black: [movement-and-camera.md](movement-and-camera.md)).
- **Night look:** a local look (Lighting/Atmosphere/Bloom/Sky/grade, EnvironmentDiffuseScale 0.25, the Terrain clouds
  thin and violet, the sun shrinks away; put back exactly; checked) until 8.3.
- **Beams** (`SecretReveal.PILLARS`, `LAYERS`): few (3 threads) → twins → a ring of 6 → all converge into the eyes'
  point; each a stack of 5 plain Beams (haze to white-hot middle, reads with nothing uploaded), pulses climbing
  (Transparency rebuilt per frame), helix strands, a gliding white filament, sparks, floor pools.
- Also shockwaves (dome, floor ring, ring facing you), a magic circle under her, a violet rim, her name card
  (`HuzzSecretName` ScreenGui, from the showcase's `GirlName` attribute); CarryAnimator keeps her Idle playing. The
  showcase stand and its lights hide during it.
- **Camera:** one smooth move through `SecretReveal.KEYS` (monotone cubic, always in front of her), one cut (`CUTS`
  6.4, under the swell); FOV kicks ease, shake is a 4.5 Hz wobble.
- **Framing on every map** (`Shared/SecretReveal` "Framing on every map", planned once at the start on each screen):
  the whole camera path is tried from 16 sides of her (a ray from her to the camera every 0.8 s, then every 0.2 s on
  the 2 best sides: 326 rays on his maps, was 816 in one frame, which hitched phones; the same side on all 3 maps,
  `NUMBERS=1` prints it; rays skip see-through parts and every character); the clearest side wins (your side breaks a tie, 6% weight); where that path still
  meets something the camera is pulled in ahead of time (`planReach`: never more than what is clear, changing at most
  `RATE` 0.5 of the distance a second, never across the cut) with a wider lens so she stays the same size
  (`wideFov`, at most 90 degrees). Nothing is decided by a ray frame by frame any more.
- **One steady clock:** the server time is read once at the start, then the screen's own clock runs the scene
  (`GetServerTimeNow` is nudged as it re-syncs).
- Lesson: **a camera ray must skip see-through parts.** Every map has an invisible `Middle` box (and the zones) with
  CanQuery on; the old per-frame ray from her to the camera hit the Middle box's top whenever the camera went low, so
  on Base and BasketBall it snapped into her body (to 5-11% of its distance, 28 studs in one frame on BasketBall) and
  back out: the "very off" angle and the choppy jumps. Measured on his place with `motion3d/secret_maps_scene.luau`
  (`NUMBERS=1` prints, per map, the side picked and how far in the camera came before and after).
- **Streaming:** the owner's place streams (StreamingEnabled): the showcase is `ModelStreamingMode` Persistent and
  RoundService streams the spot in around everyone (at most 3 s, `ReplicationFocus` until the end) before `RevealAt`.
- **Floor:** the showcase floor is read from 6 studs over the Middle box, and the client re-reads the floor under her
  and keeps the camera 1.5 over it.
- World prompts that open menus are blocked during `HuzzCinematic` (it plays in the lobby before roles are set).

## Checks and films
- Checks in `check_girl_fx.luau` (camera per frame, length 8-11 s, beams few → many, name readable, beat order).
- Film `motion3d/secret_scene.luau` (real module; bloom and sky are imitations; `SECRET_NOTEX=1` = today's look with
  nothing uploaded) → `docs/previews/secret-cutscene.mp4`, `secret-cutscene-notex.mp4`, `secret-vs-ref3.jpg`
  (`secret_vs_ref.py`), `secret-vs-ref3.mp4` (`secret_vs_ref_video.sh`, the reference re-timed to our beats);
  flashes `tools/preview/flash_check.py <film>`.
- Before | after per map: `docs/previews/secret-maps.jpg` (`motion3d/secret_maps_scene.luau` + `secret_maps_sheet.py`;
  the map as boxes, a pink stand-in girl). Checks for the framing maths in `check_girl_fx.luau` (a clear side beats a
  blocked one, the plan never sits in a wall, the camera still glides round a wall, her size holds).
- Not seen in Studio yet. Only the line from her middle to the camera is checked, so a prop can still cross part of
  her (Halloween at 5.2 s: a plank in front of her legs); meshes count as their boxes offline; terrain is untested
  offline (none on his maps today).

## Why it is this way / history
- **10 s since Oct 19** (owner: "more detailed, especially the beams ... make the duration of it logical"): it was
  14.5 s, which dragged, and everyone waits through it.
- **Camera** (owner Oct 18: "chopy", "not very logical"): hence one smooth move and one cut.
- **Framing per map** (owner Oct 19: "can you please fix the secret girl animations in different maps, they are
  sometimes very off with the camera angle, it doesnt look good"; "can you please fix up and tune up the secret
  animations, right now its still choppy sometimes"): the invisible Middle box stopping the camera ray, other players
  walking through the ray, and the re-syncing server clock.
- **Streaming:** his first Studio recording (old 7.5 s build) showed an empty spot with no girl and no map because
  the place streams.
- **Floor** (Oct 18): a ray started inside Halloween's grass missed the floor: she stood 8 low, knee-deep in the
  cutscene, camera under the floor.
- The owner's Oct 18 recordings showed the OLD cutscene because Rojo put old scripts back (core `CLAUDE.md` section 7,
  "Which code ran?").

## The Divine cutscene (Oct 26)
Owner: "for the divine ... make it completely different from the secret animation ... way smoother". "Heaven's Gate":
the sky opens in a gold portal, spears of light strike, a three-ring halo gate comes down, a sigil draws itself on the
ground, one pillar of light slams down, she rides it down, wings of light fan open, the halo becomes her crown, DIVINE
name card with a shine, she ascends.
- **Style (owner, Oct 26 17:42: v1 "looks too ai made", follow the references):** v1 was golden dusk with soft god
  rays, cloud smoke, ForceField shells and a mist bed; all of that read as soft "AI" glow. v2 copies the reference's
  execution in gold/white: deep blue night with stars, hard neon (white core, gold band, amber edge), lightning
  crackling on the spears, gold slashes, a manga impact frame (black ink claws on white; 0.12 s), speed streaks
  (diagonal) down then up, crescent swings, flying gold shards, a radial ray burst, star flares, a vignette and a
  push in to her face. Never bring back smoke, ForceField glow or wide faint beams here.
- Timeline, camera, flashes: `Shared/DivineReveal` (one camera move, NO cut; the angle only ever grows).
- Effects: `HuzzClient/Gameplay/DivineReveal`. `Gameplay/SecretReveal`'s play() runs it when the showcase's
  `RevealKind` is "Divine" (RoundService sets it), sharing the camera planning and hand-back; the hand-back fades
  through warm cream (`DivineReveal.DIP`), not black.
- Built only from neon parts, plain beams and Roblox's built-in sparkle/smoke (nothing to upload).
- Film: `DIVINE=1 SECRET_NOTEX=1 sh tools/preview/motion3d/video.sh secret_scene.luau out.mp4`. The film's os.clock
  now runs on film time (a heavy frame used to skip the cutscene ahead).
- Checks: check_girl_fx.luau "divine:" lines (plays, cleans up, Lighting restored, swells a second apart, smooth camera).
- Sounds: reuses the Secret beats for now (Build riser to the pillar, Burst, Reveal, secret_impact at the swell).
