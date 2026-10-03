# Front-page brightness and "gamey" stage gates for Hood (Roblox, Oct 2026)

**What this note answers**
1. Why The Block looks dark in Studio, and what lighting makes a part-built simulator look bright, vibrant and busy.
2. How "+1 / wall / speed" simulators make their gates and stages read as a game.
3. How front-page games drop players straight into play, and how big servers should be.

It ends with two build-ready sections: **Lighting preset to use** and **Stage gate spec**.

**Reliability tags (read first)**
- **[S] Search summary.** The claim comes from a search-engine result summary. This session's egress proxy blocked every page fetch I tried: devforum, create.roblox.com, fandom, roblox.com, sportskeeda, simplified.media, picoo.io, creation.dev and others. Treat [S] as an unverified paraphrase of the linked page.
- **[D] Roblox docs.** Official Roblox documentation, verified by reading the docs source in the earlier Hood notes. I cite those by their create.roblox.com URL and did not re-verify them this session. See `research_notes/Cartoony Roblox building UI and animation/lighting_and_build_tech.md` and `research_notes/Tiered props VFX and vibrant maps/vibrant_maps.md`.
- **[R] Repo.** I read it in the Hood repo this session (`/home/user/ROBLOX/hood/src/...`).
- **[M] Memory.** From my own knowledge, not verified this session. Check it in Studio before relying on it.
- **[I] Inference.** My own analysis or design recommendation.

**Overlap with earlier notes.** The earlier notes already cover these, and this note doesn't repeat them:
- Unified Lighting (LightingStyle / PrioritizeLightingQuality)
- Roblox's own sample lighting values
- post-process semantics
- the color budget

This note adds four things:
- a diagnosis of *why* the map reads dark
- fixes for Studio-specific problems
- the gate and stage research
- final values

---

## 1. Why The Block reads "too dark", and how to fix each cause

### Takeaway
The darkness has several causes, and they stack:
- **(a)** A low, backlit sun. The original map is rotated so the stage street points *into* the 17.2 sun.
- **(b)** `LightingStyle = Realistic`. It's the high-contrast style, and the proposed Day preset never resets it.
- **(c)** Beige haze, a warm multiplicative tint and negative saturation.
- **(d)** Large low-value surfaces: blue-grey road, asphalt and Metal.
- **(e)** Studio shows the darkest case: full-quality shadows.

The proposed "Day" preset fixes (c) and half of (a). The rest needs the extra steps in the table below.

### Diagnosis table

