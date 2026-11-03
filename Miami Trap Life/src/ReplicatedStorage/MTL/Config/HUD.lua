--!strict
-- What the main HUD shows: the icon menu's buttons, the store and emote lists, and the map markers.
-- Look (colours, image ids) lives in Theme.HUD. Emoji are placeholders until Alex's icon art arrives.
local Locations = require(script.Parent.Locations)

local HUD = {}

-- Keys: open/close the icon menu. M is the phone, E is interact, 1-6 are the hotbar.
HUD.MenuKeys = { Enum.KeyCode.G, Enum.KeyCode.DPadLeft }

-- The icon menu (2 columns, in this order). `action` is handled in MenuController:
--   phone = PhoneController.toggle(); app = open that phone app; panel = open a HUD panel (Store / Emotes)
--   map = open the full-screen map (MinimapController.openMap)
-- `requires` = story stage needed first; `path` = only on that path.
HUD.Menu = {
	{ id = "Phone", label = "PHONE", emoji = "📱", hint = "M", action = "phone" },
	{ id = "Jobs", label = "JOBS", emoji = "💼", action = "app", app = "Jobs" },
	{ id = "Goals", label = "GOALS", emoji = "📜", action = "app", app = "Goals" },
	{ id = "Map", label = "MAP", emoji = "🗺️", hint = "N", action = "map" }, -- the full-screen map (MinimapController)
	{ id = "Store", label = "STORE", emoji = "🛒", action = "panel", panel = "Store" },
	{ id = "Emotes", label = "EMOTES", emoji = "🕺", action = "panel", panel = "Emotes" },
	{ id = "Plug", label = "PLUG", emoji = "🔌", action = "app", app = "Plug", path = "Criminal" },
	{ id = "Settings", label = "SETTINGS", emoji = "⚙️", action = "panel", panel = "Settings" },
}

-- The Store: tabs of big product cards. `item` is a name in Config/Monetization (Passes or Products); the price
-- is read live from Roblox once the id is set (0 = the card shows SOON). Buying goes through the phone's "buy"
-- action. `color` tints the card's art, `ribbon` is the little banner on the corner.
HUD.StoreTabs = {
	{ id = "Passes", label = "GAME PASSES" },
	{ id = "Boosts", label = "BOOSTS" },
}
HUD.Store = {
	{ tab = "Passes", item = "StarterPack", art = "$2,500", title = "Starter Pack", blurb = "$2,500 in your pocket from day one. Skip the broke phase.", emoji = "🎁", color = Color3.fromRGB(255, 72, 104), ribbon = "BEST VALUE" },
	{ tab = "Passes", item = "Cash2x", art = "2X $", title = "2x Cash", blurb = "Every job and every hustle pays double. Forever.", emoji = "💵", color = Color3.fromRGB(114, 214, 112), ribbon = "POPULAR" },
	{ tab = "Passes", item = "XP2x", art = "2X XP", title = "2x XP", blurb = "Level up twice as fast and unlock jobs sooner. Forever.", emoji = "⭐", color = Color3.fromRGB(255, 196, 64) },
	{ tab = "Boosts", item = "CashBoost", art = "30 MIN", title = "2x Cash · 30 min", blurb = "Double pay for 30 minutes of play. Buy more to stack time.", emoji = "⏱️", color = Color3.fromRGB(114, 214, 112) },
	{ tab = "Boosts", item = "XPBoost", art = "30 MIN", title = "2x XP · 30 min", blurb = "Double XP for 30 minutes of play. Buy more to stack time.", emoji = "⚡", color = Color3.fromRGB(255, 196, 64) },
}

-- Emotes come from the character's own Animate script (Roblox's default animations), so no ids live here.
-- `anim` = the Animate child, `pick` = the Animation inside it (nil = the first one).
HUD.Emotes = {
	{ id = "wave", label = "Wave", emoji = "👋", anim = "wave" },
	{ id = "point", label = "Point", emoji = "👉", anim = "point" },
	{ id = "cheer", label = "Cheer", emoji = "🙌", anim = "cheer" },
	{ id = "laugh", label = "Laugh", emoji = "😂", anim = "laugh" },
	{ id = "dance", label = "Dance", emoji = "🕺", anim = "dance" },
	{ id = "dance2", label = "Groove", emoji = "💃", anim = "dance2" },
	{ id = "dance3", label = "Shuffle", emoji = "🎶", anim = "dance3" },
}

-- Hotbar: slot 1 is always your fists (key 1 puts guns away), guns fill 2-6 in the order you own them.
HUD.Hotbar = {
	FistsEmoji = "👊",
	GunEmoji = "🔫", -- TODO(Alex art): per-gun icons go in Theme.HUD.Images["Gun_<id>"]
}

