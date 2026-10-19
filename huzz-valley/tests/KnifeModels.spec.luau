-- lune run tests/KnifeModels.spec.luau   (from huzz-valley/)
-- Every knife is the owner's .glb model, wherever it shows (owner, Oct 19: "the knifes dont even have their shapes,
-- they all dont look good, please fix them and use the glb file to get them one to one, whenever you wear or use
-- them" / "all of the knifes"):
--   * his 30 imported models (assets/knives/HuzzKnives.rbxm): every part is one of his meshes (never a plain box),
--     sits where its .glb part sits (Handle space, tools/knives/knife_boxes.json; as imported or half a turn round,
--     never a quarter: the blade's flat across the back and the fist), and has that part's look (owner, Oct 19: "they
--     dont look as good as in the glb file"): his import's own glow (84 SurfaceAppearances with an emissive mask, on
--     15 knives) kept on his glowing parts, Neon only on glowing parts without one, every other part in its .glb
--     colour and the Roblox material nearest its metallic and roughness (Shared/KnifeLook.glbMaterial: Metal for his
--     blades and guards), no leftover texture (tools/knives/colour_knives.luau); one rule in KnifeLook, his helper's
--     lookOf (as the file shows) and the colouring tool;
--   * every knife key, in hand (give), worn (giveBack) and on a stand (display): its blade is his mesh, or for a Game
--     Pass knife without his import, the plain stand-in tagged for the .glb dress (Shared/KnifeGlb) that has a blade
--     mesh: no knife key ends up with a plain block for its blade and nothing to dress it;
--   * Shared/KnifeGlb (tools/knives/bake_pass_meshes.py): each pass knife's meshes decode, stay inside Roblox's
--     EditableMesh limits (60,000 vertices, 20,000 triangles a mesh), reach the same box as his .glb and carry its
--     colours;
--   * Gameplay/KnifeDress puts them on: one part per mesh in its .glb place times the knife's Stretch (a stand's big
--     copy), welded to the Handle, in the mesh's material (the same rule), the stand-in hidden; all or nothing;
--   * nothing laid over his model: a stand's copy is scaled evenly (no widening), no GlowShell / GlbShell, no white
--     sheen glint on any knife.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

pcall(function() -- (Lune doesn't ship Attachment.Position)
	roblox.implementProperty("Attachment", "Position", function(self) return self.CFrame.Position end, function(self, v)
		self.CFrame = self.CFrame - self.CFrame.Position + v
	end)
end)

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local boxes = serde.decode("json", fs.readFile(ROOT .. "tools/knives/knife_boxes.json"))
local baked = {}
for _, k in serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json")) do baked[k.key] = k end
local PASS = { "CrimsonRequiem", "HollowEclipse", "CelestialSeraph", "DragonsMaw", "FrostboundOath" }
local isPass = {}
for _, k in PASS do isPass[k] = true end

-- the colouring tool's matcher (the same rule the file was coloured by)
local Colour = luau.load(fs.readFile(ROOT .. "tools/knives/colour_knives.luau"), { debugName = "colour_knives", environment = {
	require = function(name)
		if name == "@lune/process" then return { args = { "--module" }, env = {} } end
		return require(name)
	end,
} })()

-- a part's mesh id ("" for none; Lune reads the newer MeshContent, Studio files may still carry MeshId)
local function meshOf(p): string
	if not p:IsA("MeshPart") then return "" end
	local okId, id = pcall(function() return p.MeshId end)
	local okC, content = pcall(function() return tostring(p.MeshContent) end)
	return (if okId and id then id else "") .. (if okC and content then content else "")
end

-- 0. one look rule: KnifeLook.glbMaterial, the colouring tool's lookOf (and SetupKnives', which made the file: 1.)
local same = true
for _, glow in { false, true } do
	for m = 0, 10 do
		for r = 0, 10 do
			local a, ar = KnifeLook.glbMaterial(m / 10, r / 10, glow)
			local b, br = Colour.lookOf(glow, m / 10, r / 10)
			if a ~= b or math.abs(ar - br) > 1e-6 then same = false end
		end
	end
end
check("KnifeLook.glbMaterial and colour_knives' lookOf are one rule", same)
check("polished metal is Metal with a little Reflectance", select(1, KnifeLook.glbMaterial(0.8, 0.25)) == "Metal" and select(2, KnifeLook.glbMaterial(0.8, 0.25)) > 0)
check("a matte grip is Plastic", KnifeLook.glbMaterial(0, 0.8) == "Plastic")
check("a glowing part is Neon", KnifeLook.glbMaterial(0.15, 0.4, true) == "Neon")

-- the SurfaceAppearances with an emissive mask in a file of knives
local function hisGlows(f)
	local n = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") and Colour.hisGlow(d) then n += 1 end
	end
	return n
end

