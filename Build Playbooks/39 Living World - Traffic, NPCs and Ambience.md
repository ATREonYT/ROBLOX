---
tags: [build-playbooks, realistic, roleplay, traffic, npc, ambience, audio, living-world]
updated: 2026-11-01
---

# 39 Living World - Traffic, NPCs and Ambience

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Sound rules: [[29 Sound Playbook]] · RP systems: [[26 Fun and Roleplay Playbook]] §8 and §13 · Deep reference: `LihFolk/LihFolk Vault V2/07 Lighting VFX and Audio/` (Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools; The Audio API - Players Emitters Wires and Effects; Spatial Audio and Mixing), `25 Physics and Vehicles/`

> **TL;DR**
> - **A still, silent city looks like a screenshot.** Within 10 seconds of standing anywhere, something should move and something should sound.
> - **Ambient traffic and pedestrians run on each client, not the server.** They're decoration: anchored models moved along a hand-placed lane graph, spawned near the player, despawned far away. Real player cars stay server-owned.
> - **Ambience = bed + layer + one-shots.** A long quiet loop for the place, a mid layer (traffic, surf), and random short sounds (dog, horn, gull, siren) from varied positions, never a single pre-mixed loop.
> - **Use the Audio API** (`AudioPlayer` → `Wire` → `AudioEmitter`, heard by the `AudioListener`). `Sound` objects still work but are discouraged for new work (Roblox docs).
> - **Cheap motion everywhere:** wind in plants, clouds, flags, birds, flickering shop signs (≤ 1 flash per second), steam vents, water.

---

## 1. The "alive" checklist per block

| Layer | Example | Cost |
|---|---|---|
| Wind | Grass, palms, flags, trash blowing | Low ([[37 Terrain, Water and Foliage]] §4.5) |
| Sky | Moving clouds, birds circling, a plane every few minutes | Very low |
| Traffic | 4–15 AI cars nearby, stopping at lights | Medium (client) |
| Pedestrians | 6–20 NPCs walking sidewalks, a few idling (phone, bench, shop door) | Medium (client) |
| Parked life | Parked cars, a car with hazard lights blinking, a bike | Very low |
| Sound | Bed, layer, one-shots, interior rooms | Low |
| Light | Day/night, lit windows at night, flickering sign | Low ([[34 Realistic Lighting and Atmosphere]] §5) |
| Events | A siren passing every few minutes, an ice cream truck, garbage truck in the morning | Low, and great for RP |

Players count too: an RP map with 30 players in the right places feels alive by itself. Spawn, jobs and hangouts should pull players onto the same streets.

---

## 2. Ambient traffic (client-side)

**Why client-side:** dozens of server cars cost physics, network and memory for everyone. Ambient cars only need to look right for the player who sees them. DevForum advice for many cars: waypoints per lane, each car follows its list, raycast/spacing to stop behind the car ahead, and don't simulate what's far away.

**Authoring the lane graph:**
1. In `Workspace.TrafficNodes`, place small invisible anchored parts along the **centre of each lane**, every 20–60 studs on straights, every 8–12 on curves. Point each part's front (LookVector) in the driving direction.
2. Each node gets an `ObjectValue` named `Next` (or several: `Next1`, `Next2` for a junction choice).
3. Nodes at a stop line get an attribute `Signal` = "NS" or "EW" (which light phase lets them go), or `Stop = true` for stop signs.
4. Set node parts' CanCollide/CanTouch/CanQuery off, Transparency 1, and keep the folder `Persistent` (it's tiny) so the graph exists on every client.

**Car models:** 6–10 low-poly car meshes (one body mesh tinted many colours, wheels as part of the mesh or simple spinning parts), in `ReplicatedStorage.AmbientCars`. Body has one simple Box collider so players bump into them.

