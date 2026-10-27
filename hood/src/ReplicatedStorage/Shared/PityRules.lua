--!strict
-- The pity counters (brief 30, PITY): a VISIBLE guarantee for players who keep opening. It replaces the idea of hidden
-- boosted odds, which this game does not do: the odds a box shows are always its real odds, and the guarantee is a
-- rule printed on the screen with a counter that counts down where you can see it.
--   Shoe boxes   every open of a box that is not Epic or better counts up that box's own counter. The Nth open since the
--                last Epic+ is GUARANTEED Epic or better (it rolls among the box's Epic+ entries by their own relative
--                weights, so the shown per-open odds stay true), then the counter resets. Hitting Epic+ naturally resets
--                it too. Each box has its own counter; a multi-open (x3, x8, Auto) counts its boxes one after the other.
--   Spin wheel   the same for the wheel's best prize (Wedges): every spin that is not one of them counts up, the Nth spin
--                since the last one is guaranteed to land on one (among them by their own weights).
-- "Every = 10" means: at most 9 opens without Epic+, then the 10th is the guaranteed one. A fresh counter shows
-- "Epic+ guaranteed in 10 opens"; after 9 misses it shows "on your next open".
-- Saved in the profile as Pity = { Boxes = { [boxId] = opens without Epic+, 1..Every-1 (0 is never stored) }, Wheel =
-- spins without the big prize, 0..Every-1 }; a profile from before it has none, which means 0 everywhere (sanitize).
-- Pure rules over that table (no Instances), so HoodServer/ShoeOpening and HudExtras (which enforce them), the clients
-- (which only show them) and the unit tests all agree. The client never decides: it reads the ShoePity attribute the
-- server keeps in step with the profile.
local Shoes = require(script.Parent.Config.Shoes)

local Pity = {}

-- THE config (one table): opens without Epic+ before the guaranteed one, per kind of box, and the lowest rank that
-- counts as a result (3 = Epic).
Pity.Boxes = { Cash = 10, Robux = 8, MinRank = 3 }
-- The wheel: spins until the guaranteed big prize, and the wedges (HudExtrasRules.Wedges ids) that are the big prize.
Pity.Wheel = { Every = 15, Wedges = { 'Jackpot' } }

local function whole(v: any): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return 0 end
	return math.max(0, math.floor(v))
end

---------------------------------------------------------------------------------------------- boxes
-- The lowest rank that ends a streak (3: Epic) and its name ("Epic").
function Pity.minRank(): number
	return Pity.Boxes.MinRank
end
function Pity.rarityName(): string
	local r = Shoes.Rarities[Pity.Boxes.MinRank]
	return r and r.Name or 'Epic'
end

-- Opens of this box until its guaranteed one when the counter is 0 (nil for an unknown box).
function Pity.boxEvery(boxId: any): number?
	local box = type(boxId) == 'string' and Shoes.BoxById[boxId]
	if not box then return nil end
	return box.Robux and Pity.Boxes.Robux or Pity.Boxes.Cash
end

-- A clean Pity table from anything (a missing or damaged one is 0 everywhere; unknown boxes are dropped; a count is a
-- whole number from 1 to Every - 1, and 0 is not stored). Returns a NEW table: callers assign it back.
function Pity.sanitize(t: any): { Boxes: { [string]: number }, Wheel: number }
	local out = { Boxes = {} :: { [string]: number }, Wheel = 0 }
	if type(t) ~= 'table' then return out end
	if type(t.Boxes) == 'table' then
		for id, n in t.Boxes do
			local every = Pity.boxEvery(id)
			local count = whole(n)
			if every and count > 0 then out.Boxes[id] = math.min(count, every - 1) end
		end
	end
	out.Wheel = math.min(whole(t.Wheel), Pity.Wheel.Every - 1)
	return out
end

-- Opens of this box without Epic+ so far.
function Pity.count(pity: any, boxId: any): number
	local every = Pity.boxEvery(boxId)
	if not every or type(pity) ~= 'table' or type(pity.Boxes) ~= 'table' then return 0 end
	return math.min(whole(pity.Boxes[boxId]), every - 1)
end
-- Opens until the guaranteed one: 1 = the NEXT open is guaranteed, Every on a fresh counter (0 for an unknown box).
function Pity.left(pity: any, boxId: any): number
	local every = Pity.boxEvery(boxId)
	if not every then return 0 end
	return every - Pity.count(pity, boxId)
