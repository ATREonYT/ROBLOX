---
tags: [sector-brief, vfx, particles, animation, audio, game-feel, juice]
updated: 2026-10-30
---
# Brief - VFX, Animation, Audio and Game Feel
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - **Effects are built once and fired with `Emit(n)`.** Do not create and destroy emitters per hit, and do not write emitter properties every frame. One emitter makes at most 400 particles/s, and only 100/s on mobile (Roblox docs).
> - **The server decides and the client draws.** The server validates the hit, the purchase or the reward, then tells clients. Clients play particles, sounds, shakes and popups. Never grant anything because a client effect fired.
> - **Kid-safe feel:** at most 1 flash per second, no strobe, no gore, and honest reveals (the result is chosen on the server before the animation plays).
> - **Animation Graphs are fully released (July 15, 2026).** Plain `Animator:LoadAnimation` clips still work and stay the default for our simple games. Use `Animator:GetTrackByAnimationId` instead of loading a track twice.
> - **New audio code uses the Audio API** (`AudioPlayer` -> `Wire` -> `AudioEmitter`/`AudioDeviceOutput`). The docs now discourage `Sound`, `SoundGroup` and `SoundEffect`. Set `SoundService.DefaultListenerLocation` to `Camera` or `Character`, or 3D audio may be silent.
> - **Never invent asset IDs** (animation, audio, texture). Leave 0 and put them on the owner's checklist. Animations must be owned by, or shared with, the game's owner. Animations still cannot be shared publicly.
> - **Use `HapticEffect`, not `HapticService`.** HapticService is now deprecated.
> - **Highlights:** up to 255 show at once per client, and disabled ones still take a slot (the old limit was 31).

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status | What to do | Source |
|---|---|---|---|
| **Animation Graphs** (Avatar tab > Animation Graph Editor; nodes Clip, Sequence, Random Sequence, Blend1D, Blend2D, Select, Priority Select, Mask, Over, Add, Subtract) | Full release July 15, 2026 | Optional. Good for locomotion blends (walk/run by speed). Publish the graph (an `AnimationGraphDefinition` asset), load its ID with an `Animation` like any clip, and drive it with `AnimationTrack:SetParameter(name, value)`. **Graph > Create Animate script** generates `Animate` (ModuleScript) + `RunClient` + `RunServer` | DevForum (Jul 15, 2026); Roblox docs (graph-editor) |
| `AnimationTrack:SetParameter / GetParameter / GetParameterDefaults` | Live | Graph parameters. NaN/Inf become 0 with a warning. Values set before the graph loads are applied when it is ready | Roblox docs |
| `Animator:GetTrackByAnimationId(id)` | Live | Look up an already-loaded track. `LoadAnimation` always makes a **new** track | Roblox docs |
| `Animator.PreferLodEnabled` (default true), `Animator.EvaluationThrottled` | Live | The engine may throttle animation for far-away remote characters. Set `PreferLodEnabled = false` only on a few key NPCs, such as a boss or a shop pet | Roblox docs |
| `AnimationTrack.KeyframeReached` | Superseded | Use `GetMarkerReachedSignal("Name")` | Roblox docs |
| `Humanoid:LoadAnimation` | Deprecated | Use the `Animator` under the Humanoid or AnimationController | Vault note [[Animation Objects]] |
| Animation sharing with connections and groups (Creator Hub > asset > Permissions) | Live since Aug 21, 2025 | Share clips with a group or a collaborator. **Public sharing is still not possible** | DevForum (Aug 21, 2025) |
| Audio API (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `AudioDeviceOutput`, `Wire`, effects such as `AudioFader`, `AudioEqualizer` and `AudioReverb`) | Recommended | The docs say `Sound`, `SoundGroup` and `SoundEffect` are "now discouraged". They are **not** deprecated, and old code still runs | Roblox docs (audio/objects) |
| `AudioPlayer.AssetId` | Deprecated | Use `AudioPlayer.Asset` | Roblox docs |
| `AudioEmitter.DistanceAttenuationMode` (default `Custom`) + `DistanceAttenuationBounds` (default 4 to 10000) | Live | Presets: `Inverse`, `InverseTapered`, `Linear`, `LinearSquared`. With `Custom`, the curve comes from `SetDistanceAttenuation({ [distance] = volume })` (up to 400 points) | Roblox docs |
| `SoundService.CharacterSoundsUseNewApi` | Live | Default footsteps and jumps can run on the new API | Roblox docs |
| Acoustic simulation (`SoundService.AcousticSimulationEnabled`, off by default) | **Client Beta** (Jan 28, 2026) | Occlusion, reverb and diffraction for Audio API sources only. It may switch itself off to protect frame rate. Not needed for cartoony simulators | DevForum (Jan 28, 2026) |
| `AudioTextToSpeech` | In the docs, no beta tag | 300 characters per request. Throttle: `1 + 6 x concurrent users` requests per minute per experience, and 4 requests per second per user | Roblox docs |
| `BasePart:BindToCollisionSummaries(callback)` ("Collision Summaries") | In the API reference | Gives contact data once per frame: `Point`, `Normal`, `RelativeVelocity`, `Area`, `Part0`, `Part1`, `Time`. Use it for impact sounds and dust scaled by hit speed. I found no official announcement date | Roblox docs (BasePart) |
| `HapticService` | **Deprecated** | Use a `HapticEffect` instance: `Type` (`UIClick`, `UIHover`, `UINotification`, `GameplayCollision`, `GameplayExplosion`, `Custom`), `Play()`, `Stop()`, `SetWaveformKeys` | Roblox docs |
| `ParticleEmitter.VelocitySpread` | Deprecated | Use `SpreadAngle` | Roblox docs |
| Highlight limit | 255 per client (was 31) | Destroy unused Highlights. A disabled one still counts | Roblox docs (effects/highlighting) |
| Client CPU Time analytics (Creator Analytics > Monitoring > Performance > Client) | Live July 2026 | Has an **Animation** bucket. Check it after adding many animated pets or NPCs | DevForum recap (Jul 17, 2026) |

