--!strict
-- The phone's server side: texts, calls, notifications, app unlocks, GPS routes, Lifestyle switch, settings.
-- The save holds the truth (data.Phone, see Rules/PhoneRules for shapes); the client renders from its snapshot and
-- uses PhoneEvent only for the moment something arrives (banner, ring). Every PhoneAction is validated here.
--
-- API (Master Plan §3.5):
--   PhoneService.text(player, contactId, text, opts?)   opts = { link = {kind="waypoint", place=GPSPlaceId, label?}
--                                                                        | {kind="app", app=AppId}, silent = bool }
--   PhoneService.call(player, callId) -> bool          rings; result comes back on CallEnded
--   PhoneService.CallEnded: Signal(player, callId, outcome)
--        outcome = a choice id from Config/Phone.Calls[callId].choices, or "answered" | "missed" | "declined" | "hungUp"
--   PhoneService.openApp(player, appId)  PhoneService.unlockApp(player, appId)
--   PhoneService.notify(player, { app, title, text })   a banner on the phone without a text thread
--   PhoneService.setPath(player, path, force?) -> ok, reason
--   PhoneService.PathChanged: Signal(player, newPath, oldPath)
--   PhoneService.addPathGuard(fn(player, wanted) -> (ok, reason?))   e.g. GunService blocks switching mid-fight
--   PhoneService.onAction(type, fn(player, payload))   other pieces handle their own phone buttons (Jobs: "chooseJob")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local PhoneConfig = require(ReplicatedStorage.MTL.Config.Phone)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local PhoneRules = require(ReplicatedStorage.MTL.Rules.PhoneRules)
local DataService = require(script.Parent.DataService)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)

local PhoneService = {}
PhoneService.CallEnded = Signal.new() -- (player, callId, outcome)
PhoneService.PathChanged = Signal.new() -- (player, newPath, oldPath)
PhoneService.TextSent = Signal.new() -- (player, contactId, text)

type CallState = { id: string, state: string, token: number, outgoing: boolean }
local calls: { [Player]: CallState } = {}
local lastPathSwitch: { [Player]: number } = {}
local handlers: { [string]: (Player, any) -> () } = {}
local pathGuards: { (Player, string) -> (boolean, string?) } = {}
local limiter = RateLimiter.new(8, 14)
local tokenCounter = 0

local function log(...)
	print("[MTL Phone]", ...)
end

local function fire(player: Player, payload: { [string]: any })
	Net.get("PhoneEvent"):FireClient(player, payload)
end

