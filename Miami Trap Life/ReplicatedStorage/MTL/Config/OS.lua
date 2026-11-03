--!strict
-- Liberty OS: the desk PC (vault: Research/Desk Computer Empire.md §4). DeskController (client) does the
-- sit-down and the camera; Controllers/OS/LibertyOS draws the screen; DeskService (server) owns who is seated
-- and routes every OS button (remote OSRequest) to the app's server handler, which re-checks everything.
local C = Color3.fromRGB

local OS = {}

-- The look: Alex's palette (UI Art Direction - Lessons, Nov 2 update). Dark grey panels, white text, green only
-- on money, gold for level, soft blue for "selected". 2 px corners, hairline borders, motion over decoration.
OS.Look = {
	Panel = C(24, 25, 29),
	Panel2 = C(32, 33, 38),
	Panel3 = C(42, 44, 50),
	Line = C(255, 255, 255),
	LineT = 0.88,
	Text = C(240, 238, 234),
	Dim = C(150, 150, 156),
	Money = C(92, 196, 104),
	Loss = C(232, 84, 84),
	Gold = C(240, 192, 72),
	Select = C(96, 170, 255),
	Warn = C(255, 170, 60),
	Corner = UDim.new(0, 2),
	Head = Enum.Font.Oswald,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Mono = Enum.Font.RobotoMono,
	-- wallpaper: Liberty at dusk (gradient + a skyline drawn from frames)
	WallTop = C(46, 36, 72),
	WallMid = C(196, 92, 84),
	WallLow = C(240, 150, 90),
	WallBottom = C(30, 26, 40),
	Wallpaper = "rbxassetid://0", -- TODO(Alex art): a real wallpaper image; 0 = the drawn one
}

-- The sit-down (seconds). Reduced Motion (Settings) skips the push-in.
OS.Desk = {
	PromptHold = 0.25,
	WalkUp = 0.35, -- root eases to the stand point beside the chair
	ChairOut = 0.3, -- chair slides back
	ChairBack = 1.2, -- studs
	ChairTurn = 15, -- degrees
	Sit = 0.55, -- root eases down onto the seat, SitType pose blends in
	ChairIn = 0.35,
	CamShoulder = 0.7, -- player camera -> over the shoulder (Quint Out)
	CamPush = 0.55, -- over the shoulder -> screen fills the frame (Sine InOut)
	FovShoulder = 60,
	FovScreen = 40,
	HandOff = 0.18, -- the full-screen OS fades in over the monitor
	Exit = 0.45, -- the pull-back
	ShoulderOffset = Vector3.new(2.3, 2.6, 3.6), -- camera, relative to the chair spot (room space: +X right, +Z behind)
	MaxDistance = 9, -- studs from the screen; the server stands you up past this
}

-- Apps in desktop order. gate: level / stage / path / own (a Realty property id) / any = list of those.
-- server = the DeskService handler module (ServerScriptService/MTL/Services/<server>), nil = client-only.
OS.Apps = {
	{ id = "Mail", title = "Mail", glyph = "@", color = C(96, 170, 255), gate = {} },
	{ id = "Bank", title = "Bank", glyph = "$", color = C(92, 196, 104), gate = {}, server = "BankService" },
	{ id = "Home", title = "Home", glyph = "⌂", color = C(240, 192, 72), gate = { level = 6 }, server = "HomeUpgrades" },
	{ id = "CoinBay", title = "CoinBay", glyph = "◎", color = C(255, 72, 104), gate = { level = 8 }, server = "CoinService" },
	{ id = "Realty", title = "Royce Realty", glyph = "▦", color = C(200, 170, 120), gate = { level = 10 }, server = "RealtyService" },
	{ id = "Freight", title = "Freight", glyph = "▣", color = C(255, 140, 60), gate = { level = 10, own = { "EndsLockup", "WynwoodWarehouse", "PortWarehouse" } }, server = "FreightService" },
	{ id = "ReUp", title = "The Re-Up", glyph = "◆", color = C(180, 110, 255), gate = { level = 12, path = "Criminal", own = { "StashHouse", "SecondStash" } }, server = "ReUpService" },
	{ id = "Clout", title = "Clout", glyph = "✦", color = C(255, 46, 99), gate = {}, external = true }, -- the social thread owns it: OS/Apps/Clout.lua mounts Apps/Clout (wide) · Config/Social
}

-- Home app: the flat's upgrade tiers (BuildFlatInterior folders carry MinTier/MaxTier; PropertyService prunes by
-- Home.Tier). Each line is what the player sees change, so the shop reads like a real before/after.
OS.Home = {
	Tiers = {
		[0] = { title = "As you found it", price = 0, level = 1, lines = { "Pallet bed, a CRT and a cracked monitor", "Peeling paint, boarded window, trash" } },
		[1] = { title = "Clean up", price = 400, level = 6, lines = { "Trash out, window unboarded, blinds up", "A real mattress, a rug, a plant that's still alive" } },
		[2] = { title = "Fixed up", price = 2500, level = 9, lines = { "Fresh paint and an accent wall", "Flat TV, a proper bed, curtains, prints, a coffee table", "Wide monitor and an LED strip on the desk" } },
		[3] = { title = "The setup", price = 8000, level = 12, lines = { "Dual monitors, RGB tower, gaming chair", "Neon sign, ceiling LEDs, sneaker wall, mini fridge" } },
	},
	Max = 3,
	XP = 80, -- per upgrade (2x pass applies through EconomyService.addXP)
	FadeSeconds = 0.6, -- the room re-dresses behind a short fade if you're inside
}

-- Bank app: move clean cash into the account (the crime thread decides what a robbery or a death can take from
-- Cash; the bank balance is never at risk). Recent = the last N money moves this session.
OS.Bank = { Recent = 25, MinMove = 1 }

-- One email per unlock: teaches the business and sets the GPS (button). Sent once (Desk.Mail[id] in the save).
OS.Mail = {
	Welcome = { from = "Liberty OS", subject = "Your PC is back on", body = "Power's on. Everything runs from here: your money, your home, and later your businesses. Apps unlock as you level up.", when = { } },
	CoinBay = { from = "Smoke", subject = "you seen these coins??", body = "Everybody on the block is on CoinBay. New coin every few minutes. Most of them rug. Watch the dev wallet: if it starts moving, GET OUT. Don't ape the first candle.", when = { app = "CoinBay" } },
	Home = { from = "Royce Properties", subject = "Making Flat 3B a home", body = "Tenants may now order improvements through the Home app. Royce Properties is happy to help. All improvements become property of the landlord at the end of your lease.", when = { app = "Home" } },
	Realty = { from = "Lionel Royce", subject = "A business proposition", body = "I hear you're doing well. Royce Realty has units across Vice Bay: lockups, warehouses, a few quiet houses. Good tenants become partners. Have a look.", when = { app = "Realty" } },
	Freight = { from = "Dez (Port of Vice Bay)", subject = "got a container with your name on it", body = "Heard you got a lockup. Ships come in every day. Sneakers, phones, bags, no paperwork. Buy a few crates off me, stack them up, and sell big: buyers pay way more per crate for a full load.", when = { app = "Freight" } },
	ReUp = { from = "Unknown number", subject = "re-up", body = "You got the space now. Order on the PC, grab the duffel at the docks, pack it at the stash. Put runners on corners when you're ready. Keep the heat low or they'll kick your door in.", when = { app = "ReUp" } },
}

return OS
