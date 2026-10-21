-- lune run tests/KnifeWear.spec.luau   (from huzz-valley/)
-- The knife you wear (owner, Oct 18: "make the knifes please be equipped when you have them, like be shown on the
-- back of the character"; Oct 19: "make the knifes when equipped be worn either on the back of the character or on
-- the side. This is very important, and make the location based on what knife/sword it is"):
--   * which knife: the one picked in the shop, else the first one you own, else the default knife (KnifeLook.pick);
--   * where: the shop table (Config/CoinShop Wear, one per knife) says Back for long blades (3.0+ studs measured:
--     swords, katanas, reapers, scythe) and Side for short knives, and every row agrees with the measured rule;
--     long blades diagonal across the back like a sword in a back sheath (two-handed poles head up), short knives
--     at the right hip, blade down;
--   * every one of the 53 (his 30 models in assets/knives/HuzzKnives.rbxm, the 23 pass and Halloween stand-ins cut
--     from his .glb) on a blocky R15 and R6 body in its rest pose: nothing goes into the head, torso, legs or arms,
--     its flat lies against the body, and it sits close to it (not floating);
--   * a cape or long hair on the back: the knife goes over it; big wings: a long blade goes to the hip instead;
--   * the real HuzzServer/KnifeService on fake bodies: ONE knife per body, worn in the lobby, moved to the hand for a
--     catcher and back after, a skin change swaps it at once, a body part swapped out gets the knife back, R6 works,
--     and a model of the wrong size is never used (the plain knife in its colours instead);
--   * in a catcher's hand every knife's tip stays off the floor through the idle, walk and run (long blades are held
--     more forward: KnifeLook.handC0's reach).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

pcall(function() -- (Lune doesn't ship Attachment.Position)
	roblox.implementProperty("Attachment", "Position", function(self) return self.CFrame.Position end, function(self, v)
		self.CFrame = self.CFrame - self.CFrame.Position + v
	end)
end)

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- which knife you wear
do
	local data = { Cosmetics = { VoidFang = true, RustyShiv = true }, Wear = { Knife = "VoidFang" } }
	check("pick: the shop's pick", KnifeLook.pick(data, CoinShop).Key == "VoidFang")
	data.Wear = {}
	check("pick: none picked = the first owned in shop order", KnifeLook.pick(data, CoinShop).Key == "RustyShiv")
	data.Wear = { Knife = "" }
	check("pick: taken off = the default knife", KnifeLook.pick(data, CoinShop) == nil)
	check("pick: none owned = the default knife", KnifeLook.pick({ Cosmetics = {}, Wear = {} }, CoinShop) == nil)
	check("pick: picked but not owned = the default knife", KnifeLook.pick({ Cosmetics = {}, Wear = { Knife = "VoidFang" } }, CoinShop) == nil)
	check("pick: owning a trail isn't a knife", KnifeLook.pick({ Cosmetics = { [CoinShop.Items[1].Key] = CoinShop.Items[1].Slot ~= "Knife" or nil }, Wear = {} }, CoinShop) == nil)
	check("pick: no save yet = the default knife", KnifeLook.pick(nil, CoinShop) == nil)
end

-- the owner's 30 models
local folder = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
local function partsOf(model)
	local h = model:FindFirstChild("Handle")
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, { name = d.Name, cf = h.CFrame:ToObjectSpace(d.CFrame), size = d.Size }) end
	end
	return out
end
local good, broken = {}, {}
for _, m in folder:GetChildren() do
	local s = KnifeLook.shape(partsOf(m))
	if KnifeLook.sane(s, m:GetAttribute("Studs"), m:GetAttribute("Wide")) then
		good[m.Name] = m
	else
		table.insert(broken, m.Name)
	end
end
table.sort(broken)
print("  models the wrong size (shown as the plain knife until fixed): " .. (if #broken > 0 then table.concat(broken, ", ") else "none"))
check("all 53 models are the right size (tools/knives/repair_knives.luau fixed 8 on Oct 18)", #folder:GetChildren() == 53 and #broken == 0)
check("the shop table wins", KnifeLook.wearOf("Side", { length = 3.4, bladeLength = 2.4, bladeWidth = 0.3 }, "Back") == "Side"
	and KnifeLook.wearOf("Back", { length = 2, bladeLength = 1, bladeWidth = 1 }) == "Back")
check("then the model's Wear attribute", KnifeLook.wearOf(nil, { length = 2, bladeLength = 1, bladeWidth = 1 }, "Back") == "Back")
check("measured: a 3.4 stud katana goes on the back", KnifeLook.wearOf(nil, { length = 3.4, bladeLength = 2.4, bladeWidth = 0.27 }) == "Back")
check("measured: a 2.6 stud dagger goes at the side", KnifeLook.wearOf(nil, { length = 2.6, bladeLength = 1.7, bladeWidth = 0.3 }) == "Side")
check("no measure = back", KnifeLook.wearOf(nil, nil) == "Back")
check("two-handed: a long pole gripped mid-pole, not a sword or a dagger",
	KnifeLook.twoHanded({ length = 3.3, yMin = -1.65, yMax = 1.65 }) and not KnifeLook.twoHanded({ length = 3.3, yMin = -0.5, yMax = 2.8 })
	and not KnifeLook.twoHanded({ length = 2.7, yMin = -1.3, yMax = 1.4 }))

-- the mounts' directions
for _, body in { { "UpperTorso", Vector3.new(2, 1.6, 1) }, { "Torso", Vector3.new(2, 2, 1) } } do
	local c0 = KnifeLook.backC0(body[1], body[2])
	local tip, thin = c0.UpVector, c0.RightVector
	local off = math.deg(math.acos(-tip.Y))
	check(body[1] .. " back: blade points down and left, 30 to 50 degrees off straight down", tip.X < 0 and off >= 30 and off <= 50)
	check(body[1] .. " back: the flat lies against the back", thin.Z > 0.95)
	check(body[1] .. " back: grip on the right, behind the body, high", c0.Position.X > 0.3 and c0.Position.Z > body[2].Z / 2 + 0.1 and c0.Position.Y > 0)
	local p = KnifeLook.backC0(body[1], body[2], { length = 3.3, yMin = -1.65, yMax = 1.65, xMin = -0.05, xMax = 0.05, zMin = -0.2, zMax = 0.8 })
	check(body[1] .. " back, a two-handed pole: head up over the right shoulder, the pole down-left", p.UpVector.Y > 0.6 and p.UpVector.X > 0.5)
	local hook = -p.LookVector -- (the knife's +Z, its wide side here)
	check(body[1] .. " back, a two-handed pole: its hook (wide side) down-right, away from the head", hook.X > 0.5 and hook.Y < 0)
	local s = KnifeLook.sideC0(body[1], body[2])
	check(body[1] .. " side: on the right hip, just off it, behind the hanging arm", s.Position.X > body[2].X / 2 and s.Position.X < body[2].X / 2 + 0.3 and s.Position.Z > body[2].Z / 2)
	local back = math.deg(math.asin(s.UpVector.Z))
	check(body[1] .. " side: blade down, 5 to 25 degrees back", s.UpVector.Y < -0.9 and back >= 5 and back <= 25)
	check(body[1] .. " side: the flat lies against the hip", math.abs(s.RightVector.X) > 0.95)
end
check("mount parts: R15 back on UpperTorso, side on LowerTorso, R6 on Torso", KnifeLook.mountPart("Back", false) == "UpperTorso"
	and KnifeLook.mountPart("Side", false) == "LowerTorso" and KnifeLook.mountPart("Side", true) == "Torso")

-- every good model on both bodies at rest: no part inside the body, and close to it
local function pointsOf(cf, size)
	local out = {}
	local n = { math.max(2, math.ceil(size.X / 0.12)), math.max(2, math.ceil(size.Y / 0.12)), math.max(2, math.ceil(size.Z / 0.12)) }
	for i = 0, n[1] - 1 do
		for j = 0, n[2] - 1 do
			for k = 0, n[3] - 1 do
				local l = Vector3.new((i / (n[1] - 1) - 0.5) * size.X, (j / (n[2] - 1) - 0.5) * size.Y, (k / (n[3] - 1) - 0.5) * size.Z)
				table.insert(out, cf * (l * 0.9)) -- (the outer 5% of a mesh box is usually empty air)
			end
		end
	end
	return out
end
local function inside(box, p, margin)
	local l = box.CFrame:PointToObjectSpace(p)
	local h = box.Size / 2
	return math.abs(l.X) < h.X - margin and math.abs(l.Y) < h.Y - margin and math.abs(l.Z) < h.Z - margin
end
local function gap(box, p)
	local l = box.CFrame:PointToObjectSpace(p)
	local h = box.Size / 2
	local d = Vector3.new(math.max(math.abs(l.X) - h.X, 0), math.max(math.abs(l.Y) - h.Y, 0), math.max(math.abs(l.Z) - h.Z, 0))
	return d.Magnitude
end
local ARMS = { LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true, ["Left Arm"] = true, ["Right Arm"] = true }
local worst = {}
local function wornCheck(kind, rig, r6, key, m)
	do
		local s = KnifeLook.shape(partsOf(m))
		local item = CoinShop.get(string.match(key, "^(%w+)"))
		local wear = KnifeLook.wearOf(item and item.Wear, s, m:GetAttribute("Wear"))
		local torso = rig.parts[KnifeLook.mountPart(wear, r6)]
		local h = m:FindFirstChild("Handle")
		local grip = h:FindFirstChild("Grip")
		local handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, s) * (if grip then grip.CFrame else CFrame.identity):Inverse()
		local hits, near = {}, math.huge
		for _, p in partsOf(m) do
			if p.name ~= "Handle" then
				for _, pt in pointsOf(handleCF * p.cf, p.size) do
					for name, part in rig.parts do
						if not part.hidden and inside(part, pt, 0.02) then hits[name] = true end
					end
					near = math.min(near, gap(torso, pt))
					if wear == "Side" then -- (at the hip it hangs beside the hip and the leg: close to the torso or the leg)
						for _, name in { "UpperTorso", "RightUpperLeg", "RightLowerLeg", "Right Leg" } do
							if rig.parts[name] then near = math.min(near, gap(rig.parts[name], pt)) end
						end
					end
				end
			end
		end
		local list = {}
		for name in hits do table.insert(list, name) end
		table.sort(list)
		check(`{kind} {wear} {key}: clear of the body` .. (if #list > 0 then " (in " .. table.concat(list, ", ") .. ")" else ""), #list == 0)
		local flat = torso.CFrame:VectorToObjectSpace(handleCF.RightVector) -- (the knife's thin way)
		check(`{kind} {wear} {key}: its flat lies against the body`, math.abs(if wear == "Side" then flat.X else flat.Z) > 0.95)
		check(`{kind} {wear} {key}: close to the body ({string.format("%.2f", near)} studs)`, near <= 0.35)
		worst[kind] = math.max(worst[kind] or 0, near)
	end
end
local BODIES = {}
for _, kind in { "R15", "R6" } do
	BODIES[kind] = if kind == "R15" then Rig.r15("Body") else Rig.r6("Body")
	for key, m in good do wornCheck(kind, BODIES[kind], kind == "R6", key, m) end
end


-- the real KnifeService on fake bodies
local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
local copy = folder:Clone()
copy.Parent = ServerStorage
local warnings = {}
local FxTexture = { get = function() return "" end, flipbook = function() end, ready = function() return false end }
local shared = { KnifeLook = KnifeLook, FxTexture = FxTexture, KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua") }
local fakeRS = { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes" } }
local env = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else fakeRS end },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	warn = function(s) table.insert(warnings, s) end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
}
-- (Shared/KnifeFx, the knife effects: loaded with its KnifeLook)
shared.KnifeFx = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/KnifeFx.lua"), { debugName = "KnifeFx", environment = (function() local e = table.clone(env); e.script = { Parent = { KnifeLook = "KnifeLook" } }; return e end)() })()
fakeRS.Shared.KnifeFx = "KnifeFx"
local KnifeService = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = env })()

local function body(r6)
	local c = Instance.new("Model")
	c.Name = "Kid"
	local function part(name, size)
		local p = Instance.new("Part")
		p.Name, p.Size = name, size
		p.Parent = c
		return p
	end
	if r6 then
		part("Torso", Vector3.new(2, 2, 1))
		part("Right Arm", Vector3.new(1, 2, 1))
	else
		part("UpperTorso", Vector3.new(2, 1.6, 1))
		part("LowerTorso", Vector3.new(2, 0.4, 1))
		local hand = part("RightHand", Vector3.new(1, 0.3, 1))
		local a = Instance.new("Attachment")
		a.Name = "RightGripAttachment"
		a.Position = Vector3.new(0, -0.15, 0)
		a.Parent = hand
	end
	return c
end
local function knives(c)
	local n, which = 0, nil
	for _, d in c:GetChildren() do
		if d:IsA("Model") and (d.Name == "HuzzKnife" or d.Name == "HuzzBackKnife") then n += 1; which = d end
	end
	return n, which
end
local function mountOf(model)
	local h = model:FindFirstChild("Handle", true)
	return h and (h:FindFirstChild("BackMount") or h:FindFirstChild("KnifeGrip"))
end

do
	local c = body(false)
	local rusty, spin = CoinShop.get("RustyShiv"), CoinShop.get("SpinKnife")
	KnifeService.giveBack(c, rusty) -- the lobby
	local n, k = knives(c)
	check("lobby: one knife, worn", n == 1 and k.Name == "HuzzBackKnife")
	check("lobby: Rusty Shiv (a short knife) at the hip, on the LowerTorso", k:GetAttribute("WornAt") == "Side" and mountOf(k).Part0.Name == "LowerTorso")
	check("lobby: the owner's model (not ours)", k:FindFirstChild("blade_0", true) ~= nil)
	check("lobby: Common has no effects on the back", k:FindFirstChildWhichIsA("ParticleEmitter", true) == nil and k:FindFirstChildWhichIsA("PointLight", true) == nil)
	local first = k
	KnifeService.giveBack(c, rusty) -- a sync with nothing new
	n, k = knives(c)
	check("sync again: the same knife, not rebuilt", n == 1 and k == first)
	KnifeService.give(c, rusty) -- becomes a catcher
	n, k = knives(c)
	check("catcher: one knife, in the hand", n == 1 and k.Name == "HuzzKnife" and mountOf(k).Part0.Name == "RightHand")
	check("catcher: the slash trail is there", k:FindFirstChild("SlashTrail", true) ~= nil)
	check("catcher: has() says so", KnifeService.has(c))
	KnifeService.giveBack(c, rusty) -- the round ends
	n, k = knives(c)
	check("after: one knife, worn again", n == 1 and k.Name == "HuzzBackKnife" and not KnifeService.has(c))
	KnifeService.giveBack(c, spin) -- picks Celestial Edge in the shop
	n, k = knives(c)
	check("skin change: one knife, the new one", n == 1 and k:GetAttribute("Skin") == "SpinKnife")
	check("Celestial Edge (a long blade): on the back, on the UpperTorso", k:GetAttribute("WornAt") == "Back" and mountOf(k).Part0.Name == "UpperTorso")
	local wornRate = 0
	for _, d in k:GetDescendants() do if d:IsA("ParticleEmitter") then wornRate += d.Rate end end
	check(string.format("worn (Legendary): its effects, a little lighter (%.1f a second), no light, no burst", wornRate),
		wornRate > 0 and wornRate <= KnifeLook.VFX.MaxTotal and k:FindFirstChildWhichIsA("Light", true) == nil and k:FindFirstChild("KnifeBurst", true) == nil)
	-- the avatar's look swaps the UpperTorso: the knife goes on the new one
	c.UpperTorso:Destroy()
	local lt = Instance.new("Part")
	lt.Name, lt.Size, lt.Parent = "UpperTorso", Vector3.new(2, 1.6, 1), c
	KnifeService.giveBack(c, spin)
	n, k = knives(c)
	check("new body part: the knife is put back on it", n == 1 and mountOf(k).Part0 == lt)
	KnifeService.give(c, spin)
	KnifeService.give(c, rusty) -- a catcher changes skin mid-round
	n, k = knives(c)
	check("catcher skin change: one knife, the new one, in hand", n == 1 and k.Name == "HuzzKnife" and k:GetAttribute("Skin") == "RustyShiv")
	KnifeService.take(c)
	KnifeService.takeBack(c)
	check("take + takeBack: none left", (knives(c)) == 0)
	-- the default knife (no knife owned: every Studio Play, the save is Mock) on a blocky R15: the owner's Oct 20
	-- "black thing attached to my character" looks like its dark grip, so where it really sits is measured here
	KnifeService.giveBack(c, nil)
	n, k = knives(c)
	local m = k and mountOf(k)
	local at = m and (m.C0 * m.C1:Inverse()).Position
	check(string.format("R15, no knife owned: the default knife at the right hip (grip at %.2f, %.2f, %.2f in the LowerTorso)",
		at and at.X or 0, at and at.Y or 0, at and at.Z or 0),
		n == 1 and k:GetAttribute("WornAt") == "Side" and m.Part0.Name == "LowerTorso" and at.X > 1 and at.X < 1.3
			and math.abs(at.Y) < 0.2 and at.Z > 0.5 and at.Z < 1)
	local steel = 0
	for _, d in k:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Part0 and d.Part0.Name == "Handle" then steel += 1 end
	end
	check("R15, no knife owned: its pommel, guard, blade and tip all welded to its grip", steel == 4)
end
do
	local c = body(true)
	KnifeService.giveBack(c, CoinShop.get("AbyssEclipse"))
	local n, k = knives(c)
	check("R6: one knife on the Torso's back", n == 1 and k:GetAttribute("WornAt") == "Back" and mountOf(k).Part0.Name == "Torso")
	KnifeService.giveBack(c, CoinShop.get("RustyShiv"))
	n, k = knives(c)
	check("R6: Rusty Shiv at the hip of the Torso", n == 1 and k:GetAttribute("WornAt") == "Side" and mountOf(k).Part0.Name == "Torso")
	KnifeService.give(c, nil)
	n, k = knives(c)
	check("R6: the default knife in the right arm", n == 1 and k.Name == "HuzzKnife" and mountOf(k).Part0.Name == "Right Arm")
	KnifeService.giveBack(c, nil)
	n, k = knives(c)
	check("no knife owned: the default knife on the back", n == 1 and k.Name == "HuzzBackKnife" and k:FindFirstChild("Blade", true) ~= nil)
end
do
	local c = body(false)
	-- a setup gone wrong (what 8 of the Oct 18 file looked like before tools/knives/repair_knives.luau): Box Cutter
	-- 12 times too big, lying along the Handle's X
	local bad = "BoxCutter"
	do
		local m = copy:FindFirstChild(bad)
		local h = m:FindFirstChild("Handle")
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= h then
				local rel = h.CFrame:ToObjectSpace(d.CFrame)
				d.CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(90)) * (CFrame.new(rel.Position * 12) * rel.Rotation)
				d.Size *= 12
			end
		end
		check("a knife 12 times too big, lying sideways, isn't sane", not KnifeLook.sane(KnifeService.shapeOf(m), m:GetAttribute("Studs")))
	end
	do
		warnings = {}
		KnifeService.giveBack(c, CoinShop.get(bad))
		local n, k = knives(c)
		check(`{bad} (wrong size in the file): the plain knife in its colours instead`, n == 1 and k:FindFirstChild("Blade", true) ~= nil)
		check(`{bad}: one warning in Output`, #warnings == 1 and string.find(warnings[1], bad, 1, true) ~= nil)
		KnifeService.giveBack(Instance.new("Model"), CoinShop.get(bad))
		check(`{bad}: warned only once`, #warnings == 1)
	end
end

-- The 5 Game Pass and 18 Halloween stand-ins (Shared/KnifeShapes, cut from his .glb: what you wear until the owner
-- imports his models) on both bodies too: clear of the body and close to it.
for _, item in CoinShop.Items do
	if item.Slot == "Knife" and item.Model and string.find(item.Model, "/", 1, true) then
		local m = KnifeService.template(item)
		for _, kind in { "R15", "R6" } do wornCheck(kind, BODIES[kind], kind == "R6", item.Key .. " (stand-in)", m) end
	end
end

-- The shop table (owner, Oct 19 "make the location based on what knife/sword it is"): every knife has a Wear, and it
-- agrees with what his .glb measures (3.0+ studs = Back): his swords, katanas, reapers and scythe on the back, his
-- knives, daggers, kunai, cleavers, sickles, karambits and shurikens at the hip.
do
	local wrong, backs, sides = {}, 0, 0
	for _, item in CoinShop.Items do
		if item.Slot == "Knife" then
			local m = KnifeService.template(item)
			local s = KnifeService.shapeOf(m)
			if item.Wear == "Back" then backs += 1 elseif item.Wear == "Side" then sides += 1 end
			if item.Wear ~= KnifeLook.wearOf(nil, s) then table.insert(wrong, string.format("%s %s %.2f", item.Key, tostring(item.Wear), s.length)) end
		end
	end
	check(`every knife's Wear matches its measured length ({backs} back, {sides} side)` .. (if #wrong > 0 then ": " .. table.concat(wrong, ", ") else ""),
		#wrong == 0 and backs + sides == 53)
	for _, key in { "PumpkinKingKatana", "CovenKatana", "SugarRushKatana", "JacksReaper", "GrandWitchScythe", "CandyReaper", "SolarReaper",
		"AbyssEclipse", "CrimsonRequiem", "CelestialSeraph" } do
		check(key .. ": on the back", CoinShop.get(key).Wear == "Back")
	end
	for _, key in { "RustyShiv", "ScoutDagger", "BloodMoonTanto", "JadeKunai", "HexShuriken", "ThornKarambit", "HarvestSickle", "GumdropDagger" } do
		check(key .. ": at the hip", CoinShop.get(key).Wear == "Side")
	end
	local pole = KnifeService.shapeOf(KnifeService.template(CoinShop.get("GrandWitchScythe")))
	check("Grand Witch Scythe: two-handed (worn head up)", KnifeLook.twoHanded(pole))
end

-- The owner's Oct 20 "black thing attached to my character": a dark block the default knife's grip size, about 3
-- studs off him at his shins. Every screen now hides a worn knife whose grip is more than KnifeLook.STRAY studs from
-- where its weld holds it or outside the body part it hangs from, and a piece farther from its grip than it was made
-- (HuzzClient/Gameplay/KnifeGuard). 1) No knife worn where it should be is ever hidden: all 53 and the default knife
-- on blocky, slim (0.7), big (1.5) and wide (1.6 across, his avatar's build) R15 bodies and on R6.
local function stretchRig(rig, k: Vector3)
	for _, p in rig.parts do p.Size *= k end
	for _, m in rig.motors do
		m.C0 = CFrame.new(m.C0.Position * k) * m.C0.Rotation
		m.C1 = CFrame.new(m.C1.Position * k) * m.C1.Rotation
	end
	Rig.fk(rig)
	return rig
end
local guardBodies = {
	{ "R15", Rig.r15("B"), false }, { "R15 slim", stretchRig(Rig.r15("B"), Vector3.one * 0.7), false },
	{ "R15 big", stretchRig(Rig.r15("B"), Vector3.one * 1.5), false }, { "R15 wide", stretchRig(Rig.r15("B"), Vector3.new(1.6, 1, 1.3)), false },
	{ "R6", Rig.r6("B"), true },
}
do
	local all = {}
	for key, m in good do table.insert(all, { key, m, CoinShop.get(key) }) end
	for _, item in CoinShop.Items do
		if item.Slot == "Knife" and item.Model and string.find(item.Model, "/", 1, true) and not good[item.Key] then table.insert(all, { item.Key, KnifeService.template(item), item }) end
	end
	table.insert(all, { "the default knife", KnifeService.template(nil), nil })
	for _, b in guardBodies do
		local rig, r6 = b[2], b[3]
		local worst, worstKey, hiddenAny = 0, "", {}
		for _, k in all do
			local m = k[2]
			local s = KnifeLook.shape(partsOf(m))
			local wear = KnifeLook.wearOf(k[3] and k[3].Wear, s, m:GetAttribute("Wear"))
			local torso = rig.parts[KnifeLook.mountPart(wear, r6)]
			local gripAt = (torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, s)).Position
			local by = KnifeLook.outside(torso.CFrame, torso.Size, gripAt)
			if by > worst then worst, worstKey = by, k[1] end
			if by > KnifeLook.STRAY then hiddenAny[k[1]] = true end
		end
		local list = {}
		for key in hiddenAny do table.insert(list, key) end
		print(string.format("  guard, %s: farthest worn grip %.2f studs outside its body part (%s)", b[1], worst, worstKey))
		check(string.format("guard, %s: no worn knife is hidden (%d knives)", b[1], #all) .. (if #list > 0 then ": " .. table.concat(list, ", ") else ""),
			#list == 0 and #all == 54)
	end
end
-- 1b) Oct 21: each screen's Gameplay/FollowGuard (c) removes a visible part inside a character whose box is more
-- than FollowGuard.LOOSE studs off every body part. No piece of any knife worn where it should be may count: all 53
-- and the default knife, every piece, on the same bodies.
do
	-- (FollowGuard asks ReplicatedStorage for Shared/LooseParts: handed the real one here)
	local LP = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/LooseParts.lua"), { debugName = "LooseParts" })()
	local fakeShared = { WaitForChild = function(self) return self end }
	local FG = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/FollowGuard.lua"), { debugName = "FollowGuard",
		environment = { game = { GetService = function() return fakeShared end }, require = function() return LP end } })()
	local all = {}
	for key, m in good do table.insert(all, { key, m, CoinShop.get(key) }) end
	for _, item in CoinShop.Items do
		if item.Slot == "Knife" and item.Model and string.find(item.Model, "/", 1, true) and not good[item.Key] then table.insert(all, { item.Key, KnifeService.template(item), item }) end
	end
	table.insert(all, { "the default knife", KnifeService.template(nil), nil })
	local function outside(cf, size, at)
		local p = cf:PointToObjectSpace(at)
		local h = size / 2
		local dx, dy, dz = math.max(math.abs(p.X) - h.X, 0), math.max(math.abs(p.Y) - h.Y, 0), math.max(math.abs(p.Z) - h.Z, 0)
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	for _, b in guardBodies do
		local rig, r6 = b[2], b[3]
		local worst, worstKey, bad = -math.huge, "", {}
		for _, k in all do
			local m = k[2]
			local h = m:FindFirstChild("Handle", true)
			local grip = h and h:FindFirstChild("Grip")
			local c1 = if grip and grip:IsA("Attachment") then grip.CFrame else CFrame.identity
			local s = KnifeLook.shape(partsOf(m))
			local wear = KnifeLook.wearOf(k[3] and k[3].Wear, s, m:GetAttribute("Wear"))
			local torso = rig.parts[KnifeLook.mountPart(wear, r6)]
			local handleAt = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, s) * c1:Inverse()
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < FG.SEE then
					local at = (handleAt * h.CFrame:ToObjectSpace(d.CFrame)).Position
					local gap = math.huge
					for name, l in rig.parts do
						if FG.LIMBS[name] then gap = math.min(gap, outside(l.CFrame, l.Size, at) - d.Size.Magnitude / 2) end
					end
					if gap > worst then worst, worstKey = gap, k[1] .. " " .. d.Name end
					if gap > FG.LOOSE then bad[k[1]] = true end
				end
			end
		end
		local list = {}
		for key in bad do table.insert(list, key) end
		print(string.format("  loose check, %s: farthest worn piece %.2f studs off the body (%s)", b[1], worst, worstKey))
		check(string.format("loose check, %s: no worn knife piece is removed", b[1]) .. (if #list > 0 then ": " .. table.concat(list, ", ") else ""), #list == 0)
	end
end
-- 2) The guard itself (HuzzClient/Gameplay/KnifeGuard.scan) on the real KnifeService's default knife, worn on a
-- blocky R15: where it should be nothing is hidden; its grip moved where his picture shows the block (3 studs to his
-- left, in front, at his shins, tilted 20 degrees): the knife is hidden; back in place, it shows again; one piece
-- come loose from the grip: only that piece.
do
	local KnifeGuard = luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/KnifeGuard.lua"), {
		debugName = "KnifeGuard",
		environment = {
			game = { GetService = function() return { WaitForChild = function(_, n) return { WaitForChild = function(_, m) return m end } end } end },
			require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
			string = string, tostring = tostring, warn = function() end, pcall = pcall, table = table,
		},
	})()
	local rig = Rig.r15("B")
	local c = Instance.new("Model")
	c.Name = "Owner"
	for name, p in rig.parts do
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame = name, p.Size, p.CFrame
		part.Parent = c
	end
	KnifeService.giveBack(c, nil)
	local k = c:FindFirstChild("HuzzBackKnife")
	local h = k and k:FindFirstChild("Handle", true)
	local m = h and h:FindFirstChild("BackMount")
	if h and m then -- (Lune solves no welds: put each part where its weld holds it)
		local was = h.CFrame
		local now = m.Part0.CFrame * m.C0 * m.C1:Inverse()
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then d.CFrame = now * was:ToObjectSpace(d.CFrame) end
		end
	end
	local state = {}
	local function hide(part, stray) state[part.Name] = stray end
	KnifeGuard.scan(c, hide)
	local shown, n = 0, 0
	for _, v in state do n += 1; if not v then shown += 1 end end
	check(string.format("guard: the default knife worn at the hip, all %d parts shown", n), n == 5 and shown == 5)
	local okLine, line = pcall(KnifeGuard.describe, k, c)
	check(`guard: the knife report line counts its pieces ({if okLine then line else "error: " .. tostring(line)})`,
		okLine and string.find(line, "5 pieces, 5 showing", 1, true) ~= nil)
	local home = h and h.CFrame
	if h then h.CFrame = c.HumanoidRootPart.CFrame * CFrame.new(-3, -2.2, -1.5) * CFrame.Angles(0, 0, math.rad(20)) end
	KnifeGuard.scan(c, hide)
	check("guard: its grip where his block hangs: the knife is hidden", state.Handle == true and state.Blade == true and state.Tip == true)
	if h then h.CFrame = home end
	KnifeGuard.scan(c, hide)
	check("guard: back on the body, it shows again", state.Handle == false and state.Blade == false)
	-- a piece come loose from its grip (the grip still at the hip): only that piece
	local blade = k and k:FindFirstChild("Blade", true)
	local bladeHome = blade and blade.CFrame
	if blade then blade.CFrame = c.HumanoidRootPart.CFrame * CFrame.new(-3, -2.2, -1.5) end
	KnifeGuard.scan(c, hide)
	check(string.format("guard: a piece 3 studs off its grip is hidden, nothing else (the knife reaches %.2f studs)", k and k:GetAttribute("Reach") or -1),
		state.Blade == true and state.Handle == false and state.Tip == false and state.Guard == false)
	if blade then blade.CFrame = bladeHome end
	KnifeGuard.scan(c, hide)
	check("guard: back in place, the piece shows again", state.Blade == false)
end

-- A cape, long hair or wings on the back (the avatar's accessories): the knife goes over a cape and hair, never
-- through; big wings send a long blade to the hip.
do
	local T = Vector3.new(2, 1.6, 1)
	local cape = { cf = CFrame.new(0, -0.3, 0.6), size = Vector3.new(1.9, 2.6, 0.2) }
	local hair = { cf = CFrame.new(0, 1.2, 0.35), size = Vector3.new(1.4, 1.6, 0.6) } -- (from the head down over the shoulders)
	local hat = { cf = CFrame.new(0, 1.9, 0.1), size = Vector3.new(1.4, 0.6, 1.4) }
	local wings = { cf = CFrame.new(0, 0.3, 1.1), size = Vector3.new(4, 3, 1.2) }
	check("backClear: nothing = 0", KnifeLook.backClear({}, T) == 0)
	check(string.format("backClear: a cape = how far it hangs off the back (%.2f)", KnifeLook.backClear({ cape }, T)), math.abs(KnifeLook.backClear({ cape }, T) - 0.2) < 1e-4)
	check("backClear: long hair counts, a hat doesn't", KnifeLook.backClear({ hair }, T) > 0.1 and KnifeLook.backClear({ hat }, T) == 0)
	check("wornAt: a cape keeps it on the back, wings send it to the hip", KnifeLook.wornAt("Back", 0.2) == "Back" and KnifeLook.wornAt("Back", KnifeLook.backClear({ wings }, T)) == "Side"
		and KnifeLook.wornAt("Side", 2) == "Side")
	local plain, over = KnifeLook.backC0("UpperTorso", T, nil), KnifeLook.backC0("UpperTorso", T, nil, 0.2)
	check("over a cape: the same place, 0.2 further out", math.abs(over.Position.Z - plain.Position.Z - 0.2) < 1e-4 and math.abs(over.Position.Y - plain.Position.Y) < 1e-4)
	-- the real KnifeService: a cape on the body pushes the worn sword out; added later, refit does it
	local c = body(false)
	local function accessory(box)
		local a = Instance.new("Accessory")
		local h = Instance.new("Part")
		h.Name, h.Size = "Handle", box.size
		h.CFrame = c.UpperTorso.CFrame * box.cf
		h.Parent = a
		a.Parent = c
		return a
	end
	KnifeService.giveBack(c, CoinShop.get("AbyssEclipse"))
	local _, k = knives(c)
	local z0 = mountOf(k).C0.Position.Z
	local a = accessory(cape)
	KnifeService.refit(c)
	check(string.format("KnifeService: a cape put on later pushes the sword out over it (%.2f -> %.2f)", z0, mountOf(k).C0.Position.Z),
		math.abs(mountOf(k).C0.Position.Z - z0 - 0.2) < 1e-3 and k:GetAttribute("WornAt") == "Back")
	a:Destroy()
	accessory(wings)
	KnifeService.refit(c)
	check("KnifeService: with big wings the sword goes to the hip", k:GetAttribute("WornAt") == "Side" and mountOf(k).Part0.Name == "LowerTorso")
	-- and at the hip, a long blade is still clear of the body (the wings case)
	local m = KnifeService.template(CoinShop.get("AbyssEclipse"))
	local s = KnifeService.shapeOf(m)
	for _, kind in { "R15", "R6" } do
		local rig = BODIES[kind]
		local torso = rig.parts[KnifeLook.mountPart("Side", kind == "R6")]
		local grip = m:FindFirstChild("Handle"):FindFirstChild("Grip")
		local handleCF = torso.CFrame * KnifeLook.sideC0(torso.Name, torso.Size, s) * (if grip then grip.CFrame else CFrame.identity):Inverse()
		local hit = false
		for _, p in partsOf(m) do
			if p.name ~= "Handle" then
				for _, pt in pointsOf(handleCF * p.cf, p.size) do
					for _, part in rig.parts do
						if not part.hidden and inside(part, pt, 0.02) then hit = true end
					end
				end
			end
		end
		check(kind .. " wings: the long blade at the hip is clear of the body", not hit)
	end
end

-- In a catcher's hand (knife check, Oct 19): at the old fixed 150 degrees the 3+ stud knives dipped into the floor in
-- the idle and the walk (Crimson Requiem up to 0.43 studs under it). KnifeLook.handC0 now holds a long blade more forward by
-- its reach (KnifeService.reachOf): every one of his 30 models and the 5 pass stand-ins, on R15 through the pack's
-- Idle, Walk and Run, keeps its tip 0.15+ studs over the floor; short knives keep Huss Valley's 150 degrees.
do
	local KFS = require("../tools/preview/motion3d/kfs")
	local Mix = Env.load(SHARED .. "LocomotionMix.lua")
	local lib = Instance.new("Folder")
	for _, inst in roblox.deserializeModel(fs.readFile(ROOT .. "src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
	local A = {}
	for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(lib:FindFirstChild(name, true)) end
	local rig = Rig.r15("Hand")
	rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
	local floorY = 0
	-- the hand through each gait, as CFrames to test each knife against
	local hands = {}
	for _, g in { { "Idle", 0 }, { "Walk", 10 }, { "Run", 26 } } do
		local mix = Mix.new()
		for _ = 1, 60 do Mix.step(mix, 1 / 30, { speed = g[2], state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } }) end
		for i = 0, 40 do
			local t = i * 0.05
			for _, m in rig.motors do m.Transform = CFrame.identity end
			local total = 0
			for _, name in { "Idle", "Walk", "Run" } do
				local w = mix.weights[name]
				if w > 1e-4 then
					total += w
					KFS.apply(A[name], rig, t, w / total)
				end
			end
			Rig.fk(rig)
			table.insert(hands, { gait = g[1], cf = rig.parts.RightHand.CFrame })
		end
	end
	local function lowestTip(reach)
		local lo, gait = math.huge, ""
		for _, h in hands do
			local at = Vector3.new(0, -0.15, 0)
			local y = (h.cf * KnifeLook.handC0(at, reach) * Vector3.new(0, reach, 0)).Y
			if y < lo then lo, gait = y, h.gait end
		end
		return lo - floorY, gait
	end
	local worstKey, worstY = "", math.huge
	local function test(key, model)
		local handle = model:FindFirstChild("Handle", true)
		local reach = KnifeService.reachOf(model, handle)
		local y, gait = lowestTip(reach)
		if y < worstY then worstKey, worstY = key, y end
		check(string.format("in hand %s: the tip stays off the floor (%.2f over it at worst, %s; reach %.2f)", key, y, gait, reach), y >= 0.15)
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:FindFirstChild("Handle", true) then test(m.Name, m) end
	end
	for _, item in CoinShop.Items do -- (the pass and Halloween knives, from his files of several: their stand-ins)
		if item.Slot == "Knife" and item.Model and string.find(item.Model, "/", 1, true) then
			test(item.Key .. " (stand-in)", (KnifeService.template(item)))
		end
	end
	print(string.format("  in hand, lowest tip: %s %.2f studs over the floor", worstKey, worstY))
	check("in hand: a short knife keeps Huss Valley's 150 degrees", KnifeLook.handAngle(2.07) == -150)
	-- the real give() uses it: a long pass knife's grip is turned forward, a short one isn't
	local c = body(false)
	KnifeService.give(c, CoinShop.get("CrimsonRequiem"))
	local _, k = knives(c)
	local grip = k and mountOf(k)
	local x = if grip then select(1, grip.C0:ToEulerAnglesXYZ()) else 0
	check(string.format("give: a long blade is held more forward (%.0f degrees, not -150)", math.deg(x)), grip ~= nil and math.deg(x) > -145)
	-- in the slash it eases back to the usual angle (Gameplay/Actions) and returns to the hold after
	if grip then
		local held = grip.C0
		local function deg(cf) return math.deg((cf:ToEulerAnglesXYZ())) end
		check("slash: the long blade turns back to -150 for the cut", math.abs(deg(KnifeLook.slashC0(held, 1)) + 150) < 0.01)
		check("slash: and back to its hold after", math.abs(deg(KnifeLook.slashC0(held, 0)) - math.deg(x)) < 0.01
			and (KnifeLook.slashC0(held, 0).Position - held.Position).Magnitude < 1e-6)
		check("slash: halfway is halfway", math.abs(deg(KnifeLook.slashC0(held, 0.5)) - (math.deg(x) - 150) / 2) < 0.01)
	end
end

print(string.format("KnifeWear: %d ok, %d failed (farthest worn knife from its torso: R15 %.2f, R6 %.2f studs)", passed, failed, worst.R15 or 0, worst.R6 or 0))
if failed > 0 then error("KnifeWear spec failed") end
