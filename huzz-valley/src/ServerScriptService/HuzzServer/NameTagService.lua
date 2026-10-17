--[[
	Name tags over every player (and the Practice Bot), as in Huss Valley: a small coloured title (their role this round),
	the name in bold, "Lv. 6 · 8 wins" under it. Downed runners show HELP! and a bar that fills while
	someone rescues them; downed with the second chance used, OUT (nobody can help them up). The picked runner's choice shows big over their head (HERO / CHICKEN).
	Made on the server (everyone sees the same); Roblox's own name over the head is hidden.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local DataService = require(script.Parent.DataService)

local NameTags = {}

-- Gotham, as Huss Valley's tags: Black Italic for the big HERO / CHICKEN, Bold for the name and role,
-- Medium for the level line.
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local DISPLAY = Font.new(GOTHAM, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new(GOTHAM, Enum.FontWeight.Bold)
local ROUND = Font.new(GOTHAM, Enum.FontWeight.Bold)
local SMALL = Font.new(GOTHAM, Enum.FontWeight.Medium)
local INK = Color3.fromRGB(10, 20, 51) -- (the kit's frame navy)

local TITLES = {
	Runner = { "RUNNER", Color3.fromRGB(110, 184, 255) },
	Catcher = { "CATCHER", Color3.fromRGB(255, 92, 104) },
	Hero = { "HERO", Color3.fromRGB(91, 224, 122) },
	Safe = { "SAFE", Color3.fromRGB(110, 236, 140) },
	Downed = { "HELP!", Color3.fromRGB(255, 160, 90) },
	Out = { "OUT", Color3.fromRGB(176, 180, 196) }, -- down with the second chance used: nobody can help them up
}
local BADGES = {
	HERO = Color3.fromRGB(91, 224, 122),
	CHICKEN = Color3.fromRGB(255, 244, 222),
}

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	for k, v in props do
		l[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = props.Name == "Badge" and 3 or 1.5
	stroke.Parent = l
	return l
end

local function build(head)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HuzzTag"
	gui.Size = UDim2.new(6.4, 0, 3.1, 0) -- studs: smaller further away, like the reference
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	local badge = label({ Name = "Badge", Text = "", FontFace = DISPLAY, Position = UDim2.fromScale(0, -0.75), Size = UDim2.fromScale(1, 0.7), Visible = false })
	badge.Parent = gui
	label({ Name = "Title", Text = "", FontFace = ROUND, Position = UDim2.fromScale(0.15, 0), Size = UDim2.fromScale(0.7, 0.22) }).Parent = gui
	label({ Name = "PlayerName", Text = "", FontFace = BOLD, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0, 0.22), Size = UDim2.fromScale(1, 0.4) }).Parent = gui
	label({ Name = "Sub", Text = "", FontFace = SMALL, TextColor3 = Color3.fromRGB(205, 210, 230), Position = UDim2.fromScale(0.2, 0.62), Size = UDim2.fromScale(0.6, 0.18) }).Parent = gui
	-- the rescue bar (downed runners only)
	local bar = Instance.new("Frame")
	bar.Name = "Rescue"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.84)
	bar.Size = UDim2.fromScale(0.55, 0.1)
	bar.BackgroundColor3 = INK
	bar.BackgroundTransparency = 0.3
	bar.Visible = false
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0.5, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 236, 140)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	gui.Adornee = head
	gui.Parent = head
	return gui
end

-- look: "Runner" | "Catcher" | "Hero" | "Safe" | "Downed" | "Out" | nil (lobby: no title). badge: "HERO" | "CHICKEN" | nil.
-- rescue: 0..1 while someone is helping them up.
function NameTags.set(player, look, badge, rescue)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = head:FindFirstChild("HuzzTag") or build(head)
	gui:SetAttribute("Look", look)
	local profile = DataService.get(player)
	local data = profile and profile.Data
	-- the title line: your role in a game; in the lobby, the title you wear (Config/CoinShop "Title" rewards)
	local title = TITLES[look]
	local worn = not title and data and CoinShop.worn(data, "Title")
	local earned = worn and CoinShop.get(worn)
	local titleGradient = gui.Title:FindFirstChild("TitleGradient")
	if earned then
		gui.Title.Text = string.upper(earned.Name)
		gui.Title.TextColor3 = if #earned.Colors > 2 then Color3.new(1, 1, 1) else earned.Colors[1]
		if #earned.Colors > 2 and not titleGradient then
			titleGradient = Instance.new("UIGradient")
			titleGradient.Name = "TitleGradient"
			titleGradient.Parent = gui.Title
		end
		if titleGradient then
			if #earned.Colors > 2 then titleGradient.Color = CoinShop.sequence(earned) else titleGradient:Destroy() end
		end
	else
		gui.Title.Text = if title then title[1] else ""
		gui.Title.TextColor3 = if title then title[2] else Color3.new(1, 1, 1)
		if titleGradient then titleGradient:Destroy() end
	end
	gui.PlayerName.Text = player.DisplayName
	-- a coin-shop name colour (Config/CoinShop "Tag"): one colour, or a gradient across the name
	local tagKey = data and CoinShop.worn(data, "Tag")
	local tag = tagKey and CoinShop.get(tagKey)
	local nameGradient = gui.PlayerName:FindFirstChild("TagGradient")
	if tag and #tag.Colors > 1 and tag.Colors[1] ~= tag.Colors[2] then
		gui.PlayerName.TextColor3 = Color3.new(1, 1, 1)
		if not nameGradient then
			nameGradient = Instance.new("UIGradient")
			nameGradient.Name = "TagGradient"
			nameGradient.Parent = gui.PlayerName
		end
		nameGradient.Color = CoinShop.sequence(tag)
	else
		gui.PlayerName.TextColor3 = if tag then tag.Colors[1] else Color3.new(1, 1, 1)
		if nameGradient then nameGradient:Destroy() end
	end
	if data then
		local level = Progression.level(data.XP or 0)
		local wins = (data.Stats and data.Stats.Wins) or 0
		gui.Sub.Text = `Lv. {level} · {wins} {if wins == 1 then "win" else "wins"}`
	end
	gui.Badge.Visible = badge ~= nil
	gui.Badge.Text = badge or ""
	gui.Badge.TextColor3 = BADGES[badge or ""] or Color3.new(1, 1, 1)
	gui.Rescue.Visible = look == "Downed" and (rescue or 0) > 0
	gui.Rescue.Fill.Size = UDim2.fromScale(math.clamp(rescue or 0, 0, 1), 1)
end

-- After the save changes (a new title or name colour): redraws a lobby tag. A tag in a game keeps its role, and
-- the next round sync redraws it anyway.
function NameTags.restyle(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("HuzzTag")
	if gui and gui:GetAttribute("Look") == nil and not gui.Badge.Visible then
		NameTags.set(player, nil, nil, nil)
	end
end

-- The Practice Bot's tag (HuzzServer/PracticeBot): CATCHER over its name, and "BOT" where players show their level.
function NameTags.bot(character: Model, name: string)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = head:FindFirstChild("HuzzTag") or build(head)
	gui.Title.Text, gui.Title.TextColor3 = TITLES.Catcher[1], TITLES.Catcher[2]
	gui.PlayerName.Text, gui.PlayerName.TextColor3 = name, Color3.new(1, 1, 1)
	gui.Sub.Text = "BOT"
end

return NameTags
