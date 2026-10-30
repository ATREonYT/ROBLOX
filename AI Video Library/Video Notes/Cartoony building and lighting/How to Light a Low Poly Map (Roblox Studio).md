---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=kJ4Kel0j04g
creator: "barjNET"
video_id: "kJ4Kel0j04g"
---
# How to Light a Low Poly Map (Roblox Studio)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Delete the default lighting, add a good low-poly skybox, ColorCorrection and Atmosphere, then tune ambient colors for your theme. Key trick: turn Lighting Brightness down to about 1 and push ColorCorrection Brightness up, so shadows are soft, then compensate with saturation and contrast.

## Tools and setup
- Roblox Studio Lighting, Sky, ColorCorrectionEffect, Atmosphere.
- Free low-poly skybox from the creator's Discord (resources channel); origin unknown.
- Creator uses only skybox, ColorCorrection and Atmosphere for simple stylized scenes.

## Step-by-step
1. [00:00] Delete all default Roblox lighting objects.
2. [01:01] Add a high-quality, simple, low-poly skybox that fits the colorful style.
3. [01:01] Add ColorCorrection and Atmosphere (delete Atmosphere temporarily while tuning the main settings).
4. [01:01] Ambient: undertone color for the whole world, indoors and outdoors. Changing it tints shadows; brighter changes the whole world. Common themes: blue, orange, or grayish white. He picks a warm orange for an earthy map.
5. [02:03] Leave ColorShift_Top and ColorShift_Bottom alone (he rarely touches them).
6. [03:05] EnvironmentDiffuseScale and SpecularScale: adjust at the end; he likes diffuse up and specular down (sometimes specular 0).
7. [03:05] OutdoorAmbient: earthy warm orange too (blue or white for other maps).
8. [03:05] ShadowSoftness: all the way up for soft edges on low poly.
9. [04:06] ClockTime: more overhead for a daytime scene. Exposure 0.1 for a sunny outdoor theme, else leave at 0.
10. [04:06] The trick: Lighting.Brightness down to around 1, then ColorCorrection.Brightness up a lot. This avoids harsh shadows but looks washed out.
11. [05:06] Compensate: ColorCorrection Saturation 0.9, Contrast 0.15 (vary per map).
12. [05:06] Re-add Atmosphere: reduce Density, set Offset 25. Ignore color/decay and haze; only Density and Offset matter.
13. [06:06] ColorCorrection TintColor: overlays the whole screen; slightly blue plus a little orange for undertones.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Lighting.Brightness | about 1 | "or something similar" |
| ColorCorrection.Brightness | turned up a lot | no number said |
| ColorCorrection.Saturation | 0.9 | |
| ColorCorrection.Contrast | 0.15 | map-dependent |
| Lighting.ExposureCompensation | 0.1 | sunny outdoor; else 0 |
| ShadowSoftness | max (all the way up) | |
| Atmosphere.Offset | 25 | |
| Atmosphere.Density | reduced | no number said |
| ClockTime | more overhead | no number said |
| Ambient / OutdoorAmbient | warm orange | no RGB said |

## Prompts and skills used
No AI prompts. Skybox free via the creator's Discord.

## Gotchas and fixes
- Default Roblox lighting is made for realistic scenes, not bright low-poly.
- Default Atmosphere is far too foggy; lower density, set offset.
- Washed-out look from high color-correction brightness is fixed with saturation and contrast.
- Settings will not match every map; tune by eye.

## Use it in our games
- Use the Lighting.Brightness ~1 plus ColorCorrection brightness-up trick for soft, bright simulator maps.
- Max ShadowSoftness suits blocky cartoony bases (inferred for our style).
- Pick one ambient hue per zone (orange for earthy, blue for ice) as a theme dial (inferred).
- Keep post effects to Sky, ColorCorrection, Atmosphere for performance on mobile (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[13 Cartoony & Low-Poly Building]] · [[04 Building, Maps & 3D Models]]
- Playbooks: [[Blueprint - Egg Run]] · [[16 Cartoony Kid-Appeal Checklist]]
- More in Cartoony building and lighting: [[How to Build PRO Roblox Maps!]] · [[How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}]] · [[How to Model a Low Poly Roblox Pet (Blender Tutorial)]] · [[How to make AMAZING Low Poly Roblox Models]] · [[How to make CARTOON LIGHTING in Roblox Studio]] · [[LOW-POLY TERRAIN TUTORIAL ROBLOX+BLENDER]] · [[Make Your Roblox Game Look 10x Better With Lighting]]
<!-- related:end -->
