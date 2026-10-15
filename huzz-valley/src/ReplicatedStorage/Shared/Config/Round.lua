-- Round rules and timings. Every number the owner may want to tune lives here.
return {
	MinPlayers = 2,
	-- Studio's Play button starts one player: let them test the carry alone
	-- (no catcher, cross twice to win). Test > Clients and Servers for real rounds.
	StudioMinPlayers = 1,

	IntermissionTime = 15, -- the wait before a game when there's only one map (no vote)
	VoteTime = 15, -- the map vote between games (design page 15)
	LoadTime = 3, -- after the vote: the map appears, everyone is moved onto it
	CountdownTime = 4, -- everyone frozen in place before GO
	RoundTime = 45, -- runners still out when it ends count as caught
	RoundEndPause = 4,
	GameOverTime = 8,
	MaxRounds = 12, -- safety net: whoever holds the girl then wins

	-- How a runner gets her (owner's call): "FirstAcross" = the first runner into the safe
	-- zone gets her automatically (she appears over their head). "Grab" = the first runner
	-- to walk up to her where she waits picks her up.
	Pickup = "FirstAcross",
	GirlSpot = "Middle", -- where she stands while nobody has her: "Middle" or "SafeZone" (the far side)
	GrabRange = 6, -- "Grab" only: studs from her centre to a runner's root

	TagRange = 5.5, -- studs between root parts

	-- A caught runner falls flat on their face and lies there until the next round
	-- (owner's call). Enabled = false sends them to the Bench part instead.
	Knockdown = {
		Enabled = true,
		FallTime = 0.45, -- seconds from standing to flat
		Bounce = 6, -- degrees of bounce when they hit the floor
		Lift = 0.5, -- torso thickness: how far the body lies above the floor
		ArmsForward = 160, -- arms out in front of the head (degrees from hanging)
	},
	StartZoneSafe = true, -- catchers can't tag runners still standing in their start zone

	Speeds = {
		Runner = 16,
		Catcher = 17.5,
		Holder = 15, -- a runner carrying the girl
		Thief = 17.5, -- a catcher she's following (she walks behind him, so no slowdown)
	},

	-- Map parts. Each map is a folder or model in Workspace holding ZoneA, ZoneB and
	-- Middle (and optionally Bench); every game picks one of the maps at random.
	-- Lobby (anywhere) is where players wait between games; without it they stay put.
	Map = {
		ZoneA = "ZoneA", -- one side; round 1 starts here
		ZoneB = "ZoneB", -- the other side; round 1's safe zone
		Middle = "Middle", -- where catchers spawn
		Bench = "Bench", -- where caught runners wait out the round
		Lobby = "Lobby", -- where everyone waits between games (optional; else the SpawnBaseplate)
		MiddleSpawn = 20, -- catchers start within this many studs of the Middle's centre
		Gap = 30, -- studs between the lobby island and the map copied in front of it
		Names = {}, -- names shown in the vote, e.g. { Base_Map = "The Field" } (default: the folder name without "_Map")
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
