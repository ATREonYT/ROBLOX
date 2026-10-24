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
	-- go down and can be rescued; anyone still down at the end joins the catchers. Rounds go on until one
	-- runner is left: they win the game and the girl (owner, Oct 19: "make the round not be capped at 3").
	-- Catchers win when no runners are left. Crossings = clean rounds in a row that end a practice game
	-- (one runner and the bot).
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
	-- (owner, Oct 21 17:34: "pop it down a bit" so coin packs are worth buying: 25/50 was ~1,800 coins an hour, 15/30 is ~1,100)
	Pay = { Played = 15, Won = 30, WonAura = 3 },
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
	MaxRounds = 20, -- safety net only (runners who never get caught): the runners left win, she goes to her carrier
	-- Rescue (as in Huss Valley): a runner still out on the field stands within Range studs of a downed
	-- runner for Time seconds to get them back up.
	-- Rescued runners can't be stabbed for Shield seconds (no camping the downed).
	-- (Range 5.5 and Time 1.2 until Oct 24: owner, 07:03 "make the help action actuall work")
	Rescue = { Range = 8, Time = 1, Shield = 2 },
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
		-- Oct 19 (owner: "make the player to player touch WAY MORE accurate"): the box is the knife's real reach now,
		-- arm plus blade (4.5 from the middle = 4 studs past the chest), and only the runner's body parts count
		-- (Shared/TouchHit: no hats, hair or wings). Was 5.5 x 4 with accessories counted, and the server took any claim
		-- within Range + Slack (11.5 studs) of the catcher.
		Reach = 4.5,
		Width = 3.5,
		Slack = 3, -- (unused since Oct 19: the server checks the knife's box against the body, Touch below)
		-- seconds between stabs, hit or miss (owner, Oct 19: "one second charge time for knife only"; was 0.6). The
		-- knife charges back up on the catcher's bar (Screens/PowerBar: KNIFE CHARGING).
		Cooldown = 1.0,
		Time = 0.40, -- the slash, Huss Valley's (docs/knife-study.md): no wind-up, the sweep lands ~0.07 s, held, back by 0.40 (Shared/StabMotion)
	},
	TagRange = 5.5, -- "Touch" only: studs between root parts
	-- How the server judges a touch (Shared/TouchHit, HuzzServer/HitHistory, RoundService): the knife's box (Stab or
	-- Lunge Reach x Width) must overlap the runner's body parts, give or take Tolerance studs.
	-- Pinpoint (owner Oct 19, RoundService.screenHit + TouchHit.verify): the catcher's screen sends where it showed the
	-- runner (seen) and the catcher (mine). The server ties seen to ONE moment of the runner's history (within
	-- SeenSlack studs, no further back than the catcher's ping + Smoothing + 0.05 s, at most MaxRewind), takes the
	-- runner's turn from its own history, wants mine within MineSlack of where it has the catcher over the last
	-- MineBack seconds (or Lead seconds on at their speed: a diving screen is a packet ahead), points the knife the
	-- server's way within FaceSlack degrees, and caps the reach at an honest one plus CapSlack studs (a critic's cheat
	-- test: the first version reached 9.9 studs and stabbed behind; now 6.35, honest 5.35, never behind).
	-- A claim that fails, an old client and the sim's bots without a claim: the look-back below, up to the catcher's
	-- one-way lag plus Smoothing seconds back, at most MaxRewind. The Practice Bot's knife is checked where the runner's screen showed
	-- the bot (Smoothing seconds back). Keep: seconds of history kept.
	Touch = { Tolerance = 0.4, Smoothing = 0.1, MaxRewind = 0.35, SeenSlack = 1.5, MineSlack = 1.5, MineBack = 0.2, Lead = 0.06,
		FaceSlack = 35, CapSlack = 1, Keep = 0.6, AheadMax = 10.5 },
	-- Everyone else drawn where the server has them now (Gameplay/OthersAhead; owner, Oct 22 19:45: "you see the
	-- difference in user locations, please fix it with the desync"): ahead along their movement by your half ping +
	-- Interp s (Roblox's smoothing, an estimate), at most MaxLead s and MaxStuds studs; Smooth = how fast the offset
	-- follows (per s); a body faster than MaxSpeed studs/s is a teleport (drawn where it is).
	-- StampSmooth (Oct 23): the same easing when the body's own stamps say where it is (Shared/MotionStamps): quicker,
	-- since a stamp already knows where it's heading (12 would trail a turn by ~0.08 s).
	Ahead = { Interp = 0.1, MaxLead = 0.3, MaxStuds = 8, Smooth = 12, MaxSpeed = 150, StampSmooth = 25 },


	-- The huss (owner's call): Space throws you left or right on your screen. Jumping is off. The push eases every
	-- frame from Speed down to EndSpeed (studs/s) over Time seconds (Shared/RunMotion.pushSpeed, Ease = the curve's
	-- power), then the run takes over. Owner, Oct 18: "make the dash go a bit further ... but not too much": ~12 studs
	-- (was 9). Cooldown before the next.
	-- Oct 19 (owner: "their huss is way quicker than ours, make it more smooth and quicker reset Huss (2 seconds)"):
	-- Huss Valley's ground slides ~4x the run's speed for a moment, then drops sharply (docs/feel-study.md gap 7);
	-- ours eased 64 to 28 over 0.30 s, so mid-huss it was barely faster than the run. Now a hard burst at 120 easing
	-- out (Ease 3: cubic) to 16 over 0.28 s: about the same 12 studs (0.28 x (16 + 104/4)), 80% of it in the first
	-- 0.15 s (was 0.22 s), and it ends at 16 sideways instead of 28, so the hand-back to the run is soft.
	-- Cooldown 2 s (owner's number; was 2.5).
	Dash = { Speed = 120, EndSpeed = 16, Time = 0.28, Ease = 3, Cooldown = 2 },
	-- Owner, Oct 24: "if you huss infront of someone they go from 1x-0.75x speed": a huss (in a game, while running)
	-- whose path passes up to Ahead studs in front of someone on the other side, and at most Side studs to their side,
	-- slows them to Slow of their speed for Time seconds (RoundRules.cutsOff). Path = the huss's length (about 12, above).
	-- (Slow 0.75 until Oct 24 10:21: "make when you huss a seeker. they go to 0.82x not 0.75x")
	Cut = { Ahead = 12, Side = 4, Path = 12, Slow = 0.82, Time = 2 },
	-- Catchers' Space (owner: "when they press space they jump and haul at the runner, and if they go into them,
	-- they get stabbed"): a leap forward the way they face, a hard burst that eases off (Speed to EndSpeed over
	-- Time: 0.38 x (40 + 32/3) = 19 studs, the old flat 56 x 0.36 reach). Any runner they reach during the leap
	-- (HitWindow seconds) is stabbed, the same as the knife. Shares the Space cooldown tile.
	-- Reach/Width: the leaping knife's box along the leap; it must touch the runner's body (Shared/TouchHit, on the
	-- screen and on the server, Oct 19). HitRange is only the simulation bot's "close enough to leap".
	-- Up: the hop (studs/s up). Oct 19 knife pass 2: 24, was 18. At 18 the body was off the floor for 0.18 s (5 frames)
	-- and 0.8 studs high, too short to show a leap at all (Huss Valley's catcher is in the air ~0.4 s); 24 = 0.245 s and
	-- 1.5 studs, long enough for the take-off, the knife leading and the landing (Shared/StabMotion LEAP). Distance unchanged.
	-- Oct 19 (owner: "add a dive feature for the tagger and after they use it they are stunned for 2 seconds"): the leap
	-- is a dive (Shared/StabMotion LEAP: a quick crouch, a straight dive, a belly landing, a pop up to the feet).
	-- Oct 20 15:13 (owner: "right now its like a ragdoll, make it straight to the point and without a long
	-- unconsiousness, make it concrete"): Stun 0.4, was 2. From StunAfter (the push's end) for Stun seconds: no moving,
	-- stabbing or powers (HuzzServer/PowerService.stun), shown on the bar (STUNNED); no stars or 💫 badge for a stun
	-- this short. Back on your feet and moving 0.78 s after the press (Huss Valley's catcher: up ~0.67 s after
	-- the leap, docs/knife-study.md). Slide: after the push the belly slides on from EndSpeed to a stop over this many
	-- seconds (RunMotion.lungeSpeed: ~2.1 studs, fast then settling) instead of stopping dead. Cooldown 3 s (from the
	-- press) keeps it from being spammed.
	Lunge = { Speed = 72, EndSpeed = 40, Up = 24, Time = 0.38, Cooldown = 3, HitRange = 4.8, HitWindow = 0.5, Reach = 4.5, Width = 4,
		Stun = 0.4, StunAfter = 0.38, Slide = 0.16 },

	-- Moving a player's body (HuzzServer/PlaceService; owner, Oct 20 15:13: "make the DSYNC way, way better"): the
	-- owner's own screen moves it; the server waits Grace seconds plus the player's round trip, and moves it itself
	-- only if its copy isn't within Near studs by then. StreamWait: seconds at most to load the spot around them first.
	-- (Grace 0.4 until Oct 24: under lag a screen took longer, the server moved the body itself and the two fought:
	-- owner, 07:04 "moving very glitchy")
	Place = { Grace = 1.2, Near = 4, StreamWait = 1 },
	-- A caught runner falls flat on their face and lies there until rescued or the next round
	-- (owner's call).
	Knockdown = {
		FallTime = 0.45, -- seconds from standing to flat
		Bounce = 0, -- degrees of bounce when they hit the floor (owner: no swinging; they land and lie still)
		Lift = 0.6, -- torso thickness: how far the body lies above the floor (a hair over half, so nothing dips in)
		ArmsOut = 125, -- arms out past the shoulders, flat on the floor (degrees from hanging)
		HeadTurn = 20, -- head turned to one side (degrees)
		ChinUp = 40, -- chin lifted off the floor (degrees)
		-- studs the body carries on forward as it falls (knife pass 2: it stopped dead from a sprint); shorter before
		-- a wall (KnockdownService: DownedSlide)
		Slide = 2.2,
		-- The catch without the snap back (owner, Oct 21: "check the desync again ... best possible performance").
		-- The runner's own screen is ahead of the server's copy by about half their ping, so lying down where the
		-- server saw them pulled them back a few studs. The server adds their forward run over half their ping (at
		-- most Lead seconds) to the slide (KnockdownService), and every screen eases its own last view of the body
		-- into the fall over Blend seconds (Gameplay/Knockdown, DownMotion.blendAt), unless it is more than
		-- BlendMax studs off (a teleport: no glide across the map).
		Lead = 0.15, Blend = 0.3, BlendMax = 12,
	},
	StartZoneSafe = true, -- catchers can't tag runners still standing in their start zone

	-- The Practice Bot (HuzzServer/PracticeBot; owner picked "Yes, add bots" so a round works alone): a catcher that
	-- joins any round with runners and no catcher. Slower than a sprinting runner (28) so the huss and a straight run
	-- beat it; it never wins a girl and is never paid.
	Bot = {
		Enabled = true,
		Name = "Practice Bot",
		-- Owner, Oct 24: "make the bots better so if people join they have someone to vs" (and runners now run 35):
		-- was Speed 24 between 18 and 28, Reaction 0.6, aiming at most 0.35 s ahead and no lunge.
		Speed = 25, -- studs a second (where it starts; 30 until runners went back to 28, Oct 24 18:22)
		-- It adapts to the kids playing it (loop audit, Oct 17: how often a kid alone beat it swung from 14% to 82%
		-- with how well they steer): Step slower after it wins a game, Step faster after it loses, between MinSpeed and
		-- MaxSpeed (never as fast as a runner's 28). The message line says so.
		MinSpeed = 21,
		MaxSpeed = 27, -- (32 while runners ran 33.6, Oct 24)
		Step = 2,
		Reach = 5, -- studs at its starting Speed: it stabs a runner this close (no lag allowance); scales with its speed
		Pause = 1.0, -- seconds it stands still after each stab
		Reaction = 0.4, -- seconds after GO before it moves
		Think = 0.15, -- seconds between picking where to run
		Lead = 2.5, -- at most this many seconds it aims ahead of a runner: where they'll meet (PracticeBot meetIn)
		-- A haul at a runner From to To studs off with nothing in the way, like a catcher's Space: Boost x its speed for
		-- Time seconds, then Cooldown seconds before the next.
		Lunge = { From = 6, To = 18, Boost = 1.8, Time = 0.35, Cooldown = 2.5 }, -- (its reach is 1.3x while it lunges)
	},

	-- Faster than Roblox's 16 (owner: "make the people run quicker", and again: "make the running quicker at max
	-- speed"; was 20/24/26/23/26). Top speeds: Gameplay/Sprint builds up to them from a walk.
	-- Owner, Oct 19: "speed goes up every round a very tiny bit" (Huss Valley's round banner says "Speed unchanged"
	-- or what changed): every round after the first, runners' and catchers' top speeds (and the Practice Bot's) go up
	-- PerRound, up to Max (Shared/RoundRules.speedScale, RoundService.speedFor). The lobby never changes.
	-- Owner, Oct 24: "Make hunters 1x speed and normal peopl 1,25x": catchers keep the old runner top (28), runners
	-- run 1.25x that (35). Was Runner 28, Catcher 30, Holder 27, LastRunner 30, Thief 30.
	-- Owner, Oct 24 10:21: "make the speed of the runner 1.2x": runners 1.2 x 28 = 33.6 (carrying her 32.6).
	-- Owner, Oct 24 18:22: "make catchers speed 1.12 and runners 1": runners back to 28, catchers 1.12 x 28 = 31.36
	-- (the last runner out gets a catcher's speed again, as before Oct 24).
	SpeedUp = { PerRound = 0.02, Max = 0.20 },
	Speeds = {
		Lobby = 22, -- everyone not in a game
		Runner = 28,
		Catcher = 31.36,
		Holder = 27, -- a runner carrying the girl
		LastRunner = 31.36, -- the only runner still out on the field: as fast as a catcher
		Thief = 31.36, -- a catcher she's following (she walks behind him, so no slowdown)
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
		Lobby = "Lobby", -- where everyone waits between games (optional; else the plaza of each copy of his new lobby in Workspace > StartingPoint, else the SpawnBaseplate: Shared/LobbyLayout)
		MiddleSpawn = 20, -- catchers start within this many studs of the Middle's centre
		Gap = 30, -- studs between the lobby island and the map copied in front of it
		Names = {}, -- names shown in the vote, e.g. { Base_Map = "The Field" } (default: the folder name without "_Map")
		-- The picture on each map's vote card and NEXT MAP tile (Config/Assets.Art name; owner's pictures, Oct 18).
		-- A map not listed here shows a live 3D view of itself instead.
		Pictures = { Base_Map = "MapBase", Halloween_Map = "MapHalloween", BasketBall_Map = "MapBasketball" },
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
	-- Owner, Oct 23 15:22 / 15:25: "make the girls chances be way lower ... so its worth to buy more luck"; then 17:49:
	-- "make the percentage less common based so you get more rares and epics, but keep it enough so people get the dev
	-- product for more luck in the server, but make them get way more rares and above". With no luck, out of 1,000
	-- rounds about 528 Common, 170 Uncommon, 132 Rare, 94 Epic, 45 Legendary, 23 Mythic, 8 Secret (Rare or better:
	-- 30%, it was 13%). The server's luck (Luck below, HuzzServer/LuckService) multiplies every Lucky rarity's weight:
	-- x2 makes Common 36%, x5 18%, x10 10% (and Secret 1.4%).
	Rarities = {
		{ Name = "Common", Weight = 28, Lucky = false, Color = Color3.fromRGB(196, 202, 214) },
		{ Name = "Uncommon", Weight = 9, Color = Color3.fromRGB(111, 214, 120) },
		{ Name = "Rare", Weight = 7, Color = Color3.fromRGB(86, 156, 255) },
		{ Name = "Epic", Weight = 5, Color = Color3.fromRGB(176, 104, 255) },
		{ Name = "Legendary", Weight = 2.4, Color = Color3.fromRGB(255, 190, 60) },
		{ Name = "Mythic", Weight = 1.2, Color = Color3.fromRGB(255, 84, 120) },
		{ Name = "Secret", Weight = 0.4, Color = Color3.fromRGB(30, 30, 30) },
	},
	-- Server luck (owner, Oct 23: "add a x2 luck, x4 luck, x8 luck dev products ... if someone bought server luck, it
	-- stays with the person while he is in the game, and then when he leaves it resets"; "they can go up to like 10x").
	-- A buy sets its buyer's luck (x2 to x10, his nine products); the server's luck is the highest of anyone here,
	-- never above Max. When a buyer leaves, their boost goes with them. The products: Config/Products.Luck.
	-- Curve (Oct 23 19:39): how the steps grow (Shared/GirlRoll.power): x2 is a small step, x7 and x8 big ones.
	Luck = { Max = 10, Curve = 1.8 },
}
