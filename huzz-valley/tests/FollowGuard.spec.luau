-- lune run tests/FollowGuard.spec.luau   (from huzz-valley/)
-- Gameplay/FollowGuard: each screen takes away the owner's "black thing following my character" (Oct 20 20:34) by
-- itself. Real Lune Instances in a fake Workspace: two bodies (alex, bob), then
--   (a) parts held to a body from outside its model: a dark block welded to his hip, one hanging off that block, one
--       held by a constraint: hidden, one [HuzzBlock] line each; and what must stay: the worn knife, the carried
--       girl, the Shield bubble, a seat he sits on, an anchored part welded to him, an invisible part;
--   (b) small parts that keep up with a body: a loose block trailing alex and one trailing bob: hidden; and what must
--       stay: a static part he walks past or circles, a big part, his companion, a catcher's follower girl, the knife
--       motes, the crown, a burst, a stand copy.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3 = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
-- (FollowGuard asks ReplicatedStorage for Shared/LooseParts: handed the real one here)
local LP = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/LooseParts.lua"), { debugName = "LooseParts" })()
local fakeShared = { WaitForChild = function(self) return self end }
local G = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/FollowGuard.lua"), { debugName = "FollowGuard",
	environment = { game = { GetService = function() return fakeShared end }, require = function() return LP end } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local game = Instance.new("DataModel")
local ws = game:GetService("Workspace")

