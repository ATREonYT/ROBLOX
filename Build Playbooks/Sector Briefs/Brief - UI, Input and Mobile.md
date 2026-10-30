---
tags: [sector-brief, ui, ux, input, mobile, controller, accessibility, cartoony-ui]
updated: 2026-10-30
---
# Brief - UI, Input and Mobile
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - **Repo rule first:** UI lives in `StarterGui` as real parts. Code builds it once, the place build saves it as `src/StarterGui/<Gui>.rbxm`, and runtime scripts reuse those parts. Use the `roblox-cartoony-ui` skill for every screen, and compare it side by side with the owner's reference.
> - **Toy look, native parts:** `UICorner` + vertical `UIGradient` + `UIStroke` (Border, Outer) + text `UIStroke` + `UIShadow` (Shape mode). `UIShadow` and per-corner `UICorner` radii are **live** (full release June 23, 2026).
> - **Do not ship betas:** the upgraded `UIShadow` features (text, inset, knockout, gradient shadows) and the upgraded `UIGradient` features (Radial, Conical, Elliptical, `TileMode`, `Scale`) are **Studio beta**. Live games can't be published with them.
> - **Input:** `GuiButton.Activated` for every UI button. New gameplay input uses the **Input Action System** (`InputContext` / `InputAction` / `InputBinding`). Roblox now says `ContextActionService` binding methods are "planned for deprecation".
> - **Device:** decide layout from `UserInputService.PreferredInput` and `GuiService.ViewportDisplaySize`, never from `TouchEnabled` alone. Every `ScreenGui` sets `ScreenInsets` on purpose.
> - **Text:** `FontFace` with a built-in rounded family (FredokaOne, LuckiestGuy). No Gotham (it now renders Montserrat). No `TextScaled` on content text: it ignores the player's Text Size setting.
> - **Kids:** 44 px tap targets, 12 px minimum drawn text on phones, colour plus icon (never colour alone), at most 1 flash per second, respect `GuiService.ReducedMotionEnabled`.
> - **Server owns the result:** a button only asks. The server checks price, cooldown and ownership, then grants.

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status Oct 30, 2026 | What we do | Source |
|---|---|---|---|
| `UIShadow` (BlurRadius, Color, Enabled, Offset, Spread, Transparency, ZIndex) | **Live** since June 23, 2026 | Use for toy-button lips and drop shadows instead of 9-slice shadow images | DevForum (Jun 23, 2026) |
| `UICorner.TopLeftRadius` / `TopRightRadius` / `BottomLeftRadius` / `BottomRightRadius` | **Live** since June 23, 2026; `CornerRadius` still sets all four | Tabs with only the top corners round | DevForum (Jun 23, 2026) |
| Upgraded UIShadow: `Mode = Enum.ApplyShadowMode.Text`, `Inset`, `ShowBehindParent = false` (knockout), child `UIGradient` | **Studio beta** (File > Beta Features > Upgraded UIShadows), announced Oct 14, 2026. "You can't publish live experiences" with it | Prototype only. Keep text outlines on `UIStroke` | DevForum (Oct 14, 2026); Roblox docs |
| Upgraded UIGradients: `Type` Radial / Conical / Elliptical, `TileMode` (Clamp, Repeat, Mirror), `Scale`, Path2D | **Studio beta** since Sept 2, 2026. Can't publish live games with it | Use Linear gradients only in shipped UI | DevForum (Sep 2, 2026); Roblox docs |
| `UIStroke` overhaul: `StrokeSizingMode` (FixedSize, ScaledSize), `BorderStrokePosition` (Outer, Center, Inner), `BorderOffset`, several strokes per object ordered by `ZIndex` | Live (full release late 2025) | Outer border strokes for the toy outline | Roblox docs (appearance modifiers); Vault research note |
| RDC 2026: "UI improvements including blur, text shadows, and improved gradients" | Announced for **late 2026** | Wait for the client release | DevForum (RDC26, Sep 2026) |
| Device Simulator and Network Simulator | **Out of beta** (Oct 2026) | Test every screen at phone sizes and on a slow network | DevForum weekly recap (Oct 12-18, 2026) |
| Input Action System (`InputContext`, `InputAction`, `InputBinding`) | Live. `InputActionLabel` and the Input Action Manager are **beta** | New input goes here | Roblox docs (Input Action System) |
| `ContextActionService:BindAction` and related binding methods | "aren't recommended for new work and are planned for deprecation". `BindActionToInputTypes` is deprecated | Don't add new CAS bindings. Old ones still work | Roblox docs (ContextActionService) |
| `InputAction:Fire()` | **Deprecated**. Use `InputBinding:Fire()` on a Scriptable binding | For tests and scripted input | Roblox docs (InputAction) |
| `UserInputService.ModalEnabled` | Deprecated. Use `GuiService.TouchControlsEnabled` | Hide the thumbstick in cutscenes | Roblox docs (UserInputService) |
| `UserInputService.PreferredInput` | Live: `Touch`, `Gamepad`, `KeyboardAndMouse` | Pick prompts and layouts from it | Roblox docs (UserInputService) |
| `Enum.Font.Gotham*` | Removed. "Using it will map to the Montserrat font family" | Use `FontFace` with a named family | Roblox docs (Enum.Font), via Vault research note |
| `ScreenGui.SafeAreaCompatibility` | Docs: avoid fullscreen extensions for new work, use `ScreenInsets` | Set `SafeAreaCompatibility = None` on new guis | Roblox docs (ScreenGui) |
| `GuiService.IsTenFootInterface()` | Always true on console, but Docs say don't use it to detect console players | Use `GuiService.ViewportDisplaySize` | Roblox docs (GuiService) |

