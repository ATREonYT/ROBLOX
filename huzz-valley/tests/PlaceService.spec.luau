--[[
	Moving a player's body, Oct 20 (owner, 15:13: "please make the DSYNC way, way better. right now on peoples screens
	it sometimes doesnt match up and the peoples locations are off on eachothers screens"):
	  - the server never sets the CFrame of a body the player's own client simulates: it asks that screen to move it
	    (HuzzServer/PlaceService -> Net "Place" -> HuzzClient/Gameplay/PlaceSelf), and moves it itself only when the
	    screen never does (once, after a grace and the player's round trip);
	  - a player who arrived and ran on is not pulled back; a body that respawned meanwhile is left alone;
	  - an anchored body (lying caught: the server owns it) is moved by the server at once;
	  - the round, the line-up, the safe zones and the fall net all go through it (no character PivotTo left in
	    RoundService or MapService but the noted reset-while-down one).
	Run from huzz-valley/: lune run tests/PlaceService.spec.luau
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

local SRC = "src/"

-- A fake body: a root part and PivotTo, like a character on the server.
local function body(at: Vector3, anchored: boolean?)
	local root = { Position = at, Anchored = anchored or false, AssemblyLinearVelocity = Vector3.new(30, 0, 0), AssemblyAngularVelocity = Vector3.new(0, 5, 0) }
	function root.IsA(_, c) return c == "BasePart" end
	local character = { PrimaryPart = root }
	function character.FindFirstChild(_, name) return if name == "HumanoidRootPart" then root else nil end
	function character.GetDescendants() return { root } end
	function character.PivotTo(_, cf) root.Position = cf.Position end
	return character, root
end

local function player(character)
	local p = { Name = "Tester", Character = character }
	function p.GetNetworkPing() return 0.05 end
	function p.RequestStreamAroundAsync() end
	return p
end

-- PlaceService with a recording remote (a fresh copy per test: its own counters and waits).
local function loadPlaceService()
	local fired = {}
	local NET, CONFIG = {}, {}
	local mods = {
		[NET] = { get = function() return { FireClient = function(_, p, c, cf) table.insert(fired, { p = p, c = c, cf = cf }) end } end },
		[CONFIG] = { Place = { Grace = 0.1, Near = 4, StreamWait = 0 } },
	}
	local services = {
		ReplicatedStorage = { Shared = { Net = NET, Config = { Round = CONFIG } } },
		Players = { PlayerRemoving = { Connect = function() end } },
	}
	local env = {
		game = { GetService = function(_, n) return services[n] end },
		require = function(x) return assert(mods[x], "unexpected require") end,
		task = task, Vector3 = Vector3, CFrame = CFrame,
	}
	local source = fs.readFile(SRC .. "ServerScriptService/HuzzServer/PlaceService.lua")
	return luau.load(source, { debugName = "PlaceService", environment = env })(), fired
end

local HERE, SPOT = Vector3.new(0, 3, 0), CFrame.new(100, 3, 50)
local WAIT = 0.6 -- (longer than Grace + the round trip: 0.1 + 0.1)

-- The screen answers: the server only asked, wrote nothing, and never moves the body itself.
do
	local PS, fired = loadPlaceService()
	local c, root = body(HERE)
	local p = player(c)
	PS.place(p, SPOT, "line")
	task.wait(0.02)
	check("the owner's screen is asked once, with its body and the spot", #fired == 1 and fired[1].p == p and fired[1].c == c and fired[1].cf == SPOT)
	check("the server writes nothing to a body the client simulates", root.Position == HERE)
	check("a move on its way is pending", PS.pending(p))
	c:PivotTo(SPOT) -- (PlaceSelf on the owner's screen; the next physics update brings it to the server)
	check("pending clears once the server's copy has arrived", not PS.pending(p))
	task.wait(WAIT)
	check("no server fallback when the screen moved it", PS.fallbacks == 0 and root.Position == SPOT.Position)
end

-- Arrived, then ran on: not pulled back to the spot (the first version checked only at the end and did).
do
	local PS = loadPlaceService()
	local c, root = body(HERE)
	local p = player(c)
	PS.place(p, SPOT, "out of a safe zone")
	task.wait(0.07)
	c:PivotTo(SPOT)
	task.wait(0.07)
	c:PivotTo(SPOT * CFrame.new(0, 0, -12)) -- (running on)
	task.wait(WAIT)
	check("a player who arrived and ran on keeps running", PS.fallbacks == 0 and (root.Position - SPOT.Position).Magnitude > 10)
end

-- A screen that never answers (an old client): the server moves it, once.
do
	local PS = loadPlaceService()
	local c, root = body(HERE)
	local p = player(c)
	PS.place(p, SPOT, "lobby")
	task.wait(WAIT)
	check("a screen that never answers: the server moves it once", PS.fallbacks == 1 and root.Position == SPOT.Position and root.AssemblyLinearVelocity == Vector3.zero)
	check("nothing pending after the fallback", not PS.pending(p))
end

-- still (the Lasso's fallback pull): a move no longer wanted when it would happen is dropped, never made
do
	local PS = loadPlaceService()
	local c, root = body(HERE)
	local p = player(c)
	local ok = true
	PS.place(p, SPOT, "lasso", function() return ok end)
	ok = false -- (became safe meanwhile)
	task.wait(WAIT)
	check("a move whose still() turned false is never made, by the screen or the server", PS.fallbacks == 0 and root.Position == HERE and not PS.pending(p))
	local c2, root2 = body(HERE)
	local p2 = player(c2)
	PS.place(p2, SPOT, "lasso", function() return true end)
	task.wait(WAIT)
	check("a still() that stays true moves as usual (server fallback for a silent screen)", PS.fallbacks == 1 and root2.Position == SPOT.Position)
	check("lastMoveAt(player) says when a move was last sent (a lasso pull drops for a move sent round the catch)",
		PS.lastMoveAt(p) > 0 and PS.lastMoveAt(p2) >= PS.lastMoveAt(p) and PS.lastMoveAt(player(body(HERE))) == 0)
end

-- Respawned while the move was on its way: the old body is left alone.
do
	local PS = loadPlaceService()
	local c, root = body(HERE)
	local p = player(c)
	PS.place(p, SPOT, "line")
	p.Character = body(Vector3.new(-50, 3, 0))
	task.wait(WAIT)
	check("a body replaced meanwhile is never moved", PS.fallbacks == 0 and root.Position == HERE)
end

-- Anchored (lying caught: the server owns it): moved by the server at once, no ask.
do
	local PS, fired = loadPlaceService()
	local c, root = body(HERE, true)
	local p = player(c)
	PS.place(p, SPOT, "line")
	check("an anchored body is moved by the server at once", root.Position == SPOT.Position and #fired == 0 and not PS.pending(p))
end

-- The screen's side (Gameplay/PlaceSelf): only your own, unanchored body; stopped, then moved.
do
	local env = { typeof = roblox.typeof or typeof, Vector3 = Vector3 }
	local PlaceSelf = luau.load(fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/PlaceSelf.lua"), { debugName = "PlaceSelf", environment = env })()
	local mine, root = body(HERE)
	local me = player(mine)
	local other, otherRoot = body(HERE)
	check("PlaceSelf ignores a body that isn't yours", PlaceSelf.apply(me, other, SPOT) == false and otherRoot.Position == HERE)
	check("PlaceSelf ignores a CFrame that isn't one", PlaceSelf.apply(me, mine, "x") == false and root.Position == HERE)
	check("PlaceSelf moves your body there, stopped", PlaceSelf.apply(me, mine, SPOT) and root.Position == SPOT.Position
		and root.AssemblyLinearVelocity == Vector3.zero and root.AssemblyAngularVelocity == Vector3.zero)
	local held, heldRoot = body(HERE, true)
	check("PlaceSelf leaves an anchored body to the server", PlaceSelf.apply(player(held), held, SPOT) == false and heldRoot.Position == HERE)
end

-- The source: every move of a live player goes through PlaceService (the old code set CFrames here directly).
do
	local round = fs.readFile(SRC .. "ServerScriptService/HuzzServer/RoundService.server.lua")
	local map = fs.readFile(SRC .. "ServerScriptService/HuzzServer/MapService.lua")
	local pivots = {}
	for line in string.gmatch(round, "[^\n]+") do
		if string.find(line, ":PivotTo%(") and not string.match(line, "^%s*%-%-") then
			table.insert(pivots, line)
		end
	end
	check("RoundService pivots no player's body but the reset while down (anchored next)", #pivots == 1 and string.find(pivots[1], "fellAt", 1, true) ~= nil)
	check("RoundService places through PlaceService (lobby, middle, line, safe zones)", select(2, string.gsub(round, "PlaceService%.place%(", "")) >= 6)
	check("the fall net places through PlaceService", string.find(map, "PlaceService.place(player", 1, true) ~= nil)
	check("PlaceSelf runs on every screen", string.find(fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/HuzzClient/StartGameplay.client.lua"), "\"PlaceSelf\"", 1, true) ~= nil)
	check("Net has the Place remote", string.find(fs.readFile(SRC .. "ReplicatedStorage/Shared/Net.lua"), "Place = \"RemoteEvent\"", 1, true) ~= nil)
end

print(string.format("PlaceService: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("PlaceService spec failed")
end
