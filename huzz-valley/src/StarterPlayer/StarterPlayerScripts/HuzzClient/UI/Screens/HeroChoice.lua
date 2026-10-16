-- Hero or Chicken (owner's call, Config/Round.Heroes): during the countdown every runner who isn't carrying her
-- picks. HERO goes for the girl (only Heroes can take her by crossing first, unless no Hero makes it) and glows
-- yellow; CHICKEN just tries to get across. Picking nothing = Chicken. Two kit buttons above the power tiles;
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

local C = Theme.Colors
local new = Kit.new

local HeroChoice = {}

local W, H = 340, 84
local BTN = { W = 162, H = 46, Gap = 16 }
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)

function HeroChoice.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local remote = Net.get("Hero") :: RemoteEvent
	local panel = new("Frame", {
		Name = "HeroChoice", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1, Visible = false, Parent = parent,
	})
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = panel }), function() return Scale.hud(PAGE_H) * 0.72 end)
	local hint = Kit.text({
		Name = "Hint", Text = "", FontFace = Theme.Fonts.Button, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24), Parent = panel,
	})
	new("UIStroke", { Name = "Outline", Color = C.TextShadow, Thickness = 1.5, Parent = hint })

	local function pick(isHero: boolean)
		if panel.Visible then remote:FireServer(isHero) end
	end
	local hero = Kit.button({
		Name = "Hero", Text = "HERO  [1]", Style = "Action", TextSize = 20,
		Position = UDim2.fromOffset(W / 2 - BTN.Gap / 2 - BTN.W, H - BTN.H), Size = UDim2.fromOffset(BTN.W, BTN.H),
		Parent = panel, OnClick = function() pick(true) end,
	})
	local chicken = Kit.button({
		Name = "Chicken", Text = "CHICKEN  [2]", Style = "Action", TextSize = 20,
		Position = UDim2.fromOffset(W / 2 + BTN.Gap / 2, H - BTN.H), Size = UDim2.fromOffset(BTN.W, BTN.H),
		Parent = panel, OnClick = function() pick(false) end,
	})

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
			shownHero = isHero
			hero.setStyle(if isHero then "Selected" else "Action")
			chicken.setStyle(if isHero then "Action" else "Selected")
		end
		local girl = round:GetAttribute("GirlName") or "her"
		hint.Text = if isHero then `HERO: first Hero across gets {girl}!` else `CHICKEN: just get across. Pick HERO to go for {girl}!`
		hint.TextColor3 = if isHero then Color3.fromRGB(255, 214, 92) else Color3.new(1, 1, 1)
	end
	RunService.RenderStepped:Connect(refresh)
	HeroChoice.refresh = refresh -- (the offline preview calls it)
	return panel
end

return HeroChoice
