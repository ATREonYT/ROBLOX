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
local G = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/FollowGuard.lua"), { debugName = "FollowGuard" })()

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
local function hidden(p)
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
check("a dark block welded to his hip from outside is hidden", hidden(block))
check("a part hanging off that block is hidden", hidden(hanger))
check("a part held by a constraint from outside is hidden", hidden(roped))
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
	for _, p in followers do p.CFrame = p.CFrame + step end
	bobFollower.CFrame = bobFollower.CFrame + step
	fPart.CFrame = fPart.CFrame + step
	tick(t, bodies)
	if t == 2 then
		check("not yet: 10 studs isn't following", not hidden(follower))
	end
end
check("a small block that followed alex 20 studs is hidden", hidden(follower))
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

print(string.format("FollowGuard: %d passed, %d failed", passed, failed))
if failed > 0 then error("FollowGuard spec failed") end
