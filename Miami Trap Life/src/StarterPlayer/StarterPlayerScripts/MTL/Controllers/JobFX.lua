--!strict
-- Local-only world dressing for jobs (helper for JobController, not booted on its own).
-- Only YOU see these, so tasks stay per player (nobody else's spill on your floor):
--   * placeholder props at stations that have no real map part yet (shelf, dumpster, car, grill...)
--   * the dynamic bits that make a task feel physical: the spill shrinking as you mop, products popping
--     onto the shelf, the full trash bag, suds, sizzle, price tags, the "done" ring.
-- TODO(Alex art): every placeholder here is plain parts. Real models can replace a prop by putting a Model named
-- like the prop ("Shelf", "Car"...) in ReplicatedStorage.MTL_JobProps: it gets cloned instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)

local J = Theme.Job
local C3 = Color3.fromRGB

local JobFX = {}

local folder: Folder
local staticFolder: Folder
local staticKey = ""

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function part(props: { [string]: any }): Part
	local base: { [string]: any } = {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}
	for k, v in props do
		base[k] = v
	end
	return new("Part", base)
end

function JobFX.sound(id: string?, volume: number?, pitch: number?)
	if not id or id == "" or id == "rbxassetid://0" then
		return
	end
	-- through UI/Sfx: respects Settings > Sound effects, caps length (~1 s), pitch capped at 1.05 (no squeaky sounds)
	Sfx.playId(id, { volume = volume or 0.5, pitch = pitch })
end

-- Floor height under a point (ignores characters and our own FX). Falls back to pos.Y - 2.5 if nothing's there
-- (e.g. not streamed in yet).
function JobFX.floor(pos: Vector3): number
	local params = RaycastParams.new()
	local ignore: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position.Y else pos.Y - 2.5
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

---------------------------------------------------------------- placeholder props