## The recipes (how we build X)

### 1. A screen (HUD, shop, popup)
1. One `ScreenGui` per screen, a **direct child** of `StarterGui` (a Folder in between makes it reset on spawn).
2. `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, `SafeAreaCompatibility = None`.
3. `ScreenInsets`:
   - interactive HUD and menus: `CoreUISafeInsets` (default, stays clear of the top bar and the notch);
   - a custom row beside Roblox's top bar buttons: `TopbarSafeInsets`;
   - full-screen background art only: `None`.
4. `DisplayOrder` bands, written down once (for example HUD 0, menus 10, popups 20, tutorial 40). Never use `ZIndex` to stack screens.
5. One `UIScale` per screen from a single controller, with a floor so phone text stays readable.
6. Code builds it, the place build saves it to `StarterGui` (repo rule 11). At runtime, find it with `PlayerGui:WaitForChild(name)`.

```lua
--!strict
-- Applied by the build code before saving the .rbxm (repo rule: UI is real parts in StarterGui)
local function configureScreen(gui: ScreenGui, displayOrder: number)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.DisplayOrder = displayOrder
end
```

Note: `IgnoreGuiInset = true` is **not** fullscreen. It switches `ScreenInsets` to `DeviceSafeInsets`, which ignores the top bar but still avoids the notch (Roblox docs, ScreenGui). Our `cannon-evolution` HUD uses `IgnoreGuiInset = true`, so check nothing sits under Roblox's top bar buttons.

### 2. The toy button (all native, shippable today)
Order from the skill: outline, lit top, darker lip, hard shadow, press feedback.

```lua
--!strict
type Theme = { top: Color3, bottom: Color3, lip: Color3, outline: Color3 }

