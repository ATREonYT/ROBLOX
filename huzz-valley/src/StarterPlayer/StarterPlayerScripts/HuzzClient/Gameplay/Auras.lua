--[[
	The anime girls in the world, on this screen (owner's call: "make the anime girl characters feel more
	included"):
	  - Your equipped girl (the player's HuzzCompanion attribute, CompanionService) walks behind you on the
	    ground as a small companion (owner: "walk behind you, not fly"): Shared/FollowMotion moves her (the
	    same code as the girl who follows a catcher) with Config/GirlMotion.Companion, walking when you walk,
	    running when you run, standing and looking round when you stop (the owner's movement pack:
	    Shared/GirlMoves); her effects are Shared/AuraLook
	    "Companion". In a round she steps aside (the round's own girl is the prize) until you're safe across:
	    then she appears beside you on the ground and hops and cheers. When you dance she steps beside you and
	    dances too (Gameplay/CompanionDance). She never bumps anyone: her parts are in the "HuzzCompanion"
	    collision group (Bootstrap), which collides with nothing (a Humanoid turns CanCollide back on by itself).
	  - An aura you wear (Shop: Blossom Aura, or a Legendary / Mythic / Secret girl's reward) shows on you instead.
	  - Equip a girl and YOU get her aura, in the lobby and in rounds (the owner's reference: flames on your
	    hands, dark wisps, crescent slashes), small for Common to Epic and growing with rarity ("Player").
	  - The big girl over the map wears her aura at 3x ("Showcase", tag HuzzShowcase).
	  - The round's girl, carried or following a catcher, glows with her "Companion" look (no light pool on the
	    floor under her while she's carried).
	  - Your girl never pops in or out: a soft puff of sparkles in her colours covers it when she steps in (the
	    lobby, safe across) or steps aside (a round starts, you change girls).
	Everyone's are drawn by every client (Gameplay/AuraFX), only near the camera; other players' are drawn
	"lite" (half the particles, no light) so a full server stays smooth on phones.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local AuraLook = require(Shared.AuraLook)
	local Looks = require(Shared.Config.GirlLooks)
	local Round = require(Shared.Config.Round)
	local FollowMotion = require(Shared.FollowMotion)
	local GirlMoves = require(Shared.GirlMoves)
	local Companion = require(Shared.Config.GirlMotion).Companion
	local AuraFX = require(script.Parent.AuraFX)
	local Burst = require(script.Parent.Burst)
	local CompanionDance = require(script.Parent.CompanionDance)
	CompanionDance.start()
	local GROUP = "HuzzCompanion"

	-- No girl ever bumps or blocks a player: every part in the group that collides with nothing, now and later.
	local function ghost(part)
		if part:IsA("BasePart") then
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			pcall(function() part.CollisionGroup = GROUP end)
		end
	end
	local ghosted = {} -- Model -> connection
	local function ghostModel(model)
		if ghosted[model] then
			return
		end
		for _, d in model:GetDescendants() do
			ghost(d)
		end
		ghosted[model] = model.DescendantAdded:Connect(ghost)
		model.Destroying:Connect(function()
			if ghosted[model] then
				ghosted[model]:Disconnect()
				ghosted[model] = nil
			end
		end)
	end

	local NEAR = 170 -- studs from the camera: effects further away are switched off
	local COMPANION_HEIGHT = Companion.Height

	local rarityColor = {}
	for _, r in Round.Rarities do
		rarityColor[r.Name] = r.Color
	end
	local function lookOf(id, rarity)
		return AuraLook.lookFor(Looks, id, rarityColor[rarity or ""])
	end

	local folder = Instance.new("Folder")
	folder.Name = "HuzzCompanions"
	folder.Parent = Workspace

	local function distance(position)
		local cam = Workspace.CurrentCamera
		return if cam then (cam.CFrame.Position - position).Magnitude else math.huge
	end
	local function near(position)
		return distance(position) < NEAR
	end

	-- Her height without hair, hats or wings (as GirlService.bodyBounds): the body parts only.
	local function bodyHeight(model)
		local low, high = math.huge, -math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Accessory") and d.Name ~= "HumanoidRootPart" then
				local y, h = d.CFrame.Position.Y, d.Size.Y / 2
				low, high = math.min(low, y - h), math.max(high, y + h)
			end
		end
		return if high > low then high - low else nil
	end

	-- Players: their aura and their companion.
	local states = {} -- Player -> { key, auraFor, aura, companion = {model, handle, walk, groundAt, ...} }
	local function clearAura(s)
		if s.aura then
			s.aura.destroy()
			s.aura, s.auraFor = nil, nil
		end
	end
	local function clearCompanion(s)
		if s.companion then
			CompanionDance.forget(s.companion.player)
			s.companion.handle.destroy()
			s.companion.model:Destroy()
			s.companion = nil
		end
	end

	local clock, frameNo = 0, 0

	-- Ground under her: one ray straight down, through every character and girl (only things you can stand on).
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	local rayFilterAt = -math.huge
	local function refreshRayFilter()
		local ignore = { folder }
		for _, name in { "HuzzCarried", "HuzzFollowers" } do
			local f = Workspace:FindFirstChild(name)
			if f then
				table.insert(ignore, f)
			end
		end
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(ignore, p.Character)
			end
		end
		rayParams.FilterDescendantsInstances = ignore
	end

	-- The lowest point of her body (feet), for how high her root stands off the ground.
	local function bodyBottom(model)
		local low = math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Accessory") and d.Name ~= "HumanoidRootPart" then
				low = math.min(low, d.CFrame.Position.Y - d.Size.Y / 2)
			end
		end
		return low
	end

	--[[ A small copy of her that walks: her root part stays anchored (moved by Shared/FollowMotion), every
		other part hangs off it on its joints, unanchored, so the Motor6D poses (Shared/GirlMotion) move her
		legs and arms (as GirlService.makeCopy + CarryAnimator do for the girl who follows a catcher). ]]
	local function makeCompanion(key, rarity, lite, seed)
		local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
		local source = girls and girls:FindFirstChild(key)
		if not (source and source:IsA("Model")) then
			return nil
		end
		local model = source:Clone()
		model.Name = "Companion"
		-- (the R15 Secret is built on AnimationConstraints: swap them for Motor6Ds, as GirlService does)
		local done = {}
		for _, d in model:GetDescendants() do
			if d.ClassName == "AnimationConstraint" then
				local a0, a1 = d.Attachment0, d.Attachment1
				local part0, part1 = a0 and a0.Parent, a1 and a1.Parent
				if part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") and not done[part1] then
					done[part1] = true
					local motor = Instance.new("Motor6D")
					motor.Name = d.Name
					motor.Part0, motor.Part1 = part0, part1
					motor.C0, motor.C1 = a0.CFrame, a1.CFrame
					motor.Parent = part1
				end
			end
		end
		for _, d in model:GetDescendants() do
			if d.ClassName == "AnimationConstraint" or d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
				d:Destroy()
			end
		end
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not (root and root:IsA("BasePart")) then
			return nil
		end
		model.PrimaryPart = root
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * COMPANION_HEIGHT / math.max(bodyHeight(model) or size.Y, 1))
		local _, newSize = model:GetBoundingBox()
		local rootHeight = root.Position.Y - bodyBottom(model)
		if rootHeight ~= rootHeight or rootHeight <= 0 or rootHeight > COMPANION_HEIGHT then
			rootHeight = COMPANION_HEIGHT * 0.5
		end

		-- Parts joined to her root (through Motor6Ds and welds) hang off it; anything loose gets welded on.
		local links = {}
		local function link(a, b)
			if a and b then
				links[a] = links[a] or {}
				links[b] = links[b] or {}
				table.insert(links[a], b)
				table.insert(links[b], a)
			end
		end
		local motors = {}
		for _, d in model:GetDescendants() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				link(d.Part0, d.Part1)
				if d:IsA("Motor6D") then
					table.insert(motors, d)
				end
			end
		end
		local joined, queue = { [root] = true }, { root }
		while #queue > 0 do
			for _, other in links[table.remove(queue)] or {} do
				if not joined[other] then
					joined[other] = true
					table.insert(queue, other)
				end
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow, d.Massless = false, false, false, false, true
				pcall(function() d.CollisionGroup = GROUP end)
				d.Anchored = d == root
				if not joined[d] and d ~= root then
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = root, d
					weld.Parent = d
				end
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.EvaluateStateMachine = false
			humanoid.PlatformStand = true
			humanoid.BreakJointsOnDeath = false
			humanoid.RequiresNeck = false
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		model.Parent = folder
		local look = lookOf(source:GetAttribute("Id"), rarity)
		local spec = AuraLook.build(look, rarity, "Companion")
		spec.scale = COMPANION_HEIGHT / 5
		local walk = FollowMotion.new({ root = root, motors = motors, rootHeight = rootHeight, seed = seed, config = Companion, moves = GirlMoves.find(os.clock()) })
		local c = { model = model, handle = AuraFX.attach(model, spec, { lite = lite }), size = newSize, walk = walk, ground = nil, leaderY = 0 }
		c.colors = { (look and look.Colors and look.Colors[1]) or Burst.PINK, Color3.new(1, 1, 1) } -- (the puff when she steps in or out)
		-- The ground under her: one ray a frame for yours, every other frame for other players' companions.
		function c.groundAt(at)
			if lite and frameNo % 2 == 1 and c.ground then
				return c.ground
			end
			local top = math.max(at.Y, c.leaderY) + 4
			local hit = Workspace:Raycast(Vector3.new(at.X, top, at.Z), Vector3.new(0, -60, 0), rayParams)
			c.ground = hit and hit.Position.Y
			return c.ground
		end
		return c
	end

	local function stateOf(p)
		local s = states[p]
		if not s then
			s = {}
			states[p] = s
		end
		return s
	end

	local function updatePlayer(p, s, dt)
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		local key = p:GetAttribute("HuzzCompanion") or ""
		local rarity = p:GetAttribute("HuzzCompanionRarity") or ""
		local alive = root ~= nil and humanoid.Health > 0
		local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
		local source = girls and key ~= "" and girls:FindFirstChild(key)

		-- the aura on the player (every rarity: Common is just a few faint motes). An aura they wear (the Blossom
		-- Aura or a girl's reward: the character's HuzzAura, HuzzServer/CosmeticsService) takes its place.
		local lite = p ~= Players.LocalPlayer
		local worn = character and character:GetAttribute("HuzzAura")
		local wantAura = alive and source ~= nil and (AuraLook.RANK[rarity] or 0) >= 1
		local auraFor = if alive and type(worn) == "string" then "worn:" .. worn elseif wantAura then key else nil
		if s.auraFor ~= auraFor or s.auraChar ~= character then
			clearAura(s)
			s.auraChar = character
			if auraFor then
				local spec = if type(worn) == "string" then AuraLook.worn(worn) else AuraLook.build(lookOf(source:GetAttribute("Id"), rarity), rarity, "Player")
				if spec then
					s.aura, s.auraFor = AuraFX.attach(character, spec, { lite = lite }), auraFor
				end
			end
		end
		if s.aura then
			s.aura.setEnabled(near(root.Position) and character:GetAttribute("DownedAt") == nil)
			s.aura.step(dt)
		end

		-- the companion beside them (not in a round)
		local role = p:GetAttribute("HuzzRole")
		local inRound = role == "Runner" or role == "Catcher"
		local cheering = inRound and p:GetAttribute("HuzzStatus") == "Safe"
		-- made inside 150 studs, removed past 190 (no rebuilding over and over at the edge)
		local far = if root then distance(root.Position) else math.huge
		local allowed = alive and source ~= nil and (not inRound or cheering)
		if s.companion and (not allowed or s.key ~= key or far > 190) then
			local m = s.companion.model
			if far <= 120 and m.Parent then
				Burst.sparks(m:GetPivot().Position, s.companion.colors, 16,
					{ speed = NumberRange.new(3, 6), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.4, 0.7) })
			end
			clearCompanion(s)
		end
		s.key = key
		if allowed and not s.companion and far < 150 then
			s.companion = makeCompanion(key, rarity, lite, p.UserId)
			if s.companion then
				s.companion.player = p
				s.companion.puff = far <= 120 -- (after her first step, where she stands)
			end
		end
		local c = s.companion
		if c and not c.model.Parent then
			clearCompanion(s) -- (something removed her)
			c = nil
		end
		if c then
			-- She walks on the ground behind you (Shared/FollowMotion); a new character (respawn) = a fresh
			-- start at her spot, and so does a teleport (FollowMotion: further than TeleportDistance).
			local w = c.walk
			if c.char ~= character then
				c.char, w.pos = character, nil
				refreshRayFilter() -- (so the ray never lands on the new character)
			end
			local dancing = CompanionDance.active(p)
			w.cheer = cheering and not dancing
			w.beside = dancing -- (she steps up beside you to dance)
			c.leaderY = root.Position.Y
			w.moves = w.moves or GirlMoves.find(os.clock()) -- (the owner's walk/run/idle once they've arrived: Shared/GirlMoves)
			local head = character:FindFirstChild("Head")
			FollowMotion.step(w, dt, clock, root.CFrame, c.groundAt, head and head.Position)
			CompanionDance.step(p, character, w.joints, dt, COMPANION_HEIGHT, w.speed < 6)
			c.handle.step(dt)
			if c.puff then
				c.puff = nil
				Burst.sparks(c.model:GetPivot().Position, c.colors, 16,
					{ speed = NumberRange.new(3, 6), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.4, 0.7) })
			end
		end
	end

	-- Girl models in the world: the showcase over the map, the round's girl carried or following.
	local worldAuras = {} -- Model -> handle
	local worldConns = {} -- Model -> its AncestryChanged connection
	local function watchModel(model, kind, carried)
		if worldAuras[model] or not model:IsA("Model") then
			return
		end
		local rarity = model:GetAttribute("Rarity")
		local spec = AuraLook.build(lookOf(model:GetAttribute("Id"), rarity), rarity, kind)
		if not spec then
			return
		end
		if kind == "Companion" then
			spec.scale = 1 -- (full size: the round's girl)
		end
		-- (the girl being carried is off the floor: no light pool under her)
		worldAuras[model] = AuraFX.attach(model, spec, { lite = kind ~= "Showcase", ground = not carried })
		if kind == "Companion" then
			ghostModel(model) -- (the round's girl, carried or following, never blocks anyone either)
		end
		if worldConns[model] then
			worldConns[model]:Disconnect()
		end
		worldConns[model] = model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) and worldAuras[model] then
				worldAuras[model].destroy()
				worldAuras[model] = nil
				worldConns[model]:Disconnect()
				worldConns[model] = nil
			end
		end)
	end
	local function showcaseAdded(model)
		task.defer(watchModel, model, "Showcase")
	end
	CollectionService:GetInstanceAddedSignal("HuzzShowcase"):Connect(showcaseAdded)
	-- the round's prize girl standing on the map: no bumping into her
	CollectionService:GetInstanceAddedSignal("HuzzPrize"):Connect(ghostModel)
	for _, m in CollectionService:GetTagged("HuzzPrize") do
		ghostModel(m)
	end
	for _, m in CollectionService:GetTagged("HuzzShowcase") do
		showcaseAdded(m)
	end
	for _, name in { "HuzzCarried", "HuzzFollowers" } do
		task.spawn(function()
			local f = Workspace:WaitForChild(name, 30)
			if f then
				f.ChildAdded:Connect(function(m)
					task.delay(0.2, watchModel, m, "Companion", name == "HuzzCarried")
				end)
				for _, m in f:GetChildren() do
					watchModel(m, "Companion", name == "HuzzCarried")
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(p)
		local s = states[p]
		if s then
			clearAura(s)
			clearCompanion(s)
			states[p] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		clock += dt
		frameNo += 1
		if clock - rayFilterAt > 0.5 then
			rayFilterAt = clock
			refreshRayFilter()
		end
		for _, p in Players:GetPlayers() do
			updatePlayer(p, stateOf(p), dt)
		end
		for model, handle in worldAuras do
			if model.Parent then
				local pivot = model:GetPivot().Position
				handle.setEnabled(near(pivot) or model:HasTag("HuzzShowcase"))
				handle.step(dt)
			end
		end
	end)
end

return M
