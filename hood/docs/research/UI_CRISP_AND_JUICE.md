# Crisp UI and juicy motion: research notes (Oct 27)

Why the owner sees "blurry, badly cut out" UI and "bad animations", and what top simulators do instead.
Sources: Roblox creator docs, DevForum threads, and the classic "juice" talks (listed at the end).
Numbers marked *(src)* come from a source. Unmarked numbers are common practice, our best estimate,
to tune by eye on a 30 fps video.

What we do today (grep of `hood/src`, Oct 27): 27 files use `TextScaled`, none set `ResampleMode`,
1 uses `ScaleType.Slice`, 35 use `UIStroke`, 25 use `UIScale`, and 10 use `ViewportFrame`. Our tweens are
mostly 0.12-0.45 s, with Back Out on pops. That's a good base, so the gaps are mostly the pictures and text,
not the timing.

---

## Part 1: causes of blur and rough cut-outs, with the fix for each

### Pictures (icons, art, badges)
- [ ] **The picture is smaller than its on-screen size, so it gets stretched up and goes soft.**
  Fix: make every picture at least as big as the largest size it is ever shown at, ideally 2x.
  Phone UI is scaled up on 1440p screens, so check the biggest screen, not your own.
- [ ] **The upload is bigger than 1024 px.** Any side over 1024 is shrunk to 1024 on upload *(src: DevForum,
  buildthomas)*, and the shrink is soft. Fix: export at exactly 1024 or less yourself, with a sharp downscale
  (Lanczos/bicubic in the art tool).
- [ ] **A huge picture is shown tiny** (1024 art in a 48 px slot), so edges shimmer or look grainy.
  Fix: keep the source within about 2-4x of the on-screen size. Upload a separate small version of each icon.
  Suggested sizes:

  | Use | Shown at (1080p) | Upload |
  |---|---|---|
  | HUD/button icon | 40-96 px | 256 px |
  | Shop card / reward art | 120-240 px | 512 px |
  | Big hero art, title logo | 300+ px | 1024 px |

- [ ] **The wrong ResampleMode.** `Default` smooths (right for our cartoon art). `Pixelated` keeps hard pixel
  edges and is only for pixel art *(src: ImageLabel docs)*. Fix: leave it on Default. Pixelated on smooth art
  gives jaggies.
