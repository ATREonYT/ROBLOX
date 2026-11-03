-- VBHouseInteriors (Script in ServerScriptService)
-- Villas are shells until someone owns them. Each furnished interior lives in ServerStorage.VBInteriors
-- under the house's HouseId and is cloned in while the house's "Owner" attribute is set.
--
-- Claim:   house:SetAttribute("Owner", player.UserId)   -> interior loads, front door swings open
-- Release: house:SetAttribute("Owner", "")              -> interior removed, door closes
-- Houses are tagged "VBHouse" (CollectionService). Other scripts can also call
--   game.ServerStorage.VBHouseAPI:Invoke("claim", houseModel, player) / ("release", houseModel)
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local store = SS:WaitForChild("VBInteriors")

local function setDoor(house, open)
	for _, d in ipairs(house:GetDescendants()) do
		if d.Name == "FrontDoor" and d:IsA("BasePart") then
			local cf = d:GetAttribute(open and "OpenCF" or "ClosedCF")
			if cf then d.CFrame = cf end
			d.CanCollide = not open
		elseif d.Name == "DoorHandle" and d:IsA("BasePart") then
			d.Transparency = open and 1 or 0
		end
	end
end

local function owned(house)
	local o = house:GetAttribute("Owner")
	return o ~= nil and o ~= "" and o ~= 0
end

local function update(house)
	local cur = house:FindFirstChild("Interior")
	if owned(house) then
		if not cur then
			local src = store:FindFirstChild(house:GetAttribute("HouseId") or house.Name)
			if src then
				local c = src:Clone()
				c.Name = "Interior"
				c.Parent = house
			end
		end
		setDoor(house, true)
	else
		if cur then cur:Destroy() end
		setDoor(house, false)
	end
end

local function hook(house)
	if not house:IsA("Model") then return end
	if house:GetAttribute("Owner") == nil then house:SetAttribute("Owner", "") end
	house:GetAttributeChangedSignal("Owner"):Connect(function() update(house) end)
	update(house)
end

for _, h in ipairs(CS:GetTagged("VBHouse")) do task.spawn(hook, h) end
CS:GetInstanceAddedSignal("VBHouse"):Connect(hook)

-- free a player's houses when they leave
Players.PlayerRemoving:Connect(function(plr)
	for _, h in ipairs(CS:GetTagged("VBHouse")) do
		if h:GetAttribute("Owner") == plr.UserId or h:GetAttribute("Owner") == tostring(plr.UserId) then h:SetAttribute("Owner", "") end
	end
end)

-- small API for the game's property system
local api = SS:FindFirstChild("VBHouseAPI") or Instance.new("BindableFunction")
api.Name = "VBHouseAPI"
api.Parent = SS
api.OnInvoke = function(action, house, plr)
	if action == "claim" and house and plr then
		if owned(house) then return false, "taken" end
		house:SetAttribute("Owner", plr.UserId)
		return true
	elseif action == "release" and house then
		house:SetAttribute("Owner", "")
		return true
	elseif action == "list" then
		local out = {}
		for _, h in ipairs(CS:GetTagged("VBHouse")) do table.insert(out, { house = h, id = h:GetAttribute("HouseId"), owner = h:GetAttribute("Owner"), style = h:GetAttribute("HouseStyle") }) end
		return out
	end
	return false, "unknown action"
end
