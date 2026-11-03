-- [SFX thread] Patches the one-shot sound helpers in the controllers to go through UI/Sfx (mute + length cap).
-- Plain find/replace, one hit each, on the LIVE Studio scripts (so other threads' newer edits are kept).
-- Run tools/SfxModulePatch.lua (UI/Sfx) first. Re-runnable: a pair already applied counts as done.
local P = {
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.JobFX", [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
]=], [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.JobFX", [=[	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = math.min(pitch or 1, 1.05) -- never pitch up into squeaky territory (Alex: no high-pitched sounds)
	SoundService:PlayLocalSound(s)
	task.delay(3, function()
		s:Destroy()
	end)
end]=], [=[	-- through UI/Sfx: respects Settings > Sound effects, caps length (~1 s), pitch capped at 1.05 (no squeaky sounds)
	Sfx.playId(id, { volume = volume or 0.5, pitch = pitch })
end]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.MissionController", [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
]=], [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.MissionController", [=[	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
	task.delay(3, function()
		s:Destroy()
	end)
end

local function action]=], [=[	Sfx.playId(id, { volume = volume or 0.5 })
end

local function action]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.PropertyController", [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
]=], [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.PropertyController", [=[	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
	task.delay(3, function()
		s:Destroy()
	end)
end]=], [=[	Sfx.playId(id, { volume = volume or 0.5 })
end]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.WayfindingController", [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
]=], [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.WayfindingController", [=[				local s = Instance.new("Sound")
				s.SoundId = Theme.Sounds.Arrive
				s.Volume = 0.4
				SoundService:PlayLocalSound(s)
				task.delay(2, function()
					s:Destroy()
				end)]=], [=[				Sfx.playId(Theme.Sounds.Arrive, { volume = 0.4 })]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.HUDController", [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
]=], [=[local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.HUDController", [=[	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
	task.delay(3, function()
		s:Destroy()
	end)
end]=], [=[	Sfx.playId(id, { volume = volume or 0.5 })
end]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.HUDController", [=[		sound(Theme.Sounds and Theme.Sounds.LevelUp)]=], [=[		Sfx.play("LevelUp") -- short "ding-up" (Theme.Sfx.LevelUp), not a music sting]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.HUDController", [=[	row.Parent = list
	Motion.tween(row, Motion.Normal]=], [=[	row.Parent = list
	Sfx.play("Toast")
	Motion.tween(row, Motion.Normal]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.CutsceneController", [=[			s.Name = "MTL_Music"
]=], [=[			s.Name = "MTL_Music"
			require(ReplicatedStorage.MTL.UI.MusicLevel).attach(s) -- matched loudness, a bit quieter (SFX thread)
]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.AmbientSound", [=[	s.Volume = e.def.volume
	local maxD = e.def.maxDistance or 60]=], [=[	s.Volume = e.def.volume
	if e.kind == "Window" or e.kind == "CarMusic" then
		require(ReplicatedStorage.MTL.UI.MusicLevel).attach(s) -- songs matched in loudness, a bit quieter (SFX thread)
	end
	local maxD = e.def.maxDistance or 60]=] },
	{ "StarterPlayer.StarterPlayerScripts.MTL.Controllers.CutsceneController", [=[	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	SoundService:PlayLocalSound(s)
	task.delay(4, function()
		s:Destroy()
	end)
end]=], [=[	-- through UI/Sfx: respects Settings > Sound effects, capped (cutscene one-shots may run up to 2.5 s)
	require(ReplicatedStorage.MTL.UI.Sfx).playId(id, { volume = volume or 0.6, max = 2.5 })
end]=] },
}
local function get(path)
	local cur = game
	for name in string.gmatch(path, "[^%.]+") do
		cur = cur and (if cur == game then game:GetService(name) else cur:FindFirstChild(name))
	end
	return cur
end
local srcs, report = {}, {}
for i, p in P do
	local scr = get(p[1])
	if not scr then
		table.insert(report, i .. " " .. p[1] .. ": SCRIPT MISSING")
		continue
	end
	local src = srcs[scr] or scr.Source
	local s = string.find(src, p[2], 1, true)
	if s and not string.find(src, p[2], s + #p[2], true) then
		src = string.sub(src, 1, s - 1) .. p[3] .. string.sub(src, s + #p[2])
		table.insert(report, i .. " " .. p[1] .. ": ok")
	elseif s then
		table.insert(report, i .. " " .. p[1] .. ": MORE THAN ONE MATCH, skipped")
	elseif string.find(src, p[3], 1, true) then
		table.insert(report, i .. " " .. p[1] .. ": already done")
	else
		table.insert(report, i .. " " .. p[1] .. ": NOT FOUND")
	end
	srcs[scr] = src
end
for scr, src in srcs do
	scr.Source = src
end
return table.concat(report, "\n")
