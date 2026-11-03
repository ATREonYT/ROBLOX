--!strict
-- Ms. Bea's lucky tin (Quality pass, Benchmark Gap List 2.10). See Config/Live.Cache.
-- One tin a day for the whole game: the spot is picked from the UTC day number, so every server agrees and it
-- moves at midnight UTC. Bea texts the clue when you join (once a day) and when the day rolls over while you play.
-- Opening it (hold E) sets data.Daily.BoostUntil = now + 15 min: EconomyService.jobMultiplier doubles shift pay
-- until then. The player attribute MTL_JobBoostUntil (unix time) drives the HUD chip on the client.
-- Once per player per day (data.Daily.CacheDay); the tin stays in the world for everyone else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Live = require(ReplicatedStorage.MTL.Config.Live)
local Net = require(ReplicatedStorage.MTL.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PhoneService = require(script.Parent.PhoneService)
local Notify = require(script.Parent.Notify)

local C = Live.Cache
local DailyCacheService = {}

local tin: Model? = nil
local tinDay = -1
local lastOpen: { [Player]: number } = {}

local function log(...)
	print("[MTL Cache]", ...)
end

local function today(): number
	return os.time() // 86400
end

function DailyCacheService.spotFor(day: number): any
	local r = Random.new(day * 7919 + 17)
	return C.spots[r:NextInteger(1, #C.spots)]
end

local function daily(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.Daily = data.Daily or { CacheDay = -1, BoostUntil = 0, CluedDay = -1 }
	return data.Daily
end

local function syncAttr(player: Player)
	local d = daily(player)
	if d and d.BoostUntil > os.time() then
		player:SetAttribute("MTL_JobBoostUntil", d.BoostUntil)
	else
		player:SetAttribute("MTL_JobBoostUntil", nil)
	end
end

-- shift pay multiplier (EconomyService asks for "Job:*" payouts)
function DailyCacheService.jobMultiplier(player: Player): number
	local d = daily(player)
	if d and d.BoostUntil > os.time() then
		return C.boostMultiplier
	end
	return 1
end

local function folder(): Folder
	local f = workspace:FindFirstChild("MTL_Live")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MTL_Live"
		f.Parent = workspace
	end
	return f :: Folder
end

local function open(player: Player)
	local t = os.clock()
	if t - (lastOpen[player] or 0) < 1 then
		return
	end
	lastOpen[player] = t
	local d = daily(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not d or not tin or not hrp or (hrp.Position - tin:GetPivot().Position).Magnitude > 12 then
		return
	end
	local day = today()
	if d.CacheDay == day then
		Notify.refuse(player, "You already found Bea's tin today. New spot at midnight UTC")
		PhoneService.text(player, C.contact, C.texts.already, { silent = true })
		return
	end
	d.CacheDay = day
	d.BoostUntil = math.max(d.BoostUntil, os.time()) + C.boostSeconds
	DataService.push(player)
	syncAttr(player)
	EconomyService.addXP(player, C.xp, "DailyCache", tin:GetPivot().Position)
	Notify.banner(player, "LUCKY TIN", "2x job pay for 15 minutes", Color3.fromRGB(120, 170, 255))
	PhoneService.text(player, C.contact, C.texts.found)
	Net.get("LiveState"):FireClient(player, { type = "cache", phase = "found", boostUntil = d.BoostUntil })
	log(player.Name, "found the tin, boost until", d.BoostUntil)
end

local function placeTin()
	local day = today()
	if tin and tinDay == day then
		return
	end
	if tin then
		tin:Destroy()
		tin = nil
	end
	local lib = ReplicatedStorage:FindFirstChild("MTL_Live")
	local template = lib and lib:FindFirstChild("LuckyTin")
	if not (template and template:IsA("Model")) then
		warn("[MTL Cache] ReplicatedStorage.MTL_Live.LuckyTin is missing")
		return
	end
	local spot = DailyCacheService.spotFor(day)
	local m = template:Clone()
	m.Name = "LuckyTin"
	local r = Random.new(day)
	m:PivotTo(CFrame.new(spot.at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0))
	local root = m.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenTin"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Bea's lucky tin"
	prompt.HoldDuration = C.holdSeconds
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(open)
	m.Parent = folder()
	tin, tinDay = m, day
	log("tin placed at", spot.id, "for day", day)
end

-- new players are busy with the story's first day: Bea only texts once you're settled (free play or level 3+)
local function settled(player: Player): boolean
	local data = DataService.get(player)
	if data and type(data.Level) == "number" and data.Level >= 3 then
		return true
	end
	local m = script.Parent:FindFirstChild("StoryService")
	local ok, story = pcall(require, m :: any)
	if ok and story and story.stage then
		local ok2, stage = pcall(story.stage, player)
		return ok2 and stage == "FreePlay"
	end
	return false
end

local function clue(player: Player)
	local d = daily(player)
	local day = today()
	if not d or d.CluedDay == day or d.CacheDay == day or not settled(player) then
		return
	end
	d.CluedDay = day
	DataService.push(player)
	PhoneService.text(player, C.contact, DailyCacheService.spotFor(day).clue)
end

function DailyCacheService.init()
	EconomyService.jobBoost = DailyCacheService.jobMultiplier
	placeTin()
	DataService.Ready:Connect(function(player)
		syncAttr(player)
		task.delay(20, function() -- after the join noise settles
			if player.Parent then
				clue(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
	-- the day rolls over: move the tin, text everyone the new clue; boosts expire on their own
	task.spawn(function()
		while true do
			task.wait(30)
			if today() ~= tinDay then
				placeTin()
				for _, p in Players:GetPlayers() do
					clue(p)
				end
			end
			for _, p in Players:GetPlayers() do
				clue(p) -- no-op once texted today; catches players who just reached free play
				local until_ = p:GetAttribute("MTL_JobBoostUntil")
				if type(until_) == "number" and until_ <= os.time() then
					p:SetAttribute("MTL_JobBoostUntil", nil)
				end
			end
		end
	end)
end

return DailyCacheService
