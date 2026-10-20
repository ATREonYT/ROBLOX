-- Smoke test: every picture shows even when the screen's picture memory is small (owner, Oct 20 14:07: "please fix
-- all of the placeholders for knifes, coins": in Play the first pictures drew, then the rest of the knife cards and
-- two coin packs stayed stand-ins). UI/ImageLoader's drawing is swapped for a fake with a budget of 130 pictures
-- (all the screens together use more; Roblox's EditableImage memory: past it CreateEditableImage gives nothing). Checks: pictures draw only on screen;
-- every knife card in ITEMS and every coin pack in COINS draws after other screens used the memory; a failure is
-- tried again (never kept forever); a picture nobody sees is freed.
-- From tools/preview: lune run harness.luau ../../src - @smoke_picture_memory.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
-- own every knife (since Oct 20 20:34 KNIVES shows only the knives you own: they come from crates)
do
	local DataService = require(game.ServerScriptService.HuzzServer.DataService)
	local CoinShop = require(game.ReplicatedStorage.Shared.Config.CoinShop)
	DataService.update(me, function(d)
		for _, it in CoinShop.Items do if it.Slot == "Knife" then d.Cosmetics[it.Key] = true end end
	end)
end

local UI = game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI
local ImageLoader = require(UI.ImageLoader)
-- the fake: at most `budget` live pictures; past it, nothing (as Roblox's CreateEditableImage)
local budget, live, made, refuse = 136, 0, 0, false -- (136 since Oct 20 20:34: the one-page Shop also holds the ability cards' (all 11 his now), the dances' and the crates' pictures, and the harness has no layout, so its whole page counts as on screen)
local images = {} -- [name] = the last fake image made for it
ImageLoader.make = function(kind, name)
	if refuse or live >= budget then error("out of picture memory (EditableImage budget)") end
	live += 1
	made += 1
	local image = { gone = false }
	image.Destroy = function() live -= 1; image.gone = true end
	images[name] = image
	return image, nil
end
ImageLoader.RETRY = 0.2
ImageLoader.IDLE_FREE = 1000 -- (freed only to make room here)

__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.5)
local MM = require(UI.ModalManager)

local function settle(seconds)
	local t = os.clock()
	while os.clock() - t < seconds do task.wait() end
end
local function waitFor(fn, seconds) -- (until fn() is true, or the time is up: the harness's frames are slow and uneven)
	local t = os.clock()
	while not fn() and os.clock() - t < seconds do task.wait() end
end
local function labels(prefix)
	local list = {}
	for _, d in me.PlayerGui:GetDescendants() do
		if d:IsA("ImageLabel") then
			local art = d:GetAttribute("Art")
			if art and string.sub(art, 1, #prefix) == prefix and d.Image == "" and ImageLoader.onScreen(d) then table.insert(list, d) end
		end
	end
	return list
end

-- nothing hidden is drawn: the closed shop's knife cards hold no memory
local hidden, cards = 0, 0
for _, d in me.PlayerGui:GetDescendants() do
	local art = d:IsA("ImageLabel") and d:GetAttribute("Art")
	if art and string.sub(art, 1, 5) == "Knife" then
		cards += 1
		if ImageLoader.showing(d) then hidden += 1 end
	end
end
check(string.format("the closed shop's knife cards aren't drawn (%d of %d drawn)", hidden, cards), hidden == 0)

-- other screens first, so the memory is used up before the knives (as in his Play)
for _, name in { "Index", "Dances", "Progression" } do
	pcall(function() MM.open(name) end) -- (opening the next window hides this one at once; the harness's close tween
	settle(0.6)                             -- never ends, so MM.close would leave it "open" here)
end
MM.open("Shop", "Items")
local knives, shown = {}, 0
waitFor(function()
	knives, shown = labels("Knife"), 0
	for _, d in knives do if ImageLoader.showing(d) then shown += 1 end end
	return #knives > 0 and shown == #knives
end, 20)
check(string.format("ITEMS: every knife card on screen draws (%d of %d)", shown, #knives), #knives > 20 and shown == #knives)
check(string.format("never more than the budget (%d live of %d)", live, budget), live <= budget)
MM.open("Shop", "Coins")
local packs, packShown = {}, 0
waitFor(function()
	packs, packShown = labels("CoinPack"), 0
	for _, d in packs do if ImageLoader.showing(d) then packShown += 1 end end
	return #packs > 0 and packShown == #packs
end, 10)
check(string.format("COINS: every coin pack draws (%d of %d)", packShown, #packs), #packs >= 3 and packShown == #packs)
MM.close()

-- a failure is tried again: no memory at all for a moment, then some
refuse = true
local probe = Instance.new("ImageLabel")
local screen = Instance.new("ScreenGui")
screen.Parent = me.PlayerGui
probe.Parent = screen
-- (a picture no other label shows and nothing drew yet, so only this probe holds it)
local used = {}
for _, d in me.PlayerGui:GetDescendants() do
	if d:IsA("ImageLabel") and d:GetAttribute("Art") then used[d:GetAttribute("Art")] = true end
end
local spare = nil
for _, m in game.ReplicatedStorage.Shared.Images.Art:GetChildren() do
	if not used[m.Name] and images[m.Name] == nil and ImageLoader.glyph("Art", m.Name) then spare = m.Name break end
end
check("found a picture no screen uses (" .. tostring(spare) .. ")", spare ~= nil)
ImageLoader.apply(probe, "Art", spare, "")
waitFor(function() return probe:FindFirstChild("NoPicture") ~= nil end, 10)
local glyphed = probe:FindFirstChild("NoPicture") ~= nil
refuse = false
waitFor(function() return ImageLoader.showing(probe) end, 10)
check("a picture that failed is tried again and draws (no failure kept forever)", ImageLoader.showing(probe))
check("its stand-in went once it drew", probe:FindFirstChild("NoPicture") == nil)
check("while it can't draw it shows a stand-in", glyphed)

-- a picture whose labels are all gone is freed
local image = images[spare]
probe:Destroy()
__fireOn(probe, "Destroying")
waitFor(function() return image ~= nil and image.gone end, 10)
check("a picture nobody sees any more is freed", image ~= nil and image.gone)
print(string.format("picture memory smoke: %d ok, %d failed (%d drawn in all)", ok, fails, made))
