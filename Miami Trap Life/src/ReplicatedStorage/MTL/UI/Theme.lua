--!strict
-- Placeholder look for every MTL ScreenGui. Alex's art replaces this: swap colours/fonts here, or replace the
-- images in StarterGui directly. Controllers find elements by NAME, never by colour or position.
local C = Color3.fromRGB

return {
	Colors = {
		Glass = C(14, 16, 22), -- panels
		GlassTransparency = 0.18,
		Stroke = C(255, 255, 255),
		StrokeTransparency = 0.88,
		Text = C(245, 246, 250),
		TextDim = C(165, 170, 185),
		Accent = C(64, 220, 160), -- money green
		AccentAlt = C(120, 170, 255), -- XP blue
		Danger = C(255, 86, 96),
		Gold = C(255, 205, 80),
		Shadow = C(0, 0, 0),
	},
	Fonts = {
		Display = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
		Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
	},
	Corner = UDim.new(0, 10),
	CornerSmall = UDim.new(0, 6),
	Padding = 10,
	-- Built-in Roblox sounds only; "" = silent until Alex uploads our own (vault rule: never invent ids).
	Sounds = {
		Arrive = "rbxassetid://9125934750", -- Shop Door Bell Big Cowbell-Like Deeper Tone (PSE)
		LevelUp = "rbxassetid://105625891237078", -- short UI level-up (CoreKit); HUD plays Theme.Sfx.LevelUp
		Toast = "rbxassetid://9119669160", -- Suction Pop 6 (PSE)
	},
	-- The phone (Piece 1). Swap colours/images here or reskin MTL_Phone in StarterGui (keep element names).
	Phone = {
		Frame = C(18, 19, 24), -- the phone body / bezel
		FrameStroke = C(70, 74, 86),
		Screen = C(10, 11, 15),
		Wallpaper = "rbxassetid://0", -- TODO(Alex art): wallpaper image; 0 = gradient placeholder
		WallTop = C(38, 24, 82),
		WallBottom = C(12, 14, 22),
		Card = C(30, 32, 40),
		CardHover = C(40, 43, 54),
		Divider = C(255, 255, 255),
		Bubble = C(44, 47, 58), -- their messages
		BubbleMe = C(64, 220, 160), -- my messages
		BubbleMeText = C(10, 30, 22),
		Badge = C(255, 70, 80),
		Answer = C(52, 200, 110),
		Decline = C(235, 64, 70),
		BezelPadding = 8,
		-- Shape: a modern rounded phone (Alex: "a bit more round"). LowPoly = true swaps in the faceted look.
		LowPoly = false,
		ScreenCorner = UDim.new(0, 30),
		FrameCorner = UDim.new(0, 38),
		Corner = UDim.new(0, 12), -- cards and buttons inside the phone
		IconCorner = UDim.new(0, 14), -- home-screen app icons
		FrameEdge = C(8, 8, 11), -- (low-poly only) the slab's side
		FacetLight = 0.10, -- (low-poly only)
		FacetDark = 0.12, -- (low-poly only)
		Rim = C(120, 126, 142), -- the metal band round the body
		-- Placeholder wallpaper until Alex's art: Miami sunset gradient + a striped retro sun
		WallMid = C(196, 64, 128),
		WallLow = C(255, 150, 86),
		Sun = { C(255, 226, 120), C(255, 96, 140) },
		GlassTint = C(255, 255, 255), -- frosted widgets/dock (with GlassAlpha transparency)
		GlassAlpha = 0.82,
		-- icon glyphs until Alex's icon art (emoji render in colour on Roblox)
		Glyphs = {
			Messages = "💬",
			Calls = "📞",
			Jobs = "💼",
			Map = "🧭",
			Camera = "📷",
			Settings = "🔧", -- (⚙️ renders blank on Roblox)
			Plug = "🛒",
			Goals = "⭐",
			Clout = "✨",
		},
		-- apps in the dock along the bottom of the home screen (the rest sit in the grid)
		Dock = { "Messages", "Calls", "Map", "Camera" },
		-- per-app icon tile colour (placeholder) and image (TODO(Alex art): icon ids; 0 = coloured tile + glyph)
		AppColors = {
			Messages = C(64, 200, 120),
			Calls = C(60, 170, 255),
			Jobs = C(255, 170, 60),
			Map = C(120, 110, 255),
			Settings = C(120, 126, 140),
			Plug = C(235, 64, 70), -- Guns piece
			Goals = C(255, 205, 80), -- Piece 4
			Clout = C(255, 46, 99), -- the social app
			Camera = C(46, 48, 58),
		},
		Icons = {
			Messages = "rbxassetid://0",
			Calls = "rbxassetid://0",
			Jobs = "rbxassetid://0",
			Map = "rbxassetid://0",
			Settings = "rbxassetid://0",
			Plug = "rbxassetid://0",
			Goals = "rbxassetid://0",
			Camera = "rbxassetid://0",
		},
		Sounds = {
			-- unused: the phone plays Theme.Sfx Phone* sounds now
			Ring = "",
			Text = "",
			Open = "", -- TODO(Alex sfx)
			Close = "",
			Tap = "",
		},
	},
	-- Jobs (Piece 2): the job panel, minigames, shift cards and world FX. Reskin MTL_Job in StarterGui (keep names).
	Job = {
		Zone = C(64, 220, 160), -- timing bar green zone
		Track = C(40, 43, 54),
		Needle = C(255, 255, 255),
		Hit = C(64, 220, 160),
		Miss = C(255, 86, 96),
		Perfect = C(255, 205, 80),
		Marker = C(240, 192, 72), -- the glow on the station you need to go to (= UI/Guide colour)
		Spill = C(120, 190, 255),
		Products = { C(235, 80, 70), C(255, 200, 70), C(70, 170, 255), C(90, 210, 120), C(240, 240, 240) },
		-- Built-in Roblox sounds as placeholders. TODO(Alex sfx): our own uploads.
		Sounds = {
			Prompt = "rbxassetid://10128760939", -- RBLX UI Select 01 (Roblox)
			Hit = "rbxassetid://10066968815", -- RBLX UI Select 02 (Roblox), pitched up per streak
			Miss = "rbxassetid://80099403859001", -- UI - Error (SodaBreadle)
			Done = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)
			Mop = "rbxasset://sounds/impact_water.mp3",
			Slam = "rbxasset://sounds/hit.wav",
			Whoosh = "rbxasset://sounds/swoosh.wav",
		},
		Icons = { ActionButton = "rbxassetid://0" }, -- TODO(Alex art)
	},
	-- Cutscenes (Piece 3): letterbox, subtitles, skip, title card. Reskin MTL_Cutscene in StarterGui (keep names).
	Cutscene = {
		Bar = C(0, 0, 0),
		BarShare = 0.11, -- letterbox bar height, share of the screen
		Fade = C(0, 0, 0),
		SubtitleText = C(245, 246, 250),
		SubtitleShadow = C(0, 0, 0),
		SpeakerDefault = C(64, 220, 160),
		-- speaker name colour per character id (Config/Story.Contacts ids); others use SpeakerDefault
		Speakers = {
			Dre = C(255, 96, 96),
			Smoke = C(220, 220, 228),
			Nina = C(190, 140, 255),
			Kev = C(90, 210, 140),
			Patel = C(255, 205, 80),
			Unknown = C(165, 170, 185),
			You = C(245, 246, 250), -- Piece 4: your own thoughts
			Rico = C(120, 170, 255),
			Tasha = C(255, 150, 90),
			Royce = C(222, 205, 160), -- Act 2: cream, like his suit
		},
		SkipFill = C(255, 255, 255),
		TitleColor = C(255, 255, 255),
		TitleSub = C(255, 205, 80),
		Sounds = {
			Title = "rbxassetid://9116329674", -- Low Impacts 1 (PSE)
			Skip = "rbxasset://sounds/swoosh.wav",
			Tick = "", -- typewriter blip (off by default)
			-- Piece 4 (the flat). Built-in placeholders; TODO(Alex sfx): PC click, keyboard smash, bed creak, alarm.
			Click = "rbxassetid://9120232133", -- Trackball Mouse Clicking 4 (PSE)
			Keys = "rbxassetid://9116154054", -- Keyboard Typing 14 (PSE)
			BedCreak = "",
			Alarm = "rbxassetid://9113087676", -- Alarm Clock 1 (PSE)
			RoomTone = "", -- TODO(Alex sfx): fridge hum / street noise through the window
			-- welcome scenes (Research: Cinematic Cutscenes §6). TODO(Alex sfx): a calm Miami track + city bed
			-- Roblox-licensed library audio (APM Music / Pro Sound Effects: free in every experience). Picked from the
			-- Creator Store by description, not by ear: Alex, swap for tracks you like.
			WelcomeMusic = "rbxassetid://9045798330", -- APM "Bonded (a 60)": hip hop / trip hop, serious drum groove
			City = "rbxassetid://9112888010", -- PSE "Traffic Ca 3": busy street, honks, birds, people (loop)
			CrewMusic = "rbxassetid://1838985214", -- APM "Hunted Suspect": dramatic urban drums, rhythmic (the crew intro)
			StoreBell = "rbxassetid://9125934750", -- the shop door bell (same as Theme.Sounds.Arrive)
		},
	},
	-- The tutorial coach (TutorialController, MTL_Tutorial). Reskin in StarterGui, keep element names.
	Tutorial = {
		-- same plain palette as the HUD (Theme.HUD): dark grey card, white text, gold = "look here" (UI/Guide)
		Card = C(24, 25, 29),
		CardTransparency = 0.12,
		Accent = C(245, 245, 245), -- done dots, "Got it", the tick: plain white like the HUD's text (Alex 2026-11-03:
		-- "the colours give it away that it's AI": gold is only for the ring and the world cues now)
		Key = C(245, 245, 245), -- key chip background
		KeyText = C(24, 25, 29),
		Dim = C(165, 168, 175),
		Ring = C(240, 192, 72), -- the ring around what the card talks about (= Guide.Color)
	},
	-- Missions (Piece 3): tracker, hold prompt, aim meter, alarm, crew barks, payout + offer. Reskin MTL_Mission.
	Mission = {
		Accent = C(255, 96, 96), -- criminal red (the job panel uses money green)
		Done = C(64, 220, 160),
		Pending = C(165, 170, 185),
		Meter = C(255, 205, 80),
		Alarm = C(255, 40, 60),
		Dim = C(0, 0, 0),
		DimTransparency = 0.35,
		Card = C(18, 19, 24),
		Tile = C(30, 32, 40),
		TileHighlight = C(255, 205, 80),
		Hazard = C(255, 160, 40), -- the crew car's hazard lights
		Sounds = {
			Step = "rbxassetid://10066968815", -- RBLX UI Select 02 (Roblox)
			Alarm = "rbxassetid://9113085203", -- Alarm Bell On Hard Surface 2 (PSE), store alarm loop
			Cash = "rbxassetid://9113849651", -- Coin Throws 3 (PSE), payout count tick
			Done = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)
			Door = "", -- TODO(Alex sfx): car door
			Engine = "", -- TODO(Alex sfx): engine pull-away
			Ambience = "rbxassetid://9112819963", -- PSE "Las Vegas Night Traffic 1": night traffic wash, distant voices (loop)
		},
		Icons = { Pass = "rbxassetid://0", Boost = "rbxassetid://0" }, -- TODO(Alex art)
	},
	-- Guns (Piece 5): crosshair, hitmarker, ammo panel, weapon bar, touch buttons, world FX. Reskin MTL_Gun (keep names).
	Gun = {
		Crosshair = C(255, 255, 255),
		CrosshairShadow = C(0, 0, 0),
		CrosshairThreat = C(255, 86, 96), -- aiming at someone you can hurt / intimidate
		Hit = C(255, 255, 255),
		HitHead = C(255, 70, 70),
		Kill = C(255, 120, 60),
		Hurt = C(200, 20, 30),
		Panel = C(14, 16, 22),
		Low = C(255, 205, 80), -- ammo running low
		Empty = C(255, 86, 96),
		SlotActive = C(64, 220, 160),
		Tracer = C(255, 228, 160),
		Flash = C(255, 196, 110),
		Spark = C(255, 210, 130),
		Dust = C(170, 160, 150),
		Blood = C(140, 18, 24), -- small, non-gory puffs
		Hole = C(18, 18, 18),
		-- built-in particle textures (rbxasset), swap for Alex's own
		FlashTexture = "rbxasset://textures/particles/fire_main.dds",
		SmokeTexture = "rbxasset://textures/particles/smoke_main.dds",
		SparkTexture = "rbxasset://textures/particles/sparkles_main.dds",
		Icons = { Fire = "rbxassetid://0", Aim = "rbxassetid://0", Reload = "rbxassetid://0" }, -- TODO(Alex art)
	},
	-- The flat (Piece 4): the FOR SALE card, door fade, world highlights. Reskin MTL_Property in StarterGui (keep names).
	Property = {
		Card = C(18, 19, 24),
		PhotoBack = C(52, 48, 40), -- placeholder until Alex's room photo
		Sign = C(245, 236, 210), -- the hand-written FOR SALE sign
		SignText = C(200, 40, 40),
		Tag = C(255, 205, 80),
		Secondary = C(40, 43, 54),
		DimTransparency = 0.4,
		Highlight = C(255, 205, 80), -- outline on the door / bed / front door you need
		HighlightPulse = 0.6, -- outline transparency swings between this and 0.1 (max 1 pulse a second)
		Bulb = C(255, 206, 150),
		Morning = C(255, 196, 140), -- light through the boards in the NEXT DAY scene
		Sounds = {
			Door = "", -- TODO(Alex sfx): door open/close
			Buy = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)
			Flicker = "", -- TODO(Alex sfx): bulb buzz
		},
	},
	-- The main HUD (cash pill, status rings, the icon menu, hotbar, map markers). Reskin MTL_HUD (keep names).
	-- Icons are emoji placeholders: put an image id in HUD.Images[<key>] and it replaces that emoji.
	HUD = {
		-- Plain, everyday colours (Alex: "make them normal"): dark grey panels, white text, green only for money,
		-- gold only for level / big moments, one soft blue for "selected". No neon, no multi-colour gradients.
		Ink = C(24, 25, 29), -- panels
		InkTransparency = 0.12,
		Ink2 = C(38, 40, 46), -- tiles, cards, slots
		Line = C(255, 255, 255), -- borders
		LineTransparency = 0.86,
		Paper = C(245, 245, 245), -- text
		Muted = C(165, 168, 175), -- secondary text
		Accent = C(96, 170, 255), -- selected tab / hover / focus
		Money = C(92, 196, 104), -- cash and buy buttons
		Gold = C(240, 192, 72), -- level, level-up, ribbons
		Danger = C(226, 72, 72),
		Corner = UDim.new(0, 8),
		Shadow = C(0, 0, 0),
		ShadowTransparency = 0.5,
		TileActive = C(245, 245, 245), -- selected hotbar slot outline
		Level = C(240, 192, 72),
		Health = C(92, 196, 104),
		HealthLow = C(226, 72, 72),
		Marker = C(24, 25, 29),
		MarkerTransparency = 0.18,
		MarkerStroke = C(255, 255, 255),
		LabelStroke = C(0, 0, 0),
		CashText = C(92, 196, 104),
		-- one type family (Gotham, same as Theme.Fonts): Heavy for labels and numbers, Medium for sentences
		Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		CashFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		BodyFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
		-- sounds: Theme.Sfx (Tap / Hover / Open / Close) through UI/Sfx.lua
		-- TODO(Alex art): image ids. "" = use the emoji in Config/HUD.
		Images = {
			Cash = "",
			MenuButton = "",
		},
	},

	-- Shared low-poly look (HUD, menus, phone): chunky panels, small hard corners, a bold dark outline and flat
	-- diagonal "facets" (a hard-step gradient, no smooth shading) to match the blocky buildings.
	-- Use it through UI/LowPoly.lua: LowPoly.style(frame, color) / LowPoly.facets(color) / LowPoly.outline().
	LowPoly = {
		Corner = UDim.new(0, 6), -- panels, tiles, slots
		CornerSmall = UDim.new(0, 4), -- pills, tags, small buttons
		Outline = C(10, 10, 14),
		OutlineThickness = 3,
		OutlineThin = 2,
		FacetAngle = 32, -- degrees; the facet edges run at this angle
		FacetSplits = { 0.38, 0.72 }, -- where the three flat bands meet (0..1 along the angle)
		FacetLight = 0.16, -- top band: blend toward white
		FacetDark = 0.22, -- bottom band: blend toward black
		Rim = C(255, 255, 255), -- thin inner highlight on the top edge
		RimTransparency = 0.82,
	},
	-- TODO(Alex art): image ids. 0 = draw the placeholder shape instead.
	Images = {
		CashIcon = "rbxassetid://0",
		LevelIcon = "rbxassetid://0",
		WaypointIcon = "rbxassetid://0",
	},
	-- UI sounds, played through UI/Sfx.lua (Sfx.play("PhoneTap")). Real recorded sounds only, no synth beeps.
	-- All load in this place (checked in Studio). "(PSE)" = Pro Sound Effects / Roblox-owned, always public;
	-- the others are community uploads that load today, swap for your own uploads any time.
	-- { id, volume 0-1, pitch, jitter = random pitch spread so repeats don't sound copy-pasted }
	Sfx = {
		-- generic UI (HUD, menus)
		Tap = { id = "rbxassetid://10128760939", volume = 0.4, jitter = 0.04 }, -- RBLX UI Select 01 (Roblox)
		Hover = { id = "rbxassetid://10066936758", volume = 0.25 }, -- RBLX UI Hover 02 (Roblox)
		Open = { id = "rbxassetid://10128766965", volume = 0.4 }, -- RBLX UI Swipe (Roblox)
		Close = { id = "rbxassetid://10066914500", volume = 0.35, jitter = 0 }, -- RBLX UI Back (Roblox)
		Confirm = { id = "rbxassetid://10066968815", volume = 0.45 }, -- RBLX UI Select 02 (Roblox)
		Error = { id = "rbxassetid://80099403859001", volume = 0.4 }, -- UI - Error (SodaBreadle)
		-- rewards: short and punchy like other games (each capped at max seconds by UI/Sfx)
		LevelUp = { id = "rbxassetid://105625891237078", volume = 0.6, jitter = 0, max = 1.5 }, -- UI levelup (CoreKit)
		Toast = { id = "rbxassetid://10066931761", volume = 0.25, jitter = 0.03, max = 0.5 }, -- RBLX UI Hover 01 (Roblox)
		Buy = { id = "rbxassetid://10066947742", volume = 0.5, jitter = 0 }, -- RBLX UI Purchase (Roblox)
		PromptDone = { id = "rbxassetid://9119668788", volume = 0.3, jitter = 0.06 }, -- suction pop (PSE): any prompt completed
		Dropped = { id = "rbxassetid://9116329927", volume = 0.6, pitch = 0.8, jitter = 0 }, -- Low Impacts 2 (PSE), slowed: you got dropped
		-- phone
		PhoneOpen = { id = "rbxassetid://10128766965", volume = 0.4, jitter = 0.02 }, -- RBLX UI Swipe (Roblox)
		PhoneClose = { id = "rbxassetid://9125434359", volume = 0.45, jitter = 0.02 }, -- side-button click (PSE)
		PhoneTap = { id = "rbxassetid://9113745498", volume = 0.4, jitter = 0.04 }, -- phone button press (PSE)
		PhoneBack = { id = "rbxassetid://10066914500", volume = 0.35, jitter = 0.03 }, -- RBLX UI Back (Roblox)
		PhoneToggle = { id = "rbxassetid://9117027976", volume = 0.35 }, -- toggle switch (PSE)
		PhoneNotify = { id = "rbxassetid://9120917794", volume = 0.45, jitter = 0 }, -- soft temple block (PSE)
		PhoneMessage = { id = "rbxassetid://9120917438", volume = 0.5, jitter = 0 }, -- soft temple block (PSE)
		PhoneVibrate = { id = "rbxassetid://75568314388208", volume = 0.5, jitter = 0 },
		PhoneSend = { id = "rbxassetid://9119668788", volume = 0.4 }, -- suction pop (PSE)
		PhoneType = { id = "rbxassetid://9116158128", volume = 0.25, jitter = 0.08 }, -- keyboard tap (PSE)
		PhoneRing = { id = "rbxassetid://9117306635", volume = 0.5, jitter = 0 }, -- soft phone ring (PSE), loops
		PhoneCallEnd = { id = "rbxassetid://9125434359", volume = 0.5, pitch = 0.9, jitter = 0 },
		PhoneShutter = { id = "rbxassetid://9113678227", volume = 0.6, jitter = 0.02 }, -- camera shutter (PSE)
		-- cutscene dialogue: one soft tick every couple of letters while a line types (pitch varies per tick)
		TextBlip = { id = "rbxassetid://10066931761", volume = 0.12, pitch = 0.95, jitter = 0.05 }, -- RBLX UI Hover 01 (Roblox), the SFX thread's pick (backup: Hover 03, 10066942189)
	},
}
