--[[
	Admin messages to every server (owner, Oct 25 13:20: "make an admin message button for the admin panel, and make
	it so that when we write something there, it sends it out to all active server appearing on the top of the
	screen"). The Admin panel's MESSAGE ALL SERVERS (AdminService "Broadcast") calls BroadcastService.send(admin, text).
	  - The text goes through Roblox's text filter first (TextService, as Roblox requires for anything a player
	    writes that others see); a text the filter can't check isn't sent.
	  - It reaches every server at once by MessagingService (topic HuzzBroadcast); each server shows it to everyone
	    there on the "AdminMessage" remote (Screens/AdminMessage: a banner at the top of the screen for SHOW seconds).
	    This server shows it straight away too; the copy coming back by MessagingService is skipped (same id).
	  - Studio without API access: it only shows in this server, and the panel's answer says so.
	  - At most MAX_LENGTH characters, and one message every GAP seconds per admin (MessagingService has limits).
]]
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

local BroadcastService = {}
BroadcastService.MAX_LENGTH = 120
BroadcastService.GAP = 5 -- seconds between one admin's messages
BroadcastService.SHOW = 10 -- seconds the banner stays on screen

local TOPIC = "HuzzBroadcast"
local seen = {} -- message id -> true (shown here already)
local lastAt = {} -- admin UserId -> os.clock()

local function show(id: string, text: string, from: string)
	if seen[id] then return end
	seen[id] = true
	;(Net.get("AdminMessage") :: RemoteEvent):FireAllClients({ text = text, from = from, seconds = BroadcastService.SHOW })
	print(`[HuzzBroadcast] {from}: {text}`)
end

-- Returns ok, the panel's answer.
function BroadcastService.send(admin: Player, text: string): (boolean, string)
	text = string.gsub(string.gsub(text, "[%c]", " "), "^%s*(.-)%s*$", "%1")
	if text == "" then return false, "Type a message first." end
	if utf8.len(text) == nil or #text > BroadcastService.MAX_LENGTH * 4 or (utf8.len(text) :: number) > BroadcastService.MAX_LENGTH then
		return false, `Keep it under {BroadcastService.MAX_LENGTH} letters.`
	end
	if os.clock() - (lastAt[admin.UserId] or -math.huge) < BroadcastService.GAP then return false, "Wait a few seconds between messages." end
	local okF, filtered = pcall(function()
		return TextService:FilterStringAsync(text, admin.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not okF or type(filtered) ~= "string" then
		if game:GetService("RunService"):IsStudio() then filtered = text -- (Studio without API access: no filter to ask)
		else return false, "Roblox's text filter didn't answer. Try again." end
	end
	lastAt[admin.UserId] = os.clock()
	local id = `{game.JobId}:{admin.UserId}:{os.clock()}`
	local entry = { Id = id, Text = filtered, From = admin.DisplayName }
	show(id, filtered, admin.DisplayName)
	local sent = pcall(function() game:GetService("MessagingService"):PublishAsync(TOPIC, entry) end)
	return true, if sent then "Sent to every server." else "Shown in this server (other servers couldn't be reached here)."
end

function BroadcastService.start()
	Net.get("AdminMessage")
	pcall(function()
		game:GetService("MessagingService"):SubscribeAsync(TOPIC, function(message)
			local e = message and message.Data
			if type(e) == "table" and type(e.Id) == "string" and type(e.Text) == "string" and type(e.From) == "string" then
				show(e.Id, string.sub(e.Text, 1, BroadcastService.MAX_LENGTH * 4), string.sub(e.From, 1, 40))
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(p) lastAt[p.UserId] = nil end)
end

return BroadcastService
