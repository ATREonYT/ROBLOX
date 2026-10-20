--[[
	The Combine machine's numbers and looks (owner, Oct 20 14:57: "can you please anime this combine machine, add a
	combine sign over it, and make it so that you can take two of the same girl, and then it creates the same skin,
	but first in silver, then gold, and then diamond. make it so that you need to have both of the types to go up.
	And make nice animations with vfx, gfx, sfx, and make a nice merging animation. Keep it smooth and tidy. and not
	too long"; 14:58 "also give the effects around the machine animations").
	Rules: Shared/CombineRules. The merge's timing: Shared/CombineMotion. The look of each grade on a girl:
	Shared/GirlGrade. The machine: HuzzServer/CombineService (prompt, sign, the merge itself) and
	Gameplay/CombineMachine (its idle loop and the merge on every screen); the window: UI/Screens/Combine.
	"Grade" is the combine step (Normal, Silver, Gold, Diamond). It is not Config/Characters' Tier (her rarity).
]]
local hex = Color3.fromHex

local Combine = {}

-- His model (Workspace > Combine > Combine_Machine). Found by these names, or by the CollectionService tag.
Combine.Folder = "Combine"
Combine.Model = "Combine_Machine"
Combine.Tag = "HuzzCombine"

-- Using it: walk up and press E (the prompt sits on his altar); one merge at a time per player.
Combine.Prompt = { Text = "Combine", Distance = 12 }
Combine.Reach = 30 -- studs: the server only merges for a player this close to the machine (the prompt is 12)
Combine.Cooldown = 1.5 -- seconds after a merge's answer before the same player can merge again
Combine.SaveWait = 10 -- seconds the server waits for the save before answering (the result shows after the save)

-- The sign over his arch (white words, dark outline: the game's look). A BillboardGui, so it reads from anywhere in
-- the lobby. Size in studs; Above = studs over the top of his model.
Combine.Sign = { Text = "COMBINE", Sub = "2 SAME GIRLS MAKE 1 BETTER", Width = 16, Height = 4.6, Above = 2.2, MaxDistance = 260 }

-- The grades, lowest to highest. Badge = the window's and the cards' badge colour. On the girl (Shared/GirlGrade):
--   Hair     her hair and accessories become this colour in Material (their picture is taken off so the colour
--            shows: the whole hairdo reads as silver / gold / crystal at a glance), with Reflectance and
--            Transparency (Diamond is see-through glass)
--   Cloth    her clothes' pictures are tinted by this (Shirt / Pants Color3: a multiply, details kept)
--   Fx       the small effect around her (world copies only, never in a picture): glints (sparkles_main), motes
--            (smoke_main), one soft light. Sizes are for a 5-stud girl and scale with her. Rates per second.
-- Owner (UI): "no gold anywhere" was about the windows' tone. The Gold grade is his own ask, so it is gold, but only
-- on the girl and her badge.
Combine.Grades = {
	Normal = { Name = "Normal", Badge = hex("8E9CC0") },
	Silver = {
		Name = "Silver", Badge = hex("D3DCEB"),
		Hair = hex("D9E0EA"), Material = Enum.Material.Metal, Reflectance = 0.22, Transparency = 0,
		Cloth = Color3.new(0.84, 0.88, 0.96),
		Fx = { Glint = { Color = hex("FFFFFF"), Rate = 1.6, Size = 0.5 }, Motes = nil, Light = nil },
	},
	Gold = {
		Name = "Gold", Badge = hex("FFD34D"),
		Hair = hex("F2BE3A"), Material = Enum.Material.Metal, Reflectance = 0.18, Transparency = 0,
		Cloth = Color3.new(1, 0.86, 0.5),
		Fx = {
			Glint = { Color = hex("FFE07A"), Rate = 3, Size = 0.55 },
			Motes = { Color = hex("FFC23A"), Rate = 2, Size = 0.3 },
			Light = { Color = hex("FFC870"), Brightness = 0.6, Range = 6 },
		},
	},
	Diamond = {
		Name = "Diamond", Badge = hex("8FE6FF"),
		Hair = hex("A6ECFF"), Material = Enum.Material.Glass, Reflectance = 0.3, Transparency = 0.18,
		Cloth = Color3.new(0.78, 0.93, 1),
		Fx = {
			Glint = { Color = hex("E6FBFF"), Rate = 4, Size = 0.7 },
			Motes = { Color = hex("8FE6FF"), Rate = 3, Size = 0.26 },
			Light = { Color = hex("9EE7FF"), Brightness = 0.8, Range = 7 },
		},
	},
}

-- The machine's idle loop (Gameplay/CombineMachine), his parts by name (the number after the last _ dropped):
--   RingSpin   seconds per turn of the ring's ticks and gems (one way) and its arcs and dots (the other way)
--   FloorSpin  seconds per turn of the floor ring's ticks round the altar
--   Bob        the fusion blade and the soul orb float up and down (studs, seconds per bob)
--   Wisps      his spirit flames drift (studs, seconds)
--   Glow       his glowing trim breathes: SurfaceAppearance EmissiveStrength x (1 - Pulse .. 1 + Pulse), seconds
--   Light      one soft light over the altar (his magenta), never blinking
--   Motes      soft motes rising round the machine; Sparkles twinkling round the ring
Combine.Idle = {
	RingSpin = 26, ArcSpin = 15, FloorSpin = 34,
	Bob = { Height = 0.18, Period = 2.6 },
	Wisps = { Drift = 0.55, Period = 5.5 },
	Glow = { Pulse = 0.22, Period = 3.2 },
	Light = { Color = hex("E978FF"), Brightness = 1.1, Range = 16 },
	Motes = { Color = hex("F3A6FF"), Rate = 4, Size = 0.35, Life = 3.2 },
	Sparkles = { Color = hex("FFE6FF"), Rate = 1.5, Size = 0.45 },
	Near = 160, -- studs: the loop runs only while the camera is this close
}

-- The merge (Shared/CombineMotion has the timeline). Height = the girls' height in his machine (they fit his ring).
Combine.Merge = {
	Height = 2.6,
	Orbit = 1.7, -- studs from the ring's middle where the two start circling
	ChargeSpeed = 6, -- the ring turns this many times faster at the peak of the charge
	ChargeGlow = 2.2, -- his glowing trim this many times brighter at the peak
	Burst = { Size = 7, Time = 0.45 }, -- the one flash (kid-safe: one, never repeated)
	Camera = { Back = 13, In = 10.5, Up = 1.4, Side = 0.12 },
}

-- Sounds (Config/SoundIds, made by tools/sfx/make_sfx.py; "" until the owner uploads them).
Combine.Sounds = { Charge = "combine_charge", Merge = "combine_merge", Reveal = "combine_reveal" }

return Combine
