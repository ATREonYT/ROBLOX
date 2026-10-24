--[[
	Passes every player's body stamp on to every screen (Shared/MotionStamps; owner, Oct 23 08:36: "make the desync
	the most precise it can be"). Each screen sends its own (Gameplay/MotionSend: server time, where, how fast, the
	speed its keys ask for, pushed or not) on the Motion UnreliableRemoteEvent; this checks it and sends it straight on
	to every other screen with the character it belongs to, gathered into a few messages a frame (Gameplay/OthersAhead
	draws them from it). The Practice Bot's body (the server moves it) gets its stamps from here, 20 a second.
	Checked, so a stamp can only say what the body really does: sane numbers; taken by the server's clock at most 0.6 s
	ago; the body alive, unanchored and not lying caught; where it says within Config Near studs of the server's own
	copy, plus how far the copy can be behind it (half the sender's ping, at most 0.25 s, and Roblox's 0.1 s, at the
	faster speed); no faster than it can go (its keys' speed never over its WalkSpeed, its own speed over that only when
	pushed, and never over a huss's); at most 40 a second per player. A stamp only moves where a body is drawn: the
	server's rules still judge every catch on its own copy (Shared/TouchHit), and a refused stamp just isn't passed on.
	Limit: a cheat could claim a push to be drawn up to MotionStamps PushStuds off on others' screens (only there:
	the server's hit check never follows a stamp further than its own copy's speed allows, RoundService.screenHit).
	MotionRelay.latest(player or model) -> the newest checked stamp (RoundService.screenHit moves the runner's on to
	the claim's moment when the server's copy hasn't got there yet).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MotionStamps = require(Shared.MotionStamps)
local C = MotionStamps.Config

local MotionRelay = {}
local MAX_RATE = 40 -- stamps a second we take from one player
local FAST = 125 -- studs/s: the fastest push a stamp may claim (a huss is 120; Config/Round Dash.Speed)
local PER_PACKET = 10 -- stamps in one message (an unreliable one carries at most ~900 bytes; one is ~60)
local latest = {} -- Player or bot Model -> stamp (a plain table, cleared on leave and on a new body)
local budget = {} -- Player -> { tokens, at }
local outbox = {} -- { { owner, character, stamp } } waiting for this frame's send

local function allow(p, now: number): boolean
	local b = budget[p]
	if not b then
		b = { tokens = 4, at = now }
		budget[p] = b
	end
	b.tokens = math.min(4, b.tokens + (now - b.at) * MAX_RATE)
	b.at = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

local function flat(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Is this stamp something the body could really be doing? (root = the server's copy of it; ping = the sender's
-- round trip in seconds: their stamp and our copy both left them half of it ago)
function MotionRelay.check(stamp, root: BasePart, humanoid: Humanoid?, serverNow: number, ping: number?): boolean
	if not stamp then return false end
	local age = serverNow - stamp.t
	if age > 0.6 or age < -0.1 then return false end
	if root.Anchored or (humanoid and humanoid.Health <= 0) then return false end
	local walk = if humanoid then humanoid.WalkSpeed else 0
	if flat(stamp.g) > walk + 2 then return false end
	local pushed = (stamp.push or 0) > 0
	local here = flat(root.AssemblyLinearVelocity)
	-- its speed: a walk or run within its WalkSpeed (or what our copy already does); a push within a huss's
	local top = if pushed then FAST else math.max(walk + 2, here * 1.25 + 4)
	if flat(stamp.v) > top then return false end
	-- where it says: near our copy, allowing for the time our copy is behind it at the faster of the two speeds
	local behind = math.clamp((ping or 0.1) / 2, 0, 0.25) + 0.1
	if (stamp.p - root.Position).Magnitude > C.Near + math.max(here, flat(stamp.v)) * behind then return false end
	return true
end

function MotionRelay.latest(who): any
	return latest[who]
end

-- This frame's stamps, to every screen but their own (in a few messages, not one per stamp per screen).
local function flush(remote)
	if #outbox == 0 then return end
	local list = outbox
	outbox = {}
	for _, viewer in Players:GetPlayers() do
		local packet = {}
		for _, e in list do
			if e[1] ~= viewer and e[2].Parent ~= nil then
				local st = e[3]
				table.insert(packet, { e[2], st.t, st.p, st.v, st.g, st.push })
				if #packet >= PER_PACKET then
					remote:FireClient(viewer, packet)
					packet = {}
				end
			end
		end
		if #packet > 0 then remote:FireClient(viewer, packet) end
	end
end

function MotionRelay.start()
	local remote = require(Shared.Net).get("Motion")
	remote.OnServerEvent:Connect(function(player, t, p, v, g, push)
		if not allow(player, os.clock()) then return end
		local role = player:GetAttribute("HuzzRole") -- (only bodies in a game: Oct 24, lag with a full lobby)
		if role ~= "Runner" and role ~= "Catcher" then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or character:GetAttribute("DownedAt") ~= nil then return end
		local stamp = MotionStamps.read(t, p, v, g, push)
		local okPing, ping = pcall(function() return player:GetNetworkPing() end)
		if not MotionRelay.check(stamp, root, character:FindFirstChildOfClass("Humanoid"), Workspace:GetServerTimeNow(),
			if okPing and type(ping) == "number" then ping else nil) then
			return
		end
		local old = latest[player]
		if old and old.t > stamp.t then return end -- (an unreliable one can come late: never go back)
		latest[player] = stamp
		table.insert(outbox, { player, character, stamp })
	end)
	local function watch(p)
		p.CharacterAdded:Connect(function() latest[p] = nil end) -- (a new body: the old one's stamp says nothing)
	end
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		latest[p] = nil
		budget[p] = nil
	end)
	-- the Practice Bot (and any other server-moved body tagged HuzzBot): stamped here, 20 a second
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= C.Every then
			acc = 0
			local now = Workspace:GetServerTimeNow()
			for model in latest do
				if typeof(model) == "Instance" and model:IsA("Model") and model.Parent == nil then latest[model] = nil end
			end
			for _, bot in CollectionService:GetTagged("HuzzBot") do
				local root = bot:IsA("Model") and bot:FindFirstChild("HumanoidRootPart")
				local h = bot:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and h and not root.Anchored then
					local v = root.AssemblyLinearVelocity
					local stamp = { t = now, p = root.Position, v = Vector3.new(v.X, 0, v.Z), g = h.MoveDirection * h.WalkSpeed, push = 0 }
					latest[bot] = stamp
					table.insert(outbox, { bot, bot, stamp })
				end
			end
		end
		flush(remote)
	end)
end

return MotionRelay
