--!strict
-- Pure helpers for homes (no Instances; unit-tested in tools/tests/test_flat_rules.py).
local Property = require(script.Parent.Parent.Config.Property)
local StoryRules = require(script.Parent.StoryRules)

local PropertyRules = {}

function PropertyRules.home(id: any): any?
	return if type(id) == "string" then (Property.Homes :: any)[id] else nil
end

function PropertyRules.owns(d: any, id: string): boolean
	return d.Home ~= nil and type(d.Home.Owned) == "table" and d.Home.Owned[id] ~= nil
end

function PropertyRules.ownsAny(d: any): boolean
	return d.Home ~= nil and type(d.Home.Owned) == "table" and next(d.Home.Owned) ~= nil
end

-- May this player buy home `id` now? -> ok, reason?, shortfall (cash still needed, 0 when enough)
function PropertyRules.canBuy(d: any, id: string): (boolean, string?, number)
	local h = PropertyRules.home(id)
	if not h then
		return false, "Not for sale", 0
	end
	if PropertyRules.owns(d, id) then
		return false, "You already own this place", 0
	end
	if not StoryRules.reached(d.Story.Stage, "FindAPlace") then
		return false, "Not for sale yet", 0
	end
	local short = math.max(0, h.price - (d.Cash or 0))
	if short > 0 then
		return false, "Not enough cash", short
	end
	return true, nil, 0
end

-- Slot i (1-based) -> the room's world origin (Vector3; the room faces -Z).
function PropertyRules.slotOrigin(i: number): Vector3
	local s = Property.Slots
	return s.Origin + Vector3.new((i - 1) * s.Spacing, 0, 0)
end

-- The lowest free slot index (taken[i] = true), or nil when every slot is used.
function PropertyRules.freeSlot(taken: { [number]: boolean }): number?
	for i = 1, Property.Slots.Max do
		if not taken[i] then
			return i
		end
	end
	return nil
end

-- Is a world point inside a room whose origin is `origin`? (generous box around the room)
function PropertyRules.insideRoom(origin: Vector3, p: Vector3): boolean
	local size = Property.Interior.Size
	local d = p - origin
	return math.abs(d.X) <= size.X / 2 + 6 and math.abs(d.Z) <= size.Z / 2 + 6 and d.Y > -8 and d.Y < size.Y + 8
end

-- Story stages where a returning player wakes up inside their home (first spawn of the session).
PropertyRules.HomeSpawnFrom = "MoveIn"
function PropertyRules.spawnsAtHome(d: any): boolean
	return PropertyRules.ownsAny(d) and StoryRules.reached(d.Story.Stage, PropertyRules.HomeSpawnFrom)
end

-- What the outside door prompt says for this player.
function PropertyRules.doorText(d: any, id: string): string
	local h = PropertyRules.home(id)
	if not h then
		return "Door"
	end
	if PropertyRules.owns(d, id) then
		return "Go inside"
	end
	return "For sale · $" .. tostring(h.price)
end

return PropertyRules
