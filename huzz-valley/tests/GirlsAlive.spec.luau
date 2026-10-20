--[[
	Every girl in the owner's real place (places/HUSSANIME.rbxl, Workspace > ANIME GIRLS) moves, as the game makes
	her: GirlRig.toMotors + joinAccessories (as GirlService.makeCopy), then the client's own motion code on her real
	joints, without an error, and visibly:
	  - held (GirlMotion.carried, calm): her legs swing and kick, her arms and head move;
	  - the big girl over the map (CarryAnimator: GirlMoves.idle on the pack + GirlMotion.look + GirlMotion.showcase),
	    and with the scripted idle used when the pack can't be read (GirlMotion.idle).
	Owner, Oct 20: "check the animations for the girls ... it doesnt seem fixed" (his clip: the prize girl over the
	field stiff for 2 s). Run from huzz-valley/: lune run tests/GirlsAlive.spec.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

local GirlRig = luau.load(fs.readFile("src/ReplicatedStorage/Shared/GirlRig.lua"),
	{ debugName = "GirlRig", environment = { Instance = roblox.Instance, CFrame = roblox.CFrame } })()

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local anims = assert(GirlMoves.load(lib:FindFirstChild("HuzzAnimations")), "the pack loads")

local place = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local folder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
check("his ANIME GIRLS folder is there", folder ~= nil)

local function angle(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.deg(math.abs(ang))
end

-- Forward kinematics on her Motor6Ds from her root (Lune has no physics): each Part1 = Part0 * C0 * Transform * C1^-1.
local function fk(motors, root)
	local placed, changed = { [root] = true }, true
	while changed do
		changed = false
		for _, m in motors do
			if m.Part0 and m.Part1 and placed[m.Part0] and not placed[m.Part1] then
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * m.Transform * m.C1:Inverse()
				placed[m.Part1] = true
				changed = true
			end
		end
	end
end

-- Runs `seconds` of one kind of motion; returns per-joint frames of Transform, or the error.
local function run(J, motors, root, kind, rootHeight, seconds)
	local s = GirlMotion.new(11)
	local pack = GirlMoves.new(anims, rootHeight)
	local frames = {}
	local dt = 1 / 30
	local ok, err = pcall(function()
		for i = 1, math.floor(seconds * 30) do
			local t = i * dt
			fk(motors, root)
			if kind == "held" then
				GirlMotion.carried(s, J, dt, t, { accel = Vector3.zero, forward = root.CFrame.LookVector, mood = "Calm", moodAge = 99, step = 0, amount = 0 })
			else
				-- (as CarryAnimator: she floats 34 studs over the field and watches a player below her)
				local ctx = { target = root.CFrame.Position + Vector3.new(6, -34, -20), distance = 40 }
				if kind == "showcase" then
					GirlMoves.idle(pack, J, dt, GirlMotion.look(s, J, dt, t, ctx))
				else
					GirlMotion.idle(s, J, dt, t, ctx) -- (the pack not there)
				end
				GirlMotion.showcase(s, J, dt, t)
			end
			local f = {}
			for key, m in J do f[key] = m.Transform end
			frames[i] = f
		end
	end)
	return ok and frames or nil, err
end

-- Biggest swing of a joint (peak to peak, degrees) over frames [a, b].
local function swing(frames, key, a, b)
	local best = 0
	for i = a, b, 3 do
		for j = i + 3, b, 3 do
			best = math.max(best, angle(frames[i][key], frames[j][key]))
		end
	end
	return best
end

local girls = 0
local summary = {}
for _, rarity in folder:GetChildren() do
	for _, original in rarity:GetChildren() do
		if original:IsA("Model") then
			girls += 1
			local name = `{rarity.Name}/{original.Name}`
			local m = original:Clone()
			GirlRig.toMotors(m)
			GirlRig.joinAccessories(m)
			local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
			local motors = {}
			for _, d in m:GetDescendants() do
				-- (Lune can't read Motor6D.Transform: a stand-in joint with the same fields, the real parts)
				if d:IsA("Motor6D") then
					table.insert(motors, { Name = d.Name, Part0 = d.Part0, Part1 = d.Part1, C0 = d.C0, C1 = d.C1, Transform = CFrame.identity })
				end
			end
			local J = GirlMotion.joints(motors)
			local missing = {}
			for _, key in { "Root", "Neck", "LShoulder", "RShoulder", "LHip", "RHip" } do
				if not (J[key] and J[key].Part0) then table.insert(missing, key) end
			end
			check(`{name}: every joint the motion needs ({table.concat(missing, ", ")} missing)`, #missing == 0 and root ~= nil)
			if root and #missing == 0 then
				local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
				local rootHeight = if ok then math.clamp(root.CFrame.Position.Y - (cf.Position.Y - size.Y / 2), 1, 6) else 3
				local line = {}
				for _, kind in { "held", "showcase", "idle" } do
					local frames, err = run(J, motors, root, kind, rootHeight, 20)
					check(`{name} {kind}: runs without an error ({tostring(err)})`, frames ~= nil)
					if frames then
						-- the quietest 2 s anywhere in 20 s (a short clip) still shows a clear move somewhere
						local quietest = math.huge
						for start = 1, #frames - 60, 15 do
							local biggest = 0
							for _, key in { "Neck", "LShoulder", "RShoulder", "LHip", "RHip" } do
								biggest = math.max(biggest, swing(frames, key, start, start + 60))
							end
							quietest = math.min(quietest, biggest)
						end
						table.insert(line, string.format("%s %.0f°", kind, quietest))
						-- (before Oct 20 the big girl's quietest 2 s moved 16° at most, mostly her head, 4° without the pack: stiff)
						local need = if kind == "held" then 15 else 20
						check(`{name} {kind}: moves at least {need}° in any 2 s ({string.format("%.1f", quietest)}°)`, quietest >= need)
					end
				end
				table.insert(summary, `{name}: {table.concat(line, ", ")}`)
			end
		end
	end
end
check(`all 35 girls checked ({girls})`, girls >= 35)
if failed > 0 then
	for _, l in summary do print("  " .. l) end
end
print(`GirlsAlive: {passed} ok, {failed} failed`)
