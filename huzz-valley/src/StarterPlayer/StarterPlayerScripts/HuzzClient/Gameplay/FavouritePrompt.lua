--[[
	Roblox's own "add this experience to your favourites?" pop-up (owner, Oct 23 14:03: "make the thing on roblox pop up
	asking you if you want to add the game to your favourites randomly"): AvatarEditorService:PromptSetFavorite on this
	game's place. Once per visit, at a random moment Config/Group.FavouriteAfter seconds in, only in the lobby with no
	window open (like the group window: never over a round), and never when it's already one of your favourites.
	Saying no is fine: it doesn't ask again this visit and gives or takes nothing. At most Config/Group.FavouriteTimes
	times ever (owner, Oct 25: "only pop up once or twice"): the save counts each one (ActionService FavAsked). In Studio Roblox has no real
	game to favourite: it only prints a [Huzz] line. Every call is in a pcall.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local okAES, AvatarEditorService = pcall(function() return game:GetService("AvatarEditorService") end)
	if not okAES then return end
	local Group = require(ReplicatedStorage:WaitForChild("Shared").Config.Group)
	local ModalManager = require(script.Parent.Parent.UI.ModalManager)
	local State = require(script.Parent.Parent.UI.State)
	local Net = require(ReplicatedStorage.Shared.Net)
	local player = Players.LocalPlayer
	local range = Group.FavouriteAfter or { 240, 540 }

	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		return ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher"
	end
	local function already(): boolean
		local ok, yes = pcall(function()
			return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
		end)
		return ok and yes == true
	end

	task.delay(math.random(range[1], range[2]), function()
		while not free() do task.wait(5) end -- (a round or a window: the next lobby moment)
		if RunService:IsStudio() or game.PlaceId == 0 then
			print("[Huzz] favourites: would ask \"add this game to your favourites?\" now (only in the live game)")
			return
		end
		if already() then return end
		while not State.data.Loaded do task.wait(1) end
		if (tonumber(State.data.FavAsked) or 0) >= (Group.FavouriteTimes or 2) then return end
		pcall(function() (Net.get("Action") :: RemoteFunction):InvokeServer("FavAsked") end)
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
end

return M
