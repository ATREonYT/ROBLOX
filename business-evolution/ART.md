# +1 Business Evolution — Art Bible & Polish Spec

> **How to use this.** Save it into the project folder as `ART.md` alongside `CLAUDE.md`, then paste the WORK ORDER at the bottom into Claude Code. Like `CLAUDE.md`, it stays in context for the whole polish pass instead of scrolling away. Attach your screenshots and the reference shots with the work order.
>
> Every number here was checked against Roblox docs and DevForum as of August 2026. Values marked as starting points are tunable; values quoted from docs are not guesses.

---

# PART 0 — WHY THE LAST PASS WASN'T ENOUGH

The previous visual pass fixed camera, scale and signage. The game still reads as machine-made, and there is a single reason for it:

> **The meta-tell is uniformity.** AI-assembled and beginner work is statistically flat — the same spacing, the same object scale, the same colour saturation, the same tween duration, the same prop density everywhere. Studio work is deliberately **non-uniform at every level**: one hero light, one oversized landmark, one 0.55s Elastic tween in a sea of 0.2s Quad ones, one saturated accent against a desaturated field.

Everything in this document exists to break uniformity in a controlled way. **If you apply a rule from here evenly across every object, you have failed the rule.**

Concretely, build a variance pass into every repeated element: **rotation ±15°, scale ±8%, hue ±4%, position jitter**, unless there's a specific reason not to. A row of eight identical training bags at exact 12-stud intervals all facing due north is the tell. Eight bags at 10–14 stud intervals, rotated 4–19°, scaled 0.94–1.07, is a game.

---

# PART 1 — 2026 PLATFORM FACTS (these invalidate most tutorials you'll find)

Do not follow pre-2025 tutorials on these points. Verify against current docs if anything here looks wrong.

| Change | What's true now | Since |
|---|---|---|
| **`Lighting.Technology` is GONE** | Replaced by `Lighting.LightingStyle` (`Realistic` \| `Soft`) plus `Lighting.PrioritizeLightingQuality` (bool). Legacy mapping: `Future` → Realistic + true, `ShadowMap` → Soft + true, `Voxel` → Soft + false. **Neither is scriptable** — set them in the Properties panel and commit the place file. | live |
| **`UIShadow` exists** | Real drop shadows. No more 9-slice shadow hacks. | full release 2026-06-23 |
| **`UICorner` has per-corner radii** | `TopLeftRadius`, `TopRightRadius`, `BottomLeftRadius`, `BottomRightRadius`. `CornerRadius` is now an alias. | full 2026-06-23 |
| **UIStroke overhaul** | `StrokeSizingMode` (`FixedSize` \| `ScaledSize`), `BorderStrokePosition`, `BorderOffset`, **multiple strokes per object**. | full 2025-12-04 |
| **Highlight cap raised** | 31 → **255** active Highlights. Disabled ones still count. | 2025-11-10 |
| **Legacy `Sound`/`SoundGroup` are "discouraged"** | New graph is `AudioPlayer` → `Wire` → `AudioEmitter` → `AudioListener` → `AudioDeviceOutput`. Legacy still works and is still what most shipped games use. **Use legacy for this project** — the new graph costs 6 instances per 3D sound. | ongoing |

---

# PART 2 — THE AUDIT

This is the most important section. **Before you write any code, walk this list against the current game and report which items we fail.** Then fix them. Then walk it again at the end. Every item is a binary pass/fail.

### Lighting & world
1. `Lighting` left at defaults — `Brightness 1`, `Ambient (70,70,70)`, `ClockTime 14`, no Atmosphere, no post-processing. **The single loudest tell.**
2. Flat lighting — no `ColorShift_Top`/`ColorShift_Bottom`, so lit and shadowed faces are the same hue. Real art always has warm light and cool shadow.
3. `GlobalShadows` off, so nothing sits on the ground.
4. No `Atmosphere` — hard horizon line, no depth cue.
5. Zero local lights. A world lit only by the sun has no focal points.
6. Default skybox.

### Materials & geometry
7. Everything `SmoothPlastic`/`Plastic` at default BrickColor palette values.
8. **Pure `#000000` or `#FFFFFF` anywhere** — parts, text, or strokes. Real art uses `(18,16,28)` and `(250,248,255)`.
9. Uniform object scale — every crate 4×4×4, every prop the same height.
10. Evenly-spaced grid layouts at exact intervals, all axis-aligned, zero rotation.
11. No negative-space variation — uniform prop density instead of a dense/sparse rhythm.
12. Everything axis-aligned at 0/90/180/270°.
13. No trim or edge detail — walls meeting floors with no baseboard, chamfer, or seam part.
14. Mesh soup with no consistent direction between assets.
15. No outlines on a cartoon-styled game — without the outline pass, low-poly reads as unfinished rather than stylised.

### UI
16. Default fonts (`SourceSans`, `Legacy`, plain `Gotham` untreated).
17. Three or more fonts in one interface.
18. No `UIPadding` anywhere — text touching frame edges.
19. No `UICorner` at all, **or** the same radius on everything including the progress bar.
20. Inconsistent corner radii across sibling elements.
21. `TextScaled` on some labels and fixed `TextSize` on their siblings.
22. No `UIStroke` on text over busy backgrounds.
23. Flat single-colour panels with no `UIGradient` depth.
24. No shadows — everything floats on one plane with no z-hierarchy.
25. Offset-only sizing — 4× too big on phones, tiny on 1440p.
26. UI under the topbar or in the notch (`ScreenInsets` left at `None`, or a hardcoded 36px inset).
27. Buttons with no hover, no press, no sound.
28. Mismatched `TextXAlignment` and layout intent.
29. Icons from three different icon sets in one panel.

### Feedback & motion
30. No feedback on any action — click, number changes, nothing else happens.
31. Instant state changes — panels appearing via `Visible = true` instead of animating.
32. `Linear` everywhere, or `Bounce` everywhere.
33. The same tween duration for everything (usually 0.5s or 1.0s) — no rhythm.
34. No particles on rewards, or one generic sparkle reused for every event.
35. No sound, or one click sound with no pitch variation firing 200×/minute.
36. No camera response to anything.
37. **Static world** — nothing idles, bobs, rotates or pulses.
38. No idle animation on held items or Interns.