local function toyButton(button: TextButton, theme: Theme)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient tints it
	button.FontFace = Font.fromName("FredokaOne")
	button.TextColor3 = Color3.new(1, 1, 1)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10) -- skill: radius 10 on nearly everything
	corner.Parent = button

	local fill = Instance.new("UIGradient") -- Linear only: Radial/Conical are beta
	fill.Rotation = 90
	fill.Color = ColorSequence.new(theme.top, theme.bottom)
	fill.Parent = button

	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	border.Thickness = 3
	border.Color = theme.outline
	border.Parent = button

	local textOutline = Instance.new("UIStroke") -- Contextual = outlines the text
	textOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textOutline.Thickness = 2
	textOutline.Color = theme.outline
	textOutline.Parent = button

	local lip = Instance.new("UIShadow") -- hard darker lip straight down
	lip.Offset = UDim2.fromOffset(0, 5)
	lip.BlurRadius = UDim.new(0, 0)
	lip.Color = theme.lip
	lip.Transparency = 0
	lip.ZIndex = -1 -- shadows only take negative ZIndex
	lip.Parent = button

	local drop = Instance.new("UIShadow") -- soft drop shadow under everything
	drop.Offset = UDim2.fromOffset(0, 8)
	drop.BlurRadius = UDim.new(0, 6)
	drop.Color = Color3.new(0, 0, 0)
	drop.Transparency = 0.6
	drop.ZIndex = -2 -- distinct ZIndex: equal values render in undefined order
	drop.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button
end
```
- Pixel values (10, 3, 2, 5, 8, 6, 0.6) are **Rule of thumb** from the skill and Kek's video, not Roblox numbers. The owner's kit wins.
- Check in Studio that the outer outline wraps the lip the way the reference does. If not, use the skill's darker offset Frame as the lip.
- Rarity = same frame, swap `theme` colours.
- Pill buttons: `CornerRadius = UDim.new(0.5, 0)` (Scale 0.5 or more on the shortest edge gives a pill; Roblox docs).

### 3. Button juice (one LocalScript for all buttons)
- Hover: 0.3 s, Back, Out, grow to about 1.05. Unhover: 0.3-0.5 s, Sine, Out (Video note, PineappleDev).
- Press: quick shrink, then bounce back, plus a click sound.
- Tween a `UIScale`, never `Size`, so `UIListLayout` rows don't jitter.
- Use `Activated` (mouse, touch and gamepad A). The video uses `MouseButton1Click`; don't copy that.

```lua
--!strict
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local HOVER = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local UNHOVER = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function juice(button: GuiButton, onActivated: () -> ())
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
	local function to(info: TweenInfo, value: number)
		if GuiService.ReducedMotionEnabled then
			scale.Scale = 1 -- reduced motion: no bounce, the sound and colour still give feedback
			return
		end
		TweenService:Create(scale, info, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function() to(HOVER, 1.05) end)
	button.MouseLeave:Connect(function() to(UNHOVER, 1) end)
	button.Activated:Connect(function()
		to(PRESS, 0.92)
		task.delay(0.06, function() to(HOVER, 1) end)
		onActivated()
	end)
end
```
- Listen to `PlayerGui.DescendantAdded` so buttons made later get juice too. Skip `TextBox`.
- Never tween `UIStroke.Thickness` on text: Roblox warns it can cause performance problems or flicker (Roblox docs).
- Shine sweep only on the one main call-to-action: tween a Linear `UIGradient.Offset` from (-1, 0) to (1, 0).

### 4. Popups and toasts
- Popup open: `CanvasGroup.GroupTransparency` 1 to 0, plus `UIScale` 0.85 to 1 with Back Out. Close faster with Quad In and no overshoot (Vault: [[UI Motion Language and Timing]]).
- Use `CanvasGroup` per popup, not per list item. It costs texture memory and renders blank past the memory cap (Roblox docs).
- The dark backdrop must be a button (or set `Active`), or clicks fall through to the world (Vault: [[ScreenGui Fundamentals]]).
- Toasts: one queue, the server sends a kind and numbers, the client formats the text. Show a few at a time and merge repeats ("+250 coins x3"). Errors appear next to the control, not as a toast that expires (Vault: [[Notification and Toast Systems]]).
- Kid-safe rule: no fake countdowns or "only 2 left" on toasts. Flashing reward bursts at most once per second.

### 5. Device and layout
```lua
--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local function applyLayout()
	local input = UserInputService.PreferredInput
	local isTouch = input == Enum.PreferredInput.Touch
	local isPad = input == Enum.PreferredInput.Gamepad
	local small = GuiService.ViewportDisplaySize == Enum.DisplaySize.Small
	-- e.g. bigger buttons on touch, button glyphs on gamepad, compact HUD when small
