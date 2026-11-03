--!strict
-- Story Piece 3 glue: stages 4-7 (Master Plan §1). TheCall itself lives in PhoneStory (the Phone piece).
--   GangMeet     accepting the call made you Criminal; a meet spot is picked (saved), the unknown number texts it,
--                the Story waypoint + breadcrumbs lead there; the crew waits by a car with hazards (client props).
--   GangIntro    you're placed facing the crew, the GangIntro cutscene plays (skippable), the crew joins Contacts.
--   FirstMission MissionService runs "FirstMission" (rob Liberty Food Mart). On completion: pay once (saved
--                before anything else, so a disconnect can't lose or double it), RobberyOutro cutscene, drop-off.
--   MissionDone  payout screen, then the 2x Money offer (dismissable, no timers). Closing it -> FindAPlace.
-- Piece 4 hooks: StoryService.onEnter("FindAPlace"...) etc.; the drop-off is next to Locations.EndsFlat;
-- Story.Data.FirstMissionResult holds what the job paid; CutsceneService.play works for the power-out scene.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Missions = require(ReplicatedStorage.MTL.Config.Missions)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local Monetization = require(ReplicatedStorage.MTL.Config.Monetization)
local MissionRules = require(ReplicatedStorage.MTL.Rules.MissionRules)
local Net = require(ReplicatedStorage.MTL.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local StoryService = require(script.Parent.StoryService)
local PhoneService = require(script.Parent.PhoneService)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)
local CutsceneService = require(script.Parent.CutsceneService)
local MissionService = require(script.Parent.MissionService)

local StoryCrew = {}

local MISSION = "FirstMission"

local function log(...)
	print("[MTL StoryCrew]", ...)
end

local function sdata(player: Player): any?
	return StoryService.data(player)
end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function floorAt(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else pos.Y - 1
end

---------------------------------------------------------------- the meet spot

type Spot = { id: string, label: string, cf: CFrame }

-- A map part tagged MTL_MeetSpot with attribute Id = "<spot id>" wins over the placeholder position (its
-- LookVector = from the crew toward where the player stands). Otherwise the crew faces the Food Mart, the way the
-- player comes from.
local function resolveSpot(cfg: any): Spot
	for _, part in CollectionService:GetTagged("MTL_MeetSpot") do
		if part:IsA("BasePart") and part:GetAttribute("Id") == cfg.Id then
			local p = part.Position
			return { id = cfg.Id, label = cfg.Label, cf = CFrame.new(p.X, floorAt(p), p.Z) * part.CFrame.Rotation }
		end
	end
	local p = cfg.Position
	local y = floorAt(p)
	local toward = Locations.FoodMart.Door
	local from = Vector3.new(p.X, y, p.Z)
	local look = Vector3.new(toward.X, y, toward.Z)
	local cf = if (look - from).Magnitude > 1 then CFrame.lookAt(from, look) else CFrame.new(from)
	if type(cfg.Yaw) == "number" then
		cf = CFrame.new(from) * CFrame.Angles(0, math.rad(cfg.Yaw), 0)
	end
	return { id = cfg.Id, label = cfg.Label, cf = cf }
end

local function meetSpot(player: Player): Spot?
	local sd = sdata(player)
	if not sd then
		return nil
	end
	local cfg = MissionRules.findSpot(Locations.MeetSpots, sd.MeetSpot)
	if not cfg then
		cfg = MissionRules.pickSpot(Locations.MeetSpots, Random.new():NextNumber())
		if not cfg then
			return nil
		end
		sd.MeetSpot = cfg.Id
		DataService.push(player)
		log(player.Name, "meet spot:", cfg.Id)
	end
	return resolveSpot(cfg)
end

local function sendMeet(player: Player)
	local spot = meetSpot(player)
	if spot then
		MissionService.send(player, { type = "meet", cframe = spot.cf, label = spot.label })
	end
end

local function standAt(player: Player, spot: Spot)
	local r = root(player)
	if not r then
		return
	end
	local stand = spot.cf:PointToWorldSpace(Missions.Meet.Layout.Player.at)
	local pos = stand + Vector3.new(0, 3, 0)
	local crew = Vector3.new(spot.cf.Position.X, pos.Y, spot.cf.Position.Z)
	r.CFrame = CFrame.lookAt(pos, crew)
	r.AssemblyLinearVelocity = Vector3.zero
end

---------------------------------------------------------------- mission end

local function dropOff(): CFrame
	local door = Locations.EndsFlat.Door
	local p = door + Missions.DropOffOffset
	local y = floorAt(p)
	return CFrame.lookAt(Vector3.new(p.X, y + 3, p.Z), Vector3.new(door.X, y + 3, door.Z))
end

-- Pays once. The result is saved in Story.Data before the outro, so rejoining never re-pays or loses it.
local function payOnce(player: Player, result: any): any?
	local sd = sdata(player)
	local data = DataService.get(player)
	if not sd or not data then
		return nil
	end
	if sd.FirstMissionResult then
		return sd.FirstMissionResult
	end
	local def = Missions.FirstMission
	local mult = EconomyService.cashMultiplier(player)
	local base = (result.take or def.Pay) + (result.bonus or 0)
	local paid = EconomyService.addCash(player, base, "Mission:FirstMission", true)
	local xp = EconomyService.addXP(player, def.XP, "Mission:FirstMission")
	data.Stats.Robberies += 1
	sd.FirstMissionResult = {
		take = result.take or def.Pay,
		bonus = result.bonus or 0,
		clean = result.clean == true,
		escape = result.escapeSeconds,
		seconds = result.seconds,
		paid = paid,
		xp = xp,
		mult = mult,
		at = os.time(),
	}
	DataService.push(player)
	log(player.Name, "paid", paid, "for", MISSION)
	return sd.FirstMissionResult
end

local function outroAndAdvance(player: Player)
	local car = MissionService.point(MISSION, "Car")
	CutsceneService.play(player, "RobberyOutro", { anchor = car })
	if not player.Parent then
		return
	end
	MissionService.cleanup(player)
	local r = root(player)
	if r then
		r.CFrame = dropOff()
		r.AssemblyLinearVelocity = Vector3.zero
	end
	StoryService.advance(player, MISSION)
end

---------------------------------------------------------------- payout + offer

local function offerItems(player: Player): { any }
	local out = {}
	for _, it in Missions.Offer.Items do
		local id = if it.kind == "pass" then Monetization.Passes[it.item] else Monetization.Products[it.item]
		table.insert(out, {
			item = it.item,
			kind = it.kind,
			title = it.title,
			sub = it.sub,
			id = id or 0,
			owned = it.kind == "pass" and MonetizationService.owns(player, it.item),
		})
	end
	return out
end

local function sendPayout(player: Player)
	local sd = sdata(player)
	local def = Missions.FirstMission
	local res = sd and sd.FirstMissionResult
	if not res then
		-- reached by debugSet without playing the mission: show the numbers, pay nothing
		res = { take = def.Pay, bonus = 0, clean = false, paid = 0, xp = 0, mult = 1, debug = true }
	end
	MissionService.send(player, {
		type = "payout",
		title = def.Title,
		take = res.take,
		bonus = res.bonus,
		clean = res.clean,
		escape = res.escape,
		cleanSeconds = def.CleanGetaway.Seconds,
		paid = res.paid,
		xp = res.xp,
		mult = res.mult,
		doubled = (res.take + res.bonus) * 2,
		debug = res.debug == true,
		offer = offerItems(player),
	})
end

---------------------------------------------------------------- init

function StoryCrew.init()
	-- 4. GangMeet
	StoryService.onEnter("GangMeet", function(player, resumed)
		local data = DataService.get(player)
		if not data then
			return
		end
		if data.Path ~= "Criminal" then
			PhoneService.setPath(player, "Criminal", true) -- you said "I'm in" (Master Plan §1 branching)
		end
		local jm = script.Parent:FindFirstChild("JobService")
		if jm then
			local ok, js = pcall(require, jm)
			if ok and js.isOnShift and js.isOnShift(player) then
				js.clockOut(player, "story")
				Notify.toast(player, "You clocked out early.")
			end
		end
		local spot = meetSpot(player)
		if not spot then
			warn("[MTL StoryCrew] no meet spots configured; skipping the meet")
			StoryService.advance(player, "GangMeet")
			return
		end
		WaypointService.set(player, "Story", spot.cf.Position, { label = spot.label, radius = Missions.Meet.Radius })
		Notify.objective(player, "Go to the meet: " .. spot.label)
		sendMeet(player)
		local sd = sdata(player)
		if sd and not sd.MeetTexted then
			sd.MeetTexted = true
			task.wait(1.5)
			for i, line in Missions.Meet.Texts do
				PhoneService.text(player, "Unknown", string.format(line, spot.label))
				if i < #Missions.Meet.Texts then
					task.wait(1.4)
				end
			end
		end
	end)
	WaypointService.Arrived:Connect(function(player, id)
		if id == "Story" and StoryService.stage(player) == "GangMeet" then
			StoryService.advance(player, "GangMeet")
		end
	end)

	-- 5. GangIntro
	StoryService.onEnter("GangIntro", function(player)
		local spot = meetSpot(player)
		MissionService.send(player, { type = "meetClear" })
		if spot then
			standAt(player, spot)
			CutsceneService.play(player, "GangIntro", { anchor = spot.cf })
		end
		if not player.Parent then
			return
		end
		local data = DataService.get(player)
		if data then
			for _, id in { "Dre", "Smoke", "Nina" } do
				data.Phone.Contacts[id] = true
			end
			DataService.push(player)
		end
		StoryService.advance(player, "GangIntro")
	end)

	-- 6. FirstMission
	StoryService.onEnter(MISSION, function(player)
		local sd = sdata(player)
		if sd and sd.FirstMissionResult then
			-- the job was done and paid, the player left during the outro: just finish the beat
			outroAndAdvance(player)
			return
		end
		MissionService.start(player, MISSION)
	end)
	MissionService.Completed:Connect(function(player, missionId, result)
		if missionId ~= MISSION or StoryService.stage(player) ~= MISSION then
			return
		end
		payOnce(player, result)
		outroAndAdvance(player)
	end)

	-- 7. MissionDone: payout, then the offer; closing the offer moves on to free play (FindAPlace)
	StoryService.onEnter("MissionDone", function(player)
		Notify.objective(player, "")
		task.wait(0.3)
		sendPayout(player)
	end)
	MissionService.onAction("closeOffer", function(player)
		if StoryService.stage(player) == "MissionDone" then
			StoryService.advance(player, "MissionDone")
		end
	end)
	MissionService.onAction("buy", function(player, payload)
		local item = payload.item
		for _, it in Missions.Offer.Items do
			if it.item == item then
				MonetizationService.prompt(player, item)
				return
			end
		end
	end)
	-- a pass bought on the offer card: refresh the card (shows OWNED)
	MonetizationService.PassChanged:Connect(function(player)
		if StoryService.stage(player) == "MissionDone" then
			sendPayout(player)
		end
	end)

	-- respawned / rejoined clients re-get what they need
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		local stage = StoryService.stage(player)
		if stage == "GangMeet" then
			sendMeet(player)
		end
	end)
	log("ready")
end

-- Studio test helpers (server Command Bar): _G.MTL.StoryCrew.meet(player) teleports you to your meet spot.
function StoryCrew.meet(player: Player)
	assert(game:GetService("RunService"):IsStudio(), "Studio-only")
	local spot = meetSpot(player)
	if spot then
		standAt(player, spot)
	end
end

return StoryCrew
