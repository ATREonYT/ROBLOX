-- [MTL HoodLife] Edit-mode stand-in for the living layer, for screenshots only (the real thing runs on the client in
-- Play). Builds Workspace.MTL_HoodLife.Preview around FOCUS: posed people on the nearest spots (outfits from
-- Config/Outfits), a traffic car on the nearest lane, a pigeon flock, and (NIGHT = true) the lit windows.
-- Run with CLEAR = true to remove it. Set FOCUS (Vector3) and NIGHT before running.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")

local FOCUS: Vector3 = FOCUS or Vector3.new(-1432, 3, -368)
local NIGHT: boolean = NIGHT == true
local CLEAR: boolean = CLEAR == true

local root = workspace:FindFirstChild("MTL_HoodLife")
if not root then
	return "run DressHoodLife first"
end
local old = root:FindFirstChild("Preview")
if old then
	old:Destroy()
end
if CLEAR then
	return "preview cleared"
end
local preview = Instance.new("Folder")
preview.Name = "Preview"
preview.Parent = root

-- fresh requires (no stale module cache between runs)
local tmp = RS.MTL:Clone()
tmp.Name = "MTL_PreviewTmp"
tmp.Parent = SS
local Rig = require(tmp.Rig)
local Outfits = require(tmp.Config.Outfits)
local Ambient = require(tmp.Config.Ambient)
local Map = require(tmp.Config.AmbientMap)
local R = require(tmp.Rules.AmbientRules)
tmp:Destroy()

local rng = Random.new(7)
local report = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { root }
params.RespectCanCollide = true
local function ground(p: Vector3): number
	local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else p.Y
end

---------------------------------------------------------------- people
local ids = Outfits.ambientIds(Ambient.People.Roles)
local rigs: { [string]: Model } = {}
local function rigFor(role: string?): Model?
	local pick = {}
	for _, id in ids do
		if role == nil or Outfits.List[id].Role == role then
			table.insert(pick, id)
		end
	end
	if #pick == 0 then
		pick = ids
	end
	local id = pick[rng:NextInteger(1, #pick)]
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Outfits.description(Outfits.List[id]), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		ok, m = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Outfits.description(Outfits.List[id], true), Enum.HumanoidRigType.R15)
		end)
	end
	if not ok or not m then
		table.insert(report, "rig failed: " .. tostring(m))
		return nil
	end
	if Outfits.List[id].Height then
		pcall(function()
			m:ScaleTo(Outfits.List[id].Height)
		end)
	end
	return m
end

local function person(cf: CFrame, pose: string, role: string?, gesture: string?)
	local m = rigFor(role)
	if not m then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	m.Parent = preview
	local rootPart = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local state: any = { pose = pose, poseT0 = -10, breath = false }
	if gesture then
		state.gesture = gesture
		state.gestureT0 = -0.6
		state.gestureDur = 1.2
	end
	rootPart.CFrame = cf + Vector3.new(0, Rig.rootHeight(m) - Rig.drop(state), 0)
	Rig.apply(Rig.joints(m), Rig.compose(state, 0), "C0")
end

local spots = {}
for _, s in Map.Spots do
	local p = Vector3.new(s[2], s[3], s[4])
	if (p - FOCUS).Magnitude < 110 then
		table.insert(spots, { s = s, d = (p - FOCUS).Magnitude })
	end
end
table.sort(spots, function(a, b)
	return a.d < b.d
end)
local n = 0
for _, e in spots do
	if n >= 12 then
		break
	end
	local s = e.s
	local kind = s[1]
	local cf = CFrame.new(s[2], s[3], s[4]) * CFrame.Angles(0, math.rad(s[5]), 0)
	local role = Ambient.People.RoleFor[kind]
	if kind == "Corner" then
		local k = math.clamp(s[6] or 3, 2, 3)
		for i = 1, k do
			local a = (i / k) * math.pi * 2
			local at = cf.Position + Vector3.new(math.cos(a) * 2.7, 0, math.sin(a) * 2.7)
			at = Vector3.new(at.X, ground(at), at.Z)
			person(CFrame.lookAt(at, Vector3.new(cf.X, at.Y, cf.Z)), if i == 1 then "Cross" else "None", if i == 1 then "Crew" else nil, if i == 2 then "Laugh" elseif i == 3 then "Open" else nil)
			n += 1
		end
	elseif kind == "Stoop" or kind == "Lean" or kind == "Bench" or string.sub(kind, 1, 9) == "Vignette:" then
		local pose = s[7] or (Ambient.People.Poses[kind] or { "None" })[1]
		local at = cf
		if string.sub(pose, 1, 3) ~= "Sit" then
			at = CFrame.new(cf.X, ground(cf.Position), cf.Z) * cf.Rotation
		end
		person(at, pose, role)
		n += 1
	end
