--[[
	Round powers (Config/Powers): Heart Shield and Rizz Rush for runners, Love Trap and Charm Wave
	for catchers. Everything is decided here on the server; the client only asks ("Power" remote,
	slot 1 or 2) and shows the result (Screens/PowerBar, Gameplay/PowerEffects).

	RoundService drives it: start(ctx) once, newRound() when a round starts, step() every frame
	of a round, clear() when the game ends. It asks speedOf/stuck when it sets a player's speed,
	canStab before a stab, and blocks() before tagging (a Heart Shield eats the stab).

	For the hotbar each player gets attributes: PowerReady1/PowerReady2 (server time the slot is
	ready again; -1 = used up this round) and ShieldUntil. Effects other players should see are
	parts and billboards made here (bubble, trail, traps, badges); one-off bursts go to every
	client as a "Power" message on the Round remote (each use, a blocked stab, a sprung trap). Charm Wave's slow
	lands Config/Powers.Fx.WindUp after the press, when its ring visibly goes out.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Powers = require(Shared.Config.Powers)
local Net = require(Shared.Net)

local PowerService = {}
local ctx = nil -- from RoundService: match(), running(), rootOf(id), playerOf(id), isDown(player), sync(id),
-- startZone(), inZone(zone, pos), ground(pos)
local state = {} -- UserId -> { ready = {slot -> time}, shieldUntil, dizzyUntil, boostUntil, boost, slowUntil, slow, stuckUntil }
local traps = {} -- { model, owner, at (Vector3), untilT }
local lastSpeedCheck = {} -- UserId -> true while an effect changes their speed
local PINK = Color3.fromRGB(255, 110, 190)

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

local function boost(id, amount, seconds)
	local s = stateOf(id)
	s.boost, s.boostUntil = amount, now() + seconds
	s.trailUntil = math.max(s.trailUntil or 0, s.boostUntil)
	-- A pink trail behind them while it lasts.
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
		trail.Color = ColorSequence.new(PINK, Color3.new(1, 1, 1))
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

local USE = {}

function USE.HeartShield(id, def)
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

function USE.RizzRush(id, def)
	boost(id, def.Boost, def.Time)
	return true
end

function USE.LoveTrap(id, def)
	local root = ctx.rootOf(id)
	if not root then
		return false
	end
	local start = ctx.startZone()
	if start and ctx.inZone(start, root.Position) then
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
				t.model:Destroy()
				table.remove(traps, i)
				break
			end
		end
	end
	local floor = ctx.ground(root.Position) or (root.Position.Y - 3)
	local at = Vector3.new(root.Position.X, floor, root.Position.Z)
	local model = Instance.new("Model")
	model.Name = "LoveTrap"
	local function piece(size, color, transparency, offset)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Transparency = transparency
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.CFrame = CFrame.new(at + Vector3.new(0, offset, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = model
		return p
	end
	piece(Vector3.new(0.2, def.Radius * 2, def.Radius * 2), Color3.fromRGB(120, 20, 70), 0.1, 0.1)
	local glow = piece(Vector3.new(0.24, def.Radius * 2 - 0.8, def.Radius * 2 - 0.8), PINK, 0.25, 0.12)
	glow.Name = "Glow"
	glow.Material = Enum.Material.Neon
	local holder = Instance.new("Part")
	holder.Name = "Sign"
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0))
	holder.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(2.2, 0, 2.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = holder
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.fromScale(1, 1)
	heart.BackgroundTransparency = 1
	heart.Text = "💘"
	heart.TextScaled = true
	heart.Parent = gui
	model.Parent = folder("HuzzTraps")
	table.insert(traps, { model = model, owner = id, at = at, untilT = now() + def.Lasts })
	return true, nil, { at = at }
end

function USE.CharmWave(id, def)
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
				badge(runnerId, "HuzzCharmed", "😍", Color3.new(1, 1, 1), def.Time)
				ctx.sync(runnerId)
			end
		end
	end)
	return true, nil, { radius = def.Radius }
end

-- Which power is in a slot for this player now (by role).
local function powerIn(id, slot)
	local match = ctx.match()
	local role = match and match.roles[id]
	local list = role and Powers[role]
	return list and list[slot]
end

local function use(player, slot)
	local id = player.UserId
	local match = ctx.match()
	if type(slot) ~= "number" or not match or match.over or not ctx.running() or (ctx.frozen and ctx.frozen(id)) then
		return -- (not while waiting on the line)
	end
	local name = powerIn(id, slot)
	if not name or (match.roles[id] == "Runner" and match.status[id] ~= "Active") or ctx.isDown(player) then
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
		-- (every client draws the cast: Gameplay/PowerEffects; at = the trap's spot, radius = the wave's reach)
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
	end)
end

-- Fresh powers for everyone in the game; traps and effects from last round go.
function PowerService.newRound()
	PowerService.clear()
	local match = ctx.match()
	for id in match.roles do
		setSlot(id, 1, 0)
		setSlot(id, 2, 0)
	end
end

function PowerService.clear()
	for _, t in traps do
		t.model:Destroy()
	end
	traps = {}
	for id in state do
		removeShield(id)
		local p = ctx.playerOf(id)
		if p then
			p:SetAttribute("PowerReady1", nil)
			p:SetAttribute("PowerReady2", nil)
			p:SetAttribute("DizzyUntil", nil)
		end
	end
	state = {}
	lastSpeedCheck = {}
end

-- Speed with powers on top: slowed (charmed, dizzy) and boosted (rush, shield pop).
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
		speed *= Powers.HeartShield.DizzySlow
	end
	if s.boostUntil and t < s.boostUntil then
		speed += s.boost
	end
	return speed
end

function PowerService.stuck(id)
	local s = state[id]
	return s ~= nil and s.stuckUntil ~= nil and now() < s.stuckUntil
end

function PowerService.canStab(id)
	local s = state[id]
	return not (s and s.dizzyUntil and now() < s.dizzyUntil)
end

-- A stab (or touch) on a runner with a live Heart Shield: the shield pops instead, the catcher
-- gets dizzy and the runner gets a burst. Returns true when the tag is blocked.
function PowerService.blocks(catcherId, runnerId)
	local s = state[runnerId]
	if not (s and s.shieldUntil and now() < s.shieldUntil) then
		return false
	end
	local def = Powers.HeartShield
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
	boost(runnerId, def.Boost, def.BoostTime)
	return true
end

-- Every frame of a round: traps catch runners, effects run out.
function PowerService.step()
	local t = now()
	local match = ctx.match()
	for i = #traps, 1, -1 do
		local trap = traps[i]
		local sprung = nil
		if t >= trap.untilT then
			sprung = false
		else
			for runnerId, status in match.status do
				local r = status == "Active" and not PowerService.stuck(runnerId) and ctx.rootOf(runnerId)
				if r then
					local d = r.Position - trap.at
					if Vector3.new(d.X, 0, d.Z).Magnitude <= Powers.LoveTrap.Radius and math.abs(d.Y) < 6 then
						local s = stateOf(runnerId)
						s.stuckUntil = t + Powers.LoveTrap.Hold
						badge(runnerId, "HuzzStuck", "💘 STUCK!", PINK, Powers.LoveTrap.Hold)
						Net.get("Round"):FireAllClients("Power", { name = "TrapSprung", id = runnerId, by = trap.owner, at = trap.at })
						ctx.sync(runnerId)
						sprung = true
						break
					end
				end
			end
		end
		if sprung ~= nil then
			trap.model:Destroy()
			table.remove(traps, i)
		end
	end
	-- Speeds go back when an effect ends; a shield that ran out pops quietly.
	for id, s in state do
		local active = (s.slowUntil and t < s.slowUntil) or (s.dizzyUntil and t < s.dizzyUntil)
			or (s.boostUntil and t < s.boostUntil) or (s.stuckUntil and t < s.stuckUntil)
		if lastSpeedCheck[id] and not active then
			ctx.sync(id)
		end
		lastSpeedCheck[id] = active or nil
		if s.shieldUntil and t >= s.shieldUntil then
			removeShield(id)
		end
	end
end

return PowerService
