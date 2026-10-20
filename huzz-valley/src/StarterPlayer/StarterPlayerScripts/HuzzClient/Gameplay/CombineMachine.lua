--[[
	The owner's Combine machine, alive on this screen (owner, Oct 20 14:57: "can you please anime this combine
	machine ... make nice animations with vfx, gfx, sfx, and make a nice merging animation. Keep it smooth and tidy.
	and not too long"; 14:58: "also give the effects around the machine animations").
	His model (Workspace > Combine > Combine_Machine, tag HuzzCombine: HuzzServer/CombineService) is moved here only
	on this screen, part by part, from where his parts stand (nothing of his is rebuilt; the server never moves them):
	  Idle (Config/Combine.Idle), while the camera is near:
	    * his summon ring: the ticks and gems turn one way, the arcs and dots the other, slowly
	    * the fusion blade in the ring and the soul orb over the lotus float up and down, the blade sways
	    * the floor ring's ticks turn round the altar; his spirit flames drift
	    * his glowing trim breathes (SurfaceAppearance EmissiveStrength, where Roblox lets a script set it)
	    * one soft light over the altar, soft motes rising round it, a few sparkles in the ring (Roblox's own
	      particle pictures only)
	  The merge (Shared/CombineMotion: the timeline, about 4 s, one burst): two copies of the girl rise from his pads,
	  circle each other in front of the ring while it spins up and the trim brightens and motes are pulled in, ONE
	  burst (a ring of light and sparkles in the new grade's colour; Gameplay/Burst.flashOk keeps it to one a
	  second), and she rises in her new grade (Shared/GirlGrade) and sinks into the altar. Sounds: Config/Combine.Sounds.
	  Yours (play / answer / skip, from UI/Screens/Combine) also takes the camera in front of the machine and holds
	  your controls; it waits at the burst for the server's answer (the save is stored first) and plays on, or the
	  copies go back down if it said no. Everyone else's merges (the Combine remote) play on the machine too, without
	  the camera.
	His parts are found by name (the number at the end dropped) and looked for again when the model streams in.
]]
local M = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Combine)
local CombineMotion = require(Shared.CombineMotion)
local GirlGrade = require(Shared.GirlGrade)
local Net = require(Shared.Net)
local Sfx = require(script.Parent.Sfx)
local Burst = require(script.Parent.Burst)

local player = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local UP = Vector3.new(0, 1, 0)

-- his parts: name without the number -> group
local RING_A = { glow_summon_tick = true, glow_summon_gem = true, glow_summon_ring = true }
local RING_B = { glow_summon_arc = true, glow_summon_dot = true }
local BLADE = { glow_fusion_blade = true, fusion_tsuba = true, fusion_grip = true }
local ORB = { glow_soul_orb = true }
local FLOOR = { glow_floor_tick = true, glow_floor_ring = true }

local function baseName(name: string): string
	return (string.gsub(name, "_%d+$", ""))
end

local machine: Model? = nil
local rig = nil -- what this screen moves: built from his parts (see collect)
local fx = nil -- our own effect parts (this screen only)
local play = nil -- the merge playing now

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Every part of his we move, with where it stands relative to his base tier (so a move of the whole model still
-- lands right), and the glowing trim's SurfaceAppearances with their own strength.
local function collect(model: Model)
	local parts = {}
	local byBase = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local b = baseName(d.Name)
			byBase[b] = byBase[b] or {}
			table.insert(byBase[b], d)
			table.insert(parts, d)
		end
	end
	local ref = byBase.shrine_tier and byBase.shrine_tier[1]
	local ring = nil
	for _, p in byBase.glow_summon_ring or {} do
		if not ring or p.Size.X > ring.Size.X then ring = p end
	end
	local altar = byBase.altar_base and byBase.altar_base[1]
	local padA = byBase.pad_cap and byBase.pad_cap[1]
	local padB = byBase.pad_cap and byBase.pad_cap[2]
	if not (ref and ring and altar and padA and padB) then return nil end
	local r = {
		model = model, ref = ref, ring = ring, altar = altar, padA = padA, padB = padB, count = #parts,
		moves = {}, -- { part, rel (to ref), kind, extra }
		glow = {}, -- { sa, base }
		blade = {},
	}
	local refCF = ref.CFrame
	local function add(p: BasePart, kind: string, extra: any?)
		table.insert(r.moves, { part = p, rel = refCF:ToObjectSpace(p.CFrame), kind = kind, extra = extra })
	end
	for b, list in byBase do
		for _, p in list do
			if RING_A[b] then add(p, "ringA")
			elseif RING_B[b] then add(p, "ringB")
			elseif BLADE[b] then add(p, "blade"); table.insert(r.blade, p)
			elseif ORB[b] then add(p, "orb")
			elseif FLOOR[b] then add(p, "floor")
			elseif string.find(b, "^glow_spirit") then
				-- each flame (its flame, wisp and tail are one model) drifts on its own
				local holder = p.Parent
				add(p, "wisp", (holder and holder.Name or p.Name))
			end
			if string.sub(b, 1, 5) == "glow_" then
				for _, c in p:GetChildren() do
					if c:IsA("SurfaceAppearance") then
						local ok, base = pcall(function() return (c :: any).EmissiveStrength end)
						if ok and type(base) == "number" then table.insert(r.glow, { sa = c, base = base }) end
					end
				end
			end
		end
	end
	return r
