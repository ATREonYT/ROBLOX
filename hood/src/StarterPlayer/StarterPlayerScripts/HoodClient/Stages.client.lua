-- Stage gates and their pads on your screen (brief 23: the run loop).
-- Each gate is a see-through haze between two pillars under a hazard beam, built SHUT (a red-tinted haze, two
-- hazard-striped barrier bars and a big padlock), with one floating sign in the opening: "STAGE N", "Recommended",
-- "Power: X" (guidance: Power opens nothing) and a state line on a badge (the video's gate).
--   Shut   the crew of the stage before it still stands this run (the server's RunStage, the furthest gate open for
--          you this run, is below it): the wall is solid for you; the badge reads "Defeat the crew first". Walk into it
--          and it flashes red and bumps you back.
--   Open   gate 1 always; any other the moment you beat the crew before it (RunCleared goes up): the haze shatters
--          toward you, the bars and padlock drop, confetti bursts, the camera kicks, "STAGE N OPEN!", and the sign turns
--          compact and low: "STAGE N" over a green "OPEN!" (at eye level from the pads, under the HUD's goal band).
--          Going back to the lobby ends the run: every gate shuts again at once.
-- Only your next gate (the first one ahead of you) shows its sign, so signs never stack down the street; it grows with
-- the distance (up to GrowMax) so it stays readable from the lobby, through the hall's doorway, and its outline
-- thickens to match.
-- The pads (parts tagged HoodStagePad, attributes Stage and Kind; the server pays): their own colour a notch darker,
-- reading the reward over "🔒 Clear the crew!", until that stage's crew is down this run; then lit, with sparkles and
-- their words: "+10 Cash / Return" (yellow) and
-- "+100 Cash / 10x Cash" (magenta, with the pass's Robux price while you don't own it), from Shared/PadRules. Their
-- labels fade and pop with the distance (HoodClient/LabelFade: FadeNear / FadeFar on the label).
-- A cash-out (Cinematic 'CashOut'): "+10 Cash" pops big in the middle of the screen in the lobby, with confetti over you.
-- Map contract (TheBlockV2 stageGate): a Model tagged HoodStageGate (attributes Stage, Required, LineZ, HalfWidth,
-- Color, Light) with a Barrier part carrying the haze SurfaceGui (Frames named Pane with attributes BaseColor and
-- BaseTransparency); Lock* parts (bars and padlock: BaseTransparency); a BillboardGui named GateSign (attributes
-- BaseW, BaseH, GrowFrom, GrowPow, GrowMax) with TextLabels Title, Sub, Power and Status (the state line); Field*
-- parts (the emitter track: BaseColor, BaseTransparency). Pads (d_kit stagePad): the slab <Name> and its <Name>Base,
-- Rim, Top, Chevron parts (BaseColor, BaseMaterial), PadSparkles, and the label <Name>Label > WorldLabel > Title, Sub,
-- Price.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)
local StageRules = require(RS.Shared.StageRules)
local PadRules = (function()
	local m = RS.Shared:FindFirstChild('PadRules')
	local ok, r = pcall(function() return m and require(m) end)
	return ok and type(r) == 'table' and r or nil
end)()

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local frame = active.Frame

local C = Color3.fromRGB
local GO, DENIED = C(76, 214, 130), C(236, 76, 100) -- (a notch softer than pure neon green and red)
-- The sign's state line: its words and its badge's colour per state (white letters, near-black outline).
local STATUS = {
	Shut = { 'Defeat the crew first', C(214, 34, 58) },
	Open = { 'OPEN!', C(36, 168, 80) },
}
-- (CRITIC3 r1) An open gate's sign is compact and low, so seen from the pads it sits at eye level, under the HUD's goal
-- band: just "STAGE N" over a green "OPEN!" (Recommended / Power only while it is shut), OPEN_H of the sign's height,
-- its foot OPEN_DROP studs lower (no padlock to clear any more). Lines: name -> { x, y, w, h } (0-1 of the sign).
local OPEN_H, OPEN_DROP = 0.52, 4.6
local OPEN_LAYOUT = { Title = { 0, 0, 1, 0.62 }, StatusPlate = { 0.27, 0.68, 0.46, 0.32 }, Status = { 0.3, 0.68, 0.4, 0.32 } }
local gates = {}
local door -- the hall's doorway (gate 1's attributes DoorHalf, DoorTop, DoorZ): a grown sign must fit through it

