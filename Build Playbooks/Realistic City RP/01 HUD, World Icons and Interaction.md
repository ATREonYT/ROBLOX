---
tags: [build-playbooks, realistic-rp, hud, ui, world-markers, proximity-prompt]
updated: 2026-11-01
---

# 01 HUD, World Icons and Interaction

Back to [[00 Start Here - Realistic City RP]] · UI rules: [[30 UI and UX Playbook]] · Kit: `Shared/Markers.luau`, `Shared/Interact.luau`

A realistic RP's HUD is **tiny and confident**: money top-right, two round buttons under it, one hotbar slot at the bottom, and the *world itself* carries the rest through icons over buildings. Everything else lives in the phone. That's why the screenshots feel clean even with 15 places marked.

## 1. HUD layout (phone first, 1080p checked)

| Slot | Element | Size (at 1080p; scale with `UIScale`) | Behaviour |
|---|---|---|---|
| Top-right | **Cash pill**: dark-green gradient, bill icon, white bold number with a green stroke | 300×64 px | Number *counts up* over 0.4 s on gain (ease-out), pops 1.08× and back; red tick-down on spend; "+$120" floats up beside it |
| Under cash | **Sprint button** (running man in a ring) | 64 px circle | Ring = stamina (radial fill); toggles sprint on touch; Shift on keyboard |
| Under cash | **Health button** (heart in a ring) | 64 px circle | Ring = health; flashes red edge (once) when hit; tap opens a small stats card |
| Under those | **Offer tile** (starter pack) | 110×110 px | Only for new players; never covers buttons; see [[12 Money - Starter Packs, Passes and Offers]] |
| Left middle | **Phone/menu button** | 96 px | Opens the phone ([[07 Phone, Apps and Banking]]) |
| Bottom centre | **Hotbar**: 1-6 slots, fists always slot 1 | 84 px circles | Number above the slot; equipped slot lifts 6 px and gets a white ring |
| Bottom-right | Season + weather glyphs, small | 40 px | Purely mood; tap shows the time |
| Above heads | Name, then rank/level ("Lv 12 · Mechanic") | BillboardGui, `MaxDistance` 60 | Job colour on the second line |

Rules: no element in the top 58 px band on phones (Roblox buttons), nothing under the thumbs' joystick zone (bottom-left 30%), and **one** font family (the cartoony games use FredokaOne; a realistic RP reads better with a heavy plain sans: **`BuilderSans` Bold**, white with a 2 px dark stroke). Repo `CLAUDE.md` bans Gotham and asks for the toy font in our cartoony games; for a realistic RP record the `BuilderSans` choice in the game's own `CLAUDE.md`.

Hide the default backpack and keep the rest:
```lua
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- our hotbar replaces it
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)   -- our heart ring replaces it
```

### Cash counter that feels like money (client)
```lua
-- Reads the server-owned attribute; the client never decides the number.
local TweenService = game:GetService("TweenService")
local player = game:GetService("Players").LocalPlayer
local label = script.Parent.Amount -- TextLabel
local shown = player:GetAttribute("Cash") or 0
local counter = Instance.new("NumberValue")
counter.Value = shown

local function fmt(n) -- 1105 -> "$1,105"
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. out
end

counter.Changed:Connect(function(v) label.Text = fmt(v) end)
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local target = player:GetAttribute("Cash") or 0
	local gained = target > counter.Value
	TweenService:Create(counter, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target }):Play()
	-- pop + coin sound only on gains; a short "tick" on spends
	script.Parent.Pop:Fire(gained)
end)
label.Text = fmt(shown)
```
(Kit `Shared/Format.luau` already has number formatting; use it in the game instead of the inline `fmt`.)

## 2. World icons (the floating circles)

### What they are
Each service in town has **one icon anchored at its door, 14-18 studs up**: dark circle (`#1B1B1F` at 15% transparency), a coloured glyph inside, a soft drop shadow. Same size on screen whatever the distance, until far away. They answer "where is the bank?" without a map.

Icon set (draw our own, 256 px, white-on-transparent glyph + colour tint in code):

| Place | Glyph | Tint | Priority |
|---|---|---|---|
| Job board / job site | briefcase | orange `#F28C28` | 5 |
| Bank / ATM | columns building | white | 5 |
| Hospital | cross on building | red/white | 4 |
| Gas station | pump | amber | 4 |
| Car dealer | car | red | 4 |
| Mechanic | wrench | grey | 3 |
| Clothing | T-shirt | blue | 3 |
| Barber | barber pole | red/white/blue | 2 |
| 24/7 store | "24" shop | red | 3 |
| Weapon store | pistol | green | 3 |
| Your house | house | yellow | 6 (tracked) |
| Police / fire station | badge / flame | blue / red | 3 |

### Two ways to draw them
- **A) BillboardGui per place** (simplest): `AlwaysOnTop = true`, `Size = UDim2.fromOffset(44, 44)` (pixel size stays constant), `MaxDistance = 900`, `LightInfluence = 0`, `StudsOffsetWorldSpace = Vector3.new(0, 16, 0)`. Good for up to ~40 places. Can't stick to screen edges.
- **B) One ScreenGui marker layer** (what the polished games do for the *active* target): project each place every frame with `Camera:WorldToViewportPoint`, size it by distance, fade it when you arrive, clamp **tracked** markers (job destination, your car, a 911 call) to the screen edge with an arrow. Kit `Markers` is the maths; this is the client:

```lua
-- StarterPlayerScripts/WorldIcons.client.lua (shape; runs on RenderStepped, budgeted)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Markers = require(ReplicatedStorage.Kit.Markers)
local Places = require(ReplicatedStorage.Config.Places) -- { {id="Bank", pos=Vector3, icon="rbxassetid://0", tint=Color3, priority=5}, ... }
local camera = workspace.CurrentCamera
local layer = script.Parent -- ScreenGui, IgnoreGuiInset = true, ZIndexBehavior = Sibling
local pool = {}             -- id -> ImageLabel (made once; never Instance.new per frame)
local tracked = {}          -- id -> true (set by the job/phone/911 systems)

local function labelFor(id, place)
	local img = pool[id]
	if not img then
		img = layer.Template:Clone()
		img.Image = place.icon
		img.Glyph.ImageColor3 = place.tint
		img.Parent = layer
		pool[id] = img
	end
	return img
end

RunService.RenderStepped:Connect(function()
	local root = camera.Focus.Position
	local view = { width = camera.ViewportSize.X, height = camera.ViewportSize.Y, insetTop = 58 }
	local entries = {}
	for id, place in Places do
		table.insert(entries, { id = id, distance = (place.pos - root).Magnitude, priority = place.priority, tracked = tracked[id] })
	end
	local show = {}
	for _, e in Markers.Pick(entries, 24) do
		show[e.id] = e
	end
	for id, place in Places do
		local img = labelFor(id, place)
		local e = show[id]
		if not e then
			img.Visible = false
			continue
		end
		local p = camera:WorldToViewportPoint(place.pos + Vector3.new(0, 16, 0))
		local x, y, on, angle = Markers.Place(p.X, p.Y, p.Z, view, e.tracked == true)
		local alpha = Markers.Alpha(e.distance, e.tracked)
		img.Visible = (on or e.tracked == true) and alpha < 1
		local size = Markers.Size(e.distance)
		img.Size = UDim2.fromOffset(size, size)
		img.Position = UDim2.fromOffset(math.round(x), math.round(y))
		img.ImageTransparency = alpha
		img.Arrow.Visible = angle ~= nil
		if angle then img.Arrow.Rotation = angle end
	end
end)
```
Key details:
- **Place positions live in a config module (Vector3s), not in parts.** With StreamingEnabled the bank's model may not be streamed in on the client, but its icon must still show ([[11 Streaming and Performance for a City]]).
- `AnchorPoint = (0.5, 0.5)` on the template; whole-pixel positions (`math.round`) so icons don't shimmer.
- Overlap: when two icons are within 18 px, nudge the lower-priority one up by its height (the screenshots stack "24" over "house" like this).
- Hide all icons inside interiors (set a `Indoors` attribute from a zone check) and while the phone or a shop is open.
- Accessibility: a setting "World icons: All / Tracked only / Off".

## 3. Ground rings and ProximityPrompts (the "press E" layer)

The gold ring in the screenshot is a **job spot**: a flat `CylinderHandleAdornment` or a decal disc on the ground, slowly pulsing (scale 1.0 → 1.06, 1.2 s, sine), with a ProximityPrompt on an invisible part above it.

ProximityPrompt defaults for a city:
```lua
prompt.MaxActivationDistance = 8      -- doors 6, counters 8, car doors 10, job rings 10
prompt.RequiresLineOfSight = true     -- no buying through walls
prompt.HoldDuration = 0               -- shops/doors instant; robbery/repair 1.5-3 s holds
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
prompt.Style = Enum.ProximityPromptStyle.Custom -- draw our own card (icon + action + key)
prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
```
- **Custom style**: listen to `ProximityPromptService.PromptShown/PromptHidden` on the client and show our own card (dark rounded rect, icon, "Open ATM", key chip `E`, hold ring for holds). One look for every prompt in the city.
- **Server check every time**: `prompt.Triggered` fires on the server; still run kit `Interact:Try(userId, targetId, { distance = serverDistance, allowed = ... }, now)` because exploiters can fire prompts from afar. Distance from the server's character position, +2 studs slack.
- **Hold prompts that can be interrupted** (robbery, repair, CPR): the server records `startedAt` on `PromptButtonHoldBegan`, refuses `Triggered` if the player moved > 4 studs or took damage since.
- Prompts in streamed-out models don't exist for that client. Big services (bank, hospital) get their counter part in a `ModelStreamingMode.Atomic` model near the door so the prompt streams with the room.

## 4. Feedback that sells it

- **Money in:** coin "cha-ching" (short, bright), cash pill pop, "+$120 Paycheck" toast (2 s, top-right under the pill).
- **Money out:** soft register "tick"; no pop.
- **Can't afford:** pill shakes 6 px twice, short low buzz, toast "Need $350 more" (the *gap*, not a scold).
- **Job done:** ring bursts into a quick sparkle (once), checkmark toast, next destination icon becomes tracked.
- Sounds: Roblox licensed library, each under 0.6 s ([[29 Sound Playbook]]).

## 5. Mobile and console

- Sprint: a **toggle** on touch (hold is tiring on glass), hold on keyboard (Shift) and gamepad (L3 click toggles).
- Use the **Input Action System** so one action has keyboard, gamepad and touch bindings: an `InputContext` "OnFoot" with `InputAction` "Sprint" (`Bool`) bound to `KeyCode.LeftShift`, `ButtonL3` and a `UIButton` = our sprint circle. Swap to an "InVehicle" context when seated ([Input Action System docs](https://create.roblox.com/docs/input/input-action-system)). Server Authority requires `PlayerScriptsUseInputActionSystem` anyway ([[10 Saving, Anti-Exploit and Admin]]).
- Test in Device Simulator at iPhone SE size, then a real phone.

## Done when
- A new player can find the bank, a job and the dealer from the spawn without opening a map.
- Every prompt in town looks identical and is refused by the server from 15 studs away.
- 40 icons cost < 0.3 ms per frame on a phone (MicroProfiler `RenderStepped`).
