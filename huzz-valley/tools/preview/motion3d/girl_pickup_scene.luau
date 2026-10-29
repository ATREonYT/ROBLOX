-- The pickup, before and after (owner, Oct 19: "add the nice girl animations when they are picked up"), the game's
-- own Shared/CarryMotion and Config/Carry:
--   0.6 s  she is won from the big girl over the map (far away): she appears on the ground in front of him in a soft
--          puff, rises turning once into his arms, a ring at his feet and sparkles mark it (Epic: purple).
--   4.2 s  she is stolen from the runner beside him (close by): she flies over from that head (Legendary: orange).
-- Left lane BEFORE (an older copy of Shared, from GIRLS_BEFORE: she appeared overhead at once), right lane NOW.
-- The puff, ring and sparkles are drawn the way Gameplay/CarryAnimator asks Gameplay/Burst for them (Burst.sparks,
-- Burst.ring); here they are sprites, so their look is a stand-in for Roblox's particles.
--   git archive HEAD huzz-valley/src/ReplicatedStorage/Shared | tar -x -C /tmp/before
--   GIRLS_BEFORE=/tmp/before/huzz-valley/src/ReplicatedStorage/Shared/ sh video.sh girl_pickup_scene.luau out.mp4
-- Film: docs/previews/girl-pickup.mp4.
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")

local NOW = "huzz-valley/src/ReplicatedStorage/Shared/"
local BEFORE = process.env.GIRLS_BEFORE or NOW
local function code(dir)
	return {
		CarryMath = Env.load(dir .. "CarryMath.lua"),
		CarryMotion = Env.load(dir .. "CarryMotion.lua"),
		Carry = Env.load(dir .. "Config/Carry.lua"),
	}
end
local lanes = { { name = "BEFORE", code = code(BEFORE), x = -5.5, fx = false }, { name = "NOW", code = code(NOW), x = 5.5, fx = true } }

