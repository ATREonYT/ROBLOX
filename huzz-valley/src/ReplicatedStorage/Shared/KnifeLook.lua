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

	Where it sits (owner, Oct 18: "make the knifes please be equipped when you have them, like be shown on the back of
	the character"; then "or even for the katanas you can make it be on the side of the person"):
	  in hand (a catcher in a round): the Grip attachment on the hand's grip, blade down and about 30 degrees forward;
	  on the back (most knives): diagonal across the upper back like a sword, handle up over the right shoulder, the
	    blade down to the left hip, flat side against the back, a little off the body so it never sinks in;
	  at the side (long slim blades, katana style): on the left hip, handle forward by the waist, the blade sloping
	    down and back like a sheathed sword, flat side out, edge up.
	Which one (KnifeLook.wearOf): the model's "Wear" attribute or the shop item's Wear field ("Back" / "Side") when
	set, else measured from the model itself (KnifeLook.shape): Side when it's at least SIDE.MinStuds long and its
	blade at least SIDE.Slender times longer than wide. Of the owner's 30 only Celestial Edge (SpinKnife) is Side;
	new models (the Game Pass knives) are sorted by the same rule, with no list to keep up.
	The old belt mount (Huss Valley's, docs/knife-study.md) sat low and flat behind the hips: the owner didn't see it.
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
-- The Game Pass knives (Config/CoinShop Pass, rarity "Exclusive"): Mythic's calm effects, nothing louder.
KnifeLook.LADDER.Exclusive = KnifeLook.LADDER.Mythic
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

-- Long slim blades go at the side (katana style), the rest on the back.
KnifeLook.SIDE = { MinStuds = 3.0, Slender = 5.5 }
local DANGLES = { "tassel", "chain", "cloth", "rope", "charm" } -- hanging bits: not part of pommel to tip

-- A knife's size from its parts, each { name, cf (in the Handle's space: +Y to the tip, X thin, Z the blade's
-- width), size }: length pommel to tip, the blade's length and width (parts named "...blade..."), how far it
-- reaches either way along its thin side (xMin, xMax: a guard sticks out further than the blade) and its widest
-- (width, along Z). Pure.
function KnifeLook.shape(parts: { { name: string, cf: CFrame, size: Vector3 } })
	local lo, hi = math.huge, -math.huge
	local blo, bhi, wlo, whi = math.huge, -math.huge, math.huge, -math.huge
	local xlo, xhi, zlo, zhi = math.huge, -math.huge, math.huge, -math.huge
	for _, p in parts do
		local n = string.lower(p.name)
		local dangle = false
		for _, d in DANGLES do
			if string.find(n, d, 1, true) then dangle = true end
		end
		if not dangle and n ~= "handle" then
			-- the part's box as seen along the Handle's axes
			local r, h = p.cf, p.size / 2
			local ey = math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z
			local ez = math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z
			local ex = math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z
			local c = r.Position
			lo, hi = math.min(lo, c.Y - ey), math.max(hi, c.Y + ey)
			xlo, xhi = math.min(xlo, c.X - ex), math.max(xhi, c.X + ex)
			zlo, zhi = math.min(zlo, c.Z - ez), math.max(zhi, c.Z + ez)
			if string.find(n, "blade", 1, true) then
				blo, bhi = math.min(blo, c.Y - ey), math.max(bhi, c.Y + ey)
				wlo, whi = math.min(wlo, c.Z - ez), math.max(whi, c.Z + ez)
			end
		end
	end
	if hi < lo then return { length = 0, bladeLength = 0, bladeWidth = 0, xMin = 0, xMax = 0, width = 0 } end
	local out = { length = hi - lo, bladeLength = 0, bladeWidth = 0, xMin = xlo, xMax = xhi, zMin = zlo, zMax = zhi, width = zhi - zlo }
	if bhi >= blo then out.bladeLength, out.bladeWidth = bhi - blo, whi - wlo end
	return out
end

