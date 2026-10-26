-- The 3-2-1-GO after a CHICKEN pick (owner: "fix the countdown when someone chooses chicken, the numbers just dont
-- appear well"), through the real Gameplay/RoundHud with a virtual server clock and the round camera's timeline as
-- Gameplay/Cinematic runs it: in its shot through Picking and Chosen, then (Countdown) a 0.3 s swing back behind
-- you and the hand-over a frame later. RoundService adds a lead of CAMERA_BACK (0.6 s) to a Countdown that comes
-- straight after a camera shot. Sampled 30 times a second, it checks: nothing drawn while the camera is still in
-- its shot; 3, 2 and 1 in order, each fully on screen (settled, solid) for at least half a second; GO! on the
-- server's start; no big word or banner in the middle meanwhile; the CHICKEN word over heads stepped aside.
-- Globals set ahead of it (optional): __lead (default 0.6), __frames = { dir = "...", at = { seconds... } } to also
-- export frames (seconds after the Chosen shot ends) for docs/previews/chicken-countdown.jpg.
-- Prints "chicken countdown: N ok, M failed".
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end
local LEAD = __lead or 0.6

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
local pg = Instance.new("PlayerGui"); pg.Parent = player
__copyStarterGui(player)
-- a body with its name tag and the big CHICKEN word over its head (HuzzServer/NameTagService's shape)
local function body(p, word)
	local m = Instance.new("Model"); m.Name = p.Name
	local head = Instance.new("Part"); head.Name = "Head"; head.Parent = m
	local tag = Instance.new("BillboardGui"); tag.Name = "HuzzTag"; tag.Parent = head
	for _, n in { "Title", "PlayerName", "Sub" } do
		local l = Instance.new("TextLabel"); l.Name = n; l.Text = n; l.Parent = tag
	end
	local badge = Instance.new("TextLabel"); badge.Name = "Badge"; badge.Text = word; badge.Visible = word ~= ""; badge.Parent = tag
	m.Parent = workspace
	p.Character = m
	return badge
end
local myWord = body(player, "CHICKEN") -- (we were picked and chose CHICKEN)
local other = Instance.new("Player"); other.Name = "Messi"; other.UserId = 2; other.Parent = Players
local otherWord = body(other, "")

workspace:SetAttribute("UIPreviewScale", 1.25)
local clock = 1000
_G.__serverClock = function() return clock end
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)

local Client = game.StarterPlayer.StarterPlayerScripts.HuzzClient
local Config = require(game.ReplicatedStorage.Shared.Config.Round)
local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
local Hud = require(Client.Gameplay.RoundHud)
Hud.start()
local root = pg:WaitForChild("HuzzRoundHud").Root
local count, banner, small = root.Count, root.Banner, root.Small

-- the round as the server runs it (setStage: Stage + EndsAt), from the Chosen shot to the run
local function setStage(stage, seconds)
	round:SetAttribute("Stage", stage)
	round:SetAttribute("EndsAt", clock + seconds)
	__fireOn(round, "Attr_Stage")
end
round:SetAttribute("Round", 1); round:SetAttribute("Streak", 0); round:SetAttribute("Crossings", 3)
round:SetAttribute("GirlName", "Kurumi Tokisaki"); round:SetAttribute("GirlRarity", "Legendary")
round:SetAttribute("PickId", 1); round:SetAttribute("PickChoice", "Chicken")
player:SetAttribute("HuzzRole", "Runner"); player:SetAttribute("HuzzStatus", "Active")
__fireOn(round, "OnClientEvent", "Announce", { text = "Tester chose CHICKEN. Everyone runs!", color = Color3.new(1, 1, 1) })
setStage("Chosen", Config.Pick.ShowTime)
player:SetAttribute("HuzzCinematic", true) -- (Gameplay/Cinematic: the push-in on the picked runner)
otherWord.Text, otherWord.Visible = "", false

local DT = 1 / 30
local countStart = clock + Config.Pick.ShowTime -- the Chosen shot ends; RoundService starts the count
local countEnd = countStart + Config.CountdownTime + LEAD
local cameraBack = countStart + 0.3 + DT -- (Shot.HandBackTime, then HuzzCinematic goes off a frame later)
local frames = __frames
if frames then pcall(__fs.writeDir, frames.dir) end
local nextFrame = 1
local seen = {} -- per word: frames drawn, frames fully settled, first time
local order = {}
local overCamera, extraWords, wordShown, goLate = 0, 0, 0, nil
local t0 = clock
while clock < countEnd + 1.3 do
	clock += DT
	if clock >= countStart and round:GetAttribute("Stage") == "Chosen" then setStage("Countdown", Config.CountdownTime + LEAD) end
	if clock >= countEnd and round:GetAttribute("Stage") == "Countdown" then setStage("Running", Config.RoundTime) end
	if clock >= cameraBack then player:SetAttribute("HuzzCinematic", false) end
	Hud.refresh()
	if Hud.tagStep then Hud.tagStep() end
	local drawn = count.TextTransparency < 0.98
	if drawn then
		local w = count.Text
		local s = seen[w]
		if not s then
			s = { frames = 0, solid = 0, first = clock }
			seen[w] = s
			table.insert(order, w)
			if w == "GO!" then goLate = clock - countEnd end
		end
		s.frames += 1
		if count.TextTransparency < 0.02 and math.abs(count.Pop.Scale - 1) < 0.02 then s.solid += 1 end
		if player:GetAttribute("HuzzCinematic") == true then overCamera += 1 end
		if banner.TextTransparency < 0.98 or small.TextTransparency < 0.98 then extraWords += 1 end
		if myWord.Visible or otherWord.Visible then wordShown += 1 end
	end
	if frames and frames.at[nextFrame] and clock - countStart >= frames.at[nextFrame] - 1e-6 then
		__exportUI(pg.HuzzRoundHud, string.format("%s/frame_%04d.json", frames.dir, nextFrame))
		nextFrame += 1
	end
	if clock - t0 > 30 then break end
end

check("nothing drawn while the camera is still in its shot", overCamera == 0)
check("3, 2, 1, GO! in that order", table.concat(order, " ") == "3 2 1 GO!")
for _, w in { "3", "2", "1" } do
	local s = seen[w]
	check(w .. " fully on screen for half a second or more", s ~= nil and s.solid * DT >= 0.5)
	check(w .. " never shows before the camera is back", s ~= nil and s.first >= cameraBack - 1e-6)
end
check("3, 2 and 1 a second apart", seen["3"] and seen["2"] and seen["1"] and math.abs(seen["2"].first - seen["3"].first - 1) < 0.05 and math.abs(seen["1"].first - seen["2"].first - 1) < 0.05)
check("GO! on the server's start (within two frames)", goLate ~= nil and goLate >= -1e-6 and goLate <= 2 * DT + 1e-6)
check("no other big word in the middle while counting", extraWords == 0)
check("the CHICKEN word over heads steps aside for the count", wordShown == 0)
-- after GO! the word comes back
for _ = 1, 3 do clock += DT; Hud.refresh(); if Hud.tagStep then Hud.tagStep() end end
check("the CHICKEN word comes back after GO!", myWord.Visible == true)

print(string.format("chicken countdown: %d ok, %d failed", ok, failed))
return nil
