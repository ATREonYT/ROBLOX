-- Checks the round HUD's feel rules (docs/feel-study.md gaps 1, 2, 10, 11; Gameplay/RoundHud) through the real
-- client code: news goes to the message line (never the middle), the message line is Huss Valley's (no panel,
-- 40% wide, fitted text, coloured words behind Theme.MessageColour), big words sit 27% from the top, the top is text
-- only, 3-2-1 follows the server clock, the prize card hides while running, and the Today's Girl window sits at the
-- right edge. Run by check.sh; prints "round hud: N ok, 0 failed".
local Players = game:GetService("Players")
local ok, failed = 0, 0
local function check(name, cond)
	if cond then ok += 1 else failed += 1; print("FAIL " .. name) end
end

local player = Instance.new("Player"); player.Name = "Tester"; player.UserId = 1; player.Parent = Players
Players.LocalPlayer = player
local pg = Instance.new("PlayerGui"); pg.Parent = player
__copyStarterGui(player)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", player)
task.wait(0.2)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)

local Client = game.StarterPlayer.StarterPlayerScripts.HuzzClient
local Theme = require(Client.UI.Theme)
local round = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Round")
round:SetAttribute("Stage", "Running")
round:SetAttribute("Round", 1)
round:SetAttribute("Streak", 0)
round:SetAttribute("Crossings", 3)
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 30)
round:SetAttribute("GirlName", "Sakura Hoshino")
round:SetAttribute("GirlRarity", "Epic")
player:SetAttribute("HuzzRole", "Runner")
player:SetAttribute("HuzzStatus", "Active")
local Hud = require(Client.Gameplay.RoundHud)
Hud.start()
Hud.refresh()
local hud = pg:WaitForChild("HuzzRoundHud")
local root = hud.Root