-- builds a prop with its bottom at y = 0 around the origin; returns a Model
local builders: { [string]: (Model) -> () } = {
	TimeClock = function(m)
		part({ Name = "Post", Size = Vector3.new(0.4, 4, 0.4), Position = Vector3.new(0, 2, 0), Color = C3(60, 60, 66), Parent = m })
		part({ Name = "Box", Size = Vector3.new(1.4, 1.6, 0.6), Position = Vector3.new(0, 4.4, 0), Color = C3(40, 42, 50), Parent = m })
		part({ Name = "Screen", Size = Vector3.new(1, 0.4, 0.1), Position = Vector3.new(0, 4.7, -0.32), Color = J.Hit, Material = Enum.Material.Neon, Parent = m })
	end,
	Boxes = function(m)
		local spots = { Vector3.new(-1.2, 0.8, 0), Vector3.new(1.2, 0.8, 0.2), Vector3.new(0, 2.4, 0.1), Vector3.new(-0.2, 0.8, 1.8) }
		for i, p in spots do
			part({ Name = "Box" .. i, Size = Vector3.new(2, 1.6, 1.6), Position = p, Color = C3(176, 132, 84), Material = Enum.Material.Cardboard, Orientation = Vector3.new(0, (i * 17) % 20 - 10, 0), Parent = m })
		end
	end,
	Shelf = function(m)
		part({ Name = "Back", Size = Vector3.new(6, 6, 0.3), Position = Vector3.new(0, 3, 0.9), Color = C3(210, 212, 218), Parent = m })
		for i = 0, 3 do
			part({ Name = "Board" .. i, Size = Vector3.new(6, 0.2, 1.8), Position = Vector3.new(0, 0.3 + i * 1.6, 0), Color = C3(225, 226, 230), Parent = m })
		end
	end,
	Bin = function(m)
		part({ Name = "Can", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2, 2), Position = Vector3.new(0, 1.3, 0), Orientation = Vector3.new(0, 0, 90), Color = C3(90, 96, 104), Material = Enum.Material.Metal, Parent = m })
	end,
	Dumpster = function(m)
		part({ Name = "Body", Size = Vector3.new(6, 3.6, 3.4), Position = Vector3.new(0, 1.8, 0), Color = C3(40, 110, 70), Material = Enum.Material.Metal, Parent = m })
		part({ Name = "Lid", Size = Vector3.new(6.1, 0.2, 3.5), Position = Vector3.new(0, 3.7, 0), Color = C3(30, 30, 34), Parent = m })
	end,
	TireRack = function(m)
		part({ Name = "Frame", Size = Vector3.new(5, 0.3, 1.6), Position = Vector3.new(0, 1.6, 0), Color = C3(70, 70, 80), Material = Enum.Material.Metal, Parent = m })
		for i = -1, 1 do
			part({ Name = "Tire", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.4, 2.4), Position = Vector3.new(i * 1.4, 2.95, 0), Color = C3(28, 28, 30), Parent = m })
		end
	end,
	Car = function(m)
		local body = C3(70 + math.random(0, 150), 70 + math.random(0, 100), 80 + math.random(0, 150))
		part({ Name = "Body", Size = Vector3.new(6, 2, 12), Position = Vector3.new(0, 1.6, 0), Color = body, Material = Enum.Material.Metal, Parent = m })
		part({ Name = "Cabin", Size = Vector3.new(5.2, 1.8, 6), Position = Vector3.new(0, 3.4, 0.6), Color = C3(30, 34, 44), Material = Enum.Material.Glass, Transparency = 0.2, Parent = m })
		for _, x in { -3, 3 } do
			for _, z in { -3.8, 3.8 } do
				part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2, 2), Position = Vector3.new(x, 1, z), Color = C3(20, 20, 22), Parent = m })
			end
		end
	end,
	Grill = function(m)
		part({ Name = "Base", Size = Vector3.new(4, 3, 2.6), Position = Vector3.new(0, 1.5, 0), Color = C3(60, 62, 70), Material = Enum.Material.Metal, Parent = m })
		part({ Name = "Plate", Size = Vector3.new(3.6, 0.15, 2.2), Position = Vector3.new(0, 3.05, 0), Color = C3(255, 120, 40), Material = Enum.Material.Neon, Transparency = 0.3, Parent = m })
	end,
	Counter = function(m)
		part({ Name = "Top", Size = Vector3.new(6, 3, 2.2), Position = Vector3.new(0, 1.5, 0), Color = C3(235, 235, 238), Parent = m })
	end,
	Table = function(m)
		part({ Name = "Top", Size = Vector3.new(4, 0.25, 4), Position = Vector3.new(0, 2.6, 0), Color = C3(150, 100, 60), Material = Enum.Material.Wood, Parent = m })
		part({ Name = "Leg", Size = Vector3.new(0.4, 2.5, 0.4), Position = Vector3.new(0, 1.25, 0), Color = C3(40, 40, 44), Parent = m })
	end,
	Register = function(m)
		part({ Name = "Counter", Size = Vector3.new(5, 3, 2.2), Position = Vector3.new(0, 1.5, 0), Color = C3(225, 225, 230), Parent = m })
		part({ Name = "Till", Size = Vector3.new(1.4, 0.9, 1), Position = Vector3.new(-1, 3.45, 0), Color = C3(40, 42, 50), Parent = m })
		part({ Name = "Screen", Size = Vector3.new(1, 0.6, 0.1), Position = Vector3.new(-1, 4.1, 0.2), Color = J.Hit, Material = Enum.Material.Neon, Parent = m })
	end,
	Podium = function(m)
		part({ Name = "Stand", Size = Vector3.new(1.6, 3.6, 1.2), Position = Vector3.new(0, 1.8, 0), Color = C3(120, 30, 40), Parent = m })
	end,
	Crates = function(m)
		for i, p in { Vector3.new(-1.3, 1, 0), Vector3.new(1.3, 1, 0), Vector3.new(0, 3, 0) } do
			part({ Name = "Crate" .. i, Size = Vector3.new(2.4, 2, 2), Position = p, Color = C3(150, 110, 70), Material = Enum.Material.WoodPlanks, Parent = m })
		end
	end,
	Post = function(_m) end, -- the post zone ring is drawn by JobFX.postRing (always, even with a map part)
}

local function placeModel(m: Model, pos: Vector3)
	local y = JobFX.floor(pos)
	m:PivotTo(CFrame.new(pos.X, y, pos.Z))
end

-- props = { {id, prop, pos} } from JobState. Rebuilt only when the job (key) changes.
function JobFX.setStatic(key: string, props: { any }?)
	if key == staticKey then
		return
	end
	staticKey = key
	staticFolder:ClearAllChildren()
	for _, p in props or {} do
		local custom = ReplicatedStorage:FindFirstChild("MTL_JobProps")
		local template = custom and custom:FindFirstChild(p.prop)
		local m: Model
		if template and template:IsA("Model") then
			m = template:Clone()
		else
			local build = builders[p.prop]
			if not build then
				continue
			end
			m = Instance.new("Model")
			m.Name = p.prop
			build(m)
			local origin = Instance.new("Part")
			origin.Name = "Origin"
			origin.Anchored, origin.CanCollide, origin.CanQuery, origin.Transparency = true, false, false, 1
			origin.Size = Vector3.new(0.2, 0.2, 0.2)
			origin.Position = Vector3.zero
			origin.Parent = m
			m.PrimaryPart = origin
		end
		m:SetAttribute("Station", p.id)
		m.Parent = staticFolder
		-- place once the area has had a moment to stream in
		task.spawn(function()
			placeModel(m, p.pos)
			task.wait(2)
			if m.Parent then
				placeModel(m, p.pos)
			end
		end)
	end