-- 1. his 30 models: meshes, places, colours, looks
local folder = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
local received = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives-received.rbxm"))[1]
local kept, had = hisGlows(folder), hisGlows(received)
check(string.format("his import's own glow kept: %d of the %d glowing SurfaceAppearances he had", kept, had), kept == had and had == 84)
local his, metalParts = 0, 0
for _, model in folder:GetChildren() do
	local nodes = boxes[model.Name]
	check(model.Name .. " is a knife key with its .glb parts", nodes ~= nil and CoinShop.get(model.Name) ~= nil)
	if not nodes then continue end
	his += 1
	local handle = model:FindFirstChild("Handle")
	local plain, mesh, wrongCol, wrongLook, tex = 0, 0, 0, 0, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			if string.find(meshOf(p), "rbxassetid://%d+") then mesh += 1 else plain += 1 end
			local okT, t = pcall(function() return p.TextureID end)
			local okC, tc = pcall(function() return tostring(p.TextureContent) end)
			if (okT and t and t ~= "") or (okC and tc and string.find(tc, "rbxasset")) then tex += 1 end
		end
	end
	check(model.Name .. ": every part is one of his meshes (" .. plain .. " plain parts)", plain == 0 and mesh > 0)
	check(model.Name .. ": no leftover import textures", tex == 0)
	local list, turn, worst = Colour.match(model, nodes)
	check(model.Name .. ": as imported or half a turn round, not a quarter (turn " .. turn .. ")", turn % 2 == 0)
	check(string.format("%s: every part on its .glb spot (worst %.3f studs)", model.Name, worst), worst < 0.12)
	for _, m in list do
		local p, n = m.part, m.node
		if n.glow and Colour.hisGlow(p) then
			-- his own glow: his colour picture and emissive mask, under no Neon
			if p.Material == roblox.Enum.Material.Neon then wrongLook += 1 end
		else
			local mat, refl = KnifeLook.glbMaterial(n.metal, n.rough, n.glow)
			if p.Color:ToHex():lower() ~= n.col then wrongCol += 1 end
			if p:FindFirstChildOfClass("SurfaceAppearance") or p.Material.Name ~= mat or math.abs(p.Reflectance - refl) > 1e-3 then wrongLook += 1 end
			if mat == "Metal" then metalParts += 1 end
		end
	end
	local k = baked[model.Name]
	local per = k.studs / k.length
	local tip, base, grip = handle:FindFirstChild("TrailTip"), handle:FindFirstChild("TrailBase"), handle:FindFirstChild("Grip")
	check(model.Name .. ": Grip, TrailBase and TrailTip where the .glb's grip, guard and tip are",
		tip and base and grip and math.abs(tip.CFrame.Position.Y - (k.tip - k.grip) * per) < 0.05
		and math.abs(base.CFrame.Position.Y - (0 - k.grip) * per) < 0.05 and grip.CFrame.Position.Magnitude < 0.01)
	check(model.Name .. ": every part in its .glb colour (" .. wrongCol .. " not)", wrongCol == 0)
	check(model.Name .. ": every part in its .glb look: his glow kept, else Neon / Metal / Plastic by the .glb (" .. wrongLook .. " not)", wrongLook == 0)
end
check("all 30 of his models are in the file (" .. his .. ")", his == 30)
check("his metal parts are Metal (" .. metalParts .. ")", metalParts > 200)

-- 2. the real KnifeService, every knife key, every way it shows
local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
folder.Parent = ServerStorage
local FxTexture = { get = function(n) return "tex:" .. n end, flipbook = function() end, ready = function() return false end }
local shared = { KnifeLook = KnifeLook, FxTexture = FxTexture, KnifeShapes = KnifeShapes }
local fakeRS = { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes" } }
local env = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else fakeRS end },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	warn = function() end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
}
local KnifeService = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = env })()

local GLB = ROOT .. "src/ReplicatedStorage/Shared/KnifeGlb/"
local function meshesOf(key)
	local list, n = {}, 1
	while fs.isFile(GLB .. key .. "_" .. n .. ".lua") do
		table.insert(list, luau.load(fs.readFile(GLB .. key .. "_" .. n .. ".lua"), { debugName = key .. "_" .. n })())
		n += 1
	end
	return list
end

local function bladeOf(model)
	local best, size = nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(string.lower(d.Name), 1, 5) == "blade" then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > size then best, size = d, v end
		end
	end
	return best
end
-- a knife's blade is his mesh, or a stand-in tagged for the .glb dress with a blade mesh baked
local function hisBlade(model, key)
	local blade = bladeOf(model)
	if not blade then return false, "no blade" end
	if string.find(meshOf(blade), "rbxassetid://%d+") then return true end
	if model:GetAttribute("Glb") ~= key then return false, "a plain " .. blade.ClassName .. " blade, not tagged for the .glb dress" end
	local tagged = pcall(function() return model:HasTag("GlbKnife") end)
	for _, g in meshesOf(key) do
		if g.blade then return true end
	end
	return false, "tagged, but no baked blade mesh" .. (if tagged then "" else "")
