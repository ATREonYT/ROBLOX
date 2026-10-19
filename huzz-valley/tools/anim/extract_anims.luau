-- Pulls the game's animations out of the owner's files into src/ServerStorage/HuzzAnimations.rbxm (a Folder of
-- KeyframeSequences that Rojo and the place build put in ServerStorage; in Studio, Bootstrap copies it to
-- ReplicatedStorage so clients can play them, and in the live game nobody downloads it):
--   design/anims/movement-pack.rbxl  (Skater Studios' "15+ R15 Movement Animations" pack, licence in the zip):
--     Idle, Walk, Run (the pack's Sprint as it is: hunched, big arm swings, like Huss Valley), Jump, Fall, Climb
--   design/anims/200-dances.rbxl  (the owner's 200 dances): the 32 in DANCES below, renamed Dance_<Id>
--   DashLeft, DashRight: made here (the huss is sideways only, like Huss Valley): a low hop-slide that way.
-- In Studio the game plays them straight from these (KeyframeSequenceProvider, Shared/AnimationLibrary); for the
-- live game the owner publishes them once (tools/studio/publish-animations.lua) and the IDs go in Config/Animations.
-- Run from the repo root: lune run huzz-valley/tools/anim/extract_anims.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum

local DIR = "huzz-valley/design/anims/"
local OUT = "huzz-valley/src/ServerStorage/HuzzAnimations.rbxm"

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
	-- the Dance Crate's own (owner, Oct 19: "dances, from crates")
	{ "BoogieBlast", "Boogie Bomb" }, { "HeadBanger", "HeadBanger" }, { "TheTwist", "Twist" }, { "ZanyZig", "Zany" },
	{ "PowerMoves", "Power Dance" }, { "Showstopper", "Showstopper" }, { "ZombieGroove", "Thriller" },
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
local made = {}
for _, m in MOVES do
	made[m[1]] = add(find(pack, m[2], "All Animations"), m[1], m[3], m[1] ~= "Jump")
	print(string.format("%-14s <- %s", m[1], m[2]))
end

-- Run keeps the pack Sprint's own arms: big swings forward and back, elbows bent, like Huss Valley's run (the
-- owner's videos 87565d66 and 1fbb6d13). (An earlier version held the fists in front of the chest: the owner
-- saw stiff crossed arms and asked for the swing back.)

-- The huss (sideways only, like Huss Valley): DashLeft and DashRight, built here on the Idle's first pose, matched
-- to the owner's reference video (87565d66, 0.6-1.8 s and 3.6-5.4 s): a compact sideways throw. Low and hunched,
-- the body tips ~38° into the way you go, the hips shift that way, only the outside leg kicks out while the inside
-- one stays bent under you, and the arms keep the run's hold in front of the chest (the outside one lifts a bit).
-- ~0.45 s, Action priority, not looped (Gameplay/Dash plays the right one).
do
	local idle = folder:FindFirstChild("Idle")
	local first
	for _, k in idle:GetChildren() do
		if k.ClassName == "Keyframe" and (not first or k.Time < first.Time) then first = k end
	end
	local rad = math.rad
	-- side = 1 for right (+x), -1 for left. Poses are in the parent part's space: x right, y up, -z forward;
	-- a positive turn about z tips the top toward -x (left), a positive turn about x swings a limb forward.
	local function pose(side)
		local lead, trail = if side > 0 then "Right" else "Left", if side > 0 then "Left" else "Right"
		-- arms keep the run's hold (fists in front of the chest), the outside one lifting a little
		local hold = {
			Right = CFrame.Angles(rad(48), rad(-18), rad(-14)),
			Left = CFrame.Angles(rad(48), rad(18), rad(14)),
		}
		return {
			-- a compact throw: ~38° into the way you go, low and still hunched forward
			LowerTorso = CFrame.new(0.3 * side, -0.5, 0) * CFrame.Angles(rad(-12), rad(-5 * side), rad(-22 * side)),
			UpperTorso = CFrame.Angles(rad(-8), rad(4 * side), rad(-6 * side)),
			Head = CFrame.Angles(rad(12), 0, rad(28 * side)), -- (head stays upright-ish, looking ahead)
			-- the inside leg stays under you, bent, foot near the ground...
			[lead .. "UpperLeg"] = CFrame.Angles(rad(30), 0, rad(30 * side)),
			[lead .. "LowerLeg"] = CFrame.Angles(rad(-52), 0, 0),
			[lead .. "Foot"] = CFrame.Angles(rad(18), 0, rad(-12 * side)),
			-- ...only the outside leg kicks out to the side
			[trail .. "UpperLeg"] = CFrame.Angles(rad(8), 0, rad(-34 * side)),
			[trail .. "LowerLeg"] = CFrame.Angles(rad(-18), 0, 0),
			[trail .. "Foot"] = CFrame.Angles(0, 0, rad(14 * side)),
			[lead .. "UpperArm"] = hold[lead],
			[lead .. "LowerArm"] = CFrame.Angles(rad(72), 0, 0),
			[trail .. "UpperArm"] = CFrame.Angles(0, 0, rad(-18 * side)) * hold[trail],
			[trail .. "LowerArm"] = CFrame.Angles(rad(60), 0, 0),
		}
	end
	for _, dir in { { "DashLeft", -1 }, { "DashRight", 1 } } do
		local extra = pose(dir[2])
		local seq = Instance.new("KeyframeSequence")
		seq.Name = dir[1]
		seq.Loop = false
		seq.Priority = Enum.AnimationPriority.Action
		local function keyframe(t, amount, style, edir, lift)
			local k = first:Clone()
			k.Time = t
			for _, p in k:GetDescendants() do
				if p.ClassName == "Pose" then
					local e = extra[p.Name]
					if e and amount > 0 then
						p.CFrame = p.CFrame * CFrame.identity:Lerp(e, amount)
					end
					if p.Name == "LowerTorso" and lift then
						p.CFrame = CFrame.new(0, lift, 0) * p.CFrame
					end
					p.EasingStyle = Enum.PoseEasingStyle[style]
					p.EasingDirection = Enum.PoseEasingDirection[edir]
				end
			end
			k.Parent = seq
		end
		keyframe(0, 0.35, "Cubic", "Out") -- (already leaning as it starts)
		keyframe(0.06, 1, "Cubic", "Out", 0.12) -- push off: a small lift
		keyframe(0.15, 1, "Cubic", "InOut") -- low, leaning into it
		keyframe(0.27, 0.9, "Cubic", "Out")
		keyframe(0.4, 0, "Linear", "In") -- then eases quickly back into the run
		seq.Parent = folder
		print(string.format("%-14s <- built (sideways huss)", dir[1]))
	end
end

local dances = roblox.deserializePlace(fs.readFile(DIR .. "200-dances.rbxl"))
for _, d in DANCES do
	local seq = add(find(dances, d[2]), "Dance_" .. d[1], "Action", true)
	print(string.format("%-20s <- %-28s %d keyframes", "Dance_" .. d[1], d[2], keyCount(seq)))
end

fs.writeFile(OUT, roblox.serializeModel({ folder }))
print(string.format("saved %s (%.1f MB)", OUT, #fs.readFile(OUT) / 1e6))
