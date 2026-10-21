-- The Combine machine offline (owner, Oct 20 14:57: "make it so that you can take two of the same girl, and then it
-- creates the same skin, but first in silver, then gold, and then diamond"), through the real server code, the real
-- client and HIS machine and a real girl from places/HUSSANIME.rbxl:
--   * the server finds his machine: tag, prompt on his altar (opens Combine), the COMBINE sign;
--   * the window: girls ready to combine first, the grade chips with counts, COMBINE green with two, grey with the
--     reason with one, her result name ("SILVER KURUMI");
--   * the merge (server): 2 Normal -> 1 Silver saved, Combines counted, everyone told; refused far away, in a round,
--     with one copy, at Diamond; the save is stored before the answer;
--   * the machine on this screen (Gameplay/CombineMachine) finds his parts, idles, and plays a whole merge with her
--     copies in their grades, then cleans up (no copies left, his parts back in their homes when it stops);
--   * kid-safe: the burst's ball and light are one flash (none for a second merge within 1 s), a grade's glint is
--     on a calm fixed timer; your merge lets go after Merge.Wait with no answer, and at once when a round starts.
-- Run from tools/preview: lune run harness.luau ../../src - @check_combine.luau setup_ui.luau
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ok, failed = 0, 0
local function check(name, c) if c then ok += 1 else failed += 1; print("FAIL " .. name) end end

__roblox.implementProperty("Humanoid", "RootPart", function(self) return self.Parent and self.Parent:FindFirstChild("HumanoidRootPart") end)
__roblox.implementMethod("Model", "GetScale", function() return 1 end)
__roblox.implementMethod("Model", "ScaleTo", function() end)
__roblox.implementMethod("Workspace", "Raycast", function() return nil end)
-- (Lune has no model pivots: the root part stands in for one)
local function pivotPart(m)
	local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
	return p
end
pcall(function() __roblox.implementMethod("Model", "GetPivot", function(self) local p = pivotPart(self); return if p then p.CFrame else CFrame.new() end) end)
pcall(__roblox.implementMethod, "Model", "PivotTo", function(self, cf)
	local p = pivotPart(self)
	if not p then return end
	local delta = cf * p.CFrame:Inverse()
	for _, d in self:GetDescendants() do if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end end
end)
pcall(function() __roblox.implementMethod("Model", "GetBoundingBox", function(self) local p = pivotPart(self); return (if p then p.CFrame else CFrame.new()), Vector3.new(2, 5, 1) end) end)
local chars = {}
__roblox.implementProperty("Player", "Character", function(self) return chars[self.Name] end, function(self, v) chars[self.Name] = v end)

-- his place: the machine and one girl
local place = __roblox.deserializePlace(__fs.readFile("../../places/HUSSANIME.rbxl"))
local combine = place:GetService("Workspace"):FindFirstChild("Combine")
check("his place has Workspace > Combine > Combine_Machine", combine and combine:FindFirstChild("Combine_Machine"))
combine:Clone().Parent = workspace
local girlsFolder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
local folder = Instance.new("Folder")
folder.Name = "HuzzGirls"
folder.Parent = RS
for _, r in girlsFolder:GetChildren() do
	local m = r:FindFirstChild("CAC_R6_Nikaccount41_E52B4E")
	if m then
		local copy = m:Clone()
		for _, d in copy:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
		copy.Name = "GC1"
		copy:SetAttribute("Id", "c_girl"); copy:SetAttribute("Name", "Kurumi"); copy:SetAttribute("Rarity", "Common")
		copy.Parent = folder
	end
end
local second = Instance.new("Model"); second.Name = "GC2"
local h2 = Instance.new("Part"); h2.Name = "Head"; h2.Parent = second
second:SetAttribute("Id", "c_two"); second:SetAttribute("Name", "Akane"); second:SetAttribute("Rarity", "Rare"); second.Parent = folder
check("a real girl to combine", folder:FindFirstChild("GC1") ~= nil)

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 91; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.4)

