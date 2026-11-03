--!strict
-- The phone: apps, tuning, scripted calls, GPS places. Tune here; no phone system hard-codes these.
-- Contacts (names/subtitles) live in Config/Story.Contacts so the story owns who people are.
local Phone = {}

-- Home-screen apps, in order. `id` is what the server/save uses (Phone.Apps[id] = true means installed).
-- `module` = the client app module in StarterPlayerScripts/MTL/Apps. `default` = installed on a new save.
-- `glyph` is the placeholder icon letter until Alex's icons arrive (Theme.Phone.Icons[id]).
Phone.Apps = {
	{ id = "Messages", title = "Messages", glyph = "M", default = true },
	{ id = "Calls", title = "Phone", glyph = "P", default = true },
	{ id = "Jobs", title = "Jobs", glyph = "J", default = true },
	{ id = "Map", title = "GPS", glyph = "G", default = true },
	{ id = "Camera", title = "Camera", glyph = "C", default = true }, -- photos (CaptureService) + selfie mode
	{ id = "Settings", title = "Settings", glyph = "S", default = true },
	{ id = "Plug", title = "Plug", glyph = "$", default = false }, -- Guns piece: guns + ammo, criminal path only
	{ id = "Story", title = "Story", glyph = "S", default = true }, -- chapters, the current mission and the cast (attribute MTL_Story)
	{ id = "Money", title = "Money", glyph = "$", default = true }, -- every way to earn, with pay, cooldown and GPS (Config/Earn)
	{ id = "Garage", title = "Garage", glyph = "G", default = true }, -- spawn the cars you own (Config/Vehicles)
	{ id = "Clout", title = "Clout", glyph = "C", default = false }, -- the social app (Config/Social): posts, followers, deals, courses; unlocks at FreePlay
	{ id = "Goals", title = "Goals", glyph = "*", default = false }, -- Piece 4: the FreePlay goals list (unlocks at FreePlay)
}

Phone.Tuning = {
	DesignSize = Vector2.new(300, 620), -- phone in design pixels (everything inside is laid out for this)
	HeightOfScreen = 0.6, -- open phone height as a share of the screen height
	MinScale = 0.5,
	MaxScale = 1.25,
	Margin = 24, -- px from the right screen edge
	OpenBottom = 14, -- px from the bottom of the screen when open (low on screen)
	PeekShare = 0.07, -- share of the phone that sticks out when closed: just the top edge + time
	HoverShare = 0.11, -- on mouse hover
	PingShare = 0.22, -- when something arrives while closed; shows the banner
	PingSeconds = 3.5,
	TiltDegrees = 0, -- closed tilt (0 keeps the glass clipping clean)
	SpringOpenHz = 3.4, -- the phone moves on a spring: how fast it rises
	SpringOpenDamping = 0.72, -- < 1 = a small bounce at the top
	SpringCloseHz = 3.8, -- how fast it drops (no bounce)
	ToggleKeys = { Enum.KeyCode.M, Enum.KeyCode.DPadUp },
	SwipeClosePixels = 70, -- drag down this far on the top/bottom bar to close
	NotificationSeconds = 4,
	RingSeconds = 25, -- server: an unanswered call becomes "missed" after this
	MaxTextsPerThread = 60,
	MaxRecents = 30,
}

-- Scripted calls. The server rings with PhoneService.call(player, id); the client plays `lines` as captions
-- on the in-call screen (tap to advance, Skip), then shows `choices`. The server validates the choice id and
-- fires PhoneService.CallResolved(player, callId, choiceId). No choices -> resolves as "answered".
-- `callBack = true`: a missed/declined/hung-up call stays in Recents with a call-back button
-- (and after a choice with keepCallBack = true).
Phone.Calls = {
	Recruit = {
		contact = "Unknown",
		callBack = true,
		lines = {
			{ who = "Unknown", text = "You the one stacking shelves at Liberty?" },
			{ who = "Unknown", text = "Don't matter how I got the number. Eight bucks a box, that's what they pay you." },
			{ who = "Unknown", text = "I got people who make that in a minute. Real money." },
			{ who = "Unknown", text = "Come meet us. I'll send you the spot. Come alone." },
		},
		choices = {
			{ id = "accept", text = "I'm in" },
			{ id = "decline", text = "Not right now", keepCallBack = true }, -- stays in Recents to call back
		},
	},
}