local function track(model)
	if gates[model] or not model:IsDescendantOf(active.Root) then return end
	gates[model] = {
		Model = model, Stage = model:GetAttribute('Stage'), Required = model:GetAttribute('Required') or 0,
		Z = model:GetAttribute('LineZ'), HalfWidth = model:GetAttribute('HalfWidth') or 20,
		Color = model:GetAttribute('Color') or C(255, 210, 60), Light = model:GetAttribute('Light') or C(255, 236, 160),
		OpenHalf = model:GetAttribute('OpenHalf') or 18, OpenTop = model:GetAttribute('OpenTop') or 18.5,
		FrameHalf = model:GetAttribute('FrameHalf') or 22, FrameTop = model:GetAttribute('FrameTop') or 24,
	}
	if model:GetAttribute('DoorHalf') then
		door = { Half = model:GetAttribute('DoorHalf'), Top = model:GetAttribute('DoorTop') or 30, Z = model:GetAttribute('DoorZ') or 7 }
	end
end
for _, m in CollectionService:GetTagged('HoodStageGate') do track(m) end
CollectionService:GetInstanceAddedSignal('HoodStageGate'):Connect(track)
CollectionService:GetInstanceRemovedSignal('HoodStageGate'):Connect(function(m) gates[m] = nil end)