### Content & structure
39. Perfectly regular progression numbers (Zone 1: 100, Zone 2: 200, Zone 3: 300).
40. Placeholder naming — "Zone 4", "Item C".
41. Every zone the same layout with a different colour tint.
42. A leaderstats-only HUD with no custom currency chips.
43. Perfectly symmetrical map with no landmark asymmetry to navigate by.

---

# PART 3 — LIGHTING & ATMOSPHERE

Set every property explicitly. Do not rely on Studio's baseplate defaults, which differ from the class defaults.

```lua
local L = game:GetService("Lighting")
L.Ambient                  = Color3.fromRGB(120, 118, 130)  -- high floor = cartoon, not realistic
L.OutdoorAmbient           = Color3.fromRGB(150, 160, 185)  -- cool sky bounce
L.Brightness               = 2.6
L.ExposureCompensation     = 0.15
L.ColorShift_Top           = Color3.fromRGB(255, 236, 200)  -- warm sun
L.ColorShift_Bottom        = Color3.fromRGB(120, 140, 175)  -- cool shadow
L.EnvironmentDiffuseScale  = 0.55
L.EnvironmentSpecularScale = 0.25
L.GlobalShadows            = true
L.ShadowSoftness           = 0.35
L.ClockTime                = 15.2   -- 14.5–15.5 gives a ~45° sun with readable form
L.GeographicLatitude       = 12     -- low latitude = higher sun, shorter shadows
L.FogEnd                   = 100000 -- use Atmosphere, never legacy Fog
```

**Set in the Properties panel (not scriptable):** `LightingStyle = Soft`, `PrioritizeLightingQuality = false`.
`Soft` is documented as *"the best option for achieving the classic Roblox look"* and is the cheapest. We're mobile-majority. `PrioritizeLightingQuality = false` degrades lighting before draw distance, which is right for a game where players need to see distant zones.

**The three levers that separate cartoon from realistic:** high `Ambient` (110–140) is the biggest by far; `Brightness` 2.4–3.0 with `ExposureCompensation` +0.1 to +0.25; and `ClockTime` 14.5–15.5. Never `ClockTime = 12` (overhead sun kills all form), never below 8 or above 18 (raking shadows read as cinematic realism).

**Atmosphere:**
```lua
A.Density = 0.28   -- 0.25–0.35; above 0.5 fogs out your zones
A.Offset  = 0.25
A.Color   = Color3.fromRGB(210, 226, 255)
A.Decay   = Color3.fromRGB(150, 175, 215)
A.Glare   = 0.15   -- needs Haze > 0 to show
A.Haze    = 0.9
```

**Post-processing** (global effects in `Lighting`, per-player effects in `workspace.CurrentCamera`):
```lua
Bloom.Intensity = 0.85    -- 0.6–1.0 candy look; >1.2 smears
Bloom.Size      = 32
Bloom.Threshold = 0.90    -- below 0.8 the whole screen glows

CC.Saturation   = 0.22    -- 0.15–0.35 sweet spot
CC.Contrast     = 0.10
CC.Brightness   = 0.02
CC.TintColor    = Color3.fromRGB(255, 250, 244)

Sun.Intensity   = 0.12    -- keep low, this isn't a god-ray game
Sun.Spread      = 0.85
```
**Disable `DepthOfFieldEffect` during gameplay.** Menus only.

**Local lights — this is where focal points come from.** A world lit only by the sun is tell #5. Put a `PointLight` on every gold-tier and above object, every neon platform, every shop counter. Budget in Part 12.

---

# PART 4 — THE WORLD

## 4.1 Footprint (from the previous pass, restated as law)

| | Target |
|---|---|
| Starting-area footprint | **~80 × 80 studs**, hard cap 100 × 100 |
| Spawn → furthest interactive object | under 40 studs |
| Walk time across the zone | under 10 seconds |
| Interactive things visible from spawn | at least 6 |
| Path width | 8–12 studs |
| Visible bare ground | close to none |

**Shrink the ground, not the props.** Big props in a small space is the mechanism. Props stay at current size or larger.

## 4.2 Scale variance — the anti-uniformity rule

The docs' own environment-art guidance: build something **much larger than the player** to give a sense of scale. Our world currently has no size hierarchy at all.

Establish four tiers and use all four in every zone:

| Tier | Height | Examples | Count per zone |
|---|---|---|---|
| **Landmark** | 40–80 studs | The tower's central atrium column, a giant hanging corporate logo, an enormous stock ticker | **exactly 1** |
| **Hero** | 12–20 studs | The rank-up podium, the Coffee Machine, the zone portal | 2–4 |
| **Standard** | 5–10 studs | Training bags, desks, shop counters, leaderboard pillars | 8–15 |
| **Detail** | 0.5–3 studs | Mugs, staplers, paper stacks, plants, cables, sticky notes | 40+ |

**The Landmark is non-negotiable.** One object so large the player orients by it. Without it every zone feels the same size and the map is unnavigable by memory — that's tell #43.

## 4.3 Placement variance

For every repeated element:
```lua
local function jitter(cf)
    return cf
        * CFrame.new(math.random(-8,8)/10, 0, math.random(-8,8)/10)
        * CFrame.Angles(0, math.rad(math.random(-15,15)), 0)
end
local scale = 0.92 + math.random() * 0.16   -- ±8%
local hueShift = (math.random() - 0.5) * 0.08  -- ±4%
```
Density should have **rhythm**: a dense cluster of props, then breathing room, then another cluster. Not an even scatter.

## 4.4 Trim and edge detail

Tell #13. Every wall-to-floor junction gets a baseboard part. Every platform edge gets a chamfer strip in a contrasting colour. Every doorway gets a frame. This is maybe 30 minutes of work and it's the difference between "blocks placed in a room" and "a built environment."

## 4.5 Set dressing library (corporate theme)

