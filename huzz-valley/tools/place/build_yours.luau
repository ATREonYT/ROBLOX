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

-- The owner's knives (Oct 18): once he has run the knife setup in Studio and sent ServerStorage > HuzzKnives
-- (right-click > Save to File) as huzz-valley/assets/knives/HuzzKnives.rbxm, every build carries them. Without that
-- file, a HuzzKnives already in his place stays; with neither, KnifeService tints the built-in knife.
do
	local file = "huzz-valley/assets/knives/HuzzKnives.rbxm"
	if fs.isFile(file) then
		local storage = theirs:GetService("ServerStorage")
		local holder
		for _, inst in roblox.deserializeModel(fs.readFile(file)) do
			if inst.Name == "HuzzKnives" then
				holder = inst
			else -- (saved as the knives themselves: put them in a folder)
				holder = holder or roblox.Instance.new("Folder")
				holder.Name = "HuzzKnives"
				inst.Parent = holder
			end
		end
		if holder then
			local old = storage:FindFirstChild("HuzzKnives")
			if old then old:Destroy() end
			holder.Parent = storage
			print("knives: " .. #holder:GetChildren() .. " from assets/knives/HuzzKnives.rbxm")
		end
	else
		local has = theirs:GetService("ServerStorage"):FindFirstChild("HuzzKnives")
		print("knives: " .. (if has then "the place's own HuzzKnives kept" else "none yet (built-in knife, tinted)"))
	end
end

-- The lobby leaderboards (owner, Oct 18: "make the leaderboards just like in the video", then with his new lobby:
-- "please add all of these leaderboards ... to the new lobby"): five round each lobby floor (Shared/LobbyLayout: in
-- his new lobby three on his grey podiums by the plaza, two on the terrace steps either side behind it, facing the
-- plaza), saved in the place so the owner sees them and can drag them (Workspace > HuzzLeaderboards). Built by the
-- game's own code (Shared/LeaderboardLook), so Studio shows the same board the game fills in. Skipped when the
-- place already has boards (anything named "Leaderboard..." or with a "Stat" attribute): his spots win.
local Layout = require("../../src/ReplicatedStorage/Shared/LobbyLayout")
local layoutApi = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame }
do
	local Look = require("../../src/ReplicatedStorage/Shared/LeaderboardLook")
	local Rules = require("../../src/ReplicatedStorage/Shared/LeaderboardRules")
	local Boards = require("../../src/ReplicatedStorage/Shared/Config/Leaderboards")
	local api = { Instance = roblox.Instance, UDim2 = roblox.UDim2, UDim = roblox.UDim, Color3 = roblox.Color3, Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum, Font = roblox.Font }
	local ws = theirs:GetService("Workspace")
	local function key(name) return (string.gsub(name, "[%s_%-]", "")):lower() end
	local has = false
	for _, d in ws:GetDescendants() do
		if (d:IsA("Model") or d:IsA("BasePart")) and (string.sub(key(d.Name), 1, 11) == "leaderboard" or d:GetAttribute("Stat") ~= nil) then has = true end
	end
	local floors = Layout.floors(ws)
	if has then
		print("leaderboards: the place has its own, kept")
	else
		local holder = roblox.Instance.new("Folder")
		holder.Name = "HuzzLeaderboards"
		local count, where = 0, {}
		for _, floor in floors do
			local spots = Layout.boardSpots(api, Rules, ws, floor, #Boards.Boards)
			local podium, steps = 0, 0
			for i, spot in spots do
				local model = Look.model(api, Boards.Boards[i], spot.at, Boards.Size, Boards.Lift, Boards.Subtitle, Boards.Shown, spot.podium)
				pcall(function() model.ModelStreamingMode = roblox.Enum.ModelStreamingMode.Atomic end)
				model.Parent = holder
				count += 1
				if spot.podium then podium += 1 else steps += 1 end
			end
			local c = floor.CFrame.Position
			table.insert(where, string.format("(%d, %d): %d on podiums, %d on steps", math.round(c.X), math.round(c.Z), podium, steps))
		end
		holder.Parent = ws
		print("leaderboards: " .. count .. " placed round " .. #floors .. " lobbies; " .. table.concat(where, "; "))
	end
end

-- Avatar stands (owner, Oct 18: "make the blocks i have in the lobby, next to the spin the wheel turn into my
-- character ... selling a gamepass", then "equipped with some exclusive knifes", then the new lobby: "add ... all of
-- the gamepass things to the new lobby"): in his new lobby, an invisible stand on each of the five round pads at the
-- front of every lobby copy (Workspace > HuzzAvatarStands, tagged; three-pad side VIP, two-pad side Dance Pack, one
-- Game Pass knife each). In older places, his plain
-- grey blocks beside each spin wheel (4 x 7.5 x 4.5, standing on the floor) become stands (renamed "AvatarStand",
-- Pass = VIP and DancePack in turn: both show SOON until their Game Pass IDs are in Config/Products; Knife = that
-- pass's exclusive knives in turn). The rule is Shared/AvatarStandRules.findBlocks; in his own Rojo-synced place
-- HuzzServer/AvatarStandService runs the same rule at game start (nothing to do by hand there).
do
	local Stand = require("../../src/ReplicatedStorage/Shared/AvatarStandRules")
	-- the pass knives from Config/CoinShop (it requires Config/Products: a stand-in with what it reads at load)
	local luau = require("@lune/luau")
	local okShop, CoinShop = pcall(function()
		local env = setmetatable({
			Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			require = function() return { Cosmetics = {} } end, script = { Parent = { Products = true } },
		}, { __index = _G })
		return luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua"), { debugName = "CoinShop", environment = env })()
	end)
	local ws = theirs:GetService("Workspace")
	-- his new lobby: an invisible stand on each round pad at the front of every lobby copy (Shared/LobbyLayout)
	local onPads = {}
	if okShop then
		local holder
		for _, floor in Layout.floors(ws) do
			for _, spot in Layout.standSpots(layoutApi, ws, floor) do
				holder = holder or roblox.Instance.new("Folder")
				holder.Name = "HuzzAvatarStands"
				local stand = Layout.standPart(layoutApi, spot)
				local knife = Stand.knife(spot.Pass, nil, CoinShop.Items, spot.Turn)
				stand:SetAttribute("Knife", knife)
				pcall(function() stand:AddTag("HuzzAvatarStand") end)
				stand.Parent = holder
				local p = spot.at.Position
				table.insert(onPads, string.format("%s (%s at %d, %d)", tostring(knife), spot.Pass, math.round(p.X), math.round(p.Z)))
			end
		end
		if holder then holder.Parent = ws end
	end
	local wheels, parts = {}, {}
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
			if count > 0 and hi - lo > 5 then -- (the big wheels, not the small 3-stud one)
				local c = sum / count
				table.insert(wheels, { X = c.X, Y = c.Y, Z = c.Z })
			end
		elseif d.ClassName == "Part" and d.Name == "Part" then
			local p, sz = d.CFrame.Position, d.Size
			table.insert(parts, { ref = d, Name = d.Name, Class = d.ClassName, X = p.X, Y = p.Y, Z = p.Z, SX = sz.X, SY = sz.Y, SZ = sz.Z })
		end
	end
	local made, knives = 0, {}
	if #onPads > 0 then
		print("avatar stands: " .. #onPads .. " on the new lobby's pads; " .. table.concat(onPads, ", "))
		wheels, parts = {}, {} -- (his old grey blocks beside the old islands' wheels stay plain blocks)
	end
	for _, b in Stand.findBlocks(wheels, parts) do
		b.ref.Name = "AvatarStand"
		b.ref:SetAttribute("Pass", b.Pass)
		if okShop then
			local knife = Stand.knife(b.Pass, nil, CoinShop.Items, b.Turn)
			if knife then
				b.ref:SetAttribute("Knife", knife)
				table.insert(knives, string.format("%s (%s at %d, %d)", knife, b.Pass, math.round(b.ref.CFrame.Position.X), math.round(b.ref.CFrame.Position.Z)))
			end
		end
		made += 1
	end
	if #onPads == 0 then
		print("avatar stands: " .. made .. " blocks beside " .. #wheels .. " spin wheels; knives " .. (if okShop then table.concat(knives, ", ") else "not set (" .. tostring(CoinShop) .. ")"))
	end
end

-- Future lighting (crisper light and shadows; Roblox drops to simpler lighting on weak devices by itself). Scripts
-- can't set Technology, so it's set here; the rest of the look is Config/Look (HuzzServer/LookService).
local okTech, errTech = pcall(function() theirs:GetService("Lighting").Technology = roblox.Enum.Technology.Future end)
print(if okTech then "lighting: Future" else "lighting: couldn't set Technology (" .. tostring(errTech) .. ")")

fs.writeFile(ROOT .. "HuzzValley-yours.rbxl", roblox.serializePlace(theirs))
print("saved " .. ROOT .. "HuzzValley-yours.rbxl")
