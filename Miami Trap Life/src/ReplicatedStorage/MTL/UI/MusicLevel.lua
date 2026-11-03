--!strict
-- Music loudness matching (client). Every song plays at the same perceived level, and a bit quieter overall.
--   MusicLevel.attach(sound)   call right after making a music Sound (cutscene tracks, window radios, car bass)
-- How: an EqualizerSoundEffect on the Sound with all three bands at the same gain = a clean volume trim that never
-- fights the code that fades Sound.Volume. While the track's first seconds play we read Sound.PlaybackLoudness
-- (divided by Volume) and set the trim so the track lands on TARGET. Each track is measured once per session.
local MusicLevel = {}

MusicLevel.TARGET = 220 -- PlaybackLoudness per unit of Volume every track is matched to (Play log prints real values)
MusicLevel.TRIM_DB = -4 -- Alex: "not so loud". Applied to every song on top of the matching.
MusicLevel.MIN_DB = -12 -- never cut a track more than this...
MusicLevel.MAX_DB = 4 -- ...or boost it more than this (quiet tracks would just get noisy)
MusicLevel.MEASURE_SECONDS = 6
MusicLevel.LOG = true

local measured: { [string]: number } = {} -- SoundId -> matching gain in dB
local measuring: { [string]: boolean } = {}

local function setGain(eq: EqualizerSoundEffect, db: number)
	eq.LowGain = db
	eq.MidGain = db
	eq.HighGain = db
end

local function eqFor(s: Sound): EqualizerSoundEffect
	local eq = s:FindFirstChild("MTL_Level") :: EqualizerSoundEffect?
	if not eq then
		local n = Instance.new("EqualizerSoundEffect")
		n.Name = "MTL_Level"
		n.Priority = 100
		n.Parent = s
		eq = n
	end
	return eq :: EqualizerSoundEffect
end

function MusicLevel.attach(s: Sound)
	local eq = eqFor(s)
	setGain(eq, MusicLevel.TRIM_DB)
	task.spawn(function()
		-- callers may attach before setting SoundId: wait for it
		local t00 = os.clock()
		while s.Parent ~= nil and s.SoundId == "" and os.clock() - t00 < 5 do
			task.wait(0.1)
		end
		local id = s.SoundId
		if id == "" then
			return
		end
		local known = measured[id]
		if known then
			setGain(eq, MusicLevel.TRIM_DB + known)
			return
		end
		if measuring[id] then
			return
		end
		measuring[id] = true
		local t0 = os.clock()
		while s.Parent and not s.IsPlaying and os.clock() - t0 < 15 do
			task.wait(0.25)
		end
		local sum, n = 0, 0
		local lastVol = -1
		local tEnd = os.clock() + MusicLevel.MEASURE_SECONDS + 4
		while s.Parent and s.IsPlaying and n < MusicLevel.MEASURE_SECONDS * 5 and os.clock() < tEnd do
			task.wait(0.2)
			local v = s.Volume
			local pl = s.PlaybackLoudness
			-- only steady stretches (not during a fade) with real signal
			if v > 0.05 and math.abs(v - lastVol) < 0.005 and pl > 2 then
				sum += pl / v
				n += 1
			end
			lastVol = v
		end
		measuring[id] = nil
		if n < 8 then
			if MusicLevel.LOG then
				print(string.format("[MTL Music] %s not measured (%d steady samples, playing=%s); trim only", id, n, tostring(s.IsPlaying)))
			end
			return -- not enough signal (stopped early / far away); the next attach measures again
		end
		local avg = sum / n
		local db = math.clamp(20 * math.log10(MusicLevel.TARGET / avg), MusicLevel.MIN_DB, MusicLevel.MAX_DB)
		measured[id] = db
		if MusicLevel.LOG then
			print(string.format("[MTL Music] %s loudness %.0f per volume -> %+.1f dB (+ trim %d dB)", id, avg, db, MusicLevel.TRIM_DB))
		end
		-- glide to the matched level so the change isn't heard as a jump
		if eq.Parent then
			local from = eq.MidGain
			local to = MusicLevel.TRIM_DB + db
			for i = 1, 20 do
				task.wait(0.05)
				if not eq.Parent then
					break
				end
				setGain(eq, from + (to - from) * i / 20)
			end
		end
	end)
end

return MusicLevel
