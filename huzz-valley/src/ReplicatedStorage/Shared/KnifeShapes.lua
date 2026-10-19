--[[
	Stand-in models for the five Game Pass knives, built from plain parts until the owner imports his own
	(design/knives/gamepass/Gamepass_Knives.glb + the knife setup: section "Knives" of huzz-valley/CLAUDE.md).
	Owner, Oct 19: "right now its very small and you dont even notice it": before this every pass knife without a
	model showed our 1.9 stud dagger in its colours. Now each one has its card's shape (design/knives/
	Five_Elemental_Knife_Cards.png) at its real length (about 3.2 studs, tools/knives/knives.json), with its glowing
	edge in Neon:
	  CrimsonRequiem   a crimson katana: a glowing red edge, gold guard, white-wrapped grip and a red tassel;
	  HollowEclipse    a huge black cleaver with a moon hole near the top and a pale glowing outline;
	  CelestialSeraph  a silver longsword with a glowing blue line down the middle and a guard of white feathers;
	  DragonsMaw       a dark jagged blade with glowing orange cracks and edge, a green guard with a red stone;
	  FrostboundOath   an icy blade with a glowing cyan core and crystal spikes off its edges.
	Pure data (HuzzServer/KnifeService builds them; tests/KnifeShapes.spec checks each against its baked length).
	Space: the Handle's (+Y to the tip, X the blade's thin way, Z its width), studs. Each part: name, kind (Block,
	Wedge: tall edge at +Z, Cylinder: round along X), size, at, rot (degrees, optional), paint (a key of the knife's
	palette) and mat (Metal, Neon, Plastic, Glass, Fabric). The Handle is the grip (the fist closes on its middle).
	trail: where the slash trail runs from and to (y).
]]
local KnifeShapes = {}

local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end

-- a point at the tip made of two wedges (symmetric), its base at y, width w, thickness t, height h
local function point(name, y, w, t, h, paint, mat, z)
	z = z or 0
	return {
		{ name = name .. "A", kind = "Wedge", size = { t, h, w / 2 }, at = { 0, y + h / 2, z + w / 4 }, rot = { 0, 180, 0 }, paint = paint, mat = mat },
		{ name = name .. "B", kind = "Wedge", size = { t, h, w / 2 }, at = { 0, y + h / 2, z - w / 4 }, paint = paint, mat = mat },
	}
end

local function bands(list, y0, y1, n, size, paint)
	for i = 0, n - 1 do
		local y = y0 + (y1 - y0) * (i + 0.5) / n
		table.insert(list, { name = "Wrap" .. (i + 1), kind = "Block", size = size, at = { 0, y, 0 }, rot = { 0, 0, 0 }, paint = paint, mat = "Fabric" })
	end
end

local function join(...)
	local out = {}
	for _, l in { ... } do
		for _, p in l do table.insert(out, p) end
	end
	return out
end

KnifeShapes.RECIPES = {}

-- Hunter Knife: a crimson katana
do
	local p = {
		{ name = "Handle", kind = "Block", size = { 0.2, 0.95, 0.24 }, at = { 0, 0, 0 }, paint = "dark", mat = "Plastic" },
		{ name = "Pommel", kind = "Block", size = { 0.22, 0.1, 0.28 }, at = { 0, -0.52, 0 }, paint = "gold", mat = "Metal" },
		{ name = "Guard", kind = "Cylinder", size = { 0.08, 0.56, 0.56 }, at = { 0, 0.52, 0 }, rot = { 0, 0, 90 }, paint = "gold", mat = "Metal" },
		{ name = "Collar", kind = "Block", size = { 0.2, 0.12, 0.28 }, at = { 0, 0.62, 0 }, paint = "gold", mat = "Metal" },
		{ name = "Blade", kind = "Block", size = { 0.07, 1.86, 0.26 }, at = { 0, 1.61, 0.03 }, paint = "blade", mat = "Metal" },
		{ name = "BladeEdge", kind = "Block", size = { 0.05, 1.86, 0.07 }, at = { 0, 1.61, -0.13 }, paint = "glow", mat = "Neon" },
		{ name = "Tassel", kind = "Block", size = { 0.07, 0.32, 0.07 }, at = { 0, -0.74, 0 }, paint = "accent", mat = "Fabric" },
	}
	local wraps = {}
	bands(wraps, -0.42, 0.42, 4, { 0.22, 0.06, 0.26 }, "white")
	KnifeShapes.RECIPES.CrimsonRequiem = {
		palette = { dark = hex("1c1014"), gold = hex("e8b830"), blade = hex("8a2a38"), glow = hex("ff3344"), accent = hex("c8142a"), white = hex("f2ece8") },
		parts = join(p, wraps, {
			{ name = "BladeTip", kind = "Wedge", size = { 0.07, 0.42, 0.33 }, at = { 0, 2.75, -0.005 }, paint = "blade", mat = "Metal" },
		}),
		trail = { 0.6, 2.9 },
	}
end

