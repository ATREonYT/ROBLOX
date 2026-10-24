-- lune run tests/OthersAhead.spec.luau   (from huzz-valley/)
-- Gameplay/OthersAhead (owner, Oct 22 19:45: two screens of one round, "you see the difference in user locations,
-- please fix it with the desync"): every other body is drawn ahead along its movement by your half ping + Roblox's
-- smoothing, so each screen shows it about where the server has it now. Real Lune Instances, fake Players:
--   the lead (ping 55 ms: 0.13 s; capped), the distance (a run, a dive capped at MaxStuds, a teleport and a still
--   body not moved), a running body's torso drawn that far ahead under a turned root while its root stays, your own
--   body never touched, a body lying caught eased back, the server's own C0 change kept, a body that leaves let go.
-- Stamps (Oct 23, Shared/MotionStamps): with a fresh one the body is drawn where it says the body is now (not the
--   guess), a turn its keys ask for shows before Roblox's copy turns, a late (older) stamp never undoes a newer one,
--   a stale stamp or a teleport falls back, and the Practice Bot (tagged HuzzBot) is drawn from its stamps too.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local Round = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/Config/Round.lua"), { debugName = "Round", environment = { Color3 = roblox.Color3, Vector3 = Vector3, CFrame = CFrame, Enum = roblox.Enum } })()
local players = {}
-- (since Oct 24 only bodies playing in a game are drawn ahead: these all play)
local function playing(_, name) return if name == "HuzzRole" then "Runner" else nil end
local me = { Name = "me", Character = nil, GetNetworkPing = function() return 0.055 end }
local fakePlayers = { LocalPlayer = me, GetPlayers = function() return players end }
local MotionStamps = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/MotionStamps.lua"), { debugName = "MotionStamps", environment = { Vector3 = Vector3 } })()
local fakeShared = { Config = { Round = Round }, MotionStamps = MotionStamps }
local fakeRS = { WaitForChild = function() return fakeShared end }
local serverNow = 1000
local bots = {}
local services = {
	Players = fakePlayers,
	Workspace = { GetServerTimeNow = function() return serverNow end },
	CollectionService = { GetTagged = function(_, tag) return if tag == "HuzzBot" then bots else {} end },
}
local OA = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/OthersAhead.lua"), { debugName = "OthersAhead",
	environment = { Vector3 = Vector3, CFrame = CFrame, game = { GetService = function(_, n) return services[n] or fakeRS end }, require = function(x) return x end } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b, eps) return (a - b).Magnitude < (eps or 0.01) end

-- an R6 body: root, torso, the RootJoint as Roblox makes it
local BASE = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), math.rad(180), 0)
local C1 = BASE
local function body(name, at: CFrame)
	local m = Instance.new("Model"); m.Name = name
	local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = at; root.Parent = m
	local torso = Instance.new("Part"); torso.Name = "Torso"; torso.Parent = m
	local j = Instance.new("Motor6D"); j.Name = "RootJoint"; j.Part0 = root; j.Part1 = torso; j.C0 = BASE; j.C1 = C1; j.Parent = root
	return m, root, j
end
local function drawn(root, j) return (root.CFrame * j.C0 * j.C1:Inverse()).Position end
local function sameCF(a, b) return near(a.Position, b.Position, 1e-3) and near(a.LookVector, b.LookVector, 1e-4) and near(a.UpVector, b.UpVector, 1e-4) end
local function frames(n) for _ = 1, n do OA.step(1 / 60) end end

local A = Round.Ahead
check(string.format("the lead at 55 ms ping: half of it + smoothing (%.3f s)", OA.lead(0.055)), math.abs(OA.lead(0.055) - (0.0275 + A.Interp)) < 1e-6)
check("a very slow connection is capped", OA.lead(2) == A.MaxLead)
local lead = OA.lead(0.055)
check("a run at 24 studs/s: drawn 24 x the lead ahead", near(OA.target(Vector3.new(24, 0, 0), lead), Vector3.new(24 * lead, 0, 0)))
check("up and down don't count (a jump, a fall)", near(OA.target(Vector3.new(0, 50, -24), lead), Vector3.new(0, 0, -24 * lead)))
check("a dive at 72 studs/s: at most MaxStuds", math.abs(OA.target(Vector3.new(0, 0, 72), A.MaxLead).Magnitude - math.min(72 * A.MaxLead, A.MaxStuds)) < 1e-6)
check("a teleport's speed: drawn where it is", OA.target(Vector3.new(900, 0, 0), lead) == Vector3.zero)
check("standing still: drawn where it is", OA.target(Vector3.new(0.1, 0, 0), lead) == Vector3.zero)

