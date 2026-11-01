--!strict
-- New Game Kit: Roleplay rules (vault note 26 Fun and Roleplay Playbook, Blueprint - Roleplay Town)
-- Install: ServerScriptService/Kit/Roleplay (ModuleScript). Pure logic: no Instances, no remotes.
-- The server scripts own the Teams, tools, doors and cars; they ask this module what is allowed.
--
--   Roleplay.CanJoin(jobs, name, counts)        -> ok, reason   (job caps keep the town balanced)
--   Roleplay.Paycheck(job, lastActive, now)     -> amount, reason (pay for WORK, never for time online)
--   Roleplay.Houses.new(ids)                    -> a house book: Claim, CanEnter, SetLocked,
--                                                  AddGuest, Kick, Release, OwnerOf, HouseOf
--   Roleplay.CanSpawnVehicle(state, now)        -> ok, reason   (one car each, a server cap, a cooldown)
--   Roleplay.CanPlaceProp(placed, cap)          -> ok, reason
--   Roleplay.JailSeconds(asked)                 -> clamped seconds (nobody is trapped for long)
-- Status: covered by tests/Roleplay.spec.luau (offline).
--
-- POLICY WARNING (2026 age rules, LihFolk "Policy and Age Rules 2026" and Brief - Game Design §11):
-- a social hangout is rated 16+, and one with PRIVATE SPACES (lockable rooms, bedrooms, bathrooms,
-- tents) needs ID-verified 18+. For a kids' game: houses start UNLOCKED, locking is off unless the
-- maturity questionnaire result allows it (Houses.LockingAllowed = false by default), and never add
-- lockable bedrooms or bathrooms. Re-check the policy before turning locking on.

local Roleplay = {}

Roleplay.Rules = {
	payInterval = 180, -- a paycheck every 3 minutes...
	-- ...only if the server saw a job action in that window (LihFolk "Weekend Build - Roleplay Town with Jobs and Paychecks" §3)
	vehiclesPerPlayer = 1,
	vehiclesPerServer = 20,
	vehicleCooldown = 10, -- seconds between two spawns by one player
	propsPerPlayer = 40,
	jailMin = 10,
	jailMax = 60,
}

export type Job = { pay: number, cap: number? }

-- jobs: { [name] = Job }; counts: { [name] = players in that job now }
function Roleplay.CanJoin(jobs: { [string]: Job }, name: string, counts: { [string]: number }, current: string?): (boolean, string)
	local job = jobs[name]
	if not job then
		return false, "Unknown"
	end
	if current == name then
		return false, "Already"
	end
	local cap = job.cap or math.huge
	if (counts[name] or 0) >= cap then
		return false, "Full"
	end
	return true, "Ok"
end

-- lastActive: os.clock() of the last SERVER-observed job action (a heal, a sale, an arrest), or nil.
function Roleplay.Paycheck(job: Job?, lastActive: number?, now: number, interval: number?): (number, string)
	if not job then
		return 0, "NoJob"
	end
	local window = interval or Roleplay.Rules.payInterval
	if lastActive and now - lastActive <= window then
		return job.pay, "Working"
	end
	return 0, "NotWorking" -- always TELL the player: "No paycheck: you weren't working"
end

-- Houses ---------------------------------------------------------------------------------------

local Houses = {}
Houses.__index = Houses
Roleplay.Houses = Houses

type HouseState = { owner: number?, locked: boolean, guests: { [number]: boolean } }

export type HouseBook = typeof(setmetatable(
	{} :: { houses: { [string]: HouseState }, byOwner: { [number]: string } },
	Houses
))

function Houses.new(ids: { string }): HouseBook
	local houses = {}
	for _, id in ids do
		houses[id] = { owner = nil, locked = false, guests = {} }
	end
	return setmetatable({ houses = houses, byOwner = {} }, Houses)
end

function Houses.OwnerOf(self: HouseBook, id: string): number?
	local h = self.houses[id]
	return h and h.owner
end

function Houses.HouseOf(self: HouseBook, userId: number): string?
	return self.byOwner[userId]
end

function Houses.Claim(self: HouseBook, userId: number, id: string): (boolean, string)
	local h = self.houses[id]
	if not h then
		return false, "Unknown"
	end
	if self.byOwner[userId] then
		return false, "HasHouse" -- one house per player
	end
	if h.owner then
		return false, "Taken"
	end
	h.owner, h.locked, h.guests = userId, false, {}
	self.byOwner[userId] = id
	return true, "Ok"
end

function Houses.CanEnter(self: HouseBook, userId: number, id: string): boolean
	local h = self.houses[id]
	if not h or not h.locked then
		return true
	end
	return h.owner == userId or h.guests[userId] == true
end

Houses.LockingAllowed = false -- see the POLICY WARNING at the top before setting this to true

function Houses.SetLocked(self: HouseBook, userId: number, id: string, locked: boolean): (boolean, string)
	if locked and not Houses.LockingAllowed then
		return false, "LockingOff"
	end
	local h = self.houses[id]
	if not h or h.owner ~= userId then
		return false, "NotOwner"
	end
	h.locked = locked
	return true, "Ok"
end

function Houses.AddGuest(self: HouseBook, userId: number, id: string, guest: number): (boolean, string)
	local h = self.houses[id]
	if not h or h.owner ~= userId then
		return false, "NotOwner"
	end
	if guest == userId then
		return false, "Self"
	end
	h.guests[guest] = true
	return true, "Ok"
end

-- Returns true when the caller should move `target` outside the door. Kicking also un-invites.
function Houses.Kick(self: HouseBook, userId: number, id: string, target: number): boolean
	local h = self.houses[id]
	if not h or h.owner ~= userId or target == userId then
		return false
	end
	h.guests[target] = nil
	return true
end

-- On PlayerRemoving: free their house and remove them from every guest list.
function Houses.Release(self: HouseBook, userId: number)
	local id = self.byOwner[userId]
	if id then
		local h = self.houses[id]
		h.owner, h.locked, h.guests = nil, false, {}
		self.byOwner[userId] = nil
	end
	for _, h in self.houses do
		h.guests[userId] = nil
	end
end

-- Vehicles and props ---------------------------------------------------------------------------

export type VehicleState = { mine: number, server: number, lastSpawn: number? }

function Roleplay.CanSpawnVehicle(state: VehicleState, now: number): (boolean, string)
	local r = Roleplay.Rules
	if state.lastSpawn and now - state.lastSpawn < r.vehicleCooldown then
		return false, "Wait"
	end
	-- At the per-player cap the caller despawns the old car first (a swap doesn't change the count,
	-- so it is allowed even on a full server).
	if state.mine >= r.vehiclesPerPlayer then
		return true, "Replace"
	end
	if state.server >= r.vehiclesPerServer then
		return false, "ServerFull"
	end
	return true, "Ok"
end

function Roleplay.CanPlaceProp(placed: number, cap: number?): (boolean, string)
	if placed >= (cap or Roleplay.Rules.propsPerPlayer) then
		return false, "PropLimit"
	end
	return true, "Ok"
end

function Roleplay.JailSeconds(asked: number?): number
	local r = Roleplay.Rules
	local n = tonumber(asked) or r.jailMin
	if n ~= n then
		n = r.jailMin
	end
	return math.clamp(math.floor(n), r.jailMin, r.jailMax)
end

return Roleplay
