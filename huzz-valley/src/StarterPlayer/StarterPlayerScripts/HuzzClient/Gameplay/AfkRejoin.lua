--[[
	Going AFK never ends in a kick (owner, Oct 19: "make the players join back automatically after going afk and about
	to get kicked"). Roblox kicks a player after 20 minutes without input; it warns the game first with
	Players.LocalPlayer.Idled (about 2 minutes in, then every 30 seconds, with how long they've been idle). Once a
	player has been idle REJOIN_AT seconds (17 minutes counting either way Roblox reports it, so always before the
	kick) this sends them straight back into this same server (TeleportService:TeleportToPlaceInstance, so their
	friends are still there), or into any server of this game if that one can't take them. Their save is kept as
	usual when they leave (DataService). A short line tells them first.
	In Studio there is no server to rejoin: it only prints a [Huzz] line. Every call is in a pcall.
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

	player.Idled:Connect(function(idleSeconds: number)
		if type(idleSeconds) == "number" and idleSeconds >= REJOIN_AT then
			rejoin()
		end
	end)
end

return M
