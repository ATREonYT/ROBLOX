--!strict
-- LeaderboardService — fills the two wall boards every floor's hub hangs on
-- its north wall (Kit.boardFrame): "Employee of the Month" (top 3 in this
-- server by rank) and the all-time Wins board (OrderedDataStore top 10).
--
-- Server-built SurfaceGui text is fine here because rebuilds are rare (30/60s)
-- and the content is identical for everyone — no per-player work at all.
-- Everything DataStore is pcall'd: the vanity board must never take a server
-- down, and in Studio without API access it simply stays empty.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)

local Shared = ReplicatedStorage.Shared
local Ranks = require(Shared.Config.Ranks)
local Format = require(Shared.Util.Format)

local Trove = require(ReplicatedStorage.Packages.Trove)

local EOTM_REFRESH_SECONDS = 30
local WINS_REFRESH_SECONDS = 60
local WINS_STORE_NAME = "AllTimeWins_v1"
local EOTM_ROW_COUNT = 3
local WINS_ROW_COUNT = 10

local MEDALS = { "🥇", "🥈", "🥉" }

-- Board faces are near-white (Kit.boardFrame), so text is dark "ink" with the
-- game's gold reserved for the numbers column.
local COLOR_INK = Color3.fromRGB(43, 47, 58)
local COLOR_VALUE = Color3.fromRGB(163, 122, 8)
local COLOR_STRIPE = Color3.fromRGB(43, 47, 58)

type RowSpec = {
	Left: string, -- medal / "#n"
	Middle: string, -- player name
	Right: string, -- rank title or Wins value
}

local LeaderboardService = {}

local trove = Trove.new()
local eotmContents: { Frame } = {}
local winsContents: { Frame } = {}

local winsStore: OrderedDataStore? = nil
-- UserId -> Wins value last persisted this session; skips no-op SetAsyncs so
-- an idle server never burns DataStore budget.
local lastWritten: { [number]: number } = {}
-- UserId -> username, so the top-10 rebuild doesn't re-ask the web every minute.
local nameCache: { [number]: string } = {}
-- The last successfully fetched top 10, kept so a transient fetch failure
-- redraws yesterday's truth instead of wiping the board.
local lastTopWins: { { UserId: number, Wins: number } } = {}

-- ── Row rendering (plain Frames/TextLabels, rebuilt in place) ───────────────

local function makeRowLabel(parent: Frame, xScale: number, widthScale: number, text: string, font: Enum.Font, color: Color3, alignment: Enum.TextXAlignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(xScale, 0.1)
	label.Size = UDim2.fromScale(widthScale, 0.8)
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = alignment
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

-- Wipes the content frame and lays `rows` out top-to-bottom. `rowCount` fixes
-- the row height even when fewer entries exist, so a board with one entry
-- doesn't render that entry six feet tall.
local function rebuildBoard(content: Frame, rows: { RowSpec }, rowCount: number, emptyText: string)
	content:ClearAllChildren()

	if #rows == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.fromScale(1, 0.3)
		empty.Position = UDim2.fromScale(0, 0.35)
		empty.Font = Enum.Font.Gotham
		empty.Text = emptyText
		empty.TextColor3 = COLOR_INK
		empty.TextTransparency = 0.35
		empty.TextScaled = true
		empty.Parent = content
		return
	end

	local rowHeight = 1 / rowCount
	for index, row in rows do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "Row" .. index
		rowFrame.BackgroundColor3 = COLOR_STRIPE
		-- Zebra striping, done with transparency so the palette stays the
		-- board's own paper color.
		rowFrame.BackgroundTransparency = if index % 2 == 0 then 0.94 else 1
		rowFrame.BorderSizePixel = 0
		rowFrame.Position = UDim2.fromScale(0, (index - 1) * rowHeight)
		rowFrame.Size = UDim2.fromScale(1, rowHeight)
		rowFrame.Parent = content

		makeRowLabel(rowFrame, 0.02, 0.12, row.Left, Enum.Font.FredokaOne, COLOR_INK, Enum.TextXAlignment.Center)
		makeRowLabel(rowFrame, 0.16, 0.48, row.Middle, Enum.Font.FredokaOne, COLOR_INK, Enum.TextXAlignment.Left)
		makeRowLabel(rowFrame, 0.66, 0.32, row.Right, Enum.Font.Gotham, COLOR_VALUE, Enum.TextXAlignment.Right)
	end
end

-- ── Employee of the Month (in-server, live) ─────────────────────────────────

local function eotmRows(): { RowSpec }
	local entries: { { Name: string, Rank: number, Productivity: number } } = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			table.insert(entries, { Name = player.DisplayName, Rank = data.Rank, Productivity = data.Productivity })
		end
	end
	table.sort(entries, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank > b.Rank
		end
		return a.Productivity > b.Productivity
	end)

	local rows: { RowSpec } = {}
	for index = 1, math.min(EOTM_ROW_COUNT, #entries) do
		local entry = entries[index]
		local rankDef = Ranks.List[entry.Rank]
		table.insert(rows, {
			Left = MEDALS[index],
			Middle = entry.Name,
			Right = if rankDef then rankDef.Name else "?",
		})
	end
	return rows
end

local function refreshEotmBoards()
	local rows = eotmRows()
	for _, content in eotmContents do
		rebuildBoard(content, rows, EOTM_ROW_COUNT, "Clock in to compete!")
	end
end

-- ── All-time Wins (OrderedDataStore) ────────────────────────────────────────

local function persistWins(userId: number, wins: number)
	local store = winsStore
	if not store then
		return
	end
	-- OrderedDataStores only take non-negative integers.
	local rounded = math.max(0, math.floor(wins))
	if lastWritten[userId] == rounded then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(userId), rounded)
	end)
	if ok then
		lastWritten[userId] = rounded
	else
		warn("[LeaderboardService] Wins write failed:", err)
	end
