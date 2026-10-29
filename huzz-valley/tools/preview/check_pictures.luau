-- Check: every picture spot in the UI shows something (owner, Oct 19: "make the icons appear for everything in the
-- ui", "make the pictures in all of the ui appear"). For each ImageLabel that names a picture (Icon / Art attribute):
-- the packed picture exists under that exact name (Roblox names are case-sensitive), and where it can't be drawn
-- (here in Lune, as in a Studio without "Allow Mesh / Image APIs") it carries a stand-in glyph unless it's a decoration.
-- From tools/preview: lune run harness.luau ../../src - @check_pictures.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local ImageLoader = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ImageLoader)
local Images = RS.Shared.Images

-- open the screens whose contents are built on demand (each Shop tab, the collections)
for _, tab in { "Passes", "Cosmetics", "Items", "Crates", "Coins" } do
	MM.open("Shop", tab)
	task.wait(0.15)
end
MM.close()
for _, name in { "Index", "Dances", "Progression" } do
	pcall(function() MM.open(name) end)
	task.wait(0.15)
	MM.close()
end
task.wait(1) -- (the knife pictures are drawn one a frame)

local gui = me.PlayerGui
local spots, missing, glyphs, blank = 0, {}, 0, {}
for _, d in gui:GetDescendants() do
	if d:IsA("ImageLabel") or d:IsA("ImageButton") then
		local icon, art = d:GetAttribute("Icon"), d:GetAttribute("Art")
		local name = icon or art
		-- (the dance figures are blank on purpose, owner Oct 23 17:32: your avatar stands or dances there: Kit.art Placeholder)
		if name and name ~= "Avatar" and d.Image == "" and not d:GetAttribute("Placeholder") then
			spots += 1
			local kind = if icon then "Icons" else "Art"
			local folder = Images:FindFirstChild(kind)
			if not (folder and folder:FindFirstChild(name)) then
				missing[kind .. "/" .. name] = true
			elseif d:FindFirstChild("NoPicture") then
				glyphs += 1
			elseif ImageLoader.glyph(kind, name) ~= nil then
				blank[kind .. "/" .. name] = true
			end
		end
	end
end
local list = {}
for k in missing do table.insert(list, k) end
table.sort(list)
check(`every named picture is packed under that exact name ({#list} missing: {table.concat(list, ", ")})`, #list == 0)
local blanks = {}
for k in blank do table.insert(blanks, k) end
table.sort(blanks)
check(`every picture that can't be drawn shows a stand-in ({#blanks} blank: {table.concat(blanks, ", ")})`, #blanks == 0)
check(`stand-ins were made ({glyphs} of {spots} spots)`, glyphs > 50)
-- every packed icon has a glyph, and every packed picture has one unless it's a decoration
local noGlyph = {}
for _, kind in { "Icons", "Art" } do
	for _, m in Images[kind]:GetChildren() do
		if ImageLoader.glyph(kind, m.Name) == nil and not ({ GroupBackdrop = 1, LightRays = 1, SpinWedge = 1, DanceFxCore = 1, DanceFxGlow = 1, StudPattern = 1, StudTile = 1, BoardStud = 1, BoardWeb = 1 })[m.Name] then
			table.insert(noGlyph, kind .. "/" .. m.Name)
		end
	end
end
check(`every packed picture has a stand-in glyph ({#noGlyph} without: {table.concat(noGlyph, ", ")})`, #noGlyph == 0)
-- a picture that gets drawn (or uploaded) loses its stand-in
local probe = Instance.new("ImageLabel")
ImageLoader.standIn(probe, "Icons", "CurrencyCoin")
check("a stand-in can be put on", probe:FindFirstChild("NoPicture") ~= nil)
ImageLoader.apply(probe, "Icons", "CurrencyCoin", "rbxassetid://1")
check("an uploaded picture takes the stand-in away", probe:FindFirstChild("NoPicture") == nil and probe.Image == "rbxassetid://1")
print(string.format("pictures: %d ok, %d failed", ok, fails))
