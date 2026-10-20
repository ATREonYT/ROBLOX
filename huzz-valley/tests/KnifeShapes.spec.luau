-- lune run tests/KnifeShapes.spec.luau   (from huzz-valley/)
-- The Game Pass knives made big and alive (owner, Oct 19: "right now its very small and you dont even notice it ...
-- better knife animations ... in the lobby and in the gamepass sections"), with the real HuzzServer/KnifeService:
--   * each stand-in (Shared/KnifeShapes: the 5 pass knives and his 18 Halloween knives, cut from his files) is its
--     listed length (not our 1.9 stud dagger), shaped like a knife (KnifeLook.sane, with its Wide allowance for his
--     sickles, karambits and shurikens), in his .glb's box and colours, glowing Neon parts where his has glow, and its
--     slash trail points;
--   * KnifeService.scale grows a model about its grip: length, attachments and welds together (by hand, no ScaleTo);
--   * the stands' copy (KnifeService.display) is about KnifeLook.STAND.Length long, for stand-ins and the owner's own
--     models alike, and carries its element: steady emitters, a burst, a tip glint, its element name;
--   * on a stand, its own shape only bigger (owner, Oct 19: "they dont look as good as in the glb file"): scaled the
--     same every way (no widening), no glow shell laid over it, the slash from mid-blade;
--   * steady: a stand's knife throws at most 32 particles a second (a hand about a third), a burst at most 20, the glint at
--     most one a second; every picture name has a stand-in in Shared/FxTexture;
--   * the slash arc fades in and out within its life and is never solid (KnifeLook.arcFade).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua")
local FxTextureReal = Env.load(SHARED .. "FxTexture.lua")
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

-- the real KnifeService (as tests/KnifeWear.spec), with the owner's 30 models in ServerStorage
local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
local folder = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
folder.Parent = ServerStorage
local FxTexture = { get = function(n) return "tex:" .. n end, flipbook = function() end, ready = function() return false end }
local shared = { KnifeLook = KnifeLook, FxTexture = FxTexture, KnifeShapes = KnifeShapes }
local fakeRS = { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes" } }
local env = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else fakeRS end },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	warn = function() end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
}
local KnifeService = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = env })()

local baked = {}
for _, k in serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json")) do baked[k.key] = k end

local PASS = { "CrimsonRequiem", "HollowEclipse", "CelestialSeraph", "DragonsMaw", "FrostboundOath" }
local SHEET = {} -- every knife of his files of several (the 5 pass knives, his 18 Halloween knives)
for _, k in serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json")) do
	if string.find(k.file, "/", 1, true) then table.insert(SHEET, k.key) end
