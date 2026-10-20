-- Smoke test: every knife shows in the live game (owner, Oct 20 15:13: "make it so that the knifes also appear inside
-- of the actual roblox game"). His 30 imported knives are his uploaded meshes on an invisible Handle; a live screen
-- loads each mesh from Roblox, and one Roblox hasn't finished or approved shows nothing. Checks:
--   * HuzzServer/KnifeService: each copy of his 30 carries the plain cut of his own .glb (ServerStorage/
--     HuzzKnifeBackups), hidden, welded to his Handle, no trail points of its own, in the same place and length as his
--     model (Handle space), and left out of the knife's measured shape; a pass knife (its own stand-in) gets none;
--   * Gameplay/KnifeMeshCheck (ContentProvider swapped for a stub): one of his meshes failing shows the cut and hides
--     his parts; all loading, or only a texture failing, changes nothing; no answer in time shows the cut meanwhile
--     and his model comes back once the meshes load.
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
local CoinShop = require(RS.Shared.Config.CoinShop)

-- a part set's box in a frame: lo, hi
local function box(parts, frame)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local r = frame:ToObjectSpace(p.CFrame)
		local h = p.Size / 2
		local e = Vector3.new(
			math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
			math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
			math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
		lo = lo:Min(r.Position - e)
		hi = hi:Max(r.Position + e)
	end
	return lo, hi
end

local keys = {}
for _, k in folder:GetChildren() do table.insert(keys, k.Name) end
table.sort(keys)
check("his 30 knives are here", #keys == 30)
local carried, hidden, welded, clean, placed, measured = 0, 0, 0, 0, 0, 0
local worst = ""
for _, key in keys do
	local skin = CoinShop.get(key)
	local model, his = KnifeService.template(skin)
	local handle = model:FindFirstChild("Handle", true)
	local cut = model:FindFirstChild("KnifeBackup")
	if his and cut and #cut:GetChildren() > 0 and model:GetAttribute("Backup") == key then carried += 1 end
	if cut and handle then
		local allHidden, allWelded, noExtras = true, true, true
		for _, p in cut:GetChildren() do
			if not (p:IsA("BasePart") and p.Transparency == 1 and type(p:GetAttribute("Shown")) == "number" and string.find(p.Name, "^KnifeBackup")) then allHidden = false end
			local w = p:FindFirstChildOfClass("Weld")
			if not (w and w.Part0 == handle and w.Part1 == p) then allWelded = false end
			for _, c in p:GetChildren() do
				if not c:IsA("Weld") then noExtras = false end
			end
		end
		if allHidden then hidden += 1 end
		if allWelded then welded += 1 end
		if noExtras and model:FindFirstChild("TrailTip", true) == nil or (model:FindFirstChild("TrailTip", true) and not model:FindFirstChild("TrailTip", true):FindFirstAncestor("KnifeBackup")) then clean += 1 end
		-- his parts vs the cut, in his Handle's space: the same tip, and the same bottom with or without his hanging
		-- chain / tassel (the cut can leave a thin one out: Abyss Eclipse's)
		local all, core = {}, {}
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") and not d:IsDescendantOf(cut) then
				local n = string.lower(d.Name)
				local hangs = string.find(n, "chain") or string.find(n, "tassel") or string.find(n, "cord") or string.find(n, "charm") or string.find(n, "rope")
				table.insert(all, d)
				if not hangs then table.insert(core, d) end
			end
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
check("each copy of his 30 carries his knife's cut (" .. carried .. ")", carried == 30)
check("the cut is hidden until needed (" .. hidden .. ")", hidden == 30)
check("the cut is welded to his Handle (" .. welded .. ")", welded == 30)
check("the cut brings no trail points of its own (" .. clean .. ")", clean == 30)
check("the cut sits where his knife is, at its length (" .. placed .. ")" .. worst, placed == 30)
check("the cut isn't measured as the knife (" .. measured .. ")", measured == 30)
local pass = KnifeService.template(CoinShop.get("CrimsonRequiem"))
check("a pass knife (its own stand-in) gets no cut", pass:FindFirstChild("KnifeBackup") == nil and pass:GetAttribute("Backup") == nil)

-- the screen side
local Check = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.KnifeMeshCheck)
local function fresh(key)
	local model = KnifeService.template(CoinShop.get(key))
	model.Parent = workspace
	local his, cut = Check.partsOf(model)
	return model, his, cut
end
local function visible(parts) for _, p in parts do if p.Transparency >= 1 then return false end end return true end
local function gone(parts) for _, p in parts do if p.Transparency < 1 then return false end end return true end
local function cutShows(cut)
	for _, p in cut do if p.Transparency ~= p:GetAttribute("Shown") then return false end end
	return true
end
local warned = {}
Check.say = function(s) table.insert(warned, s) end

local model, his, cut = fresh("EmberEdge")
local before = {}
for i, p in his do before[i] = p.Transparency end
local meshId = Check.meshIdOf(his[1])
Check.preload = function(list, cb)
	for _, p in list do cb(Check.meshIdOf(p), if Check.meshIdOf(p) == meshId then Enum.AssetFetchStatus.Failure else Enum.AssetFetchStatus.Success) end
end
Check.check(model)
check("one of his meshes failing hides his parts", gone(his))
check("... and shows the cut", cutShows(cut) and #cut > 0)
check("... saying so once in Output", #warned == 1 and string.find(warned[1], "^%[HuzzKnife%] EmberEdge") ~= nil)
Check.preload = function(list, cb)
	for _, p in list do cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success) end
end
Check.check(model)
local back = true
for i, p in his do if p.Transparency ~= before[i] then back = false end end
check("loading later brings his model back (his own transparency)", back and gone(cut))

model, his, cut = fresh("FrostFang")
Check.check(model)
check("all his meshes load: nothing changes", visible(his) and gone(cut) and model:GetAttribute("ShowingBackup") == nil)
Check.preload = function(list, cb)
	for _, p in list do
		cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success)
		cb("rbxassetid://120038515596009", Enum.AssetFetchStatus.Failure) -- (a texture)
	end
end
Check.check(model)
check("only a texture failing: his model stays", visible(his) and gone(cut))

model, his, cut = fresh("VoidFang")
Check.WAIT = 0.2
local release = false
Check.preload = function(list, cb)
	while not release do task.wait(0.05) end
	for _, p in list do cb(Check.meshIdOf(p), Enum.AssetFetchStatus.Success) end
end
task.spawn(Check.check, model)
task.wait(0.4)
check("no answer in time: the cut shows meanwhile", gone(his) and cutShows(cut))
release = true
task.wait(0.2)
check("... and his model comes back when the meshes load", visible(his) and gone(cut))
print(string.format("knife backup smoke: %d ok, %d failed", ok, fails))
