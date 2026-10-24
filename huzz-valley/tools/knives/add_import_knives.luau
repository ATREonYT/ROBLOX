-- Adds the owner's 5 Game Pass and 18 Halloween knives to assets/knives/HuzzKnives.rbxm, set up from his own imports.
-- (Owner, Oct 20 20:34: "render the knives fully. they arent rednered, is it something i didnt input?") He had
-- imported Gamepass_Knives.glb and Halloween_Knives.glb into his place (Workspace > "Gamepass knifes" and
-- "Halloween knives", 735 uploaded meshes), but his SetupKnives helper was never run on them, so ServerStorage >
-- HuzzKnives held only his 30 and those 23 fell back to the game's drawn stand-ins. This runs his helper offline on
-- those imports, exactly as his Command Bar run would (as colour_knives.luau does for his 30), checks every part of
-- every knife against tools/knives/knife_boxes.json (colour_knives' M.match and M.dressed) and, with --write, writes
-- all 53 into the file. His meshes are not touched; the 30 already in the file come through unchanged.
-- lune run huzz-valley/tools/knives/add_import_knives.luau [place.rbxl] [--write]
--   (repo root; the place defaults to his huzz-valley/places/HUSSANIME.rbxl; without --write it only reports)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local Vector3, Color3, Enum, CFrame = roblox.Vector3, roblox.Color3, roblox.Enum, roblox.CFrame

local FILE = "huzz-valley/assets/knives/HuzzKnives.rbxm"
local WRITE = table.find(process.args, "--write") ~= nil
local PLACE = "huzz-valley/places/HUSSANIME.rbxl"
for _, a in process.args do
	if string.sub(a, 1, 2) ~= "--" then PLACE = a end
end
local IMPORTS = { "Gamepass knifes", "Halloween knives" } -- (his names for them in Workspace)

-- colour_knives' matcher (it returns its helpers when it sees --module)
local Colour = luau.load(fs.readFile("huzz-valley/tools/knives/colour_knives.luau"), { debugName = "colour_knives",
	environment = {
		require = function(name)
			if name == "@lune/process" then return { args = { "--module" }, env = {} } end
			return require(name)
		end,
	} })()

local boxes = serde.decode("json", fs.readFile("huzz-valley/tools/knives/knife_boxes.json"))
local insts = roblox.deserializeModel(fs.readFile(FILE))
local folder = insts[1]
-- (a re-run sets the 23 up again from his imports: any of them already in the file go first)
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do
	local m = string.find(k.file, "/", 1, true) and folder:FindFirstChild(k.key)
	if m then m:Destroy() end
end
local had = {}
for _, m in folder:GetChildren() do had[m.Name] = true end

local place = roblox.deserializePlace(fs.readFile(PLACE))
local game = roblox.Instance.new("DataModel")
folder.Parent = game:GetService("ServerStorage")
for _, name in IMPORTS do
	local m = place:GetService("Workspace"):FindFirstChild(name)
	assert(m, "his import Workspace > " .. name .. " is not in " .. PLACE)
	m.Parent = game:GetService("Workspace")
end

-- his helper, as the Command Bar runs it (the same two swaps as colour_knives.luau)
local source = fs.readFile("huzz-valley/src/ServerStorage/HuzzStudioTools/SetupKnives.lua")
source = string.gsub(source, "if script == nil then run%(%) end[^\n]*\n", "")
local swaps
source, swaps = string.gsub(source, "a%.Position = Vector3%.new%(0, y, 0%)", "a.CFrame = CFrame.new(0, y, 0)")
assert(swaps == 1, "SetupKnives' attach() changed: update add_import_knives.luau")
local run = luau.load(source, { debugName = "SetupKnives", environment = { game = game, Instance = roblox.Instance,
	Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum } })()
local count = run()

local added, bad, total = 0, 0, 0
for _, model in folder:GetChildren() do
	total += 1
	if had[model.Name] then continue end
	local nodes = boxes[model.Name]
	if not (nodes and model:FindFirstChild("Handle")) then
		bad += 1
		print(model.Name .. "  << no Handle or no .glb boxes")
		continue
	end
	local meshes, textured = 0, 0
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			meshes += 1
			local okT, tc = pcall(function() return tostring(p.TextureContent) end)
			if okT and string.find(tc, "rbxasset") then
				textured += 1
				p.TextureContent = roblox.Content.none -- (the import's own colour picture: the colour is the part's now)
			end
		end
	end
	local list, turn, worst = Colour.match(model, nodes)
	local wrong = 0
	for _, m in list do
		if not Colour.dressed(m.part, m.node) then wrong += 1 end
	end
	local ok = turn % 2 == 0 and worst < 0.12 and wrong == 0 and meshes == #list
	if ok then added += 1 else bad += 1 end
	print(string.format("%-18s %3d parts (%3d his meshes), %2d import pictures dropped, worst %.3f studs off%s", model.Name,
		#list, meshes, textured, worst, if ok then "" else string.format("  << NOT RIGHT (turn %d, %d looks)", turn, wrong)))
end
print(string.format("his helper: %s of 53; %d added, %d not right, %d in the file", tostring(count), added, bad, total))
if WRITE and bad == 0 and total == 53 then
	folder.Parent = nil
	fs.writeFile(FILE, roblox.serializeModel(insts))
	print("wrote " .. FILE)
end
if bad > 0 or total ~= 53 then process.exit(1) end
