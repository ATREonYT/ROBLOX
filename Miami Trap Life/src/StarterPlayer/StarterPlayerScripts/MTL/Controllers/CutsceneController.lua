--!strict
-- Plays cutscenes: data modules in ReplicatedStorage/MTL/Cutscenes/<Id>.lua (Research: Cutscenes).
-- Everything on screen is a pure function of one clock `t` (camera, actors, fades, subtitles), run on RenderStepped,
-- so a SKIP just jumps the clock to the end and runs ONE cleanup path (pcall'd; it always restores the camera,
-- controls, HUD and phone, even if the scene errors). Tap = finish the line / jump to the next line. Hold = skip
-- (after a 1 s grace). Actors and props are local clones: private to this player, free for the server.
--
-- API:
--   Cutscene.play(id, { anchor = CFrame?, token = number?, marks = {Name = Vector3}? }) -> skipped   (yields until done)
--   Cutscene.isPlaying() -> boolean
--   Cutscene.releaseBlack(fadeSeconds?)   end a scene's "holdBlack" (MissionController calls it when its screen
--                                         is ready; it also releases by itself after 6 s)
--   Cutscene.registerAction(name, fn(ctx, action))   custom beats: an action { t = 3, call = "PcScreen" }
--        ctx = { t, anchor, actors = {name -> Actor}, props = {name -> Model}, camera, scene }
--   Cutscene.Started: Signal(id)   Cutscene.Finished: Signal(id, skipped)
--   Group scenes (CutsceneService.playGroup, a party watching one story beat): opts.group = { n, host, hostName },
--   opts.startAt = server time of frame 0 (everyone starts together). Holding skip is a VOTE ("2/3 want to skip"),
--   the server ends the scene for all once enough vote; only the host picks on a choice card, the others see whom
--   they're waiting for and get the pick from the server (CutsceneSync).
-- The server version is CutsceneService.play(player, id, opts) (it fires PlayCutscene and waits for CutsceneDone).
--
-- Scene data (see Cutscenes/GangIntro.lua for a full example). All positions are LOCAL to `anchor`:
--   length, skippable, holdBlack, fadeIn, grade = {TintColor, Saturation, Contrast, Brightness}, dof, ambience
--   actors = { Name = { rig = "Dre" | "@player", at = Vector3 | "@here", face = Vector3 | "@here" | "@Actor", pose? } }
--   props  = { Name = { prop = "CrewCar", at = CFrame, hazards? } }
--   shots  = { { t, from = Cam, to = Cam?, dur?, ease?, fov, fovTo?, handheld? } }
--      Cam = { pos = Vector3, look = Vector3 | "Actor" | "Prop" } | { two = {A, B}, dist?, side?, height? }
--          | { close = A, dist?, side? } | { ots = {listener, speaker}, dist?, side? (shoulder offset, 1.6) }
--          | { path = {Vector3, ...}, look = ... | lookPath = {Vector3, ...} }   (Catmull-Rom spline, smooth through every point)
--          | { gameplay = true, dist?, height? }   right behind the REAL character, where the gameplay camera sits:
--            end a scene on it and the hand-off into play has no snap (Research: Cinematic Cutscenes §5)
--      shot.safe = false skips the wall check (aerials: a look point near a building would pull the camera inside)
--      shot.focus = "Actor" | Vector3 (rack the depth of field to it; default = the look point), shot.blur = 0..1
--   hideWorld = { { name = "AutoDoors", at = Vector3, radius? } }  hide map parts under a model of that name near
--     `at` for the scene (when the scene brings its own animated copy)
--   choice = { t, prompt?, options = { { id, text }, ... }, default? }  the scene pauses at t on a choice card (keys 1-3,
--     click/tap, gamepad select). Lines/actions with `when = "<option id>"` only play after that pick (keep branch
--     content to lines, gestures, sounds, titles, fades). Holding skip before the pick jumps TO the card, not past it.
--     Cutscene.play returns (skipped, choiceId); the server gets it in CutsceneDone { choice }.
--   fill = 0..2 camera fill light (default 0.9; 1.4 at night hours; 0 = off)
--   hour = 7.5 (LightingController holds this time of day for this player during the scene, then blends back)
--   music = Theme.Cutscene.Sounds key or id (fades in at the start, out at the end) · stream = { local points to
--   stream in under the opening black } · placePlayer = { at, face } (moves the REAL character there at the start,
--   so a hand-off lands on it)
--   lines  = { { t, who, text, dur? } }
--   actions = { { t, actor, walk = Vector3, dur, ease? } | { t, actor, turn = Vector3 | "@Actor", dur? }
--             | { t, actor, gesture, dur } | { t, actor, pose = "Lean" | "None" } | { t, actor, hide = bool }
--             | { t, actor, hold = "Soda" | "Bill" | "Card" | "Keys" | "Envelope" | false }  (an item in the right
--               hand, Actors.HeldItems; an actor def may start with hold = "Soda")
--             | { t, prop, move = CFrame, dur, ease? } | { t, sound } | { t, shake, dur } | { t, fade = "in"|"out", dur }
--             | { t, title, sub?, dur } | { t, call = "Name" } }
--   marks  = { Name = Vector3 } (Piece 4) named LOCAL points, so one scene fits any room layout. Any position above
--            (actor at/face, walk, turn, shot pos/look) may be "#Name" or { mark = "Name", off = Vector3 }.
--            Cutscene.play(id, { marks = {...} }) / CutsceneService.play(player, id, { marks }) override them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local CutsceneRules = require(ReplicatedStorage.MTL.Rules.CutsceneRules)
local Rig = require(ReplicatedStorage.MTL.Rig)
local Build = require(ReplicatedStorage.MTL.UI.Build.Cutscene)
local UIState = require(script.Parent.UIState)
local Actors = require(script.Parent.Actors)

local player = Players.LocalPlayer
local K = Theme.Cutscene

local Cutscene = {}
Cutscene.Started = Signal.new()
Cutscene.Finished = Signal.new()

local gui: any
local playing = false
local stopRequested = false
local syncHandler: ((any) -> ())? = nil -- the running group scene's CutsceneSync handler
local blackToken = 0
local customActions: { [string]: (any, any) -> () } = {}
local showDialogue: (any, number, number, { [string]: any }, boolean) -> ()
local clearDialogue: () -> ()

local UP = Vector3.new(0, 1, 0)

local function log(...)
	print("[MTL Cutscene]", ...)
end

local function soundId(key: any): string?
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local fromTheme = (Theme.Mission.Sounds :: any)[key] or (K.Sounds :: any)[key]
	if fromTheme == nil then
		local sfx = ((Theme :: any).Sfx or {})[key] -- the shared UI library (UI/Sfx.lua names), e.g. "PhoneVibrate"
		fromTheme = if type(sfx) == "table" then sfx.id else sfx
	end
	local id = if fromTheme ~= nil then fromTheme else key
	if type(id) ~= "string" or id == "" or id == "rbxassetid://0" then
		return nil
	end
	return id
end

