--!strict
-- World positions used by gameplay. Systems read positions from HERE, not from map parts, because
-- StreamingEnabled may not have streamed far parts in on the client. North = -Z, east = +X, street y = 2.
-- Map thread: when a placeholder gets its real spot, change it here and note it in the Master Plan.
return {
	Spawn = Vector3.new(-1432, 3, -368),
	FoodMart = { Door = Vector3.new(-1442, 3, -330), Inside = Vector3.new(-1442, 3, -312), Radius = 14 },
	BurgerShack = { Door = Vector3.new(-1449.3, 3, -449), Inside = Vector3.new(-1436, 3, -463), Radius = 14 }, -- glass door at the west end; Inside = the dining room
	WestsideAuto = { Door = Vector3.new(-1042, 3, -458), Inside = Vector3.new(-1015, 3, -478), Radius = 16 }, -- office door (west bay); Inside = between the lifts
	-- Job sites for the Level 8+ / 15+ jobs (Jobs piece). PLACEHOLDERS: if the map has a part tagged `JobSpot`
	-- whose `Job` attribute matches the job (Config/Jobs.Defs[..].mapJob), JobService uses that part instead and
	-- overwrites these at server start (so the GPS points at the real spot too).
	CarWash = { Door = Vector3.new(-1200, 3, -360), Inside = Vector3.new(-1200, 3, -360), Radius = 14, Placeholder = true },
	Valet = { Door = Vector3.new(-1300, 3, -600), Inside = Vector3.new(-1300, 3, -600), Radius = 14, Placeholder = true },
	Security = { Door = Vector3.new(-1100, 3, -700), Inside = Vector3.new(-1100, 3, -700), Radius = 14, Placeholder = true },
	TruckDepot = { Door = Vector3.new(-900, 3, -300), Inside = Vector3.new(-900, 3, -300), Radius = 16, Placeholder = true },
	Docks = { Door = Vector3.new(-1600, 3, -900), Inside = Vector3.new(-1600, 3, -900), Radius = 16, Placeholder = true },
	-- PLACEHOLDER: the flat in the Ends (Starter Crib POI until the Map thread builds the real one)
	EndsFlat = { Door = Vector3.new(-1442, 3, -165), Out = Vector3.new(-1442, 3, -173), Radius = 10, Placeholder = true }, -- Out = where you appear when you leave (Piece 4)
	-- PLACEHOLDERS: meet spots (one picked at random per player). Real spots come from the Map thread.
	MeetSpots = {
		{ Id = "CanalBridge", Label = "Under the canal bridge", Position = Vector3.new(-1176, -6, -540), Placeholder = true },
		{ Id = "Motel", Label = "The motel", Position = Vector3.new(-1300, 3, -880), Placeholder = true },
		{ Id = "Garage", Label = "The garage", Position = Vector3.new(-1015, 3, -470), Placeholder = true },
	},
}
