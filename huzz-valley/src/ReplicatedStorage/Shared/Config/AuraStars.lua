--[[
	Aura stars on the playing field (owner: "make the auras spawn inside the playing field, and if you just go into
	them they automatically collect, no need to press E"). While a map is loaded a few float over its field; run
	through one to collect it. Between games, with no map, they float round the lobby instead. The server places
	and pays them (HuzzServer/AuraPickupService); every client draws them (Gameplay/AuraStars). Rarer colours are
	worth more. Tune freely.
	Free to collect, so no odds screen is needed; Weight is just how often each colour appears.
]]
local rgb = Color3.fromRGB
return {
	Count = 7, -- stars out at once (on the field, or in the lobby when there's no map)
	Respawn = { 25, 45 }, -- seconds before a collected star's spot fills again (random in this range)
	Radius = 45, -- studs from the lobby spawn they can appear in
	Height = 3.2, -- studs above the floor they float
	Range = 4.5, -- studs: run this close to a star and it's yours
	Kinds = {
		{ Name = "Pink", Color = rgb(255, 120, 210), Value = 1, Weight = 15 },
		{ Name = "Blue", Color = rgb(90, 160, 255), Value = 1, Weight = 15 },
		{ Name = "Purple", Color = rgb(175, 110, 255), Value = 1, Weight = 15 },
		{ Name = "Yellow", Color = rgb(255, 215, 90), Value = 1, Weight = 15 },
		{ Name = "Green", Color = rgb(100, 240, 130), Value = 1, Weight = 15 },
		{ Name = "Red", Color = rgb(255, 90, 110), Value = 1, Weight = 15 },
		{ Name = "White", Color = rgb(245, 245, 255), Value = 3, Weight = 8 },
		{ Name = "Rainbow", Color = rgb(255, 255, 255), Value = 10, Weight = 2, Rainbow = true },
	},
}
