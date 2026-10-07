-- Shot and hit sounds for the shooting ranges. Shoot.client plays them; anyone can audition them.
--   ShotSounds.init()            once per client: the 'Shots' SoundGroup under SoundService, pools, file probes
--   ShotSounds.play(kind, pitch) a shot ('Shot') or a hit (the target's Hit attribute: Ding, Tock, Glass, ...)
--   ShotSounds.demo()            plays every layer alone, then every kind whole, then 3 s of held Minigun fire on
--                                a gong, printing what each one is. Studio command bar (edit or play mode):
--                                require(game.ReplicatedStorage.Shared.ShotSounds).demo()
-- Roblox ships no gunshot, so each kind is a few client built-ins layered and pitched. The shot is clicks only
-- (the pings belong to the hits, so a shot and its hit are never two pings): a crack (paintball.wav, or
-- clickfast pitched down), a low body (clickfast further down) and a faint zing (swoosh.wav, or a very high,
-- very quiet click). Hits: Ding (steel plates, gongs, the spinner) is electronicpingshort alone, pitched by the
-- lane's tier and always well under the stage chime's pitch; Tock (boards) a low click and a low ping; Glass
-- and Tin a high ping and a click; Pop a snap; Ice a bright ping; Barrel a dull thud.
-- paintball.wav, glassbreak.wav, snap.wav and swoosh.wav may not exist in every client: each such layer starts
-- on its known-good fallback and switches to the first choice only once that has loaded. The file each layer
-- ended up on, and its pool size, are written on the SoundGroup as attributes (Shot1 = 'paintball.wav',
-- Shot1Pool = 4, ...), so Studio's Properties pane shows what loaded. Each layer's pool is sized from the
-- sound's real length at its slowest pitch, so a shot every 0.14 s never restarts a voice that is still
-- ringing. Paste uploaded ids into ShotSounds.SOUNDS to replace a whole kind.
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local RunService = game:GetService('RunService')

local ShotSounds = {}
ShotSounds.SOUNDS = { Shot = '', Ding = '', Tock = '', Glass = '', Tin = '', Pop = '', Ice = '', Barrel = '' }
ShotSounds.ORDER = { 'Shot', 'Ding', 'Tock', 'Glass', 'Tin', 'Pop', 'Ice', 'Barrel' }
local BUILTIN = 'rbxasset://sounds/'
local SPACING = 0.14 -- the fastest a layer is played again (Shoot.client's cooldown)
-- Each layer: { file, volume, playback speed, fallback = { file, volume, speed } }.
ShotSounds.LAYERS = {
	Shot = {
		{ 'paintball.wav', 0.3, 0.9, fallback = { 'clickfast.wav', 0.4, 0.6 } },
		{ 'clickfast.wav', 0.2, 0.42 },
		{ 'swoosh.wav', 0.08, 1.8, fallback = { 'clickfast.wav', 0.05, 2.2 } },
	},
	Ding = { { 'electronicpingshort.wav', 0.45, 0.5 } },
	Tock = { { 'clickfast.wav', 0.4, 0.55 }, { 'electronicpingshort.wav', 0.12, 0.4 } },
	Glass = { { 'glassbreak.wav', 0.4, 1.1, fallback = { 'electronicpingshort.wav', 0.3, 1.7 } }, { 'clickfast.wav', 0.25, 1.4 } },
	Tin = { { 'electronicpingshort.wav', 0.3, 1.25 }, { 'clickfast.wav', 0.3, 1.1 } },
	Pop = { { 'snap.wav', 0.45, 1.0, fallback = { 'clickfast.wav', 0.5, 1.6 } }, { 'swoosh.wav', 0.15, 2.0, fallback = { 'clickfast.wav', 0.08, 2.4 } } },
	Ice = { { 'electronicpingshort.wav', 0.35, 1.45 }, { 'clickfast.wav', 0.2, 1.3 } },
	Barrel = { { 'clickfast.wav', 0.45, 0.38 }, { 'electronicpingshort.wav', 0.2, 0.45 } },
}
-- The lowest pitch each kind is played at (Shoot.client: the shot at 1.1 - 0.04 x gun tier, down to 0.78 for
-- the Minigun; hits at 1, Dings higher), times the 5% jitter.
local SLOWEST = { Shot = 0.78 * 0.95 }
-- Voices a layer needs so a play every SPACING seconds never restarts one still ringing: its real length at its
-- slowest pitch over the spacing, plus one (4 to 10; 4 while the length is unknown).
function ShotSounds.poolSize(length, speed, kind)
	if type(length) ~= 'number' or length <= 0 or type(speed) ~= 'number' or speed <= 0 then return 4 end
	local slowest = speed * (SLOWEST[kind] or 0.95)
	return math.clamp(math.ceil(length / slowest / SPACING) + 1, 4, 10)
end

-- A bank: every kind's layers with their current file, pool and size, playing through one SoundGroup.
local function newBank(group)
	local bank = { group = group, kinds = {} }
	for kind, layers in ShotSounds.LAYERS do
		local list = {}
		for i, spec in layers do
			local use = spec.fallback or spec
			list[i] = { spec = spec, use = { BUILTIN .. use[1], use[2], use[3] }, file = use[1], pool = {}, next = 1, size = 4 }
		end
		bank.kinds[kind] = list
	end
	return bank
end
local function newSound(bank, id, volume)
	local sound = Instance.new('Sound')
	sound.SoundId = id
	sound.Volume = volume
	sound.SoundGroup = bank.group
	sound.Parent = bank.group
	return sound
end
local function resetPool(layer)
	for _, sound in layer.pool do sound:Destroy() end
	layer.pool, layer.next = {}, 1
end
-- The loaded length of a built-in file in seconds (0 when it does not load).
local function lengthOf(bank, file)
	local probe = newSound(bank, BUILTIN .. file, 0)
	local ok = pcall(function() ContentProvider:PreloadAsync({ probe }) end)
	local length = 0
	if ok then
		pcall(function()
			if probe.IsLoaded then length = probe.TimeLength end
		end)
	end
	probe:Destroy()
	return length
end
-- Settle one layer: the first choice if it loads, else its fallback; the pool sized from the real length.
local function settle(bank, kind, i, layer)
	local spec = layer.spec
	local name = kind .. i
	bank.group:SetAttribute(name, (spec.fallback and spec.fallback[1] or spec[1]) .. ' (loading)')
	local chosen, length = spec, lengthOf(bank, spec[1])
	if length <= 0 and spec.fallback then
		chosen = spec.fallback
		length = lengthOf(bank, chosen[1])
	end
	layer.use = { BUILTIN .. chosen[1], chosen[2], chosen[3] }
	layer.file = chosen[1]
	layer.size = ShotSounds.poolSize(length, chosen[3], kind)
	resetPool(layer)
	local note = chosen == spec and '' or (' (fallback: ' .. spec[1] .. ' did not load)')
	bank.group:SetAttribute(name, chosen[1] .. note)
	bank.group:SetAttribute(name .. 'Pool', layer.size)
	bank.group:SetAttribute(name .. 'Length', math.floor(length * 1000 + 0.5) / 1000)
end
-- True in a running game (Play or a live server); false in Studio's edit mode, where only PlayLocalSound sounds.
local function running()
	local ok, on = pcall(function() return RunService:IsRunning() end)
	return not ok or on
end
local function playIn(bank, kind, pitch)
	local uploaded = ShotSounds.SOUNDS[kind]
	local layers = bank.kinds[kind]
	if uploaded and uploaded ~= '' then
		bank.overrides = bank.overrides or {}
		bank.overrides[kind] = bank.overrides[kind] or { { use = { uploaded, 0.45, 1 }, pool = {}, next = 1, size = 4 } }
		layers = bank.overrides[kind]
	end
	for _, layer in layers or {} do
		local id, volume, speed = layer.use[1], layer.use[2], layer.use[3]
		local sound = layer.pool[layer.next]
		if not sound or sound.SoundId ~= id then
			if sound then sound:Destroy() end
			sound = newSound(bank, id, volume)
			layer.pool[layer.next] = sound
		end
		layer.next = layer.next % layer.size + 1
		sound.PlaybackSpeed = speed * (pitch or 1) * (0.95 + math.random() * 0.1)
		if running() then
			sound:Play()
		else
			SoundService:PlayLocalSound(sound) -- (edit mode: the command bar's demo)
		end
	end
end

local bank
-- Once per client: the SoundGroup (a settings menu can mute or balance 'Shots'), the pools, the probes.
function ShotSounds.init()
	if bank then return bank.group end
	local group = SoundService:FindFirstChild('Shots')
	if not (group and group:IsA('SoundGroup')) then
		group = Instance.new('SoundGroup')
		group.Name = 'Shots'
		group.Volume = 1
		group.Parent = SoundService
	end
	bank = newBank(group)
	for kind, layers in bank.kinds do
		for i, layer in layers do
			bank.group:SetAttribute(kind .. i, layer.file .. ' (loading)')
			bank.group:SetAttribute(kind .. i .. 'Pool', layer.size)
			task.spawn(settle, bank, kind, i, layer)
		end
	end
	return group
end

function ShotSounds.play(kind, pitch)
	if not bank then ShotSounds.init() end
	playIn(bank, kind, pitch)
end

-- Audition (Studio command bar, edit or play mode): each layer alone, each kind whole, then 3 s of held Minigun
-- fire on the gold gong (a shot and a Ding every 0.15 s), printing what plays. Uses its own SoundGroup
-- ('ShotsDemo', removed afterwards) so it leaves nothing behind in the place.
function ShotSounds.demo(gap)
	gap = gap or 0.7
	task.spawn(function()
		local group = Instance.new('SoundGroup')
		group.Name = 'ShotsDemo'
		group.Parent = SoundService
		local demo = newBank(group)
		for _, kind in ShotSounds.ORDER do
			for i, layer in demo.kinds[kind] do settle(demo, kind, i, layer) end
		end
		print('[ShotSounds] each layer alone (file @ speed, volume, pool size):')
		for _, kind in ShotSounds.ORDER do
			for i, layer in demo.kinds[kind] do
				print(string.format('[ShotSounds]   %s %d: %s @%.2f vol %.2f pool %d', kind, i, layer.file, layer.use[3], layer.use[2], layer.size))
				local saved = demo.kinds[kind]
				demo.kinds[kind] = { layer }
				playIn(demo, kind, 1)
				demo.kinds[kind] = saved
				task.wait(gap)
			end
		end
		print('[ShotSounds] each kind whole: a Pistol shot, then each hit')
		for _, kind in ShotSounds.ORDER do
			print('[ShotSounds]   ' .. kind)
			playIn(demo, kind, kind == 'Shot' and 1.06 or 1)
			task.wait(gap * 1.4)
		end
		print('[ShotSounds] 3 s held Minigun on the gold gong (listen for a drone, clicks or cut-off Dings)')
		for _ = 1, 20 do
			playIn(demo, 'Shot', 1.1 - 8 * 0.04)
			playIn(demo, 'Ding', 1 + 0.07 * 8)
			task.wait(0.15)
		end
		task.wait(1.5)
		group:Destroy()
		print('[ShotSounds] done')
	end)
end

return ShotSounds
