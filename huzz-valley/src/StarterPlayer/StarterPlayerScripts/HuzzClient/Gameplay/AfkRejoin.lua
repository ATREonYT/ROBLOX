--[[
	Going AFK never ends in a kick (owner, Oct 19: "make the players join back automatically after going afk and about
	to get kicked"). Roblox kicks a player after 20 minutes without input; it warns the game first with
	Players.LocalPlayer.Idled (about 2 minutes in, then every 30 seconds, with how long they've been idle). Once a
	player has been idle REJOIN_AT seconds (17 minutes counting either way Roblox reports it, so always before the
	kick) this sends them straight back into this same server (TeleportService:TeleportToPlaceInstance, so their
	friends are still there), or into any server of this game if that one can't take them. Their save is kept as
	usual when they leave (DataService). A short line tells them first.
	In Studio there is no server to rejoin: it only prints a [Huzz] line. Every call is in a pcall.
	Auto AFK (owner, Oct 24 06:12: "if a person is not moving for 4-5 minutes the afk system starts, and the user doesnt
	get kicked out"): no key, click, touch, mouse move or stick here for Config/Afk.IdleAfter seconds tells the server
	(remote Away) and they sit out games (HuzzServer/AfkService); the first input after says they're back. On Roblox's
	idle warning it also tries VirtualUser (a click nobody sees) so the idle clock starts again and no rejoin is
	needed; where Roblox doesn't let a game do that, the rejoin above is what keeps them here. Their coin boost from
	playing comes with them on that rejoin (HuzzServer/PlaytimeService).
]]
local M = {}

local REJOIN_AT = 17 * 60 -- seconds idle (Roblox's kick comes at 20 minutes)

function M.start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TeleportService = game:GetService("TeleportService")
	local player = Players.LocalPlayer

	local going = false
	local function rejoin()
		if going then
			return
		end
		going = true
		if RunService:IsStudio() then
			print("[Huzz] AFK rejoin: would rejoin this server now (Studio can't teleport)")
			going = false
			return
		end
		pcall(function()
			local Toast = require(script.Parent.Parent.UI.Toast)
			Toast.show("You were away a while. Rejoining so you don't get kicked!", 4)
		end)
		task.wait(1.5)
		local ok = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end)
		if not ok then
			pcall(function()
				TeleportService:Teleport(game.PlaceId, player)
			end)
		end
	end

	-- this server full or gone: any server of the game instead (twice at most, never a loop)
	local retries = 0
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(who)
			if who == player and going and retries < 2 then
				retries += 1
				pcall(function()
					TeleportService:Teleport(game.PlaceId, player)
				end)
			end
		end)
	end)

	-- away: no input for Afk.IdleAfter seconds
	local Afk = require(game:GetService("ReplicatedStorage").Shared.Config.Afk)
	local awayRemote = require(game:GetService("ReplicatedStorage").Shared.Net).get("Away")
	local UserInputService = game:GetService("UserInputService")
	local lastInput, away, ignoreUntil = os.clock(), false, 0
	local function setAway(on: boolean)
		if on == away then return end
		away = on
		pcall(function() awayRemote:FireServer(on) end)
	end
	local function touched()
		if os.clock() < ignoreUntil then return end -- (our own VirtualUser click)
		lastInput = os.clock()
		if away then setAway(false) end
	end
	UserInputService.InputBegan:Connect(touched)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Gamepad1 or t == Enum.UserInputType.MouseWheel then
			touched()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h and h.MoveDirection.Magnitude > 0.1 then touched() end -- (a phone's stick)
			if not away and os.clock() - lastInput >= Afk.IdleAfter then setAway(true) end
		end
	end)

	local triedVirtual = false
	player.Idled:Connect(function(idleSeconds: number)
		-- a click nobody sees, so Roblox's 20-minute idle clock starts again (stays AFK here: ignored above)
		ignoreUntil = os.clock() + 1
		local ok = pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
		if not triedVirtual then
			triedVirtual = true
			print("[HuzzAfk] keep-here click " .. (if ok then "works" else "isn't allowed: the rejoin keeps them in instead"))
		end
		if type(idleSeconds) == "number" and idleSeconds >= REJOIN_AT then
			rejoin()
		end
	end)
end

return M