-- Parts and labels, collected again while the gate is still streaming in.
local function collect(e)
	if e.Barrier and e.Barrier.Parent and e.Collected then return end
	e.Barrier = e.Model:FindFirstChild('Barrier', true)
	e.Sign = e.Model:FindFirstChild('GateSign', true)
	e.Plate = e.Sign and e.Sign:FindFirstChild('StatusPlate')
	e.Lines, e.Guis, e.Fields, e.Status, e.Locks, e.Strokes = {}, {}, {}, {}, {}, {}
	for _, d in e.Model:GetDescendants() do
		if d:IsA('BasePart') and d.Name:sub(1, 5) == 'Field' then table.insert(e.Fields, d)
		elseif d:IsA('BasePart') and d.Name:sub(1, 4) == 'Lock' then table.insert(e.Locks, d)
		elseif d:IsA('TextLabel') and d.Name == 'Status' then table.insert(e.Status, d)
		elseif d:IsA('TextLabel') and (d.Name == 'Power' or d.Name == 'Sub') and e.Sign and d:IsDescendantOf(e.Sign) then
			table.insert(e.Lines, d) -- (the sign's own: the pads' labels in the same model have a Sub too)
		end
		if d:IsA('SurfaceGui') and d.Parent == e.Barrier then table.insert(e.Guis, d) end
		-- (the sign's letter outlines: the share of the sign's height their line takes, times its Ink share, gives the
		-- thickness from the sign's height on screen)
		if d:IsA('UIStroke') and e.Sign and d:IsDescendantOf(e.Sign) and d.Parent:IsA('TextLabel') then
			table.insert(e.Strokes, { d, d.Parent })
		end
	end
	-- the sign's lines as built (the shut layout), to go back to (kept from the first look: never a compact one)
	e.Built = e.Built or {}
	for name in OPEN_LAYOUT do
		local x = e.Sign and e.Sign:FindFirstChild(name)
		if x and x:IsA('GuiObject') and not (e.Built[name] and e.Built[name][1] == x) then e.Built[name] = { x, x.Position, x.Size } end
	end
	e.Collected = e.Barrier ~= nil
end

-- The sign's layout: full while shut (as built), compact while open.
local function layout(e, open)
	for name, b in e.Built or {} do
		local x = b[1]
		local o = OPEN_LAYOUT[name]
		if open then
			x.Position, x.Size = UDim2.fromScale(o[1], o[2]), UDim2.fromScale(o[3], o[4])
		else
			x.Position, x.Size = b[2], b[3]
		end
	end
	for _, t in e.Lines do t.Visible = not open end
	e.Grown = nil -- (grow sizes it again)
end

-- The run as the server tells it: the furthest gate open (RunStage) and the highest stage beaten (RunCleared).
local function runStage() return tonumber(player:GetAttribute('RunStage')) or 1 end
local function runCleared() return tonumber(player:GetAttribute('RunCleared')) or 0 end

-- The haze in a state: its own red bands, or a red flash when it stops you.
local function tint(e, toward, amount)
	for _, f in e.Guis do
		for _, pane in f:GetChildren() do
			if pane:IsA('Frame') then
				local base = pane:GetAttribute('BaseColor') or pane.BackgroundColor3
				pane.BackgroundColor3 = toward and base:Lerp(toward, amount) or base
			end
		end
	end
	for _, p in e.Fields do
		local base = p:GetAttribute('BaseColor') or p.Color
		p.Color = toward and base:Lerp(toward, amount) or base
	end
end

-- The open moment's pieces (defined with the feedback below).
local opened -- (e): shatter, confetti, kick, the Power line's pop

-- Paint a gate: open or shut for you this run, and whether it carries the sign (your next gate). `moment`: it just
-- opened in front of you (the crew fell), so it opens with the fanfare.
local function paint(e, open, signed, moment)
	collect(e)
	local state = open and 'Open' or 'Shut'
	if e.State == state and e.Painted == e.Barrier and e.Signed == signed then return end
	local was = e.State
	e.State, e.Painted, e.Signed = state, e.Barrier, signed
	local b = e.Barrier
	if b then
		b.CanCollide = not open -- only for you: your own character's collisions run on your machine
		b.Transparency = b:GetAttribute('BaseTransparency') or 1
	end
	if moment and was == 'Shut' and open then opened(e) end
	for _, g in e.Guis do g.Enabled = not open end
	if e.Sign then e.Sign.Enabled = signed end
	for _, p in e.Fields do p.Transparency = open and 1 or (p:GetAttribute('BaseTransparency') or 0) end
	-- The lock (bars and padlock) stays while the gate is shut and drops away the moment it opens.
	for _, tween in e.Fades or {} do tween:Cancel() end
	e.Fades = {}
	for _, p in e.Locks do
		local base = p:GetAttribute('BaseTransparency') or 0
		if not open then
			p.Transparency = base
		elseif moment and was == 'Shut' then
			local tween = TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			table.insert(e.Fades, tween)
			tween:Play()
		else
			p.Transparency = 1
		end
	end
	local look = STATUS[state]
	for _, t in e.Status do t.Text = look[1] end
	if e.Plate then e.Plate.BackgroundColor3 = look[2] end
	if state ~= was then layout(e, open) end
	tint(e, nil)
end

-- Your next gate: the first one ahead of you down the street (gate 1 from the lobby; none past the last one).
local function nextGate()
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local z = root and frame:PointToObjectSpace(root.Position).Z or math.huge
	local best
	for _, e in gates do
		if e.Z and e.Z < z and (not best or e.Z > best.Z) then best = e end
	end
	return best
end
local shownRun = nil -- the RunStage the gates were last painted for (a rise is a gate opening in front of you)
local function repaint()
	local open = runStage()
	local nxt = nextGate()
	local rose = shownRun ~= nil and open > shownRun
	for _, e in gates do
		local isOpen = (e.Stage or 1) <= open
		paint(e, isOpen, e == nxt, rose and isOpen and e.Stage > shownRun)
	end
	shownRun = open
end
player:GetAttributeChangedSignal('RunStage'):Connect(repaint)
task.spawn(function()
	while true do
		repaint()
		task.wait(0.25)
	end
end)

-- The sign grows with the distance so it reads from the lobby: base size x clamp((d / GrowFrom)^GrowPow, 1, GrowMax),
-- upward from its foot (it stays clear of the padlock under it), but never past what the openings in front of it leave
-- in view from the camera: the hall's doorway (when you're in the hall), the openings of the gates between you and it,
-- and its own gate's frame outline. Its outlines keep their share of each line's height on your screen (UI2's ~7-11%),
-- so the letters keep a thick dark edge near and far.
local MARGIN = 0.6
-- Does the sign at scale f stay inside every opening in front of it, as the camera sees it? The sign is a card facing
-- the camera, standing on its foot (map frame); an opening is a rectangle x -half..half, y 0..top in the plane z (map
-- frame) between the camera and the sign: the card's corners, in camera space over depth, must fall inside the
-- opening's corners (its bottom is the ground, which hides the card's foot anyway).
local function fits(cam, f, w, h, foot, windows)
	local center = cam:PointToObjectSpace(frame:PointToWorldSpace(foot + Vector3.new(0, h * f / 2, 0)))
	local depth = -center.Z
	if depth < 1 then return true end
	local x0, x1 = (center.X - w * f / 2) / depth, (center.X + w * f / 2) / depth
	local y1 = (center.Y + h * f / 2) / depth
	for _, o in windows do
		local half, top = o[1] - MARGIN, o[2] - MARGIN
		local lo, hi, roof = -math.huge, math.huge, math.huge
		for _, k in { { -half, 0 }, { -half, top }, { half, 0 }, { half, top } } do
			local p = cam:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(k[1], k[2], o[3])))
			if -p.Z < 0.5 then return true end -- (an opening beside or behind the camera hides nothing we can judge)
			local x, y = p.X / -p.Z, p.Y / -p.Z
			if k[1] < 0 then lo = math.max(lo, x) else hi = math.min(hi, x) end
			if k[2] > 0 then roof = math.min(roof, y) end
		end
		if x0 < lo or x1 > hi or y1 > roof then return false end
	end
	return true
