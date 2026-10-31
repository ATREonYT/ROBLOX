-- Offline: builds the blocky cannons, then runs src/tools/BuildWorld1.lua in Lune's Roblox DOM
-- (on a stand-in lobby) and writes every training booth's parts to JSON for render_booths.py.
-- lune run tools/preview/dump_booths.luau <out.json>
-- Lune has no Model pivot/scale methods, so simple versions are added below.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local function parts(m)
	local out = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	return out
end

local function bbox(m)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts(m) do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local c = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
					hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
				end
			end
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

local function pivot(m)
	if m.PrimaryPart then
		return m.PrimaryPart.CFrame
	end
	return (bbox(m))
end

roblox.implementMethod("Model", "GetBoundingBox", bbox)
roblox.implementMethod("Model", "GetPivot", pivot)
roblox.implementMethod("Model", "PivotTo", function(m, cf)
	local delta = cf * pivot(m):Inverse()
	for _, p in parts(m) do
		p.CFrame = delta * p.CFrame
	end
end)
roblox.implementMethod("Model", "GetScale", function(m)
	return m:GetAttribute("_Scale") or 1
end)
roblox.implementMethod("Model", "ScaleTo", function(m, s)
	local f = s / (m:GetAttribute("_Scale") or 1)
	local o = pivot(m).Position
	for _, p in parts(m) do
		local cf = p.CFrame
		p.Size *= f
		p.CFrame = cf - cf.Position + o + (cf.Position - o) * f
	end
	m:SetAttribute("_Scale", s)
end)
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
game:GetService("ServerStorage")
local cannons = Instance.new("Folder")
cannons.Name = "Cannons"
cannons.Parent = rs
local gc = Instance.new("ModuleScript")
gc.Name = "GameConfig"
gc.Parent = rs

-- stand-in lobby: same centre and floor height as the real one in Studio
local map1b = Instance.new("Model")
map1b.Name = "map1b"
map1b.Parent = workspace
local ssm = Instance.new("Model")
ssm.Name = "StoneSkipMap"
ssm.Parent = map1b
local lobby = Instance.new("Model")
lobby.Name = "Lobby"
lobby.Parent = ssm
local floor = Instance.new("Part")
floor.Size = Vector3.new(193.6, 1, 138.7)
floor.CFrame = CFrame.new(-56.2, 7.95, -144.25)
floor.Parent = lobby

-- Lune 0.10.5's CFrame.lookAt is wrong when looking straight along -Z (it faces +Z) and gives NaN
-- when looking straight up or down (the truss posts), so build it the way Studio does
local LuneCFrame = setmetatable({
	lookAt = function(at, target, up)
		local d = (target - at).Unit
		up = up or Vector3.new(0, 1, 0)
		if math.abs(d:Dot(up)) > 0.9999 then
			up = Vector3.new(0, 0, -math.sign(d.Y))
		end
		local right = d:Cross(up).Unit
		return CFrame.fromMatrix(at, right, right:Cross(d))
	end,
}, { __index = CFrame })

local env = setmetatable({
	game = game, workspace = workspace, Instance = Instance, Vector3 = Vector3, CFrame = LuneCFrame,
	Color3 = roblox.Color3, Enum = roblox.Enum, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
	Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, UDim = roblox.UDim, Font = roblox.Font,
	warn = print,
	-- Lune has no RaycastParams or Random: a stand-in for each (the stand-in lobby has nothing to hit anyway)
	RaycastParams = { new = function()
		return {}
	end },
	Random = { new = function(seed)
		local state = (seed or 1) % 2147483647
		local function nxt()
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * nxt()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nxt() * (b - a + 1))
			end,
		}
	end },
}, { __index = _G })
local config = luau.load(fs.readFile("src/shared/GameConfig.lua"), { debugName = "GameConfig", environment = env })()
env.require = function()
	return config
end

luau.load(fs.readFile("src/tools/BuildBlockyCannons.lua"), { debugName = "BuildBlockyCannons", environment = env })()
-- the Grand Cannon / launch zone part after the booths needs the real map; the booths are built by then
local ok, err = pcall(luau.load(fs.readFile("src/tools/BuildWorld1.lua"), { debugName = "BuildWorld1", environment = env }))
if not ok then
	print("(after the booths) " .. tostring(err))
