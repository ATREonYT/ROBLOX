--[[
	Server luck (owner, Oct 23 15:22: "add a x2 luck, x4 luck, x8 luck dev products ... make it save per user, so for
	example if someone bought server luck, it stays with the person while he is in the game, and then when he leaves
	it resets"; 15:25: "they can go up to like 10x luck").
	  - Each Luck product (Config/Products.Luck, Amount = the multiplier) multiplies its buyer's own luck. It is never
	    saved: it lasts while the buyer is in this server and goes when they leave.
	  - The server's luck = every player's luck here multiplied together, never above Config/Round.Luck.Max. It
	    multiplies the girl odds past Common (Shared/GirlRoll.withLuck, used by GirlService).
	  - Shown to everyone: Workspace attribute "HuzzServerLuck" (the server's) and each player's "HuzzLuck" (their own),
	    read by Screens/LobbyHud (the LUCK button and the SERVER LUCK sign) and Screens/Luck.
	  - Robux buttons ask here (ActionService "PromptLuck"), never prompt from the client: only a Luck product with its
	    real ID, and only while the server's luck is under Max (a buy at the top would give nothing).
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

-- The server's luck now: everyone's here multiplied, 1 to Max.
function LuckService.server(): number
	local k = 1
	for _, p in Players:GetPlayers() do
		k *= mine[p.UserId] or 1
	end
	return math.clamp(k, 1, MAX)
end

function LuckService.of(player: Player): number
	return mine[player.UserId] or 1
end

-- A paid boost: multiplies the buyer's luck (ShopService's ProcessReceipt only). Always true: what was paid for is given.
function LuckService.add(player: Player, multiplier: number?): boolean
	local m = math.max(1, tonumber(multiplier) or 1)
	mine[player.UserId] = math.min((mine[player.UserId] or 1) * m, MAX * 1000) -- (kept finite; the server's is capped)
	publish()
	return true
end

function LuckService.prompt(player: Player, key: any): (boolean, string?)
	local product = type(key) == "string" and Products.get(key)
	if not product or product.Kind ~= "Luck" then return false, "That isn't sold here." end
	if Products.status(product) ~= "Ready" then return false, `{product.Name} is coming soon.` end
	if LuckService.server() >= MAX then return false, `Server luck is already at the top (x{MAX}).` end
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
