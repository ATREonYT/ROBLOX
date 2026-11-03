--!strict
-- Small "feel" helpers for big moments (helper module, not booted: required by JobController, GunController,
-- InteractFX). Numbers: Config/Movement.Juice.
--   Juice.hit("Perfect" | "Kill" | "Prompt")   hit-stop + camera punch from the config row
--   Juice.hitStop(seconds)                      your own character's animations freeze for a beat (local only)
-- Hit-stop on Roblox can't pause physics or other players, so it freezes the local character's animation tracks
-- (the part your eye is on) for 40-50 ms while the camera punches; that reads as an impact.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local MovementController = require(script.Parent.MovementController)

local Juice = {}

local stopUntil = 0

function Juice.hitStop(seconds: number)
	if seconds <= 0 then
		return
	end
	local c = Players.LocalPlayer.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local now = os.clock()
	if now < stopUntil then
		return -- already frozen; don't stack
	end
	stopUntil = now + seconds
	local frozen: { [AnimationTrack]: number } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		frozen[track] = track.Speed
		track:AdjustSpeed(0)
	end
	task.delay(seconds, function()
		for track, speed in frozen do
			if track.IsPlaying and track.Speed == 0 then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

function Juice.hit(kind: string)
	local row = (Movement.Juice :: any)[kind]
	if not row then
		return
	end
	if row.hitStop then
		Juice.hitStop(row.hitStop)
	end
	if row.pitch or row.fov then
		MovementController.punch(row.pitch or 0, row.fov)
	end
end

return Juice