end

---------------------------------------------------------------- dynamic task FX

export type FX = { progress: (number, boolean?) -> (), hit: () -> (), finish: () -> (), destroy: () -> () }

local function noop() end

-- The task's world bit for a step. `fx` = Config step.fx. Returns handles the minigame drives.
function JobFX.forStep(fx: string?, pos: Vector3): FX
	local y = JobFX.floor(pos)
	local ground = Vector3.new(pos.X, y, pos.Z)
	if fx == "Spill" then
		local size = 5.5
		local puddle = part({
			Name = "Spill",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, size, size),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = J.Spill,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Reflectance = 0.2,
			Parent = folder,
		})
		-- dress the spill: a wet-floor sign and the mop bucket (ReplicatedStorage.MTL_JobProps.Spill, pivots at the base)
		local dressing: { Instance } = {}
		local kit = ReplicatedStorage:FindFirstChild("MTL_JobProps")
		kit = kit and kit:FindFirstChild("Spill")
		if kit then
			local spots = {
				WetFloorSign = CFrame.new(0.8, 0, size / 2 + 1.2) * CFrame.Angles(0, math.rad(-25), 0),
				MopBucket = CFrame.new(-1, 0, -(size / 2 + 1.4)) * CFrame.Angles(0, math.rad(80), 0),
			}
			for name, at in spots do
				local src = kit:FindFirstChild(name)
				if src and src:IsA("Model") then
					local m = src:Clone()
					m:PivotTo(CFrame.new(ground) * at)
					m.Parent = folder
					table.insert(dressing, m)
				end
			end
		end
		return {
			progress = function(p)
				local s = math.max(0.05, size * (1 - p))
				puddle.Size = Vector3.new(0.06, s, s)
			end,
			hit = noop,
			finish = function()
				tween(puddle, 0.25, { Transparency = 1 })
			end,
			destroy = function()
				puddle:Destroy()
				for _, m in dressing do
					m:Destroy()
				end
			end,
		}
	elseif fx == "ShelfFill" then
		local items: { Part } = {}
		local slots = 9
		local placed = 0
		return {
			progress = function(p)
				local want = math.floor(p * slots + 0.0001)
				while placed < want do
					placed += 1
					local row = math.floor((placed - 1) / 3)
					local col = (placed - 1) % 3
					local target = ground + Vector3.new(-1.6 + col * 1.6, 0.85 + row * 1.6, 0)
					local item = part({
						Name = "Product",
						Size = Vector3.new(0.1, 0.1, 0.1),
						Position = target,
						Color = J.Products[(placed % #J.Products) + 1],
						Parent = folder,
					})
					tween(item, 0.2, { Size = Vector3.new(1.2, 1.1, 0.9) }, Enum.EasingStyle.Back)
					JobFX.sound(J.Sounds.Prompt, 0.25, 0.9 + placed * 0.05)
					table.insert(items, item)
				end
			end,
			hit = noop,
			finish = noop,
			destroy = function()
				-- products stay on the shelf a little while (the world changed because of you), then fade
				for _, it in items do
					task.delay(20, function()
						if it.Parent then
							tween(it, 0.6, { Transparency = 1 }).Completed:Wait()
							it:Destroy()
						end
					end)
				end
			end,
		}
	elseif fx == "Suds" or fx == "Sizzle" then
		local anchor = part({ Name = fx, Size = Vector3.new(4, 0.2, 4), Position = ground + Vector3.new(0, if fx == "Sizzle" then 3.2 else 2, 0), Transparency = 1, Parent = folder })
		local emitter = new("ParticleEmitter", {
			Rate = 0,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(40, 40),
			Size = NumberSequence.new(if fx == "Suds" then 0.6 else 0.4, 0),
			Color = ColorSequence.new(if fx == "Suds" then Color3.new(1, 1, 1) else C3(255, 170, 90)),
			Transparency = NumberSequence.new(0.2, 1),
			Parent = anchor,
		})
		return {
			progress = function(p, active)
				emitter.Rate = if active and p < 1 then 30 else 0
			end,
			hit = noop,
			finish = function()
				emitter:Emit(25)
			end,
			destroy = function()
				task.delay(1.5, function()
					anchor:Destroy()
				end)
			end,
		}
	elseif fx == "PriceTag" then
		return {
			progress = noop,
			hit = function()
				local bb = new("BillboardGui", { Size = UDim2.fromOffset(90, 30), StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, 3 + math.random() * 1.5, 0), AlwaysOnTop = true, Adornee = nil, Parent = folder })
				local anchor = part({ Name = "Tag", Size = Vector3.new(0.1, 0.1, 0.1), Position = ground, Transparency = 1, Parent = folder })
				bb.Adornee = anchor
				local label = new("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					Text = string.format("$%d.%02d", math.random(1, 9), ({ 49, 79, 99, 29 })[math.random(1, 4)]),
					TextColor3 = C3(200, 30, 40),
					FontFace = Theme.Fonts.Bold,
					TextScaled = true,
					Parent = bb,
				})
				new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = label })
				task.delay(1.2, function()
					bb:Destroy()
					anchor:Destroy()
				end)
			end,
			finish = noop,
			destroy = noop,
		}
	end
	return { progress = noop, hit = noop, finish = noop, destroy = noop }
