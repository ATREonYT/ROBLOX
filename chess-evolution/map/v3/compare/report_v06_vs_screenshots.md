# Map v06 vs the 4 screenshots (report only, nothing changed)

**How this was measured.** Each view was rendered from its fitted camera at the screenshot's exact size and laid over the screenshot at 50%. The sheet is `compare/final_sheet_v06.jpg`. HUD and players are ignored.

- **Positions:** edges were found by scanning both images for grass, path, wall and stone pixels. The screenshot's edge pixels were then cast back into the scene through the same camera to get positions in studs.
- **Colours:** the mean of each surface type, counting only pixels where both images show that surface (`scripts/colour_stats.py`).
- **Coordinates:** 1 unit = 1 stud, with spawn at 0,0. The lane runs along +Y, the treadmill stand is at -X and the phone stand is at +X.
- **Accuracy:** about ±1 to 2 studs. "About" marks a number read by eye.

**How well each view matches today** (the share of pixels where both images show the same surface type):

| View | Match |
|---|---|
| Phone | 0.86 |
| Treadmill | 0.80 |
| Hub | 0.69 |
| Lane | 0.65 |

---

## 1. Hub (overview)

**1. Layout and alignment**
- **Low:** The camera, the path cross and both stands line up within a few pixels. Nothing to fix.

**2. Pathways**
- **Low:** The cross, its widths and the branch to the lane match. Nothing to fix.

**3. Trees**
- **High:** A cube tree on the ledge behind the phone stand hides the lower third of the stand. Its canopy top is at about (57, -59, 36). The screenshot has no tree there; its big front-right tree stands at about (82, -36).
  - Fix: move that tree from (57, -59) to about (82, -36), or delete it.
- **Medium:** On the left grass edge the screenshot has a row of small pines plus cube bushes. Ours has fewer and larger trees there.
  - Fix: add 3 to 4 small 3-tier pines (about 0.6 of the current pine size) along x ≈ -60 to -45, y ≈ -20 to 40.

**4. Stands and platforms**
- **Low:** Both stands sit in the right place and at the right size in this view. See the phone-stand width under the Phone view.

**5. Cliffs and walls**
- **Low:** The wall line and the two terrace heights read the same. Nothing to fix.

**6. Props and items**
- **Medium:** The World 2 portal on the grass wedge is a purple and magenta door. In the screenshot it is a pale cyan and white glowing upright.
  - Fix: recolour the frame to white (F2F8FF) with a cyan (6FE8FF) glow.
- **Low:** The Hologram Phone pad is a pale pink glowing block. In the screenshot it is a flat purple square pad (about 8A5CF0) with a lighter rim.
  - Fix: make it a flat purple tile with a light rim.
- **Low:** The screenshot has brown wooden fence and bridge sticks by the water's edge. Ours are missing.
  - Fix: add 3 to 4 thin brown posts and rails at about (-28, -85).
- **Low:** The yellow-to-magenta glowing trail by the water is a game effect. It was not modelled on purpose.

**7. Colours**
- **Medium:** The screenshot's grass is paler: (123,229,71) against our (64,230,25).
  - This is only this screenshot. The other three show grass like ours: about (40,229,9).
  - Fix: leave the world as is and treat the hub shot as a colour-graded or lower-quality capture. Matching it would make the other three views wrong.

**8. Textures and materials**
- **High:** The grey stone has no studs (see "All views" at the end).

**9. Lighting**
- **Low:** Tree shadows on the grass are a bit darker and harder than in the screenshot.
  - Fix: widen the sun's angle from 6° to about 12° so shadow edges soften.

---

## 2. Treadmill (close-up)

**1. Layout and alignment**
- **Low:** The camera, the platform edges and the front-row and back-row positions match within about 10 px. Nothing to fix.

**2. Pathways**
- **Low:** The orange path's width and start match. Nothing to fix.

**3. Trees**
- **Medium:** The left pine behind the stand, at about (-75, -58), is about twice as wide as the screenshot's. It covers x 0 to 500 px; the screenshot's covers 280 to 520 px.
  - Fix: scale it to about 0.5 in width and height, and move it about 4 studs toward +Y.
- **Medium:** At the top right, the screenshot shows a big green tree block above the wall, at about x 2570 to 3024 and y 170 to 450 px. Ours shows only bare wall there.
  - Fix: add one cube tree on the hub grass in front of the wall, at about (-68, 70, 0), with its crown about 13 to 20 studs up. Casting the screenshot's pixels back puts it against the wall at y = 76.