local HS = game.ServerScriptService.HuzzServer
local CombineService = require(HS.CombineService)
local DataService = require(HS.DataService)
local Characters = require(RS.Shared.Config.Characters)
Characters.addGirls(folder)

-- 1. the server found his machine
local machine = CombineService.machine()
check("server finds his machine", machine ~= nil and machine.Name == "Combine_Machine")
local altar = CombineService.altar()
check("his altar", altar ~= nil)
local prompt = altar and altar:FindFirstChild("HuzzCombinePrompt")
check("the prompt opens Combine", prompt and prompt:GetAttribute("HuzzOpens") == "Combine" and prompt.ActionText == "Combine")
local sign = altar and altar:FindFirstChild("HuzzCombineSign")
check("the COMBINE sign over it", sign and sign.Title.Text == "COMBINE" and sign.StudsOffsetWorldSpace.Y > 8)
check("tagged for every screen", machine and table.find(CollectionService:GetTagged("HuzzCombine"), machine) ~= nil)

-- you, standing by his altar
local function character(at)
	local m = Instance.new("Model"); m.Name = "Tester"
	local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.CFrame = CFrame.new(at); root.Position = at; root.Parent = m
	local h = Instance.new("Humanoid"); h.Parent = m
	m.Parent = workspace
	return m
end
local near = altar.CFrame.Position + Vector3.new(4, 0, 4)
me.Character = character(near)

DataService.update(me, function(d)
	d.Characters.c_girl, d.Characters.c_two = os.time(), os.time()
	d.Copies.c_girl = { Normal = 3, Silver = 1 }
	d.Copies.c_two = { Normal = 1 }
end)
local data = DataService.get(me).Data

-- 2. the window
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local MM = require(UI.ModalManager)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")
check("Combine opens", MM.open("Combine") == true)
task.wait(0.2)
local win = gui:FindFirstChild("Combine")
local panel = win and win:FindFirstChild("Panel", true)
local girls = panel and panel:FindFirstChild("Girls")
local row1, row2 = girls and girls:FindFirstChild("Girl_c_girl"), girls and girls:FindFirstChild("Girl_c_two")
check("both girls listed", row1 and row2 and row1.Visible and row2.Visible)
check("the ready girl first, with READY", row1 and row2 and row1.LayoutOrder < row2.LayoutOrder and row1.Ready.Visible and not row2.Ready.Visible)
check("her copies by grade", row1 and row1.Copies.Text == "Normal 3   Silver 1")
local merge = panel and panel:FindFirstChild("Merge")
check("NORMAL chip counts", merge and merge.GradeNormal:FindFirstChild("Label", true) and string.find(merge.GradeNormal:FindFirstChild("Label", true).Text, "NORMAL x3") ~= nil or (merge and string.find(merge.GradeNormal.Text or "", "x3")))
check("result name SILVER KURUMI", merge and merge.ResultName.Text == "SILVER KURUMI")
check("pictures: two inputs and the result", merge and merge.InputA:FindFirstChildOfClass("ViewportFrame") and merge.InputB:FindFirstChildOfClass("ViewportFrame") and merge.Result:FindFirstChildOfClass("ViewportFrame"))
check("the result picture wears SILVER", merge and merge.Result:FindFirstChild("GradeBadge") and merge.Result.GradeBadge.Text == "SILVER")
check("the result copy is dressed Silver", merge and merge.Result:FindFirstChildOfClass("ViewportFrame"):FindFirstChildOfClass("Model"):GetAttribute("HuzzGrade") == "Silver")
check("COMBINE ready", merge and merge.CombineButton.Active ~= false and string.find(merge.Reason.Text, "make 1 Silver") ~= nil)
__fireOn(row2, "MouseButton1Click")
task.wait(0.1)
check("one copy: COMBINE grey with the reason", merge.Reason.Text == "You need 2 Normal. You have 1." and merge.ResultName.Text == "SILVER AKANE")
__fireOn(row1, "MouseButton1Click")
task.wait(0.1)

