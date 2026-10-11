-- Starred shoes (brief 29, the user: "equip best, rarity, favourites buttons in the ui for the shoes"). A starred pair is
-- kept out of Recycle (Shared/ShoeRules.canRecycle refuses it, so ShoeService's own Recycle is covered with no change
-- there) and sits first in the inventory's grid. The stars are saved in the profile: Shoes.Favorites = { [shoeId] = true }
-- (ShoeRules.sanitize keeps only pairs you own).
--
-- Remote ShoeAction('Favorite', id): toggles the star on a pair you own, under its own rate limit. (ShoeService ignores
-- this action: it is not in ShoeRules.Actions.) The player attribute ShoesFavorites ('Id,Id') follows the profile, set on
-- load and on every change; the inventory reads it.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local Net = require(RS.Shared.Net)
local ShoeRules = require(RS.Shared.ShoeRules)

local limit = RateLimiter.new(6, 3)

local function publish(player, profile)
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	player:SetAttribute('ShoesFavorites', ShoeRules.favoritesString(shoes))
end

Net.get('ShoeAction').OnServerEvent:Connect(function(player, action, id)
	if action ~= 'Favorite' or type(id) ~= 'string' then return end
	if not limit.allow(player) then return end
	local profile = Data.get(player)
	if not profile then return end
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	if ShoeRules.setFavorite(shoes, id, shoes.Favorites[id] ~= true) then
		publish(player, profile)
		Data.push(player)
	end
end)

local function watch(player)
	local function ready()
		local profile = player:GetAttribute('ProfileReady') and Data.get(player)
		if profile then publish(player, profile) end
	end
	player:GetAttributeChangedSignal('ProfileReady'):Connect(ready)
	ready()
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do task.spawn(watch, player) end
Players.PlayerRemoving:Connect(function(player) limit.remove(player) end)
