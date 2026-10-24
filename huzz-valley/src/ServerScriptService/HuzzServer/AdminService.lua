--[[
	The owner's admin panel, server side (owner, Oct 18: "give me a admin command panel or something so i can get any
	knife or any girl to spawn when i want it to do so"). Screens/Admin is the panel; everything is decided here.

	Who: Shared/AdminRules.isAdmin, checked here with what Roblox says about the place (Studio, game.CreatorId and
	CreatorType, the player's group rank for a group game) and Config/Admins (owner, Oct 21 15:22: him and
	thebiglion12 in the live game). Never the client's word. Admins get
	the attribute HuzzAdmin on their Player (it only shows the panel's button; every request is checked again).

	The "Admin" remote (client -> server: verb, key; server -> client: ok, message, verb, key), at most one request per
	ActionService.MIN_INTERVAL (0.15 s) per player, like the UI's other actions:
	  GiveKnife <knife key>   the knife goes into your knives and you wear it (saved, like a bought one)
	  SpawnGirl <girl id>     one more copy of her in your collection (twice = two to combine at the Combine machine), and she becomes your companion: she appears behind you now
	  NextGirl  <girl id>     she's the next game's girl (GirlService.setNext: the roller stops on her)
	Oct 21 15:22 ("spawn girls, any knife, any gamepass, so we can gift gamepasses, so we can get coins, aura,
	everything"): a third value, who it's for (a username or display name in this server, or the start of one;
	empty = you), on GiveKnife, SpawnGirl and:
	  AllKnives all           every knife in the shop
	  GivePass  <pass key>    what a game pass gives (saved: AdminPasses; ShopService counts it as owned)
	  GiveCoins <number>      coins, 1 to 1,000,000
	  GiveAura  <number>      Aura, 1 to 1,000,000
	  AllServersLuck "<luck> <minutes>"  every server gets that luck for that long (HuzzServer/LuckService.everywhere;
	                          "0 0" ends it); the third value is ignored
	  EndGame   now           ends the game on in this server (RoundService's ServerStorage.HuzzEndGame): no winner
	Every grant prints one "[HuzzAdmin] <admin> gave <who> ..." line in Output.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminRules = require(ReplicatedStorage.Shared.AdminRules)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local CombineRules = require(ReplicatedStorage.Shared.CombineRules)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Admins = require(ReplicatedStorage.Shared.Config.Admins)
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
	return AdminRules.isAdmin({ studio = okS and studio == true, userId = player.UserId, creatorId = creatorId, creatorType = creatorType,
		groupRank = rank, name = player.Name, admins = Admins })
end

-- Who a gift is for: "" = you; else a player in this server by username or display name (any capitals), or the one
-- player whose name starts with it. Returns the player, or nil and why.
function AdminService.find(admin: Player, who: any): (Player?, string?)
	if who == nil or who == "" then return admin, nil end
	if type(who) ~= "string" or #who > 40 then return nil, "Type a player's name." end
	local want = string.lower(who)
	local starts = {}
	for _, p in Players:GetPlayers() do
		local okD, display = pcall(function() return p.DisplayName end)
		local n, d = string.lower(p.Name), string.lower(if okD and type(display) == "string" then display else p.Name)
		if n == want or d == want then return p, nil end
		if string.sub(n, 1, #want) == want or string.sub(d, 1, #want) == want then table.insert(starts, p) end
	end
	if #starts == 1 then return starts[1], nil end
	if #starts > 1 then return nil, "More than one player starts with " .. who .. ": type more of the name." end
	return nil, "Nobody called " .. who .. " is in this server."
end

local function you(player: Player, admin: Player?): string
	return if admin == nil or admin == player then "You" else player.Name
end

local DO = {}
function DO.GiveKnife(player: Player, key: string, admin: Player?): (boolean, string?)
	local item = CoinShop.get(key)
	local done = false
	DataService.update(player, function(d)
		d.Cosmetics = d.Cosmetics or {}
		d.Wear = d.Wear or {}
		d.Cosmetics[key] = true
		d.Wear.Knife = key
		done = true
	end)
	if not done then return false, "Their save is still loading." end
	return true, `{you(player, admin)} got {item and item.Name or key} (worn now).`
end

function DO.AllKnives(player: Player, _arg: string, admin: Player?): (boolean, string?)
	local n, done = 0, false
	DataService.update(player, function(d)
		d.Cosmetics = d.Cosmetics or {}
		for _, item in CoinShop.Items do
			if item.Slot == "Knife" and not d.Cosmetics[item.Key] then d.Cosmetics[item.Key] = true; n += 1 end
		end
		done = true
	end)
	if not done then return false, "Their save is still loading." end
	return true, `{you(player, admin)} got every knife ({n} new).`
end

function DO.GivePass(player: Player, key: string, admin: Player?): (boolean, string?)
	local pass = Products.get(key)
	local done = false
	DataService.update(player, function(d)
		d.AdminPasses = d.AdminPasses or {}
		d.AdminPasses[key] = true
		done = true
	end)
	if not done then return false, "Their save is still loading." end
	pcall(function() require(script.Parent.ShopService).refreshPasses(player) end) -- (its knife and perks now)
	return true, `{you(player, admin)} got the {pass and pass.Name or key} pass.`
end

local function money(field: string, label: string)
	return function(player: Player, arg: string, admin: Player?): (boolean, string?)
		local n = math.floor(tonumber(arg) or 0)
		local done = false
		DataService.update(player, function(d)
			d[field] = (d[field] or 0) + n
			done = true
		end)
		if not done then return false, "Their save is still loading." end
		return true, `{you(player, admin)} got {n} {label}.`
	end
end
DO.GiveCoins = money("Coins", "coins")
DO.GiveAura = money("Aura", "Aura")

function DO.SpawnGirl(player: Player, id: string, admin: Player?): (boolean, string?)
	local girl = GirlService.byId(id)
	local done = false
	DataService.update(player, function(d)
		-- one more copy of her each time (so the owner can try the Combine machine: spawn her twice)
		CombineRules.add(d, id, "Normal")
		d.Equipped = id
		done = true
	end)
	if not done then return false, "Their save is still loading." end
	return true, if admin == nil or admin == player then `{girl and girl.name or id} is with you now.` else `{girl and girl.name or id} is with {player.Name} now.`
end

function DO.NextGirl(_player: Player, id: string): (boolean, string?)
	local girl = GirlService.byId(id)
	GirlService.setNext(girl)
	return true, `{girl and girl.name or id} is the next game's girl.`
end

function DO.EndGame(_player: Player, _arg: string, admin: Player?): (boolean, string?)
	local endGame = game:GetService("ServerStorage"):FindFirstChild("HuzzEndGame")
	if not (endGame and endGame:IsA("BindableFunction")) then return false, "The game loop isn't running." end
	return endGame:Invoke(admin and admin.DisplayName or nil)
end

function DO.AllServersLuck(_player: Player, arg: string): (boolean, string?)
	local luck, minutes = AdminRules.luckTime(arg)
	return require(script.Parent.LuckService).everywhere(luck or 0, (minutes :: number) or 0)
end

-- One request: refused unless the server says this player is an admin and the request names a real knife or girl.
function AdminService.handle(player: Player, verb: any, arg: any, who: any): (boolean, string?)
	local now = os.clock()
	if last[player] and now - last[player] < ActionService.MIN_INTERVAL then return false, "Too fast." end
	last[player] = now
	local ok, why = AdminRules.check(AdminService.isAdmin(player), verb, arg, CoinShop.get, GirlService.byId, Products.get)
	if not ok then return false, why end
	local target, whyNot = player, nil
	if verb ~= "NextGirl" and verb ~= "AllServersLuck" and verb ~= "EndGame" then target, whyNot = AdminService.find(player, who) end
	if not target then return false, whyNot end
	if not DataService.get(target) then return false, "Their save is still loading." end
	local done, message = DO[verb](target, arg, player)
	if done then print(`[HuzzAdmin] {player.Name} gave {target.Name}: {verb} {arg}`) end
	return done, message
end

function AdminService.start()
	local remote = Net.get("Admin") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, verb, arg, who)
		local ok, okHandled, message = pcall(AdminService.handle, player, verb, arg, who)
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
