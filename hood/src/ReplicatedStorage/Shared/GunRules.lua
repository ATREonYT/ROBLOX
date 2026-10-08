--!strict
-- Buy and equip rules for the ARMORY. Pure functions over a profile's Guns table ({Owned={[id]=true}, Equipped=id}),
-- so GunService (which enforces them), the armory client (which only labels prompts and paints pedestals with
-- them) and the unit tests all agree. No Instances in here.
local Guns = require(script.Parent.Config.Guns)
local Format = require(script.Parent.Format)

local GunRules = {}
GunRules.Range = 14 -- how close (studs) you must stand to a gun's pedestal point to buy or equip it

-- Pedestal colours per state, shared by the map builder (first paint) and the client (repaints): one hue per
-- state in three tones plus a soft neon (rose locked, blue owned, green equipped; Brief 8 volume). Top = the
-- main tone (pad top, plate back), Base = dark (base, bevel, window border), Rim = light (pad rim), Panel = the
-- display board's window, Glow = the neon face and light (GlowAlpha its transparency: brighter as you own and
-- equip), Strip = the plate face, Text = the price row.
local C = Color3.fromRGB
GunRules.Colors = {
	Locked = { Top = C(214, 104, 150), Base = C(139, 62, 95), Rim = C(239, 191, 211), Panel = C(220, 140, 172),
		Glow = C(236, 124, 174), GlowAlpha = 0.3, Strip = C(150, 58, 98), Text = C(255, 224, 110) },
	Owned = { Top = C(70, 134, 222), Base = C(57, 92, 138), Rim = C(204, 221, 242), Panel = C(124, 166, 226),
		Glow = C(120, 170, 236), GlowAlpha = 0.2, Strip = C(54, 90, 150), Text = C(170, 210, 255) },
	Equipped = { Top = C(56, 186, 100), Base = C(46, 117, 68), Rim = C(199, 233, 209), Panel = C(112, 202, 140),
		Glow = C(104, 210, 138), GlowAlpha = 0.1, Strip = C(40, 124, 66), Text = C(150, 240, 170) },
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
