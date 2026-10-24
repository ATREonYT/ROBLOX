--[[
	The AFK zone (Config/Afk): a glowing round pad in the lobby. Standing on it, or no input on your screen for
	Afk.IdleAfter seconds (Away, below), makes you AFK (player attribute HuzzAfk = true; HuzzAfkWhy "Zone" / "Away"): SkipService counts you as sitting out, so RoundService leaves you out of the next game, and your
	name tag shows AFK. RoundService starts it after MapService.init (it needs the lobby's spawn pad to find room).
	Logs on lines starting [HuzzAfk].
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Afk = require(ReplicatedStorage:WaitForChild("Shared").Config.Afk)
local SpawnSpots = require(ReplicatedStorage.Shared.SpawnSpots)
local MapService = require(script.Parent.MapService)
local NameTags = require(script.Parent.NameTagService)
local Net = require(ReplicatedStorage.Shared.Net)

local AfkService = {}
local zone = nil -- { centre: Vector3 (on the floor), radius: number }

local function make(class: string, props, parent: Instance?)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

-- His AfkZone part, if the place has one.
local function own(): BasePart?
	for _, d in Workspace:GetDescendants() do
		if d.Name == Afk.PartName and d:IsA("BasePart") then return d end
	end
	return nil
end

-- Open, flat ground beside the spawn pad for a pad of `radius`, or nil.
local function findRoom(radius: number): Vector3?
	local pad = MapService.lobbyPad()
	if not pad then return nil end
	local geo = MapService.geometry
	local top = pad.centre.Y
	local d = radius * 2
	for _, a in Afk.Search.Across do
		for _, k in Afk.Search.Inward do
			local c = pad.centre + pad.across * a + pad.inward * k
			local y = geo.floor(c.X, c.Z, top + 3, top - 3)
			if y and math.abs(y - top) <= SpawnSpots.MaxStep then
				c = Vector3.new(c.X, y, c.Z)
				local flat = not geo.blocked(c + Vector3.new(0, 3.2, 0), Vector3.new(d, 5.4, d), false)
				for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.7, 0.7 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 } } do
					if not flat then break end
					local p = c + pad.across * (o[1] * radius) + pad.inward * (o[2] * radius)
					local py = geo.floor(p.X, p.Z, y + 3, y - 3)
					flat = py ~= nil and math.abs(py - y) <= SpawnSpots.MaxStep
				end
				if flat then return c end
			end
		end
	end
	return nil
end

-- The pad, its glow and its title (his own part keeps its look: it only gets the title).
local function build(centre: Vector3, radius: number, theirs: boolean)
	local old = Workspace:FindFirstChild("HuzzAfkZone")
	if old then old:Destroy() end
	local model = make("Model", { Name = "HuzzAfkZone" })
	local base = make("Part", {
		Name = "Pad", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
		Size = Vector3.new(0.2, radius * 2, radius * 2), CFrame = CFrame.new(centre + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Afk.Color:Lerp(Color3.new(0, 0, 0), 0.35),
		Transparency = if theirs then 1 else 0.25,
	}, model)
	local top = make("Part", {
		Name = "Top", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
		Size = Vector3.new(radius * 2, 0.05, radius * 2), CFrame = CFrame.new(centre + Vector3.new(0, 0.25, 0)), Transparency = 1,
	}, model)
	if not theirs then
		local pool = make("SurfaceGui", { Name = "Glow", Face = Enum.NormalId.Top, CanvasSize = Vector2.new(240, 240), LightInfluence = 0, ResetOnSpawn = false }, top)
		for i, ring in { { 1.0, 0.55 }, { 0.86, 0.15 }, { 0.8, 0.7 }, { 0.5, 0.82 } } do
			local c = make("Frame", {
				Name = "Ring" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(ring[1], ring[1]),
				BackgroundColor3 = if i == 2 then Color3.fromRGB(28, 20, 56) else Afk.Color, BackgroundTransparency = ring[2], BorderSizePixel = 0,
			}, pool)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, c)
		end
		make("TextLabel", {
			Name = "Zzz", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.3), Text = "AFK", TextScaled = true, FontFace = Font.fromEnum(Enum.Font.FredokaOne),
			TextColor3 = Afk.Color:Lerp(Color3.new(1, 1, 1), 0.3), TextTransparency = 0.25,
		}, pool)
		make("PointLight", { Color = Afk.Color, Brightness = 0.6, Range = radius * 1.5, Shadows = false }, top)
	end
	local bb = make("BillboardGui", {
		Name = "Title", Size = UDim2.fromScale(12, 2.6), StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0), LightInfluence = 0,
		MaxDistance = 120, ResetOnSpawn = false,
	}, top)
	local title = make("TextLabel", {
		Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.62), Text = "\u{1F4A4} " .. Afk.Title,
		TextScaled = true, FontFace = Font.fromEnum(Enum.Font.FredokaOne), TextColor3 = Afk.Color,
	}, bb)
	make("UIStroke", { Color = Color3.fromRGB(28, 20, 56), Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, title)
	local line = make("TextLabel", {
		Name = "Line", BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.64), Size = UDim2.fromScale(1, 0.34), Text = Afk.Line,
		TextScaled = true, FontFace = Font.fromEnum(Enum.Font.GothamBold), TextColor3 = Color3.new(1, 1, 1),
	}, bb)
	make("UIStroke", { Color = Color3.fromRGB(28, 20, 56), Thickness = 1.5 }, line)
	model.Parent = Workspace
