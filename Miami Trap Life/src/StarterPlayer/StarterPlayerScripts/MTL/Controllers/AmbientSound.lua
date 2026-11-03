--!strict
-- World sound (client only). Required by AmbientLife (step() runs from its one Heartbeat). Owns every ambient sound:
--   zone beds    Street / Alley / Shop / Underpass / Canal, each with a day and a night loop, 2 s crossfade,
--                plus a cricket layer under every outdoor night bed
--                (zones: AmbientMap.Zones; shop interiors = under a roof, on the shop's own floor (or under its
--                own roof), near its Config/Locations Inside/Door, see AmbientRules.shopAt)
--   emitters     positional loops: window radios (hip-hop, latin, old soul, gospel, a TV), AC hum, the dog behind the
--                fence, the hoop, the grill, pigeon coos, crowd murmur near people groups, car engines + bass.
--                Only the nearest Ambient.Sound.MaxAudible play; the rest wait (a fixed pool of Sound objects).
--   one-shots    horn, wing flaps, a bark; distant 2D sirens / horns at random gaps
-- Everything sits in SoundService.MTL_Ambience (a SoundGroup), so one volume turns the whole world down.
-- Other systems use: AmbientSound.emitter(key, kind, Vector3 | () -> Vector3), .remove(key), .oneShot(kind, pos)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Locations = require(ReplicatedStorage.MTL.Config.Locations)

local AmbientSound = {}

type Emitter = { key: string, kind: string, pos: Vector3, fn: (() -> Vector3)?, def: any, music: number? }
type Slot = { part: Part, sound: Sound?, key: string? }

local cfg: any
local R: any
local group: SoundGroup
local folder: Folder
local emitters: { [string]: Emitter } = {}
local slots: { Slot } = {}
local zones: { { kind: string, pos: Vector3, r: number } } = {}
local shops: { any } = {}
local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude
roofParams.RespectCanCollide = false
local beds: { [string]: Sound } = {}
local currentBed: string? = nil
local nextDistant: { number } = {}
local rng = Random.new()

local warned: { [string]: boolean } = {}
local function validId(id: any, what: string): boolean
	if type(id) == "number" and id > 0 then
		return true
	end
	if not warned[what] then
		warned[what] = true
		warn("[MTL Ambient] no sound id for " .. what .. " (Config/Ambient.Sound): skipped")
	end
	return false
end

local function asset(id: number): string
	return "rbxassetid://" .. tostring(id)
end

local function soundGroup(): SoundGroup
	local g = SoundService:FindFirstChild("MTL_Ambience")
	if not g then
		local sg = Instance.new("SoundGroup")
		sg.Name = "MTL_Ambience"
		sg.Volume = 1
		sg.Parent = SoundService
		g = sg
	end
	return g :: SoundGroup
end

---------------------------------------------------------------- emitters

