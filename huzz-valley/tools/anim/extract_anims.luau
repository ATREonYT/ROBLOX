-- Pulls the game's animations out of the owner's files into src/ReplicatedStorage/HuzzAnimations.rbxm (a Folder of
-- KeyframeSequences that Rojo and the place build put in ReplicatedStorage):
--   design/anims/movement-pack.rbxl  (Skater Studios' "15+ R15 Movement Animations" pack, licence in the zip):
--     Idle, Walk, Run (the pack's Sprint: hunched, big arms, like Huss Valley), Jump, Fall, Climb
--   design/anims/200-dances.rbxl  (the owner's 200 dances): the 25 in DANCES below, renamed Dance_<Id>
--   Dash: made here from the pack's Sprint: a low forward lunge with the arms swept back (the huss dash).
-- In Studio the game plays them straight from these (KeyframeSequenceProvider, Shared/AnimationLibrary); for the
-- live game the owner publishes them once (tools/studio/publish-animations.lua) and the IDs go in Config/Animations.
-- Run from the repo root: lune run huzz-valley/tools/anim/extract_anims.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local DIR = "huzz-valley/design/anims/"
local OUT = "huzz-valley/src/ReplicatedStorage/HuzzAnimations.rbxm"

-- Id (the game's name) = the dance's name in 200-dances.rbxl. Display names live in Config/Dances.
local DANCES = {
	{ "Floss", "Floss" }, { "CitrusGroove", "Orange Justice" }, { "HypeUp", "Hype" },
	{ "ShockShuffle", "Electro Shuffle" }, { "ClassicGroove", "Default Dance" }, { "BoogieDown", "Boogie down" },
	{ "SmoothMoves", "Smooth Moves" }, { "SoFresh", "Fresh" }, { "PopLock", "Pop Lock" }, { "Robot", "The Robot" },
	{ "PhoneCall", "Hotline Bling" }, { "RunningMan", "Running Man" }, { "CrazyFeet", "Crazy Feet" },
	{ "Breakdown", "Breakdown" }, { "SwingTime", "Electro Swing [FULL]" }, { "FreeFlow", "Free Flow" },
	{ "Freestyle", "Freestylin" }, { "CleanGroove", "Clean Groove" }, { "BounceBounce", "New Billy Bounce" },
	{ "Flapper", "Flapper" }, { "SquatKick", "[UPDATED!] Kazotsky Kick" }, { "Sprinkler", "Sprinkler" },
	{ "CrabDance", "CrabRavedance" }, { "Toprock", "[NEW!]Heel Toe Toprock" }, { "Aerobics", "Mannrobics" },
}
-- The game's name = the pack's name (from its "All Animations" folder), and the priority it plays at.
local MOVES = {
	{ "Idle", "Idle", "Idle" }, { "Walk", "Walk", "Movement" }, { "Run", "Sprint", "Movement" },
	{ "Jump", "Jump", "Movement" }, { "Fall", "Fall", "Movement" }, { "Climb", "Climb", "Movement" },
}

local function keyCount(seq)
	local n = 0
	for _, k in seq:GetChildren() do
		if k.ClassName == "Keyframe" then n += 1 end
	end
	return n
end

-- Every KeyframeSequence with this name; the one with the most keyframes wins (duplicates are often cut-down copies).
local function find(place, name, under)
	local best
	for _, d in place:GetDescendants() do
		if d.ClassName == "KeyframeSequence" and d.Name == name and (not under or d:GetFullName():find(under, 1, true)) then
			if not best or keyCount(d) > keyCount(best) then best = d end
		end
	end
	assert(best, "not found: " .. name)
	return best
end

local folder = Instance.new("Folder")
folder.Name = "HuzzAnimations"

local function add(seq, name, priority, loop)
	local copy = seq:Clone()
	copy.Name = name
	copy.Priority = Enum.AnimationPriority[priority]
	if loop ~= nil then copy.Loop = loop end
	copy.Parent = folder
	return copy
end

local pack = roblox.deserializePlace(fs.readFile(DIR .. "movement-pack.rbxl"))
local sprint
for _, m in MOVES do
	local seq = add(find(pack, m[2], "All Animations"), m[1], m[3], m[1] ~= "Jump")
	if m[1] == "Run" then sprint = seq end
	print(string.format("%-14s <- %s", m[1], m[2]))
end

-- The dash: three keyframes built from the Sprint's pose a quarter of the way through its loop (one leg reaching),
-- leaning hard forward and low, arms flung back, then easing back toward the run.
do
	local frames = {}
	for _, k in sprint:GetChildren() do
		if k.ClassName == "Keyframe" then table.insert(frames, k) end
	end
	table.sort(frames, function(a, b) return a.Time < b.Time end)
	local length = frames[#frames].Time
	local reach = frames[1]
	for _, k in frames do
		if k.Time <= length * 0.25 then reach = k end
	end
	local rad = math.rad
	-- extra rotation per part at the lunge (forward lean is a negative X turn on the root)
	local LUNGE = {
		LowerTorso = CFrame.new(0, -0.45, -0.2) * CFrame.Angles(rad(-26), 0, 0),
		UpperTorso = CFrame.Angles(rad(-12), 0, 0),
		Head = CFrame.Angles(rad(16), 0, 0),
		RightUpperArm = CFrame.Angles(rad(-55), 0, rad(-12)),
		LeftUpperArm = CFrame.Angles(rad(-55), 0, rad(12)),
		RightLowerArm = CFrame.Angles(rad(-20), 0, 0),
		LeftLowerArm = CFrame.Angles(rad(-20), 0, 0),
	}
	local dash = Instance.new("KeyframeSequence")
	dash.Name = "Dash"
	dash.Loop = false
	dash.Priority = Enum.AnimationPriority.Action
	local function keyframe(t, amount, style, dir)
		local k = reach:Clone()
		k.Time = t
		for _, p in k:GetDescendants() do
			if p.ClassName == "Pose" then
				local extra = LUNGE[p.Name]
				if extra and amount > 0 then
					p.CFrame = p.CFrame * CFrame.identity:Lerp(extra, amount)
				end
				p.EasingStyle = Enum.PoseEasingStyle[style]
				p.EasingDirection = Enum.PoseEasingDirection[dir]
			end
		end
		k.Parent = dash
	end
	keyframe(0, 0.2, "Cubic", "Out")
	keyframe(0.1, 1, "Linear", "In")
	keyframe(0.24, 0.9, "Cubic", "InOut")
	keyframe(0.45, 0, "Linear", "In")
	dash.Parent = folder
	print("Dash           <- built from Sprint")
end

local dances = roblox.deserializePlace(fs.readFile(DIR .. "200-dances.rbxl"))
for _, d in DANCES do
	local seq = add(find(dances, d[2]), "Dance_" .. d[1], "Action", true)
	print(string.format("%-20s <- %-28s %d keyframes", "Dance_" .. d[1], d[2], keyCount(seq)))
end

fs.writeFile(OUT, roblox.serializeModel({ folder }))
print(string.format("saved %s (%.1f MB)", OUT, #fs.readFile(OUT) / 1e6))
