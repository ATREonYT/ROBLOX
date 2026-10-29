--[[
	How a knife skin looks and sits (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it
	overly crazy, i want them to be nice"). Pure numbers; HuzzServer/KnifeService builds them on the knife, so
	everyone sees the same and nothing runs every frame.

	Effects, by rarity (owner, Oct 20 07:43: "Can you make the vfx for some swords way better and more detailed, make
	them better for more high end ones"; 07:47: "check out the references provided from Huss valley, and then
	implement the vfx based on it. Make them fit and logically connected to the skin of the sword"). Built from Huss
	Valley's own skins (VFX below; the study in docs/notes/knives.md): a few small glowing motes in the skin's gem
	colour drifting near the blade, its motif (embers, frost, petals...) as a light touch, a star glint on the gem now
	and then, a little more on a swing. Common and Uncommon stay plain (03:01 that morning: "please just make them be
	normal"), and nothing uses a picture we haven't uploaded (only Roblox's own built-in ones, VFX.TEX):
	  Common, Uncommon  a soft slash trail in the knife's own colour on a swing (faint: trailSoft); nothing else;
	  Rare              the trail a little stronger, and one or two faint motes (moving as its theme does);
	  Epic              + the catcher's slash arc in its colour (arc: SlashColor), 2 crisp ball motes, its motif,
	                    the gem glowing, a few sparkles a slash;
	  Legendary, Mythic and the Game Pass knives: the gem glowing (a solid Neon ball, the light its bloom), 3 crisp
	                    ball motes drifting round the blade (4 on a stand), the motif readable worn, the gem's
	                    glint, a soft light, a longer trail.
	A Game Pass knife's trail and effect colour are its element's (ELEMENTS below: their old emit lists used our own
	pictures, which aren't uploaded, so nothing builds them: VFX themes replace them).

	Where it sits (owner, Oct 18: "make the knifes please be equipped when you have them, like be shown on the back of
	the character"; Oct 19: "make the knifes when equipped be worn either on the back of the character or on the side.
	This is very important, and make the location based on what knife/sword it is"):
	  in hand (a catcher in a round): the Grip attachment on the hand's grip, blade down and about 30 degrees forward;
	  on the back (long blades: swords, katanas, his reapers and scythe): diagonal across the upper back like a sword
	    in a back sheath, the handle end up over the right shoulder, the rest down to the left hip, flat side against
	    the back, a little off the body (and over a cape or long hair) so it never sinks in;
	  at the side (short knives and daggers): on the right hip at the belt, blade down, flat against the hip, just
	    behind the hanging arm.
	Which one (KnifeLook.wearOf): the shop table's Wear field (Config/CoinShop: every knife has one, "Back" or "Side",
	picked from his .glb's measured length and shape; the owner can change any of them), else the model's "Wear"
	attribute, else measured from the model itself (KnifeLook.shape): Back when BACK.MinStuds long.
	The old belt mount (Huss Valley's, docs/knife-study.md) sat low and flat behind the hips: the owner didn't see it.
]]
local KnifeLook = {}

KnifeLook.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- Each rarity's effects (numbers are per second / studs). Every rarity has everything the one below it has.
KnifeLook.LADDER = {
	Common = { trailTint = true, trailSoft = true },
	Uncommon = { trailTint = true, trailSoft = true },
	Rare = { trailTint = true },
	Epic = { trailTint = true, arc = true },
	Legendary = { trailTint = true, arc = true },
	Mythic = { trailTint = true, arc = true },
}
-- The default knife (no skin): nothing, the plain white smear.
KnifeLook.NONE = {}
-- The Game Pass knives (Config/CoinShop Pass, rarity "Exclusive"): Mythic's.
KnifeLook.LADDER.Exclusive = KnifeLook.LADDER.Mythic

-- The effects for a skin's rarity (nil / unknown = the default knife: none).
function KnifeLook.fx(rarity: string?)
	return KnifeLook.LADDER[rarity or ""] or KnifeLook.NONE
end

-- The colour the knife's effects use: its glowing parts' colour, else its blade's.
function KnifeLook.colour(skin): Color3?
	if not skin then return nil end
	return skin.Glow or (skin.Colors and skin.Colors[1])
end

-- The slash: a short smear round the blade (Huss Valley: about one knife long, gone in about 0.1 s, no white arc).
-- Epic and up: the knife's colour fading to white; below that, a faint white smear.
-- A Game Pass knife's trail is in its element's colours and lasts a little longer (ElementLifetime), so its arc reads
-- (owner, Oct 19: "better knife animations ... during gameplay").
-- Common and Uncommon (trailSoft, Oct 19 evening): its own colour, as faint as the old white one (Soft), less glow.
KnifeLook.TRAIL = { Lifetime = 0.12, ElementLifetime = 0.17, Tinted = { 0.2, 1 }, Soft = { 0.45, 1 }, Plain = { 0.45, 1 },
	LightEmission = 0.8, SoftLightEmission = 0.4 }
-- The trail's colours, see-through (start, end) and LightEmission for a skin (nil skin = the default knife), as
-- HuzzServer/KnifeService and Gameplay/AvatarStands build it: { colours = { a, b }, transparency = { a, b }, light }.
function KnifeLook.trailLook(skin, el)
	local T = KnifeLook.TRAIL
	local look = KnifeLook.fx(skin and skin.Rarity)
	local colour = KnifeLook.colour(skin)
	local white = Color3.new(1, 1, 1)
	if el then return { colours = { el.trail[1], el.trail[2] }, transparency = T.Tinted, light = T.LightEmission } end
	if not (look.trailTint and colour) then return { colours = { white, white }, transparency = T.Plain, light = 0.3 } end
	if look.trailSoft then -- (its colour, lifted a little so a dark blade's trail still reads)
		return { colours = { colour:Lerp(white, 0.25), white }, transparency = T.Soft, light = T.SoftLightEmission }
	end
	return { colours = { colour, white }, transparency = T.Tinted, light = T.LightEmission }
end

-- The lobby stands' aura (owner, Oct 19 evening: "make the gamepass characters look better without that green circle
-- on the bottom, and add some vfx, make the characters more atrractive so people buy the knifes"): no disc under the
-- feet any more; in the stand's colour (its knife's element light, else the pass colour) a ring of soft specks rises
-- from round the feet (Motes, from an invisible ring Width wide), a few stars twinkle round the body (Twinkles, in a
-- column Width x Height), and a soft light sits in front of the chest (Light: Front studs out, Up over the root, its
-- colour Whiten of the way to white, so faces stay their colour with a hint of it). Calm: under 10 particles a
-- second, each fades in and out over a second or more, nothing flashes. Gameplay/AvatarStands builds it;
-- tools/preview/motion3d/stand_knives_scene.luau draws it.
KnifeLook.AURA = {
	Width = 3.4, Height = 5.2,
	Light = { Brightness = 0.7, Range = 7, Front = 2.2, Up = 0.9, Whiten = 0.45 },
	Motes = { texture = "Glow", rate = 7, life = { 1.6, 2.4 }, speed = { 0.6, 1.1 }, size = 0.5, rise = 0.5, whiten = 0.35 },
	Twinkles = { texture = "Twinkle", rate = 2.5, life = { 0.9, 1.3 }, size = 0.7, whiten = 0.6 },
}

-- Long blades go on the back, short knives at the hip (KnifeLook.wearOf, for a knife the shop table doesn't name):
-- MinStuds or more pommel to tip = Back. His knives sit 1.2 to 3.4 studs in the game and 3.0 is where his swords
-- start (measured, tools/knives/wear_table.luau: Blood Moon Tanto 2.98 is the longest dagger, Shadow Cleaver 3.08 the
-- shortest long blade). PoleShare: a long knife with that share of its length or more below the grip is a
-- two-handed pole (his reapers and scythe, gripped mid-pole), worn head up (KnifeLook.backC0).
KnifeLook.BACK = { MinStuds = 3.0, PoleShare = 0.45 }
local DANGLES = { "tassel", "chain", "cloth", "rope", "charm" } -- hanging bits: not part of pommel to tip

-- A knife's size from its parts, each { name, cf (in the Handle's space: +Y to the tip, X thin, Z the blade's
-- width), size }: length pommel to tip, the blade's length and width (parts named "...blade..."), how far it
-- reaches either way along its thin side (xMin, xMax: a guard sticks out further than the blade) and its widest
-- (width, along Z). front: how far it reaches forward when hung at the hip (KnifeLook.sideC0), each way round, from
-- its real corners (a curved blade's widest bit and its pommel aren't at the same height). Pure.
function KnifeLook.shape(parts: { { name: string, cf: CFrame, size: Vector3 } })
	local lo, hi = math.huge, -math.huge
	local tilt = math.rad(KnifeLook.SIDE_TILT)
	local ts, tc = math.sin(tilt), math.cos(tilt)
	local fPlus, fMinus = math.huge, math.huge
	local blo, bhi, wlo, whi = math.huge, -math.huge, math.huge, -math.huge
	local xlo, xhi, zlo, zhi = math.huge, -math.huge, math.huge, -math.huge
	for _, p in parts do
		local n = string.lower(p.name)
		local dangle = false
		for _, d in DANGLES do
			if string.find(n, d, 1, true) then dangle = true end
		end
		if n ~= "handle" then -- (front counts the hanging bits too: a kunai's ring and tassel hang by the hip)
			local r, h = p.cf, p.size / 2
			for _, k in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1) } do
				for _, sgn in { 1, -1 } do
					local q = r * (Vector3.new(h.X * k.X, h.Y * k.Y, h.Z * k.Z) * sgn)
					fPlus, fMinus = math.min(fPlus, ts * q.Y - tc * q.Z), math.min(fMinus, ts * q.Y + tc * q.Z)
				end
			end
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
	local out = { length = hi - lo, bladeLength = 0, bladeWidth = 0, xMin = xlo, xMax = xhi, zMin = zlo, zMax = zhi, width = zhi - zlo,
		yMin = lo, yMax = hi, front = { fPlus, fMinus } }
	if bhi >= blo then out.bladeLength, out.bladeWidth = bhi - blo, whi - wlo end
	return out
end

-- True when a model is the knife it says it is: about its listed length (30%) along its blade, and much longer
-- than it is wide or thick. A setup that went wrong can leave a knife 10 times too big and lying sideways
-- (8 of the owner's Oct 18 file): that must never end up on someone's back. wide: how wide this knife really is for
-- its length (his sickles, karambits and shurikens, Halloween Oct 19: the Wide attribute or shop row, from
-- tools/knives/bake_knives.py), so his own wide shapes still count as knives.
function KnifeLook.sane(shape, studs: number?, wide: number?): boolean
	if not shape or shape.length <= 0 then return false end
	local most = if type(wide) == "number" then math.max(0.6, math.min(wide, 2) * 1.15) else 0.6
	if math.max(shape.xMax - shape.xMin, shape.width) > most * shape.length then return false end
	if type(studs) ~= "number" then return shape.length > 1 and shape.length < 6 end
	return math.abs(shape.length - studs) <= 0.3 * studs
end

-- True for a two-handed pole: long, and gripped mid-pole (his reapers and scythe).
function KnifeLook.twoHanded(shape): boolean
	return shape ~= nil and shape.yMin ~= nil and shape.length >= KnifeLook.BACK.MinStuds
		and -shape.yMin >= KnifeLook.BACK.PoleShare * shape.length
end

-- "Back" or "Side". set: the shop table's Wear (Config/CoinShop, one per knife: the owner's to change), else the
-- model's Wear attribute; with neither, measured: long (BACK.MinStuds) = Back, else Side.
-- HIP = false: every knife goes on the back (owner, Oct 21 15:23, his picture of a knife hanging beside his leg:
-- "make the location of the knife on the character itself, not in the air"; his standing call: "everyone even the
-- runners have a knife mounted on their backs"). true brings the short ones back to the hip (the table's Wear).
KnifeLook.HIP = false
function KnifeLook.wearOf(set: string?, shape, attr: string?): string
	if not KnifeLook.HIP then return "Back" end
	if set == "Back" or set == "Side" then return set end
	if attr == "Back" or attr == "Side" then return attr end
	if not shape or shape.length <= 0 then return "Back" end
	return if shape.length >= KnifeLook.BACK.MinStuds then "Back" else "Side"
end

-- The body part each place hangs from: R15 UpperTorso (back) / LowerTorso (side), R6 Torso for both.
function KnifeLook.mountPart(wear: string, r6: boolean): string
	if r6 then return "Torso" end
	return if wear == "Side" then "LowerTorso" else "UpperTorso"
end

-- Capes, wings and long hair (the avatar's own accessories): how far behind the back they reach, so a knife on the
-- back goes over them, never through. boxes: each accessory's Handle { cf, size } in the back mount's torso space
-- (+Z the back). Only what hangs down over the back counts (inside the torso's width, below the shoulder line: short
-- hair and hats don't push it out). More than CLEAR.Max (big wings): the knife goes to the hip instead (KnifeLook.wornAt), where wings
-- don't reach, rather than floating far off the back.
KnifeLook.CLEAR = { Max = 0.9 }
function KnifeLook.backClear(boxes: { { cf: CFrame, size: Vector3 } }?, torsoSize: Vector3): number
	local most = 0
	for _, b in boxes or {} do
		local r, h = b.cf, b.size / 2
		local ex = math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z
		local ey = math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z
		local ez = math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z
		local c = r.Position
		local overX = c.X - ex < torsoSize.X / 2 and c.X + ex > -torsoSize.X / 2
		local overY = c.Y - ey < torsoSize.Y / 2 - 0.1 and c.Y + ey > -torsoSize.Y / 2
		if overX and overY then most = math.max(most, c.Z + ez - torsoSize.Z / 2) end -- (overY: hangs below the shoulders)
	end
	return most
end
-- Where the knife really goes: its own place, unless big wings fill the back (then the hip). With HIP off (owner,
-- Oct 21 16:06, his picture: the knife still by his leg, his avatar has a big back piece: "make it be on the users
-- back like in the other games") it always stays on the back, and a big back piece only lifts it CLEAR.MostOut off
-- the back (it may go through wings or a backpack, as in other games, never floats off the body). Oct 21 16:16 (his
-- picture: the handle sticking out of his big bag, "make it be on the body not floating in the air"): 0, so it is
-- always pressed against the body, whatever the avatar wears.
KnifeLook.CLEAR.MostOut = 0
function KnifeLook.wornAt(wear: string, clear: number?): string
	if not KnifeLook.HIP then return "Back" end
	if wear == "Back" and (clear or 0) > KnifeLook.CLEAR.Max then return "Side" end
	return wear
end
-- How far the knife sits out for a cape, hair or wings (capped when HIP is off).
function KnifeLook.clearOut(clear: number?): number
	if not KnifeLook.HIP then return math.min(clear or 0, KnifeLook.CLEAR.MostOut) end
	return clear or 0
end

-- On the back (long blades), in the torso's space (+X right, +Y up, +Z the back), like a sword in a back sheath:
-- the grip high on the right shoulder blade, the handle end up over the right shoulder, the rest down to the left
-- hip BACK_TILT degrees off straight down, its thin side facing back (flat against the back), just off the back:
-- GAP studs past the knife's thickest bit on that side (shape.xMin: a guard sticks out more than the blade; 0.22 for
-- a knife we can't measure), plus clear (a cape or long hair: KnifeLook.backClear). A sword's blade goes down-left;
-- a two-handed pole (his reapers and scythe, gripped near the head) is turned round, so its head is the end up over
-- the shoulder and the pole runs down-left. Blocky R15 (UpperTorso 2 x 1.6 x 1) and R6 (Torso 2 x 2 x 1) with all
-- of the owner's knives: tests/KnifeWear.spec.luau checks no part goes into the head, torso, arms or legs, and none
-- floats.
KnifeLook.BACK_TILT = 40
KnifeLook.GAP = 0.05
local function off(shape, side: number, default: number): number
	if not shape then return default end
	return math.max(0.04, side) + KnifeLook.GAP
end
function KnifeLook.backC0(torsoName: string, torsoSize: Vector3, shape: any?, clear: number?): CFrame
	local a = math.rad(KnifeLook.BACK_TILT)
	local pole = KnifeLook.twoHanded(shape)
	local tip = if pole then Vector3.new(math.sin(a), math.cos(a), 0) else Vector3.new(-math.sin(a), -math.cos(a), 0)
	-- a blade wider on one side (a cleaver, a scythe's hook) keeps that side down-right, away from the head: knife +Z
	-- goes down-right, so a knife that reaches further to -Z is turned round (its other flat faces out)
	local wideNeg = shape ~= nil and shape.zMin ~= nil and -shape.zMin > shape.zMax + 0.05
	local sx = (if wideNeg then -1 else 1) * (if pole then -1 else 1)
	local out = if sx < 0 then off(shape, shape and shape.xMax or 0, 0.22) else off(shape, shape and -shape.xMin or 0, 0.22) -- (the side facing the back)
	local at = Vector3.new(0.28 * torsoSize.X, torsoSize.Y / 2 - 0.25, torsoSize.Z / 2 + out + KnifeLook.clearOut(clear))
	if pole then -- (the pole's middle on the back, a little right: the head over the right shoulder, the pole clear of the head)
		at = Vector3.new(0.2, 0, at.Z) - tip * ((shape.yMin + shape.yMax) / 2)
	elseif shape and shape.yMin and shape.zMin then
		-- (a short round knife, a shuriken or a karambit, reaches up past its grip: lowered so its top stays under
		-- the shoulders, never into the head; every knife on the back since Oct 21 15:23)
		local upY, upZ = -math.cos(a), -sx * math.sin(a) -- (how far up the knife's +Y and +Z go, per stud)
		local top = math.max(shape.yMin * upY, shape.yMax * upY) + math.max(shape.zMin * upZ, shape.zMax * upZ)
		at = Vector3.new(at.X, math.min(at.Y, torsoSize.Y / 2 - 0.15 - top), at.Z)
	end
	return CFrame.fromMatrix(at, Vector3.new(0, 0, sx), tip)
end

-- At the side (short knives and daggers; R15 LowerTorso, R6 Torso), like a dagger in a belt sheath: on the right
-- hip at the belt, blade down and SIDE_TILT degrees back, flat side against the hip, just off it (GAP past its
-- thickest bit). The hanging right arm covers the side of the hip, so the knife sits just behind it (its front edge
-- GAP behind the arm's back face, the narrow side forward): seen from the side, from behind and in the run.
KnifeLook.SIDE_TILT = 15
function KnifeLook.sideC0(torsoName: string, torsoSize: Vector3, shape: any?): CFrame
	local b = math.rad(KnifeLook.SIDE_TILT)
	local s, c = math.sin(b), math.cos(b)
	local tip = Vector3.new(0, -c, s)
	-- how far forward of the grip it reaches (shape.front, both ways round: knife +X out = its +Z forward, or +X in =
	-- its +Z back); it hangs the way that reaches forward least
	local front = (shape and shape.front) or { -s * 0.5 - c * 0.25, -s * 0.5 - c * 0.25 }
	local sx = if front[1] >= front[2] then 1 else -1
	local out = if sx > 0 then off(shape, shape and -shape.xMin or 0, 0.12) else off(shape, shape and shape.xMax or 0, 0.12)
	local y = if torsoName == "Torso" then -torsoSize.Y / 2 + 0.2 else -0.1 -- (R6: one torso, so down to the belt)
	local at = Vector3.new(torsoSize.X / 2 + out, y, torsoSize.Z / 2 + KnifeLook.GAP - math.max(front[1], front[2]))
	return CFrame.fromMatrix(at, Vector3.new(sx, 0, 0), tip)
end

-- Where a worn knife's grip goes on its body part (shape: KnifeLook.shape of the model, optional; clear: how far
-- capes and hair reach behind the back, KnifeLook.backClear).
function KnifeLook.wornC0(wear: string, torsoName: string, torsoSize: Vector3, shape: any?, clear: number?): CFrame
	if wear == "Side" then return KnifeLook.sideC0(torsoName, torsoSize, shape) end
	return KnifeLook.backC0(torsoName, torsoSize, shape, clear)
end

-- A worn knife never floats off its body (owner, Oct 20: "please remove that black thing that is attacthed to my
-- character in the game": a dark block about the default knife's grip size hung about 3 studs from him, at his shins,
-- with no knife on his body, on his own Studio screen only, and nothing offline puts one there). Each screen
-- (HuzzClient/Gameplay/KnifeGuard) hides a worn knife whose grip (its Handle) is more than STRAY studs from where its
-- mount holds it, or more than STRAY studs outside the body part it hangs from; and a piece STRAY studs farther from
-- the grip than it was made; and says so once in Output. A knife worn where it should be is never hidden:
-- tests/KnifeWear.spec puts every knife on blocky, slim, big and wide R15 and R6 bodies (the farthest grip, a
-- shuriken's pushed back off the hip, rightly sits 0.9 studs out: hence 1.5).
KnifeLook.STRAY = 1.5
-- How far a world point lies outside a box (cf, size; 0 inside).
function KnifeLook.outside(cf: CFrame, size: Vector3, at: Vector3): number
	local p = cf:PointToObjectSpace(at)
	local h = size / 2
	local d = Vector3.new(math.max(math.abs(p.X) - h.X, 0), math.max(math.abs(p.Y) - h.Y, 0), math.max(math.abs(p.Z) - h.Z, 0))
	return d.Magnitude
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
-- reach (optional): studs from the grip to the tip. A long blade is held more forward so its tip stays off the floor
-- (knife check, Oct 19: at 150 the 3+ stud knives went up to 0.43 studs into the floor in a catcher's idle and walk,
-- Crimson Requiem the worst): HAND.Angle up to HAND.Reach studs, then HAND.PerStud degrees more forward per stud,
-- at most HAND.MinAngle (tests/KnifeWear.spec: every knife's tip 0.15+ over the floor, idle, walk and run).
KnifeLook.HAND = { Angle = -150, Reach = 2.2, PerStud = 60, MinAngle = -118 }
function KnifeLook.handAngle(reach: number?): number
	local H = KnifeLook.HAND
	if type(reach) ~= "number" or reach <= H.Reach then return H.Angle end
	return math.min(H.Angle + (reach - H.Reach) * H.PerStud, H.MinAngle)
end
function KnifeLook.handC0(gripAt: Vector3, reach: number?): CFrame
	return CFrame.new(gripAt) * CFrame.Angles(math.rad(KnifeLook.handAngle(reach)), 0, 0)
end
-- During a stab or a lunge the arm is up, so the floor is no worry: Gameplay/Actions turns a long blade back to Huss
-- Valley's 150 degrees for the slash (the leap's blade stays level, not 30 degrees up), easing in over HAND.In and
-- back over HAND.Out seconds. held: the grip's C0 as the server set it; k: 0 = held, 1 = the slash angle.
KnifeLook.HAND.In, KnifeLook.HAND.Out = 0.05, 0.12
function KnifeLook.slashC0(held: CFrame, k: number): CFrame
	local x = held:ToEulerAnglesXYZ()
	local a = x + (math.rad(KnifeLook.HAND.Angle) - x) * math.clamp(k, 0, 1)
	return CFrame.new(held.Position) * CFrame.Angles(a, 0, 0)
end

-- The lobby stands show their knife BIG (owner, Oct 19: "right now its very small and you dont even notice it";
-- his reference stands hold blades as long as an arm and a half): the display copy is scaled up to Length studs
-- pommel to tip (the real pass models are 3.2 studs, our stand-in knife 1.9), never shrunk, at most MaxScale.
-- Evenly: it keeps his model's shape. (Round 2 also widened the blade up to twice and laid a see-through Neon shell
-- over it; the owner, Oct 19: "they dont look as good as in the glb file". Both gone.)
KnifeLook.STAND = { Length = 4.4, MaxScale = 2.6 }
function KnifeLook.standScale(length: number?): number
	if type(length) ~= "number" or length <= 0 then return 1 end
	return math.clamp(KnifeLook.STAND.Length / length, 1, KnifeLook.STAND.MaxScale)
end

-- The Roblox material (its Enum.Material name) and Reflectance nearest a .glb part's look, from the .glb's own
-- metallic and roughness (owner, Oct 19: "they dont look as good as in the glb file"; his blades and guards are
-- metallic 0.6 to 0.9 and polished, roughness 0.2 to 0.3; his grips matte, metallic 0 and roughness 0.8):
--   glowing (emissive)                 Neon (his own import's glow, a SurfaceAppearance, is kept where he has one)
--   metallic 0.5 and up                Metal, with Reflectance 0.12 when polished (roughness 0.35 or less), else 0.04
--   roughness 0.7 and up               Plastic (matte)
--   anything else                      SmoothPlastic
-- His Studio helper (HuzzStudioTools/SetupKnives lookOf) and the pass knives' builder (Gameplay/KnifeDress, through
-- tools/knives/bake_pass_meshes.py) use the same rule; tests/KnifeModels.spec holds them together.
KnifeLook.GLB_LOOK = { MetalFrom = 0.5, PolishedTo = 0.35, Polished = 0.12, Brushed = 0.04, MatteFrom = 0.7 }
function KnifeLook.glbMaterial(metal: number?, rough: number?, glow: boolean?): (string, number)
	local L = KnifeLook.GLB_LOOK
	if glow then return "Neon", 0 end
	local m, r = metal or 0, rough or 1
	if m >= L.MetalFrom then return "Metal", if r <= L.PolishedTo then L.Polished else L.Brushed end
	if r >= L.MatteFrom then return "Plastic", 0 end
	return "SmoothPlastic", 0
end

--[[
	Each Game Pass knife's own element (owner, Oct 19: "better knife animations ... in the lobby and in the gamepass
	sections"; each one matches its card, design/knives/Five_Elemental_Knife_Cards.png). Since Oct 20 ("just make them
	be normal") the game builds only its trail colours; emit and burst stay as data (old previews read them).
	  emit      the steady emitters (on the blade; "tip" = at the tip): texture (Shared/FxTexture name), colours,
	            rate (per second on a stand; half in hand), life, speed, size, accel (studs/s^2), spin (degrees/s),
	            box (from the whole blade, not a point), lock (stay on the blade).
	  burst     how many petals/feathers/sparks one big moment throws out (a stand's spin, a catcher's slash).
	  trail     the slash trail's colours (start, end).
	  light     the glow's colour.
]]
local function rgb(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end
KnifeLook.ELEMENTS = {
	CrimsonRequiem = { -- Hunter Knife: red petals drifting off the blade
		name = "Petals", light = rgb("ff3344"), trail = { rgb("ff3344"), rgb("ffc2cc") }, burst = 16,
		emit = {
			{ texture = "Petal", colours = { rgb("ff5a6e"), rgb("ff9fb0") }, rate = 10, life = { 1.8, 2.6 }, speed = { 0.4, 0.9 },
				size = 0.55, accel = { 0, -0.6, 0 }, spin = 90, box = true },
			{ texture = "Twinkle", colours = { rgb("ffd0da"), rgb("ff4a66") }, rate = 4, life = { 0.5, 0.8 }, speed = { 0.2, 0.4 },
				size = 0.22, box = true },
		},
	},
	HollowEclipse = { -- Moonlit Knife: pale moon glints and violet wisps
		name = "Moon", light = rgb("c9b8ff"), trail = { rgb("b48cff"), rgb("f0ecff") }, burst = 12,
		emit = {
			{ texture = "Moon", colours = { rgb("f4f0ff"), rgb("d8c8ff") }, rate = 0.6, life = { 0.8, 1 }, speed = { 0, 0 },
				size = 0.7, tip = true, lock = true, grow = true },
			{ texture = "Wisp", colours = { rgb("a77bff"), rgb("6d4bd6") }, rate = 6, life = { 1.2, 1.8 }, speed = { 0.2, 0.5 },
				size = 0.7, accel = { 0, 0.5, 0 }, spin = 30, box = true, faint = true },
		},
	},
	CelestialSeraph = { -- Sunrise Knife: gold feathers floating down and warm light
		name = "Feathers", light = rgb("ffd27a"), trail = { rgb("ffb52e"), rgb("ffd27a") }, burst = 12, -- (gold, never white: a flat sweep washed out)
		emit = {
			{ texture = "Feather", colours = { rgb("fff6e0"), rgb("ffd27a") }, rate = 4, life = { 2, 2.8 }, speed = { 0.3, 0.6 },
				size = 0.5, accel = { 0, -0.4, 0 }, spin = 40, box = true },
			{ texture = "Twinkle", colours = { rgb("fff0c0"), rgb("ffc24a") }, rate = 5, life = { 0.6, 0.9 }, speed = { 0.2, 0.4 },
				size = 0.18, box = true },
		},
	},
	DragonsMaw = { -- Inferno Knife: flames along the blade and embers rising
		name = "Fire", light = rgb("ff7a1a"), trail = { rgb("ff6a10"), rgb("ffd040") }, burst = 18,
		emit = {
			{ texture = "Flame", colours = { rgb("ffb040"), rgb("ff4a10") }, rate = 24, life = { 0.5, 0.75 }, speed = { 0.6, 1.2 },
				size = 1.3, accel = { 0, 2.5, 0 }, box = true, shrink = true },
			{ texture = "Spark", colours = { rgb("ffd060"), rgb("ff6a10") }, rate = 6, life = { 0.9, 1.4 }, speed = { 0.4, 1 },
				size = 0.12, accel = { 0, 2, 0 }, box = true },
		},
	},
	FrostboundOath = { -- Frost Knife: ice shards and snowflakes in a cold mist
		name = "Frost", light = rgb("5ae6ff"), trail = { rgb("5ae6ff"), rgb("e8fbff") }, burst = 14,
		emit = {
			{ texture = "Shard", colours = { rgb("d8f8ff"), rgb("5ae6ff") }, rate = 5, life = { 1, 1.5 }, speed = { 0.3, 0.7 },
				size = 0.45, accel = { 0, -0.3, 0 }, spin = 60, box = true },
			{ texture = "Snow", colours = { rgb("ffffff"), rgb("bff4ff") }, rate = 5, life = { 1.6, 2.2 }, speed = { 0.2, 0.4 },
				size = 0.18, accel = { 0, -0.5, 0 }, spin = 20, box = true },
			{ texture = "Wisp", colours = { rgb("bff4ff"), rgb("5ae6ff") }, rate = 3, life = { 1.4, 2 }, speed = { 0.1, 0.3 },
				size = 0.9, accel = { 0, -0.2, 0 }, spin = 15, box = true, faint = true, standOnly = true },
		},
	},
}
-- The catcher's slash arc (Gameplay/Actions; owner, Oct 19: "better knife animations ... during gameplay"): a thin
-- crescent in the knife's slash colour (Epic and up: KnifeService sets the knife's SlashColor) drawn round the front
-- and right of the body as the arm sweeps out, a Beam on two attachments on the root (so it rides with a lunge):
-- from in front (From, its curve leaving to the right) to the right side (To, arriving from the front). Shows At to
-- At + Life seconds into the stab (the sweep lands at ~0.07 s), fading out; no flash, one per stab.
KnifeLook.ARC = {
	From = Vector3.new(0.6, 0.4, -3.4), To = Vector3.new(3.6, 1.1, 0.5), Curve = 2,
	Width = { 0.15, 1 }, At = 0.03, Life = 0.2, LightEmission = 0.7,
}
-- How see-through the arc is at `age` seconds after it shows (0 = solid; 1 = gone), its middle the most solid.
function KnifeLook.arcFade(age: number): number
	local A = KnifeLook.ARC
	if age < 0 or age > A.Life then return 1 end
	local u = age / A.Life
	return if u < 0.15 then 1 - 0.85 * (u / 0.15) else 0.15 + 0.85 * ((u - 0.15) / 0.85) ^ 1.5
end

--[[ The catch (knife pass 2, Oct 19, owner: "give them a good vfx ... the leaping, the killing"; players read
	"catch"). Huss Valley's read (docs/knife-study.md section 4): the caught runner's whole body fills red for 2
	frames, then a darker red tint for ~0.2 s, then a red outline while they lie down; no spark shower, no screen
	flash. Gameplay/RoundHud draws the fill and the outline on its team Highlight (Fill: FillTransparency over time;
	the solid frames only through Gameplay/Burst.flashOk, at most one a second; otherwise it starts at the tint).
	Gameplay/Juice adds two small touches in the catcher's knife colour, one each per catch: a thin cut line across
	the runner's back (Cut, a Beam on their torso, drawn on in its first quarter, gone in Life) and a few sparks
	(Burst; it replaced 30 red sparks that read as a generic hit). Gameplay/Actions draws the leap's ribbon from the
	catcher's body (Streak: a Trail between two points on the UpperTorso, Top and Bottom studs from its middle,
	white into the knife colour, Life seconds long, so about 8 studs at the leap's speed: HV's ribbon is 6 to 8). ]]
KnifeLook.CATCH = {
	Fill = { Solid = 0.07, SolidTransparency = 0.12, Tint = 0.6, TintBy = 0.25, Gone = 0.42 },
	Cut = { Life = 0.26, Length = 3.4, Width = 0.34 },
	Burst = { Count = 10, Speed = { 6, 12 }, Life = { 0.25, 0.45 }, Size = 0.3 },
	-- (owner, Oct 21 14:53: "make the leaping visible, not just disappearing so people can see when you are jumping":
	-- was 0.14 s, half see-through and chest-high only; now the whole body's height, brighter, about 3x as long)
	Streak = { Life = 0.4, Top = 0.9, Bottom = -1.6, Transparency = { 0.15, 1 }, LightEmission = 0.8 },
	-- dust thrown up at take-off and at the belly landing, and a soft glowing outline on the diver while the dive
	-- lasts (one soft fade, never a flash), so a body flat on the floor still stands out on everyone's screen
	Dive = { Dust = 16, LandDust = 12, LandAt = 0.245, Glow = 0.8, GlowTransparency = 0.35 },
}
-- The red fill's FillTransparency `age` seconds after the catch (1 = none). solid = false: no solid frames (another
-- flash showed in the last second), it starts at the tint.
function KnifeLook.catchFill(age: number, solid: boolean?): number
	local F = KnifeLook.CATCH.Fill
	if age < 0 or age >= F.Gone then return 1 end
	if solid ~= false and age < F.Solid then return F.SolidTransparency end
	if age < F.TintBy then
		if solid == false then return F.Tint end
		local k = (age - F.Solid) / (F.TintBy - F.Solid)
		return F.SolidTransparency + (F.Tint - F.SolidTransparency) * k
	end
	local k = (age - F.TintBy) / (F.Gone - F.TintBy)
	return F.Tint + (1 - F.Tint) * k * k
end

-- The element of a knife (nil: none, the rarity ladder only).
function KnifeLook.element(key: string?)
	return key and KnifeLook.ELEMENTS[key] or nil
end
-- Particles a second for an element in a place: "stand" (the lobby showcase) or "hand" (half as many).
-- Round 2: stronger and constant on a stand (the reference's fire and petal clouds); a hand keeps about a third,
-- the back a sixth; `standOnly` emitters (Frost's mist) only on a stand.
function KnifeLook.elementRate(spec, where: string): number
	if where == "stand" then return spec.rate end
	if spec.standOnly then return 0 end
	return if where == "back" then spec.rate / 6 else spec.rate * 0.35
end

--[[
	The knife effects (owner, Oct 20 07:43 / 07:47: "make the vfx for some swords way better and more detailed, make
	them better for more high end ones" ... "check out the references provided from Huss valley, and then implement the
	vfx based on it. Make them fit and logically connected to the skin of the sword"). Shared/KnifeFx builds them
	from these numbers on the knife (HuzzServer/KnifeService: in hand, worn, the lobby stands' copy);
	tools/preview/motion3d/knife_vfx_scene.luau films them; the method is VFX-ITEMS.md at the repo root.
	What Huss Valley's skins do (their video f1c7bb86, docs/previews/knife-vfx-hv-reference.jpg): the gems glow, two or
	three small round motes in the GEM's colour (not the blade's) drift slowly round the blade, a top skin adds its own
	motif (Mrsmagic's blue electric wisps round the middle of a red blade), the gem sparkles now and then; the same
	on the back as in the hand; a swing brightens it with a few sparkles. Small, slow, soft, never a cloud. Measured
	on MELON5MAN (f1c7bb86, 5.0 s): a mote is about 5% of the knife's length across and solid, the gem's orb with its
	bloom about 15%; 2 to 4 motes show at once. Match that VISIBILITY too, not just the restraint (coordinator, Oct 20:
	the first pass showed "almost nothing" next to theirs): on a 3.2-stud knife a mote is Size 0.32 (smoke_main is a
	soft puff, its bright middle about half that) at full strength, and the gem gets a glow shell (KnifeFx) about
	0.45 studs across.
	Here: each theme has up to five roles, all in the knife's effect colour unless a theme names its own:
	  motes  the HV staple: small soft dots (TEX.Smoke, small) moving as the theme does (embers rise, frost sinks,
	         void is pulled in, petals drift);
	  motif  the theme's own thing (flames on the edge, frost mist, a dark swirl, petals, red drips, sparks...);
	  glint  a star on the gem (TEX.Sparkle, slow grow and fade): Rate 0, one at a time on a fixed timer (every =
	         GLINT_EVERY s, Gameplay/KnifeFxRange emits it), never twice within 1 s (a random Rate 0.5 gave gaps
	         under 1 s more than half the time: the critic, Oct 20);
	  orb    a soft glow held on the gem (TEX.Smoke, locked: the bloom round their gems; Epic and up);
	  haze   a faint glow or mist round the blade.
	TIER.glow: the gem glowing (KnifeFx "KnifeFxGlow"): a solid Neon ball in the gem's colour, the gem's own size,
	Transparency 0.08 top tier, 0.15 Epic, never changing, the PointLight its soft bloom (a bigger see-through ball
	read as a pale bubble round the hilt: coordinator, Oct 20, "cheap or AI").
	TIER.balls: how many crisp Neon ball motes float round the blade (hand / back / stand), made and moved on each
	screen by Gameplay/KnifeFxRange with Shared/KnifeMotes (MELON5MAN's 2 or 3 cyan balls); with them the particle
	motes drop to moteShare of their rate (a light extra).
	Where (at): "blade" anywhere over the blade (a box), "gem" the knife's biggest glowing part (else the guard),
	"tip". Fields: tex, col (two colours over its life: "c" the effect colour, "w" it a third of the way to white, or a hex),
	rate (a second, in hand at the top tier), life, speed, size (studs), accel, drag, spin (degrees a second), squash
	(Roblox Squash: + taller), inward (pulled in from round the blade), lock (moves with the knife), alpha (how solid
	at its most), dark (no glow), grow (fades in and out, never pops), shrink, sideways.
	TIER: which roles a rarity shows and how strong; worn = the share kept on the back or hip; stand = the lobby
	stands' copy. Caps: MaxRate a second for one emitter, MaxTotal for a knife; one PointLight at most (top tier, not
	worn).
]]
local VFX = {}
KnifeLook.VFX = VFX
VFX.TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}
VFX.MaxRate, VFX.MaxTotal = 6, 16
VFX.TIER = { Common = 0, Uncommon = 0, Rare = 1, Epic = 2, Legendary = 3, Mythic = 3, Exclusive = 3 }
VFX.TIERS = {
	{ roles = { "motes" }, rate = 0.35, size = 0.75, alpha = 0.55, light = nil, burst = 0, worn = { roles = { "motes" }, rate = 0.8 } }, -- Rare: one or two faint motes
	{ roles = { "motes", "motif", "orb" }, rate = 0.75, size = 0.85, glow = { Transparency = 0.15 }, light = nil, burst = 5,
		balls = { hand = 2, back = 1, stand = 2 }, moteShare = 0.4,
		worn = { roles = { "motes", "orb" }, rate = 0.8 } }, -- Epic: noticeably there
	{ roles = { "motes", "motif", "orb", "glint", "haze" }, rate = 1, size = 1, glow = { Transparency = 0.08 }, light = { Brightness = 1, Range = 6 }, burst = 8,
		balls = { hand = 3, back = 3, stand = 4 }, moteShare = 0.4,
		worn = { roles = { "motes", "motif", "orb", "glint" }, rate = 0.8 } }, -- Legendary, Mythic, Game Pass: Huss Valley's level
}
VFX.STAND = { rate = 1.2 } -- the lobby stands' copy (sizes follow the copy's own Scale)
-- (rate 2.5 x life 1.2 to 1.8 = 3 to 4 on show at the top tier; 0.9 at Rare)
-- (the gem's own colour all its life and only a little light emission, so it stays cyan on a bright sky or grass
-- instead of washing out to white: MELON5MAN's motes stay cyan)
local MOTE = { tex = "Smoke", col = { "c", "c" }, rate = 2.5, life = { 1.2, 1.8 }, speed = { 0.15, 0.35 }, size = 0.32, alpha = 1, glow = 0.3, grow = true }
local function mote(extra)
	local m = table.clone(MOTE)
	for k, v in extra do m[k] = v end
	return m
end
VFX.GLINT_EVERY = 2 -- seconds between a knife's glints (fixed, not random; kid-safe: at least 1.5)
local GLINT = { tex = "Sparkle", col = { "ffffff", "w" }, rate = 0, every = VFX.GLINT_EVERY, life = { 0.5, 0.6 }, speed = { 0, 0 }, size = 0.55, at = "gem", lock = true, grow = true, spin = 45 }
VFX.ORB = { tex = "Smoke", col = { "w", "c" }, rate = 1.5, life = { 1, 1.4 }, speed = { 0, 0 }, size = 0.9, at = "gem", lock = true, alpha = 0.6, grow = true }
VFX.THEMES = {
	Fire = {
		motes = mote({ col = { "ffd27a", "c" }, rate = 3, accel = { 0, 2.2, 0 }, life = { 0.9, 1.3 } }), -- embers rising off the edge
		motif = { tex = "Fire", col = { "ff9a1e", "d42800" }, rate = 4, life = { 0.35, 0.5 }, speed = { 0.2, 0.4 }, size = 0.28, accel = { 0, 3, 0 }, alpha = 0.95, glow = 0.6, shrink = true }, -- small flames rising off the edge, orange to red
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1.5, life = { 0.9, 1.2 }, speed = { 0.2, 0.4 }, size = 0.9, accel = { 0, 1.2, 0 }, alpha = 0.1, grow = true }, -- heat haze
	},
	Ice = {
		motes = mote({ col = { "ffffff", "c" }, rate = 2.5, accel = { 0, -0.5, 0 }, life = { 1.4, 2 } }), -- snow sinking
		motif = { tex = "Smoke", col = { "w", "c" }, rate = 2.5, life = { 1.4, 2 }, speed = { 0.05, 0.2 }, size = 0.7, accel = { 0, -0.4, 0 }, drag = 1, alpha = 0.4, grow = true, spin = 20 }, -- frost mist sinking off the blade
		glint = GLINT, -- (a crystal glint)
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1, alpha = 0.16, lock = true, grow = true },
	},
	Void = {
		motes = mote({ rate = 3, inward = true, speed = { 0.5, 0.8 }, life = { 0.8, 1.1 } }), -- motes pulled in to the blade
		motif = { tex = "Smoke", col = { "2a1040", "0a0612" }, rate = 2.5, life = { 1, 1.5 }, speed = { 0.1, 0.3 }, size = 0.7, alpha = 0.55, dark = true, spin = 120, grow = true }, -- a dark swirl
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1.1, alpha = 0.12, lock = true, grow = true },
	},
	Celestial = {
		motes = mote({ rate = 3, accel = { 0, 0.4, 0 } }), -- light motes rising, in the gem's colour (MELON5MAN's cyan)
		motif = { tex = "Sparkle", col = { "ffffff", "c" }, rate = 1.5, life = { 1.2, 1.6 }, speed = { 0.2, 0.4 }, size = 0.3, at = "gem", accel = { 0, 0.6, 0 }, spin = 90, grow = true }, -- little stars rising off the halo
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1, alpha = 0.16, lock = true, grow = true }, -- (the tip star went: two glints could land within 1 s)
	},
	Moon = {
		motes = mote({ rate = 2.5, accel = { 0, 0.3, 0 } }),
		motif = { tex = "Smoke", col = { "w", "c" }, rate = 2, life = { 1.2, 1.8 }, speed = { 0.1, 0.25 }, size = 0.6, accel = { 0, 0.3, 0 }, alpha = 0.45, grow = true, spin = 40 }, -- pale wisps
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1, alpha = 0.16, lock = true, grow = true },
	},
	Blood = {
		motes = mote({ col = { "ff8a94", "c" }, rate = 2, accel = { 0, 0.3, 0 } }),
		motif = { tex = "Smoke", col = { "c", "8a0010" }, rate = 2, life = { 0.7, 1 }, speed = { 0, 0.05 }, size = 0.18, accel = { 0, -6, 0 }, squash = 1.2, alpha = 1, glow = 0.5 }, -- red drips off the edge
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "6a0010" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0.05, 0.15 }, size = 0.9, alpha = 0.1, grow = true },
	},
	Sakura = {
		motes = mote({ rate = 2 }),
		motif = { tex = "Smoke", col = { "w", "c" }, rate = 2.5, life = { 2, 2.6 }, speed = { 0.2, 0.5 }, size = 0.3, accel = { 0, -0.4, 0 }, sideways = 0.6, spin = 120, squash = -0.6, alpha = 1, glow = 0.6 }, -- petals drifting off
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1, alpha = 0.16, lock = true, grow = true },
	},
	Storm = {
		motes = mote({ rate = 2.5 }),
		motif = { tex = "Smoke", col = { "w", "c" }, rate = 3, life = { 0.35, 0.55 }, speed = { 0.1, 0.3 }, size = 0.45, alpha = 0.6, lock = true, spin = 200 }, -- electric wisps round the middle (Mrsmagic's)
		glint = GLINT,
		haze = { tex = "Sparkle", col = { "ffffff", "c" }, rate = 3, life = { 0.15, 0.25 }, speed = { 1.5, 2.5 }, size = 0.12, drag = 4 }, -- tiny sparks off the blade (specks, not a flash)
	},
	Venom = {
		motes = mote({ accel = { 0, 0.9, 0 }, size = 0.26 }), -- bubbles rising
		motif = { tex = "Smoke", col = { "c", "c" }, rate = 1.5, life = { 0.7, 1 }, speed = { 0, 0.05 }, size = 0.17, accel = { 0, -5, 0 }, squash = 1.2, alpha = 1, glow = 0.6 }, -- drips
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 0.9, alpha = 0.1, grow = true },
	},
	Witch = {
		motes = mote({ rate = 2.5, accel = { 0, 0.4, 0 } }),
		motif = { tex = "Sparkle", col = { "w", "c" }, rate = 2.5, life = { 1.2, 1.6 }, speed = { 0.1, 0.3 }, size = 0.3, spin = 180, grow = true }, -- magic sparkles turning
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1.2, life = { 1.2, 1.6 }, speed = { 0.05, 0.15 }, size = 0.9, alpha = 0.14, spin = 60, grow = true },
	},
	Candy = {
		motes = mote({ rate = 2.5, accel = { 0, -0.2, 0 } }),
		motif = { tex = "Sparkle", col = { "ff9ec4", "ffd0e8" }, rate = 2.5, life = { 1, 1.5 }, speed = { 0.1, 0.3 }, size = 0.26, accel = { 0, -0.3, 0 }, spin = 90, grow = true }, -- sprinkles
		glint = GLINT,
		haze = { tex = "Smoke", col = { "fff0f8", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 0.9, alpha = 0.1, grow = true },
	},
	Pumpkin = {
		motes = mote({ col = { "ffd080", "c" }, rate = 3, accel = { 0, 2, 0 }, life = { 0.9, 1.3 } }), -- embers
		motif = { tex = "Fire", col = { "ffa030", "d04000" }, rate = 3, life = { 0.35, 0.5 }, speed = { 0.2, 0.4 }, size = 0.26, accel = { 0, 3, 0 }, alpha = 0.95, glow = 0.6, shrink = true }, -- small jack-o'-lantern flames, orange to red
		glint = GLINT,
		haze = { tex = "Smoke", col = { "3a2a20", "1a1410" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0.1, 0.3 }, size = 0.7, accel = { 0, 0.8, 0 }, alpha = 0.22, dark = true, grow = true },
	},
	Spirit = {
		motes = mote({ rate = 2.5, accel = { 0, 0.4, 0 } }),
		motif = { tex = "Smoke", col = { "w", "c" }, rate = 2, life = { 1.2, 1.6 }, speed = { 0.1, 0.25 }, size = 0.45, accel = { 0, 0.5, 0 }, alpha = 0.5, spin = 40, grow = true }, -- wisps
		glint = GLINT,
		haze = { tex = "Smoke", col = { "c", "c" }, rate = 1, life = { 1.2, 1.6 }, speed = { 0, 0.05 }, size = 1, alpha = 0.16, lock = true, grow = true },
	},
}
-- Each knife (Rare and up) -> its theme, from its name and colours (Config/CoinShop; the pass knives' cards).
VFX.OF = {
	SpiritKunai = "Spirit", ThunderFang = "Storm", CandyKnife = "Sakura", VenomKris = "Venom", FrostFang = "Ice",
	EmberEdge = "Fire", MoonlitKnife = "Moon", ShadowKnife = "Void", StormKunai = "Storm", BloodMoonTanto = "Blood",
	TwinFang = "Spirit", SolarReaper = "Fire", VoidFang = "Void", SpinKnife = "Celestial", AbyssEclipse = "Void",
	CelestialSeraph = "Celestial", CrimsonRequiem = "Sakura", HollowEclipse = "Moon", DragonsMaw = "Fire",
	FrostboundOath = "Ice", GourdCleaver = "Pumpkin", ThornKarambit = "Pumpkin", PumpkinKingKatana = "Pumpkin",
	JacksReaper = "Pumpkin", ToadstoolSickle = "Venom", MoonlitCleaver = "Moon", CovenKatana = "Witch",
	GrandWitchScythe = "Witch", TaffyKarambit = "Candy", CupcakeCleaver = "Candy", SugarRushKatana = "Candy",
	CandyReaper = "Candy",
	-- his reward knives (Oct 24): petals off the Thousand Blossom, Stormfang's lightning, Broken Wrath's red gems burn,
	-- Inverted Hex's dark violet pulls in
	ThousandBlossom = "Sakura", StormfangChokuto = "Storm", BrokenWrath = "Fire", InvertedHex = "Void",
}

local function hexColour(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end

-- A skin's effects at `where` ("hand", "stand" or "back"), worked out and capped; nil when it has none (Common,
-- Uncommon, the default knife, a knife with no theme). Pure numbers:
-- { theme, colour, emit = { { role, tex (an rbxasset), col = { a, b }, rate, life, speed, size, at, ... } },
--   glow = { Color, Transparency }? (the gem's solid Neon glow), balls (ball motes), drift (their rise, studs a second),
--   light = { Color, Brightness, Range }?, burst (sparkles a slash), trail (its slash trail's seconds, top tier) }
function KnifeLook.vfx(skin, where: string)
	local tierN = skin and VFX.TIER[skin.Rarity or ""] or 0
	local name = skin and VFX.OF[skin.Key or ""]
	local theme = name and VFX.THEMES[name]
	if tierN < 1 or not theme then return nil end
	local tier = VFX.TIERS[tierN]
	local el = KnifeLook.element(skin.Key)
	-- (the gem's colour, as Huss Valley's skins: the shop's Glow, else the pass element's light, else the blade)
	local colour = skin.Glow or (el and el.light) or KnifeLook.colour(skin) or Color3.new(1, 1, 1)
	local white = Color3.new(1, 1, 1)
	local function col(c: string): Color3
		if c == "c" then return colour end
		if c == "w" then return colour:Lerp(white, 0.3) end -- (a little lighter, still the gem's colour)
		return hexColour(c)
	end
	local roles, share = tier.roles, tier.rate
	if where == "back" then
		roles, share = tier.worn.roles, tier.rate * tier.worn.rate
	elseif where == "stand" then
		share = tier.rate * VFX.STAND.rate
	end
	local emit, total = {}, 0
	for _, role in roles do
		local e = theme[role] or (role == "orb" and VFX.ORB) or nil
		if not e then continue end
		local rate = if e.every then 0 else math.min(e.rate * share * (if role == "motes" and tier.balls then tier.moteShare or 1 else 1), VFX.MaxRate, VFX.MaxTotal - total)
		if rate <= 0 and not e.every then break end
		total += rate
		local out = table.clone(e)
		out.role = role
		out.tex = VFX.TEX[e.tex]
		out.col = { col(e.col[1]), col(e.col[2]) }
		out.rate = rate
		out.size = e.size * tier.size
		out.alpha = (e.alpha or 0.9) * (tier.alpha or 1)
		out.at = e.at or "blade"
		table.insert(emit, out)
	end
	return {
		theme = name, colour = colour, emit = emit,
		glow = if tier.glow then { Color = colour, Transparency = tier.glow.Transparency } else nil,
		-- ball motes: how many, and how fast they rise (+) or sink (-) as the theme's motes do (studs a second)
		balls = if tier.balls then tier.balls[where] or 0 else 0,
		drift = math.clamp(((theme.motes and theme.motes.accel) or { 0, 0.4, 0 })[2] * 0.15, -0.25, 0.35),
		-- (in hand at half strength and out on the blade's far half: at the guard it washed the forearm in its colour)
		light = if tier.light and where ~= "back" then { Color = colour, Brightness = tier.light.Brightness * (if where == "hand" then 0.5 else 1),
			Range = tier.light.Range } else nil,
		-- (only a slash in hand throws sparkles; the stands' moves and worn knives none: Huss Valley shows no spark showers)
		burst = if where == "hand" then tier.burst else 0,
		trail = if tierN >= 3 then KnifeLook.TRAIL.ElementLifetime else nil,
	}
end

return KnifeLook