end

-- The machine's frame in world space now (CombineMotion's `frame`).
local function frameOf(r)
	local front = r.ring.CFrame.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	-- (the side his stairs and pads are on: his pads sit in front of the ring)
	local padMid = (r.padA.CFrame.Position + r.padB.CFrame.Position) / 2
	local toPads = Vector3.new(padMid.X - r.ring.CFrame.Position.X, 0, padMid.Z - r.ring.CFrame.Position.Z)
	if front.Magnitude < 0.1 then front = toPads end
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(0, 0, 1)
	if toPads.Magnitude > 0.1 and front:Dot(toPads) < 0 then front = -front end
	return {
		ring = r.ring.CFrame.Position, front = front,
		padA = r.padA.CFrame.Position + UP * (r.padA.Size.Y / 2), padB = r.padB.CFrame.Position + UP * (r.padB.Size.Y / 2),
		altar = r.altar.CFrame.Position + UP * (r.altar.Size.Y / 2 + 0.6), height = Config.Merge.Height,
	}
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

local function fxPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Our effects round his machine (this screen only).
local function buildFx(r)
	local folder = Instance.new("Folder")
	folder.Name = "HuzzCombineFx"
	local I = Config.Idle
	local f = frameOf(r)
	local centre = CombineMotion.centre(f)
	local top = r.altar.CFrame.Position + UP * (r.altar.Size.Y / 2)
	local base = fxPart("Altar", Vector3.new(12, 0.2, 12), CFrame.new(top), folder)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = I.Light.Color, I.Light.Brightness, I.Light.Range, false
	light.Parent = base
	local motes = emitter(base, {
		Name = "Motes", Texture = SMOKE, Rate = I.Motes.Rate, Lifetime = NumberRange.new(I.Motes.Life * 0.8, I.Motes.Life),
		Speed = NumberRange.new(0.5, 1.1), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 0.25, 0), Drag = 0.3, Color = ColorSequence.new(I.Motes.Color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, I.Motes.Size), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local ringBox = fxPart("Ring", Vector3.new(5.6, 5.6, 0.6), r.ring.CFrame, folder)
	local sparkles = emitter(ringBox, {
		Name = "Sparkles", Texture = SPARKLE, Rate = I.Sparkles.Rate, Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), Color = ColorSequence.new(I.Sparkles.Color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, I.Sparkles.Size), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 0.5, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- the charge: motes pulled in to the middle (only while a merge charges)
	local pull = fxPart("Pull", Vector3.new(9, 9, 9), CFrame.new(centre), folder)
	pull.Shape = Enum.PartType.Ball
	local inward = emitter(pull, {
		Name = "Inward", Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(6, 8),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Color = ColorSequence.new(I.Motes.Color), LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 0.6) }),
	})
	-- the burst: one soft glowing ball (white core look: Neon in the grade's colour) and its light
	local ball = fxPart("Burst", Vector3.new(1, 1, 1), CFrame.new(centre), folder)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	local flashLight = Instance.new("PointLight")
	flashLight.Brightness, flashLight.Range, flashLight.Shadows = 0, 18, false
	flashLight.Parent = ball
	folder.Parent = Workspace
	return { folder = folder, base = base, light = light, motes = motes, ringBox = ringBox, sparkles = sparkles, pull = pull, inward = inward, ball = ball, flashLight = flashLight }
end

local function clearFx()
	if fx then fx.folder:Destroy() end
	fx = nil
end

-- Her body (no hats or hair): its lowest point and height, for standing her on a spot at a size.
local function body(model: Model): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and not d:FindFirstAncestorWhichIsA("Accoutrement") and d.Name ~= "HumanoidRootPart" then
			local p, h = d.CFrame.Position, d.Size.Y / 2
			lo, hi = math.min(lo, p.Y - h), math.max(hi, p.Y + h)
		end
	end
	if lo == math.huge then
		local cf, size = model:GetBoundingBox()
		return cf.Position.Y - size.Y / 2, size.Y
	end
	return lo, hi - lo
end

-- A still copy of her for the machine, `height` tall, in her grade. Returns { model, lift (pivot over her feet) }.
local function copyOf(key: string, grade: string?, height: number, withFx: boolean)
	local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
	local source = girls and girls:FindFirstChild(key)
	if not (source and source:IsA("Model")) then return nil end
	local model = source:Clone()
	model.Name = "CombineGirl"
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root and root:IsA("BasePart") then model.PrimaryPart = root end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			pcall(function() d.EvaluateStateMachine = false end)
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local _, h = body(model)
	pcall(function() model:ScaleTo(model:GetScale() * height / math.max(h, 0.5)) end)
	local bottom = body(model)
	local lift = model:GetPivot().Position.Y - bottom
	local handle = GirlGrade.apply(model, grade, { fx = withFx })
	return { model = model, lift = lift, fx = handle }
end

local function place(c, cf: CFrame?)
	if not c then return end
	if cf then
		c.model:PivotTo(cf * CFrame.new(0, c.lift, 0))
		if c.model.Parent ~= fx.folder then c.model.Parent = fx.folder end
	elseif c.model.Parent then
		c.model.Parent = nil
	end
end

local function cleanupPlay(p)
	for _, c in { p.a, p.b, p.result } do
		if c then c.model:Destroy() end
	end
	for _, part in rig and rig.blade or {} do part.LocalTransparencyModifier = 0 end
end

-- The camera and your controls during your own merge.
local controls = nil
local glide: RBXScriptConnection? = nil -- (the camera gliding back after your merge)
local function setControls(on: boolean)
	pcall(function()
		if not controls then
			local scripts = player:WaitForChild("PlayerScripts", 5)
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			controls = module and (require :: any)(module):GetControls()
		end
		if controls then
			if on then controls:Enable() else controls:Disable() end
		end
	end)
end

local function finish(p, skipped: boolean)
	if play ~= p then return end
	play = nil
	if skipped and p.answered and p.ok and not p.burstDone and p.onReveal then task.spawn(p.onReveal) end
	local fr = rig and frameOf(rig)
	if p.result and p.result.model.Parent and fr and not skipped then
		Burst.sparks(fr.altar, { Config.Grades[p.to] and Config.Grades[p.to].Badge or Burst.PINK, Color3.new(1, 1, 1) }, 14,
			{ speed = NumberRange.new(2, 5), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.4, 0.7) })
	end
	cleanupPlay(p)
	if fx then
		fx.inward.Rate = 0
		fx.ball.Transparency = 1
		fx.flashLight.Brightness = 0
	end
	if p.mine then
		local camera = Workspace.CurrentCamera
		local from = camera.CFrame
		local back = p.startCF
		local t0 = os.clock()
		-- glide back to where your camera was, then hand it back to Roblox
		if glide then glide:Disconnect() end
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = smooth((os.clock() - t0) / 0.45)
			camera.CFrame = from:Lerp(back, k)
			if k >= 1 then
				conn:Disconnect()
				glide = nil
				camera.CameraType = Enum.CameraType.Custom
				player:SetAttribute("HuzzCinematic", false)
				player:SetAttribute("HuzzCombining", false)
				setControls(true)
			end
		end)
		glide = conn
	end
	if p.onDone then task.spawn(p.onDone, skipped) end