## The recipes (how we build X)

### 1. A burst effect (coin pop, hatch sparkle, hit spark)
1. Put one invisible anchored part per effect type in `ReplicatedStorage/FX` (CanCollide, CanQuery, CanTouch and CastShadow all off), with the emitters on Attachments. Set **every** property in code or Studio. `LightInfluence` differs between Studio insert and `Instance.new`, so always set it (0 for glows) (Vault: [[Particle Emitters In Depth]]).
2. `Rate = 0`, and `Emit(n)` from code. Scale `n` yourself on low-end devices: graphics quality may thin out `Rate` streams but not your bursts (Vault skill `roblox-vfx`).
3. Use only built-in textures until the owner uploads art: `rbxasset://textures/particles/sparkles_main.dds`, `fire_main.dds`, `smoke_main.dds` (repo `VFX-ITEMS.md`). An unloaded ID shows as a white square.
4. Fade in and out: `Transparency` NumberSequence 1 -> 0 -> 1, and `Size` popping 0 -> big -> 0.
5. Reuse the clone (a pool). Never destroy an emitter in the same frame you call `Emit` (Vault skill `roblox-vfx`).

```lua
--!strict
-- Client: plays an effect the server told us about. Effects never grant anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FX = ReplicatedStorage:WaitForChild("FX")
local pool: {[string]: {BasePart}} = {}

local function take(name: string): BasePart
	local list = pool[name] or {}
	pool[name] = list
	local p = table.remove(list) or (FX:WaitForChild(name) :: BasePart):Clone()
	p.Parent = workspace
	return p
end

local function burst(name: string, at: Vector3, scale: number)
	local p = take(name)
	p.CFrame = CFrame.new(at)
	for _, d in p:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local n = (d:GetAttribute("Burst") :: number?) or 10
			d:Emit(math.max(1, math.floor(n * scale)))
		end
	end
	task.delay(2, function() -- longer than the longest Lifetime
		p.Parent = nil
		table.insert(pool[name], p)
	end)
end

ReplicatedStorage.Remotes.PlayFx.OnClientEvent:Connect(burst)
```

### 2. Trails, beams and highlights
- **Trail** (sword, dash, pet speed lines): two Attachments on the item, `Lifetime` 0.2 to 0.35 s, `Enabled` only while swinging. No texture gives a clean colour ribbon (repo `VFX-ITEMS.md`).
- **Beam** (guide line to the next egg, laser): two **different** Attachments that are both in Workspace. `Segments` 1 for straight, more for curves. `CurveSize0/1` bend along each attachment's X axis (Vault: [[Beams and Trails]]).
- **Flipbook**: `FlipbookLayout` `Grid2x2`/`Grid4x4`/`Grid8x8`/`Custom`, `FlipbookMode` `Loop`/`OneShot`/`PingPong`/`Random`, and `FlipbookFramerate` up to 30 fps. Leave transparent spacing between frames. Low-memory phones switch flipbooks off automatically, so the effect must still read without one (Roblox docs).
- **Highlight** (interactable chest, selected pet): one persistent Highlight per object. Set `FillColor`, `FillTransparency`, `OutlineColor`, `OutlineTransparency` and `DepthMode` (`AlwaysOnTop` or `Occluded`) explicitly. Animate its transparency instead of creating new ones. The first Highlight on screen costs the most, and on mobile the cost grows with how much of the screen it covers (Roblox docs).

