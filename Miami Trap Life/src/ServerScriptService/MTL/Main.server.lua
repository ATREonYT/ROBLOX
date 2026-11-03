--!strict
-- Boots every server service in order (Master Plan §3.2). New services: add a line here, in dependency order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.MTL.Net)
Net.init()

local Services = script.Parent.Services
local order = {
	"DataService",
	"TimeService", -- the world clock (clients draw the lighting from it)
	"MonetizationService",
	"EconomyService",
	"WaypointService",
	"StoryService",
	"PhoneService",
	"PhoneStory", -- story beats that arrive by phone (needs Story + Phone)
	"JobService", -- Piece 2: jobs, shifts, tasks (needs Economy, Story, Phone, Waypoints)
	"GunService", -- Piece 5: guns, ammo, shot validation (needs Economy, Story, Phone, Jobs)
	"CutsceneService", -- Piece 3: plays cutscenes on the client, waits for CutsceneDone; builds crew rigs
	"StoryWelcome", -- welcome scenes for new players: Welcome (Arrive) + FirstDay (FirstShift) (needs Story, Cutscene)
	"MissionService", -- Piece 3: step-by-step missions (needs Waypoints, Cutscene; uses GunService if present)
	"StoryCrew", -- Piece 3: stages GangMeet -> MissionDone (needs Story, Phone, Mission, Cutscene, Monetization)
	"PropertyService", -- Piece 4: the flat, rooms, power bill, bed, stages FindAPlace -> CommuteToWork (needs Story, Phone, Cutscene)
	"GoalService", -- Piece 4: FreePlay goals + the objective line in free play
	"StoryMissions", -- Act 2+: chapters, story missions, choices (Config/Chapters) after FreePlay (needs Story, Phone, Cutscene, Waypoints)
	"EarnService", -- the phone's Money app: GPS to any way of earning (needs Phone, Waypoints)
	"VehicleService", -- the phone's Garage: owned cars, spawn one next to you (needs Data, Phone)
	"SocialService", -- CLOUT, the social app: posts, followers, brand deals, courses, daily market (needs Economy, Phone, Story, Time; uses Property)
	"AmbientRigService", -- living neighbourhood: builds the street people (Config/Outfits) for clients to clone
	"StanceService", -- quality: crouch (character attribute MTL_Stance, posed on every client by Crouch)
	"SpawnProtection", -- 30 s no-damage after every spawn, ends when you draw a gun (needs GunService)
	"StarterShop", -- the hat/chain stand in Liberty Food Mart: something to buy in minute one (needs Data, Economy)
	"PoliceService", -- crime loop: heat stars + NPC police (cruisers on the road graph, officers, cuffs) (needs Guns)
	"CrimeService", -- crime loop: dirty cash, laundromat, Marcus, the six crimes in CrimeJobs (needs Police, Guns, Phone, Jobs, Waypoints)
	"DailyCacheService", -- quality: Ms. Bea's lucky tin, 2x job pay for 15 min once a day (needs Economy, Phone, Data)
	"AirdropService", -- quality: Liberty Relief supply drops every 12 min (needs Economy, Waypoints; Crime for tools)
	"PawnService", -- quality: Liberty Pawn & Thrift buys lick goods for clean cash (needs Economy; Crime for goods)
}

local loaded = {}
for _, name in order do
	local module = Services:FindFirstChild(name)
	if not module then
		warn("[MTL Main] missing service", name)
		continue
	end
	local ok, svc = pcall(require, module)
	if ok and type(svc) == "table" and svc.init then
		local initOk, err = pcall(svc.init)
		if initOk then
			loaded[name] = svc
		else
			warn("[MTL Main] init failed:", name, err)
		end
	else
		warn("[MTL Main] require failed:", name, svc)
	end
end

-- Start loading players only once every service is listening.
if loaded.DataService then
	loaded.DataService.start()
end

-- Studio test helper: from the server Command Bar / MCP:
--   _G.MTL.Story.debugSet(game.Players:GetPlayers()[1], "FirstShift")
--   _G.MTL.Economy.addXP(game.Players:GetPlayers()[1], 500, "Debug")
if RunService:IsStudio() then
	_G.MTL = {
		Data = loaded.DataService,
		Time = loaded.TimeService,
		Economy = loaded.EconomyService,
		Story = loaded.StoryService,
		Waypoints = loaded.WaypointService,
		Monetization = loaded.MonetizationService,
		Phone = loaded.PhoneService,
		Jobs = loaded.JobService,
		Guns = loaded.GunService,
		Cutscenes = loaded.CutsceneService,
		Missions = loaded.MissionService,
		StoryCrew = loaded.StoryCrew,
		Property = loaded.PropertyService,
		Goals = loaded.GoalService,
		StoryMissions = loaded.StoryMissions,
		Cars = loaded.VehicleService,
		Social = loaded.SocialService,
		Police = loaded.PoliceService,
		Crime = loaded.CrimeService,
		CrimeJobs = loaded.CrimeService and loaded.CrimeService.jobs,
	}
end

-- Studio-only test hook for tools that run in a different Lua VM (Studio MCP / command bar can't see _G.MTL):
--   game.ServerStorage.MTL_Debug:Invoke("Economy", "addXP", player, 500, "Debug")
--   game.ServerStorage.MTL_Debug:Invoke("Data", "snapshot", player)
if RunService:IsStudio() then
	local old = game:GetService("ServerStorage"):FindFirstChild("MTL_Debug")
	if old then
		old:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "MTL_Debug"
	bf.OnInvoke = function(service: string, fn: string, ...)
		local svc = _G.MTL and _G.MTL[service]
		assert(svc and type(svc[fn]) == "function", "[MTL Debug] no " .. tostring(service) .. "." .. tostring(fn))
		return svc[fn](...)
	end
	bf.Parent = game:GetService("ServerStorage")
end

print("[MTL Main] server ready:", #order, "services")
