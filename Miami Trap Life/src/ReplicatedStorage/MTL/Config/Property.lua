--!strict
-- Story Piece 4: homes (the flat in the Ends), interiors, the power bill, sleeping. Tune here only.
-- Master Plan §1 stages 8-12. PropertyService (server) + PropertyController (client) read this.
--
-- HOW THE FLAT WORKS
--   Outside: an invisible door part at Locations.EndsFlat.Door (or a map part tagged MTL_FlatDoor with attribute
--   Id = "EndsFlat") carries the door prompt. Not owned -> the FOR SALE card. Owned -> go inside.
--   Inside: every owner gets their OWN copy of the interior (an instanced room), built far away from the map at
--   a slot position, so two players never share one dirty room. Walking in/out is a fade + teleport.
--   The room: ServerStorage.MTL_FlatInterior (Alex's model) wins over the part-built placeholder. A model needs a
--   PrimaryPart at floor level in the middle of the room (front = -Z = the back wall, the door in the +Z wall) and
--   parts with the names in `Points` (anywhere inside the model). Missing ones fall back to the numbers below.
local Economy = require(script.Parent.Economy)

local V = Vector3.new

local Property = {}

Property.Homes = {
	EndsFlat = {
		title = "Flat 3B", -- placeholder name until Alex names the building
		area = "The Ends",
		price = Economy.EndsFlatPrice,
		location = "EndsFlat", -- Config/Locations key (Door = outside door, Out = where you appear when you leave)
		place = "Home", -- Config/Phone.Places id (GPS)
		-- the FOR SALE card (honest about how bad it is; that's the joke and the goal)
		blurb = "One room. One window. Lights not included (the power bill is your problem).",
		facts = {
			{ "Bedroom", "Yes (it's also the kitchen)" },
			{ "Power", "Off. Bill not paid" },
			{ "Landlord", "Doesn't ask questions" },
		},
		photo = "rbxassetid://0", -- TODO(Alex art): a photo of the room for the card
	},
}
Property.StarterHome = "EndsFlat" -- the story's flat (stage FindAPlace)

-- Instanced interiors: slot i sits at Origin + (i-1) * Spacing along X (far from the map, above the sea).
Property.Slots = {
	Origin = V(6000, 400, 6000),
	Spacing = 160,
	Max = 60, -- more than a full server
}

-- The placeholder room and the named points (local to the room's PrimaryPart; y = 0 is the floor).
-- "Spot" points are floor points (actors stand/sit there); the rest are objects (camera targets).
Property.Interior = {
	Size = V(26, 12, 22), -- inside size of the placeholder room (X wide, Y high, Z deep)
	Points = {
		Entry = V(6, 0, 7.5), -- where you appear when you walk in (facing -Z)
		Exit = V(6, 0, 10.6), -- the inside of the front door (the "Leave" prompt)
		ChairSpot = V(-6, 0, -6.4), -- sitting at the PC (pelvis above this floor point)
		Screen = V(-6, 3.55, -8.56), -- the dead monitor (its front face)
		Keyboard = V(-6, 2.3, -8.1),
		PowerLed = V(-8.2, 1.7, -8.25),
		BedSpot = V(7.6, 0, -4.5), -- sitting on the edge of the mattress (facing -X, into the room)
		BedStand = V(5.6, 0, -2.4), -- where you stand after getting up
		BedSeat = V(7.8, 1.05, -4.5), -- the real Seat on the mattress
		Breaker = V(11.6, 4.5, 10.75), -- breaker box by the door (power bill prompt)
		Window = V(6, 6, -10.9),
		Bulb = V(0, 9.6, 0),
	},
	PromptDistance = 7,
}

-- The power bill (Master Plan §1 FreePlay goals). One payment turns the power on (no real-time bills yet).
Property.Power = {
	Bill = Economy.PowerBill,
	-- No power = the bulb is dead (it flickers once when you walk in, then dies); the room is lit only by the
	-- cold street light through the boards. Paying turns the bulb on for good and boots the PC (client visuals).
}

-- Door and buy rules (server checks).
Property.Door = {
	Radius = 12, -- studs from the door where buying / entering is accepted
	FadeOut = 0.3, -- seconds of fade before the teleport
	Hold = 0.35, -- seconds black while the room streams in
	EnterCooldown = 1.5,
}

-- What the story says in stages 8-13 (Config/Story.Contacts ids). Rename freely.
Property.Texts = {
	-- stage 8 FindAPlace: Dre texts right after the offer card closes
	FindAPlace = {
		{ who = "Dre", text = "You got paid. Now get off the street before somebody sees you counting it." },
		{ who = "Dre", text = "There's a flat going in the Ends. Cheap. Landlord don't ask questions.", link = true },
	},
	-- stage 13 FreePlay: one welcome text
	FreePlay = { who = "Dre", text = "Heard you got a real job. Smart, keeps you clean. When you want more, you know where we are." },
	-- stage 12 CommuteToWork: the boss of the job you picked texts when you wake up (Config/Jobs.Defs[job].boss)
	Wake = {
		Patel = "Morning! Somebody robbed us the other night, can you believe it? I need all the help I can get. Come in!",
		Rico = "Morning, rookie. Bays open at 7. Come find me at Westside Auto.",
		Tasha = "Morning! Grill's heating up. Burger Shack, don't be late on day one.",
		default = "Morning. Your first shift starts when you get here.",
	},
}

-- One line under each starter job card on the ChooseJob screen (story flavour, keyed by job id).
Property.JobHooks = {
	Supermarket = "Mr. Patel's hiring again. He has no idea it was you.",
	Mechanic = "Rico pays fair, and you learn your way around cars.",
	Restaurant = "Tasha runs a tight kitchen. Busy, but the time flies.",
}

-- The PC once the power is on. Honest: nothing to do on it yet.
Property.PC = {
	OffText = "No power. Pay the power bill first.",
	OnText = "Nothing to do on the PC yet. It gets apps in a later update.",
}

return Property