Build these once as reusable models, then scatter with variance:
water cooler · potted plant (3 sizes) · stacked paper trays · desk lamp · coffee mug · filing cabinet · rolling office chair · whiteboard with scribbles · noticeboard with pinned notes · vending machine · fire extinguisher · ceiling cable run · floor cable cover · recycling bin · wall clock · framed motivational poster · cardboard box stack · pallet · trolley · photocopier

**Vary the tier per floor.** The Mailroom gets dented filing cabinets and a dying plant; the Penthouse gets a marble plinth and an orchid. Same object class, different fidelity — that's how zones read as different places rather than recoloured copies (tell #41).

---

# PART 5 — MATERIALS, GEOMETRY, COLOUR

## 5.1 Never use pure black or pure white

Tell #8, and it applies everywhere — part colours, text, strokes, UI backgrounds.

```lua
INK       = Color3.fromRGB( 22,  18,  40)  -- outlines, text strokes, "black"
INK_SOFT  = Color3.fromRGB( 46,  40,  72)
PAPER     = Color3.fromRGB(250, 248, 255)  -- "white"
```

## 5.2 Semantic colour system

Colour must mean something consistently. Define once in `Shared/Config/Palette.luau` and never pick a colour outside it.

| Meaning | Colour | Used for |
|---|---|---|
| Unlocked / affordable / go | `(86, 214, 108)` | Unlocked labels, affordable prices, confirm buttons |
| Locked / premium / stop | `(232, 74, 74)` | Locked labels, Robux items, cancel |
| Value / currency | `(255, 200, 52)` | Wins, coins, gold tier |
| Productivity | `(96, 190, 255)` | The click stat, everything tied to it |
| Rare / special | `(178, 106, 255)` | High-tier gear, the Consultant, rare Interns |
| Neutral surface | `(58, 62, 84)` | Panel backgrounds |

## 5.3 Rarity ladder (applies to gear, Interns, tiers — one system, used everywhere)

| Rarity | Colour | Treatment |
|---|---|---|
| Common | `(168, 178, 196)` | flat, no effects |
| Uncommon | `(86, 214, 108)` | subtle `UIGradient` |
| Rare | `(96, 190, 255)` | gradient + faint sparkle |
| Epic | `(178, 106, 255)` | gradient + sparkle + `PointLight` |
| Legendary | `(255, 200, 52)` | gold gradient + sparkle + light + `Highlight` outline + idle rotation |

## 5.4 The studded look

The reference world's signature is large chunky blocks with a tiled inset-square pattern. Use a `MaterialVariant` or `Texture` objects with `StudsPerTileU/V` around 4. **Pick one approach and apply it to every large surface** — mixing techniques is tell #14.

Critical for performance: instancing collapses identical meshes into one draw call **only if `MeshContent` matches and `SurfaceAppearance`s are identical**. Duplicate uploads of the same mesh break batching. Use Packages. Reuse one texture tinted via `SurfaceAppearance.Color` rather than uploading recoloured variants.

## 5.5 Toon outlines

Tell #15. Cartoon geometry without an outline pass reads as unfinished. Apply `Highlight` with `FillTransparency = 1`, `OutlineTransparency = 0`, `OutlineColor = INK`, `DepthMode = AlwaysOnTop` for hero objects only — the mobile budget is ≤6 visible Highlights, and the first visible one costs up to 1ms of GPU on mobile. For everything else, get the outline from geometry: a slightly larger, inverted, dark shell part, or a dark chamfer strip along edges.

---

# PART 6 — THE COMPONENT LIBRARY

Build each of these **once**, as a data-driven module in `ReplicatedStorage/Shared/UI/` or `Client/Controllers/`. Adding an instance of any of them must be a config edit. Thirty hand-placed BillboardGuis is a failure.

## 6.1 `Sign` — the workhorse

Five variants, one module. Signature: `Sign.create(adornee, config)`.

```lua
-- config shape
{
  variant   = "Multiplier" | "Price" | "State" | "Zone" | "Hype",
  lines     = { {text = "x350 POWER", color = GOLD, weight = "display", size = 1.0},
                {text = "INSANE DEAL", color = RED,  weight = "display", size = 0.7} },
  studsOffset = Vector3.new(0, 6, 0),
  maxDistance = 120,
  pulse       = true,   -- idle scale breathing
  gradient    = "gold" | "rainbow" | nil,
}
```

**Every line of text gets a `UIStroke`.** This is the genre's actual signature:
```lua
local s = Instance.new("UIStroke")
s.ApplyStrokeMode  = Enum.ApplyStrokeMode.Contextual
s.LineJoinMode     = Enum.LineJoinMode.Round
s.Color            = INK                      -- never pure black
s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
s.Thickness        = 0.14                     -- 0.10 subtle, 0.18 very chunky
s.Parent           = label
```
`ScaledSize` makes thickness a fraction of font size, which is the correct answer to "too thin on 4K, too fat on phones." **Do not tween `Thickness`** — the docs warn about flicker and performance. Tween `Transparency` or a child `UIGradient`'s `Offset` instead.

**Gold gradient** (for premium/legendary signage). Note `Rotation = 90` — vertical reads as metal, horizontal reads as a shine sweep:
```lua
gold.Rotation = 90
gold.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 244, 186)),
  ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 205,  62)),
  ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 170,  20)),  -- the "metal line"
  ColorSequenceKeypoint.new(0.58, Color3.fromRGB(233, 138,  12)),
  ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 226, 140)),
}
```
Hard limit: **20 keypoints max** on any ColorSequence/NumberSequence. If you parent a `UIGradient` to a `UIStroke`, set `UIStroke.Color = Color3.new(1,1,1)` or the gradient gets multiplied down.

**Extruded "sticker" title** for zone names and rank-up text — this is what makes headline text look designed rather than typed. Build a container `Frame`, then N identical `TextLabel`s all at `Size = UDim2.fromScale(1,1)`, `TextScaled = true`:
```lua
local EXTRUDE_DEPTH = 6                    -- px at design scale
local EXTRUDE_DIR   = Vector2.new(0, 1)    -- straight down
local FACE_COLOR    = Color3.fromRGB(255, 214,  74)
local SIDE_COLOR    = Color3.fromRGB(186, 118,  16)

for i = EXTRUDE_DEPTH, 1, -1 do            -- back to front
    local side = template:Clone()
    side.TextColor3 = SIDE_COLOR
    side.Position   = UDim2.fromOffset(EXTRUDE_DIR.X * i, EXTRUDE_DIR.Y * i)
    side.ZIndex     = 10 - i
    outlineText(side, 4, INK)              -- every layer keeps its outline
    side.Parent     = container
end
-- then the face layer on top at ZIndex 10
```