```lua
--!strict
-- StarterPlayerScripts/AmbientTraffic.client.luau (sketch, not yet run in Studio)
-- Moves pooled car models along the TrafficNodes graph near the local player.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_CARS = 10           -- lower on the Low graphics setting
local SPAWN_MIN, SPAWN_MAX, DESPAWN = 120, 350, 450
local SPEED = 45              -- studs/s on straights
local GAP = 22                -- keep this far behind the car ahead
local player = Players.LocalPlayer
local nodesFolder = workspace:WaitForChild("TrafficNodes")
local carTemplates = ReplicatedStorage:WaitForChild("AmbientCars"):GetChildren()
local carsFolder = Instance.new("Folder")
carsFolder.Name = "AmbientTrafficLocal"
carsFolder.Parent = workspace

type Car = { model: Model, from: BasePart, to: BasePart, t: number, speed: number }
local cars: { Car } = {}
local rng = Random.new()

local function nextOf(node: BasePart): BasePart?
	local options = {}
	for _, v in node:GetChildren() do
		if v:IsA("ObjectValue") and v.Value and v.Value:IsA("BasePart") then table.insert(options, v.Value) end
	end
	if #options == 0 then return nil end
	return options[rng:NextInteger(1, #options)] :: BasePart
end

local function canGo(node: BasePart): boolean
	local sig = node:GetAttribute("Signal")
	if sig == nil then return true end
	return workspace:GetAttribute("SignalPhase") == sig -- the server flips SignalPhase "NS"/"EW" every ~20 s
end

local function rootPos(): Vector3?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r and r.Position
end

local function spawnCar(at: Vector3)
	local nodes = nodesFolder:GetChildren()
	for _ = 1, 12 do
		local n = nodes[rng:NextInteger(1, #nodes)] :: BasePart
		local d = (n.Position - at).Magnitude
		if d > SPAWN_MIN and d < SPAWN_MAX then
			local nx = nextOf(n)
			if nx then
				local m = (carTemplates[rng:NextInteger(1, #carTemplates)] :: Model):Clone()
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then p.Anchored = true end
				end
				m.Parent = carsFolder
				table.insert(cars, { model = m, from = n, to = nx, t = 0, speed = SPEED * rng:NextNumber(0.85, 1.1) })
				return
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local me = rootPos()
	if not me then return end
	if #cars < MAX_CARS then spawnCar(me) end
	for i = #cars, 1, -1 do
		local c = cars[i]
		local segLen = (c.to.Position - c.from.Position).Magnitude
		-- stop for the car ahead on the same segment, for the player, or at a red light near the segment end
		local blocked = false
		local pos = c.from.Position:Lerp(c.to.Position, c.t)
		for _, o in cars do
			if o ~= c and o.from == c.from and o.t > c.t and (o.t - c.t) * segLen < GAP then blocked = true break end
			if o ~= c and o.from == c.to and o.t * (o.to.Position - o.from.Position).Magnitude + (1 - c.t) * segLen < GAP then blocked = true break end
		end
		if (me - pos).Magnitude < 10 then blocked = true end
		if c.t > 0.85 and not canGo(c.to) then blocked = true end
		if not blocked then
			c.t += (c.speed * dt) / math.max(segLen, 1)
		end
		if c.t >= 1 then
			local nx = nextOf(c.to)
			if not nx then c.model:Destroy() table.remove(cars, i) continue end
			c.from, c.to, c.t = c.to, nx, 0
		end
		local p = c.from.Position:Lerp(c.to.Position, c.t)
		local look = (c.to.Position - c.from.Position)
		if look.Magnitude > 0.01 then
			c.model:PivotTo(CFrame.lookAt(p, p + look))
		end
		if (p - me).Magnitude > DESPAWN then c.model:Destroy() table.remove(cars, i) end
	end
end)
```

