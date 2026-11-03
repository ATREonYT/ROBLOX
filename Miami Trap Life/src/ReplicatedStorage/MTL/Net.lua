--!strict
-- Every remote in the game. The server creates them once (Net.init); both sides get them by name (Net.get).
-- To add a remote: add it here AND to the table in "00 Master Plan" §3.3.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER = "MTL_Net"

local Net = {}

Net.Definitions = {
	-- S -> C
	ProfileUpdated = "RemoteEvent", -- public snapshot of the save
	Notify = "RemoteEvent", -- {kind="toast"|"line"|"banner", text, color?}
	PhoneEvent = "RemoteEvent", -- {type="text"|"call"|"unlockApp"|"open", ...}
	Waypoint = "RemoteEvent", -- {id, position, label, radius} | {id, clear=true}
	PlayCutscene = "RemoteEvent", -- {id, token, anchor = CFrame?, marks?, group = {n, host, hostName}?, startAt?}
	CutsceneSync = "RemoteEvent", -- group scenes: {token, type="votes", count, need} | {token, type="end"} | {token, type="choice", choice}
	JobState = "RemoteEvent",
	MissionState = "RemoteEvent", -- {type="state"|"clear"|"bark"|"progress"|"meet"|"meetClear"|"payout", ...} (MissionService)
	GunFx = "RemoteEvent", -- {type="shot", shooter, gun, origin, ends} | {type="hit", pos, head, kill, damage} | {type="hurt", from, damage}
	GunState = "RemoteEvent", -- {equipped?, mode?, guns={{id, mode, temp, mag, reserve}}, reloading?} (owner only)
	LevelUp = "RemoteEvent", -- {level, unlocks = {string}}
	Reward = "RemoteEvent", -- {cash, xp, at = Vector3?} (for "+$8 +20 XP" pops)
	SocialState = "RemoteEvent", -- CLOUT: {type="hello"|"market"|"feedPost"|"feedLike"|"leaders"|"posted"|"postFail"|"scout"|"followed"|"recording"|"launched"|"sale"|"away"|"toast", ...} (SocialService)
	CrimeState = "RemoteEvent", -- crime loop: {type="heat"|"dirty"|"prompts"|"mini"|"wash"|"washEnd"|"shop"|"booked"|"fade"|"aim"|"runStart"|"runProgress"|"runEnd"|"policeShot"|"boostDamage"|"pop"|"dropped", ...} (CrimeService/PoliceService)
	LiveState = "RemoteEvent", -- quality: {type="airdrop", phase, at?, label?, seconds?} | {type="cache", ...} | {type="pawn", title, rows} (Airdrop/DailyCache/PawnService)
	PropertyState = "RemoteEvent", -- Piece 4: {type="home"|"listing"|"fade"|"arrived"|"phone"|"bed"|"exit"|"power", ...} (PropertyService)
	-- C -> S
	ClientReady = "RemoteEvent", -- client controllers are listening (server re-sends waypoints etc.)
	PhoneAction = "RemoteEvent",
	CutsceneDone = "RemoteEvent", -- {id, token, skipped}
	CutsceneInput = "RemoteEvent", -- group scenes: {token, type="skip"} (a vote) | {token, type="choice", choice} (host only)
	JobAction = "RemoteEvent",
	MissionAction = "RemoteEvent", -- {type="begin"|"step", step} | {type="closeOffer"} | {type="buy", item}
	GunFire = "RemoteEvent", -- {gun, origin, dir, t, rays={{pos, part?}}} (one ray per pellet)
	GunReload = "RemoteEvent", -- {gun}
	GunAction = "RemoteEvent", -- {type="equip", gun} | {type="holster", reason?} | {type="sync"}
	GunAim = "UnreliableRemoteEvent", -- {aiming, raised, pitch, target?} at Guns.Tuning.AimSendHz while a gun is out
	PropertyAction = "RemoteEvent", -- Piece 4: {type="buy", home} | {type="closeListing"}
	SocialAction = "RemoteEvent", -- CLOUT: {type="sync"|"scout"|"post"|"like"|"follow"|"acceptDeal"|"declineDeal"|"gps"|"buyBots"|"startCourse"|"recordStep"|"cancelRecording"|"retireCourse", ...} (SocialService, 6/s)
	CrimeAction = "RemoteEvent", -- crime loop: {type="holdBegin"|"prompt", id} | {type="mini", id, score?, cancel?} | {type="buyTool", id} | {type="fence"} | {type="washCancel"} | {type="sync"}
	WaypointArrived = "RemoteEvent", -- {id} (hint only; the server checks the distance itself)
	PawnAction = "RemoteEvent", -- quality: {type="open"} | {type="sell", id} (PawnService)
	StanceAction = "RemoteEvent", -- quality: {crouch = bool} (StanceService sets the character attribute MTL_Stance)
	RequestSnapshot = "RemoteFunction",
}

function Net.init(): Folder
	assert(RunService:IsServer(), "[MTL Net] only the server creates remotes")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER) :: Folder?
	if not folder then
		local f = Instance.new("Folder")
		f.Name = FOLDER
		f.Parent = ReplicatedStorage
		folder = f
	end
	assert(folder)
	for name, className in Net.Definitions do
		local existing = folder:FindFirstChild(name)
		if existing then
			assert(existing.ClassName == className, "[MTL Net] wrong class for remote " .. name)
		else
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

function Net.get(name: string): any
	assert(Net.Definitions[name], "[MTL Net] unknown remote: " .. tostring(name))
	local folder = ReplicatedStorage:WaitForChild(FOLDER, 30)
	assert(folder, "[MTL Net] remotes folder never appeared")
	return folder:WaitForChild(name, 30)
end

return Net
