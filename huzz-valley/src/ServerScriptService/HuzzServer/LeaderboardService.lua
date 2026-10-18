--[[
	The lobby leaderboards' numbers (owner, Oct 18: "make the leaderboards just like in the video i sent you from the
	game"). Five boards (Config/Leaderboards): HIGHEST LEVEL, MOST WINS, MOST CATCHES, MOST RESCUES, MOST GIRLS.

	Where they stand: anything in Workspace named "Leaderboard" (a Model or a Part; also "Leaderboard 2" ...) or
	tagged "HuzzLeaderboard". Its "Stat" attribute picks the board (Level, Wins, Catches, Rescues, Girls); boards
	without one get the next stat in the list. The place build (tools/place/build_yours.luau) puts five round each
	lobby so the owner can drag them; with none at all, the same five are made here round each lobby floor.
	Every board gets the tag, so each screen (Gameplay/Leaderboards) finds it, draws it and turns it towards you.

	Numbers: live game only, one OrderedDataStore per stat (saved from each player's profile every 90 s when it
	changed, and when they leave; each board's top 50 read every 60 s; every call in pcall and only while Roblox's
	request budget allows). Players in this server are always mixed in with their live numbers, so a board is
	never empty: in Studio (saves are a Mock there) or when DataStores fail, it shows just this server.
	Sent to everyone as JSON in attributes on ReplicatedStorage.HuzzLeaderboards (one per stat).
]]
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Leaderboards)
local Progression = require(Shared.Config.Progression)
local Rules = require(Shared.LeaderboardRules)
local Look = require(Shared.LeaderboardLook)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local TAG = "HuzzLeaderboard"
local api = { Instance = Instance, UDim2 = UDim2, UDim = UDim, Color3 = Color3, Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, Enum = Enum, Font = Font }

local live = not RunService:IsStudio()
local stores = {} -- [stat] = OrderedDataStore (live only)
local saved = {} -- [stat] = { {u, n, v} } read from the store
local latest = {} -- [userId] = { name, values } (last seen numbers, also used when a player leaves)
local written = {} -- [userId] = { [stat] = value } last saved to the store
local names = {} -- [userId] = name
local folder: Folder

local function key(name: string): string
	return (string.gsub(name, "[%s_%-]", "")):lower()
end

local function statOf(value): string?
	if type(value) ~= "string" then return nil end
	for _, def in Config.Boards do
		if key(def.Stat) == key(value) then return def.Stat end
	end
	return nil
end

