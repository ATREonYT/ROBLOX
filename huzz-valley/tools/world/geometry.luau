--[[
	The world as Shared/SpawnSpots and MapService read it, for Lune (no Roblox physics offline): every part of a
	place as its box, in 16-stud cells.
	  floor(x, z, top, bottom) -> y?, part   a straight-down ray from top: the first solid (CanCollide) part's
	                                          surface at or above bottom (the part's real turned box, like a ray)
	  blocked(centre, size, solidOnly) -> bool, part
	                                          an upright box against each part's bounding box (as Roblox's
	                                          GetPartBoundsInBox): solid = CanCollide in the Default group, else
	                                          (unless solidOnly) any part you can see (Transparency < 0.9)
	Used by tests/Spawns.spec.luau, tools/check_maps.luau and the spawn plan picture.
	Geometry.new(list, opts): list of BaseParts (or a root to search); opts.skip(part) -> true leaves one out.
]]
local Vector3 = require("@lune/roblox").Vector3
local Geometry = {}

local CELL = 16

local function boxOf(p)
	local cf, s = p.CFrame, p.Size
	local pos = cf.Position
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2
	local hy = math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2
	local hz = math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	return pos.X - hx, pos.Y - hy, pos.Z - hz, pos.X + hx, pos.Y + hy, pos.Z + hz
end

function Geometry.new(list, opts)
	opts = opts or {}
	local parts = {}
	if typeof(list) == "Instance" then
		local found = {}
		for _, d in list:GetDescendants() do
			if d:IsA("BasePart") and not d:IsA("Terrain") then table.insert(found, d) end
		end
		list = found
	end
	local cells = {}
	local function cellKey(i, j) return i * 100003 + j end
	for _, p in list do
		if not (opts.skip and opts.skip(p)) then
			local x0, y0, z0, x1, y1, z1 = boxOf(p)
			local group = "Default"
			pcall(function() group = p.CollisionGroup end)
			local rec = {
				part = p, x0 = x0, y0 = y0, z0 = z0, x1 = x1, y1 = y1, z1 = z1,
				solid = p.CanCollide and (group == "Default" or group == ""), collide = p.CanCollide,
				visible = p.Transparency < 0.9, cf = p.CFrame, half = p.Size / 2,
			}
			table.insert(parts, rec)
			for i = math.floor(x0 / CELL), math.floor(x1 / CELL) do
				for j = math.floor(z0 / CELL), math.floor(z1 / CELL) do
					local k = cellKey(i, j)
					cells[k] = cells[k] or {}
					table.insert(cells[k], rec)
				end
			end
		end
	end
	local self = { parts = parts }

	local function around(x0, z0, x1, z1)
		local seen, out = {}, {}
		for i = math.floor(x0 / CELL), math.floor(x1 / CELL) do
			for j = math.floor(z0 / CELL), math.floor(z1 / CELL) do
				for _, rec in cells[cellKey(i, j)] or {} do
					if not seen[rec] then
						seen[rec] = true
						table.insert(out, rec)
					end
				end
			end
		end
		return out
	end

	-- The ray straight down through one part's turned box: the entry height, or nil.
	local function hitTop(rec, x, z, top)
		local cf, h = rec.cf, rec.half
		local o = cf:PointToObjectSpace(Vector3.new(x, top, z))
		local d = cf:VectorToObjectSpace(Vector3.new(0, -1, 0))
		local tmin, tmax = -math.huge, math.huge
		for _, ax in { "X", "Y", "Z" } do
			local oa, da, ha = o[ax], d[ax], h[ax]
			if math.abs(da) < 1e-9 then
				if oa < -ha or oa > ha then return nil end
			else
				local t1, t2 = (-ha - oa) / da, (ha - oa) / da
				if t1 > t2 then t1, t2 = t2, t1 end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then return nil end
			end
		end
		if tmax < 0 then return nil end
		return top - math.max(tmin, 0)
	end

	function self.floor(x, z, top, bottom)
		local best, bestPart = nil, nil
		for _, rec in around(x, z, x, z) do
			if rec.collide and x >= rec.x0 and x <= rec.x1 and z >= rec.z0 and z <= rec.z1 and rec.y0 <= top and rec.y1 >= bottom then
				local y = hitTop(rec, x, z, top)
				if y and y >= bottom and y <= top and (not best or y > best) then best, bestPart = y, rec.part end
			end
		end
		return best, bestPart
	end

	function self.blocked(centre, size, solidOnly)
		local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
		local x0, y0, z0, x1, y1, z1 = centre.X - hx, centre.Y - hy, centre.Z - hz, centre.X + hx, centre.Y + hy, centre.Z + hz
		for _, rec in around(x0, z0, x1, z1) do
			if (rec.solid or (not solidOnly and rec.visible))
				and rec.x0 < x1 and rec.x1 > x0 and rec.y0 < y1 and rec.y1 > y0 and rec.z0 < z1 and rec.z1 > z0 then
				return true, rec.part
			end
		end
		return false, nil
	end

	return self
end

return Geometry
