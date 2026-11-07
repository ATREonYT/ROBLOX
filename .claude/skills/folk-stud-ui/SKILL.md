---
name: folk-stud-ui
description: >-
  Build and tune Roblox menus in the Folk Stud UI style, a white studded sheet with no title bar, thick black outlines, burning vivid colours, spinning light rays and chunky animated buttons, with a ready left rail HUD, shop, quests, backpack, index, settings and rebirth windows that work right after install. Use this whenever someone asks for a stud UI, a "steal a" style menu, a simulator shop, crate or egg shop, quest tab, daily or weekly quests, backpack or inventory, pet or item index, settings menu, rebirth window, HUD buttons on the left rail, or any cartoon Roblox menu in this look. Also use it when they want icons from the FOLK Icon Pack zip, or when they have added their own images to one of these menus and say things like "fix and adjust them", "tune the colours" or "make the background blurry", even if they never name the style.
---

# Folk Stud UI

A white studded sheet with thick black stickers on it. The title, icon and X break out of the frame, and all colour comes from the objects. The menu is meant to be handed to people who will drop in their own art, so expect that and treat their edits as the source of truth.

## Quick start

When someone asks for this with no other direction, build it all straight away from the sample content, and let them react to it. They get a left rail with Shop, Quests, Rebirth, Backpack, Index and Settings squares, and each window starts closed and pops open from the rail. Follow `references/studio-workflow.md` to install:

1. `ReplicatedStorage.FolkStudUI` from `scripts/FolkStudUI.lua`
2. `StarterPlayerScripts.FolkStudClient` from `scripts/FolkStudClient.lua`
3. Build in Edit mode, into `StarterGui`, from `scripts/sample_config.lua`. Set `Enabled = false` on `FolkShop`, `FolkQuests`, `FolkRebirth`, `FolkBackpack`, `FolkIndex` and `FolkSettings`

Then check for the icon pack with `py scripts/icons.py where`. If it is there, offer to replace the placeholder icons with matching ones from it, following `references/icon-pack.md`. If it is not, carry on: the menus work without it.

## Files

- `scripts/FolkStudUI.lua`: the kit. `M.hud`, `M.shop`, `M.quests`, `M.setQuest`, `M.backpack`, `M.equipItem`, `M.index`, `M.setFound`, `M.selectItem`, `M.settings`, `M.settingsLive`, `M.setSetting`, `M.rebirth`, `M.live`, `M.hudLive`, `M.show`, `M.pop`, `M.setBar`, and the colour tokens.
- `scripts/FolkStudClient.lua`: runs the rail and the windows.
- `scripts/sample_config.lua`: placeholder content to copy and edit. Leave a section out and its side tab goes too.
- `scripts/icons.py`: finds icons in the separate icon pack zip without unzipping it, and copies the chosen ones out. See `references/icon-pack.md`.
- `references/asset-ids.md`: the known IDs: studs, rays, shop, rebirth and gift icons, pointer. Check it before asking for an ID.
- `scripts/prepare_background.py`: bakes the blur for a banner background.
- `references/images/`: the reference screenshots this style comes from: rebirth, index, HUD, exclusive shop and the rainbow shop. Look at them before building a new screen, and copy their construction, not their art or names.
- `references/studio-workflow.md`: installing through the Studio tools, uploading images and testing. Read it before the first build, because those tools have traps.
- `references/style-spec.md`: every measurement, plus layouts for an index, featured offers and a HUD. Read it for any screen the templates do not cover.

## Build order

1. Find the place with `list_roblox_studios`, and confirm it is the one the user means.
2. Install the kit and build into `StarterGui`, so the user can see and edit the window without pressing Play.
3. Add a LocalScript that calls `M.live` on the copy in `PlayerGui`. Leave the buy and gift handlers for the game's own purchase code, and grant on the server.
4. Test in Play, then report what was and was not tested.
5. For another screen, reuse the kit's helpers and tokens, not new ones, so it stays one style.

## The rules, and why

These all came from a real build being corrected by eye.

