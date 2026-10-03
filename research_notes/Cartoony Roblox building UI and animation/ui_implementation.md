# Implementing Polished, Responsive Code-Built Game UI in Roblox (Luau), 2025–2026

> Research method note: create.roblox.com and devforum.roblox.com were blocked by this environment's network proxy. All Creator Hub facts below were read directly from the **official source of the Creator Hub**, the `Roblox/creator-docs` GitHub repo (https://github.com/Roblox/creator-docs), snapshot at commit `9f840b1` dated **2026-10-02**. Each is cited with its public create.roblox.com URL, which is the same text. DevForum facts come from **search-result snippets and thread titles only** (I could not open the threads) and are labeled as such. GitHub library facts come from raw files in those repos.
>
> Codebase context (local grep of `/home/user/ROBLOX`): Hood's client HUD lives in `hood/src/StarterPlayer/StarterPlayerScripts/HoodClient/*.client.lua` (e.g. `Lobby.client.lua`, `Foundation.client.lua`). Across the repo's game scripts the patterns are UICorner (19 uses), UIStroke (18), `Enum.Font.LuckiestGuy` (10), `Enum.Font.FredokaOne` (10), `Enum.Font.GothamBold` (9), `Enum.Font.GothamBlack` (5), `TextScaled` (7), `ScreenInsets` (6), `UIScale` (1) and `UIGradient` (1). Several findings below apply directly: Gotham was removed, TextScaled is discouraged, and UIScale is under-used.

---

## 1. Responsive scaling: Scale vs Offset, AnchorPoint, constraints, UIScale, safe areas, text sizing, touch targets

### Takeaway
The approach that holds up best in 2025–26 is to **author in Offset pixels at a reference resolution, then multiply the whole HUD with a UIScale computed from the ScreenGui's size** (clamped). Use Scale only for anchoring positions to screen edges and corners. Keep `ScreenInsets = CoreUISafeInsets` for interactive UI. Avoid `TextScaled` in favor of a fixed `TextSize` scaled by UIScale, or `AutomaticSize`. Roblox itself says pure Scale sizing breaks on 4K TVs and recommends adapting by `GuiService.ViewportDisplaySize`.

### Cited Findings

**Scale vs Offset / AnchorPoint**
- `UDim2` has a Scale component (a **percentage** of the container's size) and an Offset component (**pixels**). The two are additive. — [Position and size](https://create.roblox.com/docs/ui/position-and-size)
- `AnchorPoint` is the origin from which position and size apply. The default is `(0,0)` (top-left), values are fractions 0–1 of the object's size, and `(0.5,0.5)` is the center. — [Position and size](https://create.roblox.com/docs/ui/position-and-size)
- Roblox: "Positioning UI elements by Scale is a common approach… Scale is also recommended for sizing… However, 75% would render to a huge size on 4K TVs for console players, so it's recommended that you explore screen size adaptation." — [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform)
- `GuiService.ViewportDisplaySize` (read-only `Enum.DisplaySize`) values: `Small` = most tablet/mobile/handheld, `Medium` = most laptops and monitors, `Large` = most TVs or larger. You can listen with `GetPropertyChangedSignal`. Roblox says "attempting to predict screen size by pixels often leads to misinterpretation." — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService), [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform)