### 3. Character animation (punch, carry, celebrate)
1. Author in the Animation Editor (or Blender/mocap via skill `roblox-ai-animation`). Set the priority in the editor or on the track: `Core < Idle < Movement < Action < Action2 < Action3 < Action4` (Roblox docs).
2. Carry and idle poses: animate **arms and torso only**, so the default walk keeps moving the legs (skill `roblox-ai-animation`).
3. Add named **event markers** at the contact frame. Fire VFX, sound and the +1 popup from the marker, never from a timer.
4. Publish under the **owner of the game** (the group if the game is group-owned). Leave the ID as 0 until then.

```lua
--!strict
-- Client (own character) or server (NPCs). Tracks started by a player's client on their own character replicate.
local function getTrack(humanoid: Humanoid, anim: Animation): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	return animator:GetTrackByAnimationId(anim.AnimationId) or animator:LoadAnimation(anim)
end

local function punch(humanoid: Humanoid, anim: Animation, onHit: () -> ())
	local track = getTrack(humanoid, anim)
	track.Priority = Enum.AnimationPriority.Action
	local conn: RBXScriptConnection
	conn = track:GetMarkerReachedSignal("Hit"):Connect(function(_param: string)
		onHit() -- play effects; the server already decided the damage or reward
	end)
	track.Stopped:Once(function() conn:Disconnect() end)
	track:Play(0.05) -- short fade in
end
```

Replication rules (Roblox docs, `Animator:LoadAnimation`): the `Animator` must be created on the server and be in Workspace before loading. Player characters: load and play on that player's client. NPCs: load and play on the server. An Animator created on a client never replicates.

**Animation Graph (optional):** after Create Animate script, set parameters from `RunClient` for player characters in `AuthorityMode.Automatic`. Under `AuthorityMode.Server`, set them from **both** `RunServer` and `RunClient`. NPCs use `RunServer` (Roblox docs, graph-editor).

**R6 vs R15:** R15 has 15 parts with elbows and knees. R6 has 6 parts and no elbows or knees, so it is stiffer and big moves clip. A clip made for one rig does not play on the other. Pick one per game and set it in Game Settings > Avatar (skill `roblox-ai-animation`; Vault [[R15 Rig Anatomy and Attachments]]).

### 4. Audio with the Audio API
- **2D (UI clicks, music):** in a LocalScript, `AudioPlayer` -> `Wire` -> `AudioDeviceOutput`. For a settings mute, put an `AudioFader` bus between them (`Interface`, `Effects`, `Music`).
- **3D (machine hum, egg crack in the world):** `AudioPlayer` -> `Wire` -> `AudioEmitter` (parented to the part). An `AudioListener` -> `Wire` -> `AudioDeviceOutput` hears it. Set `SoundService.DefaultListenerLocation = Enum.ListenerLocation.Camera` (or `Character`) and the engine builds that listener chain for you. `Default` only does so in some voice-chat setups, which is the classic "3D sound is silent" bug (Roblox docs, enum ListenerLocation).

```lua
--!strict
-- LocalScript: a UI sound bus with a mute toggle.
local SoundService = game:GetService("SoundService")

local out = Instance.new("AudioDeviceOutput")
out.Parent = SoundService
local bus = Instance.new("AudioFader")
bus.Name = "Interface"
bus.Parent = SoundService
local w1 = Instance.new("Wire")
w1.SourceInstance = bus
w1.TargetInstance = out
w1.Parent = bus

local function makeSound(id: string, volume: number): AudioPlayer
	local p = Instance.new("AudioPlayer")
	p.Asset = id -- "rbxassetid://<owner's id>"; leave "" until uploaded
	p.Volume = volume
	p.Parent = bus
	local w = Instance.new("Wire")
	w.SourceInstance = p
	w.TargetInstance = bus
	w.Parent = p
	return p
end

local click = makeSound("", 0.3)
local function setMuted(m: boolean) bus.Volume = if m then 0 else 1 end
-- click:Play() on button press; check click.IsReady before the first play
```