-- Messages: canned replies the player can send in any thread (server checks the index), and what each contact
-- answers back (once a minute at most, after a short "typing" pause). Keep it short and in character.
Phone.QuickReplies = { "On my way", "Bet", "Who's this?", "Busy rn", "Say less", "Thanks" }
Phone.ReplyCooldown = 2.5 -- seconds between the player's replies
Phone.AutoReplyCooldown = 60 -- per contact
Phone.AutoReplies = {
	Patel = { "Less texting, more stacking.", "Shelves won't fill themselves!", "See you at the store." },
	Dre = { "Bet.", "Keep your head down.", "We'll hit you up." },
	Smoke = { "aight", "say less" },
	Nina = { "Don't text this number for dumb stuff.", "k." },
	Unknown = { "..." },
	default = { "👍" },
}

-- Contacts that never pick up when the player calls them (no scripted call): what the screen says.
Phone.NoAnswer = {
	default = "No answer",
	Patel = "Mr. Patel is busy. Text him instead.",
}

-- GPS places. `location` = a key in Config/Locations (the server resolves positions; the client never sends one).
-- `field` = which position inside that entry (Door by default). `requires` = story stage the player must have
-- reached before the place shows. `ownedHome = true` = only once the player owns a home.
Phone.Places = {
	{ id = "FoodMart", label = "Liberty Food Mart", location = "FoodMart", category = "Work" },
	{ id = "BurgerShack", label = "Burger Shack", location = "BurgerShack", category = "Work" },
	{ id = "WestsideAuto", label = "Westside Auto Repair", location = "WestsideAuto", category = "Work" },
	-- Level 8+ / 15+ job sites (Jobs piece). Shown once the player can pick their own job.
	{ id = "CarWash", label = "Bay Suds Car Wash", location = "CarWash", category = "Work", requires = "ChooseJob" },
	{ id = "Valet", label = "Coral Hotel", location = "Valet", category = "Work", requires = "ChooseJob" },
	{ id = "Security", label = "Bayside Mall", location = "Security", category = "Work", requires = "ChooseJob" },
	{ id = "TruckDepot", label = "Vice Bay Freight", location = "TruckDepot", category = "Work", requires = "ChooseJob" },
	{ id = "Docks", label = "Port of Vice Bay", location = "Docks", category = "Work", requires = "ChooseJob" },
	{ id = "Home", label = "Your place", location = "EndsFlat", category = "Home", requires = "FindAPlace" },
}

Phone.GPSWaypointId = "GPS" -- the GPS uses its own waypoint id so it never replaces the story waypoint

-- Jobs app shell: shown until the Jobs piece adds Config/Jobs.lua (then the app reads that instead).
Phone.JobsFallback = {
	{ id = "Supermarket", title = "Liberty Food Mart", role = "Stocker", pay = "$8 / task", level = 1, place = "FoodMart" },
	{ id = "Mechanic", title = "Westside Auto Repair", role = "Mechanic", pay = "$10 / task", level = 1, place = "WestsideAuto" },
	{ id = "Restaurant", title = "Burger Shack", role = "Cook", pay = "$9 / task", level = 1, place = "BurgerShack" },
}

-- Lifestyle switch (Settings). Opens from this stage on (StoryRules.freePlayOpen). Cooldown stops spam-flipping.
Phone.PathSwitchCooldown = 30
Phone.Paths = {
	Civilian = { title = "Civilian", blurb = "Work, earn, stay safe. No guns out, no PvP." },
	Criminal = { title = "Criminal", blurb = "Crew missions, guns out, PvP on. Watch your back." },
}

-- Settings the client may change (whitelist + type). Keys live in the save under Settings.
Phone.SettingKeys = {
	Music = "boolean",
	Sound = "boolean",
	ReducedMotion = "boolean",
	Tutorial = "number", -- TutorialController: how many tutorial steps are done (Config/Tutorial; 99 = skipped)
	Graphics = "number", -- QualityController: 0 Auto, 1 Low, 2 Med, 3 High (Config/Quality.Choices)
	-- HUD Settings panel (MenuController): volume % per SoundGroup (AudioMixer), sprint mode, keybind hints
	MusicVol = "number",
	SfxVol = "number",
	UIVol = "number",
	AmbVol = "number",
	SprintToggle = "boolean",
	KeyHintsMode = "number", -- 0 auto, 1 always, 2 never
	Shake = "number", -- camera shake % (CamShake, guns)
}

return Phone
