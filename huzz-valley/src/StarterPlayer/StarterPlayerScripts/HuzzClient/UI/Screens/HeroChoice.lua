-- Chicken or Hero (Huss Valley, owner's call): each round one runner is picked at random (the camera zooms in on
-- them, Gameplay/Cinematic) and only they see this: a gold HERO card (cross alone first; make it and the girl
-- comes down to you, plus coins) and a cream CHICKEN card (run with everyone), keys 1 and 2, and a bar running
-- down the time left (Config/Round.Pick.ChooseTime). No answer in time = the server picks at random.
-- While it shows, shift lock lets go of the mouse (the "HuzzChoosing" attribute) so you can click.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)
local Motion = require(UI.Motion)

local F = Theme.Fonts
local new = Kit.new
local rgb = Color3.fromRGB

local HeroChoice = {}

local W, H = 420, 196
local CARD = { W = 190, H = 112, Gap = 22 }
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local C = Theme.Colors
local INK = C.Frame
-- HERO in Huss Valley green, CHICKEN in the kit's action violet; white words with a dark outline (no gold: owner).
local LOOKS = {
	Hero = { Top = C.SelectedTabTop, Bottom = C.SelectedTab, Text = Color3.new(1, 1, 1), Line = rgb(236, 255, 238), Rim = C.SelectedRim, Outline = true },
	Chicken = { Top = C.ActionTop, Bottom = C.ActionPressed, Text = Color3.new(1, 1, 1), Line = rgb(236, 234, 255), Rim = C.ActionRim, Outline = true },
}

local function choiceCard(parent: Instance, name: string, key: string, word: string, x: number, y: number, onClick: () -> ())
	local look = LOOKS[name]
	local btn = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + CARD.W / 2, y + CARD.H / 2), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(16) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(look.Top, look.Bottom), Parent = btn })
	new("UIStroke", { Name = "Rim", Thickness = 3, Color = look.Rim, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	new("Frame", { Name = "Gloss", Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = btn }, { Kit.corner(4) })
	local keyDot = new("TextLabel", {
		Name = "Key", Text = key, FontFace = F.Number, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.Pill,
		Position = UDim2.fromOffset(-8, -8), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = btn,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }), new("UIStroke", { Thickness = 1.5, Color = C.Frame, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	new("TextLabel", {
		Name = "Word", Text = word, FontFace = F.Heading, TextSize = 32, TextColor3 = look.Text, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), ZIndex = 2, Parent = btn,
	}, { new("UIStroke", { Name = "Outline", Color = look.Rim, Thickness = 1.5, Enabled = look.Outline }) })
	local line1 = new("TextLabel", {
		Name = "Line", Text = "", FontFace = F.Button, TextSize = 16, TextColor3 = look.Line, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 18), ZIndex = 2, Parent = btn,
	})
	local line2 = new("TextLabel", {
		Name = "Line2", Text = "", FontFace = F.Body, TextSize = 14, TextColor3 = look.Line, TextTransparency = 0.1, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 80), Size = UDim2.new(1, -20, 0, 16), ZIndex = 2, Parent = btn,
	})
	btn.Activated:Connect(onClick)
	Motion.bindButton(btn, function() return nil end)
	return { Instance = btn, line = line1, line2 = line2, key = keyDot }
end

function HeroChoice.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local remote = Net.get("Hero") :: RemoteEvent
	local panel = new("Frame", {
		Name = "HeroChoice", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1, Visible = false, Parent = parent,
	})
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = panel }), function() return Scale.touchMin(Scale.hud(PAGE_H) * 0.6, 0.6, W) end) -- (owner: "make the choosing hero or chicken boxes smaller"; was 0.8)
	local title = new("TextLabel", {
		Name = "Hint", Text = "HERO OR CHICKEN?", FontFace = F.Big, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38), Parent = panel,
	}, { new("UIStroke", { Name = "Outline", Color = C.TitleShadow, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round }) })
	-- the time left: a bar that empties (and the seconds)
	local timer = new("Frame", { Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(260, 12), BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = panel }, { Kit.corner(6), new("UIStroke", { Color = INK, Thickness = 2 }) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Progress, BorderSizePixel = 0, Parent = timer }, { Kit.corner(6) })
	local secs = new("TextLabel", { Name = "Seconds", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 8, 0.5, 0), Size = UDim2.fromOffset(40, 20), Text = "", FontFace = F.Number, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Parent = timer },
		{ new("UIStroke", { Color = INK, Thickness = 2 }) })

	local sent = nil
	local function pick(isHero: boolean)
		if panel.Visible and sent == nil then
			sent = isHero
			remote:FireServer(isHero)
		end
	end
	local y = H - CARD.H
	local hero = choiceCard(panel, "Hero", "1", "HERO", W / 2 - CARD.Gap / 2 - CARD.W, y, function() pick(true) end)
	local chicken = choiceCard(panel, "Chicken", "2", "CHICKEN", W / 2 + CARD.Gap / 2, y, function() pick(false) end)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled -- (no keys to show)
	hero.key.Visible, chicken.key.Visible = not touchOnly, not touchOnly

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.One or k == Enum.KeyCode.DPadLeft or k == Enum.KeyCode.ButtonL1 then pick(true)
		elseif k == Enum.KeyCode.Two or k == Enum.KeyCode.DPadRight or k == Enum.KeyCode.ButtonR1 then pick(false) end
	end)

	local wasVisible = false
	local function refresh()
		local now = Workspace:GetServerTimeNow()
		local openAt = (round:GetAttribute("PickAt") or 0) + Config.Pick.Roulette
		local show = round:GetAttribute("Stage") == "Picking" and round:GetAttribute("PickId") == player.UserId
			and now >= openAt - 0.2 -- (even over an open menu: it's your turn)
		panel.Visible = show == true
		if player:GetAttribute("HuzzChoosing") ~= (show == true) then
			player:SetAttribute("HuzzChoosing", show == true) -- (local only: shift lock frees the mouse)
		end
		if show and not wasVisible then
			sent = nil
			Motion.pop(hero.Instance)
			Motion.pop(chicken.Instance)
		end
		wasVisible = show == true
		if not show then return end
		local left = math.max(0, (round:GetAttribute("EndsAt") or now) - now)
		fill.Size = UDim2.fromScale(math.clamp(left / Config.Pick.ChooseTime, 0, 1), 1)
		fill.BackgroundColor3 = if left <= 3 then rgb(255, 110, 120) else C.Progress
		secs.Text = tostring(math.ceil(left))
		hero.line.Text = "Run first. Alone."
		hero.line2.Text = `Make it: carry her +{Config.HeroBonus}`
		chicken.line.Text = "Run with the group"
		chicken.line2.Text = "Safe, but no girl"
	end
	RunService.RenderStepped:Connect(refresh)
	HeroChoice.refresh = refresh -- (the offline preview calls it)
	return panel
end

return HeroChoice
