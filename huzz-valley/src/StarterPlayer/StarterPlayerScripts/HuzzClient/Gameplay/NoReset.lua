--[[
	No respawning (owner, Oct 25: "make players not be able to respawn, it ruins the game mechanics"): Roblox's
	Reset Character button in the Esc menu is turned off for everyone, in the lobby and in a game. Roblox only takes
	this once its own menu has loaded, so it keeps trying for a while. (A fall off the map still brings you back as
	before: RoundService places the new body.)
]]
local StarterGui = game:GetService("StarterGui")

local M = {}

function M.start()
	task.spawn(function()
		for _ = 1, 30 do
			if pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end) then
				print("[Huzz] NoReset: the Reset Character button is off")
				return
			end
			task.wait(1)
		end
		warn("[Huzz] NoReset: couldn't turn the Reset Character button off")
	end)
end

return M