**BillboardGui config:** `LightInfluence = 0` (signs must not dim in shadow), `MaxDistance` 90 on mobile / 140+ on desktop, `AlwaysOnTop` only for critical state text. Budget: **≤25 visible BillboardGuis on mobile.** Pool them and toggle `Enabled` by distance.

## 6.2 `Pad` — the platform under every interactive object

Reference shows every training bag, egg and shop item standing on a raised, coloured, glowing platform. That platform is doing enormous work: it groups, it colour-codes, it gives the object a base, and it catches the eye.

Spec: a rounded slab 6–10 studs across, top surface tinted to the object's rarity colour, a chamfer strip in `INK` around the edge, a `PointLight` above it for Epic+, a slow-pulsing `Beam` ring for Legendary, and a subtle idle bob on the object above it.

## 6.3 `TierLadder` — the progression display

Training bags are a data-driven ladder, not eight placed objects:
```lua
TIERS = {
  {mult =    1, name = "Intern Bag",     material = "Wood",   rarity = "Common",    fx = "none"},
  {mult =   10, name = "Analyst Bag",    material = "Metal",  rarity = "Uncommon",  fx = "sparkle"},
  {mult =   50, name = "Manager Bag",    material = "Gold",   rarity = "Rare",      fx = "sparkle+light"},
  {mult =  250, name = "Director Bag",   material = "Neon",   rarity = "Epic",      fx = "column"},
  {mult = 1000, name = "Executive Bag",  material = "Void",   rarity = "Legendary", fx = "column+ring"},
  {mult = 5000, name = "Chairman's Bag", material = "Prism",  rarity = "Legendary", fx = "full"},
}
```
Each entry generates: the bag, its Pad, its Sign (multiplier + lock state), its particles, its light, its unlock check. **Adding tier 7 is one table row.**

## 6.4 `DisplayPodium`

Rotating platform showing an unearned reward — the next three ranks above the player's current one. Slow Y rotation (one revolution per 8s, `Linear`), the actual outfit, the rank name in extruded text, the requirement below it, and a `Highlight` outline. This is the single best retention object in the genre: it shows people what they're working toward.

## 6.5 `LeaderboardPillar`

Three tall pillars: TOP 100 PRODUCTIVITY, TOP 100 RESTRUCTURES, TOP 100 WINS. `SurfaceGui` on a chunky pillar with an extruded title cap. **Use a separate `OrderedDataStore`** — ProfileStore's own docs state it is not designed for global leaderboards.

## 6.6 `Chip` — the HUD currency pill

Rounded pill (`UICorner` `UDim.new(0.5, 0)`), icon on the left, tabular number on the right, `UIStroke` on the text, `UIShadow` beneath, and a scale punch + colour flash when the value changes.

---

# PART 7 — THE JUICE STACK

Tell #30 is "no feedback on any action" and it is the difference between a prototype and a product. **A professional interaction is never one thing — it's four to six things firing together on a tuned timeline.**

Below, `t=` is milliseconds from input. Every one of these must fire **client-side immediately on input**, before any network round-trip. Predict locally, reconcile when the server replies.

## 7.1 Click a training bag (fires hundreds of times per session — keep it tight)

```
t=0     sound: "tink" transient, Volume 0.3, PlaybackSpeed pitch-laddered (see 7.6)
t=0     bag squashes: UIScale-equivalent on the model, 0.94, TweenInfo(0.05, Quad, Out)
t=0     number popup spawns: "+1", random ±20px screen jitter
t=0     particle burst: :Emit(6) coin preset
t=60    bag springs back: TweenInfo(0.22, Back, Out)
t=0-150 popup: fade in 0.15s Linear → hold 0.25s → fade out 0.4s Quart. 0.8s total life.
```
Every 10th click is a **critical**: orange text, 1.4× size, distinct sound, `:Emit(14)`, camera `ShakeOnce(0.35, 12, 0, 0.18)`.

## 7.2 Purchase

```
t=0     button press: UIScale 0.94, TweenInfo(0.05, Quad, Out)
t=0     UIShadow collapses: BlurRadius 12→4, Offset (0,6)→(0,2)   ← this sells the press
t=0     sound layer 1: click, Volume 0.4
t=80    button release pop: UIScale 1.0, TweenInfo(0.22, Back, Out)
t=80    sound layer 2: coin chime, ascending 2-note, Volume 0.55
t=80    particle: purchase-confirm puff, :Emit(12)
t=140   sound layer 3: shimmer tail, Volume 0.25
t=80    currency chip: scale punch 1.18 (0.14s Back Out, reverses) + count-up tween
        on the number over 0.6s Quart Out
```

## 7.3 Rival defeated

```
t=0     impact sound + hit-stop: set emitter.TimeScale = 0.15 for 80ms
t=0     camera ShakeOnce(1.2, 8, 0, 0.5)
t=0     FOV punch +3, in 0.06s Quad, out 0.22s Quint
t=0     rival ragdolls into a swivel chair and rolls offscreen
t=0     4-layer particle burst (ring + flash + sparks + smoke — see Part 8)
t=120   "+N WINS" popup, gold gradient, 1.6× normal popup size
t=200   Wins chip punch + count-up
```

## 7.4 Rank up — the money moment, the thing people clip

