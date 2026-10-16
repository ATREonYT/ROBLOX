-- Hero or Chicken (owner's call, Config/Round.Heroes): during the countdown every runner who isn't carrying her
-- picks. HERO goes for the girl (only Heroes can take her by crossing first, unless no Hero makes it) and glows
-- yellow; CHICKEN just tries to get across. Picking nothing = Chicken. Two cards above the power tiles (a gold
-- HERO card, a cream CHICKEN card; the picked one is lit with a white rim and a PICKED tag, the other dimmed);
-- keys 1 and 2. While it shows, shift lock lets go of the mouse (the "HuzzChoosing" attribute) so you can click.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

local W, H = 372, 124
local CARD = { W = 172, H = 88, Gap = 26 }
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local INK = rgb(16, 14, 38)
local LOOKS = {
	Hero = { Top = rgb(255, 230, 130), Bottom = rgb(240, 160, 28), Text = rgb(74, 40, 0), Line = rgb(110, 62, 6) },
	Chicken = { Top = rgb(255, 250, 238), Bottom = rgb(238, 218, 184), Text = rgb(122, 64, 18), Line = rgb(128, 90, 52) },
}

local function choiceCard(parent: Instance, name: string, key: string, word: string, x: number, onClick: () -> ())
	local look = LOOKS[name]
	local btn = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + CARD.W / 2, H - CARD.H / 2), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(14) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(look.Top, look.Bottom), Parent = btn })
	local rim = new("UIStroke", { Name = "Rim", Thickness = 3, Color = INK, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	new("Frame", { Name = "Gloss", Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 0, 22), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = btn }, { Kit.corner(10) })
	-- the key to press, in a dark circle at the top left
	local keyDot = new("TextLabel", {
		Name = "Key", Text = key, FontFace = F.Display, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = INK,
		Position = UDim2.fromOffset(-8, -8), Size = UDim2.fromOffset(28, 28), ZIndex = 3, Parent = btn,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	local wordLabel = new("TextLabel", {
		Name = "Word", Text = word, FontFace = F.Display, TextSize = 34, TextColor3 = look.Text, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 36), ZIndex = 2, Parent = btn,
	})
	local line = new("TextLabel", {
		Name = "Line", Text = "", FontFace = F.Round, TextSize = 15, TextColor3 = look.Line, BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 20), ZIndex = 2, Parent = btn,
	})
	local picked = new("TextLabel", {
		Name = "Picked", Text = "PICKED", FontFace = F.Display, TextSize = 14, TextColor3 = INK, BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(70, 22), ZIndex = 3, Visible = false, Parent = btn,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Thickness = 2, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	-- dims the card you didn't pick
	local shade = new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4, Parent = btn }, { Kit.corner(14) })
	btn.Activated:Connect(onClick)
	local function set(on: boolean)
		rim.Color = if on then Color3.new(1, 1, 1) else INK
		rim.Thickness = if on then 4 else 3
		rim.Transparency = if on then 0 else 0.15
		picked.Visible = on
		shade.BackgroundTransparency = if on then 1 else 0.5
		btn.Size = if on then UDim2.fromOffset(CARD.W + 8, CARD.H + 4) else UDim2.fromOffset(CARD.W, CARD.H)
	end
	return { Instance = btn, set = set, line = line, word = wordLabel, key = keyDot }
end

function HeroChoice.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local remote = Net.get("Hero") :: RemoteEvent
	local panel = new("Frame", {
		Name = "HeroChoice", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1, Visible = false, Parent = parent,
	})
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = panel }), function()
		local s = Scale.hud(PAGE_H) * 0.72
		-- sits just above the power tiles (PowerBar: 62 px tall, 10 px off the bottom, the same scale)
		panel.Position = UDim2.new(0.5, 0, 1, -math.round(10 + 62 * s + 12 * s))
		return s
	end)
	local hint = new("TextLabel", {
		Name = "Hint", Text = "HERO OR CHICKEN?", FontFace = F.Display, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28), Parent = panel,
	}, { new("UIStroke", { Name = "Outline", Color = INK, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round }) })

	local function pick(isHero: boolean)
		if panel.Visible then remote:FireServer(isHero) end
	end
	local x0 = W / 2 - CARD.Gap / 2 - CARD.W
	local hero = choiceCard(panel, "Hero", "1", "HERO", x0, function() pick(true) end)
	local chicken = choiceCard(panel, "Chicken", "2", "CHICKEN", W / 2 + CARD.Gap / 2, function() pick(false) end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.One then pick(true)
		elseif input.KeyCode == Enum.KeyCode.Two then pick(false) end
	end)

	local shownHero = nil
	local function refresh()
		local show = Config.Heroes and round:GetAttribute("Stage") == "Countdown" and player:GetAttribute("HuzzRole") == "Runner"
			and player:GetAttribute("HuzzStatus") == "Active" and round:GetAttribute("HolderId") ~= player.UserId
			and player:GetAttribute("MenuOpen") ~= true
		panel.Visible = show == true
		if player:GetAttribute("HuzzChoosing") ~= (show == true) then
			player:SetAttribute("HuzzChoosing", show == true) -- (local only: shift lock frees the mouse)
		end
		if not show then return end
		local isHero = player:GetAttribute("HuzzHero") == true
		if isHero ~= shownHero then
			local first = shownHero == nil
			shownHero = isHero
			hero.set(isHero)
			chicken.set(not isHero)
			if not first then Motion.pop((if isHero then hero else chicken).Instance) end
		end
		local girl = round:GetAttribute("GirlName") or "her"
		hero.line.Text = `Go for {girl}`
		chicken.line.Text = "Just get across"
	end
	RunService.RenderStepped:Connect(refresh)
	HeroChoice.refresh = refresh -- (the offline preview calls it)
	return panel
end

return HeroChoice