end
-- two walkers on the nearest sidewalk
local bestW, bestD = nil, 1e9
for _, w in Map.Walks do
	local path = R.path(w.pts, false)
	local _, d = R.nearest(path, FOCUS.X, FOCUS.Z)
	if d < bestD then
		bestW, bestD = { w = w, path = path }, d
	end
end
if bestW then
	for k = 1, 2 do
		local d0 = R.nearest(bestW.path, FOCUS.X, FOCUS.Z) + (k * 14 - 21)
		local x, z, dx, dz = R.sample(bestW.path, d0)
		local at = Vector3.new(x, ground(Vector3.new(x, bestW.w.y, z)), z)
		local dir = if k == 1 then Vector3.new(dx, 0, dz) else Vector3.new(-dx, 0, -dz)
		person(CFrame.lookAt(at, at + dir), "None", "Street")
	end
end
table.insert(report, n .. " people + 2 walkers")

---------------------------------------------------------------- a car on the nearest lane
local lib = RS:FindFirstChild("MTL_AmbientCars")
local tpl = lib and lib:FindFirstChild("SedanA")
if tpl then
	local best, bd, bl = nil, 1e9, nil
	for _, l in Map.Lanes do
		local path = R.path(l.pts, true, l.corners)
		local d, dist = R.nearest(path, FOCUS.X, FOCUS.Z)
		if dist < bd then
			best, bd, bl = d, dist, { l = l, path = path }
		end
	end
	if best and bl then
		local d = best + 30
		local fx, fz = R.sample(bl.path, d + 6)
		local rx, rz = R.sample(bl.path, d - 6)
		local c = Vector3.new((fx + rx) / 2, bl.l.y, (fz + rz) / 2)
		local car = tpl:Clone()
		local cf, size = car:GetBoundingBox()
		local toBottom = car:GetPivot():ToObjectSpace(cf * CFrame.new(0, -size.Y / 2, 0))
		-- SedanA's front is +Z, so look backwards along the lane
		car:PivotTo(CFrame.lookAt(c, c - Vector3.new(fx - rx, 0, fz - rz)) * toBottom:Inverse())
		for _, p in car:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				if p.Name == "Color" then
					p.Color = Color3.fromRGB(30, 50, 90)
				end
			end
		end
		car.Parent = preview
		table.insert(report, ("car %.0f studs from focus"):format(bd))
	end
end

---------------------------------------------------------------- pigeons
local pb, pd = nil, 1e9
for _, s in Map.Spots do
	if s[1] == "Pigeons" then
		local d = (Vector3.new(s[2], s[3], s[4]) - FOCUS).Magnitude
		if d < pd then
			pb, pd = s, d
		end
	end
end
if pb and pd < 140 then
	for i = 1, 7 do
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(0.5, 3)
		local p = Vector3.new(pb[2] + math.cos(a) * r, 0, pb[4] + math.sin(a) * r)
		p = Vector3.new(p.X, ground(Vector3.new(p.X, pb[3], p.Z)), p.Z)
		local col = Ambient.Birds.Colors[(i % #Ambient.Birds.Colors) + 1]
		local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local body = Instance.new("Part")
		body.Anchored = true
		body.CanCollide = false
		body.Size = Vector3.new(0.55, 0.5, 0.95)
		body.Color = col
		body.CFrame = CFrame.new(p + Vector3.new(0, 0.25, 0)) * yaw * CFrame.Angles(math.rad(-10), 0, 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		body.Parent = preview
		local head = Instance.new("Part")
		head.Anchored = true
		head.CanCollide = false
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(0.34, 0.34, 0.34)
		head.Color = col:Lerp(Color3.fromRGB(70, 90, 96), 0.35)
		head.CFrame = CFrame.new(p) * yaw * CFrame.new(0, 0.55, -0.42)
		head.Parent = preview
	end
	table.insert(report, ("pigeons %.0f studs from focus"):format(pd))
end

---------------------------------------------------------------- night windows
if NIGHT then
	local lit = 0
	for i, w in Map.Windows do
		local st = R.windowState(i, 21, 3, Ambient.Windows)
		if st > 0 then
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Size = Vector3.new(math.max(w[5] - 0.2, 0.6), math.max(w[6] - 0.2, 0.6), 0.05)
			p.CFrame = CFrame.new(w[1], w[2], w[3]) * CFrame.Angles(0, math.rad(w[4]), 0)
			p.Color = if st == 2 then Ambient.Windows.TV elseif R.hash(i, 5) < 0.3 then Ambient.Windows.Warm2 else Ambient.Windows.Warm
			p.Transparency = 0.08
			p.Parent = preview
			lit += 1
		end
	end
	table.insert(report, lit .. " lit windows")
end
return table.concat(report, " | ")
