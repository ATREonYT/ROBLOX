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
	Shop = 'rbxassetid://88763591212363', -- Shop
	Rebirth = 'rbxassetid://91291937266649', -- Rebirth
	Rewards = 'rbxassetid://127464825908096', -- Rewards
	PVP = 'rbxassetid://91160541119904', -- PVP
	Evolve = 'rbxassetid://99938416713950', -- Evolve
	Cash = 'rbxassetid://136985583204634', -- Cash
	Power = 'rbxassetid://126162449468622', -- Power
	Trophy = 'rbxassetid://89581521738339', -- Trophy
	Gun = 'rbxassetid://130835467144112', -- Gun
	Muscle = 'rbxassetid://128476938637097', -- Muscle
	Basket = 'rbxassetid://97661865614325', -- Basket
	BasketRed = 'rbxassetid://104437860061358', -- BasketRed
	Quest = 'rbxassetid://77316945060927', -- Quest
	Sneaker = 'rbxassetid://135466846742352', -- Sneaker
	Robux = 'rbxassetid://125635995204176', -- Robux
	Shield = 'rbxassetid://116985031620734', -- Shield
	XP = 'rbxassetid://91607418722312', -- XP
	Skull = 'rbxassetid://86893544603085', -- Skull
	VIP = 'rbxassetid://77787816163473', -- VIP
	AutoFight = 'rbxassetid://83178241825686', -- AutoFight
	Arrow = 'rbxassetid://113407110908103', -- Arrow
	RebirthSkip = 'rbxassetid://82173776211195', -- RebirthSkip
	DoublePower = 'rbxassetid://126746631874297', -- DoublePower
	World = 'rbxassetid://140610810001647', -- World
	Backpack = 'rbxassetid://137087037234595', -- Backpack
	ShoePile = 'rbxassetid://127716319325217', -- ShoePile
	ShoeBox = 'rbxassetid://106008920620916', -- ShoeBox
	Delete = 'rbxassetid://90704694594344', -- Delete
	Favorite = 'rbxassetid://84569375661347', -- Favorite
	Search = 'rbxassetid://140515423369563', -- Search
	PotionRed = 'rbxassetid://93676996166584', -- PotionRed
	PotionGold = 'rbxassetid://109176537086690', -- PotionGold
	BoostBundle = 'rbxassetid://77574171737630', -- BoostBundle
	CashTiny = 'rbxassetid://94026771497381', -- CashTiny
	CashSmall = 'rbxassetid://99820370965902', -- CashSmall
	CashMedium = 'rbxassetid://106947736679939', -- CashMedium
	CashLarge = 'rbxassetid://140712609671424', -- CashLarge
	PowerTiny = 'rbxassetid://110284810437230', -- PowerTiny
	PowerSmall = 'rbxassetid://83126902062971', -- PowerSmall
	PowerMedium = 'rbxassetid://124023829354542', -- PowerMedium
	PowerLarge = 'rbxassetid://120004850531354', -- PowerLarge
	PowerPack1 = 'rbxassetid://120597979511657', -- PowerPack1
	PowerPack2 = 'rbxassetid://99607859615615', -- PowerPack2
	PowerPack3 = 'rbxassetid://112656632981265', -- PowerPack3
	DoubleCash = 'rbxassetid://123747476693871', -- DoubleCash
	Shoe_FreshCanvas = 'rbxassetid://75052011743908', -- Shoe_FreshCanvas
	Shoe_RedRocket = 'rbxassetid://98997647794820', -- Shoe_RedRocket
	Shoe_Checkmate = 'rbxassetid://109927536832492', -- Shoe_Checkmate
	Shoe_ChromeKicks = 'rbxassetid://80562637701751', -- Shoe_ChromeKicks
	Shoe_StreetAngel = 'rbxassetid://123300481924622', -- Shoe_StreetAngel
	Shoe_BlockRoyalty = 'rbxassetid://73737965260577', -- Shoe_BlockRoyalty
	Shoe_SprayTag = 'rbxassetid://104145740853705', -- Shoe_SprayTag
	Shoe_DripTag = 'rbxassetid://132035871344658', -- Shoe_DripTag
	Shoe_PaintSplash = 'rbxassetid://98087002365304', -- Shoe_PaintSplash
	Shoe_NeonBomb = 'rbxassetid://115022055454236', -- Shoe_NeonBomb
	Shoe_WildStyle = 'rbxassetid://124689082649027', -- Shoe_WildStyle
	Shoe_Masterpiece = 'rbxassetid://81321012768391', -- Shoe_Masterpiece
	Shoe_SilverStreak = 'rbxassetid://124467509587323', -- Shoe_SilverStreak
	Shoe_MidnightChrome = 'rbxassetid://84294030658280', -- Shoe_MidnightChrome
	Shoe_RainbowDrip = 'rbxassetid://86828715159592', -- Shoe_RainbowDrip
	Shoe_Hologram = 'rbxassetid://94374116061635', -- Shoe_Hologram
	Shoe_PlatinumWings = 'rbxassetid://119869497003002', -- Shoe_PlatinumWings
	Shoe_GoldenHour = 'rbxassetid://121190330020020', -- Shoe_GoldenHour
	Shoe_Starlight = 'rbxassetid://73226830216155', -- Shoe_Starlight
	Shoe_SolarFlare = 'rbxassetid://118075171852401', -- Shoe_SolarFlare
	Shoe_AstroCrown = 'rbxassetid://117230132947745', -- Shoe_AstroCrown
	Shoe_TheGrail = 'rbxassetid://105845925530005', -- Shoe_TheGrail
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
	Box_Street = 'rbxassetid://111760592874889', -- Box_Street
	Box_Graffiti = 'rbxassetid://83004407352966', -- Box_Graffiti
	Box_Exclusive = 'rbxassetid://74134054354957', -- Box_Exclusive
	Box_Grail = 'rbxassetid://110300251209095', -- Box_Grail
	Box_Frost = '', -- Box_Frost
	Box_Lava = '', -- Box_Lava
	Box_Toxic = '', -- Box_Toxic
	Box_Candy = '', -- Box_Candy
	Box_Ocean = '', -- Box_Ocean
	Box_Gem = '', -- Box_Gem
	Box_Galaxy = '', -- Box_Galaxy
	Box_Gold = '', -- Box_Gold
	Lucky = 'rbxassetid://112424841860537', -- Lucky
	TripleOpen = 'rbxassetid://125193263908315', -- TripleOpen
	ExtraEquip = 'rbxassetid://81254049599880', -- ExtraEquip
	TenXCash = 'rbxassetid://120293885026484', -- TenXCash
	ProBay = 'rbxassetid://139829268002634', -- ProBay
	GoldBay = 'rbxassetid://106991311205061', -- GoldBay
	BlockParty = 'rbxassetid://121225031752640', -- BlockParty
	Gun_Pistol = 'rbxassetid://127067094321830', -- Gun_Pistol
	Gun_Revolver = 'rbxassetid://79327957074248', -- Gun_Revolver
	Gun_Uzi = 'rbxassetid://130444937436351', -- Gun_Uzi
	Gun_Shotgun = 'rbxassetid://110383453307044', -- Gun_Shotgun
	Gun_Tommy = 'rbxassetid://71795541172198', -- Gun_Tommy
	Gun_AK = 'rbxassetid://115893068324758', -- Gun_AK
	Gun_Deagle = 'rbxassetid://73060512009589', -- Gun_Deagle
	Gun_Minigun = 'rbxassetid://122767406956364', -- Gun_Minigun
	Gun_Blaster = 'rbxassetid://84183281310413', -- Gun_Blaster
	Gun_Diamond = 'rbxassetid://72692185187607', -- Gun_Diamond
	BoxLid_Street = 'rbxassetid://96246243278711', -- BoxLid_Street
	BoxLid_Graffiti = 'rbxassetid://113027237968442', -- BoxLid_Graffiti
	BoxLid_Exclusive = 'rbxassetid://72076921420262', -- BoxLid_Exclusive
	BoxLid_Grail = 'rbxassetid://92580122866879', -- BoxLid_Grail
	BoxBase_Street = 'rbxassetid://98851029499570', -- BoxBase_Street
	BoxBase_Graffiti = 'rbxassetid://95842461433149', -- BoxBase_Graffiti
	BoxBase_Exclusive = 'rbxassetid://109746922054001', -- BoxBase_Exclusive
	BoxBase_Grail = 'rbxassetid://107078897492882', -- BoxBase_Grail
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
	Shoe_AstroCrown = { 0.041, 0.168, 0.955, 0.824 },
	Shoe_BlockRoyalty = { 0.033, 0.102, 0.963, 0.891 },
	Shoe_Checkmate = { 0.049, 0.158, 0.947, 0.832 },
	Shoe_ChromeKicks = { 0.043, 0.150, 0.953, 0.838 },
	Shoe_DripTag = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_FreshCanvas = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_GoldenHour = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_Hologram = { 0.043, 0.178, 0.953, 0.814 },
	Shoe_Masterpiece = { 0.033, 0.141, 0.963, 0.848 },
	Shoe_MidnightChrome = { 0.049, 0.158, 0.947, 0.832 },
	Shoe_NeonBomb = { 0.043, 0.150, 0.953, 0.838 },
	Shoe_PaintSplash = { 0.049, 0.158, 0.947, 0.832 },
	Shoe_PlatinumWings = { 0.043, 0.186, 0.953, 0.805 },
	Shoe_RainbowDrip = { 0.043, 0.150, 0.953, 0.838 },
	Shoe_RedRocket = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_SilverStreak = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_SolarFlare = { 0.043, 0.135, 0.953, 0.857 },
	Shoe_SprayTag = { 0.061, 0.170, 0.939, 0.828 },
	Shoe_Starlight = { 0.049, 0.158, 0.947, 0.832 },
	Shoe_StreetAngel = { 0.043, 0.178, 0.953, 0.814 },
	Shoe_TheGrail = { 0.041, 0.184, 0.955, 0.809 },
	Shoe_WildStyle = { 0.037, 0.146, 0.959, 0.844 },
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