local function part(name, parent, at: Vector3, size: Vector3?, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size or Vector3.new(0.5, 1.2, 0.5)
	p.CFrame = CFrame.new(at)
	p.Color = Color3.fromRGB(32, 30, 38)
	p.Anchored = false
	p.CastShadow = false
	for k, v in props or {} do p[k] = v end
	p.Parent = parent
	return p
end
local function folder(name, parent)
	local f = Instance.new(if name:sub(1, 1) == "!" then "Model" else "Folder")
	f.Name = name:gsub("^!", "")
	f.Parent = parent or ws
	return f
end
local function weld(class, name, a, b)
	local w = Instance.new(class)
	w.Name = name
	w.Part0, w.Part1 = a, b
	w.Parent = b
	return w
end
local function body(name, at: Vector3)
	local m = Instance.new("Model")
	m.Name = name
	Instance.new("Humanoid").Parent = m
	local root = part("HumanoidRootPart", m, at, Vector3.new(2, 2, 1), { Transparency = 1 })
	local lower = part("LowerTorso", m, at - Vector3.new(0, 1, 0), Vector3.new(2, 0.4, 1))
	local upper = part("UpperTorso", m, at + Vector3.new(0, 0.5, 0), Vector3.new(2, 1.6, 1))
	weld("Motor6D", "Root", root, lower)
	weld("Motor6D", "Waist", lower, upper)
	m.Parent = ws
	return m, root, lower, upper
end

-- joints(part): every weld, motor and constraint in the world that holds it (as Roblox's part:GetJoints())
local function joints(p)
	local out = {}
	for _, d in ws:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			local a, b = G.ends(d)
			if a == p or b == p then table.insert(out, d) end
		end
	end
	return out
end
-- gone from view: removed (Oct 21: "don't try to hide it, remove it"), or at least hidden
local function hidden(p)
	local ok, parent = pcall(function() return p.Parent end)
	if not ok or parent == nil then return true end
	local ltm = 0
	pcall(function() ltm = p.LocalTransparencyModifier end)
	return p.Transparency >= 1 or ltm >= 1
end

local alex, root, lower, upper = body("alex", Vector3.new(0, 3, 0))
local bob, bobRoot = body("bob", Vector3.new(60, 3, 0))

-- the worn knife (inside his model, welded to the hip)
local knife = folder("!HuzzBackKnife", alex)
local handle = part("Handle", knife, Vector3.new(1, 2, 0.6), Vector3.new(0.22, 0.75, 0.26))
weld("Weld", "BackMount", lower, handle)
-- a hat on an AccessoryRigidConstraint (inside his model)
local acc = Instance.new("Accessory"); acc.Parent = alex
local hat = part("Handle", acc, Vector3.new(0, 5, 0), Vector3.new(1, 1, 1))
weld("Weld", "AccessoryWeld", upper, hat)

-- (a) held to him from outside his model
local junk = folder("Junk")
local block = part("Block", junk, Vector3.new(2, 0.6, -2))
weld("Weld", "Weld", lower, block)
local hanger = part("Hanger", junk, Vector3.new(2, 0.2, -2), Vector3.new(0.3, 0.3, 0.3))
weld("WeldConstraint", "WeldConstraint", block, hanger)
local roped = part("Roped", junk, Vector3.new(-2, 1, 0))
local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
b0.Parent, b1.Parent = roped, upper
local bs = Instance.new("BallSocketConstraint"); bs.Attachment0, bs.Attachment1 = b0, b1; bs.Parent = roped
-- ... and what must stay
local carried = folder("!Girl", folder("HuzzCarried"))
Instance.new("Humanoid").Parent = carried
local girlRoot = part("HumanoidRootPart", carried, Vector3.new(0, 4, 1), Vector3.new(1, 1, 0.5))
weld("Motor6D", "HuzzCarryMotor", upper, girlRoot)
local bubble = part("HuzzShield", folder("HuzzShields"), Vector3.new(0, 3, 0), Vector3.new(7, 7, 7), { Transparency = 0.6 })
weld("WeldConstraint", "WeldConstraint", root, bubble)
local seat = Instance.new("Seat"); seat.Name = "Bench"; seat.Size = Vector3.new(2, 1, 2); seat.CFrame = CFrame.new(0, 1, 0); seat.Parent = ws
weld("Weld", "SeatWeld", seat, root)
local wall = part("Wall", ws, Vector3.new(0, 1, 3), Vector3.new(1, 1, 1), { Anchored = true })
weld("Weld", "Weld", wall, root)
local ghost = part("Invisible", junk, Vector3.new(0, 1, -1), nil, { Transparency = 1 })
weld("Weld", "Weld", upper, ghost)

-- (b) the things near the bodies
local follower = part("Trailing", ws, Vector3.new(2, 0.6, 2))
local bobFollower = part("BobBlock", ws, Vector3.new(62, 0.6, 2))
local static = part("Lantern", ws, Vector3.new(1, 1, 1), Vector3.new(1, 2, 1), { Anchored = true, CastShadow = true })
local big = part("Crate", ws, Vector3.new(2, 2, 0), Vector3.new(4, 4, 4))
local companion = folder("!Companion", folder("HuzzCompanions"))
Instance.new("Humanoid").Parent = companion
local compPart = part("Torso", companion, Vector3.new(-2, 1.5, 2), Vector3.new(0.8, 1, 0.5))
local fGirl = folder("!Follower_bob", folder("HuzzFollowers"))
Instance.new("Humanoid").Parent = fGirl
local fPart = part("Torso", fGirl, Vector3.new(58, 1.5, 2), Vector3.new(0.8, 1, 0.5))
local mote = part("Ball", folder("HuzzKnifeMotes"), Vector3.new(1, 2, 1), Vector3.new(0.2, 0.2, 0.2))
local crownPart = part("Band", folder("!HuzzCrown"), Vector3.new(0, 5, 0), Vector3.new(1, 0.3, 1), { Anchored = true })
local spark = part("Spark", folder("HuzzBursts"), Vector3.new(0, 3, 1), Vector3.new(0.3, 0.3, 0.3))
local stand = folder("!StandAvatar", folder("HuzzStandAvatars"))
Instance.new("Humanoid").Parent = stand
local standPart = part("RightHand", stand, Vector3.new(-1, 1, -1), Vector3.new(1, 0.3, 1))

local followers = { follower, compPart, mote, crownPart, spark, big, standPart }
local lines = {}
local state = {}
local function tick(t, bodies)
	local io = { joints = joints, pool = G.collect(ws), say = function(s) table.insert(lines, s) end }
	return G.check(bodies, state, io, t)
end
local function move(m, by: Vector3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = d.CFrame + by end
	end
end

-- t = 0: both bodies stand; (a) is found at once
local bodies = { { name = "alex", character = alex, root = root }, { name = "bob", character = bob, root = bobRoot } }
tick(0, bodies)
check("a dark block welded to his hip from outside is removed", hidden(block))
check("a part hanging off that block is removed", hidden(hanger))
check("a part held by a constraint from outside is removed", hidden(roped))
local blockLine
for _, l in lines do if string.find(l, "Junk.Block:", 1, true) then blockLine = l end end
check("the block gets one [HuzzBlock] line", blockLine ~= nil and string.sub(blockLine, 1, 18) == "[HuzzBlock] hid Wo")
check("its line says why, size, colour, class, anchored and what holds it", blockLine ~= nil
	and string.find(blockLine, "joined to alex's body", 1, true) ~= nil and string.find(blockLine, "0.50 x 1.20 x 0.50", 1, true) ~= nil
	and string.find(blockLine, "colour 32,30,38", 1, true) ~= nil and string.find(blockLine, "; Part,", 1, true) ~= nil
	and string.find(blockLine, "anchored false", 1, true) ~= nil and string.find(blockLine, "held by ", 1, true) ~= nil and string.find(blockLine, "Weld Weld -> Workspace.alex.LowerTorso", 1, true) ~= nil
	and string.find(blockLine, "in Workspace (Workspace) > Junk (Folder) > Block (Part)", 1, true) ~= nil)
check("the worn knife stays", not hidden(handle))
check("his hat stays", not hidden(hat))
check("the carried girl stays", not hidden(girlRoot))
check("the Shield bubble stays", not hidden(bubble))
check("the seat he sits on stays", not hidden(seat))
check("an anchored part he's welded to stays", not hidden(wall))
check("an invisible part gets no line", #lines == 3)
check("his own body is never hidden", not hidden(lower) and not hidden(upper))

-- t = 1..4: each body walks 5 studs a second; the trailing blocks and our own followers keep up; the rest stay put
for t = 1, 4 do
	local step = Vector3.new(5, 0, 0)
	move(alex, step)
	move(bob, step)
	for _, p in followers do pcall(function() p.CFrame = p.CFrame + step end) end -- (a removed one is gone)
	pcall(function() bobFollower.CFrame = bobFollower.CFrame + step end)
	fPart.CFrame = fPart.CFrame + step
	tick(t, bodies)
	if t == 2 then
		check("not yet: 10 studs isn't following", not hidden(follower))
	end
end
check("a small block that followed alex 20 studs is removed", hidden(follower))
check("one that followed bob is hidden too (every body, on every screen)", hidden(bobFollower))
local bobLine
for _, l in lines do if string.find(l, "BobBlock", 1, true) then bobLine = l end end
check("its line says whom it followed", bobLine ~= nil and string.find(bobLine, "followed bob for", 1, true) ~= nil)
check("the lantern he walked past stays", not hidden(static))
check("a big part stays", not hidden(big))
check("his companion stays", not hidden(compPart))
check("a catcher's follower girl stays", not hidden(fPart))
check("the knife motes stay", not hidden(mote))
check("the crown stays", not hidden(crownPart))
check("a burst's spark stays", not hidden(spark))
check("a stand copy stays", not hidden(standPart))

-- circling a static part (never more than 11 studs from where it first came near) never counts as following
local post = part("Post", ws, Vector3.new(200, 1, 0), Vector3.new(0.5, 3, 0.5), { Anchored = true })
local loner, lonerRoot = body("carl", Vector3.new(203.5, 3, 0))
local circle = { { name = "carl", character = loner, root = lonerRoot } }
for i = 1, 24 do
	local a = i / 24 * 2 * math.pi
	local want = Vector3.new(200 + 3.5 * math.cos(a), 3, 3.5 * math.sin(a))
	move(loner, want - lonerRoot.CFrame.Position)
	tick(4 + i, circle)
end
check("walking round a post doesn't hide it", not hidden(post))

local before = #lines
tick(40, bodies)
check("nothing is told twice", #lines == before)

-- (c) loose inside a character (Oct 21: his close-up has the block outlined with his legs: it's in his character).
-- A body with real limbs (dana): a dark grip-sized box inside her worn knife, 3 studs to her side at her shins, is
-- removed (gone, not hidden) with one "[HuzzBlock] removed" line; a loose box straight in her model too; what stays:
-- her worn knife's grip at the hip, a small accessory on her, big wings reaching out, the knife in her hand at arm's
-- length, an invisible part far off.
do
	local dana, danaRoot, danaLower = body("dana", Vector3.new(-80, 3, 0))
	local function limb(name, at, size) return part(name, dana, at, size) end
	limb("Head", Vector3.new(-80, 4.9, 0), Vector3.new(1.2, 1.2, 1.2))
	limb("LeftUpperLeg", Vector3.new(-80.5, 1.4, 0), Vector3.new(1, 1.2, 1))
	limb("LeftLowerLeg", Vector3.new(-80.5, 0.5, 0), Vector3.new(1, 0.9, 1))
	limb("RightUpperLeg", Vector3.new(-79.5, 1.4, 0), Vector3.new(1, 1.2, 1))
	limb("RightLowerLeg", Vector3.new(-79.5, 0.5, 0), Vector3.new(1, 0.9, 1))
	local dKnife = folder("!HuzzBackKnife", dana)
	local dGrip = part("Handle", dKnife, Vector3.new(-78.8, 2, 0.8), Vector3.new(0.22, 0.75, 0.26))
	local dBlock = part("Handle", folder("!HuzzBackKnife2", dana), Vector3.new(-83.2, 0.6, -1.2), Vector3.new(0.22, 0.75, 0.26))
	dBlock.CFrame = dBlock.CFrame * CFrame.Angles(0, 0, math.rad(20))
	local dLoose = part("Part", dana, Vector3.new(-80, 0.6, -3.6), Vector3.new(0.4, 1.2, 0.4), { Color = Color3.fromRGB(163, 162, 165) })
	local bag = Instance.new("Accessory"); bag.Parent = dana
	local bagHandle = part("Handle", bag, Vector3.new(-80.9, 2, -0.7), Vector3.new(0.7, 0.8, 0.4))
	local wings = Instance.new("Accessory"); wings.Parent = dana
	local wingHandle = part("Handle", wings, Vector3.new(-80, 4, 3.6), Vector3.new(6, 4, 0.5))
	local held = folder("!HuzzKnife", dana)
	local heldTip = part("Tip", held, Vector3.new(-80, 1, -5), Vector3.new(0.1, 0.4, 0.2))
	local dGhost = part("Hitbox", dana, Vector3.new(-80, 1, 8), Vector3.new(2, 2, 2), { Transparency = 1 })
	local found = {}
	for _, l in G.loose(dana) do found[l.part] = l.gap end
	check("(c) the grip-sized block 3 studs off her shins is found", found[dBlock] ~= nil)
	check("(c) a loose box in her model is found", found[dLoose] ~= nil)
	check("(c) her worn knife's grip at the hip stays", found[dGrip] == nil)
	check("(c) a small accessory on her stays", found[bagHandle] == nil)
	check("(c) big wings stay", found[wingHandle] == nil)
	check("(c) the knife in her hand stays", found[heldTip] == nil)
	check("(c) an invisible part stays", found[dGhost] == nil)
	local n0 = #lines
	tick(50, { { name = "dana", character = dana, root = danaRoot } })
	check("(c) the block is removed, not hidden", dBlock.Parent == nil and dLoose.Parent == nil)
	check("(c) her body and knife are still there", danaLower.Parent == dana and dGrip.Parent ~= nil and bagHandle.Parent ~= nil)
	local said
	for i = n0 + 1, #lines do if string.find(lines[i], "[HuzzBlock] removed", 1, true) then said = lines[i] end end
	check("(c) it says so on one [HuzzBlock] removed line", said ~= nil and string.find(said, "loose inside dana's character", 1, true) ~= nil)
	local none = #G.loose(Instance.new("Model")) == 0
	check("(c) a body still loading (no body parts) is left alone", none)
end

print(string.format("FollowGuard: %d passed, %d failed", passed, failed))
if failed > 0 then error("FollowGuard spec failed") end
