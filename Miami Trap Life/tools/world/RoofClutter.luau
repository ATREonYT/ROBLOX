-- Rooftop clutter for the hood (Quality pass, LihFolk Build List item 13). Edit-time builder, run once from the
-- Studio command bar / MCP. Everything is built from plain parts (no inserted models, no scripts).
-- Finds exposed flat roofs in the hood and adds package AC units, vent stacks, a water tank, a satellite dish and
-- a roof hatch, seeded by the roof position so a re-run gives the same layout. Output: workspace.MTL_WorldDetail.Roofs
-- Re-running clears that folder first.
local ARGS = {}
local BOUNDS_MIN = ARGS.min or Vector3.new(-1720, 6, -960)
local BOUNDS_MAX = ARGS.max or Vector3.new(-980, 120, -60)
local DRY = ARGS.dry

local root = workspace:FindFirstChild("MTL_WorldDetail") or Instance.new("Folder")
root.Name = "MTL_WorldDetail"
root.Parent = workspace
local old = root:FindFirstChild("Roofs")
if old and not DRY then
	old:Destroy()
end
local out = Instance.new("Folder")
out.Name = "Roofs"
if not DRY then out.Parent = root end

local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local WHITE = Color3.fromRGB(206, 206, 200)
local GREY = Color3.fromRGB(150, 152, 150)
local DARK = Color3.fromRGB(46, 48, 50)
local RUST = Color3.fromRGB(128, 84, 58)

