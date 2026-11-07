# Folk Stud UI style spec

Measurements and layouts behind the kit. Where this file and SKILL.md differ, SKILL.md wins: its rules are later corrections, such as text outlines of 3.7 with Bevel joins, and burning colours over sampled ones.

The look: **a bright white studded sheet with no title bar, where everything on it is a thick black sticker**. The title, icon and close button break out of the frame. Colour comes only from the objects, never from the window.

**How far to trust the numbers.** The Rebirth window was measured from the pixels of a 907 x 619 screenshot, so its figures and hex values are measured. The HUD, Index and Exclusive Shop screens were only read by eye from these screenshots, so their figures are estimates until they are measured. Fonts are judged by eye in every case. Scale all pixels with the window.

## Window

Measured on the Rebirth window, 792 x 541 px outside the outline.

| Part | Value |
|---|---|
| Body | Solid white `#FFFFFF`, no transparency |
| Outline | Pure black `#000000`, 4 px plus 1 px of soft edge |
| Corners | About 14 px radius, so they read as rounded but still square |
| World behind | Strongly blurred, so the white sheet sits on soft colour |
| Title bar | **None.** There is no strip, gradient or divider |

### Body studs

| Part | Value |
|---|---|
| Tile | 25 px wide by 23 px tall, about 3.2% of the window width |
| Mark | An L shape, the left and bottom edges of a stud: 11 px tall and about 11 px wide, with a 2 px core |
| Mark colour | `#DFDFDF` at the core, on white |
| Top and right edges | Almost nothing, about `#F9F9F9` at most |

Only the shadowed side is drawn, so the studs stay very faint and text on the sheet stays clean. Use a real tiled image, not many frames.

### Title and icon

- The icon sits over the top left corner and pokes out past both edges. In the Rebirth window it spans about x 2 to 70 and y 13 to 85, while the window corner is at (16, 34). It is about 9% of the window width.
- The title sits right after the icon, centred on the top border line, so the black line runs behind the letters. Its letters are about 40 px tall.
- Author's note: centre the letters' height on the border line, not the text box. The reference's title sits lower, about 9 px below the line, and the style's author wants it centred.
- White text with a black stroke of about 5 px, rounded.
- There is no shadow. The thick stroke does the work.
- The icon has its own dark ink: navy `#040435` on the Rebirth icon, and near black `#1A1A1A` on the arrow and arm icons. Icons are not outlined in pure black like the frames.

### Close button

| Part | Value |
|---|---|
| Size | 73 x 77 px, about 9% of the window width, with its lip in the height |
| Position | Over the top right corner, poking out about 21 px to the right and 21 px above |
| Face | Vertical gradient, `#FB303E` to `#D00709` |
| Lip | `#AB0808`, 4 px at the bottom |
| Outline | 3-4 px black, with a radius of about 12 px |
| Studs | 3 x 3 marks at a 22 px step: a dark edge about `#B5222B` and a lit edge about `#FA5C66` |
| Author's choice | **No studs on the X in our builds.** The reference has them, but the style's author wants the close button plain |
| X | Bold white with a thick black stroke |

## Plates and buttons

The key rule: **a thing you can press has a lip and studs, and a thing you only read has neither.**

### Info plates (the x1 Money and x1.5 Money boxes)

| Part | Value |
|---|---|
| Size | 278 x 97 px, about 35% of the window width |
| Outline | 5 px black, radius about 12 px |
| Face | Plain vertical gradient, `#A0FF3B` to `#1CE306`, no lip or studs |
| Watermark | A large icon, centred behind the text, sunk into the green at low contrast and cropped by the frame |
| Text | White, black stroke about 4 px, filling about half the plate height |

### Pressable buttons

Measured from the Rebirth button, 245 x 88 px, and the purple Skip button, 222 x 80 px.

| Part | Green | Purple |
|---|---|---|
| Face top | `#91F630` | `#C33BF5` |
| Face bottom | `#31DD22` | `#9A0EE4` |
| Lip | `#08A917`, 4 px | `#7407BA` to `#6106A1`, about 4 px |
| Outline | 4 px black, radius about 16 px | Same |
| Stud marks | Lighter than the face, about `#A9FD5E` on `#92FD31`, at about a 24 px step | Same idea in lilac |

- The main action is the largest and the greenest. The other actions in the row are smaller and purple.
- The gift button is a square purple button of about 78 x 80 px, holding only a present icon. It sits right beside any Robux or skip price.
- Buttons in a row have gaps of about 15 px.
- A subtitle can break out of the bottom edge: KEEP STRENGTH! is small white capitals with a black stroke, sitting over the button's lip.

### Other pieces