-- a runner going +X with their root turned (facing +X); you standing
local runner, rRoot, rJoint = body("Runner", CFrame.new(10, 3, 0) * CFrame.Angles(0, math.rad(-90), 0))
local mine, mRoot, mJoint = body("Me", CFrame.new(0, 3, 0))
rRoot.AssemblyLinearVelocity = Vector3.new(24, 0, 0)
mRoot.AssemblyLinearVelocity = Vector3.new(24, 0, 0)
me.Character = mine
players = { me, { Name = "runner", Character = runner, GetAttribute = playing } }
local before = drawn(rRoot, rJoint)
frames(120)
local shift = drawn(rRoot, rJoint) - before
check(string.format("the running body is drawn %.2f studs ahead along its run (want %.2f)", shift.X, 24 * lead), near(shift, Vector3.new(24 * lead, 0, 0), 0.02))
check("its root stays where Roblox has it", rRoot.CFrame.Position == Vector3.new(10, 3, 0))
check("HitCheck gets the same offset", near(OA.offset(runner), shift, 0.02))
check("your own body is never moved", sameCF(mJoint.C0, BASE) and OA.offset(mine) == Vector3.zero)
check("the joint's turn is untouched (poses on top stay right)", sameCF(rJoint.C0.Rotation, BASE.Rotation))

-- it eases in: one frame in it's only part of the way
local r2, r2Root, r2Joint = body("Runner2", CFrame.new(0, 3, 20))
r2Root.AssemblyLinearVelocity = Vector3.new(0, 0, -24)
players = { me, { Name = "runner", Character = runner, GetAttribute = playing }, { Name = "r2", Character = r2, GetAttribute = playing } }
OA.step(1 / 60)
local first = OA.offset(r2).Magnitude
check(string.format("it eases in (%.2f studs after one frame)", first), first > 0 and first < 24 * lead * 0.5)

-- caught (anchored): eased back to where it is
rRoot.Anchored = true
frames(120)
check("a body lying caught is drawn where it is", near(drawn(rRoot, rJoint), before, 0.02))

-- the server changes the joint (a resized body): that's the new base
rRoot.Anchored = false
local NEW = CFrame.new(0, 0.3, 0) * BASE.Rotation
rJoint.C0 = NEW
frames(120)
check("the server's own change is kept under the shift", near((rJoint.C0.Position - rRoot.CFrame:VectorToObjectSpace(OA.offset(runner))), NEW.Position, 0.02))

-- they leave: the joint is let go
players = { me }
OA.step(1 / 60)
check("a body that leaves gets its joint back", sameCF(rJoint.C0, NEW) and sameCF(r2Joint.C0, BASE))

