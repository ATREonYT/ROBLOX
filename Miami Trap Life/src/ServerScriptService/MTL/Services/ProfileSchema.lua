--!strict
-- The save template (Master Plan §3.4) and the public snapshot sent to the owning client.
-- Adding a field: add it here with a default (Reconcile fills it in for old saves) and note it in the Master Plan.
-- Never rename or remove a field without a migration in DataService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.MTL.Config.Economy)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)

local Schema = {}

Schema.StoreName = "MTL_Profile_v1"
Schema.Version = 1

Schema.Template = {
	Version = 1,
	Cash = Economy.StartCash,
	Bank = 0,
	XP = 0,
	Level = 1,
	Path = "Civilian", -- "Civilian" | "Criminal"
	Story = { Stage = StoryRules.first(), Done = {}, Data = {} }, -- Data: per-stage scratch (e.g. chosen meet spot)
	Job = { Current = "", Shifts = {}, TasksDone = {} },
	Home = { Owned = {}, Current = "", PowerPaidUntil = 0, PowerOn = false }, -- Owned[homeId] = os.time() bought · PowerOn (Piece 4: one bill turns it on)
	Goals = { Done = {} }, -- Piece 4: Done[goalId] = os.time() the FreePlay goal's reward was given (Config/Goals)
	Inventory = { Guns = {}, Ammo = {}, Mags = {}, Items = {} }, -- Guns[gunId]=true · Ammo[ammoType]=reserve rounds · Mags[gunId]=rounds in the mag
	Phone = { Contacts = {}, Texts = {}, Unread = {}, Recents = {}, Apps = { Jobs = true, Messages = true, Calls = true, Map = true, Settings = true, Goals = false } }, -- shapes: Rules/PhoneRules · Goals unlocks at FreePlay (Piece 4)
	Earn = { Ready = {} }, -- Ready[methodId] = os.time() a money method can be done again (Config/Earn; the crime loop writes it)
	Garage = { Owned = {}, Last = "", Bought = {} }, -- Owned[carId] = true (Config/Vehicles) · Last = the car spawned last
	Boosts = { XP2xSeconds = 0, Cash2xSeconds = 0 }, -- remaining PLAY seconds
	Purchases = {}, -- [PurchaseId] = os.time()
	Stats = { Earned = 0, Spent = 0, Robberies = 0, PlayTime = 0, Joins = 0 },
	Crime = { Dirty = 0, Fence = 0, Last = {}, Count = {}, Told = {} }, -- crime loop (Config/Crime): Dirty = dirty cash in your bag · Fence = goods waiting for Marcus ($) · Last[method or method:site] = os.time() last done · Count[method] · Told[method] = unlock text sent
	Social = { Handle = "", Real = 0, Bots = 0, PostCount = 0, Posts = {}, SpotsEver = {}, SpotsToday = { day = -1, ids = {} }, Milestones = {}, PlayerFollowers = {}, Deals = { Offers = {}, Done = 0 }, Courses = {}, Earned = { Fund = 0, Deals = 0, Courses = 0 }, History = {}, Today = { day = -1, income = 0, sales = 0, posted = false, proof = false, gained = 0 }, Trust = 1, LastPostAt = 0, LastSeen = 0, Joined = 0 }, -- CLOUT (Config/Social, SocialService): Real = real followers · Bots = bought ones · Posts = last 24 (newest first) · Deals.Active = the accepted brand deal · Courses = {id, topic, price, launchDay, sold, revenue, refunds?, retired?} · History = last 7 Clout days {day, income, sales, followers, gained}
	Settings = { Music = true, Sound = true, ReducedMotion = false },
	Daily = { CacheDay = -1, BoostUntil = 0, CluedDay = -1 }, -- quality (DailyCacheService): CacheDay = UTC day you opened Bea's tin · BoostUntil = unix time 2x job pay ends · CluedDay = day Bea texted the clue
}

local PRIVATE = { Purchases = true }

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end
Schema.deepCopy = deepCopy

-- Fixes anything a bad save or an old version could have broken. Returns the same table.
function Schema.sanitize(data: any)
	if type(data.Cash) ~= "number" or data.Cash ~= data.Cash then
		data.Cash = Economy.StartCash
	end
	data.Cash = math.clamp(math.floor(data.Cash), 0, Economy.MaxCash)
	if type(data.Level) ~= "number" or data.Level < 1 then
		data.Level = 1
	end
	if type(data.XP) ~= "number" or data.XP < 0 then
		data.XP = 0
	end
	if data.Path ~= "Civilian" and data.Path ~= "Criminal" then
		data.Path = "Civilian"
	end
	if not StoryRules.isValid(data.Story.Stage) then
		data.Story.Stage = StoryRules.first()
	end
	return data
end

function Schema.public(data: any)
	local out = {}
	for k, v in data do
		if not PRIVATE[k] then
			out[k] = deepCopy(v)
		end
	end
	return out
end

return Schema
