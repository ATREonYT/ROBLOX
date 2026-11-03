--!strict
-- The living neighbourhood (client only, nothing replicates, the server pays nothing). Booted last by Client.client.lua.
-- One Heartbeat drives everything: things near the camera update every frame, far things at Ambient.FarHz (10 Hz).
--   AmbientPeople   street people: walkers, stoop sitters, corner groups, vignette actors, chatter, scare
--   AmbientTraffic  4-6 cars on lane loops, corner braking, stop + honk, bass, night lights
--   AmbientBirds    pigeon flocks that scatter, birds on wires, gulls over the canal
--   AmbientSound    zone beds (day/night, 2 s crossfade) + nearest-8 positional emitters + one-shots
--   AmbientWindows  night window glow + TV flicker, laundry/flag sway
-- Positions come from Config/AmbientMap (generated: tools/SurveyHoodLife.lua -> tools/build_ambient_map.py), never
-- from map parts, so StreamingEnabled can't hide them. Tunables: Config/Ambient. Pure maths: Rules/AmbientRules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ambient = require(ReplicatedStorage.MTL.Config.Ambient)
local AmbientRules = require(ReplicatedStorage.MTL.Rules.AmbientRules)
local DayNightRules = require(ReplicatedStorage.MTL.Rules.DayNightRules)
local Net = require(ReplicatedStorage.MTL.Net)

local Lighting = require(script.Parent.LightingController)
local Cutscene = require(script.Parent.CutsceneController)
local People = require(script.Parent.AmbientPeople)
local Traffic = require(script.Parent.AmbientTraffic)
local Birds = require(script.Parent.AmbientBirds)
local Sound = require(script.Parent.AmbientSound)
local Windows = require(script.Parent.AmbientWindows)

local player = Players.LocalPlayer

local AmbientLife = {}

local ctx: any = nil
local package: any = {} -- optional controllers (MovementController, GunController), looked up in init
local conn: RBXScriptConnection? = nil

local function log(...)
	print("[MTL Ambient]", ...)
end

local function loadMap(): any
	local mod = ReplicatedStorage.MTL.Config:FindFirstChild("AmbientMap")
	if not mod then
		return nil
	end
	local ok, map = pcall(require, mod)
	return if ok and type(map) == "table" then map else nil
end

local function spotCF(s: any): CFrame
	return CFrame.new(s[2], s[3], s[4]) * CFrame.Angles(0, math.rad(s[5] or 0), 0)
end

local function build(map: any): any
	local c: any = {
		cfg = Ambient,
		R = AmbientRules,
		map = map,
		now = os.clock(),
		hour = 12,
		night = false,
		day = 0,
		camPos = Vector3.zero,
		camLook = Vector3.new(0, 0, -1),
		playerPos = nil,
		sprinting = false,
		calm = true,
		lastThreat = nil,
		peds = {},
		spots = {},
		spotsByKind = {},
		peopleSpots = {},
		walks = {},
		lanes = {},
	}
	local f = workspace:FindFirstChild("MTL_LocalAmbient")
	if f then
		f:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MTL_LocalAmbient"
	folder.Parent = workspace
	c.folder = folder
	-- street lights: after dark, people hang out near them
	local lamps: { Vector3 } = {}
	for _, l in map.Lamps or {} do
		table.insert(lamps, Vector3.new(l[1], l[2], l[3]))
	end
	-- spots: { kind, x, y, z, yawDeg, n?, pose? }
	for i, s in map.Spots or {} do
		local cf = spotCF(s)
		local spot = { i = i, kind = s[1], cf = cf, pos = cf.Position, n = s[6], pose = s[7], taken = 0, lit = false }
		for _, l in lamps do
			if Vector3.new(l.X - spot.pos.X, 0, l.Z - spot.pos.Z).Magnitude < Ambient.People.NightLampRadius then
				spot.lit = true
				break
			end
		end
		table.insert(c.spots, spot)
		c.spotsByKind[spot.kind] = c.spotsByKind[spot.kind] or {}
		table.insert(c.spotsByKind[spot.kind], spot)
		if spot.kind == "Stoop" or spot.kind == "Bench" or spot.kind == "Corner" or spot.kind == "Lean"
			or (string.sub(spot.kind, 1, 9) == "Vignette:") then
			table.insert(c.peopleSpots, spot)
		end
	end
	for _, w in map.Walks or {} do
		table.insert(c.walks, { y = w.y, path = AmbientRules.path(w.pts, w.loop == true) })
	end
	for _, l in map.Lanes or {} do
		table.insert(c.lanes, { y = l.y, speed = l.speed, path = AmbientRules.path(l.pts, l.loop ~= false, l.corners) })
	end
	return c
