--[[
	How a knife skin looks and sits (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it
	overly crazy, i want them to be nice"). Pure numbers; HuzzServer/KnifeService builds them on the knife, so
	everyone sees the same and nothing runs every frame.

	Effects climb with the rarity (Config/CoinShop Rarity), always in the knife's own glow colour (its glowing parts,
	Config/CoinShop Glow), calm, with no flashes:
	  Common     nothing: plain steel, like Huss Valley's default knife;
	  Uncommon   a faint sheen: a small glint on the blade now and then;
	  Rare       + a soft glow: a dim light round the blade;
	  Epic       + a few small sparkles (3 a second, never more than 4) and the slash trail in its colour;
	  Legendary  + a small light (Range 4) and its glow and sparkles stay on while it's on your back;
	  Mythic     + a few embers drifting up off the blade.
	Below Legendary, the knife on your back is just the model (its own Neon parts still glow); effects show in hand.
	Particles use Roblox's stand-in pictures until the owner uploads ours (Shared/FxTexture).

	Where it sits (docs/knife-study.md, Huss Valley's knives):
	  in hand: the Grip attachment on the hand's grip, blade along the forearm, down and about 30 degrees forward;
	  on the back: across the belt, flat, grip on the right hip, blade to the left and 15 degrees down, flat side out.
]]
local KnifeLook = {}

KnifeLook.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- Each rarity's effects (numbers are per second / studs). Every rarity has everything the one below it has.
KnifeLook.LADDER = {
	Common = {},
	Uncommon = { sheen = 0.5 },
	Rare = { sheen = 0.5, glow = { range = 2.5, brightness = 0.5 } },
	Epic = { sheen = 0.5, glow = { range = 2.5, brightness = 0.6 }, sparkles = 3, trailTint = true },
	Legendary = { sheen = 0.5, glow = { range = 4, brightness = 1 }, sparkles = 3, trailTint = true, back = true },
	Mythic = { sheen = 0.5, glow = { range = 4, brightness = 1 }, sparkles = 3, trailTint = true, back = true, embers = 1.5 },
}
KnifeLook.MAX_SPARKLES = 4 -- a second (owner: "dont make it overly crazy")

-- The effects for a skin's rarity (nil / unknown = the default knife: none).
function KnifeLook.fx(rarity: string?)
	return KnifeLook.LADDER[rarity or ""] or KnifeLook.LADDER.Common
end

-- The colour the knife's effects use: its glowing parts' colour, else its blade's.
function KnifeLook.colour(skin): Color3?
	if not skin then return nil end
	return skin.Glow or (skin.Colors and skin.Colors[1])
end

-- The slash: a short smear round the blade (Huss Valley: about one knife long, gone in about 0.1 s, no white arc).
-- Epic and up: the knife's colour fading to white; below that, a faint white smear.
KnifeLook.TRAIL = { Lifetime = 0.12, Tinted = { 0.2, 1 }, Plain = { 0.45, 1 }, LightEmission = 0.8 }

-- On the back (R15 LowerTorso, R6 Torso): grip on the right hip (+X), behind the body (+Z is the back), the blade
-- pointing left and 15 degrees down (105 degrees round the back axis), turned 90 degrees round itself so the flat of
-- the blade faces backward. Measured against docs/previews/knife-study-back.jpg.
function KnifeLook.backC0(torsoName: string, torsoSize: Vector3): CFrame
	local y = if torsoName == "Torso" then -0.75 else 0 -- (R6: one torso, so down to the belt)
	return CFrame.new(0.55, y, torsoSize.Z / 2 + 0.15) * CFrame.Angles(0, 0, math.rad(105)) * CFrame.Angles(0, math.rad(90), 0)
end

-- In the right hand: the hand's grip point, the blade 150 degrees round the hand's X (down and forward).
function KnifeLook.handC0(gripAt: Vector3): CFrame
	return CFrame.new(gripAt) * CFrame.Angles(math.rad(-150), 0, 0)
end

return KnifeLook
