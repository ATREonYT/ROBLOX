---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=YIyir52FiYo
creator: "Gamer M8"
video_id: "YIyir52FiYo"
---
# How to make CARTOON LIGHTING in Roblox Studio

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
A fast, copy-the-numbers recipe for a purple and yellow cartoony look: set Lighting properties, add ColorCorrection, and drop in a custom skybox. Whole thing takes about 3 minutes and every value is spoken aloud.

## Tools and setup
- Roblox Studio, Lighting service in the Explorer and Properties panel.
- ColorCorrectionEffect (added under Lighting with the plus button).
- Custom skybox from an "Iris" plugin (name from captions, unsure of spelling) with many skies; creator uses the "afternoon Sky one". Link is in the video description.
- No prices or versions mentioned.

## Step-by-step
1. [00:00] Select Lighting in the Explorer and open Properties.
2. [00:00] Set Ambient to a purple: 200, 160, 225.
3. [00:00] Keep Brightness at 2. Keep ColorShift_Bottom black.
4. [00:00] Set ColorShift_Top to a yellow: 215, 190, 135.
5. [00:00] Set EnvironmentDiffuseScale 0.3 (makes everything look brighter) and EnvironmentSpecularScale 0.25.
6. [00:00] Keep GlobalShadows on. Set OutdoorAmbient to a darker purple (125, 100, 150 as heard in captions).
7. [01:03] Keep ShadowSoftness at the default 0.2 (higher = blurrier shadows, lower = sharper shadows).
8. [01:03] Keep Technology as ShadowMap ("otherwise it'll change lighting").
9. [01:03] Scroll down: ClockTime 14, GeographicLatitude 40 (controls shadow and light direction), ExposureCompensation default 0.
10. [01:03] Set FogColor to a light purple: 200, 170, 250. Set FogEnd 2500 (bigger number = effectively no fog, smaller = fog closer).
11. [02:03] In Explorer click plus on Lighting, add ColorCorrection: Brightness 0.05, Contrast 0.1, Saturation 0.15.
12. [02:03] Add a custom skybox via the plugin (afternoon Sky one), apply it to Lighting.
13. [02:03] Tweak any value to taste.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Lighting.Ambient | 200, 160, 225 | purple |
| Lighting.Brightness | 2 | kept |
| ColorShift_Bottom | black | kept |
| ColorShift_Top | 215, 190, 135 | yellow |
| EnvironmentDiffuseScale | 0.3 | brighter look |
| EnvironmentSpecularScale | 0.25 | |
| GlobalShadows | on | |
| OutdoorAmbient | 125, 100, 150 | caption read "125 comma 100 100 comma 150", likely 125,100,150 |
| ShadowSoftness | 0.2 | default |
| Technology | ShadowMap | kept |
| ClockTime | 14 | |
| GeographicLatitude | 40 | shadow/light direction |
| ExposureCompensation | 0 | default |
| FogColor | 200, 170, 250 | purple |
| FogEnd | 2500 | |
| ColorCorrection Brightness | 0.05 | |
| ColorCorrection Contrast | 0.1 | |
| ColorCorrection Saturation | 0.15 | |

## Prompts and skills used
No AI prompts. Skybox plugin ("Iris" per captions) with "afternoon Sky one"; link in the description.

## Gotchas and fixes
- Fog: make FogEnd huge to effectively remove fog, smaller to bring it closer.
- Keep Technology on ShadowMap or the lighting changes.
- Creator says the values are personal taste; adjust freely.

## Use it in our games
- Use the purple Ambient plus yellow ColorShift_Top as a ready cartoony preset for a simulator lobby; swap hues per zone or biome (inferred).
- Raising EnvironmentDiffuseScale to 0.3 is a cheap way to brighten a map without washing out shadows.
- Light ColorCorrection (0.05 / 0.1 / 0.15) adds pop to a +1 style game without heavy post-processing (inferred).
- FogEnd 2500 hides far map edges in steal-style bases while keeping depth (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Light a Low Poly Map (Roblox Studio)]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to Model a Low Poly Roblox Pet (Blender Tutorial)]] · [[How to make AMAZING Low Poly Roblox Models]] · [[LOW-POLY TERRAIN TUTORIAL ROBLOX+BLENDER]] · [[Make Your Roblox Game Look 10x Better With Lighting]]
<!-- related:end -->
