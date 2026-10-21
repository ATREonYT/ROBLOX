-- Check: the lobby leaderboards and avatar stands run end to end offline (HuzzServer/LeaderboardService,
-- Gameplay/Leaderboards, Gameplay/AvatarStands). With no boards in the place, five are made round the lobby floor,
-- tagged, filled with this server's players (Studio: no DataStores), drawn on this screen in one unlit slab colour
-- (studs, web, Halloween pumpkin and candle) and turned towards you in real time (never past TurnMax, home when you're
-- behind it, still for small wobbles). His plain grey block beside a spin wheel (named "Part", as in his own Rojo
-- place where nothing renames it) is found and tagged by the server, gets your copy holding its pass's exclusive
-- knife, its sign, and a button that never opens a purchase for a pass that isn't ready ("coming soon").
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_lobby_boards.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- a lobby floor like the owner's (Maps > Spawn > SpawnBaseplate, 100 x 13 x 100, top at 19.6) and one of his 4 x 8 x 4 blocks
local floor = Instance.new("Part")
floor.Name = "SpawnBaseplate"
floor.Anchored = true
floor.Size = Vector3.new(100, 13, 100)
floor.CFrame = CFrame.new(-227, 13.1, -706)
floor.Parent = workspace
local block = Instance.new("Part")
block.Name = "Part" -- (his name for it: only our place build used to rename it, so his own game had no stands)
block.Anchored = true
block.Size = Vector3.new(4, 7.5, 4.5)
block.CFrame = CFrame.new(-269, 23.35, -726)
block.Parent = workspace
local wheel = Instance.new("Model") -- his big spin wheel beside it (14 studs tall)
wheel.Name = "SpinWheel"
for _, y in { 20, 34 } do
	local w = Instance.new("Part"); w.Anchored = true; w.Size = Vector3.new(2, 2, 2); w.CFrame = CFrame.new(-269, y, -694); w.Parent = wheel
end
wheel.Parent = workspace

-- (Lune has no HttpService JSON: the same thing through serde)
__roblox.implementMethod("HttpService", "JSONEncode", function(_, v) return __serde.encode("json", v) end)
__roblox.implementMethod("HttpService", "JSONDecode", function(_, s) return __serde.decode("json", s) end)
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)