end

local function encode(list, p, extra)
	local shape = p.ClassName == "WedgePart" and "Wedge" or (p.ClassName == "Part" and p.Shape.Name or "Block")
	local row = {
		shape = shape,
		size = { p.Size.X, p.Size.Y, p.Size.Z },
		cf = { p.CFrame:GetComponents() },
		color = { p.Color.R, p.Color.G, p.Color.B },
		neon = p.Material == roblox.Enum.Material.Neon,
		alpha = p.Transparency,
	}
	for k, v in extra or {} do
		row[k] = v
	end
	table.insert(list, row)
end

local out = {}
-- the cannonball stand with a stand-in ball on each pad, coloured like BallStand.lua does
-- (the first ball picked: green pad; the rest purple)
do
	local ok2, err2 = pcall(luau.load(fs.readFile("src/tools/BuildCannonBallStand.lua"), { debugName = "BuildCannonBallStand", environment = env }))
	if not ok2 then
		print("(stand) " .. tostring(err2))
	end
	local stand = workspace:FindFirstChild("CannonBallStand")
	if stand then
		local list, pads = {}, {}
		for _, p in stand:GetChildren() do
			if p.Name == "PadBase" then
				table.insert(pads, p)
			end
		end
		table.sort(pads, function(a, b)
			if math.abs(a.CFrame.Position.Y - b.CFrame.Position.Y) > 1 then
				return a.CFrame.Position.Y < b.CFrame.Position.Y
			end
			return a.CFrame.Position.X < b.CFrame.Position.X
		end)
		local GREEN, PURPLE = roblox.Color3.fromRGB(64, 220, 104), roblox.Color3.fromRGB(160, 90, 245)
		for _, p in stand:GetChildren() do
			if p:IsA("BasePart") then
				if string.sub(p.Name, 1, 5) == "State" then
					local d = p.CFrame.Position - pads[1].CFrame.Position
					p.Color = (math.abs(d.Y) < 1.5 and roblox.Vector2.new(d.X, d.Z).Magnitude < 3.2) and GREEN or PURPLE
				end
				encode(list, p)
			end
		end
		for i, pad in pads do
			local b = config.Balls[i]
			if b then
				local c = pad.CFrame.Position + Vector3.new(0, pad.Size.Z / 2 + 0.5 + 1.3, 0)
				local core = Instance.new("Part")
				core.Shape = roblox.Enum.PartType.Ball
				core.Size = Vector3.new(2.6, 2.6, 2.6)
				core.CFrame = CFrame.new(c)
				core.Color = b.Color
				encode(list, core)
				local band = Instance.new("Part")
				band.Shape = roblox.Enum.PartType.Cylinder
				band.Size = Vector3.new(0.45, 2.7, 2.7)
				band.CFrame = CFrame.new(c) * CFrame.Angles(0, math.rad(90), 0)
				band.Color = b.Band
				encode(list, band)
			end
		end
		out.stand = { parts = list, x = 0 }
	end
end
-- the start of the water: your cannon (placed like Effects.placeMyCannon), the Launch Zone,
-- and stand-in lobby floor and sea so the scene reads
do
	local list = {}
	local spot = workspace:FindFirstChild("MyCannonSpot")
	local zone = workspace:FindFirstChild("LaunchZone")
	if spot and zone then
		local dir = config.LAUNCH_DIRECTION.Unit
		local m = cannons.Cannon01_Starter:Clone()
		m:PivotTo(CFrame.lookAt(Vector3.new(0, 0, 0), -dir))
		local _, size = m:GetBoundingBox()
		m:ScaleTo(9 / size.Y)
		local cf, sc = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (spot.CFrame.Position - Vector3.new(cf.Position.X, cf.Position.Y - sc.Y / 2, cf.Position.Z)))
		for _, p in parts(m) do
			encode(list, p)
		end
		encode(list, zone)
		-- floor and sea as small tiles (the renderer drops faces that reach behind the camera),
		-- flagged ground so they are always drawn first
		local fy = spot.CFrame.Position.Y
		local function tiles(x0, x1, z0, z1, y, step, color)
			for x = x0, x1 - 0.01, step do
				for z = z0, z1 - 0.01, step do
					local t = Instance.new("Part")
					t.Size = Vector3.new(math.min(step, x1 - x), 0.2, math.min(step, z1 - z))
					t.CFrame = CFrame.new(x + t.Size.X / 2, y, z + t.Size.Z / 2)
					t.Color = color
					encode(list, t, { ground = true })
				end
			end
		end
		tiles(-153, 41, -214, -75, fy - 0.1, 8, roblox.Color3.fromRGB(205, 200, 225))
		tiles(-753, -153, -192, -96, 5.4, 24, roblox.Color3.fromRGB(40, 170, 225))
	end
	out.start = { parts = list, x = 0 }
