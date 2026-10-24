-- Checks every dance on a plain R6 body (owner, Oct 23 20:07: "fix the dances so they look appropriate, so keep on
-- checking them to make sure they look good and are on par"): prints each dance's numbers and films 6 moments of
-- each, front three-quarter, one after another (6 frames a dance, captioned), for a contact sheet.
--   lowest   the lowest point of the body over the dance (0 = the floor with the root at standing height; under
--            -0.25 the feet sink in, over 0.6 at its lowest the body floats)
--   pop      the biggest turn of any joint in 1/30 s (over 70 degrees reads as a snap)
--   seam     how far the last frame is from the first (a looping dance jumps by this much each loop)
--   drift    how far the torso wanders from the root (over 3 studs it leaves its spot)
-- From the repo root: sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/dance_audit.luau out.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")

local folder = roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm"))[1]
local names = {}
for _, seq in folder:GetChildren() do
	if seq.Name:find("^Dance_") then table.insert(names, seq.Name) end
end
table.sort(names)

local H = 3
local function lowest(rig)
	local low = math.huge
	for _, n in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local p = rig.parts[n]
		local h = p.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (p.CFrame * Vector3.new(h.X * x, h.Y * y, h.Z * z)).Y)
				end
			end
		end
	end
	return low
end
local function angle(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.deg(math.abs(ang))
end

local probe = Rig.r6("Probe")
local scene = Scene.new()
for i = -6, 6 do
	for j = -6, 6 do
		scene:addBox(CFrame.new(j * 3, 0.03, i * 3), Vector3.new(0.3, 0.06, 0.3), "#b9a06a")
	end
end
local body = scene:addRig(Rig.r6("Dancer", { shirt = "#3a7be0", pants = "#2b2f3a", skin = "#e9c29a", hair = "#1a1414" }))
print(string.format("%-22s %6s %7s %7s %6s %6s  %s", "dance", "length", "lowest", "highest", "pop", "seam", "drift"))
for _, name in names do
	local anim = KFS.load(folder:FindFirstChild(name))
	local len = math.max(anim.length, 1 / 30)
	local low, lowMax, pop, drift = math.huge, -math.huge, 0, 0
	local prev = nil
	local n = math.max(2, math.floor(len * 30))
	for i = 0, n do
		local t = i / n * len
		for _, m in probe.motors do m.Transform = CFrame.identity end
		KFS.apply(anim, probe, t)
		probe.root.CFrame = CFrame.new(0, H, 0)
		Rig.fk(probe)
		local l = lowest(probe)
		low = math.min(low, l)
		lowMax = math.max(lowMax, l)
		drift = math.max(drift, (probe.parts.Torso.CFrame.Position - probe.root.CFrame.Position).Magnitude)
		local now = {}
		for _, m in probe.motors do now[m] = m.Transform end
		if prev then
			for m, cf in now do pop = math.max(pop, angle(prev[m], cf)) end
		end
		prev = now
	end
	local first = KFS.sample(anim, 0)
	local last = KFS.sample(anim, len)
	local seam = 0
	for k, cf in first do
		if last[k] then seam = math.max(seam, angle(cf, last[k])) end
	end
	local flags = {}
	if low < -0.25 then table.insert(flags, "SINKS") end
	if low > 0.6 then table.insert(flags, "FLOATS") end
	if pop > 70 then table.insert(flags, "SNAPS") end
	if anim.loop ~= false and seam > 25 then table.insert(flags, "LOOP-JUMP") end
	if drift > 3 then table.insert(flags, "WANDERS") end
	print(string.format("%-22s %6.2f %7.2f %7.2f %6.0f %6.0f  %5.2f %s %s", name:sub(7), len, low, lowMax, pop, seam, drift, tostring(anim.loop), table.concat(flags, " ")))
	for k = 0, 5 do
		local t = (k + 0.5) / 6 * len
		for _, m in body.motors do m.Transform = CFrame.identity end
		KFS.apply(anim, body, t)
		body.root.CFrame = CFrame.new(0, H, 0)
		Rig.fk(body)
		scene:frame(Vector3.new(5.5, 4.2, -8.5), Vector3.new(0, 2.6, 0), { caption = string.format("%s  %.1fs", name:sub(7), t) })
	end
end
scene:save(nil, 30, 480, 480)