end
-- The largest scale up to f that fits: the hall's doorway (when you're in the hall), the openings of the gates
-- between you and the sign, and its own gate's frame outline (never wider or taller than the frame it stands in).
local function fit(e, cam, f, w, h, foot)
	local c = frame:PointToObjectSpace(cam.Position)
	f = math.min(f, 2 * e.FrameHalf / w, (e.FrameTop - foot.Y) / h)
	local windows = {}
	if door and c.Z > door.Z and door.Z > foot.Z then table.insert(windows, { door.Half, door.Top, door.Z }) end
	for _, o in gates do
		local z = o.Z and o.Z + 1.5
		if o ~= e and z and c.Z > z and z > foot.Z then table.insert(windows, { o.OpenHalf, o.OpenTop, z }) end
	end
	if f <= 1 or fits(cam, f, w, h, foot, windows) then return math.max(1, f) end
	local lo, hi = 1, f -- (bisect: the card only gets bigger with f)
	for _ = 1, 8 do
		local mid = (lo + hi) / 2
		if fits(cam, mid, w, h, foot, windows) then lo = mid else hi = mid end
	end
	return lo
end
local NEAR, NEAR_MIN, NEAR_GONE = 36, 0.45, 9 -- (studs from the camera to the sign)
local function grow(e, cam)
	local sign = e.Sign
	local anchor = sign.Parent
	if not (anchor and anchor:IsA('BasePart')) then return end
	local open = e.State == 'Open'
	local drop = open and OPEN_DROP or 0
	local at = anchor.CFrame.Position - Vector3.new(0, drop, 0)
	local d = math.max(1, (cam.CFrame.Position - at).Magnitude)
	local w, h = sign:GetAttribute('BaseW') or sign.Size.X.Scale, (sign:GetAttribute('BaseH') or sign.Size.Y.Scale) * (open and OPEN_H or 1)
	local f = math.clamp((d / (sign:GetAttribute('GrowFrom') or 80)) ^ (sign:GetAttribute('GrowPow') or 1), 1, sign:GetAttribute('GrowMax') or 1)
	if f > 1 then f = fit(e, cam.CFrame, f, w, h, frame:PointToObjectSpace(at)) end
	-- (LOOP) Up close the base sign was wider than the screen (cut off under the HUD from the doorway): it shrinks
	-- inside NEAR studs and is gone as you walk through, like the video's sign fading as you pass.
	if d < NEAR then f = d <= NEAR_GONE and 0 or math.max(NEAR_MIN, d / NEAR) end
	if math.abs(f - (e.Grown or 0)) > 0.01 then
		e.Grown = f
		sign.Size = UDim2.fromScale(w * f, h * f)
		sign.StudsOffsetWorldSpace = Vector3.new(0, h * f / 2 - drop, 0)
	end
	local vh = cam.ViewportSize.Y
	if vh < 100 then vh = 720 end -- (ViewportSize can read 1 x 1 for a frame at startup)
	local px = h * f / d * vh / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	for _, s in e.Strokes do s[1].Thickness = math.clamp(px * s[2].Size.Y.Scale * (s[2]:GetAttribute('Ink') or 0.1), 1.5, 8) end
