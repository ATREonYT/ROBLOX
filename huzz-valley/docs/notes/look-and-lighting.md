# Look, lighting and sky (`Config/Look` → `HuzzServer/LookService`)

Read before changing the colour grade, Lighting, Atmosphere, sky, clouds or any lamp's brightness. The place build
saves these into the owner's place too (core `CLAUDE.md` section 4), so Studio's edit view shows the game's look.

## Today's look: even, cartoony light
- `Config/Look` → `HuzzServer/LookService` ("find the filters that make the game feel premium"): colour grade, bloom,
  soft sun rays, light haze, early-afternoon sun. Map parts keep the owner's colours; the floors keep his own colours
  and materials (the reference's grey stone tiles are map design, not light).
- **Technology ShadowMap** (`build_yours.luau`; sun shadows stay, lamps light softly with no pools or shadows of their
  own). Brightness 1.4, ClockTime 13, latitude 23, Ambient 150,150,160, OutdoorAmbient 210,210,218,
  EnvironmentDiffuseScale 1 (the blue-ish shade), EnvironmentSpecularScale 0.2, ShadowSoftness 0.6, Exposure +0.05,
  grade Contrast 0.05, Saturation 0.12, Bloom 0.4/24/1.6, SunRays 0.03.
- **Our lamps are turned down so the glow stays on the object:** lobby props 0.5/7 (fainter pad pools), board
  pumpkin/candle/base 0.4/5, 0.3/4, 0.3/6, aura stars 0.6+0.15t / 6+t, the showcase girl's key/rim/stand 1.5/0.8/1.0,
  the avatar stands' disc light 0.4 / Range 6 (`Gameplay/AvatarStands`). His own 38 pumpkin PointLights (0.5 / 8) are
  unchanged (ShadowMap drops their shadows). The board slab is his daylight slate ([lobby.md](lobby.md), "Lobby
  leaderboards"). SecretReveal's night look also sets EnvironmentDiffuseScale 0.25 (put back after).
- Measured on his reference (`design/lobby-ref/oct19-lighting-ref.png`, `tools/preview/feel/light_measure.py`, boxes
  `boxes_ref_oct19.json`): a cast shadow keeps 0.53 of the sunlit floor, a block's shaded side 0.82 of its lit top,
  shade a little blue (+53), sky 87,178,249.
- Model (`tools/preview/light`: `render_light.mjs` three.js scene from `tools/world/scene_dump.luau`, calibrated so the
  Oct 17 look gives the measured 0.25; `calibrate.py`, `looks.json`, `light_compare.py`): cast shadow / sun 0.51
  (reference 0.53, the Oct 17 look 0.29), sunlit floors as bright or brighter. Picture `docs/previews/lighting-vs-ref.jpg`
  (a model, not a render). Light audit of his place: `tools/world/light_audit.luau`. The cast-shadow numbers are a
  model; only Studio shows the real thing.
- Grade estimate: `tools/preview/feel/look_estimate.py` (lobby ~0.64, round ~0.72 at the Oct 17 tune); picture
  `docs/previews/lobby-look-before-after.jpg` (`tools/preview/feel/look_before_after.py`: a model of the grade, not a render).

## The sky
- No uploads: Roblox's built-in sky stays (his place sets no skybox IDs; no store skybox ID was found that we could
  verify). `Config/Look.Atmosphere` paints it bluer (Color 178,214,255 at the horizon, Decay 85,165,245 above, Density
  0.22, Offset 0.25, Haze 0.3), `Look.Sky` (sun 14, stars 3000; made in Lighting if missing) and `Look.Clouds` = real
  3D Terrain Clouds (`Workspace.Terrain > HuzzClouds`: Cover 0.4, Density 0.75, white). LookService applies them; the
  place build saves them.
- Model `docs/previews/sky-vs-ref.jpg` (`tools/preview/light/sky_model.py`: a model, not a render; its skybox colours
  are read off the reference, its clouds are flat blobs). A proper cartoon skybox would need 6 face pictures uploaded.
- The Secret cutscene's night look swaps and restores all of it: [secret-cutscene.md](secret-cutscene.md).
- Not seen in Studio yet: the Oct 19 even lighting and the Oct 19 sky.

## Why it is this way / history
- **Oct 17 feel study** (`docs/feel-study.md` gap 3): the floor was blown out (brightness 0.76 to 0.87, 35 to 48%
  clipped vs HV 0.62 / 15%) at Brightness 2.8 / Exposure +0.15, so the first tune went darker (2.0 / -0.1, grade
  Contrast 0.12, Saturation 0.35, haze Density 0.2, Haze 0.3, lifted cool shadows).
  Ambient 92,96,112, OutdoorAmbient 128,130,148 then.
- **Oct 18** (owner: "that brighter contrast ... but not too much contrast so it looks normal"): Brightness 2.2,
  Ambient 96,100,116, OutdoorAmbient 132,134,152, Exposure -0.05, Contrast 0.16, Saturation 0.4 (estimate on his lobby
  frame: brightness 0.65 -> 0.70, contrast +8%, nothing clipped; 2.3 / 0 / 0.18 / 0.42 clipped a third of the floor).
- **Oct 19, even light** (owner: "make the lighting be one to one as the game, you see how the objects dont have light
  only around them, there is even, nice, cartoony lighting over the map"). Ours (Oct 17 recording,
  `boxes_our_oct17.json`) kept 0.25: a strong sun over a weak sky fill, plus **Future** lighting, which gives every
  PointLight its own pool and shadows. So: ShadowMap, a softer sun over a strong sky fill (it was ClockTime 14.2,
  latitude 28, Bloom 0.55/22/1.5, SunRays 0.05), and a gentler grade (the Oct 18 0.4 Saturation made orange floors go
  neon). The lamps came down from: lobby props 1.4/12, board 0.8/7, 0.5/5, 0.6/9, aura stars 1.2+0.25t / 9+1.5t,
  showcase girl 2.2/1.1/1.4.
- **Oct 19, sky** (owner: "try making the skybox better for the better lighting experience"; same reference:
  saturated blue overhead, big soft white clouds low down, a clean horizon).
