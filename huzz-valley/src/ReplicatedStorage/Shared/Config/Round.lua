-- Round rules and timings. Every number the owner may want to tune lives here.
return {
	MinPlayers = 2, -- (1 while Bot.Enabled: the Practice Bot catches for a player alone)
	-- Studio's Play button starts one player: the Practice Bot catches (Bot below).
	-- Test > Clients and Servers for rounds with real players.
	StudioMinPlayers = 1,

	IntermissionTime = 25, -- the wait before a game when there's only one map (no vote; owner: time to shop)
	VoteTime = 30, -- the map vote between games (owner: a bit longer, so people can shop; the vote tucks away)
	-- After the vote the new map replaces the old one and the girl roller (a small reel at the top of
	-- the screen) runs: Cells girls go past top to bottom, slowing over SpinTime, stopping on the girl at Stop.
	Roll = { Time = 7.5, SpinTime = 5.5, Cells = 30, Stop = 26 },
	-- Huss Valley's loop, one to one (owner's call; Shared/RoundRules): runners line up on their safe line,
	-- one random runner picks HERO (crosses alone first) or CHICKEN, then everyone runs. Stabbed runners
	-- go down and can be rescued; anyone still down at the end joins the catchers. Runners win by getting
	-- everyone across Crossings rounds in a row; catchers win when no runners are left.
	Crossings = 3,
	LineupTime = 3, -- runners stand in a row on their line, facing across (the round's goal shows; was 3.5)
	-- The pick (owner's call): the camera sweeps the line, a highlight hops between runners for Roulette
	-- seconds and lands on one at random; the camera zooms in and they get ChooseTime seconds to pick
	-- (no answer = a random pick). ShowTime: everyone sees what they chose.
	-- (loop audit, Oct 17: half of everyone's time was spent standing still, so ChooseTime 8 -> 6, ShowTime 2.6 -> 2)
	Pick = { Enabled = true, Roulette = 2.8, ChooseTime = 6, ShowTime = 2 },
	HeroTime = 30, -- the Hero's solo crossing (everyone else waits on the line; owner, Oct 18: longer, was 20)
	HeroBonus = 25, -- coins for a Hero who makes it across (and the girl comes down to them)
	-- End-of-game pay (owner: coins must be worth earning; the coin shop is Config/CoinShop). Aura is the rarer one:
	-- crates cost it (Config/Crates), so it only comes from wins and the reward track.
	-- (loop audit, Oct 18: a real game paid ~340 coins an hour, less than the free wheel: 15/35 -> 25/50)
	Pay = { Played = 25, Won = 50, WonAura = 3 },
	-- Winning a girl you already own pays coins by her rarity instead (Results says so)
	DupeCoins = { Common = 25, Uncommon = 50, Rare = 75, Epic = 150, Legendary = 400, Mythic = 700, Secret = 1500 },
	CountdownTime = 3, -- 3, 2, 1, GO (everyone on the line)
	RoundTime = 60, -- runners still out when it ends count as caught (owner, Oct 18: a bit longer, was 45)
	RoundEndPause = 2.5, -- (was 3.5: pure waiting)
	-- A stalled round (loop audit: an AFK runner made every round run the full clock): when every runner still to
	-- cross has stood in the start zone (where nobody can stab them) for Wait seconds, the clock drops to Time
	-- seconds ("Hurry!"). A Hero who stays in the start zone for HeroWait seconds loses the solo run: everyone runs.
	Hurry = { Wait = 5, Time = 6, HeroWait = 6 },
	GameOverTime = 8,
	MaxRounds = 12, -- safety net: catchers win
	-- Rescue (as in Huss Valley): a runner still out on the field stands within Range studs of a downed
	-- runner for Time seconds to get them back up.
	-- Rescued runners can't be stabbed for Shield seconds (no camping the downed).
	Rescue = { Range = 5.5, Time = 1.2, Shield = 2 },
	-- The game's girl, big, floating over the middle of the map for the whole game (owner's call).
	-- Studio testing only (ignored in the live game): every roll picks a girl of this rarity, e.g. "Secret" to see
	-- the Secret girl's arrival cutscene every game. "" = the normal fair roll.
	StudioTestRarity = "",
	Showcase = {
		Scale = 3, -- times her normal size
		Height = 34, -- studs from the field's floor up to her feet (owner: higher)
		Spin = 0.35, -- radians per second (a slow turn)
		Bob = 0.6, -- studs up and down
	},
	-- How catchers tag (owner's call): "Stab" = they hold a knife and click / tap STAB to stab a runner
	-- in reach; "Touch" = running into a runner (TagRange) tags them.
	TagMode = "Stab",
	Stab = {
		Range = 8.5, -- studs from the catcher's root to the runner's (a little generous: other players lag on screen)
		-- Pinpoint (owner, Oct 18: "make hitboxes pinpoint"): the catcher's screen picks the runner whose body is in a
		-- box in front of them, Reach studs from their middle to the knife's tip and Width across (Gameplay/HitCheck);
		-- the server only checks that runner is within Range (+ Slack for lag) of where it sees the catcher.
		Reach = 5.5,
		Width = 4,
		Slack = 3,
		Cooldown = 0.6, -- seconds between stabs, hit or miss
		Time = 0.42, -- how long the stab move lasts (coil 0.11 s, thrust 0.06 s, hit 0.1 s, follow-through: Shared/StabMotion)
	},
	TagRange = 5.5, -- "Touch" only: studs between root parts


	-- The huss (owner's call): Space throws you left or right on your screen. Jumping is off. The push eases every
	-- frame from Speed down to EndSpeed (studs/s) over Time seconds (Shared/RunMotion.pushSpeed), then the run takes
	-- over: Huss Valley's ~0.30 s and ~10 studs (docs/feel-study.md gap 7; was a flat 72 for 0.24 s = 17 studs, a snap).
	-- Owner, Oct 18: "make the dash go a bit further ... but not too much": 0.30 x (28 + 36/3) = 12 studs (was 50 to
	-- 20 = 9), same 0.30 s, so the lean and lines keep their timing. Cooldown before the next.
	Dash = { Speed = 64, EndSpeed = 28, Time = 0.30, Cooldown = 2.5 },
	-- Catchers' Space (owner: "when they press space they jump and haul at the runner, and if they go into them,
	-- they get stabbed"): a leap forward the way they face, a hard burst that eases off (Speed to EndSpeed over
	-- Time: 0.38 x (40 + 32/3) = 19 studs, the old flat 56 x 0.36 reach). Any runner they reach during the leap
	-- (HitWindow seconds, within HitRange studs) is stabbed, the same as the knife. Shares the Space cooldown tile.
	-- Reach/Width: the leaping knife's box on the catcher's screen (pinpoint, as Stab).
	Lunge = { Speed = 72, EndSpeed = 40, Up = 18, Time = 0.38, Cooldown = 3, HitRange = 4.8, HitWindow = 0.5, Reach = 4.5, Width = 4 },

	-- A caught runner falls flat on their face and lies there until rescued or the next round
	-- (owner's call).
	Knockdown = {
		FallTime = 0.45, -- seconds from standing to flat
		Bounce = 0, -- degrees of bounce when they hit the floor (owner: no swinging; they land and lie still)
		Lift = 0.6, -- torso thickness: how far the body lies above the floor (a hair over half, so nothing dips in)
		ArmsOut = 125, -- arms out past the shoulders, flat on the floor (degrees from hanging)
		HeadTurn = 20, -- head turned to one side (degrees)
		ChinUp = 40, -- chin lifted off the floor (degrees)
	},
	StartZoneSafe = true, -- catchers can't tag runners still standing in their start zone

	-- The Practice Bot (HuzzServer/PracticeBot; owner picked "Yes, add bots" so a round works alone): a catcher that
	-- joins any round with runners and no catcher. Slower than a sprinting runner (28) so the huss and a straight run
	-- beat it; it never wins a girl and is never paid.
	Bot = {
		Enabled = true,
		Name = "Practice Bot",
		Speed = 24, -- studs a second (where it starts)
		-- It adapts to the kids playing it (loop audit, Oct 17: how often a kid alone beat it swung from 14% to 82%
		-- with how well they steer): Step slower after it wins a game, Step faster after it loses, between MinSpeed and
		-- MaxSpeed (never faster than a runner's 28). The message line says so.
		MinSpeed = 18,
		MaxSpeed = 28,
		Step = 2,
		Reach = 5, -- studs at Speed 24: it stabs a runner this close (no lag allowance); scales with its speed
		Pause = 1.2, -- seconds it stands still after each stab
		Reaction = 0.6, -- seconds after GO before it moves
		Think = 0.15, -- seconds between picking where to run
		Lead = 0.35, -- seconds it aims ahead of a runner (less when they're far)
	},

	-- Faster than Roblox's 16 (owner: "make the people run quicker", and again: "make the running quicker at max
	-- speed"; was 20/24/26/23/26). Top speeds: Gameplay/Sprint builds up to them from a walk.
	Speeds = {
		Lobby = 22, -- everyone not in a game
		Runner = 28,
		Catcher = 30,
		Holder = 27, -- a runner carrying the girl
		LastRunner = 30, -- the only runner still out on the field (a catch-up: as fast as a catcher)
		Thief = 30, -- a catcher she's following (she walks behind him, so no slowdown)
	},

	-- Map parts. Each map is a folder or model in Workspace holding ZoneA, ZoneB and
	-- Middle (and optionally Bench); every game picks one of the maps at random.
	-- Lobby (anywhere) is where players wait between games; without it they stay put.
	Map = {
		ZoneA = "ZoneA", -- one side; round 1 starts here
		ZoneB = "ZoneB", -- the other side; round 1's safe zone
		LineupGap = 5, -- studs between runners standing on the line (a visible gap, as in the reference)
		Middle = "Middle", -- where catchers spawn
		Bench = "Bench", -- where caught runners wait out the round
		Lobby = "Lobby", -- where everyone waits between games (optional; else the SpawnBaseplate)
		MiddleSpawn = 20, -- catchers start within this many studs of the Middle's centre
		Gap = 30, -- studs between the lobby island and the map copied in front of it
		Names = {}, -- names shown in the vote, e.g. { Base_Map = "The Field" } (default: the folder name without "_Map")
		SafeLines = true, -- a white line where each zone meets the field, and SAFE ZONE over the goal's line
		LineWidth = 0.8,
		SignHeight = 9, -- the SAFE ZONE sign above the line (studs)
		WallHeight = 40, -- the start-line wall that holds runners until GO (invisible: the owner asked for no laser wall, Oct 18)
		BoundsHeight = 60, -- invisible walls round the field so nobody jumps off the map (0 = none)
		-- Maps go in as built, facing the lobby the way they faced it in Studio, except: FarSide names a
		-- landmark that must end up away from the lobby; OpenSide = true picks the side with fewer fences and
		-- walls to face the lobby, so people there can watch (owner's calls).
		FarSide = { Halloween_Map = "Mausoleum" },
		OpenSide = { BasketBall_Map = true },
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
	GirlRig = "Original", -- owner: the R15 rebuild came out deformed, so the girls stay exactly as built

	-- Weight = how often the round's girl comes from this rarity (only rarities that have girls count).
	-- Raised from 50/25/13/7/3.5/1.2/0.3 on the owner's request (too many Commons): out of 100 rounds about
	-- 28 Common, 24 Uncommon, 20 Rare, 14 Epic, 8 Legendary, 4.5 Mythic, 1.5 Secret.
	Rarities = {
		{ Name = "Common", Weight = 28, Color = Color3.fromRGB(196, 202, 214) },
		{ Name = "Uncommon", Weight = 24, Color = Color3.fromRGB(111, 214, 120) },
		{ Name = "Rare", Weight = 20, Color = Color3.fromRGB(86, 156, 255) },
		{ Name = "Epic", Weight = 14, Color = Color3.fromRGB(176, 104, 255) },
		{ Name = "Legendary", Weight = 8, Color = Color3.fromRGB(255, 190, 60) },
		{ Name = "Mythic", Weight = 4.5, Color = Color3.fromRGB(255, 84, 120) },
		{ Name = "Secret", Weight = 1.5, Color = Color3.fromRGB(30, 30, 30) },
	},
}
