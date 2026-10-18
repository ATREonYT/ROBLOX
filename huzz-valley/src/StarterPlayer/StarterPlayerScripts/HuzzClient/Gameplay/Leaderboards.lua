--[[
	Draws the lobby leaderboards on this screen and turns them towards your character (owner, Oct 18: "make the
	leaderboards just like in the video i sent you from the game, make them follow your character", then "make the
	leaderboards move smoothly, right now they move very weirdly", then "make it follow me in real time, not adjust
	after i move"). Each board turns about its own upright centre (never leans) to face you as you move, every
	frame (Rules.turn at Config/Leaderboards.TurnRate: caught up in about 0.1 s, so a respawn or a jump home is a
	quick swing, not a snap), at most TurnMax degrees from the way it was placed; from behind or far away it swings
	back home (Shared/LeaderboardRules aim, where the old spinning problem is written down). Only this screen's copy turns, nothing is sent, the stone base
	stays put; the Halloween pumpkin and candle are welded to the slab, so they turn with it.

	The boards are HuzzServer/LeaderboardService's (tag "HuzzLeaderboard": a Model with a "Board" part, or the owner's
	own Part). The face saved with the place (SurfaceGui "LeaderboardFace") is reused: it's copied into PlayerGui
	(adorned to the board, so its list scrolls with the mouse wheel, 12 of the top 50 at a time) and the saved one is
	switched off; a board without one gets the same face built by Shared/LeaderboardLook. Rows come from the JSON
	the server keeps in ReplicatedStorage.HuzzLeaderboards (one attribute per stat). Headshots are Roblox's own
	thumbnails (rbxthumb), no upload needed. Boards streamed out are dropped and drawn again when they return.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config.Leaderboards)
	local Rules = require(Shared.LeaderboardRules)
	local Look = require(Shared.LeaderboardLook)
	local Kit = require(script.Parent.Parent.UI.Kit)
	local ImageLoader = require(script.Parent.Parent.UI.ImageLoader)
	local Assets = require(Shared.Config.Assets)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local data = ReplicatedStorage:WaitForChild("HuzzLeaderboards", 60)

	local TAG = "HuzzLeaderboard"
	local api = { Instance = Instance, UDim2 = UDim2, UDim = UDim, Color3 = Color3, Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, Enum = Enum, Font = Font }
	local defs = {}
	for _, def in Config.Boards do defs[def.Stat] = def end

	local boards = {} -- [board instance] = { part, gui, canvas, def, yaw, centre }
	local function icon(name, props) return Kit.icon(name, props) end

	local function entriesFor(stat: string)
		local json = data and data:GetAttribute(stat)
		if type(json) ~= "string" then return {} end
		local ok, list = pcall(function() return HttpService:JSONDecode(json) end)
		return if ok and type(list) == "table" then list else {}
	end

	local function refill(rec)
		pcall(Look.fill, api, rec.canvas, rec.def, entriesFor(rec.def.Stat), Config.Shown, Rules.format, icon)
	end

	local function facePart(item: Instance): BasePart?
		if item:IsA("BasePart") then return item end
		local named = item:FindFirstChild("Board", true)
		if named and named:IsA("BasePart") then return named end
		-- (turning just its biggest part would leave the rest of a model behind: critic)
		warn(`[Huzz] Leaderboard {item:GetFullName()}: name the part the board goes on "Board"`)
		return nil
	end

	local function drop(item: Instance)
		local rec = boards[item]
		if not rec then return end
		boards[item] = nil
		if rec.gui then rec.gui:Destroy() end
		if rec.saved and rec.saved.Parent then rec.saved.Enabled = true end
		if rec.part and rec.part.Parent then rec.part.CFrame = rec.home end
	end

	local function bind(item: Instance)
		if boards[item] then return end
		local def = defs[item:GetAttribute("Stat") or ""]
		local part = facePart(item)
		if not def or not part then return end
		local saved = part:FindFirstChild("LeaderboardFace")
		local gui
		if saved and saved:IsA("SurfaceGui") then
			gui = saved:Clone()
			saved.Enabled = false
			for _, d in gui:GetDescendants() do
				local r = d:IsA("UICorner") and d:GetAttribute("HuzzRadius")
				if typeof(r) == "UDim" then d.CornerRadius = r end
			end
		else
			gui = Look.surface(api, part)
			gui.Parent = nil
			Look.canvas(api, gui, def, Config.Subtitle)
		end
		gui.Name = "Leaderboard_" .. def.Stat
		gui.Adornee = part
		gui.ResetOnSpawn = false
		gui.Enabled = true
		gui.Parent = playerGui
		local canvas = gui:FindFirstChild("Canvas")
		if not canvas then gui:Destroy() return end
		-- the face's own pictures (studs, web): drawn here from Shared/Images (the server can't), or the uploaded IDs
		for _, d in canvas:GetDescendants() do
			local name = d:IsA("ImageLabel") and d:GetAttribute("Icon")
			if name == "BoardStud" or name == "BoardWeb" then
				pcall(ImageLoader.apply, d, "Icons", name, Assets.icon(name))
			end
		end
		local cf = part.CFrame
		local look = cf.LookVector
		local home = Rules.yawTo(0, 0, look.X, look.Z)
		local rec = {
			part = part, gui = gui, saved = saved, canvas = canvas, def = def, home = cf,
			homeYaw = home, yaw = home, vel = 0, goal = home, written = home, centre = cf.Position,
		}
		boards[item] = rec
		refill(rec)
	end

	local function tryBind(item: Instance)
		local ok, err = pcall(bind, item)
		if not ok then warn("[Huzz] leaderboard: " .. tostring(err)) end
	end

	pcall(function()
		for _, item in CollectionService:GetTagged(TAG) do tryBind(item) end
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(item) task.defer(tryBind, item) end)
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(drop)
	end)
	-- a board's parts can arrive after its tag (streaming): try the unbound ones again now and then
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(function()
				for _, item in CollectionService:GetTagged(TAG) do
					if not boards[item] then tryBind(item) end
				end
			end)
			for item, rec in boards do
				if not item.Parent or not rec.part.Parent then drop(item) end
			end
		end
	end)

	if data then
		pcall(function()
			data.AttributeChanged:Connect(function(stat)
				for _, rec in boards do
					if rec.def.Stat == stat then refill(rec) end
				end
			end)
		end)
	end

	-- the turn towards you, in real time (upright axis only, about the slab's own centre)
	local rad = math.rad
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local at = root and root.CFrame.Position
		for _, rec in boards do
			local c = rec.centre
			local want = if at then Rules.aim(rec.homeYaw, c.X, c.Z, at.X, at.Z, rad(Config.TurnMax), rad(Config.TurnBehind), Config.TurnRange) else rec.homeYaw
			if math.abs(Rules.wrap(want - rec.yaw)) > 1e-4 then
				rec.yaw = Rules.turn(rec.yaw, want, math.min(dt, 0.1), Config.TurnRate)
			end
			if math.abs(Rules.wrap(rec.yaw - rec.written)) > 1e-4 then -- (only touch the part when it really moved)
				rec.written = rec.yaw
				rec.part.CFrame = CFrame.new(c) * CFrame.Angles(0, rec.yaw, 0)
			end
		end
	end)
end

return M
