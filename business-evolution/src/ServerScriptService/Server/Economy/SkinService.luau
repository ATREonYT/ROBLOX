--!strict
-- Skins: the wardrobe wall in the hub. Buy with Wins, wear one at a time, and
-- the equipped skin multiplies your click income (see Stack.clickIncome).
--
-- This service also OWNS how a character looks: it paints the body parts from
-- the skin config on spawn and on every equip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)
local Net = require(ServerScriptService.Server.Net.Net)

local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

local SkinService = {}

local trove = Trove.new()
local playerTroves: { [Player]: any } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Paint the character in the equipped skin. Clothing textures would cover the
-- colours, so they are removed; they come back on respawn if a skin is unset.
local function applySkin(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	if not (data and character) then
		return
	end
	local skin = Skins.get(data.EquippedSkin) or Skins.get(Skins.DefaultId)
	if not skin then
		return
	end

	for _, item in character:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end

	local shirt = rgb(skin.Shirt)
	local trousers = rgb(skin.Trousers)
	local material = if skin.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local TORSO_PARTS = { "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }
	local LEG_PARTS = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

	for _, name in TORSO_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = shirt
			part.Material = material
		end
	end
	for _, name in LEG_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = trousers
			part.Material = Enum.Material.SmoothPlastic
		end
	end
end

SkinService.applyFor = applySkin

local function onBuySkin(player: Player, skinId: string)
	local data = DataService.get(player)
	local skin = Skins.get(skinId)
	if not (data and skin) then
		return
	end
	if table.find(data.OwnedSkins, skinId) then
		return -- already owned; the client should have greyed this out
	end
	if data.Wins < skin.Cost then
		return
	end
	DataService.update(player, function(live)
		live.Wins -= skin.Cost
		table.insert(live.OwnedSkins, skinId)
		live.EquippedSkin = skinId -- buying always equips: nobody buys to not wear
	end)
	applySkin(player)
	Net.sendAll("Fx", { Kind = "Purchase", UserId = player.UserId })
	DataService.pushState(player)
end

local function onEquipSkin(player: Player, skinId: string)
	local data = DataService.get(player)
	if not data or not Skins.get(skinId) then
		return
	end
	if not table.find(data.OwnedSkins, skinId) then
		return -- not yours
	end
	DataService.update(player, function(live)
		live.EquippedSkin = skinId
	end)
	applySkin(player)
	DataService.pushState(player)
end

local function watchPlayer(player: Player)
	local playerTrove = trove:Extend() :: any
	playerTroves[player] = playerTrove
	playerTrove:Connect(player.CharacterAdded, function()
		-- Let the default appearance finish loading before repainting it.
		task.defer(function()
			applySkin(player)
		end)
	end)
	if player.Character then
		applySkin(player)
	end
end

function SkinService:Init() end

function SkinService:Start()
	Net.bind("RequestBuySkin", 3, 5, t.tuple(t.string), onBuySkin)
	Net.bind("RequestEquipSkin", 5, 8, t.tuple(t.string), onEquipSkin)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	trove:Connect(Players.PlayerAdded, watchPlayer)
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		applySkin(player)
	end)
	trove:Connect(DataService.PlayerUnloading :: any, function(player: Player)
		local playerTrove = playerTroves[player]
		if playerTrove then
			playerTrove:Destroy()
		end
		playerTroves[player] = nil
	end)
end

return SkinService
