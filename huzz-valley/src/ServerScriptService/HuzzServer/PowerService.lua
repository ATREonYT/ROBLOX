--[[
	Round powers (Config/Powers). Runners: this round's ability on Q (Shield, Invisible, Glitchy or Body Double, picked
	at random for each runner when the round starts) and Speed Boost on E (only while carrying the girl). Catchers:
	Bear Trap on Q, Slow Wave on E. Everything is decided here on the server; the client only asks ("Power" remote,
	slot 1 or 2) and shows the result (Screens/PowerBar, Gameplay/PowerEffects).

	RoundService drives it: start(ctx) once, newRound() when a round starts, step() every frame of a round, clear()
	when the game ends. It asks speedOf/stuck when it sets a player's speed, canStab/stunned before a stab, blocks()
	before tagging (a Shield eats the stab) and stun() after a catcher's dive (Config/Round.Lunge.Stun).

	For the cards each player gets attributes: PowerName1/PowerName2 (which power is in each slot this round),
	PowerReady1/PowerReady2 (server time the slot is ready again; -1 = used up this round), ShieldUntil, DizzyUntil,
	StunnedFrom/StunnedUntil (a dive's stun). The character gets InvisibleUntil (every screen fades it) and
	StunnedFrom / StunnedUntil. Effects other players should see are parts made here (bubble, trail, traps, badges); one-off bursts go
	to every client as a "Power" message on the Round remote (each use, a blocked stab, a sprung trap). Slow Wave's
	slow lands Config/Powers.Fx.WindUp after the press, when its ring visibly goes out; a Bear Trap lands
	BearTrap.Flight after the throw (every screen draws it flying) and catches from BearTrap.Arm after that.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Powers = require(Shared.Config.Powers)
local Net = require(Shared.Net)
local BearTrap = require(Shared.BearTrap)
local DownMotion = require(Shared.DownMotion)

local PowerService = {}
local ctx = nil -- from RoundService: match(), running(), rootOf(id), playerOf(id), isDown(player), sync(id),
-- startZone(), inZone(zone, pos), ground(pos)
local state = {} -- UserId -> { ready = {slot -> time}, pick, shieldUntil, dizzyUntil, boostUntil, boost, slowUntil, slow,
-- stuckUntil, stunFrom, stunUntil }
local lastPick = {} -- UserId -> last round's ability (the next round picks another)
local traps = {} -- { model, owner, at (Vector3), armAt, untilT }
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
		trail.Color = ColorSequence.new(color or Powers.SpeedBoost.Accent, Color3.new(1, 1, 1))
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

function USE.Shield(id, def)
	local s = stateOf(id)
	s.shieldUntil = now() + def.Lasts
	local p = ctx.playerOf(id)
	p:SetAttribute("ShieldUntil", s.shieldUntil)
	local root = ctx.rootOf(id)
	if root then
		local bubble = Instance.new("Part")
		bubble.Name = "HuzzShield"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(7, 7, 7)
		bubble.Material = Enum.Material.ForceField
		bubble.Color = def.Accent
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
	boost(id, def.Boost, def.Time, def.Accent)
	return true
end

function USE.Invisible(id, def)
	local p = ctx.playerOf(id)
	local c = p and p.Character
	if not c then
		return false
	end
	-- every screen fades this character (Gameplay/PowerEffects), still catchable
	c:SetAttribute("InvisibleUntil", now() + def.Lasts)
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
		local model = BearTrap.build(def.Accent)
		BearTrap.pose(model, CFrame.new(at) * CFrame.Angles(0, yaw, 0), 0)
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
	-- The slow lands when the wave visibly goes out (Gameplay/PowerEffects: a wind-up, then the ring), not on the
	-- press, so runners can see it coming. Measured from where the catcher is then.
	local match = ctx.match()
	task.delay(Powers.Fx.WindUp, function()
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
				badge(runnerId, "HuzzSlowed", "🐌 SLOW", Color3.fromRGB(220, 200, 255), def.Time)
				ctx.sync(runnerId)
			end
		end
	end)
	return true, nil, { radius = def.Radius }
end

-- Which power is in a slot for this player now (by role; a runner's Q is this round's pick).
local function powerIn(id, slot)
	local match = ctx.match()
	local role = match and match.roles[id]
	local list = role and Powers[role]
	local name = list and list[slot]
	if name == "Pick" then
		name = stateOf(id).pick
	end
	return name
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
	local ready = s.ready[slot] or 0
	if ready < 0 or t < ready - 0.15 or PowerService.stuck(id) then
		return
	end
	local def = Powers[name]
	local ok, _, extra = USE[name](id, def)
	if ok then
		setSlot(id, slot, if def.OncePerRound then -1 else t + def.Cooldown)
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

-- This round's ability for a runner: any of RunnerPick but last round's.
local function pickFor(id)
	local pool = {}
	for _, name in Powers.RunnerPick do
		if name ~= lastPick[id] or #Powers.RunnerPick == 1 then
			table.insert(pool, name)
		end
	end
	local name = pool[math.random(1, #pool)]
	lastPick[id] = name
	return name
end

-- Fresh powers for everyone in the game; traps and effects from last round go.
function PowerService.newRound()
	PowerService.clear()
	local match = ctx.match()
	for id, role in match.roles do
		if role == "Runner" then
			stateOf(id).pick = pickFor(id)
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
	for _, t in traps do
		if t.model then
			t.model:Destroy()
		end
	end
	traps = {}
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
				p.Character:SetAttribute("InvisibleUntil", nil)
				p.Character:SetAttribute("StunnedFrom", nil)
				p.Character:SetAttribute("StunnedUntil", nil)
			end
		end
		if keepPowers then
			state[id] = { ready = s.ready, pick = s.pick }
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
			badge(id, "HuzzStunned", "💫 STUNNED", Color3.fromRGB(255, 230, 120), math.max(0, s.stunUntil - now()))
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
	boost(runnerId, def.Boost, def.BoostTime, def.Accent)
	return true
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
						badge(runnerId, "HuzzStuck", "🪤 STUCK!", def.Accent, def.Hold)
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
			if trap.model then
				trap.model:Destroy()
			end
			table.remove(traps, i)
		end
	end
	-- Speeds go back when an effect ends; a shield that ran out pops quietly.
	for id, s in state do
		local active = (s.slowUntil and t < s.slowUntil) or (s.dizzyUntil and t < s.dizzyUntil)
			or (s.boostUntil and t < s.boostUntil) or (s.stuckUntil and t < s.stuckUntil)
			or (s.stunUntil and t < s.stunUntil)
		-- (a dive's stun starts a moment after the dive: freeze them the first frame it's on, not when a timer says)
		local stunnedNow = PowerService.stunned(id)
		if (lastSpeedCheck[id] and not active) or (stunnedNow and lastSpeedCheck[id] ~= "stunned") then
			ctx.sync(id)
		end
		lastSpeedCheck[id] = if stunnedNow then "stunned" elseif active then true else nil
		if s.shieldUntil and t >= s.shieldUntil then
			removeShield(id)
		end
	end
end

return PowerService
