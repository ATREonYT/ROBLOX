--!strict
-- Buy and equip rules for the ARMORY. Pure functions over a profile's Guns table ({Owned={[id]=true}, Equipped=id}),
-- so GunService (which enforces them), the armory client (which only labels prompts and paints pedestals with
-- them) and the unit tests all agree. No Instances in here.
local Guns = require(script.Parent.Config.Guns)
local Format = require(script.Parent.Format)

local GunRules = {}
GunRules.Range = 14 -- how close (studs) you must stand to a gun's pedestal point to buy or equip it

-- Pedestal colours per state, shared by the map builder (first paint) and the client (repaints): the pad face
-- (Top), its light core (Glow), its dark rim (Shade), the front plate (Strip), the price (Text) and the
-- nameplate's price/state line (Word: red locked, yellow buy, blue owned, green equipped). Buy is how a Locked gun
-- you can afford is shown (the same pad, a yellow BUY line).
local C = Color3.fromRGB
GunRules.Colors = {
	Locked = { Top = C(255, 112, 186), Glow = C(255, 160, 214), Shade = C(150, 50, 106), Strip = C(226, 64, 146), Text = C(255, 228, 92), Word = C(255, 92, 92) },
	Buy = { Top = C(255, 112, 186), Glow = C(255, 160, 214), Shade = C(150, 50, 106), Strip = C(226, 64, 146), Text = C(255, 228, 92), Word = C(255, 214, 52) },
	Owned = { Top = C(72, 150, 255), Glow = C(140, 196, 255), Shade = C(30, 66, 152), Strip = C(40, 96, 210), Text = C(150, 205, 255), Word = C(110, 180, 255) },
	Equipped = { Top = C(64, 220, 104), Glow = C(150, 250, 172), Shade = C(20, 112, 50), Strip = C(26, 156, 64), Text = C(120, 255, 150), Word = C(92, 242, 122) },
}

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
