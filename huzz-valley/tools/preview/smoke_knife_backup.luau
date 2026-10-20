-- Smoke test: every knife shows in the live game (owner, Oct 20 15:13: "make it so that the knifes also appear inside
-- of the actual roblox game"). His 30 imported knives are his uploaded meshes on an invisible Handle; a live screen
-- loads each mesh from Roblox, and one Roblox hasn't finished or approved shows nothing. Checks:
--   * HuzzServer/KnifeService: a copy of his knife carries nothing extra, only its "Backup" attribute (the critic,
--     Oct 20 evening: the hidden cut in every copy was up to 199 parts a knife on every screen); prints the part
--     counts before and after; a pass knife (its own stand-in) isn't marked;
--   * HuzzServer/KnifeGlbService.backup hands out each of the 53 cuts' rows (his 30's in ServerStorage/HuzzKnifeBackups;
--     since Oct 20 20:34 his 23 of the files of several are his models too, their cut their stand-in's rows,
--     Shared/KnifeStandInParts), nothing for an odd key;
--   * Shared/KnifeCut builds each cut on a copy: welded to his Handle, no trail points of its own, the same tip,
--     bottom and width as his model (turned half round where his import is), left out of the knife's measured shape;
--   * Gameplay/KnifeMeshCheck (Roblox's loader and the remote swapped for stubs): one of his meshes failing builds the
--     cut on that copy and hides his parts, saying so once; loading later removes it; all loading, or only a texture
--     failing, builds nothing; no answer in time builds it meanwhile and removes it once the meshes load; the cut's
--     data is asked once a knife; no data: his parts stay.
-- From tools/preview: lune run harness.luau ../../src - @smoke_knife_backup.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local folder = __roblox.deserializeModel(__fs.readFile("../../assets/knives/HuzzKnives.rbxm"))[1]
folder.Name = "HuzzKnives"
folder.Parent = SS

local KnifeService = require(game.ServerScriptService.HuzzServer.KnifeService)
local KnifeGlbService = require(game.ServerScriptService.HuzzServer.KnifeGlbService)
local KnifeCut = require(RS.Shared.KnifeCut)
local CoinShop = require(RS.Shared.Config.CoinShop)

-- a part set's box in a frame: lo, hi
local function box(parts, frame)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local r = frame:ToObjectSpace(p.CFrame)
		local h = p.Size / 2
		if p:IsA("WedgePart") then
			-- (a wedge is half its block: its 6 real corners, or a big turned one reads wider than it is: Hollow Eclipse)
			for _, k in { { 1, -1, -1 }, { -1, -1, -1 }, { 1, -1, 1 }, { -1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 } } do
				local q = r * Vector3.new(h.X * k[1], h.Y * k[2], h.Z * k[3])
				lo, hi = lo:Min(q), hi:Max(q)
			end
			continue
		end
		local e = Vector3.new(
			math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
			math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
			math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
		lo = lo:Min(r.Position - e)
		hi = hi:Max(r.Position + e)
	end
	return lo, hi
end
local function count(model)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	return n
end

local keys = {}
for _, k in folder:GetChildren() do table.insert(keys, k.Name) end
table.sort(keys)
check("his 53 knives are here", #keys == 53)
local marked, bare, served, welded, clean, placed, measured = 0, 0, 0, 0, 0, 0, 0
local partsNow, partsBefore, biggest, biggestKey = 0, 0, 0, ""
local worst = ""
for _, key in keys do
	local skin = CoinShop.get(key)
	local model, his = KnifeService.template(skin)
	local handle = model:FindFirstChild("Handle", true)
	if his and model:GetAttribute("Backup") == key then marked += 1 end
	local n = count(model)
	if model:FindFirstChild("KnifeBackup") == nil and n == count(folder:FindFirstChild(key)) then bare += 1 end
	local baked = KnifeGlbService.backup(key)
	if type(baked) == "table" and #baked.parts > 1 then served += 1 end
	if baked and handle then
		partsNow += n
		partsBefore += n + #baked.parts - 1 -- (the old copy carried every row but the Handle as a hidden part)
		if #baked.parts - 1 > biggest then biggest, biggestKey = #baked.parts - 1, key end
		local mine = {}
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") then table.insert(mine, d) end
		end
		local cut = KnifeCut.build(baked, model, handle, KnifeCut.turned(baked, handle, mine))
		local allWelded, noExtras = true, true
		for _, p in cut:GetChildren() do
			local w = p:FindFirstChildOfClass("Weld")
			if not (p:IsA("BasePart") and string.find(p.Name, "^KnifeBackup") and w and w.Part0 == handle and w.Part1 == p) then allWelded = false end
			for _, c in p:GetChildren() do
				if not c:IsA("Weld") then noExtras = false end
			end
		end
		if allWelded and #cut:GetChildren() == #baked.parts - 1 then welded += 1 end
		if noExtras then clean += 1 end
		-- his parts vs the cut, in his Handle's space: the same tip, and the same bottom with or without his hanging
		-- chain / tassel (the cut can leave a thin one out: Abyss Eclipse's)
		local all, core = {}, {}
		for _, d in mine do
			local nm = string.lower(d.Name)
			local hangs = string.find(nm, "chain") or string.find(nm, "tassel") or string.find(nm, "cord") or string.find(nm, "charm") or string.find(nm, "rope")
			table.insert(all, d)
			if not hangs then table.insert(core, d) end
		end
		local alo, ahi = box(all, handle.CFrame)
		local clo = box(core, handle.CFrame)
		local blo, bhi = box(cut:GetChildren(), handle.CFrame)
		local bottom = math.min(math.abs(alo.Y - blo.Y), math.abs(clo.Y - blo.Y))
		local across = math.max(math.abs(alo.Z - blo.Z), math.abs(ahi.Z - bhi.Z))
		if math.abs(ahi.Y - bhi.Y) <= 0.25 and bottom <= 0.25 and across <= 0.25 then
			placed += 1
		else
			worst ..= string.format(" %s(his %.2f..%.2f, cut %.2f..%.2f, across his %.2f..%.2f cut %.2f..%.2f)", key, alo.Y, ahi.Y, blo.Y, bhi.Y, alo.Z, ahi.Z, blo.Z, bhi.Z)
		end
		local a, b = KnifeService.shapeOf(folder:FindFirstChild(key)), KnifeService.shapeOf(model)
		if a and b and math.abs(a.length - b.length) < 1e-6 then measured += 1 end
	end
	model:Destroy()
end
print(string.format("parts in a copy of his knife, all 53 summed: %d now, %d before (each carried its hidden cut); the most a knife added: %d (%s)",
	partsNow, partsBefore, biggest, biggestKey))
check("each copy of his 53 is marked with its key (" .. marked .. ")", marked == 53)
check("... and carries nothing extra: the same parts as his model (" .. bare .. ")", bare == 53)
check("the server hands out each cut's rows (" .. served .. ")", served == 53)
check("nothing for an odd key", KnifeGlbService.backup("../x") == nil and KnifeGlbService.backup(5) == nil and KnifeGlbService.backup("NoSuchKnife") == nil)
check("each cut is welded to his Handle, every row a part (" .. welded .. ")", welded == 53)
check("the cut brings no trail points of its own (" .. clean .. ")", clean == 53)
check("the cut sits where his knife is, at its length (" .. placed .. ")" .. worst, placed == 53)
check("the cut isn't measured as the knife (" .. measured .. ")", measured == 53)
-- (a place without his pass model: its stand-in shows, unmarked: nothing of his to fail)
local his = folder:FindFirstChild("CrimsonRequiem")
his.Parent = nil
local pass = KnifeService.template(CoinShop.get("CrimsonRequiem"))
his.Parent = folder
check("a pass knife's stand-in isn't marked", pass:FindFirstChild("KnifeBackup") == nil and pass:GetAttribute("Backup") == nil)

-- the screen side
local Check = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.KnifeMeshCheck)
local asked = {}
Check.fetch = function(key)
	asked[key] = (asked[key] or 0) + 1
	return KnifeGlbService.backup(key)
end
local function fresh(key)
	local model = KnifeService.template(CoinShop.get(key))
	model.Parent = workspace
	local his = Check.partsOf(model)
	return model, his
end
local function visible(parts) for _, p in parts do if p.Transparency >= 1 then return false end end return true end
local function gone(parts) for _, p in parts do if p.Transparency < 1 then return false end end return true end
local function cutShows(model)
	local cut = model:FindFirstChild("KnifeBackup")
	if not cut or #cut:GetChildren() == 0 then return false end
	for _, p in cut:GetChildren() do if p.Transparency >= 1 then return false end end
	return true
end
local warned = {}
Check.say = function(s) table.insert(warned, s) end

local model, his = fresh("EmberEdge")
local before = {}
for i, p in his do before[i] = p.Transparency end
local meshId = Check.meshIdOf(his[1])
local function failOne(list, cb)
	for _, p in list do cb(Check.meshIdOf(p), if Check.meshIdOf(p) == meshId then Enum.AssetFetchStatus.Failure else Enum.AssetFetchStatus.Success) end
end
Check.preload = failOne
Check.check(model)
check("one of his meshes failing hides his parts", gone(his))
check("... and builds the cut on that copy", cutShows(model))
check("... saying so once in Output", #warned == 1 and string.find(warned[1], "^%[HuzzKnife%] EmberEdge") ~= nil and string.find(warned[1], "showing the plain cut") ~= nil)
local other = fresh("EmberEdge")
Check.check(other)
check("the cut's data is asked once a knife (" .. tostring(asked.EmberEdge) .. ")", asked.EmberEdge == 1 and cutShows(other))
Check.preload = function(list, cb)
	for _, p in list do cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success) end
end
Check.check(model)
local back = true
for i, p in his do if p.Transparency ~= before[i] then back = false end end
check("loading later removes the cut and brings his model back", back and model:FindFirstChild("KnifeBackup") == nil)

model, his = fresh("FrostFang")
Check.check(model)
check("all his meshes load: nothing is built", visible(his) and model:FindFirstChild("KnifeBackup") == nil and asked.FrostFang == nil)
Check.preload = function(list, cb)
	for _, p in list do
		cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success)
		cb("rbxassetid://120038515596009", Enum.AssetFetchStatus.Failure) -- (a texture)
	end
end
Check.check(model)
check("only a texture failing: his model stays", visible(his) and model:FindFirstChild("KnifeBackup") == nil)

model, his = fresh("VoidFang")
Check.WAIT = 0.2
local release = false
Check.preload = function(list, cb)
	while not release do task.wait(0.05) end
	for _, p in list do cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success) end
end
task.spawn(Check.check, model)
task.wait(0.4)
check("no answer in time: the cut is built meanwhile", gone(his) and cutShows(model))
release = true
task.wait(0.2)
check("... and removed when the meshes load", visible(his) and model:FindFirstChild("KnifeBackup") == nil)

Check.WAIT = 8
Check.fetch = function() return nil end
model, his = fresh("NightTanto")
meshId = Check.meshIdOf(his[1])
Check.preload = failOne
Check.check(model)
check("no cut to be had: his parts stay as they are", visible(his) and model:FindFirstChild("KnifeBackup") == nil
	and string.find(warned[#warned], "couldn't be fetched") ~= nil)
print(string.format("knife backup smoke: %d ok, %d failed", ok, fails))