end

local function body()
	local c = Instance.new("Model")
	for _, spec in { { "UpperTorso", Vector3.new(2, 1.6, 1), 3 }, { "LowerTorso", Vector3.new(2, 0.4, 1), 2 }, { "RightHand", Vector3.new(0.4, 0.3, 0.4), 1.6 } } do
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = spec[1], spec[2], CFrame.new(0, spec[3], 0)
		p.Parent = c
	end
	return c
end

local knives = 0
for _, item in CoinShop.Items do
	if item.Slot ~= "Knife" then continue end
	knives += 1
	local key = item.Key
	local c = body()
	KnifeService.giveBack(c, item)
	local worn = c:FindFirstChild("HuzzBackKnife")
	local ok, why = if worn then hisBlade(worn, key) else false, "nothing worn"
	check(key .. " worn: his blade (" .. tostring(why) .. ")", ok)
	KnifeService.give(c, item)
	local held = nil
	for _, d in c:GetChildren() do
		if d:IsA("Model") and d.Name ~= "HuzzBackKnife" then held = d end
	end
	ok, why = if held then hisBlade(held, key) else false, "nothing in hand"
	check(key .. " in hand: his blade (" .. tostring(why) .. ")", ok)
	local stand = KnifeService.display(item)
	ok, why = if stand then hisBlade(stand, key) else false, "no stand copy"
	check(key .. " on a stand: his blade (" .. tostring(why) .. ")", ok)
	if stand then
		local s = stand:GetAttribute("Stretch")
		check(key .. " stand copy carries its Stretch, even every way (his shape, bigger)", typeof(s) == "Vector3" and s.Y > 1.2
			and math.abs(s.X - s.Y) < 1e-3 and math.abs(s.Z - s.Y) < 1e-3)
	end
	local over = {}
	for _, m in { worn, held, stand } do
		local ok, list = pcall(function() return m:GetDescendants() end) -- (giving one knife takes the one before)
		for _, d in if ok then list else {} do
			if d.Name == "GlowShell" or d.Name == "KnifeSheen" then over[d.Name] = true end
		end
	end
	check(key .. ": nothing laid over his model (no glow shell, no sheen glint)", next(over) == nil)
	if isPass[key] then
		local t = KnifeService.template(item)
		check(key .. ": without his import, the stand-in is tagged for the .glb dress", t:GetAttribute("Glb") == key)
	end
end
check("35 knife keys checked (" .. knives .. ")", knives == 35)

