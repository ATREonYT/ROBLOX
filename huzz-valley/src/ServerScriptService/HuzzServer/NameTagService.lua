--[[
	Name tags over every player, as in Huss Valley: a small coloured title (their role this round),
	the name in bold, "Lv. 6 · 8 wins" under it. Downed runners show HELP! and a bar that fills while
	someone rescues them. The picked runner's choice shows big over their head (HERO / CHICKEN).
	Made on the server (everyone sees the same); Roblox's own name over the head is hidden.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local DataService = require(script.Parent.DataService)

local NameTags = {}

-- The lobby kit's faces (UI/Theme.Fonts): Montserrat Black for the big HERO / CHICKEN, Montserrat Bold for
-- the name, Roboto Condensed Bold for the role, Montserrat Medium for the level line.
local MONTSERRAT, CONDENSED = "rbxasset://fonts/families/Montserrat.json", "rbxasset://fonts/families/RobotoCondensed.json"
local DISPLAY = Font.new(MONTSERRAT, Enum.FontWeight.Heavy)
local BOLD = Font.new(MONTSERRAT, Enum.FontWeight.Bold)
local ROUND = Font.new(CONDENSED, Enum.FontWeight.Bold)
local SMALL = Font.new(MONTSERRAT, Enum.FontWeight.Medium)
local INK = Color3.fromRGB(10, 20, 51) -- (the kit's frame navy)

local TITLES = {
	Runner = { "RUNNER", Color3.fromRGB(110, 184, 255) },
	Catcher = { "CATCHER", Color3.fromRGB(255, 92, 104) },
	Hero = { "HERO", Color3.fromRGB(255, 214, 70) },
	Safe = { "SAFE", Color3.fromRGB(110, 236, 140) },
	Downed = { "HELP!", Color3.fromRGB(255, 160, 90) },
}
local BADGES = {
	HERO = Color3.fromRGB(255, 214, 70),
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

-- look: "Runner" | "Catcher" | "Hero" | "Safe" | "Downed" | nil (lobby: no title). badge: "HERO" | "CHICKEN" | nil.
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
	local title = TITLES[look]
	gui.Title.Text = if title then title[1] else ""
	gui.Title.TextColor3 = if title then title[2] else Color3.new(1, 1, 1)
	gui.PlayerName.Text = player.DisplayName
	local profile = DataService.get(player)
	local data = profile and profile.Data
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

return NameTags