-- Moonlit Knife: a huge black cleaver with a moon hole
do
	local p = {
		{ name = "Handle", kind = "Block", size = { 0.2, 0.9, 0.22 }, at = { 0, 0, 0 }, paint = "dark", mat = "Plastic" },
		{ name = "Pommel", kind = "Cylinder", size = { 0.22, 0.24, 0.24 }, at = { 0, -0.52, 0 }, paint = "silver", mat = "Metal" },
		{ name = "Guard", kind = "Block", size = { 0.26, 0.12, 0.62 }, at = { 0, 0.5, 0.08 }, paint = "dark", mat = "Metal" },
		{ name = "Blade", kind = "Block", size = { 0.09, 2.0, 0.72 }, at = { 0, 1.58, 0.1 }, paint = "blade", mat = "Metal" },
		{ name = "BladeEdge", kind = "Block", size = { 0.1, 2.0, 0.05 }, at = { 0, 1.58, -0.285 }, paint = "glow", mat = "Neon" },
		{ name = "BladeSpine", kind = "Block", size = { 0.1, 2.0, 0.05 }, at = { 0, 1.58, 0.485 }, paint = "glow", mat = "Neon" },
		{ name = "BladeTop", kind = "Block", size = { 0.1, 0.05, 0.82 }, at = { 0, 2.6, 0.1 }, paint = "glow", mat = "Neon" },
		{ name = "MoonRing", kind = "Cylinder", size = { 0.1, 0.32, 0.32 }, at = { 0, 2.28, 0.14 }, paint = "glow", mat = "Neon" },
		{ name = "MoonHole", kind = "Cylinder", size = { 0.12, 0.22, 0.22 }, at = { 0, 2.28, 0.14 }, paint = "hole", mat = "Plastic" },
		{ name = "Rune", kind = "Block", size = { 0.1, 0.22, 0.03 }, at = { 0, 1.2, 0.1 }, rot = { 25, 0, 0 }, paint = "glow", mat = "Neon" },
	}
	local wraps = {}
	bands(wraps, -0.4, 0.4, 4, { 0.22, 0.05, 0.24 }, "silver")
	KnifeShapes.RECIPES.HollowEclipse = {
		palette = { dark = hex("1a1a20"), silver = hex("b8bcc8"), blade = hex("1e1e26"), glow = hex("e4ecff"), hole = hex("0c0c10") },
		parts = join(p, wraps),
		trail = { 0.6, 2.6 },
	}
end

-- Sunrise Knife: a silver longsword with a guard of white feathers
do
	local p = {
		{ name = "Handle", kind = "Block", size = { 0.2, 0.85, 0.22 }, at = { 0, 0, 0 }, paint = "white", mat = "Plastic" },
		{ name = "Pommel", kind = "Block", size = { 0.22, 0.14, 0.24 }, at = { 0, -0.5, 0 }, paint = "gold", mat = "Metal" },
		{ name = "PommelGem", kind = "Block", size = { 0.24, 0.1, 0.1 }, at = { 0, -0.5, 0 }, paint = "glow", mat = "Neon" },
		{ name = "Guard", kind = "Block", size = { 0.24, 0.1, 0.42 }, at = { 0, 0.47, 0 }, paint = "gold", mat = "Metal" },
		{ name = "GuardGem", kind = "Block", size = { 0.26, 0.12, 0.12 }, at = { 0, 0.47, 0 }, paint = "glow", mat = "Neon" },
		{ name = "Blade", kind = "Block", size = { 0.07, 1.8, 0.32 }, at = { 0, 1.42, 0 }, paint = "blade", mat = "Metal" },
		{ name = "BladeFuller", kind = "Block", size = { 0.08, 1.6, 0.06 }, at = { 0, 1.38, 0 }, paint = "glow", mat = "Neon" },
	}
	local wraps = {}
	bands(wraps, -0.38, 0.38, 3, { 0.22, 0.05, 0.24 }, "gold")
	local wings = {}
	for side = -1, 1, 2 do
		for i = 1, 4 do
			local a = 52 + i * 11
			local r = 0.16 + i * 0.05
			table.insert(wings, {
				name = "Feather" .. (if side > 0 then "R" else "L") .. i, kind = "Block", size = { 0.05, 0.46 - i * 0.03, 0.1 },
				at = { 0, 0.47 + 0.17 * math.cos(math.rad(a)), side * (0.2 + r * math.sin(math.rad(a))) }, rot = { side * a, 0, 0 },
				paint = "white", mat = "Plastic",
			})
		end
	end
	KnifeShapes.RECIPES.CelestialSeraph = {
		palette = { white = hex("f6f6fa"), gold = hex("e8b830"), blade = hex("d4dde4"), glow = hex("3ac0ff") },
		parts = join(p, wraps, wings, point("BladeTip", 2.32, 0.32, 0.07, 0.5, "blade", "Metal")),
		trail = { 0.55, 2.8 },
	}
end

