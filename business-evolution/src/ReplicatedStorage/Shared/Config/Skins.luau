--!strict
-- Skins — the hero shop of the reference game, in business dress. Bought with
-- Wins, worn on your character, and each one multiplies the Productivity you
-- earn per click. Exactly one is equipped at a time.
--
-- The ladder deliberately starts free (you own the Intern from your first
-- second) and ends somewhere absurd, so the shop wall always shows both what
-- you just bought and what you are saving for.

export type Skin = {
	Id: string,
	Name: string,
	Cost: number, -- Wins; 0 = owned from the start
	PowerPerClick: number, -- multiplies click income
	Tagline: string,
	-- Look, applied to the character by AppearanceService.
	Shirt: { number },
	Trousers: { number },
	Accent: { number }, -- tie / pocket square / trim
	Glow: boolean, -- Neon accents for the top of the ladder
}

local Skins: { Skin } = {
	{
		Id = "Intern",
		Name = "Intern",
		Cost = 0,
		PowerPerClick = 1,
		Tagline = "The lanyard is not even yours.",
		Shirt = { 236, 238, 240 },
		Trousers = { 92, 104, 128 },
		Accent = { 180, 188, 200 },
		Glow = false,
	},
	{
		Id = "Salesman",
		Name = "Salesman",
		Cost = 5,
		PowerPerClick = 2,
		Tagline = "Coffee is for closers.",
		Shirt = { 220, 226, 236 },
		Trousers = { 66, 78, 104 },
		Accent = { 220, 68, 68 },
		Glow = false,
	},
	{
		Id = "Analyst",
		Name = "Analyst",
		Cost = 25,
		PowerPerClick = 5,
		Tagline = "The spreadsheet has feelings too.",
		Shirt = { 206, 216, 232 },
		Trousers = { 52, 62, 88 },
		Accent = { 74, 152, 226 },
		Glow = false,
	},
	{
		Id = "Manager",
		Name = "Manager",
		Cost = 120,
		PowerPerClick = 12,
		Tagline = "Let's circle back on that.",
		Shirt = { 60, 66, 84 },
		Trousers = { 40, 44, 58 },
		Accent = { 226, 178, 66 },
		Glow = false,
	},
	{
		Id = "Director",
		Name = "Director",
		Cost = 600,
		PowerPerClick = 35,
		Tagline = "Your calendar is a weapon.",
		Shirt = { 44, 48, 64 },
		Trousers = { 30, 34, 46 },
		Accent = { 236, 200, 96 },
		Glow = false,
	},
	{
		Id = "Executive",
		Name = "Executive",
		Cost = 3000,
		PowerPerClick = 100,
		Tagline = "The elevator greets you by name.",
		Shirt = { 30, 34, 48 },
		Trousers = { 22, 25, 36 },
		Accent = { 255, 214, 110 },
		Glow = false,
	},
	{
		Id = "Tycoon",
		Name = "Tycoon",
		Cost = 15000,
		PowerPerClick = 300,
		Tagline = "You own the building. And the street.",
		Shirt = { 24, 26, 38 },
		Trousers = { 18, 20, 30 },
		Accent = { 255, 196, 40 },
		Glow = true,
	},
	{
		Id = "Mogul",
		Name = "Mogul",
		Cost = 80000,
		PowerPerClick = 900,
		Tagline = "Markets move when you sneeze.",
		Shirt = { 40, 22, 60 },
		Trousers = { 26, 16, 40 },
		Accent = { 200, 90, 255 },
		Glow = true,
	},
	{
		Id = "Chairman",
		Name = "Chairman",
		Cost = 400000,
		PowerPerClick = 2600,
		Tagline = "The building was named after you all along.",
		Shirt = { 250, 214, 120 },
		Trousers = { 120, 92, 30 },
		Accent = { 255, 240, 190 },
		Glow = true,
	},
	{
		Id = "Sovereign",
		Name = "Sovereign Fund",
		Cost = 2500000,
		PowerPerClick = 9000,
		Tagline = "A country keeps its savings with you.",
		Shirt = { 30, 245, 220 },
		Trousers = { 20, 60, 70 },
		Accent = { 190, 255, 250 },
		Glow = true,
	},
}

local SkinsModule = {}

SkinsModule.List = Skins
SkinsModule.DefaultId = "Intern"

local byId: { [string]: Skin } = {}
for _, skin in Skins do
	byId[skin.Id] = skin
end

function SkinsModule.get(id: string): Skin?
	return byId[id]
end

-- Click multiplier from the equipped skin (1 if the id is unknown, so a bad
-- save can never zero out a player's income).
function SkinsModule.multiplierFor(skinId: string): number
	local skin = byId[skinId]
	return if skin then skin.PowerPerClick else 1
end

return SkinsModule
