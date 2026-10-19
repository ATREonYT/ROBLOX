-- Plays a dance on your own avatar (your Animator, so everyone sees it), for the Dances window and the G wheel.
-- One dance at a time; starting another replaces it. Like Huss Valley's emotes, walking away stops it (after a
-- short grace, so the key press that started it can't), and so does a new character.
-- The animation comes from Shared/AnimationLibrary: the published ID, or in Studio the raw one.
-- In step: when someone within SYNC_RANGE is already doing the same dance (their character's HuzzDance /
-- HuzzDanceAt, set by the server from the Dance remote), yours starts on their beat, so you dance together.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local AnimationLibrary = require(Shared.AnimationLibrary)
local State = require(script.Parent.State)

local Net = require(Shared.Net)
-- each dance's song (owner, Oct 19: "find the sounds we can use for all of the dances"): Gameplay/Music plays it for
-- you only while you dance (Config/Dances Music -> Tracks) and dips the background under it
local okMusic, Music = pcall(function() return require(script.Parent.Parent:WaitForChild("Gameplay", 5):WaitForChild("Music", 5)) end)

local DancePlayer = {}
local SYNC_RANGE = 30 -- studs

-- When a dancer near you started this dance (server time), or nil.
local function partnerStart(id: string): number?
	local me = Players.LocalPlayer
	local mine = me and me.Character
	local root = mine and mine:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bestDist
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local at = c and c:GetAttribute("HuzzDanceAt")
		if p ~= me and r and c:GetAttribute("HuzzDance") == id and type(at) == "number" then
			local d = (r.Position - root.Position).Magnitude
			if d <= SYNC_RANGE and (not bestDist or d < bestDist) then best, bestDist = at, d end
		end
	end
	return best
end

local track: AnimationTrack? = nil
local playing: string? = nil
local startedAt = 0
local listeners: { (string?) -> () } = {}

local function emit()
	for _, fn in table.clone(listeners) do task.spawn(fn, playing) end
end

function DancePlayer.changed(fn: (string?) -> ())
	table.insert(listeners, fn)
end

function DancePlayer.current(): string?
	return playing
end

-- Where your dance is now (seconds into it), or nil: your companion follows it, so she stays in step too.
function DancePlayer.position(): number?
	local t = track
	if not t then return nil end
	local ok, pos = pcall(function() return t.TimePosition end)
	return if ok then pos else nil
end

function DancePlayer.owned(id: string): boolean
	return State.data.Dances[id] == true
end

-- Can this dance play here? (false + why, for the UI to say)
function DancePlayer.ready(id: string): (boolean, string?)
	local d = Dances.get(id)
	if not d then return false, "Unknown dance." end
	if not DancePlayer.owned(id) then return false, "locked" end
	if not AnimationLibrary.has("Dance_" .. id, d.AnimationId) then
		return false, "This dance isn't published yet (it plays in Studio tests)."
	end
	return true
end

function DancePlayer.stop()
	local t = track
	track, playing = nil, nil
	if t then pcall(function() t:Stop(0.25) end) end
	if okMusic and Music then pcall(Music.danceStop) end
	pcall(function() (Net.get("Dance") :: RemoteEvent):FireServer(nil) end)
	emit()
end

-- Returns true when it started, or false and a message.
function DancePlayer.play(id: string): (boolean, string?)
	local ok, why = DancePlayer.ready(id)
	if not ok then return false, why end
	local d = Dances.get(id) :: any
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return false, "Your avatar isn't ready yet." end
	local animation = Instance.new("Animation")
	animation.AnimationId = AnimationLibrary.id("Dance_" .. id, d.AnimationId)
	local loaded, made = pcall(function() return (animator :: Animator):LoadAnimation(animation) end)
	if not loaded or not made then return false, "That dance couldn't load." end
	if track then pcall(function() (track :: AnimationTrack):Stop(0.2) end) end
	made.Looped = true
	made.Priority = Enum.AnimationPriority.Action
	made:Play(0.25)
	track, playing, startedAt = made, id, os.clock()
	if okMusic and Music then pcall(Music.dance, id) end
	-- on the beat of anyone near already doing it, else from now
	local now = workspace:GetServerTimeNow()
	local beat = partnerStart(id) or now
	if beat < now then
		task.spawn(function()
			for _ = 1, 200 do -- (wait up to 5 s for the animation to load: a published one can take a moment)
				if made.Length > 0 or track ~= made then break end
				task.wait(0.025)
			end
			if track == made and made.Length > 0 then
				made.TimePosition = (workspace:GetServerTimeNow() - beat) % made.Length
			end
		end)
	end
	pcall(function() (Net.get("Dance") :: RemoteEvent):FireServer(id, beat) end)
	emit()
	return true
end

function DancePlayer.toggle(id: string): (boolean, string?)
	if playing == id then
		DancePlayer.stop()
		return true
	end
	return DancePlayer.play(id)
end

-- Walking away stops the dance (as Huss Valley's emotes); so does respawning.
local player = Players.LocalPlayer
if player then
	player.CharacterAdded:Connect(function()
		if playing then DancePlayer.stop() end
	end)
	RunService.Heartbeat:Connect(function()
		if not playing or os.clock() - startedAt < 0.4 then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0.2 then
			DancePlayer.stop()
		end
	end)
end

return DancePlayer