end

-- The next gate's sign grows with the distance (every frame while it shows).
RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	for _, e in gates do
		if e.Sign and e.Sign.Enabled then grow(e, cam) end
	end
end)

---------------------------------------------------------------------------------------------- pads
-- Each pad: until its stage's crew is down this run, its own bright colour a notch darker (CRITIC3 r2: the reference's
-- pads stay pink and yellow while the crew stands; a grey lerp read as dirty), no sparkles, and its reward over
-- "🔒 Clear the crew!"; then lit, "Return" / "10x Cash" under the reward, and a burst. LabelFade owns the label's transparency and size; this writes its
-- words and colours only.
local LOCKED_BRIGHTNESS = 0.85
local pads = {} -- [slab] = { Part, Stage, Kind, Parts, Sparkles, Label = { Title, Sub, Price } }
local function padWords(pad)
	local tenX = pad.Kind == 'TenX'
	local owned = player:GetAttribute('Pass_' .. (PadRules and PadRules.Pass or 'TenXCash')) == true
	if PadRules and type(PadRules.labels) == 'function' then
		local ok, big, small, price = pcall(PadRules.labels, pad.Stage, pad.Kind, owned)
		if ok and type(big) == 'string' then return big, small or '', price end
	end
	local cash = 10 * 2 ^ (math.max(1, pad.Stage) - 1) * (tenX and 10 or 1)
	return '+' .. Format.compact(cash) .. ' Cash', tenX and '10x Cash' or 'Return', nil
end
local function trackPad(part)
	if pads[part] or not part:IsA('BasePart') or not part:IsDescendantOf(active.Root) then return end
	local stage, kind = part:GetAttribute('Stage'), part:GetAttribute('Kind')
	if type(stage) ~= 'number' or (kind ~= 'Return' and kind ~= 'TenX') then return end
	pads[part] = { Part = part, Stage = stage, Kind = kind }
