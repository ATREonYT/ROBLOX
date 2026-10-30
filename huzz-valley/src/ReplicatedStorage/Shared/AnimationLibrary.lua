--[[
	Where every animation's ID comes from (walk, run, dash, the 25 dances...):
	  1. the published ID: Config/AnimationIds (written by the owner's one-time helper,
	     ServerStorage.HuzzStudioTools.PublishAnimations), else Config/Animations for moves and Config/Dances for
	     dances (typed in by hand);
	  2. otherwise, in Studio only, the raw animation itself: ServerStorage.HuzzAnimations holds the owner's
	     KeyframeSequences (tools/anim/extract_anims.luau; Bootstrap copies them to ReplicatedStorage in Studio
	     only, so players never download them), and KeyframeSequenceProvider turns one into a
	     temporary ID that plays in Studio tests. These temporary IDs never work in the live game;
	  3. otherwise "" (the game falls back to its built-in scripted moves, and a dance is drawn by hand on the
	     dancer's joints: UI/DancePlayer, Gameplay/DanceSync).
	AnimationLibrary.id("Run"), AnimationLibrary.id("Dance_Floss", Dances.get("Floss").AnimationId).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(script.Parent.Config.Animations)
local okIds, AnimationIds = pcall(function() return require(script.Parent.Config:FindFirstChild("AnimationIds") :: any) end)
if not okIds or type(AnimationIds) ~= "table" then AnimationIds = {} end

local AnimationLibrary = {}
local temp = {} -- name -> temporary Studio ID (or false: tried and failed)

-- The published ID only (never Studio's temporary one), or "".
function AnimationLibrary.published(name: string, published: string?): string
	for _, id in { AnimationIds[name], published or "", Animations[name] or "" } do
		if type(id) == "string" and id ~= "" then
			return id
		end
	end
	return ""
end

function AnimationLibrary.id(name: string, published: string?): string
	local id = AnimationLibrary.published(name, published)
	if id ~= "" then
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
