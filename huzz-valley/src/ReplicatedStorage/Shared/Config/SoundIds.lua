--[[
	The game's sound effects, by name (Gameplay/Sfx plays them). Every value is a string: "rbxassetid://<number>",
	or "" while there is no real ID yet (then Sfx plays Roblox's own stand-in from its FALLBACK, or nothing).
	Never invent an ID: each one below says where it was seen (docs/sound-picks.md has the research and the reasons).

	Where the sounds come from (owner, Oct 19: "don't create random sound by yourself, do a research of what sounds good
	and not, and then logically select the best sounds"):
	  * Button sounds (ui_click/hover/open/close): Kenney's "Interface Sounds" (CC0, free for commercial games), copied
	    in as they are to assets/sfx/ui_*.ogg. They need the owner's upload: Studio > View > Asset Manager > Bulk
	    Import those 4 files, then run tools/studio/collect-sound-ids.lua and send the [HuzzSfx] lines.
	  * The Secret cutscene (secret_*): Roblox's own licensed library (Pro Sound Effects and APM Music, distributed by
	    Roblox for use in any experience). Public, so no upload: they play as soon as the IDs are here.
	  * Everything else: our own sounds from tools/sfx/make_sfx.py (assets/sfx), "" until the owner uploads them.
	Check every picked ID in Studio: tools/studio/check-sound-picks.lua (prints [HuzzSfx] OK/MISSING and plays each).
]]
return {
	ui_click = "", -- assets/sfx/ui_click.ogg = Kenney Interface Sounds drop_002 (CC0); upload, then paste its ID
	ui_hover = "", -- assets/sfx/ui_hover.ogg = Kenney select_002 (CC0)
	ui_open = "", -- assets/sfx/ui_open.ogg = Kenney maximize_009 (CC0): a short swell up
	ui_close = "", -- assets/sfx/ui_close.ogg = Kenney minimize_009 (CC0): the same swell going down
	ui_error = "",
	coin = "",
	reward = "",
	level_up = "",
	countdown_tick = "",
	countdown_go = "",
	roulette_tick = "",
	pick_land = "",
	hero_chosen = "",
	chicken_chosen = "",
	dash = "",
	stab = "",
	caught = "",
	rescue = "",
	safe = "",
	round_win = "",
	round_lose = "",
	step = "",
	heart_shield = "",
	power_rush = "",
	spin_tick = "",
	spin_win = "",
	spin_big_win = "",
	-- the 3D crate opening (owner, Oct 20 15:13: "make it feel premium"): assets/sfx/crate_*.ogg, made by
	-- tools/sfx/make_sfx.py; "" until the owner uploads them (then Sfx plays Roblox's stand-in or nothing)
	crate_thud = "", -- each of the three hops lands
	crate_latch = "", -- the latch pops and the lid cracks
	crate_open = "", -- the lid is flung open and hits its stop
	crate_rise = "", -- the knife lifts out
	crate_reveal = "", -- the knife stops in front of you (Common to Rare)
	crate_reveal_big = "", -- the same, Epic and up
	lunge = "",
	trap_set = "",
	trap_snap = "",
	knock_down = "",
	revive = "",
	aura_pickup = "",
	speed_wind = "", -- a loop: play it with Gameplay/Sfx.loop

	-- Oct 19 heartbeat: a licensed pick only (the coordinator's brief, owner: "don't create random sound by yourself").
	-- Roblox's library (Pro Sound Effects / APM) showed no heartbeat when searched from the cloud (only community
	-- uploads, not safe: docs/notes/sounds.md), so it stays "" (Gameplay/Sfx plays a soft built-in thump) until one is
	-- picked in Studio's Toolbox (Audio, creator ProSoundEffects or APMOfficial), with its store URL here and in
	-- docs/sound-picks.md.
	heartbeat = "", -- the red-edge pulse when a catcher is close (Gameplay/Heartbeat): one beat ("lub-dub") per play
	-- Oct 19 abilities: made in the game's sound family like the other power sounds (tools/sfx/make_sfx.py ->
	-- assets/sfx/<name>.ogg); "" until the owner uploads them.
	trap_throw = "", -- the Bear Trap leaving the hand
	invisible = "", -- turning invisible
	glitch = "", -- the Glitchy blink
	decoy = "", -- the Body Double splitting off
	-- Oct 20 Combine machine (Gameplay/CombineMachine, timed to Shared/CombineMotion): made by tools/sfx/make_sfx.py
	-- (assets/sfx/<name>.ogg); "" until the owner uploads them.
	combine_charge = "", -- the machine charging while the two girls circle (2 s)
	combine_merge = "", -- the burst as they become one
	combine_reveal = "", -- her new grade showing
	-- Oct 20 abilities (owner: "make them well made, right now they are kind of quick and feel cheap"): made in the
	-- same family by tools/sfx/make_sfx.py, "" until the owner uploads them
	power_charge = "", -- every ability's wind-up: a short soft riser under the cast pose
	power_end = "", -- an ability running out (Shield fizzles, Invisible shimmers back, a trap or peel folds away)
	power_ready = "", -- your ability card is ready again (quiet)
	banana_drop = "", -- the Banana Peel tossed behind you
	banana_slip = "", -- a catcher slipping on it
	smoke_bomb = "", -- the Smoke Bomb's puff
	radar_ping = "", -- the Radar's sweep
	lasso_throw = "", -- the Lasso leaving the hand
	lasso_hit = "", -- the Lasso catching a runner (or bouncing off a Shield)

	-- The Secret cutscene, keyed to its beats in Config/SecretSounds (Build, Burst, Reveal, End).
	-- "Light Cone Suck Synth And Reverse Cymbal Build, Disappear" (Pro Sound Effects, 5.7 s, Energy): the build-up
	-- https://create.roblox.com/store/asset/9125626784/Light-Cone-Suck-Synth-And-Reverse-Cymbal-Bui-SFX
	secret_riser = "rbxassetid://9125626784",
	-- "Sparkle Tone, Constant High End Shimmer, Sparkle, Glistening" (Pro Sound Effects, 18 s): the magic bed under the night
	-- https://create.roblox.com/store/asset/9125986205/Sparkle-Tone-Constant-High-End-Shimmer-Spark-SFX
	secret_shimmer = "rbxassetid://9125986205",
	-- "Magic Burst 2" (Pro Sound Effects, 1.8 s, Stings): the burst
	-- https://create.roblox.com/store/asset/9116384799/Magic-Burst-2-SFX
	secret_impact = "rbxassetid://9116384799",
	-- "Magic Insect Flying Pixie Dust Twinkles 4" (Pro Sound Effects, 8.6 s): the sparkle tail (fits the butterflies)
	-- https://create.roblox.com/store/asset/9116397511/Magic-Insect-Flying-Pixie-Dust-Twinkles-4-SFX
	secret_sparkle = "rbxassetid://9116397511",
	-- "Through the Looking Glass (sting)" (APM Music, Juice Music FANTASIA, 8 s: glockenspiel melody over orchestra): her reveal
	-- https://create.roblox.com/store/asset/1840018171/Through-the-Looking-Glass-sting
	secret_sting = "rbxassetid://1840018171",
	secret_land = "", -- (retired: the sting carries her landing; the old synthesized thump is gone)
}