| Rule | Why |
|---|---|
| Use the most burning tone of every colour | Pale, pastel or greyed versions look stale. Do not lighten by mixing in white. Dark shades are for lips and outlines only, never button faces or bar tracks: a bar track is white with a black outline. This beats a colour sampled from a reference |
| All text gets a `UIStroke` of 3.7 with `LineJoinMode` Bevel | Round closes up the holes in O and 0. Miter throws spikes off corners, worst on small text |
| Stud texture `3014551673`: sheet tile 50 x 46 at `ImageTransparency` 0.8, buttons and cards tile 48 x 48 at about 0.55-0.75 | It holds 2 x 2 studs, so the tile is twice the stud step. At full strength it looks noisy |
| No studs on the X | It should read as plain and instant |
| No studs on a picture background | They fight the picture |
| No title bar. Centre the title's letters on the top border line, with the icon hanging over the corner | This is the style's signature. Centre the letters by eye in a capture, because the text box and the letters differ |
| Centre anchor every button, scale with a `UIScale` | A top left anchor makes a button grow toward its lower right |
| Keep the screen fit and the open pop on two separate `UIScale`s | The camera size is near zero at Play start. A pop that tweens back to a saved fit value leaves the window invisible, and this only shows in a real Play start |
| Anchor so the window, not its canvas, is centred | Overflow margins otherwise push the window off centre |
| Labels hug their text with `AutomaticSize.X` | A wide label is awkward to select in Studio |
| Black outlines on vivid cards | A rarity coloured outline disappears against a bright face |
| Pressable things get a lip and studs. Things you only read stay flat | The lip tells the player what can be pressed |
| Name a text stroke `UIStroke`, not a made up word | People look for it by name in the Explorer |
| Screens start closed and open from a rail of gradient squares: icon inside, word underneath it and still inside | The HUD stays clear, and the rail teaches where things are |
| Keep the menu alive | Light rays spin behind heroes and top rewards, heroes float, tags wiggle, the best deal's outline glints, and cards pop in one after another. A still shop looks unfinished. `M.live` skips idle motion when the player has reduced motion on |
| Black outline and drop shadow on hero art, hard shadows under cards, a drop only under text of 30 px and up | They lift the art off vivid backgrounds and sell the sticker look |
| Every state of a button stays burning. A finished button is the flat lime gradient with white text, no studs and no lip | A dark teal DONE! was rejected on sight as ugly. Losing the studs and lip is what says it can no longer be pressed, so the colour does not have to go dull |
| A row that holds its own buttons gets `NoHover` | Only the button inside should grow, or the row and its button both move under the mouse |
| Keep anything fixed to a heading clear of the X | The X overhangs the top right corner, so a pill flush with the right edge gets its corner covered at the top of the scroll |
| Flat icons get a black outline and shadow: use `sticker`, not a bare image. The exception is a 3D preview of the model | A bare icon looks empty on a vivid card, and thin art like a sword almost disappears |
| A selected tile gets a thick gold outline | White disappears against the white sheet |
| Matching labels get the same size, height and shadow | A drop on one and not its neighbour reads as a heavier stroke, even when both strokes are 3.7. Set one size that fits the longest word |

Copy the construction of a reference, never its art or names. Offer to draw new icons, or use the user's own.

## Adding a screen

`M.quests` is the pattern to copy for any scrolling screen:

1. Inside `FolkStudUI`, call the local `shell(parent, cfg, name, kind, title, icon)`, which makes the window, X, title and scroll, then lay out rows into its content.
2. Give each section a heading, set the content and canvas size from the final `y`, and call `sideTabs` so tabs jump and follow the scroll.
3. Add a square to `hud.buttons` with `opens = "<ScreenName>"`, and pass the screen to `M.hudLive` and `M.live` in the client.
4. Rebuild only the new screen and `FolkHud`. Rebuilding the others throws away edits the user made to them. Set `Enabled = false` on the new screen.

## The quest window

A quest is `{ id, title, desc, have, need, reward, rewardIcon, color, icon, hero, state }`, and sections are `{ name, timer, icon, color, quests }`. Leave `timer` out and the pill goes too. The timer text is plain sample text, so the game has to update it.

| State | Button | Row |
|---|---|---|
| `go`, the default while `have < need` | Blue GO, studded | Plain. Rays only on a `hero` row |
| `ready`, the default once `have >= need` | Lime CLAIM, studded | Rays behind the icon, and the outline glints gold |
| `done`, only ever set by you | Flat lime DONE! | Outline back to black, a small pop |

`M.setQuest(gui, id, have, need, state)` updates a row and tweens its bar. Pass nil for `have` and `need` to keep the counts, as a claim does. In the template, Go closes the window and Claim marks the row done with no reward. Before shipping, make Claim ask the server, which checks progress and pays, and show its answer, because a client that pays can be exploited. Make Go point the player at the quest.

A row is only a visual state, so a rebuild resets it to the config. Calling `setQuest` in Edit mode writes that state into `StarterGui`, so rebuild afterwards.

## The item screens