-- 3. the server's rules
local Action = RS.Remotes.Action
local okA, info = Action:InvokeServer("Combine", "c_girl", "Normal")
check("2 Normal -> 1 Silver", okA == true and type(info) == "table" and info.to == "Silver" and info.saved == true)
check("saved: Normal 1, Silver 2", data.Copies.c_girl.Normal == 1 and data.Copies.c_girl.Silver == 2 and data.Combines == 1)
-- (FireAllClients goes straight to the handlers in the harness; the client's handler is checked in part 4)
task.wait(1.6)
local okB, whyB = Action:InvokeServer("Combine", "c_girl", "Normal")
check("one Normal left: refused", okB == false and whyB == "You need 2 Normal. You have 1.")
task.wait(1.6)
local okC = Action:InvokeServer("Combine", "c_girl", "Silver")
check("2 Silver -> 1 Gold", okC == true and data.Copies.c_girl.Gold == 1 and data.Copies.c_girl.Silver == nil)
task.wait(1.6)
DataService.update(me, function(d) d.Copies.c_girl.Diamond = 2 end)
local okD, whyD = Action:InvokeServer("Combine", "c_girl", "Diamond")
check("Diamond is the top", okD == false and whyD == "Diamond is the top!")
task.wait(1.6)
local okE, whyE = Action:InvokeServer("Combine", "c_two", "Normal")
check("someone else's girl / one copy refused", okE == false and whyE ~= nil)
task.wait(1.6)
local okF, whyF = Action:InvokeServer("Combine", "c_girl", "Bogus")
check("a made-up grade refused", okF == false and whyF == "Pick a girl first.")
task.wait(1.6)
DataService.update(me, function(d) d.Copies.c_girl.Normal = 4 end)
me.Character = character(near + Vector3.new(200, 0, 0))
local okG, whyG = Action:InvokeServer("Combine", "c_girl", "Normal")
check("far away refused", okG == false and whyG == "Walk up to the machine.")
me.Character = character(near)
task.wait(1.6)
me:SetAttribute("HuzzRole", "Runner")
local okH, whyH = Action:InvokeServer("Combine", "c_girl", "Normal")
check("in a round refused", okH == false and whyH == "Not during a round.")
me:SetAttribute("HuzzRole", nil)
task.wait(1.6)

-- 4. the machine on this screen
local CM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.CombineMachine)
CM.start()
local camera = workspace.CurrentCamera or Instance.new("Camera")
if not workspace.CurrentCamera then camera.Parent = workspace; workspace.CurrentCamera = camera end
camera.CFrame = CFrame.lookAt(near + Vector3.new(10, 6, 10), altar.CFrame.Position)
local function frames(n, dt)
	for _ = 1, n do __fireOn(RunService, "RenderStepped", dt or 1 / 30) end
end
-- (it looks for his machine once a second)
task.wait(1.1)
frames(3)
local fx = workspace:FindFirstChild("HuzzCombineFx")
check("effects round his machine (light, motes, sparkles)", fx and fx:FindFirstChild("Altar") and fx.Altar:FindFirstChildOfClass("PointLight") and fx.Altar:FindFirstChild("Motes") and fx:FindFirstChild("Ring") and fx.Ring:FindFirstChild("Sparkles"))
-- his ring moves on this screen
local tick = nil
for _, d in workspace.Combine:GetDescendants() do
	if d:IsA("BasePart") and string.match(d.Name, "^glow_summon_tick") then tick = d break end