end

-- each helper runs in its own pcall: an error is logged (at most once per 30 s per helper) and the rest keep going.
-- 5 failures in a row switch that helper off for 10 s, then it gets another go.
type Guard = { fails: number, offUntil: number, loggedAt: number, lastErr: string?, runs: number }
local guards: { [string]: Guard } = {}
local function guarded(name: string, fn: (any, number, boolean) -> (), c: any, dt: number, far: boolean)
	local g = guards[name]
	if not g then
		g = { fails = 0, offUntil = 0, loggedAt = -1e9, lastErr = nil, runs = 0 }
		guards[name] = g
	end
	if c.now < g.offUntil then
		return
	end
	local ok, err = pcall(fn, c, dt, far)
	g.runs += 1
	if ok then
		g.fails = 0
		return
	end
	g.fails += 1
	g.lastErr = tostring(err)
	if c.now - g.loggedAt > 30 then
		g.loggedAt = c.now
		warn(("[MTL Ambient] %s step failed (%d in a row): %s"):format(name, g.fails, tostring(err)))
	end
	if g.fails >= 5 then
		g.fails = 0
		g.offUntil = c.now + 10
		warn(("[MTL Ambient] %s paused for 10 s"):format(name))
	end
end

local function threat(pos: Vector3)
	if not ctx then
		return
	end
	ctx.lastThreat = { pos = pos, t = ctx.now }
	People.threat(ctx, pos)
	Birds.threat(ctx, pos)
end

local farEvery = 1 / Ambient.FarHz
local farAcc = 0
local aimAt = 0
local statsAt = 0
local outerLoggedAt = -1e9

local frames = 0
local function step(dt: number)
	frames += 1
	local c = ctx
	c.now = os.clock()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camCF = cam.CFrame
	-- a scripted camera can hand us NaN for a frame: keep the last good values
	if camCF.Position.X == camCF.Position.X then
		c.camPos = camCF.Position
		local look = camCF.LookVector
		if Vector3.new(look.X, 0, look.Z).Magnitude > 1e-3 then
			c.camLook = Vector3.new(look.X, 0, look.Z)
		end
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	c.playerPos = if root then root.Position - Vector3.new(0, 2.5, 0) else nil
	farAcc += dt
	local far = farAcc >= farEvery
	if far then
		farAcc = 0
		-- every read from another system is pcall'd: one bad value must never stall the whole street
		local ok, h = pcall(Lighting.clock)
		if ok and type(h) == "number" and h == h then
			c.hour = h
		end
		c.night = c.hour >= 19 or c.hour < 6.2
		pcall(function()
			c.day = math.floor(workspace:GetServerTimeNow() / DayNightRules.cycleSeconds())
		end)
		local okC, playing = pcall(Cutscene.isPlaying)
		c.calm = not (okC and playing == true)
		local mc = package.MovementController
		local okS, sprint = pcall(function()
			return mc ~= nil and mc.isSprinting()
		end)
		c.sprinting = okS and sprint == true
		-- someone (you) aiming a gun out in the street scares people too
		local gc = package.GunController
		local okA, aiming = pcall(function()
			return gc ~= nil and gc.isAiming()
		end)
		if okA and aiming and c.playerPos and c.now - aimAt > 1 then
			aimAt = c.now
			threat(c.playerPos)
		end
	end
	-- while a cutscene owns the camera the street holds still (no spawning, no moving, nothing fights the scene);
	-- windows and sound carry on
	local scene = not c.calm or player:GetAttribute("MTL_Cutscene") ~= nil
	if not scene then
		guarded("People", People.step, c, dt, far)
		guarded("Traffic", Traffic.step, c, dt, far)
		guarded("Birds", Birds.step, c, dt, far)
	end
	guarded("Windows", Windows.step, c, dt, far)
	guarded("Sound", Sound.step, c, dt, far)
	if far and RunService:IsStudio() and c.now - statsAt > 2 then
		statsAt = c.now
		local n, pool = People.stats()
		player:SetAttribute("MTL_AmbientStats", ("people %d/%d cars %d birdParts %d sounds %d windows %d"):format(
			n, pool, Traffic.stats(), Birds.stats(), (Sound.stats()), Windows.stats()))
	end