end
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyLayout)
GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(applyLayout)
applyLayout()
```
- Layout with Scale for position, a `UIScale` for size, and `UISizeConstraint` (`MinSize` keeps tap targets, `MaxSize` stops panels growing on monitors).
- Lists and grids: `UIListLayout` with flex (`HorizontalFlex = Fill` for tab bars) and `UIFlexItem` (`FlexMode` Grow, Shrink, Fill) for per-child sizing. `UIGridLayout` for pet grids. `UIPadding` for inner space.
- Thumb zones on phones: main action bottom-right, menu column on the left (proven sim HUD, skill). Keep clear of the jump button and thumbstick.
- `GuiService.TopbarInset` changes at runtime. Listen with `GetPropertyChangedSignal("TopbarInset")`, never read it once.
- `ScrollingFrame` clips the outer `UIStroke` rims of its children, so give them padding. `ClipsDescendants` clips square and ignores `UICorner` (repo `CLAUDE.md`).

### 6. Input with the Input Action System
Setup (Roblox docs):
1. `ReplicatedStorage > Inputs` folder. Inside it, one `InputContext` per mode (`PlayContext`, `MenuContext`) with `Priority` and `Sink` set. A menu context gets a higher `Priority` plus `Sink = true`, so menu keys don't also fire gameplay.
2. One `InputAction` per mechanic (`Type = Bool` for buttons, `Direction2D` for sticks).
3. Under each action, one `InputBinding` per device: keyboard (`KeyCode = Enum.KeyCode.LeftShift`), gamepad (`Enum.KeyCode.ButtonL3`), touch (`UIButton = <your GuiButton>`).
4. Action scripts: a `Script` with `RunContext = Client` inside the action.
5. Optional: `Workspace.PlayerScriptsUseInputActionSystem = Enum.RolloutState.Enabled` moves default player controls onto the system.

```lua
--!strict
-- Client: ask the server to sprint. The server decides speed (server-authoritative).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sprint = ReplicatedStorage:WaitForChild("Inputs"):WaitForChild("PlayContext"):WaitForChild("Sprint") :: InputAction
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprint") :: RemoteEvent