- [ ] **A dark or white fringe (halo) around cut-out art.** Fully see-through pixels still carry a hidden colour.
  When Roblox smooths the edge it mixes that colour in, giving a black or white rim *(src: DevForum "white
  outline", PixelFix thread)*. The ImageLabel docs say see-through pixels "are black after upload", so use alpha
  blending to avoid dark outlines. Fix, in order:
  1. Run an **alpha bleed** before upload: fill the colour of see-through pixels from their neighbours, about
     4 px, without changing what you see *(src: PixelFix)*.
  2. Bake a solid **dark outline** (3-6 px at 512) into the art. The soft edge then mixes dark into dark and
     reads clean. This is also the +1/simulator house style.
  3. Never upload "remove background" output as is. It leaves half-see-through pixels of the old background
     colour around the edge.
- [ ] **Rough, jaggy cut-outs** (stair-steps, leftover specks). Fix: cut out at 2x or 4x, then shrink, which
  smooths the edge for free. Or ask Claude Design for a transparent PNG from the start, so there's nothing to cut.
  Check each icon on a light and a dark background at 100 % zoom before upload.
- [ ] **Stretched to the wrong shape** (`ScaleType.Stretch` on a box of another shape) looks squashed and soft.
  Fix: `ScaleType.Fit`, or a `UIAspectRatioConstraint` that matches the art. Our UIKit already uses Fit.
- [ ] **Rotated at rest.** A picture sitting at 7 degrees is resampled and goes slightly soft. Fix: rotate
  during motion only, and let it settle at 0 degrees. For a tilted "sticker" look, bake the tilt into the art.

### Panels and buttons
- [ ] **Panels and buttons drawn as one stretched picture** get blurry corners and borders that are thick on
  one side and thin on the other. Fix A, best: build them from native parts: Frame + `UICorner` + `UIStroke` +
  `UIGradient`, plus a second darker Frame offset 4-6 px down as the chunky "lip". These are drawn by the
  engine, so they stay sharp at every size.
- [ ] Fix B, when it must be a picture (a textured wood sign, say): **9-slice.** Set `ScaleType = Slice` and set
  `SliceCenter` to the stretchable middle. The corners keep their pixel size and only the edges and middle
  stretch *(src: 9-slice docs)*. Upload at 2x and set `SliceScale = 0.5`, so the corners are sharp on big
  screens. `SliceScale` grows the edges "as if a larger texture was uploaded" *(src)*.
- [ ] **UIStroke too thick on a phone and hair-thin on 1440p.** By default the thickness is in pixels.
  Fix: `StrokeSizingMode = ScaledSize`, which makes it relative to the box's shorter side, or to the font size
  on text *(src: StrokeSizingMode docs)*. Or set the pixels from the screen height (about 2 px at 720p,
  4 px at 1440p). Use `LineJoinMode = Round` for chunky corners.
- [ ] **Half-pixel edges.** A box with an odd pixel size and `AnchorPoint` 0.5 lands on half a pixel, so its
  1 px lines go soft. Fix: when using offsets, keep sizes even and positions whole. Size by Scale plus
  `UIAspectRatioConstraint`. Set `AnchorPoint` to the corner it hangs from: {0,1} for bottom-left, 0.5,0.5 for
  centred windows *(src: "UI Designing Tips")*.
- [ ] **Scaling a window by tweening `Size`** makes children re-lay out every frame and jitter. Fix: put a
  `UIScale` in the window and tween its `Scale`. DevForum users report it "works much better" *(src: Smooth UI
  Tweening)*. Text and native shapes are redrawn at the new size, not stretched.

### Text
- [ ] **TextScaled blur and uneven sizes.** Roblox staff acknowledged a TextScaled blur bug, and it was not fixed
  as of the thread *(src)*. TextScaled also makes neighbouring labels pick different sizes, which looks messy.
  Fix: use a fixed `TextSize` worked out from the screen height (one size table for the whole game: title, button,
  body, small), plus `UITextSizeConstraint` (min and max) where TextScaled must stay. Turning on `RichText` is
  reported to cure most of the blur *(src)*. **This is our biggest text item: 27 files use TextScaled.**
- [ ] **A thin or ragged outline on text.** The old `TextStrokeColor3` is a thin 1 px fringe. Fix: a `UIStroke`
  child on the TextLabel (Contextual mode), dark, thickness scaled to the font size, `LineJoinMode = Round`.
  Gradient fills go in a `UIGradient` on the label. Our `Shared/TextStyle` already does this. Make sure every
  label goes through it.
- [ ] **The font.** Montserrat Black/GothamBlack is right for big words. Keep small body text at a weight that
  stays readable (Bold, not Black), because Black closes up at small sizes. Wide Gotham hurts long text
  *(src: "UI Designing Tips")*.
- [ ] **Text on 3D boards** (SurfaceGui) is drawn as a picture, so it blurs with distance *(src)*. Fix:
  `PixelsPerStud` about 50-100 and big text. Use a `BillboardGui` for labels that must always read.

### Other ways things go soft
- [ ] **CanvasGroup** draws its children into a texture. Quality depends on the player's graphics level, it uses
  extra memory, it goes blank over the memory cap, and it rebuilds when resized *(src: docs)*. It pixelates on
  low settings *(src: forum)*. Fix: use it only briefly, for a fade, at a fixed size. Never wrap the whole HUD.
- [ ] **ViewportFrames as icons.** They draw no shadows and no post effects, use flat lighting, and render Neon
  and Glass at the lowest quality *(src: docs)*. Quality drops as the frame gets small *(src)*. Each one costs
  about a mini render, and about 50 hurt performance *(src: forum)*. Fix: for grids (shop, inventory), use
  **pre-rendered PNG icons** of our GLB models at 512, with a transparent background and an outline. Keep at most
  1-2 ViewportFrames, for a single big spinning preview.
- [ ] **Checking only in the preview renderer.** It can lie about fonts and edges. Fix: final crispness is judged
  in Studio's Device Emulator (phone, tablet, 1080p, 1440p) at 100 %.

### Touch and size floor (phones)
- Buttons at least about 44-48 px tall on a phone screen. The main HUD icon slot is about 8-10 % of the
  screen's short side.
- Leave 8-10 % see-through margin inside each icon picture, so outline and shadow aren't clipped.
- Respect `GuiService.PreferredTextSize`. `UITextSizeConstraint` overrides the player's text-size setting,
  so keep the minimum readable *(src: accessibility docs)*.

---

## Part 2: motion and juice

General rules (Juice It or Lose It / Art of Screenshake, applied to UI):
- **In = ease Out** (fast start, soft landing). **Out = ease In.** Exits take about 60 % of the entry time.
- **Overshoot is the "pop".** Roblox `Back` overshoots about 10 % (the standard Back curve), enough for windows
  and rewards. `Elastic` wobbles several times *(src: docs)*. Keep it for tiny things (a badge or a "+1"),
  never a whole window, where it looks cheap.
- **Linear only for endless spins** (sun rays). Everything else eases. DevForum advice: Quint Out for movement,
  Back for opening, 0.3-0.4 s *(src: Smooth UI Tweening)*.
- **Every motion gets a sound.** Rising pitch on repeats (coins) is half the juice.
- **Stagger groups** by 0.03-0.08 s, so lists cascade instead of popping at once.
- **Squash on impact:** 1.15 x 0.9, back to 1 in 0.15 s, when a counter or icon is "hit" by something arriving.
- **Reduced motion:** when `GuiService.ReducedMotionEnabled` is on, set tween times to 0 or use fades only
  *(src: accessibility docs)*. We already check it in 10 files. Keep doing so in every new motion.

| Motion | What moves | Time (s) | Easing | Notes / numbers |
|---|---|---|---|---|
| **Window open** | UIScale 0.85 -> 1, backdrop dim 0 -> 0.4 | 0.25-0.32 (dim 0.2) | Back Out (dim Quad Out) | Start at 0.85-0.9, never 0 (from 0 looks like a cheap zoom). Stagger the window's content (title, then cards) by 0.04. |
| **Window close** | UIScale 1 -> 0.9, fade | 0.15-0.18 | Quad In (or Back In) | Faster than open. Input is off once closing starts. |
| **Button hover** (PC) | UIScale 1 -> 1.05-1.08, stroke a little brighter | 0.10-0.15 | Quad/Sine Out | Return the same way. Styling Transitions can do this declaratively; their example default is 0.25 *(src)*. |
| **Button press** | UIScale -> 0.92, lip shrinks 4 -> 1 px (moves down) | 0.06-0.08 | Quad Out | Feels like a physical key. |
| **Button release** | UIScale -> 1 (or the hover size) | 0.18-0.25 | Back Out | The bounce-back is where it feels good. Click sound on release. |
| **Number count-up** (Cash, Power) | The value | 0.4-0.8 (scales with the size of the jump, capped) | Quart/Quad Out | Fast then settles. Our big-number format each frame. NumberSpinner defaults: 0.5 s, Quad Out, bounce 1.08 *(src)*. |
| **Counter bump** | UIScale 1 -> 1.12 -> 1 | 0.06 up, 0.18 down | Quad Out, then Back Out | On each gain; if it's already bumping, restart rather than stacking. |
| **"+N" floater** | Rises 40-60 px, fades | 0.6-0.8 | Quad Out (fade in the last 40 %) | Starts at scale 0.6 -> 1.1 -> 1 in the first 0.15. Random sideways spread of ±15 px. |
| **Currency flies to counter** | 6-12 small icons | Burst 0.15-0.25, then flight 0.45-0.7 | Burst Quad Out, flight Sine/Quad In along a curve | Burst out 30-80 px at random angles, then curve to the counter (one bezier control point to the side). Stagger 0.03-0.05. Each landing gives a counter bump plus a tick sound with pitch rising 3-5 % each. The count-up starts at the first landing. |
| **Reward popup** | Card UIScale 0.5 -> 1, rotation -8 -> 0 degrees | 0.35-0.45 | Back Out | Hold 1.2-1.8 s (or until tapped), exit 0.2-0.25 Quad In upward with a fade. Rays behind spin Linear, 8-12 s per turn. |
| **Notification toast** | Slides in from the top/side, about 110 % of its height | 0.25-0.3 in, 0.2 out | Back Out in (or Quint Out), Quad In out | Hold 2.5-3.5 s. At most 3 stacked; others shift 0.2 Quad Out. No toast for routine things. |
| **Idle on shop items** | Bob ±3-4 px or tilt ±3 degrees | 1.2-2.0 per half-cycle, repeat reversed | Sine InOut | Offset each item's phase so they don't move in sync. Only the "buy this next" item gets extra. |
| **Shine sweep** (best item) | UIGradient Offset -1 -> 1 | 0.6 sweep, every 3-4 s | Quad InOut | A gloss, not a flash: no brightness jump, at most one sweep per 3 s. |
| **Purchase celebration** | Item 0 -> 1.15 -> 1, confetti, rays, sound | Pop 0.35, all over within about 1.5 | Back Out | One soft white wash allowed: transparency 0.6 -> 1 over 0.3 s, at most once per second. No screen shake on UI. |
| **Rebirth / level up** | Big title UIScale 1.6 -> 1, fade in | 0.4 | Back Out | Then a reward popup. Hold about 1.5 s. Player can tap to skip. |
| **Unbox / hatch reveal** | Shake (±4 to ±8 degrees, rising), squeeze, pop, reveal | Shake 1.0-1.5, pop 0.2, reveal 0.4 | Shake Sine, reveal Back Out | Rarity colour in the background, no strobe. "Skip" and "fast open" offered. The odds and pity counter stay on screen (see below). |
| **Locked / can't afford** | Horizontal shake ±6 px, 3 cycles | 0.25 total | Sine | Plus a soft "nope" sound. Never red flashing. |
| **Tab switch** | New page slides 20-30 px plus fade | 0.18-0.22 | Quint Out | Old page just disappears (or fades 0.1). |

### Per game: what's worth taking (style, not one to one)
- **+1 Soldier Evolution / +1 series:** chunky dark-outlined text, a big "+N" floater on every gain, bars and
  counters that bump. Simple and constant, never cluttered. Our closest model.
- **Pet Simulator 99:** native-looking rounded panels with thick outlines and gradients, coins that physically
  fly to the counter, and very fast egg opening with a skip option.
  **Don't copy:** its limited-time pressure and countdown events, and any "only X left" stock.
- **Arm Wrestle / Muscle Legends:** the stat number is the hero. Big count-up plus bump on every rep, and a
  bounce on the strength bar.
  **Don't copy:** pop-ups pushing a pass in the middle of play.
- **Bee Swarm Simulator:** calm, clean menus. Juice is saved for collection moments, which keeps it special.
- **Anime simulators:** big rarity reveals with rays and colour.
  **Don't copy:** strobe or rapid rainbow flashing on high rarities (breaks our 1 flash per second rule),
  "near-miss" reveals that pretend you almost got the top item, and hiding the odds.

### Kid-safe checklist for every motion
- [ ] At most 1 flash per second. A flash means a sudden brightness jump over a large area. Sweeps and colour
  fades are fine.
- [ ] No countdowns, "ends soon", "only N left" or fake stock, unless they're real and the same for everyone.
- [ ] Paid random items: odds and the pity counter are shown before and during the open. The reveal never
  fakes a near-miss.
- [ ] Reduced motion respected; every celebration can be tapped away.

---

## Sources
- ImageLabel (ResampleMode, ScaleType, SliceCenter, SliceScale): https://create.roblox.com/docs/reference/engine/classes/ImageLabel
- 9-slice design: https://create.roblox.com/docs/ui/9-slice
- UIStroke / StrokeSizingMode: https://create.roblox.com/docs/reference/engine/classes/UIStroke , https://create.roblox.com/docs/reference/engine/enums/StrokeSizingMode
- CanvasGroup: https://create.roblox.com/docs/reference/engine/classes/CanvasGroup
- ViewportFrame: https://create.roblox.com/docs/reference/engine/classes/ViewportFrame
- UI animation: https://create.roblox.com/docs/ui/animation
- Accessibility (reduced motion, text size): https://create.roblox.com/docs/production/publishing/accessibility
- 1024 upload limit: https://devforum.roblox.com/t/tutorial-optimizing-textures-and-images/185497
- Edge halos: https://devforum.roblox.com/t/weird-white-outline-on-imageguis/26001 , https://devforum.roblox.com/t/automated-pixelfix-for-ui-run-and-forget/4812286
- TextScaled blur: https://devforum.roblox.com/t/text-is-blurry-when-textscaled-is-set-to-true/3050136
- Layout tips: https://devforum.roblox.com/t/ui-designing-tips/2423307
- Tween timings: https://devforum.roblox.com/t/smooth-ui-tweening/994529 , https://devforum.roblox.com/t/full-release-styling-transitions/4646870
- Number spinner defaults: https://devforum.roblox.com/t/numberspinnerv2-a-modern-animated-number-and-text-spinner-module/4748302
- ViewportFrame cost and quality: https://devforum.roblox.com/t/how-much-do-viewport-frames-affect-performance/376225 , https://devforum.roblox.com/t/quality-of-viewports/3176350
- Juice talks (summary): https://rpgplayground.com/research-making-a-juicy-game/
