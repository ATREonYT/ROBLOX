-- Starts every server service in order.
local SoundService = game:GetService("SoundService")
local HuzzServer = script.Parent

-- Sound groups the Audio settings control (each player's client sets its own volumes).
local master = SoundService:FindFirstChild("Master") or Instance.new("SoundGroup")
master.Name = "Master"
master.Parent = SoundService
for _, name in { "Music", "Effects", "Interface" } do
	local g = master:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = master
end
-- The owner's songs (SoundService > Music > Background_Music, Important_Song_Actions) are played by each client
-- (Gameplay/Music) through the Music group; stop any set to play by themselves, so nobody hears two songs at once.
do
	local songs = SoundService:FindFirstChild("Music")
	if songs then
		for _, s in songs:GetDescendants() do
			if s:IsA("Sound") then
				s.Playing = false
			end
		end
	end
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

-- The owner's 3D knife crates (Workspace > scrates > Standard_Crates) go to ReplicatedStorage.HuzzCrates for Shop >
-- CRATES and the crate opening (Shared/CrateModels). Before MapService puts his spare lobby copies away; the place
-- build has usually done it already.
do
	local ok, err = pcall(function()
		require(game:GetService("ReplicatedStorage").Shared.CrateModels).publish(workspace, game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"))
	end)
	if not ok then warn("[Huzz] crate models:", err) end
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
require(HuzzServer.FriendService).start() -- friend rewards: +10% coins with a friend here, the friend knife (Config/Friends)
require(HuzzServer.SpinService).start() -- Spin the Wheel: a free spin every 15 min, bought spins (Config/SpinWheel)
require(HuzzServer.LookService).apply() -- the lighting look: colour grade, bloom, sun rays, haze (Config/Look)
require(HuzzServer.HeadLookService).start() -- everyone's head follows their mouse on every screen (Config/Run.Loco.Look)
require(HuzzServer.LeaderboardService).start() -- the lobby leaderboards (Config/Leaderboards; each screen turns them to face you)
do -- the lobby avatar stands: finds his grey blocks, readies the pass knives (a failure here never stops the game)
	local ok, err = pcall(function() require(HuzzServer.AvatarStandService).start() end)
	if not ok then warn("[Huzz] avatar stands: " .. tostring(err)) end
end
do -- his .glb knife meshes, sent to each screen only for the knives it shows (HuzzServer/KnifeGlbService)
	local ok, err = pcall(function() require(HuzzServer.KnifeGlbService).start() end)
	if not ok then warn("[Huzz] knife meshes: " .. tostring(err)) end
end
do -- the owner's admin panel (give any knife, spawn any girl; owner only, HuzzServer/AdminService)
	local ok, err = pcall(function() require(HuzzServer.AdminService).start() end)
	if not ok then warn("[Huzz] admin panel: " .. tostring(err)) end
end
do -- his Combine machine: its prompt and sign; the merge itself is ActionService "Combine" (HuzzServer/CombineService)
	local ok, err = pcall(function() require(HuzzServer.CombineService).start() end)
	if not ok then warn("[Huzz] combine machine: " .. tostring(err)) end
end
do -- his five lobby props on the round pads (Config/LobbyProps; each screen floats them and opens their menus)
	local ok, err = pcall(function() require(HuzzServer.LobbyPropService).start() end)
	if not ok then warn("[Huzz] lobby props: " .. tostring(err)) end
end
-- No jumping anywhere (owner): Space is the huss in the lobby too (RoundService keeps every Humanoid at 0).
pcall(function()
	game:GetService("StarterPlayer").CharacterJumpHeight = 0
	game:GetService("StarterPlayer").CharacterJumpPower = 0
end)
local RewardService = require(HuzzServer.RewardService)
RewardService.start() -- titles and looks from the girls you get (Config/CoinShop rewards)
DataService.onChanged = function(player)
	if #RewardService.sync(player) > 0 then return end -- (it changed the save: this runs again with the rewards)
	-- each on its own: one failing (a look, a title) never stops the rest, so your girl always follows the save
	-- (owner, Oct 19: "make the girls appear for everyone on everyones screen")
	for _, step in {
		function() CosmeticsService.refresh(player) end,
		function() require(HuzzServer.NameTagService).restyle(player) end, -- (a new title or name colour shows at once)
		function() CompanionService.refresh(player) end, -- (the equipped anime girl follows you: Gameplay/Auras)
	} do
		local ok, err = pcall(step)
		if not ok then warn("[Huzz] after a save change: " .. tostring(err)) end
	end
	-- a newly worn knife skin shows straight away: on your body, or in your hand while you're a catcher
	local c = player.Character
	if c then
		local KnifeService = require(HuzzServer.KnifeService)
		local Shared = game:GetService("ReplicatedStorage").Shared
		local profile = DataService.get(player)
		local skin = require(Shared.KnifeLook).pick(profile and profile.Data, require(Shared.Config.CoinShop))
		if KnifeService.has(c) then KnifeService.give(c, skin) else KnifeService.giveBack(c, skin) end
	end
end