sprint.Pressed:Connect(function() remote:FireServer(true) end)
sprint.Released:Connect(function() remote:FireServer(false) end)
```
- `Pressed` and `Released` fire for `Bool` actions only. `StateChanged` fires for all types, only on a change. For sticks, poll `GetState()` every frame (Roblox docs).
- Button prompts: `InputActionLabel` (beta, don't ship yet) or read `InputAction.PreferredBinding` and show `DisplayName` / `DisplayImage`, falling back to `UserInputService:GetStringForKeyCode` / `GetImageForKeyCode` (Roblox docs).
- Raw `UserInputService.InputBegan`: always return early when `gameProcessedEvent` is true, or typing "e" in chat opens your shop.
- Hide default touch controls in cutscenes with `GuiService.TouchControlsEnabled = false`. Turn them back on after.
- Rebinding: see [[Rebinding Controls with the Input Action System]] (disable the gameplay context while capturing a key, reserve Esc and Start).

### 7. Controller
- Every button is reachable with the D-pad. `GuiService.SelectedObject` sets focus when a menu opens. `AutoSelectGuiEnabled` lets the Select button enter UI (Roblox docs).
- Set `Selectable = false` on decorative buttons and tap pads, or the selection jumps onto them (Vault: [[Gamepad and Console UX]]).
- B closes the top popup. Test with Studio's Controller Emulator.

### 8. Accessibility for kids
- **Text size:** `GuiService.PreferredTextSize` is `Medium`, `Large`, `Larger` or `Largest`. Text with `TextScaled` and text inside `UITextSizeConstraint` bounds ignore it (Roblox docs). Content text uses a fixed `TextSize` plus `AutomaticSize`.
- **Reduced motion:** `GuiService.ReducedMotionEnabled`. Swap bounces, shakes and sweeps for fades.
- **Background transparency:** multiply see-through panel `BackgroundTransparency` by `GuiService.PreferredTransparency` (Roblox docs). Toy panels are opaque anyway.
- **Colour:** rarity shows colour **and** a word or icon. Check red/green pairs (Vault: [[Colour-Blind Safe Design]]).
- **Reading load:** short words, big numbers, icons next to labels. Many players are young readers (Rule of thumb).
- **Flashes:** at most 1 per second (repo `CLAUDE.md`).

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| UIShadows on screen | Recommend no more than 100 at once | DevForum (Jun 23, 2026 and Oct 14, 2026) |
| UIShadow ZIndex | Negative only; all shadows render below the parent | Roblox docs (UIShadow) |
| UIShadow BlurRadius scale | Relative to the parent's shorter side; negatives count as 0 | Roblox docs (UIShadow) |
| UICorner pill | Scale 0.5 or more on the shortest edge | Roblox docs (appearance modifiers) |
| `ContextActionService` touch buttons | At most 7 from `BindAction` | Roblox docs (ContextActionService) |
| `PreferredTextSize` | Medium (default), Large, Larger, Largest | Roblox docs (GuiService) |
| `PreferredTransparency` | 0 to 1, default 1; 0 = fully opaque | Roblox docs (GuiService) |
| UI image size | Rarely needs more than 512 x 512; minor ones under 256 x 256 | Roblox docs (Improve performance), via Vault research note |
| Icon export | 192 px or more for the owner's Retina Mac | Skill `roblox-cartoony-ui` (Rule of thumb) |
| Tap target | 44 px drawn, 8 px gaps | Vault: [[Responsive UI for Phone Tablet Console and PC]] (Rule of thumb) |
| Smallest drawn text on phones | 12 px | Vault: [[Responsive UI for Phone Tablet Console and PC]] (Rule of thumb) |
| Test viewports | 1920 x 1080 down to 667 x 375, plus a notched phone | Vault: [[HUD Design]] (Rule of thumb) |
| Hover tween | 0.3 s Back Out; unhover 0.3-0.5 s Sine Out | Video note: [[Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!]] |
| Toy outline | Black stroke 3 px outside, white 6 px outside under it; corner radius 10 | Video note: [[The Greatest Cartoony UI Tutorial on Roblox (w Figma)]] |
| Flashes | At most 1 per second | Repo `CLAUDE.md` |
| CanvasGroup texture | Capped at 1024 x 1024 per group | DevForum (older beta thread), via Vault research note; treat as approximate |

## Pitfalls (what AI models and beginners get wrong)
- Shipping beta features: text, inset or gradient `UIShadow`, Radial/Conical `UIGradient`, `InputActionLabel`. They look fine in Studio, then block publishing.
- Using the old research claim "UIShadow can't shadow text". It can now, but only in beta.
- `MouseButton1Click` instead of `Activated`: touch and gamepad break.
- No `gameProcessedEvent` check: chat typing fires abilities.
- New `ContextActionService:BindAction` code. It is on its way out.
- `TouchEnabled` used as "is a phone". Some touch laptops report false, and a phone with a pad is a gamepad player. Use `PreferredInput`.
- `IgnoreGuiInset = true` thought to mean fullscreen. Full-screen art needs `ScreenInsets = None`.
- `ScreenGui` inside a Folder in `StarterGui`: it resets on every death.
- `TextScaled` on everything: mixed sizes and no response to Text Size. Repo and skill ban the blanket use.
- `Enum.Font.GothamBlack` from old kits: renders Montserrat. Write `FontFace` explicitly.
- Emoji as icons, random boxes around buttons, dark see-through glass panels (skill: classic AI-made UI).
- Half-pixel offsets (`UDim` offsets are whole numbers), `UICorner` on a `ScrollingFrame` (not supported), weak tables keyed by Instance (repo `CLAUDE.md`).
- Tweening `Size` for juice (layouts jitter) or `UIStroke.Thickness` on text (flicker).
- Two strokes or two shadows with the same `ZIndex`: render order is undefined.
- Invented `rbxassetid://` numbers. Only the owner uploads; leave a named placeholder.
- Granting coins or items from a LocalScript. The client only requests.