end
for _, st in workspace.TrainingStations:GetChildren() do
	local list = {}
	for _, p in parts(st) do
		if p.Transparency < 0.95 then
			local shape = p.ClassName == "WedgePart" and "Wedge" or (p.ClassName == "Part" and p.Shape.Name or "Block")
			table.insert(list, {
				shape = shape,
				size = { p.Size.X, p.Size.Y, p.Size.Z },
				cf = { p.CFrame:GetComponents() },
				color = { p.Color.R, p.Color.G, p.Color.B },
				neon = p.Material == roblox.Enum.Material.Neon,
				alpha = p.Transparency,
				cannon = p:FindFirstAncestor("Cannon") ~= nil,
				name = p.Name,
				spin = p:FindFirstAncestor("Spin") ~= nil,
				belt = p:FindFirstChild("BeltStuds") ~= nil,
			})
			-- the console screen's words (scene3d draws them on the screen)
			local gui = p:FindFirstChildOfClass("SurfaceGui")
			if gui then
				local lines = {}
				for _, t in gui:GetChildren() do
					if t:IsA("TextLabel") then
						table.insert(lines, { text = t.Text, y = t.Position.Y.Scale, h = t.Size.Y.Scale, color = { t.TextColor3.R, t.TextColor3.G, t.TextColor3.B } })
					end
				end
				list[#list].gui = { face = gui.Face.Name, lines = lines }
			end
		end
	end
	-- lights and particle sources, for scene3d's preview
	local lights, motes = {}, {}
	for _, d in st:GetDescendants() do
		if d:IsA("PointLight") and d.Parent:IsA("BasePart") then
			local c = d.Parent.CFrame.Position
			table.insert(lights, { pos = { c.X, c.Y, c.Z }, color = { d.Color.R, d.Color.G, d.Color.B }, brightness = d.Brightness, range = d.Range })
		elseif d:IsA("ParticleEmitter") and d.Parent:IsA("BasePart") then
			local k = d.Color.Keypoints
			table.insert(motes, {
				cf = { d.Parent.CFrame:GetComponents() },
				size = { d.Parent.Size.X, d.Parent.Size.Y, d.Parent.Size.Z },
				colors = { { k[1].Value.R, k[1].Value.G, k[1].Value.B }, { k[#k].Value.R, k[#k].Value.G, k[#k].Value.B } },
				rate = d.Rate,
				life = (d.Lifetime.Min + d.Lifetime.Max) / 2,
				speed = (d.Speed.Min + d.Speed.Max) / 2,
				size0 = d.Size.Keypoints[1].Value,
			})
		end
	end
	local axis = st:FindFirstChild("Axis", true)
	out[tostring(st:GetAttribute("StationId"))] = {
		parts = list,
		x = st.PrimaryPart.CFrame.Position.X,
		lights = lights,
		motes = motes,
		axis = axis and { axis.CFrame:GetComponents() } or nil,
		spinPeriod = axis and axis.Parent:GetAttribute("SpinPeriod") or nil,
		stand = { st.StandPoint.CFrame:GetComponents() },
	}
end
fs.writeFile(process.args[1], serde.encode("json", out))
print("dumped " .. #workspace.TrainingStations:GetChildren() .. " booths")
