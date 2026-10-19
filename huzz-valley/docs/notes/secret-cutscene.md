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
- Not seen in Studio yet.

## Why it is this way / history
- **10 s since Oct 19** (owner: "more detailed, especially the beams ... make the duration of it logical"): it was
  14.5 s, which dragged, and everyone waits through it.
- **Camera** (owner Oct 18: "chopy", "not very logical"): hence one smooth move and one cut.
- **Streaming:** his first Studio recording (old 7.5 s build) showed an empty spot with no girl and no map because
  the place streams.
- **Floor** (Oct 18): a ray started inside Halloween's grass missed the floor: she stood 8 low, knee-deep in the
  cutscene, camera under the floor.
- The owner's Oct 18 recordings showed the OLD cutscene because Rojo put old scripts back (core `CLAUDE.md` section 7,
  "Which code ran?").
