--!strict
-- Guns (Piece 5): owning, equipping and holstering guns, ammo and reloads, and the server side of every shot.
-- The server owns every decision. The client (GunController) predicts ammo and draws effects at once, then sends
-- GunFire; this service checks it (holding that gun, ammo, fire rate, muzzle near the head, aim cone, range,
-- lag-compensated hitbox, no wall in between, path + safe-zone rules) and only then deals damage and confirms
-- the hit back to the shooter (hitmarker). Research: [[Gun Mechanics]].
--
-- API (Master Plan §3.5):
--   GunService.give(player, gunId, opts?) -> ok     opts = { temporary = true, mode = "Intimidate"|"Live", ammo = n }
--       temporary guns are never saved; removed by take(), on MissionDone (story) or when the player leaves.
--       permanent: adds the gun to Inventory.Guns (+ opts.ammo rounds of its ammo type, full mag).
--   GunService.take(player, gunId)                  removes a temporary gun (or a permanent one if no temp exists)
--   GunService.lend(player, gunId, opts) / GunService.unlend(player)   aliases for missions (temporary Intimidate)
--   GunService.equip(player, gunId, force?) -> ok, reason   force = skip path / shift / safe-zone checks
--   GunService.holster(player, reason?)
--   GunService.equipped(player) -> gunId?, mode?
--   GunService.owns(player, gunId) -> bool
--   GunService.addAmmo(player, ammoType, n) -> added
--   GunService.isInFight(player) -> bool             shot at / hit by a player in the last Tuning.FightSeconds
--   GunService.inSafeZone(player) -> bool, zoneId?
--   GunService.addFireGuard(fn(player, gunId) -> (ok, reason?))
--   Signals: Equipped(player, gunId, mode) · Holstered(player, gunId, reason) · Fired(player, gunId, hitPos, hitModel?)
--            Damaged(attacker, victimModel, damage, head, killed) · Killed(attacker, victimModel)
--            Intimidating(player, targetModel, heldSeconds)   ~4x/s while aiming at a model tagged MTL_Intimidate
--            Downed(attacker, victimPlayer) · Finished(finisher, victimPlayer, downedByUserId?) · BledOut(victim, byUserId?)
--   Players aren't killed by a shot: they go down (Services/GunDowned, Config/Guns.Downed). Killed fires only when
--   someone finishes them (hold E), by the finisher. NPCs still drop at once. Gun deaths ragdoll.
--   NPCs: a Humanoid model takes damage only if it has attribute MTL_Damageable = true.
--   Player attributes: character MTL_Gun = equipped gun id ("" when holstered), MTL_GunMode, MTL_Aiming, MTL_AimPitch.
--
-- Wired here: Criminal path to use live guns; holster on clock-in, on Civilian switch, in safe zones and in
-- cutscenes (client asks); no path switch / clock-in mid-fight; the starter Pistol on Config/Guns.Starter stage;
-- Plug app phone actions buyGun{gun} / buyAmmo{ammo}.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local GunRules = require(ReplicatedStorage.MTL.Rules.GunRules)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local PhoneService = require(script.Parent.PhoneService)
local JobService = require(script.Parent.JobService)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)
local GunModels = require(script.Parent.GunModels)
local GunDowned = require(script.Parent.GunDowned)

local GunService = {}
GunService.Equipped = Signal.new()
GunService.Holstered = Signal.new()
GunService.Fired = Signal.new()
GunService.Damaged = Signal.new()
GunService.Killed = Signal.new()
GunService.Intimidating = Signal.new()
GunService.Downed = Signal.new()
GunService.Finished = Signal.new()
GunService.BledOut = Signal.new()

local T = Guns.Tuning
local MODEL_NAME = "MTL_Gun"
local GRIP_NAME = "MTL_GunGrip"
local DANGER = Color3.fromRGB(255, 86, 96)

type Temp = { mode: string, mag: number, reserve: number }
type Live = {
	equipped: string?,
	mode: string,
	equippedAt: number,
	selected: string?, -- last gun taken out (shown in the holster)
	temp: { [string]: Temp },
	reload: { gun: string, untilT: number, prevMag: number, prevReserve: number }?,
	bucket: any,
	lastCombat: number?,
	aiming: boolean,
	aimPitch: number,
	aimTarget: Instance?,
	aimSince: number,
	lastPing: number,
	lastSafeToast: number,
	reloadHinted: boolean, -- the one-time "Press R to reload" in the first robbery
}

local live: { [Player]: Live } = {}
local fireGuards: { (Player, string) -> (boolean, string?) } = {}
local history: { [Player]: { times: { number }, cfs: { CFrame } } } = {}

local fireLimiter = RateLimiter.new(30, 12)
local actionLimiter = RateLimiter.new(6, 6)
local aimLimiter = RateLimiter.new(T.AimSendHz * 2, T.AimSendHz * 2)