Sound design for kid games (rule of thumb from `cannon-evolution/src/client/GameClient/Sfx.lua` and [[Sound Design for Games]]): preload every sound at start, keep a small pool per sound so a replay never cuts off the last one, skip a repeat of the same button sound within a short gap, never pitch-wobble UI sounds, add a small pitch spread to game sounds, and make the reward sounds the loudest. Use Creator Store audio from Roblox's licensed library, or audio the owner made or licensed.

### 5. Game feel and juice
- **Camera shake** (client only): add an offset after the camera updates. Use `RunService:BindToRenderStep("Shake", Enum.RenderPriority.Camera.Value + 1, fn)` and multiply `camera.CFrame` by a small rotation built from `trauma^2` that decays over time. Light hits get no shake. Give players a settings toggle (Vault: [[Hit-Stop and Screen Shake Tuning by Numbers]], [[Camera Shake and Camera FX]]).
- **Hit-stop:** `track:AdjustSpeed(0)` on the attacker's track for 50 to 90 ms, then `AdjustSpeed(1)`. At 30 fps, 50 ms is only 1 or 2 frames (Vault note above).
- **+1 popups:** a pooled `BillboardGui` with `AlwaysOnTop`, a `TweenService` rise of about 2 studs with `Back` easing, then a fade. Fire it from the marker or the server's confirm, never before.
- **Button squash:** set the squashed size instantly, then spring back with a tween that overshoots. Keep the area the same (width = 1/height). Never squash the text (Vault: [[Squash Stretch and Anticipation in UI and Characters]]).
- **Reveals (eggs, crates):** the server picks the result first. The reel shows only items that can really drop, and the length grows by tier: common 0.3 to 0.5 s, legendary 3 to 4 s (Vault: [[Reward Moments and Celebrations]]).
- **Haptics:** a `HapticEffect` with `Type = Enum.HapticEffectType.UIClick`, created on the client, then `:Play()`. The class page does not say where to parent it, so check the docs' code samples. The docs list most haptic iPhone, Pixel and Galaxy phones plus PlayStation, Xbox and Quest controllers. Test on a real device.
- **Impact by speed (Collision Summaries):**

```lua
--!strict
-- Runs where the part is simulated (client for parts it owns, server for server-owned). Nothing replicates.
local function bindImpacts(part: BasePart, play: (pos: Vector3, strength: number) -> ())
	return part:BindToCollisionSummaries(function(summaries)
		for _, s in summaries do
			local speed = math.abs(s.RelativeVelocity:Dot(s.Normal)) -- head-on speed
			if speed > 8 then play(s.Point, math.clamp(speed / 40, 0, 1)) end
		end
	end)
end
```
Summaries skip parts with `CanCollide = false` and contacts between sleeping parts. The callback can get several summaries per frame, so rate-limit what it plays (Roblox docs).

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| ParticleEmitter max rate | 400 particles/s per emitter; 100/s on mobile | Roblox docs (effects/particle-emitters) |
| Live particles | Rate x mean Lifetime | Roblox docs (ParticleEmitter sample) |
| `Emit()` default count | 16 | Roblox docs |
| Flipbook framerate max | 30 fps; layouts 2x2, 4x4, 8x8, custom | Roblox docs |
| Particle Lifetime cap | 20 s | Vault skill `roblox-vfx` (not re-verified) |
| Per-item effect budget | ~16 particles/s per item, ≤6 per emitter, ≤1 light | Repo `VFX-ITEMS.md` (rule of thumb) |
| Highlights on screen | 255 per client; disabled ones count | Roblox docs (effects/highlighting) |
| Animation priorities | 7 levels: Core, Idle, Movement, Action, Action2, Action3, Action4 | Roblox docs |
| Playing tracks under Server Authority | 8 per Animator at release (known limit) | Vault [[Server Authority and Input Migration 2026]] |
| Combat or grab move length | 0.33 to 0.7 s (0.5 s default) | Skill `roblox-ai-animation` (rule of thumb) |
| Audio file | under 20 MB, 7 min, ≤48 kHz; mp3/ogg/wav/flac | Roblox docs (audio/assets) |
| Audio import quota | 2,000 per 30 days ID-verified, 100 unverified (Studio/Creator Hub page). The Open Cloud page says 100/month verified, 10 unverified. **The docs disagree**; plan for the lower number when using Open Cloud | Roblox docs (audio/assets; cloud/guides/usage-assets) |
| Text-to-speech | 300 chars/request; `1 + 6 x CCU` requests/min/experience; 4 req/s per user | Roblox docs |
| Custom attenuation curve | up to 400 points; volume 0 to 1 | Roblox docs (AudioEmitter) |
| Emitter default bounds | 4 to 10000 studs (presets only) | Roblox docs |
| Hit-stop by tier | medium 50 ms, heavy 66, finisher 75, ultimate 89 | Vault [[Hit-Stop and Screen Shake Tuning by Numbers]] (rule of thumb) |
| Hit-stop budget | ≤140 ms per rolling 0.6 s | Same vault note (rule of thumb) |
| Visible shake | under 10% of combat seconds | Same vault note (rule of thumb) |
| Reward watch time | under ~10% of play time | Vault [[Reward Moments and Celebrations]] (rule of thumb) |
| Flashes | ≤1 per second | Repo `CLAUDE.md` (kid-safe rule) |

