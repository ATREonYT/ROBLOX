--!strict
-- Server side of cutscenes. The client plays the scene (CutsceneController); the server only says "play" and waits.
--   CutsceneService.play(player, id, { anchor = CFrame?, marks = { Name = Vector3 }? }) -> (finished, skipped)
--       marks (Piece 4): named points local to the anchor (e.g. the PC chair in this player's room) that the scene
--       uses as "#Name"; the scene's own `marks` are the defaults.
--       Yields until the client reports CutsceneDone (token-checked) or a timeout (scene length + 10 s), or the
--       player leaves (finished = false). Either way the caller moves the story on: skipping still advances.
--   CutsceneService.playGroup(players, id, opts) -> (finished, skipped, choice)   one story beat for a party: the
--       same token and start time for everyone, players[1] is the host (the only one who picks on a choice card),
--       holding skip is a vote and the scene ends for all once enough vote (2 players: both; more: a majority + 1,
--       capped at everyone; people who leave stop counting). LihFolk build list #15, research: "Multiplayer
--       Cutscene Sync - Server Clock, Late Joiners and Skip Votes".
--   CutsceneService.isPlaying(player) -> boolean
--   CutsceneService.rig(actorId) -> Model?     a fresh copy of a crew/NPC rig (server NPCs, e.g. the clerk)
-- Rigs: on init, every Config/Missions.Actors entry gets an R15 rig in ReplicatedStorage.MTL_Actors.<Id>, built
-- from its colours (HumanoidDescription). A rig Alex already put there is kept as-is (that's how real art drops in).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Missions = require(ReplicatedStorage.MTL.Config.Missions)
local CutsceneRules = require(ReplicatedStorage.MTL.Rules.CutsceneRules)
local RateLimiter = require(script.Parent.RateLimiter)

local CutsceneService = {}

type Pending = { id: string, token: number, done: BindableEvent, skipped: boolean, finished: boolean, choice: string? }
local pending: { [Player]: Pending } = {}
local tokenCounter = 0
local limiter = RateLimiter.new(4, 6)

-- group scenes by token: who's in it, who voted to skip, the host's pick
type Group = { players: { Player }, votes: { [Player]: boolean }, startAt: number, id: string, choice: string?, ended: boolean }
local groups: { [number]: Group } = {}
local VOTE_GRACE = 2 -- seconds after frame 0 before skip votes count

local function log(...)
	print("[MTL Cutscene]", ...)
end

local function library(): Folder
	local lib = ReplicatedStorage:FindFirstChild("MTL_Actors")
	if not lib then
		local f = Instance.new("Folder")
		f.Name = "MTL_Actors"
		f.Parent = ReplicatedStorage
		lib = f
	end
	return lib :: Folder
end

local function buildRig(id: string, cfg: any): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = cfg.Skin
	desc.LeftArmColor = cfg.Skin
	desc.RightArmColor = cfg.Skin
	desc.TorsoColor = cfg.Shirt
	desc.LeftLegColor = cfg.Pants
	desc.RightLegColor = cfg.Pants
	if type(cfg.ShirtId) == "number" and cfg.ShirtId ~= 0 then
		desc.Shirt = cfg.ShirtId
	end
	if type(cfg.PantsId) == "number" and cfg.PantsId ~= 0 then
		desc.Pants = cfg.PantsId
	end
	-- accessories (comma-separated ids): hair, hat, glasses
	if type(cfg.Hair) == "string" then
		desc.HairAccessory = cfg.Hair
	end
	if type(cfg.Hat) == "string" then
		desc.HatAccessory = cfg.Hat
	end
	if type(cfg.FaceAcc) == "string" then
		desc.FaceAccessory = cfg.FaceAcc
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok or not model then
		warn("[MTL Cutscene] couldn't build rig", id, model)
		return nil
	end
	model.Name = id
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if cfg.Height and cfg.Height ~= 1 then
		pcall(function()
			model:ScaleTo(cfg.Height)
		end)
	end
	return model
end

function CutsceneService.rig(actorId: string): Model?
	local lib = library()
	local t = lib:FindFirstChild(actorId) or lib:WaitForChild(actorId, 8)
	if not t or not t:IsA("Model") then
		return nil
	end
	local was = t.Archivable
	t.Archivable = true
	local copy = t:Clone()
	t.Archivable = was
	return copy
end

function CutsceneService.isPlaying(player: Player): boolean
	return pending[player] ~= nil
end

local function sceneLength(id: string): number?
	local folder = ReplicatedStorage.MTL:FindFirstChild("Cutscenes")
	local module = folder and folder:FindFirstChild(id)
	if not module then
		return nil
	end
	local ok, scene = pcall(require, module)
	if not ok or type(scene) ~= "table" then
		return nil
	end
	return CutsceneRules.length(scene)
end

-- option ids of a scene's choice card, as a set (nil = the scene has no choice)
local function sceneChoices(id: string): { [string]: boolean }?
	local folder = ReplicatedStorage.MTL:FindFirstChild("Cutscenes")
	local module = folder and folder:FindFirstChild(id)
	local ok, scene = pcall(require, module :: any)
	if not ok or type(scene) ~= "table" or type(scene.choice) ~= "table" then
		return nil
	end
	local set = {}
	for _, o in scene.choice.options or {} do
		set[o.id] = true
	end
	return set
end

-- returns (finished, skipped, choiceId?) — choiceId only for scenes with a choice card
function CutsceneService.play(player: Player, id: string, opts: { [string]: any }?): (boolean, boolean, string?)
	local o = opts or {}
	local length = sceneLength(id)
	if not length then
		warn("[MTL Cutscene] unknown scene", id)
		return true, true
	end
	local old = pending[player]
	if old then
		old.finished = false
		old.done:Fire()
	end
	tokenCounter += 1
	local p: Pending = { id = id, token = tokenCounter, done = Instance.new("BindableEvent"), skipped = false, finished = false }
	pending[player] = p
	local anchor: CFrame? = o.anchor
	if anchor then
		pcall(function()
			player:RequestStreamAroundAsync(anchor.Position, 5)
		end)
	end
	if pending[player] ~= p or not player.Parent then
		return false, false
	end
	Net.get("PlayCutscene"):FireClient(player, { id = id, token = p.token, anchor = anchor, marks = o.marks })
	log(player.Name, "play", id)
	local token = p.token
	task.delay(length + (if sceneChoices(id) then 120 else 10), function() -- a choice card waits for the player
		local now = pending[player]
		if now and now.token == token then
			warn("[MTL Cutscene]", player.Name, id, "timed out; moving on")
			now.finished = true
			now.skipped = true
			now.done:Fire()
		end
	end)
	p.done.Event:Wait()
	p.done:Destroy()
	if pending[player] == p then
		pending[player] = nil
	end
	return p.finished, p.skipped, p.choice
end

local function need(n: number): number
	return if n <= 2 then n else math.min(n, math.ceil(n / 2) + 1)
end

local function syncAll(g: Group, msg: { [string]: any })
	for _, p in g.players do
		if p.Parent then
			Net.get("CutsceneSync"):FireClient(p, msg)
		end
	end
end

local function countVotes(token: number, g: Group)
	if g.ended then
		return
	end
	local live, count = 0, 0
	for _, p in g.players do
		if p.Parent then
			live += 1
			if g.votes[p] then
				count += 1
			end
		end
	end
	syncAll(g, { token = token, type = "votes", count = count, need = need(live) })
	if live > 0 and count >= need(live) then
		g.ended = true
		syncAll(g, { token = token, type = "end" })
		log("group skip", g.id, count .. "/" .. live)
	end
end

function CutsceneService.playGroup(players: { Player }, id: string, opts: { [string]: any }?): (boolean, boolean, string?)
	local list = {}
	for _, p in players do
		if p.Parent then
			table.insert(list, p)
		end
	end
	if #list <= 1 then
		return CutsceneService.play(list[1] or players[1], id, opts)
	end
	local o = opts or {}
	local length = sceneLength(id)
	if not length then
		warn("[MTL Cutscene] unknown scene", id)
		return true, true
	end
	tokenCounter += 1
	local token = tokenCounter
	local g: Group = { players = list, votes = {}, startAt = workspace:GetServerTimeNow() + 0.8, id = id, ended = false }
	groups[token] = g
	local anchor: CFrame? = o.anchor
	local waits = {}
	for i, p in list do
		local old = pending[p]
		if old then
			old.finished = false
			old.done:Fire()
		end
		local pd: Pending = { id = id, token = token, done = Instance.new("BindableEvent"), skipped = false, finished = false }
		pending[p] = pd
		waits[p] = pd
		if anchor then
			pcall(function()
				p:RequestStreamAroundAsync(anchor.Position, 5)
			end)
		end
		Net.get("PlayCutscene"):FireClient(p, {
			id = id,
			token = token,
			anchor = anchor,
			marks = o.marks,
			startAt = g.startAt,
			group = { n = #list, host = i == 1, hostName = list[1].DisplayName },
		})
	end
	log("group play", id, #list, "players")
	-- wait for everyone (or the timeout); a player leaving releases their own wait
	local deadline = os.clock() + length + (if sceneChoices(id) then 120 else 10) + 1
	for p, pd in waits do
		if pending[p] == pd and not pd.finished then
			local fired = false
			local conn = pd.done.Event:Connect(function()
				fired = true
			end)
			while not fired and os.clock() < deadline and p.Parent and pending[p] == pd do
				task.wait(0.25)
			end
			conn:Disconnect()
		end
		pd.done:Destroy()
		if pending[p] == pd then
			pending[p] = nil
		end
	end
	groups[token] = nil
	local host = waits[list[1]]
	local anySkip = g.ended
	for _, pd in waits do
		anySkip = anySkip or pd.skipped
	end
	return true, anySkip, g.choice or (host and host.choice)
end

function CutsceneService.init()
	Net.get("CutsceneInput").OnServerEvent:Connect(function(player, payload)
		if not limiter:allow(player) or type(payload) ~= "table" or type(payload.token) ~= "number" then
			return
		end
		local g = groups[payload.token]
		if not g or not table.find(g.players, player) then
			return
		end
		if payload.type == "skip" then
			if workspace:GetServerTimeNow() - g.startAt < VOTE_GRACE then
				return
			end
			g.votes[player] = true
			countVotes(payload.token, g)
		elseif payload.type == "choice" and player == g.players[1] and g.choice == nil and type(payload.choice) == "string" then
			local opts = sceneChoices(g.id)
			if opts and opts[payload.choice] then
				g.choice = payload.choice
				syncAll(g, { token = payload.token, type = "choice", choice = payload.choice })
			end
		end
	end)

	task.spawn(function()
		local lib = library()
		for id, cfg in Missions.Actors do
			if not lib:FindFirstChild(id) then
				local m = buildRig(id, cfg)
				if m then
					m.Parent = lib
				end
			end
		end
		log("actor rigs ready")
	end)

	Net.get("CutsceneDone").OnServerEvent:Connect(function(player, payload)
		if not limiter:allow(player) or type(payload) ~= "table" then
			return
		end
		local p = pending[player]
		if not p or payload.token ~= p.token or payload.id ~= p.id then
			return
		end
		p.finished = true
		p.skipped = payload.skipped == true
		-- a story choice made inside the scene: only accepted if it's one of the scene's own option ids
		if type(payload.choice) == "string" then
			local opts = sceneChoices(p.id)
			if opts and opts[payload.choice] then
				p.choice = payload.choice
			end
		end
		p.done:Fire()
	end)

	Players.PlayerRemoving:Connect(function(player)
		for token, g in groups do
			if table.find(g.players, player) then
				task.delay(0.5, countVotes, token, g) -- after they are gone: the vote threshold shrinks with the party
			end
		end
		local p = pending[player]
		if p then
			p.finished = false
			p.done:Fire()
		end
	end)
end

return CutsceneService
