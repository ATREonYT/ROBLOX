--!strict
-- Buy and equip rules for the ARMORY. Pure functions over a profile's Guns table ({Owned={[id]=true}, Equipped=id}),
-- so GunService (which enforces them), the armory client (which only labels prompts and paints the shop's gun
-- panels with them) and the unit tests all agree. No Instances in here.
local Guns = require(script.Parent.Config.Guns)
local Format = require(script.Parent.Format)

local GunRules = {}
GunRules.Range = 14 -- how close (studs) you must stand to a gun's point (on the shop counter) to buy or equip it

-- Gun-shop colours per state, shared by the map builder (first paint) and the client (repaints). Only small parts
-- take them: Top = the card behind each shown gun (in the slat wall's own blue-grey while locked, so a gun you
-- don't have seems to hang on the bare wall; blue once owned, green equipped: colour means "yours"), Text = the
-- price or state word on the gun's dark tag.
local C = Color3.fromRGB
GunRules.Colors = {
	Locked = { Top = C(104, 110, 124), Text = C(255, 224, 110) },
	Owned = { Top = C(104, 152, 218), Text = C(150, 200, 255) },
	Equipped = { Top = C(88, 188, 118), Text = C(140, 236, 160) },
}

-- Rarity bands by tier, in an order anyone reads without text: bronze, silver, gold, diamond. The shop shows a
-- gun's band on the metal strip along its tag (and the shop's mounts climb with it); the client bursts in it
-- when you buy the gun.
GunRules.Rarity = {
	{ Name = 'Bronze', MaxTier = 3, Color = C(190, 120, 70) },
	{ Name = 'Silver', MaxTier = 6, Color = C(204, 210, 220) },
	{ Name = 'Gold', MaxTier = 8, Color = C(240, 192, 64) },
	{ Name = 'Diamond', MaxTier = math.huge, Color = C(120, 224, 250) },
}
function GunRules.rarity(tier: number?)
	for _, band in GunRules.Rarity do
		if (tier or 1) <= band.MaxTier then return band end
	end
	return GunRules.Rarity[#GunRules.Rarity]
end

-- Makes a Guns table safe to use in place: unknown ids are dropped, the starter is always owned, and the
-- equipped gun is a known one you own (otherwise the starter). Returns the same table.
function GunRules.sanitize(guns)
	if type(guns.Owned) ~= 'table' then guns.Owned = {} end
	for id in guns.Owned do
		if type(id) ~= 'string' or not Guns.ById[id] or guns.Owned[id] ~= true then guns.Owned[id] = nil end
	end
	guns.Owned[Guns.Starter] = true
	if type(guns.Equipped) ~= 'string' or not guns.Owned[guns.Equipped] then guns.Equipped = Guns.Starter end
	return guns
end

-- 'Equipped', 'Owned' or 'Locked': the three looks of a pedestal.
function GunRules.state(guns, id: string): string
	if guns and guns.Equipped == id then return 'Equipped' end
	if guns and type(guns.Owned) == 'table' and guns.Owned[id] == true then return 'Owned' end
	return 'Locked'
end

local function near(distance)
	return type(distance) == 'number' and distance == distance and distance >= 0 and distance <= GunRules.Range
end

-- Can this player buy gun `id` right now? Returns true, or false and a reason:
-- 'unknown' (no such gun), 'owned' (already yours: equip it instead), 'far' (not at the pedestal),
-- 'cash' (can't afford it).
function GunRules.canBuy(guns, cash: number, id: any, distance: any): (boolean, string?)
	local gun = type(id) == 'string' and Guns.ById[id]
	if not gun then return false, 'unknown' end
	if GunRules.state(guns, id) ~= 'Locked' then return false, 'owned' end
	if not near(distance) then return false, 'far' end
	if type(cash) ~= 'number' or cash ~= cash or cash < gun.Cost then return false, 'cash' end
	return true, nil
end

-- Can this player equip gun `id` right now? false reasons: 'unknown', 'locked' (buy it first),
-- 'equipped' (already in use), 'far'.
function GunRules.canEquip(guns, id: any, distance: any): (boolean, string?)
	if type(id) ~= 'string' or not Guns.ById[id] then return false, 'unknown' end
	local state = GunRules.state(guns, id)
	if state == 'Locked' then return false, 'locked' end
	if state == 'Equipped' then return false, 'equipped' end
	if not near(distance) then return false, 'far' end
	return true, nil
end

-- The Power multiplier the equipped gun gives each punch (1 when nothing valid is equipped).
function GunRules.multiplier(guns): number
	return Guns.multiplier(guns and guns.Equipped)
end

-- Owned gun ids in ladder order, comma separated: the OwnedGuns player attribute clients read.
function GunRules.ownedList(guns): string
	local ids = {}
	for _, gun in Guns.List do
		if guns and type(guns.Owned) == 'table' and guns.Owned[gun.Id] == true then table.insert(ids, gun.Id) end
	end
	return table.concat(ids, ',')
end

-- The reverse of ownedList, for clients: {Owned=..., Equipped=...} from the two player attributes.
function GunRules.fromAttributes(owned: string?, equipped: string?)
	local guns = { Owned = {}, Equipped = equipped }
	for id in string.gmatch(owned or '', '[^,]+') do guns.Owned[id] = true end
	return GunRules.sanitize(guns)
end

-- Prompt wording for a pedestal in a given state.
function GunRules.actionText(state: string, cost: number): string
	if state == 'Equipped' then return 'Equipped' end
	if state == 'Owned' then return 'Equip' end
	if cost <= 0 then return 'Take' end
	return 'Buy ' .. Format.compact(cost) .. ' Cash'
end

return GunRules
