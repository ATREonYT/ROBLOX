--[[
	Aura stars in the lobby (Config/AuraStars): keeps Count stars floating near the lobby spawn, each with a
	ProximityPrompt (E, "Collect Aura"). The server decides everything: who's close enough, that the star still
	exists (first press wins), and the pay (DataService). A collected star's spot refills after a short wait.
	The look (glow, rings, sparkles, bobbing) is drawn on every client (Gameplay/AuraStars, tag "HuzzAuraStar").
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

-- The middle of the lobby: its spawn if there is one, else the lobby part.
local function centre(): Vector3?
	local spawn = Workspace:FindFirstChild("HuzzLobbySpawn", true)
	if spawn and spawn:IsA("BasePart") then return spawn.Position end
	local lobby = MapService.lobby
	return if lobby then lobby.Position else nil
end

local function spot(): Vector3?
	local c = centre()
	if not c then return nil end
	for _ = 1, 8 do
		local a, r = rng:NextNumber() * math.pi * 2, Config.Radius * math.sqrt(rng:NextNumber())
		local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local floor = MapService.ground(p, c.Y + 30)
		if floor and math.abs(floor - c.Y) < 25 then
			return Vector3.new(p.X, floor + Config.Height, p.Z)
		end
	end
	return nil
end

local spawnOne
local function collect(star: BasePart, player: Player)
	if not star.Parent then return end -- (someone else got it first)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - star.Position).Magnitude > Config.Range + 4 then return end
	local value = star:GetAttribute("Value") or 1
	local at = star.Position
	local kind = star:GetAttribute("Kind")
	star:Destroy()
	DataService.update(player, function(d) d.Aura = (d.Aura or 0) + value end)
	Net.get("Round"):FireClient(player, "AuraCollected", { value = value, kind = kind, at = at })
	task.delay(rng:NextNumber(Config.Respawn[1], Config.Respawn[2]), spawnOne)
end

function spawnOne()
	local at = spot()
	if not at then
		task.delay(5, spawnOne) -- (no lobby floor yet: try again soon)
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
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Collect"
	prompt.ActionText = "Collect Aura"
	prompt.ObjectText = `+{kind.Value} Aura`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Range
	prompt.RequiresLineOfSight = false
	prompt.Parent = star
	prompt.Triggered:Connect(function(player) collect(star, player) end)
	CollectionService:AddTag(star, "HuzzAuraStar")
	star.Parent = folder
end

function AuraPickupService.start()
	folder = Instance.new("Folder")
	folder.Name = "HuzzAuraStars"
	folder.Parent = Workspace
	task.spawn(function()
		-- wait for the lobby (MapService sets it up when the round script starts)
		local waited = 0
		while not centre() and waited < 60 do
			task.wait(1)
			waited += 1
		end
		for _ = 1, Config.Count do
			spawnOne()
			task.wait(0.2)
		end
	end)
end

return AuraPickupService