**Make it look good:** ease the speed into stops (multiply speed by a 0–1 factor that ramps), smooth corners (interpolate the facing over the first 30% of each segment), spin wheels, brake lights on when blocked, headlights at night, and a soft engine `AudioEmitter` with a short attenuation (≈ 40 studs). For many cars, collect CFrames and move them with `workspace:BulkMoveTo` once per frame. Rich car audio: `LihFolk/.../Engine and Tyre Audio Driven by RPM and Slip.md`.

**Limits to tell Alex:** each player sees their own traffic (two players won't see the same AI car). That's normal for ambient traffic. Police chases, crashes and anything players interact with need server cars ([[26 Fun and Roleplay Playbook]] §8).

---

## 3. Ambient pedestrians (client-side)

- **Rigs:** R15 rigs with an `AnimationController` + `Animator` (no Humanoid; Humanoids cost far more). Our own outfits; vary with a few shirt/pants/skin/hair combos.
- **Paths:** a second graph, `Workspace.WalkNodes`, along sidewalks, with spots tagged `Idle` (bench, bus stop, shop window, phone call). Walk speed 5–7 studs/s with a walk animation; at an Idle spot, play an idle animation for 5–20 s.
- **Count by graphics level:** 6–10 low, 12–20 mid, 30 high, all within ~150 studs of the player; despawn beyond 250.
- **Avoid the player:** pause and turn if the player is within 4 studs ahead.
- **No talking NPCs in the street** unless they're a job giver. Job givers are server NPCs with ProximityPrompts.
- **Kid-safe:** no fighting, no pushing, no stealing NPC behaviours; ambient NPCs are friendly background.

Animation work: [[19 Animation and VFX Recipe Book]] and the `roblox-ai-animation` skill.

---

## 4. Ambience sound (the Audio API way)

**Structure per zone (from the DevForum environmental audio tutorial and the vault's soundscape note):**
1. **Bed** (30 s+ loop, very quiet, non-directional): city hum, distant freeway, HVAC, surf for the coast.
2. **Layer** (loops, positioned): traffic on the avenue, waves on the beach, a fountain, insects in the bushes.
3. **One-shots** (short, random time and position): dog bark, car horn, door slam, bird calls (many variations), gulls, a far siren, a plane, a basketball bounce.
4. **Events:** ice cream truck jingle, church bell on the hour, garbage truck at 7:00 in-game.

Fade the bed between zones (city → park → beach) over 2–3 s. Change the set with the time of day (birds by day, crickets at night). Many variations of each one-shot so nothing repeats; never a single pre-mixed ambience loop where the same horn plays every 48 seconds.

**Audio API wiring (Roblox docs):** `AudioPlayer` (the file) → `Wire` → `AudioEmitter` (a speaker in the world, parented to a part) → heard by the `AudioListener` (on the camera or character; set `SoundService.ListenerLocation` to Camera or Character) → `AudioDeviceOutput`. `AudioEmitter.DistanceAttenuation` is a volume-by-distance curve (for example half volume at 50 studs, silent at 70).

```lua
--!strict
-- Client: random one-shot ambience around the player using the Audio API (sketch, not yet run in Studio).
-- Fill SOUNDS with uploaded, licensed asset ids (prefer Roblox licensed library sounds). Never invent ids.
local Players = game:GetService("Players")
local SOUNDS = {
	day = { "rbxassetid://0" },   -- dog bark, horn, birds (several variations each)
	night = { "rbxassetid://0" }, -- crickets, far siren, cat
}
local player = Players.LocalPlayer
local host = Instance.new("Part")
host.Anchored, host.CanCollide, host.CanTouch, host.CanQuery = true, false, false, false
host.Transparency, host.Size = 1, Vector3.one
host.Name = "AmbientOneShotHost"
host.Parent = workspace

local ap = Instance.new("AudioPlayer"); ap.Parent = host
local em = Instance.new("AudioEmitter"); em.Parent = host
local w = Instance.new("Wire"); w.SourceInstance = ap; w.TargetInstance = em; w.Parent = host
em:SetDistanceAttenuation({ [0] = 1, [40] = 0.6, [90] = 0.15, [140] = 0 })

local rng = Random.new()
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(6, 18))
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local h = (workspace:GetAttribute("WorldClock") :: number?) or 12
			local list = (h > 6 and h < 19) and SOUNDS.day or SOUNDS.night
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(30, 90)
			host.Position = r.Position + Vector3.new(math.cos(a) * d, rng:NextNumber(0, 15), math.sin(a) * d)
			ap.Asset = list[rng:NextInteger(1, #list)]
			ap.Volume = rng:NextNumber(0.35, 0.7)
			ap.PlaybackSpeed = rng:NextNumber(0.94, 1.06) -- small pitch changes hide repeats
			ap:Play()
		end
	end
end)
```

**Indoor sound:** inside job buildings, swap to a room tone and add `AudioReverb` on the room's emitters; muffle outside (an `AudioEqualizer` low-pass on the outdoor bed while indoors).

**Project sound rules still apply** ([[09 Owner Taste Rules]], [[29 Sound Playbook]]): prefer Roblox licensed library sounds, nothing harsh, ambience quiet under gameplay sounds, UI sounds short.

---

## 5. Cheap motion that sells "alive"

- **Birds:** a few flipbook-animated bird sprites (Beam or BillboardGui) circling high; a flock flushes up when the player runs near pigeons.
- **Flags and banners:** a cloth-like mesh with a looping bone animation, or a texture scroll.
- **Steam and vents:** a small ParticleEmitter on manhole covers and rooftop vents at night (≤ 10 particles each).
- **Signs:** a shop sign that flickers (≤ 1 flash per second, kid-safe rule), a rotating barber pole (hood-01 icon set has a barber).
- **Water:** shoreline foam, boats bobbing (a small sine on their pivot), a marker light blinking.
- **Paper and leaves:** a few particles blown along the street by `GlobalWind` (WindAffectsDrag on).

---

## 6. Distance culling for lights and effects (client)

```lua
--!strict
-- Client: turn off lights, emitters and ambient sounds far from the camera (sketch, not yet run in Studio).
local CollectionService = game:GetService("CollectionService")
local RANGE = 200 -- set from the graphics menu: High 300, Medium 200, Low 120
task.spawn(function()
	while true do
		local cam = workspace.CurrentCamera.CFrame.Position
		for _, inst in CollectionService:GetTagged("Cullable") do
			local p = inst:IsA("BasePart") and inst or inst:FindFirstAncestorWhichIsA("BasePart")
			if p then
				local on = (p.Position - cam).Magnitude < RANGE
				for _, x in inst:GetDescendants() do
					if x:IsA("Light") or x:IsA("ParticleEmitter") then x.Enabled = on end
				end
			end
		end
		task.wait(0.5)
	end
end)
```

Tag lamp heads, sign glows, vents and fountains `Cullable`. This is often the single biggest night-time win on phones.

## Sources
DevForum [Most efficient way to simulate a lot of traffic](https://devforum.roblox.com/t/most-effecient-way-to-simulate-a-lot-of-traffic/2164600) (lane waypoints, raycast stopping, don't simulate far traffic), [AI Traffic System](https://devforum.roblox.com/t/ai-traffic-system/1448682), [Environmental audio tutorial](https://devforum.roblox.com/t/ambientsorcery%E2%80%99s-tutorial-1-creating-compelling-environmental-audio/3507022) (bed + layer + random foreground one-shots, many variations, fade between zones, change with time of day), [New Audio API](https://devforum.roblox.com/t/new-audio-api-beta-elevate-sound-and-voice-in-your-experiences/2848873). Roblox docs [Audio objects](https://create.roblox.com/docs/audio/objects) (AudioPlayer, AudioEmitter, Wire, ListenerLocation, DistanceAttenuation), [Global wind](https://create.roblox.com/docs/environment/global-wind).