## Checklist before shipping
- [ ] Side by side with the owner's reference at the same size (repo rule).
- [ ] All screens are real parts in `StarterGui`, saved by the place build.
- [ ] Each `ScreenGui`: direct child, `ResetOnSpawn = false`, chosen `ScreenInsets`, `SafeAreaCompatibility = None`, `DisplayOrder` from the band plan.
- [ ] Studio Beta Features for Upgraded UIShadows and Upgraded UIGradients are off, and the place publishes.
- [ ] Device Simulator: phone portrait/landscape, tablet, 1080p, a notched phone. Nothing under the top bar, no overlaps.
- [ ] Every button: outline, lit top, darker lip, shadow, press feedback, `Activated`, sound.
- [ ] Tap targets 44 px drawn, text 12 px or more on phones.
- [ ] Text Size set to Largest: nothing clips. Reduce Motion on: no bounces.
- [ ] Gamepad: every menu opens with focus set, B closes, no dead ends.
- [ ] No gameplay key fires while typing in chat.
- [ ] No emoji, no Gotham, no blanket `TextScaled`, no fake timers, at most 1 flash per second.
- [ ] Every purchase or reward button only sends a request; the server validates and grants.

## Go deeper
- Containers and stacking: [[ScreenGui Fundamentals]] · Notch and top bar: [[Safe Areas and Insets]]
- Layout: [[Layout - Scale Offset and Constraints]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Virtualized Lists and Large Inventories]]
- Text: [[Text Fonts and Rich Text]] · [[Readable Text and UI Scale]]
- Toy look: [[14 Cartoony UI & Juice]] · [[16 Cartoony Kid-Appeal Checklist]] · [[The Greatest Cartoony UI Tutorial on Roblox (w Figma)]] · [[How To Make Simulator UI Buttons In Figma Roblox UI Tutorial]] · [[Make INSANE Roblox GUI Assets with AI! (GPT Image 2)]] · [[Cartoony Roblox building UI and animation]] · [[07 UI & GUI]]
- Design system: [[LihFolk UI Design System]] · [[LihFolk UI Spec]] · [[Glossy Icon Style - Owner Reference]]
- Motion: [[UI Motion Language and Timing]] · [[UI and GUI Animation]] · [[Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!]] · [[Game Feel and Juice]]
- Menus and messages: [[HUD Design]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Notification and Toast Systems]] · [[Notification Queues and Limits]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]] · [[Onboarding and FTUE - Tutorials That Keep Players]]
- Input: [[Input - UserInputService and ContextActionService]] · [[Rebinding Controls with the Input Action System]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[Mobile Button Layout Editor]] · [[Gamepad and Console UX]] · [[Controller Support QoL]]
- Accessibility: [[Accessibility Start Here]] · [[Accessibility]] · [[Colour-Blind Safe Design]] · [[Motion Sensitivity and Camera Comfort]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Input Remapping and One-Handed Play]] · [[Settings Menu Essentials and Persistence]] · [[UI Scale HUD Hide and Compact Mode]]
- What AI gets wrong: [[AI Pitfalls - UI and Input]] · Platform news: [[03 What's New on Roblox - RDC 2026 and October]]
- Code: `.claude/skills/roblox-cartoony-ui/SKILL.md`, `cannon-evolution/src/client/GameClient/Kit.lua`, `cannon-evolution/src/client/GameClient/HUD.lua`

## Sources
All read 2026-10-30.
- https://create.roblox.com/docs/reference/engine/classes/UIShadow (and the `.md` version)
- https://create.roblox.com/docs/ui/appearance-modifiers
- https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263
- https://devforum.roblox.com/t/studio-beta-upgraded-uishadow-capabilities/4934553
- https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594
- https://devforum.roblox.com/t/weekly-recap-october-12-18-2026/4938638
- https://devforum.roblox.com/t/rdc26-what-we-announced/4865880
- https://create.roblox.com/docs/input/input-action-system.md
- https://create.roblox.com/docs/reference/engine/classes/InputAction.md
- https://create.roblox.com/docs/reference/engine/classes/ContextActionService.md
- https://create.roblox.com/docs/reference/engine/classes/UserInputService.md
- https://create.roblox.com/docs/reference/engine/classes/GuiService.md
- https://create.roblox.com/docs/reference/engine/classes/ScreenGui.md
- Vault and repo: `CLAUDE.md`, `.claude/skills/roblox-cartoony-ui/SKILL.md`, `research_notes/Cartoony Roblox building UI and animation/ui_implementation.md`, the LihFolk notes linked above.

## Vault corrections
| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Input - UserInputService and ContextActionService]] | "`ContextActionService` is not deprecated (only its `BindActionToInputTypes` method is superseded)" | Docs now say `BindAction` and related binding methods "aren't recommended for new work and are planned for deprecation". Use the Input Action System | Roblox docs, ContextActionService (Oct 30, 2026) |
| [[Input - UserInputService and ContextActionService]], [[Responsive UI for Phone Tablet Console and PC]] | `PreferredInput` includes `MicroGamepad` | The UserInputService page lists only `Touch`, `Gamepad`, `KeyboardAndMouse`. Unverified whether `MicroGamepad` exists; don't depend on it | Roblox docs, UserInputService (Oct 30, 2026) |
| `research_notes/.../ui_implementation.md` and [[Cartoony Roblox building UI and animation]] | UIShadow: "no text shadows, no inset shadows, no UIGradients" | True for the live version. Studio beta (Oct 14, 2026) adds `Mode = Text`, `Inset`, `ShowBehindParent`, gradient shadows; can't publish with it yet | DevForum (Oct 14, 2026) |
| `research_notes/.../ui_implementation.md` | UIGradient `Type`/`Scale`/`TileMode` presented as shipped; types Linear/Radial/Conical | They are Studio beta ("Upgraded UIGradients", Sept 2, 2026); live games can't publish with them. `Elliptical` is also a type | DevForum (Sep 2, 2026); Roblox docs |
| `research_notes/.../ui_implementation.md` | Per-corner UICorner status "conflict", maybe beta | Resolved: full release June 23, 2026; the beta flag was removed | DevForum (Jun 23, 2026) |
| `business-evolution/ART.md` | "UIShadows on screen ≤ 40 (mobile)" | Roblox's only guidance is no more than 100 on screen. 40 is an unsourced house budget; label it Rule of thumb | DevForum (Jun 23, 2026) |
| [[Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!]] | Click sound on `MouseButton1Click` | Use `GuiButton.Activated` so touch and gamepad work | Vault: [[Input - UserInputService and ContextActionService]] (Docs) |
| [[03 What's New on Roblox - RDC 2026 and October]] | Lists the Upgraded UIShadow beta only | Also add the Upgraded UIGradients Studio beta (Sept 2, 2026), same no-publish rule | DevForum (Sep 2, 2026) |