local function playSound(key: any, volume: number?)
	local id = soundId(key)
	if not id then
		return
	end
	-- SFX thread: one-shots go through the shared Sfx module (mute setting, pooling, length cap 2.5 s, no squeaky pitch)
	local okS, SfxMod = pcall(require, ReplicatedStorage.MTL.UI.Sfx)
	if okS and type(SfxMod) == "table" and SfxMod.playId then
		SfxMod.playId(id, { volume = volume or 0.6, max = 2.5 })
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	SoundService:PlayLocalSound(s)
	task.delay(4, function()
		s:Destroy()
	end)
end

function Cutscene.registerAction(name: string, fn: (any, any) -> ())
	customActions[name] = fn
end

function Cutscene.isPlaying(): boolean
	return playing
end

-- Everything that isn't ours (the place's stock ticker, chat, player list...) hides during a scene and comes back.
local hiddenGuis: { ScreenGui } = {}
local hiddenCore: { Enum.CoreGuiType } = {}
local hiddenConns: { RBXScriptConnection } = {}
local function hideOthers(on: boolean)
	local StarterGui = game:GetService("StarterGui")
	if on then
		local pg = player:FindFirstChild("PlayerGui")
		for _, g in (if pg then pg:GetChildren() else {}) do
			if g:IsA("ScreenGui") and g.Enabled and string.sub(g.Name, 1, 4) ~= "MTL_" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
				-- some screens (the place's news ticker) switch themselves back on: keep them off until the scene ends
				table.insert(hiddenConns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
					if g.Enabled then
						g.Enabled = false
					end
				end))
			end
		end
		for _, t in { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu } do
			local okGet, was = pcall(function()
				return StarterGui:GetCoreGuiEnabled(t)
			end)
			if okGet and was then
				pcall(function()
					StarterGui:SetCoreGuiEnabled(t, false)
				end)
				table.insert(hiddenCore, t)
			end
		end
	else
		for _, c in hiddenConns do
			c:Disconnect()
		end
		table.clear(hiddenConns)
		for _, g in hiddenGuis do
			if g.Parent then
				g.Enabled = true
			end
		end
		for _, t in hiddenCore do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(t, true)
			end)
		end
		table.clear(hiddenGuis)
		table.clear(hiddenCore)
	end
end

local function getGui()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Cutscene")
	if existing then
		return existing
	end
	local built = Build.build()
	built.Parent = pg
	return built
end

local function setBars(on: boolean, instant: boolean?)
	local share = K.BarShare
	local top = if on then UDim2.fromScale(0, share) else UDim2.fromScale(0, 0)
	local bottom = if on then UDim2.fromScale(0, 1 - share) else UDim2.fromScale(0, 1)
	if instant then
		gui.BarTop.Position = top
		gui.BarBottom.Position = bottom
	else
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Motion.tween(gui.BarTop, info, { Position = top })
		Motion.tween(gui.BarBottom, info, { Position = bottom })
	end
end

local function skipHintText(): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Hold A to skip"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Hold to skip"
	end
	return "Hold SPACE to skip"
end

-- Ends a held black screen (fade back to the world).
function Cutscene.releaseBlack(fadeSeconds: number?)
	blackToken += 1
	UIState.pop("CutsceneBlack")
	if not gui or playing then
		return
	end
	local fade = gui.Fade
	local t = Motion.tween(fade, TweenInfo.new(fadeSeconds or 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 1 })
	local token = blackToken
	t.Completed:Connect(function()
		if token == blackToken and not playing then
			gui.Enabled = false
		end
	end)
end

local function holdBlack()
	blackToken += 1
	local token = blackToken
	gui.Enabled = true
	gui.Fade.BackgroundTransparency = 0
	UIState.push("CutsceneBlack", { hideHUD = true, hidePhone = true, hideWaypoints = true, lockControls = true })
	task.delay(6, function()
		if token == blackToken then
			Cutscene.releaseBlack()
		end
	end)
end

---------------------------------------------------------------- evaluation helpers

type ActorRun = {
	actor: Actors.Actor,
	def: any,
	startPos: Vector3, -- local
	startDir: Vector3, -- local flat facing
	segs: { any },
	floorY: { [number]: number }, -- world floor height at each segment end (index 0 = start)
}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

local function lerpDir(a: Vector3, b: Vector3, w: number): Vector3
	local ya = math.atan2(-a.X, -a.Z)
	local yb = math.atan2(-b.X, -b.Z)
	local d = (yb - ya + math.pi) % (2 * math.pi) - math.pi
	local y = ya + d * w
	return Vector3.new(-math.sin(y), 0, -math.cos(y))
end

-- Where the camera aims for an actor: a steady point at head height above the ROOT, not the head part itself.
-- The head bobs with the walk/idle animations; aiming at it made the camera wobble (Alex: "it moves around when
-- he walks"). The offset is measured once, when the actor is first looked at.
local function headOf(actor: Actors.Actor): Vector3
	local a = actor :: any
	if a.headOffset == nil then
		local head = actor.model:FindFirstChild("Head") :: BasePart?
		a.headOffset = if head then math.clamp(head.Position.Y - actor.root.Position.Y, 0.8, 4) else 1.5
	end
	return actor.root.Position + Vector3.new(0, a.headOffset, 0)
end

---------------------------------------------------------------- marks (Piece 4)

-- A copy of `scene` with every "#Mark" / { mark, off } position turned into a local Vector3.
local function withMarks(scene: any, marks: any): any
	if scene.marks == nil and marks == nil then
		return scene
	end
	local all: { [string]: Vector3 } = {}
	for k, v in scene.marks or {} do
		all[k] = v
	end
	for k, v in (if type(marks) == "table" then marks else {}) do
		if type(k) == "string" and typeof(v) == "Vector3" then
			all[k] = v
		end
	end
	local function r(v: any): any
		if type(v) == "string" and string.sub(v, 1, 1) == "#" then
			local m = all[string.sub(v, 2)]
			if not m then
				warn("[MTL Cutscene] unknown mark", v)
			end
			return m or Vector3.zero
		elseif type(v) == "table" and type(v.mark) == "string" then
			local m = all[v.mark]
			if not m then
				warn("[MTL Cutscene] unknown mark", v.mark)
			end
			return (m or Vector3.zero) + (if typeof(v.off) == "Vector3" then v.off else Vector3.zero)
		end
		return v
	end
	local function cam(c: any): any
		if type(c) ~= "table" then
			return c
		end
		local out = table.clone(c)
		if out.pos ~= nil then
			out.pos = r(out.pos)
		end
		if out.look ~= nil then
			out.look = r(out.look)
		end
		return out
	end
	local copy = table.clone(scene)
	copy.actors = {}
	for name, def in scene.actors or {} do
		local d = table.clone(def)
		d.at = r(d.at)
		d.face = r(d.face)
		copy.actors[name] = d
	end
	copy.actions = {}
	for i, a in scene.actions or {} do
		local c = table.clone(a)
		if c.walk ~= nil then
			c.walk = r(c.walk)
		end
		if c.turn ~= nil then
			c.turn = r(c.turn)
		end
		copy.actions[i] = c
	end
	copy.shots = {}
	for i, sh in scene.shots or {} do
		local c = table.clone(sh)
		c.from = cam(c.from)
		c.to = cam(c.to)
		if c.focus ~= nil then
			c.focus = r(c.focus)
		end
		copy.shots[i] = c
	end
	-- Act 2 set scenes: where the real player ends up and what streams in can be marks too
	if scene.placePlayer then
		copy.placePlayer = table.clone(scene.placePlayer)
		copy.placePlayer.at = r(copy.placePlayer.at)
		copy.placePlayer.face = r(copy.placePlayer.face)
	end
	if scene.stream then
		copy.stream = {}
		for i, p in scene.stream do
			copy.stream[i] = r(p)
		end
	end
	return copy
end

---------------------------------------------------------------- play

---------------------------------------------------------------- dialogue box (portrait + typed line + blips)

local Sfx: any = nil
do
	local m = ReplicatedStorage.MTL.UI:FindFirstChild("Sfx")
	if m then
		local ok, mod = pcall(require, m)
		Sfx = if ok then mod else nil
	end
end

local dlg = { index = -1, typed = 0, who = nil :: string?, blipAt = 0 }

local THOUGHT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic)
local SPOKEN = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

