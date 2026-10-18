-- Builds places/HuzzValley-yours.rbxl: the owner's own place (places/HUSSANIME.rbxl: maps, girls, lobby) with
-- every current script and the saved UI swapped in, so it plays without Rojo. Also strips the known
-- CoreValidation scam out of any free model. Run from the repo root after build_place.sh:
--   lune run huzz-valley/tools/place/build_yours.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ROOT = "huzz-valley/places/"
local theirs = roblox.deserializePlace(fs.readFile(ROOT .. "HUSSANIME.rbxl"))
local ours = roblox.deserializePlace(fs.readFile(ROOT .. "HuzzValley.rbxl"))

-- Each of these is replaced by the current build's version (path from the service).
local SWAP = {
	{ "ServerScriptService", "HuzzServer" },
	{ "ReplicatedStorage", "Shared" },
	{ "ServerStorage", "HuzzAnimations" }, -- (the owner's animations: tools/anim/extract_anims.luau)
	{ "StarterPlayer", "StarterPlayerScripts", "HuzzClient" },
	{ "StarterGui", "HuzzUI" },
	{ "ServerStorage", "HuzzStudioTools" },
	{ "ServerStorage", "HuzzImages" }, -- (effect textures for the upload helper: tools/icons/pack_images.py)
}
local function at(game, path)
	local inst = game:GetService(path[1])
	for i = 2, #path - 1 do
		inst = inst:FindFirstChild(path[i])
		if not inst then return nil end
	end
	return inst
end
for _, path in SWAP do
	local parentTheirs, parentOurs = at(theirs, path), at(ours, path)
	local name = path[#path]
	local fresh = parentOurs and parentOurs:FindFirstChild(name)
	if parentTheirs and fresh then
		local old = parentTheirs:FindFirstChild(name)
		if old then old:Destroy() end
		fresh:Clone().Parent = parentTheirs
		print("swapped " .. table.concat(path, "."))
	else
		print("skipped " .. table.concat(path, ".") .. " (missing)")
	end
end

-- The scam in free models: a hidden Dependencies > Utilities > CoreValidation script.
local removed = 0
for _, d in theirs:GetDescendants() do
	if d.ClassName == "Script" and d.Name == "CoreValidation" and d.Parent and d.Parent.Name == "Utilities" then
		local deps = d.Parent.Parent
		if deps and deps.Name == "Dependencies" then deps:Destroy() else d.Parent:Destroy() end
		removed += 1
	end
end
print("scam scripts removed: " .. removed)

-- The lobby leaderboards (owner, Oct 18: "make the leaderboards just like in the video"): five round each lobby
-- floor (on his three grey podiums first, two along the back edge), saved in the place so the owner sees them and can drag them (Workspace > HuzzLeaderboards). Built by the
-- game's own code (Shared/LeaderboardLook), so Studio shows the same board the game fills in. Skipped when the
-- place already has boards (anything named "Leaderboard..." or with a "Stat" attribute): his spots win.
do
	local Look = require("../../src/ReplicatedStorage/Shared/LeaderboardLook")
	local Rules = require("../../src/ReplicatedStorage/Shared/LeaderboardRules")
	local Boards = require("../../src/ReplicatedStorage/Shared/Config/Leaderboards")
	local api = { Instance = roblox.Instance, UDim2 = roblox.UDim2, UDim = roblox.UDim, Color3 = roblox.Color3, Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum, Font = roblox.Font }
	local ws = theirs:GetService("Workspace")
	local function key(name) return (string.gsub(name, "[%s_%-]", "")):lower() end
	local has, floors, named = false, {}, {}
	for _, d in ws:GetDescendants() do
		if (d:IsA("Model") or d:IsA("BasePart")) and (string.sub(key(d.Name), 1, 11) == "leaderboard" or d:GetAttribute("Stat") ~= nil) then has = true end
		if d:IsA("BasePart") and key(d.Name) == "spawnbaseplate" then table.insert(floors, d) end
		if d:IsA("BasePart") and key(d.Name) == "lobby" then table.insert(named, d) end
	end
	if #named > 0 then floors = named end
	if has then
		print("leaderboards: the place has its own, kept")
	else
		local holder = roblox.Instance.new("Folder")
		holder.Name = "HuzzLeaderboards"
		local count = 0
		local podiums = Look.podiums(ws)
		for _, floor in floors do
			for i, spot in Look.layout(api, Rules, floor, podiums, #Boards.Boards) do
				local model = Look.model(api, Boards.Boards[i], spot.at, Boards.Size, Boards.Lift, Boards.Subtitle, Boards.Shown, spot.podium)
				pcall(function() model.ModelStreamingMode = roblox.Enum.ModelStreamingMode.Atomic end)
				model.Parent = holder
				count += 1
			end
		end
		holder.Parent = ws
		print("leaderboards: " .. count .. " placed round " .. #floors .. " lobbies")
	end
end

-- Avatar stands (owner, Oct 18: "make the blocks i have in the lobby, next to the spin the wheel turn into my
-- character ... selling a gamepass"): in this copy of his place, his plain grey blocks beside each spin
-- wheel (4 x 7.5 x 4.5, standing on the floor) become stands (renamed "AvatarStand", Pass = VIP and DancePack: both show SOON until their Game Pass
-- IDs are in Config/Products). In his own newer place he does the same by hand (huzz-valley/CLAUDE.md).
do
	local ws = theirs:GetService("Workspace")
	local wheels = {}
	for _, d in ws:GetDescendants() do
		local n = string.lower(d.Name)
		if d:IsA("Model") and string.find(n, "spin") and string.find(n, "wheel") then
			local lo, hi, sum, count = math.huge, -math.huge, roblox.Vector3.new(0, 0, 0), 0
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					local q = p.CFrame.Position
					lo, hi, sum, count = math.min(lo, q.Y), math.max(hi, q.Y), sum + q, count + 1
				end
			end
			if count > 0 and hi - lo > 5 then table.insert(wheels, sum / count) end -- (the big wheels, not the small 3-stud one)
		end
	end
	local made, passes = 0, { "VIP", "DancePack" }
	for _, w in wheels do
		local near = {}
		for _, d in ws:GetDescendants() do
			if d.ClassName == "Part" and d.Name == "Part" then
				local s, p = d.Size, d.CFrame.Position
				if s.X > 3 and s.X < 5.5 and s.Z > 3 and s.Z < 5.5 and s.Y > 6 and s.Y < 9 -- (his are 4 x 7.5 x 4.5)
					and math.abs(p.X - w.X) < 12 and math.abs(p.Z - w.Z) < 45 then
					table.insert(near, d)
				end
			end
		end
		table.sort(near, function(a, b) return a.CFrame.Position.Z < b.CFrame.Position.Z end)
		for i, block in near do
			block.Name = "AvatarStand"
			block:SetAttribute("Pass", passes[(i - 1) % #passes + 1])
			made += 1
		end
	end
	print("avatar stands: " .. made .. " blocks beside " .. #wheels .. " spin wheels")
end

-- Future lighting (crisper light and shadows; Roblox drops to simpler lighting on weak devices by itself). Scripts
-- can't set Technology, so it's set here; the rest of the look is Config/Look (HuzzServer/LookService).
local okTech, errTech = pcall(function() theirs:GetService("Lighting").Technology = roblox.Enum.Technology.Future end)
print(if okTech then "lighting: Future" else "lighting: couldn't set Technology (" .. tostring(errTech) .. ")")

fs.writeFile(ROOT .. "HuzzValley-yours.rbxl", roblox.serializePlace(theirs))
print("saved " .. ROOT .. "HuzzValley-yours.rbxl")
