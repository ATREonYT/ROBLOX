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

-- Places every part from the root through its joints, with the pose on the Motor6Ds (Transform = the pose).
local function pose(model: Model, posed: { [string]: CFrame })
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local edges: { [BasePart]: { { other: BasePart, place: (BasePart) -> CFrame } } } = {}
	local function link(a: BasePart, b: BasePart, fromA: (BasePart) -> CFrame, fromB: (BasePart) -> CFrame)
		edges[a] = edges[a] or {}
		edges[b] = edges[b] or {}
		table.insert(edges[a], { other = b, place = fromA })
		table.insert(edges[b], { other = a, place = fromB })
	end
	for _, j in model:GetDescendants() do
		if j.ClassName == "AnimationConstraint" then
			-- avatars on Roblox's newer joints: like a Motor6D with its attachments as C0 / C1
			local a0, a1 = (j :: any).Attachment0, (j :: any).Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local t = posed[p1.Name] or CFrame.new()
				local c0, c1 = a0.CFrame, a1.CFrame
				link(p0, p1, function(a) return a.CFrame * c0 * t * c1:Inverse() end, function(b) return b.CFrame * c1 * t:Inverse() * c0:Inverse() end)
			end
		elseif j:IsA("JointInstance") and j.Part0 and j.Part1 then
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			local t = if j:IsA("Motor6D") then (posed[p1.Name] or CFrame.new()) else CFrame.new()
			local c0, c1 = j.C0, j.C1
			link(p0, p1, function(a) return a.CFrame * c0 * t * c1:Inverse() end, function(b) return b.CFrame * c1 * t:Inverse() * c0:Inverse() end)
		elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 then
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			local rel = p0.CFrame:ToObjectSpace(p1.CFrame) -- (as built, before anything moves)
			link(p0, p1, function(a) return a.CFrame * rel end, function(b) return b.CFrame * rel:Inverse() end)
		end
	end
	local rootWas = root.CFrame
	root.CFrame = CFrame.new()
	local done = { [root] = true }
	local queue, i = { root }, 1
	while queue[i] do
		local part = queue[i]
		i += 1
		for _, e in edges[part] or {} do
			if not done[e.other] then
				done[e.other] = true
				e.other.CFrame = e.place(part)
				table.insert(queue, e.other)
			end
		end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			-- a part no joint reaches (held some other way) keeps its place relative to the body
			if not done[p] then p.CFrame = rootWas:ToObjectSpace(p.CFrame) end
			p.Anchored = true
		end
	end
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
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		-- frame the whole body, a little from the side so the pose reads
		local cf, size = model:GetBoundingBox()
		local centre = cf.Position
		local fit = math.max(size.Y, size.X * 0.75)
		local dist = fit / (2 * math.tan(math.rad(cam.FieldOfView) / 2)) * 1.15
		cam.CFrame = CFrame.lookAt(centre + Vector3.new(-0.22, 0.08, -1).Unit * dist, centre)
		cam.Parent = vp
		vp.CurrentCamera = cam
	end)
	return vp
end

return DancePose
