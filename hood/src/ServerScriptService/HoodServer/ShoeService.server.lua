-- Shoe boxes and shoes: the game's eggs and pets (brief 16; the rules are Shared/ShoeRules, the list Config/Shoes).
-- Boxes stand on the shoe-box dais at the back of the hall (map: a Model tagged HoodShoeBoxes holding ShoeBox_<Id>
-- models, each with an invisible BoxPoint_<Id> part). Opening one costs its Price in Cash and gives one pair, rolled
-- here. Up to three pairs are equipped: the best is worn, the others follow you (Shoes.client builds both on every
-- client from the attributes below). The equipped bonus multiplies the Power every shot pays (LobbyService and
-- WaveService pass ShoeMultiplier to ShotRules.pay).
--
-- Remotes (Shared/Net), all checked here:
--   OpenShoeBox(boxId)     a known box, the open rate limit (one per 1.25 s), a loaded profile and a live character,
--                          within ShoeRules.Range of that box's BoxPoint, enough Cash, room in the rack. Takes the
--                          Cash, rolls the shoe (server Random), saves it, answers with ShoeOpened.
--   ShoeAction(action, id) 'Equip' | 'Unequip' | 'EquipBest' | 'Recycle' (a spare pair, for a tenth of its box's
--                          price), from anywhere, under the action rate limit.
--   ShoeOpened             to that player: { Box, Shoe, Rarity, New (first pair of it), Count (copies now),
--                          Equipped (it went straight on) }; Shoes.client plays the unboxing moment from it.
-- Answers that need words go back as Net 'Notice' messages.
--
-- Player attributes kept in step with the profile (set on load and on every change):
--   ShoesEquipped   the equipped ids, best first, comma separated ('' for none)
--   ShoeWorn        the best equipped id (worn on the feet), '' for none
--   ShoeBonus       the equipped pairs' total bonus, percent
--   ShoeMultiplier  1 + ShoeBonus / 100 (what a shot's Power is multiplied by)
--   ShoesOwned      the rack: 'Id:copies,...' in the boxes' order
--   ShoesOpened     boxes opened ever
-- ReplicatedStorage attribute ShoeBoxes: true when this map has shoe boxes (GoalService skips the box goal otherwise).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local Format = require(RS.Shared.Format)
local Shoes = require(RS.Shared.Config.Shoes)
local ShoeRules = require(RS.Shared.ShoeRules)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
-- No dais on this map is fine: attributes still get set (equip and recycle work), and opens are refused.
local active = ActiveMap.get()

local points = {}
local function pointFor(id)
	local p = points[id]
	if p and p.Parent then return p end
	p = active and active.Root:FindFirstChild('BoxPoint_' .. id, true)
	points[id] = p
	return p
end
local found = 0
for _, box in Shoes.Boxes do
	if pointFor(box.Id) then found += 1 end
end
RS:SetAttribute('ShoeBoxes', found > 0)
if active and found < #Shoes.Boxes then warn('[ShoeService] ' .. found .. ' of ' .. #Shoes.Boxes .. ' shoe boxes found on this map.') end

local rng = Random.new()
local openLimit = RateLimiter.new(ShoeRules.OpenBurst, ShoeRules.OpenPerSecond)
local actionLimit = RateLimiter.new(ShoeRules.ActionBurst, ShoeRules.ActionPerSecond)
local opened = Net.get('ShoeOpened')

local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function sync(player, profile)
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local list = ShoeRules.equippedList(shoes)
	local bonus = ShoeRules.bonus(shoes)
	set(player, 'ShoesEquipped', table.concat(list, ','))
	set(player, 'ShoeWorn', list[1] or '')
	set(player, 'ShoeBonus', bonus)
	set(player, 'ShoeMultiplier', 1 + bonus / 100)
	set(player, 'ShoesOwned', ShoeRules.ownedString(shoes))
	set(player, 'ShoesOpened', shoes.Opened)
end
local function notice(player, text) Net.get('Notice'):FireClient(player, text) end
local function nameOf(id) local s = Shoes.ById[id]; return s and s.Name or 'that pair' end

Net.get('OpenShoeBox').OnServerEvent:Connect(function(player, boxId)
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return end
	if not openLimit.allow(player) then return end
	local profile = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if not profile or not root or not humanoid or humanoid.Health <= 0 then return end
	local point = pointFor(box.Id)
	if not point then
		notice(player, 'Find the shoe boxes at the back of the hall.')
		return
	end
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local ok, why = ShoeRules.canOpen(shoes, profile.Data.Cash, box.Id, (root.CFrame.Position - point.CFrame.Position).Magnitude)
	if not ok then
		if why == 'far' then
			notice(player, 'Walk up to the ' .. box.Name .. ' to open it')
		elseif why == 'cash' then
			notice(player, 'Need ' .. Format.compact(box.Price) .. ' Cash for the ' .. box.Name)
		elseif why == 'full' then
			notice(player, 'Your shoe rack is full (' .. ShoeRules.MaxOwned .. ' pairs). Recycle spares in SHOES first.')
		end
		return
	end
	local before = #shoes.Equipped
	profile.Data.Cash -= box.Price
	local id, fresh = ShoeRules.open(shoes, box.Id, rng:NextNumber())
	local shoe = Shoes.ById[id]
	player:SetAttribute('Cash', profile.Data.Cash)
	sync(player, profile)
	Data.push(player)
	opened:FireClient(player, {
		Box = box.Id, Shoe = id, Rarity = shoe.Rarity, New = fresh, Count = ShoeRules.copies(shoes, id), Equipped = #shoes.Equipped > before,
	})
	-- Legendary and up are news for the whole server, like big stage clears.
	if shoe.Rank >= 4 then
		for _, other in Players:GetPlayers() do
			if other ~= player then notice(other, player.DisplayName .. ' unboxed ' .. shoe.Name .. ' (' .. shoe.Rarity .. ')!') end
		end
	end
end)

Net.get('ShoeAction').OnServerEvent:Connect(function(player, action, id)
	if type(action) ~= 'string' or not ShoeRules.Actions[action] then return end
	if not actionLimit.allow(player) then return end
	local profile = Data.get(player)
	if not profile then return end
	local shoes = ShoeRules.sanitize(profile.Data.Shoes)
	profile.Data.Shoes = shoes
	local changed = false
	if action == 'Equip' then
		local ok, why = ShoeRules.equip(shoes, id)
		changed = ok
		if why == 'full' then
			notice(player, ShoeRules.MaxEquipped .. ' pairs are on. Take one off first, or tap EQUIP BEST.')
		elseif why == 'all' then
			notice(player, 'Every pair of ' .. nameOf(id) .. ' you have is on.')
		end
	elseif action == 'Unequip' then
		changed = ShoeRules.unequip(shoes, id)
	elseif action == 'EquipBest' then
		changed = ShoeRules.equipBest(shoes)
		if #shoes.Equipped > 0 then notice(player, 'Wearing your best shoes! ' .. ShoeRules.bonusText(ShoeRules.bonus(shoes)) .. ' Power') end
	elseif action == 'Recycle' then
		local ok, why = ShoeRules.canRecycle(shoes, id)
		if ok then
			local cash = ShoeRules.recycle(shoes, id)
			profile.Data.Cash = math.min(1e12, profile.Data.Cash + cash)
			player:SetAttribute('Cash', profile.Data.Cash)
			notice(player, 'Recycled ' .. nameOf(id) .. ': +' .. Format.compact(cash) .. ' Cash')
			changed = true
		elseif why == 'equipped' then
			notice(player, 'Take ' .. nameOf(id) .. ' off before recycling it.')
		end
	end
	if changed then
		sync(player, profile)
		Data.push(player)
	end
end)

-- Attributes follow the profile: DataService flips ProfileReady once a profile has loaded.
local function watch(player)
	local function ready()
		local profile = player:GetAttribute('ProfileReady') and Data.get(player)
		if profile then sync(player, profile) end
	end
	player:GetAttributeChangedSignal('ProfileReady'):Connect(ready)
	ready()
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do task.spawn(watch, player) end
Players.PlayerRemoving:Connect(function(player)
	openLimit.remove(player)
	actionLimit.remove(player)
end)