| # | Cause (evidence) | Why it darkens | Fix |
|---|---|---|---|
| 1 | **Low sun.** ClockTime 17.2, GeographicLatitude 28 [R `BlockBuilder.lua:461`, `Maps.lua:7`] | My approximate solar math puts the sun at about **10–21° elevation** (it depends on the declination Roblox uses). A 20-stud terrace then casts a **50–110-stud shadow**, and a 40-stud street is mostly in shade, lit only by OutdoorAmbient. At ClockTime 13–14 the sun sits at about 50–75° and the same terrace casts 5–17 studs. [I] | Use **ClockTime 13–14** for day. Measure the angle with the Command Bar snippet below and aim for **50–65° elevation**. |
| 2 | **Backlit camera.** `BlockBuilder.Finalize()` sets `yaw = atan2(-sun.X, -sun.Z)` and pivots the map by it [R `BlockBuilder.lua:476`]. That rotation sends the map's local −Z (lobby → stages, the main camera direction) to the sun's horizontal direction. | Walking toward the stages, players look straight into the sun. Every gate face, facade and avatar shows its **shadow side**, and SunRays and Glare add flare. It's moody golden hour, but it isn't bright. [I, derived from the code] | Put the sun **behind** the main view. In TheBlockV2 (unrotated, `Origin = CFrame.new(2400,0,0)` [R]) you want the sun's horizontal direction within about ±60° of **+Z**. If it's in front, mirror ClockTime around noon (for example 13 → 11), which flips the east-west side of the sun. |
| 3 | **Realistic style.** `LightingStyle = Realistic` [R `BlockBuilder.lua:464`]. `HoodLighting.Apply('Day')` doesn't set LightingStyle [R `HoodLighting.lua`]. | Docs: Soft gives "flatter-looking lighting with diffused shadows and **lower contrast between shadowed and lit areas**", while Realistic gives high-fidelity, higher-contrast shading. Studio starts new games on Soft. [D/S] [Global lighting](https://create.roblox.com/docs/environment/lighting), [Construct your world](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/construct-your-world) | Set `LightingStyle = Soft` and `PrioritizeLightingQuality = true` in the preset, which keeps the shadow-mapped sun. Re-check in a live server: a DevForum thread reports the style reverting to Soft in-game ([3437295](https://devforum.roblox.com/t/lightingstyle-property-keeps-changing-to-soft-only-in-game/3437295) [S]). |
| 4 | **Beige veil.** Atmosphere Color (218,201,172), Haze 1.6–1.7, Offset 0.12, Glare 0.25 [R] | Haze tints and flattens everything at distance toward tan. A low Offset blends silhouettes into the sky. Haze is also what makes Glare visible. [D] [Atmosphere](https://create.roblox.com/docs/environment/atmosphere) | Haze ≤ 0.3, Color pale sky blue, Offset 0.55–0.65, Glare 0 (as in the Day preset). |
| 5 | **Grade removes light.** ColorCorrection Saturation −0.05, TintColor (255,245,228) [R] | TintColor is **multiplicative** [D] ([ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect)), so (255,245,228) cuts green by 4% and blue by 11%: a warm, dimmer image. | Saturation +0.2 to +0.28. TintColor (255,255,255) for day; keep any warmth to ≥ 250 per channel. |
| 6 | **Neon can't glow.** Bloom Threshold 1.2, Intensity 0.18 [R] | Bloom Threshold 1 means only pure white blooms [D] ([BloomEffect](https://create.roblox.com/docs/reference/engine/classes/BloomEffect)). At 1.2 almost nothing blooms, so the 11 Neon parts look flat. | Threshold 1.0–1.1, Intensity 0.6–0.9, Size 28–32. |
| 7 | **Low-value large surfaces.** Corridor road (75,82,99) covers 24 of the 40 floor studs [R `TheBlockV2.lua:28,245`]. Lobby asphalt (60,62,66) [R `SimulatorLobby.lua:13`]. 49 Metal parts in V2 (earlier note). | Shading multiplies albedo. sRGB 75 is only about 7% linear reflectance, so the bottom third of every gameplay frame is dark. Metal mostly reflects the environment, which is dull at dusk. [I] | Lift road to about **(104,112,134)**, still visibly asphalt. Add a bright center lane or crosswalk paint, and stage-colored lane stripes near each gate. Keep near-black for small trims only (earlier color-budget rule). |
| 8 | **Specular sky reflections.** EnvironmentSpecularScale 0.65 [R] on many SmoothPlastic and Metal faces | SmoothPlastic is **more reflective** than Plastic [S] ([fandom: Plastic](https://roblox.fandom.com/wiki/Plastic), [DevForum 2764770](https://devforum.roblox.com/t/how-can-i-lower-the-reflectance-from-smoothplastic/2764770)), so large faces pick up a sky-tinted sheen at grazing angles. The DevForum fixes are a MaterialVariant with roughness and metalness maps, or Plastic plus a SurfaceAppearance [S]. | EnvironmentSpecularScale **0.15–0.25**. Prefer Plastic (studded) for big walls. Save SmoothPlastic for small, saturated trim. |
| 9 | **Studio = worst case.** | The engine "degrades shadow quality as client graphics quality decreases, eventually disabling shadows altogether at quality levels below 4" [D] ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). Studio on a good GPU shows full shadows, which is the darkest look; low-end phones look flatter and brighter. Studio has **no Fullbright view**; it's an open feature request ([DevForum 4622596](https://devforum.roblox.com/t/fullbright-option-in-studio/4622596) [S]). | Judge brightness in Studio at max quality, since that's the worst case, and also on a real phone. Never "fix" it by making Studio-only changes. |
| 10 | **Washed-out stage walls.** White walls at Transparency 0.65, navy text, `MaxDistance = 32` [R `TheBlockV2.lua:1317–1326`] | The gate reads as a pale smear. You only see its text from inside 32 studs, about one gate ahead. | See the **Stage gate spec**: opaque colored frame, big number, glowing barrier. |

### Studio check-up (Command Bar)
```lua
-- 1) Sun elevation and direction (want elev 50–65 for day; horizontal dir toward +Z for TheBlockV2's stage view)
local d = game.Lighting:GetSunDirection()
print(('sun elev %.0f°  dirXZ=(%.2f, %.2f)'):format(math.deg(math.asin(d.Y)), d.X, d.Z))
-- 2) Is darkness shadow coverage? Toggle and look; undo afterwards.
game.Lighting.GlobalShadows = false   -- if the street suddenly looks right, fix sun angle / CastShadow, not ambient
-- 3) Kill one effect at a time to find the culprit
for _, e in game.Lighting:GetChildren() do if e:IsA('PostEffect') then print(e.ClassName, e.Name, e.Enabled) end end
```
[I] `GetSunDirection` returns the vector toward the sun [M]. Mirroring ClockTime around 12 swaps the sun's east/west side [I].

### Targeted fixes that keep sun shadows [I]
- **`CastShadow = false` on the terrace and rowhouse blocks that line the stage corridor.** Characters, gates and props still cast crisp shadows, so the street stays sunlit at any ClockTime. This is the single most effective "hood street" fix, because tall walls along a 40-stud street are what make the shade. ([BasePart.CastShadow](https://create.roblox.com/docs/reference/engine/classes/BasePart#CastShadow) is a standard property [M].)
- **GlobalShadows = false** is the community "simulator" shortcut. The "Best Simulator Lighting?" DevForum thread suggests it with Brightness 5, EnvDiffuse 1, EnvSpecular 1, Voxel (legacy), Exposure 0.1, Ambient (0,0,0), OutdoorAmbient (70,70,70), "a cartoony sky", and "make all materials SmoothPlastic", for an Expedition Antarctica / Arm Wrestle Simulator look ([DevForum 2569169](https://devforum.roblox.com/t/best-simulator-lighting/2569169) [S]). The catch is that with GlobalShadows off, "OutdoorAmbient will be ignored and the hue from Ambient applied everywhere" [D] ([Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)). Their Ambient 0 recipe gets its fill from EnvDiffuse 1 instead. You also lose contact shadows that ground props and characters. **Not recommended for Hood**, whose studded parts and terraces need shadow to read as 3D. Use it only as a "low graphics" fallback.
- **Brightness vs Exposure.** Raising Brightness "increases all brightness of the space, including within the shadows, which leads to an unintentional murkiness". ExposureCompensation "applies a bias toward increasing the effect of brighter parts" [D] ([Enhance indoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-indoor-environments)). For "a bit too dark", first raise **OutdoorAmbient** (shadow fill) and **Exposure +0.1 to +0.3**, then Brightness only up to about 3.
- **EnvironmentDiffuseScale and the sky color.** Environment diffuse is "ambient light derived from surroundings", and the docs say to lower Ambient and OutdoorAmbient when you raise it [S/D] ([Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting); [DevForum 559378](https://devforum.roblox.com/t/environmentdiffusescale-vsenvironmentspecularscale/559378)). Because that fill comes *from the sky*, a beige or dusk sky tints the shade brown and a clear blue sky tints it cool. That's one more reason to keep the day atmosphere blue [I].

---

## 2. What bright front-page simulator lighting looks like (2025–26)

### Takeaway
No hit game publishes its Lighting values. The consistent community and official pattern for "bright cartoony" is:
- a high sun (ClockTime about 12–15)
- Brightness about 2.5–3 (up to 5 in flat, shadowless recipes)
- strong shadow fill (OutdoorAmbient about 128–200, often cool-tinted)
- EnvDiffuse 0.5–1
- low haze
- ColorCorrection Saturation +0.1 to +0.3, Contrast about +0.1
- Bloom that only catches Neon
- a saturated cartoon sky with moving clouds

"Active" comes from motion (clouds, skybox spin, pulsing neon, particles), not from lighting.

### Cited findings
- **Technology and style.** `Lighting.Technology` is deprecated and replaced by `LightingStyle` (Soft / Realistic) plus `PrioritizeLightingQuality`. The old modes map as Voxel = Soft + false, ShadowMap = Soft + true, Future = Realistic + true. Unified Lighting went fully live in 2025, and the Legacy and Compatibility modes can no longer be selected. [D] ([Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting); [Unified Lighting is fully live](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512) [S])
- **Studio vs game.** Several DevForum threads report Studio and in-game lighting differing. Causes they mention include the Unified Lighting beta showing only in Studio, LightingStyle switching to Soft in-game, and graphics-quality differences. ([3795741](https://devforum.roblox.com/t/lighting-changes-style-between-studio-and-game/3795741), [3439038](https://devforum.roblox.com/t/lighting-in-game-is-different-from-studio/3439038), [1457451](https://devforum.roblox.com/t/game-lighting-darker-in-game-than-in-studio-preview/1457451) [S])
- **Community values for simulators.**
  - Simulator lighting should be "bright but not overbearing". One summary recommends Brightness 4–5 for sunny lighting, ColorCorrection Contrast and Saturation +0.1 to +0.2, and environment scales 0.5–1. [S] ([simplified.media](https://simplified.media/guides/roblox-lighting-atmosphere); [DevForum 2569169](https://devforum.roblox.com/t/best-simulator-lighting/2569169), but the summary doesn't say which source gave which number)
  - Cartoony grades quoted across threads: Saturation 0.12–0.3, Contrast 0.1–0.15, small Brightness 0.03–0.2, Tint near-white. [S] ([Lighting Settings For Cartoony Style](https://devforum.roblox.com/t/lighting-settings-for-cartoony-style/2167959); [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686); detail in the earlier `vibrant_maps.md` §2)
  - EnvDiffuse and EnvSpecular near 1 is described as "the modern-rendering look; both at 0 is flat and dated". [S] ([gamertagmythras guide](https://gamertagmythras.com/blog/roblox/roblox-lighting-atmosphere-guide))
  - For dark spots: raise Ambient and/or OutdoorAmbient, combined with Brightness. [S] ([DevForum 1863962](https://devforum.roblox.com/t/help-with-lighting-my-game-is-too-dark-at-some-places/1863962))
- **Roblox's own stylized samples.**
  - Island Jump: OutdoorAmbient (134,158,190) cool fill, ColorShift_Top (196,222,255), ClockTime 9, Atmosphere Density 0.375 / Offset 0.17.
  - Laser Tag: Atmosphere Offset 0.65, Bloom 1.5/56.
  - Outdoor evening tutorial: Ambient = OutdoorAmbient (156,136,176) lavender.
  - [D] Values and URLs are in `vibrant_maps.md` §2.
- **Studio's default for new places.**
  - Studio "begins every game with Soft lighting which renders a flatter look with softer lights and shadows" [D] ([Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting)).
  - [M, verify with File → New → Baseplate] My recollection of the post-2022 Baseplate template: ClockTime 14.5, Ambient and OutdoorAmbient (70,70,70), **EnvironmentDiffuseScale 1 and EnvironmentSpecularScale 1**, ShadowSoftness 0.2. It ships an Atmosphere (Density 0.3, Offset 0.25, Color 199,199,199, Decay 106,112,125, Haze 0, Glare 0), Bloom (1 / 24 / Threshold 2), SunRays (0.01 / 0.1) and a disabled DepthOfField.
  - **Implication [I]:** the modern default gets most of its shadow fill from the sky (EnvDiffuse 1), not from Ambient. A map that lowers EnvDiffuse (Hood's original 0.65) and uses a dusk sky gets darker shade unless OutdoorAmbient rises to compensate.
- **Post-process.**
  - Bloom "causes brighter colors to glow, similar to applying the Neon material to everything, including the Sky".
  - The ColorGradingEffect tonemapper `Default` gives "vivid colors and high contrasts"; `Retro` is less saturated.
  - Camera-parented effects apply per player.
  - [D] ([Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects))
- **ExposureCompensation** ranges from −5 to 5. +1 doubles exposure and −1 halves it, applied before tonemapping. [D/S] ([Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting))
- **Sky and clouds.**
  - Cartoon and anime skyboxes on the Creator Store include [Anime sky 13107361022](https://create.roblox.com/store/asset/13107361022/Anime-sky) and [Anime skybox 105189455817751](https://create.roblox.com/store/asset/105189455817751/Anime-skybox). There's also a DevForum method for "simulation skies (like Pet Sim X)" using only the default sky plus Atmosphere ([1991916](https://devforum.roblox.com/t/making-a-cartoony-sky-without-using-skyboxes-from-toolbox-or-making-one/1991916)). [S, via earlier notes]
  - `Clouds` render only when parented under Terrain, and drift with `Workspace.GlobalWind` [D] ([Dynamic clouds](https://create.roblox.com/docs/environment/clouds)).
  - `Sky.SkyboxOrientation` can be animated, and the docs call it "a low-cost feature which works seamlessly across all platforms" [D] ([Skyboxes](https://create.roblox.com/docs/environment/skybox)).

### Materials and color under light [I unless tagged]
- **Plastic (studded)** is the matte workhorse. It reflects less than SmoothPlastic [S], so big studded walls keep their albedo color from every angle.
- **SmoothPlastic** has more specular and sky reflection [S]. It looks crisp on small, saturated pieces such as trim, toys and signs. On big flat faces under a dull sky it goes milky or grey, so keep EnvironmentSpecularScale ≤ 0.25.
- **Neon** is emissive and ignores scene lighting. With Bloom Threshold ≤ 1.1 it gives the "gamey glow" for gates, pads and signs.
- **Metal** shows the environment rather than its color. It looks dark and grey under a dusk sky, so don't use it on large areas.
- **Color values.**
  - Lighting multiplies albedo. Under the ACES-style tonemapper, mid-value colors (V 40–60%) render noticeably darker than the color picker suggests [I].
  - Large surfaces should be V ≥ 70%. Hue-shift shadows cool rather than grey (earlier color-budget table in `vibrant_maps.md` §2).
  - Studs add small dark rings. If a studded wall reads darker than its SmoothPlastic neighbor, add about +5–10 value to it [I, verify by eye].

---

## 3. "Gamey" stage gates in wall, speed and strength simulators

### Takeaway
Across the "+1 Strength / Speed per second", Punch Wall, Race Clicker, Legends of Speed and Muscle Legends family, a gate is a **number you can read from far away, in a color that tells you how hard it is**, on a barrier that is obviously "in your way". Clearing it pays off with a burst, a sound, a banner, a counter tick and a reward (Wins or trophies).

Recurring conventions:
- the requirement or reward number is *written on the wall*
- a color or rarity ladder per stage, ending in a rainbow or gold final stage
- a barrier you can see through (neon, laser or forcefield) so the next zone is visible
- a trophy or win pad at the end of a run
- checkpoint and leaderboard "Stage" counters

### Cited findings (what games do)
- **Numbers written on walls.**
  - Fat Race Clicker: "each wall passed will give you the number of trophies written on the wall" [S] ([progameguides](https://progameguides.com/roblox/fat-race-clicker-codes/)).
  - Race Clicker: "each time you cross a line you get a win, higher lines give you more wins". It runs a 30-second click countdown and then a race of up to about 1.5–2 min [S] ([NamuWiki](https://en.namu.wiki/w/Race%20Clicker); [Droid Gamers](https://www.droidgamers.com/guides/roblox-the-games-race-clicker-guide/); [TheGamer](https://www.thegamer.com/roblox-race-clicker-codes/)).
- **Walls as stages.**
  - Punch Wall (2025): "break 40 lined-up walls in three different worlds", wall HP increasing down the line. Players walk into the passage made by broken walls, and get a **Trophy after breaking all 40** [S] ([Sportskeeda beginner's guide](https://www.sportskeeda.com/roblox-news/punch-wall-a-beginner-s-guide)).
  - Wall Punch Simulator: "smash your way through giant brick and crazy walls… complete over **100+ Rainbow Stages**" [S] ([Roblox page](https://www.roblox.com/games/12888107609/Wall-Punch-Simulator)).
  - "+1 Strength Per Click", "+1 Fist Per Click", "Break wall" and "+1 Strength to Escape" all describe the loop as "break walls to earn **Wins** and unlock stages" [S] ([+1 Fist Per Click](https://www.roblox.com/games/94440858954283/1-Fist-Per-Click); [Break wall](https://www.roblox.com/games/129634411989280/Break-wall); [+1 Strength to Escape](https://www.roblox.com/games/138078880987602/1-Strength-to-Escape); [rolimons +1 Strength Per Click](https://www.rolimons.com/game/120766736586332)).
- **Color = value.** Legends of Speed hoops are color-coded by payout: **yellow +150, blue +200, purple +600 steps**. Magma City has a Red hoop at 900 and a Yellow-Orange hoop at 1000, and a Speedway hoop gives 8,000 [S] ([Hoops wiki](https://legends-of-speed.fandom.com/wiki/Hoops); [Magma City](https://legends-of-speed.fandom.com/wiki/Magma_City)).
- **Portals and special barriers.**
  - Muscle Legends unlocks gyms by rebirth count (Frost 1, Mythical 5, Eternal 15, Legends 30, Jungle 60). The top gym's portal has "electric effects" [S] ([Legends Gym](https://muscle-legends.fandom.com/wiki/Legends_Gym); [Rebirths](https://muscle-legends.fandom.com/wiki/Rebirths)).
  - Steal a Brainrot base gates are red laser beams (earlier `vibrant_maps.md` §1 [S]).
- **Gate = the strength check itself.** Strongman Simulator: "drag huge objects blocking the exit in each area" (for example a Protein Bar Gate) [S] ([Strongman wiki](https://roblox.fandom.com/wiki/The_Gang_Stockholm/Strongman_Simulator); [kitsunes areas](https://kitsunes-strongmansimulator.webador.com/areas)).
- **Zone chains.** Pet Simulator 99 progresses through a linear sequence of themed zones bought with Coins, Emeralds or Void Bars, and you "smash zone breakables to unlock the next gate" [S] ([bloxodes PS99 areas](https://bloxodes.com/wiki/pet-simulator-99/areas); [shapes.inc PS99 zones](https://shapes.inc/fandom/ps99/areas-and-zones)).
- **Per-player gate implementation (DevForum patterns).**
  - A bought or earned gate is "permanently gone for that player": set Transparency 1 or CanCollide false *locally* when their data says unlocked ([2944641](https://devforum.roblox.com/t/how-would-i-go-about-making-an-area-gate-like-in-simulators/2944641), [3093542](https://devforum.roblox.com/t/1-player-simulator-gate-help/3093542)).
  - The server sends the client how many barriers are unlocked on load ([266358](https://devforum.roblox.com/t/barrier-system-for-a-simulator/266358)).
  - A LocalScript makes a barrier non-collide when a level is reached ([2229645](https://devforum.roblox.com/t/how-can-i-make-it-so-that-a-barrier-blocking-a-level-will-unlock-when-that-level-is-reached/2229645)). [S]
- **ForceField material** (DevForum announcement [297785](https://devforum.roblox.com/t/new-material-forcefield-v20/297785) [S]):
  - Fresnel-driven transparency, so it's visible near the edges.
  - Vertex-alpha outlines give a border even on flat faces.
  - Animation exists "for mesh-based (for now) parts with custom textures", using the texture's red channel. **Plain Parts don't animate.**
  - A guide says Transparency 0 looks "super opaque and thick", and 0.5–0.8 lets the inner glow stand out [S] ([roblox-force-field-visual-effect](https://roblox-force-field-visual-effect.pages.dev/)).
- **Highlight outlines.**
  - The docs say at most 255 simultaneous Highlights render on a client, extras are ignored, and the first Highlight on screen costs the most (up to about 1 ms GPU on mobile) [S] ([Highlighting](https://create.roblox.com/docs/effects/highlighting)).
  - Older threads mention a lower cap of about 31 ([DevForum 2628557](https://devforum.roblox.com/t/increase-highlight-limit/2628557?page=3) [S]).
  - Either way, **use one Highlight on "your next gate"**.
- **Readable world text.**
  - Lowering `SurfaceGui.PixelsPerStud` makes fixed-size text bigger; that was the fix in "Large SurfaceGui text for simulator display".
  - Low PPS (about 50) is blurry but legible far away; high PPS (about 150) is crisp up close.
  - `MaxDistance` hides a gui beyond N studs.
  - [S] ([3083555](https://devforum.roblox.com/t/large-surfacegui-text-for-simulator-display/3083555); [1899400](https://devforum.roblox.com/t/text-scale-on-surface-gui-being-unreadable-or-blurry/1899400))
  - A lock-icon overlay is the standard "not yet earned" convention [S] ([Implement designs in Studio](https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/implement-designs-in-studio)).
- **Camera juice.** EZ Camera Shake ([98482](https://devforum.roblox.com/t/ez-camera-shake-ported-to-roblox/98482)) and CameraShakeUpdated ([3621709](https://devforum.roblox.com/t/camerashakeupdated-simple-camerascreen-shaking-module/3621709)) are the go-to modules. DevForum posts warn that raw `Camera` offsets "look harsh" and that big `CFrame.Angles` shakes are "too disruptive" [S] ([782324](https://devforum.roblox.com/t/help-with-screen-shake/782324)).
- **Obby checkpoints.**
  - Name checkpoint parts 1, 2, 3…; on touch, update the stage and spawn only if the number is higher.
  - Show the "Stage" in leaderstats.
  - Give "visual feedback like a sound effect or particle effect".
  - "One checkpoint every 3 to 5 obstacles. A death should cost seconds, not minutes."
  - [S] ([DevForum obby tutorial 874825](https://devforum.roblox.com/t/how-to-create-an-obby-part-1-checkpoints-system-and-lava-bricks/874825); [creation.dev obby guide](https://www.creation.dev/blog/roblox-obby-design-guide); [Skyrunner checkpoint tutorial](https://skyrunnergames.com/tutorials/obby-checkpoint-system))
- **Breakable-wall feedback recipe** (earlier `animation_and_vfx.md`): anticipation shake 0.15–0.3 s, then swap to 4–8 pre-cut chunks with outward velocity 20–40 and up 10–25, a dust `Emit(30)`, a camera shake, and a 2–4 s fade cleanup. Done client-side for per-player progress [I, earlier note].

### What Hood's gate does today [R `TheBlockV2.lua:1290–1331`]
- White studded posts (1.6 × 12) and a beam (12–13.6), 17 Neon marquee bulbs, and stage-hued bunting.
- A **white wall at Transparency 0.65, CanCollide false**, with SurfaceGui lines:
  - "STAGE i" (band ≈ 3.6 studs)
  - the name (≈ 1.7 studs)
  - "RECOMMENDED POWER: X" (≈ 1.9 studs, magenta)
- `MaxDistance = 32`.
- Requirements come from `Balance.WallBase 50 × WallGrowth 2.1^(i−1)`: 50, 105, 221, 463, 972, 2.0K, 4.3K, 9.0K, 18.9K, 39.7K [R `Balance.lua:5,18`].

**Gap vs. genre [I]:**
- The key number is the smallest text and buried in a sentence.
- The gate is the palest object on screen.
- Its color isn't the stage's color.
- You can't read the next goal from more than one gate away.
- It doesn't block.
- There's no locked / ready / cleared state and no pass payoff.

---

## 4. Onboarding: straight into gameplay, and server size

### Cited findings
- **Roblox FTUE guidance.**
  - "Use a brief tutorial… get to the fun as quickly as possible."
  - "Deliver a joyful moment after users complete your core loop for the first time."
  - "Preview the progress that users can make."
  - [D] ([Retention](https://create.roblox.com/docs/production/analytics/retention))
  - Onboarding "visual elements": "a bouncing arrow pointing at a button", "particle effects over an item of interest", "a glowing trail in the world that directs players to a destination", "an in-world sign displaying a game's core loop". Plus contextual tutorials and timed hints (A/B-test the hint delay, for example 5 s vs 10 s) [D/S] ([Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques); [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)).
  - Measure each step with funnel events [D] ([Improving onboarding through funnel events](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458) [S]).
- **Timing rules of thumb** (third-party guides):
  - "Immediate action within 10 seconds, first reward within 60 seconds, clear objective at all times, no walls of text or forced tutorials."
  - In a simulator, players "should be clicking, collecting, and seeing numbers go up before the first minute ends".
  - [S] ([bloxg retention guide](https://bloxg.com/guides/roblox-player-retention); [rolearn first-week retention](https://rolearn.dev/guidance/first-week-retention-optimization/))
  - Roblox's discovery penalizes bounces under 60 s and from 61–180 s (earlier `success_factors.md` §2).
- **Objective arrows.** The community resource "ArrowBeams" ([DevForum 3045079](https://devforum.roblox.com/t/arrowbeams-simple-solution-to-creating-objective-arrows/3045079) [S]) is a Beam-based objective arrow, the same pattern as the docs' "glowing trail".
- **Server sizes.**
  - The max is 200, and social slots can be at most 20% of the server ([Experience Join Improvements](https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621) [S]).
  - Hits run small:
    - **Grow a Garden** has 6 plots per server but was capped at **5 players** (some sources say 4) [S] ([fandom discussion](https://growagarden.fandom.com/f/p/4400000000000064812); [allthings.how](https://allthings.how/grow-a-garden-player-count-server-limit-and-record-highs/)).
    - **Steal a Brainrot** has **8 players** per public server [S] ([Game Rant](https://gamerant.com/steal-a-brainrot-private-server-links-roblox/)).
    - **Muscle Legends** has **20** [S] ([fandom VIP servers](https://muscle-legends.fandom.com/wiki/VIP_servers)).
  - DevForum advice: about **8–20** for obby or race-style games. A server with fewer than about 40 players "feels empty" only on *large* maps. Set social slots to "Roblox Optimized" or about 15–20% [S] ([Optimal player count per server?](https://devforum.roblox.com/t/optimal-player-count-per-server/910475); [How many people should fit in a server?](https://devforum.roblox.com/t/how-many-people-should-o-fit-in-a-server/775457)).

### Inferences for Hood [I]
- **Spawn.** The lobby already spawns players "on the medallion, facing the gate" [R `SimulatorLobby.lua:944`]. Keep the first training bag **8–12 studs ahead and in frame**, so the first action needs no turning.
- **Power from second 1.**
  - Show a floating "+1 💪" over the head every tick for the first 30 s.
  - Run a pulsing Beam trail from the player to the first bag.
  - When Power ≥ the Stage 1 requirement, retarget the trail to Gate 1 and flip that gate to its **READY** state (see the spec).
- **First joyful moment in ≤ 40 s.** Stage 1 needs 50 Power, which is 50 s at +1/s [R]. Either lower Stage 1 to **25**, or make the first bag ×2, so the first gate bursts open at about 25–40 s.
  - Stage 2 (105) then gives a second goal about 1 minute later.
  - Show the *next two* gate numbers from the spawn plaza (see MaxDistance in the spec) to "preview progress".
- **Core-loop sign.** Put one in-world sign in the spawn sight line: **TRAIN → POWER → BREAK GATES → REBIRTH**, with icons and no paragraphs.
- **Server size.**
  - **MaxPlayers 12** (acceptable range 10–16), social slots on Roblox Optimized.
  - The stage corridor is one 40-stud street with gates every 28 studs, so 20+ players crowd the first gates.
  - 12 still keeps the courtyard lobby and leaderboard lively.
  - A/B-test 12 vs 16 with Experiments once traffic allows.

---

## Lighting preset to use

Both presets are syntheses of the evidence above [I]. Values are exact; tune by eye ±10%. Apply them with the existing `ServerStorage.HoodLighting` pattern and add the four rows it doesn't handle yet: **LightingStyle, PrioritizeLightingQuality, Clouds, and the ColorGrading tonemapper**.

Rule kept in both: every **Ambient channel ≤ OutdoorAmbient** (the engine clamps otherwise [D]).

### A. "Front-page Day" (default for every map)

Changes from the proposed Day preset are **bold**.

| Object | Property | Value | Why |
|---|---|---|---|
| Lighting | LightingStyle | **Soft** | Lower lit/shadow contrast; the stylized style [D] |
| | PrioritizeLightingQuality | **true** | Keeps the shadow-mapped sun on more devices [D] |
| | ClockTime | **13.0** (allowed 12.5–14) | Sun at about 50–75°. Mirror to 11.0 if the sun ends up in front of the stage view (check with the snippet) |
| | GeographicLatitude | **30** | Gives a high noon sun |
| | Brightness | 3 | |
| | ExposureCompensation | **0.2** | Lifts highlights without murky shadows [D] |
| | Ambient | **(128, 130, 158)** | Occluded fill: cool, never grey-black |
| | OutdoorAmbient | **(162, 168, 200)** | Bright cool shadow fill; the main anti-dark lever |
| | ColorShift_Top | (255, 238, 210) | Warm sunlit faces |
| | ColorShift_Bottom | **(130, 160, 225)** | Cool undersides |
| | EnvironmentDiffuseScale | **0.5** | Sky fill, now that the sky is blue |
| | EnvironmentSpecularScale | **0.15** | Stops sky sheen on SmoothPlastic and Metal |
| | GlobalShadows | true | Plus **CastShadow = false on corridor terraces and rowhouses** |
| | ShadowSoftness | 0.2 | Realistic only; harmless under Soft |
| Atmosphere | Density / Offset | **0.22 / 0.6** | Silhouettes stay crisp |
| | Haze / Glare | **0.2 / 0** | No veil |
| | Color / Decay | (196, 228, 255) / **(140, 180, 255)** | Pale sky blue |
| Sky | SunAngularSize / MoonAngularSize | **16 / 11** | Slightly cartoon sun |
| | StarCount / CelestialBodiesShown | 0 / true | |
| | Skybox | A saturated cartoon sky (e.g. Creator Store anime sky), or the default sky | Keep Haze low so its colors show |
| | SkyboxOrientation | Client spins Y at **0.5°/s** | "Active" sky at almost no cost [D] |
| Clouds (under Terrain) | Cover / Density / Color | **0.55 / 0.25 / (255, 255, 255)** | Only render under Terrain [D] |
| Workspace | GlobalWind | **(8, 0, 4)** | Clouds drift; grass and particles sway |
| ColorCorrectionEffect | Brightness / Contrast / Saturation | **0.04 / 0.12 / 0.25** | Community cartoony range [S] |
| | TintColor | **(255, 255, 255)** | No multiplicative dimming |
| BloomEffect | Intensity / Size / Threshold | **0.65** / 28 / 1.1 | Neon, gates and sun bloom; white sidewalks don't |
| SunRaysEffect | Intensity / Spread | **0.015 / 0.25** | Subtle, because the sun is behind the camera |
| ColorGradingEffect | TonemapperPreset | **Default** (never Retro) | "Vivid colors and high contrasts" [D] |
| DepthOfFieldEffect | — | none | Costs every frame |
| Map palette (not Lighting) | Corridor road | **(104, 112, 134)**, up from (75, 82, 99) | Removes the dark bottom third of the frame |

### B. "Golden Block" (hood evening that stays bright: events, Uptown or Hills, or a rotating time of day)

| Object | Property | Value | Why |
|---|---|---|---|
| Lighting | LightingStyle / PrioritizeLightingQuality | Soft / true | |
| | ClockTime | **16.3** | About 22–35° sun, golden but not grazing. The gold comes from the colors below. Mirror to about 7.7 if the sun lands in front of the stage view. |
| | GeographicLatitude | 30 | |
| | Brightness | 2.8 | |
| | ExposureCompensation | 0.3 | |
| | Ambient | (130, 112, 160) | |
| | OutdoorAmbient | (176, 150, 196) | Brighter version of the docs' evening lavender (156,136,176) [D] |
| | ColorShift_Top / Bottom | (255, 200, 150) / (140, 130, 220) | Warm key, purple shade |
| | EnvironmentDiffuseScale / SpecularScale | 0.5 / 0.2 | |
| | GlobalShadows | true (terrace CastShadow off, as in Day) | |
| Atmosphere | Density / Offset | 0.26 / 0.45 | |
| | Haze / Glare | 0.9 / 0.35 | Glare needs Haze > 0 [D] |
| | Color / Decay | (255, 196, 170) peach / (150, 120, 220) violet | Peach, not beige |
| Clouds | Cover / Density / Color | 0.5 / 0.3 / (255, 214, 200) | |
| ColorCorrectionEffect | Brightness / Contrast / Saturation / Tint | 0.05 / 0.12 / **0.3** / (255, 250, 245) | |
| BloomEffect | Intensity / Size / Threshold | 0.9 / 32 / 1.0 | String lights and neon signs glow |
| SunRaysEffect | Intensity / Spread | 0.04 / 0.35 | |
| ColorGradingEffect | TonemapperPreset | Default | |
| World lights | Neon signs, string lights, window SurfaceLights (Brightness 1–2, Range 12–16, Shadows false) | On | This is where the "hood at dusk" vibe lives |

**Acceptance test [I].**
- Take the same three camera shots in Studio at max quality: spawn → Gate 1, mid-corridor, and the Gate 10 approach.
- Repeat them on a phone.
- Pass criteria:
  - the road and the gate faces show their lit side
  - no large area reads near-black
  - only Neon blooms
- Check that LightingStyle survives into a live server.

---

## Stage gate spec

A build spec for the 40-stud stage street (walkable x −20..20, terraces start at |x| = 20; gates every 28 studs at `stageZ(i) = −14 − 28(i−1)` [R]). It's my synthesis of the genre conventions above [I].

**Gate-local frame:**
- origin: street center, floor top (y = 0)
- +X: across the street
- +Y: up
- +Z: toward the approaching player (lobby side)

### Per-stage color ladder (gate i matches the corridor segment *behind* it)

| Stage | Name (config) | Base | Dark (header, stroke) | Light (Neon, barrier) |
|---|---|---|---|---|
| 1 | Moving Boxes | (120, 214, 72) lime | (58, 140, 40) | (190, 255, 140) |
| 2 | Chain Link Fence | (38, 200, 180) teal | (14, 120, 112) | (140, 255, 235) |
| 3 | Delivery Truck | (64, 170, 255) sky | (26, 96, 190) | (160, 220, 255) |
| 4 | Hydrant Spray | (72, 104, 255) blue | (36, 52, 170) | (150, 170, 255) |
| 5 | Construction Barrier | (150, 84, 240) purple | (88, 40, 160) | (210, 170, 255) |
| 6 | Scaffolding | (255, 90, 190) pink | (170, 40, 120) | (255, 170, 225) |
| 7 | Food Cart Line | (240, 60, 64) red | (150, 24, 34) | (255, 150, 150) |
| 8 | Block Party | (255, 140, 40) orange | (170, 80, 16) | (255, 200, 130) |
| 9 | Pigeon Flock | (255, 200, 40) gold | (176, 120, 10) | (255, 236, 150) |
| 10 | Station Turnstile (final) | white + **rainbow** | (40, 40, 60) | Neon hue-cycles over 3 s; UIGradient rainbow on text |

This is a rarity-style ladder (cool to hot, then gold, then rainbow), the convention players already read as "harder and better" (Legends of Speed hoop colors, Wall Punch Simulator's Rainbow Stages [S]). Recolor the corridor segment's facades to the same hue so each stage is a color zone.

### Parts (about 30 per gate, 10 gates ≈ 300 parts)

| Part | Size (studs) | Position (center) | Material | Color | Notes |
|---|---|---|---|---|---|
| PillarL / PillarR | 4 × 16 × 4 | (±18, 8, 0) | Plastic, studs on all faces | Base | Opening is 32 wide × 16 tall |
| PillarBaseBand ×2 | 4.4 × 1.2 × 4.4 | (±18, 0.6, 0) | SmoothPlastic | (250, 250, 252) | |
| PillarNeonStrip ×2 | 0.3 × 12 × 1.2 | (±15.85, 8, 0) | Neon | Light | On the inner faces, framing the opening |
| Header | 40 × 6 × 3 | (0, 19, 0) | Plastic, studs | Dark | Carries the number SurfaceGuis |
| HeaderCap | 41 × 0.8 × 3.8 | (0, 22.4, 0) | SmoothPlastic | (250, 250, 252) | |
| MarqueeBulbs ×16 | Ball 0.5 | x −15…15 every 2 studs, y 15.75, z +1.6 | Neon | Alternate (255, 236, 160) / Light | Keep the existing idea; client chase-animates at 8 Hz on the *next* gate only |
| BadgeRim | Cylinder Ø9 × 1.0 deep (Size (1, 9, 9), rotated `CFrame.Angles(0, math.pi/2, 0)` so the axis runs along Z) | (0, 27.3, 0) | SmoothPlastic | Dark | Crown above the header; pokes above the 20-stud terraces as a landmark |
| BadgeFace | Cylinder Ø7.6 × 1.4 deep (Size (1.4, 7.6, 7.6), same rotation) | (0, 27.3, 0) | SmoothPlastic | (255, 255, 255) | |
| BadgeLabel | 7 × 7 × 0.1 | (0, 27.3, +0.75) | Transparency 1, CanCollide/CastShadow false | — | Carries the stage-number SurfaceGui (cylinder faces aren't SurfaceGui-friendly) |
| Barrier | 32 × 16 × 0.4 | (0, 8, 0) | **ForceField** | Light | Transparency 0.45, CastShadow false, CanCollide true on the server; the client turns it off for players who qualify |
| LaserBeams ×4 | Beam between pillar-face attachments at y 3, 6.5, 10, 13.5 | x ±16, z +0.6 (just in front of the sheet) | — | ColorSequence Light → white → Light | Width0/1 0.35, LightEmission 1, LightInfluence 0, TextureMode Wrap, TextureLength 4, TextureSpeed 1.5, FaceCamera true. Gives motion that plain ForceField parts lack [S] |
| LaserNubs ×8 | Ball 0.8 | Beam ends (x ±15.6, z +0.6) | Neon | Light | |
| ThresholdLine | 32 × 0.12 × 1.2 | (0, 0.06, 0) | Neon | Light | CanCollide/CastShadow false |
| StartLine | 32 × 0.1 × 4 | (0, 0.05, −2.6) | SmoothPlastic + Texture checker (2-stud squares; StudsPerTileU/V 4) | (250, 250, 252) / (30, 30, 36) | Race "you crossed it" cue. Fallback: 2 rows × 16 tiles of 2 × 2 |
| ApproachChevrons ×3 | 6 × 0.1 × 2 (or wedge-pair chevrons) | (0, 0.05, +6 / +10 / +14) | Neon, Transparency 0.25 | Light | Pulse in sequence (0.15 s offset) on the next gate only |
| CheckpointPad | Cylinder Ø10 × 0.4 + rim Ø10.8 Neon | (0, 0.2, −10) | SmoothPlastic / Neon rim | Base / Light | Touch sets checkpoint (see feedback) |
| PillarSurfaceLights ×2 | SurfaceLight on the inner pillar faces | — | — | Light | Brightness 2, Range 14, Angle 90, Shadows false. Colors the road at the gate |
| PillarSparkles ×2 | Attachment at (±18, 22.8, 0) | — | ParticleEmitter | Light | Rate 3, Lifetime 1.2–1.8, Speed 1–2, Size 0.5 → 0, LightEmission 1, LightInfluence 0. Enabled on the next gate only |

### Text (SurfaceGui: SizingMode PixelsPerStud, PixelsPerStud 25, LightInfluence 0, AlwaysOnTop false)

Face naming: the approach side (+Z) is `Enum.NormalId.Back`, because a part's Front face is −Z in Roblox [M].

| Surface | Content | Size | Style |
|---|---|---|---|
| Header front (+Z), MaxDistance **150** | 💪 icon + **requirement number** (`compact`: "1.2K") + "POWER" | Icon 4.5 × 4.5 studs. Number band 5 studs tall (cap ≈ 4.2) × 16 wide. "POWER" 2 studs tall | Number: LuckiestGuy, white, UIStroke Dark at 6 px (≈ 0.24 stud), plus a black copy offset 0.15 stud down at 0.5 transparency as a cartoon drop shadow. "POWER": FredokaOne, Light |
| Header back (−Z), MaxDistance 60 | Stage name ("CHAIN LINK FENCE") | 2.5 studs | FredokaOne, white, Dark stroke |
| BadgeLabel, MaxDistance **150** | "STAGE" + numeral | "STAGE" 1.1 studs; numeral 4.5 studs | LuckiestGuy, Dark fill, white stroke |
| Barrier front, MaxDistance 70 | Lock icon / state text / progress bar / "850 / 1.2K" | Lock 5 × 5 at y 7–12; state text 1.8 studs at y 5–6.8; bar 20 × 1.4 at y 2.6–4 (UICorner, UIGradient Base → Light fill); counter 1.1 studs inside the bar | Updated per player on the client |

**Readability [I].** The 4.2-stud numerals subtend about 2.9° at 84 studs (three gates ahead). That's roughly 40+ px tall on a 1080p phone at the default FOV, so the next 2–3 goals read from the spawn plaza and corridor. Raising MaxDistance from today's 32 is safe once the numbers sit on opaque headers instead of see-through walls.

### States (client-side per player; the server owns the truth)

| State | When | Look |
|---|---|---|
| **Locked** | Power < requirement | Barrier Light at Transparency 0.45. Lock icon closed. State text "NEED 1.2K 💪". Bar shows progress |
| **Ready** | Power ≥ requirement and gate not cleared | Barrier pulses Transparency 0.45 ↔ 0.2 (0.6 s sine). Lock pops open (scale 1 → 1.3 → 1, Back easing). Text "GO! →" in (120, 255, 120). Lasers turn white-green. The **single Highlight** (OutlineColor white, OutlineTransparency 0.2, FillTransparency 1, DepthMode Occluded) sits on this gate. Onboarding Beam retargets here |
| **Cleared** | Passed once | Barrier and lasers hidden, CanCollide off. Badge numeral gets a green ✓. Sparkles, SurfaceLights and bulb chase off, so attention moves to the next gate |

### Pass feedback (client, about 1.2 s total; server validates and records)
1. **Cross the ThresholdLine.** The client asks the server; the server checks Power ≥ requirement and records the stage.
2. **Shatter (0–0.4 s).**
   - Hide the Barrier.
   - Spawn 12–16 shards: ForceField or Neon, 2 × 2 × 0.3, color Light.
   - Shard velocity: forward (−Z) 20–40 plus up 10–25, random spin.
   - Fade the shards from 0.8 s and Debris them at 2 s.
3. **Burst.**
   - Sparkle `Emit(40)`: Light + white, Size 0.6 → 0, Lifetime 0.6–1.0, Speed 25–40, SpreadAngle 180.
   - Confetti `Emit(60)`: Rotation, Squash.
   - Shockwave ring: a flat Neon cylinder scaling Ø1 → Ø40 in 0.35 s while Transparency goes 0 → 1.
4. **Camera.** FOV kick 70 → 78 → 70 over 0.35 s, plus a light shake (≈ 0.25-stud amplitude, 0.25 s). Use a shake module, not raw offsets [S].
5. **Sound.** A glass/whoosh shatter plus a short level-up jingle, Volume 0.6, PlaybackSpeed 1 + 0.03·i so later stages sound "higher".
6. **UI.**
   - Center banner "STAGE i CLEARED!": LuckiestGuy, 80–96 px, stage Base color with a white UIStroke.
   - Banner animation: pop 0 → 1.15 → 1 (Back), 1.2 s hold, then slide up.
   - "+N Wins" (or cash) floater.
   - leaderstats `Stage` +1.
   - If it's the player's best stage, a server-wide feed line.
7. **Checkpoint.** Touching the CheckpointPad sets the respawn and the "teleport to best stage" target. The pad flashes white for 0.15 s and a "CHECKPOINT ✓" toast shows.

**Not enough Power (bump).**
- The Barrier flashes (255, 70, 70) for 0.2 s.
- Push the character back: AssemblyLinearVelocity +Z 40, up 15.
- A floater shows "NEED 350 MORE 💪".
- Play a short "denied" buzz.
- The genre convention is that the barrier tells you exactly how far off you are.

### Final gate (Stage 10)
- Header text "WIN! 🏆" with a rotating rainbow UIGradient (Rotation +90°/s). Pillars and Neon cycle hue over 3 s.
- Beyond the gate, at z −10, a **trophy on a pedestal**:
  - pedestal: Cylinder Ø8 × 3, Plastic studs, gold (255, 200, 40), Neon rim
  - cup: Ball Ø4 SmoothPlastic gold, plus 2 cylinder handles and a 2 × 1 × 2 base
  - client-side spin at 30°/s, with sparkles
- Touching it plays the big version of the pass feedback (confetti 150, longer banner, "REBIRTH / NEXT MAP" prompt). This echoes Punch Wall's trophy after the last wall [S].

### Fit with today's corridor [R/I]
- `stageProps` places props at z + 7 on the approach side of each gate. Most props sit at the sides (|x| 13–19), but **stage 10's turnstiles are on the centerline** at x −6, 0, 6, so move them aside or skip the chevrons there.
- Beyond gate 10 the floor runs about 34 more studs (floor ends at z −300; gate 10 is at −266). Put the trophy at local z −20 and leave out that gate's CheckpointPad.

### Performance notes [I]
- Only the player's **next** gate runs particles, lights, bulb chase, chevrons and the Highlight. Every other gate is static parts plus SurfaceGuis.
- Use one client loop at about 4 Hz to pick the next gate (the earlier note's "gate emitters by distance" pattern).
- That leaves 2 SurfaceLights and 1 Highlight active.
- Total is about 30 parts per gate.