## Pitfalls
- **Inventing IDs.** AI models write `rbxassetid://507766666`-style IDs from memory. They play nothing, or play someone else's asset. Leave them as 0 or "" and list them for the owner.
- **Test-uploaded or someone else's animations don't play live.** A clip must be owned by the game's owner (user or group) or shared with it. Group games need group uploads or a grant (DevForum Aug 21, 2025; Vault [[Animation Asset Permissions and Groups]]).
- **`LoadAnimation` on every input** leaks tracks. Cache, or use `GetTrackByAnimationId`.
- **An idle with animated legs** at a higher priority makes the character slide. Animate the upper body only.
- **An Animator created on the client** never replicates. Let the Humanoid make it, or create it on the server.
- **3D audio silent:** no listener (`DefaultListenerLocation` left on `Default`/`None`), or a `Wire` with the wrong pin names (check `Wire.Connected`).
- **`SoundService.AmbientReverb`** affects only legacy `Sound`s, not Audio API sources. Use `AudioReverb` (Roblox docs).
- **Emitters in ViewportFrames** (shop previews) don't draw. Use glow parts there (repo `VFX-ITEMS.md`).
- **Additive white on a bright map** turns into fog. Use `LightEmission` 0 to 0.3 with saturated colour for clouds and motes (skill `roblox-vfx`).
- **Random-rate glints** can blink faster than 1 per second. Use `Rate = 0` and a fixed timer of 1.5 s or more.
- **Shake on every coin** makes kids feel sick and hides the UI. Save shake for big moments, and offer a toggle.
- **Server-made moving parts** for motes replicate every frame. Build them on each client from a tag.
- **Effects fired before the server confirms** show rewards that never arrive. Keep the click feedback local; play the reward juice after the server says yes.
- **Using HapticService `SetMotor` code** from old notes. It is deprecated.

## Checklist before shipping
- [ ] Every asset ID is real and owned by, or granted to, the game owner. Zeros are on the owner's list.
- [ ] Every emitter sets `LightInfluence`, `LightEmission`, Transparency and Size fades. Bursts use `Emit`, and nothing writes emitter properties per frame.
- [ ] Effects are pooled. A busy server tested on a phone (or Studio's emulator at low quality) keeps a steady frame rate.
- [ ] No more than 1 flash per second anywhere, no strobing, and no gore.
- [ ] Rewards, damage and grants are decided on the server; clients only draw.
- [ ] Animations: right priority, upper-body-only idles and carries, markers named exactly as in code, R6 or R15 matches the game setting.
- [ ] Audio: listener location set, volume buses with a mute toggle in settings, sounds preloaded, music licensed.
- [ ] Shake and haptics have an off switch. Light hits have no shake.
- [ ] Reveals show only items that can really drop, and odds are shown for paid random items.
- [ ] Check Client CPU Time (Animation bucket) after launch if there are many pets or NPCs.

## Go deeper
- VFX: [[Particle Emitters In Depth]], [[Beams and Trails]], [[Highlights and Selection Effects]], [[VFX Design Playbook]], [[VFX Performance Budgets and Culling]], [[Replicating VFX - Server Validates, Clients Render]], [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]], [[Designing VFX Textures and Flipbooks in Figma]], [[Escalation and Grandeur Without Clutter]], [[05 VFX]]. Repo: `VFX-ITEMS.md`, skill `.claude/skills/roblox-vfx`.
- Animation: [[Animation Start Here]], [[Animator Deep Dive]], [[AnimationTrack Reference]], [[Playback, Priorities and Blending]], [[Markers and Events]], [[Replication and Ownership]], [[Publishing Animations]], [[Animation Asset Permissions and Groups]], [[The Default Animate Script]], [[Animation Editor Advanced]], [[Animation LOD]], [[VFX Timing with Animation]], [[06 Animation]]. Rigs: [[Skeleton Library]], [[R15 Rig Anatomy and Attachments]], [[Custom Characters and StarterCharacter]]. Skill: `.claude/skills/roblox-ai-animation`.
- Audio: [[The Audio API - Players Emitters Wires and Effects]], [[Sound Fundamentals]], [[Spatial Audio and Mixing]], [[Sound Design for Games]], [[Music and Adaptive Audio]], [[Music Licensing and Audio Upload Rules for 2026]], [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]], [[Audio Pipeline]], [[09 Audio]]. Reference code: `cannon-evolution/src/client/GameClient/Sfx.lua`.
- Game feel: [[Game Feel Start Here]], [[Hit-Stop and Screen Shake Tuning by Numbers]], [[Camera Shake and Camera FX]], [[Feedback Timing - Sound Visual and Haptic Sync]], [[Juice on a Budget - Mobile and Low-End]], [[Reward Moments and Celebrations]], [[Squash Stretch and Anticipation in UI and Characters]], [[Hit Reactions Stagger and Hit-Stop]], [[UI and GUI Animation]], [[Tween and CFrame Animation of Objects]], [[Gore Policy and Kid-Friendly Hit Feedback]], [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]]. Repo: `GAME-FEEL.md`; reference code `cannon-evolution/src/client/GameClient/Effects.lua`.

