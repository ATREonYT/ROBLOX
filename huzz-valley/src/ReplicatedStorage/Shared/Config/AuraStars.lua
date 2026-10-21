--[[
	Aura stars in the playing zone (owner: "make the auras spawn inside the playing field, and if you just go into
	them they automatically collect, no need to press E"; then "taking the auras and making them be collected in the
	playing zone, make the different colors give different amounts of aura, and the ones that give more are rarer").
	While a map is loaded a few float over its crossing area (the Middle, between the two safe zones); run through
	one to collect it. Between games there are none. The server places and pays them (HuzzServer/AuraPickupService);
	every client draws them (Gameplay/AuraStars): rarer stars are bigger, sparkle more and glow brighter.
	Free to collect, so no odds screen is needed; Weight is how often each colour appears (out of 100 here).
	Tune freely.
]]
local rgb = Color3.fromRGB
return {
	-- (owner, Oct 21 17:34: "you get very quick aura and coins, so please pop it down a bit", so the Aura packs are worth
	-- buying: 7 stars every 25-45 s was ~1,900 Aura an hour at most, 19 crate opens; now ~550 at most)
	Count = 4, -- stars out at once on the field
	Respawn = { 60, 90 }, -- seconds before a collected star's spot fills again (random in this range)
	Inset = 8, -- studs kept clear of the Middle's edges (so none sit on a safe line or a wall)
	Height = 3.2, -- studs above the floor they float
	Range = 4.5, -- studs: run this close to a star and it's yours
	-- Common to rare: each step is worth more and shows up less (about 3 Aura a star on average).
	Kinds = {
		{ Name = "Blue", Color = rgb(90, 160, 255), Value = 1, Weight = 40 },
		{ Name = "Green", Color = rgb(100, 240, 130), Value = 2, Weight = 25 },
		{ Name = "Purple", Color = rgb(175, 110, 255), Value = 3, Weight = 16 },
		{ Name = "Pink", Color = rgb(255, 120, 210), Value = 5, Weight = 10 },
		{ Name = "White", Color = rgb(245, 245, 255), Value = 10, Weight = 6 },
		{ Name = "Rainbow", Color = rgb(255, 255, 255), Value = 25, Weight = 3, Rainbow = true },
	},
}
