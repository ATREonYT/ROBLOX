--!strict
-- Story Piece 3: the meet, the crew, the first mission (rob Liberty Food Mart), the payout. Tune here only.
-- Positions are LOCAL offsets: meet layout -> relative to the meet spot's CFrame (its LookVector points from the crew
-- toward where the player stands); mission points -> relative to Locations.FoodMart.Inside, unless a part
-- Workspace.MTL_Stations.FirstMission.<Point> exists (tools/PlaceMissionPoints.lua makes them; drag into the map).
local Economy = require(script.Parent.Economy)

local C = Color3.fromRGB
local V = Vector3.new

local Missions = {}

-- The people in the scenes. Rigs are built by the server (CutsceneService) from these colours into
-- ReplicatedStorage.MTL_Actors.<Id>. Alex: drop a finished rig named <Id> into ReplicatedStorage.MTL_Actors in
-- Studio and it is used instead (keep a Humanoid + HumanoidRootPart, R15). Names/lines: Config/Story + Cutscenes/*.
-- TODO(Alex art): Shirt/Pants are clothing asset ids (0 = plain body colours).
Missions.Actors = {
	-- Looks: Roblox-made catalog clothing + hair (creator "Roblox", found with AvatarEditorService:SearchCatalogAsync
	-- and built once with CreateHumanoidModelFromDescription in Studio, 2026-11-02). Hair/Hat/FaceAcc = accessory ids
	-- (comma-separated strings, HumanoidDescription format). Alex: swap any id, or drop a finished rig in MTL_Actors.
	Dre = { Skin = C(110, 74, 52), Shirt = C(196, 40, 52), Pants = C(28, 28, 34), ShirtId = 398633584, PantsId = 382538503, Hair = "9174355709", Height = 1.04 }, -- denim jacket + white hoodie, black jeans, black dreads
	Smoke = { Skin = C(150, 104, 72), Shirt = C(235, 235, 238), Pants = C(70, 74, 86), ShirtId = 144076436, PantsId = 398635338, Hair = "13655562", Hat = "80275296", Height = 1.0 }, -- striped tee + denim jacket, ripped skater pants, grey beanie
	Nina = { Skin = C(86, 58, 44), Shirt = C(120, 70, 190), Pants = C(52, 70, 120), ShirtId = 398634295, PantsId = 382537569, Hair = "7193454569", Height = 0.95 }, -- top + grey jacket, black jeans, black braids
	Kev = { Skin = C(234, 190, 160), Shirt = C(40, 150, 90), Pants = C(170, 150, 110), ShirtId = 382537702, PantsId = 129458426, Hair = "398672920", Height = 0.98 }, -- teal shirt, jeans
	-- welcome scenes: the Food Mart owner (Cutscenes/FirstDay)
	Patel = { Skin = C(176, 124, 88), Shirt = C(48, 96, 168), Pants = C(60, 58, 66), ShirtId = 398635081, PantsId = 129459077, FaceAcc = "62690529", Height = 0.97 }, -- blue plaid shirt, black slacks, thick glasses
	-- Act 2 (Story Bible §3): Lionel Royce, landlord and lender. Cream suit (plain colours read as tailored), grey hair.
	-- Act 2.1: the supplier's driver (grey work shirt, the Liberty cap from the starter stand)
	Driver = { Skin = C(120, 84, 60), Shirt = C(110, 116, 124), Pants = C(46, 52, 64), ShirtId = 0, PantsId = 0, Hat = "129057054940664", Height = 1.02 },
	Royce = { Skin = C(198, 150, 112), Shirt = C(232, 222, 200), Pants = C(226, 216, 194), ShirtId = 0, PantsId = 0, Height = 1.03 }, -- (hair id 97396641893799 was not an accessory: removed until a grey one is picked)
}

-- Animations for the people in cutscenes (Actors.lua). R15 actors play these; R6 avatars and any 0 fall back to the
-- procedural poses in Rig.lua. Every id below is a Roblox-owned animation (default Animate set or a Roblox catalog
-- emote), checked in Studio on 2026-11-02 with KeyframeSequenceProvider (Roblox-owned = plays in any experience).
-- Alex: paste your own (group-owned) ids over them any time; keys = names used in Cutscenes/*.
--   Idle / Walk = the base layer (an actor with no held pose breathes and shifts its weight; walking plays a cycle)
--   the rest = one-shot gestures ({ t, actor, gesture = "Wave", dur })
Missions.Animations = {
	Idle = 2510196951, -- "Rthro Idle1" (Roblox): slow natural breathing/weight shift (was the stiff Animate idle)
	Walk = 913402848, -- "Mocap Walk" (Roblox): motion-captured, heel-to-toe (Alex: "the walking animation is bad")
	Wave = 3344650532, -- emote "Wave"
	Point = 3344585679, -- emote "Point"
	Shrug = 3334392772, -- emote "Shrug"
	Nod = 4841397952, -- emote "Agree"
	Laugh = 507770818, -- Animate laugh
	Cheer = 507770677, -- Animate cheer
	Salute = 3333474484, -- emote "Salute"
	Open = 0, -- procedural (open-hands "relax" while talking)
	HandsUp = 0, -- procedural (the clerk)
	Lean = 0,
	Phone = 0,
	Cross = 0,
	Smash = 0,
	Sit = 0,
	Flop = 0,
	Press = 0, -- Piece 4: PC power button
	Give = 0, -- Act 2: hand over a bill / card / envelope (procedural, Rig.Gestures.Give)
	Count = 0, -- Act 2: count bills (procedural)
	Stretch = 507770677, -- Piece 4: waking up (the Animate "cheer": both arms up = a big morning stretch)
}
-- How fast the walk cycle plays for cutscene walks (they're slower than a running player).
Missions.WalkAnimSpeed = 0.8 -- starting speed; Actors then matches it to real movement:
Missions.WalkAnimRef = 10 -- studs/s at which the walk animation plays at speed 1 (lower = faster steps)

---------------------------------------------------------------- stage 4-5: the meet

Missions.Meet = {
	Radius = 14, -- arrive this close to the meet spot to start the intro
	ShowPropsWithin = 450, -- the crew + car with hazards appear on the client from this far away
	-- where everyone stands, relative to the meet spot CFrame (same layout in the waiting scene and the cutscene)
	Layout = {
		Car = CFrame.new(0, 0, 8) * CFrame.Angles(0, math.rad(90), 0),
		Dre = { at = V(0, 0, 0), face = V(0, 0, -10) },
		Smoke = { at = V(-5.5, 0, 4), face = V(-1, 0, -8), pose = "Lean" },
		Nina = { at = V(5, 0, 4.5), face = V(1, 0, -8), pose = "Phone" },
		Player = { at = V(0, 0, -10), face = V(0, 0, 0) }, -- the real player is placed here for the cutscene
	},
	-- Text from the unknown number when the meet is set (label = the meet spot's Label from Config/Locations)
	Texts = {
		"%s. Pull up when you're ready.",
		"Come alone. It's on your GPS.",
	},
}

---------------------------------------------------------------- stage 6: the first mission

Missions.FirstMission = {
	Title = "Liberty Food Mart",
	Chapter = "FIRST JOB", -- title card at the end of the intro
	Pay = Economy.FirstMissionPay, -- the take (2x Money applies on top). Must cover Economy.EndsFlatPrice.
	XP = 150,
	CleanGetaway = { Seconds = 30, Bonus = 250 }, -- from the alarm to the car under this = bonus (never a fail)
	ResetRadius = 600, -- wander this far from the store mid-mission -> back to the car with a toast
	Gun = { Id = "Pistol", Ammo = 18 }, -- GunService.give(player, Id, {temporary, mode = "Intimidate"}) (Guns thread). 18 = a full mag of 12 + 6 spare, so the "Press R to reload" hint after the first shot works
	Clerk = "Kev",
	-- Points: offset from Locations.FoodMart.Inside (yaw = degrees, 0 faces -Z / north toward the door).
	Points = {
		Car = { offset = V(-20, 0, -40), radius = 9, yaw = 90 }, -- getaway car in the front lot (start + escape)
		Door = { offset = V(0, 0, -15), radius = 7 }, -- just inside the front door
		Clerk = { offset = V(6, 0, -9.5), radius = 12, yaw = 0 }, -- behind the counter, facing the door
		Register = { offset = V(6, 0, -12), radius = 6 }, -- same spot as the Cashier job's register
	},
	-- Steps in order. kind: "hold" (stand at the point and hold the action), "zone" (walk into the point),
	-- "aim" (aim at the clerk; GunService.Intimidating, or the built-in hold-aim when Guns isn't installed).
	-- bark = a crew line shown at the bottom when the step starts { who, text }.
	Steps = {
		{
			id = "Mask",
			kind = "hold",
			point = "Car",
			text = "Grab a mask from the car",
			verb = "Mask up",
			seconds = 1.2,
			bark = { "Nina", "Masks are in the back. Gun's not loaded, just point it." },
		},
		{ id = "Enter", kind = "zone", point = "Door", text = "Walk into Liberty Food Mart", bark = { "Dre", "Walk in normal. Like it's a shift." } },
		{
			id = "Threaten",
			kind = "aim",
			point = "Clerk",
			text = "Aim at the clerk",
			verb = "Aim",
			seconds = 2.0,
			bark = { "Kev", "Wait... you WORK here!" },
			after = { "Kev", "Okay okay! Take it, it's all yours!" },
		},
		{
			id = "Grab",
			kind = "hold",
			point = "Register",
			text = "Grab the cash",
			verb = "Grab cash",
			seconds = 3.5,
			bark = { "Smoke", "Clock's ticking, Food Mart!" },
		},
		{
			id = "Escape",
			kind = "zone",
			point = "Car",
			text = "Get to the car!",
			alarm = true,
			bark = { "Nina", "Alarm! Move, move, move!" },
		},
	},
	-- Validation (server): a hold must last at least seconds * MinHoldShare; aim fallback needs facing within
	-- AimDot (cosine) of the clerk and at most AimRange studs.
	MinHoldShare = 0.75,
	AimDot = 0.7,
	AimRange = 26,
}

-- Where the outro cutscene leaves you (the drop-off). Next to the flat in the Ends, so Piece 4 starts close.
Missions.DropOffOffset = V(18, 0, -20) -- from Locations.EndsFlat.Door (placeholder until the Map thread sets one)

---------------------------------------------------------------- stage 7: payout + offer

Missions.Offer = {
	-- What the offer card shows (Config/Monetization names). No timers, no "only now", one clear "Maybe later".
	Items = {
		{ item = "Cash2x", kind = "pass", title = "2x Money", sub = "Every job, forever" },
		{ item = "CashBoost", kind = "product", title = "2x Money boost", sub = "30 minutes of play time" },
	},
}

return Missions
