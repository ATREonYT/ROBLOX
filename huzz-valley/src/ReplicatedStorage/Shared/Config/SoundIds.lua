--[[
	The game's sound effects (owner: "make these sound effects better"). Our own sounds, made by
	tools/sfx/make_sfx.py into assets/sfx/<name>.ogg (see assets/sfx/README.md).

	Every ID is empty until the owner uploads them (cloud sessions can't reach Roblox). How:
	  1. Studio > Window > Asset Manager > Bulk Import: pick every file in huzz-valley/assets/sfx.
	  2. In Asset Manager > Audio, select them all and drag them into Workspace.
	  3. Paste tools/studio/collect-sound-ids.lua into the Command Bar: it prints this file filled in
	     (lines starting with [HuzzSfx]); send that text to Claude, or paste it over this file.
	While an ID is empty the game plays Roblox's own stand-in (Gameplay/Sfx FALLBACK) or nothing.
]]
return {
	ui_click = "",
	ui_hover = "",
	ui_open = "",
	ui_close = "",
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
}