-- Inferno Knife: a dark jagged blade with glowing cracks
do
	local p = {
		{ name = "Handle", kind = "Block", size = { 0.2, 0.9, 0.22 }, at = { 0, 0, 0 }, paint = "green", mat = "Plastic" },
		{ name = "Pommel", kind = "Block", size = { 0.22, 0.12, 0.26 }, at = { 0, -0.51, 0 }, paint = "gold", mat = "Metal" },
		{ name = "Guard", kind = "Block", size = { 0.26, 0.12, 0.66 }, at = { 0, 0.5, 0 }, paint = "green", mat = "Metal" },
		{ name = "GuardTrim", kind = "Block", size = { 0.27, 0.04, 0.66 }, at = { 0, 0.44, 0 }, paint = "gold", mat = "Metal" },
		{ name = "GuardGem", kind = "Block", size = { 0.28, 0.12, 0.12 }, at = { 0, 0.5, 0 }, paint = "gem", mat = "Neon" },
		{ name = "Blade", kind = "Block", size = { 0.09, 1.8, 0.46 }, at = { 0, 1.46, 0.04 }, paint = "blade", mat = "Metal" },
		{ name = "BladeEdge", kind = "Block", size = { 0.1, 1.8, 0.05 }, at = { 0, 1.46, -0.19 }, paint = "glow", mat = "Neon" },
		{ name = "Crack1", kind = "Block", size = { 0.1, 0.38, 0.03 }, at = { 0, 1.0, 0.06 }, rot = { 28, 0, 0 }, paint = "glow", mat = "Neon" },
		{ name = "Crack2", kind = "Block", size = { 0.1, 0.32, 0.03 }, at = { 0, 1.5, 0.1 }, rot = { -32, 0, 0 }, paint = "glow", mat = "Neon" },
		{ name = "Crack3", kind = "Block", size = { 0.1, 0.36, 0.03 }, at = { 0, 1.98, 0.02 }, rot = { 22, 0, 0 }, paint = "glow", mat = "Neon" },
	}
	local teeth = {}
	for i = 1, 5 do
		table.insert(teeth, { name = "Tooth" .. i, kind = "Wedge", size = { 0.09, 0.2, 0.1 }, at = { 0, 0.72 + i * 0.32, 0.32 }, rot = { 0, 180, 0 }, paint = "blade", mat = "Metal" })
	end
	local wraps = {}
	bands(wraps, -0.38, 0.38, 3, { 0.22, 0.05, 0.24 }, "gold")
	KnifeShapes.RECIPES.DragonsMaw = {
		palette = { green = hex("1d4a32"), gold = hex("d6a23a"), blade = hex("2a110d"), glow = hex("ff7a1a"), gem = hex("ff2a1a") },
		parts = join(p, teeth, wraps, {
			{ name = "BladeTip", kind = "Wedge", size = { 0.09, 0.5, 0.46 }, at = { 0, 2.61, 0.04 }, rot = { 0, 180, 0 }, paint = "blade", mat = "Metal" },
		}),
		trail = { 0.6, 2.8 },
	}
end

-- Frost Knife: an icy blade with crystal spikes
do
	local p = {
		{ name = "Handle", kind = "Block", size = { 0.2, 0.9, 0.22 }, at = { 0, 0, 0 }, paint = "dark", mat = "Plastic" },
		{ name = "Pommel", kind = "Block", size = { 0.22, 0.12, 0.26 }, at = { 0, -0.51, 0 }, paint = "silver", mat = "Metal" },
		{ name = "Guard", kind = "Block", size = { 0.24, 0.1, 0.5 }, at = { 0, 0.48, 0 }, paint = "silver", mat = "Metal" },
		{ name = "GuardGem", kind = "Block", size = { 0.26, 0.12, 0.12 }, at = { 0, 0.48, 0 }, paint = "glow", mat = "Neon" },
		{ name = "Blade", kind = "Block", size = { 0.07, 1.82, 0.3 }, at = { 0, 1.44, 0 }, paint = "ice", mat = "Glass" },
		{ name = "BladeCore", kind = "Block", size = { 0.08, 1.7, 0.08 }, at = { 0, 1.42, 0 }, paint = "glow", mat = "Neon" },
	}
	local spikes = {}
	for i, s in { { 0.95, 1 }, { 1.35, -1 }, { 1.75, 1 }, { 2.1, -1 } } do
		table.insert(spikes, {
			name = "Crystal" .. i, kind = "Block", size = { 0.06, 0.3, 0.07 }, at = { 0, s[1], s[2] * 0.2 }, rot = { -s[2] * 40, 0, 0 },
			paint = "glow", mat = "Neon",
		})
	end
	local wraps = {}
	bands(wraps, -0.38, 0.38, 4, { 0.22, 0.05, 0.24 }, "silver")
	KnifeShapes.RECIPES.FrostboundOath = {
		palette = { dark = hex("1e2636"), silver = hex("d8dee8"), ice = hex("aee6f9"), glow = hex("5ae6ff") },
		parts = join(p, spikes, wraps, point("BladeTip", 2.35, 0.3, 0.07, 0.48, "ice", "Glass")),
		trail = { 0.55, 2.8 },
	}
end

function KnifeShapes.get(key: string?)
	return key and KnifeShapes.RECIPES[key] or nil
end

return KnifeShapes