**UIScale**
- `UIScale.Scale` multiplies the parent's `AbsoluteSize`. For example, 0.5 turns {0,200},{0,50} into {0,100},{0,25}. It "proportionally scales the object and all of its children, including any applied appearance modifiers like UIStroke or UICorner." It is also recommended for tweening the size of a button. — [UIScale](https://create.roblox.com/docs/reference/engine/classes/UIScale), [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- Community pattern (BetterScale): "On every resize, BetterScale computes `screenSize / resolution` on the configured axis, clamps it to `Range`, then multiplies by `Ratio`." The default reference `Resolution` is **1280×720**, it is commonly set to `Vector2.new(1920,1080)`, and the `Range` attribute is e.g. `NumberRange.new(0.5, 2.0)`. The `Axis` attribute is X, Y or XY. — [BetterScale (GitHub)](https://github.com/bloxlibs/BetterScale)
- Other community resources using the same "UIScale driven by viewport" idea include AutoUIScale and a tagged-UIScale approach with a `base_resolution` attribute of 1920×1080 (search-snippet level only). — [AutoUIScale](https://developerplacebruno.itch.io/roblox-autouiscale), [DevForum: What is a good method to properly scaling UI?](https://devforum.roblox.com/t/what-is-a-good-method-to-properly-scaling-ui/218157)
- Known bug threads (titles only, not read): "UIScale incorrectly scaling UIStroke thickness" and "UIScale doesn't properly scale UIStrokes with ScaledSize". — [DevForum 4157250](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250), [DevForum 4527312](https://devforum.roblox.com/t/uiscale-doesnt-properly-scale-uistrokes-with-scaledsize/4527312)

**Constraints**
- `UISizeConstraint` sets `MinSize`/`MaxSize` in pixels. For example, (200,200)–(400,400) keeps the object between 200×200 and 400×400. **Warning:** when an object is under both a layout (e.g. UIListLayout) and a UISizeConstraint, "the constraint will override the layout." — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- `UIAspectRatioConstraint` enforces width:height (`AspectRatio`, default 1). It is handy for square thumbnails and it also overrides layouts. Roblox's size-tween sample adds one so the object keeps its ratio while tweening Scale sizes. — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers), [UI animation](https://create.roblox.com/docs/ui/animation)
- `UITextSizeConstraint` (`MinTextSize`/`MaxTextSize`) works with `TextScaled`. Roblox: "Do not use MinTextSize values lower than 9 or the text will be difficult to read." — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- `AutomaticSize` (`None`/`X`/`Y`/`XY`) grows an object to fit its content. `Size` becomes the **minimum** size, it respects AnchorPoint, and text grows on Y only when `TextWrapped` is true. ScrollingFrame uses `AutomaticCanvasSize` instead. — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers), [AutomaticSize enum](https://create.roblox.com/docs/reference/engine/enums/AutomaticSize)

**TextScaled pitfalls**
- `TextScaled`: "When enabled, TextSize is ignored and TextWrapped is automatically enabled… useful for rendering text elements within BillboardGuis… **It's recommended that you avoid usage of TextScaled** and adjust UI to take advantage of the AutomaticSize property." — [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)
- New read-only `TextLabel.TextFits` is true when the text fits entirely and false when it is clipped or truncated. It reflects TextWrapped, TextTruncate and TextScaled. — [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)
- `GuiService.PreferredTextSize` (`Medium` default, `Large`, `Larger`, `Largest`) maps to the player's Text Size setting. Text limited by a UITextSizeConstraint will not shrink below its minimum. — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)

**ScreenInsets / safe areas / IgnoreGuiInset**
- `ScreenGui.ScreenInsets` values:
  - `CoreUISafeInsets` is the **default and the recommended value for interactive/important UI**. It keeps content clear of the top bar buttons and device cutouts.
  - `DeviceSafeInsets` avoids notches but not Roblox core UI.
  - `TopbarSafeInsets` is the dynamic space left in the top bar.
  - `None` should be used "only for a ScreenGui that contains non-interactive content like background images."
  
  — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui), [ScreenInsets enum](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets)
- `IgnoreGuiInset` is legacy-compatible. When false, ScreenInsets is `CoreUISafeInsets`. Setting it true while ScreenInsets is CoreUISafeInsets switches it to `DeviceSafeInsets`. — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- `ClipToDeviceSafeArea` defaults to true, so descendants are clipped to the device safe area. This is kept for backward compatibility with offscreen slide-in UI. — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- `SafeAreaCompatibility` defaults to `FullscreenExtension`. It auto-expands "fullscreen" descendants on screens with cutouts. Roblox recommends avoiding it for new work and using ScreenInsets per ScreenGui instead. — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- `GuiService.TopbarInset` (a Rect) is the unoccupied area beside Roblox's left-most controls. It is dynamic, so listen with `GetPropertyChangedSignal`. `GuiService:GetGuiInset()` returns the top-left and bottom-right insets, which apply only to ScreenGuis with IgnoreGuiInset=false. — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)
- Community reports (search snippets) say the reintroduced top bar is **58 px** tall. One bug thread says `GetGuiInset()` can return 0 on the first frame and then (0,58) a heartbeat later. — [DevForum: Reintroduction of the topbar](https://devforum.roblox.com/t/reintroduction-of-the-topbar-messing-up-ui/3260927), [DevForum: GetGuiInset returns 0 at first](https://devforum.roblox.com/t/guiservicegetguiinset-returns-0000-at-first/3472295)
- Console: "some TVs will not show content fully to the edges of the screen… put UI elements in TV-safe areas." — [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines)

**Touch targets & thumb zones**
- Roblox gives no numeric minimum. It says interactive elements must be "large enough to tap reliably," to test on real phones ("Buttons that seem comfortably sized on a desktop monitor can be frustratingly small on a 5-inch display"), and to keep frequent buttons in thumb zones. "A button placed 40% below the screen's top edge is reachable on a phone but almost unreachable on a tablet." It recommends positioning custom buttons **relative to the default jump button**. — [Test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware), [Position and size](https://create.roblox.com/docs/ui/position-and-size)
- Roblox's own `TouchJump.lua` (PlayerModule) uses `minAxis = math.min(AbsoluteSize.x, AbsoluteSize.y)` and `isSmallScreen = minAxis <= 500`. The jump button is **70–72 px on small screens and 120 px otherwise**, with an inset from the edges of 64 px (small) or 100/112 px (large). — [Roblox-Client-Tracker mirror: TouchJump.lua](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/scripts/PlayerScripts/StarterPlayerScripts/PlayerModule.module/ControlModule/TouchJump.lua)
- Platform norms: Apple HIG requires a minimum 44×44 pt tappable area and Material Design 48×48 dp. The visible icon can be smaller if padding enlarges the hit area. — [TetraLogical: Foundations, target sizes](https://tetralogical.com/blog/2022/12/20/foundations-target-size/)

### Inferences
- **Recommended HUD scaling pattern for Hood.** Build every HUD element in Offset pixels designed at 1280×720 or 1920×1080. Pin elements to edges with Scale positions plus AnchorPoint, for example top-right `Position = UDim2.new(1,-16,0,16)` with `AnchorPoint = Vector2.new(1,0)`. Then drive one UIScale per ScreenGui. Use `ScreenGui.AbsoluteSize` (which already excludes the insets) rather than `Camera.ViewportSize`, because the inset-adjusted size is what your UI actually occupies.
  ```lua
  -- Responsive UIScale (reference 1280x720, clamped). Run in the HUD LocalScript.
  local REF = Vector2.new(1280, 720)
  local function attachAutoScale(screenGui: ScreenGui, minS: number?, maxS: number?)
      local uiScale = Instance.new("UIScale")
      uiScale.Parent = screenGui -- UIScale on a ScreenGui is not valid; put it on a full-size root Frame
      return uiScale
  end
  -- Correct version: a root Frame that fills the ScreenGui carries the UIScale.
  local function makeRoot(screenGui: ScreenGui)
      local root = Instance.new("Frame")
      root.Name = "Root"
      root.BackgroundTransparency = 1
      root.Size = UDim2.fromScale(1, 1)
      root.Parent = screenGui
      local s = Instance.new("UIScale"); s.Parent = root
      local function update()
          local abs = screenGui.AbsoluteSize
          local k = math.min(abs.X / REF.X, abs.Y / REF.Y)   -- "fit" (letterbox) rule
          s.Scale = math.clamp(k, 0.55, 1.6)                  -- keep phones legible, TVs sane
      end
      screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
      update()
      return root, s
  end
  ```
  When UIScale < 1, children laid out with Scale inside `root` see a larger logical parent. So with this pattern, give root `Size = UDim2.fromScale(1/k, 1/k)` or keep the HUD in Offset. Most projects use pure Offset under the scaled root, which is why the snippet uses `min()`. The `min(w/refW, h/refH)` "fit" formula and the clamp range are community practice, not a Roblox-documented formula. Treat the numbers as tunable.
- **A phone floor.** Phones in landscape typically report a short axis of roughly 360–430 logical px. Roblox's own `minAxis <= 500` check implies this. So 720-reference scaling gives about k≈0.5–0.6 on phones. Clamp the minimum (about 0.55–0.6) or add a per-`ViewportDisplaySize.Small` bonus multiplier, so a 72 px design-size button does not fall below roughly 44 px on device. Mirror Roblox's 70/120 jump-button split as a sanity check for primary action buttons.
- **Text.** Replace `TextScaled = true` in Hood's HUD with a fixed `TextSize` (e.g. 28–36 at 720p reference) under the scaled root. Where the text length varies, add `AutomaticSize = X` with a min-width `Size`. Keep `TextScaled` only for BillboardGuis, where Roblox explicitly says it is useful.
- **Insets.** Keep gameplay HUD ScreenGuis on `CoreUISafeInsets`. Use `None` only for full-screen backdrops and vignettes. If something must sit in the top bar row, such as a coin pill next to the Roblox menu, use a separate ScreenGui with `TopbarSafeInsets`.

### Gaps
- No official Roblox minimum touch-target size exists in the docs. The 44 pt and 48 dp figures are Apple/Google norms, and how Roblox offset pixels map to device points/dp on each platform is not documented. My inference that Roblox mobile UI px ≈ logical points comes from the jump-button heuristic, not from a spec.
- I could not open the UIScale/UIStroke bug threads, so whether they are fixed as of Oct 2026 is unknown.

---

## 2. Styling objects: UICorner, UIStroke, UIGradient, UIShadow, UIPadding, layouts and flex, ZIndexBehavior, CanvasGroup, 9-slice, ResampleMode, RichText, fonts

### Takeaway
Roblox shipped major styling upgrades in 2025–26:
- **UIStroke** gained `StrokeSizingMode` (pixel or scaled thickness), `BorderStrokePosition`/`BorderOffset`, `ZIndex` and multiple border strokes.
- **UIShadow** gives native drop shadows.
- **UICorner** got per-corner radii.
- **UIGradient** got `Type` (Linear/Radial/Conical), `Scale` and `TileMode`.
- A CSS-like **StyleSheet/StyleRule** system arrived with tokens, hover states, media-style queries and transitions.

Old enum fonts like Gotham and Arial are removed and silently remapped, so use `FontFace = Font.new(...)` going forward.

### Cited Findings

**UIStroke (2025 overhaul)**
- Properties are `ApplyStrokeMode` (`Contextual` = on text, `Border` = on bounds), `BorderOffset` (UDim), `BorderStrokePosition` (`Outer`/`Center`/`Inner`), `Color`, `Enabled`, `LineJoinMode` (`Round` default, `Bevel`, `Miter`), `StrokeSizingMode`, `Thickness`, `Transparency` and `ZIndex`. A child UIGradient gives gradient strokes. — [UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke), [BorderStrokePosition enum](https://create.roblox.com/docs/reference/engine/enums/BorderStrokePosition)
- `StrokeSizingMode.FixedSize` (0) means Thickness is in pixels. `ScaledSize` (1) means Thickness is "relative to minimum parent width or height. If stroke is on text, thickness is relative to font size." — [StrokeSizingMode enum](https://create.roblox.com/docs/reference/engine/enums/StrokeSizingMode)
- DevForum (snippet): ScaledSize makes Thickness "a percentage of the parent GuiObject's shortest axis. For example, a Thickness of 0.1 on a 200x300 Frame would result in a 20-pixel stroke." "The limit of one border UIStroke per object has been removed." The thread went from Studio Beta to Client Beta to a "[Full Release]" title. — [DevForum: [Full Release] UIStroke Improvements](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036)
- You can stroke text and border independently by parenting two UIStrokes, one `Contextual` and one `Border`. Multiple sibling strokes render by `ZIndex`, and the order is **undefined if ZIndex ties**. — [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)
- **Warning:** do not tween `Thickness` on a UIStroke applied to **text**: it "renders and stores many glyph sizes each frame, potentially causing performance issues or text flickering." — [UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke)
- Legacy text stroke: `TextStrokeTransparency` "is multiple renderings of the same transparency, so this property is essentially multiplicative on itself four times over." Roblox recommends 0.75–1 for subtle effects and points to UIStroke as the "powerful alternative which supports color gradients." — [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)
- Older community fix (before ScaledSize): scripts that rescale Thickness by viewport size. — [DevForum: Make UIStroke Responsive on All Screen Size](https://devforum.roblox.com/t/make-uistroke-responsive-on-all-screen-size/1463151)

**UICorner (per-corner radii)**
- `CornerRadius` (UDim) is now shorthand that writes `TopLeftRadius`, `TopRightRadius`, `BottomRightRadius` and `BottomLeftRadius`. Reading it returns TopLeft. Scale is relative to the **shortest** edge, so 0.5 or more gives a pill. UICorner **cannot apply to ScrollingFrame**. Input (but not descendants) is clipped to the rounded area. — [UICorner](https://create.roblox.com/docs/reference/engine/classes/UICorner), [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)
- **Status conflict:** the docs snapshot (2026-10-02) still says the individual-corner properties are "currently in beta. To use it, enable New UI Capabilities in Studio's beta features window" ([UICorner](https://create.roblox.com/docs/reference/engine/classes/UICorner)). However, the DevForum thread is titled "[Full Release] New UI Capabilities: Shadows & Individual Corners!" ([DevForum 4636263](https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263)). Verify in Studio before relying on it in live servers.

**UIShadow (new)**
- Properties are `BlurRadius` (UDim, with scale relative to the shorter parent axis, non-negative), `Color`, `Enabled`, `Offset` (UDim2), `Spread` (UDim2), `Transparency` and `ZIndex` (**negative only**, because shadows render below the parent). Multiple shadows are allowed. It follows parent Rotation and UICorner rounding.
- Limits: **no text shadows** (on a TextLabel it shadows the rectangle), no inset shadows, no Path2D, and no textures or UIGradients on the shadow.

  — [UIShadow](https://create.roblox.com/docs/reference/engine/classes/UIShadow), [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)

**UIGradient**
- `Color` takes a ColorSequence and `Transparency` a NumberSequence. `Rotation` is clockwise degrees. `Offset` is a Vector2 "scalar translation" relative to AbsoluteSize, so (1,0) shifts right by the full width.
- New: `Type` (`Linear` default, `Radial`, `Conical`); `Scale` (default 1, min 0.001; values below 1 compress the gradient and values above 1 stretch it); `TileMode` (`Clamp` default, `Repeat`, `Mirror`).
- `Type`, `Scale` and `TileMode` are tagged **NotBrowsable** in the API dump, meaning they are hidden in the Properties window, but the guide documents them.
- Both a parent and its UIStroke can have their own UIGradient, so fill and stroke gradients are independent.

  — [UIGradient](https://create.roblox.com/docs/reference/engine/classes/UIGradient), [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)

**UIPadding** applies `PaddingTop`, `PaddingBottom`, `PaddingLeft` and `PaddingRight` (UDim) to a parent's contents. UIListLayout `Padding` is spacing *between* items only. — [Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers), [List and flex layouts](https://create.roblox.com/docs/ui/list-flex-layouts)

**Layouts and flex**
- `UIListLayout` has `FillDirection`, `HorizontalAlignment`, `VerticalAlignment`, `SortOrder` (LayoutOrder or Name) and `Padding`, plus the flex properties `Wraps`, `HorizontalFlex`, `VerticalFlex` and `ItemLineAlignment`. `UIFlexAlignment` values are `None`, `Fill`, `SpaceAround`, `SpaceBetween` and `SpaceEvenly`. — [List and flex layouts](https://create.roblox.com/docs/ui/list-flex-layouts), [UIFlexAlignment enum](https://create.roblox.com/docs/reference/engine/enums/UIFlexAlignment)
- `UIFlexItem` gives per-child flex: `FlexMode` (`None`, `Grow` = 1:0, `Shrink` = 0:1, `Fill` = 1:1, `Custom`), `GrowRatio`/`ShrinkRatio` (Custom only) and `ItemLineAlignment` (`Automatic`, `Start`, `Center`, `End`, `Stretch`). — [UIFlexItem](https://create.roblox.com/docs/reference/engine/classes/UIFlexItem), [UIFlexMode enum](https://create.roblox.com/docs/reference/engine/enums/UIFlexMode)
- Roblox's example for flex is a tab bar with `HorizontalFlex = Fill`: "No approach is easier than flex in this case." — [List and flex layouts](https://create.roblox.com/docs/ui/list-flex-layouts)
- `UIPageLayout` has `Animated`, `Circular`, `EasingStyle`/`EasingDirection`, `TweenTime` (min 0.01), `GamepadInputEnabled`, `ScrollWheelInputEnabled`, `TouchInputEnabled`, `JumpTo(page)` and `Next()`. — [UIPageLayout](https://create.roblox.com/docs/reference/engine/classes/UIPageLayout)
- UIGridLayout and UITableLayout are covered in [Grid and table layouts](https://create.roblox.com/docs/ui/grid-table-layouts). I did not extract their details.

**ZIndexBehavior**
- `Sibling` **is the default**: children always render above parents, and ZIndex orders siblings. `Global` sorts all descendants by ZIndex. — [LayerCollector](https://create.roblox.com/docs/reference/engine/classes/LayerCollector)

**CanvasGroup**
- It renders descendants as one flattened texture with `GroupTransparency`/`GroupColor3`. UICorner and UIGradient under it apply to the whole group, and `ClipsDescendants` is always true.
- It only flattens when the ancestor `ZIndexBehavior = Sibling`.
- It "consumes extra texture memory," with quality and memory capped by the client `QualityLevel`. "When exceeding the memory cap, CanvasGroup will render as a blank texture." Roblox recommends **static sizes**, because resizing reallocates the texture.

  — [CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup)
- DevForum (snippets): each CanvasGroup allocates a texture of AbsoluteSize (DPI-scaled), capped at **1024×1024**. Groups are down-res'd under memory pressure and at graphics quality ≤3. Nested CanvasGroups "run out of texture memory very quickly." — [DevForum: CanvasGroup Beta announcement](https://devforum.roblox.com/t/canvasgroup-beta-group-transparency-on-ui-groups/1797885), [DevForum: Using many CanvasGroups is unworkable…](https://devforum.roblox.com/t/using-many-canvasgroups-is-unworkable-until-proper-memory-management-methods-are-implemented/3502537), [DevForum: low quality at graphics level 3](https://devforum.roblox.com/t/canvasgroup-makes-its-content-low-quality-at-certain-sizes-and-graphics-level-3-or-below/2946471)

**9-slice / images**
- `ScaleType` has `Stretch` (default), `Slice`, `Tile`, `Fit` and `Crop`. With `Slice`, `SliceCenter` (Rect) sets the slice boundaries. `SliceScale` (default 1.0) "scales the 9-slice edges… as if you'd uploaded a new version of the texture upscaled." Studio has a visual 9-Slice Editor. — [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel), [ScaleType enum](https://create.roblox.com/docs/reference/engine/enums/ScaleType), [9-slice design](https://create.roblox.com/docs/ui/9-slice)
- `ResampleMode`: `Default` = bilinear and `Pixelated` = nearest-neighbor, for crisp pixel art. — [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel), [ResamplerMode enum](https://create.roblox.com/docs/reference/engine/enums/ResamplerMode)
- Transparent pixels are set to black on upload, so scaled transparent images should use alpha blending to avoid dark fringes. — [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)
- Performance guidance: UI images rarely need more than 512×512, and minor ones should be below 256×256. Use sprite sheets with `ImageRectOffset`/`ImageRectSize`. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)

**RichText**
- Tags:
  - `<b>`, `<i>`, `<u>`
  - `<font color="#FF7800">`, `<font size="40">`, `<font face="Michroma">`, `<font family="rbxasset://fonts/families/Michroma.json">`, `<font weight="heavy">` or `weight="900"`, `<font transparency="0.5">`
  - `<stroke color thickness|th transparency|tr joins="round|bevel|miter" sizing="fixed|scaled">`
  - `<uppercase>`/`<uc>`, `<smallcaps>`/`<sc>`, `<mark color transparency>`
- Example: `You won <stroke color="#00A2FF" thickness="2" transparency="0.25" joins="miter">25 gems</stroke>.`

  — [Rich text](https://create.roblox.com/docs/ui/rich-text)
- The typewriter sample strips rich-text tags before animating `MaxVisibleGraphemes`, because "char-by-char animation will break the tags." — [UI animation](https://create.roblox.com/docs/ui/animation)

**Fonts**
- `Datatype.Font` = family asset + `Weight` (e.g. `Enum.FontWeight.Bold`) + `Style` (Italic), and also has a `Bold` property. Constructors are `Font.new(family, weight?, style?)`, `Font.fromEnum(Enum.Font.X)`, `Font.fromName("FredokaOne")` and `Font.fromId(assetId)`. Set it via `TextLabel.FontFace`, which stays in sync with the legacy `Font` enum property. The enum shows `Unknown` if there is no match. — [Font datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font), [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)
- Built-in family paths (`rbxasset://fonts/families/<Name>.json`) include BuilderSans, BuilderExtended, BuilderMono, FredokaOne, LuckiestGuy, Bangers, DenkOne, PermanentMarker, ComicNeueAngular, PatrickHand, Nunito, Montserrat, Oswald, Roboto and others. — [Font datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font)
- **Deprecations:** `Enum.Font.Gotham`, `GothamMedium`, `GothamBold` and `GothamBlack` "**has been removed.** Using it will map to the **Montserrat** font family." `Arial`/`ArialBold` map to **Arimo**. The `Enum.Font` docs call `Datatype.Font` "a newer alternative… [that] provides access to more fonts." — [Font enum](https://create.roblox.com/docs/reference/engine/enums/Font)
- Other new text props: `LineHeight` (1.0–3.0), `OpenTypeFeatures` (e.g. `"zero"`, `"ss03"`) and `TextDirection`. — [TextLabel](https://create.roblox.com/docs/reference/engine/classes/TextLabel)

### Inferences
- **The cartoony "sticker" button stack, all native, no images:**
  - Frame/TextButton with `UICorner` (`UDim.new(0, 12)` at reference scale, or `UDim.new(0.5, 0)` for pills)
  - fill `UIGradient` (Rotation 90, lighter top and darker bottom)
  - `UIStroke` in Border mode, `BorderStrokePosition = Inner` or `Outer`, `LineJoinMode = Round`, dark outline color
  - a second thin inner UIStroke (higher ZIndex) for a highlight rim
  - `UIShadow` with Offset ≈ (0, 4px) and small blur for a drop shadow
  - text with a `Contextual` UIStroke (2–3 px) for the classic outlined cartoon font

  Before UIShadow, this needed a duplicated darker frame offset downward or a 9-slice image.
  ```lua
  local function stickerButton(parent, text, theme)
      local b = Instance.new("TextButton")
      b.AutoButtonColor = false
      b.Size = UDim2.fromOffset(180, 64)
      b.BackgroundColor3 = Color3.new(1,1,1)               -- tinted by gradient
      b.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
      b.TextSize = 30; b.TextColor3 = Color3.new(1,1,1); b.Text = text
      local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = b
      local g = Instance.new("UIGradient"); g.Rotation = 90
      g.Color = ColorSequence.new(theme.Top, theme.Bottom); g.Parent = b
      local border = Instance.new("UIStroke")
      border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      border.BorderStrokePosition = Enum.BorderStrokePosition.Outer  -- 2025 API
      border.Thickness = 3; border.Color = theme.Outline; border.Parent = b
      local textStroke = Instance.new("UIStroke")                 -- Contextual = text outline
      textStroke.Thickness = 2.5; textStroke.Color = theme.Outline; textStroke.Parent = b
      local sh = Instance.new("UIShadow")                          -- 2026 API
      sh.Offset = UDim2.fromOffset(0, 5); sh.BlurRadius = UDim.new(0, 2)
      sh.Color = theme.Outline; sh.Transparency = 0.2; sh.ZIndex = -1; sh.Parent = b
      local s = Instance.new("UIScale"); s.Parent = b              -- for press/hover juice
      b.Parent = parent
      return b, s
  end
  ```
- **Stroke scaling choice.** Under a UIScale-driven HUD, keep strokes on `FixedSize`, because UIScale already multiplies them per the docs. Use `ScaledSize` for Scale-sized elements that are not under a UIScale, such as BillboardGuis. Avoid mixing the two until the bug threads above are confirmed fixed.
- **Fonts for Hood.** Replace `Enum.Font.GothamBold`/`GothamBlack` (9 + 5 uses) with an explicit `Font.new(".../BuilderSans.json", Enum.FontWeight.Bold or .Heavy)` or a Montserrat FontFace. They already render as Montserrat silently, so this makes the intent explicit and allows weights. Keep FredokaOne or LuckiestGuy for display numbers and titles via `FontFace`.
- **Shine sweep** works by tweening a UIGradient `Offset` from (-1,0) to (1,0) with a narrow transparent-opaque-transparent sequence. See section 4 for code.
- **CanvasGroup** is best for one-off fades of whole popups, using `GroupTransparency` for open/close. Do not use it per list item or per button.

### Gaps
- Exact release dates: the UIStroke announcement appears to date to about 2025-09-25, judging by an X post linking the thread ([FracturedSkies on X](https://x.com/FracturedSkies_/status/1971289488497443238), date derived from post ID). The Full Release date and the UIShadow/individual-corner release dates were not confirmed, and the docs and DevForum disagree on beta status (see above).
- The UIGradient `Type`/`Scale`/`TileMode` "NotBrowsable" tag may mean they are still gated. I could not confirm from an announcement.
- Custom font upload (bringing your own .ttf/.otf) is not documented in creator-docs as of the snapshot. `Font.fromId` takes a font-family asset ID, but I found no official upload workflow.
- Performance cost of UIShadow (blur) per element is undocumented.

---

## 3. Reusable UI component kit in Luau: theme tables, factories, state; libraries (Fusion, React-lua, Vide) vs vanilla; Roblox's StyleSheet system

### Takeaway
For a code-built simulator HUD, a vanilla-Luau kit is the pragmatic default:
- a `Theme` module of tokens
- small factory functions that return instances plus a cleanup handle
- a tiny signal/state store

Reactive libraries (Fusion, Vide, React-lua) are mature but add a learning curve. Roblox's own **StyleSheet/StyleRule** engine feature now covers theming, hover states, breakpoints and transitions natively, and it works from code.

### Cited Findings

**Roblox UI Styling (engine-level, CSS-like)**
- Concepts:
  - `StyleSheet` aggregates `StyleRule`s.
  - `StyleRule.Selector` targets class (`"Frame"`), tag (`".ButtonPrimary"` via CollectionService), name (`"#Name"`), modifiers (`"::UICorner"`), states (`":Hover"`, from `Enum.GuiState`) and queries (`"@Name"`).
  - Tokens are attributes on a token StyleSheet referenced as `"$Token"`.
  - Themes are StyleSheets that derive tokens via `StyleDerive`.
  - A `StyleLink` links one StyleSheet to a ScreenGui tree ("Only one StyleSheet can apply to a given tree").
  - `StyleRule.Priority` resolves conflicts.

  — [UI styling](https://create.roblox.com/docs/ui/styling), [StyleRule](https://create.roblox.com/docs/reference/engine/classes/StyleRule), [StyleSheet](https://create.roblox.com/docs/reference/engine/classes/StyleSheet)
- Code API: `rule:SetProperties({BackgroundColor3 = "$FrameColor", Size = "$FrameSize"})`, `tokens:SetAttribute("Gold", Color3.fromHex("FFCC00"))`, `rule:SetPropertyTransitions({BackgroundColor3 = TweenInfo.new(1, Enum.EasingStyle.Cubic), Rotation = TweenInfo.new(1.25, …)})`, and `hoverRule.Selector = "TextButton:Hover"`. — [UI styling](https://create.roblox.com/docs/ui/styling), [CSS comparisons](https://create.roblox.com/docs/ui/styling/css-comparisons)
- `StyleQuery` sets conditions such as `"MinSize"`, `"MaxSize"` and `"PreferredInput"`. For example, `queryCondition.Selector = "::StyleQuery #WideContainer"` with `SetProperty("MinSize", Vector2.new(400,0))` enables rules like `"@WideContainer Frame > TextButton"`.
- Built-in queries: `@ViewportDisplaySizeSmall`, `@ViewportDisplaySizeMedium`, `@ViewportDisplaySizeLarge`, `@PreferredInputKeyboardAndMouse`, `@PreferredInputTouch`, `@PreferredInputGamepad`, `@ReducedMotionEnabledTrue` and `@ReducedMotionEnabledFalse`.

  — [CSS comparisons](https://create.roblox.com/docs/ui/styling/css-comparisons), [StyleQuery](https://create.roblox.com/docs/reference/engine/classes/StyleQuery)
- Roblox's cross-platform guide recommends the Style Editor and queries for both ViewportDisplaySize and PreferredInput. — [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform)

**Libraries**
- **Roact is deprecated.** A DevForum tutorial is titled "Roact UI Framework Crash Course (Deprecated)." **React-lua** is "a comprehensive, but not exhaustive, translation of upstream ReactJS 17.x into Lua." The community fork `jsdotlua/react-lua` aims to be "the Roblox and global Lua community go-to for React in Lua," and Roblox keeps a read-only mirror, `Roblox/react-luau`. — [DevForum: Roact crash course (Deprecated)](https://devforum.roblox.com/t/roact-ui-framework-crash-course-deprecated/796618), [jsdotlua/react-lua README](https://github.com/jsdotlua/react-lua), [Roblox/react-luau](https://github.com/Roblox/react-luau)
- **Fusion** is "A modern reactive UI library, built specifically for Roblox and Luau." Its main branch `wally.toml` version is `0.4.0-dev1`. — [Fusion wally.toml](https://github.com/dphfox/Fusion/blob/main/wally.toml)
- **Vide** is "a reactive Luau UI library inspired by Solid," "Fully Luau typecheckable," version `0.4.1`. API sample: `create "TextButton" { Text = function() return "count: "..count() end, Activated = function() count(count()+1) end }`. — [Vide README](https://github.com/centau/vide), [Vide wally.toml](https://github.com/centau/vide/blob/main/wally.toml)
- Community opinion (search snippet of a DevForum thread, not read in full): "Roblox isn't the web… frameworks like Fusion and Vide provide much better solutions specific to Roblox." — [DevForum: Use case for Fusion / React etc](https://devforum.roblox.com/t/use-case-for-fusion-react-etc/3663300)

### Inferences
- **What simulator devs actually use.** I found no survey data. Anecdotally, given the deprecation and learning-curve discussion and the tooling here, most simulator-genre teams build UI in Studio or plain Luau with TweenService and a handful of utility modules. Larger studios use React-lua (Roblox uses it internally for its own app UI) or Fusion/Vide. For Hood's code-built HUD, a vanilla kit gets about 90% of the benefit without a dependency.
- **Recommended vanilla kit shape:**
  ```lua
  -- ReplicatedStorage/UIKit/Theme.lua
  return {
      Font = { Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
               Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold) },
      Color = { Outline = Color3.fromRGB(28, 20, 45), Coin = Color3.fromRGB(255, 205, 40),
                GreenTop = Color3.fromRGB(120, 230, 90), GreenBottom = Color3.fromRGB(40, 170, 60) },
      Radius = { S = UDim.new(0, 8), M = UDim.new(0, 14), Pill = UDim.new(0.5, 0) },
      Stroke = { Text = 2.5, Border = 3 },
      Motion = { Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                 Release = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                 Open = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                 Close = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In) },
  }
  ```
  ```lua
  -- UIKit/create.lua : tiny declarative helper (no library)
  local function create(className, props, children)
      local inst = Instance.new(className)
      for k, v in props do
          if typeof(v) == "RBXScriptSignal" then continue end
          if k ~= "Parent" then inst[k] = v end
      end
      for _, child in children or {} do child.Parent = inst end
      if props.Parent then inst.Parent = props.Parent end   -- parent last (one layout pass)
      return inst
  end
  return create
  ```
  Component factories (`Button(props)`, `Panel(props)`, `CurrencyPill(props)`, `Toast(props)`) should return `(instance, api)`, where `api` has `:Set(value)` and `:Destroy()`. Use a minimal `Value` object (a get/set plus a changed signal) for state such as coins and gems, so the HUD updates on change and never polls.
- **Hybrid option.** Use the engine StyleSheet for global tokens and hover/press/breakpoint rules, with tags such as `.Primary` and `.Pill`, and Luau factories only for structure and behavior. This puts theme tweaks in one place and gets `@PreferredInputTouch`/`@ViewportDisplaySizeSmall` layout swaps without code. One caveat is that a StyleRule transition and a script TweenService tween on the same property will fight. Pick one owner per property.

### Gaps
- No quantitative data (download counts or a survey) on framework adoption among top simulators.
- I did not verify Fusion's latest *stable* tag (the main branch says 0.4.0-dev1) or React-lua's current release.
- How stable the StyleSheet system is for production, and its performance at scale, were not covered by an announcement I could read.

---

## 4. UI motion / "juice": TweenService patterns, UIScale press/hover, popups, counters, shine sweeps, toasts, springs, tween conflicts, per-frame updates

### Takeaway
Use **TweenService on a child UIScale** (not `Size`) for press and pop effects, `Back` Out easing for "overshoot" opens, and `Quad`/`Quint` for closes. Animate a NumberValue for count-ups and UIGradient `Offset` for shines. For interruptible, continuously retargeted motion, use springs: `spr`, or the built-in `TweenService:SmoothDamp` for critically damped motion. Roblox cancels a running tween when a new tween targets the same property, so let one controller own each property.

### Cited Findings
- `TweenService:Create(instance, TweenInfo, goals)` tweens number, boolean, CFrame, Rect, Color3, UDim, UDim2, Vector2, Vector2int16, Vector3 and EnumItem values. "If two tweens attempt to modify the same property, the initial tween will be cancelled and overwritten by the most recent tween." — [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- `TweenService:GetValue(alpha, EasingStyle, EasingDirection)` returns an eased alpha clamped 0–1, which is handy for custom per-frame animations. — [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- **New:** `TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)` "simulat[es] a critically damped spring" and returns `(newValue, newVelocity)`. Feed the velocity back in on the next call. It supports number, Vector2, Vector3 and CFrame. — [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- The default `EasingStyle` is `Quad` and the default `EasingDirection` is `Out`. Chain tweens via `tween.Completed:Connect(...)`. For size tweens, Roblox adds a UIAspectRatioConstraint and uses Scale targets. Placing UI in a CanvasGroup lets you tween `GroupTransparency`/`GroupColor3` for the whole group. — [UI animation](https://create.roblox.com/docs/ui/animation)
- **Style transitions** can also animate properties when StyleRule states change (e.g. `:Hover`) via `SetPropertyTransitions`. — [UI animation](https://create.roblox.com/docs/ui/animation), [CSS comparisons](https://create.roblox.com/docs/ui/styling/css-comparisons)
- UIScale "is also useful to tween the size of an object, for example to slightly increase the size of a button" on hover. — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- Avoid tweening UIStroke Thickness on text (glyph cache churn, flicker). — [UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke)
- Typewriter: animate `MaxVisibleGraphemes` over `utf8.graphemes(text)`. — [UI animation](https://create.roblox.com/docs/ui/animation)
- **spr** (Fraktality): `spr.target(obj, dampingRatio, undampedFrequency, {Prop = goal})`, `spr.stop(obj, prop?)` and `spr.completed(obj, cb)`.
  - A damping ratio below 1 overshoots ("recommended for animations that need extra pop"), exactly 1 is critical ("most visually neutral"), and above 1 is overdamped.
  - It animates Color3 in CIELUV space.
  - Supported types: boolean, CFrame, Color3, ColorSequence, number, NumberRange, UDim, UDim2, Vector2, Vector3.
  - Example: `spr.target(frame, 0.6, 4, {Position = UDim2.fromScale(0.5,0.5)})` "overshoots, and wobbles."

  — [spr README](https://github.com/Fraktality/spr)
- **RbxUtil Spring** (Sleitnick) "Simulates a critically damped spring. This is mostly just a wrapper around `TweenService:SmoothDamp()`." Call `spring:Update(dt)` every frame. — [RbxUtil spring source](https://github.com/Sleitnick/RbxUtil/blob/main/modules/spring/init.luau)
- Other spring modules: Quenty's NevermoreEngine `Spring` and DervexDev's `AdvancedSpring` (UDim2, CFrame and others). — [Nevermore Spring docs](https://quenty.github.io/NevermoreEngine/api/Spring/), [AdvancedSpring](https://github.com/DervexDev/AdvancedSpring)
- `RunService.RenderStepped` "has been superseded by `RunService.PreRender`, which should be used for new work." PreRender fires before each frame renders with `deltaTimeRender`. — [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- Microprofiler: TweenService has its own per-frame update step. **UpdateUILayouts/Layout** cost grows with "UI elements being resized or repositioned, such as those managed by UILayout and those tweened with TweenService." Roblox recommends fixed sizes where possible. — [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)
- Accessibility: `GuiService.ReducedMotionEnabled` maps to the player's Reduce Motion toggle. There is also a built-in `@ReducedMotionEnabledTrue` style query. — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService), [CSS comparisons](https://create.roblox.com/docs/ui/styling/css-comparisons)

### Inferences
These are implementation patterns built on the cited APIs. The durations and easings are common practice, not official values.

- **Button press/hover via UIScale** (avoids layout reflow because the layout uses the un-scaled Size):
  ```lua
  local TS = game:GetService("TweenService")
  local function bindJuice(button: GuiButton, uiScale: UIScale)
      local function to(s, info) TS:Create(uiScale, info, {Scale = s}):Play() end -- new tween auto-cancels old
      local fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
      local pop  = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
      button.MouseEnter:Connect(function() to(1.06, pop) end)
      button.MouseLeave:Connect(function() to(1.00, pop) end)
      button.MouseButton1Down:Connect(function() to(0.92, fast) end)
      button.MouseButton1Up:Connect(function() to(1.06, pop) end)
      button.Activated:Connect(function() -- play click SFX here
      end)
  end
  ```
  Alternatively, read `button.GuiState` (Idle/Hover/Press/NonInteractable) via `GetPropertyChangedSignal("GuiState")`. That unifies mouse, touch and gamepad, though the GuiState → Hover mapping for gamepad selection is not documented.
- **Popup open/close** (scale from 0.6 with Back Out, plus fade via CanvasGroup; close with a short Quad In):
  ```lua
  local function openPopup(group: CanvasGroup, scale: UIScale)
      group.Visible = true; group.GroupTransparency = 1; scale.Scale = 0.6
      TS:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
      TS:Create(group, TweenInfo.new(0.2), {GroupTransparency = 0}):Play()
  end
  local function closePopup(group: CanvasGroup, scale: UIScale)
      local t = TS:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.8})
      TS:Create(group, TweenInfo.new(0.15), {GroupTransparency = 1}):Play()
      t.Completed:Once(function(state) if state == Enum.PlaybackState.Completed then group.Visible = false end end)
      t:Play()
  end
  ```
  The `Completed` state check matters. If a reopen cancels the close tween, the popup must not be hidden afterward.
- **Number tick-up counter** (tween a NumberValue and format on Changed, with a punch on the label's UIScale):
  ```lua
  local function makeCounter(label: TextLabel, punch: UIScale)
      local nv = Instance.new("NumberValue")
      nv.Changed:Connect(function(v) label.Text = string.format("%d", math.floor(v + 0.5)) end)
      return function(target: number)
          TS:Create(nv, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Value = target}):Play()
          punch.Scale = 1.25
          TS:Create(punch, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
      end
  end
  ```
  Add abbreviations (1.2K, 3.4M) in the formatter for simulator-scale numbers.
- **Shine sweep** (UIGradient Offset; the transparency sequence makes a narrow bright band):
  ```lua
  local shine = Instance.new("UIGradient")
  shine.Rotation = 20
  shine.Transparency = NumberSequence.new({
      NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1),
      NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.55, 1),
      NumberSequenceKeypoint.new(1, 1)})
  -- Put shine on a white overlay Frame (BackgroundTransparency 0) above the button so it doesn't replace the fill gradient
  shine.Offset = Vector2.new(-1, 0); shine.Parent = overlay
  task.spawn(function()
      while overlay.Parent do
          shine.Offset = Vector2.new(-1, 0)
          TS:Create(shine, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {Offset = Vector2.new(1, 0)}):Play()
          task.wait(2.5)
      end
  end)
  ```
  This works because `Offset` (1,0) shifts the gradient by one full width. A GuiObject takes only one UIGradient for its fill, so the shine needs its own overlay frame. The overlay must use matching UICorner radii, or ClipsDescendants inside a rounded parent (note that UICorner clips input but not descendants).
- **Toast notifications.** Put a UIListLayout (VerticalAlignment Top, Padding 8) inside a top-center container. Each toast is a Frame with an inner content frame. Tween the inner frame's UIScale 0 → 1 with Back Out (about 0.3 s), hold 2–3 s, then fade via the TextTransparency/UIStroke Transparency tween and Destroy. The layout reflows the rest. Animate the inner child, not the layout-controlled frame, because layouts own Position.
- **Springs vs tweens.**
  - Tweens fit fire-and-forget transitions.
  - Springs (`spr.target(scale, 0.5, 5, {Scale = 1})`) fit continuously retargeted values such as hover, drag, follow-cursor, or a bar chasing a value. They preserve velocity on retarget, while tweens restart from zero velocity, which looks jerky on rapid taps.
  - For critically damped only, use `TweenService:SmoothDamp` in a `RunService.PreRender` loop to avoid a dependency.
- **Conflict avoidance.** Use one tween "owner" per (instance, property). Keep a table `active[inst][prop] = tween` and `:Cancel()` it explicitly if you need deterministic callbacks. Never tween the same property from both a StyleRule transition and a script.
- **Many elements.** Prefer animating `UIScale.Scale`, `Rotation`, transparencies or a gradient `Offset`, which do not change layout, over `Size`/`Position` of layout-managed items, because those trigger the UpdateUILayouts cost Roblox flags. Do not tween TextSize; use UIScale (by analogy with the documented glyph-cache issue for stroke thickness). Respect `ReducedMotionEnabled` by swapping Back/Elastic for short Quad fades.

### Gaps
- No official Roblox numbers on how many concurrent tweens or springs are "too many." The guidance is qualitative (MicroProfiler).
- Whether `Elastic` easing is recommended in Roblox docs for UI: not addressed. Durations above are practitioner conventions, not documented.

---

## 5. Viewports & 3D in UI: ViewportFrame for pet/outfit previews, lighting, WorldModel, cost

### Takeaway
A ViewportFrame needs its own `Camera` (set as `CurrentCamera`), a cloned model, and the lighting properties `Ambient`, `LightColor` and `LightDirection`. Animated rigs must sit inside a `WorldModel`. ViewportFrames skip shadows and post-FX and render Neon/Glass at lowest quality. Create them on demand and destroy them when hidden.

### Cited Findings
- **Caveats:** no shadows or post-processing; `Neon`/`Glass` at lowest quality; nested GuiObjects are not supported; lighting acts as if `EnvironmentSpecularScale`/`EnvironmentDiffuseScale` = 0, unless there is a `Sky` child (cubemap reflections, which then act like 1). — [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame)
- **Lighting defaults:** `Ambient` is `Color3.fromRGB(200,200,200)`, `LightColor` is `Color3.fromRGB(140,140,140)` and `LightDirection` is `Vector3.new(-1,-1,-1)`. `ImageColor3` and `ImageTransparency` tint and fade the rendered result. — [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), [Viewport frames guide](https://create.roblox.com/docs/ui/viewport-frames)
- `CurrentCamera` defaults to nil. Cameras do not replicate, but the camera's CFrame/FOV are saved with the ViewportFrame. To update the view, "update the camera, **not** the objects." — [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), [Viewport frames guide](https://create.roblox.com/docs/ui/viewport-frames)
- Official rotating-object sample: create `Camera` with `FieldOfView = 50` and parent it to the ViewportFrame. The object is placed at the origin pitched 40°, and the camera orbits at distance 10 via `RunService.PostSimulation` using `CFrame.Angles(0, math.rad(t*speed), 0) * CFrame.new(0,0,dist)`. — [Viewport frames guide](https://create.roblox.com/docs/ui/viewport-frames)
- `WorldModel` inside a ViewportFrame lets parts be animated and spatially queried (not simulated), and "you can put Humanoid characters in the WorldModel and their joints will be set up correctly for animation." "To avoid possible performance issues… only create WorldModels when you want to show them and… delete WorldModels that are currently not in use." — [WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel)

### Inferences
- **Pet card preview pattern:**
  ```lua
  local function petViewport(parent: GuiObject, petModel: Model)
      local vf = Instance.new("ViewportFrame")
      vf.Size = UDim2.fromScale(1, 1); vf.BackgroundTransparency = 1
      vf.Ambient = Color3.fromRGB(210, 210, 220)     -- brighter = more "cartoony/flat"
      vf.LightColor = Color3.fromRGB(255, 245, 230)
      vf.LightDirection = Vector3.new(-0.3, -1, -0.5)
      local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vf
      vf.CurrentCamera = cam
      local m = petModel:Clone(); m:PivotTo(CFrame.new()); m.Parent = vf
      local _, size = m:GetBoundingBox()
      local dist = (size.Magnitude / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.1
      cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.15, dist), Vector3.zero)
      vf.Parent = parent
      return vf
  end
  ```
  The lower FOV (about 30) reduces perspective distortion for product-shot looks, and the bounding-box fit generalizes across pet sizes. Both are practitioner conventions.
- **Cost control for inventories.** Grids with dozens of pets should use static ViewportFrames: no per-frame camera updates for off-screen items, and only rotate the hovered/selected one. Better still, use pre-rendered ImageLabel thumbnails for the grid and a single live ViewportFrame (with WorldModel for idle animation) in the detail panel. Destroy WorldModels when the panel closes, per Roblox's guidance.
- For outfit or avatar previews, put a cloned character with a `Humanoid` + `Animator` in a `WorldModel` and play animations on it there.

### Gaps
- No official per-ViewportFrame cost numbers (GPU/memory) were found. The docs only warn about WorldModel lifetime.

---

## 6. Input & platform: PreferredInput, TouchEnabled/GamepadEnabled, GuiService and gamepad selection, ProximityPrompt custom UI, BillboardGui

### Takeaway
Branch UI on **`UserInputService.PreferredInput`** (the new, recommended signal) instead of `TouchEnabled`/`GamepadEnabled`, and listen for changes. Make every button gamepad-selectable. Use `ProximityPrompt.Style = Custom` with `ProximityPromptService.PromptShown`/`PromptHidden` for branded prompts. For world labels, size BillboardGuis in Offset (constant pixels) or Scale (studs) on purpose, and set `MaxDistance`.

### Cited Findings

**PreferredInput**
- `UserInputService.PreferredInput` (read-only) reports the **primary** input: `KeyboardAndMouse`, `Gamepad`, `Touch` or `MicroGamepad` (a thumbstick-less remote). It "changes based on built-in device inputs and the player's most recent interaction." Examples: a phone with a Bluetooth keyboard gives KeyboardAndMouse; a tablet with a gamepad gives Gamepad; a console where KBM was last used gives KeyboardAndMouse. — [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService), [PreferredInput enum](https://create.roblox.com/docs/reference/engine/enums/PreferredInput)
- `TouchEnabled`, `GamepadEnabled`, `KeyboardEnabled` and `MouseEnabled` still exist, but each doc now says: "For seamless cross-platform compatibility on mixed-input devices, see PreferredInput which more accurately reflects… the primary input." — [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService)
- Official detection snippet: read `PreferredInput` once, then `UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(...)`. — [Input overview](https://create.roblox.com/docs/input)
- With the Input Action System, `InputAction.PreferredBinding` complements this. `InputActionLabel` auto-shows the right key or button glyph. `UserInputService:GetImageForKeyCode()`/`GetStringForKeyCode()` give platform glyphs (Xbox vs PlayStation). — [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform)

**Gamepad selection / GuiService**
- `GuiService.SelectedObject` is the currently focused GuiObject. `GuiNavigationEnabled` toggles default controller navigation. `AutoSelectGuiEnabled` lets Select or Backslash auto-pick a GUI. — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)
- `GuiObject.Selectable`, `NextSelectionUp`/`Down`/`Left`/`Right`, `SelectionImageObject` (custom highlight, best sized with Scale) and `SelectionOrder` (lower is selected first when starting selection or calling `GuiService:Select(ancestor)`). — [GuiObject](https://create.roblox.com/docs/reference/engine/classes/GuiObject)
- `GuiButton.Activated` fires on left-click release, touch release, or A/Cross in UI navigation, so use it rather than `MouseButton1Click` for cross-platform. — [GuiButton](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
- `GuiObject.GuiState` is Idle, Hover, Press or NonInteractable. `Interactable = false` disables a button and locks the state to NonInteractable. — [GuiObject](https://create.roblox.com/docs/reference/engine/classes/GuiObject)
- Console guidance: design for `ViewportDisplaySize.Large`, respect TV-safe areas, consider bespoke controller navigation, and add UI navigation sound effects. — [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines)
- Player preferences to respect: `GuiService.PreferredTextSize`, `PreferredTransparency` (multiply your BackgroundTransparency by it) and `ReducedMotionEnabled`. — [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)

**ProximityPrompt custom UI**
- `Style = Enum.ProximityPromptStyle.Custom` "suppresses the built-in prompt UI." Listen to `PromptShown`/`PromptHidden` (on the prompt or on `ProximityPromptService`, client-side) to create and tear down your UI. `PromptButtonHoldBegan` supports hold-progress bars with non-zero `HoldDuration`. Defaults: `KeyboardKeyCode` = E and `GamepadKeyCode` = ButtonX. `RequiresLineOfSight` hides the prompt when it is occluded. — [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt), [ProximityPromptStyle enum](https://create.roblox.com/docs/reference/engine/enums/ProximityPromptStyle), [Proximity prompts guide](https://create.roblox.com/docs/ui/proximity-prompts)

**BillboardGui**
- `Size` scale components = **studs in 3D** (the label scales with distance), offset = pixels (constant on-screen size).
- `MaxDistance` defaults to inf/0, meaning no limit; Roblox recommends setting it outdoors.
- `AlwaysOnTop` renders over 3D, with colors matching ScreenGui and sharper text on high DPI.
- `LightInfluence` ranges 0–1. `Brightness` ranges 0–1000 and applies when LightInfluence = 0.
- `DistanceLowerLimit`/`DistanceUpperLimit`/`DistanceStep` control scaling with distance.
- `StudsOffset` is camera-relative and `StudsOffsetWorldSpace` uses world axes. `SizeOffset` acts like an anchor.

  — [BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui)
- MicroProfiler: to cut adorn rendering cost, "Reduce the number of visible adorned objects, such as BillboardGuis, Humanoid name/health labels." — [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)

### Inferences
- **Input-adaptive HUD:**
  ```lua
  local UIS = game:GetService("UserInputService")
  local function applyInputMode()
      local p = UIS.PreferredInput
      mobileButtons.Visible = (p == Enum.PreferredInput.Touch)
      keyHints.Visible = (p == Enum.PreferredInput.KeyboardAndMouse)
      padHints.Visible = (p == Enum.PreferredInput.Gamepad or p == Enum.PreferredInput.MicroGamepad)
  end
  applyInputMode()
  UIS:GetPropertyChangedSignal("PreferredInput"):Connect(applyInputMode)
  ```
  When a menu opens and PreferredInput is Gamepad, call `GuiService:Select(menuFrame)` (or set `SelectedObject` to the primary button) and give buttons a themed `SelectionImageObject` (a rounded Frame with UIStroke).
- **Custom prompt:** set `Style = Custom` on server-created prompts. In a client LocalScript, on `ProximityPromptService.PromptShown(prompt, inputType)`, clone a BillboardGui template (Offset size so it stays crisp, `AlwaysOnTop = true`, `LightInfluence = 0`) adorned to `prompt.Parent`. Show the key glyph from `UIS:GetImageForKeyCode(prompt.GamepadKeyCode)` or `prompt.KeyboardKeyCode.Name`, animate it in with the UIScale pop, and drive a hold ring from `PromptButtonHoldBegan`/`Ended` with a tween of duration `HoldDuration`.
- **BillboardGui recipes:**
  - Nameplates and price tags: Offset size, `AlwaysOnTop = true`, `LightInfluence = 0`, `MaxDistance` about 60–120 studs, `StudsOffset = (0, 3, 0)`.
  - Diegetic signs that should shrink with distance: Scale size (studs) with `TextScaled` plus a `UITextSizeConstraint`, which is the documented good use of TextScaled.

### Gaps
- Whether `GuiState` reports `Hover` while an element is gamepad-selected is not stated in the docs, so cross-input hover styling via GuiState should be tested.
- `MicroGamepad` is relatively new. I found no guidance on which devices emit it beyond "a TV remote or another limited-input gamepad."

---

## 7. Common UI performance & correctness pitfalls

### Takeaway
The big wins, roughly in order of impact:
1. Do not rebuild or reparent UI every frame. Create it once and update properties.
2. Keep animated elements away from big static trees.
3. Limit UIGradient/UICorner/UIStroke on text.
4. Use CanvasGroups sparingly and at static sizes.
5. Parent a code-built HUD with `ResetOnSpawn = false`.
6. Animate UIScale/transparency rather than Size/Position of layout children.

### Cited Findings
- **ScreenGui caching:** a ScreenGui's appearance "is cached until… a descendant is added to or removed from it; a property of a descendant changes; a property of the ScreenGui itself changes," and it is then "recomputed on the next frame." — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- **Rebuild Z-order list** runs "on first render or when a new element is added, removed, or had its ZIndex changed." Roblox advises reducing element counts "before first render and avoid frequently changing the parent and ZIndex of UI elements." — [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)
- **Perform/fillGuiVertices:** "If there are too many **Process GuiEffect** labels, consider reducing the use of UIGradient and UICorner on text labels." Elsewhere: "Reduce the number of visible UI elements. Using CanvasGroups can help at the expense of increased memory use." — [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)
- **UpdateUILayouts/Layout:** reduce UI elements being resized or repositioned, including UILayout-managed and TweenService-tweened ones, and consider fixed sizes. — [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table)
- **CanvasGroup:** extra texture memory, capped by QualityLevel; renders **blank** past the cap; recommend static sizes. Community reports cover a 1024² cap per group, down-res at low graphics levels, and nested groups exhausting memory. — [CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup), [DevForum: many CanvasGroups unworkable](https://devforum.roblox.com/t/using-many-canvasgroups-is-unworkable-until-proper-memory-management-methods-are-implemented/3502537)
- **UIStroke on text:** do not tween Thickness (glyph re-rasterization, flicker). — [UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke)
- **ResetOnSpawn:** it defaults to true, so the ScreenGui is deleted and re-cloned on every respawn. It also resets if the ScreenGui is an *indirect* descendant of StarterGui (e.g. in a Folder). Only `ResetOnSpawn = false` **and** being a direct child of StarterGui prevents the reset. — [On-screen UI containers](https://create.roblox.com/docs/ui/on-screen-containers)
- StarterGui contents are not cloned until `LoadCharacterAsync()` if `Players.CharacterAutoLoads` is disabled. — [On-screen UI containers](https://create.roblox.com/docs/ui/on-screen-containers)
- Toggle whole screens with `ScreenGui.Enabled` (contents do not render while false) and layer them with `DisplayOrder`. — [On-screen UI containers](https://create.roblox.com/docs/ui/on-screen-containers)
- **Layout overrides:** UISizeConstraint and UIAspectRatioConstraint override UIListLayout sizing, a common "why is my list item the wrong size" bug. — [Size modifiers](https://create.roblox.com/docs/ui/size-modifiers)
- **UICorner** on ScrollingFrame is unsupported, and UICorner clips input but not descendants. — [UICorner](https://create.roblox.com/docs/reference/engine/classes/UICorner)
- **Images:** limit pixel dimensions (≤512, minor ≤256) and use sprite sheets via `ImageRectOffset`/`ImageRectSize`. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- **Legacy API flags:** `RunService.RenderStepped` is superseded by `PreRender`; `Enum.Font.Gotham*`/`Arial*` are removed and remapped; prefer `FontFace`. `GuiObject:TweenSize()`/`TweenPosition()` still appear in the MicroProfiler docs, but TweenService is the documented path. Roact is deprecated in favor of React-lua. — [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService), [Font enum](https://create.roblox.com/docs/reference/engine/enums/Font), [MicroProfiler tag table](https://create.roblox.com/docs/performance-optimization/microprofiler/tag-table), [DevForum: Roact (Deprecated)](https://devforum.roblox.com/t/roact-ui-framework-crash-course-deprecated/796618)
- **SafeAreaCompatibility** `FullscreenExtension` (the default) silently transforms "fullscreen" frames. Roblox recommends ScreenInsets for new work. — [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui)
- **GetGuiInset** may return zero on the first frame (community bug report). — [DevForum](https://devforum.roblox.com/t/guiservicegetguiinset-returns-0000-at-first/3472295)

### Inferences
- **Code-built HUD lifecycle.** Hood builds its HUD from LocalScripts in `StarterPlayerScripts`, which run once per session. So create ScreenGuis with `ResetOnSpawn = false`, parent them to `PlayerGui`, and rebind character-dependent bits on `CharacterAdded`. The repo already sets `ResetOnSpawn = false` 8 times; keep that consistent.
- **Split ScreenGuis by update frequency.** Combine the cache-invalidation rule (any descendant property change recomputes the ScreenGui) with the Z-order-rebuild rule. A constantly animating element, such as a shining button, a ticking timer or a spinning icon, should live in its own small ScreenGui. That avoids invalidating a large static HUD every frame. Concretely: StaticHUD, AnimatedHUD, Popups (higher DisplayOrder) and Toasts.
- **Pool, do not recreate.** For toasts, damage numbers and inventory cells, keep a pool of pre-built frames and toggle `Visible` and text. Do not `Instance.new` and `Destroy` per event, and never per frame.
- **Budget decorations.** Use UIStroke/UIGradient on container frames rather than on every text label in a 100-item grid. For long lists, prefer one baked 9-slice image per cell, or a single stroke on the card, and plain text with one Contextual stroke.
- **Use CanvasGroup only for transient whole-panel fades.** Set `GroupTransparency` back to 0 at rest. Never use it inside scrolling inventory items, and never nest them.
- **Test matrix.** Use Studio Device Emulator (phone, tablet, 4K TV), the Controller Emulator, and graphics quality ≤3, because CanvasGroup quality drops there. Roblox recommends device emulation in the [Cross-platform guide](https://create.roblox.com/docs/projects/cross-platform).

### Gaps
- No official per-instance cost figures exist for UIStroke, UIGradient, UIShadow or UICorner, only the qualitative MicroProfiler advice.
- I found no authoritative statement on whether hiding a GuiObject via `Visible = false` fully skips its GuiEffect processing, compared with `ScreenGui.Enabled = false`, which the docs say stops rendering.
- DevForum thread bodies (UIStroke and New UI Capabilities announcements, CanvasGroup threads, framework-usage discussions) were inaccessible. Claims from them rest on search snippets and titles only and should be spot-checked.