-- 3. the baked .glb meshes of the 5 pass knives
local Dress = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/KnifeDress.lua"), { debugName = "KnifeDress", environment = {
	Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, Instance = Instance,
} })()
for _, key in PASS do
	local meshes = meshesOf(key)
	check(key .. ": baked .glb meshes", #meshes > 0)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local cols, looks, tris, inLimits, inRange, boxOk = {}, {}, 0, true, true, true
	for _, g in meshes do
		check(key .. " mesh belongs to it", g.key == key)
		inLimits = inLimits and g.nv <= 60000 and g.nt <= 20000
		local verts, faces, mid = Dress.unpack(g)
		local vlo, vhi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, v in verts do vlo, vhi = vlo:Min(v + mid), vhi:Max(v + mid) end
		local glo, ghi = Vector3.new(g.lo[1], g.lo[2], g.lo[3]), Vector3.new(g.hi[1], g.hi[2], g.hi[3])
		boxOk = boxOk and (vlo - glo).Magnitude < 1e-3 and (vhi - ghi).Magnitude < 1e-3
		for _, f in faces do
			for _, i in f do
				if i < 1 or i > #verts then inRange = false end
			end
		end
		tris += #faces
		lo, hi = lo:Min(glo), hi:Max(ghi)
		cols[g.col .. (if g.glow then "*" else "")] = true
		looks[g.col .. "/" .. tostring(g.mat) .. "/" .. tostring(g.refl)] = true
	end
	check(key .. ": every mesh within EditableMesh's limits", inLimits)
	check(key .. ": every triangle names real vertices", inRange)
	check(key .. ": every mesh decodes to its own box", boxOk)
	local nlo, nhi = Vector3.one * math.huge, -Vector3.one * math.huge
	local want = {}
	for _, n in boxes[key] do
		nlo = nlo:Min(Vector3.new(n.lo[1], n.lo[2], n.lo[3]))
		nhi = nhi:Max(Vector3.new(n.hi[1], n.hi[2], n.hi[3]))
		want[n.col .. (if n.glow then "*" else "")] = true
	end
	check(string.format("%s: the same box as his .glb (%.3f, %.3f studs off)", key, (lo - nlo).Magnitude, (hi - nhi).Magnitude),
		(lo - nlo).Magnitude < 0.01 and (hi - nhi).Magnitude < 0.01)
	local same = true
	for c in want do if not cols[c] then same = false end end
	for c in cols do if not want[c] then same = false end end
	check(key .. ": the same colours and glow as his .glb", same)
	local wantLook = {}
	for _, n in boxes[key] do
		local mat, refl = KnifeLook.glbMaterial(n.metal, n.rough, n.glow)
		wantLook[n.col .. "/" .. mat .. "/" .. tostring(refl)] = true
	end
	local lookOk = true
	for l in looks do if not wantLook[l] then lookOk = false end end
	check(key .. ": every mesh in the material his .glb part has (KnifeLook.glbMaterial)", lookOk)
	check(key .. ": " .. tris .. " triangles, his whole model", tris > 3000)

	-- 4. the dress, on a stand copy (stretched) and in a hand
	local function fakeMake() return Instance.new("MeshPart") end
	local stand = KnifeService.display(CoinShop.get(key))
	local stretch = stand:GetAttribute("Stretch")
	local dressed = Dress.dress(stand, meshes, fakeMake)
	check(key .. " stand: dressed", dressed ~= nil and dressed.Parent == stand)
	if dressed then
		local handle = stand:FindFirstChild("Handle", true)
		local parts, shells, placed = 0, 0, true
		for _, p in dressed:GetChildren() do
			if p.Name == "GlbShell" then shells += 1 else parts += 1 end
		end
		for i, p in dressed:GetChildren() do
			local w = p:FindFirstChildOfClass("WeldConstraint")
			placed = placed and w ~= nil and w.Part0 == handle
		end
		-- each part's place and size: its .glb box times the stand's stretch
		local fits = true
		local list = {}
		for _, p in dressed:GetChildren() do table.insert(list, p) end
		for i, g in meshes do
			local p = list[i]
			local glo, ghi = Vector3.new(g.lo[1], g.lo[2], g.lo[3]), Vector3.new(g.hi[1], g.hi[2], g.hi[3])
			local at = handle.CFrame:PointToObjectSpace(p.CFrame.Position)
			local want = (glo + ghi) / 2 * stretch
			fits = fits and (at - want).Magnitude < 1e-3 and (p.Size - ((ghi - glo) * stretch):Max(Vector3.one * 0.01)).Magnitude < 1e-3
				and p.Color:ToHex():lower() == g.col and p.Material.Name == g.mat and math.abs(p.Reflectance - g.refl) < 1e-3
		end
		check(key .. " stand: one part per mesh (" .. parts .. "), welded to the Handle", parts == #meshes and placed)
		check(key .. " stand: every part in its .glb place, size, colour and material, times the stretch", fits)
		check(key .. " stand: no shell laid over his blade", shells == 0)
		local shown = 0
		for _, d in stand:GetDescendants() do
			if d:IsA("BasePart") and not d:IsDescendantOf(dressed) and d.Transparency < 1 then shown += 1 end
		end
		check(key .. " stand: the stand-in's own parts hidden (" .. shown .. " showing)", shown == 0)
		check(key .. " stand: dressing twice adds nothing", Dress.dress(stand, meshes, fakeMake) == dressed and #stand:GetChildren() == #stand:GetChildren())
	end
	-- in a hand: no stretch, the .glb's own size
	local c = body()
	KnifeService.give(c, CoinShop.get(key))
	local held = nil
	for _, d in c:GetChildren() do if d:IsA("Model") then held = d end end
	local d2 = held and Dress.dress(held, meshes, fakeMake)
	if d2 then
		local p = d2:GetChildren()[1]
		local g = meshes[1]
		check(key .. " in hand: the .glb's own size", (p.Size - Vector3.new(g.hi[1] - g.lo[1], g.hi[2] - g.lo[2], g.hi[3] - g.lo[3]):Max(Vector3.one * 0.01)).Magnitude < 1e-3)
	else
		check(key .. " in hand: dressed", false)
	end
	-- all or nothing: one mesh that can't be made leaves the stand-in as it was
	local n = 0
	local plainKnife = KnifeService.template(CoinShop.get(key))
	local r = Dress.dress(plainKnife, meshes, function()
		n += 1
		if n == 2 then error("no mesh memory") end
		return Instance.new("MeshPart")
	end)
	local shown = 0
	for _, d in plainKnife:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" and d.Transparency < 1 then shown += 1 end
	end
	check(key .. ": a failed mesh leaves the stand-in whole, no half knife", r == nil and plainKnife:FindFirstChild("GlbDress") == nil and shown > 3)
end

print(string.format("KnifeModels: %d passed, %d failed", passed, failed))
if failed > 0 then error("KnifeModels spec failed") end
