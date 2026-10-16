--[[
	Builds a girl's effects (Shared/AuraLook data) on a character or a model, on this screen only (every
	client builds them for everyone it can see, so nothing heavy goes over the network):
	  ParticleEmitters on Attachments at her hands / body / head / feet, a PointLight, and crescent slashes
	  (two Beams each: a bright core over a dark edge, bent into an arc with CurveSize, swept round and faded
	  every frame by step()).
	AuraFX.attach(model, spec) -> handle { step(dt), setEnabled(on), destroy() }. Not started on its own:
	Gameplay/Auras uses it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraLook = require(Shared.AuraLook)
local ImageIds = require(Shared.Config.ImageIds)

local AuraFX = {}

local function texture(name)
	local id = ImageIds["Fx/" .. name]
	return if id and id ~= "" then id else AuraLook.TEXTURES[name]
end

local function colorSeq(list)
	local keys = {}
	for _, k in list do
		table.insert(keys, ColorSequenceKeypoint.new(k[1], k[2]))
	end
	return ColorSequence.new(keys)
end

local function numberSeq(list, mult)
	local keys = {}
	for _, k in list do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2] * (mult or 1)))
	end
	return NumberSequence.new(keys)
end

-- Where each anchor is on this model: a part and an offset (R15 and R6 both).
local function anchor(model, at, scale)
	local function find(...)
		for _, name in { ... } do
			local p = model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				return p
			end
		end
		return nil
	end
	if at == "RightHand" then
		local hand = find("RightHand")
		if hand then return hand, CFrame.identity end
		local arm = find("Right Arm")
		return arm, CFrame.new(0, -(arm and arm.Size.Y or 2) * 0.45, 0)
	elseif at == "LeftHand" then
		local hand = find("LeftHand")
		if hand then return hand, CFrame.identity end
		local arm = find("Left Arm")
		return arm, CFrame.new(0, -(arm and arm.Size.Y or 2) * 0.45, 0)
	elseif at == "Head" then
		return find("Head"), CFrame.identity
	elseif at == "Feet" then
		local root = find("HumanoidRootPart", "LowerTorso", "Torso")
		return root, CFrame.new(0, -2.6 * scale, 0)
	end
	return find("UpperTorso", "Torso", "HumanoidRootPart"), CFrame.identity
end

