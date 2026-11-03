--!strict
-- 30 seconds of spawn protection after every spawn (research P0-6: spawn camping is the top complaint in the genre).
-- An invisible ForceField (Humanoid:TakeDamage, which GunService uses, ignores damage while one is present) plus the
-- character attribute MTL_SpawnProtected. It ends early the moment you draw a live gun, so nobody can shoot from
-- inside it. A small toast says when it's on and when it ends.
local Players = game:GetService("Players")

local Notify = require(script.Parent.Notify)

local SpawnProtection = {}

SpawnProtection.Seconds = 30

local function stop(char: Model, why: string?)
	local ff = char:FindFirstChild("MTL_SpawnShield")
	if ff then
		ff:Destroy()
	end
	if char:GetAttribute("MTL_SpawnProtected") then
		char:SetAttribute("MTL_SpawnProtected", nil)
		local player = Players:GetPlayerFromCharacter(char)
		if player and why then
			Notify.toast(player, why)
		end
	end
end

function SpawnProtection.isProtected(player: Player): boolean
	local char = player.Character
	return char ~= nil and char:GetAttribute("MTL_SpawnProtected") == true
end

function SpawnProtection.init()
	local function onCharacter(player: Player, char: Model)
		local ff = Instance.new("ForceField")
		ff.Name = "MTL_SpawnShield"
		ff.Visible = false -- no bubble: the toast tells you
		ff.Parent = char
		char:SetAttribute("MTL_SpawnProtected", true)
		task.delay(1.5, function()
			if char.Parent and char:GetAttribute("MTL_SpawnProtected") then
				Notify.toast(player, "Spawn protection: 30 s")
			end
		end)
		task.delay(SpawnProtection.Seconds, function()
			if char.Parent then
				stop(char, "Spawn protection ended")
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	-- drawing a live gun ends it (an Intimidate story gun doesn't: it can't hurt anyone)
	task.defer(function()
		local guns = script.Parent:FindFirstChild("GunService")
		local ok, GunService = pcall(require, guns :: any)
		if ok and GunService and GunService.Equipped then
			GunService.Equipped:Connect(function(player: Player, _gunId: string, mode: string?)
				if mode ~= "Intimidate" and player.Character then
					stop(player.Character, "Spawn protection off: gun out")
				end
			end)
		end
	end)
end

return SpawnProtection