-- package AC unit: cabinet, louvered sides, fan shroud with blades, rails, duct into the roof
local function acUnit(base: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "ACUnit"
	local w, h, d = 4.2, 2.6, 3.2
	local tint = WHITE:Lerp(Color3.fromRGB(190, 182, 160), rng:NextNumber(0, 0.6))
	for _, x in { -1.4, 1.4 } do
		part(m, "Rail", Vector3.new(0.3, 0.3, d + 0.6), base * CFrame.new(x, 0.15, 0), DARK)
	end
	local body = part(m, "Cabinet", Vector3.new(w, h, d), base * CFrame.new(0, 0.3 + h / 2, 0), tint)
	-- louvers on the long sides
	for _, z in { -d / 2 - 0.03, d / 2 + 0.03 } do
		for i = 0, 5 do
			part(m, "Louver", Vector3.new(w - 0.6, 0.08, 0.06), base * CFrame.new(0, 0.7 + i * 0.32, z), tint:Lerp(DARK, 0.45), Enum.Material.Metal)
		end
	end
	-- fan shroud + blades on top
	local top = body.CFrame * CFrame.new(0.6, h / 2, 0)
	part(m, "Shroud", Vector3.new(0.35, 2.4, 2.4), top * CFrame.new(0, 0.17, 0) * CFrame.Angles(0, 0, math.rad(90)), tint:Lerp(DARK, 0.2), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Grille", Vector3.new(0.05, 2.25, 2.25), top * CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.DiamondPlate, Enum.PartType.Cylinder).Transparency = 0.15
	local spin = rng:NextNumber(0, math.pi)
	for i = 0, 1 do
		part(m, "Blade", Vector3.new(2.0, 0.05, 0.4), top * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, spin + i * math.pi / 2, math.rad(12)), DARK)
	end
	-- service panel + label plate
	part(m, "Panel", Vector3.new(1.2, 1.3, 0.05), body.CFrame * CFrame.new(-1.3, -0.1, d / 2 + 0.06), tint:Lerp(GREY, 0.4))
	-- duct that disappears into the roof
	local duct = part(m, "Duct", Vector3.new(1.0, 1.2, 1.0), base * CFrame.new(-w / 2 - 0.6, 0.6, 0), GREY, Enum.Material.Metal)
	part(m, "DuctElbow", Vector3.new(0.7, 1.0, 1.0), duct.CFrame * CFrame.new(0.75, 0.1, 0), GREY, Enum.Material.Metal)
	-- rust streak
	if rng:NextNumber() < 0.5 then
		part(m, "Rust", Vector3.new(0.4, 1.4, 0.02), body.CFrame * CFrame.new(rng:NextNumber(-1.5, 1.5), -0.4, d / 2 + 0.05), RUST, Enum.Material.CorrodedMetal).Transparency = 0.35
	end
	return m, Vector3.new(w + 2, h, d + 1)
end

local function ventStack(base: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Vent"
	local tall = rng:NextNumber(1.4, 2.6)
	part(m, "Flash", Vector3.new(0.25, 1.3, 1.3), base * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Pipe", Vector3.new(tall, 0.55, 0.55), base * CFrame.new(0, tall / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), GREY, Enum.Material.Metal, Enum.PartType.Cylinder)
	if rng:NextNumber() < 0.5 then
		-- turbine vent
		part(m, "Turbine", Vector3.new(1.1, 1.0, 1.1), base * CFrame.new(0, tall + 0.4, 0), Color3.fromRGB(176, 178, 176), Enum.Material.Metal, Enum.PartType.Ball)
		part(m, "Ribs", Vector3.new(0.9, 0.85, 0.9), base * CFrame.new(0, tall + 0.4, 0) * CFrame.Angles(0, math.rad(45), 0), DARK, Enum.Material.DiamondPlate, Enum.PartType.Ball).Transparency = 0.5
	else
		part(m, "Cap", Vector3.new(0.12, 1.0, 1.0), base * CFrame.new(0, tall + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	return m, Vector3.new(1.6, tall, 1.6)
end

local function waterTank(base: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "WaterTank"
	local r, tall = 2.2, 3.8
	for _, o in { Vector3.new(1.5, 0, 1.5), Vector3.new(-1.5, 0, 1.5), Vector3.new(1.5, 0, -1.5), Vector3.new(-1.5, 0, -1.5) } do
		part(m, "Leg", Vector3.new(0.3, 2.2, 0.3), base * CFrame.new(o.X, 1.1, o.Z), DARK)
	end
	part(m, "Deck", Vector3.new(4.0, 0.25, 4.0), base * CFrame.new(0, 2.3, 0), DARK, Enum.Material.DiamondPlate)
	local tint = Color3.fromRGB(70, 74, 78):Lerp(Color3.fromRGB(214, 210, 198), rng:NextNumber())
	part(m, "Tank", Vector3.new(tall, r * 2, r * 2), base * CFrame.new(0, 2.4 + tall / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), tint, Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(m, "Lid", Vector3.new(0.3, 1.2, 1.2), base * CFrame.new(0, 2.4 + tall + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), tint:Lerp(DARK, 0.3), Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(m, "Pipe", Vector3.new(0.3, 2.6, 0.3), base * CFrame.new(r - 0.2, 1.3, 0), GREY)
	return m, Vector3.new(5, 7, 5)
end

local function dish(base: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Dish"
	part(m, "Foot", Vector3.new(0.8, 0.2, 0.8), base * CFrame.new(0, 0.1, 0), DARK)
	part(m, "Mast", Vector3.new(0.18, 1.6, 0.18), base * CFrame.new(0, 0.9, 0), GREY)
	local face = base * CFrame.new(0, 1.8, 0) * CFrame.Angles(math.rad(-30), 0, 0)
	part(m, "Bowl", Vector3.new(0.15, 1.8, 1.8), face * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(226, 226, 222), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(m, "Arm", Vector3.new(0.08, 0.08, 1.1), face * CFrame.new(0, -0.3, -0.6) * CFrame.Angles(math.rad(-25), 0, 0), GREY)
	part(m, "LNB", Vector3.new(0.2, 0.2, 0.3), face * CFrame.new(0, -0.55, -1.1), DARK)
	return m, Vector3.new(2, 2.6, 2)
end

local function hatch(base: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Hatch"
	part(m, "Curb", Vector3.new(3.0, 0.7, 3.0), base * CFrame.new(0, 0.35, 0), GREY, Enum.Material.Concrete)
	part(m, "Lid", Vector3.new(2.8, 0.18, 2.8), base * CFrame.new(0, 0.79, 0), Color3.fromRGB(110, 112, 108), Enum.Material.DiamondPlate)
	part(m, "Handle", Vector3.new(0.6, 0.1, 0.1), base * CFrame.new(0, 0.93, 1.1), DARK)
	return m, Vector3.new(3.2, 1, 3.2)
end

local function pipeRun(base: CFrame, rng: Random, len: number)
	local m = Instance.new("Model")
	m.Name = "PipeRun"
	part(m, "Pipe", Vector3.new(len, 0.4, 0.4), base * CFrame.new(0, 0.55, 0), Color3.fromRGB(104, 112, 104), Enum.Material.Metal, Enum.PartType.Cylinder)
	local n = math.max(2, math.floor(len / 5))
	for i = 0, n do
		local x = -len / 2 + i * len / n
		part(m, "Sleeper", Vector3.new(0.4, 0.35, 0.9), base * CFrame.new(x, 0.18, 0), DARK, Enum.Material.Wood)
	end
	return m, Vector3.new(len, 1, 1)
end

-- ---------------------------------------------------------------- roof finder
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { out, root }

local roofs = {}
local seen = 0
for i, d in workspace:GetDescendants() do
	if i % 15000 == 0 then
		task.wait()
	end
	if d:IsA("BasePart") and d.Transparency < 0.5 and d.Size.Y <= 3 and d.Size.X >= 14 and d.Size.Z >= 14 then
		local p = d.Position
		local top = p.Y + d.Size.Y / 2
		if p.X > BOUNDS_MIN.X and p.X < BOUNDS_MAX.X and p.Z > BOUNDS_MIN.Z and p.Z < BOUNDS_MAX.Z and top > 11 and top < BOUNDS_MAX.Y and math.abs(d.CFrame.UpVector.Y) > 0.995 and not d:IsDescendantOf(root) then
			seen += 1
			local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -100, 0), rp)
			if hit and hit.Instance == d and math.abs(hit.Position.Y - top) < 0.2 then
				table.insert(roofs, d)
			end
		end
	end
end

local placed = 0
local count = { ACUnit = 0, Vent = 0, WaterTank = 0, Dish = 0, Hatch = 0, PipeRun = 0 }

local function free(cf: CFrame, size: Vector3, roof: BasePart)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { roof }
	local hits = workspace:GetPartBoundsInBox(cf * CFrame.new(0, size.Y / 2 + 0.15, 0), size + Vector3.new(0.6, 0, 0.6), op)
	return #hits == 0
end

local function onRoof(pos: Vector3, roof: BasePart, half: Vector3)
	-- every corner of the footprint has to land on this roof
	for _, o in { Vector3.new(half.X, 0, half.Z), Vector3.new(-half.X, 0, half.Z), Vector3.new(half.X, 0, -half.Z), Vector3.new(-half.X, 0, -half.Z) } do
		local h = workspace:Raycast(pos + o + Vector3.new(0, 30, 0), Vector3.new(0, -40, 0), rp)
		if not h or h.Instance ~= roof then
			return false
		end
	end
	return true
end

for _, roof in roofs do
	local p = roof.Position
	local rng = Random.new(math.floor(p.X * 7 + p.Z * 13 + p.Y))
	local top = p.Y + roof.Size.Y / 2
	local sx, sz = roof.Size.X, roof.Size.Z
	local area = sx * sz
	-- how busy is it already? (someone else's dish/AC/billboard)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { roof }
	local already = #workspace:GetPartBoundsInBox(roof.CFrame * CFrame.new(0, roof.Size.Y / 2 + 2.5, 0), Vector3.new(sx - 2, 4, sz - 2), op)
	local plan = {}
	local nAC = math.clamp(math.floor(area / 380), 1, 4)
	if already > 10 then
		nAC = math.max(0, nAC - 2)
	end
	for _ = 1, nAC do
		table.insert(plan, acUnit)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		table.insert(plan, ventStack)
	end
	if area > 450 and rng:NextNumber() < 0.45 then
		table.insert(plan, waterTank)
	end
	if rng:NextNumber() < 0.35 then
		table.insert(plan, dish)
	end
	if rng:NextNumber() < 0.7 then
		table.insert(plan, hatch)
	end
	local group = Instance.new("Model")
	group.Name = (roof.Parent and roof.Parent.Name or "Roof") .. "_Roof"
	group.Parent = out -- in the world while placing, so later pieces see earlier ones
	for _, build in plan do
		for _try = 1, 14 do
			local yaw = CFrame.Angles(0, (rng:NextInteger(0, 3)) * math.pi / 2, 0)
			local lx = rng:NextNumber(-sx / 2 + 3, sx / 2 - 3)
			local lz = rng:NextNumber(-sz / 2 + 3, sz / 2 - 3)
			local base = CFrame.new((roof.CFrame * CFrame.new(lx, 0, lz)).Position.X, top, (roof.CFrame * CFrame.new(lx, 0, lz)).Position.Z) * (roof.CFrame - roof.CFrame.Position) * yaw
			local m, foot = build(base, rng)
			local ok = onRoof(base.Position, roof, (base - base.Position):VectorToWorldSpace(foot / 2):Abs()) and free(base, foot, roof)
			if ok then
				m.Parent = group
				count[m.Name] += 1
				placed += 1
				break
			else
				m:Destroy()
			end
		end
	end
	-- a pipe run along one long edge on the bigger roofs
	if area > 600 and rng:NextNumber() < 0.6 then
		local alongX = sx > sz
		local len = (if alongX then sx else sz) * 0.6
		local off = (if alongX then sz else sx) / 2 - 1.6
		local local_ = if alongX then CFrame.new(0, 0, off) else CFrame.new(off, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		local base = CFrame.new((roof.CFrame * local_).Position.X, top, (roof.CFrame * local_).Position.Z) * ((roof.CFrame * local_) - (roof.CFrame * local_).Position)
		local m, foot = pipeRun(base, rng, len)
		if free(base, foot, roof) then
			m.Parent = group
			count.PipeRun += 1
			placed += 1
		else
			m:Destroy()
		end
	end
	if #group:GetChildren() == 0 then
		group:Destroy()
	end
	task.wait()
end

if DRY then
	out:Destroy()
end
local s = {}
for k, v in count do
	table.insert(s, k .. "=" .. v)
end
return string.format("candidates %d, exposed roofs %d, placed %d (%s)", seen, #roofs, placed, table.concat(s, " "))
