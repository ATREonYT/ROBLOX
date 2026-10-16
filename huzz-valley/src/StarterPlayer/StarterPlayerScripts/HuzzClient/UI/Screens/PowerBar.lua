-- The power hotbar (Config/Powers), bottom centre while you play a round, in the spirit of Huss Valley's ability
-- cards but in our kit: two navy cards with the power's icon, name, what it does and its key (Q / E). Tap a card or
-- press its key (gamepad L1 / R1) to use it. The server decides (HuzzServer/PowerService) and sends the result back
-- as the player's PowerReady1/PowerReady2 attributes (server time the slot is ready; -1 = used up this round), which
-- the cards count down. A Heart Shield that's on shows on its card until it runs out or pops.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Powers = require(Shared.Config.Powers)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex

local PowerBar = {}

local CARD = { W = 184, H = 62, Gap = 12 }
local W = 2 * CARD.W + CARD.Gap
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local PINK = hex("FF6EBE")
local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.E }
local PADS = { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1 }

local function card(parent: Instance, slot: number)
	local b = new("TextButton", {
		Name = "Card" .. slot, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(CARD.W, CARD.H),
		Position = UDim2.fromOffset((slot - 1) * (CARD.W + CARD.Gap) + CARD.W / 2, CARD.H / 2), -- centred: presses shrink evenly
		BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(8) })
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(C.RowTop, C.Panel), Parent = b })
	local rim = Kit.stroke(C.RowBorder, 2)
	rim.Name = "Rim"
	rim = Kit.attach(rim, b) :: UIStroke
	local press = new("UIScale", { Name = "Press", Parent = b })
	local well = new("Frame", {
		Name = "IconWell", Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = C.IconCell, BorderSizePixel = 0, Parent = b,
	}, { Kit.corner(6) })
	local icon = Kit.text({
		Name = "Icon", Text = "", TextSize = 30, FontFace = Theme.Fonts.Name, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = well,
	})
	local name = Kit.name({ Name = "PowerName", Text = "", TextSize = 15, Position = UDim2.fromOffset(63, 8), Size = UDim2.fromOffset(112, 20), Parent = b })
	local blurb = Kit.text({
		Name = "Blurb", Text = "", TextSize = 13, TextColor3 = C.SubText, Position = UDim2.fromOffset(63, 30), Size = UDim2.fromOffset(88, 26),
		TextYAlignment = Enum.TextYAlignment.Top, Parent = b,
	})
	local key = new("Frame", {
		Name = "Key", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -7, 1, -7), Size = UDim2.fromOffset(22, 20),
		BackgroundColor3 = C.Pill, BorderSizePixel = 0, Parent = b,
	}, { Kit.corner(5) })
	Kit.attach(Kit.stroke(C.PillRim, 1.5), key)
	local keyText = Kit.text({
		Name = "Text", Text = Powers.Keys[slot], FontFace = Theme.Fonts.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = key,
	})
	-- The cooldown: a dark cover that shrinks away, with the seconds left on top.
	local cover = new("Frame", {
		Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = hex("0A1222"), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3, Visible = false, Parent = b,
	}, { Kit.corner(8) })
	local count = Kit.text({
		Name = "Count", Text = "", FontFace = Theme.Fonts.Number, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), ZIndex = 4, Visible = false, Parent = b,
	})
	new("UIStroke", { Name = "Outline", Color = C.TextShadow, Thickness = 1.5, Parent = count })
	return { button = b, rim = rim, press = press, icon = icon, name = name, blurb = blurb, key = keyText, cover = cover, count = count }
end

function PowerBar.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local remote = Net.get("Power") :: RemoteEvent
	local bar = new("Frame", {
		Name = "PowerBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(W, CARD.H),
		BackgroundTransparency = 1, Visible = false, Parent = parent,
	})
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = bar }), function() return Scale.hud(PAGE_H) * 0.72 end)
	local cards = { card(bar, 1), card(bar, 2) }
	-- Phones have no Q / E: hide the key pills there.
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, c in cards do
		(c.key.Parent :: GuiObject).Visible = not touchOnly
	end

	local function powersNow(): { string }?
		return Powers[player:GetAttribute("HuzzRole") or ""]
	end

	local function use(slot: number)
		local list = powersNow()
		if not list or not bar.Visible or player:GetAttribute("MenuOpen") then return end
		local c = cards[slot]
		c.press.Scale = 0.94
		task.delay(0.08, function() c.press.Scale = 1 end)
		remote:FireServer(slot)
	end
	for slot, c in cards do
		c.button.Activated:Connect(function() use(slot) end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		for slot = 1, 2 do
			if input.KeyCode == KEYS[slot] or input.KeyCode == PADS[slot] then use(slot) end
		end
	end)

	-- Every frame: which powers, and how long until each is ready.
	local shown = nil
	local function refresh()
		local list = powersNow()
		local stage = round:GetAttribute("Stage")
		local status = player:GetAttribute("HuzzStatus")
		local playing = list ~= nil and (stage == "Countdown" or stage == "Running") and status ~= "Caught" and status ~= "Safe"
			and player:GetAttribute("PowerReady1") ~= nil
		bar.Visible = playing
		if not playing then shown = nil; return end
		local roleKey = player:GetAttribute("HuzzRole")
		if shown ~= roleKey then
			shown = roleKey
			for slot, c in cards do
				local def = Powers[list[slot]]
				c.icon.Text, c.name.Text, c.blurb.Text = def.Icon, def.Name, def.Text
			end
		end
		local now = Workspace:GetServerTimeNow()
		for slot, c in cards do
			local def = Powers[list[slot]]
			local ready = player:GetAttribute("PowerReady" .. slot) or 0
			local shieldOn = list[slot] == "HeartShield" and (player:GetAttribute("ShieldUntil") or 0) > now
			local text, frac = "", 0
			if stage == "Countdown" then
				text, frac = "", 1
			elseif shieldOn then
				local left = (player:GetAttribute("ShieldUntil") :: number) - now
				text, frac = "ON", left / def.Lasts
			elseif ready < 0 then
				text, frac = "USED", 1
			elseif ready > now then
				text, frac = tostring(math.ceil(ready - now)), (ready - now) / (def.Cooldown or 1)
			end
			c.cover.Visible = frac > 0
			c.cover.Size = UDim2.fromScale(1, math.clamp(frac, 0, 1))
			c.cover.BackgroundColor3 = if shieldOn then PINK else hex("0A1222")
			c.cover.BackgroundTransparency = if shieldOn then 0.55 else 0.3
			c.count.Visible = text ~= ""
			c.count.Text = text
			local isReady = frac <= 0 and stage == "Running"
			c.rim.Color = if shieldOn then PINK elseif isReady then C.Action else C.RowBorder
		end
	end
	RunService.RenderStepped:Connect(refresh)
	PowerBar.refresh = refresh -- (the offline preview calls it)
	refresh()
	return bar
end

return PowerBar
