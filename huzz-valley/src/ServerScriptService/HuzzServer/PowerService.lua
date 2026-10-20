--[[
	Round powers (Config/Powers). Abilities are bought with coins and picked in a loadout (owner, Oct 20 15:13: "make
	the abilities be bought, add a few more abilities, but make them well made"; Shared/AbilityRules, saved Abilities
	and Loadout): runners bring one on Q (their pick, or RANDOM: one they own, a new one each round) and get Speed
	Boost on E (only while carrying the girl); catchers bring two, on Q and E. The loadout is read when the round
	starts (a change in the lobby plays from the next round). Everything is decided here on the server; the client
	only asks ("Power" remote, slot 1 or 2) and shows the result (Screens/PowerBar, Gameplay/PowerEffects).
	Runner abilities: Shield, Invisible, Glitchy, Body Double, Banana Peel (catchers slip), Smoke Bomb (a cloud that
	hides you and slows catchers in it). Catcher abilities: Bear Trap, Slow Wave, Radar (runners glow through walls for
	a few seconds), Lasso (pulls the first runner the rope touches a few studs closer: the runner's own screen moves
	them, as with the huss and Glitchy; no other screen pushes a body). Safe runners and runners still in their start
	zone are never slowed, pulled or tripped by a catcher's ability (Radar only shows where runners are).

	RoundService drives it: start(ctx) once, newRound() when a round starts, step() every frame of a round, clear()
	when the game ends. It asks speedOf/stuck when it sets a player's speed, canStab/stunned before a stab, blocks()
	before tagging (a Shield eats the stab) and stun() after a catcher's dive (Config/Round.Lunge.Stun).

	For the cards each player gets attributes: PowerName1/PowerName2 (which power is in each slot this round),
	PowerReady1/PowerReady2 (server time the slot is ready again; -1 = used up this round), ShieldUntil, DizzyUntil,
	StunnedFrom/StunnedUntil (a dive's stun). The character gets InvisibleFrom/InvisibleUntil (every screen fades it),
	StunnedFrom / StunnedUntil, SlipUntil (a catcher on a banana peel: stars over the head) and SpottedUntil (Radar:
	a glowing outline through walls). Effects other players should see are parts made here (bubble, trail, traps,
	peels, badges); one-off bursts go to every client as a "Power" message on the Round remote (each use, a blocked
	stab, a sprung trap, a slip, the lasso's hit, a shield running out). Each power lands its own Fx WindUp after the
	press, when every screen shows it go off (Slow Wave's slow, Radar's sweep, the lasso leaving the hand, the smoke,
	the peel); a Bear Trap lands BearTrap.Flight after the throw and catches from BearTrap.Arm after that.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Powers = require(Shared.Config.Powers)
local Net = require(Shared.Net)
local BearTrap = require(Shared.BearTrap)
local BananaPeel = require(Shared.BananaPeel)
local DownMotion = require(Shared.DownMotion)
local AbilityRules = require(Shared.AbilityRules)

local PowerService = {}
-- The powers' look is the one they had before the Oct 19 renames (owner, Oct 20: "bring back the nice effects with
-- the power ups ... just keep the same effects, change the name"): pink bubble, pink speed trail, the Love Trap's pink
-- heart disc with its 💘 sign as the Bear Trap (Shared/BearTrap), "💘 STUCK!" and "😍" on a slowed runner. The new
-- names and rules stay.
local PINK = Color3.fromRGB(255, 110, 190)
local ctx = nil -- from RoundService: match(), running(), rootOf(id), playerOf(id), isDown(player), sync(id),
-- startZone(), inZone(zone, pos), ground(pos), bot() (the Practice Bot module while it catches, or nil)
local state = {} -- UserId -> { ready = {slot -> time}, pick, loadout, shieldUntil, dizzyUntil, boostUntil, boost,
-- slowUntil, slow, stuckUntil, stunFrom, stunUntil, smokeUntil }
local lastPick = {} -- UserId -> last round's ability (Random picks another)
local traps = {} -- { model, owner, at (Vector3), armAt, untilT }
local peels = {} -- { model, owner, at, armAt, untilT }
local clouds = {} -- { owner, at, from, untilT, radius }
local ropes = {} -- { owner, dir, t0, match }: lassos in flight
local lastSpeedCheck = {} -- UserId -> true while an effect changes their speed ("stunned" while a dive's stun holds them)

local function now()
	return Workspace:GetServerTimeNow()
end

local function stateOf(id)
	local s = state[id]
	if not s then
		s = { ready = {} }
		state[id] = s
	end
	return s
end

local function folder(name)
	local f = Workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = Workspace
	end
	return f
end

-- The field's walls (MapService), when there is one: a thrown trap never lands past them.
local okMap, MapService = pcall(function()
	return require(script.Parent:FindFirstChild("MapService"))
end)
if not okMap or type(MapService) ~= "table" then
	MapService = nil
end
-- The saves (which abilities each player bought and brings). None in a test without saves: everyone plays the
-- default loadout.
local okData, DataService = pcall(function()
	return require(script.Parent.DataService)
end)
if not okData or type(DataService) ~= "table" then
	DataService = nil
end

local function wind(name: string): number
	local fx = Powers.Fx[name]
	return (fx and fx.WindUp) or Powers.Fx.WindUp
end

local function saveOf(id)
	local p = ctx.playerOf(id)
	local profile = p and DataService and DataService.get and DataService.get(p)
	return profile and profile.Data
end

-- A small badge over someone's head ("💫 DIZZY"), removed after `seconds`.
local function badge(id, name, text, color, seconds)
	local p = ctx.playerOf(id)
	local head = p and p.Character and p.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 16, 48)
	stroke.Parent = label
	gui.Parent = head
	task.delay(seconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function setSlot(id, slot, value)
	stateOf(id).ready[slot] = value
	local p = ctx.playerOf(id)
	if p then
		p:SetAttribute("PowerReady" .. slot, value)
	end
end

local function removeShield(id)
	local s = stateOf(id)
	s.shieldUntil = nil
	local p = ctx.playerOf(id)
	if p then
		p:SetAttribute("ShieldUntil", nil)
	end
	if s.bubble then
		s.bubble:Destroy()
		s.bubble = nil
	end
end

local function boost(id, amount, seconds, color)
	local s = stateOf(id)
	s.boost, s.boostUntil = amount, now() + seconds
	s.trailUntil = math.max(s.trailUntil or 0, s.boostUntil)
	-- A trail behind them while it lasts (the power's colour).
	local p = ctx.playerOf(id)
	local root = ctx.rootOf(id)
	if root and not root:FindFirstChild("HuzzRushTrail") then
		local a0 = Instance.new("Attachment")
		a0.Name = "HuzzRushA"
		a0.Position = Vector3.new(0, 1.2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "HuzzRushB"
		a1.Position = Vector3.new(0, -1.6, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "HuzzRushTrail"
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.35
		trail.Color = ColorSequence.new(color or PINK, Color3.new(1, 1, 1))
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.LightEmission = 0.5
		trail.Parent = root
		-- Gone when the last boost ends (a second boost can stretch it).
		local function finish()
			local left = (s.trailUntil or 0) - now()
			if left > 0.05 then
				task.delay(left, finish)
			else
				for _, item in { trail, a0, a1 } do
					item:Destroy()
				end
			end
		end
		task.delay(seconds, finish)
	end
	ctx.sync(id)
	return p
end

-- The flat way a root part faces.
local function facing(root)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
end

local USE = {}
local stepPeels, stepClouds, stepRopes -- (PowerService.step's helpers, further down)

function USE.Shield(id, def)
	local s = stateOf(id)
	-- (it blocks from the press; Lasts counts from when the bubble shows, after the wind-up)
	s.shieldUntil = now() + wind("Shield") + def.Lasts
	local p = ctx.playerOf(id)
	p:SetAttribute("ShieldUntil", s.shieldUntil)
	local root = ctx.rootOf(id)
	if root then
		local bubble = Instance.new("Part")
		bubble.Name = "HuzzShield"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(7, 7, 7)
		bubble.Material = Enum.Material.ForceField
		bubble.Color = PINK
		bubble.CanCollide, bubble.CanQuery, bubble.CanTouch, bubble.Massless, bubble.CastShadow = false, false, false, true, false
		bubble.CFrame = root.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, bubble
		weld.Parent = bubble
		-- Outside the character, so the team outline (a Highlight on the character) doesn't ring it.
		bubble.Parent = folder("HuzzShields")
		s.bubble = bubble
	end
	return true
end

function USE.SpeedBoost(id, def)
	local match = ctx.match()
	if def.CarrierOnly and match.holder ~= id then
		return false, "Carry the girl"
	end
	boost(id, def.Boost, def.Time, PINK)
	return true
end

function USE.Invisible(id, def)
	local p = ctx.playerOf(id)
	local c = p and p.Character
	if not c then
		return false
	end
	-- every screen fades this character (Gameplay/PowerEffects) from the end of the wind-up, still catchable
	local from = now() + wind("Invisible")
	c:SetAttribute("InvisibleFrom", from)
	c:SetAttribute("InvisibleUntil", from + def.Lasts)
	return true, nil, { lasts = def.Lasts }
end

function USE.Glitchy(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	-- the runner's own screen moves them (like the huss): every screen draws the glitch from here
	return true, nil, { at = root.Position, dir = facing(root) }
end

function USE.BodyDouble(id, def)
	local root = ctx.rootOf(id)
	local p = ctx.playerOf(id)
	local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not (root and h) then
		return false
	end
	-- every screen makes its own copy running on from here (only a look)
	return true, nil, { at = root.Position, dir = facing(root), speed = math.max(h.WalkSpeed, 16), lasts = def.Lasts }
end

-- New Oct 20. A peel dropped Back studs behind the runner (on the floor); it lands after the wind-up (every screen
-- draws it tossed back), arms Arm later, and the first catcher on it slips (PowerService.step). One out at a time.
function USE.BananaPeel(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local dir = facing(root)
	local spot = root.Position - dir * def.Back
	local floor = ctx.ground(spot) or ctx.ground(root.Position)
	if not floor then
		return false
	end
	local at = Vector3.new(spot.X, floor, spot.Z)
	local mine = 0
	for _, q in peels do
		if q.owner == id then mine += 1 end
	end
	if mine >= def.MaxOut then -- (your oldest makes way)
		for i, q in peels do
			if q.owner == id then
				if q.model then q.model:Destroy() end
				table.remove(peels, i)
				break
			end
		end
	end
	local t0 = now()
	local land = wind("BananaPeel") + Powers.Fx.Flash + 0.3 -- (the toss behind: PowerEffects draws it in the air)
	local yaw = math.atan2(-dir.X, -dir.Z)
	local peel = { owner = id, at = at, armAt = t0 + land + def.Arm, untilT = t0 + land + def.Lasts }
	table.insert(peels, peel)
	local match = ctx.match()
	task.delay(land, function()
		if ctx.match() ~= match or not table.find(peels, peel) then
			return
		end
		local model = BananaPeel.build()
		BananaPeel.pose(model, CFrame.new(at) * CFrame.Angles(0, yaw, 0))
		BananaPeel.arm(model, false)
		model:SetAttribute("Owner", id)
		model.Parent = folder("HuzzTraps")
		peel.model = model
		task.delay(def.Arm, function()
			if model.Parent then
				BananaPeel.arm(model, true)
			end
		end)
	end)
	return true, nil, { at = at, dir = dir, land = land }
end

-- New Oct 20. A cloud where the runner stands, from the end of the wind-up for Lasts seconds. Catchers inside are
-- slowed (PowerService.step); every screen draws it and hides the name tags of runners inside it.
function USE.SmokeBomb(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local floor = ctx.ground(root.Position)
	local at = Vector3.new(root.Position.X, floor or (root.Position.Y - 3), root.Position.Z)
	local from = now() + wind("SmokeBomb") + Powers.Fx.Flash
	table.insert(clouds, { owner = id, at = at, from = from, untilT = from + def.Lasts, radius = def.Radius })
	return true, nil, { at = at, radius = def.Radius, lasts = def.Lasts }
end

-- New Oct 20. Every active runner within Range glows on every screen for Lasts seconds (character SpottedUntil),
-- each when the sweep reaches them (Sweep seconds to the edge, after the wind-up). It only shows them.
function USE.Radar(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local match = ctx.match()
	task.delay(wind("Radar") + Powers.Fx.Flash, function()
		local from = ctx.rootOf(id)
		if not from or ctx.match() ~= match or match.over or not ctx.running() then
			return
		end
		local origin = from.Position
		for runnerId, status in match.status do
			local r = status == "Active" and ctx.rootOf(runnerId)
			local d = r and (r.Position - origin).Magnitude
			if d and d <= def.Range then
				task.delay(def.Sweep * d / def.Range, function()
					local p = ctx.playerOf(runnerId)
					local c = p and p.Character
					if c and ctx.match() == match and not match.over then
						c:SetAttribute("SpottedUntil", now() + def.Lasts)
					end
				end)
			end
		end
	end)
	return true, nil, { range = def.Range, sweep = def.Sweep }
end

-- New Oct 20. The rope leaves the hand after the wind-up and flies straight ahead at Speed; PowerService.step finds
-- the first runner it touches. Every screen draws it from this message (and LassoHit / LassoMiss).
function USE.Lasso(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local dir = facing(root)
	table.insert(ropes, { owner = id, dir = dir, t0 = now() + wind("Lasso") + Powers.Fx.Flash, match = ctx.match() })
	return true, nil, { dir = dir, range = def.Range, speed = def.Speed }
end

-- Where a thrown trap lands: Throw studs ahead on the floor, shorter before a wall or the field's walls, never in the
-- runners' start zone. nil when there's nowhere to put it.
local function landing(root, def)
	local dir = facing(root)
	local throw = def.Throw
	-- (pcall: one failed ray must never stop the power; the offline sim has no RaycastParams)
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true -- (zones and effects don't stop it; walls, trees and fences do)
		local ignore = {}
		for _, p in Players:GetPlayers() do
			table.insert(ignore, p.Character)
		end
		for _, name in { "HuzzTraps", "HuzzShields", "HuzzCarried", "HuzzFollowers" } do
			table.insert(ignore, Workspace:FindFirstChild(name))
		end
		params.FilterDescendantsInstances = ignore
		local wall = Workspace:Raycast(root.Position, dir * (throw + 1.5), params)
		if wall then
			throw = math.max(0, wall.Distance - 1.5)
		end
	end)
	local start = ctx.startZone()
	if MapService and MapService.fieldLocal then
		local x, z, dx, dz, lo, hi = MapService.fieldLocal(root.Position, dir)
		if x then
			throw = DownMotion.fieldSlide(x, z, dx, dz, throw, def.Radius * 0.5, lo, hi)
		end
	end
	for _, k in { 1, 0.7, 0.4, 0 } do
		local p = root.Position + dir * throw * k
		local floor = ctx.ground(p)
		if floor then
			local at = Vector3.new(p.X, floor, p.Z)
			if not (start and ctx.inZone(start, at + Vector3.new(0, 1, 0))) then
				return at, dir
			end
		end
	end
	return nil
end

function USE.BearTrap(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local at, dir = landing(root, def)
	if not at then
		return false, "Not in the runners' start zone"
	end
	local mine = 0
	for _, t in traps do
		if t.owner == id then
			mine += 1
		end
	end
	if mine >= def.MaxOut then
		-- The oldest of yours makes way.
		for i, t in traps do
			if t.owner == id then
				if t.model then
					t.model:Destroy()
				end
				table.remove(traps, i)
				break
			end
		end
	end
	local t0 = now()
	local yaw = math.atan2(-dir.X, -dir.Z)
	local trap = { owner = id, at = at, yaw = yaw, armAt = t0 + def.Flight + def.Arm, untilT = t0 + def.Flight + def.Lasts }
	table.insert(traps, trap)
	-- It lands after its flight (every screen draws it flying there meanwhile), set open, then arms.
	local match = ctx.match()
	task.delay(def.Flight, function()
		if ctx.match() ~= match or not table.find(traps, trap) then
			return
		end
		local model = BearTrap.build(PINK)
		BearTrap.pose(model, CFrame.new(at) * CFrame.Angles(0, yaw, 0), 0)
		BearTrap.arm(model, false) -- (dim until it can catch)
		model:SetAttribute("Owner", id)
		model:SetAttribute("ArmAt", trap.armAt)
		model.Parent = folder("HuzzTraps")
		trap.model = model
		task.delay(def.Arm, function()
			if model.Parent then
				BearTrap.arm(model, true)
			end
		end)
	end)
	return true, nil, { at = at, dir = dir, flight = def.Flight }
end

function USE.SlowWave(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	-- The slow lands when the wave visibly goes out (Gameplay/PowerEffects: a ring gathers, then the wave), not on
	-- the press, so runners can see it coming and step out. Measured from where the catcher is then.
	local match = ctx.match()
	task.delay(wind("SlowWave"), function()
		local from = ctx.rootOf(id)
		if not from or ctx.match() ~= match or match.over or not ctx.running() then
			return
		end
		local start = ctx.startZone()
		for runnerId, status in match.status do
			local r = status == "Active" and ctx.rootOf(runnerId)
			if r and (r.Position - from.Position).Magnitude <= def.Radius and not (start and ctx.inZone(start, r.Position)) then
				local s = stateOf(runnerId)
				s.slow, s.slowUntil = def.Slow, now() + def.Time
				badge(runnerId, "HuzzSlowed", "😍", Color3.new(1, 1, 1), def.Time)
				ctx.sync(runnerId)
			end
		end
	end)
	return true, nil, { radius = def.Radius }
end

-- Which power is in a slot for this player now (by role, from the loadout read at the round's start; a runner's Q
-- is this round's pick).
local function powerIn(id, slot)
	local match = ctx.match()
	local role = match and match.roles[id]
	local s = stateOf(id)
	s.loadout = s.loadout or AbilityRules.loadout(saveOf(id))
	return AbilityRules.slot(role, slot, s.loadout, s.pick)
end

local function use(player, slot)
	local id = player.UserId
	local match = ctx.match()
	if type(slot) ~= "number" or not match or match.over or not ctx.running() or (ctx.frozen and ctx.frozen(id)) then
		return -- (not while waiting on the line)
	end
	local name = powerIn(id, slot)
	if not name or not USE[name] or (match.roles[id] == "Runner" and match.status[id] ~= "Active") or ctx.isDown(player) then
		return
	end
	local s = stateOf(id)
	local t = now()
	if not AbilityRules.canUse(s.ready[slot], t) or PowerService.stuck(id) then
		return
	end
	local def = Powers[name]
	local ok, _, extra = USE[name](id, def)
	if ok then
		setSlot(id, slot, AbilityRules.nextReady(name, t))
		-- (every client draws the cast: Gameplay/PowerEffects; at = the trap's spot, radius = the wave's reach, ...)
		local msg = { name = name, id = id }
		for k, v in extra or {} do
			msg[k] = v
		end
		Net.get("Round"):FireAllClients("Power", msg)
	end
end

function PowerService.start(context)
	ctx = context
	Net.get("Power").OnServerEvent:Connect(use)
	Players.PlayerRemoving:Connect(function(p)
		local s = state[p.UserId]
		if s and s.bubble then
			s.bubble:Destroy()
		end
		state[p.UserId] = nil
		lastPick[p.UserId] = nil
	end)
end

-- This round's ability for a runner: their pick, or with RANDOM one they own but not last round's
-- (Shared/AbilityRules.runnerPick).
local function pickFor(id)
	local name = AbilityRules.runnerPick(saveOf(id), lastPick[id])
	lastPick[id] = name
	return name
end

-- Fresh powers for everyone in the game; traps and effects from last round go.
function PowerService.newRound()
	PowerService.clear()
	local match = ctx.match()
	for id, role in match.roles do
		local s = stateOf(id)
		s.loadout = AbilityRules.loadout(saveOf(id)) -- (a change in the lobby plays from this round on)
		if role == "Runner" then
			s.pick = pickFor(id)
		end
		setSlot(id, 1, 0)
		setSlot(id, 2, 0)
		local p = ctx.playerOf(id)
		if p then
			p:SetAttribute("PowerName1", powerIn(id, 1))
			p:SetAttribute("PowerName2", powerIn(id, 2))
		end
	end
end

-- keepPowers (after the Hero's solo run): traps and effects go, but everyone keeps their power cards and
-- cooldowns. (Owner, Oct 18: "if you run out of time why dont you have any buttons after?": clearing the cards here
-- hid the power bar for the whole run that follows a Hero run.)
function PowerService.clear(keepPowers: boolean?)
	for _, list in { traps, peels } do
		for _, t in list do
			if t.model then
				t.model:Destroy()
			end
		end
	end
	traps, peels, clouds, ropes = {}, {}, {}, {}
	for id, s in state do
		removeShield(id)
		local p = ctx.playerOf(id)
		if p then
			if not keepPowers then
				p:SetAttribute("PowerReady1", nil)
				p:SetAttribute("PowerReady2", nil)
				p:SetAttribute("PowerName1", nil)
				p:SetAttribute("PowerName2", nil)
			end
			p:SetAttribute("DizzyUntil", nil)
			p:SetAttribute("StunnedFrom", nil)
			p:SetAttribute("StunnedUntil", nil)
			if p.Character then
				p.Character:SetAttribute("InvisibleFrom", nil)
				p.Character:SetAttribute("InvisibleUntil", nil)
				p.Character:SetAttribute("SpottedUntil", nil)
				p.Character:SetAttribute("SlipUntil", nil)
				p.Character:SetAttribute("StunnedFrom", nil)
				p.Character:SetAttribute("StunnedUntil", nil)
			end
		end
		if keepPowers then
			state[id] = { ready = s.ready, pick = s.pick, loadout = s.loadout }
		end
	end
	if not keepPowers then
		state = {}
	end
	lastSpeedCheck = {}
end

-- Speed with powers on top: slowed (Slow Wave, dizzy) and boosted (Speed Boost, a shield pop).
function PowerService.speedOf(id, base)
	local s = state[id]
	if not s then
		return base
	end
	local t = now()
	local speed = base
	if s.slowUntil and t < s.slowUntil then
		speed *= s.slow
	end
	if s.dizzyUntil and t < s.dizzyUntil then
		speed *= Powers.Shield.DizzySlow
	end
	if s.smokeUntil and t < s.smokeUntil then
		speed *= Powers.SmokeBomb.Slow
	end
	if s.boostUntil and t < s.boostUntil then
		speed += s.boost
	end
	return speed
end

-- Stunned after a dive (Config/Round.Lunge.Stun): from `after` seconds from now, for `seconds`. No moving, no
-- stabbing, no powers. Shown on the catcher's bar (player StunnedFrom / StunnedUntil) and over their body on every
-- screen (character StunnedFrom / StunnedUntil: Gameplay/PowerEffects circles three stars over the head; the 💫 badge;
-- Shared/StabMotion keeps them lying dazed).
function PowerService.stun(id, after: number, seconds: number)
	if not ctx or seconds <= 0 then
		return
	end
	local s = stateOf(id)
	local t = now()
	s.stunFrom, s.stunUntil = t + after, t + after + seconds
	local p = ctx.playerOf(id)
	if p then
		p:SetAttribute("StunnedFrom", s.stunFrom)
		p:SetAttribute("StunnedUntil", s.stunUntil)
		if p.Character then
			p.Character:SetAttribute("StunnedFrom", s.stunFrom)
			p.Character:SetAttribute("StunnedUntil", s.stunUntil)
		end
	end
	task.delay(after, function()
		if state[id] == s and s.stunUntil then
			ctx.sync(id) -- (speed 0 now; step() gives it back when it ends)
			if seconds >= 1 then -- (a dive's 0.4 s pop up is no "stunned" moment: owner Oct 20 15:13, no long unconsciousness)
				badge(id, "HuzzStunned", "💫 STUNNED", Color3.fromRGB(255, 230, 120), math.max(0, s.stunUntil - now()))
			end
		end
	end)
end

function PowerService.stunned(id)
	local s = state[id]
	local t = now()
	return s ~= nil and s.stunUntil ~= nil and t >= (s.stunFrom or 0) and t < s.stunUntil
end

-- Can't move: caught in a trap, or stunned after a dive.
function PowerService.stuck(id)
	local s = state[id]
	return s ~= nil and ((s.stuckUntil ~= nil and now() < s.stuckUntil) or PowerService.stunned(id))
end

-- (A dive's own hit window isn't cut short by the stun that follows it: RoundService checks stunned() for new stabs.)
function PowerService.canStab(id)
	local s = state[id]
	return not (s and s.dizzyUntil and now() < s.dizzyUntil)
end

-- A stab (or touch) on a runner with a live Shield: the shield pops instead, the catcher gets dizzy and the runner
-- gets a burst. Returns true when the tag is blocked.
function PowerService.blocks(catcherId, runnerId)
	local s = state[runnerId]
	if not (s and s.shieldUntil and now() < s.shieldUntil) then
		return false
	end
	local def = Powers.Shield
	removeShield(runnerId)
	local root = ctx.rootOf(runnerId)
	Net.get("Round"):FireAllClients("Power", { name = "ShieldPop", id = runnerId, by = catcherId, at = root and root.Position })
	if catcherId then
		local c = stateOf(catcherId)
		c.dizzyUntil = now() + def.Dizzy
		local catcher = ctx.playerOf(catcherId)
		if catcher then
			catcher:SetAttribute("DizzyUntil", c.dizzyUntil) -- the STAB button goes dark meanwhile
		end
		badge(catcherId, "HuzzDizzy", "💫 DIZZY", Color3.fromRGB(255, 230, 120), def.Dizzy)
		ctx.sync(catcherId)
	end
	boost(runnerId, def.Boost, def.BoostTime, PINK)
	return true
end

-- Flat distance and height gap from a spot on the floor.
local function near(pos: Vector3, at: Vector3, radius: number, tall: number): boolean
	local d = pos - at
	return Vector3.new(d.X, 0, d.Z).Magnitude <= radius and math.abs(d.Y) < tall
end

-- Banana peels: the first catcher on an armed one slips (stuck and no stabbing for Slip seconds); it goes when it
-- runs out.
stepPeels = function(t, match)
	local def = Powers.BananaPeel
	for i = #peels, 1, -1 do
		local peel = peels[i]
		local gone = t >= peel.untilT
		if not gone and t >= peel.armAt then
			for catcherId, role in match.roles do
				local r = role == "Catcher" and not PowerService.stuck(catcherId) and ctx.playerOf(catcherId) and ctx.rootOf(catcherId)
				if r and near(r.Position, peel.at, def.Radius, 6) then
					local s = stateOf(catcherId)
					s.stuckUntil = t + def.Slip
					s.dizzyUntil = math.max(s.dizzyUntil or 0, t + def.Slip)
					local p = ctx.playerOf(catcherId)
					if p then
						p:SetAttribute("DizzyUntil", s.dizzyUntil) -- (the STAB button goes dark meanwhile)
						if p.Character then
							p.Character:SetAttribute("SlipUntil", t + def.Slip) -- (stars over the head on every screen)
						end
					end
					badge(catcherId, "HuzzSlip", "🍌 SLIP!", def.Accent, def.Slip)
					local feet = Vector3.new(r.Position.X, peel.at.Y, r.Position.Z)
					Net.get("Round"):FireAllClients("Power", { name = "PeelSlip", id = catcherId, by = peel.owner, at = feet, slip = def.Slip })
					ctx.sync(catcherId)
					gone = true
					peel.slipped = true
					break
				end
			end
		end
		-- the Practice Bot slips on it too (alone in Studio, the owner's catcher is the bot)
		local bot = not gone and t >= peel.armAt and ctx.bot and ctx.bot()
		local botAt = bot and bot.position()
		if botAt and near(botAt, peel.at, def.Radius, 6) then
			bot.trip(def.Slip)
			Net.get("Round"):FireAllClients("Power", { name = "PeelSlip", by = peel.owner, at = Vector3.new(botAt.X, peel.at.Y, botAt.Z), slip = def.Slip, body = bot.body() })
			gone, peel.slipped = true, true
		end
		if gone then
			if not peel.slipped and peel.model then
				Net.get("Round"):FireAllClients("Power", { name = "PeelGone", id = peel.owner, at = peel.at })
			end
			if peel.model then
				peel.model:Destroy()
			end
			table.remove(peels, i)
		end
	end
end

-- Smoke clouds: catchers inside one are slowed (the slow rolls on while they stay in, and ends a moment after).
stepClouds = function(t, match)
	for i = #clouds, 1, -1 do
		if t >= clouds[i].untilT then
			table.remove(clouds, i)
		end
	end
	if #clouds == 0 then
		return
	end
	for catcherId, role in match.roles do
		local r = role == "Catcher" and ctx.rootOf(catcherId)
		if r then
			for _, c in clouds do
				if t >= c.from and near(r.Position, c.at, c.radius, 9) then
					local s = stateOf(catcherId)
					local was = s.smokeUntil and t < s.smokeUntil
					s.smokeUntil = t + 0.25
					if not was then
						ctx.sync(catcherId)
					end
					break
				end
			end
		end
	end
end

-- Lassos in flight: the rope's tip runs out at Speed from the catcher along the way they faced; the first active
-- runner it touches (not in their start zone) is pulled towards the catcher by their own screen (LassoHit), then
-- slowed for Hold. A Shield stops it. Past Range it's a miss and reels back.
stepRopes = function(t, match)
	local def = Powers.Lasso
	local start = ctx.startZone()
	for i = #ropes, 1, -1 do
		local rope = ropes[i]
		local from = ctx.rootOf(rope.owner)
		if rope.match ~= match or match.over or not from then
			table.remove(ropes, i)
		elseif t >= rope.t0 then
			local tip = math.min((t - rope.t0) * def.Speed, def.Range)
			local best, bestAlong, bestRoot = nil, math.huge, nil
			for runnerId, status in match.status do
				local r = status == "Active" and not (ctx.frozen and ctx.frozen(runnerId)) and ctx.rootOf(runnerId)
				if r and not (start and ctx.inZone(start, r.Position)) then
					local d = r.Position - from.Position
					local flat = Vector3.new(d.X, 0, d.Z)
					local along = flat:Dot(rope.dir)
					local side = (flat - rope.dir * along).Magnitude
					if along > 0.5 and along <= tip + 0.5 and side <= def.Width / 2 + 1 and math.abs(d.Y) < 6 and along < bestAlong then
						best, bestAlong, bestRoot = runnerId, along, r
					end
				end
			end
			if best then
				table.remove(ropes, i)
				local s = stateOf(best)
				local blocked = s.shieldUntil ~= nil and t < s.shieldUntil
				local flat = Vector3.new(from.Position.X - bestRoot.Position.X, 0, from.Position.Z - bestRoot.Position.Z)
				local dist = if blocked then 0 else math.clamp(flat.Magnitude - def.MinGap, 0, def.Pull)
				Net.get("Round"):FireAllClients("Power", {
					name = "LassoHit", id = rope.owner, target = best, at = bestRoot.Position, toward = from.Position,
					dist = dist, time = def.PullTime, blocked = blocked,
				})
				if not blocked then
					s.slow, s.slowUntil = def.Slow, t + def.PullTime + def.Hold
					badge(best, "HuzzLassoed", "YOINK!", def.Accent, def.PullTime + def.Hold)
					ctx.sync(best)
				end
			elseif tip >= def.Range then
				table.remove(ropes, i)
				Net.get("Round"):FireAllClients("Power", { name = "LassoMiss", id = rope.owner })
			end
		end
	end
end

-- Every frame of a round: armed traps catch runners, effects run out.
function PowerService.step()
	local t = now()
	local match = ctx.match()
	local def = Powers.BearTrap
	for i = #traps, 1, -1 do
		local trap = traps[i]
		local sprung = nil
		if t >= trap.untilT then
			sprung = false
		elseif t >= trap.armAt then
			for runnerId, status in match.status do
				local r = status == "Active" and not PowerService.stuck(runnerId) and ctx.rootOf(runnerId)
				if r then
					local d = r.Position - trap.at
					if Vector3.new(d.X, 0, d.Z).Magnitude <= def.Radius and math.abs(d.Y) < 6 then
						local s = stateOf(runnerId)
						s.stuckUntil = t + def.Hold
						badge(runnerId, "HuzzStuck", "💘 STUCK!", PINK, def.Hold)
						-- (it snaps round their feet, not where it lay: Radius reaches past the jaws)
						local feet = Vector3.new(r.Position.X, trap.at.Y, r.Position.Z)
						Net.get("Round"):FireAllClients("Power", { name = "TrapSprung", id = runnerId, by = trap.owner, at = feet, yaw = trap.yaw, hold = def.Hold })
						ctx.sync(runnerId)
						sprung = true
						break
					end
				end
			end
		end
		if sprung ~= nil then
			if sprung == false and trap.model then -- (ran out: every screen shows it fold away)
				Net.get("Round"):FireAllClients("Power", { name = "TrapGone", id = trap.owner, at = trap.at })
			end
			if trap.model then
				trap.model:Destroy()
			end
			table.remove(traps, i)
		end
	end
	stepPeels(t, match)
	stepClouds(t, match)
	stepRopes(t, match)
	-- Speeds go back when an effect ends; a shield that ran out pops quietly.
	for id, s in state do
		local active = (s.slowUntil and t < s.slowUntil) or (s.dizzyUntil and t < s.dizzyUntil)
			or (s.boostUntil and t < s.boostUntil) or (s.stuckUntil and t < s.stuckUntil)
			or (s.stunUntil and t < s.stunUntil) or (s.smokeUntil and t < s.smokeUntil)
		-- (a dive's stun starts a moment after the dive: freeze them the first frame it's on, not when a timer says)
		local stunnedNow = PowerService.stunned(id)
		if (lastSpeedCheck[id] and not active) or (stunnedNow and lastSpeedCheck[id] ~= "stunned") then
			ctx.sync(id)
		end
		lastSpeedCheck[id] = if stunnedNow then "stunned" elseif active then true else nil
		if s.shieldUntil and t >= s.shieldUntil then
			-- ran out without a stab: every screen shows it fizzle (a blocked stab pops it: ShieldPop)
			local root = ctx.rootOf(id)
			Net.get("Round"):FireAllClients("Power", { name = "ShieldEnd", id = id, at = root and root.Position })
			removeShield(id)
		end
	end
end

return PowerService
