--[[
	Your companion girl dances when you dance (owner: "make the anime characters dance when you dance").
	  - Yours: UI/DancePlayer says which dance you started (or nil when you stop); she dances the same one, in step,
	    and stops when you do. The dance is read as a KeyframeSequence (in Studio: ReplicatedStorage.HuzzAnimations;
	    live: ReplicatedStorage.HuzzDanceMoves, where the server puts a dance's own moves the first time someone
	    starts it while it has no published ID (HuzzServer/ActionService), else KeyframeSequenceProvider with the
	    published ID in Config/Dances) and put on her R6 body by
	    Shared/DanceRetarget. If it can't be read, she does a cute built-in dance instead.
	  - Other players': their character's HuzzDance / HuzzDanceAt (the dance and its beat, set by the server) say
	    which dance and where in it, so their girl dances on their beat on every screen (synced dancing, owner
	    Oct 19: Gameplay/DanceSync shows the dancers themselves on the same beat). Before those arrive, a looped
	    Action track playing on their avatar (a dance; the huss and the stab aren't looped) is read instead: the same
	    dance at the same moment when this screen knows its ID, else the built-in dance.
	Gameplay/Auras moves the girls and calls CompanionDance.step() after her walk pose each frame.
]]
local CompanionDance = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Library = require(Shared.AnimationLibrary)
local Sampler = require(Shared.KeyframeSampler)
local Retarget = require(Shared.DanceRetarget)

local FADE = 0.3 -- seconds in and out
local R15_HEIGHT = 5.2 -- an R15 avatar, for scaling the hips' bounce to her size

local mine = { id = nil :: string?, at = 0, pos = nil :: (() -> number?)? } -- your dance (UI/DancePlayer)
local anims = {} -- dance id -> sampled anim, or false (couldn't read it), or "loading"
local byAnimId: { [string]: string }? = nil -- AnimationId -> dance id (for other players' tracks)
local records = {} -- Player -> { weight, id, t, procedural, scanAt }

-- The dance as a sampled KeyframeSequence (nil while loading or when it can't be read).
local function animFor(id: string)
	local a = anims[id]
	if a ~= nil then
		return if type(a) == "table" then a else nil
	end
	local folder = ReplicatedStorage:FindFirstChild("HuzzAnimations")
	local seq = folder and folder:FindFirstChild("Dance_" .. id)
	if not seq then -- (live, not published: the moves the server shares once someone dances it)
		local shared = ReplicatedStorage:FindFirstChild("HuzzDanceMoves")
		seq = shared and shared:FindFirstChild("Dance_" .. id)
	end
	if seq and seq:IsA("KeyframeSequence") then
		local ok, loaded = pcall(Sampler.load, seq)
		anims[id] = if ok and loaded and loaded.length > 0 then loaded else false
		return anims[id] or nil
	end
	local d = Dances.get(id)
	local published = if d then Library.published("Dance_" .. id, d.AnimationId) else ""
	if published == "" then
		return nil -- (not kept: its moves may still be on their way, HuzzDanceMoves)
	end
	anims[id] = "loading"
	task.spawn(function()
		local ok, got = pcall(function()
			return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(published)
		end)
		local loaded = nil
		if ok and got then
			local ok2, l = pcall(Sampler.load, got)
			loaded = ok2 and l or nil
		end
		anims[id] = if loaded and loaded.length > 0 then loaded else false
	end)
	return nil
end

-- Which dance an AnimationId is (built once, the first time another player dances).
local function danceOfAnim(animId: string): string?
	if not byAnimId then
		local map = {}
		for _, d in Dances.List do
			local id = Library.id("Dance_" .. d.Id, d.AnimationId)
			if id ~= "" then
				map[id] = d.Id
			end
		end
		byAnimId = map
	end
	return (byAnimId :: any)[animId]
end

-- Another player's dance right now: (dance id or "?" for an unknown dance, its time) or nil.
local function scanOther(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local carryArms = Library.id("CarryArms")
	for _, t in animator:GetPlayingAnimationTracks() do
		if t.Looped and t.Priority == Enum.AnimationPriority.Action and t.WeightTarget > 0.5 then
			local animId = t.Animation and t.Animation.AnimationId or ""
			if animId ~= "" and animId ~= carryArms then
				return danceOfAnim(animId) or "?", t.TimePosition
			end
		end
	end
	return nil
end

-- The dance as a sampled KeyframeSequence, for Gameplay/DanceSync too (nil while loading or when it can't be read).
CompanionDance.anim = animFor

function CompanionDance.start()
	local ok, DancePlayer = pcall(function()
		return require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("DancePlayer"))
	end)
	if ok and DancePlayer then
		DancePlayer.changed(function(id)
			mine.id, mine.at = id, os.clock()
			if id then
				animFor(id) -- (start loading it now)
			end
		end)
		mine.id = DancePlayer.current()
		mine.pos = DancePlayer.position
	end
end

-- Is this player's girl dancing (or fading out of it)? Auras keeps her beside you while she is.
function CompanionDance.active(p: Player): boolean
	local r = records[p]
	return r ~= nil and r.id ~= nil
end

--[[ One frame for one player's girl, after her walk pose: J = her joints (Shared/GirlMotion.joints), height = her
	height in studs, standing = she isn't hurrying after you (no dancing while she runs to catch up). ]]
function CompanionDance.step(p: Player, character: Model?, J, dt: number, height: number, standing: boolean)
	local r = records[p]
	if not r then
		r = { weight = 0, id = nil, t = 0, scanAt = 0, seen = nil, seenT = nil }
		records[p] = r
	end
	-- what is the player dancing?
	local id, at = nil, nil
	if p == Players.LocalPlayer then
		id = mine.id
		at = if id then ((mine.pos and mine.pos()) or (os.clock() - mine.at)) else nil -- (your track's time: in step)
	elseif character and type(character:GetAttribute("HuzzDance")) == "string" and type(character:GetAttribute("HuzzDanceAt")) == "number" then
		-- their dance and its beat: the same moment on every screen
		id = character:GetAttribute("HuzzDance")
		at = workspace:GetServerTimeNow() - character:GetAttribute("HuzzDanceAt")
		local anim = animFor(id)
		if anim and anim.length > 0 then
			at %= anim.length
		end
	elseif character then
		local now = os.clock()
		if now - r.scanAt > 0.25 then
			r.scanAt = now
			r.seen, r.seenT = scanOther(character)
			r.seenAt = now
		end
		id = r.seen
		at = if r.seenT then r.seenT + (now - (r.seenAt or now)) else nil
	end
	local want = id ~= nil and standing
	if want then
		if r.id ~= id then
			r.id = id
		end
		r.t = at or (r.t + dt)
	else
		r.t += dt -- (keeps moving while she fades out)
	end
	r.weight = math.clamp(r.weight + (if want then dt else -dt) / FADE, 0, 1)
	if r.weight <= 0 then
		r.id = nil
		return
	end
	local w = r.weight * r.weight * (3 - 2 * r.weight)
	local scale = height / R15_HEIGHT
	local anim = r.id and r.id ~= "?" and animFor(r.id)
	if anim then
		Retarget.apply(J, Sampler.sample(anim, r.t), w, scale)
	else
		Retarget.procedural(J, r.t, w, scale)
	end
end

function CompanionDance.forget(p: Player)
	records[p] = nil
end

return CompanionDance