end
check("23 stand-ins cut from his files (" .. #SHEET .. ")", #SHEET == 23)
local function count(model, class)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA(class) then n += 1 end end
	return n
end

-- 1. the stand-ins
for _, key in SHEET do
	local skin = CoinShop.get(key)
	local model, own = KnifeService.template(skin)
	local shape = KnifeService.shapeOf(model)
	check(key .. ": no model of his yet, so our stand-in", own == false and KnifeShapes.get(key) ~= nil)
	check(key .. string.format(": stand-in about its real length (%.2f vs %.2f studs)", shape.length, baked[key].studs),
		math.abs(shape.length - baked[key].studs) <= 0.15 * baked[key].studs)
	check(key .. ": shaped like a knife (KnifeLook.sane)", KnifeLook.sane(shape, skin.Studs, skin.Wide))
	local neon = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") and d.Material == roblox.Enum.Material.Neon then neon += 1 end end
	if baked[key].glowParts > 0 then
		check(key .. ": glowing parts (" .. neon .. ")", neon >= 1)
	else
		check(key .. ": no glow on his, none on ours (" .. neon .. ")", neon == 0)
	end
	-- cut from his .glb (Shared/KnifeStandIns): his outline, his colours, not too many parts
	local glbBoxes = serde.decode("json", fs.readFile(ROOT .. "tools/knives/knife_boxes.json"))[key]
	local lo, hi, cols = Vector3.one * math.huge, -Vector3.one * math.huge, {}
	for _, n in glbBoxes do
		lo, hi = lo:Min(Vector3.new(n.lo[1], n.lo[2], n.lo[3])), hi:Max(Vector3.new(n.hi[1], n.hi[2], n.hi[3]))
		cols[n.col] = true
	end
	local mlo, mhi, count, foreign = Vector3.one * math.huge, -Vector3.one * math.huge, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			count += 1
			-- its real corners (a turned block's 8, a wedge's 6: since Oct 20 the stand-ins are wedges turned about X)
			local h = d.Size / 2
			local corners = if d:IsA("WedgePart")
				then { { 1, -1, -1 }, { -1, -1, -1 }, { 1, -1, 1 }, { -1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 } }
				else { { 1, 1, 1 }, { 1, 1, -1 }, { 1, -1, 1 }, { 1, -1, -1 }, { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, 1 }, { -1, -1, -1 } }
			for _, k in corners do
				local q = d.CFrame * Vector3.new(h.X * k[1], h.Y * k[2], h.Z * k[3])
				mlo, mhi = mlo:Min(q), mhi:Max(q)
			end
			if not cols[d.Color:ToHex():lower()] then foreign += 1 end
		end
	end
	check(string.format("%s: the stand-in fills his .glb's box (%.3f, %.3f studs off)", key, (mlo - lo).Magnitude, (mhi - hi).Magnitude),
		(mlo - lo).Magnitude < 0.06 and (mhi - hi).Magnitude < 0.06)
	check(key .. ": every stand-in part in one of his colours (" .. foreign .. " not)", foreign == 0)
	check(key .. ": " .. count .. " parts, at most 200", count <= 200 and count >= 20)
	check(key .. ": slash trail points", model:FindFirstChild("TrailBase", true) ~= nil and model:FindFirstChild("TrailTip", true) ~= nil)
	local handle = model:FindFirstChild("Handle", true)
	local loose = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle then
			local held = false
			for _, w in d:GetChildren() do if w:IsA("WeldConstraint") and w.Part0 == handle then held = true end end
			if not held then loose += 1 end
		end
	end
	check(key .. ": every part welded to the handle", loose == 0)
end

-- 2. the scaler
do
	local model = KnifeService.template(CoinShop.get("DragonsMaw"))
	local before = KnifeService.shapeOf(model)
	local tip0 = model:FindFirstChild("TrailTip", true)
	local tipBefore = tip0.Parent.CFrame * tip0.CFrame.Position
	local handle = model:FindFirstChild("Handle", true)
	local h0 = handle.CFrame
	KnifeService.scale(model, 2)
	local after = KnifeService.shapeOf(model)
	check(string.format("scale x2: twice as long (%.2f -> %.2f)", before.length, after.length), math.abs(after.length - 2 * before.length) < 0.01)
	check("scale x2: the grip stays where it was", (handle.CFrame.Position - h0.Position).Magnitude < 1e-4)
	local tipAfter = tip0.Parent.CFrame * tip0.CFrame.Position
	check("scale x2: the trail tip moves out with the blade", ((tipAfter - h0.Position) - (tipBefore - h0.Position) * 2).Magnitude < 1e-3)
	check("scale x2: remembered (Scale attribute)", model:GetAttribute("Scale") == 2)
	local w = Instance.new("Weld")
	w.C0 = CFrame.new(0, 1, 0)
	w.Parent = handle
	KnifeService.scale(model, 1.5)
	check("scale: a weld's offset grows too", math.abs(w.C0.Position.Y - 1.5) < 1e-4)
end

-- 3. the stands' copy: big, with its element
local function lengthOf(model)
	return KnifeService.shapeOf(model).length
end
for _, key in PASS do
	local m = KnifeService.display(CoinShop.get(key))
	local L = lengthOf(m)
	check(key .. string.format(": the stand's knife is big (%.2f studs, target %.1f)", L, KnifeLook.STAND.Length), math.abs(L - KnifeLook.STAND.Length) < 0.25)
	local sh = KnifeService.shapeOf(m)
	local plain = KnifeService.template(CoinShop.get(key))
	local psh = KnifeService.shapeOf(plain)
	local k = sh.length / psh.length
	check(key .. string.format(": its own shape on a stand, only bigger (x%.2f long, x%.2f wide, x%.2f thick)", k, sh.width / psh.width, (sh.xMax - sh.xMin) / (psh.xMax - psh.xMin)),
		math.abs(sh.width / psh.width - k) < 0.02 and math.abs((sh.xMax - sh.xMin) / (psh.xMax - psh.xMin) - k) < 0.02)
	local shells = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "GlowShell" then shells += 1 end
	end
	check(key .. string.format(": nothing laid over the blade (%d glow shell parts)", shells), shells == 0)
	check(key .. ": the slash starts halfway up the blade", m:FindFirstChild("StandTrailBase", true) ~= nil)
	-- nothing on the knife (owner, Oct 20: "just make them be normal"): no particles, sparkles or lights at all
	local extras = 0
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Sparkles") or d:IsA("Fire") or d:IsA("Smoke") then extras += 1 end
	end
	check(key .. string.format(": plain on the stand, nothing scattered round it (%d particle emitters or lights)", extras), extras == 0)
end
do -- one of the owner's own models (he'll import the pass ones the same way): scaled to the same length
	local skin = CoinShop.get("VoidFang")
	local m = KnifeService.display(skin)
	check(string.format("his own model on a stand: big too (%.2f studs)", lengthOf(m)), math.abs(lengthOf(m) - KnifeLook.STAND.Length) < 0.3)
	check("his own model on a stand: no element (only the pass knives have one)", m:GetAttribute("Element") == nil)
