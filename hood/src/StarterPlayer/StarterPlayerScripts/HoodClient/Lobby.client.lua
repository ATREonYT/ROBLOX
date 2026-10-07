-- World-side guidance and feedback on the active map (the original Block's SimulatorLobby, or The Block V2):
-- look stand / EVOLVE booth prompts, Locked/Unlocked on the training stations (the original Block's gym still
-- shows locked gear as black silhouettes), the floating arrow over where to go next ("TRAIN x4 HERE", "EVOLVE
-- HERE"), the "+N POWER" pop over your head and the sway of the bag you train on. The screen HUD (Power, LEVEL bar, hint line, notices) is HUD.client.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local Skins = require(RS.Shared.Config.Skins)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local lobby = active.Lobby
-- A map can go without a morph stand (The Block V2 evolves you at the EVOLVE booth): then the stand prompts
-- and labels are skipped and training runs as usual.
local hasStand = active.Root:GetAttribute('MorphStand') ~= false
local morphs = hasStand and ActiveMap.find(lobby, 'Morphs', 20) or nil
if hasStand and not morphs then return end
local training = lobby:FindFirstChild('Training') or lobby

local C = Color3.fromRGB
local DISPLAY = Font.new('rbxasset://fonts/families/LuckiestGuy.json')
local INK = C(28, 24, 48)
local function label(parent, name, textSize, color)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = DISPLAY
	t.TextSize = textSize
	t.TextColor3 = color
	t.TextWrapped = true
	local stroke = Instance.new('UIStroke')
	stroke.Color = INK
	stroke.Thickness = 2.5
	stroke.Parent = t
	t.Parent = parent
	return t, stroke
end
local function compact(v)
	if v >= 1e6 then return string.format('%.1fM', v / 1e6) elseif v >= 1000 then return string.format('%.1fK', v / 1000) end
	return tostring(math.floor(v))
end

---------------------------------------------------------------------------------------------- prompts
-- Each look's own prompt reaches only its standing spot (figures stand 9 studs apart, so neighbours' prompts
-- never show together); the stand's WARDROBE badge has the one big prompt, on its own key, which opens the
-- HUD's EVOLVE panel (every look, equip from there) through the local OpenEvolve attribute.
local FIGURE_REACH = 5
local prompts = {}
for _, s in (morphs and Skins.List or {}) do
	local stand = morphs:WaitForChild('Skin_' .. s.Id)
	local target = stand:WaitForChild('Interact')
	local p = Instance.new('ProximityPrompt')
	p.Name = 'Equip_' .. s.Id
	p.MaxActivationDistance = FIGURE_REACH
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.ObjectText = s.Name
	p.ActionText = 'Equip'
	p.Parent = target
	p.Triggered:Connect(function() Net.get('EquipSkin'):FireServer(s.Id) end)
	prompts[s.Id] = p
end
local wardrobePoint = morphs and ActiveMap.find(lobby, 'WardrobePoint', 10) or nil
if wardrobePoint then
	local p = Instance.new('ProximityPrompt')
	p.Name = 'Wardrobe'
	p.MaxActivationDistance = 6 -- (you stand on its ring; every look's standing spot is 8+ studs away)
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.GamepadKeyCode = Enum.KeyCode.ButtonY
	p.ObjectText = 'WARDROBE'
	p.ActionText = 'Evolve & change look'
	p.UIOffset = Vector2.new(0, -24)
	p.Parent = wardrobePoint
	p.Triggered:Connect(function() player:SetAttribute('OpenEvolve', os.clock()) end)
end
-- No stand: one prompt at the EVOLVE booth puts on your best unlocked look.
local evolvePoint = not morphs and ActiveMap.find(lobby, 'EvolvePoint', 10) or nil
local evolvePrompt
if evolvePoint then
	evolvePrompt = Instance.new('ProximityPrompt')
	evolvePrompt.Name = 'Evolve'
	evolvePrompt.MaxActivationDistance = 12
	evolvePrompt.RequiresLineOfSight = false
	evolvePrompt.HoldDuration = 0
	evolvePrompt.ObjectText = 'EVOLVE'
	evolvePrompt.ActionText = 'Evolve'
	evolvePrompt.Parent = evolvePoint
	evolvePrompt.Triggered:Connect(function()
		local n = player:GetAttribute('Power') or 0
		local best = Skins.List[1]
		for _, s in Skins.List do
			if n >= s.Required then best = s end
		end
		if best.Id ~= (player:GetAttribute('EquippedSkin') or 'CornerKid') then Net.get('EquipSkin'):FireServer(best.Id) end
	end)
end
-- Looks on the stand (Skin_<Id> > Display = the figure, Lock = the padlock, Turntable = the disc, LabelAnchor =
-- the label (WorldLabel) and the NextMarker; effects marked UnlockedOnly or held by a part marked so; all
-- optional):
--   locked     its own colours pulled halfway to a dark shade of the pad colour (still recognisable, plainly
--              not yours), padlock shown, unlock-only effects off, frozen
--   next look  (the first one you can't wear yet) in full colour with its padlock, its pad pulsing and its
--              NEXT tag hanging off the pad: the goal
--   unlocked   full colour, effects on, breathing (a small HoodMotion bob, phased by column)
--   worn       the same, turning slowly on its disc
-- A stand with the Showcase attribute (the featured Kingpin) keeps its own colours and motion.
-- Labels on the podium's stands (Look attribute): the full label only on stands within 7 studs of you whose
-- equip point is above your feet but within one level (the row you face, never the row behind/below you);
-- while none is up, your next look shows a bobbing ▼ marker instead.
local LOOK_SHADOW = C(26, 27, 36)
local LOCK_TINT = 0.4 -- how far a locked figure's colours move toward the shade
local LABEL_RANGE, LABEL_RISE = 7, 4.5
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
-- Stands with LockStyle 'Gold' (the top tier) lock as gold statues: each part's brightness mapped onto a
-- dark -> mid -> light gold ramp, small bits (eyes, buttons) dark gold so faces still read; SmoothPlastic with
-- a little reflectance for the sheen (Metal reads as dull bronze away from a bright sky).
local GOLD_DARK, GOLD_MID, GOLD_LIGHT = C(110, 70, 12), C(214, 158, 36), C(255, 226, 130)
local function gold(color, size)
	if size.X < 0.3 and size.Y < 0.3 and size.Z < 0.3 then return GOLD_DARK end
	local l = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return l < 0.5 and GOLD_DARK:Lerp(GOLD_MID, l / 0.5) or GOLD_MID:Lerp(GOLD_LIGHT, (l - 0.5) / 0.5)
end
local looks = {}
for _, s in (morphs and Skins.List or {}) do
	local stand = morphs:FindFirstChild('Skin_' .. s.Id)
	local band = stand and stand:GetAttribute('BandColor')
	local entry = { Parts = {}, Lock = {}, Fx = {}, Disc = {}, Glow = {}, Tag = {}, Column = stand and stand:GetAttribute('Column') or 1 }
	-- The shade: the pad colour darkened by the stand's LockShade.
	entry.Shadow = typeof(band) == 'Color3' and band:Lerp(Color3.new(0, 0, 0), stand:GetAttribute('LockShade') or 0.6) or LOOK_SHADOW
	entry.Gold = stand and stand:GetAttribute('LockStyle') == 'Gold'
	entry.Showcase = stand and stand:GetAttribute('Showcase')
	entry.Display = stand and not entry.Showcase and stand:FindFirstChild('Display')
	if entry.Display then entry.Pivot = entry.Display:GetPivot() end
	for _, p in (entry.Display and entry.Display:GetDescendants() or {}) do
		if p:IsA('BasePart') and p.Transparency < 1 then
			table.insert(entry.Parts, { Part = p, Color = p.Color, Material = p.Material, Reflectance = p.Reflectance, Gold = entry.Gold and gold(p.Color, p.Size) or nil })
		end
	end
	for _, name in { 'Lock', 'Turntable', 'NextTag' } do
		local m = stand and stand:FindFirstChild(name)
		for _, p in (m and m:GetDescendants() or {}) do
			if p:IsA('BasePart') or (name == 'NextTag' and p:IsA('SurfaceGui')) then table.insert(name == 'Lock' and entry.Lock or name == 'Turntable' and entry.Disc or entry.Tag, p) end
		end
	end
	for _, d in (stand and stand:GetDescendants() or {}) do
		if (d:IsA('ParticleEmitter') or d:IsA('Beam')) and (d:GetAttribute('UnlockedOnly') or d.Parent:GetAttribute('UnlockedOnly')) then table.insert(entry.Fx, d) end
		-- The pad's inset and rim strips: they pulse while this is your next look.
		if d:IsA('BasePart') and (d.Name == 'PadGlow' or d.Name == 'PadRimStrip') then table.insert(entry.Glow, d) end
	end
	local anchor = stand and stand:GetAttribute('Look') and stand:FindFirstChild('LabelAnchor')
	entry.Label = anchor and anchor:FindFirstChild('WorldLabel')
	entry.Marker = anchor and anchor:FindFirstChild('NextMarker')
	if entry.Marker then
		-- The marker bobs (it only shows on your next look).
		TweenService:Create(entry.Marker, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffset = entry.Marker.StudsOffset + Vector3.new(0, 0.3, 0) }):Play()
	end
	entry.Point = stand and stand:FindFirstChild('Interact')
	looks[s.Id] = entry
end
local pulsing = {}
local function paintLooks(n, worn)
	local goal = Skins.nextSkin(n)
	for _, s in Skins.List do
		local e = looks[s.Id]
		local locked = n < s.Required
		local shaded = locked and goal ~= s
		local state = (locked and 'L' or 'U') .. (shaded and 'S' or '') .. (worn == s.Id and 'W' or '') .. (goal == s and 'G' or '')
		if e and e.State ~= state then
			e.State = state
			for _, r in e.Parts do
				if shaded and r.Gold then
					r.Part.Color, r.Part.Material, r.Part.Reflectance = r.Gold, Enum.Material.SmoothPlastic, 0.2
				else
					r.Part.Color = shaded and r.Color:Lerp(e.Shadow, LOCK_TINT) or r.Color
					r.Part.Material = shaded and Enum.Material.SmoothPlastic or r.Material
					r.Part.Reflectance = r.Reflectance
				end
			end
			for _, p in e.Lock do p.Transparency = locked and 0 or 1 end
			for _, p in e.Disc do p.Transparency = worn == s.Id and 0 or 1 end
			for _, p in e.Tag do
				if p:IsA('SurfaceGui') then p.Enabled = goal == s else p.Transparency = goal == s and 0 or 1 end
			end
			for _, fx in e.Fx do fx.Enabled = not locked end
			local d = e.Display
			if d and locked then
				-- Frozen, back on its spot.
				d:RemoveTag('HoodMotion')
				d:PivotTo(e.Pivot)
			elseif d then
				d:SetAttribute('Bob', 0.1)
				d:SetAttribute('BobPeriod', 2.4 + 0.3 * e.Column)
				d:SetAttribute('Spin', worn == s.Id and 12 or nil)
				d:AddTag('HoodMotion')
			end
			-- The goal's pad breathes; any other pad sits still at full glow.
			for _, t in (pulsing[s.Id] or {}) do t:Cancel() end
			pulsing[s.Id] = nil
			for _, p in e.Glow do p.Transparency = 0 end
			if goal == s then
				pulsing[s.Id] = {}
				for _, p in e.Glow do
					local t = TweenService:Create(p, PULSE, { Transparency = 0.35 })
					t:Play()
					table.insert(pulsing[s.Id], t)
				end
			end
		end
	end
end
-- Where your feet are, from your rig (R15: the root's bottom less HipHeight; R6: 2-stud legs), so short,
-- scaled and Rthro avatars are judged by the level they stand on. Each stand's level is its equip point less 1.2.
local function feetOf(c, root)
	local hum = c and c:FindFirstChildOfClass('Humanoid')
	local legs = hum and (hum.RigType == Enum.HumanoidRigType.R15 and hum.HipHeight or 2) or 2
	return root.Position.Y - root.Size.Y / 2 - legs
end
local function showLabels(n)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local feet = root and feetOf(c, root)
	local goal = n and Skins.nextSkin(n)
	local any = false
	for _, s in Skins.List do
		local e = looks[s.Id]
		if e and e.Label and e.Point then
			local near = false
			if root then
				local d = e.Point.Position - root.Position
				local up = e.Point.Position.Y - 1.2 - feet -- (the stand's level above yours: one tier up is 2.7-4.5)
				near = Vector3.new(d.X, 0, d.Z).Magnitude <= LABEL_RANGE and up > 0.1 and up <= LABEL_RISE + 0.2
			end
			e.Label.Enabled = near
			any = any or near
		end
	end
	for _, s in Skins.List do
		local e = looks[s.Id]
		if e and e.Marker then e.Marker.Enabled = goal == s and not any end
	end
end
-- While you walk a tier the row below you stands between the camera and you (the figures don't collide, so
-- the camera doesn't pull in): fade, on your screen only, any figure standing on your level or lower (its pad
-- base at or under your feet) within 3.5 studs of the line from the camera to you, between the two.
local FADE, FADE_WIDTH = 0.6, 3.5
local function fadeRows()
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local cam = workspace.CurrentCamera
	local feet = root and feetOf(c, root)
	for _, s in Skins.List do
		local e = looks[s.Id]
		if e and e.Pivot and e.Point then
			local fade = false
			if root then
				local fp, rp = e.Pivot.Position, root.Position
				if e.Point.Position.Y - 1.2 <= feet + 0.5 then -- (its level at or under yours)
					if cam then
						local a = Vector3.new(cam.CFrame.Position.X, 0, cam.CFrame.Position.Z)
						local b = Vector3.new(rp.X, 0, rp.Z)
						local f = Vector3.new(fp.X, 0, fp.Z)
						local ab = b - a
						local t = ab.Magnitude > 0.01 and (f - a):Dot(ab) / ab:Dot(ab) or 2
						fade = t > 0 and t < 1 and (a + ab * t - f).Magnitude < FADE_WIDTH
					else
						fade = math.abs(fp.X - rp.X) < FADE_WIDTH and fp.Z < rp.Z
					end
				end
			end
			if e.Faded ~= fade then
				e.Faded = fade
				for _, r in e.Parts do r.Part.LocalTransparencyModifier = fade and FADE or 0 end
			end
		end
	end
end
if morphs then
	-- Labels follow you round the stand and the row in front fades (a few checks a second).
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + 0.25
		showLabels(player:GetAttribute('Power'))
		fadeRows()
	end)
end

---------------------------------------------------------------------------------------------- arrow
local indicator = Instance.new('BillboardGui')
indicator.Name = 'NextDestination'
indicator.Size = UDim2.fromOffset(190, 50)
indicator.StudsOffset = Vector3.new(0, 7, 0)
indicator.AlwaysOnTop = true
indicator.MaxDistance = 150
indicator.ResetOnSpawn = false
indicator.Parent = player.PlayerGui
local pointer = label(indicator, 'Destination', 22, C(255, 224, 80))

---------------------------------------------------------------------------------------------- stations
-- Training stations in the built lobby: shooter's box, sign, targets. The range lanes (a label with a Power row) stay in
-- full colour while locked, like the reference: the label says Locked in red and the station's effects run at
-- half rate. Older stations without that label (the original Block's gym) still show locked gear as a black
-- silhouette.
local okVfx, HoodVFX = pcall(require, RS.Shared.HoodVFX)
if not okVfx then HoodVFX = nil end
local stations = {}
for _, s in Skins.Stations do
	local model = training:FindFirstChild('Training_' .. s.Id, true)
	if model then
		local sign = model:FindFirstChild('Sign', true) or model:FindFirstChild('Nameplate', true)
		local entry = { Zone = model:FindFirstChild('TrainingZone', true), Sign = sign, Parts = {}, Swing = {}, Fx = model:FindFirstChild('Theme') }
		entry.Bag = sign ~= nil and sign:FindFirstChild('Power', true) ~= nil
		local gear = model:FindFirstChild('Equipment')
		if gear then
			if not entry.Bag then
				for _, p in gear:GetDescendants() do
					if p:IsA('BasePart') and p.Transparency < 1 then table.insert(entry.Parts, { Part = p, Color = p.Color, Material = p.Material }) end
				end
			end
			local hinge = gear:FindFirstChild('Hinge')
			local swing = gear:FindFirstChild('Swing')
			if hinge and swing then
				entry.Hinge = hinge.CFrame
				for _, p in swing:GetDescendants() do
					if p:IsA('BasePart') then table.insert(entry.Swing, { Part = p, Offset = hinge.CFrame:ToObjectSpace(p.CFrame) }) end
				end
			end
		end
		stations[s.Id] = entry
	end
end
-- Range-lane labels like the reference's spawn view: the stations at the two ends of each row show their
-- stack from anywhere, the ones in the middle of a row only up close (22 studs), so a row reads as two clean
-- stacks instead of a pile of text. A station is in the middle when two others sit within a row pitch of it.
local LABEL_FAR, LABEL_NEAR, NEXT_LIFT = 250, 22, Vector3.new(0, 6.5, 0)
for _, e in stations do
	if e.Bag and e.Zone then
		e.Label = e.Sign:FindFirstChildWhichIsA('BillboardGui')
		local near = 0
		for _, o in stations do
			if o ~= e and o.Bag and o.Zone then
				local d = o.Zone.CFrame.Position - e.Zone.CFrame.Position
				if Vector3.new(d.X, 0, d.Z).Magnitude < 16 then near += 1 end -- (row pitch 10.5-14.5; rows sit 35+ apart)
			end
		end
		e.Middle = near >= 2
	end
end
-- The lanes whose box is within 25 studs of each lane's box (any direction, any height): their stacks hide while
-- you stand in that box, so the shooter's view isn't a pile of labels under the HUD hint.
local NEIGHBOUR = 25
for _, e in stations do
	e.Near = {}
	for id, o in stations do
		if o ~= e and e.Zone and o.Zone and (o.Zone.CFrame.Position - e.Zone.CFrame.Position).Magnitude < NEIGHBOUR then e.Near[id] = true end
	end
end
local SILHOUETTE = C(18, 18, 22)
local UNLOCKED, LOCKED = C(20, 235, 70), C(235, 25, 50)
local function paintStations(n)
	local goal = nil -- the next station to unlock shows its stack from afar (lifted clear if it's a middle one)
	for _, s in Skins.Stations do
		if n < s.Required then goal = s break end
	end
	-- While you're still in the free tier the next lane stays a plain lane (no lift, no long range): lifted, its
	-- stack landed on the FREE lane's from the side, and the free lane is the one a new player needs.
	local free = n < (Skins.Stations[2] and Skins.Stations[2].Required or 0)
	-- Your own lane's label hides while you stand in its box (the HUD hint already says its multiplier, or what it
	-- needs), and so do your neighbours' (within 25 studs): from the shooter's spot they pile up under the hint.
	local here = player:GetAttribute('TrainingStation') or ''
	local hereId = here:gsub('^Locked:', '')
	local box = stations[hereId]
	for _, s in Skins.Stations do
		local e = stations[s.Id]
		if e and e.Label then
			local lift = goal == s and not free
			local own = hereId == s.Id
			local beside = box ~= nil and not own and not lift and box.Near[s.Id] == true
			local state = (e.Middle and 'M' or 'E') .. (lift and 'G' or '') .. (own and 'O' or '') .. (beside and 'N' or '')
			if e.LabelState ~= state then
				e.LabelState = state
				e.Label.MaxDistance = (e.Middle and not lift) and LABEL_NEAR or LABEL_FAR
				e.Label.StudsOffset = (e.Middle and lift) and NEXT_LIFT or Vector3.zero
				e.Label.Enabled = not own and not beside
			end
		end
		if e then
			local locked = n < s.Required
			if e.Locked ~= locked then
				e.Locked = locked
				for _, r in e.Parts do
					r.Part.Color = locked and SILHOUETTE or r.Color
					r.Part.Material = locked and Enum.Material.SmoothPlastic or r.Material
				end
				if e.Fx and HoodVFX then HoodVFX.setDensity(e.Fx, locked and 0.5 or 1) end
				local detail = e.Sign and e.Sign:FindFirstChild('Detail', true)
				if detail then
					if e.Bag then
						-- Chip, Locked/Unlocked and "xN Power" all stay up at every distance.
						detail.Text = locked and 'Locked' or 'Unlocked'
						detail.TextColor3 = locked and LOCKED or UNLOCKED
					else
						detail.Text = locked and ('LOCKED • ' .. compact(s.Required) .. ' POWER') or (s.Required == 0 and 'FREE • TRAIN HERE' or 'UNLOCKED • TRAIN HERE')
						detail.TextColor3 = locked and C(255, 128, 128) or C(126, 255, 171)
					end
				end
			end
		end
	end
end
local function zoneOf(id)
	local e = stations[id]
	return e and e.Zone
end

---------------------------------------------------------------------------------------------- new-player guide
-- A brand-new player (under the first look's Power, never reborn) who isn't in a shooter's box gets a scrolling
-- chevron trail from their feet to the box of the lane they can use, and a pulsing frame in that box: it works
-- from any facing, on any layout and after every respawn, and ends on the box the arrow names. It hands over to
-- the arrow whenever the evolve guidance is on, hides while you stand in a box, and is gone for good at the first
-- look's Power (a few seconds of shooting). One beam and four parts, made once per target. While the box is off
-- screen (behind you at the spawn), a small pointer on an inner ellipse of the screen turns toward it, with the
-- lane's name, so the first frame shows the way without turning.
local GUIDE_POWER = Skins.List[2] and Skins.List[2].Required or 25
local GUIDE_COLOR = C(255, 224, 80)
local guide, guideWant = {}, nil
local compass = Instance.new('ScreenGui')
compass.Name = 'GuideCompass'
compass.ResetOnSpawn, compass.IgnoreGuiInset, compass.Enabled, compass.DisplayOrder = false, true, false, 2
compass.Parent = player.PlayerGui
local needle = Instance.new('Frame')
needle.Name = 'Pointer'
needle.AnchorPoint, needle.Size, needle.BackgroundTransparency = Vector2.new(0.5, 0.5), UDim2.fromOffset(150, 96), 1
needle.Parent = compass
-- ">>": two chevrons of two bars each, turned toward the box bar by bar (no rotated container, so every UI
-- renderer draws it the same).
local bars = {}
for _, ox in { -11, 11 } do
	for _, sy in { -1, 1 } do
		local bar = Instance.new('Frame')
		bar.Name = 'Chevron'
		bar.AnchorPoint, bar.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(30, 11)
		bar.BackgroundColor3, bar.BorderSizePixel = GUIDE_COLOR, 0
		local edge = Instance.new('UIStroke')
		edge.Color, edge.Thickness = INK, 2
		edge.Parent = bar
		bar.Parent = needle
		table.insert(bars, { bar = bar, x = ox - 5, y = sy * 10, r = -sy * 45 }) -- (the upper arm falls to the tip, the lower rises to it)
	end
end
local laneName = label(needle, 'Lane', 18, GUIDE_COLOR)
laneName.AnchorPoint, laneName.Position, laneName.Size = Vector2.new(0.5, 0), UDim2.fromOffset(75, 62), UDim2.fromOffset(150, 26)
local compassConn
local function showCompass(on) -- (the pointer itself hides too, for every UI renderer)
	compass.Enabled, needle.Visible = on, on
end
showCompass(false)
local function pointCompass()
	local cam = workspace.CurrentCamera
	local zone = guide.zone
	local ok, vp = pcall(function() return cam.ViewportSize end)
	if not (cam and zone and ok and vp.X > 1) then return showCompass(false) end
	local rel = cam.CFrame:PointToObjectSpace(zone.CFrame.Position + Vector3.new(0, 1, 0))
	local ty = math.tan(math.rad(cam.FieldOfView) / 2)
	local tx = ty * vp.X / vp.Y
	if rel.Z < 0 and math.abs(rel.X / rel.Z) < tx * 0.85 and math.abs(rel.Y / rel.Z) < ty * 0.85 then
		return showCompass(false) -- (on screen: the trail, the frame and the arrow show the way)
	end
	local dx, dy = rel.X, -rel.Y
	if rel.Z > 0 then dy = math.max(dy, math.abs(dx) * 0.4 + 0.5) end -- behind you: point down and to its side
	local a = math.atan2(dy, dx)
	needle.Position = UDim2.fromOffset(vp.X / 2 + math.cos(a) * vp.X * 0.25, vp.Y / 2 + math.sin(a) * vp.Y * 0.25) -- (clear of the HUD's columns)
	local ca, sa = math.cos(a), math.sin(a)
	for _, b in bars do
		b.bar.Position = UDim2.fromOffset(75 + b.x * ca - b.y * sa, 30 + b.x * sa + b.y * ca)
		b.bar.Rotation = math.deg(a) + b.r
	end
	showCompass(true)
end
local function clearGuide()
	for _, t in guide.tweens or {} do t:Cancel() end
	for _, k in { 'beam', 'frame', 'from', 'to' } do
		if guide[k] then guide[k]:Destroy() end
	end
	guide = {}
	if compassConn then compassConn:Disconnect() compassConn = nil end
	showCompass(false)
end
local function showGuide(zone)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not (zone and root) then return clearGuide() end
	if guide.zone == zone and guide.root == root and guide.beam and guide.beam.Parent then return end
	clearGuide()
	guide.zone, guide.root, guide.tweens = zone, root, {}
	-- The trail rides 0.7 over the floor (clear of rims and mats), from the feet to the middle of the box.
	local h = c:FindFirstChildOfClass('Humanoid')
	local feet = (h and h.HipHeight or 2) + root.Size.Y / 2
	guide.from = Instance.new('Attachment')
	guide.from.Name = 'GuideFrom'
	guide.from.CFrame = CFrame.new(0, 0.7 - feet, 0)
	guide.from.Parent = root
	guide.to = Instance.new('Attachment')
	guide.to.Name = 'GuideTo'
	guide.to.CFrame = CFrame.new(0, zone.Size.Y / 2 + 0.7, 0)
	guide.to.Parent = zone
	local beam = Instance.new('Beam')
	beam.Name = 'FloorGuide'
	beam.Attachment0, beam.Attachment1 = guide.from, guide.to
	beam.FaceCamera = true -- (a band along the floor from the follow camera, whatever the attachments' axes)
	beam.Width0, beam.Width1 = 1.2, 1.2
	beam.Segments = 1
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.LightEmission, beam.LightInfluence, beam.Brightness = 0.5, 0, 1
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.15), NumberSequenceKeypoint.new(0.95, 0.15), NumberSequenceKeypoint.new(1, 0.5) })
	if HoodVFX and HoodVFX.applyTexture then HoodVFX.applyTexture(beam, 'chevron') else beam.Texture = 'rbxasset://textures/glow.png' end
	beam.TextureMode, beam.TextureLength, beam.TextureSpeed = Enum.TextureMode.Wrap, 2, 1.5 -- (chevrons point and scroll toward the box)
	beam.Parent = zone
	guide.beam = beam
	-- A pulsing frame just inside the box's edges.
	local frame = Instance.new('Model')
	frame.Name = 'GuideFrame'
	local w, d = zone.Size.X - 0.3, zone.Size.Z - 0.3
	local top = zone.CFrame * CFrame.new(0, zone.Size.Y / 2 + 0.06, 0)
	for _, b in { { 0, d / 2, w, 0.25 }, { 0, -d / 2, w, 0.25 }, { w / 2, 0, 0.25, d }, { -w / 2, 0, 0.25, d } } do
		local p = Instance.new('Part')
		p.Name = 'GuideEdge'
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material, p.Color = Enum.Material.Neon, GUIDE_COLOR
		p.Size = Vector3.new(b[3], 0.1, b[4])
		p.CFrame = top * CFrame.new(b[1], 0, b[2])
		p.Transparency = 0.15
		p.Parent = frame
		local t = TweenService:Create(p, PULSE, { Transparency = 0.75 })
		t:Play()
		table.insert(guide.tweens, t)
	end
	frame.Parent = zone.Parent
	guide.frame = frame
	compassConn = RunService.PreRender:Connect(pointCompass)
end
-- n: Power; station: TrainingStation; evolving: the arrow is on the evolve guidance; zone: the box to go to.
local function updateGuide(n, station, evolving, zone, laneTitle)
	guideWant = { n, station, evolving, zone, laneTitle }
	local new = n < GUIDE_POWER and (player:GetAttribute('Rebirths') or 0) == 0
	if new and station == '' and not evolving then
		laneName.Text = laneTitle or ''
		showGuide(zone)
	else
		clearGuide()
	end
end
player.CharacterAdded:Connect(function(c)
	c:WaitForChild('HumanoidRootPart', 10)
	if guideWant then updateGuide(table.unpack(guideWant)) end
end)

---------------------------------------------------------------------------------------------- refresh
-- The HUD's EVOLVE panel asks for directions by setting the local GuideEvolve attribute: the arrow then points
-- at the EVOLVE booth (or the stand's WARDROBE when a better look is ready, else the next look's stand) until
-- you get there or 45 seconds pass.
local GUIDE_TIME, GUIDE_ARRIVED = 45, 12
local guideUntil = 0
local function evolveTarget(skin, best, nextSkin)
	if morphs then
		if wardrobePoint and best.Gain > skin.Gain then return wardrobePoint end
		local s = (best.Gain > skin.Gain and best) or nextSkin
		local stand = s and morphs:FindFirstChild('Skin_' .. s.Id)
		return stand and stand:FindFirstChild('Interact')
	end
	return evolvePoint
end
local function near(part)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	return root ~= nil and (root.Position - part.Position).Magnitude < GUIDE_ARRIVED
end

local lastPower
local pulse
local function refresh()
	local n = player:GetAttribute('Power')
	if n == nil then return end
	local id = player:GetAttribute('EquippedSkin') or 'CornerKid'
	local skin = Skins.ById[id] or Skins.List[1]
	local station = player:GetAttribute('TrainingStation') or ''
	local best = Skins.List[1]
	for _, s in Skins.List do
		local unlocked = n >= s.Required
		if prompts[s.Id] then prompts[s.Id].ActionText = (id == s.Id and 'Equipped') or (unlocked and 'Equip  +' .. s.Gain .. '/sec') or (compact(s.Required) .. ' Power needed') end
		local anchor = morphs and morphs['Skin_' .. s.Id]:FindFirstChild('LabelAnchor')
		local detail = anchor and anchor:FindFirstChild('WorldLabel') and anchor.WorldLabel:FindFirstChild('Detail')
		if detail then
			-- Labels with their own Gain row (The Block V2's stand) keep the price, the action and the gain apart.
			local split = anchor.WorldLabel:FindFirstChild('Gain')
			detail.Text = split and (id == s.Id and 'EQUIPPED' or unlocked and 'EQUIP' or 'LOCKED') or (id == s.Id and 'EQUIPPED' or unlocked and 'EQUIP' or compact(s.Required) .. ' PWR') .. ' • +' .. s.Gain .. '/sec'
			-- (a chip-only label, its name rows hidden, names the look: your own body can hide the pad's nameplate)
			local title = split and anchor.WorldLabel:FindFirstChild('Title')
			if title and not title.Visible then detail.Text = string.upper(s.Name) .. ' · ' .. detail.Text end
			detail.TextColor3 = id == s.Id and (split and C(120, 220, 255) or C(255, 126, 119)) or unlocked and C(109, 244, 133) or (split and C(255, 90, 90) or C(255, 255, 255))
		end
		if unlocked then best = s end
	end
	paintLooks(n, id)
	showLabels(n)
	fadeRows()
	paintStations(n)
	local nextSkin = Skins.nextSkin(n)
	if evolvePrompt then
		evolvePrompt.ActionText = (best.Id ~= id and ('Evolve → ' .. best.Name .. '  +' .. best.Gain .. '/sec')) or (nextSkin and ('Next: ' .. nextSkin.Name .. ' at ' .. compact(nextSkin.Required) .. ' Power')) or 'Fully evolved'
	end
	local bestGym = Skins.Stations[1]
	for _, g in Skins.Stations do
		if n >= g.Required and stations[g.Id] then bestGym = g end
	end
	local guideTo = os.clock() < guideUntil and evolveTarget(skin, best, Skins.List[skin.Index + 1])
	if guideTo and near(guideTo) then
		guideUntil = 0
		guideTo = nil
	end
	if guideTo then
		indicator.Adornee = guideTo
		pointer.Text = guideTo == wardrobePoint and ('WARDROBE: ' .. best.Name .. ' ↓') or morphs and 'YOUR NEXT LOOK ↓' or 'EVOLVE HERE ↓'
	elseif station:find('Locked:') then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN x' .. bestGym.Multiplier .. ' HERE ↓'
	elseif (morphs or evolvePoint) and best.Gain > skin.Gain then
		-- A better look is unlocked: the stand's WARDROBE equips it (what the HUD hint says too).
		indicator.Adornee = wardrobePoint or (morphs and morphs['Skin_' .. best.Id].Interact) or evolvePoint
		pointer.Text = wardrobePoint and ('WARDROBE: ' .. best.Name .. ' ↓') or morphs and 'EQUIP YOUR LOOK ↓' or 'EVOLVE HERE ↓'
	elseif station == '' then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN x' .. bestGym.Multiplier .. ' HERE ↓'
	else
		indicator.Adornee = nil
	end
	updateGuide(n, station, guideTo and true or false, zoneOf(bestGym.Id), string.upper(bestGym.Name))
	-- "+N POWER" over your head whenever Power goes up; not while you shoot on a range (Shoot.client puts each
	-- shot's "+N" on the target, and a second number over your head would sit right on it).
	if lastPower and n > lastPower and not require(RS.Shared.ShotRules).counts(station) then
		local c = player.Character
		local head = c and c:FindFirstChild('Head')
		if head then
			if pulse then pulse:Destroy() end
			pulse = Instance.new('BillboardGui')
			pulse.Name = 'PowerGain'
			pulse.Size = UDim2.fromOffset(160, 38)
			pulse.Adornee = head
			pulse.StudsOffset = Vector3.new(0, 3.4, 0)
			pulse.AlwaysOnTop = true
			pulse.ResetOnSpawn = false
			pulse.Parent = player.PlayerGui
			local t, stroke = label(pulse, 'Gain', 25, C(126, 255, 171))
			t.Text = '+' .. compact(n - lastPower) .. ' POWER'
			local fade = TweenInfo.new(0.8)
			TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
	end
	lastPower = n
end
for _, key in { 'Power', 'EquippedSkin', 'TrainingStation', 'PowerRate' } do
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
player:GetAttributeChangedSignal('GuideEvolve'):Connect(function()
	guideUntil = os.clock() + GUIDE_TIME
	refresh()
end)
refresh()

-- Only the bag you're training on sways, and only on your screen.
local lastStation = ''
RunService.Heartbeat:Connect(function()
	local station = player:GetAttribute('TrainingStation') or ''
	local last = stations[lastStation]
	if lastStation ~= station and last and last.Hinge then
		for _, r in last.Swing do r.Part.CFrame = last.Hinge * r.Offset end
	end
	lastStation = station
	local e = stations[station]
	if e and e.Hinge then
		local sway = e.Hinge * CFrame.Angles(math.sin(os.clock() * 6) * 0.12, 0, 0)
		for _, r in e.Swing do r.Part.CFrame = sway * r.Offset end
	end
end)