```
t=-600  riser sound starts (0.6s), Volume 0.5   ← BEFORE the visual. This is what
                                                   makes it feel like it's happening
                                                   TO the player rather than at them.
t=0     input disabled, camera eases in: FOV punch -12, in 0.12s, out 0.7s Quint
t=0     screen flash: BackgroundTransparency snaps to 0.25 (NO in-tween),
        then tween to 1 over 0.35s Quad Out
t=0     impact sound, Volume 0.8, on the beat
t=0     camera ShakeOnce(4.0, 11, 0, 1.1)
t=0     old outfit shatters (particle burst + parts scaling to 0)
t=250   new outfit assembles, each piece TweenInfo(0.28, Back, Out) staggered 40ms apart
t=400   extruded rank title slams in: TweenInfo(0.55, Elastic, Out), Scale 0.2→1.0,
        Rotation -8→0
t=400   choir/pad tail, 1.5s, Volume 0.4
t=1200  input restored
```
**Reserve `Elastic` for this and only this.** It's a once-per-session moment; using it anywhere repeatable makes it worthless.

## 7.5 Easing reference — which style for what

| Effect | Style | Direction | Why |
|---|---|---|---|
| Button hover in | Quad / Sine | Out | No overshoot on hover — it feels twitchy |
| Button press down | Quad | Out | Must be ≤0.06s or the press feels laggy |
| Button release pop | **Back** | Out | The overshoot *is* the pop |
| Popup appear | **Back** | Out | The signature simulator feel |
| Popup dismiss | Quad or Back | In | Anticipate, then leave |
| Reward slam-in | **Elastic** | Out | Once-per-session moments only |
| Panel slide from edge | Quint / Quart | Out | Back's overshoot exposes the gap behind the screen edge |
| Progress bar fill | Quad | Out | **Never Back** — a bar that overshoots reads as a bug |
| Idle bob / breathe | **Sine** | InOut + `repeatCount = -1, reverses = true` | The only style that loops seamlessly |
| Number count-up | Quart | Out | Fast, then settles on the final digit |
| FOV punch | Quad in, Quint out | | |

**Never use `Bounce`.** It reads as amateur in essentially every context; `Back` gives the same energy with control.

**Concrete durations:**

| Interaction | TweenInfo | Target |
|---|---|---|
| Hover in | `(0.12, Quad, Out)` | `UIScale.Scale = 1.05` |
| Hover out | `(0.18, Quad, Out)` | `1.00` |
| Press down | `(0.05, Quad, Out)` | `0.94` + shadow collapse |
| Release pop | `(0.22, Back, Out)` | `1.00` |
| Scale punch | `(0.14, Back, Out, 0, true)` | `1.18`, reverses |
| Popup appear | `(0.28, Back, Out)` | `Scale 0.85 → 1.0` + `GroupTransparency 1 → 0` over `0.16s Quad Out` |
| Panel slide-in | `(0.38, Quint, Out)` | `Position.Y.Scale 1.15 → 0.5` |
| Reward pop | `(0.55, Elastic, Out)` + 0.05 delay | `Scale 0.2 → 1.0` |
| Toast | in `(0.3, Back, Out)`, hold 2.2s, out `(0.25, Quad, In)` | |
| Currency counter | `(0.6, Quart, Out)` | on a NumberValue |

**Five implementation rules that will otherwise bite:**
1. **Animate `UIScale.Scale`, never `Size`.** Tweening `Size` fights `UIListLayout`/`UIGridLayout`, reflows siblings and thrashes layout every frame. Put a `UIScale` on every button.
2. Set `AnchorPoint = (0.5, 0.5)` on anything you scale or it grows from the corner.
3. **Cancel the previous tween** before starting a new one, or fast hover-in/out leaves buttons stuck at 1.05. This is the single most common Roblox UI bug.
4. Wrap fading UI in a `CanvasGroup` and tween `GroupTransparency` once, instead of walking N descendants.
5. Disable input during the appear tween (`button.Active = false`) so a double-tap doesn't fire twice.

## 7.6 Camera

Use `CameraShaker` (sleitnick). `ShakeOnce(magnitude, roughness, fadeIn, fadeOut)`:
```
click / pickup ......... (0.35, 12, 0,    0.18)
purchase ............... (0.8,  10, 0,    0.3)
rival defeated ......... (1.2,   8, 0,    0.5)
rank-up / restructure .. (4.0,  11, 0,    1.1)
boss defeated .......... (6.0,  14, 0.05, 1.6)
```
**Magnitude > 6 makes mobile players motion-sick** and hides the reward you're celebrating. Put shake behind a settings toggle — accessibility, and it measurably affects retention for a subset of players.

FOV punch: `BASE = 70`, in-time ≤ 0.1s, out-time 2–5× the in-time, never exceed ±15 from base. **Always tween back to a stored `BASE`**, not to the current value, or repeated punches drift.

## 7.7 Idle motion — the fix for tell #37

**Nothing in the world may be completely static.** Minimum:
- Every pickup, Intern and shop item: idle bob, `Sine InOut`, `repeatCount = -1, reverses = true`, ~2.5s period, ±0.4 studs, plus a slow Y rotation
- Legendary items: additional sparkle emitter + slow `Highlight` pulse
- Signs: gentle scale breathe, 1.0 ↔ 1.03, 3s period
- The Landmark: something moving on it — a rotating logo, a scrolling ticker
- Give each object a **random phase offset** so they don't bob in unison. Bobbing in sync is worse than not bobbing.

---

# PART 8 — PARTICLE PRESETS

Hard limits: `Rate` caps at 400/s desktop and **100/s mobile**; `Lifetime` caps at 20s; flipbooks cap at 30fps.

## 8.1 What separates cheap from expensive

**Cheap:** one emitter doing everything · `Size`/`Transparency` as constants instead of NumberSequences (flat pop-in and pop-out) · `LightEmission = 1` on every layer (if everything glows, nothing reads as bright) · no `Rotation`/`RotSpeed` randomisation (obvious sprite tiling) · `Acceleration = (0,0,0)` so nothing has weight · `Drag = 0` so it reads as a screensaver · the default `sparkles_main.dds` unmodified · `SpreadAngle (180,180)` on everything so every effect is a sphere.

**Expensive:** 3–4 emitters per event, each on its own `ZOffset` layer · a `Size` curve with **fast attack, slow decay** (0 → peak by t=0.15–0.3 → 0) · `Transparency` starting at 1 and snapping to 0 within the first 8–12% of lifetime · `Squash > 0` on fast sparks so they stretch along motion · `VelocityInheritance` 0.2–0.4 on moving emitters · **one low-`LightEmission` smoke or dust layer under every bright burst** — that's the layer that gives it mass.