- **Progress bar:** flat grey track `#B5B5B5` with a 4 px black outline, 633 x 70 px. The fill is a vertical gradient from `#27CBFF` to `#29A1FF`, and it has its own black outline on its right end. A big icon overflows the far end of the bar, showing what the bar is for. Centred text with a black stroke.
- **Warning text:** coral `#FF5C5C` with a black stroke, directly on the white sheet. This is the only coloured text on that window.
- **Arrow between plates:** chunky white with a sky lip `#8BC0DD` and a `#1A1A1A` outline of about 4 px, rounded. It is 76 px wide.

### Type

- Looks like Montserrat ExtraBold or Black for all text, with a thick rounded black stroke. Check the weight in Studio against the reference.
- Text sits directly on the sheet with no plate behind it.
- Stroke roughly scales with size: about 5 px on the title, 4 px on plates and about 3 px on small labels.

## Stud texture IDs

The style's author supplied these. Both are public decals, so use the image ID in code: a decal ID does not load in an `Image` property.

| Use | Name | Decal ID | Image ID | Texture |
|---|---|---|---|---|
| Tried first, then dropped: its R squares look busy on white | Universal Studs | 82666893993499 | 93033739647054 | 4 x 4 studs per image, already faint (alpha at most about 55 of 255). Every second stud has a raised R |
| **Author's pick: "normal studs"** | Stud (Transparent) | 3014551680 | 3014551673 | 2 x 2 studs per image, strong dark and light edges. On the white sheet use `TileSize` 50 x 46 at `ImageTransparency` 0.8. On buttons use 48 x 48 at 0.55 |

- Tile size is the number of studs per image times the stud step. Faded this way, this texture's edges read as the reference's L marks, which suggests it may be the same kind of texture.
- Find the image ID in Studio with `game:GetObjects("rbxassetid://<decal id>")[1].Texture`.

## Text outlines: author's rule

- **Use a `UIStroke` thickness of 3.7 on all text, with `LineJoinMode` set to Bevel.** This replaces the per-size stroke values listed elsewhere in this note.
- Round joins close up the holes in letters like O and 0. If a letter's hole looks wrong, change the join mode before changing the thickness.
- Do not use Miter at this thickness. It throws sharp spikes off letter corners, most visibly on small text such as rarity labels.

## Fitting item art

From fitting the style's author's art into the stud shop:

- Long thin sword art looks tiny when upright in a square slot. Rotate it about 40 degrees and enlarge the slot, so it fills the card's diagonal.
- Use `ScaleType.Fit`, not Crop, for items, so wings and flames are not cut off.
- Let a crate's art overlap the strip below it.
- A banner background must sit behind the content. Roblox GUI has no image blur, so blur the picture before uploading, and raise its saturation so it stays vivid. Do not fade it with transparency, which turns it stale.
- A picture background takes no stud texture, and the blur should be light enough to keep the scene readable: about 5 px on a 1024 px wide image worked here, where 9 px was too much.
- On a bright rarity card, keep a black outline. A rarity coloured outline disappears against a vivid face.

## Gift icon IDs

The style's author supplied these for the gift button. All three are public decals, so use the image ID in code.

| Asset name | Decal ID | Image ID | Note |
|---|---|---|---|
| Gift Icon | 123818257119451 | 114440493073627 | |
| PLAYTIME GIFT ICON | 81141841222365 | 129606937650131 | The one set on the Rebirth window's gift button in the test place |
| gift_icon3 | 126380337706170 | 86546455378804 | |

## Rebirth build, tested

The Rebirth window was rebuilt in Studio on a 907 x 619 root, using the reference's pixels as coordinates, and captured at 1:1 beside the reference. Frame edges landed within 1 px, and sampled colours were close. These numbers came from that comparison.

| Text | Montserrat Heavy size | Stroke |
|---|---|---|
| Title | 50 | 5 |
| Rebirth 0 and 1 labels | 36 | 4 |
| Plate text | 51.5 | 4.5 |
| Warning | 40 | 4 |
| Bar text | 41 | 4.5 |
| Main button | 53 | 5 |
| Skip button | 35 | 4 |
| Skip subtitle | 23 | 3.5 |
| X | 56 | 4.5 |

- `Montserrat.json` at `Enum.FontWeight.Heavy` matches the letter shapes and widths, so this confirms the font guess by eye.
- Body stud image: `ImageColor3` black at `ImageTransparency` 0.875, gives `#DFDFDF` on white.
- Button stud image: one raised rounded square per 24 px tile, at `ImageTransparency` 0.35.
- A `TextButton` already has a `Text` property, so a child label named Text must be reached with `FindFirstChild`, not `button.Text`.
- Hover at 1.06 and press at 0.94 on a `UIScale` feel right, with the open pop on the root's `UIScale`. Those values are this build's own choice, because a still image shows no motion.
- Keep the screen fit and the open pop on separate `UIScale` objects. In a real Play start the camera's `ViewportSize` is near zero for a moment, so tweening one scale back to a value saved at that moment leaves the window invisible. A test on an already running client does not show this bug.
- The studio tool can only upload images from an http URL, and it needs the served folder set with `--directory` so the paths resolve.

