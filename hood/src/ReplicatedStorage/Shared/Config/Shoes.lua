--!strict
-- Shoes and shoe boxes: the game's "pets and eggs" (brief 16). Boxes stand on the shoe-box dais at the back of the
-- hall; opening one costs Cash and gives one pair of shoes, rolled by rarity (every box holds one shoe of each
-- rarity). Every pair gives a Power bonus; up to MaxEquipped pairs are equipped at once: the best one is worn on your
-- feet, the others follow you like pets. The equipped bonuses add up, and the total multiplies the Power every shot
-- pays (ranges and stage targets), alongside your gun and the range (Shared/ShoeRules, Shared/ShotRules).
--
--   Rarities  list of { Id, Name, Color, Chance (percent; they add up to 100), Weight (Chance x 100, what the roll
--             uses), Rank (1 Common .. 6 Secret), Power (the rarity's bonus factor) }
--   Boxes     list of { Id, Name, Price (Cash), Color, Shoes = { 6 ids, Common .. Secret }, Tier (1..10), Base (the
--             Common's bonus; the others are Base x their rarity's Power) }, cheapest first
--   ById[id]  { Id, Name, Box, Rarity, Bonus (percent of Power per shot), Colors = { Main, Accent, Sole }, Rank, Tier }
--   List      all 60 shoes, box by box, Common first
-- Ids are the source pictures' names in CamelCase (digits and '+' spelled out: TwentyFourKarat, PlusOneInfinity).
-- Saved data holds ids: never rename or remove one (a retired id is dropped from saves by ShoeRules.sanitize).
local C = Color3.fromRGB

local Shoes = {}

Shoes.MaxEquipped = 3 -- pairs equipped at once (1 worn + 2 following)
Shoes.MaxOwned = 100 -- pairs in your shoe rack; recycle spares to make room

-- Rarity ladder, as the pictures' discs: grey, blue, purple, orange, red, rainbow (Secret's Color is its base; it
-- shows as a rainbow where it can).
Shoes.Rarities = {
	{ Id = 'Common', Name = 'Common', Color = C(178, 186, 198), Chance = 62, Power = 1 },
	{ Id = 'Rare', Name = 'Rare', Color = C(61, 155, 255), Chance = 25, Power = 1.6 },
	{ Id = 'Epic', Name = 'Epic', Color = C(166, 77, 255), Chance = 9.5, Power = 2.6 },
	{ Id = 'Legendary', Name = 'Legendary', Color = C(255, 150, 32), Chance = 3, Power = 4.2 },
	{ Id = 'Mythic', Name = 'Mythic', Color = C(255, 59, 92), Chance = 0.45, Power = 7 },
	{ Id = 'Secret', Name = 'Secret', Color = C(255, 236, 120), Chance = 0.05, Power = 12 },
}
Shoes.RarityById = {}
for i, r in Shoes.Rarities do
	r.Rank = i
	r.Weight = math.floor(r.Chance * 100 + 0.5)
	Shoes.RarityById[r.Id] = r
end
Shoes.TotalWeight = 10000
-- The Secret rarity's rainbow (frames, banners and text gradients).
Shoes.Rainbow = { C(255, 82, 82), C(255, 170, 40), C(255, 236, 70), C(80, 220, 110), C(60, 170, 255), C(170, 90, 255) }

-- Box id, name, price, colour, Base (the Common's bonus, percent), then its 6 shoes Common..Secret:
-- { id, name, { main, accent, sole } }.
local W = C(246, 246, 242)
local rows = {
	{ 'Street', 'Street Box', 25, C(232, 70, 56), 4, {
		{ 'FreshCanvas', 'Fresh Canvas', { W, C(196, 200, 208), W } },
		{ 'RedRocket', 'Red Rocket', { C(218, 36, 44), C(255, 206, 40), W } },
		{ 'Checkmate', 'Checkmate', { C(30, 30, 36), W, C(240, 80, 70) } },
		{ 'ChromeKicks', 'Chrome Kicks', { C(196, 204, 216), C(232, 56, 64), C(36, 36, 44) } },
		{ 'StreetAngel', 'Street Angel', { C(230, 186, 70), W, W } },
		{ 'BlockRoyalty', 'Block Royalty', { C(40, 30, 60), C(255, 196, 48), C(230, 50, 70) } },
	} },
	{ 'Graffiti', 'Graffiti Box', 75, C(255, 110, 190), 6, {
		{ 'SprayTag', 'Spray Tag', { C(255, 120, 190), C(255, 200, 50), W } },
		{ 'DripTag', 'Drip Tag', { C(50, 200, 220), C(255, 120, 190), W } },
		{ 'PaintSplash', 'Paint Splash', { C(30, 30, 36), C(120, 230, 90), W } },
		{ 'NeonBomb', 'Neon Bomb', { C(255, 60, 170), C(80, 240, 230), C(36, 36, 44) } },
		{ 'WildStyle', 'Wild Style', { C(130, 230, 80), C(255, 100, 180), C(250, 250, 250) } },
		{ 'Masterpiece', 'Masterpiece', { C(70, 40, 120), C(255, 210, 60), C(40, 220, 210) } },
	} },
	{ 'Frost', 'Frost Box', 200, C(120, 200, 255), 8, {
		{ 'IceCold', 'Ice Cold', { W, C(150, 210, 255), W } },
		{ 'SnowDay', 'Snow Day', { C(220, 236, 255), C(90, 160, 240), W } },
		{ 'Flurry', 'Flurry', { C(70, 140, 230), W, C(200, 230, 255) } },
		{ 'Glacier', 'Glacier', { C(150, 220, 255), C(230, 250, 255), C(60, 120, 200) } },
		{ 'BlizzardKing', 'Blizzard King', { W, C(80, 170, 255), C(200, 210, 230) } },
		{ 'AbsoluteZero', 'Absolute Zero', { C(20, 40, 110), C(110, 240, 255), C(220, 240, 255) } },
	} },
	{ 'Lava', 'Lava Box', 450, C(255, 110, 40), 11, {
		{ 'Ember', 'Ember', { C(70, 64, 66), C(255, 120, 40), C(40, 36, 38) } },
		{ 'HotStep', 'Hot Step', { C(220, 50, 40), C(255, 170, 40), C(40, 36, 38) } },
		{ 'MagmaCrack', 'Magma Crack', { C(36, 30, 32), C(255, 110, 30), C(60, 50, 50) } },
		{ 'Obsidian', 'Obsidian', { C(30, 24, 40), C(160, 90, 255), C(255, 120, 40) } },
		{ 'Inferno', 'Inferno', { C(230, 40, 30), C(255, 210, 50), C(40, 30, 30) } },
		{ 'Phoenix', 'Phoenix', { C(255, 120, 30), C(255, 220, 80), C(200, 40, 40) } },
	} },
	{ 'Toxic', 'Toxic Box', 900, C(110, 230, 70), 15, {
		{ 'SlimeTime', 'Slime Time', { C(120, 220, 70), C(130, 70, 200), W } },
		{ 'GlowStick', 'Glow Stick', { C(190, 255, 60), C(40, 40, 46), C(160, 255, 90) } },
		{ 'Ooze', 'Ooze', { C(70, 200, 80), C(200, 255, 120), C(40, 60, 40) } },
		{ 'Reactor', 'Reactor', { C(255, 220, 40), C(36, 36, 40), C(120, 240, 80) } },
		{ 'ToxicTitan', 'Toxic Titan', { C(40, 46, 40), C(120, 255, 80), C(150, 80, 220) } },
		{ 'Mutant', 'Mutant', { C(120, 60, 190), C(140, 255, 90), C(250, 250, 250) } },
	} },
	{ 'Candy', 'Candy Box', 1600, C(255, 150, 200), 20, {
		{ 'Bubblegum', 'Bubblegum', { C(255, 150, 200), W, W } },
		{ 'CottonCandy', 'Cotton Candy', { C(255, 180, 220), C(150, 210, 255), W } },
		{ 'Sprinkles', 'Sprinkles', { W, C(255, 90, 150), C(120, 210, 255) } },
		{ 'Gummy', 'Gummy', { C(240, 60, 80), C(90, 220, 120), C(255, 200, 60) } },
		{ 'SugarRush', 'Sugar Rush', { C(255, 120, 200), C(255, 230, 90), C(120, 220, 255) } },
		{ 'CandyKingdom', 'Candy Kingdom', { C(250, 140, 210), C(255, 205, 60), C(160, 110, 240) } },
	} },
	{ 'Ocean', 'Ocean Box', 2800, C(40, 170, 200), 27, {
		{ 'Wave', 'Wave', { C(60, 150, 230), W, W } },
		{ 'Coral', 'Coral', { C(255, 120, 110), C(255, 200, 170), W } },
		{ 'Tidal', 'Tidal', { C(30, 170, 190), W, C(20, 90, 130) } },
		{ 'Pearl', 'Pearl', { C(240, 236, 248), C(220, 190, 240), C(150, 210, 230) } },
		{ 'DeepSea', 'Deep Sea', { C(20, 40, 90), C(60, 230, 230), C(30, 60, 120) } },
		{ 'Atlantis', 'Atlantis', { C(30, 160, 170), C(255, 200, 60), W } },
	} },
	{ 'Gem', 'Gem Box', 4500, C(40, 200, 120), 36, {
		{ 'EmeraldKick', 'Emerald Kick', { C(40, 190, 100), W, W } },
		{ 'RubyRunner', 'Ruby Runner', { C(220, 30, 70), W, C(40, 36, 40) } },
		{ 'Facet', 'Facet', { C(120, 200, 255), C(255, 120, 200), W } },
		{ 'DiamondStep', 'Diamond Step', { C(220, 245, 255), C(120, 220, 255), C(200, 210, 230) } },
		{ 'CrystalCrown', 'Crystal Crown', { C(150, 90, 230), C(255, 205, 60), W } },
		{ 'PrismCore', 'Prism Core', { W, C(255, 120, 200), C(120, 230, 255) } },
	} },
	{ 'Galaxy', 'Galaxy Box', 7000, C(110, 90, 240), 48, {
		{ 'NightSky', 'Night Sky', { C(30, 40, 100), C(250, 250, 255), C(60, 70, 140) } },
		{ 'Comet', 'Comet', { C(60, 110, 230), C(255, 170, 60), W } },
		{ 'Nebula', 'Nebula', { C(130, 60, 200), C(255, 120, 200), C(40, 30, 80) } },
		{ 'Supernova', 'Supernova', { C(255, 220, 80), W, C(255, 120, 40) } },
		{ 'CosmicWings', 'Cosmic Wings', { C(70, 50, 170), W, C(150, 200, 255) } },
		{ 'BlackHole', 'Black Hole', { C(20, 16, 30), C(170, 90, 255), C(255, 150, 60) } },
	} },
	{ 'Gold', 'Gold Box', 10000, C(255, 196, 48), 64, {
		{ 'GoldRush', 'Gold Rush', { C(255, 196, 48), C(40, 36, 40), W } },
		{ 'Royal', 'Royal', { C(110, 50, 170), C(255, 200, 50), W } },
		{ 'Monogram', 'Monogram', { C(120, 80, 50), C(255, 200, 60), C(60, 40, 30) } },
		{ 'TwentyFourKarat', '24 Karat', { C(255, 205, 50), C(255, 240, 160), C(200, 140, 20) } },
		{ 'KingsCrown', "King's Crown", { C(255, 200, 50), C(220, 40, 60), C(110, 50, 170) } },
		{ 'PlusOneInfinity', '+1 Infinity', { C(255, 215, 70), C(60, 200, 255), C(255, 255, 255) } },
	} },
}

-- A rarity's bonus for a box: Base x Power, rounded to a whole percent (5s from 50, 10s from 200, 50s from 1000).
local function nice(v: number): number
	local step = v >= 1000 and 50 or v >= 200 and 10 or v >= 50 and 5 or 1
	return math.max(1, math.floor(v / step + 0.5) * step)
end
Shoes.nice = nice

Shoes.Boxes = {}
Shoes.BoxById = {}
Shoes.List = {}
Shoes.ById = {}
for tier, row in rows do
	local box = { Id = row[1], Name = row[2], Price = row[3], Color = row[4], Base = row[5], Tier = tier, Shoes = {} }
	for rank, s in row[6] do
		local rarity = Shoes.Rarities[rank]
		local shoe = {
			Id = s[1], Name = s[2], Box = box.Id, Rarity = rarity.Id, Rank = rank, Tier = tier,
			Bonus = nice(box.Base * rarity.Power),
			Colors = { Main = s[3][1], Accent = s[3][2], Sole = s[3][3] },
		}
		table.insert(box.Shoes, shoe.Id)
		table.insert(Shoes.List, shoe)
		Shoes.ById[shoe.Id] = shoe
	end
	table.insert(Shoes.Boxes, box)
	Shoes.BoxById[box.Id] = box
end

-- A shoe's bonus (percent; 0 for an unknown id).
function Shoes.bonus(id: any): number
	local s = type(id) == 'string' and Shoes.ById[id]
	return s and s.Bonus or 0
end

return Shoes
