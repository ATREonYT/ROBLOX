--!strict
-- Every sound the game makes, on or off in one place (brief 18: "remove these bad sound effects, we will work on better
-- sound effects later"). Each script that makes a Sound checks Enabled first: while it is false nothing is created and
-- nothing plays (shots and hits, gates, waves, goals, shoe boxes, the street's ambience). Roblox's own character sounds
-- (footsteps, jumps) are not the game's and stay.
--   Sound.Enabled          false: silent game
--   Sound.new(id, volume, parent, props?)  a Sound, or nil while sounds are off
--   Sound.play(sound, pitch?)              plays it (nil-safe; nothing while off)
local Sound = {}
Sound.Enabled = false

function Sound.new(id: string, volume: number?, parent: Instance?, props: { [string]: any }?): Sound?
	if not Sound.Enabled then return nil end
	local s = Instance.new('Sound')
	s.SoundId = id
	s.Volume = volume or 0.5
	for k, v in props or {} do (s :: any)[k] = v end
	s.Parent = parent
	return s
end

function Sound.play(s: Sound?, pitch: number?)
	if not Sound.Enabled or not s then return end
	if pitch then s.PlaybackSpeed = pitch end
	s:Play()
end

return Sound