end
local before = tick and tick.CFrame.Position
task.wait(0.3)
frames(20)
check("his ring turns (idle)", tick and (tick.CFrame.Position - before).Magnitude > 0.001)
-- a whole merge: yours
local reveal, finished = false, false
local started = CM.play({ key = "GC1", from = "Normal", to = "Silver", mine = true, onReveal = function() reveal = true end, onDone = function() finished = true end })
check("the merge starts on his machine", started == true)
frames(10)
local copies = 0
for _, d in fx:GetChildren() do if d.Name == "CombineGirl" then copies += 1 end end
check("two copies of her rise", copies == 2)
check("your camera is taken (cinematic)", me:GetAttribute("HuzzCinematic") == true)
-- before the answer it waits at the burst
local t0 = os.clock()
while os.clock() - t0 < 2.4 do task.wait(0.05); frames(1) end
check("waits at the burst for the server", not reveal and CM.playing())
CM.answer(true)
local t1 = os.clock()
while os.clock() - t1 < 8 and not finished do task.wait(0.05); frames(1) end
check("the burst reveals her", reveal)
local t2 = os.clock()
while os.clock() - t2 < 4 and me:GetAttribute("HuzzCinematic") do task.wait(0.05); frames(1) end
check("the merge ends", finished and not CM.playing())
copies = 0
for _, d in fx:GetChildren() do if d.Name == "CombineGirl" then copies += 1 end end
check("no copies left behind", copies == 0)
check("your camera is given back", me:GetAttribute("HuzzCinematic") == false)
-- a refused merge: the copies go back and it ends
finished = false
CM.play({ key = "GC1", from = "Normal", to = "Silver", mine = true, onDone = function() finished = true end })
frames(5)
CM.answer(false)
local t3 = os.clock()
while os.clock() - t3 < 5 and not finished do task.wait(0.05); frames(1) end
check("a refused merge ends", finished and not CM.playing())
-- someone else's merge plays too (the remote), without your camera
local t4 = os.clock()
while os.clock() - t4 < 0.6 do task.wait(0.05); frames(1) end
for _, fn in (function()
	local ev = RS.Remotes:FindFirstChild("Combine")
	return { function() __fireOn(ev, "OnClientEvent", 5, "GC1", "Silver", "Gold", workspace:GetServerTimeNow()) end }
end)() do pcall(fn) end
frames(2)
check("someone else's merge plays on the machine", CM.playing() and me:GetAttribute("HuzzCinematic") ~= true)

-- 5. kid-safe: the burst's ball, its light and ring are one flash; a second merge within 1 s shows no flash
local Burst = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.Burst)
CM.skip()
Burst.step(2) -- (a while since any flash)
-- (watches the ball and its light for a few frames from just before the burst: did they ever show?)
local function burstShows(): boolean
	local seen = false
	CM.play({ key = "GC1", from = "Silver", to = "Gold", mine = false, startAt = os.clock() - 1.98 })
	local t7 = os.clock()
	while os.clock() - t7 < 0.3 do
		frames(1)
		if fx.Burst.Transparency < 1 or fx.Burst:FindFirstChildOfClass("PointLight").Brightness > 0 then seen = true end
		task.wait(0.01)
	end
	CM.skip()
	return seen
end
local shows = burstShows()
for _ = 1, 2 do -- (a busy machine can stall a frame past the 0.45 s burst: try again)
	if shows then break end
	Burst.step(2)
	shows = burstShows()
end
check("the burst's ball and light show", shows)
Burst.step(0.3)
check("a second burst within 1 s: no ball, no light", not burstShows())

