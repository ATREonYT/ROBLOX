--!strict
-- Pure phone helpers (no Instances), shared by PhoneService, the phone apps and the tests.
-- Save shapes (Master Plan §3.4, Phone):
--   Texts[contactId]  = { { me = bool, text = string, t = os.time(), link = {kind, place}? }, ... } oldest first
--   Unread[contactId] = number
--   Recents           = { { call = callId?, contact = id, kind = "missed"|"declined"|"answered"|"outgoing",
--                           t = os.time(), callBack = bool, seen = bool }, ... } newest first
--   Contacts[contactId] = true
local Phone = require(script.Parent.Parent.Config.Phone)
local StoryRules = require(script.Parent.StoryRules)

local PhoneRules = {}

-- Adds a message to a thread, keeping only the newest `max`. Returns the thread.
function PhoneRules.appendText(thread: { any }, msg: any, max: number?): { any }
	table.insert(thread, msg)
	local limit = max or Phone.Tuning.MaxTextsPerThread
	while #thread > limit do
		table.remove(thread, 1)
	end
	return thread
end

-- Adds a call to the front of Recents, keeping only the newest `max`. Returns the list.
function PhoneRules.addRecent(recents: { any }, entry: any, max: number?): { any }
	table.insert(recents, 1, entry)
	local limit = max or Phone.Tuning.MaxRecents
	while #recents > limit do
		table.remove(recents)
	end
	return recents
end

-- A later call-back for the same call replaces the old "call back" button (only the newest one can be called back).
function PhoneRules.clearCallBack(recents: { any }, callId: string)
	for _, r in recents do
		if r.call == callId then
			r.callBack = false
		end
	end
end

-- The newest Recents entry for `callId` that can still be called back, or nil.
function PhoneRules.findCallBack(recents: { any }, callId: string): any?
	for _, r in recents do
		if r.call == callId and r.callBack then
			return r
		end
	end
	return nil
end

function PhoneRules.unreadTotal(phone: any): number
	local n = 0
	for _, c in (phone and phone.Unread) or {} do
		if type(c) == "number" then
			n += c
		end
	end
	return n
end

function PhoneRules.missedCount(phone: any): number
	local n = 0
	for _, r in (phone and phone.Recents) or {} do
		if r.kind == "missed" and not r.seen then
			n += 1
		end
	end
	return n
end

-- Badge numbers per app id for the home screen.
function PhoneRules.badges(phone: any): { [string]: number }
	return { Messages = PhoneRules.unreadTotal(phone), Calls = PhoneRules.missedCount(phone) }
end

-- Thread list for Messages: { {contact, last, t, unread} } newest first.
function PhoneRules.threads(phone: any): { any }
	local out = {}
	for contact, list in (phone and phone.Texts) or {} do
		local last = list[#list]
		if last then
			table.insert(out, {
				contact = contact,
				last = last,
				t = last.t or 0,
				unread = (phone.Unread and phone.Unread[contact]) or 0,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.t ~= b.t then
			return a.t > b.t
		end
		return a.contact < b.contact
	end)
	return out
end

-- "now", "4m", "2h", "3d"
function PhoneRules.ago(seconds: number): string
	if seconds < 60 then
		return "now"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600) .. "h"
	end
	return math.floor(seconds / 86400) .. "d"
end

-- Minutes after midnight -> "9:05 PM"
function PhoneRules.clock(minutes: number): string
	local m = math.floor(minutes) % 1440
	local h24 = m // 60
	local h12 = h24 % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, m % 60, if h24 < 12 then "AM" else "PM")
end

function PhoneRules.place(id: any): any?
	for _, p in Phone.Places do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Is this GPS place listed for a player at `stage` (ownsHome = player owns any home)?
function PhoneRules.placeVisible(place: any, stage: string, ownsHome: boolean): boolean
	if place.requires and not StoryRules.reached(stage, place.requires) then
		return false
	end
	if place.ownedHome and not ownsHome then
		return false
	end
	return true
end

-- World position of a GPS place, read from Config/Locations (passed in so this stays pure). Returns pos, radius.
function PhoneRules.placePosition(place: any, locations: any): (Vector3?, number)
	local loc = locations[place.location]
	if typeof(loc) == "Vector3" then
		return loc, 14
	elseif type(loc) == "table" then
		local v = loc[place.field or "Door"] or loc.Inside
		if typeof(v) == "Vector3" then
			return v, loc.Radius or 14
		end
	end
	return nil, 14
end

function PhoneRules.validChoice(callId: any, choiceId: any): boolean
	local cfg = type(callId) == "string" and Phone.Calls[callId] or nil
	if not cfg then
		return false
	end
	if not cfg.choices then
		return choiceId == "answered"
	end
	for _, c in cfg.choices do
		if c.id == choiceId then
			return true
		end
	end
	return false
end

-- Can the player switch Lifestyle now? Returns ok, reason (shown in Settings when not ok).
function PhoneRules.canSwitchPath(stage: string, current: string, wanted: any, lastSwitch: number, now: number): (boolean, string?)
	if wanted ~= "Civilian" and wanted ~= "Criminal" then
		return false, "Unknown lifestyle"
	end
	if wanted == current then
		return false, "Already " .. wanted
	end
	if not StoryRules.freePlayOpen(stage) then
		return false, "Unlocks after your first mission"
	end
	local wait = Phone.PathSwitchCooldown - (now - lastSwitch)
	if wait > 0 then
		return false, string.format("Wait %ds to switch again", math.ceil(wait))
	end
	return true, nil
end

function PhoneRules.validSetting(key: any, value: any): boolean
	return type(key) == "string" and Phone.SettingKeys[key] ~= nil and type(value) == Phone.SettingKeys[key]
end

function PhoneRules.appInfo(id: any): (any?, number?)
	for i, a in Phone.Apps do
		if a.id == id then
			return a, i
		end
	end
	return nil
end

return PhoneRules