local function phoneData(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local p = data.Phone
	p.Texts = p.Texts or {}
	p.Unread = p.Unread or {}
	p.Recents = p.Recents or {}
	p.Contacts = p.Contacts or {}
	p.Apps = p.Apps or {}
	return p
end

local function contactName(id: string): string
	local c = Story.Contacts[id]
	return if c then c.Name else id
end

---------------------------------------------------------------- texts

function PhoneService.text(player: Player, contactId: string, text: string, opts: { [string]: any }?): boolean
	local p = phoneData(player)
	if not p or type(text) ~= "string" or text == "" then
		return false
	end
	local o = opts or {}
	local msg: { [string]: any } = { me = false, text = text, t = os.time() }
	if type(o.link) == "table" then
		msg.link = o.link
	end
	p.Texts[contactId] = PhoneRules.appendText(p.Texts[contactId] or {}, msg)
	p.Contacts[contactId] = true
	if not o.silent then
		p.Unread[contactId] = (p.Unread[contactId] or 0) + 1
	end
	DataService.push(player)
	fire(player, { type = "text", contact = contactId, name = contactName(contactId), text = text, silent = o.silent == true })
	PhoneService.TextSent:Fire(player, contactId, text)
	return true
end

-- A line the PLAYER "sent" (scripted replies, e.g. after a choice). Never counts as unread.
function PhoneService.textFromMe(player: Player, contactId: string, text: string)
	local p = phoneData(player)
	if not p then
		return
	end
	p.Texts[contactId] = PhoneRules.appendText(p.Texts[contactId] or {}, { me = true, text = text, t = os.time() })
	p.Contacts[contactId] = true
	DataService.push(player)
end

---------------------------------------------------------------- notifications / apps

function PhoneService.notify(player: Player, n: { app: string?, title: string, text: string? })
	fire(player, { type = "notify", app = n.app, title = n.title, text = n.text or "" })
end

function PhoneService.openApp(player: Player, appId: string)
	fire(player, { type = "open", app = appId })
end

function PhoneService.unlockApp(player: Player, appId: string)
	local p = phoneData(player)
	if not p or p.Apps[appId] then
		return
	end
	p.Apps[appId] = true
	DataService.push(player)
	local info = PhoneRules.appInfo(appId)
	fire(player, { type = "unlockApp", app = appId, title = if info then info.title else appId })
end

---------------------------------------------------------------- calls

function PhoneService.isInCall(player: Player): boolean
	return calls[player] ~= nil
end

local function addRecent(player: Player, callId: string?, contact: string, kind: string, callBack: boolean)
	local p = phoneData(player)
	if not p then
		return
	end
	if callId then
		PhoneRules.clearCallBack(p.Recents, callId)
	end
	PhoneRules.addRecent(p.Recents, {
		call = callId,
		contact = contact,
		kind = kind,
		t = os.time(),
		callBack = callBack,
		seen = kind ~= "missed",
	})
	p.Contacts[contact] = true
	DataService.push(player)
end

local function endCall(player: Player, outcome: string)
	local c = calls[player]
	if not c then
		return
	end
	calls[player] = nil
	fire(player, { type = "call", state = "ended", call = c.id, outcome = outcome })
	log(player.Name, "call", c.id, "->", outcome)
	PhoneService.CallEnded:Fire(player, c.id, outcome)
end

local function connect(player: Player, c: CallState)
	local cfg = PhoneConfig.Calls[c.id]
	c.state = "connected"
	fire(player, {
		type = "call",
		state = "connected",
		call = c.id,
		contact = cfg.contact,
		name = contactName(cfg.contact),
		lines = cfg.lines,
		choices = cfg.choices,
		outgoing = c.outgoing,
	})
end

-- Rings the player with a scripted call from Config/Phone.Calls. Returns false if they're already on a call.
function PhoneService.call(player: Player, callId: string): boolean
	local cfg = PhoneConfig.Calls[callId]
	assert(cfg, "[MTL Phone] unknown call " .. tostring(callId))
	if calls[player] or not DataService.get(player) then
		return false
	end
	tokenCounter += 1
	local c: CallState = { id = callId, state = "ringing", token = tokenCounter, outgoing = false }
	calls[player] = c
	fire(player, { type = "call", state = "ringing", call = callId, contact = cfg.contact, name = contactName(cfg.contact) })
	log(player.Name, "ringing", callId)
	local token = c.token
	task.delay(PhoneConfig.Tuning.RingSeconds, function()
		local now = calls[player]
		if now and now.token == token and now.state == "ringing" then
			addRecent(player, callId, cfg.contact, "missed", cfg.callBack == true)
			endCall(player, "missed")
		end
	end)
	return true
end

local function onAnswer(player: Player, payload: any)
	local c = calls[player]
	if c and c.state == "ringing" and payload.call == c.id then
		connect(player, c)
	end
end

local function onDecline(player: Player, payload: any)
	local c = calls[player]
	if c and c.state == "ringing" and payload.call == c.id then
		local cfg = PhoneConfig.Calls[c.id]
		addRecent(player, c.id, cfg.contact, "declined", cfg.callBack == true)
		endCall(player, "declined")
	end
end

local function onChoice(player: Player, payload: any)
	local c = calls[player]
	if not (c and c.state == "connected" and payload.call == c.id) then
		return
	end
	local choice = payload.choice
	if not PhoneRules.validChoice(c.id, choice) then
		return
	end
	local cfg = PhoneConfig.Calls[c.id]
	local keep = false
	for _, ch in cfg.choices or {} do
		if ch.id == choice and ch.keepCallBack then
			keep = true
		end
	end
	addRecent(player, c.id, cfg.contact, if c.outgoing then "outgoing" else "answered", keep and cfg.callBack == true)
	endCall(player, choice)
end

local function onHangUp(player: Player, payload: any)
	local c = calls[player]
	if not (c and c.state == "connected" and payload.call == c.id) then
		return
	end
	local cfg = PhoneConfig.Calls[c.id]
	if cfg.choices then
		-- hung up before answering the question: they can call back
		addRecent(player, c.id, cfg.contact, if c.outgoing then "outgoing" else "answered", cfg.callBack == true)
		endCall(player, "hungUp")
	else
		addRecent(player, c.id, cfg.contact, if c.outgoing then "outgoing" else "answered", false)
		endCall(player, "answered")
	end
end

local function onCallBack(player: Player, payload: any)
	local p = phoneData(player)
	if not p or calls[player] or type(payload.call) ~= "string" then
		return
	end
	local entry = PhoneRules.findCallBack(p.Recents, payload.call)
	if not entry or not PhoneConfig.Calls[payload.call] then
		return
	end
	tokenCounter += 1
	local c: CallState = { id = payload.call, state = "connected", token = tokenCounter, outgoing = true }
	calls[player] = c
	connect(player, c)
end

---------------------------------------------------------------- lifestyle / settings

function PhoneService.addPathGuard(fn: (Player, string) -> (boolean, string?))
	table.insert(pathGuards, fn)
end

-- force = story/admin switch (skips stage, cooldown and guards).
function PhoneService.setPath(player: Player, wanted: string, force: boolean?): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not force then
		local ok, reason = PhoneRules.canSwitchPath(data.Story.Stage, data.Path, wanted, lastPathSwitch[player] or -1e9, os.clock())
		if not ok then
			return false, reason
		end
		for _, guard in pathGuards do
			local gOk, gReason = guard(player, wanted)
			if not gOk then
				return false, gReason or "Can't switch right now"
			end
		end
	elseif wanted ~= "Civilian" and wanted ~= "Criminal" then
		return false, "Unknown lifestyle"
	end
	local old = data.Path
	if old == wanted then
		return true, nil
	end
	data.Path = wanted
	lastPathSwitch[player] = os.clock()
	player:SetAttribute("MTL_Path", wanted)
	DataService.push(player)
	log(player.Name, "path", old, "->", wanted)
	PhoneService.PathChanged:Fire(player, wanted, old)
	return true, nil
end

local function onSetPath(player: Player, payload: any)
	local ok, reason = PhoneService.setPath(player, payload.path)
	if ok then
		Notify.toast(player, "Lifestyle: " .. tostring(payload.path), if payload.path == "Criminal" then Color3.fromRGB(255, 86, 96) else nil)
	else
		Notify.toast(player, reason or "Can't switch right now")
	end
	fire(player, { type = "pathResult", ok = ok, reason = reason })
end

local function onSetSetting(player: Player, payload: any)
	local data = DataService.get(player)
	if data and PhoneRules.validSetting(payload.key, payload.value) then
		data.Settings[payload.key] = payload.value
		DataService.push(player)
	end
end

---------------------------------------------------------------- GPS / links

-- Sets the GPS route to a place id from Config/Phone.Places (server checks it's visible to this player).
function PhoneService.route(player: Player, placeId: string): boolean
	local data = DataService.get(player)
	local place = PhoneRules.place(placeId)
	if not data or not place then
		return false
	end
	local ownsHome = next(data.Home.Owned) ~= nil
	if not PhoneRules.placeVisible(place, data.Story.Stage, ownsHome) then
		return false
	end
	local pos, radius = PhoneRules.placePosition(place, Locations)
	if not pos then
		warn("[MTL Phone] no position for place", placeId)
		return false
	end
	WaypointService.set(player, PhoneConfig.GPSWaypointId, pos, { label = place.label, radius = radius })
	player:SetAttribute("MTL_GPS", placeId)
	return true
end

function PhoneService.clearRoute(player: Player)
	WaypointService.clear(player, PhoneConfig.GPSWaypointId)
	player:SetAttribute("MTL_GPS", nil)
end

local function onOpenLink(player: Player, payload: any)
	local p = phoneData(player)
	if not p or type(payload.contact) ~= "string" or type(payload.index) ~= "number" then
		return
	end
	local thread = p.Texts[payload.contact]
	local msg = thread and thread[math.floor(payload.index)]
	local link = msg and msg.link
	if type(link) ~= "table" then
		return
	end
	if link.kind == "waypoint" and type(link.place) == "string" then
		if PhoneService.route(player, link.place) then
			Notify.toast(player, "Route set: " .. (link.label or link.place))
		end
	elseif link.kind == "app" and type(link.app) == "string" then
		PhoneService.openApp(player, link.app)
	end
end

---------------------------------------------------------------- actions

function PhoneService.onAction(actionType: string, fn: (Player, any) -> ())
	assert(handlers[actionType] == nil, "[MTL Phone] action already handled: " .. actionType)
	handlers[actionType] = fn
end

-- Messages quick replies: the player sends one of Config/Phone.QuickReplies into a thread they already have;
-- the contact may answer back with a canned line after a short pause.
local lastReply: { [Player]: number } = {}
local lastAutoReply: { [Player]: { [string]: number } } = {}

local function onQuickReply(player: Player, payload: any)
	local p = phoneData(player)
	local contact, index = payload.contact, payload.index
	if not p or type(contact) ~= "string" or type(index) ~= "number" then
		return
	end
	local text = PhoneConfig.QuickReplies[math.floor(index)]
	if not text or not p.Contacts[contact] or not p.Texts[contact] then
		return
	end
	local now = os.clock()
	if now - (lastReply[player] or -1e9) < PhoneConfig.ReplyCooldown then
		return
	end
	lastReply[player] = now
	PhoneService.textFromMe(player, contact, text)
	local seen = lastAutoReply[player] or {}
	lastAutoReply[player] = seen
	if now - (seen[contact] or -1e9) < PhoneConfig.AutoReplyCooldown then
		return
	end
	seen[contact] = now
	local pool = PhoneConfig.AutoReplies[contact] or PhoneConfig.AutoReplies.default
	if not pool or #pool == 0 then
		return
	end
	local answer = pool[math.random(1, #pool)]
	fire(player, { type = "typing", contact = contact })
	task.delay(1.6 + math.random() * 1.4, function()
		if player.Parent then
			PhoneService.text(player, contact, answer)
		end
	end)
end

local builtIn: { [string]: (Player, any) -> () } = {
	quickReply = onQuickReply,
	answerCall = onAnswer,
	declineCall = onDecline,
	callChoice = onChoice,
	hangUp = onHangUp,
	callBack = onCallBack,
	setPath = onSetPath,
	setSetting = onSetSetting,
	openLink = onOpenLink,
	readThread = function(player, payload)
		local p = phoneData(player)
		if p and type(payload.contact) == "string" and p.Unread[payload.contact] then
			p.Unread[payload.contact] = nil
			DataService.push(player)
		end
	end,
	seenRecents = function(player)
		local p = phoneData(player)
		if not p then
			return
		end
		local changed = false
		for _, r in p.Recents do
			if not r.seen then
				r.seen = true
				changed = true
			end
		end
		if changed then
			DataService.push(player)
		end
	end,
	gpsRoute = function(player, payload)
		if type(payload.place) == "string" then
			PhoneService.route(player, payload.place)
		end
	end,
	gpsClear = function(player)
		PhoneService.clearRoute(player)
	end,
}

function PhoneService.init()
	Net.get("PhoneAction").OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.type) ~= "string" then
			return
		end
		if not limiter:allow(player) or not DataService.get(player) then
			return
		end
		local fn = builtIn[payload.type] or handlers[payload.type]
		if not fn then
			if payload.type == "chooseJob" then
				Notify.toast(player, "Jobs open in the next update") -- until the Jobs piece registers chooseJob
			end
			return
		end
		local ok, err = pcall(fn, player, payload)
		if not ok then
			warn("[MTL Phone] action", payload.type, "failed:", err)
		end
	end)

	DataService.Ready:Connect(function(player, data)
		player:SetAttribute("MTL_Path", data.Path)
		-- apps added to Config after a save was made get installed if they're defaults
		for _, app in PhoneConfig.Apps do
			if app.default and data.Phone.Apps[app.id] == nil then
				data.Phone.Apps[app.id] = true
			end
		end
	end)

	-- a client that (re)starts listening mid-ring sees the ring again
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		local c = calls[player]
		if c then
			local cfg = PhoneConfig.Calls[c.id]
			if c.state == "ringing" then
				fire(player, { type = "call", state = "ringing", call = c.id, contact = cfg.contact, name = contactName(cfg.contact) })
			else
				connect(player, c)
			end
		end
	end)

	WaypointService.Arrived:Connect(function(player, id)
		if id == PhoneConfig.GPSWaypointId then
			local place = PhoneRules.place(player:GetAttribute("MTL_GPS"))
			player:SetAttribute("MTL_GPS", nil)
			Notify.toast(player, "Arrived" .. (if place then ": " .. place.label else ""))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		calls[player] = nil
		lastPathSwitch[player] = nil
		lastReply[player] = nil
		lastAutoReply[player] = nil
	end)
end

return PhoneService
