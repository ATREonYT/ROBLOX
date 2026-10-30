-- His R6 movement pack (Oct 22): each loop's stride, so the walk and run play at the speed that keeps the feet planted,
-- and where in the loop the right leg is furthest forward (Config/Run.LocoR6 WalkAt / RunAt / phases).
-- lune run huzz-valley/tools/preview/motion3d/r6_stride.luau <movement-pack.rbxl> (from the repo root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Vector3 = roblox.Vector3
local Rig = require("./rig")
local KFS = require("./kfs")
local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local function find(name)
	for _, d in place:GetDescendants() do if d.ClassName == "KeyframeSequence" and d.Name == name then return d end end
end
for _, name in { "Stylized Walk", "Stylized Run 1", "Stylized Run 2", "Walk Backwards" } do
	local anim = KFS.load(find(name))
	local rig = Rig.r6("R", {})
	local N = 120
	local minZ, maxZ, fwdT, fwdZ = math.huge, -math.huge, 0, math.huge
	local lowY = math.huge
	local samples = {}
	for i = 0, N - 1 do
		local t = anim.length * i / N
		KFS.apply(anim, rig, t)
		Rig.fk(rig)
		local foot = rig.root.CFrame:PointToObjectSpace((rig.parts["Right Leg"].CFrame * roblox.CFrame.new(0, -1, 0)).Position)
		samples[i] = foot
		lowY = math.min(lowY, foot.Y)
		if foot.Z < fwdZ then fwdZ, fwdT = foot.Z, t end -- (-Z is forward)
	end
	-- the foot's travel while it is near the ground (the planted part of the step)
	for i = 0, N - 1 do
		local f = samples[i]
		if f.Y < lowY + 0.25 then minZ = math.min(minZ, f.Z); maxZ = math.max(maxZ, f.Z) end
	end
	local stride = maxZ - minZ -- one foot's ground travel per loop (= one stride: two steps)
	print(string.format("%-16s len %.3f  planted travel %.2f studs  -> planted at %.1f studs/s  right foot forward at %.2f of the loop (lowest foot %.2f)",
		name, anim.length, stride, stride / anim.length * 1, fwdT / anim.length, lowY))
end
