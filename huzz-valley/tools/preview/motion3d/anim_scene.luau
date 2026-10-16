-- The owner's animations (KeyframeSequences in a .rbxl), each on its own rig in a row, looping, filmed from
-- 3/4 front. ANIM_FILE=<place.rbxl> ANIM_NAMES="Walk,Run,Run V2" [SECONDS=4] sh video.sh anim_scene.luau out.mp4
-- ANIM_UNDER=<text> only takes animations whose full name contains it (the pack has cut-down duplicates);
-- ANIM_VIEW=side films them side on, in a row, to compare runs; ANIM_VIEW=back from behind and above, like the
-- game's camera.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")

local file = process.env.ANIM_FILE
local place
if file:match("%.rbxmx?$") then
	place = roblox.Instance.new("Folder")
	for _, inst in roblox.deserializeModel(fs.readFile(file)) do inst.Parent = place end
else
	place = roblox.deserializePlace(fs.readFile(file))
end
local names = string.split(process.env.ANIM_NAMES or "", ",")
if (process.env.ANIM_NAMES or "") == "" then -- every KeyframeSequence in the file, in a grid
	names = {}
	for _, d in place:GetDescendants() do
		if d.ClassName == "KeyframeSequence" and (process.env.ANIM_PREFIX == nil or d.Name:find(process.env.ANIM_PREFIX, 1, true) == 1) then table.insert(names, d.Name) end
	end
end
local PER_ROW = if #names > 6 then 5 else #names
local SECONDS = tonumber(process.env.SECONDS or "4")
local scene = Scene.new()
local rigs = {}
local COLORS = { "#3a5bd0", "#d04a5b", "#3fae6a", "#c9a227", "#8a4fd0", "#2aa7b8" }
for i, name in names do
	local found
	for _, d in place:GetDescendants() do
		if d.ClassName == "KeyframeSequence" and d.Name == name and (process.env.ANIM_UNDER == nil or d:GetFullName():find(process.env.ANIM_UNDER, 1, true)) then found = d break end
	end
	assert(found, "no animation called " .. name)
	local rig = scene:addRig(Rig.r15("R" .. i, { shirt = COLORS[(i - 1) % #COLORS + 1], pants = "#22232c" }))
	local col, row = (i - 1) % PER_ROW, (i - 1) // PER_ROW
	local x, z = (col - (PER_ROW - 1) / 2) * 5, row * 6
	if process.env.ANIM_VIEW == "side" then x, z = (i - 1) * 4.5, 0 end
	rig.root.CFrame = if process.env.ANIM_VIEW == "side" then Rig.lookAt(Vector3.new(x, Rig.REST_HEIGHT, z), Vector3.new(x + 1, Rig.REST_HEIGHT, z))
		else Rig.lookAt(Vector3.new(x, Rig.REST_HEIGHT, z), Vector3.new(x, Rig.REST_HEIGHT, z - 1))
	rigs[i] = { rig = rig, anim = KFS.load(found) }
	print(i, name, "length", rigs[i].anim.length)
end
local width = PER_ROW * 5
local rows = math.ceil(#names / PER_ROW)
for f = 0, SECONDS * 30 - 1 do
	local t = f / 30
	for _, r in rigs do
		KFS.apply(r.anim, r.rig, t)
		Rig.fk(r.rig)
	end
	if process.env.ANIM_VIEW == "side" then
		local mid = (#names - 1) * 2.25
		scene:frame(Vector3.new(mid, 2.8, -(#names * 2.4 + 4)), Vector3.new(mid, 2.4, 0))
	elseif process.env.ANIM_VIEW == "back" then
		scene:frame(Vector3.new(0, 7, width * 0.5 + 6), Vector3.new(0, 2.2, 0))
	elseif rows > 1 then
		scene:frame(Vector3.new(0, 16, -18), Vector3.new(0, 1, rows * 2.6))
	else
		scene:frame(Vector3.new(width * 0.55, 3.2, -width * 0.42), Vector3.new(0, 2.4, 0))
	end
end
scene:save(nil, 30, 1280, 640)
