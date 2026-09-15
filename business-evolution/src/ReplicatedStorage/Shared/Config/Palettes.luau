--!strict
-- One locked 5-colour palette per floor (§11). The map kit and the UI theme
-- both read from here so a floor's look can be retuned in one place.
-- Stored as {r,g,b} 0-255 tables (shared config must stay userdata-free);
-- call Palettes.color() to get a Color3 at the point of use.

export type Palette = {
	Ground: { number }, -- floor surface
	Wall: { number },
	Primary: { number }, -- the floor's dominant furniture colour
	Accent: { number }, -- the "pop" colour: signage, highlights, trim
	Dark: { number }, -- shadows, legs, frames
}

local Palettes: { [string]: Palette } = {
	Mailroom = {
		Ground = { 168, 154, 124 }, -- worn beige carpet
		Wall = { 205, 193, 163 },
		Primary = { 176, 141, 87 }, -- cardboard
		Accent = { 122, 122, 82 }, -- olive
		Dark = { 92, 81, 66 },
	},
	CubicleFarm = {
		Ground = { 124, 148, 99 }, -- sickly green carpet
		Wall = { 216, 216, 214 },
		Primary = { 158, 163, 168 }, -- grey felt
		Accent = { 58, 88, 150 }, -- corporate navy
		Dark = { 74, 78, 84 },
	},
	OpenPlan = {
		Ground = { 201, 141, 90 }, -- warm wood
		Wall = { 168, 90, 62 }, -- exposed brick
		Primary = { 240, 234, 214 }, -- cream
		Accent = { 90, 168, 96 }, -- leaf green
		Dark = { 52, 48, 44 }, -- black steel
	},
	Executive = {
		Ground = { 35, 37, 43 }, -- dark marble
		Wall = { 51, 55, 61 }, -- charcoal
		Primary = { 107, 74, 43 }, -- real wood
		Accent = { 201, 162, 75 }, -- gold
		Dark = { 20, 21, 25 },
	},
	Penthouse = {
		Ground = { 242, 239, 233 }, -- white marble
		Wall = { 250, 248, 244 },
		Primary = { 226, 219, 205 }, -- warm stone
		Accent = { 212, 175, 55 }, -- gold trim
		Dark = { 111, 214, 232 }, -- pool cyan (the Penthouse "dark" is water!)
	},
	OrbitalHQ = {
		Ground = { 42, 50, 66 }, -- deck panels
		Wall = { 184, 196, 206 }, -- chrome
		Primary = { 30, 36, 52 },
		Accent = { 53, 224, 255 }, -- cyan neon
		Dark = { 11, 15, 30 }, -- deep space
	},
}

local PalettesModule = {}

PalettesModule.ByFloor = Palettes

function PalettesModule.get(floorId: string): Palette
	return Palettes[floorId] or Palettes.Mailroom
end

function PalettesModule.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

return PalettesModule
