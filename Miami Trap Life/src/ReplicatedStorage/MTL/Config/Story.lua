--!strict
-- The story stages in order (Master Plan §1). Index = onboarding funnel step number. Never reorder; only append.
local Story = {}

Story.Stages = {
	"Arrive", -- 1  spawn with a phone and $50
	"FirstShift", -- 2  supermarket job until Level 4 (Levels.CriminalCallLevel)
	"TheCall", -- 3  unknown number calls
	"GangMeet", -- 4  go to the meet spot
	"GangIntro", -- 5  crew intro cutscene
	"FirstMission", -- 6  rob the Liberty Food Mart
	"MissionDone", -- 7  payout + pass offer
	"FindAPlace", -- 8  buy the flat in the Ends
	"MoveIn", -- 9  power-out cutscene
	"ChooseJob", -- 10 job app: supermarket / mechanic / restaurant
	"FirstNight", -- 11 sleep
	"CommuteToWork", -- 12 go to the chosen job
	"FreePlay", -- 13 everything open
}

-- Placeholders until Alex names them (Master Plan open question 4). Rename freely; ids stay.
Story.Crew = { Name = "Liberty Lows" }
Story.Contacts = {
	Patel = { Name = "Mr. Patel", Subtitle = "Liberty Food Mart" },
	Rico = { Name = "Rico", Subtitle = "Westside Auto Repair" }, -- Jobs piece: Mechanic boss
	Tasha = { Name = "Tasha", Subtitle = "Burger Shack" }, -- Jobs piece: Restaurant boss
	Unknown = { Name = "Unknown" },
	Bea = { Name = "Ms. Bea", Subtitle = "Liberty Gardens" }, -- quality: the neighbourhood grandma who hides her lucky tin daily (Config/Live.Cache)
	Dre = { Name = "Dre", Subtitle = "Liberty Lows" },
	Smoke = { Name = "Smoke", Subtitle = "Liberty Lows" },
	Nina = { Name = "Nina", Subtitle = "Liberty Lows" },
	Kev = { Name = "Kev", Subtitle = "Night clerk, Liberty Food Mart" }, -- Story piece 3: the clerk you rob (speaks in scenes)
	You = { Name = "You" },
	Royce = { Name = "Mr. Royce", Subtitle = "Royce Properties" }, -- Act 2: landlord, lender, polite -- Story piece 4: the player's own thoughts in cutscenes (never a phone contact)
}

-- Objective line text per stage (the HUD shows it). Systems may override with more specific text.
Story.Objectives = {
	Arrive = "Head inside Liberty Food Mart",
	FirstShift = "Work your shift at Liberty Food Mart",
	TheCall = "Answer your phone",
	GangMeet = "Go to the meet",
	GangIntro = "",
	FirstMission = "Rob Liberty Food Mart",
	MissionDone = "",
	FindAPlace = "Buy the flat in the Ends",
	MoveIn = "Go inside your new place",
	ChooseJob = "Pick a job on your phone",
	FirstNight = "Get some sleep. Work starts tomorrow.",
	CommuteToWork = "Head out to work",
	FreePlay = "",
}

return Story
