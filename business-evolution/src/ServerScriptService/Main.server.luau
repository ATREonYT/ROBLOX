--!strict
-- THE single server entry point (§13.1). Every other server file is a
-- ModuleScript required from here, so startup order is explicit and readable.
--
-- Two-phase init: Init() may not touch other services (wire yourself up),
-- Start() may (talk to everyone). That's the whole framework.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

local Net = require(Server.Net.Net)

-- Order matters only for readability — Init never crosses service boundaries,
-- and Start runs after every Init has finished.
local services: { any } = {
	require(Server.Data.DataService),
	require(Server.World.MapService),
	require(Server.Economy.ProductivityService),
	require(Server.Economy.ShopService),
	require(Server.Economy.RestructureService),
	require(Server.Economy.MonetizationService),
	require(Server.Progression.RankService),
	require(Server.Progression.FloorService),
	require(Server.Progression.AppearanceService),
	require(Server.Rivals.RivalService),
	require(Server.Economy.InternService),
	require(Server.Boards.LeaderboardService),
}

Net.Start()

for _, service in services do
	if service.Init then
		service:Init()
	end
end

for _, service in services do
	if service.Start then
		service:Start()
	end
end

print("[BusinessEvolution] server up —", #services, "services started")
