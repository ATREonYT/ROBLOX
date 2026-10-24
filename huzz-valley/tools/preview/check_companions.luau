-- Everyone's equipped girl on YOUR screen (owner, Oct 19: "make the girls appear for everyone on everyones screen";
-- "cc's head doesnt move"). Runs the real HuzzClient/Gameplay/Auras with three players standing in the lobby, using
-- his real girls from places/HUSSANIME.rbxl (an R6 Common and C.C., his R15 Secret), and checks:
--   * every player's girl is built and walks on this screen, yours and the others';
--   * one player whose girl can't be built (a broken model) doesn't stop the others' girls (each player is updated on
--     its own: one error used to end the frame's loop, so everyone after that player had no girl on this screen);
--   * C.C.'s hair hangs off her Head (Shared/GirlRig), so it turns with her head.
-- Run from tools/preview: lune run harness.luau ../../src - @check_companions.luau setup_ui.luau
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ok, failed = 0, 0
local function check(name, c) if c then ok += 1 else failed += 1; print("FAIL " .. name) end end

-- engine bits Lune doesn't have
__roblox.implementProperty("Humanoid", "RootPart", function(self) return self.Parent and self.Parent:FindFirstChild("HumanoidRootPart") end)
__roblox.implementMethod("Model", "GetScale", function() return 1 end)
-- (building one girl fails: her copy errors as it is sized, as anything unexpected in a model would)
__roblox.implementMethod("Model", "ScaleTo", function(self)
	if self:GetAttribute("Id") == "broken" then error("this girl can't be built") end
end)
__roblox.implementMethod("Workspace", "Raycast", function() return nil end)
local chars = {}
__roblox.implementProperty("Player", "Character", function(self) return chars[self.Name] end, function(self, v) chars[self.Name] = v end) -- (by name: Lune may hand out a new userdata for the same player)

-- his girls, published as GirlService.publish does (anchored copies with Id and Rarity)
local place = __roblox.deserializePlace(__fs.readFile("../../places/HUSSANIME.rbxl"))
local girlsFolder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
local folder = RS:FindFirstChild("HuzzGirls") or Instance.new("Folder")
folder.Name = "HuzzGirls"
folder.Parent = RS
local function publish(id, key, rarity)
	for _, r in girlsFolder:GetChildren() do
		local m = r:FindFirstChild(id)
		if m then
			local copy = m:Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored = true end
			end
			copy.Name = key
			copy:SetAttribute("Id", id)
			copy:SetAttribute("Rarity", rarity)
			copy.Parent = folder
			return copy
		end
	end
end
publish("CAC_R6_Nikaccount41_E52B4E", "GZ1", "Common")
publish("CAC_R15_TransportViewer_DDEE6E", "GZ2", "Secret")
local broken = folder:FindFirstChild("GZ1"):Clone() -- (a girl whose copy can't be built: see ScaleTo above)
broken.Name = "GZ3"
broken:SetAttribute("Id", "broken")
broken.Parent = folder

local function character(name, at)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(at)
	root.Position = at
	root.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0))
	head.Position = at + Vector3.new(0, 1.5, 0)
	head.Parent = m
	local h = Instance.new("Humanoid")
	h.Health = 100
	pcall(function() h.RootPart = root end)
	h.Parent = m
	m.Parent = workspace
	return m
end
local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 77; me.Parent = Players
Players.LocalPlayer = me
local nextId = 100
local function join(name, at, girl, rarity)
	local p = if name == "me" then me else Instance.new("Player")
	if name ~= "me" then
		nextId += 1
		p.Name, p.UserId = name, nextId
		p.Parent = Players
	end
	p.Character = character(name, at)
	p:SetAttribute("HuzzCompanion", girl)
	p:SetAttribute("HuzzCompanionRarity", rarity)
	p:SetAttribute("HuzzCompanionPrestige", 0)
	p:SetAttribute("HuzzRole", "Lobby")
	return p
end
-- (the broken one joins second, so the girls after it in the list show whether one error stops the rest)
join("me", Vector3.new(0, 3, 0), "GZ1", "Common")
join("Broken", Vector3.new(10, 3, 0), "GZ3", "Rare")
local cc = join("Friend", Vector3.new(-10, 3, 6), "GZ2", "Secret")
local other = join("Other", Vector3.new(6, 3, -12), "GZ1", "Common")
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 25)

local Auras = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.Auras)
local okStart, err = pcall(Auras.start)
check("Auras starts: " .. tostring(err), okStart)
for _ = 1, 45 do
	__fireOn(RunService, "RenderStepped", 1 / 30)
end
local built = workspace:FindFirstChild("HuzzCompanions")
local count = if built then #built:GetChildren() else 0
check(`every player's girl is on this screen, yours and the others' ({count} of 3)`, count == 3)

-- C.C. on this screen: her hair on her Head
local ccModel = nil
for _, m in (built and built:GetChildren() or {}) do
	if m:FindFirstChild("UpperTorso") then ccModel = m end
end
check("C.C. walks on this screen", ccModel ~= nil)
if ccModel then
	local onHead, loose = 0, 0
	for _, acc in ccModel:GetChildren() do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		if handle then
			local to = nil
			for _, d in handle:GetDescendants() do
				if d:IsA("JointInstance") then to = if d.Part1 == handle then d.Part0 else d.Part1 end
				if d:IsA("WeldConstraint") then to = if d.Part1 == handle then d.Part0 else d.Part1 end
			end
			if to and to.Name == "Head" then onHead += 1 elseif not to or to.Name == "HumanoidRootPart" then loose += 1 end
		end
	end
	check(`C.C.'s hair and face hang off her Head ({onHead} on her head, {loose} on her root or loose)`, onHead >= 2 and loose == 0)
end

-- a player leaves: their girl goes with them
local before = count
__fireOn(Players, "PlayerRemoving", other)
other.Parent = nil
for _ = 1, 3 do __fireOn(RunService, "RenderStepped", 1 / 30) end
check("a player who leaves takes their girl", built and #built:GetChildren() == before - 1)
local _ = cc

print(`companions: {ok} ok, {failed} failed`)
return ""