end
for _, part in CollectionService:GetTagged('HoodStagePad') do trackPad(part) end
CollectionService:GetInstanceAddedSignal('HoodStagePad'):Connect(trackPad)
CollectionService:GetInstanceRemovedSignal('HoodStagePad'):Connect(function(part) pads[part] = nil end)
-- Its pieces: the slab and its <Name>* parts, the sparkles and the label, found next to it (again while streaming in).
local function padParts(pad)
	if pad.Parts and pad.Label and pad.Label.Title and pad.Label.Title.Parent then return end
	local name, home = pad.Part.Name, pad.Part.Parent
	pad.Parts, pad.Sparkles, pad.Label = {}, {}, {}
	if not home then return end
	for _, d in home:GetChildren() do
		if d:IsA('BasePart') and d.Name:sub(1, #name) == name and d:GetAttribute('BaseColor') ~= nil then table.insert(pad.Parts, d) end
		if d:IsA('BasePart') and d.Name:sub(1, #name) == name then
			for _, x in d:GetChildren() do if x:IsA('ParticleEmitter') then table.insert(pad.Sparkles, x) end end
		end
	end
	local anchor = home:FindFirstChild(name .. 'Label')
	local gui = anchor and anchor:FindFirstChildOfClass('BillboardGui')
	if gui then
		pad.Label = { Title = gui:FindFirstChild('Title'), Sub = gui:FindFirstChild('Sub'), Price = gui:FindFirstChild('Price') }
	end
end
local function paintPad(pad, moment)
	padParts(pad)
	local ready = StageRules.padReady(pad.Stage, runCleared())
	local big, small, price = padWords(pad)
	local key = table.concat({ tostring(ready), big, small, price or '', #pad.Parts }, '|')
	if pad.Key == key then return end
	pad.Key = key
	for _, p in pad.Parts do
		local base = p:GetAttribute('BaseColor')
		local k = ready and 1 or LOCKED_BRIGHTNESS
		p.Color = Color3.new(base.R * k, base.G * k, base.B * k)
	end
	for _, sp in pad.Sparkles do sp.Enabled = ready end
	local L = pad.Label
	-- (the reward stays the big line in the pad's colour, so it reads from the stage's entry; the small line says what
	-- opens it)
	if L.Title then L.Title.Text = big end
	if L.Sub then L.Sub.Text = ready and small or '🔒 Clear the crew!' end
	if L.Price then
		L.Price.Text = price or ''
		L.Price.Visible = ready and price ~= nil and price ~= ''
	end
	-- Lit the moment the crew falls: a burst of its own colour over it.
	if moment and ready then
		local top = pad.Part.CFrame.Position + Vector3.new(0, pad.Part.Size.Y / 2 + 1, 0)
		Juice.burst(top, pad.Part:GetAttribute('BaseColor') or GO, 1.6)
		for _, sp in pad.Sparkles do pcall(function() sp:Emit(12) end) end
	end
end
local function repaintPads(moment)
	for _, pad in pads do paintPad(pad, moment) end
end
player:GetAttributeChangedSignal('RunCleared'):Connect(function() repaintPads(true) end)
player:GetAttributeChangedSignal('Pass_' .. (PadRules and PadRules.Pass or 'TenXCash')):Connect(function() repaintPads(false) end)
task.spawn(function()
	while true do
		repaintPads(false)
		task.wait(1)
	end
end)

---------------------------------------------------------------------------------------------- feedback
local gui = Instance.new('ScreenGui')
gui.Name = 'StageFeedback'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild('PlayerGui')

-- (COMBAT: every game sound is behind Config/Sound, off for now: these are nil while it is.)
local Sound = require(RS.Shared.Config.Sound)
local function sound(id, volume)
	return Sound.new(id, volume, gui)
end
local chime = sound('rbxasset://sounds/electronicpingshort.wav', 0.6)
local buzz = sound('rbxasset://sounds/button.wav', 0.5)

local function stroke(parent, color, thickness)
	local s = Instance.new('UIStroke')
	s.Color = color
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- The banner: pops in with an overshoot, holds, then floats up and fades. (LOOP: it sits just under the fight's
-- "N LEFT" counter, sized to the screen like the HUD (UIKit's scale), in the HUD's Gotham Black: in the middle of the
-- screen it covered the next gate's sign and the goons running at you.)
local DISPLAY = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy)
local okKit, Kit = pcall(require, RS.Shared.UIKit)
local banner
local function showBanner(title, detail, color, detailColor)
	if banner then banner:Destroy() end
	local okAbs, abs = pcall(function() return gui.AbsoluteSize end) -- (offline checks may not have it)
	if not okAbs or typeof(abs) ~= 'Vector2' or abs.X <= 1 then abs = Vector2.new(1280, 720) end
	local k = (okKit and Kit.scaleFor) and Kit.scaleFor(abs) or 1
	local holder = Instance.new('Frame')
	holder.Name = 'Banner'
	holder.AnchorPoint = Vector2.new(0.5, 0)
	-- (under Roblox's top bar, the fight's counter and Waves.client's "Hold click to shoot!" line under it)
	holder.Position = UDim2.new(0.5, 0, 0, 58 + 94 * k)
	holder.Size = UDim2.fromOffset(480 * k, 86 * k)
	holder.BackgroundTransparency = 1
	holder:SetAttribute('Title', title)
	holder.Parent = gui
	banner = holder
	local scale = Instance.new('UIScale')
	scale.Scale = 0.3
	scale.Parent = holder
	-- (LOOP) a dark see-through backing, like the GOAL DONE moment's, so it reads over the street and the next sign
	local back = Instance.new('Frame')
	back.Name = 'Back'
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.5)
	back.Size = UDim2.new(1, 16 * k, 1, 12 * k)
	back.BackgroundColor3 = C(16, 19, 30)
	back.BackgroundTransparency = 0.4
	back.BorderSizePixel = 0
	back.ZIndex = 0
	local backCorner = Instance.new('UICorner')
	backCorner.CornerRadius = UDim.new(0, 12 * k)
	backCorner.Parent = back
	back.Parent = holder
	local t = Instance.new('TextLabel')
	t.Name = 'Title'
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.6)
	t.FontFace = DISPLAY
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = holder
	local tStroke = stroke(t, C(0, 0, 0), 4.5 * k)
	local g = Instance.new('UIGradient')
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	g.Rotation = 90
	g.Parent = t
	local d = Instance.new('TextLabel')
	d.Name = 'Detail'
	d.BackgroundTransparency = 1
	d.Position = UDim2.fromScale(0, 0.62)
	d.Size = UDim2.fromScale(1, 0.38)
	d.FontFace = DISPLAY
	d.TextScaled = true
	d.Text = detail
	d.TextColor3 = detailColor or C(90, 255, 120)
	d.Parent = holder
	local dStroke = stroke(d, C(0, 0, 0), 3.5 * k)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if banner ~= holder then return end
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = holder.Position - UDim2.fromOffset(0, 24 * k) }):Play()
		for _, x in { t, d } do TweenService:Create(x, fade, { TextTransparency = 1 }):Play() end
		for _, x in { tStroke, dStroke } do TweenService:Create(x, fade, { Transparency = 1 }):Play() end
		TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function() if banner == holder then holder:Destroy(); banner = nil end end)
	end)
