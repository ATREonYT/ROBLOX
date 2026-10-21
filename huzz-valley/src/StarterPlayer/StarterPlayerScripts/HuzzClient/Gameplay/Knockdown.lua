--[[
	Plays a caught player's fall and keeps them lying flat (Shared/DownMotion)
	while their character has the DownedAt attribute (set by the server's
	KnockdownService). Runs after Roblox's animations each frame, so the limbs
	blend from whatever animation was playing into the sprawl. When they get up
	(revived, round over) the server stands them up at once; DownMotion.rise
	eases the body up from the floor over 0.4 s instead of popping upright.
	Knife pass 2: the catch lands first (DownMotion.HIT, a flinch) and the body carries on forward as it falls
	(DownedSlide studs, from the server).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local DownMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DownMotion"))
	local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"):WaitForChild("Round"))
	local active = {} -- character -> DownMotion record

	local function jointsOf(character)
		local list = {}
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") or d.ClassName == "AnimationConstraint" then
				table.insert(list, d)
			end
		end
		return list
	end

	require(script.Parent.Frame).on(40, function()
		local now = Workspace:GetServerTimeNow()
		local seen = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local at = character and character:GetAttribute("DownedAt")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if at and root then
				seen[character] = true
				local rec = active[character]
				local fresh = not rec
				if not rec then
					rec = DownMotion.new(jointsOf(character))
					active[character] = rec
				end
				rec.risingAt = nil -- (downed again while getting up)
				local feet, height = character:GetAttribute("DownedFeet"), character:GetAttribute("DownedHeight")
				rec.height = height or rec.height
				if feet and height then
					local path = DownMotion.rootCFrame(feet, height, now - at, character:GetAttribute("DownedSlide"))
					-- the fall starts where this screen had the body (no snap back to the server's spot), easing
					-- onto the server's path (Config/Round.Knockdown.Blend)
					if fresh then
						local off = root.Position - path.Position
						rec.offset = if off.Magnitude <= (Config.Knockdown.BlendMax or 0) then off else nil
					end
					if rec.offset then
						local w = DownMotion.blendAt(now - at)
						if w <= 0 then rec.offset = nil else path += rec.offset * w end
					end
					root.CFrame = path
				end
				DownMotion.step(rec, now - at)
			end
		end
		for character, rec in active do
			if not seen[character] then
				-- getting up: eases from lying flat back to standing (no pop), then hands the joints back
				rec.risingAt = rec.risingAt or os.clock()
				if not character.Parent or not DownMotion.rise(rec, os.clock() - rec.risingAt, rec.height) then
					active[character] = nil
					DownMotion.release(rec)
				end
			end
		end
	end)
end

return M