-- Map markers: round icons floating over places in the world (positions copied from the Vice Bay POIs).
-- Shown within `range` studs (default Markers.Range). `requires` = story stage needed first.
HUD.Markers = {
	Range = 650,
	Height = 16, -- studs above the spot
	Size = 46, -- px when close; shrinks to MinScale far away
	MinScale = 0.62,
	LabelRange = 140, -- name + distance always shown this close
	List = {
		-- the hood (Liberty / Westside)
		{ name = "Liberty Food Mart", emoji = "🏪", pos = Vector3.new(-1442, 4, -312) },
		{ name = "Burger Shack", emoji = "🍔", pos = Vector3.new(-1442, 4, -445) },
		{ name = "Westside Auto Repair", emoji = "🔧", pos = Vector3.new(-1015, 4, -445) },
		{ name = "Sunshine Gas", emoji = "⛽", pos = Vector3.new(-1297, 4, -883) },
		{ name = "Sudz Car Wash", emoji = "🧽", pos = Vector3.new(-1839.5, 4, -190) },
		{ name = "Lucky's Used Autos", emoji = "🚗", pos = Vector3.new(-1312, 4, -620) },
		{ name = "Liberty Park", emoji = "🌳", pos = Vector3.new(-1580, 4, -200) },
		{ name = "Fresh Cutz", emoji = "💈", pos = Vector3.new(-1837.5, 4, 445) },
		{ name = "Liberty Sound Studio", emoji = "🎙️", pos = Vector3.new(-1837.5, 4, 495) },
		{ name = "Westside Boxing", emoji = "🥊", pos = Vector3.new(-1841.5, 4, 345) },
		{ name = "Westside Courts", emoji = "🏀", pos = Vector3.new(-1879.5, 4, 115) },
		{ name = "Pickup Court", emoji = "🏀", pos = Vector3.new(-1720, 4, 662) },
		{ name = "Westside Car Meet", emoji = "🏁", pos = Vector3.new(-1881.5, 4, 710) },
		{ name = "Train Station", emoji = "🚆", pos = Vector3.new(-828, 8, -316) },
		{ name = "Your place", emoji = "🏠", pos = Locations.EndsFlat.Door, requires = "MoveIn" },
		-- midtown
		{ name = "Food Truck", emoji = "🌮", pos = Vector3.new(-480, 4, -650) },
		{ name = "Wynwood Walls", emoji = "🎨", pos = Vector3.new(-320, 4, -484) },
		{ name = "Creator House", emoji = "📸", pos = Vector3.new(-480, 4, -1018) },
		{ name = "Cafe La Habana", emoji = "☕", pos = Vector3.new(-480, 4, 625) },
		{ name = "Domino Park", emoji = "🌴", pos = Vector3.new(-320, 4, 719) },
		{ name = "Tower Theater", emoji = "🎬", pos = Vector3.new(-160, 4, 625) },
		{ name = "Bayside Central Park", emoji = "🌳", pos = Vector3.new(105, 4, -62) },
		{ name = "Hot Dog Cart", emoji = "🌭", pos = Vector3.new(132, 4, -59) },
		{ name = "SoHo Car Meet", emoji = "🏁", pos = Vector3.new(181, 4, -905) },
		{ name = "Lookout Hill", emoji = "⛰️", pos = Vector3.new(185, 26, -560) },
		{ name = "Stock Exchange", emoji = "📈", pos = Vector3.new(800, 8, -328) },
		{ name = "Brickell Station", emoji = "🚇", pos = Vector3.new(256, 5, -569) },
		{ name = "Bayfront Park Station", emoji = "🚇", pos = Vector3.new(256, 5, -147) },
		{ name = "Government Center", emoji = "🚇", pos = Vector3.new(256, 5, 257) },
		{ name = "Flagler Station", emoji = "🚇", pos = Vector3.new(864, 5, -329) },
		-- port and beach
		{ name = "Suncoast Freight", emoji = "🚚", pos = Vector3.new(-1150, 4, 1110) },
		{ name = "Port of Vice Bay", emoji = "⚓", pos = Vector3.new(-700, 4, 1110) },
		{ name = "Vice Bay Yachts", emoji = "⛵", pos = Vector3.new(1050, 5, 804) },
		{ name = "Beach Volleyball", emoji = "🏐", pos = Vector3.new(1560, 4, -280) },
		{ name = "Lifeguard HQ", emoji = "🛟", pos = Vector3.new(1600, 4, -100) },
		{ name = "Helados Stand", emoji = "🍦", pos = Vector3.new(1530, 4, -60) },
		{ name = "Pier Fishing", emoji = "🎣", pos = Vector3.new(1918, 6, -560) },
		-- other job spots (these replace the map's old "JOB" billboards)
		{ name = "Valet · Brickell", emoji = "🔑", pos = Vector3.new(829, 4, -532) },
		{ name = "Valet · Vice One", emoji = "🔑", pos = Vector3.new(611, 4, -716) },
		{ name = "Valet · Grand Bay Hotel", emoji = "🔑", pos = Vector3.new(1037, 4, -112) },
		{ name = "Yacht Club Bar", emoji = "🍸", pos = Vector3.new(1058, 5, 714) },
		{ name = "Boat Tours", emoji = "🚤", pos = Vector3.new(1082, 4, 980) },
		{ name = "Fisher Key Ferry", emoji = "⛴️", pos = Vector3.new(1450, 4, 1510) },
		{ name = "Salvage Diving", emoji = "🤿", pos = Vector3.new(-1110, 4, 1870) },
		{ name = "Star Island Gardens", emoji = "🌺", pos = Vector3.new(2420, 4, -830) },
		{ name = "Golf Club", emoji = "⛳", pos = Vector3.new(-4000, 4, -322), range = 1200 },
		-- far landmarks (seen from further away)
		{ name = "Vice Bay International", emoji = "✈️", pos = Vector3.new(-3240, 4, 1792), range = 2500 },
		{ name = "Coral Beach", emoji = "🏖️", pos = Vector3.new(-4800, 4, 300), range = 2000 },
		{ name = "Sol Raceway", emoji = "🏎️", pos = Vector3.new(-250, 4, -3300), range = 2000 },
	},
}

return HUD