## 8.2 Coin / Wins burst (`:Emit(14)`)

```lua
Color               = ColorSequence.new(Color3.fromRGB(255,226,120), Color3.fromRGB(255,168,26))
Size                = NumberSequence.new{
                        NumberSequenceKeypoint.new(0.00, 0.0),
                        NumberSequenceKeypoint.new(0.15, 0.85),
                        NumberSequenceKeypoint.new(0.75, 0.7),
                        NumberSequenceKeypoint.new(1.00, 0.0)}
Transparency        = NumberSequence.new{
                        NumberSequenceKeypoint.new(0.00, 1.0),
                        NumberSequenceKeypoint.new(0.08, 0.0),
                        NumberSequenceKeypoint.new(0.70, 0.0),
                        NumberSequenceKeypoint.new(1.00, 1.0)}
Lifetime            = NumberRange.new(0.45, 0.8)
Speed               = NumberRange.new(11, 19)
SpreadAngle         = Vector2.new(35, 35)
EmissionDirection   = Enum.NormalId.Top
Acceleration        = Vector3.new(0, -55, 0)   -- heavy gravity = weight
Drag                = 2.5
RotSpeed            = NumberRange.new(-220, 220)
Rotation            = NumberRange.new(-180, 180)
LightEmission       = 0.55
LightInfluence      = 0
Brightness          = 1.4
ZOffset             = 0.2
VelocityInheritance = 0.25
Rate = 0; Enabled = false
```
Plus a sibling **flash** emitter on the same attachment, `:Emit(1)`: `Size {0→0.4, 0.25→3.2, 1→0}`, `Transparency {0→0.15, 1→1}`, `Lifetime 0.16`, `Speed 0`, `LightEmission 1`, `ZOffset 0.6`.

## 8.3 Sparkle (continuous, on Legendary items)

```lua
Size          = NumberSequence.new{NSK(0,0), NSK(0.35,0.45), NSK(1,0)}
Transparency  = NumberSequence.new{NSK(0,1), NSK(0.3,0.1), NSK(1,1)}
Lifetime      = NumberRange.new(0.7, 1.4)
Rate          = 12          -- keep LOW; sparkle is contrast, not density
Speed         = NumberRange.new(0.4, 1.2)
SpreadAngle   = Vector2.new(180, 180)
Acceleration  = Vector3.new(0, 1.5, 0)
Drag          = 1.5
RotSpeed      = NumberRange.new(-30, 30)
LightEmission = 1
LightInfluence = 0
ZOffset       = 0.4
Shape         = Enum.ParticleEmitterShape.Sphere
ShapeStyle    = Enum.ParticleEmitterShapeStyle.Volume
Orientation   = Enum.ParticleOrientation.FacingCamera
```

## 8.4 Neon tier column (Epic/Legendary pads)

```lua
Color             = ColorSequence.new{
                      CSK(0.0, Color3.fromRGB(255,240,180)),
                      CSK(0.4, Color3.fromRGB(120,255, 90)),
                      CSK(1.0, Color3.fromRGB( 20,120, 40))}
Size              = NumberSequence.new{NSK(0,0.35), NSK(0.2,0.5), NSK(1,0.05)}
Transparency      = NumberSequence.new{NSK(0,1), NSK(0.12,0.05), NSK(0.75,0.2), NSK(1,1)}
Lifetime          = NumberRange.new(1.6, 3.2)
Rate              = 22
Speed             = NumberRange.new(3.5, 7)
SpreadAngle       = Vector2.new(14, 14)
EmissionDirection = Enum.NormalId.Top
Acceleration      = Vector3.new(0, 3.5, 0)   -- positive = buoyant
Drag              = 0.6
LightEmission     = 0.9
Brightness        = 2
Shape             = Enum.ParticleEmitterShape.Cylinder
ShapeStyle        = Enum.ParticleEmitterShapeStyle.Volume
```

## 8.5 Rank-up explosion — four layers, all `Enabled = false`

```lua
-- 1. shockwave ring, Orientation = FacingCameraWorldUp, :Emit(1)
Size = NumberSequence.new{NSK(0,1), NSK(1,26)}
Transparency = NumberSequence.new{NSK(0,0.1), NSK(1,1)}
Lifetime = NumberRange.new(0.55,0.55); Speed = NumberRange.new(0,0)
LightEmission = 1; ZOffset = 0.8

-- 2. core flash, :Emit(1)
Size = NumberSequence.new{NSK(0,2), NSK(0.3,9), NSK(1,0)}
Lifetime = NumberRange.new(0.25,0.25); LightEmission = 1; Brightness = 3

-- 3. sparks, :Emit(45)
Lifetime = NumberRange.new(0.4,1.1); Speed = NumberRange.new(28,60)
SpreadAngle = Vector2.new(180,180); Drag = 10
Acceleration = Vector3.new(0,-80,0)
Size = NumberSequence.new{NSK(0,0.35), NSK(1,0)}
RotSpeed = NumberRange.new(-400,400); LightEmission = 0.8; Squash = 1.5

-- 4. smoke puff, :Emit(10)  ← THE LAYER THAT GIVES IT MASS. Do not skip this one.
FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
FlipbookMode   = Enum.ParticleFlipbookMode.OneShot
Lifetime = NumberRange.new(0.9,1.4); Speed = NumberRange.new(6,14)
SpreadAngle = Vector2.new(180,180); Drag = 4
Size = NumberSequence.new{NSK(0,3), NSK(1,9)}
Transparency = NumberSequence.new{NSK(0,0.35), NSK(1,1)}
LightEmission = 0; LightInfluence = 1; ZOffset = -0.5
Color = Color3.fromRGB(90,80,95)
```

## 8.6 Purchase-confirm puff (`:Emit(12)`)

Green, `Lifetime 0.28–0.42`, `Speed 6–10`, `Drag 6`, `Acceleration (0,-14,0)`, total on-screen time ~0.4s. **Anything longer on a repeatable action becomes visual noise.**

