-- Round rules and timings. Every number the owner may want to tune lives here.
return {
	MinPlayers = 2,
	-- Studio's Play button starts one player: let them test the carry alone
	-- (no catcher, cross twice to win). Test > Clients and Servers for real rounds.
	StudioMinPlayers = 1,

	IntermissionTime = 15,
	CountdownTime = 4, -- everyone frozen in place before GO
	RoundTime = 45, -- runners still out when it ends count as caught
	RoundEndPause = 4,
	GameOverTime = 8,
	MaxRounds = 12, -- safety net: whoever holds the girl then wins

	TagRange = 5.5, -- studs between root parts
	StartZoneSafe = true, -- catchers can't tag runners still standing in their start zone

	Speeds = {
		Runner = 16,
		Catcher = 17.5,
		Holder = 15, -- a runner carrying the girl
		Thief = 16, -- a catcher carrying the girl
	},

	-- Map parts, found by CollectionService tag ("Huzz" .. name, e.g. HuzzZoneA)
	-- or else by name anywhere in Workspace. Bench and Lobby are optional.
	Map = {
		ZoneA = "ZoneA", -- one side; round 1 starts here
		ZoneB = "ZoneB", -- the other side; round 1's safe zone
		Middle = "Middle", -- where catchers spawn
		Bench = "Bench", -- where caught runners wait out the round
		Lobby = "Lobby", -- where everyone waits between games (falls back to ZoneA)
		BuildTestField = true, -- no zones found: build a plain test field so the game still runs
	},

	-- The owner's "ANIME GIRLS" folder (Workspace, or moved to ServerStorage):
	-- one folder per rarity (ANIME GIRLS/Legendary/<girl model>), or a "Rarity"
	-- attribute on the model. A girl in the folder twice counts once.
	GirlFolders = {
		{ "Workspace", "ANIME GIRLS" },
		{ "ServerStorage", "ANIME GIRLS" },
		{ "ReplicatedStorage", "ANIME GIRLS" },
	},
	-- "R15": every girl is rebuilt as R15 from her own HumanoidDescription when she's
	-- first picked (same look, plus elbows and knees). "Original" keeps her model as is.
	GirlRig = "R15",

	-- Weight = how often the round's girl comes from this rarity
	-- (only rarities that have girls count).
	Rarities = {
		{ Name = "Common", Weight = 50, Color = Color3.fromRGB(196, 202, 214) },
		{ Name = "Uncommon", Weight = 25, Color = Color3.fromRGB(111, 214, 120) },
		{ Name = "Rare", Weight = 13, Color = Color3.fromRGB(86, 156, 255) },
		{ Name = "Epic", Weight = 7, Color = Color3.fromRGB(176, 104, 255) },
		{ Name = "Legendary", Weight = 3.5, Color = Color3.fromRGB(255, 190, 60) },
		{ Name = "Mythic", Weight = 1.2, Color = Color3.fromRGB(255, 84, 120) },
		{ Name = "Secret", Weight = 0.3, Color = Color3.fromRGB(30, 30, 30) },
	},
}
