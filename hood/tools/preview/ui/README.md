# UI preview: pictures of the game's windows, offline

Draws our real windows (built by the real client scripts) at 1280x720, without Studio.

```
LUNE=<path to lune> sh hood/tools/preview/ui/shoot.sh [out dir]          # default out dir: hood/tools/preview/ui/out
python3 -I hood/tools/preview/ui/compose.py <mockup.png> <out.jpg> shop.png rebirth.png shoes.png worlds.png
```

Chromium comes with Playwright (`npm install playwright` if `require('playwright')` fails; the session machines
have it under `/opt/node22/lib/node_modules`). A slot in `compose.py` can be `note:line 1|line 2` instead of a PNG.

## How it works
1. **shoot.sh** joins a scenario and runs it in the Lune harness (`tools/checks/harness_live.luau`):
   `dump.luau` + `prelude.luau` + `tools/checks/feel_base.luau`'s set-up (the screen changed to 1280x720) + `windows.luau`.
2. **prelude.luau** makes every icon count as loaded, so windows keep their pictures instead of the flat stand-ins.
3. **windows.luau** gives the player some progress and a rack of shoes, then opens each window the way the game does:
   the Store's `Open`, the HUD's Rebirth square, the inventory's `Open('Shoes')` (drawn in the `HoodArt` gui), the World
   window's `Open`. It dumps each ScreenGui to `<out>/<name>.json` once the open motion has finished.
4. **dump.luau** (`__uiDump(gui, path)`) writes each GuiObject's class, Position / Size, AnchorPoint, ZIndex, Visible,
   background, LayoutOrder, Rotation, clipping, AutomaticSize, text (string, colour, size, scaled, wrap, rich, alignment,
   stroke, font), image (`PreviewImage` attribute, colour, transparency, scale type) and its modifiers: UICorner,
   UIStroke (with its gradient), UIGradient, UIPadding, UIListLayout, UIGridLayout, UIAspectRatioConstraint, UIScale,
   UISizeConstraint, UITextSizeConstraint.
5. **index.html** lays the tree out with CSS:
   - positions and sizes as `calc(scale * 100% + offset px)`, AnchorPoint as a translate;
   - ZIndex as z-index (Sibling behaviour);
   - UIListLayout as flex, UIGridLayout as grid, UIPadding as an inset box;
   - UIStroke on a frame as a ring outside the box, on text as a ring of text shadows;
   - UIGradient as a linear gradient times the colour (`background-clip: text` on text);
   - Montserrat (Heavy = 900) for the game's fonts, and `RbxIcon.ttf` for the Robux sign (U+E002); both are from `../render14/fonts`;
   - icons from `hood/art/icons3d/<id>.png` (`icon3d:` attributes) and stud tiles from `hood/art/ui/<file>.png` (`ui:` attributes);
   - behind the window, a plain, dimmed "sky, buildings, green floor" backdrop (`--no-bg` for black).
6. **shoot.js** screenshots each JSON to a PNG in Chromium and prints what it could not draw.

## What it can't draw (it is a sketch of the layout, not Roblox)
- **Blur** behind open windows (Lighting BlurEffect) and anything in the 3D world: the backdrop is a flat stand-in.
- **ViewportFrames** (3D models in the UI): drawn as an empty dashed box. The shop's bundle art uses some.
- **Images without a local PNG** (uploaded decals with no `PreviewImage` attribute): left out; shoot.js lists them.
- **Gradients on a UIStroke**: drawn in their first colour. Gradient Offset is ignored.
- **Text**: Roblox's own line breaking, line height and glyph metrics differ a little. The text stroke is a ring of
  shadows, so its corners are rounder than Roblox's. Rich text keeps only `font color`, `b`, `i` and `br`.
- **UICorner in Scale**: measured once after layout; **AutomaticSize** is approximate (min size plus content).
- **Vertical UIGridLayout** fills row by row.
- **Motion**: only the state after the open animation. Tweens, pulses and particles need Studio or a video.
- **Phone sizes**: only 1280x720. To check a phone, change the four sizes in `shoot.sh`, the same way.

## The owner's pictures (round 3, Oct 27)
- The windows wear pieces cut from the owner's mockup (`hood/tools/ui/cut_mockup.py` -> `hood/art/ui_owner/`) and
  every item shows its real rendered picture (`hood/tools/ui/render_items.sh` -> `hood/art/icons3d/`). Both are packed
  into Luau (`hood/tools/ui/pack_images.py` -> `Shared/Images/`) and drawn in game by `Shared/ImageLoader`
  (EditableImage: no upload needed).
- `prelude.luau` makes the loader count every packed picture as drawn; `dump.luau` writes which ones show (`packed`)
  and their 9-slice; `index.html` draws them from the PNGs (9-slice as a CSS border-image, tiles as a repeat).
- Only Studio shows whether Roblox actually draws them: Game Settings > Security > "Allow Mesh / Image APIs" must be on
  (the place published), and the picture memory budget holds. Without them the windows fall back to their drawn look
  and Output prints one `[HoodUI]` line naming the fix.

## Motion: the Shop as a video (Oct 27)
- `SCENE=shopvideo sh shoot.sh <out>` opens the Shop and dumps it every 1/30 s of game time (210 frames, 7 s; a
  hover and a press on the Featured price half way), draws each frame, then in <out>:
  `ffmpeg -framerate 30 -i f_%03d.png -c:v libx264 -pix_fmt yuv420p shop.mp4`. It shows the pop-in, the stagger,
  the icons' idle motion, the shine sweeps, the sparkles and the green buttons' glow (all on `Shared/UIIdle`). Not drawn:
  a UIGradient's Offset (the HUD offers' shine, `UIMotion.shine`), the 3D views.

## Phones, the HUD, the fallback and closing (Oct 27, release fixes)
- `SCENE=hud SW=844 SH=390 NOTCH=47 TOUCH=1 sh shoot.sh <out>` draws the HUD alone on a phone screen (`hud.luau`) and
  prints what overlaps or runs off the screen (`hud.layout.json`: each screen's top-level blocks, as the box around
  their painted parts). The harness doesn't run Extras' fills of the right column, so those three slots are drawn as
  magenta stand-ins of their size. Roblox's own thumbstick and jump button aren't drawn.
- `FALLBACK=1` makes Roblox refuse every packed picture (as without "Allow Mesh / Image APIs"): the windows must show
  their old drawn look, and Output one `[HoodUI]` line.
- `windows.luau` presses each window's real X after its picture and prints `[ui] <name> open: N painted / closed by
  its X: ok` (or what is still shown).