**4. Stands and platforms**
- **Medium:** Back-row machines in the screenshot each stand on a dark navy pad, which is the unlocked or locked base. Ours stand on bare grey stone.
  - Fix: put a dark navy (1E2A5A) pad about 0.3 high under each back-row machine.

**5. Cliffs and walls**
- **Low:** The back wall, its green ledge stripe and the top lip match within about 12 px. Nothing to fix.

**6. Props and items**
- **Medium:** The machines are your new studded designs, not the game's current ones. They are bigger and more decorated, though their positions and footprints match. This is intended; keep them unless you want the old look back.
- **Medium:** There is a missing bush, made of 2 stacked green cube blocks, on the grass left of the path.
  - Fix: add it at about (-16, -14, 0).
- **Low:** There is a missing small green sprout plant right of the path.
  - Fix: add it at about (-15, 17, 0).
- **Low:** The face of the portal (blue frame, right edge) is flat magenta. In the screenshot it is a glowing magenta-to-pink gradient with sparkles.
  - Fix: give the face a vertical gradient from FF1EE0 to FFB6F5 and let it emit.

**7. Colours**
- **Low:** The path is a touch light and yellow: (244,142,28) against (236,130,11).
  - Fix: darken the path colour by about 4% and take the blue out (E8800A to E47A00).
- **Low:** The portal's blue is too pale: red 89 against 40.
  - Fix: make the frame a purer blue (2A6BFF to 1E5BFF) and take the white glow off the frame.

**8. Textures and materials**
- **High:** The platform stone and the sunken bays have no studs. In the screenshot the whole platform shows a grey stud grid.

**9. Lighting**
- **Low:** Fine.

---

## 3. Phone stand (close-up)

**1. Layout and alignment**
- **High:** Our phone stand is about 8 studs too wide. At the middle row its side edges reach y ≈ +33 and -35; in the screenshot they reach about +29.5 and -30.6.
  - Fix: pull each side cheek and wing in by about 4 studs. The stand's half-width goes from about 34 to about 30 studs.

**2. Pathways**
- **Low:** The path's start and width match (632 px against 636 px). Nothing to fix.

**3. Trees**
- **Low:** The trunks at the left and right corners match closely. Nothing to fix.

**4. Stands and platforms**
- **High:** In the screenshot the front row sits in a sunken bay cut into a flat platform. The bay's back wall and left and right sides are dark studded slopes, so the platform outline is a trapezoid. Ours instead has a raised back tier with a light-grey vertical face, and the front row on the lower level.
  - Fix: keep the back row at platform height. Lower the front-row area into a bay, by eye about 1.5 studs deep, with sloped sides about 8 studs wide at the ends. Use the darker bay stone (Paving_Bay_Grey) on the slopes.
- **Medium:** In the screenshot the front edge has a darker grey trim band along its whole length. Ours is lighter and thinner.
  - Fix: make the front trim 1 stud tall with Paving_Dark_Trim.

**5. Cliffs and walls**
- **Low:** The back wall and its grey base band match. Nothing to fix.

**6. Props and items**
- **Medium:** The phone items are blocky stand-ins. In the screenshot they are glowing crystal phones with particles: back row on black plinths, front row on coloured pads.
  - The pad colours already match (green, cyan, red, black, black).
  - Fix: real phone models or a phone mesh from your kit. The particles belong to the game.
- **Low:** Two small green sprouts are missing in front of the stand, left and right of the path.
  - Fix: add them at about (25.5, 10.7, 0) and (26.2, -12.1, 0).
- **Low:** A bush is missing at the left front corner.
  - Fix: add 2 stacked cube blocks at about (22, 24, 0).

**7. Colours**
- **Medium:** The back wall is too dark in this view: red 171 against 190.
  - Fix: the same wall material reads right in the treadmill view (190 against 196), so this is shade, not colour. Light the wall behind the phone stand more, for example by giving it a little less shadow from the corner trees, rather than changing the material.
- **Low:** Stone is within 10. Nothing to fix.

**8. Textures and materials**
- **High:** The stone has no studs. In the screenshot the platform, the bay slopes and the plinth tops all show the stud grid.

**9. Lighting**
- **Low:** Fine. The glow on the items is weaker than the game's particles, which is expected.

---

## 4. Lane (long view)

**1. Layout and alignment**
- **Low:** The camera matches. The lane floor lines up within about 20 px, with the same width (501 px against 492 px).

**2. Pathways**
- **Low:** The lane floor, the red mats and the stage gates match. Nothing to fix.

