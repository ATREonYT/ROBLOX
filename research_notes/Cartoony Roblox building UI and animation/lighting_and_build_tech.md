# Lighting, atmosphere, post-processing, terrain and performance for a bright cartoony Roblox simulator ("Hood"), 2025–2026

> How I got the sources: create.roblox.com, devforum.roblox.com, medium.com and web.archive.org were all blocked by this environment's network proxy. I read the official Roblox Creator Hub docs from their source repository instead, [github.com/Roblox/creator-docs](https://github.com/Roblox/creator-docs) (latest commit 2 Oct 2026, so current). Each docs claim below links to the matching create.roblox.com page. I could not open DevForum threads in full. DevForum claims marked "(search snippet)" come only from search-engine summaries of those threads, so treat them as lower confidence.

## 1. Which lighting technology to use (Voxel / ShadowMap / Future → Unified Lighting) and what the Lighting property values mean

### Takeaway
`Lighting.Technology` is deprecated and can't be set from scripts. Lighting is now set with two scriptable properties, `LightingStyle` (Soft or Realistic) and `PrioritizeLightingQuality`. The old settings map onto them as Voxel = Soft + false, ShadowMap = Soft + true, Future = Realistic + true. Compatibility and Legacy can no longer be selected. For a bright cartoony city with readable sun shadows, use **Soft + PrioritizeLightingQuality = true** (shadow-mapped sun, the old "ShadowMap"). Use **Realistic** only if you want local lights to cast shadows (the gym interior, the shop at night) and can afford the cost.

