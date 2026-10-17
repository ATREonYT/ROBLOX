--[[
	The game's sound effects (owner: "make these sound effects better"). Our own sounds, made by
	tools/sfx/make_sfx.py into assets/sfx/<name>.ogg (see assets/sfx/README.md).

	Every ID is empty until the owner uploads them (cloud sessions can't reach Roblox). How (also in README.md):
	  1. Studio > View > Asset Manager > Bulk Import: pick every file in huzz-valley/assets/sfx.
	  2. Right-click each sound > Copy ID, and paste it here next to its name (or send the list to Claude).
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
	secret_riser = "",
	secret_impact = "",
	secret_land = "",
}