---

# PART 9 — UI SYSTEM

## 9.1 Responsive foundation — do this before any UI work

```lua
local DESIGN_Y = 900              -- author at 1600×900
local MIN, MAX = 0.55, 1.35
local cam = workspace.CurrentCamera
local function apply()
    local v = cam.ViewportSize
    local s = v.Y / DESIGN_Y
    if v.X / v.Y > 1.9 then s = s * 1.12 end   -- landscape phones are short; bias up
    uiScale.Scale = math.clamp(s, MIN, MAX)
end
cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply); apply()
```
One `UIScale` per root `Frame` (it does not apply to `ScreenGui`), everything else authored in Offset px. That gives pixel-exact strokes and corners *and* correct scaling.

**`ScreenGui.ScreenInsets = CoreUISafeInsets`** for anything interactive. Never hardcode the topbar height — it's been reported as both 36px and 58px. Use `GuiService:GetGuiInset()` or the enum.

## 9.2 Corner radii — consistent, not identical (tells #19 and #20)

| Element | CornerRadius |
|---|---|
| Root panel / shop window | `UDim.new(0, 24)` |
| Card / list row | `UDim.new(0, 16)` |
| Primary button | `UDim.new(0, 14)` |
| Small icon button | `UDim.new(0, 12)` |
| Pill (currency chip, tag) | `UDim.new(0.5, 0)` |
| Progress bar and its fill | `UDim.new(0.5, 0)` on **both** |

Pick Offset or Scale as a policy and hold it project-wide.

## 9.3 Padding — 8px base grid, no exceptions (tell #18)

```
Panel outer:   UIPadding 24 all sides
Card:          16 all sides
Button label:  10 top/bottom, 18 left/right
List gap:      UIListLayout.Padding = UDim.new(0, 12)
Grid gap:      UIGridLayout.CellPadding = UDim2.fromOffset(12, 12)
Icon ↔ text:   10
```

## 9.4 Shadows — two per panel is the "expensive" look

`UIShadow.ZIndex` must be **negative**. Budget ≤40 on mobile.
```lua
-- contact shadow
s1.BlurRadius = UDim.new(0, 8);  s1.Offset = UDim2.fromOffset(0, 4)
s1.Transparency = 0.45; s1.Spread = -2; s1.ZIndex = -1
-- ambient shadow
s2.BlurRadius = UDim.new(0, 44); s2.Offset = UDim2.fromOffset(0, 18)
s2.Transparency = 0.72; s2.Spread = 4;  s2.ZIndex = -2
```
Button at rest: `BlurRadius 12, Offset (0,6), Transparency 0.55`. Pressed: tween to `BlurRadius 4, Offset (0,2), Transparency 0.7`. **The shadow collapsing is what sells the press.**
Legendary glow: `Color = rarityColor, BlurRadius 60, Transparency 0.35, Spread 6, Offset 0`.

## 9.5 Typography