end

-- The AFK line over the name tag, only on a lobby tag (a tag in a game shows its role; never touched here).
local function showTag(player: Player, on: boolean)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("HuzzTag")
	if not gui or gui:GetAttribute("Look") ~= nil then return end
	local badge = gui:FindFirstChild("Badge")
	local showing = badge and badge.Visible and badge.Text == Afk.Badge
	if on and not (badge and badge.Visible) then
		NameTags.set(player, nil, Afk.Badge, nil)
	elseif not on and showing then
		NameTags.set(player, nil, nil, nil)
	end
end

-- Away (owner, Oct 24 06:12: "make the afk system be automatic, if a person is not moving for 4-5 minutes"): their
-- own screen says when it has had no input for Afk.IdleAfter seconds, and when they're back (Gameplay/AfkRejoin,
-- remote Away). Trusted as it is: being away only sits you out of games.
local away: { [Player]: boolean } = {}
local lastAway: { [Player]: number } = {}

local function check()
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local onZone = zone ~= nil and root ~= nil and root:IsA("BasePart") and Afk.inside(zone.centre, zone.radius, root.Position)
		local on = onZone or away[p] == true
		if (p:GetAttribute("HuzzAfk") == true) ~= on then
			p:SetAttribute("HuzzAfk", if on then true else nil)
		end
		local why = if onZone then "Zone" elseif on then "Away" else nil
		if p:GetAttribute("HuzzAfkWhy") ~= why then p:SetAttribute("HuzzAfkWhy", why) end
		showTag(p, on)
	end
end

function AfkService.isAfk(player: Player): boolean
	return player:GetAttribute("HuzzAfk") == true
end

function AfkService.zone()
	return zone
end

function AfkService.start()
	Net.get("Away").OnServerEvent:Connect(function(player, on)
		local t = os.clock()
		if type(on) ~= "boolean" or t - (lastAway[player] or 0) < 0.5 then return end
		lastAway[player] = t
		away[player] = if on then true else nil
		pcall(check)
	end)
	Players.PlayerRemoving:Connect(function(p)
		away[p], lastAway[p] = nil, nil
	end)
	task.spawn(function()
		while true do
			pcall(check)
			task.wait(Afk.Check)
		end
	end)
	-- (a moment first: the leaderboards, stands and props go up as the game starts, and the search must see them)
	task.wait(5)
	local theirs = own()
	local centre, radius
	if theirs then
		radius = math.max(theirs.Size.X, theirs.Size.Z) / 2
		centre = theirs.Position - Vector3.new(0, theirs.Size.Y / 2, 0)
	elseif Afk.Pad then
		radius = Afk.Radius
		centre = findRoom(radius)
	end
	if not centre then
		if Afk.Pad then warn("[HuzzAfk] no open ground beside the spawn found for the AFK zone: add a part named AfkZone where you want it") end
		return
	end
	zone = { centre = centre, radius = radius }
	build(centre, radius, theirs ~= nil)
	print(string.format("[HuzzAfk] AFK zone at %.0f, %.0f, %.0f (%s)", centre.X, centre.Y, centre.Z, if theirs then "your AfkZone part" else "beside the spawn"))
end

return AfkService
