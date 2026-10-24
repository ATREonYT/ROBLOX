--[[
	The AFK zone (owner's friend Aloninja, via the owner, Oct 24: "and an afk place system"): a round pad in the lobby.
	While you stand on it you are AFK: you are left out of every game (like SKIP, for as long as you stay; the
	SKIP count and "everyone skips" count you too), and your name tag says AFK. Step off and you play the next game.
	There is no reward for standing there. Going idle for IdleAfter seconds does the same (owner, Oct 24 06:12).
	HuzzServer/AfkService builds it: on his own part named AfkZone if the place has one (anywhere in Workspace;
	its middle and its width), else on open, flat ground beside the lobby's spawn pad (Search: studs across the
	carpet and into the plaza from the pad's middle, nearest first). Kid-safe: nothing flashes; the glow is steady.
]]
local Afk = {
	PartName = "AfkZone", -- his own part, if he places one
	Radius = 8, -- studs (the pad is 16 across)
	Height = 7, -- studs above and below the pad that still count as standing on it
	Check = 0.25, -- seconds between checks
	-- Owner, Oct 24 06:12: "if a person is not moving for 4-5 minutes the afk system starts": no key, click, touch,
	-- mouse or stick on their screen for this long and they're AFK too, until they touch anything (Gameplay/AfkRejoin).
	IdleAfter = 270,
	Color = Color3.fromRGB(150, 130, 255),
	Title = "AFK ZONE",
	Line = "Stand here to sit out games",
	Badge = "AFK", -- over your name tag while you're on it
	Search = {
		Across = { 26, -26, 32, -32, 38, -38, 44, -44, 52, -52 },
		Inward = { 4, 10, 0, 16, -4 },
	},
}

-- Whether a spot is on the pad (flat distance and height).
function Afk.inside(centre: Vector3, radius: number, pos: Vector3): boolean
	local dx, dz = pos.X - centre.X, pos.Z - centre.Z
	return dx * dx + dz * dz <= radius * radius and math.abs(pos.Y - centre.Y) <= Afk.Height
end

return Afk