-- A still 3D portrait of the speaker's head: the head + its hair/hat/glasses copied into the box's ViewportFrame,
-- framed from the front. Speakers without an actor in the scene (a text message, a voice) get their initial.
local function setPortrait(who: string?, actors: { [string]: any })
	local box = gui.Subtitle
	local portrait = box:FindFirstChild("Portrait")
	if not portrait then
		return
	end
	local view = portrait:FindFirstChild("View") :: ViewportFrame?
	local initial = portrait:FindFirstChild("Initial") :: TextLabel?
	local ring = portrait:FindFirstChild("Ring") :: UIStroke?
	local color = (K.Speakers :: any)[who] or K.SpeakerDefault
	if ring then
		ring.Color = color
	end
	if view then
		view:ClearAllChildren()
	end
	local actor = if who == "You" then actors.Player else (who and actors[who])
	local head = actor and actor.model:FindFirstChild("Head") :: BasePart?
	if view and head then
		local m = Instance.new("Model")
		local function copy(part: BasePart)
			local was = part.Archivable
			part.Archivable = true
			local c = part:Clone()
			part.Archivable = was
			for _, d in c:GetChildren() do
				if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
					d:Destroy()
				end
			end
			c.Anchored = true
			c.LocalTransparencyModifier = 0
			c.Parent = m
		end
		copy(head)
		for _, acc in actor.model:GetChildren() do
			local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and (handle.Position - head.Position).Magnitude < 4 then
				copy(handle)
			end
		end
		m.Parent = view
		local cam = view:FindFirstChildOfClass("Camera") or Instance.new("Camera")
		cam.FieldOfView = 30
		local look = head.CFrame.LookVector
		local focus = head.Position + Vector3.new(0, 0.05, 0)
		cam.CFrame = CFrame.lookAt(focus + look * 3.6 + head.CFrame.RightVector * 0.9 + Vector3.new(0, 0.25, 0), focus)
		cam.Parent = view
		view.CurrentCamera = cam
		if initial then
			initial.Text = ""
		end
		portrait.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	else
		local contact = who and (Story.Contacts :: any)[who]
		local name = if contact then contact.Name else (who or "?")
		if initial then
			initial.Text = string.upper(string.sub(string.gsub(name, "^Mr%. ", ""), 1, 1))
		end
		portrait.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	end
end

