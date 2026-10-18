--[[
	The owner's admin panel, server side (owner, Oct 18: "give me a admin command panel or something so i can get any
	knife or any girl to spawn when i want it to do so"). Screens/Admin is the panel; everything is decided here.

	Who: Shared/AdminRules.isAdmin, checked here with what Roblox says about the place (Studio, game.CreatorId and
	CreatorType, the player's group rank for a group game). Never a typed user ID, never the client's word. Admins get
	the attribute HuzzAdmin on their Player (it only shows the panel's button; every request is checked again).

	The "Admin" remote (client -> server: verb, key; server -> client: ok, message, verb, key), at most one request per
	ActionService.MIN_INTERVAL (0.15 s) per player, like the UI's other actions:
	  GiveKnife <knife key>   the knife goes into your knives and you wear it (saved, like a bought one)
	  SpawnGirl <girl id>     she's added to your collection and becomes your companion: she appears behind you now
	  NextGirl  <girl id>     she's the next game's girl (GirlService.setNext: the roller stops on her)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminRules = require(ReplicatedStorage.Shared.AdminRules)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local GirlService = require(script.Parent.GirlService)
local ActionService = require(script.Parent.ActionService)

local AdminService = {}
local last: { [Player]: number } = {}

-- What Roblox says about this player and this place (pcall: Lune and offline Studio lack some of it).
function AdminService.isAdmin(player: Player): boolean
	local okS, studio = pcall(function() return RunService:IsStudio() end)
	local creatorType = ""
	pcall(function() creatorType = game.CreatorType.Name end)
	local creatorId = 0
	pcall(function() creatorId = game.CreatorId end)
	local rank = nil
	if creatorType == "Group" and creatorId > 0 then
		local okR, r = pcall(function() return player:GetRankInGroup(creatorId) end)
		if okR then rank = r end
	end
	return AdminRules.isAdmin({ studio = okS and studio == true, userId = player.UserId, creatorId = creatorId, creatorType = creatorType, groupRank = rank })
end

local DO = {}
function DO.GiveKnife(player: Player, key: string): (boolean, string?)
	local item = CoinShop.get(key)
	local done = false
	DataService.update(player, function(d)
		d.Cosmetics = d.Cosmetics or {}
		d.Wear = d.Wear or {}
		d.Cosmetics[key] = true
		d.Wear.Knife = key
		done = true
	end)
	if not done then return false, "Your save is still loading." end
	return true, `You got {item and item.Name or key} (worn now).`
end

function DO.SpawnGirl(player: Player, id: string): (boolean, string?)
	local girl = GirlService.byId(id)
	local done = false
	DataService.update(player, function(d)
		d.Characters = d.Characters or {}
		d.Characters[id] = d.Characters[id] or os.time()
		d.Equipped = id
		done = true
	end)
	if not done then return false, "Your save is still loading." end
	return true, `{girl and girl.name or id} is with you now.`
end

function DO.NextGirl(_player: Player, id: string): (boolean, string?)
	local girl = GirlService.byId(id)
	GirlService.setNext(girl)
	return true, `{girl and girl.name or id} is the next game's girl.`
end

-- One request: refused unless the server says this player is an admin and the request names a real knife or girl.
function AdminService.handle(player: Player, verb: any, arg: any): (boolean, string?)
	local now = os.clock()
	if last[player] and now - last[player] < ActionService.MIN_INTERVAL then return false, "Too fast." end
	last[player] = now
	local ok, why = AdminRules.check(AdminService.isAdmin(player), verb, arg, CoinShop.get, GirlService.byId)
	if not ok then return false, why end
	if not DataService.get(player) then return false, "Your save is still loading." end
	return DO[verb](player, arg)
end

function AdminService.start()
	local remote = Net.get("Admin") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, verb, arg)
		local ok, okHandled, message = pcall(AdminService.handle, player, verb, arg)
		if not ok then okHandled, message = false, "That didn't work." end
		if not okHandled and message == "Only the game's owner can use this." then
			warn(`[Huzz] Admin request refused for {player.Name} (not the game's owner)`)
		end
		remote:FireClient(player, okHandled == true, message, verb, arg)
	end)
	local function mark(player: Player)
		player:SetAttribute("HuzzAdmin", AdminService.isAdmin(player))
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in Players:GetPlayers() do mark(p) end
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
end

return AdminService
