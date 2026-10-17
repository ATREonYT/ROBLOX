--[[
	Where every animation's ID comes from (walk, run, dash, the 25 dances...):
	  1. the published ID (Config/Animations for moves, Config/Dances for dances), once the owner has published
	     them (tools/studio/publish-animations.lua);
	  2. otherwise, in Studio only, the raw animation itself: ServerStorage.HuzzAnimations holds the owner's
	     KeyframeSequences (tools/anim/extract_anims.luau; Bootstrap copies them to ReplicatedStorage in Studio
	     only, so players never download them), and KeyframeSequenceProvider turns one into a
	     temporary ID that plays in Studio tests. These temporary IDs never work in the live game;
	  3. otherwise "" (the game falls back to its built-in scripted moves, and a dance says it isn't ready).
	AnimationLibrary.id("Run"), AnimationLibrary.id("Dance_Floss", Dances.get("Floss").AnimationId).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(script.Parent.Config.Animations)

local AnimationLibrary = {}
local temp = {} -- name -> temporary Studio ID (or false: tried and failed)

function AnimationLibrary.id(name: string, published: string?): string
	local id = published or Animations[name]
	if type(id) == "string" and id ~= "" then
		return id
	end
	if temp[name] ~= nil then
		return temp[name] or ""
	end
	if RunService:IsStudio() then
		local folder = ReplicatedStorage:FindFirstChild("HuzzAnimations")
		if not folder then
			return "" -- (not copied over yet: ask again later, don't remember the miss)
		end
		temp[name] = false
		local seq = folder:FindFirstChild(name)
		if seq and seq:IsA("KeyframeSequence") then
			local ok, made = pcall(function()
				return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
			end)
			if ok and type(made) == "string" and made ~= "" then
				temp[name] = made
			end
		end
	end
	return temp[name] or ""
end

-- True when this animation can play here (published, or raw in Studio).
function AnimationLibrary.has(name: string, published: string?): boolean
	return AnimationLibrary.id(name, published) ~= ""
end

return AnimationLibrary
