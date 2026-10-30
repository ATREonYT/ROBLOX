---
tags: [roblox, video-notes, ui]
source: https://www.youtube.com/watch?v=z16zs2v-FNI
creator: "Kek"
video_id: "z16zs2v-FNI"
---
# The Greatest Cartoony UI Tutorial on Roblox (w/ Figma)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Full real-time Figma walkthrough (recorded by UI Genesis staff member "Hamorei", as heard) of a cartoony pet-inventory UI. The recipe: gradient fill + darker duplicate offset down for fake 3D + flattened duplicate with a 3px outside black stroke + white outer stroke + drop shadow + masked soft-light highlights and halftone textures.

## Tools and setup
- Figma (frame tool shortcut F; text tool T; the video also says "D" once, likely a slip).
- Frame preset: Presentation, 1920x1080.
- Font: Fredoka One (heard as "Fidoka / Foca one").
- UI Resources website (heard as "eye resources") for halftone textures and icons (downloaded or copy-pasted).
- The finished UI is sold for $5 on Kek's Gumroad; UI Genesis Discord server mentioned.

## Step-by-step
1. [00:00] Make a frame: press F, choose Presentation > 1920x1080. Change the frame fill from white to a darker solid color.
2. [01:00] Base background: shape tool, drag a rectangle, center it using the alignment buttons (horizontal center + vertical center). Fill near-white.
3. [02:02] Corner radius 10. Add a stroke (blue-ish), weight about 5.
4. [03:03] Figma can't do double strokes, so Ctrl+D duplicate the layer. Name top "base frame", bottom "white outline". On the white outline: stroke position Inside > Outside, color white.
5. [04:04] On base frame: stroke settings (icon next to weight) > style Dashed; adjust blue to a lighter shade.
6. [05:04] Select both layers (Shift-click), Ctrl+G to group, double-click to rename "main background".
7. [05:04] Search bar: rectangle, white fill, add Effect > change Drop Shadow to Inner Shadow. Y position defaults to 4: set 0. Raise blur; opacity 25% default, set 30%. Corner radius 10.
8. [06:05] Text tool (T): type "search", size 48, font Fredoka One. Lighten text color.
9. [07:07] Center text: click text, Shift-click rectangle, use vertical center alignment. Fine-tune padding by selecting and holding Alt while hovering to read distances (top 9, bottom 8, left 15 at first); nudge with arrow keys, enlarge the rectangle by 1px at the bottom until equal.
10. [08:07] Pet frame: shape tool, tall rectangle (hold Shift for perfect square if wanted). Fill > Gradient (top to bottom): golden top, darker orange bottom (legendary look). Corner radius.
11. [09:09] Fake 3D: Ctrl+D the shape, press Down arrow a few times, change its fill to solid darker color.
12. [10:10] Outline around the whole 3D shape: select both layers, Ctrl+D, right click > Flatten (makes a vector), add stroke Outside, remove the fill (keep only stroke). Make it thicker (3).
13. [11:11] Rename to "black stroke"; duplicate, name "white stroke", set to white and thicker (6, so it equals the 3 black + 3 more visible). Add a drop shadow (Effects +): Y to 0, bigger blur, raise opacity then reduce a bit. This makes the frame float.
14. [12:11] Highlights via mask: duplicate the top layer, Ctrl+G group, right click the shape inside > Use as mask. Anything dragged into the group is clipped to the shape.
15. [13:11] Draw a long white rectangle, tilt it, drag into the mask group; Ctrl+D a second and resize smaller for variety.
16. [14:11] Select both highlights > Appearance blending mode (water drop icon) > Soft Light (Overlay looks similar but harsher).
17. [15:11] Halftone texture: copy image from UI Resources, Ctrl+V, drag into the mask group, resize (Alt+Shift), set blend mode Soft Light.
18. [15:11] Title text ("doggy"): move to top of layer list, white, black stroke, thicker. Alt-drag to duplicate for "level one".
19. [16:11] Group search as "search bar"; group everything else as "pet frame". Add a pet icon (from UI Resources), flip horizontally, put inside the pet frame group.
20. [17:13] Duplicate the pet frame group (Ctrl+D) and Shift+Right arrow to move; repeat Ctrl+D to auto-repeat the same spacing. Fix gap (frames showed 41 padding; increase). Group row as "golden frames"; Ctrl+D with Shift+Down to make rows.
21. [18:13] Search bar stroke: gray, thicker, position Outside.
22. [19:15] Equip Best button: rectangle, green gradient top-to-bottom (use Rotate gradient button), bright green top, darker green bottom, corner radius 10; duplicate and offset down with darker solid color for 3D; flatten, outside stroke 3.
23. [21:16] Mask group on button with soft/overlay highlight shapes plus dotted halftone texture on corners (duplicate, flip horizontally/vertically).
24. [22:19] Group as "equip button"; add text "equip best", center, stroke thicker; duplicate text, drag down for 3D text effect (fill the duplicate black for a stronger effect).
25. [23:19] Delete Mode button: duplicate the equip button, change text, switch gradients (top and bottom 3D layer) from green to red.
26. [25:22] Filter button: duplicate, delete texts and the vector (it won't resize), resize the shapes, remake outline (duplicate both, flatten, outside stroke 3) and text; make main shapes gray (white to gray).
27. [28:23] Exit button: square (Shift), corner radius 10, red gradient with inner pink stroke; duplicate for 3D (remove stroke on the bottom), flatten, black outside stroke, group "exit button"; "X" text with stroke 3 and 3D duplicate.
28. [31:28] Header: rectangle radius 10, bright blue to darker blue gradient, 3D duplicate in darker blue, flatten, outside stroke, "inventory" title with stroke and 3D text duplicate; mask group with highlights (soft light) and halftones on both sides rotated.
29. [34:34] Add drop shadow to the main frame (Y to 0, bigger blur and opacity).
30. [35:37] Rarity variants: select a row group > Properties > Selection colors; change the gradient top (pinkish purple) and the darker colors to make an epic purple row.
31. [37:39] Inner strokes: on the top frame of one pet frame, add stroke Inside, weight 4, brighter color (yellow for orange, bright purple for purple, bright green for green button); delete other copies and re-duplicate with Ctrl+D so positions repeat.
32. [38:42] Copy stroke property: click empty space in a properties section to highlight it, Ctrl+C, select another shape, Ctrl+V (color copies, weight does not: set 4).
33. [39:42] Fix a one-pixel misalignment: select all pet frames, use Align vertical center.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Frame size | 1920x1080 | Presentation preset |
| Corner radius | 10 | used on nearly everything |
| Base frame stroke | about 5, blue-ish, dashed | white outline duplicate Outside |
| Inner shadow | Y 0, blur raised, color opacity 30% | default Y 4, opacity 25% |
| Search text size | 48 | font Fredoka One |
| Black outline stroke | 3, Outside | on flattened vector |
| White stroke | 6, Outside | under black stroke |
| Drop shadow | Y 0, larger blur, opacity adjusted | default Y 4, opacity 25% |
| Blend mode (highlights, textures) | Soft Light (Overlay on button) | |
| Pet frame spacing | 41 (increased) | fixed by auto-repeat Ctrl+D |
| Inner stroke weight | 4 | Inside position |
| Fake 3D offset | Down arrow a few presses | darker solid duplicate |
| Gumroad price | $5 | for this UI |

## Prompts and skills used
No AI prompts. Websites: UI Resources (textures/icons), Figma, Gumroad (Kek), UI Genesis Discord.

## Gotchas and fixes
- Figma has no double strokes: duplicate the layer and use a second outside stroke.
- Effects default to Y 4: set to 0 to center shadows.
- Stroke only applies to one layer of a 3D pair: duplicate both, Flatten into a vector, then stroke Outside (remove fill).
- Resizing a flattened vector distorts it: delete and remake it after resizing.
- Text centering: Shift-click both, use align, then check with Alt-hover padding.
- Accidentally moving a duplicate 1px: select all and use Align vertical center.
- Copying stroke via Ctrl+V does not copy weight.

## Use it in our games
- Reuse the recipe for sim shop/inventory/pet frames: gradient + darker offset duplicate + black outline + white outline + shadow (inferred).
- Rarity colors via swapping gradient colors (orange legendary, purple epic in the video); extend to our own tiers (inferred).
- Build in Figma once as components then export slices for Roblox ImageLabels with UICorner/UIStroke for in-engine versions (inferred).
- Use the "Equip Best", "Delete Mode", "Filter", "Exit" buttons as a template for +1 and steal-style inventory screens (inferred).
