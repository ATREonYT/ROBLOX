--[[
	Server luck (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products ... make it save per user, so for
	example if someone bought server luck, it stays with the person while he is in the game, and then when he leaves
	it resets"; 15:25: "they can go up to like 10x luck"; 16:06 he sent nine products, x2 to x10, priced from 5 to 219).
	  - Each Luck product (Config/Products.Luck, Amount = the luck it gives) sets its buyer's luck to that, if higher.
	    It is never saved: it lasts while the buyer is in this server and goes when they leave.
	  - The server's luck = the highest luck of anyone here, never above Config/Round.Luck.Max. (Boosts don't
	    multiply: with his prices, x2 and x5 together would be x10 for a tenth of the x10's price.) It multiplies the
	    girl odds past Common (Shared/GirlRoll.withLuck, used by GirlService).
	  - Shown to everyone: Workspace attribute "HuzzServerLuck" (the server's) and each player's "HuzzLuck" (their own),
	    read by Screens/LobbyHud (the LUCK button and the SERVER LUCK sign) and Screens/Luck.
	  - A ladder (owner, Oct 23 17:32: "make it so that you have to buy x2 luck then x3 luck, etc. so they can't just
	    buy x10 luck"): only the next step above the server's luck can be bought (Products.nextLuck), so each buy
	    costs more than the last.
	  - Robux buttons ask here (ActionService "PromptLuck"), never prompt from the client: only that next step, with
	    its real ID.
	Granted only in ShopService's ProcessReceipt, once per PurchaseId.
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Round = require(Shared.Config.Round)

local LuckService = {}
local MAX = (Round.Luck and Round.Luck.Max) or 10
local mine: { [number]: number } = {} -- UserId -> that player's luck (1 = none)

local function publish()
	local server = LuckService.server()
	Workspace:SetAttribute("HuzzServerLuck", server)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzLuck", mine[p.UserId] or 1)
	end
end

-- The server's luck now: the highest of anyone here, 1 to Max.
function LuckService.server(): number
	local k = 1
	for _, p in Players:GetPlayers() do
		k = math.max(k, mine[p.UserId] or 1)
	end
	return math.clamp(k, 1, MAX)
end

function LuckService.of(player: Player): number
	return mine[player.UserId] or 1
end

-- A paid boost: the buyer's luck becomes this, if higher (ShopService's ProcessReceipt only). Always true: what was
-- paid for is given (a lower one only if a prompt raced another buyer's higher one; it still counts once they leave).
function LuckService.add(player: Player, luck: number?): boolean
	local m = math.clamp(tonumber(luck) or 1, 1, MAX)
	mine[player.UserId] = math.max(mine[player.UserId] or 1, m)
	publish()
	return true
end

function LuckService.prompt(player: Player, key: any): (boolean, string?)
	local product = type(key) == "string" and Products.get(key)
	if not product or product.Kind ~= "Luck" then return false, "That isn't sold here." end
	if Products.status(product) ~= "Ready" then return false, `{product.Name} is coming soon.` end
	if LuckService.server() >= MAX then return false, `Server luck is already at the top (x{MAX}).` end
	local nextOne = Products.nextLuck(LuckService.server())
	if not nextOne or nextOne.Key ~= product.Key then
		return false, if nextOne then `Buy the {nextOne.Name} first.` else `Server luck is already at the top (x{MAX}).`
	end
	if not pcall(function() MarketplaceService:PromptProductPurchase(player, product.Id) end) then
		return false, "The purchase couldn't open. Try again."
	end
	return true
end

function LuckService.start()
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
