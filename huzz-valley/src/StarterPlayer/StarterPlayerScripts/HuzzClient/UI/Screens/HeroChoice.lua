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
local INK = rgb(16, 14, 38)
local LOOKS = {
	Hero = { Top = rgb(255, 230, 130), Bottom = rgb(240, 160, 28), Text = rgb(74, 40, 0), Line = rgb(110, 62, 6) },
	Chicken = { Top = rgb(255, 250, 238), Bottom = rgb(238, 218, 184), Text = rgb(122, 64, 18), Line = rgb(128, 90, 52) },
}

local function choiceCard(parent: Instance, name: string, key: string, word: string, x: number, y: number, onClick: () -> ())
	local look = LOOKS[name]
	local btn = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + CARD.W / 2, y + CARD.H / 2), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(16) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(look.Top, look.Bottom), Parent = btn })
	new("UIStroke", { Name = "Rim", Thickness = 3, Color = INK, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	new("Frame", { Name = "Gloss", Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = btn }, { Kit.corner(4) })
	local keyDot = new("TextLabel", {
		Name = "Key", Text = key, FontFace = F.Display, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = INK,
		Position = UDim2.fromOffset(-9, -9), Size = UDim2.fromOffset(30, 30), ZIndex = 3, Parent = btn,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	new("TextLabel", {
		Name = "Word", Text = word, FontFace = F.Display, TextSize = 38, TextColor3 = look.Text, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), ZIndex = 2, Parent = btn,
	})
	local line1 = new("TextLabel", {
		Name = "Line", Text = "", FontFace = F.Round, TextSize = 15, TextColor3 = look.Line, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 18), ZIndex = 2, Parent = btn,
	})
	local line2 = new("TextLabel", {
		Name = "Line2", Text = "", FontFace = F.Round, TextSize = 13, TextColor3 = look.Line, TextTransparency = 0.15, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
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
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = panel }), function() return Scale.hud(PAGE_H) * 0.8 end)
	local title = new("TextLabel", {
		Name = "Hint", Text = "CHICKEN OR HERO?", FontFace = F.Display, TextSize = 34, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38), Parent = panel,
	}, { new("UIStroke", { Name = "Outline", Color = INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }) })
	new("UIGradient", { Name = "Shine", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(255, 222, 130)), Parent = title })
	-- the time left: a bar that empties (and the seconds)
	local timer = new("Frame", { Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(260, 12), BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = panel }, { Kit.corner(6) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 214, 70), BorderSizePixel = 0, Parent = timer }, { Kit.corner(6) })
	local secs = new("TextLabel", { Name = "Seconds", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 8, 0.5, 0), Size = UDim2.fromOffset(40, 20), Text = "", FontFace = F.Display, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Parent = timer },
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
		if input.KeyCode == Enum.KeyCode.One then pick(true)
		elseif input.KeyCode == Enum.KeyCode.Two then pick(false) end
	end)

	local wasVisible = false
	local function refresh()
		local now = Workspace:GetServerTimeNow()
		local openAt = (round:GetAttribute("PickAt") or 0) + Config.Pick.Roulette
		local show = round:GetAttribute("Stage") == "Picking" and round:GetAttribute("PickId") == player.UserId
			and now >= openAt - 0.2 and player:GetAttribute("MenuOpen") ~= true
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
		fill.BackgroundColor3 = if left <= 3 then rgb(255, 110, 110) else rgb(255, 214, 70)
		secs.Text = tostring(math.ceil(left))
		local girl = round:GetAttribute("GirlName") or "her"
		hero.line.Text = "Cross alone first"
		hero.line2.Text = if round:GetAttribute("HolderId") == player.UserId then `Make it: +{Config.HeroBonus} coins` else `Make it: win {girl}!`
		chicken.line.Text = "Run with everyone"
		chicken.line2.Text = "Play it safe"
	end
	RunService.RenderStepped:Connect(refresh)
	HeroChoice.refresh = refresh -- (the offline preview calls it)
	return panel
end

return HeroChoice