### Cited Findings
**Unified Lighting (current system)**
- `Technology` "has been superseded by `LightingStyle` which determines the artistic intent behind lighting, and `PrioritizeLightingQuality` which indicates whether you prefer lighting/shading quality or view distance to scale down first." Technology is "non-scriptable and only modifiable in Studio" (security RobloxScriptSecurity). — [Lighting API reference](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Status of each Technology enum value: `Legacy` is deprecated and can't be selected in Studio. `Compatibility` "simulates the removed legacy technology and is now deprecated. To achieve a similar look, use `Voxel` Lighting and add a `ColorGradingEffect` post-processing effect set to the `Retro` preset." `Unified` (value 5) is deprecated. `Voxel` "Uses a 4×4×4 voxel map". `ShadowMap` gives "more realistic and crisp shadows from sunlight". `Future` gives "high-fidelity lighting and shadows." — [Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology)
- `LightingStyle.Realistic` = "The most advanced and realistic lighting and shadows Roblox can deliver". `LightingStyle.Soft` = "A flat, retro-Roblox look with softer lights and shadows." — [LightingStyle enum](https://create.roblox.com/docs/reference/engine/enums/LightingStyle)
- "`Enum.LightingStyle.Soft` is the stylized look; `Enum.LightingStyle.Realistic` is the naturalistic look. The actual shadowing path also depends on `PrioritizeLightingQuality` (for example, Soft with that property enabled uses shadow maps rather than voxel lighting)." `LightingStyle` and `PrioritizeLightingQuality` are both script-writable (security `None`). — [Lighting API reference](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- **Conflicting doc:** the Light Sources page says LightingStyle is "modifiable only in the Properties window for the global Lighting object." — [Light sources](https://create.roblox.com/docs/effects/light-sources). This contradicts the API reference's security `None`. A DevForum thread is titled "LightingStyle property keeps changing to Soft only in-game" — [DevForum 3437295](https://devforum.roblox.com/t/lightingstyle-property-keeps-changing-to-soft-only-in-game/3437295) (title only, not read).
- `PrioritizeLightingQuality`: "As the rendering quality level reduces, a setting of `true` prioritizes features such as advanced shadows and high‑quality shaders at closer distances, while a setting of `false` prioritizes view distance. If lighting and shadows are very important to the artistic feel of your game, set this to `true`." — [Global lighting](https://create.roblox.com/docs/environment/lighting)
- Default mapping from old Technology values: Voxel → PrioritizeLightingQuality false / LightingStyle Soft. ShadowMap → true / Soft. Future → true / Realistic. The same issue warns that Rojo/rbx-dom can serialize Voxel as an empty value, which "results in Roblox Studio using `Compatibility (2)`". — [rojo-rbx/rbx-dom issue #637 (July 2026)](https://github.com/rojo-rbx/rbx-dom/issues/637)
- Timeline: Unified Lighting entered Studio beta in January 2025 ("no changes in live experiences until full release where lighting preferences will be migrated and the Technology property will be deprecated") — [Bloxy News on X](https://x.com/Bloxy_News/status/1881791534917718321); [Weekly Recap Jan 20–24, 2025](https://devforum.roblox.com/t/weekly-recap-january-20-24-2025/3411316). It was later announced "fully live" — [DevForum: Let There Be (Unified) Light!](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512) (search snippet gives July 23, 2025 for the fully-live update). Roblox says it is "committed to maintaining the existing look and feel of all experiences" (search snippet of the same thread).
- Future lighting is "fully rolled-out to all Android devices" (client beta). For lower-end and mid-range Android, "the engine will reduce their lighting quality to offer them better framerate" (search snippet). — [DevForum: Future is Bright on Android fully rolled out](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808); [Progressive rollout thread](https://devforum.roblox.com/t/progressive-rollout-of-future-lighting-on-android-devices-client-beta/3064250)
- Studio starts new games on Soft: "Studio begins every game with `Soft` lighting which renders a flatter look with softer lights and shadows." Realistic "automatically detects when a user is either in an interior or exterior space." — [Environmental art: Construct your world](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/construct-your-world); [Customize global lighting (core curriculum)](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)
- Shadows degrade with graphics quality: "The Roblox engine automatically degrades shadow quality as client graphics quality level decreases, eventually disabling shadows altogether at quality levels below 4." — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- For Realistic interiors: "it's best to surround indoor spaces with Part objects with a thickness of at least 1 stud to prevent undesirable outdoor light from leaking". Roblox's sample uses at least 2.5-stud parts. — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)

**Lighting property semantics and defaults** (all from [Lighting API reference](https://create.roblox.com/docs/reference/engine/classes/Lighting) unless noted)
- `Ambient` defaults to `[0,0,0]` and is the hue for areas occluded from the sky. `OutdoorAmbient` defaults to `[127,127,127]`. "The effective OutdoorAmbient value is clamped to be greater than or equal to Ambient in all channels", so keep every Ambient channel ≤ the matching OutdoorAmbient channel.
- If `GlobalShadows = false`, "OutdoorAmbient will be ignored and the hue from the Ambient property will be applied everywhere."
- GlobalShadows voxel note: "each lighting voxel is 4×4×4 studs. This means objects need to be larger than 4×4×4 studs to display a realistic shadow."
- `ColorShift_Top` tints surfaces facing the sun or moon. `ColorShift_Bottom` tints surfaces facing away. Brightness strengthens or weakens both. "The influence of ColorShift_Bottom can be very hard to identify when GlobalShadows is enabled."
- Brightness: setting `OutdoorAmbient` to `[255,255,255]` "will make the place appear brighter than its default value of 127,127,127".
- `ExposureCompensation` defaults to 0, range −5 to 5. "A value of 1 indicates twice as much exposure and -1 means half."
- `EnvironmentDiffuseScale` and `EnvironmentSpecularScale` default to 0. When you raise Diffuse, "it's recommended to decrease Ambient and OutdoorAmbient accordingly." Specular "is especially important to make metal look more realistic."
- `ShadowSoftness` defaults to `0.2` and only works in ShadowMap or Future (i.e. a shadow-map-capable path). The Global lighting page says it's "only valid when LightingStyle is set to Realistic". — [Global lighting](https://create.roblox.com/docs/environment/lighting). These two docs pages disagree. There is also a DevForum bug report that the property is hidden when Soft is selected — [DevForum 3509181](https://devforum.roblox.com/t/unified-lighting-beta-shadowsoftness-lighting-property-does-not-appear-when-lightingstyle-is-set-to-soft/3509181).
- Brightness vs Exposure: a higher Brightness "increases all brightness of the space, including brightness within the shadows, which leads to an unintentional murkiness". ExposureCompensation "applies a bias toward increasing the effect of brighter parts of the environment." — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)
- Deprecated or no-ops: `Lighting.Outlines` (feature removed), `Lighting.ShadowColor` ("no current functionality"). `FogColor/FogStart/FogEnd` are hidden whenever an `Atmosphere` exists. `ExtendLightRangeTo120` is unused; local light Range is always clamped at 120 studs.

**Roblox's own stylized sample values** (official, exact)
- Island Jump (the core curriculum's stylized sample): Ambient `16,16,16`; ColorShift_Top `196,222,255`; OutdoorAmbient `134,158,190`; ShadowSoftness `0`; LightingStyle Realistic; ClockTime `9`; GeographicLatitude `78`. Atmosphere Density `0.375`, Offset `0.17`. — [Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)
- Outdoor campsite tutorial: EnvironmentDiffuseScale and EnvironmentSpecularScale `1`; ClockTime `17`; Ambient and OutdoorAmbient `156,136,176` (light purple). Atmosphere Density `0.272`, Haze `1`, Color `85,78,54`. — [Enhance outdoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments)
- Indoor cabin tutorial: ClockTime `15.6`, GeographicLatitude `323` (optional), Ambient `83,70,57`, ExposureCompensation `0.5`, Atmosphere Density `0.5`. — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)
- Laser-tag env-art sample: Ambient and OutdoorAmbient `26,34,36`; Realistic; ShadowSoftness `0.15`; GeographicLatitude `-18`. Atmosphere Density `0.285`, Offset `0.65`, Decay `254,254,254`, Glare `0.3`. — [Construct your world](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/construct-your-world)

**Community "cartoony" values (DevForum, search snippets only)**
- "Ambience: 163,163,163; Brightness: 2.67; Outdoor Ambience: 128,128,128; ShadowMap (0.27 softness) or voxel. Color Correction Contrast 0.1, Saturation 0.3, Tint 241,241,231." — summarized from [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686) / [Lighting Settings For Cartoony Style](https://devforum.roblox.com/t/lighting-settings-for-cartoony-style/2167959). The snippet doesn't say which of the two threads. Note that Ambient 163 > OutdoorAmbient 128, so the effective OutdoorAmbient gets clamped up to 163.
- For simulators: "Color Correction with 0.2 Brightness, 0.1 Contrast, 0.12 Saturation, TintColor [255,243,235]". Also "Brightness 2.5 and ExposureCompensation 0.1 working well" for cartoony. — same search result set (unverified which thread).

### Inferences
- **Pick Soft + `PrioritizeLightingQuality = true`** as the main setting for Hood. Soft is officially "the stylized look". The `true` flag gives shadow-mapped sun shadows, which read well on brick rowhouse facades and sidewalks, and keeps those shadows longer as quality scales down. Realistic adds local-light shadows and indoor/outdoor detection, which mainly helps the gym and shop interiors. On a mobile-heavy simulator audience that cost is rarely worth it. Hood's current `BlockBuilder.SetLighting()` uses Realistic, so A/B test Soft on a low-end phone.
- Because Technology can't be scripted and Rojo can mis-serialize it, set `LightingStyle` and `PrioritizeLightingQuality` explicitly in the Studio place, or in the Studio-time builder script, as Hood does with `pcall`. After publishing, check that they persisted. Don't put the Lighting service into `default.project.json` without explicitly listing all three properties (rbx-dom issue #637).
- Bright cartoon recipe built from the sourced numbers: keep Brightness around 2–3, raise OutdoorAmbient to about 128–160 neutral or slightly warm, and keep Ambient below it. Use ColorShift_Top warm (≈255,230,200) and EnvironmentDiffuse/Specular low to moderate (0.2–0.5). Toon looks usually avoid strong PBR reflections. Set ShadowSoftness about 0.15–0.3, ClockTime about 13–14.5 for a high, bright sun, and ExposureCompensation 0–0.3.
- The "evening hood" vibe in Hood's current map (ClockTime 17.2, warm ColorShift_Top 255,220,175, cool ColorShift_Bottom 137,163,194) matches the documented pattern: warm sun-facing light, cool shade. Its ColorCorrection `Saturation = -0.05` works against a "bright saturated cartoon" target. Sourced cartoony presets use +0.1 to +0.3.

### Gaps
- I found no published, verified Lighting values for specific top simulators (Pet Simulator 99, Bee Swarm, etc.). DevForum "how X does its lighting" threads couldn't be fetched.
- Whether `LightingStyle` is reliably settable at runtime from a server Script remains contradictory between docs pages. Needs a live test.
- I found no official per-device cost table for Soft vs Realistic.

## 2. Atmosphere, Sky, Clouds and post-processing: values for a bright cartoon look vs a sunset/evening "hood" look

### Takeaway
Atmosphere controls distance blending and sky color. Keep Density low (~0.25–0.38) and Offset low to moderate for bright stylized scenes, and add Haze and Glare (which require Haze > 0) for sunsets. Post-processing should be subtle: Roblox's own samples use ColorCorrection Contrast 0.05 / Saturation 0.1 and SunRays Intensity ≈0.02–0.04. Sky texture rotation (`SkyboxOrientation`) and dynamic Clouds (parented under Terrain, moved by GlobalWind) are documented low-cost ways to make the sky move.

### Cited Findings
**Atmosphere** ([Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere); [Atmosphere API](https://create.roblox.com/docs/reference/engine/classes/Atmosphere))
- Density: higher means more particles obscuring objects. Example tabs show `0` and `0.35`. Density doesn't directly affect the skybox.
- Offset: "When you increase this value, it creates a horizon silhouette; when you decrease this value, it blends distant objects into the sky." A low offset "may cause 'ghosting' where the skybox can be seen through objects/terrain." Examples: `0` and `1`.
- Haze: examples `1` and `2.8`. Combine with Color for mood ("smoky tint", "foggy blue tint").
- Color: examples `[255,255,255]` and `[255,200,255]`. Pair it with high Haze to make it visible.
- Glare: "you must combine a glare with a Haze value higher than 0". Examples `0` and `1`.
- Decay: hue away from the sun. Only visible when Haze and Glare are > 0. Examples `[255,255,255]` and `[255,90,80]` (reddish sunset falloff).
- Creator Store and other sites summarize presets like "Dark_menacing Density 0.7, Haze 1.5; horror_fog 0.95 / 2.5" (search snippet, third-party, [picoo.io guide](https://picoo.io/how-to-make/roblox-lighting-atmosphere)). Those are horror values, i.e. the opposite end from a cartoon look.

**Sky / celestial bodies** ([Skyboxes](https://create.roblox.com/docs/environment/skybox); [Sky API](https://create.roblox.com/docs/reference/engine/classes/Sky))
- `SunAngularSize` defaults to `21`, clamped to `[0, 60]`. Setting Sun or Moon angular size to `0` hides that body. `CelestialBodiesShown=false` hides all. `StarCount` controls stars.
- `SkyboxOrientation` (Vector3 degrees, applied Y then X then Z) can be animated. The sample spins at `ROTATION_SPEED = 5` degrees/sec on a Heartbeat with a 30° X tilt. The doc says "skybox orientation is a low-cost feature which works seamlessly across all platforms and visual quality levels". Celestial bodies and dynamic clouds don't rotate with it.
- Warm-sky skybox IDs used by Roblox's indoor-lighting sample: Bk `162001887`, Dn `161998893`, Ft `162001897`, Lf `162001904`, Rt `162001919`, Up `162001926`. — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)
- Cartoon and anime skyboxes are distributed on the Creator Store, e.g. [Anime sky (13107361022)](https://create.roblox.com/store/asset/13107361022/Anime-sky), [Anime skybox (105189455817751)](https://create.roblox.com/store/asset/105189455817751/Anime-skybox), and the [Sky and Atmosphere category](https://create.roblox.com/store/category/visual-effects/skyboxes-and-atmosphere). A DevForum tutorial covers "Making a Cartoony Sky without using skyboxes" for "simulation skies (like pet sim X)" using only the default sky plus Atmosphere — [DevForum 1991916](https://devforum.roblox.com/t/making-a-cartoony-sky-without-using-skyboxes-from-toolbox-or-making-one/1991916) (search snippet only).

**Dynamic clouds** ([Dynamic clouds](https://create.roblox.com/docs/environment/clouds); [Clouds API](https://create.roblox.com/docs/reference/engine/classes/Clouds))
- Clouds "only render if you parent the object under the Terrain class." Cover ranges 0–1 (examples 0.65, 0.8). Density mainly affects transparency (examples 0.1, 0.3). Lower values give light, semi-translucent clouds; higher values give stormy ones. Lighting and Atmosphere also influence Color, so it's "not intended as a dedicated property to simulate colored sunsets."
- Clouds drift with `Workspace.GlobalWind`. — [Global wind](https://create.roblox.com/docs/environment/global-wind)

**Post-processing** ([Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects) and API pages)
- Effects in `Lighting` apply to all players. Effects in `Camera` apply per player, e.g. blurring the world behind a shop menu.
- Bloom ([BloomEffect](https://create.roblox.com/docs/reference/engine/classes/BloomEffect)) "causes brighter colors to glow, similar to applying the neon Material to everything, including the Sky." Threshold: "If set to 1, only pure white colors will bloom. If set to 0, all colors will bloom." Size is a radius in pixels, and 0 disables bleed. Multiple Bloom effects compose.
- ColorCorrection ([ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect)): Brightness −1 to 1. Contrast < 0 reduces and > 0 increases. Saturation > 0 gives more vivid color, and −1 gives full desaturation. TintColor is multiplicative. Multiple instances compose.
- SunRays ([SunRaysEffect](https://create.roblox.com/docs/reference/engine/classes/SunRaysEffect)): Intensity is opacity (0–1). Spread should stay within 0–1 ("values outside that range have undefined behavior"). It "may not render on low-end devices."
- DepthOfField ([DepthOfFieldEffect](https://create.roblox.com/docs/reference/engine/classes/DepthOfFieldEffect)) is controlled by FocusDistance, InFocusRadius, Near and FarIntensity. It "may render differently on low-end devices."
- **New: ColorGradingEffect** with `TonemapperPreset` = `Default` ("post‑2019 Roblox appearance which provides vivid colors and high contrasts") or `Retro` ("pre‑2019… less saturated… less contrast"). Only the most recently parented instance applies. It's the official replacement for the deprecated Compatibility look. — [ColorGradingEffect](https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect); [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- Official sample values: ColorCorrection Contrast `0.05`, Saturation `0.1`; SunRays Intensity `0.023`, Spread `0.266`. — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)

### Inferences
Suggested presets, synthesized from the sourced ranges above. These are starting points to tune by eye, not values published by a specific hit game.

```lua
-- PRESET A: "Bright cartoon day" (lobby/daytime maps)
local L = game:GetService("Lighting")
L.LightingStyle = Enum.LightingStyle.Soft          -- verify it persists (see section 1)
L.PrioritizeLightingQuality = true                  -- shadow-mapped sun
L.ClockTime = 14; L.GeographicLatitude = 35
L.Brightness = 2.6; L.ExposureCompensation = 0.15
L.Ambient = Color3.fromRGB(120, 120, 135)           -- keep <= OutdoorAmbient per channel
L.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
L.ColorShift_Top = Color3.fromRGB(255, 235, 205); L.ColorShift_Bottom = Color3.fromRGB(150, 175, 210)
L.EnvironmentDiffuseScale = 0.3; L.EnvironmentSpecularScale = 0.2
L.GlobalShadows = true; L.ShadowSoftness = 0.2
-- Atmosphere: Density 0.3, Offset 0.2, Haze 0.5, Glare 0, Color (200,220,255), Decay (180,200,230)
-- Bloom: Intensity 0.3, Size 24, Threshold 0.95  (only near-white / neon blooms)
-- ColorCorrection: Brightness 0.03, Contrast 0.08, Saturation 0.2, Tint (255,250,245)
-- SunRays: Intensity 0.02, Spread 0.3
-- Clouds (under Terrain): Cover 0.6, Density 0.25, Color white; GlobalWind ~ (5,0,2)

-- PRESET B: "Golden-hour hood" (Block map; close to Hood's current values)
-- ClockTime 17.2–17.8, GeographicLatitude ~28, Brightness 2.4–2.8, Exposure 0.2
-- ColorShift_Top (255,200,150), ColorShift_Bottom (130,150,200)
-- Ambient (100,95,115) / OutdoorAmbient (150,135,140)
-- Atmosphere: Density 0.3, Offset 0.15, Haze 1.6–2.0, Glare 0.3–0.5, Color (255,205,160), Decay (150,120,170)
-- ColorCorrection: Contrast 0.06, Saturation 0.12 (not negative), Tint (255,240,225)
-- SunRays Intensity 0.03–0.04, Spread 0.6; Bloom Intensity 0.25, Threshold 0.9–1.0 so neon signs pop
```
- A Bloom Threshold above 1 (Hood currently uses 1.2) means almost nothing blooms except HDR-bright neon or sky. Lowering it to about 0.9–1.0 makes neon signage and string lights glow more. Combine this with Neon on light-colored parts (section 3).
- Use a Camera-parented BlurEffect or DepthOfField for shop or boxing UI focus rather than global DoF, which costs every frame on every client.
- Don't use the legacy Fog properties together with Atmosphere: they're hidden and ignored once an Atmosphere exists.

### Gaps
- No official preset library lists exact "cartoony simulator" Atmosphere values. The numbers above combine official examples and community snippets.
- I couldn't confirm the exact contents of the best-known DevForum lighting-preset threads (blocked).

## 3. Local lights (PointLight / SpotLight / SurfaceLight) and Neon glow

### Takeaway
Local lights go on a `BasePart` or `Attachment` (Attachment is recommended for point lights), with Range capped at 120 studs. Shadows on local lights are the expensive part: only enable them on a few hero lights. Neon is fullbright and bloom-driven, does **not** emit light, and its glow depends on the color's brightness (HSV Value). Pair a Neon part with a shadowless PointLight or SurfaceLight to "fake" emissive light cheaply.

### Cited Findings
- PointLight is for "non-directional lights like bulbs, torches", inserted "into an Attachment or a BasePart (Attachment is recommended for point‑specific light emission)". SpotLight is a cone with max `Angle` 180 (half sphere). SurfaceLight emits from a whole face; Angle 0 = straight out. Higher Brightness "doesn't light up a larger region around the light" (Range limits it). — [Light sources](https://create.roblox.com/docs/effects/light-sources)
- `Light.Brightness` defaults to 1. A light must be a direct child of a BasePart or Attachment that is in Workspace. A SurfaceLight on an Attachment behaves like a SpotLight. — [PointLight](https://create.roblox.com/docs/reference/engine/classes/PointLight), [SurfaceLight](https://create.roblox.com/docs/reference/engine/classes/SurfaceLight) API
- Max Range is always 120 studs for PointLight, SpotLight and SurfaceLight. — [Lighting API (ExtendLightRangeTo120 note)](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Official example light values: campfire PointLight Range `48`, Brightness `2`, Color `255,179,73`, Shadows on — [Enhance outdoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments). Candle PointLight Brightness `0.7`, Color `255,202,156`. Desk SpotLight Face Bottom, Angle `140`, Brightness `4`, Color `255,238,202`, Range `12`. Fill PointLight Range `12`, Color `142,157,125`. Clock SurfaceLight Brightness `2`, Color `146,255,251`, Range `4` — [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments). Lamp prop tutorial example ranges 8 and 12 — [Light with props](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/light-with-props).
- Setting a part's Material to Neon "will make the part appear to glow brightly, although it will not actually emit any light." — [Light with props](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/light-with-props)
- To recreate a pre-2019 look, "experiment with `TonemapperPreset.Retro` and set the brightness of all lights to a maximum of 1.0." — [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- Performance: "maps that contain a high number and density of light objects that cast shadows… can have performance issues." Mitigations: "Disable Light.Shadows on light instances where the object does not need to cast shadows. Limit the range and angle of light instances. Use fewer light instances. Consider disabling lights that are outside of a specific range or on a room-by-room basis." MicroProfiler scopes are `LightGridCPU` (voxel light grid) and `ShadowMapSystem`. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Neon behavior (community): "If you treat part color as HSV format, the Value (V) influences the glow… Color3.fromHSV(0,0,1) will glow, but Color3.fromHSV(0,0,0) won't glow at all, and Hue or saturation does not influence the glow"; "Bloom changes the intensity of the neon effect"; SurfaceGui and BillboardGui `LightInfluence` and `Brightness` give a neon-like glow for UI and signs (search snippet) — [DevForum: Everything about Neon shader in Roblox](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408). Also: "Neon is rendered completely fullbright… no shadows cast on it, and… will trip the bloom limits on detail quality higher than 7" (search snippet) — [Roblox Wiki (fandom): Neon](https://roblox.fandom.com/wiki/Neon), a community wiki of lower reliability.
- Community-reported Future light limit: "Roblox won't render anything above 819 lights in Future at once" (search snippet, unverified) — [DevForum: Increase Range Limit of Lights #170](https://devforum.roblox.com/t/increase-range-limit-of-lights/68336/170). There are also reports that Future is "much more intensive than Shadowmapping… especially when shadows are enabled on the lights" — [DevForum: Very poor performance with Future lighting](https://devforum.roblox.com/t/very-poor-performance-with-future-lighting-technology/1439704) (snippet).

### Inferences
- Pattern for Hood: give storefront signs, the gym "OPEN" sign and string lights a Neon material with a bright, saturated color (high V). Add at most one shadowless PointLight or SurfaceLight per sign cluster (Range 8–16, Brightness 1–2, warm color). Turn Shadows on only for 1–3 hero lights, such as the boxing ring spotlight.
- Under Soft (voxel-based local lighting), local lights are cheap but blocky at 4-stud resolution. That fits a cartoon style. Under Realistic they get per-pixel lighting and shadows but cost more on mobile.
- Toggle interior lights by proximity or room from a LocalScript (docs-endorsed mitigation) instead of leaving dozens of lights on map-wide.

### Gaps
- No official doc states how Neon renders differently under Soft vs Realistic. The "Future = emissive, ShadowMap = flat glow" claim came only from a third-party guide ([simplified.media](https://simplified.media/guides/roblox-lighting-atmosphere)) and isn't verified.
- No official per-device light budget. The 819 figure is an unverified forum claim.

## 4. Terrain vs parts for cartoony maps; water and stylized grass

### Takeaway
For a city neighborhood, build with parts and built-in materials. Use Terrain only where it adds something parts can't do cheaply: animated grass (`Decoration`) on park lawns, terrain water with waves and reflections, and as the parent for dynamic `Clouds`. The terrain grass and decoration settings are **not scriptable**, so set them in Studio.

### Cited Findings
- Terrain is "grids of voxels which are 4×4×4 stud regions". Animated grass "renders only on the Grass material". — [Terrain](https://create.roblox.com/docs/parts/terrain)
- Grass: enable `Terrain.Decoration`, then set `GrassLength` 0.1–1. Both are tagged **NotScriptable**. Grass sway follows `GlobalWind`, and its speed is reduced when players enable "Reduce Motion". — [Terrain](https://create.roblox.com/docs/parts/terrain); [Terrain API](https://create.roblox.com/docs/reference/engine/classes/Terrain); [Global wind](https://create.roblox.com/docs/environment/global-wind)
- Terrain water properties (scriptable): `WaterColor` default `[0.05, 0.33, 0.36]` ("a dark teal"); `WaterReflectance` 0–1, default 1; `WaterTransparency` 0–1, default `0.3`; `WaterWaveSize` max wave height in studs, 0–1; `WaterWaveSpeed` waves per minute, 0–100. "Some water properties are only visible while playtesting." Terrain materials can be recolored with `Terrain:SetMaterialColor()`, since `MaterialColors` isn't scriptable. — [Terrain API](https://create.roblox.com/docs/reference/engine/classes/Terrain); [Terrain](https://create.roblox.com/docs/parts/terrain)
- Terrain can be generated from code with `FillBlock`, `FillBall`, `FillCylinder`, `FillRegion`, e.g. `workspace.Terrain:FillBlock(CFrame.new(0,0,0), Vector3.new(4,4,4), Enum.Material.Grass)`. — [Terrain](https://create.roblox.com/docs/parts/terrain)
- "Built-in materials use far less memory than custom textures… Try to use materials whenever possible." — [Design for performance](https://create.roblox.com/docs/performance-optimization/design)
- Transparency: "Avoid transparency values other than 0 (visible) and 1 (invisible)", because of overdraw. — [Design for performance](https://create.roblox.com/docs/performance-optimization/design). The 2018 Part Instancing announcement says "semitransparent MeshParts (Transparency > 0) will not get instanced at all" (search snippet, old) — [DevForum: Part Instancing pre-release](https://devforum.roblox.com/t/part-instancing-pre-release-announcement/130333).

### Inferences
- Water in a city map (a fountain or a hydrant puddle): a part is cheaper and more controllable for small decorative water. Use an opaque or 0-transparency SmoothPlastic or Glass part in a saturated cyan, optionally with a scrolling `Texture` for motion. Use terrain water only for larger bodies where waves and reflections show (WaveSize about 0.1–0.3, WaveSpeed 10–20, Transparency about 0.5, WaterColor set to a cartoon cyan).
- Grass: because `Decoration` is Studio-only, a code-generated map can still use Terrain Grass. Have the builder call `FillBlock` with Grass for lawn strips in Studio, and keep Decoration on in the saved place. Otherwise use flat Grass-material parts. In a stylized look, plain colored parts often read better than detailed textures.

### Gaps
- I found no official guidance on performance cost of terrain water vs part water, or animated grass cost on mobile.

## 5. Performance for large part-built maps on mobile (streaming, collisions, instancing, textures, LOD)

### Takeaway
Turn on StreamingEnabled with the recommended baselines: MinRadius 64, TargetRadius 1024, ModelStreamingBehavior Improved, StreamOutBehavior Opportunistic, PauseOutsideLoadedArea, EnableSLIMAvatars. Build from many **identical** primitives and built-in materials so instancing collapses draw calls. Anchor everything static, and disable CanCollide, CanTouch and CanQuery on decoration. Use Box collision fidelity for small parts. Keep partial transparency, decals and particles rare. Stay under a measured baseline budget; Roblox's example budget is under 1,000 draw calls and 1,000,000 triangles. SLIM LOD can cover whole building models, but only for static, Studio-saved models.

### Cited Findings
**Budgets and measurement**
- Roblox's example: on a baseline device you might find you "need to stay below 1,000 draw calls and 1,000,000 triangles". Use Render stats (Shift+F2) and Developer Console (F9). The Studio emulator "isn't accurate for memory usage". At 60 FPS the frame budget is 16.67 ms. — [Design for performance](https://create.roblox.com/docs/performance-optimization/design)
- Third-party heuristic: "a well-optimised Roblox game targets fewer than 5,000 instances in Workspace during active play" (search snippet, unverified; possibly from [santozstudios](https://santozstudios.com/blog/roblox-performance-optimisation-guide/)). Roblox staff guide by MrChickenRocket on mobile optimization: [Real world building and scripting optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146) (couldn't fetch; snippet says it recommends turning `CastShadow` off on details that don't need it).

**Streaming** ([Instance streaming](https://create.roblox.com/docs/workspace/streaming); [Streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques))
- StreamingEnabled is on by default for new places and "cannot be set in a script". All streaming properties are non-scriptable (Studio only).
- Recommended values: `StreamingMinRadius` = default `64` ("to maximize how much the engine can scale the game down for low‑end devices"). `StreamingTargetRadius` = default `1024`. `ModelStreamingBehavior` = `Improved`. `StreamingIntegrityMode` = `PauseOutsideLoadedArea`. `StreamOutBehavior` = `Opportunistic` ("aggressively garbage collect content, significantly reducing memory usage"). `EnableSLIMAvatars` = `Enabled`. Optional: `PredictiveStreamingMode` = Enabled, which pre-fetches respawn spots and areas left by CFrame teleports.
- TargetRadius must be larger than MinRadius; the band between them is a buffer. Test streaming bugs with TargetRadius at its minimum, `64`.
- `ModelStreamingMode`: Nonatomic (default), Atomic (all descendants stream together), Persistent ("intended for very rare circumstances… overuse may negatively impact performance"; "load after join and never stream out, permanently occupying memory"), PersistentPerPlayer. Set it from Studio or server Scripts, "never in LocalScripts".
- Model structure: "Decompose container models" (huge container models hurt streaming). "Keep the spatial extent of each model under ~64 cubic studs to increase the likelihood that the entire actual model streams in together." Flatten nested hierarchies.
- Instances created by client scripts are exempt from streaming out unless parented under a server-created instance. Anchored assemblies stream part-by-part.
- For a hub-and-zones layout ("home base" and "trading hub"), add replication foci per area with `Player:AddReplicationFocus()`, but "each additional focus increases the server's workload".

**SLIM / Model LOD** ([SLIM](https://create.roblox.com/docs/workspace/streaming/slim); [Model API](https://create.roblox.com/docs/reference/engine/classes/Model); [ModelLevelOfDetail](https://create.roblox.com/docs/reference/engine/enums/ModelLevelOfDetail))
- `Model.LevelOfDetail = SLIM` "combines multiple parts into fewer draw calls" via cloud-generated composite meshes with multiple LODs. It works best on "static world geometry — buildings, props". Requirements: streaming on, place saved to Roblox (not local `.rbxl`), Team Create enabled. Limitations: "does not support models modified at runtime (parts added/removed, properties changed) or models that play animations", and excludes models containing Humanoids. `LevelOfDetail` is PluginSecurity (not settable from game scripts). `StreamingMesh` is the legacy imposter (no textures) and should be converted to SLIM. The demo place is "City People Cars SLIM Template".

**Draw calls and instancing** ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve))
- Instancing collapses "identical meshes with the same texture characteristics into a single draw call": the same MeshContent and either identical SurfaceAppearance, identical TextureContent, or identical Material when neither exists.
- "Objects like decals, textures, and particles don't batch well and introduce additional draw calls… property changes to ParticleEmitters can have a dramatic impact on performance."
- Other listed problems: excessive object density, too many `RenderFidelity=Precise` meshes, excessive shadow casting, high transparency overdraw, "Too many parts in a Model could cause rebuilds".
- Community (2018 announcement plus later replies, search snippets): "Parts of the same material, transparency and shape will generally render in one draw call". MeshParts that differ only in "Size, CFrame, Color and Reflectance… will be instanced". "If identical MeshParts are positioned further apart, they're split into different clusters". — [DevForum: Part Instancing pre-release](https://devforum.roblox.com/t/part-instancing-pre-release-announcement/130333); [Unions for performance?](https://devforum.roblox.com/t/unions-for-performance/2270887)

**Unions / MeshParts / RenderFidelity**
- RenderFidelity `Automatic` (default) gives highest detail under 250 studs, medium at 250–500, lowest beyond 500. Unions (PartOperation) can't use `Performance`. — [Meshes](https://create.roblox.com/docs/parts/meshes); [PartOperation API](https://create.roblox.com/docs/reference/engine/classes/PartOperation)
- Solid-modeling results over 20,000 triangles get simplified to 20,000. Runtime `UnionAsync` calls are asynchronous and "can impact performance… you should not perform a large series of calls… in quick succession." — [Solid modeling](https://create.roblox.com/docs/parts/solid-modeling)
- Community view: "MeshParts generally deliver superior performance for complex geometry… UnionOperations often impose significant overhead"; "Parts load the fastest" (search snippets) — [DevForum: Unions for performance?](https://devforum.roblox.com/t/unions-for-performance/2270887); [What does load faster? Mesh vs Union vs Part](https://devforum.roblox.com/t/what-does-load-faster-mesh-vs-union-vs-part/1544940).

**Physics and collision** ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve); [BasePart API](https://create.roblox.com/docs/reference/engine/classes/BasePart); [Meshes](https://create.roblox.com/docs/parts/meshes))
- "Anchor parts that don't require simulation."
- For parts that need no collisions, set `CanCollide`, `CanTouch` and `CanQuery` to `false`. `CanQuery` only takes effect when `CanCollide` is false. "There is a small performance gain on parts that have both CanTouch and CanCollide set to false."
- CollisionFidelity: Box has the lowest memory, and Default or PreciseConvexDecomposition are the most expensive. "It's generally safe to set any small anchored part's collision fidelity to Box." For complex large meshes, build custom collision from Box parts. The Tunable option exposes a `CollisionPrecision` slider.
- `CastShadow`: "not designed for performance enhancement, but in complex scenes, strategically disabling it on certain parts can improve performance". It may cause artifacts. It's most effective on small or far parts. Roblox's laser-tag sample disables it on edge-of-map foliage with "almost no difference".

**Textures and memory** ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve))
- "A 1024x1024 pixel texture consumes four times the graphics memory of a 512x512". Pre-compression doesn't help memory. Images usually need "at most 512x512" and "Most minor images should be smaller than 256x256". Upload each asset once and reuse it. Use trim sheets, sprite sheets for UI, and `SurfaceAppearance.Color` tints instead of recolored texture copies.
- Audio can be a "surprising contributor to memory".

**NPCs** ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve))
- Static NPCs: use `AnimationController` instead of Humanoid. Play NPC animations on the client. Disable unused HumanoidStateTypes (e.g. Climbing). Pool NPCs. Only spawn NPCs near players.

### Inferences
- Hood's maps are generated by Luau **in Studio** and saved into the place (the README says the map lives in the Studio place). That means SLIM is viable for static rowhouse and shop models. Have the builder group each building into its own model under about 64-stud extents, then set `LevelOfDetail = SLIM` (Studio or plugin context only). Don't use SLIM on models whose parts change at runtime (doors, animated signs, NPCs).
- Hood's builder sets `Ground` and `ElevatedRail` to `Persistent`. The docs warn persistent models "permanently occupy memory". A 725-stud-long rail is a large persistent model. Consider Atomic or default for the rail and keep only gameplay-critical pieces persistent.
- For generated geometry: reuse a small palette of part sizes, materials and colors (identical primitives instance well). Avoid per-part random Material variety. Prefer `Transparency` 0 or 1, keeping windows opaque "glass-look" parts unless see-through is needed. Set `CanCollide/CanTouch/CanQuery = false` and `CastShadow = false` on trim, rivets, sleepers, window frames and other small details, all anchored. These can be applied in the builder helper functions (`box`, `part`, `facpart`).
- `workspace.StreamingEnabled = true` in `BlockBuilder.lua` only works because the builder runs in Studio's command bar or plugin context. That line would fail in a live server Script.

### Gaps
- Roblox publishes no official "max parts on mobile" number. The 5,000-instance figure is an unverified third-party heuristic. Measure draw calls and triangles on a baseline phone instead.
- No current (2025–26) official statement on whether partially transparent *parts* (not meshes) still break instancing. The only source is the 2018 announcement.
- I couldn't read the MrChickenRocket staff optimization guide in full.

## 6. Making the map feel "alive" at low performance cost

### Takeaway
The cheapest life comes from engine-driven systems that need no per-frame scripting: GlobalWind (moves grass, clouds and wind-affected particles), dynamic Clouds, `SkyboxOrientation` rotation, low-Rate long-Lifetime ParticleEmitters (dust motes, leaves, fireflies) enabled only near the player, ambient sounds, and client-animated NPCs using AnimationController.

### Cited Findings
- GlobalWind "affects terrain grass, dynamic clouds, and particles". Particles follow it when `WindAffectsDrag` is enabled and `Drag > 0`. Fire and Smoke follow it by default. Official gust script: baseWind `(5,0,2)`, gust `(25,0,10)`, cycle duration 3.5 s, max delay 5 s, sine ramp over 100 steps. — [Global wind](https://create.roblox.com/docs/environment/global-wind)
- Skybox spin: `ROTATION_SPEED = 5` degrees per second, described as "a low-cost feature". — [Skyboxes](https://create.roblox.com/docs/environment/skybox)
- ParticleEmitter: "A single particle emitter can create up to 400 particles per second (100 per second on mobile). For best performance, keep the particle rate as low as possible." Particle size costs fill-rate, and overlapping particles cost overdraw. Flipbooks cost memory and are auto-deactivated on low-memory clients. — [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Third-party: "16000 particles on computer… 3500 particles on mobile" cap, and "set a separate mobile budget of 150-300 particles maximum"; for dust, "a Rate of 5 or 10 is often enough if the Lifetime is long"; disable emitters when the player isn't nearby (search snippet, unverified) — [kitsblox: Roblox Particle System Deep Dive](https://kitsblox.com/blog/roblox-particle-system-deep-dive)
- Write event-driven code rather than per-frame calculations, and break long work into chunks. — [Design for performance](https://create.roblox.com/docs/performance-optimization/design)
- NPC animations: run them client-side and use AnimationController for static NPCs. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Flickering-light tutorial exists for animated light effects. — [Create flickering lights](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/create-flickering-lights)

### Inferences
- Hood checklist:
  1. Set GlobalWind to about (4,0,2) with occasional gusts.
  2. Add Clouds under Terrain (Cover about 0.6).
  3. Run one LocalScript that tweens neon sign `Color` brightness (HSV V) to pulse or flicker. Tween a few properties rather than doing per-frame work.
  4. Add 2–4 ParticleEmitters at Rate 2–8 with long Lifetime: leaves near trees, dust in the gym, fireflies or sparks near string lights at night. Use `WindAffectsDrag` on outdoor emitters.
  5. Add positional `Sound`s: boombox, traffic, gym bag hits.
  6. Use the existing ambient neighbors and the bodega cat as client-animated AnimationController rigs.
- Gate emitters, NPC animations and interior lights by distance in one client loop running at a low rate (e.g. every 0.5 s), not per frame.

### Gaps
- No official numeric cost comparisons between ParticleEmitter, Beam and Trail for ambient effects. The mobile particle caps come from a third-party blog.

## 7. Notable resources: sample places, templates and DevForum threads

### Takeaway
The most reliable "copy this" lighting references are Roblox's own sample places, whose exact values are listed in sections 1–3: Island Jump, the Lighting Indoors/Outdoors UCT samples, and the laser-tag env-art sample. The SLIM city template shows streaming LOD for a city. DevForum preset threads exist, but I could only see them through search snippets.

### Cited Findings
- Island Jump - Completed Sample (stylized, official lighting values in section 1): [roblox.com/games/14238807008](https://www.roblox.com/games/14238807008/Island-Jump-Completed-Sample) via [Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)
- Lighting Indoors - Complete (UCT): [roblox.com/games/17562253150](https://www.roblox.com/games/17562253150/UCT-Lighting-Indoors-After) via [Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)
- City People Cars SLIM Template: [roblox.com/games/135885449743134](https://www.roblox.com/games/135885449743134/CPC-Slim-Template); SLIM Platform Avatars (200 animated avatars): [roblox.com/games/81704282913046](https://www.roblox.com/games/81704282913046/SLIM-Platform-Avatars). Both via [SLIM](https://create.roblox.com/docs/workspace/streaming/slim).
- Roblox offers an "AI streaming skill" (in Assistant or via Studio MCP) that "configures streaming settings to the recommended baselines" and adds WaitForChild and nil checks. A typical conversion takes "20-30 minutes and… roughly 200,000 tokens". — [Streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques)
- DevForum threads to read manually (blocked here): [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686), [Lighting Settings For Cartoony Style](https://devforum.roblox.com/t/lighting-settings-for-cartoony-style/2167959), [Which lighting style is best for cartoon style maps?](https://devforum.roblox.com/t/which-lighting-style-is-best-for-cartoon-style-maps/643528), [Guide to Lighting](https://devforum.roblox.com/t/guide-to-lighting/2764787), [Everything about Neon shader](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408), [Real world building and scripting optimization (Roblox Staff)](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146), [Unified Lighting fully live](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512), [Making a Cartoony Sky without skyboxes](https://devforum.roblox.com/t/making-a-cartoony-sky-without-using-skyboxes-from-toolbox-or-making-one/1991916), [Ultimate skybox pack](https://devforum.roblox.com/t/ultimate-skybox-pack/2472902).
- Legacy "Future Is Bright" comparison page (historical Voxel/ShadowMap/Future comparisons): [roblox.github.io/future-is-bright/compare.html](https://roblox.github.io/future-is-bright/compare.html). zeux's article [The Future Is Bright](https://medium.com/@zeuxcg/the-future-is-bright-updating-lighting-systems-in-roblox-27dcc85cc391) was not fetched (blocked).

### Inferences
- Older tutorials (pre-2025) that say "set Technology to Future/ShadowMap/Voxel" are now outdated in wording. Translate them with the mapping in section 1. Any advice to use "Compatibility" for a classic look should become Voxel/Soft plus `ColorGradingEffect.TonemapperPreset = Retro`. Advice to use Lighting Fog should become Atmosphere. `StreamingMesh` LOD advice should become SLIM.

### Gaps
- I found no "Mystery Dungeon" or stylized Roblox Studio template with documented lighting values. The Studio template list (`resources/templates.md`) wasn't examined in detail.
- I couldn't fetch the DevForum threads that analyze lighting in specific popular simulators.