local function budget(kind: string): boolean
	local ok, n = pcall(function()
		return game:GetService("DataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType[kind])
	end)
	return not ok or (n or 0) > 1 -- (unknown budget: try; pcall catches a refusal)
end

-- Every board placed in Workspace (named or tagged), its Stat filled in, tagged for the clients.
local function findBoards(): { Instance }
	local found = {}
	local function add(item)
		if item and (item:IsA("Model") or item:IsA("BasePart")) and not table.find(found, item) then
			table.insert(found, item)
		end
	end
	for _, d in Workspace:GetDescendants() do
		if (d:IsA("Model") or d:IsA("BasePart")) and string.sub(key(d.Name), 1, 11) == "leaderboard" then
			-- (a part inside a board model is the model's, not a second board)
			local p = d.Parent
			local inside = false
			while p and p ~= Workspace do
				if string.sub(key(p.Name), 1, 11) == "leaderboard" then inside = true break end
				p = p.Parent
			end
			if not inside then add(d) end
		end
	end
	pcall(function()
		for _, t in CollectionService:GetTagged(TAG) do add(t) end
	end)
	return found
end

local function lobbyFloors(): { BasePart }
	local tagged, named, bases = {}, {}, {}
	pcall(function()
		for _, t in CollectionService:GetTagged("HuzzLobby") do
			if t:IsA("BasePart") then table.insert(tagged, t) end
		end
	end)
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") then
			if key(d.Name) == "lobby" then table.insert(named, d)
			elseif key(d.Name) == "spawnbaseplate" then table.insert(bases, d) end
		end
	end
	return if #tagged > 0 then tagged elseif #named > 0 then named else bases
end

-- No boards in the place: five round each lobby, on his podiums first (the same spots the place build uses).
local function makeDefaults(): { Instance }
	local made = {}
	local holder = Instance.new("Folder")
	holder.Name = "HuzzLeaderboards"
	local podiums = Look.podiums(Workspace)
	for _, floor in lobbyFloors() do
		for i, spot in Look.layout(api, Rules, floor, podiums, #Config.Boards) do
			local def = Config.Boards[i]
			local ok, model = pcall(Look.model, api, def, spot.at, Config.Size, Config.Lift, Config.Subtitle, Config.Shown, spot.podium)
			if ok and model then
				model.Parent = holder
				table.insert(made, model)
			else
				warn("[Huzz] leaderboard couldn't be built: " .. tostring(model))
			end
		end
	end
	holder.Parent = Workspace
	return made
end

local function setUp()
	local boards = findBoards()
	if #boards == 0 then boards = makeDefaults() end
	local nextStat = 1
	for _, b in boards do
		local stat = statOf(b:GetAttribute("Stat"))
		if not stat then
			stat = Config.Boards[(nextStat - 1) % #Config.Boards + 1].Stat
			nextStat += 1
			b:SetAttribute("Stat", stat)
		end
		b:SetAttribute("Stat", stat)
		if b:IsA("Model") then
			-- the whole board streams in at once, so a screen never draws half of one
			pcall(function() (b :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
		end
		if not pcall(function() b:AddTag(TAG) end) then pcall(function() CollectionService:AddTag(b, TAG) end) end
	end
	print(string.format("[Huzz] Leaderboards: %d boards", #boards))
end

local failedAt = {} -- userId -> os.clock() of a failed name lookup (asked again after 10 minutes, not every minute)
local function nameOf(userId: number): string
	if names[userId] then return names[userId] end
	if failedAt[userId] and os.clock() - failedAt[userId] < 600 then return "" end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.Name
		return p.Name
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and type(n) == "string" then
		names[userId] = n
		return n
	end
	failedAt[userId] = os.clock()
	return ""
end

-- The numbers of everyone in this server right now (also remembered for when they leave).
local function snapshotPlayers()
	for _, p in Players:GetPlayers() do
		local profile = DataService.get(p)
		if profile and profile.Data then
			latest[p.UserId] = { name = p.Name, values = Rules.values(profile.Data, Progression.XPPerLevel) }
			names[p.UserId] = p.Name
		end
	end
end

local function save(userId: number)
	local rec = latest[userId]
	if not live or not rec then return end
	written[userId] = written[userId] or {}
	for _, def in Config.Boards do
		local v = rec.values[def.Stat]
		local store = stores[def.Stat]
		if store and v and v > 0 and written[userId][def.Stat] ~= v and budget("SetIncrementSortedAsync") then
			local ok = pcall(store.SetAsync, store, tostring(userId), v)
			if ok then written[userId][def.Stat] = v end
		end
	end
end

local function read(def)
	local store = stores[def.Stat]
	if not store or not budget("GetSortedAsync") then return end
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Top)
	if not ok or not pages then return end
	local ok2, page = pcall(pages.GetCurrentPage, pages)
	if not ok2 or type(page) ~= "table" then return end
	local list = {}
	for _, item in page do
		local u = tonumber(item.key)
		if u then table.insert(list, { u = u, n = "", v = tonumber(item.value) or 0 }) end
	end
	for _, e in list do e.n = nameOf(e.u) end
	saved[def.Stat] = list
end

local function publish()
	snapshotPlayers()
	for _, def in Config.Boards do
		local here = {}
		for _, p in Players:GetPlayers() do
			local rec = latest[p.UserId]
			if rec then table.insert(here, { u = p.UserId, n = rec.name, v = rec.values[def.Stat] or 0 }) end
		end
		local entries = Rules.rank({ here, saved[def.Stat] or {} }, Config.Top)
		local ok, json = pcall(function() return HttpService:JSONEncode(entries) end)
		if ok and folder:GetAttribute(def.Stat) ~= json then folder:SetAttribute(def.Stat, json) end
	end
end

function LeaderboardService.start()
	folder = ReplicatedStorage:FindFirstChild("HuzzLeaderboards") or Instance.new("Folder")
	folder.Name = "HuzzLeaderboards"
	folder.Parent = ReplicatedStorage
	local okSetup, err = pcall(setUp)
	if not okSetup then warn("[Huzz] Leaderboards: " .. tostring(err)) end

	if live then
		local ok = pcall(function()
			local DataStoreService = game:GetService("DataStoreService")
			for _, def in Config.Boards do
				stores[def.Stat] = DataStoreService:GetOrderedDataStore(Config.StorePrefix .. def.Stat)
			end
		end)
		if not ok then live = false end -- (no DataStores here: the boards show this server only)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = DataService.get(player)
		if profile and profile.Data then
			latest[player.UserId] = { name = player.Name, values = Rules.values(profile.Data, Progression.XPPerLevel) }
		end
		task.spawn(function()
			save(player.UserId)
			latest[player.UserId] = nil
			written[player.UserId] = nil
		end)
		task.delay(1, pcall, publish)
	end)
	Players.PlayerAdded:Connect(function() task.delay(5, pcall, publish) end)

	-- publish: the live numbers of everyone here (often), mixed with the saved top 50
	task.spawn(function()
		while true do
			pcall(publish)
			task.wait(if live then Config.PublishEvery else Config.StudioPublishEvery)
		end
	end)
	if live then
		task.spawn(function() -- read each board's top 50, spread over the minute
			while live do
				for _, def in Config.Boards do
					pcall(read, def)
					task.wait(Config.ReadEvery / #Config.Boards)
				end
				pcall(publish)
			end
		end)
		task.spawn(function() -- save everyone's numbers that changed
			while live do
				task.wait(Config.WriteEvery)
				pcall(snapshotPlayers)
				for _, p in Players:GetPlayers() do
					pcall(save, p.UserId)
					task.wait(0.2)
				end
			end
		end)
		game:BindToClose(function()
			pcall(snapshotPlayers)
			for _, p in Players:GetPlayers() do pcall(save, p.UserId) end
		end)
	end
end

return LeaderboardService
