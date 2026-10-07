-- The ARMORY: buy guns with Cash and equip one. The equipped gun multiplies the Power each shot pays at the
-- ranges (LobbyService's Shoot handler reads the player attribute GunMultiplier), and it is the gun you hold:
-- every player carries one gun Tool (Shared/GunTool) of their equipped gun, given on spawn and swapped
-- (in the hand if it was held) whenever the equipped gun changes. Shoot.client takes it out on a range.
--
-- Remotes (Shared/Net): BuyGun(id) and EquipGun(id), both RemoteEvents. Everything is checked here: the id,
-- a rate limit, that the profile is loaded and the character alive, that you stand within GunRules.Range of
-- that gun's pedestal (part GunPoint_<Id> in the active map), that you own it (equip) or can afford it (buy).
-- Buying takes the Cash, adds the gun and equips it. Answers go back as Net 'Notice' messages.
--
-- Player attributes kept in step with the profile (set on load and on every change):
--   EquippedGun    gun id ('Pistol' to start)
--   GunMultiplier  that gun's Multiplier (1 for the pistol)
--   OwnedGuns      owned ids in ladder order, comma separated (clients paint the pedestals from it)
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local Format = require(RS.Shared.Format)
local Guns = require(RS.Shared.Config.Guns)
local GunRules = require(RS.Shared.GunRules)
local GunTool = require(RS.Shared.GunTool)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
-- No armory on this map is fine: attributes still get set (the pistol's x1), and buy requests are refused.
local active = ActiveMap.get()

local points = {}
local function pointFor(id)
	local p = points[id]
	if p and p.Parent then return p end
	p = active and active.Root:FindFirstChild('GunPoint_' .. id, true)
	points[id] = p
	return p
end

-- The held gun follows EquippedGun (a failed build never blocks the attributes).
local function giveTool(player)
	local id = player:GetAttribute('EquippedGun')
	if type(id) == 'string' then
		local ok, err = pcall(GunTool.sync, player, id)
		if not ok then warn('[GunService] gun tool: ' .. tostring(err)) end
	end
end

local function sync(player, profile)
	local guns = GunRules.sanitize(profile.Data.Guns)
	player:SetAttribute('EquippedGun', guns.Equipped)
	player:SetAttribute('GunMultiplier', GunRules.multiplier(guns))
	player:SetAttribute('OwnedGuns', GunRules.ownedList(guns))
	giveTool(player)
end

local function notice(player, text) Net.get('Notice'):FireClient(player, text) end
local function perShot(gun) return 'x' .. gun.Multiplier .. ' Power per shot' end

-- Shared front half of both requests: valid id, under the rate limit, profile loaded, alive, and how far
-- you stand from the gun. Returns nil when the request should be dropped silently.
local limit = RateLimiter.new(4, 2)
local function begin(player, id)
	if type(id) ~= 'string' or not Guns.ById[id] then return nil end
	if not limit.allow(player) then return nil end
	local profile = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if not profile or not root or not humanoid or humanoid.Health <= 0 then return nil end
	local point = pointFor(id)
	if not point then
		notice(player, 'Find the ARMORY to get guns.')
		return nil
	end
	return profile, (root.Position - point.Position).Magnitude
end

local function equip(player, profile, gun)
	profile.Data.Guns.Equipped = gun.Id
	sync(player, profile)
	Data.push(player)
end

Net.get('BuyGun').OnServerEvent:Connect(function(player, id)
	local profile, distance = begin(player, id)
	if not profile then return end
	local guns = GunRules.sanitize(profile.Data.Guns)
	local gun = Guns.ById[id]
	local ok, why = GunRules.canBuy(guns, profile.Data.Cash, id, distance)
	if not ok then
		if why == 'owned' then
			-- Already yours (the client was a beat behind): treat it as an equip.
			if GunRules.canEquip(guns, id, distance) then
				equip(player, profile, gun)
				notice(player, 'Equipped ' .. gun.Name .. '! ' .. perShot(gun))
			end
		elseif why == 'far' then
			notice(player, 'Walk up to the gun to buy it')
		elseif why == 'cash' then
			notice(player, 'Need ' .. Format.compact(gun.Cost) .. ' Cash')
		end
		return
	end
	profile.Data.Cash -= gun.Cost
	guns.Owned[gun.Id] = true
	equip(player, profile, gun)
	notice(player, 'Bought ' .. gun.Name .. '! ' .. perShot(gun))
	-- The top guns are news for the whole server, like big stage clears.
	if gun.Tier >= 7 then
		for _, other in Players:GetPlayers() do
			if other ~= player then notice(other, player.DisplayName .. ' bought the ' .. gun.Name .. '!') end
		end
	end
end)

Net.get('EquipGun').OnServerEvent:Connect(function(player, id)
	local profile, distance = begin(player, id)
	if not profile then return end
	local guns = GunRules.sanitize(profile.Data.Guns)
	local gun = Guns.ById[id]
	local ok, why = GunRules.canEquip(guns, id, distance)
	if not ok then
		if why == 'locked' then
			notice(player, 'Buy the ' .. gun.Name .. ' first: ' .. Format.compact(gun.Cost) .. ' Cash')
		elseif why == 'far' then
			notice(player, 'Walk up to the gun to equip it')
		end
		return
	end
	equip(player, profile, gun)
	notice(player, 'Equipped ' .. gun.Name .. '! ' .. perShot(gun))
end)

-- Attributes follow the profile: DataService flips ProfileReady once a profile has loaded.
local function watch(player)
	local function ready()
		local profile = player:GetAttribute('ProfileReady') and Data.get(player)
		if profile then sync(player, profile) end
	end
	player:GetAttributeChangedSignal('ProfileReady'):Connect(ready)
	ready()
	-- A new character gets a fresh Backpack: hand the gun over again once it exists.
	player.CharacterAdded:Connect(function()
		task.wait(0.1) -- (the old Backpack goes away around the spawn)
		if player:WaitForChild('Backpack', 10) then giveTool(player) end
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do task.spawn(watch, player) end
Players.PlayerRemoving:Connect(function(player) limit.remove(player) end)
