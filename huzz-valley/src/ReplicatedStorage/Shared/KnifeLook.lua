--[[
	How a knife skin looks and sits (owner, Oct 18: "add some vfx to the knifes, but make it fit it, and dont make it
	overly crazy, i want them to be nice"). Pure numbers; HuzzServer/KnifeService builds them on the knife, so
	everyone sees the same and nothing runs every frame.

	Effects climb with the rarity (Config/CoinShop Rarity), always in the knife's own glow colour (its glowing parts,
	Config/CoinShop Glow), calm, with no flashes:
	  Common     nothing: his model as it is;
	  Uncommon   nothing either (it had a white sheen glint: gone Oct 19, it hid his model; his metal shines itself);
	  Rare       a soft glow: a dim light round the blade;
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
	Uncommon = {},
	Rare = { glow = { range = 2.5, brightness = 0.5 } },
	Epic = { glow = { range = 2.5, brightness = 0.6 }, sparkles = 3, trailTint = true },
	Legendary = { glow = { range = 4, brightness = 1 }, sparkles = 3, trailTint = true, back = true },
	Mythic = { glow = { range = 4, brightness = 1 }, sparkles = 3, trailTint = true, back = true, embers = 1.5 },
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
-- A Game Pass knife's trail is in its element's colours and lasts a little longer (ElementLifetime), so its arc reads
-- (owner, Oct 19: "better knife animations ... during gameplay").
KnifeLook.TRAIL = { Lifetime = 0.12, ElementLifetime = 0.17, Tinted = { 0.2, 1 }, Plain = { 0.45, 1 }, LightEmission = 0.8 }

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
	sections"; each one matches its card, design/knives/Five_Elemental_Knife_Cards.png). Replaces Mythic's plain
	sparkles and embers on that knife; the glow stays. Calm: a few particles a second, nothing flashes.
	  emit      the steady emitters (on the blade; "tip" = at the tip): texture (Shared/FxTexture name), colours,
	            rate (per second on a stand; half in hand), life, speed, size, accel (studs/s^2), spin (degrees/s),
	            box (from the whole blade, not a point), lock (stay on the blade).
	  burst     how many petals/feathers/sparks one big moment throws out (a stand's spin, a catcher's slash).
	  trail     the slash trail's colours (start, end).
	  light     the glow's colour.
	Particles use Roblox's stand-in pictures (sparkles, fire) until the owner uploads ours (Shared/FxTexture).
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
	Streak = { Life = 0.14, Top = 0.45, Bottom = -0.5, Transparency = { 0.45, 1 }, LightEmission = 0.6 },
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

return KnifeLook
