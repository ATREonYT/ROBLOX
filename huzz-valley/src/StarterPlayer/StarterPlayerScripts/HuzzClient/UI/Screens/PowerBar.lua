--[[
	The ability cards and the dash bar (owner, Oct 19: "abilities above a clean, nice dash bar which shows the reset"),
	one-to-one with his pictures b (catcher) and c (runner): design/owner-oct19/pic-b-catcher-bar.png and
	pic-c-runner-bar.png, measured in docs/notes/ui.md ("Ability cards and the dash bar").

	Laid out in the pictures' own pixels (P below): at 1920 wide (Scale.hud = 1.375) one of ours is one of his (his
	screenshots are crops of a 1920-wide screen: the bar is 886 of them, 46% across); other screens scale with the HUD.
	  * The bar: 886 x 11 with a 1 px black outline, a pill; green (78,248,97 -> 58,187,73) when Space is ready, grey
	    (216 -> 162) while it charges back up, filling as it does ("shows the reset"). Over its left end the state
	    (CATCH READY / DASH PAUSED ...), over its right end a help line, above its middle the key line
	    (PRESS SPACE TO CATCH / SPACE · DASH), and a catcher's ATTACK with the mouse over the right end.
	  * The cards above it (194 x 77): ABILITY, the picture, the title, "<key> · LET'S GO!" or the state in the
	    power's colour (Config/Powers Accent; STUNNED / STUCK while the server refuses powers), and a line that fills
	    as it charges. A runner has one (this round's
	    Q ability, his picture c: the one they bring, Shop > ABILITIES) and, only while carrying the girl, Speed Boost on
	    E; a catcher has the two they bring (Bear Trap and Slow Wave to start).
	What it shows comes from the server: PowerName1/2 and PowerReady1/2 (HuzzServer/PowerService), DashReady (the
	huss's or the dive's ready time), ShieldUntil, DizzyUntil, StunnedFrom/StunnedUntil (a dive's stun); KnifeReady
	is set on this screen by Gameplay/Actions (the knife's 1 s charge). Tap a card or press its key (gamepad L1 / R1)
	to use it; on a phone the bar and its key line are the dash button. A card that comes back from its cooldown
	chimes quietly (power_ready) and its rim glows a moment. The Oct 20 abilities have no picture yet: their card
	shows the glyph (Config/Powers Emoji).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Powers = require(Shared.Config.Powers)
local RoundConfig = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)
local ImageLoader = require(UI.ImageLoader)
local Assets = require(Shared.Config.Assets)
local okSfx, Sfx = pcall(function() return require(UI.Parent.Gameplay.Sfx) end)

local new = Kit.new
local rgb = Color3.fromRGB

local PowerBar = {}

local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local REF_HUD = 1.375 -- Scale.hud at 1920 x 1080: there one picture pixel is one screen pixel
-- His pictures' pixels, measured (relative to the bar's top-left outline pixel: pic b x 157, y 302)
local P = {
	W = 886, Bottom = 20, -- the bar's outline box, and its gap to the screen's bottom
	BarY = 0, BarH = 11,
	LabelCapTop = -21, LabelCaps = 12, -- CATCH READY / DASH PAUSED: caps 12 px tall, 10 px over the bar
	KeyCapTop = -50, KeyCaps = 15, -- PRESS SPACE TO CATCH / SPACE · DASH, centred
	SubBottom = -9, Sub = 17, -- the help line (its letters 7 px over the bar), right end 3 px in from the bar's
	AttackX = 671, -- ATTACK's left
	Mouse = { X = 772, Y = -68, W = 32, H = 48 }, -- (34 x 50 with its outline)
	Card = { W = 194, H = 77, Gap = 10, Bottom = -116 }, -- card bottom 116 px over the bar's top
}
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local BOLD = Font.new(GOTHAM, Enum.FontWeight.Bold)
local HEAVY = Font.new(GOTHAM, Enum.FontWeight.Heavy)
local MEDIUM = Font.new(GOTHAM, Enum.FontWeight.Medium)
-- Gotham's capital letters are 0.7 of its TextSize: TextSize from the caps heights measured in his pictures
local function sizeFor(caps: number): number
	return math.floor(caps / 0.7 + 0.5)
end

local WHITE = rgb(255, 255, 255)
local SOFT = rgb(222, 222, 222) -- (his runner text and help lines: DEDEDE)
local GREY_TITLE = rgb(180, 181, 181) -- (a card waiting: ONE HIT SHIELD)
local GREEN_TEXT = rgb(80, 255, 100) -- CATCH READY
local AMBER = rgb(255, 214, 70) -- stunned, dizzy, stuck
local CARD_FILL = rgb(23, 37, 31)
local BLACK = rgb(0, 0, 0)
local FILL = {
	Ready = { rgb(78, 248, 97), rgb(58, 187, 73) },
	Charging = { rgb(216, 216, 216), rgb(162, 162, 162) },
	Stunned = { rgb(255, 214, 70), rgb(214, 160, 40) },
}
local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.E }
local PADS = { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1 }

