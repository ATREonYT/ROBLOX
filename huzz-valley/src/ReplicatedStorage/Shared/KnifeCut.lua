--[[
	Builds the plain cut of one of his 30 knives on this screen (owner, Oct 20 15:13: "make it so that the knifes also
	appear inside of the actual roblox game"): Gameplay/KnifeMeshCheck calls it only on a copy whose uploaded meshes
	don't load here, from the knife's baked rows (ServerStorage/HuzzKnifeBackups/<Key>, tools/knives/bake_stand_ins.py,
	fetched once a knife by remote KnifeBackup). Nothing is in the copy otherwise, so nothing extra replicates.
	Rows: { name, size x, y, z, centre x, y, z, colour (rrggbb), material, Reflectance, then optionally a turn about X and "W" for a wedge } in the
	Handle's space (+Y to the tip, X the blade's thin way, Z its width); the "Handle" row is skipped (his Handle holds
	it). Each part: KnifeBackup<n> in a Folder "KnifeBackup", touching nothing, no shadow, held on his Handle by a Weld
	(C0 = its place) and placed there now (a ViewportFrame copy has no physics to move it).
	Some of his imports sit half a turn round about the Handle's length (Solar Reaper's blade curves the other way):
	turned() says whether to turn the cut with them, from which way its width lines up with his parts.
]]
local KnifeCut = {}

KnifeCut.FOLDER = "KnifeBackup"

local MATERIAL = { Metal = "Metal", Neon = "Neon", Plastic = "Plastic", SmoothPlastic = "SmoothPlastic", Glass = "Glass", Fabric = "Fabric" }

local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16) or 0, tonumber(string.sub(h, 3, 4), 16) or 0, tonumber(string.sub(h, 5, 6), 16) or 0)
end

-- Each row's place in the Handle's space.
local function placeOf(r): CFrame
	return CFrame.new(r[5], r[6], r[7]) * CFrame.Angles(math.rad(r[11] or 0), 0, 0)
end

-- How far parts reach across (the Handle's Z): lo, hi. items: { { cf (Handle space), size } }.
local function across(items): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, it in items do
		local r, h = it.cf, it.size / 2
		local e = math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z
		lo, hi = math.min(lo, r.Position.Z - e), math.max(hi, r.Position.Z + e)
	end
	return lo, hi
end

-- True when his parts (BaseParts other than the Handle) line up with the cut turned half round.
function KnifeCut.turned(baked, handle: BasePart, his: { BasePart }): boolean
	local a, b = {}, {}
	for _, p in his do
		table.insert(a, { cf = handle.CFrame:ToObjectSpace(p.CFrame), size = p.Size })
	end
	for _, r in baked.parts do
		if r[1] ~= "Handle" then table.insert(b, { cf = placeOf(r), size = Vector3.new(r[2], r[3], r[4]) }) end
	end
	if #a == 0 or #b == 0 then return false end
	local hlo, hhi = across(a)
	local clo, chi = across(b)
	return math.abs(hlo + chi) + math.abs(hhi + clo) < math.abs(hlo - clo) + math.abs(hhi - chi)
end

-- The cut, in a Folder "KnifeBackup" parented to the copy, welded to its Handle. Returns the folder.
function KnifeCut.build(baked, model: Instance, handle: BasePart, turn: boolean?): Folder
	local folder = Instance.new("Folder")
	folder.Name = KnifeCut.FOLDER
	local half = if turn then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local n = 0
	for _, r in baked.parts do
		if r[1] ~= "Handle" then
			n += 1
			local p = Instance.new(if r[12] == "W" then "WedgePart" else "Part")
			p.Name = KnifeCut.FOLDER .. n
			p.Size = Vector3.new(r[2], r[3], r[4])
			p.Color = hex(r[8])
			p.Material = (Enum.Material :: any)[MATERIAL[r[9]] or "SmoothPlastic"]
			p.Reflectance = r[10] or 0
			if r[9] == "Glass" then p.Transparency = 0.12 end
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
			local at = half * placeOf(r)
			p.CFrame = handle.CFrame * at
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = handle, p, at
			w.Parent = p
			p.Parent = folder
		end
	end
	folder.Parent = model
	return folder
end

return KnifeCut