end

-- Short field-of-view punch for the break-through.
local function fovKick()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local base = cam.FieldOfView
	local out = TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + 8 })
	out.Completed:Once(function()
		TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FieldOfView = base }):Play()
	end)
	out:Play()
end

-- The haze shatters into shards that fly forward and fade (only on your screen).
local function shatter(e)
	local b = e.Barrier
	if not b then return end
	local cf, size = b.CFrame, b.Size
	for k = 1, 14 do
		local shard = Instance.new('Part')
		shard.Name = 'Shard'
		shard.Size = Vector3.new(2, 2, 0.3)
		shard.Material = Enum.Material.Neon
		shard.Color = k % 3 == 0 and Color3.new(1, 1, 1) or e.Light
		shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow = false, false, false, false
		shard.CFrame = cf * CFrame.new((math.random() - 0.5) * size.X * 0.9, (math.random() - 0.5) * size.Y * 0.8, 0) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		shard.Parent = workspace
		shard.AssemblyLinearVelocity = cf:VectorToWorldSpace(Vector3.new((math.random() - 0.5) * 16, 10 + math.random() * 15, -(20 + math.random() * 20)))
		shard.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		task.delay(0.8, function()
			if shard.Parent then TweenService:Create(shard, TweenInfo.new(0.8), { Transparency = 1, Size = Vector3.new(0.6, 0.6, 0.1) }):Play() end
		end)
		Debris:AddItem(shard, 2)
	end
end

-- The open moment (the crew before this gate just fell): the haze shatters toward you, confetti, a camera kick, a
-- rising chime and the sign's title pops; the banner says so.
opened = function(e)
	shatter(e)
	local fx = e.Model:FindFirstChild('PassFX', true)
	if fx and fx:IsA('ParticleEmitter') then fx:Emit(60) end
	Juice.kick(0.45)
	fovKick()
	Sound.play(chime, 1 + math.min(e.Stage or 1, 10) * 0.03)
	local title = e.Sign and e.Sign:FindFirstChild('Title')
	if title then
		local s = title:FindFirstChildOfClass('UIScale') or Instance.new('UIScale')
		s.Parent = title
		s.Scale = 1.4
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local name = title and title:IsA('TextLabel') and title.Text ~= '' and title.Text or ('STAGE ' .. tostring(e.Stage))
	showBanner(name .. ' OPEN!', 'Cash out on a pad, or walk on!', e.Light, Color3.new(1, 1, 1))
end
-- The boss's crew down (no gate after it): its pads light up.
player:GetAttributeChangedSignal('RunCleared'):Connect(function()
	local c = runCleared()
	local last = 0
	for _, e in gates do last = math.max(last, e.Stage or 0) end
	if c > 0 and c >= last then showBanner('BOSS BEATEN!', 'Cash out on a pad!', C(255, 210, 60), Color3.new(1, 1, 1)) end
end)