Backpack and Index share a scrolling tile list on the left, 4 tiles across, and a card on the right that shows the selected item. Sections become side tabs.

- **Tiles:** `{ id, name, rarity, art, desc, stats = { { "DAMAGE", "120" }, { "SPEED", "1.2" } } }`, with at most two stats. Rarity is Common, Rare, Epic, Legendary, Mythic or Divine, and sets the colours.
- **Backpack:** an item also takes `equipped` and `use`. `use` is the button's word: EQUIP by default, or something like OPEN or USE. Only EQUIP items mark themselves worn. `slots` adds a count on the top border. Keep what a player owns on the server, and fill the screen from it.
- **Index:** each section is a world, with `color`, `icon` or `background`, `reward` and `rewardArt`. An item with `found = true` shows in full, and the rest are black silhouettes called ???. `M.setFound(gui, id, true)` reveals one and updates the bar. `claim` sets the bottom button's words.
- Item art uses the same values as everywhere else, so a long sword can be `{ id = ..., rot = 40, scale = 1.35 }`.

## The settings window

A row is `{ id, title, desc, value, color, icon }` plus `kind`: nothing for a toggle, `"slider"` with `min` and `max`, or `"button"` with `label`. Run it with `M.settingsLive(gui, { change = fn(id, value), press = fn(id) })`, not `M.live`, because the sliders need it. Scrolling pauses during a slider drag. The template saves nothing: apply each change, save it through the server, and load saved values with `M.setSetting`. Sliders have code for touch, but only the mouse has been tested.

## When the user adds their own art

This is the most common request after the first build: they swap images in Studio, then say something like "added new images, fix and adjust them and the rest".

Start by reading the live GUI. List every `ImageLabel` whose image is not a kit default, with its position, size, rotation and `ScaleType`, and take a capture. Then patch in place, because rebuilding would throw away their edits. Apply the same fix to the module too, so a rebuild keeps it.

Look for these patterns:

| What you find | Fix |
|---|---|
| A picture placed in a `Studs` layer, so it is faint and tinted | Give it its own opaque `Background` layer with `ScaleType` Crop and matching corners |
| A sticker whose `Art` was swapped but its `Ink` copies were not, so the old shape shows as the outline | Set every `Ink` image to the new art |
| Long thin art, like a sword, looks tiny in a square slot | Rotate about 40 degrees and enlarge, so it fills the diagonal. Slightly larger for rarer items reads well |
| `ScaleType` Crop on an item, cutting off wings or flames | Use Fit, at one consistent size across its row |
| An icon touching a button | Shrink or move the icon, not the button |
| New art in only some slots | Offer to carry it into contents strips, bundles and side tabs, so placeholders do not remain |
| Muddy colours from see-through cards over a picture | Make the cards opaque. Gold over blue turns olive |

**Backgrounds that compete with the content.** Do not fade the image, since transparency makes it stale. Bake a blur with `prepare_background.py` and upload the result. A blur of 5 at 1024 px wide kept the scene readable; 9 was too much. The tool's default raises saturation so it stays vivid. If they supplied a screenshot, crop its buttons and dark corners with `--crop`.

**Getting the source file.** Image ids return no usable thumbnail from the Roblox API, though decal ids do. Failing that, use the file the user pasted in the chat. Say so if the only copy is a low resolution screenshot.

**Decal ids.** A decal id does not load in an `Image` property. Find the image id with `game:GetObjects("rbxassetid://<decal>")[1].Texture`.

Report which images you changed and which placeholders remain, then let them steer. They will react to what they see, often in one line ("no stud on background, slightly less blurry"), so make that exact change and keep the rest.

**New animated parts** are driven by attributes, so they survive being edited in Studio: `Spin`, `Float`, `Wiggle`, `Beat`, `Glint`, `Turn`, `Slide`, and `Reveal` for the cascade. Use the kit's `sticker` for hero art and `rays` behind it.

## What to check before calling it done

Compare a capture against the rules, zoomed in on text. Check that each scroll section looks right, not just the top. In Play, confirm the window appears from a fresh start, tabs jump and follow scrolling including at the very bottom, hover and press keep the button's centre fixed, X closes it, and every rail square still opens its window. On quests, click Claim and Go, and look at each state, not just the default. Say plainly what was not tested, such as phone sizes.

Purchases, quest and index rewards, the items a player owns, and saved settings are not connected in the template. Use `MarketplaceService` for purchases, and keep quest progress and payouts on the server: the client only asks to claim, then shows the answer with `M.setQuest`.
