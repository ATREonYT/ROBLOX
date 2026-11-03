--!strict
-- Story chapters after Act 1 (Story Bible §4, §6). Act 1 stays on the stage machine (Config/Story.Stages); from
-- FreePlay on, StoryMissions runs these missions. Save: data.Story.Data = { Chapter = 2, Missions = { [id] = step
-- number | "done" }, Choices = { Kev1 = "help", Tab = "truth", ... } }. Only one mission runs at a time: the first
-- one in the chapter's list whose gates are open.
--
-- Mission fields:
--   chapter, title, line = "Straight" | "Street" | "Either", giver (a Story.Contacts id), level
--   needs = { mission ids that must be done }   needsAny = { { ids }, { ids } } (any one group fully done)
--   path = "Criminal" (Street line missions need the Criminal path)
--   offer = { { from, text }, ... }  texts when the mission opens (once)
--   steps = { step, ... } in order:
--     { kind = "go", at = Place id, label, objective, radius? }      waypoint; arriving moves on
--     { kind = "scene", id = Cutscenes id, anchor = Place id, choice? = Choices key }
--         the scene's pick is saved under Choices[choice]; a scene step that fails (an unaffordable pick) goes back
--         to the "go" step before it
--     { kind = "texts", texts = { { from, text } }, gap? }           phone texts, then move on
--   reward = { cash, xp }   done = { { from, text } } texts a little after the reward   contacts = { ids added }
--   blurb = one line for the Story app
-- Places: world points and scene anchors. "Set" places read an Anchors folder in the map (the building thread
-- owns the sets; a missing set falls back to `at`).
local V = Vector3.new

local Chapters = {}

-- Act 1 runs on the stage machine; listed here only so the Story app can show it
Chapters.Act1 = { id = 1, title = "New in Town" }

Chapters.List = {
	{
		id = 2,
		title = "The Tab",
		level = 6,
		missions = { "BackOfHouse", "KevKnows", "Cash4Gold", "TheTab" },
		goal = "Find out what Royce wants with Liberty", -- added to Goals when the chapter ends
	},
}

Chapters.Places = {
	-- the Food Mart's back door on the alley (anchor: world-aligned, at the door; +Z = out into the alley, +X = east)
	FoodMartBack = { at = V(-1478, 2.3, -286), waypoint = V(-1472, 3, -281), radius = 9, phonePlace = "FoodMart" },
	-- inside the store at the front door, looking in (StoryWelcome.storeAnchor)
	FoodMartStore = { store = true, phonePlace = "FoodMart" },
	FoodMartTill = { waypoint = V(-1429.5, 3, -319), radius = 6, phonePlace = "FoodMart" }, -- the customer side of the register
	-- Royce's Cash 4 Gold (building thread: Workspace.ViceBay.Buildings.Hood.RoyceCash4Gold.Anchors.C4G_*)
	Cash4Gold = { set = "RoyceCash4Gold", prefix = "C4G_", waypoint = V(-1134.2, 3, -337.5), radius = 9 },
	-- the Ends rooftop (MTL_EndsRooftop.Anchors.Roof_*); you climb the fire escape
	Rooftop = { set = "MTL_EndsRooftop", prefix = "Roof_", waypoint = V(-1463.1, 3, -70.7), radius = 8, phonePlace = "Home" },
}

Chapters.Missions = {
	-- 2.1 Straight · Patel · Level 6
	BackOfHouse = {
		chapter = 2,
		title = "Back of the House",
		blurb = "Patel needs a hand with the late delivery.",
		line = "Straight",
		giver = "Patel",
		level = 6,
		offer = {
			{ "Patel", "Store's open late tonight. Could use a hand with the delivery." },
			{ "Patel", "I'll pay cash, and I'll throw in a sandwich." },
		},
		steps = {
			{ kind = "go", at = "FoodMartBack", label = "Food Mart, back door", objective = "Help Patel unload the truck out back" },
			{ kind = "scene", id = "BackOfHouse", anchor = "FoodMartBack" },
			{ kind = "go", at = "FoodMartTill", label = "The register", objective = "Watch the register for Mr. Patel" },
			{ kind = "scene", id = "RoyceSoda", anchor = "FoodMartStore" },
		},
		reward = { cash = 150, xp = 120 },
		contacts = { "Royce" },
		done = { { "Royce", "Good hands at the till. If you ever want real hours, come see me." } },
	},
	-- 2.2 Either · Kev · Level 7
	KevKnows = {
		chapter = 2,
		title = "Kev Knows",
		blurb = "Kev wants a word. Out back, on his break.",
		line = "Either",
		giver = "Kev",
		level = 7,
		needs = { "BackOfHouse" },
		offer = {
			{ "Kev", "hey. you got a minute tonight?" },
			{ "Kev", "back of the store. by the dumpster. i'm on break." },
		},
		steps = {
			{ kind = "go", at = "FoodMartBack", label = "Behind the Food Mart", objective = "Meet Kev behind the Food Mart" },
			{ kind = "scene", id = "KevKnows", anchor = "FoodMartBack", choice = "Kev1" },
		},
		reward = { xp = 60 },
		contacts = { "Kev" },
	},
	-- 2.3 Street · Dre · Level 7 (Criminal path)
	Cash4Gold = {
		chapter = 2,
		title = "Cash 4 Gold",
		blurb = "Dre's next job. The boring part is yours.",
		line = "Street",
		giver = "Dre",
		level = 7,
		path = "Criminal",
		offer = {
			{ "Dre", "Got a job. Boring part's yours." },
			{ "Dre", "Back door of Cash 4 Gold. Don't be late, he notices." },
		},
		steps = {
			{ kind = "go", at = "Cash4Gold", label = "Cash 4 Gold, back door", objective = "Meet Dre behind Cash 4 Gold" },
			{ kind = "scene", id = "Cash4Gold", anchor = "Cash4Gold" },
		},
		reward = { cash = 900, xp = 200 },
	},
	-- 2.7 Finale · either line · Level 10
	TheTab = {
		chapter = 2,
		title = "The Tab",
		blurb = "Nina found something. Meet her on the roof.",
		line = "Either",
		giver = "Nina",
		level = 10,
		needsAny = { { "BackOfHouse", "KevKnows" }, { "Cash4Gold" } },
		offer = {
			{ "Nina", "Roof of your building. Tonight." },
			{ "Nina", "Come alone. Don't tell Dre." },
		},
		steps = {
			{ kind = "go", at = "Rooftop", label = "The roof (fire escape)", objective = "Meet Nina on your roof" },
			{ kind = "scene", id = "Rooftop", anchor = "Rooftop" },
			{
				kind = "texts",
				gap = 2.2,
				texts = {
					{ "Patel", "Sorry, it's late. The supplier stopped delivering." },
					{ "Patel", "I'm a little behind. Three thousand, give or take." },
					{ "Patel", "Meeting Mr. Royce on Monday to discuss options. It's fine!" },
				},
			},
			{ kind = "go", at = "FoodMartTill", label = "Mr. Patel", objective = "Go see Mr. Patel at the counter" },
			{ kind = "scene", id = "TheTab", anchor = "FoodMartStore", choice = "Tab" },
		},
		reward = { xp = 400 },
	},
}

-- what a pick costs or gives, checked by the server before it's saved (Choices key -> option id -> effect)
Chapters.ChoiceEffects = {
	Tab = {
		pay = { cost = 3000, short = "You need $3,000 for the envelope. Come back when you have it." },
	},
}

return Chapters