local function log(...)
	print("[MTL Guns]", ...)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function state(player: Player): Live
	local s = live[player]
	if not s then
		s = {
			equipped = nil,
			mode = "Live",
			equippedAt = 0,
			selected = nil,
			temp = {},
			reload = nil,
			bucket = GunRules.newBucket(T.FireBurst, now()),
			lastCombat = nil,
			aiming = false,
			aimPitch = 0,
			aimTarget = nil,
			aimSince = 0,
			lastPing = 0,
			lastSafeToast = -1e9,
			reloadHinted = false,
		}
		live[player] = s
	end
	return s
end

local function isVector3(v: any): boolean
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

local function character(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, hum, root
end

local function alive(player: Player): boolean
	local _, hum, root = character(player)
	return hum ~= nil and root ~= nil and hum.Health > 0
end

---------------------------------------------------------------- ownership + ammo

function GunService.owns(player: Player, gunId: string): boolean
	if state(player).temp[gunId] then
		return true
	end
	local data = DataService.get(player)
	return data ~= nil and data.Inventory.Guns[gunId] == true
end

local function modeOf(player: Player, gunId: string): string
	local t = state(player).temp[gunId]
	return if t then t.mode else "Live"
end

local function getMag(player: Player, gunId: string): number
	local t = state(player).temp[gunId]
	if t then
		return t.mag
	end
	local data = DataService.get(player)
	return if data then (data.Inventory.Mags[gunId] or 0) else 0
end

local function setMag(player: Player, gunId: string, n: number)
	local t = state(player).temp[gunId]
	if t then
		t.mag = n
		return
	end
	local data = DataService.get(player)
	if data then
		data.Inventory.Mags[gunId] = n
	end
end

local function getReserve(player: Player, gunId: string): number
	local t = state(player).temp[gunId]
	if t then
		return t.reserve
	end
	local data = DataService.get(player)
	local def = Guns.Defs[gunId]
	return if data and def then (data.Inventory.Ammo[def.Ammo] or 0) else 0
end

local function setReserve(player: Player, gunId: string, n: number)
	local t = state(player).temp[gunId]
	if t then
		t.reserve = n
		return
	end
	local data = DataService.get(player)
	local def = Guns.Defs[gunId]
	if data and def then
		data.Inventory.Ammo[def.Ammo] = n
	end
end

-- Guns this player can pick from, in Config order (temporary ones included).
local function gunList(player: Player): { string }
	local out = {}
	for _, id in Guns.Order do
		if GunService.owns(player, id) then
			table.insert(out, id)
		end
	end
	return out
end

local function sendState(player: Player)
	local s = state(player)
	local list = {}
	for _, id in gunList(player) do
		table.insert(list, {
			id = id,
			mode = modeOf(player, id),
			temp = s.temp[id] ~= nil,
			mag = getMag(player, id),
			reserve = getReserve(player, id),
		})
	end
	local reload = s.reload
	Net.get("GunState"):FireClient(player, {
		equipped = s.equipped,
		mode = if s.equipped then s.mode else nil,
		guns = list,
		reloading = if reload and reload.untilT > now() then reload.gun else nil,
	})
end
GunService.sendState = sendState

---------------------------------------------------------------- safe zones

local zoneCenters: { { id: string, pos: Vector3, radius: number, height: number } } = {}

local function buildZones()
	table.clear(zoneCenters)
	for _, z in Guns.SafeZones do
		local loc = (Locations :: any)[z.location]
		local pos = if typeof(loc) == "Vector3" then loc elseif type(loc) == "table" then loc[z.field or "Door"] else nil
		if typeof(pos) == "Vector3" then
			table.insert(zoneCenters, { id = z.id, pos = pos, radius = z.radius, height = z.height or 20 })
		else
			warn("[MTL Guns] safe zone", z.id, "has no position in Config/Locations")
		end
	end
end

local function pointSafe(p: Vector3): (boolean, string?)
	for _, z in zoneCenters do
		if GunRules.inZone(p.X, p.Y, p.Z, z.pos.X, z.pos.Y, z.pos.Z, z.radius, z.height) then
			return true, z.id
		end
	end
	for _, part in CollectionService:GetTagged("MTL_SafeZone") do
		if part:IsA("BasePart") then
			local l = part.CFrame:PointToObjectSpace(p)
			local h = part.Size / 2
			if GunRules.boxDistance(l.X, l.Y, l.Z, h.X, h.Y, h.Z) <= 0 then
				return true, part:GetAttribute("ZoneId") or part.Name
			end
		end
	end
	return false, nil
end

function GunService.inSafeZone(player: Player): (boolean, string?)
	if JobService.isOnShift(player) then
		return true, "Shift"
	end
	local _, _, root = character(player)
	if not root then
		return false, nil
	end
	return pointSafe(root.Position)
end

local function path(player: Player): string
	local data = DataService.get(player)
	return if data then data.Path else "Civilian"
end

---------------------------------------------------------------- models (hand / holster)

local function limbs(char: Model): (BasePart?, BasePart?, BasePart?)
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	local hip = (char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")) :: BasePart?
	local back = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	return hand, hip, back
end

local function clearModel(char: Model?)
	if not char then
		return
	end
	local old = char:FindFirstChild(MODEL_NAME)
	if old then
		old:Destroy()
	end
end

-- Puts the selected gun in the hand (inHand) or on the hip/back.
local function placeModel(player: Player, gunId: string?, inHand: boolean)
	local char = character(player)
	if not char then
		return
	end
	local existing = char:FindFirstChild(MODEL_NAME) :: Model?
	if not gunId then
		clearModel(char)
		return
	end
	local model = existing
	if not model or model:GetAttribute("MTL_GunId") ~= gunId then
		clearModel(char)
		model = GunModels.build(gunId)
		assert(model)
		model.Name = MODEL_NAME
	end
	assert(model)
	local handle = model.PrimaryPart :: BasePart
	local grip = handle:FindFirstChild("Grip") :: Attachment?
	local hand, hip, back = limbs(char)
	local motor = handle:FindFirstChild(GRIP_NAME) :: Motor6D?
	if not motor then
		local m = Instance.new("Motor6D")
		m.Name = GRIP_NAME
		m.Part1 = handle
		m.Parent = handle
		motor = m
	end
	assert(motor)
	local def = Guns.Defs[gunId]
	if inHand and hand then
		local att = hand:FindFirstChild("RightGripAttachment") :: Attachment?
		local at = if att then att.Position elseif hand.Name == "Right Arm" then Vector3.new(0, -1, 0) else Vector3.new(0, -0.15, 0)
		motor.Part0 = hand
		motor.C0 = CFrame.new(at) * CFrame.Angles(math.rad(-90), 0, 0) -- barrel along the arm
	elseif def and def.Slot == "Primary" and back then
		motor.Part0 = back
		motor.C0 = CFrame.new(0, 0, 0.75) * CFrame.Angles(0, 0, math.rad(-40)) * CFrame.Angles(0, math.rad(90), 0)
	elseif hip then
		motor.Part0 = hip
		local side = if hip.Name == "Torso" then Vector3.new(1.05, -0.9, 0) else Vector3.new(1.0, -0.1, 0.05)
		motor.C0 = CFrame.new(side) * CFrame.Angles(math.rad(-90), 0, 0) -- barrel down, grip up
	end
	motor.C1 = if grip then grip.CFrame else CFrame.new()
	model.Parent = char
	char:SetAttribute("MTL_Gun", if inHand then gunId else "")
end

---------------------------------------------------------------- equip / holster

local function cancelReload(player: Player)
	local s = state(player)
	local r = s.reload
	if r and r.untilT > now() and GunService.owns(player, r.gun) then
		setMag(player, r.gun, r.prevMag) -- unequipped mid-reload: the reload didn't happen
		setReserve(player, r.gun, r.prevReserve)
	end
	s.reload = nil
end

function GunService.equipped(player: Player): (string?, string?)
	local s = live[player]
	if s and s.equipped then
		return s.equipped, s.mode
	end
	return nil, nil
end

function GunService.holster(player: Player, reason: string?)
	local s = state(player)
	local was = s.equipped
	if not was then
		return
	end
	cancelReload(player)
	s.equipped = nil
	s.aiming = false
	s.aimTarget = nil
	local char = player.Character
	if char then
		char:SetAttribute("MTL_GunMode", nil)
		char:SetAttribute("MTL_Aiming", false)
	end
	-- the holster shows a live gun only on the criminal path (story guns just disappear)
	local show = s.selected and GunService.owns(player, s.selected) and modeOf(player, s.selected) == "Live" and path(player) == "Criminal"
	placeModel(player, if show then s.selected else nil, false)
	DataService.push(player)
	sendState(player)
	GunService.Holstered:Fire(player, was, reason or "player")
end

function GunService.equip(player: Player, gunId: string, force: boolean?): (boolean, string?)
	local def = Guns.Defs[gunId]
	if not def then
		return false, "Unknown gun"
	end
	if not GunService.owns(player, gunId) then
		return false, "You don't have that"
	end
	local s = state(player)
	local mode = modeOf(player, gunId)
	if GunDowned.isDowned(player.Character) then
		return false, "You're down"
	end
	if not force then
		local safe = GunService.inSafeZone(player)
		local ok, reason = GunRules.canEquip(path(player), mode, JobService.isOnShift(player) ~= nil, safe, alive(player))
		if not ok then
			return false, reason
		end
	elseif not alive(player) then
		return false, "You're down"
	end
	if s.equipped == gunId then
		return true, nil
	end
	if s.equipped then
		cancelReload(player)
	end
	s.equipped = gunId
	s.mode = mode
	s.selected = gunId
	s.equippedAt = now()
	placeModel(player, gunId, true)
	local char = player.Character
	if char then
		char:SetAttribute("MTL_GunMode", mode)
	end
	sendState(player)
	GunService.Equipped:Fire(player, gunId, mode)
	return true, nil
end

---------------------------------------------------------------- give / take / ammo

function GunService.give(player: Player, gunId: string, opts: { [string]: any }?): boolean
	local def = Guns.Defs[gunId]
	local data = DataService.get(player)
	if not def or not data then
		return false
	end
	local o = opts or {}
	local s = state(player)
	if o.temporary or o.noDamage then
		local mode = if o.noDamage then "Intimidate" else (o.mode or "Live")
		if not Guns.Modes[mode] then
			mode = "Intimidate"
		end
		s.temp[gunId] = { mode = mode, mag = math.min(def.Mag, o.ammo or def.Mag), reserve = math.max(0, (o.ammo or def.Mag) - def.Mag) }
	else
		data.Inventory.Guns[gunId] = true
		if data.Inventory.Mags[gunId] == nil then
			data.Inventory.Mags[gunId] = def.Mag
		end
		if o.ammo and o.ammo > 0 then
			GunService.addAmmo(player, def.Ammo, o.ammo)
		end
		DataService.push(player)
	end
	sendState(player)
	return true
end

function GunService.take(player: Player, gunId: string)
	local s = state(player)
	if s.equipped == gunId then
		GunService.holster(player, "taken")
	end
	if s.temp[gunId] then
		s.temp[gunId] = nil
	else
		local data = DataService.get(player)
		if data then
			data.Inventory.Guns[gunId] = nil
			data.Inventory.Mags[gunId] = nil
			DataService.push(player)
		end
	end
	if s.selected == gunId then
		s.selected = nil
		if not s.equipped then
			placeModel(player, nil, false)
		end
	end
	sendState(player)
end

local function takeTemporary(player: Player)
	local s = state(player)
	local ids = {}
	for id in s.temp do
		table.insert(ids, id)
	end
	for _, id in ids do
		GunService.take(player, id)
	end
end

-- Mission helpers (the Story thread's names): a temporary, no-damage gun.
function GunService.lend(player: Player, gunId: string, opts: { [string]: any }?): boolean
	local o = table.clone(opts or {})
	o.temporary = true
	if o.mode == nil then
		o.mode = if o.noDamage == false then "Live" else "Intimidate"
	end
	o.noDamage = nil
	return GunService.give(player, gunId, o)
end

function GunService.unlend(player: Player)
	takeTemporary(player)
end

function GunService.addAmmo(player: Player, ammoType: string, n: number): number
	local data = DataService.get(player)
	local pack = Guns.Ammo[ammoType]
	if not data or not pack or type(n) ~= "number" or n <= 0 then
		return 0
	end
	local have = data.Inventory.Ammo[ammoType] or 0
	local new = math.min(pack.Max, have + math.floor(n))
	data.Inventory.Ammo[ammoType] = new
	DataService.push(player)
	sendState(player)
	return new - have
end

---------------------------------------------------------------- fights / guards

function GunService.isInFight(player: Player): boolean
	local s = live[player]
	return s ~= nil and GunRules.inFight(s.lastCombat, now(), T.FightSeconds)
end

function GunService.addFireGuard(fn: (Player, string) -> (boolean, string?))
	table.insert(fireGuards, fn)
end

---------------------------------------------------------------- lag compensation

local function recordHistory()
	local t = now()
	local keep = math.ceil(T.HistorySeconds * T.HistoryHz) + 1
	for _, player in Players:GetPlayers() do
		local _, hum, root = character(player)
		if root and hum and hum.Health > 0 then
			local h = history[player]
			if not h then
				h = { times = {}, cfs = {} }
				history[player] = h
			end
			table.insert(h.times, t)
			table.insert(h.cfs, root.CFrame)
			while #h.times > keep do
				table.remove(h.times, 1)
				table.remove(h.cfs, 1)
			end
		end
	end
end

-- Root CFrames to test a hit against (rewound samples + now).
local function rootSamples(victim: Player?, root: BasePart, shotT: number): { CFrame }
	local out = { root.CFrame }
	if victim then
		local h = history[victim]
		if h then
			for _, i in GunRules.rewindSamples(h.times, shotT, now(), T.MaxRewind, T.RewindWindow) do
				table.insert(out, h.cfs[i])
			end
		end
	end
	return out
end

---------------------------------------------------------------- shooting

local function humanoidModel(inst: Instance): (Model?, Humanoid?)
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") then
			local hum = cur:FindFirstChildOfClass("Humanoid")
			if hum then
				return cur, hum
			end
		end
		cur = cur.Parent
	end
	return nil, nil
end

local function characterList(): { Instance }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true
wallParams.IgnoreWater = true

-- true if the map (not characters) blocks the line a -> b (with a little slack at the end).
local function blocked(a: Vector3, b: Vector3, extra: { Instance }?): boolean
	local list = characterList()
	for _, e in extra or {} do
		table.insert(list, e)
	end
	wallParams.FilterDescendantsInstances = list
	local d = b - a
	local len = d.Magnitude
	if len < 0.05 then
		return false
	end
	local hit = Workspace:Raycast(a, d.Unit * math.max(0, len - 1), wallParams)
	return hit ~= nil
end

type HitResult = { model: Model, hum: Humanoid, damage: number, head: boolean, pos: Vector3 }

-- Validates one claimed hit. Returns nil if anything is off.
local function checkHit(shooter: Player, s: Live, def: any, origin: Vector3, pos: Vector3, part: any, shotT: number): HitResult?
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then
		return nil
	end
	local model, hum = humanoidModel(part)
	if not model or not hum or hum.Health <= 0 or model == shooter.Character then
		return nil
	end
	local victim = Players:GetPlayerFromCharacter(model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	-- spawn protection (Services/SpawnProtection): no damage, no hitmarker, no fight timer
	if victim and (model:GetAttribute("MTL_SpawnProtected") == true or model:FindFirstChildOfClass("ForceField")) then
		return nil
	end
	-- a downed player is finished up close (hold E), not shot again
	if victim and GunDowned.isDowned(model) then
		return nil
	end
	-- rules first (cheap)
	local attackerSafe = GunService.inSafeZone(shooter)
	local targetSafe = if victim then (GunService.inSafeZone(victim)) else false
	local ok = GunRules.canDamage(s.mode, path(shooter), attackerSafe, {
		isPlayer = victim ~= nil,
		path = if victim then path(victim) else nil,
		safe = targetSafe,
		damageable = model:GetAttribute("MTL_Damageable") == true,
		self = victim == shooter,
	})
	if not ok then
		return nil
	end
	-- lag-compensated hitbox: the part's offset from the root now, applied to each rewound root
	local rel = root.CFrame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local head = part.Name == "Head"
	local tol = if head then T.HeadTolerance else T.BodyTolerance
	local best = math.huge
	for _, cf in rootSamples(victim, root, shotT) do
		local l = (cf * rel):PointToObjectSpace(pos)
		best = math.min(best, GunRules.boxDistance(l.X, l.Y, l.Z, half.X, half.Y, half.Z))
		if best <= tol then
			break
		end
	end
	if best > tol then
		log(shooter.Name, "hit rejected: off hitbox by", math.floor(best * 10) / 10)
		return nil
	end
	if blocked(origin, pos, { model }) then
		log(shooter.Name, "hit rejected: wall")
		return nil
	end
	local dmg = GunRules.damage(def, (pos - origin).Magnitude, head)
	if dmg <= 0 then
		return nil
	end
	return { model = model, hum = hum, damage = dmg, head = head, pos = pos }
end

local function fxTargets(origin: Vector3, except: Player): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= except then
			local _, _, root = character(p)
			if root and (root.Position - origin).Magnitude <= T.FxRange then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function reject(player: Player, why: string)
	-- the client predicted a shot the server didn't take: resend the truth so its counter snaps back
	sendState(player)
	if RunService:IsStudio() then
		log(player.Name, "shot rejected:", why)
	end
end

local function onFire(player: Player, p: any)
	if not fireLimiter:allow(player) or type(p) ~= "table" then
		return
	end
	local s = live[player]
	if not s or not s.equipped or p.gun ~= s.equipped then
		return reject(player, "not holding that gun")
	end
	local gunId = s.equipped :: string
	local def = Guns.Defs[gunId]
	local t = now()
	if not isVector3(p.origin) or not isVector3(p.dir) or type(p.t) ~= "number" or type(p.rays) ~= "table" then
		return reject(player, "bad payload")
	end
	local origin: Vector3, dir: Vector3 = p.origin, p.dir
	if dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
		return reject(player, "bad dir")
	end
	dir = dir.Unit
	local rays = p.rays
	if #rays < 1 or #rays > (def.Pellets or 1) then
		return reject(player, "bad ray count")
	end
	local char, hum = character(player)
	if not char or not hum or hum.Health <= 0 or GunDowned.isDowned(char) then
		return
	end
	if t - s.equippedAt < def.EquipTime * T.EquipGrace then
		return reject(player, "still equipping")
	end
	local r = s.reload
	if r and r.untilT > t then
		return reject(player, "reloading")
	end
	local mag = getMag(player, gunId)
	if mag <= 0 then
		return reject(player, "empty")
	end
	if not GunRules.rateAllow(s.bucket, def, t, T.FireRateTolerance, T.FireBurst) then
		return reject(player, "too fast")
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head or (origin - head.Position).Magnitude > T.OriginTolerance then
		return reject(player, "origin far from head")
	end
	if blocked(head.Position, origin) then
		return reject(player, "origin through a wall")
	end
	if s.mode == "Live" then
		local safe = GunService.inSafeZone(player)
		if safe then
			GunService.holster(player, "safe")
			return reject(player, "safe zone")
		end
	end
	for _, guard in fireGuards do
		local ok, why = guard(player, gunId)
		if not ok then
			return reject(player, why or "guard")
		end
	end

	setMag(player, gunId, mag - 1)

	-- each ray: clamp it to the cone and range; validate hits
	local maxAngle = GunRules.maxSpread(def) + T.AngleTolerance
	local ends: { Vector3 } = {}
	local totals: { [Model]: HitResult } = {}
	local firstModel: Model? = nil
	for i = 1, #rays do
		local ray = rays[i]
		local pos = if type(ray) == "table" then ray.pos else nil
		if not isVector3(pos) then
			pos = origin + dir * def.Range
		end
		local v = pos - origin
		local dist = v.Magnitude
		local okCone = dist > 0.01 and GunRules.angle(v.X, v.Y, v.Z, dir.X, dir.Y, dir.Z) <= maxAngle
		if not okCone or dist > def.Range + 5 then
			pos = origin + dir * math.min(math.max(dist, 1), def.Range)
		else
			local hit = checkHit(player, s, def, origin, pos, if type(ray) == "table" then ray.part else nil, p.t)
			if hit then
				local acc = totals[hit.model]
				if acc then
					acc.damage += hit.damage
					acc.head = acc.head or hit.head
				else
					totals[hit.model] = hit
				end
				firstModel = firstModel or hit.model
			end
		end
		table.insert(ends, pos)
	end

	-- effects for everyone else
	local fx = { type = "shot", shooter = player, gun = gunId, origin = origin, ends = ends }
	for _, other in fxTargets(origin, player) do
		Net.get("GunFx"):FireClient(other, fx)
	end
	GunService.Fired:Fire(player, gunId, ends[1], firstModel)
	-- first robbery: teach the reload once, right after the first shot
	if not s.reloadHinted and StoryService.stage(player) == "FirstMission" then
		s.reloadHinted = true
		Net.get("GunFx"):FireClient(player, { type = "reloadHint" })
	end

	-- damage. A shot that would kill a player downs them instead (GunDowned); NPCs drop and ragdoll.
	for model, hit in totals do
		local victim = Players:GetPlayerFromCharacter(model)
		local before = hit.hum.Health
		local lethal = before - hit.damage <= 0
		local downed = false
		hit.hum:SetAttribute("MTL_LastAttacker", player.UserId)
		if victim and lethal and GunDowned.down(player, victim, model, hit.hum) then
			downed = true
		else
			if not victim and lethal then
				hit.hum.BreakJointsOnDeath = false
			end
			hit.hum:TakeDamage(hit.damage)
		end
		local killed = before > 0 and hit.hum.Health <= 0
		if killed and not victim then
			GunDowned.ragdoll(model)
		end
		if victim then
			s.lastCombat = t
			state(victim).lastCombat = t
			Net.get("GunFx"):FireClient(victim, { type = "hurt", from = origin, damage = hit.damage })
		end
		Net.get("GunFx"):FireClient(player, { type = "hit", pos = hit.pos, head = hit.head, kill = killed or downed, downed = downed, damage = hit.damage, model = model })
		GunService.Damaged:Fire(player, model, hit.damage, hit.head, killed)
		if killed then
			GunService.Killed:Fire(player, model)
			if victim then
				Notify.toast(player, "You dropped " .. victim.DisplayName, DANGER)
			end
		end
	end
	if getMag(player, gunId) <= 0 then
		sendState(player)
	end
end

local function onReload(player: Player, p: any)
	if not actionLimiter:allow(player) or type(p) ~= "table" then
		return
	end
	local s = live[player]
	if not s or not s.equipped or p.gun ~= s.equipped then
		return
	end
	local gunId = s.equipped :: string
	local def = Guns.Defs[gunId]
	local t = now()
	if s.reload and s.reload.untilT > t then
		return
	end
	local mag, reserve = getMag(player, gunId), getReserve(player, gunId)
	if not GunRules.canReload(mag, def.Mag, reserve) then
		return sendState(player)
	end
	local newMag, newReserve = GunRules.reload(mag, def.Mag, reserve)
	s.reload = { gun = gunId, untilT = t + def.Reload * T.ReloadGrace, prevMag = mag, prevReserve = reserve }
	if player.Character then
		player.Character:SetAttribute("MTL_ReloadAt", workspace:GetServerTimeNow()) -- other clients play the reload animation from this
	end
	setMag(player, gunId, newMag)
	setReserve(player, gunId, newReserve)
	DataService.push(player)
	sendState(player)
end

local function onAction(player: Player, p: any)
	if not actionLimiter:allow(player) or type(p) ~= "table" then
		return
	end
	if p.type == "equip" and type(p.gun) == "string" then
		local ok, reason = GunService.equip(player, p.gun)
		if not ok then
			Notify.refuse(player, reason or "Can't take that out right now")
			sendState(player)
		end
	elseif p.type == "holster" then
		GunService.holster(player, if p.reason == "cutscene" then "cutscene" else "player")
	elseif p.type == "sync" then
		sendState(player)
	elseif p.type == "respawn" then
		GunDowned.respawn(player)
	end
end

---------------------------------------------------------------- aiming (pose + intimidation)

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = true

local function validIntimidateTarget(player: Player, target: any): boolean
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not CollectionService:HasTag(target, "MTL_Intimidate") then
		return false
	end
	local char, _, root = character(player)
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local tRoot = (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart) :: BasePart?
	if not head or not root or not tRoot then
		return false
	end
	local d = tRoot.Position - head.Position
	if d.Magnitude > T.IntimidateRange then
		return false
	end
	local look = root.CFrame.LookVector
	if GunRules.angle(look.X, 0, look.Z, d.X, 0, d.Z) > T.IntimidateFacing then
		return false
	end
	aimParams.FilterDescendantsInstances = { char :: Instance }
	local hit = Workspace:Raycast(head.Position, d, aimParams)
	return hit == nil or hit.Instance:IsDescendantOf(target)
end

local function onAim(player: Player, p: any)
	if not aimLimiter:allow(player) or type(p) ~= "table" then
		return
	end
	local s = live[player]
	if not s or not s.equipped then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local aiming = p.aiming == true -- really aiming (intimidation needs this)
	local raised = aiming or p.raised == true -- arms up (aiming or just fired from the hip): pose for others
	local pitch = if type(p.pitch) == "number" and p.pitch == p.pitch then math.clamp(p.pitch, -80, 80) else 0
	if raised ~= s.aiming then
		s.aiming = raised
		char:SetAttribute("MTL_Aiming", raised)
	end
	if math.abs(pitch - s.aimPitch) >= 2 then
		s.aimPitch = pitch
		char:SetAttribute("MTL_AimPitch", math.floor(pitch + 0.5))
	end
	-- intimidation: continuous aim at the same tagged model
	local t = os.clock()
	local target = if aiming and validIntimidateTarget(player, p.target) then p.target else nil
	if target ~= s.aimTarget then
		s.aimTarget = target
		s.aimSince = t
		s.lastPing = 0
	end
	if target and t - s.lastPing >= T.IntimidatePing then
		s.lastPing = t
		GunService.Intimidating:Fire(player, target, t - s.aimSince)
	end
end

---------------------------------------------------------------- shop (Plug app)

local function onBuyGun(player: Player, p: any)
	local gunId = type(p) == "table" and p.gun
	local def = type(gunId) == "string" and Guns.Defs[gunId]
	local data = DataService.get(player)
	if not def or not data then
		return
	end
	local ok, why = GunRules.canBuyGun(def, data.Level, data.Cash, data.Path, data.Inventory.Guns[gunId] == true)
	if not ok then
		Notify.toast(player, why or "Can't buy that")
		return
	end
	if not EconomyService.spend(player, def.Price, "Shop:Gun:" .. gunId) then
		Notify.toast(player, "Not enough cash")
		return
	end
	GunService.give(player, gunId, { ammo = def.Mag * 2 })
	Notify.toast(player, def.Display .. " is yours. It's on your weapon bar.", Color3.fromRGB(64, 220, 160))
	log(player.Name, "bought", gunId)
end

local function onBuyAmmo(player: Player, p: any)
	local ammo = type(p) == "table" and p.ammo
	local pack = type(ammo) == "string" and Guns.Ammo[ammo]
	local data = DataService.get(player)
	if not pack or not data then
		return
	end
	local user = false
	for id in data.Inventory.Guns do
		local def = Guns.Defs[id]
		if def and def.Ammo == ammo then
			user = true
		end
	end
	local ok, why = GunRules.canBuyAmmo(pack, data.Inventory.Ammo[ammo] or 0, data.Cash, data.Path, user)
	if not ok then
		Notify.toast(player, why or "Can't buy that")
		return
	end
	if EconomyService.spend(player, pack.Price, "Shop:Ammo:" .. ammo) then
		GunService.addAmmo(player, ammo, pack.Count)
	end
end

---------------------------------------------------------------- lifecycle

local function onCharacter(player: Player, char: Model)
	local s = state(player)
	s.equipped = nil
	s.reload = nil
	s.aiming = false
	s.aimTarget = nil
	char:SetAttribute("MTL_Gun", "")
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		GunDowned.onCharacter(player, char, hum) -- ragdoll on death, death cause for the card
		hum.Died:Connect(function()
			if s.equipped then
				GunService.holster(player, "died")
			end
			clearModel(char)
		end)
	end
	-- show the last gun in the holster again
	task.wait(0.2)
	if player.Character == char and s.selected and GunService.owns(player, s.selected) and modeOf(player, s.selected) == "Live" and path(player) == "Criminal" then
		placeModel(player, s.selected, false)
	end
	sendState(player)
end

local function onReady(player: Player, data: any)
	-- the saved mag can't be more than the gun holds (config changes)
	for id in data.Inventory.Guns do
		local def = Guns.Defs[id]
		if not def then
			data.Inventory.Guns[id] = nil
		else
			data.Inventory.Mags[id] = math.clamp(data.Inventory.Mags[id] or def.Mag, 0, def.Mag)
		end
	end
	local s = state(player)
	for _, id in Guns.Order do
		if data.Inventory.Guns[id] then
			s.selected = s.selected or id
		end
	end
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
end

-- Auto-holster: live guns go away in safe zones, on shift, or off the criminal path.
local function watchdog()
	while true do
		task.wait(T.SafeCheckSeconds)
		for player, s in live do
			if s.equipped and s.mode == "Live" and player.Parent then
				local safe, zone = GunService.inSafeZone(player)
				if safe or path(player) ~= "Criminal" then
					GunService.holster(player, "safe")
					if os.clock() - s.lastSafeToast > 8 then
						s.lastSafeToast = os.clock()
						Notify.toast(player, if zone == "Shift" then "Gun away: you're on shift" elseif safe then "Safe zone: gun holstered" else "Gun away: Civilian lifestyle")
					end
				end
			end
		end
	end
end

function GunService.init()
	buildZones()
	GunDowned.init({
		GunService = GunService,
		path = path,
		markFight = function(a: Player, b: Player)
			local t = now()
			state(a).lastCombat = t
			state(b).lastCombat = t
		end,
	})
	Net.get("GunFire").OnServerEvent:Connect(onFire)
	Net.get("GunReload").OnServerEvent:Connect(onReload)
	Net.get("GunAction").OnServerEvent:Connect(onAction)
	Net.get("GunAim").OnServerEvent:Connect(onAim)
	DataService.Ready:Connect(onReady)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / T.HistoryHz then
			acc = 0
			recordHistory()
		end
	end)
	task.spawn(watchdog)

	Players.PlayerRemoving:Connect(function(player)
		live[player] = nil
		history[player] = nil
	end)

	-- path: Civilian puts guns away; no switching mid-fight
	PhoneService.addPathGuard(function(player)
		if GunService.isInFight(player) then
			return false, "You're in a fight. Wait a bit."
		end
		return true, nil
	end)
	PhoneService.PathChanged:Connect(function(player, new)
		if new ~= "Criminal" then
			local _, mode = GunService.equipped(player)
			if mode == "Live" then
				GunService.holster(player, "path")
			end
			local s = state(player)
			if not s.equipped then
				placeModel(player, nil, false)
			end
		else
			local s = state(player)
			if not s.equipped and s.selected and GunService.owns(player, s.selected) then
				placeModel(player, s.selected, false)
			end
		end
		sendState(player)
	end)

	-- jobs: no clock-in mid-fight; clocking in puts the gun away
	JobService.addShiftGuard(function(player)
		if GunService.isInFight(player) then
			return false, "You're in a fight. Lose them first."
		end
		return true, nil
	end)
	JobService.ClockedIn:Connect(function(player)
		local _, mode = GunService.equipped(player)
		if mode == "Live" then
			GunService.holster(player, "shift")
		end
	end)

	-- story: the crew hands you a real piece after the first job; mission guns go back
	local st = Guns.Starter
	if st.GrantOnStage ~= "" then
		StoryService.onEnter(st.GrantOnStage, function(player, resumed)
			takeTemporary(player)
			if resumed then
				return
			end
			if not GunService.owns(player, st.Gun) then
				GunService.give(player, st.Gun, { ammo = st.Ammo })
				-- a full mag in the gun, not just reserve (an old save can hold a stale Mags entry)
				local data = DataService.get(player)
				if data then
					data.Inventory.Mags[st.Gun] = Guns.Defs[st.Gun].Mag
					DataService.push(player)
					sendState(player)
				end
				Notify.toast(player, "Dre slid you a " .. Guns.Defs[st.Gun].Display .. ". Press 1 to take it out.", Color3.fromRGB(64, 220, 160))
			end
		end)
	end

	PhoneService.onAction("buyGun", onBuyGun)
	PhoneService.onAction("buyAmmo", onBuyAmmo)

	-- the Plug app appears once the player is on the criminal path (and stays)
	local function plug(player: Player)
		local data = DataService.get(player)
		if data and data.Path == "Criminal" and not data.Phone.Apps.Plug then
			PhoneService.unlockApp(player, "Plug")
		end
	end
	DataService.Ready:Connect(function(player, data)
		if data.Phone.Apps.Plug == nil then
			data.Phone.Apps.Plug = false -- not a default app: hidden until the criminal path (the phone hides false)
		end
		plug(player)
	end)
	PhoneService.PathChanged:Connect(plug)

	log("ready:", #Guns.Order, "guns,", #zoneCenters, "safe zones")
end

---------------------------------------------------------------- Studio helpers

-- _G.MTL.Guns.debug(p, "Uzi")  -> Criminal path, gun + 120 rounds, equipped (skips the story)
function GunService.debug(player: Player, gunId: string?)
	local id = gunId or "Pistol"
	PhoneService.setPath(player, "Criminal", true)
	GunService.give(player, id, { ammo = 120 })
	return GunService.equip(player, id, true)
end

-- _G.MTL.Guns.dummy(p)            -> a damageable target dummy 15 studs in front of you
-- _G.MTL.Guns.dummy(p, "clerk")   -> an MTL_Intimidate dummy (aim at it to see the Intimidating signal)
function GunService.dummy(player: Player, kind: string?): Model?
	local _, _, root = character(player)
	if not root then
		return nil
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[MTL Guns] couldn't make a dummy:", rig)
		return nil
	end
	rig.Name = if kind == "clerk" then "MTL_TestClerk" else "MTL_TestDummy"
	rig:PivotTo(CFrame.lookAt(root.Position + root.CFrame.LookVector * 15, root.Position))
	if kind == "clerk" then
		CollectionService:AddTag(rig, "MTL_Intimidate")
	else
		rig:SetAttribute("MTL_Damageable", true)
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				task.wait(3)
				rig:Destroy()
			end)
		end
	end
	rig.Parent = Workspace
	return rig
end

return GunService
