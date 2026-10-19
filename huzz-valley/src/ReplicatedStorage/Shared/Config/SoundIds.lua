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
	lunge = "",
	trap_set = "",
	trap_snap = "",
	knock_down = "",
	revive = "",
	aura_pickup = "",
	speed_wind = "", -- a loop: play it with Gameplay/Sfx.loop

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
