--[[
	StyleCannonBallStand: paste into the Command Bar after BuildCannonBallStand (then BuildCartoonyMap for
	the studs). Safe to run again.

	Alex, Oct 31: "make the stand that the cannon balls are on be more adapted to the map". The stand
	(Alex's GunStand_2Tiers model) keeps its shape exactly; only its colours change, from the cool
	blue-grey and white of a sci-fi armory to the island's own pirate palette:
	  - the base and kerbs are the grey stone of the map's paths;
	  - the walls, tiers and stairs are the two browns of the map's planks;
	  - the posts are dark wood;
	  - the caps, bands and pad rims are brass;
	  - the glow strip on the back wall is a warm lantern light.
	The colours were measured off the map file. The pads' State parts are left alone, because the game
	colours those (BallStand.lua: purple, and green for the ball you picked).
]]

local stand = workspace:FindFirstChild("CannonBallStand")
if not stand then
	error("[StandStyle] no CannonBallStand in Workspace: run BuildCannonBallStand first")
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local WOOD = rgb(176, 122, 69) -- the map's light plank
local WOOD_DARK = rgb(150, 100, 55) -- the map's darker plank
local WOOD_DEEP = rgb(105, 68, 38) -- posts and kick boards
local STONE = rgb(170, 163, 150) -- the map's path stones
local STONE_DARK = rgb(132, 126, 116)
local BRASS = rgb(225, 175, 70)
local BRASS_DARK = rgb(180, 132, 50)
local LANTERN = rgb(255, 196, 110)

local LOOK = {
	ArmoryApron = STONE,
	ApronKerb = STONE_DARK,
	ApronKerbTop = STONE,
	ApronCorner = STONE_DARK,
	ApronCornerCap = BRASS,
	ArmoryBack = WOOD_DARK,
	BackKick = WOOD_DEEP,
	BackBand = BRASS,
	BackCoping = WOOD_DEEP,
	ArmoryTier = WOOD_DARK,
	ArmoryTierTop = WOOD,
	TierBand = BRASS,
	TierKick = WOOD_DEEP,
	TierCoping = WOOD_DEEP,
	ArmoryStair = WOOD_DARK,
	StairTread = WOOD,
	Pilaster = WOOD_DEEP,
	CornerPost = WOOD_DEEP,
	PilasterCap = BRASS,
	PilasterBase = BRASS,
	CornerCap = BRASS,
	CornerBase = BRASS,
	PadBase = WOOD_DEEP,
	PadPlinth = WOOD_DARK,
	PadLip = BRASS,
	PlateCap = BRASS,
	PlateBolt = BRASS_DARK,
	MatRim = BRASS,
	PlazaDeck = STONE,
	PlazaKerb = STONE_DARK,
}

local done, glow, skipped = 0, 0, {}
for _, p in ipairs(stand:GetDescendants()) do
	if p:IsA("BasePart") and string.sub(p.Name, 1, 5) ~= "State" then
		if p.Material == Enum.Material.Neon then
			p.Color = LANTERN -- glowing trims become warm lantern light
			glow += 1
		elseif LOOK[p.Name] then
			p.Color = LOOK[p.Name]
			p.Material = Enum.Material.SmoothPlastic
			done += 1
		else
			skipped[p.Name] = true
		end
	end
end
local left = {}
for name in pairs(skipped) do
	table.insert(left, name)
end
print(("[StandStyle] %d parts in the island's colours, %d glow strips warm%s"):format(done, glow, #left > 0 and (", left as they were: " .. table.concat(left, ", ")) or ""))