-- Stamps: a runner whose own screen says it's at x = 3, 0.1 s ago, running +X at 24 (Roblox has it at x = 0)
local Z = Vector3.zero
local s1, s1Root = body("Stamped", CFrame.new(0, 3, 40))
s1Root.AssemblyLinearVelocity = Vector3.new(24, 0, 0)
players = { me, { Name = "s1", Character = s1, GetAttribute = playing } }
OA.stamp(s1, serverNow - 0.1, Vector3.new(3, 3, 40), Vector3.new(24, 0, 0), Vector3.new(24, 0, 0), false)
frames(60)
check(string.format("a fresh stamp: drawn where it says the body is now (%.2f, want 5.40)", OA.offset(s1).X), near(OA.offset(s1), Vector3.new(5.4, 0, 0), 0.02))
-- a late, older stamp arrives: ignored
OA.stamp(s1, serverNow - 0.4, Vector3.new(-20, 3, 40), Z, Z, false)
frames(5)
check("an older stamp that arrives late never undoes a newer one", near(OA.offset(s1), Vector3.new(5.4, 0, 0), 0.02))
-- the keys turn to -Z; Roblox's copy (and its speed) hasn't turned yet
OA.stamp(s1, serverNow - 0.1, Vector3.new(3, 3, 40), Vector3.new(24, 0, 0), Vector3.new(0, 0, -24), false)
frames(60)
local turned = OA.offset(s1)
check(string.format("a turn shows as soon as its stamp arrives (%.2f studs along the new way)", -turned.Z), turned.Z < -0.5)
-- a stamp 1 s old: back to the guess from the drawn speed
OA.stamp(s1, serverNow + 0.5, Vector3.new(0, 3, 40), Vector3.new(24, 0, 0), Vector3.new(24, 0, 0), false)
serverNow += 1.6
frames(120)
check("a stale stamp: the old guess takes over", near(OA.offset(s1), OA.target(s1Root.AssemblyLinearVelocity, OA.lead()), 0.05))
-- a teleport: the stamp is far from Roblox's copy, so drawn where Roblox has it
OA.stamp(s1, serverNow, Vector3.new(300, 3, 40), Z, Z, false)
frames(120)
check("a stamp miles away (a teleport): drawn where it is", near(OA.offset(s1), Z, 0.02))
check("a broken stamp is ignored", (function() OA.stamp(s1, 0 / 0, Z, Z, Z, false); OA.stamp(s1, serverNow, "x", Z, Z); return true end)())
-- the Practice Bot: a model tagged HuzzBot, stamped by the server
local bot, botRoot = body("PracticeBot", CFrame.new(0, 3, -40))
botRoot.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
bots = { bot }
OA.stamp(bot, serverNow - 0.05, Vector3.new(0, 3, -42), Vector3.new(0, 0, -20), Vector3.new(0, 0, -20), false)
frames(60)
check(string.format("the Practice Bot is drawn from its stamps too (%.2f, want -3.00)", OA.offset(bot).Z), near(OA.offset(bot), Vector3.new(0, 0, -3), 0.02))
check("its root stays where Roblox has it", botRoot.CFrame.Position == Vector3.new(0, 3, -40))
-- a batch from the server (a few stamps in one message); a new stamp that disagrees a little is eased in, not popped
local b1, b1Root = body("Batch", CFrame.new(0, 3, 80))
b1Root.AssemblyLinearVelocity = Z
players = { me, { Name = "b1", Character = b1, GetAttribute = playing } }
OA.stamps({ { b1, serverNow, Vector3.new(2, 3, 80), Z, Z, 0 }, { "junk" }, 5 })
frames(60)
check("a batch of stamps is read (junk in it ignored)", near(OA.offset(b1), Vector3.new(2, 0, 0), 0.02))
OA.stamps({ { b1, serverNow + 0.01, Vector3.new(3, 3, 80), Z, Z, 0 } })
OA.step(1 / 60)
local mid = OA.offset(b1).X
check(string.format("a new stamp 1 stud off is eased in (%.2f after one frame)", mid), mid > 2.05 and mid < 2.95)
frames(60)
check("and gets there", near(OA.offset(b1), Vector3.new(3, 0, 0), 0.02))
-- a moving body whose stamps stop coming (a hitch): not carried on
OA.stamps({ { b1, serverNow + 0.02, Vector3.new(3, 3, 80), Vector3.new(24, 0, 0), Vector3.new(24, 0, 0), 0 } })
local t0 = os.clock()
while os.clock() - t0 < 0.25 do end
frames(60)
check("a moving body gone quiet isn't carried on (the guess: still)", near(OA.offset(b1), Z, 0.02))

-- caught mid-run: the last stamp would carry them on, so it's dropped
bot:SetAttribute("DownedAt", 1)
botRoot.AssemblyLinearVelocity = Z
frames(120)
check("a body caught mid-run isn't carried on by its last stamp", near(OA.offset(bot), Z, 0.02))

print(string.format("OthersAhead: %d ok, %d failed", passed, failed))
if failed > 0 then error("OthersAhead spec failed") end
