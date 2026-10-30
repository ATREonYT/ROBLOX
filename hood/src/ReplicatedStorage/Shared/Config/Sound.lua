--!strict
-- Every sound the game makes, on or off in one place (brief 18: "remove these bad sound effects, we will work on better
-- sound effects later"). Each script that makes a Sound checks Enabled first: while it is false nothing is created and
-- nothing plays (shots and hits, gates, waves, goals, shoe boxes, the street's ambience). Roblox's own character sounds
-- (footsteps, jumps) are not the game's and stay.
--   Sound.Enabled          false: silent game
--   Sound.new(id, volume, parent, props?)  a Sound, or nil while sounds are off
--   Sound.play(sound, pitch?)              plays it (nil-safe; nothing while off)
-- Our own footsteps (Oct 27, the owner: "make custom walking sounds ... not the original Roblox ones, and make them sound
-- exactly when a step is taken on screen"): HoodClient/Footsteps plays them when a foot lands (Shared/FootstepRules).
-- They have their own switch, Footsteps, so they play while the rest stays off. The sounds are made by
-- hood/tools/sounds/make_footsteps.py (hood/art/sounds/Step*.ogg); hood/tools/upload_assets.py writes their ids into
-- Steps below. Until a set has ids, Roblox's own footsteps stay on.
--   Sound.Footsteps        true: our footsteps play (once they have ids)
--   Sound.Steps            the ids, by file name: StepHard1-3 (floors, streets), StepSoft1-3 (grass, dirt, sand)
--   Sound.step(id, volume, parent)         a footstep Sound, or nil while Footsteps is off or the id is empty
local Sound = {}
Sound.Enabled = false
Sound.Footsteps = true
Sound.Steps = {
	StepHard1 = '',
	StepHard2 = '',
	StepHard3 = '',
	StepSoft1 = '',
	StepSoft2 = '',
	StepSoft3 = '',
}

function Sound.new(id: string, volume: number?, parent: Instance?, props: { [string]: any }?): Sound?
	if not Sound.Enabled then return nil end
	local s = Instance.new('Sound')
	s.SoundId = id
	s.Volume = volume or 0.5
	for k, v in props or {} do (s :: any)[k] = v end
	s.Parent = parent
	return s
end

function Sound.step(id: string?, volume: number?, parent: Instance?): Sound?
	if not Sound.Footsteps or not id or id == '' then return nil end
	local s = Instance.new('Sound')
	s.SoundId = id
	s.Volume = volume or 0.4
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 60
	s.Parent = parent
	return s
end

function Sound.play(s: Sound?, pitch: number?)
	if not Sound.Enabled or not s then return end
	if pitch then s.PlaybackSpeed = pitch end
	s:Play()
end

return Sound
