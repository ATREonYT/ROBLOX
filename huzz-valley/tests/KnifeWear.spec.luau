-- lune run tests/KnifeWear.spec.luau   (from huzz-valley/)
-- The knife you wear (owner, Oct 18: "make the knifes please be equipped when you have them, like be shown on the
-- back of the character"; "or even for the katanas you can make it be on the side of the person"):
--   * which knife: the one picked in the shop, else the first one you own, else the default knife (KnifeLook.pick);
--   * where: diagonal across the back, or at the left hip for long slim blades; the owner's 30 real models
--     (assets/knives/HuzzKnives.rbxm) sorted by their own shape: only Celestial Edge (SpinKnife) at the side;
--   * every one of the 30 on a blocky R15 and R6 body in its rest pose: nothing goes into the head, torso, legs or
--     (on the back) the arms, and it sits close to the body (not floating);
--   * the real HuzzServer/KnifeService on fake bodies: ONE knife per body, worn in the lobby, moved to the hand for a
--     catcher and back after, a skin change swaps it at once, a body part swapped out gets the knife back, R6 works,
--     and a model of the wrong size is never used (the plain knife in its colours instead).
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
local good, broken, side = {}, {}, {}
for _, m in folder:GetChildren() do
	local s = KnifeLook.shape(partsOf(m))
	if KnifeLook.sane(s, m:GetAttribute("Studs")) then
		good[m.Name] = m
		if KnifeLook.wearOf(m:GetAttribute("Wear"), s) == "Side" then table.insert(side, m.Name) end
	else
		table.insert(broken, m.Name)
	end
end
table.sort(broken)
table.sort(side)
print("  models the wrong size (shown as the plain knife until fixed): " .. (if #broken > 0 then table.concat(broken, ", ") else "none"))
check("all 30 models are the right size (tools/knives/repair_knives.luau fixed 8 on Oct 18)", #folder:GetChildren() == 30 and #broken == 0)
check("only Celestial Edge goes at the side (got " .. table.concat(side, ", ") .. ")", #side == 1 and side[1] == "SpinKnife")
check("set Wear wins", KnifeLook.wearOf("Side", { length = 2, bladeLength = 1, bladeWidth = 1 }) == "Side"
	and KnifeLook.wearOf("Back", { length = 4, bladeLength = 3, bladeWidth = 0.2 }) == "Back")
check("a long slim katana (3.4 studs, 9 to 1) goes at the side", KnifeLook.wearOf(nil, { length = 3.4, bladeLength = 2.4, bladeWidth = 0.27 }) == "Side")
check("a long wide cleaver stays on the back", KnifeLook.wearOf(nil, { length = 3.4, bladeLength = 2.2, bladeWidth = 0.7 }) == "Back")
check("a short slim knife stays on the back", KnifeLook.wearOf(nil, { length = 2.6, bladeLength = 1.7, bladeWidth = 0.08 }) == "Back")
check("no measure = back", KnifeLook.wearOf(nil, nil) == "Back")

-- the mounts' directions
for _, body in { { "UpperTorso", Vector3.new(2, 1.6, 1) }, { "Torso", Vector3.new(2, 2, 1) } } do
	local c0 = KnifeLook.backC0(body[1], body[2])
	local tip, thin = c0.UpVector, c0.RightVector
	local off = math.deg(math.acos(-tip.Y))
	check(body[1] .. " back: blade points down and left, 30 to 50 degrees off straight down", tip.X < 0 and off >= 30 and off <= 50)
	check(body[1] .. " back: the flat lies against the back", thin.Z > 0.95)
	check(body[1] .. " back: grip on the right, behind the body, high", c0.Position.X > 0.3 and c0.Position.Z > body[2].Z / 2 + 0.1 and c0.Position.Y > 0)
	local s = KnifeLook.sideC0(body[1], body[2])
	check(body[1] .. " side: grip on the left, outside the leg, in front", s.Position.X < -body[2].X / 2 - 0.2 and s.Position.Z < -0.3)
	local down = math.deg(math.asin(-s.UpVector.Y))
	check(body[1] .. " side: blade slopes down toward the back, 15 to 40 degrees", s.UpVector.Z > 0.7 and down >= 15 and down <= 40)
	check(body[1] .. " side: the flat faces out", s.RightVector.X < -0.95)
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
local worst, armTouch = {}, {}
for _, kind in { "R15", "R6" } do
	local rig = if kind == "R15" then Rig.r15("Body") else Rig.r6("Body")
	local r6 = kind == "R6"
	for key, m in good do
		local s = KnifeLook.shape(partsOf(m))
		local wear = KnifeLook.wearOf(m:GetAttribute("Wear"), s)
		local torso = rig.parts[KnifeLook.mountPart(wear, r6)]
		local h = m:FindFirstChild("Handle")
		local grip = h:FindFirstChild("Grip")
		local handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, s) * (if grip then grip.CFrame else CFrame.identity):Inverse()
		local hits, near = {}, math.huge
		for _, p in partsOf(m) do
			if p.name ~= "Handle" then
				for _, pt in pointsOf(handleCF * p.cf, p.size) do
					for name, part in rig.parts do
						if not part.hidden and not (wear == "Side" and ARMS[name]) and inside(part, pt, 0.02) then hits[name] = true end
						-- (at the side the hanging hand can touch the hilt: a known gap, counted, not failed)
						if wear == "Side" and ARMS[name] and inside(part, pt, 0.02) then armTouch[`{kind} {key} {name}`] = true end
					end
					near = math.min(near, gap(torso, pt))
				end
			end
		end
		local list = {}
		for name in hits do table.insert(list, name) end
		table.sort(list)
		check(`{kind} {wear} {key}: clear of the body` .. (if #list > 0 then " (in " .. table.concat(list, ", ") .. ")" else ""), #list == 0)
		check(`{kind} {wear} {key}: close to the body ({string.format("%.2f", near)} studs)`, near <= 0.35)
		worst[kind] = math.max(worst[kind] or 0, near)
	end
end

do
	local list = {}
	for k in armTouch do table.insert(list, k) end
	table.sort(list)
	print("  at the hip, touching a hanging arm at rest: " .. (if #list > 0 then table.concat(list, ", ") else "none"))
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
	check("lobby: on the back, on the UpperTorso", k:GetAttribute("WornAt") == "Back" and mountOf(k).Part0.Name == "UpperTorso")
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
	check("after: one knife, back on the back", n == 1 and k.Name == "HuzzBackKnife" and not KnifeService.has(c))
	KnifeService.giveBack(c, spin) -- picks Celestial Edge in the shop
	n, k = knives(c)
	check("skin change: one knife, the new one", n == 1 and k:GetAttribute("Skin") == "SpinKnife")
	check("Celestial Edge: at the side, on the LowerTorso", k:GetAttribute("WornAt") == "Side" and mountOf(k).Part0.Name == "LowerTorso")
	check("Legendary: its glow stays on while worn", k:FindFirstChildWhichIsA("PointLight", true) ~= nil)
	-- the avatar's look swaps the LowerTorso: the knife goes on the new one
	c.LowerTorso:Destroy()
	local lt = Instance.new("Part")
	lt.Name, lt.Size, lt.Parent = "LowerTorso", Vector3.new(2, 0.4, 1), c
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
end
do
	local c = body(true)
	KnifeService.giveBack(c, CoinShop.get("AbyssEclipse"))
	local n, k = knives(c)
	check("R6: one knife on the Torso's back", n == 1 and k:GetAttribute("WornAt") == "Back" and mountOf(k).Part0.Name == "Torso")
	KnifeService.giveBack(c, CoinShop.get("SpinKnife"))
	n, k = knives(c)
	check("R6: Celestial Edge at the side of the Torso", n == 1 and k:GetAttribute("WornAt") == "Side" and mountOf(k).Part0.Name == "Torso")
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

print(string.format("KnifeWear: %d ok, %d failed (farthest worn knife from its torso: R15 %.2f, R6 %.2f studs)", passed, failed, worst.R15 or 0, worst.R6 or 0))
if failed > 0 then error("KnifeWear spec failed") end
