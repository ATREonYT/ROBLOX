---
tags: [roblox, video-notes, cartoony-building-lighting]
source: https://www.youtube.com/watch?v=0_lkryX-CgM
creator: "DatBoiEle"
video_id: "0_lkryX-CgM"
---
# How to Make Stylized Trees & Assets NEWEST METHOD ULTIMATE Tutorial {Roblox Studio}

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Stylized, flat-looking anime-style trees from leaf-card planes in Blender (custom normals from a sphere), imported to Studio with a SurfaceAppearance, PixelFix to remove black leaf outlines, then the key trick: PointLights colored like the leaf (and a blue one underneath) to tint leaf shadows. Also a method for stylized rocks and other assets via base texture plus texture painting.

## Tools and setup
- Blender; Photopea (free browser photo editor; transcript says "Photoia"); Clip Studio Paint (any painter works); PixelFix (small downloadable tool that fixes transparent-edge outlines, forum post linked in description); FX plugin (Studio plugin for editing lights, link in description); Roblox Studio; Toolbox (white decal for roughness map, trunk model).

## Step-by-step
1. [00:00] In Blender add a plane, rotate it upright. In Photopea make a new 900x900 canvas, draw scattered leaves (ovals; could be maple, cherry blossom) on transparent background.
2. [01:00] Make leaves white: select leaf layer, Ctrl+U (hue/saturation), lightness all the way up. Export as PNG.
3. [01:00] Blender: UV Editing, Open the texture. On the plane's material: New, Base Color yellow dot, Image Texture, pick leaf PNG. Set viewport shading to Texture.
4. [01:00] Back in Layout, duplicate/spam and rotate the plane randomly to form a roundish bush; check from every angle so it has bumps on all sides.
5. [02:01] Fix shading: add UV Sphere, put it in the bush. On the bush plane add Data Transfer modifier, object = sphere, enable Face Corner Data, Custom Normals. Enable Auto Smooth (Object Data green triangle, Normals) when prompted.
6. [03:01] Edit mode, turn on Face Orientation overlay. Make the outer side all blue: hover over red part, press L to select, Alt+N, Flip. Turn overlay off. Object mode; keep sphere in middle (changes shadows), then delete it. Bush is now light on top, dark underneath.
7. [03:01] Export FBX. In Studio: Import 3D.
8. [04:01] The import looks wrong: copy texture ID from the plane's properties, add a SurfaceAppearance child under the plane, paste into ColorMap, set AlphaMode to Transparency (captioned "overlay").
9. [04:01] Enable DoubleSided on the plane (leaves invisible from behind otherwise).
10. [04:01] Remove black outlines: drag the leaf texture onto PixelFix app, wait until "press any key to exit", then re-upload the fixed image (if no re-upload option, save the game via Game Settings first, then use Add Image). Use PixelFix on any transparent-background texture.
11. [06:02] Optional fluffier leaves: in Photopea, Filter, Blur, Gaussian blur on the leaf layer; redo PixelFix and re-upload each time. Middle blur chosen; max blur looked like a cloud.
12. [06:02] Color: change the SurfaceAppearance Color for a green.
13. [07:02] Remove shine for flat drawn look: Toolbox, Decals, search "white", copy asset ID of a white decal, paste into RoughnessMap.
14. [07:02] Add a trunk (from Toolbox here; or model in Blender). Check the tree from all angles.
15. [08:03] Lighting: Lighting properties. Ambient = dark blue; OutdoorAmbient = blue; ColorShift_Top = yellowish (sunny). Lower EnvironmentDiffuseScale and EnvironmentSpecularScale to show more shadow. Then reduce ColorShift_Top intensity, raise ExposureCompensation a bit.
16. [09:03] Add ColorCorrection under Lighting: tweaked values around 0.05 each; lowered contrast, lowered brightness (since exposure was raised), raised saturation (anime style). Bloom optional.
17. [09:03] The secret: put an invisible part at the top of the foliage with a PointLight (use FX plugin or Explorer). Set light color to the leaf color; adjust Range and Brightness until it looks right. It mainly recolors leaf shadows.
18. [10:03] Add a second PointLight under the foliage in blue, with lower brightness and range, so it tints shadows in the leaves but does not light the ground.
19. [11:03] Reuse: to swap leaf style without Blender, select all the SurfaceAppearances (click top, shift-click bottom) and paste a new ColorMap texture ID.
20. [12:03] Stylized rocks: cube; shape with edge Ctrl+B bevel and face extrude (S/E). Alternate method below.
21. [13:04] Auto-rock method: cube, Subdivision modifier (viewport 4), Displace modifier with new texture of type Voronoi ("voyoid"), size about 1. Apply both. Add Decimate, lower ratio until shape holds with fewer verts, apply.
22. [14:05] Edit mode, vertex select: select the center vertices of each face (C circle select), M, At Center, to flatten faces. Object mode: right-click, Shade Smooth, enable Auto Smooth.
23. [15:06] Base texture: paint a bluish-gray rock color with random splotches of similar colors in Clip Studio Paint (or anything). UV Editing, open it, assign via Image Texture on the material, view as Texture.
24. [16:06] Edit mode, A then U, Smart UV Project. Texture Paint mode: turn off specular in shading, use Flat. Enable Cavity to see edges.
25. [17:06] Paint lighter base color onto some edges (white edges sell sharp rock), grass color on top. Always Image, Save (Blender does not autosave textures).
26. [18:06] Export FBX; keep the FBX and texture in the same folder, then Import 3D in Studio imports them together.
27. [18:06] Wood fence example: model, grab base texture from Google, apply, texture paint, 3 plank variants, build in Studio.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Leaf canvas | 900x900 | Photopea |
| Leaf color | white, lightness max | tint via SurfaceAppearance Color |
| Data Transfer | Face Corner Data, Custom Normals, Auto Smooth on | sphere gives round shading |
| SurfaceAppearance AlphaMode | Transparency | on leaf plane |
| DoubleSided | on | leaf plane |
| RoughnessMap | white decal asset ID | removes shine |
| Ambient / OutdoorAmbient | dark blue / blue | daylight |
| ColorShift_Top | yellowish, then lowered | sunny |
| EnvironmentDiffuseScale, EnvironmentSpecularScale | lowered (no number) | more shadow |
| ExposureCompensation | raised slightly | |
| ColorCorrection | ~0.05 per value, contrast down, brightness down, saturation up | exact numbers not stated |
| Canopy PointLight | leaf color; Range and Brightness by eye | invisible part on top |
| Under PointLight | blue, low brightness and range | tints shadows, not ground |
| Rock Subdivision viewport | 4 | |
| Voronoi size | about 1 | Displace |
| Gaussian blur | middle amount | max = cloud look |

## Prompts and skills used
- None (no AI). Links named: Photopea, PixelFix, FX plugin (descriptions links, not in transcript).

## Gotchas and fixes
- Black outlines around leaf alpha edges: run PixelFix on the texture and re-upload (needed after every texture change).
- Leaves invisible from behind: DoubleSided on.
- Shiny leaves: white RoughnessMap.
- Cannot re-upload: save game via Game Settings, then Add Image appears.
- Light parts affect nearby builds: reduce range.
- Blender does not autosave painted textures.
- Keep FBX and texture in same folder to import together.

## Use it in our games
- Leaf-card trees are very cheap for simulator maps; swapping the SurfaceAppearance ColorMap ID gives new biome trees without Blender (inferred).
- The colored PointLight inside canopy plus blue under-light is a cheap way to get pretty cartoony foliage; keep range small for performance (inferred).
- Use the ColorShift_Top yellow + dark blue ambient + lowered environment scales recipe as a daytime cartoony lighting preset.
- Base-texture then hand-paint-edges workflow works for stylized rocks/props in steal-style bases (inferred).