end

-- A full trash bag sitting at the bin until you pick it up. Returns a destroy function.
function JobFX.bag(pos: Vector3): () -> ()
	local y = JobFX.floor(pos)
	local bag = part({ Name = "Bag", Size = Vector3.new(1.5, 2, 1.5), Position = Vector3.new(pos.X + 1.6, y + 1, pos.Z), Color = C3(30, 30, 34), Parent = folder })
	return function()
		bag:Destroy()
	end
end

-- The glowing column on the station you need to go to.
function JobFX.beacon(pos: Vector3, radius: number): () -> ()
	local y = JobFX.floor(pos)
	local ring = part({
		Name = "Beacon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, radius * 0.9, radius * 0.9),
		CFrame = CFrame.new(pos.X, y + 0.06, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = J.Marker,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		Parent = folder,
	})
	local column = part({
		Name = "Column", -- a thin, faint light line (was a thick neon pillar: read as "AI")
		Size = Vector3.new(0.18, 6, 0.18),
		Position = Vector3.new(pos.X, y + 3, pos.Z),
		Color = J.Marker,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
		CastShadow = false,
		Parent = folder,
	})
	local alive = true
	task.spawn(function()
		while alive do
			tween(ring, 0.8, { Transparency = 0.8 }, Enum.EasingStyle.Sine).Completed:Wait()
			if not alive then
				break
			end
			tween(ring, 0.8, { Transparency = 0.45 }, Enum.EasingStyle.Sine).Completed:Wait()
		end
	end)
	return function()
		alive = false
		ring:Destroy()
		column:Destroy()
	end
end

-- The post zone for AFK jobs (stand inside it). Returns a destroy function.
function JobFX.postRing(pos: Vector3, radius: number): () -> ()
	local y = JobFX.floor(pos)
	local ring = part({
		Name = "PostZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, radius * 2, radius * 2),
		CFrame = CFrame.new(pos.X, y + 0.05, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = J.Zone,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
		Parent = folder,
	})
	return function()
		ring:Destroy()
	end
end

-- "Done!" ring that bursts out of a station.
function JobFX.burst(pos: Vector3, color: Color3?)
	local y = JobFX.floor(pos)
	local ring = part({
		Name = "Burst",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 1, 1),
		CFrame = CFrame.new(pos.X, y + 0.3, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color or J.Hit,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = folder,
	})
	tween(ring, 0.45, { Size = Vector3.new(0.1, 12, 12), Transparency = 1 })
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

-- Level-up: a ring of light rising around the character.
function JobFX.levelUp(character: Model?)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 2.8, 0)
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			local ring = part({
				Name = "LevelRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.15, 3, 3),
				CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Theme.Colors.Gold,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				Parent = folder,
			})
			tween(ring, 0.9, { Size = Vector3.new(0.15, 9, 9), CFrame = CFrame.new(base + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1 }, Enum.EasingStyle.Quart)
			task.delay(1, function()
				ring:Destroy()
			end)
		end)
	end
end

function JobFX.clearDynamic()
	for _, c in folder:GetChildren() do
		if c ~= staticFolder then
			c:Destroy()
		end
	end
end

function JobFX.init()
	folder = Instance.new("Folder")
	folder.Name = "MTL_JobFX"
	folder.Parent = workspace
	staticFolder = Instance.new("Folder")
	staticFolder.Name = "Props"
	staticFolder.Parent = folder
end

return JobFX