-- A text line with his look: Gotham, a 1 px black outline.
local function label(props: { [string]: any }, outline: number?): TextLabel
	local p: { [string]: any } = {
		BackgroundTransparency = 1, FontFace = BOLD, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false,
	}
	for k, v in props do p[k] = v end
	local l = new("TextLabel", p)
	local s = Kit.attach(Kit.stroke(BLACK, outline or 1), l) :: UIStroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return l
end

-- One card (his picture b / c): 194 x 77 outline box.
local function card(parent: Instance, slot: number)
	local c = P.Card
	local b = new("TextButton", {
		Name = "Card" .. slot, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(c.W - 2, c.H - 2),
		Position = UDim2.fromOffset(0, P.Card.Bottom - 1), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "",
		BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(8) })
	-- dark green-black, warming to the power's colour from the middle to the right edge (half way to it)
	local shade = new("UIGradient", { Name = "Shade", Parent = b })
	local rimStroke = Kit.stroke(BLACK, 1)
	rimStroke.Name = "Rim" -- (named before attach, so the saved StarterGui copy is found and reused, not doubled)
	local rim = Kit.attach(rimStroke, b) :: UIStroke
	local press = new("UIScale", { Name = "Press", Parent = b })
	local icon = Kit.icon("AbilityShield", {
		Name = "Icon", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(72, 72), ZIndex = 2, Parent = b,
	})
	local emoji = label({ Name = "Emoji", Text = "", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(72, 72), ZIndex = 2, Visible = false, Parent = b })
	label({ Name = "Tag", Text = "ABILITY", TextSize = sizeFor(6), Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(60, 9),
		ZIndex = 3, Parent = b })
	local title = label({ Name = "Title", Text = "", TextSize = sizeFor(9), Position = UDim2.fromOffset(69, 18), Size = UDim2.fromOffset(118, 14),
		ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
	local status = label({ Name = "Status", Text = "", TextSize = sizeFor(7), Position = UDim2.fromOffset(70, 46), Size = UDim2.fromOffset(118, 12),
		ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd, Parent = b })
	-- the line: 171 x 3 at x 10 (his: rel 11..182, y 67..69), filling as it charges
	local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(10, 66), Size = UDim2.fromOffset(171, 3),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 3, Parent = b }, { Kit.corner(2) })
	local line = new("Frame", { Name = "Line", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		ZIndex = 4, Parent = track }, { Kit.corner(2) })
	return { button = b, shade = shade, rim = rim, press = press, icon = icon, emoji = emoji, title = title, status = status,
		line = line, glowUntil = 0, name = nil }
end

local SPRING = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function squash(c)
	c.press.Scale = 0.92
	TweenService:Create(c.press, SPRING, { Scale = 1 }):Play()
end

-- A mouse drawn in frames (his picture b, next to ATTACK): dark body, the left button lit.
local function mouse(parent: Instance)
	local m = P.Mouse
	local body = new("Frame", { Name = "Mouse", Position = UDim2.fromOffset(m.X, m.Y), Size = UDim2.fromOffset(m.W, m.H),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = parent }, { Kit.corner(15) })
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(rgb(92, 92, 92), rgb(40, 40, 40)), Parent = body })
	Kit.attach(Kit.stroke(BLACK, 1), body)
	local left = new("Frame", { Name = "Left", Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(12, 18),
		BackgroundColor3 = rgb(236, 236, 236), BorderSizePixel = 0, Parent = body }, { Kit.corner(6) })
	new("Frame", { Name = "Wheel", Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(4, 10),
		BackgroundColor3 = rgb(30, 30, 30), BorderSizePixel = 0, Parent = body }, { Kit.corner(2) })
	return body, left
end