-- True when a model is the knife it says it is: about its listed length (30%) along its blade, and much longer
-- than it is wide or thick. A setup that went wrong can leave a knife 10 times too big and lying sideways
-- (8 of the owner's Oct 18 file): that must never end up on someone's back.
function KnifeLook.sane(shape, studs: number?): boolean
	if not shape or shape.length <= 0 then return false end
	if math.max(shape.xMax - shape.xMin, shape.width) > 0.6 * shape.length then return false end
	if type(studs) ~= "number" then return shape.length > 1 and shape.length < 6 end
	return math.abs(shape.length - studs) <= 0.3 * studs
end

-- "Back" or "Side": what's set (the model's Wear attribute, else the shop item's Wear), else by its shape.
function KnifeLook.wearOf(set: string?, shape): string
	if set == "Back" or set == "Side" then return set end
	if not shape or shape.bladeWidth <= 0 then return "Back" end
	local slim = shape.bladeLength / shape.bladeWidth
	return if shape.length >= KnifeLook.SIDE.MinStuds and slim >= KnifeLook.SIDE.Slender then "Side" else "Back"
end

-- The body part each place hangs from: R15 UpperTorso (back) / LowerTorso (side), R6 Torso for both.
function KnifeLook.mountPart(wear: string, r6: boolean): string
	if r6 then return "Torso" end
	return if wear == "Side" then "LowerTorso" else "UpperTorso"
end

-- On the back, in the torso's space (+X right, +Y up, +Z the back): the grip high on the right shoulder blade, the
-- blade pointing down-left BACK_TILT degrees off straight down, its thin side facing back (flat against the back),
-- just off the back: GAP studs past the knife's thickest bit on that side (shape.xMin: a guard sticks out more than
-- the blade; 0.22 for a knife we can't measure). The handle (0.4 to 0.6 studs past the grip) ends over the right
-- shoulder, beside the head. Blocky R15 (UpperTorso 2 x 1.6 x 1) and R6 (Torso 2 x 2 x 1) with all of the owner's
-- knives: tests/KnifeWear.spec.luau checks no part goes into the head, torso, arms or legs, and none floats.
KnifeLook.BACK_TILT = 40
KnifeLook.GAP = 0.05
local function off(shape, side: number, default: number): number
	if not shape then return default end
	return math.max(0.04, side) + KnifeLook.GAP
end
function KnifeLook.backC0(torsoName: string, torsoSize: Vector3, shape: any?): CFrame
	local a = math.rad(KnifeLook.BACK_TILT)
	local tip = Vector3.new(-math.sin(a), -math.cos(a), 0)
	-- a blade wider on one side (a cleaver) keeps that side down-right, away from the head: knife +Z goes down-right,
	-- so a knife that reaches further to -Z is turned round (its other flat faces out)
	local flip = shape ~= nil and shape.zMin ~= nil and -shape.zMin > shape.zMax + 0.05
	local out = if flip then off(shape, shape.xMax, 0.22) else off(shape, shape and -shape.xMin or 0, 0.22) -- (the side facing the back)
	local at = Vector3.new(0.28 * torsoSize.X, torsoSize.Y / 2 - 0.25, torsoSize.Z / 2 + out)
	return CFrame.fromMatrix(at, Vector3.new(0, 0, if flip then -1 else 1), tip)
end

-- At the side (R15 LowerTorso, R6 Torso), like a sheathed sword: on the left hip just outside the leg, the grip in
-- front of the hip, the blade sloping SIDE_TILT degrees down toward the back, thin side out (flat side out), edge up.
KnifeLook.SIDE_TILT = 28
function KnifeLook.sideC0(torsoName: string, torsoSize: Vector3, shape: any?): CFrame
	local b = math.rad(KnifeLook.SIDE_TILT)
	local tip = Vector3.new(0, -math.sin(b), math.cos(b))
	local y = if torsoName == "Torso" then -torsoSize.Y / 2 - 0.25 else -0.45 -- (R6: one torso, so down to the hip)
	local out = off(shape, shape and shape.xMax or 0, 0.3) -- (knife +X faces the leg)
	local at = Vector3.new(-(torsoSize.X / 2 + out), y, -0.6)
	return CFrame.fromMatrix(at, Vector3.new(-1, 0, 0), tip)
end

-- Where a worn knife's grip goes on its body part (shape: KnifeLook.shape of the model, optional).
function KnifeLook.wornC0(wear: string, torsoName: string, torsoSize: Vector3, shape: any?): CFrame
	if wear == "Side" then return KnifeLook.sideC0(torsoName, torsoSize, shape) end
	return KnifeLook.backC0(torsoName, torsoSize, shape)
end

-- Which knife you wear (from the save): the one picked in the shop when you own it; never picked but you own knives:
-- the first you own in shop order; taken off, or none owned: nil = the default knife (owner's standing call:
-- "everyone even the runners have a knife mounted on their backs"). shop = Config/CoinShop.
function KnifeLook.pick(data, shop)
	if not data then return nil end
	local key = shop.worn(data, "Knife")
	local item = key and shop.get(key)
	if item and item.Slot == "Knife" then return item end
	if (data.Wear or {}).Knife ~= nil then return nil end
	local best = nil
	for k in data.Cosmetics or {} do
		local it = shop.get(k)
		if it and it.Slot == "Knife" and (best == nil or it.Order < best.Order) then best = it end
	end
	return best
end

-- In the right hand: the hand's grip point, the blade 150 degrees round the hand's X (down and forward).
function KnifeLook.handC0(gripAt: Vector3): CFrame
	return CFrame.new(gripAt) * CFrame.Angles(math.rad(-150), 0, 0)
end

return KnifeLook
