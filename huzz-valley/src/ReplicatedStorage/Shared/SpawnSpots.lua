--[[
	Where a body may be put down (owner, Oct 19: "fix the spawn point locations ... make them spawn not in the middle
	inside of objects and just make them spawn on open ground"; "make catchers spawn in the middle").

	A spot is open ground when:
	  - there is floor under it, and under four points round it (1.5 studs out) at the same height (within MaxStep):
	    no edge, hole, step or slope under the feet;
	  - nothing at all is in a standing body's box (Body, from Lift over the floor): nothing solid and nothing you
	    can see (a see-through prop you'd stand inside still looks wrong);
	  - nothing solid in the box round it (Room): room to walk off in any direction.
	Every place the game puts a body uses it (MapService: the lobby's spawn pad, the start lines, the catchers in the
	middle, the bench, the Practice Bot), and tests/Spawns.spec.luau runs the same rules over the owner's real place.

	Pure: the world is read through `api`, so the game (Roblox: GetPartBoundsInBox and a ray, MapService) and the
	offline check (Lune: tools/world/geometry.luau, the same box test over his place's parts) agree:
	  api.floor(x, z, top, bottom) -> y?    the highest solid surface under (x, z) between top and bottom
	  api.blocked(centre, size, solidOnly) -> boolean
	                                        an upright box (no turn) touches a part's bounding box that is solid
	                                        (or, unless solidOnly, that you can see)
]]
local SpawnSpots = {}

SpawnSpots.Body = Vector3.new(4, 5.4, 4) -- a standing avatar, shoulders and arms (any way it faces)
SpawnSpots.Room = Vector3.new(6, 4.6, 6) -- nothing solid within 3 studs each way: room to move
SpawnSpots.Lift = 0.4 -- the boxes start this far over the floor (the floor itself never counts)
SpawnSpots.Foot = 1.5 -- the four floor points round the spot
SpawnSpots.MaxStep = 0.8 -- floor points within this of each other
SpawnSpots.RootHeight = 3.2 -- a standing root part over the floor (as MapService always put bodies down)

-- Is (x, z) open ground near height nearY? Returns ok, the floor's height, and why not.
function SpawnSpots.check(api, x: number, z: number, nearY: number): (boolean, number?, string?)
	local y = api.floor(x, z, nearY + 4, nearY - 6)
	if not y then
		return false, nil, "no floor"
	end
	local f = SpawnSpots.Foot
	for _, o in { { f, f }, { -f, f }, { f, -f }, { -f, -f } } do
		local y2 = api.floor(x + o[1], z + o[2], y + 2, y - 3)
		if not y2 or math.abs(y2 - y) > SpawnSpots.MaxStep then
			return false, y, "edge"
		end
	end
	local body, room = SpawnSpots.Body, SpawnSpots.Room
	if api.blocked(Vector3.new(x, y + SpawnSpots.Lift + body.Y / 2, z), body, false) then
		return false, y, "inside something"
	end
	if api.blocked(Vector3.new(x, y + SpawnSpots.Lift + room.Y / 2, z), room, true) then
		return false, y, "no room"
	end
	return true, y, nil
end

--[[ The open spot nearest (x, z): the point itself, else rings round it (`step` apart, up to `radius`), each ring
	tried in the same order every time. `keep(x, z)` (optional) can refuse points (outside a zone, too close to
	another spot). Returns the spot on the floor (Vector3) or nil. ]]
function SpawnSpots.near(api, x: number, z: number, nearY: number, radius: number, step: number?, keep: ((number, number) -> boolean)?): Vector3?
	step = step or 1
	local function try(px, pz)
		if keep and not keep(px, pz) then return nil end
		local ok, y = SpawnSpots.check(api, px, pz, nearY)
		return if ok and y then Vector3.new(px, y, pz) else nil
	end
	local hit = try(x, z)
	if hit then return hit end
	local r = step :: number
	while r <= radius + 1e-6 do
		local n = math.max(6, math.ceil(2 * math.pi * r / (step :: number)))
		for k = 0, n - 1 do
			local a = 2 * math.pi * k / n
			hit = try(x + math.cos(a) * r, z + math.sin(a) * r)
			if hit then return hit end
		end
		r += step :: number
	end
	return nil
end

--[[ Up to `count` open spots for a group, nearest the wanted points first. `wanted` is a list of {x, z} in the
	order to fill; each one moves to the nearest open point within `jiggle` studs, never closer than `gap` to a spot
	already taken. Points that find nothing are skipped (the caller passes more points than it needs). ]]
function SpawnSpots.fill(api, wanted: { { number } }, nearY: number, count: number, gap: number, jiggle: number, keep: ((number, number) -> boolean)?): { Vector3 }
	local out = {}
	local function apart(px, pz)
		if keep and not keep(px, pz) then return false end
		for _, s in out do
			local dx, dz = s.X - px, s.Z - pz
			if dx * dx + dz * dz < gap * gap - 1e-6 then return false end
		end
		return true
	end
	for _, w in wanted do
		if #out >= count then break end
		local hit = SpawnSpots.near(api, w[1], w[2], nearY, jiggle, 0.5, apart)
		if hit then table.insert(out, hit) end
	end
	return out
end

return SpawnSpots
