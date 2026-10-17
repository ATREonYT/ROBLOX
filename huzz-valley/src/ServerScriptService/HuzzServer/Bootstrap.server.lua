-- Starts every server service in order.
local SoundService = game:GetService("SoundService")
local HuzzServer = script.Parent

-- Sound groups the Audio settings control (each player's client sets its own volumes).
local master = SoundService:FindFirstChild("Master") or Instance.new("SoundGroup")
master.Name = "Master"
master.Parent = SoundService
for _, name in { "Music", "Effects" } do
	local g = master:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = master
end

-- Studio only: the owner's raw animations go where clients can play them (Shared/AnimationLibrary). In the live
-- game they stay in ServerStorage (published IDs are used there), so nobody downloads 2.7 MB for nothing.
if game:GetService("RunService"):IsStudio() then
	local raw = game:GetService("ServerStorage"):FindFirstChild("HuzzAnimations")
	local RS = game:GetService("ReplicatedStorage")
	if raw and not RS:FindFirstChild("HuzzAnimations") then
		raw:Clone().Parent = RS
	end
end

-- Everywhere (Studio AND the live game): the movement pack's Idle, Walk and Run (~180 KB) go to
-- ReplicatedStorage.HuzzGirlMoves, so every screen can play them by hand on the anime girls (Shared/GirlMoves:
-- the prize's idle, a girl following a catcher, your companion). No upload needed; the dances stay server-side.
do
	local raw = game:GetService("ServerStorage"):FindFirstChild("HuzzAnimations")
	local RS = game:GetService("ReplicatedStorage")
	if raw and not RS:FindFirstChild("HuzzGirlMoves") then
		local folder = Instance.new("Folder")
		folder.Name = "HuzzGirlMoves"
		for _, name in { "Idle", "Walk", "Run" } do
			local seq = raw:FindFirstChild(name)
			if seq then
				seq:Clone().Parent = folder
			end
		end
		folder.Parent = RS
	end
end

-- "HuzzCompanion": the anime girls who walk with you or the catcher (Gameplay/Auras puts their parts in it on each
-- screen; owner: "make the little character not collide with the user"). A Humanoid turns collisions back on for
-- some body parts, so CanCollide alone isn't enough: this group collides with nothing at all. Other services
-- register their groups later (MapService, KnockdownService), so it's set again for a while.
do
	local PhysicsService = game:GetService("PhysicsService")
	local COMPANION = "HuzzCompanion"
	pcall(function() PhysicsService:RegisterCollisionGroup(COMPANION) end)
	local function noCollisions()
		pcall(function()
			for _, g in PhysicsService:GetRegisteredCollisionGroups() do
				PhysicsService:CollisionGroupSetCollidable(COMPANION, g.name, false)
			end
		end)
	end
	noCollisions()
	task.spawn(function()
		for _ = 1, 30 do
			task.wait(10)
			noCollisions()
		end
	end)
end

local DataService = require(HuzzServer.DataService)
local ShopService = require(HuzzServer.ShopService)
local SettingsService = require(HuzzServer.SettingsService)
local CosmeticsService = require(HuzzServer.CosmeticsService)
local ActionService = require(HuzzServer.ActionService)
local CompanionService = require(HuzzServer.CompanionService)

DataService.start()
SettingsService.start()
ShopService.start()
CosmeticsService.start()
ActionService.start()
CompanionService.start()
require(HuzzServer.AuraPickupService).start() -- Aura stars to collect in the lobby (Config/AuraStars)
require(HuzzServer.SpinService).start() -- Spin the Wheel: a free spin every 15 min, bought spins (Config/SpinWheel)
require(HuzzServer.LookService).apply() -- the lighting look: colour grade, bloom, sun rays, haze (Config/Look)
-- No jumping anywhere (owner): Space is the huss in the lobby too (RoundService keeps every Humanoid at 0).
pcall(function()
	game:GetService("StarterPlayer").CharacterJumpHeight = 0
	game:GetService("StarterPlayer").CharacterJumpPower = 0
end)
local RewardService = require(HuzzServer.RewardService)
RewardService.start() -- titles and looks from the girls you get (Config/CoinShop rewards)
DataService.onChanged = function(player)
	if #RewardService.sync(player) > 0 then return end -- (it changed the save: this runs again with the rewards)
	CosmeticsService.refresh(player)
	require(HuzzServer.NameTagService).restyle(player) -- (a new title or name colour shows in the lobby straight away)
	CompanionService.refresh(player) -- (the equipped anime girl follows you: Gameplay/Auras)
	-- a newly worn knife skin shows on your back straight away (a catcher's hand knife updates at the next sync)
	local c = player.Character
	local KnifeService = require(HuzzServer.KnifeService)
	if c and not KnifeService.has(c) then
		local profile = DataService.get(player)
		local key = profile and profile.Data.Wear and profile.Data.Wear.Knife
		KnifeService.giveBack(c, key and require(game:GetService("ReplicatedStorage").Shared.Config.CoinShop).get(key) or nil)
	end
end
