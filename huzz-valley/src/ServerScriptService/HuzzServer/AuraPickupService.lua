--[[
	Aura stars (Config/AuraStars): keeps Count stars floating over the playing zone (the map's Middle) while a map
	is loaded; none between games. Run into one and it's collected: the server checks every player's distance to every
	star ten times a second (first one there wins) and pays (DataService). A collected star refills elsewhere after a
	short wait; when the map changes, the stars move to the new field. The look (glow, sparkles, bobbing) is drawn on
	every client (Gameplay/AuraStars, tag "HuzzAuraStar"); "AuraCollected" goes to every client (the collector's id in
	it) so everyone sees the star pop and only the collector gets the "+N".
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.AuraStars)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local AuraPickupService = {}

local rng = Random.new()
local folder: Folder

local function pickKind()
	local total = 0
	for _, k in Config.Kinds do total += k.Weight end
	local x = rng:NextNumber() * total
	for _, k in Config.Kinds do
		x -= k.Weight
		if x < 0 then return k end
	end
	return Config.Kinds[1]
end

-- A spot over the playing zone, or nil between games (owner: "collected in the playing zone").
local function spot(): Vector3?
	if not MapService.current then return nil end
	local p = MapService.playSpot(Config.Inset)
	return if p then p + Vector3.new(0, Config.Height, 0) else nil
end

local spawnOne
local function collect(star: BasePart, player: Player)
	if not star.Parent then return end -- (someone else got it first)
	local value = star:GetAttribute("Value") or 1
	local at = star.Position
	local kind = star:GetAttribute("Kind")
	star:Destroy()
	DataService.update(player, function(d)
		d.Aura = (d.Aura or 0) + value
	end)
	require(script.Parent.ProgressService).addStat(player, "AuraStars", 1) -- (lore quest: Star Catcher; daily quests)
	-- (to everyone: the collector sees "+N", everyone near sees the star pop: Gameplay/AuraStars)
	Net.get("Round"):FireAllClients("AuraCollected", { value = value, kind = kind, at = at, id = player.UserId })
	player:SetAttribute("HuzzGameAura", (player:GetAttribute("HuzzGameAura") or 0) + value) -- (the results screen)
	task.delay(rng:NextNumber(Config.Respawn[1], Config.Respawn[2]), spawnOne)
end

function spawnOne()
	local at = spot()
	if not at then
		task.delay(3, spawnOne) -- (no map loaded: try again soon)
		return
	end
	local kind = pickKind()
	local star = Instance.new("Part")
	star.Name = "AuraStar"
	star.Anchored, star.CanCollide, star.CanQuery, star.CanTouch, star.CastShadow = true, false, false, false, false
	star.Transparency = 1
	star.Size = Vector3.new(2, 3, 0.2)
	star.CFrame = CFrame.new(at)
	star:SetAttribute("Kind", kind.Name)
	star:SetAttribute("Value", kind.Value)
	CollectionService:AddTag(star, "HuzzAuraStar")
	star:SetAttribute("Map", if MapService.current then MapService.current.name else "")
	star.Parent = folder
end

-- Ten times a second: anyone close enough to a star collects it; stars left from an old map move to the new one.
local function watch()
	local Players = game:GetService("Players")
	while true do
		task.wait(0.1)
		local mapName = if MapService.current then MapService.current.name else ""
		for _, star in folder:GetChildren() do
			if star:IsA("BasePart") then
				if star:GetAttribute("Map") ~= mapName then
					star:Destroy() -- (the map changed: this one belonged to the old field)
					task.defer(spawnOne)
				else
					for _, player in Players:GetPlayers() do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						-- in a game only runners pick stars up (they spawn in the middle, where catchers wait: catchers took
						-- most of the Aura; loop audit, Oct 18)
						local catcher = player:GetAttribute("HuzzRole") == "Catcher"
						if root and root:IsA("BasePart") and not catcher and (root.Position - star.Position).Magnitude <= Config.Range then
							pcall(collect, star, player) -- (one failed pickup can't stop the others)
							break
						end
					end
				end
			end
		end
	end
end

function AuraPickupService.start()
	folder = Instance.new("Folder")
	folder.Name = "HuzzAuraStars"
	folder.Parent = Workspace
	task.spawn(function()
		for _ = 1, Config.Count do
			spawnOne()
			task.wait(0.2)
		end
		watch()
	end)
end

return AuraPickupService
