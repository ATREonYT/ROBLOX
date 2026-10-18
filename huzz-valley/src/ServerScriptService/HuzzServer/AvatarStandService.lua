--[[
	Gets the lobby avatar stands ready on the server (owner, Oct 18: "make the character things in the lobby work,
	because im going to make them into gamepasses shown with the character of the person playing, equipped with some
	exclusive knifes"). Each screen draws the stands itself (HuzzClient/Gameplay/AvatarStands); this makes sure there
	are stands to draw and knives to hold:

	1. Which stands: anything named "AvatarStand..." or tagged "HuzzAvatarStand" (the place build saves them in
	   Workspace > HuzzAvatarStands, so he can drag them). If the place has none (his own place synced by Rojo):
	   - his new lobby (owner Oct 18: "please add ... all of the gamepass things to the new lobby"): an invisible
	     stand on each of the five small round pads at the front of every lobby copy (Shared/LobbyLayout.standSpots:
	     the side with three pads is VIP, the two-pad side Dance Pack, one Game Pass knife each), made here in
	     Workspace > HuzzAvatarStands;
	   - else (his older places) his plain grey blocks beside the big spin wheels (Shared/AvatarStandRules.findBlocks),
	     tagged here with Pass = VIP / DancePack in turn.
	   Nothing of his is renamed and nothing typed in Studio is overwritten.
	2. Which knife: each stand gets a "Knife" attribute (if it has none) = one of its pass's exclusive knives
	   (Config/CoinShop Pass), in turn, so the six stands show different knives. A typed knife the pass doesn't give
	   is replaced (with a warning in Output): a stand never shows something the pass doesn't give.
	3. The knife models: clients can't see ServerStorage, so a ready copy of each pass knife (his model from
	   ServerStorage/HuzzKnives/<key> when he has set it up, else the game's own knife in its colours, with its
	   rarity's calm effects: HuzzServer/KnifeService.display) goes in ReplicatedStorage > HuzzStandKnives.
	The VIEW button and buying stay on the client's rules (Shared/AvatarStandRules: SOON until a real Game Pass ID is
	in Config/Products); the knives are given only by ShopService when Roblox says you own the pass.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local Products = require(Shared.Config.Products)
local Rules = require(Shared.AvatarStandRules)
local KnifeService = require(script.Parent.KnifeService)
local LobbyLayout = require(Shared.LobbyLayout)

local AvatarStandService = {}
local TAG = "HuzzAvatarStand"
local api = { Instance = Instance, Vector3 = Vector3, CFrame = CFrame }
local folder: Folder

local function key(name: string): string
	return (string.gsub(name, "[%s_%-]", "")):lower()
end

local function passKeyOf(stand: Instance): string?
	local info = Rules.resolve({ Pass = stand:GetAttribute("Pass") }, Products)
	return info.Key
end

-- Stands placed by hand (named or tagged).
local function placed(): { Instance }
	local out = {}
	for _, d in Workspace:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Model")) and string.sub(key(d.Name), 1, 11) == "avatarstand" then table.insert(out, d) end
	end
	pcall(function()
		for _, t in CollectionService:GetTagged(TAG) do
			if not table.find(out, t) then table.insert(out, t) end
		end
	end)
	return out
end

-- His grey blocks beside the big spin wheels (Shared/AvatarStandRules.findBlocks).
local function found(): { any }
	local wheels, parts = {}, {}
	for _, d in Workspace:GetDescendants() do
		local n = string.lower(d.Name)
		if d:IsA("Model") and string.find(n, "spin") and string.find(n, "wheel") then
			local lo, hi, sum, count = math.huge, -math.huge, Vector3.zero, 0
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					local q = p.CFrame.Position
					lo, hi, sum, count = math.min(lo, q.Y), math.max(hi, q.Y), sum + q, count + 1
				end
			end
			if count > 0 and hi - lo > 5 then
				local c = sum / count
				table.insert(wheels, { X = c.X, Y = c.Y, Z = c.Z })
			end
		elseif d.ClassName == "Part" and d.Name == "Part" then
			local p, s = d.CFrame.Position, d.Size
			table.insert(parts, { ref = d, Name = d.Name, Class = d.ClassName, X = p.X, Y = p.Y, Z = p.Z, SX = s.X, SY = s.Y, SZ = s.Z })
		end
	end
	return Rules.findBlocks(wheels, parts)
end

-- A ready copy of a knife for the stands (once per key).
local function publish(knifeKey: string)
	if folder:FindFirstChild(knifeKey) then return end
	local skin = CoinShop.get(knifeKey)
	if not skin then return end
	local ok, model = pcall(KnifeService.display, skin)
	if ok and model then
		model.Name = knifeKey
		model.Parent = folder
	else
		warn("[Huzz] avatar stand knife " .. knifeKey .. " couldn't be made: " .. tostring(model))
	end
end

-- The knife a stand shows (its own if it's one its pass gives, else the pass's next one).
local function pickKnife(stand: Instance, turns: { [string]: number })
	local pass = passKeyOf(stand)
	if not pass then return end
	turns[pass] = (turns[pass] or 0) + 1
	local knife, why = Rules.knife(pass, stand:GetAttribute("Knife"), CoinShop.Items, turns[pass])
	if why then warn("[Huzz] Avatar stand " .. stand:GetFullName() .. ": " .. why) end
	stand:SetAttribute("Knife", knife)
end

-- His new lobby's round pads: an invisible stand on each, with its pass and that pass's knife.
local function onPads(): { Instance }
	local out = {}
	local holder
	for _, floor in LobbyLayout.floors(Workspace) do
		for _, spot in LobbyLayout.standSpots(api, Workspace, floor) do
			if not holder then
				holder = Instance.new("Folder")
				holder.Name = "HuzzAvatarStands"
				holder.Parent = Workspace
			end
			local stand = LobbyLayout.standPart(api, spot)
			stand:SetAttribute("Knife", Rules.knife(spot.Pass, nil, CoinShop.Items, spot.Turn))
			stand.Parent = holder
			if not pcall(function() stand:AddTag(TAG) end) then pcall(function() CollectionService:AddTag(stand, TAG) end) end
			table.insert(out, stand)
		end
	end
	return out
end

function AvatarStandService.start()
	folder = Instance.new("Folder")
	folder.Name = "HuzzStandKnives"
	folder.Parent = ReplicatedStorage
	local stands = placed()
	local how = "placed"
	if #stands == 0 then
		stands = onPads()
		how = "on the new lobby's pads"
	end
	if #stands == 0 then
		how = "found beside the spin wheels"
		for _, b in found() do
			if b.ref:GetAttribute("Pass") == nil then b.ref:SetAttribute("Pass", b.Pass) end
			if not pcall(function() b.ref:AddTag(TAG) end) then pcall(function() CollectionService:AddTag(b.ref, TAG) end) end
			table.insert(stands, b.ref)
		end
	end
	local turns = {}
	for _, stand in stands do
		local ok, err = pcall(pickKnife, stand, turns)
		if not ok then warn("[Huzz] avatar stand: " .. tostring(err)) end
	end
	-- every pass knife is ready, so a stand changed while playing (or one added later) has its knife too
	for _, item in CoinShop.Items do
		if item.Pass then publish(item.Key) end
	end
	print(string.format("[Huzz] Avatar stands: %d (%s)", #stands, how))
end

return AvatarStandService