end
-- THE call for a UI: opens left until this box's guaranteed Epic+ (1 = the next open, 10 / 8 on a fresh counter). `counters`
-- is whatever the caller holds: the profile's Pity table ({ Boxes = { [boxId] = n } }), the boxes map alone ({ [boxId] = n }),
-- the ShoePity attribute string ('Street:3,Graffiti:7'), or nil (nothing counted yet). 0 for an unknown box.
function Pity.remaining(counters: any, boxId: any): number
	if type(counters) == 'string' then
		counters = Pity.decode(counters)
	elseif type(counters) == 'table' and type(counters.Boxes) ~= 'table' then
		counters = { Boxes = counters }
	end
	return Pity.left(counters, boxId)
end
-- Is the next open of this box the guaranteed one?
function Pity.due(pity: any, boxId: any): boolean
	local every = Pity.boxEvery(boxId)
	return every ~= nil and Pity.left(pity, boxId) <= 1
end
-- An open of this box gave a shoe of rank `rank`: Epic+ resets the counter, anything else counts up. Returns whether it
-- reset. (The caller asks Pity.due BEFORE the roll to know whether that roll was the guaranteed one.)
function Pity.record(pity: any, boxId: any, rank: any): boolean
	local every = Pity.boxEvery(boxId)
	if not every or type(pity) ~= 'table' then return false end
	if type(pity.Boxes) ~= 'table' then pity.Boxes = {} end
	if type(rank) == 'number' and rank >= Pity.Boxes.MinRank then
		pity.Boxes[boxId] = nil
		return true
	end
	pity.Boxes[boxId] = math.min(Pity.count(pity, boxId) + 1, every - 1)
	return false
end

-- The line the box panels and the odds board show, for Pity.remaining's number: "Epic+ guaranteed in 7 opens" ("... on your
-- next open!" at 1 left).
function Pity.boxLine(left: any): string
	local n = math.max(1, whole(left))
	local name = Pity.rarityName() .. '+ guaranteed'
	if n <= 1 then return name .. ' on your next open!' end
	return name .. ' in ' .. n .. ' opens'
end

-- The counters as the ShoePity attribute ('Street:3,Graffiti:7' in the boxes' order, '' when every counter is 0) and back.
function Pity.encode(pity: any): string
	local parts = {}
	local boxes = type(pity) == 'table' and type(pity.Boxes) == 'table' and pity.Boxes or {}
	for _, box in Shoes.Boxes do
		local n = Pity.count({ Boxes = boxes }, box.Id)
		if n > 0 then table.insert(parts, box.Id .. ':' .. n) end
	end
	return table.concat(parts, ',')
end
function Pity.decode(text: any): { Boxes: { [string]: number }, Wheel: number }
	local boxes = {}
	for id, n in string.gmatch(type(text) == 'string' and text or '', '([^,:]+):(%d+)') do boxes[id] = tonumber(n) end
	return Pity.sanitize({ Boxes = boxes })
end

---------------------------------------------------------------------------------------------- the wheel
function Pity.wheelCount(pity: any): number
	if type(pity) ~= 'table' then return 0 end
	return math.min(whole(pity.Wheel), Pity.Wheel.Every - 1)
end
-- Spins until the guaranteed big prize: 1 = the NEXT spin, Every on a fresh counter.
function Pity.wheelLeft(pity: any): number
	return Pity.Wheel.Every - Pity.wheelCount(pity)
end
function Pity.wheelDue(pity: any): boolean
	return Pity.wheelLeft(pity) <= 1
end
function Pity.isBigPrize(wedgeId: any): boolean
	return type(wedgeId) == 'string' and table.find(Pity.Wheel.Wedges, wedgeId) ~= nil
end
-- A spin landed on wedge `wedgeId`: the big prize resets the counter, anything else counts up. Returns whether it reset.
function Pity.wheelRecord(pity: any, wedgeId: any): boolean
	if type(pity) ~= 'table' then return false end
	if Pity.isBigPrize(wedgeId) then
		pity.Wheel = 0
		return true
	end
	pity.Wheel = math.min(Pity.wheelCount(pity) + 1, Pity.Wheel.Every - 1)
	return false
end
-- "Big prize guaranteed in 12 spins" ("... on your next spin!" at 1 left).
function Pity.wheelLine(left: any): string
	local n = math.max(1, whole(left))
	if n <= 1 then return 'Big prize guaranteed on your next spin!' end
	return 'Big prize guaranteed in ' .. n .. ' spins'
end

return Pity
