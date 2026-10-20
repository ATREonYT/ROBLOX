--[[
	Stand-in models for the five Game Pass knives and his 18 Halloween knives, built from plain parts until the owner
	imports his own (design/knives/gamepass/Gamepass_Knives.glb, design/knives/halloween/Halloween_Knives.glb + the knife
	setup: docs/notes/knives.md, "Owner how-to"), and
	wherever a screen can't draw his model (Gameplay/KnifeDress needs Roblox's EditableMesh: in the live game only
	with Game Settings > Security > "Allow Mesh / Image APIs").
	Owner, Oct 19, his Studio screenshot of the lobby stands: the first hand-made stand-ins (an orange blocky jagged
	blade, a small cyan stub) were nothing like his model. Now each one is cut from his own .glb
	(Shared/KnifeStandIns, one module a knife in Shared/KnifeStandInParts, baked by tools/knives/bake_stand_ins.py):
	each of his looks seen from the side, its outline filled solid and cut into triangles, each triangle two wedges
	turned about the blade's thin axis (Oct 20, owner: "please fix the knifes finally, they are still missing pixels,
	and please just make them be normal": the Oct 19 cut, thin slices of blocks, read as scattered bits), so the
	outline is his (the moon hole, the teeth, the spikes, the feathers), solid, in his colours and the Roblox material
	nearest his (Shared/KnifeLook.glbMaterial), at his real length.
	Pure data (HuzzServer/KnifeService builds them; tests/KnifeShapes.spec checks each against its baked length).
	Space: the Handle's (+Y to the tip, X the blade's thin way, Z its width), studs. Each part: name, kind (Block or
	Wedge), size, at, rot (degrees about X, Y, Z; only X here), paint (a key of the knife's palette: his colour), mat (Enum.Material name), refl (Reflectance), hidden
	(the tiny Handle at the grip's middle). trail: where the slash trail runs from and to (y).
	fromBaked turns one baked module into a recipe (HuzzServer/KnifeService also uses it for his 30 knives' hidden
	backups in ServerStorage/HuzzKnifeBackups, baked the same way: shown only where his uploaded meshes don't load).
]]
local KnifeShapes = {}

local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end

-- One baked module ({ trail, parts = rows }, tools/knives/bake_stand_ins.py) as a recipe.
function KnifeShapes.fromBaked(baked)
	local palette, parts = {}, {}
	for _, r in baked.parts do -- { name, size x, y, z, centre x, y, z, colour, material, Reflectance[, turn about X[, "W"]] }
		local col = r[8]
		palette[col] = palette[col] or hex(col)
		table.insert(parts, { name = r[1], kind = if r[12] == "W" then "Wedge" else "Block", size = { r[2], r[3], r[4] },
			at = { r[5], r[6], r[7] }, rot = if r[11] then { r[11], 0, 0 } else nil, paint = col,
			mat = r[9], refl = r[10], hidden = r[1] == "Handle" })
	end
	return { palette = palette, parts = parts, trail = baked.trail }
end

KnifeShapes.RECIPES = {}
for key, baked in require(script.Parent.KnifeStandIns) do
	KnifeShapes.RECIPES[key] = KnifeShapes.fromBaked(baked)
end

function KnifeShapes.get(key: string?)
	return key and KnifeShapes.RECIPES[key] or nil
end

return KnifeShapes
