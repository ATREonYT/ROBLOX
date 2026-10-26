--[[
	Server luck (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products ... make it save per user, so for
	example if someone bought server luck, it stays with the person while he is in the game, and then when he leaves
	it resets"; 15:25: "they can go up to like 10x luck"; 16:06 he sent nine products, x2 to x10, priced from 5 to 219).
	  - Each Luck product (Config/Products.Luck, Amount = the luck it gives) sets its buyer's luck to that, if higher.
	    It is never saved: it lasts while the buyer is in this server and goes when they leave.
	  - The server's luck = everyone's boosts added up, never above Config/Round.Luck.Max (owner, Oct 23 17:53: "make
	    it stack with other players ... if one person who bought 5x luck, leaves a server with 8x luck, the luck
	    turns into 3x luck if the other guy who bought 3x stays"). Nobody boosted = x1. It multiplies the girl odds
	    past Common (Shared/GirlRoll.withLuck, used by GirlService).
	  - Shown to everyone: Workspace attribute "HuzzServerLuck" (the server's) and each player's "HuzzLuck" (their own),
	    read by Screens/LobbyHud (the LUCK button and the SERVER LUCK sign) and Screens/Luck.
	  - A ladder for your own boost (owner, Oct 23 17:32: "make it so that you have to buy x2 luck then x3 luck, etc.
	    so they can't just buy x10 luck"): only the next step above YOUR boost can be bought (Products.nextLuck), so
	    each buy costs more than the last; none while the server is at the top (it would give nothing).
	  - Robux buttons ask here (ActionService "PromptLuck"), never prompt from the client: only that next step, with
	    its real ID.
	  - Every server's luck for a while (owner, Oct 23 20:21: "give admin panel a way to add all servers luck for a
	    specific amount of time"): the Admin panel's ALL SERVERS (AdminService "AllServersLuck") calls
	    LuckService.everywhere(luck, minutes). It counts like one more booster in every server (x5 for everyone and a
	    buyer's x3 make x8, never past Max) until its end time (os.time, the same clock in every server). It reaches
	    the other servers at once by MessagingService and is kept in a DataStore so servers that start later get it
	    too (both in pcall: Studio without API access just keeps it in this server). Shown as the Workspace
	    attributes "HuzzGlobalLuck" and "HuzzGlobalLuckEnds" (os.time).
	  - Told to everyone in the server when a buy raises its luck (owner, Oct 26 09:42: "make it say when someone buys a
	    luck multiplier for the server like: ATRE_playzYT BOOSTED THE SERVER LUCK: x8"): the "LuckBoost" remote with the
	    buyer's name and the server's new luck (Screens/AdminMessage shows it as its outlined line).
	Granted only in ShopService's ProcessReceipt, once per PurchaseId.
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Round = require(Shared.Config.Round)
local Net = require(Shared.Net)

local LuckService = {}
local MAX = (Round.Luck and Round.Luck.Max) or 10
local mine: { [number]: number } = {} -- UserId -> that player's luck (1 = none)
local global = { luck = 1, ends = 0 } -- every server's luck from the Admin panel, until `ends` (os.time)
local TOPIC, STORE_KEY = "HuzzGlobalLuck", "Current"

local function globalNow(): number
	if global.luck > 1 and os.time() < global.ends then return global.luck end
	return 1
end

local function publish()
	local server = LuckService.server()
	Workspace:SetAttribute("HuzzServerLuck", server)
	local g = globalNow()
	Workspace:SetAttribute("HuzzGlobalLuck", g)
	Workspace:SetAttribute("HuzzGlobalLuckEnds", if g > 1 then global.ends else 0)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzLuck", mine[p.UserId] or 1)
	end
end

-- The server's luck now: everyone's boosts added up (x5 and x3 make x8), 1 to Max.
function LuckService.server(): number
	local k = 0
	for _, p in Players:GetPlayers() do
		local b = mine[p.UserId] or 1
		if b > 1 then k += b end
	end
	local g = globalNow()
	if g > 1 then k += g end
	return math.clamp(k, 1, MAX)
end

function LuckService.of(player: Player): number
	return mine[player.UserId] or 1
end

-- A paid boost: the buyer's own boost becomes this, if higher (ShopService's ProcessReceipt only). Always true: what
-- was paid for is given.
function LuckService.add(player: Player, luck: number?): boolean
	local m = math.clamp(tonumber(luck) or 1, 1, MAX)
	local before = LuckService.server()
	mine[player.UserId] = math.max(mine[player.UserId] or 1, m)
	publish()
	local after = LuckService.server()
	if after > before then
		pcall(function() (Net.get("LuckBoost") :: RemoteEvent):FireAllClients({ name = player.Name, luck = after }) end)
	end
	return true
end

function LuckService.prompt(player: Player, key: any): (boolean, string?)
	local product = type(key) == "string" and Products.get(key)
	if not product or product.Kind ~= "Luck" then return false, "That isn't sold here." end
	if Products.status(product) ~= "Ready" then return false, `{product.Name} is coming soon.` end
	if LuckService.server() >= MAX then return false, `Server luck is already at the top (x{MAX}).` end
	local nextOne = Products.nextLuck(LuckService.of(player))
	if not nextOne or nextOne.Key ~= product.Key then
		return false, if nextOne then `Buy the {nextOne.Name} first.` else `Your boost is already at the top (x{MAX}).`
	end
	if not pcall(function() MarketplaceService:PromptProductPurchase(player, product.Id) end) then
		return false, "The purchase couldn't open. Try again."
	end
	return true
end

-- Takes an every-server luck (from the panel here, another server's message, or the store) if it's newer.
local function take(luck: any, ends: any, at: any)
	luck, ends, at = tonumber(luck), tonumber(ends), tonumber(at) or 0
	if not luck or not ends then return end
	if at < (global.at or 0) then return end -- (an older message arriving late)
	global = { luck = math.clamp(math.floor(luck), 1, MAX), ends = ends, at = at }
	publish()
end

-- The Admin panel's every-server luck: luck (2 to Max) for minutes; luck 0 ends it. Returns ok, message.
function LuckService.everywhere(luck: number, minutes: number): (boolean, string)
	local entry = { Luck = if luck >= 2 then luck else 1, Ends = if luck >= 2 then os.time() + math.floor(minutes * 60) else 0, At = math.max(os.time() + os.clock() % 1, (global.at or 0) + 0.001) } -- (always newer than the one running: END IT pressed within the same second was taken as an older message)
	take(entry.Luck, entry.Ends, entry.At)
	local sent = pcall(function() game:GetService("MessagingService"):PublishAsync(TOPIC, entry) end)
	local kept = pcall(function() game:GetService("DataStoreService"):GetDataStore(TOPIC):SetAsync(STORE_KEY, entry) end)
	local reach = if sent then "every server" else "this server (other servers couldn't be reached here)"
	print(`[HuzzLuck] every-server luck x{entry.Luck} until {entry.Ends} (sent {sent}, kept {kept})`)
	if entry.Luck <= 1 then return true, `Every-server luck ended in {reach}.` end
	return true, `x{entry.Luck} luck for {minutes} min in {reach}.`
end

function LuckService.start()
	-- every-server luck: what's kept (a server starting later), then each message, and its end on time
	task.spawn(function()
		local ok, entry = pcall(function() return game:GetService("DataStoreService"):GetDataStore(TOPIC):GetAsync(STORE_KEY) end)
		if ok and type(entry) == "table" then take(entry.Luck, entry.Ends, entry.At) end
	end)
	pcall(function()
		game:GetService("MessagingService"):SubscribeAsync(TOPIC, function(message)
			local entry = message and message.Data
			if type(entry) == "table" then take(entry.Luck, entry.Ends, entry.At) end
		end)
	end)
	task.spawn(function()
		local was = globalNow()
		while true do
			task.wait(1)
			local now = globalNow()
			if now ~= was then was = now; publish() end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("HuzzLuck", mine[p.UserId] or 1)
	end)
	Players.PlayerRemoving:Connect(function(p)
		mine[p.UserId] = nil -- (their luck leaves with them)
		task.defer(publish) -- (after they're gone from the list)
	end)
	publish()
end

return LuckService