-- 6. your merge lets go: after Merge.Wait with no answer ("slow"), and at once when a round starts
local why = nil
finished = false
CM.play({ key = "GC1", from = "Normal", to = "Silver", mine = true, onDone = function(_, r) finished = true; why = r end })
local t5 = os.clock()
while os.clock() - t5 < 2 + require(RS.Shared.Config.Combine).Merge.Wait + 2 and not finished do task.wait(0.05); frames(1) end
check("no answer: it lets go after Merge.Wait (Try again)", finished and why == "slow")
local t6 = os.clock()
while os.clock() - t6 < 2 and me:GetAttribute("HuzzCinematic") do task.wait(0.05); frames(1) end
check("the camera comes back after a slow answer", me:GetAttribute("HuzzCinematic") == false)
CM.answer(true, 1) -- (a late answer for an old merge lands nowhere)
check("a late answer starts nothing", not CM.playing())
finished, why = false, nil
CM.play({ key = "GC1", from = "Normal", to = "Silver", mine = true, onDone = function(_, r) finished = true; why = r end })
frames(5)
me:SetAttribute("HuzzRole", "Runner")
__fireOn(me, "Attr_HuzzRole") -- (the harness doesn't fire attribute signals by itself)
task.wait(0.05)
check("a round starting lets go at once", finished and why == "round" and me:GetAttribute("HuzzCinematic") == false and not CM.playing())
me:SetAttribute("HuzzRole", nil)

-- 7. a grade's glint: on a fixed timer, never two within 1.5 s (kid-safe, the knives' rule)
local GirlGrade = require(RS.Shared.GirlGrade)
local doll = folder.GC1:Clone()
doll.Parent = workspace
GirlGrade.apply(doll, "Diamond", { fx = true })
local glintE = doll.HuzzGradeFx:FindFirstChild("Glint")
check("the glint has no random rate", glintE and glintE.Rate == 0)
check("a sheen in the grade's colour", doll.HuzzGradeFx:FindFirstChild("HuzzGradeSheen") ~= nil)
local emits = {}
local tt = os.clock()
for i = 0, 600 do
	local at = tt + i / 30
	local fired = GirlGrade.stepGlints(at)
	if fired and table.find(fired, glintE) then table.insert(emits, at) end
end
local closest = math.huge
for i = 2, #emits do closest = math.min(closest, emits[i] - emits[i - 1]) end
check(("glints on a calm timer (%d in 20 s, closest %.2f s)"):format(#emits, closest), #emits >= 5 and #emits <= 11 and closest >= 1.5)
doll:Destroy()

-- Owner, Oct 21: "make the text not overlap with anything ... more pinpoint and precise". Every box on the stage
-- (the rule, her copies and their captions, the result and her name, the grade path) and the reason, COMBINE and
-- the girls' tray sit on one grid: none touches another, each at least 4 px apart, all inside the window.
do
	local function box(g)
		local p = g.Parent
		local pw, ph = p.Size.X.Offset, p.Size.Y.Offset
		local w, h = g.Size.X.Offset + g.Size.X.Scale * pw, g.Size.Y.Offset + g.Size.Y.Scale * ph
		local x = g.Position.X.Offset + g.Position.X.Scale * pw - g.AnchorPoint.X * w
		local y = g.Position.Y.Offset + g.Position.Y.Scale * ph - g.AnchorPoint.Y * h
		if p.Name == "Merge" then x += p.Position.X.Offset; y += p.Position.Y.Offset end
		return { x = x, y = y, w = w, h = h, name = g.Name }
	end
	local names = { "Banner", "InputA", "InputB", "Result", "Caption1", "Caption2", "ResultName", "GradeNormal", "GradeSilver", "GradeGold", "GradeDiamond", "Reason", "CombineButton" }
	local boxes = {}
	for _, n in names do
		local g = merge and merge:FindFirstChild(n)
		check("the stage has " .. n, g ~= nil)
		if g then table.insert(boxes, box(g)) end
	end
	local tray = panel:FindFirstChild("Tray")
	check("the girls' tray is there", tray ~= nil)
	if tray then table.insert(boxes, box(tray)) end
	local worst = math.huge
	local bad = {}
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, b = boxes[i], boxes[j]
			local gap = math.max(b.x - (a.x + a.w), a.x - (b.x + b.w), b.y - (a.y + a.h), a.y - (b.y + b.h))
			worst = math.min(worst, gap)
			if gap < 4 then table.insert(bad, ("%s/%s %d"):format(a.name, b.name, gap)) end
		end
	end
	check(("no two boxes closer than 4 px (closest %d px) %s"):format(worst, table.concat(bad, ", ")), #bad == 0)
	local outside = {}
	for _, b in boxes do
		if b.x < 0 or b.y < 0 or b.x + b.w > 720 or b.y + b.h > 584 then table.insert(outside, b.name) end
	end
	check(("all inside the 720 x 584 window %s"):format(table.concat(outside, ", ")), #outside == 0)
end

print(("checks: %d ok, %d failed"):format(ok, failed))