**3. Trees**
- **Medium:** Two white-trunk birch trees are missing. In the screenshot one stands on the left top land at about (-48, 144) and one on the right at about (47, 159).
  - Fix: add 2 birch trees, each with a white (F0F0F0) trunk with grey patches and a cube crown.
- **Medium:** The left-bank pines are bigger and closer together than the screenshot's. The screenshot shows separate 3-to-4-tier pines with sky between them.
  - Fix: scale them to about 0.75 and space them every 26 studs instead of 20.
- **Low:** The big tree at the right front, at about (46, 91), is the right size, but its feet sit right at a terrace edge. See the right-block fix under Cliffs and walls; that fix also cures this.

**4. Stands and platforms**
- Nothing in this view.

**5. Cliffs and walls**
- **High:** The block right of the lane has an extra step at the front.
  - Ours has a ledge 10 studs deep at height 24.6, from y 79 to y 89. Above it sits a second face at y = 89.
  - In the screenshot the front face rises in one piece from the ground to the top land (38.6). Its top edge is at about y 76 to 79, and the top land runs right up to that edge. That is why the screenshot shows grass in front of the big tree's feet.
  - Fix: delete that 10-stud front ledge. Bring the upper terrace's front face forward from y 89 to y 79, so the front face goes straight from 0 to 38.6.
- **Medium:** The left ledge near the lane mouth is too wide.
  - In the screenshot the upper cliff on the left comes forward near the mouth. Its foot is at x ≈ -27 at y ≈ 79 and slants back to x ≈ -35 by y ≈ 109. Beyond that it runs straight at about x = -35.
  - Ours runs straight at x = -37 all the way.
  - Fix: move the left upper cliff to x = -35 along the lane. For the first 30 studs (y 76 to 106), slant it from x = -27 to x = -35.
- **Low:** The left upper cliff face is a little taller than the screenshot's (its top edge sits about 40 px higher on screen).
  - Fix: check this again after the change above, before touching the height.

**6. Props and items**
- **Low:** The stage gates, the red mats and the small coloured pads match.

**7. Colours**
- **Medium:** The lane floor stone is too dark and too neutral: (163,168,167) against (172,186,189).
  - Fix: make the lane floor colour a lighter blue-grey, about (176,190,194) or B0BEC2.
- **Low:** The grass has a little too much blue in every view: blue +7 to +13.
  - Fix: set the blue in the grass colours to 0, or use a whiter fill light (EEF2F6 to F4F4F2).

**8. Textures and materials**
- **High:** The lane floor has no studs. The screenshot shows the grey stud grid all along it.
- **Medium:** In the screenshot the red cliff faces show clear square studs. Ours are faint.
  - Fix: raise the rim term in the wall texture (`inout` or `baseplate` on Bark/Wall) from 0.30 to about 0.45.

**9. Lighting**
- **Medium:** Cast shadows from trees on the top land are dark patches in ours. They are barely visible in the screenshot.
  - Fix: widen the sun's angle to about 12° and/or turn shadow casting off for the tree crowns. Keep the face shading as it is now, since that now matches.
- **Low:** The screenshot's sky has soft white clouds; ours is plain blue.
  - Fix: add 3 to 4 flat white cloud cards, or ignore this.

---

## All views

- **Textures, High:** Every grey stone surface is flat grey. In all four screenshots the stone shows the stud grid: the treadmill platform, the phone stand, the bays and the lane floor.
  - Fix: add a stone stud texture, the same way the grass got its studs. Use the `inlet` style (sunken squares) at the same 8 by 8 tile, multiplied onto the stone colours. Do this before any other polish, because it touches every view.

## The 5 most important fixes

1. **Studs on all grey stone** (every view, High). Add the sunken-stud texture to the platforms, bays and lane floor.
2. **Delete the 10-stud front ledge on the block right of the lane** (Lane, High). The front face goes straight up from 0 to 38.6 at y ≈ 79.
3. **Make the phone stand about 8 studs narrower, with a sunken front bay** (Phone, High). Pull each side in about 4 studs. Keep the back row at platform height and drop the front row into a bay about 1.5 studs deep with sloped sides.
4. **Move or delete the tree hiding the phone stand** (Hub, High). It is at about (57, -59); the screenshot's tree there stands at about (82, -36).
5. **Narrow the left lane ledge near the mouth and fix the trees** (Lane and Treadmill, Medium).
   - Left upper cliff: slant it from x -27 to -35 over the first 30 studs, then run it at -35.
   - The left treadmill pine at half size.
   - Add the two birches and the missing bushes.