end

local function fetchTopWins()
	local store = winsStore
	if not store then
		return
	end
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, WINS_ROW_COUNT)
		return pages:GetCurrentPage()
	end)
	if not ok then
		warn("[LeaderboardService] Wins fetch failed:", result)
		return -- keep showing the previous fetch; stale beats blank
	end

	local top: { { UserId: number, Wins: number } } = {}
	for _, entry in result :: { any } do
		local userId = tonumber(entry.key)
		local wins = tonumber(entry.value)
		if userId and wins then
			table.insert(top, { UserId = userId, Wins = wins })
		end
	end
	lastTopWins = top
end

-- Board keys are UserIds; turning them back into names needs a web call for
-- anyone not in this server, so results are cached and failures fall back to
-- a placeholder that self-heals on the next refresh.
local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local inServer = Players:GetPlayerByUserId(userId)
	if inServer then
		nameCache[userId] = inServer.DisplayName
		return inServer.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return "Employee #" .. userId
end

local function refreshWinsBoards()
	local rows: { RowSpec } = {}
	for index, entry in lastTopWins do
		table.insert(rows, {
			Left = MEDALS[index] or ("#" .. index),
			Middle = nameFor(entry.UserId),
			Right = Format.abbreviate(entry.Wins),
		})
	end
	for _, content in winsContents do
		rebuildBoard(content, rows, WINS_ROW_COUNT, "No legends yet")
	end
end

local function flushLoadedPlayers()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			persistWins(player.UserId, data.Wins)
		end
	end
end

-- ── Board discovery ─────────────────────────────────────────────────────────

-- The world builder gives each leaderboard pillar a bare Neon "Screen" part.
-- This service owns what goes ON it, so it attaches the SurfaceGui itself and
-- returns the frame rows get parented to.
local function attachContentFrame(screen: BasePart, title: string): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.Parent = screen

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(1, 0.12)
	header.Font = Enum.Font.FredokaOne
	header.Text = title
	header.TextColor3 = Color3.fromRGB(255, 236, 180)
	header.TextScaled = true
	header.Parent = gui

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromScale(0, 0.13)
	content.Size = UDim2.fromScale(1, 0.87)
	content.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = content

	return content
end

local function collectBoards()
	-- The world builder names every pillar screen; find them by walking the
	-- world folder rather than through a manifest, so this service does not
	-- care how the map was assembled.
	local world = Workspace:FindFirstChild("BusinessEvolutionWorld")
	if not world then
		warn("[LeaderboardService] no world folder yet — boards stay blank")
		return
	end
	-- Pillars are built left to right: POWER, RESTRUCTURES, WINS. The first
	-- feeds the in-server standings, the last the all-time Wins board.
	local screens: { BasePart } = {}
	for _, descendant in world:GetDescendants() do
		if descendant.Name == "Screen" and descendant:IsA("BasePart") then
			table.insert(screens, descendant)
		end
	end
	table.sort(screens, function(a, b)
		return a.Position.X < b.Position.X
	end)
	if screens[1] then
		table.insert(eotmContents, attachContentFrame(screens[1], "TOP POWER (SERVER)"))
	end
	if screens[3] then
		table.insert(winsContents, attachContentFrame(screens[3], "TOP WINS (ALL TIME)"))
	end
end

-- ── Service lifecycle ───────────────────────────────────────────────────────

function LeaderboardService:Init()
	-- Getting the store object is what throws in Studio without API access;
	-- catching it HERE turns every later DataStore path into a clean no-op
	-- (winsStore stays nil) instead of six scattered failure modes.
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetOrderedDataStore(WINS_STORE_NAME)
	end)
	if ok then
		winsStore = storeOrError
	else
		warn("[LeaderboardService] DataStores unavailable — Wins board disabled:", storeOrError)
	end
end

function LeaderboardService:Start()
	collectBoards()

	-- Leave-time write catches the 60s flush window; PlayerUnloading fires
	-- while the profile is still readable. Snapshot the number synchronously —
	-- by the time the spawned write runs, the profile is gone.
	trove:Connect(DataService.PlayerUnloading :: any, function(player: Player)
		local data = DataService.get(player)
		if data then
			local userId = player.UserId
			local wins = data.Wins
			task.spawn(persistWins, userId, wins)
		end
	end)

	trove:Add(task.spawn(function()
		while true do
			refreshEotmBoards()
			task.wait(EOTM_REFRESH_SECONDS)
		end
	end))

	trove:Add(task.spawn(function()
		while true do
			flushLoadedPlayers()
			fetchTopWins()
			refreshWinsBoards()
			task.wait(WINS_REFRESH_SECONDS)
		end
	end))
end

return LeaderboardService
