-- IconModels: the HUD, window and card pictures (brief 24: flat cartoon PNGs, no 3D models anywhere in the UI).
-- Hand-maintained (no longer generated): the art is rendered by hood/tools/blender/icons_hd.py into hood/art/icons3d/<Id>.png
-- (512 px, transparent, one framing for all: the art centred, its longer side 88% of the canvas, a #060632 outline), and
-- hood/tools/upload_assets.py uploads the changed PNGs and rewrites M.Images below (keep its layout: one `Id = '...', -- Id`
-- line per image).
--   M.Ids                  every icon id that has a Fallback row (the families below have none)
--   M.Images[id]           the uploaded image ('' until uploaded); families: Shoe_<ShoeId>, Box_<BoxId>, Gun_<GunId>,
--                          BoxLid_<BoxId> / BoxBase_<BoxId> (a box's lid and body in the box's exact framing)
--   M.Fallback[id]         the flat 2D stand-in UIKit draws while an image can't show (not uploaded, in review, rejected):
--                          { Color = the block, Glyph = a UIKit Kit.Glyphs name, Text = a short sticker?, Ink = the glyph's
--                          fill?, Accent = its details? }. Families get theirs from Config (UIKit), so they have no rows.
--   M.has(id)              true when UIKit can show `id`: an image, a Fallback row, or a Shoe_ / Box_ / Gun_ family id
--   M.BoxLidLine           the lid's bottom edge in a Box_<id> PNG, as a fraction of the canvas height from the top
--                          (M.BoxLidLines[boxId] per box)
local M = {}
M.Ids = { 'Shop', 'Rebirth', 'Rewards', 'PVP', 'Evolve', 'Cash', 'Power', 'Trophy', 'Gun', 'Muscle', 'Basket', 'BasketRed', 'Quest', 'Sneaker', 'Robux', 'Shield', 'XP', 'Skull', 'VIP', 'AutoFight', 'Arrow', 'RebirthSkip', 'DoublePower', 'World', 'Backpack', 'ShoePile', 'ShoeBox', 'Delete', 'Favorite', 'Search', 'PotionRed', 'PotionGold', 'BoostBundle', 'CashTiny', 'CashSmall', 'CashMedium', 'CashLarge', 'PowerTiny', 'PowerSmall', 'PowerMedium', 'PowerLarge', 'PowerPack1', 'PowerPack2', 'PowerPack3', 'DoubleCash', 'Lucky', 'TripleOpen', 'ExtraEquip', 'TenXCash', 'ProBay', 'GoldBay', 'BlockParty' }
-- The uploaded image ids of the hood/art/icons3d PNGs (rbxassetid://...), written by hood/tools/upload_assets.py.
M.Images = {
	Shop = 'rbxassetid://117144901120764', -- Shop
	Rebirth = 'rbxassetid://103361619270783', -- Rebirth
	Rewards = 'rbxassetid://103649616247856', -- Rewards
	PVP = 'rbxassetid://70761256249206', -- PVP
	Evolve = 'rbxassetid://121050906886591', -- Evolve
	Cash = 'rbxassetid://138584372997267', -- Cash
	Power = 'rbxassetid://87578744665897', -- Power
	Trophy = 'rbxassetid://79637849351339', -- Trophy
	Gun = 'rbxassetid://78859240435689', -- Gun
	Muscle = 'rbxassetid://82497751954996', -- Muscle
	Basket = 'rbxassetid://115965935689965', -- Basket
	BasketRed = 'rbxassetid://104277724778865', -- BasketRed
	Quest = 'rbxassetid://133876055881773', -- Quest
	Sneaker = 'rbxassetid://104055209686103', -- Sneaker
	Robux = 'rbxassetid://139241840538268', -- Robux
	Shield = 'rbxassetid://127389907824825', -- Shield
	XP = 'rbxassetid://103326912698674', -- XP
	Skull = 'rbxassetid://85252718291002', -- Skull
	VIP = 'rbxassetid://104188044863978', -- VIP
	AutoFight = 'rbxassetid://114125565679340', -- AutoFight
	Arrow = 'rbxassetid://82744250493627', -- Arrow
	RebirthSkip = 'rbxassetid://132373266808103', -- RebirthSkip
	DoublePower = 'rbxassetid://98715092516172', -- DoublePower
	World = 'rbxassetid://88983035389300', -- World
	Backpack = 'rbxassetid://124122489781241', -- Backpack
	ShoePile = 'rbxassetid://120974184895124', -- ShoePile
	ShoeBox = 'rbxassetid://82585132923140', -- ShoeBox
	Delete = 'rbxassetid://89584770337306', -- Delete
	Favorite = 'rbxassetid://93130764462339', -- Favorite
	Search = 'rbxassetid://110084260284952', -- Search
	PotionRed = 'rbxassetid://71428056494832', -- PotionRed
	PotionGold = 'rbxassetid://123335735031521', -- PotionGold
	BoostBundle = 'rbxassetid://131863456387030', -- BoostBundle
	CashTiny = 'rbxassetid://139143168634274', -- CashTiny
	CashSmall = 'rbxassetid://139671947870442', -- CashSmall
	CashMedium = 'rbxassetid://77275961907933', -- CashMedium
	CashLarge = 'rbxassetid://118667847963328', -- CashLarge
	PowerTiny = 'rbxassetid://103165395268922', -- PowerTiny
	PowerSmall = 'rbxassetid://131542442436920', -- PowerSmall
	PowerMedium = 'rbxassetid://131189280905625', -- PowerMedium
	PowerLarge = 'rbxassetid://102617900930614', -- PowerLarge
	PowerPack1 = 'rbxassetid://86256081274504', -- PowerPack1
	PowerPack2 = 'rbxassetid://85247268044655', -- PowerPack2
	PowerPack3 = 'rbxassetid://111445991240072', -- PowerPack3
	DoubleCash = 'rbxassetid://97175208283590', -- DoubleCash
	Shoe_FreshCanvas = 'rbxassetid://85745034534989', -- Shoe_FreshCanvas
	Shoe_RedRocket = 'rbxassetid://132854488737070', -- Shoe_RedRocket
	Shoe_Checkmate = 'rbxassetid://97483584008431', -- Shoe_Checkmate
	Shoe_ChromeKicks = 'rbxassetid://77070654323327', -- Shoe_ChromeKicks
	Shoe_StreetAngel = 'rbxassetid://108508675098488', -- Shoe_StreetAngel
	Shoe_BlockRoyalty = 'rbxassetid://127932087267263', -- Shoe_BlockRoyalty
	Shoe_SprayTag = 'rbxassetid://71193143538721', -- Shoe_SprayTag
	Shoe_DripTag = 'rbxassetid://96363043019730', -- Shoe_DripTag
	Shoe_PaintSplash = 'rbxassetid://113588187443272', -- Shoe_PaintSplash
	Shoe_NeonBomb = 'rbxassetid://103725000321909', -- Shoe_NeonBomb
	Shoe_WildStyle = 'rbxassetid://86913184275263', -- Shoe_WildStyle
	Shoe_Masterpiece = 'rbxassetid://117719000419125', -- Shoe_Masterpiece
	Shoe_SilverStreak = 'rbxassetid://90991926429978', -- Shoe_SilverStreak
	Shoe_MidnightChrome = 'rbxassetid://78672098577540', -- Shoe_MidnightChrome
	Shoe_RainbowDrip = 'rbxassetid://95311061203343', -- Shoe_RainbowDrip
	Shoe_Hologram = 'rbxassetid://129738224181710', -- Shoe_Hologram
	Shoe_PlatinumWings = 'rbxassetid://89512628103516', -- Shoe_PlatinumWings
	Shoe_GoldenHour = 'rbxassetid://80574873870564', -- Shoe_GoldenHour
	Shoe_Starlight = 'rbxassetid://73305108372967', -- Shoe_Starlight
	Shoe_SolarFlare = 'rbxassetid://98512993840194', -- Shoe_SolarFlare
	Shoe_AstroCrown = 'rbxassetid://115238965806100', -- Shoe_AstroCrown
	Shoe_TheGrail = 'rbxassetid://131097975749755', -- Shoe_TheGrail
	Shoe_IceCold = '', -- Shoe_IceCold
	Shoe_SnowDay = '', -- Shoe_SnowDay
	Shoe_Flurry = '', -- Shoe_Flurry
	Shoe_Glacier = '', -- Shoe_Glacier
	Shoe_BlizzardKing = '', -- Shoe_BlizzardKing
	Shoe_AbsoluteZero = '', -- Shoe_AbsoluteZero
	Shoe_Ember = '', -- Shoe_Ember
	Shoe_HotStep = '', -- Shoe_HotStep
	Shoe_MagmaCrack = '', -- Shoe_MagmaCrack
	Shoe_Obsidian = '', -- Shoe_Obsidian
	Shoe_Inferno = '', -- Shoe_Inferno
	Shoe_Phoenix = '', -- Shoe_Phoenix
	Shoe_SlimeTime = '', -- Shoe_SlimeTime
	Shoe_GlowStick = '', -- Shoe_GlowStick
	Shoe_Ooze = '', -- Shoe_Ooze
	Shoe_Reactor = '', -- Shoe_Reactor
	Shoe_ToxicTitan = '', -- Shoe_ToxicTitan
	Shoe_Mutant = '', -- Shoe_Mutant
	Shoe_Bubblegum = '', -- Shoe_Bubblegum
	Shoe_CottonCandy = '', -- Shoe_CottonCandy
	Shoe_Sprinkles = '', -- Shoe_Sprinkles
	Shoe_Gummy = '', -- Shoe_Gummy
	Shoe_SugarRush = '', -- Shoe_SugarRush
	Shoe_CandyKingdom = '', -- Shoe_CandyKingdom
	Shoe_Wave = '', -- Shoe_Wave
	Shoe_Coral = '', -- Shoe_Coral
	Shoe_Tidal = '', -- Shoe_Tidal
	Shoe_Pearl = '', -- Shoe_Pearl
	Shoe_DeepSea = '', -- Shoe_DeepSea
	Shoe_Atlantis = '', -- Shoe_Atlantis
	Shoe_EmeraldKick = '', -- Shoe_EmeraldKick
	Shoe_RubyRunner = '', -- Shoe_RubyRunner
	Shoe_Facet = '', -- Shoe_Facet
	Shoe_DiamondStep = '', -- Shoe_DiamondStep
	Shoe_CrystalCrown = '', -- Shoe_CrystalCrown
	Shoe_PrismCore = '', -- Shoe_PrismCore
	Shoe_NightSky = '', -- Shoe_NightSky
	Shoe_Comet = '', -- Shoe_Comet
	Shoe_Nebula = '', -- Shoe_Nebula
	Shoe_Supernova = '', -- Shoe_Supernova
	Shoe_CosmicWings = '', -- Shoe_CosmicWings
	Shoe_BlackHole = '', -- Shoe_BlackHole
	Shoe_GoldRush = '', -- Shoe_GoldRush
	Shoe_Royal = '', -- Shoe_Royal
	Shoe_Monogram = '', -- Shoe_Monogram
	Shoe_TwentyFourKarat = '', -- Shoe_TwentyFourKarat
	Shoe_KingsCrown = '', -- Shoe_KingsCrown
	Shoe_PlusOneInfinity = '', -- Shoe_PlusOneInfinity
	Box_Street = 'rbxassetid://111504536980240', -- Box_Street
	Box_Graffiti = 'rbxassetid://109937073305479', -- Box_Graffiti
	Box_Exclusive = 'rbxassetid://97686481161520', -- Box_Exclusive
	Box_Grail = 'rbxassetid://106607070015656', -- Box_Grail
	Box_Frost = '', -- Box_Frost
	Box_Lava = '', -- Box_Lava
	Box_Toxic = '', -- Box_Toxic
	Box_Candy = '', -- Box_Candy
	Box_Ocean = '', -- Box_Ocean
	Box_Gem = '', -- Box_Gem
	Box_Galaxy = '', -- Box_Galaxy
	Box_Gold = '', -- Box_Gold
	Lucky = '', -- Lucky
	TripleOpen = '', -- TripleOpen
	ExtraEquip = '', -- ExtraEquip
	TenXCash = '', -- TenXCash
	ProBay = '', -- ProBay
	GoldBay = '', -- GoldBay
	BlockParty = '', -- BlockParty
	Gun_Pistol = '', -- Gun_Pistol
	Gun_Revolver = '', -- Gun_Revolver
	Gun_Uzi = '', -- Gun_Uzi
	Gun_Shotgun = '', -- Gun_Shotgun
	Gun_Tommy = '', -- Gun_Tommy
	Gun_AK = '', -- Gun_AK
	Gun_Deagle = '', -- Gun_Deagle
	Gun_Minigun = '', -- Gun_Minigun
	Gun_Blaster = '', -- Gun_Blaster
	Gun_Diamond = '', -- Gun_Diamond
	BoxLid_Street = '', -- BoxLid_Street
	BoxLid_Graffiti = '', -- BoxLid_Graffiti
	BoxLid_Exclusive = '', -- BoxLid_Exclusive
	BoxLid_Grail = '', -- BoxLid_Grail
	BoxBase_Street = '', -- BoxBase_Street
	BoxBase_Graffiti = '', -- BoxBase_Graffiti
	BoxBase_Exclusive = '', -- BoxBase_Exclusive
	BoxBase_Grail = '', -- BoxBase_Grail
}
-- The flat 2D stand-ins (brief 24, agreed with UI6): each row is the art's own main colour and a simple glyph.
M.Fallback = {
	Basket = { Color = Color3.fromRGB(252, 140, 24), Glyph = 'basket' },
	Shop = { Color = Color3.fromRGB(252, 140, 24), Glyph = 'basket' },
	BasketRed = { Color = Color3.fromRGB(222, 28, 76), Glyph = 'basket' },
	World = { Color = Color3.fromRGB(60, 156, 240), Glyph = 'globe', Accent = Color3.fromRGB(92, 204, 92) },
	Rebirth = { Color = Color3.fromRGB(240, 50, 82), Glyph = 'cycle' },
	RebirthSkip = { Color = Color3.fromRGB(52, 186, 74), Glyph = 'cycle' },
	Sneaker = { Color = Color3.fromRGB(232, 40, 56), Glyph = 'shoe' },
	Gun = { Color = Color3.fromRGB(122, 136, 164), Glyph = 'gun' },
	Backpack = { Color = Color3.fromRGB(224, 90, 69), Glyph = 'bag' },
	Quest = { Color = Color3.fromRGB(246, 162, 112), Glyph = 'scroll', Accent = Color3.fromRGB(232, 54, 74) },
	Rewards = { Color = Color3.fromRGB(232, 50, 120), Glyph = 'gift', Accent = Color3.fromRGB(255, 164, 18) },
	Power = { Color = Color3.fromRGB(252, 164, 28), Glyph = 'arm' },
	Muscle = { Color = Color3.fromRGB(252, 164, 28), Glyph = 'arm' },
	PowerPack1 = { Color = Color3.fromRGB(252, 164, 28), Glyph = 'arm' },
	PowerPack2 = { Color = Color3.fromRGB(252, 164, 28), Glyph = 'arm', Accent = Color3.fromRGB(255, 214, 40) },
	PowerPack3 = { Color = Color3.fromRGB(252, 164, 28), Glyph = 'arm', Accent = Color3.fromRGB(255, 214, 40) },
	Cash = { Color = Color3.fromRGB(88, 200, 78), Glyph = 'cash' },
	Trophy = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'trophy' },
	Robux = { Color = Color3.fromRGB(255, 255, 255), Glyph = 'hex', Ink = Color3.fromRGB(11, 42, 0) },
	Arrow = { Color = Color3.fromRGB(52, 186, 74), Glyph = 'arrow' },
	Evolve = { Color = Color3.fromRGB(52, 186, 74), Glyph = 'arrow' },
	Shield = { Color = Color3.fromRGB(30, 140, 250), Glyph = 'shield' },
	XP = { Color = Color3.fromRGB(30, 140, 250), Glyph = 'shield', Text = 'XP' },
	Skull = { Color = Color3.fromRGB(58, 62, 80), Glyph = 'skull', Ink = Color3.fromRGB(242, 244, 250) },
	PVP = { Color = Color3.fromRGB(232, 44, 56), Glyph = 'fist' },
	DoublePower = { Color = Color3.fromRGB(255, 196, 40), Glyph = 'arm' },
	DoubleCash = { Color = Color3.fromRGB(88, 200, 78), Glyph = 'cash' },
	VIP = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'crown', Accent = Color3.fromRGB(230, 30, 70) },
	AutoFight = { Color = Color3.fromRGB(226, 40, 66), Glyph = 'gun' },
	Lucky = { Color = Color3.fromRGB(62, 196, 74), Glyph = 'clover' },
	TripleOpen = { Color = Color3.fromRGB(162, 84, 236), Glyph = 'box' },
	ExtraEquip = { Color = Color3.fromRGB(40, 130, 245), Glyph = 'shoe' },
	TenXCash = { Color = Color3.fromRGB(70, 176, 70), Glyph = 'cash' },
	ProBay = { Color = Color3.fromRGB(40, 190, 190), Glyph = 'text', Text = 'x100' },
	GoldBay = { Color = Color3.fromRGB(255, 196, 40), Glyph = 'text', Text = 'x250' },
	PotionRed = { Color = Color3.fromRGB(236, 44, 72), Glyph = 'potion', Text = '2x' },
	PotionGold = { Color = Color3.fromRGB(255, 204, 30), Glyph = 'potion', Text = '3x' },
	BoostBundle = { Color = Color3.fromRGB(236, 44, 72), Glyph = 'potion', Accent = Color3.fromRGB(176, 228, 252) },
	CashTiny = { Color = Color3.fromRGB(70, 176, 70), Glyph = 'cash' },
	CashSmall = { Color = Color3.fromRGB(70, 176, 70), Glyph = 'cash' },
	CashMedium = { Color = Color3.fromRGB(70, 176, 70), Glyph = 'cash' },
	CashLarge = { Color = Color3.fromRGB(70, 176, 70), Glyph = 'cash' },
	PowerTiny = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'dumbbell' },
	PowerSmall = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'dumbbell' },
	PowerMedium = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'dumbbell' },
	PowerLarge = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'dumbbell' },
	ShoePile = { Color = Color3.fromRGB(232, 40, 56), Glyph = 'shoe' },
	ShoeBox = { Color = Color3.fromRGB(255, 140, 30), Glyph = 'box' },
	Delete = { Color = Color3.fromRGB(236, 52, 92), Glyph = 'x' },
	Favorite = { Color = Color3.fromRGB(250, 166, 22), Glyph = 'star' },
	Search = { Color = Color3.fromRGB(60, 66, 90), Glyph = 'search' },
	BlockParty = { Color = Color3.fromRGB(150, 80, 232), Glyph = 'star', Accent = Color3.fromRGB(255, 204, 40) },
}
-- (brief 25) Each PNG's drawn content: { x0, y0, x1, y1 } as fractions of the 512 canvas (alpha > 10%, top-left
-- origin), written by hood/tools/blender/icon_bounds.py after each render batch. UIKit places pictures by it.
M.Bounds = {
	Arrow = { 0.061, 0.068, 0.939, 0.932 },
	AutoFight = { 0.061, 0.086, 0.939, 0.914 },
	Backpack = { 0.064, 0.061, 0.936, 0.939 },
	Basket = { 0.084, 0.061, 0.918, 0.939 },
	BasketRed = { 0.061, 0.098, 0.941, 0.902 },
	BlockParty = { 0.076, 0.061, 0.922, 0.939 },
	BoostBundle = { 0.061, 0.166, 0.939, 0.834 },
	BoxBase_Exclusive = { 0.084, 0.223, 0.916, 0.832 },
	BoxBase_Graffiti = { 0.084, 0.223, 0.916, 0.832 },
	BoxBase_Grail = { 0.061, 0.285, 0.939, 0.756 },
	BoxBase_Street = { 0.084, 0.223, 0.916, 0.832 },
	BoxLid_Exclusive = { 0.061, 0.168, 0.941, 0.619 },
	BoxLid_Graffiti = { 0.061, 0.168, 0.941, 0.619 },
	BoxLid_Grail = { 0.166, 0.244, 0.834, 0.600 },
	BoxLid_Street = { 0.061, 0.168, 0.941, 0.619 },
	Box_Exclusive = { 0.061, 0.168, 0.941, 0.832 },
	Box_Graffiti = { 0.061, 0.168, 0.941, 0.832 },
	Box_Grail = { 0.061, 0.244, 0.939, 0.756 },
	Box_Street = { 0.061, 0.168, 0.941, 0.832 },
	Cash = { 0.061, 0.203, 0.939, 0.797 },
	CashLarge = { 0.061, 0.127, 0.939, 0.873 },
	CashMedium = { 0.061, 0.129, 0.939, 0.871 },
	CashSmall = { 0.061, 0.174, 0.939, 0.826 },
	CashTiny = { 0.061, 0.180, 0.939, 0.820 },
	Delete = { 0.086, 0.061, 0.914, 0.939 },
	DoubleCash = { 0.061, 0.141, 0.939, 0.859 },
	DoublePower = { 0.061, 0.084, 0.939, 0.916 },
	Evolve = { 0.061, 0.068, 0.939, 0.932 },
	ExtraEquip = { 0.061, 0.156, 0.939, 0.844 },
	Favorite = { 0.061, 0.072, 0.939, 0.928 },
	GoldBay = { 0.209, 0.061, 0.791, 0.939 },
	Gun = { 0.061, 0.150, 0.939, 0.850 },
	Gun_AK = { 0.061, 0.152, 0.939, 0.848 },
	Gun_Blaster = { 0.061, 0.223, 0.941, 0.777 },
	Gun_Deagle = { 0.061, 0.197, 0.939, 0.803 },
	Gun_Diamond = { 0.061, 0.223, 0.939, 0.777 },
	Gun_Minigun = { 0.061, 0.248, 0.939, 0.752 },
	Gun_Pistol = { 0.061, 0.145, 0.939, 0.855 },
	Gun_Revolver = { 0.061, 0.139, 0.939, 0.861 },
	Gun_Shotgun = { 0.061, 0.133, 0.939, 0.867 },
	Gun_Tommy = { 0.061, 0.154, 0.939, 0.848 },
	Gun_Uzi = { 0.061, 0.102, 0.939, 0.898 },
	Lucky = { 0.111, 0.061, 0.891, 0.939 },
	Muscle = { 0.061, 0.078, 0.939, 0.922 },
	PVP = { 0.154, 0.061, 0.844, 0.939 },
	PotionGold = { 0.086, 0.061, 0.912, 0.939 },
	PotionRed = { 0.086, 0.061, 0.912, 0.939 },
	Power = { 0.061, 0.078, 0.939, 0.922 },
	PowerLarge = { 0.061, 0.244, 0.939, 0.756 },
	PowerMedium = { 0.061, 0.156, 0.941, 0.844 },
	PowerPack1 = { 0.061, 0.078, 0.939, 0.922 },
	PowerPack2 = { 0.061, 0.078, 0.939, 0.922 },
	PowerPack3 = { 0.061, 0.078, 0.939, 0.922 },
	PowerSmall = { 0.125, 0.061, 0.875, 0.939 },
	PowerTiny = { 0.061, 0.152, 0.939, 0.848 },
	ProBay = { 0.105, 0.061, 0.895, 0.939 },
	Quest = { 0.061, 0.092, 0.939, 0.908 },
	Rebirth = { 0.061, 0.068, 0.939, 0.932 },
	RebirthSkip = { 0.061, 0.068, 0.939, 0.932 },
	Rewards = { 0.061, 0.092, 0.939, 0.908 },
	Robux = { 0.104, 0.061, 0.895, 0.939 },
	Search = { 0.061, 0.092, 0.939, 0.908 },
	Shield = { 0.105, 0.061, 0.893, 0.939 },
	ShoeBox = { 0.061, 0.168, 0.941, 0.832 },
	ShoePile = { 0.061, 0.135, 0.939, 0.865 },
	Shoe_AstroCrown = { 0.145, 0.039, 0.855, 0.961 },
	Shoe_BlockRoyalty = { 0.070, 0.039, 0.930, 0.961 },
	Shoe_Checkmate = { 0.059, 0.039, 0.941, 0.961 },
	Shoe_ChromeKicks = { 0.062, 0.039, 0.938, 0.961 },
	Shoe_DripTag = { 0.055, 0.039, 0.945, 0.961 },
	Shoe_FreshCanvas = { 0.045, 0.039, 0.955, 0.961 },
	Shoe_GoldenHour = { 0.055, 0.039, 0.945, 0.961 },
	Shoe_Hologram = { 0.150, 0.039, 0.850, 0.961 },
	Shoe_Masterpiece = { 0.070, 0.039, 0.930, 0.961 },
	Shoe_MidnightChrome = { 0.059, 0.039, 0.941, 0.961 },
	Shoe_NeonBomb = { 0.062, 0.039, 0.938, 0.961 },
	Shoe_PaintSplash = { 0.059, 0.039, 0.941, 0.961 },
	Shoe_PlatinumWings = { 0.168, 0.039, 0.832, 0.961 },
	Shoe_RainbowDrip = { 0.062, 0.039, 0.938, 0.961 },
	Shoe_RedRocket = { 0.055, 0.039, 0.945, 0.961 },
	Shoe_SilverStreak = { 0.055, 0.039, 0.945, 0.961 },
	Shoe_SolarFlare = { 0.154, 0.039, 0.846, 0.961 },
	Shoe_SprayTag = { 0.045, 0.039, 0.955, 0.961 },
	Shoe_Starlight = { 0.059, 0.039, 0.941, 0.961 },
	Shoe_StreetAngel = { 0.156, 0.039, 0.844, 0.961 },
	Shoe_TheGrail = { 0.164, 0.039, 0.836, 0.961 },
	Shoe_WildStyle = { 0.064, 0.039, 0.936, 0.961 },
	Shop = { 0.084, 0.061, 0.918, 0.939 },
	Skull = { 0.068, 0.061, 0.930, 0.939 },
	Sneaker = { 0.061, 0.160, 0.941, 0.840 },
	TenXCash = { 0.066, 0.061, 0.934, 0.939 },
	TripleOpen = { 0.061, 0.184, 0.941, 0.816 },
	Trophy = { 0.061, 0.117, 0.939, 0.883 },
	VIP = { 0.061, 0.111, 0.939, 0.889 },
	World = { 0.062, 0.061, 0.936, 0.939 },
	XP = { 0.100, 0.061, 0.902, 0.939 },
}
-- (brief 25) The PNGs with text baked into the picture: id -> that text. The Store skips its own sticker ('2x', 'x100')
-- while a PNG whose text is that sticker shows, so a card never carries the label twice ('$' on money or a box's name
-- plate is not a sticker). Kept up to date by hood/tools/import_icons.py (hood/art/incoming/labels.txt) for imported
-- pictures; set by hand for rendered ones.
M.Labelled = {
	Cash = '$',
	CashLarge = '$',
	CashMedium = '$',
	CashSmall = '$',
	CashTiny = '$',
	DoubleCash = '$',
	TenXCash = '$',
	XP = 'XP',
}
M.BoxLidLine = 0.619
-- per box (each Box_<id> PNG has its own framing; the lid's bottom edge runs from the median to the front corner):
-- prefer the BoxLid_<id> / BoxBase_<id> PNGs, which split it exactly
M.BoxLidLines = { Street = 0.619, Graffiti = 0.619, Exclusive = 0.619, Grail = 0.6 }

local FAMILIES = { '^Shoe_', '^Box_', '^Gun_' }
function M.has(id: string): boolean
	local image = M.Images[id]
	if type(image) == 'string' and image ~= '' then return true end
	if M.Fallback[id] ~= nil then return true end
	for _, pattern in FAMILIES do
		if string.match(id, pattern) then return true end
	end
	return false
end

return M