-- Walking through an open gate: a small burst and a chime.
local function passed(rootPos)
	Juice.burst(rootPos + Vector3.new(0, 2, 0), GO, 1.4)
	Sound.play(chime, 1.15)
end

-- Walking into a shut gate: red flash, a bump back toward the lobby, and what to do about it.
local lastBump = 0
local function bump(e, root)
	if os.clock() - lastBump < 0.8 then return end
	lastBump = os.clock()
	tint(e, DENIED, 0.55)
	task.delay(0.2, function() if e.State == 'Shut' then tint(e, nil) end end)
	root.AssemblyLinearVelocity = frame:VectorToWorldSpace(Vector3.new(0, 15, 40))
	Sound.play(buzz)
	local why = 'DEFEAT THE CREW FIRST!'
	if not banner or banner:GetAttribute('Title') ~= why then showBanner(why, "Beat this street's crew to open it", DENIED, Color3.new(1, 1, 1)) end
end

-- A pad paid out (you are back in the lobby): the Cash, big in the middle of the screen in the pads' face (the reference's
-- "+1" trophies rising from you), clear of the goal line at the top: pops in with an overshoot, holds, rises and fades.
local pop
local function cashPop(reward, tenX)
	if pop then pop:Destroy() end
	local okAbs, abs = pcall(function() return gui.AbsoluteSize end)
	if not okAbs or typeof(abs) ~= 'Vector2' or abs.X <= 1 then abs = Vector2.new(1280, 720) end
	local k = (okKit and Kit.scaleFor) and Kit.scaleFor(abs) or 1
	local holder = Instance.new('Frame')
	holder.Name = 'CashPop'
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5) -- (the middle: under the goal line and its GOAL DONE moments)
	holder.Size = UDim2.fromOffset(560 * k, 150 * k)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	pop = holder
	local scale = Instance.new('UIScale')
	scale.Scale = 0.2
	scale.Parent = holder
	local function text(name, value, y, h, color, ink)
		local t = Instance.new('TextLabel')
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = value
		t.TextColor3 = color
		t.Parent = holder
		return t, stroke(t, C(26, 14, 38), ink * k)
	end
	local big, bigInk = text('Amount', '+' .. Format.compact(reward) .. ' Cash', 0, 0.66, Color3.new(1, 1, 1), 6)
	local g = Instance.new('UIGradient')
	g.Color = ColorSequence.new(C(255, 246, 150), C(255, 196, 24))
	g.Rotation = 90
	g.Parent = big
	local small, smallInk = text('Detail', tenX and '10x Cash! Run banked' or 'Run banked! Spend it, then go again', 0.68, 0.3, Color3.new(1, 1, 1), 3.5)
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.9, function()
		if pop ~= holder then return end
		local fade = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.4) }):Play()
		for _, x in { big, small } do TweenService:Create(x, fade, { TextTransparency = 1 }):Play() end
		for _, x in { bigInk, smallInk } do TweenService:Create(x, fade, { Transparency = 1 }):Play() end
		task.delay(0.6, function() if pop == holder then holder:Destroy(); pop = nil end end)
	end)
end
Net.get('Cinematic').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or info.Kind ~= 'CashOut' then return end
	local reward = type(info.Reward) == 'number' and info.Reward or 0
	local gold = C(255, 214, 40)
	cashPop(reward, info.TenX == true)
	task.delay(0.15, function()
		local character = player.Character
		local root = character and character:FindFirstChild('HumanoidRootPart')
		if not root then return end
		Juice.burst(root.Position + Vector3.new(0, 2, 0), gold, 2)
		if Juice.shards then pcall(Juice.shards, root.Position + Vector3.new(0, 3, 0), gold, 'confetti') end
	end)
end)

-- Watch your own character cross gate lines (stages run toward -Z in the map frame).
local lastZ
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	if not root then lastZ = nil; return end
	local p = frame:PointToObjectSpace(root.Position)
	for _, e in gates do
		if e.Z and math.abs(p.X) <= e.HalfWidth then
			if lastZ and lastZ >= e.Z and p.Z < e.Z and e.State == 'Open' then passed(root.Position) end
			if e.State == 'Shut' and p.Z > e.Z and p.Z < e.Z + 3 then bump(e, root) end
		end
	end
	lastZ = p.Z
end)