-- boards made round the floor
local holder = workspace:FindFirstChild("HuzzLeaderboards")
check("default boards made", holder ~= nil)
local boards = holder and holder:GetChildren() or {}
check("five boards", #boards == 5)
local stats = {}
for _, b in boards do
	stats[b:GetAttribute("Stat") or "?"] = b
	check(b.Name .. " tagged", b:HasTag("HuzzLeaderboard"))
	local board = b:FindFirstChild("Board")
	check("board part", board ~= nil and board:IsA("BasePart"))
	if board then
		local p = board.CFrame.Position
		check("on the floor (x)", math.abs(p.X - -227) + 7 <= 50)
		check("on the floor (z)", math.abs(p.Z - -706) + 1 <= 50)
		check("stands on the floor top", math.abs((p.Y - board.Size.Y / 2) - (19.6 + 1.2)) < 0.05)
		check("saved face", board:FindFirstChild("LeaderboardFace") ~= nil)
		check("no collisions on the slab", board.CanCollide == false)
	end
end
for _, s in { "Level", "Wins", "Catches", "Rescues", "Girls" } do check("board " .. s, stats[s] ~= nil) end

-- the character, then the screens
local function character()
	local c = Instance.new("Model"); c.Name = "Tester"
	local hum = Instance.new("Humanoid"); hum.Parent = c
	local r = Instance.new("Part"); r.Name = "HumanoidRootPart"; r.Size = Vector3.new(2, 2, 1); r.CFrame = CFrame.new(-227, 23, -690); r.Parent = c
	local h = Instance.new("Part"); h.Name = "Head"; h.Size = Vector3.new(2, 1, 1); h.CFrame = CFrame.new(-227, 25, -690); h.Parent = c
	local hand = Instance.new("Part"); hand.Name = "RightHand"; hand.Size = Vector3.new(0.6, 0.6, 0.6); hand.CFrame = CFrame.new(-225.5, 22, -690); hand.Parent = c
	-- (his avatar is on Roblox's newer joints: an AnimationConstraint between two attachments, as his Oct 20 one)
	local a0 = Instance.new("Attachment"); a0.Name = "NeckRigAttachment"; a0.CFrame = CFrame.new(0, 1, 0); a0.Parent = r
	local a1 = Instance.new("Attachment"); a1.Name = "NeckRigAttachment"; a1.CFrame = CFrame.new(0, -0.5, 0); a1.Parent = h
	local neck = Instance.new("AnimationConstraint"); neck.Name = "Neck"; neck.Attachment0 = a0; neck.Attachment1 = a1; neck.Parent = h
	c.Parent = workspace
	return c
end
me.Character = character()
local errors = {}
local Gameplay = game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay
for _, name in { "Leaderboards", "AvatarStands" } do
	local okS, err = pcall(function() require(Gameplay[name]).start() end)
	check(name .. " starts: " .. tostring(err), okS)
end
task.wait(0.3)

-- server data: this server's player on every board
local data = RS:FindFirstChild("HuzzLeaderboards")
check("data folder", data ~= nil)
local json = data and data:GetAttribute("Level")
check("level board data", type(json) == "string" and string.find(json, "Tester") ~= nil)
check("wins board data", data and type(data:GetAttribute("Wins")) == "string")

-- drawn on this screen
local guis = {}
for _, g in me.PlayerGui:GetChildren() do
	if string.sub(g.Name, 1, 12) == "Leaderboard_" then table.insert(guis, g) end
end
check("five faces in PlayerGui", #guis == 5)
local levelGui = me.PlayerGui:FindFirstChild("Leaderboard_Level")
check("adorned to its board", levelGui and levelGui.Adornee ~= nil)
local row1 = levelGui and levelGui.Canvas.List:FindFirstChild("Row1")
check("row 1 filled: " .. tostring(row1 and row1.PlayerName.Text), row1 and row1.PlayerName.Text == "#1 Tester")
check("row 1 value", row1 and row1.Value.Text == "LEVEL 1")
check("headshot", row1 and string.find(row1.Avatar.Image, "AvatarHeadShot&id=77", 1, true) ~= nil)
check("12 bands shown", levelGui and levelGui.Canvas.List:FindFirstChild("Row12") ~= nil)
check("saved face switched off", levelGui and levelGui.Adornee:FindFirstChild("LeaderboardFace").Enabled == false)
local winsRow = me.PlayerGui.Leaderboard_Wins.Canvas.List.Row1
check("wins trophy", winsRow:FindFirstChild("Trophy") ~= nil and winsRow.Trophy.Visible)
check("wins number", winsRow.Value.Text == "0")
check("title", me.PlayerGui.Leaderboard_Catches.Canvas.Title.Text == "MOST CATCHES")
check("subtitle", me.PlayerGui.Leaderboard_Catches.Canvas.Subtitle.Text == "GLOBAL · ALL TIME · TOP 50")
-- one slab colour: the face paints its own unlit backdrop (the header was the lit, see-through part before: purple)
local canvas = levelGui.Canvas
check("face backdrop, opaque, under everything", canvas:FindFirstChild("Backdrop") ~= nil and canvas.Backdrop.BackgroundTransparency == 0)
check("studs on the face", canvas.Backdrop:FindFirstChild("Studs") ~= nil)
check("a faint web in the corner", canvas.Backdrop:FindFirstChild("Web") ~= nil)
check("slab not see-through", levelGui.Adornee.Transparency == 0)
local deco = levelGui.Adornee:FindFirstChild("Halloween")
check("pumpkin and candle on the slab", deco ~= nil and deco:FindFirstChild("Pumpkin") ~= nil and deco:FindFirstChild("Flame") ~= nil)

-- turning towards you in real time (owner: "make it follow me in real time, not adjust after i move")
local LB = require(RS.Shared.Config.Leaderboards)
local board = levelGui.Adornee
local home = board.CFrame
local rootPart = me.Character.HumanoidRootPart
local function frames(n) for _ = 1, n do __fireOn(RunService, "RenderStepped", 1 / 30) end end
local function offHome() return math.deg(math.acos(math.clamp(board.CFrame.LookVector:Dot(home.LookVector), -1, 1))) end
-- stand `deg` off its front, `dist` studs away
local function standAt(deg, dist)
	local a = math.rad(deg)
	local side = home.RightVector * math.sin(a) + home.LookVector * math.cos(a)
	local p = home.Position + side * dist
	rootPart.CFrame = CFrame.new(p.X, 23, p.Z)
end
standAt(0, 20)
frames(200)
home = board.CFrame -- (settled facing straight out)
standAt(30, 20)
frames(1)
local first = offHome()
check(string.format("first frame: already turning towards you (%.1f deg)", first), first > 5)
frames(15)
check(string.format("faces you within half a second (30 deg: %.1f)", offHome()), math.abs(offHome() - 30) < 1)
local after = board.CFrame
check("stays upright", math.abs(after.LookVector.Y) < 1e-6 and math.abs(after.UpVector.Y - 1) < 1e-6)
check("turns about its own centre", (after.Position - home.Position).Magnitude < 1e-6)
-- level with its edge: it stops at the limit, never edge-on
standAt(88, 20)
local most = 0
for _ = 1, 200 do frames(1); most = math.max(most, offHome()) end
check(string.format("never past %d degrees (%.1f)", LB.TurnMax, most), most <= LB.TurnMax + 0.5)
-- behind it: it goes home instead of spinning round
standAt(180, 20)
frames(60)
check(string.format("straight behind it: back home (%.1f deg)", offHome()), offHome() < 1)
-- respawning (no body for a moment): it holds where it is, no swing home and back
standAt(40, 20)
frames(60)
local held = offHome()
rootPart.Name = "Gone" -- (the harness can't clear Player.Character: a body with no root reads the same to the boards)
frames(30)
check(string.format("no body (respawning): it holds (%.1f -> %.1f deg)", held, offHome()), math.abs(offHome() - held) < 0.5)
rootPart.Name = "HumanoidRootPart"
standAt(0, 20)
frames(60)

-- the avatar stand: his grey block found by the server, tagged, with a pass and that pass's knife
check("his grey block is tagged as a stand", block:HasTag("HuzzAvatarStand"))
check("its pass: the first knife Game Pass, Hunter Knife (owner Oct 18: one pass per knife)", block:GetAttribute("Pass") == "HunterKnifePass")
check("its knife: the one that pass gives (" .. tostring(block:GetAttribute("Knife")) .. ")", block:GetAttribute("Knife") == "CrimsonRequiem")
local knives = RS:FindFirstChild("HuzzStandKnives")
check("the pass knives are ready for the screens (5)", knives ~= nil and #knives:GetChildren() == 5)
local copies = workspace:FindFirstChild("HuzzStandAvatars")
local copy = copies and copies:FindFirstChild("StandAvatar")
check("your copy stands there", copy ~= nil)
if copy then
	local root = copy.HumanoidRootPart
	check("copy anchored by its root", root.Anchored)
	check("copy where the block was", math.abs(root.CFrame.Position.X - -269) < 0.01 and math.abs(root.CFrame.Position.Z - -726) < 0.01)
	check("feet on the floor (tall block turns into you)", root.CFrame.Position.Y > 19.6 and root.CFrame.Position.Y < 19.6 + 6)
	check("no name tag on the copy", copy:FindFirstChildWhichIsA("BillboardGui", true) == nil)
	local knife = copy:FindFirstChild("StandKnife")
	check("your copy holds the exclusive knife", knife ~= nil and knife:GetAttribute("Knife") == "CrimsonRequiem")
	local weld = knife and knife:FindFirstChild("StandKnifeGrip", true)
	check("welded to the right hand", weld ~= nil and weld.Part0 ~= nil and weld.Part0.Name == "RightHand")
	local anchored = false
	for _, d in (knife and knife:GetDescendants() or {}) do if d:IsA("BasePart") and d.Anchored then anchored = true end end
	check("the knife moves with the hand (nothing anchored)", knife ~= nil and not anchored)
	-- big (owner Oct 19: "right now its very small and you dont even notice it"): pommel to tip about 4.4 studs
	local handle = knife and knife:FindFirstChild("Handle", true)
	local lo, hi = math.huge, -math.huge
	for _, d in (knife and knife:GetDescendants() or {}) do
		if d:IsA("BasePart") and d ~= handle and not string.find(d.Name, "Tassel") then
			local y = handle.CFrame:PointToObjectSpace(d.CFrame.Position).Y
			lo, hi = math.min(lo, y - d.Size.Y / 2), math.max(hi, y + d.Size.Y / 2)
		end
	end
	check(string.format("the stand's knife is big (%.1f studs, was 1.9)", hi - lo), hi - lo > 4 and hi - lo < 5.2)
	-- its effects by tier (owner, Oct 20 07:43 "make them better for more high end ones", over 03:01's "just make
	-- them be normal" for the high-end knives; the stands are where kids see them): this exclusive knife has its
	-- themed effects, kid-safe: one light at most, its glint only on a fixed timer of 1.5 s or more (Rate 0, never two
	-- within 1 s), no other star on it, and no spark bursts
	local lights, stars, glintOk, bursts, rate = 0, 0, true, 0, 0
	for _, d in (knife and knife:GetDescendants() or {}) do
		if d:IsA("Light") then lights += 1 end
		if d:IsA("Sparkles") or d:IsA("Fire") or d:IsA("Smoke") then bursts += 1 end
		if d:IsA("ParticleEmitter") then
			if d.Name == "KnifeBurst" then bursts += 1 end
			if d.Name == "KnifeFx_glint" then
				glintOk = glintOk and d.Rate == 0 and (tonumber(knife:GetAttribute("GlintEvery")) or 0) >= 1.5
			elseif d.LockedToPart and string.find(d.Texture, "sparkles_main", 1, true) and d.Rate > 0 and d.Parent:IsA("Attachment") then
				stars += 1
			end
			rate += d.Rate
		end
	end
	check(string.format("its effects by tier (%s, %.1f particles a second), one light at most (%d)", tostring(knife and knife:GetAttribute("Fx")), rate, lights),
		knife ~= nil and knife:GetAttribute("Fx") ~= nil and rate > 0 and rate <= 16 and lights <= 1)
	check("kid-safe: the glint on a fixed timer of 1.5 s or more, no other star on the gem or tip", glintOk and stars == 0)
	check("no spark bursts on the stand's knife", bursts == 0 and (knife == nil or knife:GetAttribute("Burst") == nil))
	local blade = knife and knife:FindFirstChild("Blade", true)
	local glowing = 0
	for _, d in (knife and knife:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Transparency < 1 then glowing += 1 end
	end
	check("the stand-in is cut from his .glb (a blade and his glowing parts, " .. glowing .. ")", blade ~= nil and glowing >= 5)
	-- one rigid piece (owner, Oct 20 20:34: Moonlit's knife lay on the floor by its copy): his newer joints became Motor6Ds
	local motor = copy:FindFirstChild("Neck", true)
	check("the copy's joints are plain Motor6Ds (no AnimationConstraint left)", motor ~= nil and motor:IsA("Motor6D")
		and copy:FindFirstChildWhichIsA("AnimationConstraint", true) == nil)
	-- a knife that came off its hand is put back, with one [HuzzKnife] line
	if knife and handle then
		rootPart.Name = "HumanoidRootPart"
		rootPart.CFrame = CFrame.new(-262, 23, -720)
		local hand = copy:FindFirstChild("RightHand")
		check("the stand knife starts in the fist", hand ~= nil and (handle.CFrame.Position - hand.CFrame.Position).Magnitude < 3)
		handle.CFrame = handle.CFrame + Vector3.new(0, -9, 0)
		task.wait(1.1) -- (a just-mounted knife gets a second)
		frames(2)
		local again = copy:FindFirstChild("StandKnife")
		local h2 = again and again:FindFirstChild("Handle", true)
		local w2 = again and again:FindFirstChild("StandKnifeGrip", true)
		check("a stand knife that came off its hand is put back in it", again ~= nil and again ~= knife and h2 ~= nil and w2 ~= nil
			and w2.Part0 ~= nil and w2.Part0.Name == "RightHand")
		rootPart.Name = "Gone"
	end
end
check("block hidden on this screen", block.LocalTransparencyModifier == 1)
-- the aura (owner, Oct 19 evening: "without that green circle on the bottom, and add some vfx"): no disc, no solid
-- part under the feet; rising specks and twinkles in the knife's own colours (Hunter: red), a soft light on the body
check("no disc under the feet (the green circle is gone)", copies and copies:FindFirstChild("StandGlow") == nil)
local ring = copies and copies:FindFirstChild("StandAura")
local body = copies and copies:FindFirstChild("StandAuraBody")
check("the aura's holders are invisible", ring ~= nil and body ~= nil and ring.Transparency == 1 and body.Transparency == 1)
local motes = ring and ring:FindFirstChild("AuraMotes")
local stars = body and body:FindFirstChild("AuraTwinkles")
local red = motes and motes.Color.Keypoints[#motes.Color.Keypoints].Value
check("rising specks in the knife's colour (Hunter red)", red ~= nil and red.R > 0.9 and red.G < 0.35)
check("calm: under 10 aura particles a second", motes ~= nil and stars ~= nil and motes.Rate + stars.Rate <= 10)
local auraLight = copy and copy.HumanoidRootPart:FindFirstChild("StandAuraLight")
check("a soft light on the character", auraLight ~= nil and auraLight:FindFirstChildOfClass("PointLight") ~= nil)
local sign = me.PlayerGui:FindFirstChild("StandSign")
check("sign", sign ~= nil and sign.Plate.Title.Text == "HUNTER KNIFE")
check("the sign names the knife", sign ~= nil and sign.Plate.Subtitle.Text == "EXCLUSIVE KNIFE: CRIMSON REQUIEM")
check("tag", sign and sign.Tag.Text == "GAME PASS")
local button = me.PlayerGui:FindFirstChild("StandButton")
local text = button and button.View.Text or ""
-- (the Hunter Knife pass got its real ID, Oct 21: the button shows its price; with Id 0 it says soon and never prompts)
local Products = require(game:GetService("ReplicatedStorage").Shared.Config.Products)
local hunter = Products.get("HunterKnifePass")
local ready = hunter ~= nil and Products.status(hunter) == "Ready"
if ready then
	check("button shows the pass's price: " .. text, string.find(text, tostring(hunter.Price), 1, true) ~= nil)
else
	check("button says soon (the pass has no ID yet): " .. text, string.find(text, "SOON", 1, true) ~= nil)
end
for _, w in { "LIMITED", "ENDS" } do
	check("no " .. w, not string.find(text .. (sign and sign.Tag.Text or ""), w, 1, true))
end
_G.__prompts = {}
if button then __fireOn(button.View, "Activated") end
task.wait(0.05)
check("tapping opens Roblox's prompt only for a pass with its ID", #_G.__prompts == (if ready then 1 else 0))

print(string.format("lobby boards: %d ok, %d failed", ok, fails))
return nil