local function defFor(kind: string, music: number?): any
	local S = cfg.Sound
	if kind == "Window" then
		local m = S.Music[((music or 0) % #S.Music) + 1]
		return { id = m.id, volume = m.volume, maxDistance = S.MusicMaxDistance }
	end
	return S.Loops[kind]
end

function AmbientSound.emitter(key: string, kind: string, at: any, music: number?)
	local def = defFor(kind, music)
	if not def or not validId(def.id, kind) then
		return -- never a Sound without an id (warned once per kind)
	end
	local e: Emitter = { key = key, kind = kind, pos = Vector3.zero, fn = nil, def = def, music = music }
	if typeof(at) == "Vector3" then
		e.pos = at
	else
		e.fn = at
		e.pos = at()
	end
	emitters[key] = e
end

function AmbientSound.remove(key: string)
	emitters[key] = nil
end

function AmbientSound.oneShot(kind: string, pos: Vector3?)
	local def = cfg.Sound.OneShots[kind]
	if not def or not validId(def.id, kind) then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = asset(def.id)
	s.Volume = def.volume
	s.RollOffMaxDistance = def.maxDistance or 80
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.SoundGroup = group
	s.PlaybackSpeed = rng:NextNumber(0.94, 1.06)
	if pos then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		p.CFrame = CFrame.new(pos)
		p.Parent = folder
		s.Parent = p
		Debris:AddItem(p, 6)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 12)
	end
	s:Play()
end

local function newSlot(): Slot
	local p = Instance.new("Part")
	p.Name = "Emitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(0, 2000, 0)
	p.Parent = folder
	-- the Sound itself is made on first use, so no idle Sound ever sits there with an empty SoundId
	return { part = p, sound = nil, key = nil }
end

local function assign(slot: Slot, e: Emitter?)
	if not e then
		slot.key = nil
		if slot.sound then
			slot.sound:Destroy()
			slot.sound = nil
		end
		slot.part.CFrame = CFrame.new(0, 2000, 0)
		return
	end
	if not validId(e.def.id, e.kind) then
		return
	end
	slot.key = e.key
	slot.part.CFrame = CFrame.new(e.pos)
	if slot.sound then
		slot.sound:Destroy()
	end
	local s = Instance.new("Sound")
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.SoundGroup = group
	s.SoundId = asset(e.def.id)
	s.Volume = e.def.volume
	if e.kind == "Window" or e.kind == "CarMusic" then
		require(ReplicatedStorage.MTL.UI.MusicLevel).attach(s) -- songs matched in loudness, a bit quieter (SFX thread)
	end
	local maxD = e.def.maxDistance or 60
	s.RollOffMaxDistance = maxD
	-- full volume out to 40 % of the range (radios read from across the street), then it falls away
	s.RollOffMinDistance = maxD * 0.4
	s.PlaybackSpeed = if e.kind == "Window" then 1 else rng:NextNumber(0.95, 1.05)
	s.Parent = slot.part
	slot.sound = s
	-- radios aren't all on the same beat: start somewhere inside the track once it has loaded
	task.spawn(function()
		if not s.IsLoaded then
			s.Loaded:Wait()
		end
		if s.Parent and s.TimeLength > 4 then
			s.TimePosition = rng:NextNumber(0, s.TimeLength * 0.6)
		end
	end)
	s:Play()
end

local function updateEmitters(ctx: any)
	local list: { Emitter } = {}
	local dists: { number? } = {}
	for _, e in emitters do
		if e.fn then
			e.pos = e.fn()
		end
		local d = (e.pos - ctx.camPos).Magnitude
		local maxD = math.min(e.def.maxDistance or 60, cfg.Sound.Radius)
		table.insert(list, e)
		-- rank by how far into its own range it is, so a quiet AC close by beats a far radio
		dists[#list] = if d < maxD then d / maxD else nil
	end
	local chosen: { [string]: Emitter } = {}
	for _, i in R.nearestN(dists, cfg.Sound.MaxAudible, #list) do
		chosen[list[i].key] = list[i]
	end
	-- keep slots that still play a chosen emitter (no restarts), free the rest
	local free: { Slot } = {}
	for _, slot in slots do
		local k = slot.key
		if k and chosen[k] then
			slot.part.CFrame = CFrame.new(chosen[k].pos)
			chosen[k] = nil
		else
			if k then
				assign(slot, nil)
			end
			table.insert(free, slot)
		end
	end
	for _, e in chosen do
		local slot = table.remove(free)
		if not slot then
			break
		end
		assign(slot, e)
	end
end

---------------------------------------------------------------- zone beds

local function bed(name: string): Sound?
	local def = cfg.Sound.Beds[name]
	if not def or def.id == 0 then
		return nil
	end
	local s = beds[name]
	if not s then
		local snd = Instance.new("Sound")
		snd.Name = "Bed_" .. name
		snd.SoundId = asset(def.id)
		snd.Looped = true
		snd.Volume = 0
		snd.SoundGroup = group
		snd.Parent = SoundService
		beds[name] = snd
		s = snd
	end
	return s
end

-- names of the part hit from `pos` along `dir` and its ancestors up to Workspace (nil = nothing: sky / void)
local function chainAt(pos: Vector3, dir: Vector3): { string }?
	local filter: { Instance } = { folder }
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	if char then
		table.insert(filter, char)
	end
	roofParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), dir, roofParams)
	if not hit then
		return nil
	end
	local names = {}
	local inst: Instance? = hit.Instance
	while inst and inst ~= workspace do
		table.insert(names, inst.Name)
		inst = inst.Parent
	end
	return names
end

local function zoneAt(pos: Vector3): string
	local roof = chainAt(pos, Vector3.new(0, 60, 0))
	if roof and R.shopAt(pos.X, pos.Y, pos.Z, roof, chainAt(pos, Vector3.new(0, -8, 0)), shops, cfg.Sound.ShopFind) then
		return "Shop"
	end
	for _, z in zones do
		local d = Vector3.new(pos.X - z.pos.X, 0, pos.Z - z.pos.Z).Magnitude
		if d < z.r and math.abs(pos.Y - z.pos.Y) < 24 then
			return z.kind
		end
	end
	return "Street"
end

local nightLayer: Sound? = nil
local nightOn = false

local function updateNightLayer(on: boolean)
	local def = cfg.Sound.NightLayer
	if not def or def.id == 0 or on == nightOn then
		return
	end
	nightOn = on
	if not nightLayer then
		local s = Instance.new("Sound")
		s.Name = "Bed_NightLayer"
		s.SoundId = asset(def.id)
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = group
		s.Parent = SoundService
		s:Play()
		nightLayer = s
	end
	TweenService:Create(nightLayer :: Sound, TweenInfo.new(cfg.Sound.Crossfade * 2), { Volume = if on then def.volume else 0 }):Play()
end

local function updateBed(ctx: any)
	local focus = ctx.playerPos or ctx.camPos
	local zoneName = zoneAt(focus)
	updateNightLayer(ctx.night and zoneName ~= "Shop")
	local zone = cfg.Sound.Zones[zoneName] or cfg.Sound.Zones.Street
	local name = if ctx.night then zone.night else zone.day
	if name == currentBed then
		return
	end
	local fade = TweenInfo.new(cfg.Sound.Crossfade, Enum.EasingStyle.Sine)
	if currentBed then
		local old = beds[currentBed]
		if old then
			local tw = TweenService:Create(old, fade, { Volume = 0 })
			tw:Play()
			local mine = currentBed
			tw.Completed:Connect(function()
				if currentBed ~= mine then
					old:Stop()
				end
			end)
		end
	end
	currentBed = name
	local s = bed(name)
	if s then
		if not s.IsPlaying then
			s:Play()
		end
		TweenService:Create(s, fade, { Volume = cfg.Sound.Beds[name].volume }):Play()
	end
end

local function updateDistant(ctx: any)
	for i, d in cfg.Sound.Distant do
		if d.id ~= 0 then
			if not nextDistant[i] then
				nextDistant[i] = ctx.now + rng:NextNumber(d.every[1], d.every[2])
			elseif ctx.now >= nextDistant[i] then
				nextDistant[i] = ctx.now + rng:NextNumber(d.every[1], d.every[2])
				if not (d.dayOnly and ctx.night) then
					local s = Instance.new("Sound")
					s.SoundId = asset(d.id)
					s.Volume = d.volume
					s.PlaybackSpeed = rng:NextNumber(0.92, 1.05)
					s.SoundGroup = group
					s.Parent = SoundService
					s:Play()
					Debris:AddItem(s, 30)
				end
			end
		end
	end
end

---------------------------------------------------------------- loop

function AmbientSound.init(ctx: any)
	cfg = ctx.cfg
	R = ctx.R
	group = soundGroup()
	folder = Instance.new("Folder")
	folder.Name = "Sound"
	folder.Parent = ctx.folder
	for _ = 1, cfg.Sound.MaxAudible do
		table.insert(slots, newSlot())
	end
	-- shop interiors (checked first, by roof), then the map's alleys / underpass / canal
	for _, s in cfg.Sound.Shops do
		local loc = (Locations :: any)[s.key]
		if loc then
			local anchors = {}
			for _, p in { loc.Inside, loc.Door } do
				table.insert(anchors, { p.X, p.Y, p.Z })
			end
			table.insert(shops, { key = s.key, model = s.model, by = s.by, r = s.r, anchors = anchors })
		end
	end
	for _, z in ctx.map.Zones or {} do
		table.insert(zones, { kind = z[1], pos = Vector3.new(z[2], z[3], z[4]), r = z[5] })
	end
	-- static emitters from the map spots
	local window = 0
	for _, s in ctx.spots do
		if s.kind == "Window" then
			window += 1
			AmbientSound.emitter("W" .. s.i, "Window", s.pos, window)
		elseif s.kind == "Dog" or s.kind == "AC" or s.kind == "Ball" or s.kind == "Grill" then
			AmbientSound.emitter("S" .. s.i, s.kind, s.pos) -- sound-only spots placed by the survey / DressHoodLife
		end
	end
end

function AmbientSound.step(ctx: any, _dt: number, far: boolean)
	if not far then
		return
	end
	updateEmitters(ctx)
	updateBed(ctx)
	updateDistant(ctx)
end

-- emitters playing, the current zone bed ("-" if none), and how many emitters are registered
function AmbientSound.stats(): (number, string, number)
	local n = 0
	for _, s in slots do
		if s.key and s.sound and s.sound.IsPlaying then
			n += 1
		end
	end
	local registered = 0
	for _ in emitters do
		registered += 1
	end
	local b = currentBed and beds[currentBed]
	return n, if b and b.IsPlaying then (currentBed :: string) else "-", registered
end

return AmbientSound