-- opts.lite (other players' auras and companions): half the particles, no white cores or shards, no light,
-- so a full server stays smooth on phones.
function AuraFX.attach(model, spec, opts)
	local lite = opts and opts.lite == true
	local scale = spec.scale or 1
	local made = {}
	local emitters = {}
	local function keep(inst)
		table.insert(made, inst)
		return inst
	end

	for _, e in spec.emitters do
		local skip = lite and (string.sub(e.name, 1, 4) == "Core" or string.sub(e.name, 1, 5) == "Shard")
		local part, offset = anchor(model, e.at, scale)
		if part and not skip then
			local att = keep(Instance.new("Attachment"))
			att.Name = "HuzzAura" .. e.name
			att.CFrame = offset
			att.Parent = part
			local p = Instance.new("ParticleEmitter")
			p.Name = e.name
			p.Texture = texture(e.texture)
			p.Color = colorSeq(e.colors)
			p.LightEmission = e.light
			p.LightInfluence = if e.light > 0.5 then 0 else 1
			p.Rate = e.rate * (if lite then 0.5 else 1)
			p.Lifetime = NumberRange.new(e.life[1], e.life[2])
			p.Speed = NumberRange.new(e.speed[1] * scale, e.speed[2] * scale)
			p.SpreadAngle = Vector2.new(e.spread, e.spread)
			p.Size = numberSeq(e.size, scale)
			p.Transparency = numberSeq(e.alpha)
			p.Acceleration = Vector3.new(e.accel[1], e.accel[2], e.accel[3]) * scale
			p.Drag = e.drag or 0
			p.Rotation = NumberRange.new(e.rot[1], e.rot[2])
			p.RotSpeed = NumberRange.new(e.spin[1], e.spin[2])
			p.ZOffset = (e.z or 0) * scale
			p.Parent = att
			table.insert(emitters, p)
		end
	end

	local body = anchor(model, "Body", scale)
	local light = nil
	if spec.light and body and not lite then
		light = keep(Instance.new("PointLight"))
		light.Name = "HuzzAuraLight"
		light.Color = spec.light.color
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range * scale
		light.Shadows = false
		light.Parent = body
	end

	-- Crescent slashes: a small pool, reused. Each is two halves (start-middle, middle-end) so it's thick in the
	-- middle and sharp at both ends; each half is a bright core drawn over a wider dark edge.
	local slashes, clock, spawnAt, seed = {}, 0, 0, math.random(1, 100000)
	local S = spec.slashes
	if S and body then
		local count = math.ceil(S.rate * (if lite then 0.5 else 1) * S.life) + 2
		for i = 1, count do
			local atts = {}
			for j, tag in { "A", "M", "B" } do
				local a = keep(Instance.new("Attachment"))
				a.Name = "HuzzSlash" .. i .. tag
				a.Parent = body
				atts[j] = a
			end
			local beams = {}
			for half = 1, 2 do
				for _, layer in { { "Edge", S.edge, 0, 1.7, 0 }, { "Core", S.core, 0.6, 1, 0.05 } } do
					local b = keep(Instance.new("Beam"))
					b.Name = "HuzzSlash" .. layer[1] .. half
					b.Attachment0, b.Attachment1 = atts[half], atts[half + 1]
					b.Color = ColorSequence.new(layer[2])
					b.LightEmission = layer[3]
					b.LightInfluence = if layer[3] > 0 then 0 else 1
					b.ZOffset = layer[5] -- (the core always on top of its dark edge)
					b.FaceCamera = true
					b.Segments = 12
					b.Enabled = false
					b.Parent = body
					table.insert(beams, { beam = b, widthMult = layer[4], half = half, edge = layer[1] == "Edge" })
				end
			end
			slashes[i] = { atts = atts, beams = beams, born = -1, seed = 0 }
		end
	end
	local rate = if S then S.rate * (if lite then 0.5 else 1) else 0

	local function frame(pos, tangent)
		local side = tangent:Cross(Vector3.new(0, 1, 0))
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.new(1, 0, 0)
		return CFrame.fromMatrix(pos, tangent, side:Cross(tangent))
	end

	local handle = { enabled = true }
	function handle.step(dt)
		if not (S and body and body.Parent and handle.enabled) then
			return
		end
		clock += dt
		if clock >= spawnAt then
			spawnAt = clock + (0.6 + math.random() * 0.8) / rate
			for _, s in slashes do
				if s.born < 0 then
					seed += 1
					s.born, s.seed = clock, seed
					break
				end
			end
		end
		for _, s in slashes do
			if s.born >= 0 then
				local age = clock - s.born
				if age > S.life then
					s.born = -1
					for _, b in s.beams do
						b.beam.Enabled = false
					end
				else
					local p0, pm, p1, t0, tm, t1, curve, alpha, width =
						AuraLook.slash(S, s.seed, age, body.CFrame.Position, scale)
					s.atts[1].WorldCFrame = frame(p0, t0)
					s.atts[2].WorldCFrame = frame(pm, tm)
					s.atts[3].WorldCFrame = frame(p1, t1)
					for _, b in s.beams do
						local beam = b.beam
						beam.CurveSize0, beam.CurveSize1 = curve, curve
						local w = width * b.widthMult
						-- sharp at the outer ends, thick where the halves meet
						beam.Width0 = if b.half == 1 then 0 else w
						beam.Width1 = if b.half == 1 then w else 0
						local a = math.clamp(alpha + (if b.edge then 0.15 else 0), 0, 1)
						beam.Transparency = NumberSequence.new(a)
						beam.Enabled = true
					end
				end
			end
		end
	end
	function handle.setEnabled(on)
		if handle.enabled == on then
			return
		end
		handle.enabled = on
		for _, p in emitters do
			p.Enabled = on
		end
		if light then
			light.Enabled = on
		end
		if not on then
			for _, s in slashes do
				s.born = -1
				for _, b in s.beams do
					b.beam.Enabled = false
				end
			end
		end
	end
	function handle.destroy()
		for _, inst in made do
			inst:Destroy()
		end
		table.clear(made)
		table.clear(slashes)
		S = nil
	end
	return handle
end

return AuraFX