## Rebirth layout

Each row has one job, reading from top to bottom:

1. Two labels, Rebirth 0 and Rebirth 1.
2. Two plates with an arrow between them, showing the change at a glance.
3. The cost in coral.
4. The progress bar.
5. The action row: main button, purple skip, gift.

The plates are 122 px apart, leaving room for the arrow. The action row is pushed right, under the end of the bar.

## Index

Read by eye. The window uses the same white sheet, with the same title and close button.

| Part | Rule |
|---|---|
| World card | Tall card on the far left with a painted scene and the world's name at the top. One per world, with its creature grid to the right |
| Creature grid | Four columns of rounded tiles, tinted by rarity, with black outlines and faint studs |
| Rarity label | Small text at the top left of each tile, coloured by rarity with a black stroke, breaking the tile's top edge slightly |
| Locked creature | A solid black silhouette with `???` at the bottom right |
| Found creature | Its full colour model, with its name at the bottom right in place of `???` |
| World progress bar | Dark track, lime fill, a count such as 1/8 and a reward item overflowing the right end |
| Next world | The list scrolls, and the next row is cut off cleanly above the claim button |
| Claim All | A wide blue button fixed along the bottom of the list, with an icon overflowing its left end |
| Detail panels | Two plates on the right: grey with studs, "Found in" and a large icon, then a green gradient "Rewards:" plate |
| Side tabs | Outside the window on the right, at a height near the middle. These are wide grey and brown studded pills, with a word over an icon that overflows the pill |

These side tabs are wide and hold a word, unlike the square tabs in Rainbow Shop Menu Style - Owner Reference.

## Exclusive Shop

Read by eye. The page scrolls under the fixed title, with cards cut off cleanly by the frame.

**Featured offer**

- A full-width banner with a dark painted scene and a thin pastel gradient border.
- Large title with a gradient fill, a tilted NEW! tag at the top left, and a red ENDS IN timer pill at the top right.
- The hero item sits on a white burst at the left, with the odds row beside it.
- Odds cards rise in rarity from left to right. Each has a rarity word in its own colour, a percent tilted over the top corner, and a model that breaks out of its card. The rarest card is the brightest and has a pale outline.
- A dark pill below tracks a goal: SUPER SIZE BOOST IN 50 EGGS and 0/50.
- Four prices run along the bottom, each with a gift button. Quantity sits under the price, and a small red discount tag sits on top. The best-value pack has a gold outline.

**Three column offers**

- Each card has its own full-colour gradient and studs: blue, red and gold.
- Two lines of title: a rarity word in its own colour with a stroke, then the item name in white.
- A big item fills the middle and overlaps the band below it.
- A dark see-through band shows the possible contents with their percents. The row is cut off at the card's edges, which shows there is more to see.
- A green price button and a purple gift button sit at the bottom, and the card has a darker lip.

**Bundles and passes**

- A rainbow bundle card has a gradient title with a bracket tag such as [OP], and a list of contents with each name and rarity in its own colour.
- The old price sits over the button in red with a strike through it, and overlaps the button's top edge.
- LIMITED OFFER! sits on the card's top edge in gold text with a black stroke.
- A pass card uses a warm gold studded face: big icon at the left, centred title and description, OP! in coral at the top right, and the price and gift buttons at the lower right.

## HUD

Read by eye from a 1919 px wide capture.

| Part | Rule |
|---|---|
| Objective | Very large, centred text near the top: Lift on your Bench! 0/50. **Each word has a colour:** the verb blue, plain words white, the object orange, and the count lime. Thick black stroke, on a dark see-through band that fades out at both ends |
| Main money | Giant lime gradient number above the objective, $60K, with a dark outline. It is the largest thing on the screen |
| Second count | Smaller red count with an icon beside the money |
| Left buttons | Three stacked squares of about 112 px at a step of about 125 px: Shop, Index, Rebirth. Studded gradient faces, black outlines, an icon that fills the tile and a one-word label over its lower edge |
| Right buttons | The same tile in the same size, on the right side: Animals, Eggs |
| NEW! tag | Small red tag on the tile's top right corner |
| Stats | Bottom left stack with no plates: a large icon and a large number in the icon's colour |
| Boost line | Bold italic text with a small green plus button, at the bottom left |
| Path to the goal | **White rounded chevrons laid on the ground** from the player to the target, in perspective, about one every 50-60 px on screen near the player |
| World labels | Text with black strokes floating over items, with no plates: the name in white and the price in lime with a Robux icon. Bargains get a tilted red Cheap! with a white burst behind it |
| Timers | An icon and white text on a soft dark band that fades out, such as a moon and "in 2m 20s" |
| Hotbar | A single small dark rounded slot, centred at the bottom |
| Buff | A green square at the bottom right with its time left written over it |