function PowerBar.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local remote = Net.get("Power") :: RemoteEvent
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- The whole cluster (cards to bar) is one frame, so it's one box on the screen; everything is laid out from the
	-- bar's top-left inside it (Inner), in his pixels.
	local TOP = -(P.Card.Bottom - 1) + (P.Card.H - 2) + 1 -- (the cards' top, over the bar's top)
	local root = new("Frame", {
		Name = "PowerBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -P.Bottom),
		Size = UDim2.fromOffset(P.W, TOP + P.BarH), BackgroundTransparency = 1, Visible = false, Parent = parent,
	})
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = root }), function()
		return Scale.touchMin(Scale.hud(PAGE_H) / REF_HUD, 0.6, P.W)
	end)
	local inner = new("Frame", { Name = "Inner", Position = UDim2.fromOffset(0, TOP), Size = UDim2.fromOffset(P.W, P.BarH),
		BackgroundTransparency = 1, Parent = root })
	-- the bar: the outline box 886 x 11 = a 884 x 9 fill with a 1 px black outline round it
	local track = new("TextButton", { Name = "Bar", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(P.W - 2, P.BarH - 2),
		BackgroundColor3 = rgb(16, 28, 22), BackgroundTransparency = 0.35, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		Parent = inner }, { Kit.corner(5) })
	Kit.attach(Kit.stroke(BLACK, 1), track)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Parent = track }, { Kit.corner(5) })
	local fillShade = new("UIGradient", { Name = "Shade", Rotation = 90, Parent = fill })
	local state = label({ Name = "State", Text = "", TextSize = sizeFor(P.LabelCaps), Position = UDim2.fromOffset(1, P.LabelCapTop - 4),
		Size = UDim2.fromOffset(400, 20), Parent = inner })
	local keyLine = label({ Name = "Key", Text = "", FontFace = HEAVY, TextSize = sizeFor(P.KeyCaps), AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(P.W / 2, P.KeyCapTop - 5), Size = UDim2.fromOffset(420, 25),
		Parent = inner }, 1.5)
	local help = label({ Name = "Help", Text = "", FontFace = MEDIUM, TextSize = P.Sub, TextColor3 = SOFT, AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(P.W - 3, P.SubBottom + 4), Size = UDim2.fromOffset(420, 20),
		Parent = inner })
	local attack = label({ Name = "Attack", Text = "ATTACK", FontFace = HEAVY, TextSize = sizeFor(P.KeyCaps), Position = UDim2.fromOffset(P.AttackX, P.KeyCapTop - 5),
		Size = UDim2.fromOffset(100, 25), Parent = inner }, 1.5)
	local mouseBody, mouseLeft = mouse(inner)
	-- (a phone has no Space: the bar and its key line are the dash button there)
	local dashHit = new("TextButton", { Name = "DashHit", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(P.W / 2, P.KeyCapTop - 10),
		Size = UDim2.fromOffset(460, -P.KeyCapTop + 10 + P.BarH), BackgroundTransparency = 1, Text = "", Visible = touchOnly, Parent = inner })
	local cards = { card(inner, 1), card(inner, 2) }
	local Dash = require(script.Parent.Parent.Parent:WaitForChild("Gameplay"):WaitForChild("Dash"))

	local function nameIn(slot: number): string?
		local n = player:GetAttribute("PowerName" .. slot)
		if type(n) == "string" and Powers[n] then return n end
		local list = Powers[player:GetAttribute("HuzzRole") or ""]
		local v = list and list[slot]
		return if v and Powers[v] then v else nil
	end
	local function carrying(): boolean
		return round:GetAttribute("HolderId") == player.UserId
	end
	-- Which cards show now: a runner's Speed Boost only while carrying the girl.
	local function shownSlots(): { number }
		local list = {}
		for slot = 1, 2 do
			local n = nameIn(slot)
			if n and not (Powers[n].CarrierOnly and not carrying()) then table.insert(list, slot) end
		end
		return list
	end

	local function use(slot: number)
		local n = nameIn(slot)
		if not n or not root.Visible or player:GetAttribute("MenuOpen") then return end
		if Powers[n].CarrierOnly and not carrying() then return end
		squash(cards[slot])
		remote:FireServer(slot)
	end
	for slot, c in cards do
		c.button.Activated:Connect(function() use(slot) end)
	end
	local function dash()
		if root.Visible then Dash.try() end
	end
	dashHit.Activated:Connect(dash)
	track.Activated:Connect(function() if touchOnly then dash() end end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		for slot = 1, 2 do
			if input.KeyCode == KEYS[slot] or input.KeyCode == PADS[slot] then use(slot) end
		end
	end)
	-- The server took it: the card's rim lights in its colour for a moment (its slot's ready time jumped ahead).
	for slot = 1, 2 do
		player:GetAttributeChangedSignal("PowerReady" .. slot):Connect(function()
			local ready = player:GetAttribute("PowerReady" .. slot)
			if root.Visible and type(ready) == "number" and (ready < 0 or ready > Workspace:GetServerTimeNow() + 0.5) then
				cards[slot].glowUntil = os.clock() + 0.4
			end
		end)
	end

	local function paintFill(kind: string, frac: number)
		local f = FILL[kind]
		fillShade.Color = ColorSequence.new(f[1], f[2])
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		fill.Visible = frac > 0.005
	end

	-- A card's look for its power and state.
	local function paintCard(c, name: string, waiting: boolean, now: number, slot: number, hold: string?)
		local def = Powers[name]
		if c.name ~= name then
			c.name = name
			local base = CARD_FILL
			c.shade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.5, base),
				ColorSequenceKeypoint.new(1, base:Lerp(def.Accent, 0.5)),
			})
			c.title.Text = def.Card or string.upper(def.Name)
			-- (the picture: tools/icons/ability_icons.mjs, packed; the emoji if it can't be drawn)
			local ok = pcall(function()
				local kebab = (def.Icon:gsub("(%l)(%u)", "%1-%2"):lower())
				c.icon:SetAttribute("Icon", def.Icon)
				c.icon:SetAttribute("PreviewFile", "assets/icons/" .. kebab .. ".png")
				c.icon.Image = Assets.icon(def.Icon)
				ImageLoader.apply(c.icon, "Icons", def.Icon, c.icon.Image)
			end)
			c.emoji.Text = def.Emoji or ""
			c.emoji.Visible = not ok
			c.icon.Visible = ok
			c.line.BackgroundColor3 = def.Accent
			c.status.TextColor3 = def.Accent
		end
		local ready = player:GetAttribute("PowerReady" .. slot) or 0
		local key = if touchOnly then "TAP" else Powers.Keys[slot]
		local onUntil = if name == "Shield" then player:GetAttribute("ShieldUntil")
			elseif name == "Invisible" then (player.Character and player.Character:GetAttribute("InvisibleUntil"))
			else nil
		local text, frac, live
		if waiting then
			text, frac, live = "WAIT FOR ROUND", 1, false
		elseif hold then -- (stunned or stuck: the server refuses powers until it ends, so say so)
			text, frac, live = hold, if ready > now then 1 - (ready - now) / (def.Cooldown or 1) elseif ready < 0 then 0 else 1, false
		elseif type(onUntil) == "number" and onUntil > now then
			text, frac, live = string.format("ON  ·  %ds", math.ceil(onUntil - now)), (onUntil - now) / (def.Lasts or 1), true
		elseif ready < 0 then
			text, frac, live = "USED THIS ROUND", 0, false
		elseif ready > now then
			text, frac, live = string.format("READY IN %ds", math.ceil(ready - now)), 1 - (ready - now) / (def.Cooldown or 1), false
			c.cooling = true
		else
			text, frac, live = key .. "  ·  LET'S GO!", 1, true
			if c.cooling and ready > 0 and now - ready < 1 then
				-- ready again after its cooldown (not a new round's fresh card): a quiet chime and the rim glows a
				-- moment (Oct 20: "feel way better to play")
				c.glowUntil = os.clock() + 0.35
				if okSfx then Sfx.play("power_ready") end
			end
			c.cooling = false
		end
		c.status.Text = text
		c.title.TextColor3 = if live then WHITE else GREY_TITLE
		c.line.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		local glowing = os.clock() < c.glowUntil
		c.rim.Color = if glowing then def.Accent else BLACK
		c.rim.Thickness = if glowing then 2 else 1
	end

	-- Every frame: what Space does and how charged it is, and the cards.
	local function refresh()
		local role = player:GetAttribute("HuzzRole")
		local stage = round:GetAttribute("Stage")
		local status = player:GetAttribute("HuzzStatus")
		local playing = (role == "Runner" or role == "Catcher") and (stage == "Countdown" or stage == "Running" or stage == "HeroRun")
			and status ~= "Downed" and status ~= "Safe" and player:GetAttribute("PowerReady1") ~= nil
		root.Visible = playing
		if not playing then return end
		local now = Workspace:GetServerTimeNow()
		local waiting = player:GetAttribute("HuzzFrozen") == true or stage == "Countdown" -- (on the line: no dash, no powers)
		local catcher = role == "Catcher"
		local dashReady = player:GetAttribute("DashReady") or 0
		local hold: string? = nil
		attack.Visible, mouseBody.Visible = catcher, catcher
		keyLine.TextColor3 = if catcher then WHITE else SOFT -- (his catcher picture is white, his runner one DEDEDE)
		-- the bar
		if catcher then
			keyLine.Text = if touchOnly then "TAP HERE TO CATCH" else "PRESS SPACE TO CATCH"
			help.Text = "Tag in front  ·  Space to dive"
			local stunFrom, stunUntil = player:GetAttribute("StunnedFrom") or math.huge, player:GetAttribute("StunnedUntil") or 0
			local dizzy = player:GetAttribute("DizzyUntil") or 0
			local knife = player:GetAttribute("KnifeReady") or 0
			local knifeCharging = knife > now
			attack.TextColor3 = if knifeCharging or waiting then GREY_TITLE else WHITE
			mouseLeft.BackgroundColor3 = if knifeCharging or waiting then rgb(130, 130, 130) else rgb(236, 236, 236)
			if waiting then
				state.Text, state.TextColor3 = "DIVE PAUSED", SOFT
				paintFill("Charging", 1)
			elseif now >= stunFrom and now < stunUntil then
				state.Text, state.TextColor3 = "STUNNED 💫", AMBER
				paintFill("Stunned", (stunUntil - now) / (RoundConfig.Lunge.Stun or 2))
				hold = "STUNNED"
			elseif dizzy > now then
				state.Text, state.TextColor3 = "DIZZY 💫", AMBER
				paintFill("Stunned", (dizzy - now) / Powers.Shield.Dizzy)
			elseif knifeCharging then
				state.Text, state.TextColor3 = "KNIFE CHARGING", SOFT
				paintFill("Charging", 1 - (knife - now) / RoundConfig.Stab.Cooldown)
			elseif dashReady > now then
				state.Text, state.TextColor3 = "DIVE RECHARGING", SOFT
				paintFill("Charging", 1 - (dashReady - now) / (player:GetAttribute("DashCooldown") or RoundConfig.Lunge.Cooldown))
			else
				state.Text, state.TextColor3 = "CATCH READY", GREEN_TEXT
				paintFill("Ready", 1)
			end
		else
			keyLine.Text = if touchOnly then "TAP HERE  ·  DASH" else "SPACE  ·  DASH"
			local stuck = (player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				and (player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid).WalkSpeed <= 0) == true
			if waiting then
				state.Text, state.TextColor3, help.Text = "DASH PAUSED", SOFT, "Waiting for movement"
				paintFill("Charging", 1)
			elseif stuck then
				state.Text, state.TextColor3, help.Text = "STUCK!", AMBER, "Caught in a bear trap"
				paintFill("Stunned", 1)
				hold = "STUCK"
			elseif dashReady > now then
				state.Text, state.TextColor3 = "DASH RECHARGING", SOFT
				help.Text = string.format("Ready in %.1fs", dashReady - now)
				paintFill("Charging", 1 - (dashReady - now) / (player:GetAttribute("DashCooldown") or RoundConfig.Dash.Cooldown))
			else
				state.Text, state.TextColor3, help.Text = "DASH READY", GREEN_TEXT, "A or D to pick a side"
				paintFill("Ready", 1)
			end
		end
		-- the cards, centred over the bar, side by side
		local slots = shownSlots()
		local span = #slots * P.Card.W + (#slots - 1) * P.Card.Gap
		for slot, c in cards do
			local i = table.find(slots, slot)
			c.button.Visible = i ~= nil
			if i then
				local x = P.W / 2 - span / 2 + (i - 1) * (P.Card.W + P.Card.Gap) + P.Card.W / 2
				c.button.Position = UDim2.fromOffset(math.floor(x), P.Card.Bottom - 1)
				paintCard(c, nameIn(slot) :: string, waiting, now, slot, hold)
			end
		end
	end
	RunService.RenderStepped:Connect(refresh)
	PowerBar.refresh = refresh -- (the offline preview calls it)
	refresh()
	return root
end

return PowerBar
