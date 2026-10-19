--[[
	Stand-in models for the five Game Pass knives, built from plain parts until the owner imports his own
	(design/knives/gamepass/Gamepass_Knives.glb + the knife setup: section "Knives" of huzz-valley/CLAUDE.md), and
	wherever a screen can't draw his model (Gameplay/KnifeDress needs Roblox's EditableMesh: in the live game only
	with Game Settings > Security > "Allow Mesh / Image APIs").
	Owner, Oct 19, his Studio screenshot of the lobby stands: the first hand-made stand-ins (an orange blocky jagged
	blade, a small cyan stub) were nothing like his model. Now each one is cut from his own .glb
	(Shared/KnifeStandIns, baked by tools/knives/bake_stand_ins.py): thin slices across the knife, one block per
	stretch of each of his looks, so the outline follows his (the moon hole, the teeth, the spikes, the feathers), in
	his colours and the Roblox material nearest his (Shared/KnifeLook.glbMaterial), at his real length.
	Pure data (HuzzServer/KnifeService builds them; tests/KnifeShapes.spec checks each against its baked length).
	Space: the Handle's (+Y to the tip, X the blade's thin way, Z its width), studs. Each part: name, kind (Block),
	size, at, paint (a key of the knife's palette: his colour), mat (Enum.Material name), refl (Reflectance), hidden
	(the tiny Handle at the grip's middle). trail: where the slash trail runs from and to (y).
]]
local KnifeShapes = {}

local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end

KnifeShapes.RECIPES = {}
for key, baked in require(script.Parent.KnifeStandIns) do
	local palette, parts = {}, {}
	for _, r in baked.parts do -- { name, size x, y, z, centre x, y, z, colour, material, Reflectance }
		local col = r[8]
		palette[col] = palette[col] or hex(col)
		table.insert(parts, { name = r[1], kind = "Block", size = { r[2], r[3], r[4] }, at = { r[5], r[6], r[7] }, paint = col,
			mat = r[9], refl = r[10], hidden = r[1] == "Handle" })
	end
	KnifeShapes.RECIPES[key] = { palette = palette, parts = parts, trail = baked.trail }
end

function KnifeShapes.get(key: string?)
	return key and KnifeShapes.RECIPES[key] or nil
end

return KnifeShapes