**Exactly two fonts** (tell #17): one heavy rounded display face for headings, numbers and signage; one clean face for body copy. Never `SourceSans` or `Legacy` untreated (tell #16).

`UIStroke` thickness by text size, if using `FixedSize` at 1080p — the ratio that reads as this genre is roughly **TextSize / 9 to TextSize / 6**:

| TextSize | Chunky | Body |
|---|---|---|
| 18 | 2 | 1.5 |
| 24 | 3 | 2 |
| 32 | 4 | 2.5 |
| 42 | 5 | 3 |
| 56 | 7 | 4 |
| 72 | 9 | 5 |

Prefer `ScaledSize` with `Thickness = 0.14` and let it handle every resolution.

## 9.6 HUD layout

- Bottom-left: currency `Chip` stack — Productivity, Wins, Interns. Icon + tabular number, `UIStroke`, `UIShadow`, punch-and-count-up on change.
- Left edge: compact round icon buttons (Shop, Interns, Stats, Rebirth) — not big flat squares. Gradient fill, shadow, hover/press states, sound.
- Top-centre: event bar — countdown to the next boss with a SKIP button.
- Above the HUD: `+N per click · +N/sec` in extruded text.
- Every button gets hover, press, release and sound. Tell #27 is buttons with none of those.

---

# PART 10 — SOUND

Tell #35. A professional UI sound is **2–3 layers played simultaneously**, and the transient must fire in the same frame as the input.

| Event | Layer 1 (transient) | Layer 2 (body) | Layer 3 (tail) |
|---|---|---|---|
| Button click | tick, Vol 0.35, pitch ±0.06 | soft pop, Vol 0.2 | — |
| Purchase | click, Vol 0.4 | ascending 2-note chime, Vol 0.55 | shimmer, Vol 0.25, +0.06s |
| Click a bag | tink, Vol 0.3, pitch ±0.12 | — | — |
| Rival defeated | impact, Vol 0.5 | whoosh, Vol 0.4, +0.15s | — |
| Rank-up | riser 0.6s, Vol 0.5, **0.6s before the visual** | impact, Vol 0.8, on the beat | pad tail 1.5s, Vol 0.4 |
| Can't afford | dull thud, Vol 0.35, `PlaybackSpeed 0.9` | — | — |

**Pitch randomisation** — `PlaybackSpeed = 2` is exactly one octave, so ±0.06 ≈ ±1 semitone:

| Class | ± spread |
|---|---|
| UI click / hover | 0.04–0.08 (more and buttons sound broken) |
| Coin / pickup | 0.10–0.15 |
| Impact | 0.12–0.20 |
| Music, jingles | **0** — never pitch-shift melodic content |

**The single highest-value audio trick in this genre:** for rapid clicks, don't randomise — **step the pitch up per consecutive hit**: `1.0, 1.06, 1.12, 1.19, 1.26…` capped at 1.6, reset after 0.6s of silence. That ladder is what makes clicking feel good.

Cap concurrent copies of any one SFX at ~4 — more produces phasing that reads as a bug.

**Routing:** `Master` → `Music` (0.35), `SFX` (0.8) → `UI` (0.6) / `World` (0.9), `Ambience` (0.4). `Sound.SoundGroup` must be **assigned** — parenting does nothing. World SFX: `RollOffMode = InverseTapered`, `RollOffMinDistance = 8`, `RollOffMaxDistance = 90`.

**Where to get audio:** the Creator Store has 100,000+ professionally-produced licensed sounds and music tracks, free to use. Right-click → Copy Asset ID (left-clicking inserts a legacy Sound instance). Never rip asset IDs from other games — audio privacy means they won't load for our experience anyway.

---

# PART 11 — PERFORMANCE BUDGETS

Baseline device: a 2GB Android phone at graphics quality 10, 60 FPS target.

| Resource | Mobile | Desktop |
|---|---|---|
| Draw calls (scene) | **≤ 450** | ≤ 900 |
| Draw calls (UI) | **≤ 120** | ≤ 150 |
| Triangles in view | ≤ 400,000 | ≤ 900,000 |
| Active particles in view | **≤ 200** | ≤ 700 |
| Particle emitters in view | ≤ 12 | ≤ 30 |
| Emitters per burst event | ≤ 4 | ≤ 6 |
| Beams + Trails in view | ≤ 15 | ≤ 40 |
| Local lights (no shadows) | ≤ 20 | ≤ 45 |
| Local lights **casting shadows** | **≤ 3** | ≤ 8 |
| Visible BillboardGuis | ≤ 25 | ≤ 60 |
| Visible Highlights | **≤ 6** | ≤ 25 |
| UIShadows on screen | ≤ 40 | ≤ 100 |
| UIStrokes on screen | ≤ 120 | ≤ 300 |
| Simultaneous Sounds | ≤ 12 | ≤ 24 |
| Unique particle textures | ≤ 8 | ≤ 20 |
| Client memory | **≤ 1.3 GB** | — |

**Quality tiering — implement this, don't just aspire to it:**
```lua
local q = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local tier = (isMobile or q <= 4) and "LOW" or (q <= 7 and "MED" or "HIGH")

local PROFILE = {
  LOW  = {particleMul = 0.35, emitDivisor = 3, shadowLights = false,
          billboardDist =  90, highlightCap =  4},
  MED  = {particleMul = 0.70, emitDivisor = 2, shadowLights = true,
          billboardDist = 140, highlightCap = 12},
  HIGH = {particleMul = 1.00, emitDivisor = 1, shadowLights = true,
          billboardDist = 220, highlightCap = 25},
}[tier]
```

**Cheap wins the docs specifically call out:** avoid partial transparency (use 0 or 1 — layered semi-transparent surfaces cause massive overdraw) · enable instance streaming · `Model.LevelOfDetail = SLIM` on world models · `Workspace.EnableSLIMAvatars = true` · `CastShadow = false` on props at the edges of playable space · `Light.Shadows = false` on decorative lights · reuse one texture tinted with `SurfaceAppearance.Color` rather than uploading recoloured variants.

**Measure with Shift+F2 in the live client** (Render Stats: Draw scene, triangles, timing). Studio play-solo runs a server and inflates memory — the live client is the only number that counts. F9 for `LuaHeap` / `InstanceCount`. The emulator is fine for aspect ratio and controls, useless for memory — test on a real cheap Android.

---

# PART 12 — QUALITY GATES

Do not tell me a pass is finished until every gate below is green. Report each one explicitly.

**Gate A — the audit.** Zero fails on the Part 2 list. Report it item by item.

**Gate B — the variance check.** Pick any three repeated elements. Confirm each instance differs in rotation, scale and position from its neighbours. If any set is uniform, it fails.

**Gate C — the silhouette test.** Screen-capture from spawn, then again from 40 studs back. Every interactive object must be identifiable by shape alone.

**Gate D — the scale hierarchy.** Confirm all four tiers exist in the zone and that there is **exactly one** Landmark.

**Gate E — the feedback sweep.** Every interactive element responds with at least three simultaneous channels (visual + sound + motion). Walk the list and confirm.

**Gate F — nothing is static.** Stand still for 10 seconds and screen-capture twice, 5 seconds apart. If the two frames are identical outside the player, it fails.

**Gate G — the numbers.** Shift+F2 in a live client. Report draw calls, triangles and frame time against Part 11.

**Gate H — the phone test.** Emulate a phone viewport. Confirm the UI is not under the topbar, text is legible, and buttons are thumb-sized.

**Gate I — the side-by-side.** Put our screenshot next to the reference and tell me honestly which specific things still differ. Do not tell me it matches when it doesn't — I would rather have an accurate list of what's left.

---

# PART 13 — HOW TO WORK

Five passes. **Stop after each one.** Screen-capture and report against the gates before continuing.

| Pass | Scope | Gates |
|---|---|---|
| **P1 — Foundation** | Camera. Lighting, Atmosphere, post-processing. Map shrink to the Part 4.1 targets. The Landmark object. | C, D, G |
| **P2 — Systems** | The component library (Part 6), built data-driven. Palette and rarity config. Signage applied everywhere. | A (UI items), B |
| **P3 — Materials & variance** | Studded materials, trim and edge detail, prop scale-up, the variance pass, set dressing, tier escalation. | A (materials items), B, C |
| **P4 — Juice** | Every interaction in Part 7. Particles from Part 8. Idle motion. Camera shake and FOV. | E, F |
| **P5 — UI & sound** | The full Part 9 UI system, HUD rebuild, Part 10 sound. Then the whole audit again. | A (all), E, H, I |

**Use the Studio MCP server every pass.** `start_stop_play` → `character_navigation` to walk the space → `user_mouse_input` to fire the interactions → `get_console_output` to assert → `screen_capture` from at least three positions (spawn, training yard, shop). Do not describe what you built — show me.

**Everything tunable goes in `ReplicatedStorage/Shared/Config/`:** `Palette.luau`, `Rarity.luau`, `Juice.luau` (all tween durations and easing), `Particles.luau`, `Signage.luau`, `Perf.luau`. If I have to open a service file to change a colour or a tween duration, the pass failed.

**When you're unsure between two options, build the louder one.** This genre's failure mode is timidity, not excess. I will tell you to dial it back — that's a much easier conversation than "make it more."