end
do -- the hand: the same knife at its real size, half the element
	local c = Instance.new("Model")
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.Size = Vector3.new(1, 0.3, 1)
	hand.Parent = c
	KnifeService.give(c, CoinShop.get("DragonsMaw"))
	local held = c:FindFirstChild("HuzzKnife")
	local rate = 0
	for _, d in held:GetDescendants() do if d:IsA("ParticleEmitter") and d.Name ~= "KnifeBurst" then rate += d.Rate end end
	check(string.format("in hand: its real size (%.2f studs), not the stand's", lengthOf(held)), lengthOf(held) < 3.6)
	check(string.format("in hand: no particles (%.1f a second)", rate), rate == 0 and held:FindFirstChildWhichIsA("Light", true) == nil)
	check("in hand: the slash arc colour is set (Epic and up)", typeof(held:GetAttribute("SlashColor")) == "Color3")
	local trail = held:FindFirstChild("SlashTrail", true)
	check("in hand: the trail in the element's colours, a little longer", trail and math.abs(trail.Lifetime - KnifeLook.TRAIL.ElementLifetime) < 1e-4)
end

-- 4. pictures: every element texture has a stand-in until uploads
for key, el in KnifeLook.ELEMENTS do
	for _, spec in el.emit do
		check(key .. ": " .. spec.texture .. " has a stand-in picture", FxTextureReal.FALLBACK[spec.texture] ~= nil)
	end
end

-- 5. the slash arc
do
	local A = KnifeLook.ARC
	check("arc: hidden before it starts and after its life", KnifeLook.arcFade(-0.01) == 1 and KnifeLook.arcFade(A.Life + 0.01) == 1)
	local most = 1
	for i = 0, 100 do most = math.min(most, KnifeLook.arcFade(A.Life * i / 100)) end
	check(string.format("arc: never solid (at most %.2f see-through)", most), most >= 0.14)
	check("arc: gone in a fifth of a second (one per stab, no flashing)", A.Life <= 0.25)
end

print(`KnifeShapes: {passed} ok, {failed} failed`)
if failed > 0 then error("KnifeShapes spec failed") end