The screen is loud but readable because the corners and edges hold the buttons, and the middle stays open for play.

## Quests, as built

The same shell as the shop, with Daily and Weekly as side tabs. Pixel values are this build's own, tuned by eye against the other screens.

| Part | Value |
|---|---|
| Row | 118 tall with a 12 gap, radius 16, 4 black outline, 6 lip in the row colour's dark shade. Gradient face with studs 48 x 48 at 0.72 |
| Icon | Sticker of 88 centred at x 62, y 54, floating. Rays of 130 behind it when ready or `hero` |
| Title | Size 28 at x 122, y 26, left aligned |
| Description | Size 18 at x 122, y 52 |
| Bar | 420 x 28 at x 122, y 72, lime fill, count centred at size 18. White track with a 3 black outline |
| Reward | Sticker of 52 at x 596, y 38, with gold `#FFE600` text of size 22 under it |
| Button | 150 x 64 at x 668, y 24, label size 28. DONE! is 150 x 60, because it has no lip |
| Timer pill | 214 x 36 beside the heading, red with studs, beating, and 36 in from the right edge to clear the X |

## Backpack, Index and Settings, as built

Tuned by eye against the other screens, in the same window as the shop.

| Part | Value |
|---|---|
| Item list | 590 wide scroll, 572 of content, leaving the card on the right |
| Backpack tile | 134 square, gap 12, lip 5, sticker art at 69% of the tile, name size 16, rarity size 14 at the top left |
| Index tile | 106 square, gap 8, name size 13, rarity size 12, beside a world card 112 wide. A 36 tall white bar sits below, with a 64 reward sticker over its right end |
| Claim button | 574 x 58, fixed under the list, with its icon overflowing the left end |
| Card | 258 x 556, 12 in from the window's right edge and 52 down, to clear the X. Rays 270 and art 170, name size 28, two stat rows |
| Card button | EQUIP is lime and studded. EQUIPPED is flat lime, with no studs or lip |
| Worn mark | Lime tag with an E, overflowing the tile's top right corner |
| Settings row | 92 tall, gap 12, sticker 68, title 26, description 18. Toggle 160 x 60: lime ON, red OFF |
| Slider | White track 300 x 30 with a lime fill, a gold knob of 42 and a gold number. The knob overhangs, so leave room before the number |
| Rail labels | Size 21, so Backpack and Settings fit a 112 square |

## How it differs from the rainbow shop style

| | Rainbow Shop Menu Style - Owner Reference | This style |
|---|---|---|
| Body | Dark and translucent | Solid white with studs |
| Header | Rainbow bar | None, the title sits on the border |
| Close button | Inside the bar | Over the corner, poking out |
| Colour | Cards and header | Cards and buttons only |
| Font | Fredoka One | Looks like Montserrat ExtraBold or Black |
| Prices | Lime number printed on the card | Green studded button beside a purple gift button |

## Common mistakes

- Adding a title bar. The title on the border, with nothing behind it, is the signature of this style.
- Studs too strong, or drawn on all four sides. On the sheet they should be almost invisible.
- Giving every box a lip. Plates you only read stay flat, so a lip means it can be pressed.
- Keeping the icon, X and title inside the frame. They must break out of it, which means the window must not clip them.
- Thin text strokes. Thin outlines make text unreadable on the bright gradients.
- Using a tinted or grey outline on frames. The frame outline is pure black.
- Colouring the window. The white sheet is what makes the objects loud.
- Showing a price without a gift button, where the game offers gifting.
- Copying this reference's art or names. Use the construction with your own icons.

## Checklist

- White sheet, faint L shaped studs, 4 px black outline, radius about 14 px, blurred world behind.
- No title bar. The title is centred on the top border, with the icon and X overflowing the corners.
- Pressable: gradient face, lip, studs, 4 px black outline. Read only: gradient face and outline.
- Main action in green and largest. Secondary actions in purple.
- Thick rounded black stroke on all text. Coral only for warnings.
- Bars have a big icon overflowing the end, showing what the bar is for.
- Lists scroll beneath fixed parts and are cut off cleanly.
- HUD objective with one colour per word, and a ground chevron path to the target.
- Read it on a phone, and make sure overflowing icons never cover a button's tap area.

