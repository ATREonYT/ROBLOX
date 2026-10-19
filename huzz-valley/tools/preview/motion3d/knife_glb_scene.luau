-- Every knife as the owner's .glb (owner, Oct 19: "use the glb file to get them one to one, whenever you wear or
-- use them"): his .glb next to what the game showed before and what it shows now, drawn from the game's real
-- instances, not from the .glb:
--   * his imported knives (assets/knives/HuzzKnives.rbxm, before = the file as it was, OLD_KNIVES; now = the file):
--     each MeshPart is drawn with the .glb part it was made from, where the part sits, in the part's own colour and
--     material (a part still wearing the import's colour picture shows that colour, not glowing);
--   * the Game Pass knives: before = the plain-part stand-in (Shared/KnifeShapes, as boxes); now = the stand-in
--     dressed by Gameplay/KnifeDress from Shared/KnifeGlb (each dressed MeshPart drawn with its baked mesh, decoded
--     by KnifeDress itself, at its size; the stand's glow shell too).
-- Still 0: 8 knives, each as glb | before | now, broad side on. Still 1: on the back (Dragon's Maw) and in the hand
-- (Twin Fang), glb | before | now, placed as HuzzServer/KnifeService places them.
-- From huzz-valley/: python3 -I tools/knives/knife_meshes.py /tmp/knives.json;
--   git show HEAD:huzz-valley/assets/knives/HuzzKnives.rbxm > /tmp/old.rbxm; then from the repo root:
-- KNIFE_MESHES=/tmp/knives.json OLD_KNIVES=/tmp/old.rbxm MOTION3D_KEEP=<dir> sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/knife_glb_scene.luau /tmp/x.mp4   (stills <dir>/still_0.png and still_1.png)
-- The one picture: ffmpeg -i <dir>/still_0.png -i <dir>/still_1.png -filter_complex "vstack,scale=1280:-1" -q:v 3 \
--   huzz-valley/docs/previews/knives-glb-vs-ours.jpg
-- (His imported knives' "before" colours are the file's: a part still wearing the import's colour picture is drawn in
-- that picture's colour, not glowing; Studio is the judge of exactly how those looked.)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua")
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")

pcall(function() -- (Lune doesn't ship Attachment.Position)
	roblox.implementProperty("Attachment", "Position", function(self) return self.CFrame.Position end, function(self, v)
		self.CFrame = self.CFrame - self.CFrame.Position + v
	end)
end)

local glbMeshes = serde.decode("json", fs.readFile(process.env.KNIFE_MESHES or error("set KNIFE_MESHES")))
local boxes = serde.decode("json", fs.readFile("huzz-valley/tools/knives/knife_boxes.json"))
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
local nodeIndex = {} -- [key][box table] = its index (knife_boxes and knife_meshes list a knife's parts in one order)
for key, list in boxes do
	nodeIndex[key] = {}
	for i, n in list do nodeIndex[key][n] = i end
end
local Colour = luau.load(fs.readFile("huzz-valley/tools/knives/colour_knives.luau"), { debugName = "colour_knives", environment = {
	require = function(name)
		if name == "@lune/process" then return { args = { "--module" }, env = {} } end
		return require(name)
	end,
} })()
local Dress = luau.load(fs.readFile("huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/KnifeDress.lua"), { debugName = "KnifeDress",
	environment = { Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, Instance = Instance } })()

local nowFolder = roblox.deserializeModel(fs.readFile("huzz-valley/assets/knives/HuzzKnives.rbxm"))[1]
local oldFolder = roblox.deserializeModel(fs.readFile(process.env.OLD_KNIVES or error("set OLD_KNIVES")))[1]

-- the real KnifeService, his knives in ServerStorage (as tests/KnifeModels.spec)
local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
nowFolder.Parent = ServerStorage
local shared = { KnifeLook = KnifeLook, KnifeShapes = KnifeShapes,
	FxTexture = { get = function(n) return "tex:" .. n end, flipbook = function() end, ready = function() return false end } }
local KnifeService = luau.load(fs.readFile("huzz-valley/src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes" } } end },
	require = function(x) return shared[x] end, warn = function() end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
} })()

local GLB = "huzz-valley/src/ReplicatedStorage/Shared/KnifeGlb/"
local function bakedOf(key)
	local list, n = {}, 1
	while fs.isFile(GLB .. key .. "_" .. n .. ".lua") do
		local g = luau.load(fs.readFile(GLB .. key .. "_" .. n .. ".lua"), { debugName = key .. "_" .. n })()
		g.id = key .. "_" .. n
		table.insert(list, g)
		n += 1
	end
	return list
end

-- the mesh library render.mjs draws from: his .glb knives, single .glb parts in a given look, the baked dress meshes
local lib = {}
for key, parts in glbMeshes do lib["glb:" .. key] = parts end
local function nodeMesh(key, i, col, glow)
	local name = string.format("n:%s:%d:%s:%d", key, i, col, if glow then 1 else 0)
	if not lib[name] then
		local p = glbMeshes[key][i]
		lib[name] = { { pos = p.pos, col = "#" .. col, glow = glow, metal = p.metal, node = p.node } }
	end
	return name
end
local function dressMesh(g)
	local name = "d:" .. g.id
	if not lib[name] then
		local verts, tris = Dress.unpack(g)
		local pos = table.create(#tris * 9)
		for _, t in tris do
			for _, i in t do
				local v = verts[i]
				table.insert(pos, v.X); table.insert(pos, v.Y); table.insert(pos, v.Z)
			end
		end
		lib[name] = { { pos = pos, col = "#" .. g.col, glow = g.glow, metal = 0, node = if g.blade then "blade" else "part" } }
	end
	return name
end

local function comps(cf)
	local c = { cf:GetComponents() }
	return { c[1], c[2], c[3] }, { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }
end
-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function glbAt(key, handleCF)
	local k = baked[key]
	local per = k.studs / k.length
	local p, r = comps(handleCF * CFrame.new(0, -k.grip * per, 0) * TURN)
	return { m = "glb:" .. key, p = p, r = r, s = per }
end

-- Draws a knife model as the game has it, its Handle at handleCF: { meshes }, { boxes }
local function draw(model, key, handleCF, before)
	local handle = model:FindFirstChild("Handle", true)
	local meshes, plain = {}, {}
	local k = baked[key]
	local per = k.studs / k.length
	local matched, turn = {}, 0
	if boxes[key] and model:FindFirstChildWhichIsA("MeshPart", true) then
		local list
		list, turn = Colour.match(model, boxes[key])
		for _, m in list do matched[m.part] = m end
	end
	local R = CFrame.Angles(0, turn * math.pi / 2, 0)
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or d == handle or d.Transparency >= 1 then continue end
		local neon = d.Material == roblox.Enum.Material.Neon
		local meshId = d:GetAttribute("Mesh")
		if meshId then -- a dressed part: its baked mesh, scaled to the part
			local g = nil
			for _, x in bakedOf(key) do if x.id == meshId then g = x end end
			local span = Vector3.new(g.hi[1] - g.lo[1], g.hi[2] - g.lo[2], g.hi[3] - g.lo[3]):Max(Vector3.one * 0.01)
			local p, r = comps(handleCF * handle.CFrame:ToObjectSpace(d.CFrame))
			local s = d.Size / span
			local entry = { m = dressMesh(g), p = p, r = r, s = { s.X, s.Y, s.Z } }
			if d.Name == "GlbShell" then entry.shell = { c = "#" .. d.Color:ToHex():lower(), a = 1 - d.Transparency } end
			table.insert(meshes, entry)
		elseif matched[d] then -- one of his meshes: its .glb part where it sits, in its own colour
			local m = matched[d]
			local col, glow = d.Color:ToHex():lower(), neon
			local okT, tc = pcall(function() return tostring((d :: any).TextureContent) end)
			if before and okT and string.find(tc, "rbxasset") then col = m.node.col end -- (its colour picture)
			local cf = handleCF * CFrame.new(m.gap) * R * CFrame.new(0, -k.grip * per, 0) * TURN
			local p, r = comps(cf)
			table.insert(meshes, { m = nodeMesh(key, nodeIndex[key][m.node], col, glow), p = p, r = r, s = per })
		else -- a plain part (the stand-in)
			table.insert(plain, { CFrame = handleCF * handle.CFrame:ToObjectSpace(d.CFrame), Size = d.Size, Color = "#" .. d.Color:ToHex():lower(),
				Neon = neon or nil, Shape = if d:IsA("Part") and d.Shape == roblox.Enum.PartType.Cylinder then "cyl" else nil })
		end
	end
	return meshes, plain
end

local function fakeMake(g)
	local p = Instance.new("MeshPart")
	p:SetAttribute("Mesh", g.id)
	return p
end
local PASS = {}
for _, key in { "CrimsonRequiem", "HollowEclipse", "CelestialSeraph", "DragonsMaw", "FrostboundOath" } do PASS[key] = true end
-- the three ways a knife shows: "glb" (nil model), "before", "now"
local function modelOf(key, how)
	if PASS[key] then
		local m = KnifeService.template(CoinShop.get(key))
		if how == "now" then
			local gs = bakedOf(key)
			assert(Dress.dress(m, gs, fakeMake), "dress failed for " .. key)
		end
		return m
	end
	return (if how == "before" then oldFolder else nowFolder):FindFirstChild(key):Clone()
end

local scene = Scene.new()
local frameBoxes = { {}, {} }
local function addPlain(frame, list)
	for _, b in list do
		local box = scene:addBox(b.CFrame, b.Size, b.Color)
		box.Neon, box.Shape, box.Hidden = b.Neon, b.Shape, true
		table.insert(frameBoxes[frame], box)
	end
end
local function show(frame)
	for f, list in frameBoxes do
		for _, b in list do b.Hidden = f ~= frame end
	end
end

-- Still 0: the sheet
local SHEET = { "TwinFang", "VoidFang", "AbyssEclipse", "SpinKnife", "CrimsonRequiem", "HollowEclipse", "CelestialSeraph", "DragonsMaw", "FrostboundOath" }
local HOW = { "glb", "before", "now" }
local meshes0, labels0 = {}, {}
local COLS, GAP, GROUP, ROW = 5, 1.25, 5.0, 5.2
for i, key in SHEET do
	local row, col = (i - 1) // COLS, (i - 1) % COLS
	local z0 = (col - (COLS - 1) / 2) * GROUP
	local y0 = 7 - row * ROW
	for j, how in HOW do
		-- broad side to the camera (+X looks at the knife's Z width): Handle +Y up, grip at y0
		local handleCF = CFrame.new(0, y0, z0 + (j - 2) * GAP) * CFrame.Angles(0, 0, 0)
		if how == "glb" then
			table.insert(meshes0, glbAt(key, handleCF))
		else
			local m, plain = draw(modelOf(key, how), key, handleCF, how == "before")
			for _, e in m do table.insert(meshes0, e) end
			addPlain(1, plain)
		end
		table.insert(labels0, { p = { 0, y0 - 1.15, z0 + (j - 2) * GAP }, text = how, h = 0.32, c = if how == "now" then "#7dff9a" elseif how == "before" then "#ff9a8a" else "#ffffff" })
	end
	table.insert(labels0, { p = { 0, y0 - 1.6, z0 }, text = baked[key].name, h = 0.4, c = "#ffe28a" })
end
show(1)
scene:frame(Vector3.new(-25, 4.9, 0), Vector3.new(0, 4.9, 0), { meshes = meshes0, labels = labels0, fov = 30,
	caption = "Each knife: his .glb | what the game showed before | now (drawn from the game's own parts)" })

-- Still 1: worn on the back (Dragon's Maw) and in the hand (Twin Fang), each glb | before | now
local lib15 = Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib15 end
local Idle = KFS.load(lib15:FindFirstChild("Idle", true))
local meshes1, labels1 = {}, {}
local SET = {
	{ key = "DragonsMaw", how = "glb", where = "back" }, { key = "DragonsMaw", how = "before", where = "back" }, { key = "DragonsMaw", how = "now", where = "back" },
	{ key = "TwinFang", how = "glb", where = "hand" }, { key = "TwinFang", how = "before", where = "hand" }, { key = "TwinFang", how = "now", where = "hand" },
}
for i, s in SET do
	local rig = scene:addRig(Rig.r15("Body" .. i, { shirt = if s.where == "back" then "#e6e6ee" else "#3a6fd8", pants = "#2b2f3a" }))
	local x = (i - 3.5) * 3.3 + (if s.where == "hand" then 1.4 else -1.4)
	-- (the back from behind; the hand from the front, turned a little so the knife in the right hand isn't behind the body)
	rig.root.CFrame = CFrame.new(x, Rig.REST_HEIGHT, 0) * CFrame.Angles(0, math.rad(if s.where == "back" then 0 else 205), 0)
	KFS.apply(Idle, rig, 0.8, 1)
	Rig.fk(rig)
	local model = modelOf(s.key, if s.how == "glb" then "now" else s.how) -- (the glb one sits where ours does)
	local handle = model:FindFirstChild("Handle", true)
	local grip = handle:FindFirstChild("Grip")
	local gripCF = if grip then grip.CFrame else CFrame.identity
	local handleCF
	if s.where == "back" then
		local shape = KnifeService.shapeOf(model)
		local wear = KnifeService.wearOf(model, CoinShop.get(s.key), shape)
		local torso = rig.parts[KnifeLook.mountPart(wear, false)]
		handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, shape) * gripCF:Inverse()
	else
		handleCF = rig.parts.RightHand.CFrame * KnifeLook.handC0(Vector3.new(0, -0.15, 0), KnifeService.reachOf(model, handle)) * gripCF:Inverse()
	end
	if s.how == "glb" then
		table.insert(meshes1, glbAt(s.key, handleCF))
	else
		local m, plain = draw(model, s.key, handleCF, s.how == "before")
		for _, e in m do table.insert(meshes1, e) end
		addPlain(2, plain)
	end
	table.insert(labels1, { p = { x, 6.3, 0 }, text = s.how, h = 0.45, c = if s.how == "now" then "#7dff9a" elseif s.how == "before" then "#ff9a8a" else "#ffffff" })
end
table.insert(labels1, { p = { -6.3, 7.0, 0 }, text = "Dragon's Maw on the back", h = 0.5, c = "#ffe28a" })
table.insert(labels1, { p = { 6.3, 7.0, 0 }, text = "Twin Fang in the hand", h = 0.5, c = "#ffe28a" })
show(2)
scene:frame(Vector3.new(0, 4.4, 17), Vector3.new(0, 3.6, 0), { meshes = meshes1, labels = labels1, fov = 50,
	caption = "Worn and held, placed as HuzzServer/KnifeService places them: his .glb | before | now" })

local libPath = (process.env.MOTION3D_DIR or ".") .. "/knife_glb_meshes.json"
fs.writeFile(libPath, serde.encode("json", lib))
scene:save(nil, 30, 1600, 900, { stills = { 0, 1 }, meshFile = libPath, sky = "#20202c", ground = "#3a3a46" })
print("knife glb scene: " .. #meshes0 .. " + " .. #meshes1 .. " meshes")
