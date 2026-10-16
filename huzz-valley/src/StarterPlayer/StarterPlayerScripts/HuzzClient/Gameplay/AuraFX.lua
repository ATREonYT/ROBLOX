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

function AuraFX.attach(model, spec)
	local scale = spec.scale or 1
	local made = {}
	local emitters = {}
	local function keep(inst)
		table.insert(made, inst)
		return inst
	end

	for _, e in spec.emitters do
		local part, offset = anchor(model, e.at, scale)
		if part then
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
			p.Rate = e.rate
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
	if spec.light and body then
		local light = keep(Instance.new("PointLight"))
		light.Name = "HuzzAuraLight"
		light.Color = spec.light.color
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range * scale
		light.Shadows = false
		light.Parent = body
	end

	-- Crescent slashes: a small pool, reused.
	local slashes, clock, spawnAt, seed = {}, 0, 0, math.random(1, 100000)
	local S = spec.slashes
	if S and body then
		for i = 1, math.ceil(S.rate * S.life) + 2 do
			local a0 = keep(Instance.new("Attachment"))
			a0.Name = "HuzzSlash" .. i .. "A"
			a0.Parent = body
			local a1 = keep(Instance.new("Attachment"))
			a1.Name = "HuzzSlash" .. i .. "B"
			a1.Parent = body
			local beams = {}
			for _, layer in { { "Edge", S.edge, 0, 1.9 }, { "Core", S.core, 1, 1 } } do
				local b = keep(Instance.new("Beam"))
				b.Name = "HuzzSlash" .. layer[1]
				b.Attachment0, b.Attachment1 = a0, a1
				b.Color = ColorSequence.new(layer[2])
				b.LightEmission = layer[3]
				b.LightInfluence = 1 - layer[3]
				b.FaceCamera = true
				b.Segments = 18
				b.Width0 = 0
				b.Enabled = false
				b.Parent = body
				beams[layer[1]] = { beam = b, widthMult = layer[4] }
			end
			slashes[i] = { a0 = a0, a1 = a1, beams = beams, born = -1, seed = 0 }
		end
	end

	local handle = { enabled = true }
	function handle.step(dt)
		if not (S and body and body.Parent and handle.enabled) then
			return
		end
		clock += dt
		if clock >= spawnAt then
			spawnAt = clock + (0.6 + math.random() * 0.8) / S.rate
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
					local p0, p1, t0, t1, curve, alpha, width = AuraLook.slash(S, s.seed, age, body.CFrame.Position, scale)
					local function frame(pos, tangent)
						local side = tangent:Cross(Vector3.new(0, 1, 0))
						side = if side.Magnitude > 0.01 then side.Unit else Vector3.new(1, 0, 0)
						return CFrame.fromMatrix(pos, tangent, side:Cross(tangent))
					end
					s.a0.WorldCFrame = frame(p0, t0)
					s.a1.WorldCFrame = frame(p1, t1)
					for name, b in s.beams do
						local beam = b.beam
						beam.CurveSize0, beam.CurveSize1 = curve, curve
						beam.Width1 = width * b.widthMult
						-- the tail fades out; the edge sits a little fainter than the core
						local a = math.clamp(alpha + (if name == "Edge" then 0.15 else 0), 0, 1)
						beam.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, math.min(1, a + 0.35)), NumberSequenceKeypoint.new(1, a),
						})
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