end

-- Starts a merge on the machine. o = { key (her model in HuzzGirls), from, to (grades), mine (your own: the camera
-- and the wait for the answer), startAt (os.clock() it began, for others' merges joining late), onReveal() (at the
-- burst), onDone(skipped) }.
-- Returns false when the machine isn't here.
function M.play(o): boolean
	if not (rig and fx) then return false end
	if play then
		if not o.mine then return false end -- (someone else's merge never cuts yours)
		finish(play, true)
	end
	local H = Config.Merge.Height
	local inputFx = (Config.Grades[o.from] and Config.Grades[o.from].Fx) ~= nil
	local p = {
		key = o.key, from = o.from, to = o.to, mine = o.mine == true, t0 = o.startAt or os.clock(), hold = 0, spin = 0,
		answered = not o.mine, ok = true, cue = 1, onDone = o.onDone, onReveal = o.onReveal,
		a = copyOf(o.key, o.from, H, inputFx), b = copyOf(o.key, o.from, H, inputFx), result = copyOf(o.key, o.to, H, true),
	}
	if not (p.a and p.b and p.result) then
		cleanupPlay(p)
		return false
	end
	-- (a merge already under way when we came near: its sounds that are past stay unplayed)
	while CombineMotion.CUES[p.cue] and CombineMotion.CUES[p.cue].at < os.clock() - p.t0 - 0.2 do p.cue += 1 end
	local col = Config.Grades[o.to] and Config.Grades[o.to].Badge or Burst.PINK
	fx.ball.Color = col
	fx.flashLight.Color = col
	fx.inward.Color = ColorSequence.new(Config.Idle.Motes.Color, col)
	if p.mine then
		local camera = Workspace.CurrentCamera
		if glide then glide:Disconnect(); glide = nil end -- (a new merge while the last one's camera glides back)
		p.startCF = camera.CFrame
		player:SetAttribute("HuzzCinematic", true) -- (prompts and shift lock let go; the round HUD stays out of the shot)
		player:SetAttribute("HuzzCombining", true)
		camera.CameraType = Enum.CameraType.Scriptable
		setControls(false)
	end
	play = p
	return true
end

-- The server's answer to your merge: ok, or no (the copies go back down and it ends).
function M.answer(ok: boolean)
	local p = play
	if not (p and p.mine) then return end
	p.answered, p.ok = true, ok
end

-- Tap to skip: straight to the end.
function M.skip()
	local p = play
	if p and p.answered then finish(p, true) end
end

function M.playing(): boolean
	return play ~= nil
end

-- One frame of the machine: idle loop plus the merge.
local angle = { a = 0, b = 0, floor = 0 }
local function step(dt: number)
	local r = rig
	if not r then return end
	local now = os.clock()
	local I = Config.Idle
	local p = play
	local state = nil
	local t = 0
	if p then
		t = now - p.t0 - p.hold
		if not p.answered and t > CombineMotion.MERGE_AT - 0.05 then -- (waiting for the save: keep charging)
			p.hold += t - (CombineMotion.MERGE_AT - 0.05)
			t = CombineMotion.MERGE_AT - 0.05
			p.spin += dt * 9
		end
		if p.answered and not p.ok then
			-- no: the two drift back down to the pads and it ends
			p.failAt = p.failAt or now
			if now - p.failAt > 0.5 then finish(p, true) return end
		end
		if t >= CombineMotion.LENGTH then finish(p, false) return end
		state = CombineMotion.at(t, frameOf(r))
		-- sounds on their beats (your own merge heard flat, others' from the machine)
		local cue = CombineMotion.CUES[p.cue]
		while cue and t >= cue.at and p.ok do
			local name = Config.Sounds[cue.sound]
			if name then pcall(Sfx.play, name, if p.mine then nil else { at = r.ring }) end
			p.cue += 1
			cue = CombineMotion.CUES[p.cue]
		end
	end
	local ringMul = state and state.ring or 1
	local glow = state and state.glow or 0
	angle.a += dt * (2 * math.pi / I.RingSpin) * ringMul
	angle.b -= dt * (2 * math.pi / I.ArcSpin) * ringMul
	angle.floor += dt * (2 * math.pi / I.FloorSpin) * (1 + (ringMul - 1) * 0.4)
	local refCF = r.ref.CFrame
	local ringCF = refCF * r.ringRel
	local axis = ringCF.LookVector
	local centreRing = ringCF.Position
	local altarPos = (refCF * r.altarRel).Position
	local bob = math.sin(now * 2 * math.pi / I.Bob.Period) * I.Bob.Height
	local parts, cfs = {}, {}
	for _, mv in r.moves do
		local home = refCF * mv.rel
		local cf = home
		if mv.kind == "ringA" or mv.kind == "ringB" then
			local rot = CFrame.fromAxisAngle(axis, if mv.kind == "ringA" then angle.a else angle.b)
			cf = CFrame.new(centreRing) * rot * CFrame.new(-centreRing) * home
		elseif mv.kind == "floor" then
			local rot = CFrame.fromAxisAngle(UP, angle.floor)
			cf = CFrame.new(altarPos) * rot * CFrame.new(-altarPos) * home
		elseif mv.kind == "blade" then
			local sway = math.sin(now * 0.9) * math.rad(14)
			local pivot = (refCF * r.bladeRel).Position
			cf = CFrame.new(pivot + UP * bob) * CFrame.fromAxisAngle(UP, sway) * CFrame.new(-pivot) * home
		elseif mv.kind == "orb" then
			cf = (home + UP * (bob * 0.7)) * CFrame.Angles(0, now * 0.6, 0)
		elseif mv.kind == "wisp" then
			local seed = (#mv.extra * 7.3 + string.byte(mv.extra, -1) * 1.7) % 6.283
			local w = 2 * math.pi / I.Wisps.Period
			local D = I.Wisps.Drift
			cf = home + Vector3.new(math.sin(now * w + seed) * D, math.sin(now * w * 1.3 + seed * 2) * D * 0.8, math.cos(now * w * 0.8 + seed) * D)
		end
		table.insert(parts, mv.part)
		table.insert(cfs, cf)
	end
	local ok = pcall(function() Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end)
	if not ok then
		for i, part in parts do part.CFrame = cfs[i] end
	end
	-- his glowing trim breathes (and brightens while charging)
	if r.glowOk ~= false then
		local breathe = 1 + I.Glow.Pulse * math.sin(now * 2 * math.pi / I.Glow.Period)
		local mul = breathe * (1 + (Config.Merge.ChargeGlow - 1) * glow)
		for _, g in r.glow do
			local okSet = pcall(function() (g.sa :: any).EmissiveStrength = g.base * mul end)
			if not okSet then r.glowOk = false break end
		end
	end
	-- our effects
	if fx then
		local f = frameOf(r)
		local centre = CombineMotion.centre(f)
		fx.light.Brightness = I.Light.Brightness * (1 + 0.15 * math.sin(now * 2 * math.pi / I.Glow.Period) + 1.2 * glow)
		fx.sparkles.Rate = I.Sparkles.Rate * (1 + 3 * glow)
		fx.inward.Rate = if state and state.inward then 40 else 0
		fx.pull.CFrame = CFrame.new(centre)
		fx.ball.CFrame = CFrame.new(centre)
		if state and state.burst then
			fx.ball.Size = Vector3.one * state.burst.size
			fx.ball.Transparency = state.burst.transparency
			fx.flashLight.Brightness = 6 * state.flash
		else
			fx.ball.Transparency = 1
			fx.flashLight.Brightness = 0
		end
		-- the burst's one-off part, once it is due (even when a slow frame skipped past the burst itself)
		if p and p.ok and not p.burstDone and t >= CombineMotion.MERGE_AT then
			p.burstDone = true
			if p.onReveal then task.spawn(p.onReveal) end
			local col = Config.Grades[p.to] and Config.Grades[p.to].Badge or Burst.PINK
			-- one ring of light out through his ring, and sparkles (one flash a second at most on this screen)
			if Burst.flashOk() then
				pcall(Burst.ring, CFrame.lookAt(centre, centre + f.front) * CFrame.Angles(math.pi / 2, 0, 0),
					{ r0 = 0.6, r1 = 5, time = 0.55, ease = "quart", width = 0.16, glow = 0.6, color = col })
			end
			Burst.sparks(centre, { col, Color3.new(1, 1, 1) }, 36, { speed = NumberRange.new(7, 12), gravity = Vector3.new(0, -4, 0), drag = 4, life = NumberRange.new(0.5, 0.9) })
		end
	end
	-- the girls and the camera
	if p and state then
		local function spun(cf: CFrame?): CFrame?
			if not cf or p.spin == 0 then return cf end
			local c = CombineMotion.centre(frameOf(r))
			return CFrame.new(c) * CFrame.Angles(0, p.spin, 0) * CFrame.new(-c) * cf * CFrame.Angles(0, p.spin, 0)
		end
		if p.answered and not p.ok then
			-- back down to the pads, then gone
			local f = frameOf(r)
			local k = smooth((now - (p.failAt or now)) / 0.5)
			place(p.a, state.a.cf and state.a.cf:Lerp(CFrame.new(f.padA), k))
			place(p.b, state.b.cf and state.b.cf:Lerp(CFrame.new(f.padB), k))
			place(p.result, nil)
		else
			place(p.a, if state.a.show then spun(state.a.cf) else nil)
			place(p.b, if state.b.show then spun(state.b.cf) else nil)
			place(p.result, if state.result.show then state.result.cf else nil)
		end
		for _, part in r.blade do part.LocalTransparencyModifier = if t > 0.9 and t < CombineMotion.HOLD_END then 1 else 0 end
		if t < 0.05 and not p.puffed then
			p.puffed = true
			local f = frameOf(r)
			local col = Config.Grades[p.from] and Config.Grades[p.from].Badge or Burst.PINK
			Burst.sparks(f.padA + UP * 1.2, { col, Burst.PINK }, 10, { speed = NumberRange.new(2, 4), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.3, 0.6) })
			Burst.sparks(f.padB + UP * 1.2, { col, Burst.PINK }, 10, { speed = NumberRange.new(2, 4), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.3, 0.6) })
		end
		if p.mine then
			local camera = Workspace.CurrentCamera
			local plan = CFrame.lookAt(state.camera.eye, state.camera.look)
			local k = smooth((now - p.t0) / 0.5) -- (eases in from your own camera)
			camera.CFrame = if k < 1 then p.startCF:Lerp(plan, k) else plan
		end
	end
end

local function near(r): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - r.ring.CFrame.Position).Magnitude < Config.Idle.Near
end

-- His machine on this screen: the tagged model (looked for again until found, and again if it goes or streams).
local function findMachine(): Model?
	local ok, tagged = pcall(function() return CollectionService:GetTagged(Config.Tag) end)
	for _, m in (if ok then tagged else {}) do
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then return m end
	end
	-- (the tag streams in with it; by name too)
	local holder = Workspace:FindFirstChild(Config.Folder)
	local m = holder and holder:FindFirstChild(Config.Model)
	return if m and m:IsA("Model") then m else nil
end

function M.start()
	local lastLook = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now - lastLook > 1 then
			lastLook = now
			local m = findMachine()
			local count = 0
			if m then
				for _, d in m:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
			end
			-- (a new model, or more of it arrived: collect again from where his parts stand now)
			if m ~= machine or (rig and count ~= rig.count) or (m and not rig) then
				if play then finish(play, true) end -- (its copies live in our effects folder, rebuilt below)
				machine = m
				clearFx()
				rig = nil
				if m and not play then
					local r = collect(m)
					if r then
						local refCF = r.ref.CFrame
						r.ringRel = refCF:ToObjectSpace(r.ring.CFrame)
						r.altarRel = refCF:ToObjectSpace(r.altar.CFrame)
						local bladeAt = r.blade[1] and r.blade[1].CFrame or r.ring.CFrame
						r.bladeRel = refCF:ToObjectSpace(bladeAt)
						rig = r
						fx = buildFx(r)
					end
				end
			end
		end
		if rig and (play or near(rig)) then
			local ok, err = pcall(step, dt)
			if not ok then
				warn("[Huzz] combine machine: " .. tostring(err))
				if play then finish(play, true) end
			end
		end
		if fx then
			local on = rig ~= nil and (play ~= nil or near(rig))
			if fx.folder.Parent ~= (if on then Workspace else nil) then fx.folder.Parent = if on then Workspace else nil end
		end
	end)
	-- everyone else's merges, on the machine
	local remote = Net.get("Combine") :: RemoteEvent
	remote.OnClientEvent:Connect(function(userId, key, from, to, startAt)
		if userId == player.UserId or type(key) ~= "string" then return end
		if not (rig and near(rig)) then return end
		local ago = 0
		pcall(function() ago = Workspace:GetServerTimeNow() - (tonumber(startAt) or 0) end)
		if ago > CombineMotion.HOLD_END then return end
		M.play({ key = key, from = from, to = to, mine = false, startAt = os.clock() - math.max(ago, 0) })
	end)
end

return M