-- the message line: no panel, 40% of the 1280 layout wide, fitted text, a thick dark outline
local message = root:FindFirstChild("Message")
check("message line exists", message ~= nil and message:IsA("TextLabel"))
check("message line: no panel behind it", message.BackgroundTransparency == 1 and #message:GetChildren() <= 2)
check("message line: 40% of the screen wide", message.Size.X.Offset == 512)
check("message line: words fit the box (TextScaled, 14 to 27)", message.TextScaled == true and message:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize == 27)
check("message line: dark outline 3 px", message:FindFirstChild("Outline").Thickness >= 3)

local GREEN = Color3.fromRGB(110, 236, 140)
local function near(a: Color3, b: Color3) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02 end
__fireOn(round, "OnClientEvent", "Announce", { text = "Messi is safe", color = GREEN })
Hud.refresh()
check("news shows on the message line", message.Visible and message.Text == "Messi is safe")
check("MessageColour on: the words take the news colour", Theme.MessageColour ~= true or near(message.TextColor3, GREEN))
check("short news is big (27)", message.TextSize == 27)
__fireOn(round, "OnClientEvent", "Announce", { text = "Get everyone across 3 rounds in a row", color = Color3.new(1, 1, 1) })
Hud.refresh()
check("long news fits the 40% box (smaller)", message.TextSize < 27 and message.TextSize >= 14)
-- a near-black rarity colour (Secret) is lifted so it reads on the dark outline
__fireOn(round, "OnClientEvent", "Announce", { text = "Marin is up for grabs!", color = Color3.fromRGB(20, 20, 30) })
local c = message.TextColor3
check("a dark news colour is lifted", Theme.MessageColour ~= true or (c.R * 0.3 + c.G * 0.59 + c.B * 0.11) > 0.3)
local saved = Theme.MessageColour
Theme.MessageColour = false
__fireOn(round, "OnClientEvent", "Announce", { text = "Messi is safe", color = GREEN })
check("MessageColour off: always white", near(message.TextColor3, Color3.new(1, 1, 1)))
Theme.MessageColour = saved

-- news never prints in the middle (the old "big" flag is ignored), big words sit 27% from the top
local banner, small = root:FindFirstChild("Banner"), root:FindFirstChild("Small")
__fireOn(round, "OnClientEvent", "Announce", { text = "Map: Halloween", color = Color3.new(1, 1, 1), big = true })
task.wait(0.05)
check("news with the old big flag stays off the middle", banner.TextTransparency == 1 and small.TextTransparency == 1)
check("big words 27% from the top (194 of 720)", banner.Position.Y.Offset == 194 and root:FindFirstChild("Count").Position.Y.Offset == 194)
__fireOn(round, "OnClientEvent", "Safe", {})
check("SAFE! is a centre word", banner.Text == "SAFE!" and banner.TextTransparency == 0)
-- a new big word while the last one fades: the old fade must not eat the new word (it did: tweens fought)
task.wait(1.5)
__stepTweens(0.1)
__fireOn(round, "OnClientEvent", "Caught", { runner = 1, final = false })
__stepTweens(0.3)
check("a new big word survives the last one's fade", banner.Text == "YOU'RE DOWN" and banner.TextTransparency == 0)

-- the top is text only (no panels), HV's 9% of the screen tall without the help line, the round line in Roblox's top bar row
round:SetAttribute("Stage", "Running") -- (the harness's own server loop moves on while we wait: set it again)
round:SetAttribute("Round", 1)
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 30)
player:SetAttribute("HuzzRole", "Runner")
player:SetAttribute("HuzzStatus", "Active")
player:SetAttribute("HuzzHero", nil) -- (the harness's server may have picked us as the Hero meanwhile: "Hero" line)
player:SetAttribute("HuzzOut", nil)
round:SetAttribute("HolderId", 0)
Hud.refresh()
local top = root:FindFirstChild("Top")local panels = 0
for _, d in top:GetDescendants() do
	if d:IsA("Frame") and d.BackgroundTransparency < 1 then panels += 1 end
end
check("top of screen: text only, no panels", panels == 0)
check("top lines: round, role and time", string.find(top.Round.Text, "ROUND 1") ~= nil and string.find(top.Role.Text, "Runner") ~= nil and string.find(top.Role.Text, "%d:%d%d") ~= nil) -- (any clock: the harness's server time drifts from the wall clock)
check("top lines end by 9% of the screen (65 of 720, role line)", top.Role.Position.Y.Offset + top.Role.Size.Y.Offset <= 65)
check("HUD ignores the top bar inset; round line in the top bar row", hud.IgnoreGuiInset == true and top.Round.Position.Y.Offset + top.Round.Size.Y.Offset / 2 <= 16)
check("role line text 14", top.Role.TextSize == 14)
__fireOn(round, "Attr_Stage")
check("prize card hidden while running", root.Prize.Visible == false)
round:SetAttribute("GirlName", "Sakura Hoshino") -- (the harness's own server loop may have moved on: set it again)
round:SetAttribute("Stage", "Lineup")
__fireOn(round, "Attr_Stage") -- (the harness doesn't fire attribute signals by itself)
check("prize card back between runs", root.Prize.Visible == true)

-- 3-2-1 follows the server clock: just in = popped big and see-through, settled = full size and solid
local count = root:FindFirstChild("Count")
round:SetAttribute("Stage", "Countdown")
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 2.6)
Hud.refresh()
check("countdown: 3 shows settled", count.Text == "3" and count.TextTransparency == 0 and math.abs(count.Pop.Scale - 1) < 0.001)
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 1.98)
Hud.refresh()
check("countdown: 2 pops in (bigger, fading in)", count.Text == "2" and count.Pop.Scale > 1.1 and count.TextTransparency > 0)
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 1.1)
Hud.refresh()
check("countdown: 2 shrinks and fades before 1", count.Text == "2" and count.Pop.Scale < 1 and count.TextTransparency > 0.3)
round:SetAttribute("Stage", "Running")
round:SetAttribute("EndsAt", workspace:GetServerTimeNow() + 30)
Hud.refresh()
check("GO! after the count, bigger and green", count.Text == "GO!" and count.TextSize > 104 and count.TextColor3.G > count.TextColor3.R)

-- whole pixels everywhere (Roblox stores whole offsets)
local half = 0
for _, d in root:GetDescendants() do
	if d:IsA("GuiObject") then
		for _, v in { d.Position.X.Offset, d.Position.Y.Offset, d.Size.X.Offset, d.Size.Y.Offset } do
			if v ~= math.floor(v) then half += 1 end
		end
	end
end
check("round HUD: whole-pixel offsets", half == 0)

-- the Today's Girl window: at the right edge, not the middle
local roll = player.PlayerGui.HuzzUI:FindFirstChild("GirlRoll", true)
check("Today's Girl window at the right edge", roll ~= nil and roll.AnchorPoint.X == 1 and roll.Position.X.Scale == 1)
-- and below the settings button (when that sits on the screen rather than in Roblox's top bar row)
local gearRow = player.PlayerGui.HuzzUI:FindFirstChild("TopRight", true)
local gearScale = gearRow and gearRow:FindFirstChildOfClass("UIScale")
local gearBottom = if gearRow and gearRow.Position.Y.Offset >= 0 then gearRow.Position.Y.Offset + 44 * (if gearScale then gearScale.Scale else 1) else 0
check("Today's Girl window clears the settings button", roll ~= nil and roll.Position.Y.Offset >= gearBottom)

print(string.format("round hud: %d ok, %d failed", ok, failed))
return nil
