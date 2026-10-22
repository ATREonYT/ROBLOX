--[[
	Pictures of your avatar frozen mid-dance, for the Dances cards and the dance wheel's slots.
	A still copy of your character is put in the dance's most telling pose (Config/DancePoses, the second picked by
	tools/preview/motion3d/dance_poses.luau), read straight from the dance's KeyframeSequence (Shared/KeyframeSampler):
	no Animator and nothing that moves, so a screen full of them costs nothing per frame (the old cards each ran a
	live animation, which lagged). Every part is placed once by hand from its joints, so accessories follow.
	  DancePose.anim(id)        the dance, sampled (nil while loading or if it can't be read). In Studio straight
	                            from ReplicatedStorage.HuzzAnimations; live, from its published ID.
	  DancePose.picture(parent, id, props, dark?, onFail?) -> ViewportFrame
	                            props = ViewportFrame properties (Position, Size, ...); dark = a locked silhouette;
	                            fills in when the dance has loaded, or calls onFail (show the note instead).
	  DancePose.live(parent, id, props, onReady?) -> { setOn(on) }
	                            your avatar actually dancing it, looping (owner, Oct 21: "make it your character
	                            dancing the dance", the Shop's dance cards). The parts are placed by hand from the
	                            dance's KeyframeSequence, FPS (30) times a second, and only while setOn(true) (the Shop
	                            turns on the cards in view while it's open). onReady() once it shows. In the live
	                            game a dance with no published ID asks the server for its moves (ActionService
	                            "SeeDance", which shares them in HuzzDanceMoves) and starts when they arrive.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local DancePoses = require(Shared.Config.DancePoses)
local Sampler = require(Shared.KeyframeSampler)

local DancePose = {}

local anims = {} -- dance id -> sampled anim, false (can't be read) or "loading"
local waiting: { [string]: { (boolean) -> () } } = {}

local function settle(id: string, value)
	anims[id] = value
	local list = waiting[id]
	waiting[id] = nil
	for _, fn in list or {} do task.spawn(fn, value ~= false) end
end

function DancePose.anim(id: string)
	local a = anims[id]
	if a ~= nil then
		return if type(a) == "table" then a else nil
	end
	local folder = ReplicatedStorage:FindFirstChild("HuzzAnimations")
	local seq = folder and folder:FindFirstChild("Dance_" .. id)
	if not seq then -- (live, not published: the moves the server shares once someone dances it, HuzzDanceMoves)
		local shared = ReplicatedStorage:FindFirstChild("HuzzDanceMoves")
		seq = shared and shared:FindFirstChild("Dance_" .. id)
	end
	if seq and seq:IsA("KeyframeSequence") then
		local ok, loaded = pcall(Sampler.load, seq)
		anims[id] = if ok and loaded and loaded.length > 0 then loaded else false
		return anims[id] or nil
	end
	local d = Dances.get(id)
	local published = if d then require(Shared.AnimationLibrary).published("Dance_" .. id, d.AnimationId) else ""
	if published == "" then
		return nil -- (not kept: its moves may arrive later; the white stand-in figure shows meanwhile)
	end
	anims[id] = "loading"
	task.spawn(function()
		local ok, got = pcall(function()
			return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(published)
		end)
		local loaded = nil
		if ok and got then
			local ok2, l = pcall(Sampler.load, got)
			loaded = ok2 and l or nil
		end
		settle(id, if loaded and loaded.length > 0 then loaded else false)
	end)
	return nil
end

-- Calls fn(true) once the dance is readable, fn(false) if it never will be.
local function whenLoaded(id: string, fn: (boolean) -> ())
	if DancePose.anim(id) then
		fn(true)
	elseif anims[id] == "loading" then
		waiting[id] = waiting[id] or {}
		table.insert(waiting[id], fn)
	else
		fn(false)
	end
end

-- A still copy of the character, nothing that runs or glows, standing at the origin facing -Z.
local function stillCopy(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = was
	if not ok or not copy then return nil end
	for _, x in copy:GetDescendants() do
		if x:IsA("LuaSourceContainer") or x:IsA("BillboardGui") or x:IsA("ParticleEmitter") or x:IsA("Highlight")
			or x:IsA("Trail") or x:IsA("Beam") or x:IsA("Light") or x:IsA("Sound") or x:IsA("ForceField") then
			x:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return copy
end

-- A body's joints, once: rig(model) -> apply(posed), which places every part from the root through its joints with
-- the pose on the Motor6Ds (Transform = the pose). Every part ends up anchored; a part no joint reaches (held some
-- other way) keeps its place relative to the body.
local function rig(model: Model): ((posed: { [string]: CFrame }) -> ())?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	type Edge = { other: BasePart, place: (BasePart, { [string]: CFrame }) -> CFrame }
	local edges: { [BasePart]: { Edge } } = {}
	local function link(a: BasePart, b: BasePart, fromA, fromB)
		edges[a] = edges[a] or {}
		edges[b] = edges[b] or {}
		table.insert(edges[a], { other = b, place = fromA })
		table.insert(edges[b], { other = a, place = fromB })
	end
	local NONE = CFrame.new()
	for _, j in model:GetDescendants() do
		if j.ClassName == "AnimationConstraint" then
			-- avatars on Roblox's newer joints: like a Motor6D with its attachments as C0 / C1
			local a0, a1 = (j :: any).Attachment0, (j :: any).Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local c0, c1, key = a0.CFrame, a1.CFrame, p1.Name
				link(p0, p1, function(a, posed) return a.CFrame * c0 * (posed[key] or NONE) * c1:Inverse() end,
					function(b, posed) return b.CFrame * c1 * (posed[key] or NONE):Inverse() * c0:Inverse() end)
			end
		elseif j:IsA("JointInstance") and j.Part0 and j.Part1 then
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			local motor, key = j:IsA("Motor6D"), p1.Name
			local c0, c1 = j.C0, j.C1
			link(p0, p1, function(a, posed) return a.CFrame * c0 * (if motor then posed[key] or NONE else NONE) * c1:Inverse() end,
				function(b, posed) return b.CFrame * c1 * (if motor then posed[key] or NONE else NONE):Inverse() * c0:Inverse() end)
		elseif j:IsA("RigidConstraint") then
			-- accessories on Roblox's newer welds (hair, glasses, hats): held by their attachments (owner, Oct 22: the
			-- hair and glasses stayed put while the head danced away)
			local a0, a1 = (j :: any).Attachment0, (j :: any).Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local rel = a0.CFrame * a1.CFrame:Inverse()
				link(p0, p1, function(a) return a.CFrame * rel end, function(b) return b.CFrame * rel:Inverse() end)
			end
		elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 then
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			local rel = p0.CFrame:ToObjectSpace(p1.CFrame) -- (as built, before anything moves)
			link(p0, p1, function(a) return a.CFrame * rel end, function(b) return b.CFrame * rel:Inverse() end)
		end
	end
	-- the order parts are placed in (from the root out), worked out once
	local steps: { { part: BasePart, from: BasePart, place: any } } = {}
	local done = { [root] = true }
	local queue, i = { root }, 1
	while queue[i] do
		local part = queue[i]
		i += 1
		for _, e in edges[part] or {} do
			if not done[e.other] then
				done[e.other] = true
				table.insert(steps, { part = e.other, from = part, place = e.place })
				table.insert(queue, e.other)
			end
		end
	end
	-- A part no joint reaches (held some other way) follows the body part it belongs to, keeping its place on it: the
	-- one with an attachment of the same name (how Roblox hangs an accessory: HairAttachment on the Head), else the
	-- nearest one. Never left where it stood while the body dances (owner, Oct 22: "make the characters be normal").
	local bodyParts: { BasePart } = {}
	local byAttachment: { [string]: BasePart } = {}
	for part in done do
		table.insert(bodyParts, part)
		for _, a in part:GetChildren() do
			if a:IsA("Attachment") and not byAttachment[a.Name] then byAttachment[a.Name] = part end
		end
	end
	local function owner(p: BasePart): BasePart
		for _, a in p:GetChildren() do
			local on = a:IsA("Attachment") and byAttachment[a.Name]
			if on and on ~= p then return on end
		end
		local best, bestD = root, math.huge
		for _, b in bodyParts do
			local d = (b.CFrame.Position - p.CFrame.Position).Magnitude
			if d < bestD then best, bestD = b, d end
		end
		return best
	end
	local loose: { { part: BasePart, on: BasePart, at: CFrame } } = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if not done[p] then
				local on = owner(p)
				table.insert(loose, { part = p, on = on, at = on.CFrame:ToObjectSpace(p.CFrame) })
			end
			p.Anchored = true
		end
	end
	-- (the joints' places are kept above: take the joints out, so nothing drags a posed part along afterwards)
	for _, j in model:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("RigidConstraint") or j.ClassName == "AnimationConstraint" then
			pcall(function() j.Enabled = false end)
		end
	end
	return function(posed: { [string]: CFrame })
		root.CFrame = NONE
		for _, st in steps do
			st.part.CFrame = st.place(st.from, posed)
		end
		for _, l in loose do
			l.part.CFrame = l.on.CFrame * l.at
		end
	end
end
local function pose(model: Model, posed: { [string]: CFrame })
	local apply = rig(model)
	if apply then apply(posed) end
end

local templates: { [string]: { char: Model, model: Model } } = {}
-- (accessories that finish loading after the first pictures: draw them again with the full look)
local me = Players.LocalPlayer
if me then
	pcall(function() me.CharacterAppearanceLoaded:Connect(function() table.clear(templates) end) end)
end

-- Your character in this dance's pose (a template to clone), or nil.
local function posedModel(id: string): Model?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if not character then return nil end
	local t = templates[id]
	if t and t.char == character then return t.model end
	local anim = DancePose.anim(id)
	if not anim then return nil end
	local copy = stillCopy(character)
	if not copy then return nil end
	local at = math.min(DancePoses[id] or 0, math.max(anim.length - 0.01, 0))
	local ok = pcall(pose, copy, Sampler.sample(anim, at))
	if not ok then return nil end
	copy.Archivable = true
	templates[id] = { char = character, model = copy }
	return copy
end

-- Frames a body in a ViewportFrame: the whole body, a little from the side so the pose reads (room = extra space).
local function frame(vp: ViewportFrame, model: Model, room: number)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local cf, size = model:GetBoundingBox()
	local centre = cf.Position
	local fit = math.max(size.Y, size.X * 0.75)
	local dist = fit / (2 * math.tan(math.rad(cam.FieldOfView) / 2)) * room
	cam.CFrame = CFrame.lookAt(centre + Vector3.new(-0.22, 0.08, -1).Unit * dist, centre)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

function DancePose.picture(parent: Instance, id: string, props: { [string]: any }, dark: boolean?, onFail: (() -> ())?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Dancer"
	vp.BackgroundTransparency = 1
	vp:SetAttribute("RuntimeOnly", true)
	if dark then
		vp.Ambient, vp.LightColor, vp.ImageColor3 = Color3.new(0, 0, 0), Color3.new(0, 0, 0), Color3.fromHex("0B1426")
	else
		vp.Ambient, vp.LightColor, vp.LightDirection = Color3.fromRGB(180, 180, 200), Color3.fromRGB(255, 250, 240), Vector3.new(-0.5, -1, -0.8)
	end
	for k, v in props do (vp :: any)[k] = v end
	vp.Parent = parent
	whenLoaded(id, function(ok)
		local template = ok and posedModel(id)
		if not template or not vp.Parent then
			if onFail and vp.Parent then onFail() end
			vp:Destroy()
			return
		end
		local model = template:Clone()
		model.Parent = vp
		frame(vp, model, 1.15)
	end)
	return vp
end

-- The live dancers: each placed FPS times a second while it's on (a card in view in an open window).
local FPS = 30 -- (owner, Oct 22: "they don't dance well": 15 looked choppy next to the real dance)
type Live = { vp: ViewportFrame, on: boolean, apply: ((any) -> ())?, anim: any, t0: number }
local lives: { Live } = {}
local stepping = false
local function startStepping()
	if stepping then return end
	stepping = true
	local last = 0
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < 1 / FPS then return end
		last = now
		for i = #lives, 1, -1 do
			local l = lives[i]
			if not l.vp.Parent then
				table.remove(lives, i)
			elseif l.on and l.apply and l.anim then
				local ok, err = pcall(function()
					local len = math.max(l.anim.length, 0.05)
					l.apply(Sampler.sample(l.anim, (now - l.t0) % len))
				end)
				if not ok then
					warn("[HuzzUI] DancePose: a dancer stopped:", err)
					l.apply = nil
				end
			end
		end
	end)
end

-- Live game: a dance with no published ID has no moves on this screen until the server shares them. The asks of one
-- moment go together in one call (the server takes one action at a time from each player).
local asked: { [string]: boolean } = {}
local queue: { string } = {}
local sending = false
local function askFor(id: string, fn: (boolean) -> ())
	if asked[id] then fn(false) return end
	asked[id] = true
	table.insert(queue, id)
	if not sending then
		sending = true
		task.spawn(function()
			while #queue > 0 do
				task.wait(0.1) -- (the rest of this moment's cards join in)
				local batch = {}
				while #queue > 0 and #batch < 12 do table.insert(batch, table.remove(queue, 1)) end
				pcall(function()
					local Net = require(Shared.Net)
					;(Net.get("Action") :: RemoteFunction):InvokeServer("SeeDance", batch)
				end)
				task.wait(0.4)
			end
			sending = false
		end)
	end
	task.spawn(function()
		local seq = nil
		for _ = 1, 40 do -- (up to 8 s)
			local shared = ReplicatedStorage:FindFirstChild("HuzzDanceMoves")
			seq = shared and shared:FindFirstChild("Dance_" .. id)
			if seq then break end
			task.wait(0.2)
		end
		if seq then anims[id] = nil end -- (read it again now)
		fn(seq ~= nil and DancePose.anim(id) ~= nil)
	end)
end

function DancePose.live(parent: Instance, id: string, props: { [string]: any }, onReady: (() -> ())?)
	-- (nothing is made until it's first seen: a page of dances costs nothing until you scroll to it, and the saved UI
	-- never holds a dancer)
	local l: Live? = nil
	local function start()
		local vp = Instance.new("ViewportFrame")
		vp.Name = "Dancer"
		vp.BackgroundTransparency = 1
		vp:SetAttribute("RuntimeOnly", true)
		vp.Ambient, vp.LightColor, vp.LightDirection = Color3.fromRGB(180, 180, 200), Color3.fromRGB(255, 250, 240), Vector3.new(-0.5, -1, -0.8)
		for k, v in props do (vp :: any)[k] = v end
		vp.Parent = parent
		local live: Live = { vp = vp, on = true, apply = nil, anim = nil, t0 = os.clock() }
		l = live
		local function build(ok: boolean)
			local character = Players.LocalPlayer and Players.LocalPlayer.Character
			local anim = ok and DancePose.anim(id)
			if not (anim and character and vp.Parent) then return end
			local copy = stillCopy(character)
			local apply = copy and rig(copy)
			if not (copy and apply) then return end
			local okP = pcall(apply, Sampler.sample(anim, math.min(DancePoses[id] or 0, math.max(anim.length - 0.01, 0))))
			if not okP then copy:Destroy() return end
			copy.Parent = vp
			frame(vp, copy, 1.3) -- (a little more room: arms and legs swing out)
			live.apply, live.anim = apply, anim
			if onReady then onReady() end
		end
		whenLoaded(id, function(ok)
			if ok then build(true) else askFor(id, build) end
		end)
		table.insert(lives, live)
		startStepping()
	end
	return {
		setOn = function(on: boolean)
			if l then
				l.on = on
			elseif on and Players.LocalPlayer and Players.LocalPlayer.Character then
				start()
			end
		end,
	}
end

return DancePose