local GIRL = { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#7a5cc8", eyes = "#2a1a40" }
local scene = Scene.new()
for i = -10, 30 do
	for j = -6, 6 do
		scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end

local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		if not p.hidden then
			local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
local function hide(rig, hidden)
	for _, p in rig.parts do
		if p.Name ~= "HumanoidRootPart" then p.hidden = hidden end
	end
	rig.decor = if hidden then {} else rig.savedDecor
end

local PICKS = {
	{ at = 0.6, colour = "#b068ff", near = false }, -- won from the big girl over the map
	{ at = 4.2, colour = "#ffbe3c", near = true }, -- stolen from the runner beside him
}
for _, lane in lanes do
	local c = lane.code
	lane.carrier = scene:addRig(Rig.r15("Carrier" .. lane.name, { shirt = "#2f6fe0", pants = "#262a36" }))
	lane.other = scene:addRig(Rig.r15("Other" .. lane.name, { shirt = "#6b6b78", pants = "#30303a" }))
	lane.girl = scene:addRig(Rig.r6("Girl" .. lane.name, GIRL))
	Rig.scale(lane.girl, c.Carry.GirlLength / 5.25)
	lane.girl.savedDecor = lane.girl.decor
	local centre, size = bounds(lane.girl)
	lane.motor = Rig.motor("HuzzCarryMotor", lane.carrier.parts.UpperTorso, lane.girl.root, c.CarryMath.holdC0(c.CarryMath.rig(lane.carrier), size.Z), centre)
	lane.carrier.root.CFrame = CFrame.new(lane.x, Rig.REST_HEIGHT, 0)
	lane.other.root.CFrame = CFrame.new(lane.x + 4.2, Rig.REST_HEIGHT, -1.5)
	Rig.fk(lane.other)
	lane.sparks, lane.rings = {}, {}
end

local FPS, DT, SECONDS = 30, 1 / 30, 8
local seed = 7
local function rnd()
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end
local function burst(lane, at, colour, count, speed, up)
	for _ = 1, count do
		local dir = Vector3.new(rnd() - 0.5, rnd() - 0.3 + up, rnd() - 0.5)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
		table.insert(lane.sparks, { p = at, v = dir * speed * (0.6 + rnd() * 0.6), age = 0, life = 0.4 + rnd() * 0.4, c = if rnd() < 0.5 then colour else "#ffffff", g = if up > 0 then 3 else -4 })
	end
end
local function carrierSpeed(t) return if t > 2 and t < 3.4 then 9 elseif t > 5.6 and t < 7 then 9 else 0 end

local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local sprites = {}
	for _, lane in lanes do
		local c = lane.code
		-- the carrier walks a little between the pickups (her hold follows him)
		local speed = carrierSpeed(t)
		lane.carrier.root.CFrame = lane.carrier.root.CFrame + Vector3.new(0, 0, -speed * DT)
		lane.other.root.CFrame = lane.other.root.CFrame + Vector3.new(0, 0, -speed * DT)
		Rig.fk(lane.other)
		-- which pickup is on
		local pick
		for _, pk in PICKS do
			if t >= pk.at then pick = pk end
		end
		if pick and lane.pick ~= pick then
			lane.pick = pick
			local from = if pick.near then lane.other.parts.Head.CFrame.Position + Vector3.new(0, 1.4, 0) else Vector3.new(lane.x, 40, -60)
			lane.carry = c.CarryMotion.new({
				motor = lane.motor, rig = c.CarryMath.rig(lane.carrier), root = lane.carrier.root, girlMotors = lane.girl.motors,
				start = pick.at, from = from, seed = 7,
			})
			lane.puffed, lane.landed = false, false
		end
		hide(lane.girl, lane.carry == nil)
		if lane.carry then
			Rig.fk(lane.carrier, { lane.motor }, { lane.girl })
			c.CarryMotion.step(lane.carry, DT, t, "Excited", t - pick.at)
			Rig.fk(lane.carrier, { lane.motor }, { lane.girl })
			-- the game's pickup effects (Gameplay/CarryAnimator pickupFx), NOW lane only
			if lane.fx then
				local P = lane.carry.from
				if not lane.puffed then
					lane.puffed = true
					burst(lane, P, pick.colour, 8, 3.5, 0.6)
				end
				local progress = if c.CarryMotion.progress then c.CarryMotion.progress(lane.carry, t) else 1
				if progress >= 1 and not lane.landed then
					lane.landed = true
					burst(lane, lane.girl.root.CFrame.Position, pick.colour, 14, 6, 0)
					local feet = lane.carrier.root.CFrame.Position - Vector3.new(0, Rig.REST_HEIGHT - 0.15, 0)
					table.insert(lane.rings, { p = feet, age = 0, c = pick.colour })
				end
			end
		else
			Rig.fk(lane.carrier)
		end
		-- effects: sparkles (Burst.sparks) and the ring (Burst.ring: 1.2 -> 5 studs over 0.55 s, fading over its last half)
		local keep = {}
		for _, q in lane.sparks do
			q.age += DT
			if q.age < q.life then
				q.v = q.v * math.exp(-3 * DT) + Vector3.new(0, q.g * DT, 0)
				q.p += q.v * DT
				local k = q.age / q.life
				table.insert(sprites, { p = { q.p.X, q.p.Y, q.p.Z }, s = 0.55 * (1 - k * 0.6), c = q.c, a = 1 - k, t = "star", r = 0, add = true })
				table.insert(keep, q)
			end
		end
		lane.sparks = keep
		local keepR = {}
		for _, ring in lane.rings do
			ring.age += DT
			local k = ring.age / 0.55
			if k < 1 then
				local e = 1 - (1 - k) ^ 2
				local r = 1.2 + (5 - 1.2) * e
				local a = if k < 0.5 then 1 else 1 - (k - 0.5) / 0.5
				table.insert(sprites, { p = { ring.p.X, ring.p.Y, ring.p.Z }, s = r * 2, c = ring.c, a = a * 0.9, t = "@ring6", flat = true, b = 1, add = true })
				table.insert(keepR, ring)
			end
		end
		lane.rings = keepR
	end

	local z = lanes[1].carrier.root.CFrame.Position.Z
	local focus = Vector3.new(0, 4.2, z - 1)
	local target = focus + Vector3.new(7, 3, -17) -- (from in front of them: she starts in front of the carrier)
	camPos = if camPos then camPos:Lerp(target, 0.5) else target
	local labels = {}
	for _, lane in lanes do
		table.insert(labels, { p = { lane.x, 10.2, z }, text = lane.name, h = 0.9, c = if lane.name == "NOW" then "#7dffa0" else "#ffffff", o = "#000000" })
	end
	local caption = if t < 4.2 then "Picked up (won from the girl over the map): she rises from in front of him, turning once"
		else "Stolen from the runner beside him: she flies over from that head"
	if not process.env.EVERY or f % tonumber(process.env.EVERY) == 0 then
		scene:frame(camPos, focus, { caption = caption, labels = labels, sprites = sprites })
	end
end
scene:save(nil, FPS, 1280, 720)
