--!strict
-- +1 Chess Evolution: top-10 Wins board beside the spawn (note 20 rule 26, Blueprint §3).
-- Uses an OrderedDataStore; in Studio without API access it shows a friendly line instead.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3, align: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(25, 25, 35)
	s.Parent = t
	t.Parent = parent
	return t
end

local function buildBoard(map: Instance): { TextLabel }
	local spot = map:FindFirstChild("LeaderboardSpot") :: BasePart?
	local cf = if spot then spot.CFrame else CFrame.lookAt(Vector3.new(-16, 9, 54), Vector3.new(0, 9, 64))
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	local function block(name: string, size: Vector3, at: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at
		p.Color = color
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local board = block("Board", Vector3.new(12, 13, 0.8), cf, Color3.fromRGB(40, 36, 70))
	block("Frame", Vector3.new(12.8, 13.8, 0.6), cf * CFrame.new(0, 0, 0.25), Color3.fromRGB(255, 200, 40))
	for _, x in { -5, 5 } do
		block("Post", Vector3.new(1, 9, 1), cf * CFrame.new(x, -7, 0.3), Color3.fromRGB(176, 92, 42))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Top"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, "Title", "TOP WINS", UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0.02), Color3.fromRGB(255, 210, 60))
	local rows = {}
	for i = 1, 10 do
		local row = label(gui, "Row" .. i, "", UDim2.fromScale(0.9, 0.075), UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.083),
			if i == 1 then Color3.fromRGB(255, 215, 80) elseif i == 2 then Color3.fromRGB(225, 230, 240) elseif i == 3 then Color3.fromRGB(240, 160, 90) else Color3.new(1, 1, 1),
			Enum.TextXAlignment.Left)
		table.insert(rows, row)
	end
	model.Parent = map
	return rows
end

function Leaderboard.Start(config: any, map: Instance)
	local rows = buildBoard(map)
	local store: OrderedDataStore? = nil
	local ok = pcall(function()
		store = DataStoreService:GetOrderedDataStore(config.Leaderboard.storeName)
	end)
	local names: { [number]: string } = {}
	local function nameOf(id: number): string
		if names[id] then
			return names[id]
		end
		local got, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
		names[id] = if got then n else "Player"
		return names[id]
	end
	local function refresh()
		-- write everyone here, then read the top
		local readOk = false
		if ok and store then
			for _, player in Players:GetPlayers() do
				local stats = player:FindFirstChild("leaderstats")
				local wins = stats and stats:FindFirstChild("Wins") :: IntValue?
				if wins and wins.Value > 0 then
					pcall(function()
						(store :: OrderedDataStore):SetAsync(tostring(player.UserId), wins.Value)
					end)
				end
			end
			local got, pages = pcall(function()
				return (store :: OrderedDataStore):GetSortedAsync(false, config.Leaderboard.size)
			end)
			if got and pages then
				readOk = true
				local page = (pages :: DataStorePages):GetCurrentPage()
				for i, row in rows do
					local e = page[i]
					row.Text = if e then `{i}. {nameOf(tonumber(e.key) or 0)}   {e.value}` else ""
				end
			end
		end
		if not readOk then
			-- Studio without API access: show who is here now
			local here = Players:GetPlayers()
			table.sort(here, function(a, b)
				local wa = a:FindFirstChild("leaderstats") and (a.leaderstats :: any).Wins.Value or 0
				local wb = b:FindFirstChild("leaderstats") and (b.leaderstats :: any).Wins.Value or 0
				return wa > wb
			end)
			for i, row in rows do
				local p = here[i]
				row.Text = if p then `{i}. {p.Name}   {(p :: any).leaderstats.Wins.Value}` else ""
			end
		end
	end
	task.spawn(function()
		task.wait(5)
		while true do
			refresh()
			task.wait(config.Leaderboard.refresh)
		end
	end)
	print("[Chess] leaderboard ready")
end

return Leaderboard