## Sources
All read 2026-10-30.
- https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840 (posted Jul 15, 2026)
- https://devforum.roblox.com/t/weekly-recap-july-13-%E2%80%93-17-animation-graphs-go-live-5%C3%97-more-data-store-storage/4743286 (Jul 17, 2026)
- https://devforum.roblox.com/t/client-beta-acoustic-simulation-emit-audio-with-presence/4307121 (Jan 28, 2026)
- https://devforum.roblox.com/t/sharing-animation-assets-with-connections-and-groups/3892540 (Aug 21, 2025)
- https://create.roblox.com/docs/effects/highlighting
- https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter
- https://create.roblox.com/docs/audio/objects.md
- Roblox creator-docs source (github.com/Roblox/creator-docs, `content/en-us/`), files: `effects/particle-emitters.md`, `audio/assets.md`, `audio/objects.md`, `animation/graph-editor.md`, `animation/events.md`, `projects/assets/privacy.md`, `cloud/guides/usage-assets.md`; class pages `ParticleEmitter`, `Beam`, `Trail`, `Animator`, `AnimationTrack`, `AnimationController`, `AudioPlayer`, `AudioEmitter`, `AudioListener`, `AudioTextToSpeech`, `Wire`, `Sound`, `SoundService`, `BasePart` (BindToCollisionSummaries), `Camera`, `HapticEffect`, `HapticService`; enums `AnimationPriority`, `ListenerLocation`, `ParticleFlipbookLayout`, `ParticleFlipbookMode`, `DistanceAttenuationMode`, `HapticEffectType`.

## Vault corrections
| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Camera Shake and Camera FX]] (section on controller rumble) | Use `HapticService` (`IsVibrationSupported`, `IsMotorSupported`) for rumble | `HapticService` is deprecated, superseded by `HapticEffect` | Roblox docs, HapticService class |
| [[Controller Support QoL]] | Snippet uses `HapticService:SetMotor` | Same: use `HapticEffect` (`Type`, `Play`, `SetWaveformKeys`) | Roblox docs |
| [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] | Rumble via `HapticService:SetMotor` | Same | Roblox docs |
| [[Animation Objects]] and [[Animation Editor Advanced]] (section 8) | Animation graphs are "newer and still evolving" | Full release on Jul 15, 2026, live for all games with automatic replication. Still optional | DevForum (Jul 15, 2026) |
| [[Asset Upload Automation with Open Cloud]] and [[Audio Pipeline]] | Audio quota 100/month verified, 10 unverified | Correct for Open Cloud only. The audio/assets page says 2,000 per 30 days verified and 100 unverified for normal imports. The two docs pages disagree; say which path each number is for | Roblox docs (both pages) |
| `huzz-valley/docs/notes/combine.md` (repo file, not vault) | Roblox draws at most 31 Highlights | Limit is 255 per client; disabled ones still count | Roblox docs (effects/highlighting) |