end

function AmbientLife.init()
	if not Ambient.Enabled then
		return
	end
	local map = loadMap()
	if not map then
		log("no Config/AmbientMap yet: run tools/SurveyHoodLife.lua + tools/build_ambient_map.py")
		return
	end
	ctx = build(map)
	-- optional controllers (looked up lazily, never required here so a missing one can't stop us)
	local controllers = script.Parent
	package = {
		MovementController = (function()
			local m = controllers:FindFirstChild("MovementController")
			local ok, r = pcall(require, m)
			return if ok then r else nil
		end)(),
		GunController = (function()
			local m = controllers:FindFirstChild("GunController")
			local ok, r = pcall(require, m)
			return if ok then r else nil
		end)(),
	}
	ctx.sound = Sound
	Sound.init(ctx)
	People.init(ctx)
	Traffic.init(ctx)
	Birds.init(ctx)
	Windows.init(ctx)
	-- gunshots anywhere nearby (the server's shot effects reach every client)
	Net.get("GunFx").OnClientEvent:Connect(function(p: any)
		if type(p) == "table" and p.type == "shot" and typeof(p.origin) == "Vector3" then
			threat(p.origin)
		end
	end)
	-- stats on their own timer (not inside the step, so a stalled step still reports). Set workspace attribute
	-- MTL_AmbientDebug = true: a line 20 s after start, then every 60 s
	task.spawn(function()
		local wait = 20
		local lastFrames, lastAt = frames, os.clock()
		while true do
			task.wait(wait)
			wait = 60
			if workspace:GetAttribute("MTL_AmbientDebug") then
				local okP, n, pool = pcall(People.stats)
				local partCount = 0
				for _, d in ctx.folder:GetDescendants() do
					if d:IsA("BasePart") then
						partCount += 1
					end
				end
				local fps = (frames - lastFrames) / math.max(os.clock() - lastAt, 1e-3)
				local states = {}
				for name, g in guards do
					table.insert(states, ("%s %s%s"):format(name, if os.clock() < g.offUntil then "PAUSED" else "ok",
						if g.lastErr then " (last error: " .. string.sub(g.lastErr, 1, 80) .. ")" else ""))
				end
				table.sort(states)
				local playing, bedName, registered = Sound.stats()
				print(("[MTL Ambient] stats: people %s/%s, cars %d, bird parts %d, sounds playing %d of %d, bed %s, lit windows %d, our parts %d, steps/s %.0f, cutscene %s | %s"):format(
					tostring(if okP then n else "?"), tostring(if okP then pool else "?"), Traffic.stats(), Birds.stats(), playing, registered,
					bedName, Windows.stats(), partCount, fps, tostring(not ctx.calm), table.concat(states, ", ")))
			end
			lastFrames, lastAt = frames, os.clock()
		end
	end)
	if workspace:GetAttribute("MTL_AmbientDebug") then
		print("[MTL Ambient] debug on: first stats line in 20 s, then every 60 s")
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		-- helpers are guarded one by one inside step(); this outer guard only catches the frame setup
		local ok, err = pcall(step, dt)
		if not ok and os.clock() - outerLoggedAt > 30 then
			outerLoggedAt = os.clock()
			warn("[MTL Ambient] frame setup failed:", err)
		end
	end)
	log(("on: %d spots, %d walks, %d lanes, %d windows"):format(#ctx.spots, #ctx.walks, #ctx.lanes, #(map.Windows or {})))
end

-- what's running right now (Studio checks)
function AmbientLife.stats(): string
	return (player:GetAttribute("MTL_AmbientStats") :: string?) or "off"
end

return AmbientLife
