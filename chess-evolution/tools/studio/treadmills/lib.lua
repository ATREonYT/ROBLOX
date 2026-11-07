-- [Treadmills] shared builder for the chess treadmills (Alex's six reference machines, Nov 7).
-- Lives in Studio as ServerStorage.TreadmillTools.Lib. Each machine file starts with
-- `local T = require(game.ServerStorage.TreadmillTools.Lib)`; paste it in the Command Bar (Edit mode). It rebuilds Map.Stations.<id>.Visual
-- from the live Deck, keeps Deck, Align, Belt, Screen, LabelAnchor and every attribute, and backs up the
-- old Visual to ServerStorage.TreadmillBackup.<id> the first time.
-- Local frame: origin = floor under the Deck centre, -Z = console end, +Z = open entry, belt top at y 0.8.
local T = {}

T.rgb = Color3.fromRGB
T.SP = Enum.Material.SmoothPlastic
T.NEON = Enum.Material.Neon
T.METAL = Enum.Material.Metal
T.GLASS = Enum.Material.Glass

function T.begin(id: string)
	local station = workspace.Map.Stations:FindFirstChild(id)
	assert(station, "[Treadmills] no station " .. id)
	local deck = station:FindFirstChild("Deck") :: BasePart
	local origin = deck.CFrame * CFrame.new(0, -deck.Size.Y / 2, 0)
	local old = station:FindFirstChild("Visual")
	local backupRoot = game.ServerStorage:FindFirstChild("TreadmillBackup") or Instance.new("Folder")
	backupRoot.Name = "TreadmillBackup"
	backupRoot.Parent = game.ServerStorage
	if old then
		if not backupRoot:FindFirstChild(id) then
			old.Name = id
			old.Parent = backupRoot
		else
			old:Destroy()
		end
	end
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the whole machine streams in together
	local groups = {}
	for _, g in ipairs({ "Chassis", "BeltVisual", "Console", "Trim", "VFX" }) do
		local m = Instance.new("Model")
		m.Name = g
		m.Parent = visual
		groups[g] = m
	end
	local B = { id = id, station = station, origin = origin, visual = visual, g = groups, count = 0 }
	-- invisible root with the named attachments
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.CFrame = origin
	root.Parent = groups.Chassis
	B.root = root
	visual.PrimaryPart = root
	return B
end

local function cf(B, pos: Vector3, rot: Vector3?)
	local r = rot or Vector3.zero
	return B.origin * CFrame.new(pos) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end
T.cf = cf

-- part(B, group, name, shape, size, pos, color, material?, rot?, opts?)
-- shape: "Block" | "Cylinder" (axis X) | "Ball" | "Wedge" | "Corner"
function T.part(B, group: string, name: string, shape: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: Vector3?, opts: { [string]: any }?)
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif shape == "Corner" then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
		p.Shape = Enum.PartType[shape]
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf(B, pos, rot)
	p.Color = color
	p.Material = material or T.SP
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = (material ~= T.NEON)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		for k, v in pairs(opts) do
			if k == "Accent" then
				p:SetAttribute("Accent", v)
			else
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = B.g[group]
	B.count += 1
	return p
end

-- mirrored pair: fn(s) with s = -1 (left) and 1 (right)
function T.pair(fn)
	fn(-1)
	fn(1)
end

function T.attach(B, name: string, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = B.root
	return a
end

-- vertical cylinder helper (Roblox cylinders run along X, so turn them upright)
function T.vcyl(B, group, name, h: number, d: number, pos: Vector3, color, material, opts)
	return T.part(B, group, name, "Cylinder", Vector3.new(h, d, d), pos, color, material, Vector3.new(0, 0, 90), opts)
end
-- cylinder pointing along Z (faces the entry)
function T.zcyl(B, group, name, len: number, d: number, pos: Vector3, color, material, opts)
	return T.part(B, group, name, "Cylinder", Vector3.new(len, d, d), pos, color, material, Vector3.new(0, 90, 0), opts)
end

-- a slab with rounded top corners (flat bottom), facing +Z: w wide, h tall, d deep, corner radius r
function T.roundTop(B, group: string, name: string, w: number, h: number, d: number, r: number, c: Vector3, color: Color3, material: Enum.Material?)
	T.part(B, group, name, "Block", Vector3.new(w, h - r, d), c + Vector3.new(0, -r / 2, 0), color, material)
	T.part(B, group, name, "Block", Vector3.new(w - 2 * r, r, d), c + Vector3.new(0, h / 2 - r / 2, 0), color, material)
	for _, s in ipairs({ -1, 1 }) do
		T.zcyl(B, group, name, d, 2 * r, c + Vector3.new(s * (w / 2 - r), h / 2 - r, 0), color, material)
	end
end

-- moving belt lines the client scrolls toward the entry
function T.beltLines(B, color: Color3, width: number, z0: number, z1: number, spacing: number)
	local n = math.floor((z1 - z0) / spacing)
	for i = 0, n - 1 do
		T.part(B, "BeltVisual", "Slat", "Block", Vector3.new(width, 0.04, 0.16), Vector3.new(0, 0.82, z0 + i * spacing), color, T.SP)
	end
	B.visual:SetAttribute("BeltZ0", z0)
	B.visual:SetAttribute("BeltZ1", z0 + n * spacing)
end

-- Restyle the gameplay anchors without moving their role: Belt becomes the dark running belt,
-- Screen becomes the recessed console panel (its ConsoleLight and FX attachment stay inside it).
function T.styleAnchors(B, beltColor: Color3, screenSize: Vector3, screenPos: Vector3, screenRot: Vector3?, screenColor: Color3)
	local belt = B.station:FindFirstChild("Belt") :: BasePart
	belt.Color = beltColor
	belt.Material = T.SP
	belt.Transparency = 0
	local screen = B.station:FindFirstChild("Screen") :: BasePart
	screen.Size = screenSize
	screen.CFrame = cf(B, screenPos, screenRot)
	screen.Color = screenColor
	screen.Material = T.SP
	screen.Transparency = 0
	local light = screen:FindFirstChild("ConsoleLight") :: PointLight?
	if light then
		light.Range = 7
	end
end

function T.finish(B)
	B.visual.Parent = B.station
	B.station:SetAttribute("VisualVersion", "chess-ref-1")
	print(("[Treadmills] %s built: %d parts"):format(B.id, B.count))
	return B.visual
end

return T
