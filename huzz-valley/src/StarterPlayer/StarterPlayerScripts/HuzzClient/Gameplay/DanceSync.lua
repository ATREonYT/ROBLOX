--[[
	Synced dancing (owner, Oct 19: "make synced dancing"). The rule, simply: every dance has a beat, the server time
	it started (the character's HuzzDanceAt, set by the server from the Dance remote, UI/DancePlayer); anyone who
	starts the same dance within 30 studs of a dancer takes that dancer's beat; and on EVERY screen each dancer is
	shown at (server time now - their beat), so people doing the same dance move together everywhere, and their girls
	dance with them (Gameplay/CompanionDance reads the same two attributes).
	  - A dance track that reached this screen (your own, or another player's replicated one) is kept on its beat:
	    nudged when it drifts more than 0.12 s (Roblox starts a replicated track whenever it arrives, and a published
	    dance can take a moment to load, so without this two in-step dancers could look out of step on a third screen).
	  - Another player's dance that can't play on this screen (Studio's stand-in animation IDs only play for the
	    player who made them, and a published one may still be loading): drawn here by hand from the dance's
	    KeyframeSequence (CompanionDance.anim: ReplicatedStorage.HuzzAnimations in Studio, HuzzDanceMoves live while
	    it isn't published, else KeyframeSequenceProvider) on their joints (R6 since Oct 22: the owner's R6 dances on
	    R6 bodies; R15 dances on R15 ones), so everyone sees everyone dance.
	  - Your own dance in the live game while it has no published ID (UI/DancePlayer.handBeat; owner, Oct 20 15:13:
	    "inside the actual roblox game, not studio, make it so that dances are available"): drawn the same way on
	    your own joints, on its beat (no track exists to play).
	  - Sync dance: walk up to someone dancing (not in a round, not in a cutscene) and press E or tap "SYNC DANCE"
	    (also while you dance something else or the same dance off their beat; Oct 22 18:54): you start their dance on
	    their beat. Only a dance you own: otherwise it says where to get it (nothing sold from here).
	Gameplay/Frame order 9: after the walk pack (PlayerMoves 8, which steps aside while someone dances), before the
	huss pose (RunAnimator 10) and the carry (20).
]]
local M = {}

local PARTS = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local PARTS_R6 = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DRIFT = 0.12 -- seconds a track may drift off its beat before it's nudged back
local FADE = 0.25 -- seconds a hand-drawn dance fades in and out
local DRAW_RANGE = 120 -- studs from the camera: hand-drawn dances further away aren't drawn
local PROMPT_NAME = "HuzzDanceTogether"

-- Where a looped dance is at a server time, given its beat (pure: tests/DanceSync.spec.luau).
function M.timeAt(now: number, beat: number, length: number): number
	if length <= 0 then
		return 0
	end
	return (now - beat) % length
end

-- How far a track's time is off its beat, wrapped round the loop (-length/2 .. length/2).
function M.offBy(position: number, want: number, length: number): number
	if length <= 0 then
		return 0
	end
	return (position - want + length / 2) % length - length / 2
end

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Dances = require(Shared.Config.Dances)
	local Library = require(Shared.AnimationLibrary)
	local Sampler = require(Shared.KeyframeSampler)
	local CompanionDance = require(script.Parent.CompanionDance)
	local Frame = require(script.Parent.Frame)
	local UI = script.Parent.Parent:WaitForChild("UI")
	local okPlayer, DancePlayer = pcall(function() return require(UI:WaitForChild("DancePlayer", 10)) end)
	local okToast, Toast = pcall(function() return require(UI:WaitForChild("Toast", 10)) end)
	local carryArms = Library.id("CarryArms")

	local recs = {} -- character -> { motors, k, weight, written, base, track, scanAt, prompt }

	local function danceOf(character: Model): (string?, number?)
		local id, at = character:GetAttribute("HuzzDance"), character:GetAttribute("HuzzDanceAt")
		if type(id) == "string" and type(at) == "number" and Dances.get(id) then
			return id, at
		end
		return nil, nil
	end

	-- Their dance track on this screen, if one is really playing (a looped Action track with a length).
	local function trackOf(character: Model): AnimationTrack?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return nil
		end
		local found = nil
		pcall(function()
			for _, t in animator:GetPlayingAnimationTracks() do
				if t.Looped and t.Priority == Enum.AnimationPriority.Action and t.WeightTarget > 0.5 and t.Length > 0
					and not (t.Animation and t.Animation.AnimationId == carryArms) then
					found = t
				end
			end
		end)
		return found
	end

	-- Each part's joints: Motor6Ds, or on Roblox's newer joints (his avatar, Oct 20) AnimationConstraints, which hold the
	-- part by an attachment instead of Part1 and are sometimes doubled up (all of them get the pose). A list of
	-- { part name, joint }; nil while a part has none (still streaming in: tried again next scan).
	local function motorsOf(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local r6 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
		if not (humanoid and root) or (not r6 and humanoid.RigType ~= Enum.HumanoidRigType.R15) then
			return nil
		end
		local want = {}
		for _, name in (if r6 then PARTS_R6 else PARTS) do
			want[name] = false
		end
		local list = {}
		for _, j in character:GetDescendants() do
			local part = nil
			if j:IsA("Motor6D") then
				part = j.Part1
			elseif j.ClassName == "AnimationConstraint" then
				local a1 = (j :: any).Attachment1
				part = a1 and a1.Parent
			end
			if part and part.Parent == character and want[part.Name] ~= nil then
				want[part.Name] = true
				table.insert(list, { name = part.Name, joint = j })
			end
		end
		for _, found in want do
			if not found then
				return nil
			end
		end
		return list, if r6 then 1 else math.clamp((humanoid.HipHeight + root.Size.Y / 2) / 3, 0.5, 2)
	end

	-- (written / base are keyed by the joint, in a plain table emptied on release)
	local function release(rec)
		for m, base in rec.base do
			if m.Parent and rec.written[m] == m.Transform then
				m.Transform = base
			end
		end
		rec.written, rec.base = {}, {}
	end

	local function write(rec, pose, w)
		for _, entry in rec.motors do
			local name, m = entry.name, entry.joint
			local cf = pose[name]
			if cf and m.Parent then
				if name == "LowerTorso" then
					cf = CFrame.new(cf.Position * rec.k) * cf.Rotation -- (the hips' bounce, to their size)
				end
				local current = m.Transform
				local base = if rec.written[m] == current then rec.base[m] else current
				rec.base[m] = base
				m.Transform = if w >= 0.999 or not base then cf else base:Lerp(cf, w)
				rec.written[m] = m.Transform -- read back: Roblox stores CFrames as float32
			end
		end
	end

	-- Roblox swaps the avatar's own limbs in after the body appears: joints that left it mean a new look.
	local function stale(rec): boolean
		for _, entry in rec.motors do
			if not entry.joint:IsDescendantOf(game) then
				return true
			end
		end
		return false
	end

	-- Your own dance is drawn here when it has no track (DancePlayer.handBeat: live, not published).
	local function mineByHand(id: string?): boolean
		return id ~= nil and okPlayer and DancePlayer ~= nil and DancePlayer.handBeat ~= nil
			and DancePlayer.handBeat() ~= nil and DancePlayer.current() == id
	end

	-- "Sync dance": a button on another dancer, for you while you're free to dance. Also while you're dancing
	-- something else, or the same dance off their beat (owner, Oct 22 18:54: "make a button to sync dancing with
	-- another person if he is dancing and you are close to him"); gone once you're in step with them.
	local function canJoin(): boolean
		local me = Players.LocalPlayer
		local role = me:GetAttribute("HuzzRole")
		if role == "Runner" or role == "Catcher" or me:GetAttribute("HuzzCinematic") == true or me:GetAttribute("HuzzChoosing") == true then
			return false
		end
		return okPlayer and DancePlayer ~= nil
	end
	local function inStep(character: Model, id: string?): boolean
		local mine = Players.LocalPlayer.Character
		local at = character:GetAttribute("HuzzDanceAt")
		return id ~= nil and mine ~= nil and DancePlayer.current() == id and type(at) == "number"
			and math.abs((mine:GetAttribute("HuzzDanceAt") or -1) - at) < 0.05
	end
	local function setPrompt(rec, character: Model, id: string?)
		local want = id ~= nil and canJoin() and not inStep(character, id)
		local root = character:FindFirstChild("HumanoidRootPart")
		if want and root then
			local prompt = rec.prompt
			if not (prompt and prompt.Parent == root) then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = PROMPT_NAME
				prompt.ActionText = "SYNC DANCE"
				prompt.KeyboardKeyCode = Enum.KeyCode.E -- (owner, Oct 23: "make everything be E"; was F)
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.HoldDuration = 0
				prompt.Triggered:Connect(function()
					local dance = character:GetAttribute("HuzzDance")
					if type(dance) ~= "string" or not canJoin() or not (okPlayer and DancePlayer) then
						return
					end
					if not DancePlayer.owned(dance) then
						if okToast and Toast then
							local d = Dances.get(dance)
							Toast.show(`Get {d and d.Name or "this dance"} in Dances to join in!`)
						end
						return
					end
					local beat = character:GetAttribute("HuzzDanceAt")
					local ok, why = DancePlayer.play(dance, if type(beat) == "number" then beat else nil) -- (on their beat)
					if not ok and okToast and Toast then
						Toast.show(why or "That dance couldn't start.")
					end
				end)
				prompt.Parent = root
				rec.prompt = prompt
			end
			local d = Dances.get(id :: string)
			prompt.ObjectText = d and d.Name or ""
		elseif rec.prompt then
			rec.prompt:Destroy()
			rec.prompt = nil
		end
	end

	Frame.on(9, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local me = Players.LocalPlayer
		local seen = {}
		for _, p in Players:GetPlayers() do
			local character = p.Character
			if character and character.Parent then
				seen[character] = true
				local rec = recs[character]
				if not rec then
					rec = { weight = 0, written = {}, base = {}, scanAt = -math.huge }
					recs[character] = rec
				end
				local id, beat = danceOf(character)
				-- 4 times a second: the track, the joints, the prompt
				if clock - rec.scanAt >= 0.25 then
					rec.scanAt = clock
					rec.track = if id then trackOf(character) else nil
					if rec.motors and stale(rec) then
						release(rec)
						rec.motors = nil
					end
					if (p ~= me or mineByHand(id)) and id and not rec.track and not rec.motors then
						rec.motors, rec.k = motorsOf(character)
					end
					if p ~= me then
						pcall(setPrompt, rec, character, id)
					end
				end
				-- a track on screen: keep it on its beat
				local track = rec.track
				if id and beat and track then
					pcall(function()
						local length = track.Length
						local want = M.timeAt(now, beat, length)
						if math.abs(M.offBy(track.TimePosition, want, length)) > DRIFT then
							track.TimePosition = want
						end
					end)
				end
				-- no track on this screen (another player's): draw it by hand
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local close = root ~= nil and (not camPos or (root.Position - camPos).Magnitude < DRAW_RANGE)
				local draw = (p ~= me or mineByHand(id)) and id ~= nil and track == nil and rec.motors ~= nil and close
				local anim = draw and CompanionDance.anim(id :: string)
				rec.weight = math.clamp(rec.weight + (if anim then dt else -dt) / FADE, 0, 1)
				if anim then
					rec.anim, rec.beat = anim, beat
				end
				if rec.weight > 0 and rec.anim and rec.motors then
					local w = rec.weight * rec.weight * (3 - 2 * rec.weight)
					pcall(write, rec, Sampler.sample(rec.anim, M.timeAt(now, rec.beat or now, rec.anim.length)), w)
				elseif next(rec.written) then
					release(rec)
					rec.anim = nil
				end
			end
		end
		for character, rec in recs do
			if not seen[character] then
				if rec.prompt then
					rec.prompt:Destroy()
				end
				recs[character] = nil -- (a plain table, cleared when the character goes: never a weak table)
			end
		end
	end)
end

return M
