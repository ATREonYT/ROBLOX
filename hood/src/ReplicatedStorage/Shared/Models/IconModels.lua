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
M.Ids = { 'Shop', 'Rebirth', 'Rewards', 'PVP', 'Evolve', 'Cash', 'Power', 'Trophy', 'Gun', 'Muscle', 'Basket', 'BasketRed', 'Quest', 'Sneaker', 'Robux', 'Shield', 'XP', 'Skull', 'VIP', 'AutoFight', 'Arrow', 'RebirthSkip', 'DoublePower', 'World', 'Backpack', 'ShoePile', 'ShoeBox', 'Delete', 'Favorite', 'Search', 'PotionRed', 'PotionGold', 'BoostBundle', 'CashTiny', 'AutoCollect', 'CashSmall', 'CashMedium', 'CashLarge', 'PowerTiny', 'PowerSmall', 'PowerMedium', 'PowerLarge', 'PowerPack1', 'PowerPack2', 'PowerPack3', 'DoubleCash', 'Lucky', 'TripleOpen', 'ExtraEquip', 'TenXCash', 'ProBay', 'GoldBay', 'BlockParty', 'SpinWheel', 'SpinWheelDisc', 'PlaytimeGift', 'StarterCrate', 'Missions', 'SkinsPistol', 'Rank' }
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
	AutoCollect = '', -- AutoCollect
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
	Box_GrailBundle = '', -- Box_GrailBundle
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
	BoxLid_GrailBundle = '', -- BoxLid_GrailBundle
	BoxBase_Street = 'rbxassetid://98851029499570', -- BoxBase_Street
	BoxBase_Graffiti = 'rbxassetid://95842461433149', -- BoxBase_Graffiti
	BoxBase_Exclusive = 'rbxassetid://109746922054001', -- BoxBase_Exclusive
	BoxBase_Grail = 'rbxassetid://107078897492882', -- BoxBase_Grail
	BoxBase_GrailBundle = '', -- BoxBase_GrailBundle
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
	AutoCollect = { Color = Color3.fromRGB(226, 52, 60), Glyph = 'cash' }, -- (brief 32) the Auto Collect pad's magnet
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
	-- HUD30 BEGIN (brief 30, HUD: the soldier HUD's extras, drawn by hood/tools/draw/icons/Hud30.js)
	SpinWheel = { Color = Color3.fromRGB(255, 184, 26), Glyph = 'cycle' },
	SpinWheelDisc = { Color = Color3.fromRGB(255, 184, 26), Glyph = 'cycle' },
	PlaytimeGift = { Color = Color3.fromRGB(154, 62, 242), Glyph = 'gift', Accent = Color3.fromRGB(255, 196, 40) },
	StarterCrate = { Color = Color3.fromRGB(208, 140, 82), Glyph = 'box' },
	Missions = { Color = Color3.fromRGB(246, 215, 166), Glyph = 'scroll', Accent = Color3.fromRGB(216, 58, 58) },
	SkinsPistol = { Color = Color3.fromRGB(63, 106, 58), Glyph = 'gun' },
	Rank = { Color = Color3.fromRGB(196, 204, 216), Glyph = 'shield', Accent = Color3.fromRGB(255, 201, 40) },
	-- HUD30 END
}
-- (brief 25) Each PNG's drawn content: { x0, y0, x1, y1 } as fractions of the 512 canvas (alpha > 10%, top-left
-- origin), written by hood/tools/blender/icon_bounds.py after each render batch. UIKit places pictures by it.
M.Bounds = {
	Arrow = { 0.061, 0.068, 0.939, 0.932 },
	AutoCollect = { 0.049, 0.133, 0.951, 0.832 },
	AutoFight = { 0.082, 0.049, 0.973, 0.986 },
	AutoOpen = { 0.070, 0.049, 0.918, 0.975 },
	Backpack = { 0.064, 0.061, 0.936, 0.939 },
	Basket = { 0.084, 0.061, 0.918, 0.939 },
	BasketRed = { 0.061, 0.098, 0.941, 0.902 },
	BlockParty = { 0.076, 0.061, 0.922, 0.939 },
	BoostBundle = { 0.061, 0.166, 0.939, 0.834 },
	BoxBase_Exclusive = { 0.104, 0.271, 0.894, 0.861 },
	BoxBase_Graffiti = { 0.102, 0.262, 0.896, 0.852 },
	BoxBase_Grail = { 0.074, 0.176, 0.926, 0.824 },
	BoxBase_GrailBundle = { 0.080, 0.253, 0.921, 0.864 },
	BoxBase_Street = { 0.096, 0.266, 0.902, 0.859 },
	BoxLid_Exclusive = { 0.074, 0.139, 0.926, 0.559 },
	BoxLid_Graffiti = { 0.074, 0.148, 0.926, 0.558 },
	BoxLid_Grail = { 0.132, 0.182, 0.892, 0.559 },
	BoxLid_GrailBundle = { 0.075, 0.136, 0.926, 0.564 },
	BoxLid_Street = { 0.074, 0.141, 0.926, 0.557 },
	BoxOpen_Exclusive = { 0.126, 0.074, 0.874, 0.926 },
	BoxOpen_Graffiti = { 0.131, 0.074, 0.869, 0.926 },
	BoxOpen_Grail = { 0.102, 0.074, 0.897, 0.926 },
	BoxOpen_GrailBundle = { 0.129, 0.074, 0.871, 0.925 },
	BoxOpen_Street = { 0.127, 0.074, 0.873, 0.926 },
	Box_Exclusive = { 0.074, 0.139, 0.926, 0.861 },
	Box_Graffiti = { 0.074, 0.148, 0.926, 0.852 },
	Box_Grail = { 0.074, 0.176, 0.926, 0.824 },
	Box_GrailBundle = { 0.075, 0.136, 0.926, 0.864 },
	Box_Street = { 0.074, 0.141, 0.926, 0.859 },
	Cash = { 0.061, 0.203, 0.939, 0.797 },
	CashBig = { 0.064, 0.148, 0.938, 0.832 },
	CashLarge = { 0.053, 0.096, 0.957, 0.900 },
	CashMedium = { 0.033, 0.090, 0.930, 0.871 },
	CashMega = { 0.041, 0.189, 0.957, 0.807 },
	CashSmall = { 0.078, 0.158, 0.922, 0.842 },
	CashTiny = { 0.088, 0.285, 0.912, 0.715 },
	Delete = { 0.086, 0.061, 0.914, 0.939 },
	DoubleCash = { 0.049, 0.104, 0.951, 0.859 },
	DoublePower = { 0.049, 0.133, 0.951, 0.855 },
	Evolve = { 0.061, 0.068, 0.939, 0.932 },
	ExtraEquip = { 0.027, 0.180, 0.951, 0.859 },
	Favorite = { 0.061, 0.072, 0.939, 0.928 },
	FeaturedBg_Grail = { 0.000, 0.000, 1.000, 1.000 },
	FeaturedBg_Sneaker = { 0.000, 0.000, 1.000, 1.000 },
	FeaturedBg_Street = { 0.000, 0.000, 1.000, 1.000 },
	GoldBay = { 0.209, 0.061, 0.791, 0.939 },
	Gun = { 0.061, 0.150, 0.939, 0.850 },
	Gun_AK = { 0.031, 0.188, 0.969, 0.812 },
	Gun_Blaster = { 0.031, 0.109, 0.996, 0.867 },
	Gun_Deagle = { 0.031, 0.096, 0.969, 0.889 },
	Gun_Diamond = { 0.004, 0.162, 0.969, 0.883 },
	Gun_Minigun = { 0.016, 0.234, 0.975, 0.766 },
	Gun_Pistol = { 0.031, 0.094, 0.969, 0.906 },
	Gun_Revolver = { 0.031, 0.148, 0.969, 0.852 },
	Gun_Shotgun = { 0.031, 0.164, 0.969, 0.836 },
	Gun_Tommy = { 0.031, 0.172, 0.969, 0.828 },
	Gun_Uzi = { 0.031, 0.082, 0.969, 0.918 },
	Lucky = { 0.092, 0.049, 0.896, 0.959 },
	Missions = { 0.061, 0.092, 0.941, 0.908 },
	Muscle = { 0.061, 0.078, 0.939, 0.922 },
	PVP = { 0.154, 0.061, 0.844, 0.939 },
	PlaytimeGift = { 0.061, 0.092, 0.939, 0.908 },
	PotionGold = { 0.086, 0.061, 0.912, 0.939 },
	PotionRed = { 0.086, 0.061, 0.912, 0.939 },
	Power = { 0.061, 0.078, 0.939, 0.922 },
	PowerBig = { 0.078, 0.240, 0.922, 0.822 },
	PowerLarge = { 0.064, 0.129, 0.949, 0.820 },
	PowerMedium = { 0.055, 0.166, 0.922, 0.834 },
	PowerMega = { 0.031, 0.215, 0.953, 0.797 },
	PowerPack1 = { 0.061, 0.078, 0.939, 0.922 },
	PowerPack2 = { 0.061, 0.078, 0.939, 0.922 },
	PowerPack3 = { 0.061, 0.078, 0.939, 0.922 },
	PowerSmall = { 0.088, 0.285, 0.912, 0.715 },
	PowerTiny = { 0.105, 0.258, 0.895, 0.742 },
	ProBay = { 0.105, 0.061, 0.895, 0.939 },
	Quest = { 0.061, 0.092, 0.939, 0.908 },
	Rank = { 0.062, 0.061, 0.936, 0.939 },
	Rebirth = { 0.061, 0.068, 0.939, 0.932 },
	RebirthSkip = { 0.061, 0.068, 0.939, 0.932 },
	Rewards = { 0.061, 0.092, 0.939, 0.908 },
	Robux = { 0.104, 0.061, 0.895, 0.939 },
	Search = { 0.061, 0.092, 0.939, 0.908 },
	ServerBoost = { 0.105, 0.020, 0.881, 0.973 },
	Shield = { 0.105, 0.061, 0.893, 0.939 },
	ShoeBox = { 0.061, 0.168, 0.941, 0.832 },
	ShoePile = { 0.061, 0.135, 0.939, 0.865 },
	Shoe_AstroCrown = { 0.075, 0.163, 0.926, 0.837 },
	Shoe_BlockRoyalty = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_Checkmate = { 0.075, 0.150, 0.926, 0.850 },
	Shoe_ChromeKicks = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_DripTag = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_FreshCanvas = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_GoldenHour = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_Hologram = { 0.075, 0.161, 0.925, 0.839 },
	Shoe_Masterpiece = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_MidnightChrome = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_NeonBomb = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_PaintSplash = { 0.075, 0.150, 0.926, 0.850 },
	Shoe_PlatinumWings = { 0.074, 0.161, 0.925, 0.839 },
	Shoe_RainbowDrip = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_RedRocket = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_SilverStreak = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_SolarFlare = { 0.075, 0.107, 0.926, 0.893 },
	Shoe_SprayTag = { 0.075, 0.150, 0.926, 0.850 },
	Shoe_Starlight = { 0.074, 0.150, 0.926, 0.850 },
	Shoe_StreetAngel = { 0.074, 0.162, 0.926, 0.838 },
	Shoe_TheGrail = { 0.075, 0.162, 0.926, 0.838 },
	Shoe_WildStyle = { 0.074, 0.150, 0.926, 0.850 },
	Shop = { 0.084, 0.061, 0.918, 0.939 },
	SkinsPistol = { 0.061, 0.150, 0.939, 0.850 },
	Skull = { 0.068, 0.061, 0.930, 0.939 },
	Sneaker = { 0.061, 0.160, 0.941, 0.840 },
	Speed2x = { 0.018, 0.127, 0.951, 0.873 },
	SpinWheel = { 0.062, 0.061, 0.936, 0.939 },
	SpinWheelDisc = { 0.062, 0.061, 0.936, 0.939 },
	StarterCrate = { 0.061, 0.123, 0.939, 0.875 },
	TenXCash = { 0.066, 0.061, 0.934, 0.939 },
	TripleOpen = { 0.100, 0.049, 0.902, 0.961 },
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
	AutoFight = 'AUTO', -- (brief 32: the pass icons rendered from the user's pad prizes carry their badge)
	AutoOpen = 'AUTO',
	Cash = '$',
	CashLarge = '$',
	CashMedium = '$',
	CashSmall = '$',
	CashTiny = '$',
	DoubleCash = '2x',
	DoublePower = '2x',
	ExtraEquip = '+1',
	Speed2x = '2x',
	TripleOpen = 'x3',
	TenXCash = '$',
	XP = 'XP',
}
M.BoxLidLine = 0.619
-- per box (each Box_<id> PNG has its own framing; the lid's bottom edge runs from the median to the front corner):
-- prefer the BoxLid_<id> / BoxBase_<id> PNGs, which split it exactly
M.BoxLidLines = { Street = 0.511, Graffiti = 0.524, Exclusive = 0.511, Grail = 0.535, GrailBundle = 0.538 }

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