function showDialogue(line: any, index: number, shown: number, actors: { [string]: any }, seeking: boolean)
	local box = gui.Subtitle
	local textCol = box:FindFirstChild("Text") or box -- older reskins: labels straight under Subtitle
	local who = line.who
	if index ~= dlg.index then
		dlg.index = index
		dlg.typed = shown
		local contact = who and (Story.Contacts :: any)[who]
		local name = if contact then contact.Name else (who or "")
		if who == "You" then
			name = "You (thinking)"
		end
		textCol.Speaker.Text = string.upper(name)
		textCol.Speaker.TextColor3 = (K.Speakers :: any)[who] or K.SpeakerDefault
		textCol.Line.Text = line.text
		textCol.Line.FontFace = if who == "You" then THOUGHT else SPOKEN
		textCol.Line.TextColor3 = if who == "You" then Color3.fromRGB(220, 224, 236) else K.SubtitleText
		if who ~= dlg.who then
			dlg.who = who
			setPortrait(who, actors)
		end
		if not box.Visible then
			box.Visible = true
			local pop = box:FindFirstChild("Pop") :: UIScale?
			if pop then
				pop.Scale = 0.94
				Motion.tween(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			end
		end
	end
	textCol.Line.MaxVisibleGraphemes = if shown >= #line.text then -1 else shown
	local nxt = box:FindFirstChild("Next")
	if nxt then
		nxt.Visible = shown >= #line.text
	end
	-- typing blip: one soft tick every 2 new letters (not for spaces, not while seeking/skipping ahead)
	if shown > dlg.typed then
		local added = string.sub(line.text, dlg.typed + 1, shown)
		dlg.typed = shown
		if not seeking and Sfx and string.find(added, "%S") and os.clock() - dlg.blipAt > 0.045 then
			dlg.blipAt = os.clock()
			local base = if who == "You" then 0.92 else 1
			pcall(Sfx.play, "TextBlip", { pitch = base * (0.94 + math.random() * 0.14) })
		end
	end
end

function clearDialogue()
	if not gui then
		return
	end
	local box = gui.Subtitle
	local textCol = box:FindFirstChild("Text") or box
	textCol.Speaker.Text = ""
	textCol.Line.Text = ""
	box.Visible = false
	dlg.index = -1
	dlg.typed = 0
	dlg.who = nil
	local portrait = box:FindFirstChild("Portrait")
	local view = portrait and portrait:FindFirstChild("View")
	if view then
		view:ClearAllChildren()
	end
end

function Cutscene.play(id: string, opts: { [string]: any }?): boolean
	local o = opts or {}
	if playing then
		stopRequested = true
		while playing do
			task.wait()
		end
	end
	local module = ReplicatedStorage.MTL:FindFirstChild("Cutscenes") and ReplicatedStorage.MTL.Cutscenes:FindFirstChild(id)
	if not module then
		warn("[MTL Cutscene] no scene", id)
		return true
	end
	local okReq, scene = pcall(require, module)
	if not okReq or type(scene) ~= "table" then
		warn("[MTL Cutscene] bad scene", id, scene)
		return true
	end
	local problems = CutsceneRules.validate(scene)
	if #problems > 0 then
		warn("[MTL Cutscene]", id, "has problems:", table.concat(problems, "; "))
	end
	scene = withMarks(scene, o.marks)
	-- choice branches: a private copy whose lines/actions are filtered to what's been picked so far
	local rawScene = scene
	local choiceSpec = if type(rawScene.choice) == "table" then rawScene.choice else nil
	local chosen: string? = nil
	local function filtered(list: { any }?): { any }
		local out = {}
		for _, e in list or {} do
			if e.when == nil or e.when == chosen then
				table.insert(out, e)
			end
		end
		return out
	end
	scene = table.clone(rawScene)
	scene.lines = filtered(rawScene.lines)
	scene.actions = filtered(rawScene.actions)
	-- group scene (a party): skip is a vote, only the host picks on a choice card
	local group = if type(o.group) == "table" and (o.group.n or 1) > 1 then o.group else nil
	local myVote = false

	playing = true
	stopRequested = false
	blackToken += 1 -- a new scene takes over any held black
	UIState.pop("CutsceneBlack")
	local length = CutsceneRules.length(scene)
	local camera = workspace.CurrentCamera
	local anchor: CFrame = o.anchor or CFrame.new((player.Character and player.Character:GetPivot().Position) or Vector3.zero)
	local skipped = false
	local finished = false
	local conns: { RBXScriptConnection } = {}
	local actorRuns: { [string]: ActorRun } = {}
	local actors: { [string]: Actors.Actor } = {}
	local props: { [string]: Model } = {}
	local propRuns: { [string]: { base: CFrame, segs: { any } } } = {}
	local effects: { Instance } = {}
	local ambience: Sound? = nil
	local music: Sound? = nil
	local realParts: { BasePart | Decal } = {}
	local savedType = camera.CameraType
	local savedFov = camera.FieldOfView
	local t = 0
	local lastT = -1
	local typedDone: { [number]: boolean } = {}
	local pressStart: number? = nil
	local playClock = 0 -- real seconds since start (for the skip grace)
	local ctx: any = { anchor = anchor, actors = actors, props = props, camera = camera, scene = scene, t = 0 }

	Cutscene.Started:Fire(id, scene)
	log("play", id, string.format("%.1fs", length))

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		for _, a in actors do
			Actors.destroy(a)
		end
		for _, p in props do
			p:Destroy()
		end
		for _, e in effects do
			e:Destroy()
		end
		for _, snd in { ambience, music } do
			local s = snd :: Sound
			Motion.tween(s, TweenInfo.new(if s == music then 1.5 else 0.5), { Volume = 0 })
			task.delay(1.6, function()
				s:Destroy()
			end)
		end
		for _, p in realParts do
			(p :: any).LocalTransparencyModifier = 0
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local lastShot = scene.shots and scene.shots[#scene.shots]
		local endsInPlay = lastShot and ((lastShot.to and lastShot.to.gameplay) or lastShot.from.gameplay)
		local handoff = endsInPlay
		if endsInPlay and char then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if skipped and root then
				-- skipped: jump straight to where the hand-off would have ended (behind you), not a random angle
				local spec = if lastShot.to and lastShot.to.gameplay then lastShot.to else lastShot.from
				local focus = root.Position + UP * 1.5
				local back = flat(root.CFrame.LookVector)
				camera.CFrame = CFrame.lookAt(focus - back * (spec.dist or 12) + UP * (spec.height or 3.4), focus)
			end
			camera.Focus = CFrame.new(char:GetPivot().Position + UP * 1.5)
		end
		camera.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
		if hum then
			camera.CameraSubject = hum
		end
		-- a close hand-off (e.g. indoors: the default 12.5-stud zoom would sit outside the window) keeps its distance:
		-- clamp the zoom for a moment; raising the limit again doesn't zoom back out
		local handDist = handoff and ((lastShot.to and lastShot.to.dist) or lastShot.from.dist)
		if type(handDist) == "number" then
			local maxZoom = player.CameraMaxZoomDistance
			player.CameraMaxZoomDistance = math.max(handDist, player.CameraMinZoomDistance)
			task.delay(0.25, function()
				player.CameraMaxZoomDistance = maxZoom
			end)
		end
		camera.FieldOfView = if savedFov >= 20 and savedFov <= 120 then savedFov else 70
		clearDialogue()
		local choiceCard = gui:FindFirstChild("Choice")
		if choiceCard then
			choiceCard.Visible = false
		end
		gui.Title.Visible = false
		gui.Skip.Visible = false
		setBars(false)
		hideOthers(false)
		player:SetAttribute("MTL_Cutscene", nil)
	end

	local function finish(wasSkipped: boolean)
		if finished then
			return
		end
		finished = true
		skipped = wasSkipped
		local ok, err = pcall(cleanup)
		if not ok then
			warn("[MTL Cutscene] cleanup error:", err)
			camera.CameraType = Enum.CameraType.Custom
		end
		if scene.holdBlack then
			holdBlack()
		else
			Motion.tween(gui.Fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
			local token = blackToken
			task.delay(0.4, function()
				if not playing and token == blackToken then
					gui.Enabled = false
				end
			end)
		end
		UIState.pop("Cutscene")
		playing = false
		if o.token then
			Net.get("CutsceneDone"):FireServer({ id = id, token = o.token, skipped = wasSkipped, choice = chosen })
		end
		log("done", id, if wasSkipped then "(skipped)" else "")
		Cutscene.Finished:Fire(id, wasSkipped)
	end

	local okSetup, setupErr = pcall(function()
		gui.Enabled = true
		gui.Fade.BackgroundTransparency = 0 -- hide the setup frame
		gui.Title.Visible = false
		clearDialogue()
		gui.Skip.Visible = false
		gui.Skip.Bar.Fill.Size = UDim2.fromScale(0, 1)
		gui.Skip.Hint.Text = skipHintText()
		setBars(true)
		hideOthers(true)
		player:SetAttribute("MTL_Cutscene", id) -- other camera effects (run sway, shake) must stay off while this is set
		UIState.push("Cutscene", { hideHUD = true, hidePhone = true, hideWaypoints = true, lockControls = true })
		camera.CameraType = Enum.CameraType.Scriptable

		-- hide the real character (the clone stars instead)
		local char = player.Character
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					table.insert(realParts, d)
				end
			end
		end
		local here = if char then anchor:ToObjectSpace(char:GetPivot()) else CFrame.new()

		-- actors
		for name, def in scene.actors or {} do
			local actor = Actors.spawn(def.rig)
			if actor then
				actors[name] = actor
				local at = if def.at == "@here" then Vector3.new(here.Position.X, 0, here.Position.Z) else (def.at or Vector3.zero)
				actorRuns[name] = { actor = actor, def = def, startPos = at, startDir = Vector3.new(0, 0, -1), segs = {}, floorY = {} }
			end
		end
		-- facing needs every actor's start position
		for name, run in actorRuns do
			local face = run.def.face
			local dir = Vector3.new(0, 0, -1)
			if typeof(face) == "Vector3" then
				dir = flat(face - run.startPos)
			elseif face == "@here" then
				dir = flat(here.LookVector)
			elseif type(face) == "string" and string.sub(face, 1, 1) == "@" then
				local other = actorRuns[string.sub(face, 2)]
				if other then
					dir = flat(other.startPos - run.startPos)
				end
			end
			run.startDir = dir
		end
		-- motion segments per actor (walk/turn), in order, each starting where the last ended
		for _, a in scene.actions or {} do
			local run = a.actor and actorRuns[a.actor]
			if run and (a.walk or a.turn) then
				table.insert(run.segs, a)
			end
		end
		for name, run in actorRuns do
			local pos = run.startPos
			run.floorY[0] = Actors.floor(anchor:PointToWorldSpace(pos))
			for i, sgm in run.segs do
				if sgm.walk then
					pos = sgm.walk
				end
				run.floorY[i] = Actors.floor(anchor:PointToWorldSpace(pos))
			end
		end
		-- props
		for name, def in scene.props or {} do
			local m = Actors.prop(def.prop, def) -- the def doubles as the builder's opts (hazards, boxes, text...)
			if m then
				props[name] = m
				local base = def.at or CFrame.new()
				local floorY = Actors.floor(anchor:PointToWorldSpace(base.Position))
				local world = anchor * base
				m:PivotTo(world + Vector3.new(0, floorY - world.Position.Y, 0))
				local segs = {}
				for _, a in scene.actions or {} do
					if a.prop == name and a.move then
						table.insert(segs, a)
					end
				end
				-- wheels (parts named Tire / Rim around each Tire's hub) roll while the prop moves
				local wheels = {}
				local piv = m:GetPivot()
				for _, t in m:GetDescendants() do
					if t:IsA("BasePart") and t.Name == "Tire" then
						local hub = piv:PointToObjectSpace(t.Position)
						local parts = {}
						for _, p in m:GetDescendants() do
							if p:IsA("BasePart") and (p.Name == "Tire" or p.Name == "Rim") then
								local lp = piv:PointToObjectSpace(p.Position)
								if math.abs(lp.Y - hub.Y) < 0.4 and math.abs(lp.Z - hub.Z) < 0.4 and math.abs(lp.X - hub.X) < 0.6 then
									table.insert(parts, { part = p, rel = piv:ToObjectSpace(p.CFrame) })
								end
							end
						end
						table.insert(wheels, { hub = hub, radius = math.max(t.Size.Y, t.Size.Z) / 2, parts = parts })
					end
				end
				propRuns[name] = { base = base, segs = segs, floorY = floorY, wheels = wheels } :: any
			end
		end
		-- grade, depth of field, ambience
		if scene.grade then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "MTL_CutsceneGrade"
			cc.TintColor = scene.grade.TintColor or Color3.new(1, 1, 1)
			cc.Saturation = scene.grade.Saturation or 0
			cc.Contrast = scene.grade.Contrast or 0
			cc.Brightness = scene.grade.Brightness or 0
			cc.Parent = Lighting
			table.insert(effects, cc)
		end
		if scene.dof then
			local dof = Instance.new("DepthOfFieldEffect")
			dof.Name = "MTL_CutsceneDOF"
			dof.FarIntensity = 0.35
			dof.NearIntensity = 0
			dof.InFocusRadius = 7
			dof.FocusDistance = 12
			dof.Parent = Lighting
			table.insert(effects, dof)
			ctx.dof = dof
		end
		local amb = soundId(scene.ambience)
		if amb then
			local s = Instance.new("Sound")
			s.Name = "MTL_Ambience"
			s.SoundId = amb
			s.Looped = true
			s.Volume = 0.35
			s.Parent = gui
			s:Play()
			ambience = s
		end
		-- camera fill light: a soft warm light riding just beside the lens, so faces read at night and indoors (the
		-- cheapest "lit like a film set" trick). scene.fill = brightness (0 = off; default 0.9, more when the scene
		-- holds a night hour)
		local fill = if type(scene.fill) == "number" then scene.fill else 0.55 -- subtle: faces read, the lighting doesn't visibly change
		if fill > 0 then
			local lp = Instance.new("Part")
			lp.Name = "MTL_CamFill"
			lp.Anchored = true
			lp.CanCollide = false
			lp.CanQuery = false
			lp.CanTouch = false
			lp.CastShadow = false
			lp.Transparency = 1
			lp.Size = Vector3.new(0.2, 0.2, 0.2)
			local light = Instance.new("PointLight")
			light.Brightness = fill
			light.Range = 18
			light.Color = Color3.fromRGB(255, 236, 214)
			light.Shadows = false
			light.Parent = lp
			lp.Parent = Actors.folder()
			table.insert(effects, lp)
			ctx.fillLight = lp
		end
		local mus = soundId(scene.music)
		if mus then
			local s = Instance.new("Sound")
			s.Name = "MTL_Music"
			pcall(function() -- matched loudness, a bit quieter (SFX thread; the module may not exist in older installs)
				require(ReplicatedStorage.MTL.UI:FindFirstChild("MusicLevel") :: any).attach(s)
			end)
			s.SoundId = mus
			s.Looped = true
			s.Volume = 0
			s.Parent = gui
			s:Play()
			Motion.tween(s, TweenInfo.new(2, Enum.EasingStyle.Sine), { Volume = scene.musicVolume or 0.4 })
			music = s
		end
		-- world pieces the scene replaces with its own props (e.g. the Food Mart's real AutoDoors while FirstDay's
		-- door props play): hidden for this player only, kept hidden every frame like the real character
		for _, h in (if type(scene.hideWorld) == "table" then scene.hideWorld else {}) do
			local at = if typeof(h.at) == "Vector3" then anchor:PointToWorldSpace(h.at) else anchor.Position
			for _, p in workspace:GetPartBoundsInRadius(at, h.radius or 8) do
				local m = p:FindFirstAncestor(h.name)
				if m and not p:IsDescendantOf(Actors.folder()) then
					table.insert(realParts, p)
					for _, d in p:GetDescendants() do
						if d:IsA("Decal") then
							table.insert(realParts, d)
						end
					end
				end
			end
		end
		-- the real character stands where the scene will end (hidden until then), so a hand-off lands on it
		if type(scene.placePlayer) == "table" and char then
			local at = scene.placePlayer.at
			local face = scene.placePlayer.face
			if at == "@here" then
				at = Vector3.new(here.Position.X, 0, here.Position.Z)
			end
			if typeof(at) == "Vector3" then
				local floorY = Actors.floor(anchor:PointToWorldSpace(at), { char })
				local w = anchor:PointToWorldSpace(at)
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hip = if root then (char:GetPivot().Position.Y - Actors.floor(char:GetPivot().Position, { char })) else 3
				local pos = Vector3.new(w.X, floorY + math.clamp(hip, 2, 6), w.Z)
				local dir = if typeof(face) == "Vector3" then flat(anchor:PointToWorldSpace(face) - pos) else flat(char:GetPivot().LookVector)
				char:PivotTo(CFrame.lookAt(pos, pos + dir))
				if root then
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
	if not okSetup then
		warn("[MTL Cutscene] setup failed:", setupErr)
		finish(true)
		return true
	end
	-- stream far shots in while the screen is still black (StreamingEnabled), never longer than 2.5 s
	if type(scene.stream) == "table" and #scene.stream > 0 then
		local pending = #scene.stream
		for _, lp in scene.stream do
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(anchor:PointToWorldSpace(lp), 2.5)
				end)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 2.5 do
			waited += task.wait()
		end
	end

	---------------------------------------------------------------- per-frame evaluation

	local function actorTransform(run: ActorRun, now: number): (CFrame, number, number, Vector3)
		local pos, dir = run.startPos, run.startDir
		local floorA = run.floorY[0]
		local floorY = floorA
		local walking, walkDist = 0, 0
		for i, sgm in run.segs do
			local t0 = sgm.t or 0
			if now < t0 then
				break
			end
			local dur = math.max(sgm.dur or 0.4, 0.01)
			local a = math.clamp((now - t0) / dur, 0, 1)
			local floorB = run.floorY[i] or floorA
			if sgm.walk then
				local from, to = pos, sgm.walk :: Vector3
				local e = CutsceneRules.ease(sgm.ease or "Sine", a)
				pos = from:Lerp(to, e)
				local travel = to - from
				if travel.Magnitude > 0.05 then
					dir = lerpDir(dir, flat(travel), math.clamp(a * 5, 0, 1))
				end
				floorY = floorA + (floorB - floorA) * e
				if a < 1 then
					walking = math.min(1, a * 6, (1 - a) * 6)
					walkDist = (to - from).Magnitude * e
				end
			elseif sgm.turn then
				local target: Vector3? = nil
				if typeof(sgm.turn) == "Vector3" then
					target = sgm.turn
				elseif type(sgm.turn) == "string" then
					local other = actorRuns[(string.gsub(sgm.turn, "^@", ""))]
					target = other and other.startPos
				end
				if target then
					dir = lerpDir(dir, flat(target - pos), CutsceneRules.ease("Sine", a))
				end
			end
			floorA = floorB
		end
		local worldPos = anchor:PointToWorldSpace(pos)
		local worldDir = anchor:VectorToWorldSpace(dir)
		local cf = CFrame.lookAt(Vector3.new(worldPos.X, floorY, worldPos.Z), Vector3.new(worldPos.X, floorY, worldPos.Z) + worldDir)
		return cf, walking, walkDist, worldDir
	end

	local function lastOf(list: { any }, now: number, field: string): (any?, any?)
		local cur, prev = nil, nil
		for _, a in list do
			if (a.t or 0) > now then
				break
			end
			if a[field] ~= nil then
				prev = cur
				cur = a
			end
		end
		return cur, prev
	end

	local function actorActions(name: string): { any }
		local out = {}
		for _, a in scene.actions or {} do
			if a.actor == name then
				table.insert(out, a)
			end
		end
		return out
	end
	local perActor: { [string]: { any } } = {}
	for name in actorRuns do
		perActor[name] = actorActions(name)
	end

	local function lookPoint(look: any): Vector3
		if typeof(look) == "Vector3" then
			return anchor:PointToWorldSpace(look)
		elseif type(look) == "string" then
			if actors[look] then
				return headOf(actors[look])
			elseif props[look] then
				return props[look]:GetPivot().Position + Vector3.new(0, 2.5, 0)
			end
		end
		return anchor.Position + UP * 3
	end

	local function spline(points: { Vector3 }, a: number): Vector3
		local n = #points
		if n == 1 then
			return points[1]
		end
		local s = math.clamp(a, 0, 1) * (n - 1)
		local i = math.min(math.floor(s) + 1, n - 1)
		local u = s - (i - 1)
		local p0, p1, p2, p3 = points[math.max(i - 1, 1)], points[i], points[i + 1], points[math.min(i + 2, n)]
		local u2, u3 = u * u, u * u * u
		return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
	end

	local function resolveCam(spec: any, alpha: number?): (Vector3, Vector3)
		if spec.path then
			local a = alpha or 0
			local pos = anchor:PointToWorldSpace(spline(spec.path, a))
			local look = if spec.lookPath then anchor:PointToWorldSpace(spline(spec.lookPath, a)) else lookPoint(spec.look)
			return pos, look
		elseif spec.gameplay then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local focus = root.Position + UP * 1.5
				local back = flat(root.CFrame.LookVector)
				return focus - back * (spec.dist or 12) + UP * (spec.height or 3.4), focus
			end
		end
		if spec.pos then
			return anchor:PointToWorldSpace(spec.pos), lookPoint(spec.look)
		elseif spec.two then
			local a, b = actors[spec.two[1]], actors[spec.two[2]]
			if a and b then
				local ha, hb = headOf(a), headOf(b)
				local mid = (ha + hb) / 2
				local d = flat(hb - ha)
				local perp = Vector3.new(-d.Z, 0, d.X) * (spec.side or 1)
				return mid + perp * (spec.dist or 12) + UP * (spec.height or 0.5), mid
			end
		elseif spec.close then
			local a = actors[spec.close]
			if a then
				local h = headOf(a)
				local fwd = flat(a.root.CFrame.LookVector)
				local right = flat(a.root.CFrame.RightVector)
				return h + fwd * (spec.dist or 5) + right * 1.3 * (spec.side or 1) + UP * 0.25, h
			end
		elseif spec.ots then
			local l, s = actors[spec.ots[1]], actors[spec.ots[2]]
			if l and s then
				local hl, hs = headOf(l), headOf(s)
				local dir = (hs - hl)
				dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
				local right = dir:Cross(UP)
				right = if right.Magnitude > 0.01 then right.Unit else Vector3.new(1, 0, 0)
				return hl - dir * (spec.dist or 4.5) + right * (spec.side or 1.6) + UP * 0.45, hs
			end
		end
		return anchor.Position + Vector3.new(0, 8, 20), anchor.Position
	end

	local camParams = RaycastParams.new()
	camParams.FilterType = Enum.RaycastFilterType.Exclude
	local function safeCam(pos: Vector3, look: Vector3): Vector3
		local list: { Instance } = { Actors.folder() }
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(list, p.Character)
			end
		end
		-- only solid, visible things block the camera: glass, plexi, invisible zones and walk-through parts don't
		-- (they used to pull the camera into a shop counter's plexi screen)
		local d = pos - look
		for _ = 1, 6 do
			camParams.FilterDescendantsInstances = list
			local hit = workspace:Raycast(look, d, camParams)
			if not hit then
				return pos
			end
			local part = hit.Instance
			if part:IsA("BasePart") and part.Transparency < 0.3 and part.CanCollide then
				return hit.Position - d.Unit * 0.6
			end
			table.insert(list, part)
		end
		return pos
	end

	local function shakeAt(now: number): Vector3
		local v = Vector3.zero
		for _, a in scene.actions or {} do
			if a.shake and now >= a.t and now < a.t + (a.dur or 0.5) then
				local k = (1 - (now - a.t) / (a.dur or 0.5)) * a.shake
				v += Vector3.new(math.noise(now * 25, 1.3) * k, math.noise(now * 25, 7.1) * k, 0)
			end
		end
		return v
	end

	local function blackAt(now: number): number
		local black = 1 - math.clamp(now / math.max(scene.fadeIn or 0.6, 0.01), 0, 1)
		local f, prevF = lastOf(scene.actions or {}, now, "fade")
		if f then
			local a = math.clamp((now - f.t) / math.max(f.dur or 0.5, 0.01), 0, 1)
			if f.fade == "out" then
				black = math.max(black, a)
			elseif prevF and prevF.fade == "out" then
				black = 1 - a -- fading back in after a fade out (Piece 4: "NEXT DAY")
			else
				black = math.min(black, 1 - a)
			end
			if f.fade == "out" and a >= 1 then
				black = 1
			end
		end
		return black
	end

	local function render(now: number)
		ctx.t = now
		-- actors
		local line, lineIndex = CutsceneRules.lineAt(scene.lines or {}, now)
		for name, run in actorRuns do
			local actor = run.actor
			local cf, walking, walkDist = actorTransform(run, now)
			local list = perActor[name]
			local poseA, poseB = lastOf(list, now, "pose")
			local g: any = nil
			for _, a in list do
				if a.gesture and now >= a.t and now <= a.t + (a.dur or 1.2) then
					g = a
				end
			end
			local hideA = lastOf(list, now, "hide")
			local holdA = lastOf(list, now, "hold")
			local poseName = if poseA then poseA.pose elseif run.def.pose then run.def.pose else "None"
			local prevName = if poseB then poseB.pose elseif poseA and run.def.pose then run.def.pose else "None"
			local state: any = {
				pose = poseName,
				prevPose = prevName,
				poseT0 = if poseA then poseA.t else -10,
				gesture = if g then g.gesture else nil,
				gestureT0 = if g then g.t else nil,
				gestureDur = if g then g.dur else nil,
				walk = walking,
				walkPhase = walkDist * 1.5,
				hold = if holdA and holdA.hold then holdA.hold elseif holdA == nil then run.def.hold else nil,
			}
			-- heads follow whoever is talking (the speaker looks at the player)
			local target: Actors.Actor? = nil
			if line and line.who then
				if line.who == name then
					target = actors.Player
				else
					target = actors[line.who]
				end
			end
			if target and target ~= actor then
				local rel = cf:PointToObjectSpace(headOf(target))
				state.lookYaw = math.atan2(-rel.X, -rel.Z)
			end
			Actors.place(actor, cf, Rig.drop(state))
			Actors.setHidden(actor, hideA ~= nil and hideA.hide == true)
			Actors.render(actor, state, now)
		end
		-- props
		for name, pr in propRuns :: any do
			local m = props[name]
			local cfLocal = pr.base
			for _, sgm in pr.segs do
				if now < sgm.t then
					break
				end
				local a = CutsceneRules.ease(sgm.ease or "Sine", (now - sgm.t) / math.max(sgm.dur or 1, 0.01))
				cfLocal = cfLocal:Lerp(sgm.move, a)
			end
			local world = anchor * cfLocal
			local placed = world + Vector3.new(0, pr.floorY - (anchor * pr.base).Position.Y, 0)
			local wheels = pr.wheels
			if wheels and #wheels > 0 then
				-- launch squat: the nose lifts a touch over the rear axle as it pulls away, the wheels stay planted
				local squat = 0
				for _, sgm in pr.segs do
					local u = (now - sgm.t) / math.max(sgm.dur or 1, 0.01)
					if u > 0 and u < 1 then
						squat = math.rad(2.2) * math.sin(math.min(u * 2.5, 1) * math.pi)
					end
				end
				local rear = 0
				for _, w in wheels do
					rear = math.max(rear, w.hub.Z)
				end
				m:PivotTo(placed * CFrame.new(0, 0, rear) * CFrame.Angles(squat, 0, 0) * CFrame.new(0, 0, -rear))
				-- roll: distance travelled / tyre radius (front = -Z, so the tops turn toward -Z)
				local roll = -(cfLocal.Position - pr.base.Position).Magnitude / wheels[1].radius
				for _, w in wheels do
					local spin = placed * CFrame.new(w.hub) * CFrame.Angles(roll, 0, 0) * CFrame.new(-w.hub)
					for _, p in w.parts do
						p.part.CFrame = spin * p.rel
					end
				end
			else
				m:PivotTo(placed)
			end
		end
		-- camera
		local shots = scene.shots
		local si = math.max(CutsceneRules.indexAt(shots, now), 1)
		local shot = shots[si]
		local alpha = CutsceneRules.shotAlpha(shot, now)
		local p1, l1 = resolveCam(shot.from, alpha)
		local pos, look = p1, l1
		if shot.to then
			local p2, l2 = resolveCam(shot.to, alpha)
			pos, look = p1:Lerp(p2, alpha), l1:Lerp(l2, alpha)
		end
		if shot.safe ~= false then
			pos = safeCam(pos, look)
		end
		local fov = shot.fov or 60
		if shot.fovTo then
			fov += (shot.fovTo - fov) * alpha
		end
		local hand = shot.handheld or 0
		local noise = Vector3.zero
		local roll = 0
		if hand > 0 then
			noise = Vector3.new(math.noise(now * 7.3, 0.2), math.noise(now * 8.1, 3.7), math.noise(now * 6.7, 9.1)) * hand * 10
			roll = math.noise(now * 5.3, 4.4) * hand * 0.6
		end
		local shake = shakeAt(now)
		camera.CFrame = CFrame.lookAt(pos + noise + shake, look + noise * 0.5) * CFrame.Angles(0, 0, roll)
		if ctx.fillLight then
			ctx.fillLight.CFrame = camera.CFrame * CFrame.new(1.6, 0.8, -0.5)
		end
		camera.FieldOfView = math.clamp(fov, 20, 80)
		if ctx.dof then
			local focusAt = if shot.focus ~= nil then lookPoint(shot.focus) else look
			ctx.dof.FocusDistance = math.clamp((pos - focusAt).Magnitude, 0, 200)
			ctx.dof.FarIntensity = shot.blur or 0.35
		end
		-- the real character stays hidden (camera scripts may reset it)
		for _, p in realParts do
			(p :: any).LocalTransparencyModifier = 1
		end
		-- fade + title
		gui.Fade.BackgroundTransparency = 1 - blackAt(now)
		local title = nil
		for _, a in scene.actions or {} do
			if a.title and now >= a.t and now <= a.t + (a.dur or 2) then
				title = a
			end
		end
		if title then
			gui.Title.Visible = true
			gui.Title.Main.Text = title.title
			gui.Title.Sub.Text = title.sub or ""
			local lt = now - title.t
			local alphaT = math.min(lt / 0.3, ((title.dur or 2) - lt) / 0.3, 1)
			gui.Title.Main.TextTransparency = 1 - math.clamp(alphaT, 0, 1)
			gui.Title.Sub.TextTransparency = 1 - math.clamp(alphaT - 0.15, 0, 1)
			local rule = gui.Title:FindFirstChild("Rule")
			if rule then
				rule.BackgroundTransparency = 1 - math.clamp(alphaT - 0.1, 0, 1)
				rule.Visible = (title.sub or "") ~= ""
			end
		else
			gui.Title.Visible = false
		end
		-- dialogue box: portrait + name tag + typed line (+ a soft blip per few letters, only while typing live)
		if line then
			local shown = if typedDone[lineIndex] then #line.text else CutsceneRules.typed(line.text, line.t, now)
			showDialogue(line, lineIndex, shown, actors, now - lastT > 0.3)
		else
			clearDialogue()
		end
		-- one-shot actions crossed since the last frame
		if now > lastT then
			local late = now - lastT > 0.3 -- seeking: skip sounds
			for _, a in CutsceneRules.crossed(scene.actions or {}, lastT, now) do
				if a.sound and not late then
					playSound(a.sound, a.volume)
				elseif a.title and not late then
					playSound("Title", 0.5)
				elseif a.call and customActions[a.call] then
					local ok, err = pcall(customActions[a.call], ctx, a)
					if not ok then
						warn("[MTL Cutscene] action", a.call, "failed:", err)
					end
				end
			end
		end
		lastT = now
	end

	---------------------------------------------------------------- input: tap = line, hold = skip

	local function tap()
		if choiceShown and not chosen then
			return -- the card is up: pick with a button / number key
		end
		local lines = scene.lines or {}
		local target, finishLine = CutsceneRules.tapTarget(lines, t)
		if finishLine then
			local _, i = CutsceneRules.lineAt(lines, t)
			typedDone[i] = true
		elseif target and target < length then
			t = target
		end
	end
	local function pressBegin()
		pressStart = os.clock()
	end
	local function pressEnd()
		if pressStart and os.clock() - pressStart < CutsceneRules.SkipHold then
			tap()
		end
		pressStart = nil
		gui.Skip.Bar.Fill.Size = UDim2.fromScale(0, 1)
	end
	local SKIP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.Return] = true, [Enum.KeyCode.ButtonA] = true }
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if SKIP_KEYS[input.KeyCode] then
			pressBegin()
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if SKIP_KEYS[input.KeyCode] then
			pressEnd()
		end
	end))
	table.insert(conns, gui.Tap.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressBegin()
		end
	end))
	table.insert(conns, gui.Tap.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressEnd()
		end
	end))

	---------------------------------------------------------------- choice card

	local choiceGui = gui:FindFirstChild("Choice")
	local choiceShown = false
	local function pick(optId: string)
		if chosen or not choiceSpec then
			return
		end
		chosen = optId
		scene.lines = filtered(rawScene.lines)
		scene.actions = filtered(rawScene.actions)
		for name in actorRuns do
			perActor[name] = actorActions(name)
		end
		typedDone = {}
		if choiceGui then
			choiceGui.Visible = false
		end
		GuiService.SelectedObject = nil
		playSound("Confirm", 0.4)
		log("choice", id, optId)
		if group and group.host then
			Net.get("CutsceneInput"):FireServer({ token = o.token, type = "choice", choice = optId })
		end
	end
	local function showChoice()
		if choiceShown or not choiceSpec or not choiceGui then
			return
		end
		choiceShown = true
		clearDialogue()
		choiceGui.Prompt.Text = choiceSpec.prompt or ""
		choiceGui.Prompt.Visible = (choiceSpec.prompt or "") ~= ""
		local list = choiceGui.Options
		for _, c in list:GetChildren() do
			if c:IsA("GuiButton") and c.Name ~= "OptionTemplate" then
				c:Destroy()
			end
		end
		if group and not group.host then
			-- the host decides for the party; you see whom you're waiting for
			choiceGui.Prompt.Text = string.format("Waiting for %s to choose...", tostring(group.hostName or "the host"))
			choiceGui.Prompt.Visible = true
			choiceGui.Visible = true
			return
		end
		local first: GuiButton? = nil
		for i, opt in choiceSpec.options or {} do
			local b = list.OptionTemplate:Clone()
			b.Name = "Option" .. i
			b.LayoutOrder = i
			b.Visible = true
			b.Num.Text = tostring(i)
			b.Label.Text = opt.text
			b.Parent = list
			b.Activated:Connect(function()
				pick(opt.id)
			end)
			first = first or b
		end
		choiceGui.Visible = true
		local pop = choiceGui:FindFirstChild("Pop") :: UIScale?
		if pop then
			pop.Scale = 0.94
			Motion.tween(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end
		playSound("Open", 0.35)
		if first and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = first
		end
	end
	local NUM_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3 }
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		local n = NUM_KEYS[input.KeyCode]
		if n and choiceShown and not chosen and choiceSpec and choiceSpec.options[n] and not (group and not group.host) then
			pick(choiceSpec.options[n].id)
		end
	end))

	---------------------------------------------------------------- run

	local done = Instance.new("BindableEvent")
	local hintText = gui.Skip.Hint.Text
	if group then
		syncHandler = function(msg: any)
			if msg.token ~= o.token then
				return
			end
			if msg.type == "votes" then
				gui.Skip.Hint.Text = string.format("%d/%d want to skip", msg.count or 0, group.n)
			elseif msg.type == "end" then
				stopRequested = true
			elseif msg.type == "choice" and type(msg.choice) == "string" then
				pick(msg.choice)
			end
		end
		table.insert(conns, ({ Disconnect = function()
			syncHandler = nil
			gui.Skip.Hint.Text = hintText
		end } :: any))
		-- everyone in the party starts on the same frame (server clock); never wait more than 3 s
		if type(o.startAt) == "number" then
			local wait = o.startAt - workspace:GetServerTimeNow()
			if wait > 0 then
				task.wait(math.min(wait, 3))
			end
		end
	end
	-- bound LAST in the render step, after every camera script, so nothing (gameplay sway, camera modules) can move
	-- the cutscene camera; unbound with the other connections
	local bindName = "MTL_CutsceneCam"
	table.insert(conns, ({ Disconnect = function()
		RunService:UnbindFromRenderStep(bindName)
	end } :: any))
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
		if finished then
			return
		end
		playClock += dt
		t += dt
		local skippable = scene.skippable ~= false
		if skippable and playClock >= CutsceneRules.SkipGrace then
			gui.Skip.Visible = true
			if pressStart then
				local held = os.clock() - pressStart
				gui.Skip.Bar.Fill.Size = UDim2.fromScale(math.clamp(held / CutsceneRules.SkipHold, 0, 1), 1)
				if held >= CutsceneRules.SkipHold then
					if choiceSpec and not chosen then
						-- skip runs up TO the choice card (the story needs the pick), not past it
						pressStart = nil
						gui.Skip.Bar.Fill.Size = UDim2.fromScale(0, 1)
						t = math.max(t, choiceSpec.t)
					elseif group then
						-- a party votes; the server ends it for everyone (CutsceneSync "end")
						pressStart = nil
						gui.Skip.Bar.Fill.Size = UDim2.fromScale(0, 1)
						if not myVote then
							myVote = true
							playSound("Skip", 0.3)
							Net.get("CutsceneInput"):FireServer({ token = o.token, type = "skip" })
							gui.Skip.Hint.Text = "Waiting for the others"
						end
					else
						playSound("Skip", 0.4)
						finish(true)
						done:Fire()
						return
					end
				end
			end
		end
		if stopRequested then
			finish(true)
			done:Fire()
			return
		end
		-- the scene holds on its choice card until a pick
		if choiceSpec and not chosen and t >= choiceSpec.t then
			t = choiceSpec.t
			showChoice()
		end
		local ok, err = pcall(render, math.min(t, length))
		if not ok then
			warn("[MTL Cutscene] render error:", err)
			finish(true)
			done:Fire()
			return
		end
		if t >= length then
			finish(false)
			done:Fire()
		end
	end)
	-- a respawn mid-scene ends it cleanly
	table.insert(conns, player.CharacterRemoving:Connect(function()
		task.defer(function()
			if not finished then
				finish(true)
				done:Fire()
			end
		end)
	end))
	if not finished then
		done.Event:Wait()
	end
	done:Destroy()
	return skipped, chosen
end

function Cutscene.init()
	gui = getGui()
	gui.Enabled = false
	Net.get("PlayCutscene").OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or type(msg.id) ~= "string" then
			return
		end
		task.spawn(Cutscene.play, msg.id, {
			anchor = if typeof(msg.anchor) == "CFrame" then msg.anchor else nil,
			token = msg.token,
			marks = if type(msg.marks) == "table" then msg.marks else nil,
			group = if type(msg.group) == "table" then msg.group else nil,
			startAt = if type(msg.startAt) == "number" then msg.startAt else nil,
		})
	end)
	Net.get("CutsceneSync").OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and syncHandler then
			syncHandler(msg)
		end
	end)
end

return Cutscene
