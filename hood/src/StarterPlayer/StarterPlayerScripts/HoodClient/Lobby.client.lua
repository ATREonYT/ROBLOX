-- World-side guidance and feedback on the active map (the original Block's SimulatorLobby, or The Block V2):
-- look stand prompts (where a map has one), Locked/Open on the training stations (the original Block's gym
-- still shows locked gear as black silhouettes), the floating arrow over where to go next ("TRAIN HERE"), the
-- "+N POWER" pop over your head and the sway of the bag you train on. Looks equip from the HUD's EVOLVE menu. The screen HUD (Power, LEVEL bar, hint line, notices) is HUD.client.
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
-- A map may have a morph stand (`Morphs`, which the original Block's SimulatorLobby builds): its looks get
-- prompts, labels and locked/unlocked paint. Without one (The Block V2) all of that is skipped and the rest runs
-- as usual; looks equip from the HUD's EVOLVE menu anywhere. Only the original Block waits for its stand to
-- stream in, so a map without one never stalls here.
local morphs = active.Root:GetAttribute('MorphStand') ~= false
	and (lobby:FindFirstChild('Morphs', true) or (active.Id == 'Block' and ActiveMap.find(lobby, 'Morphs', 20)))
	or nil
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
-- Each look on a stand has its own Equip prompt (the server equips unlocked looks from anywhere, so the prompt
-- is only a shortcut).
local FIGURE_REACH = 11
local prompts = {}
for _, s in (morphs and Skins.List or {}) do
	local stand = morphs:WaitForChild('Skin_' .. s.Id, 10)
	local target = stand and stand:WaitForChild('Interact', 10)
	if not target then continue end
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
-- Training stations in the built lobby: shooter's box, plaque, target. The range lanes (a plaque with a Power
-- row) stay in full colour while locked: the plaque at the bay's entrance says LOCKED in red, a rope hangs across
-- the entrance, and the lane's effect runs at half rate. Older stations without that plaque (the original
-- Block's gym) still show locked gear as a black silhouette.
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
		-- The lane's rope across its entrance (shown while locked) and, on older lanes, a state lamp.
		entry.Ropes, entry.Lamps = {}, {}
		for _, p in model:GetDescendants() do
			if p:IsA('BasePart') and p.Name == 'LockRope' then table.insert(entry.Ropes, p) end
			if p:IsA('BasePart') and p.Name == 'StateLamp' then table.insert(entry.Lamps, p) end
		end
		stations[s.Id] = entry
	end
end
local SILHOUETTE = C(18, 18, 22)
local LAMP_OPEN, LAMP_LOCKED = C(90, 220, 120), C(235, 80, 70)
local UNLOCKED, LOCKED = C(140, 206, 120), C(217, 119, 106) -- (soft sage and terracotta, as the lanes build them)
local function paintStations(n)
	for _, s in Skins.Stations do
		local e = stations[s.Id]
		if e then
			local locked = n < s.Required
			if e.Locked ~= locked then
				e.Locked = locked
				for _, r in e.Parts do
					r.Part.Color = locked and SILHOUETTE or r.Color
					r.Part.Material = locked and Enum.Material.SmoothPlastic or r.Material
				end
				if e.Fx and HoodVFX then HoodVFX.setDensity(e.Fx, locked and 0.5 or 1) end
				for _, rope in e.Ropes do rope.Transparency = locked and 0 or 1 end
				for _, lamp in e.Lamps do lamp.Color = locked and LAMP_LOCKED or LAMP_OPEN end
				local detail = e.Sign and e.Sign:FindFirstChild('Detail', true)
				if detail then
					if e.Bag then
						detail.Text = locked and 'LOCKED' or 'OPEN'
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
-- A new player (never reborn, Stage 1 not cleared yet) is led in two steps, published as the GuidePhase
-- attribute for the HUD's hint:
--   'lane'  under Stage 1's Power (the stage-1 gate's Required, 10): to the free lane's box (BAY 1);
--   'exit'  from then until Stage 1 is cleared: to the stage-1 door ("The street is open!").
-- Each step draws a scrolling chevron trail from the feet along a walkable route (the lobby's GuideNodes, else
-- the engine's pathfinding, else straight), moves the floating arrow over the goal, pulses a frame in a lane's
-- box, and, while the next turn of the trail is off screen, shows a small pointer on an inner ellipse of the
-- screen. The trail re-plans after a respawn or when you wander off it. The lane step hides while you stand in a
-- box; the exit step keeps its trail and arrow there (you are in BAY 1 when Stage 1 opens), without the pointer.
-- Map contract (all read live, so the lobby can move things): Training_<Id>.TrainingZone; the HoodStageGate
-- model with Stage = 1 (Required, LineZ, PadZ and its Barrier part); and, optionally, a GuideNodes folder of small
-- invisible parts, each standing on a walkable floor, whose Links attribute names (comma-separated) the nodes
-- you can walk to from it in a straight line (stair foot to stair top, and so on). A node with Goal = 'Exit'
-- marks where the exit trail ends; without one it ends DOOR_IN studs inside the stage-1 gate line.
local CollectionService = game:GetService('CollectionService')
local okPath, PathfindingService = pcall(function() return game:GetService('PathfindingService') end)
if not okPath then PathfindingService = nil end
local GUIDE_POWER = Skins.List[2] and Skins.List[2].Required or 25 -- (a map without stage gates: the old hand-off)
local GUIDE_COLOR = C(240, 186, 80)
local HOVER, DOOR_IN, LEVEL = 0.7, 8, 0.8 -- trail height over the floor; exit point; "same floor" tolerance
local guide, guideWant = {}, nil
local compass = Instance.new('ScreenGui')
compass.Name = 'GuideCompass'
compass.ResetOnSpawn, compass.IgnoreGuiInset, compass.Enabled, compass.DisplayOrder = false, true, false, 2
compass.Parent = player.PlayerGui
local needle = Instance.new('Frame')
needle.Name = 'Pointer'
needle.AnchorPoint, needle.Size, needle.BackgroundTransparency = Vector2.new(0.5, 0.5), UDim2.fromOffset(150, 96), 1
needle.Parent = compass
-- ">>": two chevrons of two bars each, turned toward the goal bar by bar (no rotated container, so every UI
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

-- The map's pieces.
local function stageOne()
	local ok, tagged = pcall(function() return CollectionService:GetTagged('HoodStageGate') end)
	for _, m in ok and tagged or {} do
		if m:GetAttribute('Stage') == 1 and m:IsDescendantOf(active.Root) then return m end
	end
	return nil
end
local function guideNodes()
	local folder = active.Root:FindFirstChild('GuideNodes', true)
	local nodes = {}
	if not folder then return nodes end
	for _, p in folder:GetChildren() do
		if p:IsA('BasePart') then
			nodes[p.Name] = { pos = p.CFrame.Position - Vector3.new(0, p.Size.Y / 2, 0), links = {}, goal = p:GetAttribute('Goal') }
		end
	end
	for _, p in folder:GetChildren() do
		local node, links = nodes[p.Name], p:GetAttribute('Links')
		if node and type(links) == 'string' then
			for other in links:gmatch('[^,%s]+') do
				local o = nodes[other]
				if o and o ~= node then node.links[o], o.links[node] = true, true end
			end
		end
	end
	return nodes
end
-- Where the exit trail ends: the lobby's Exit node, else on the floor DOOR_IN studs inside the gate line (the
-- lobby side is the PadZ side; stages run toward -Z in the map frame).
local function exitPoint(gate)
	for _, node in guideNodes() do
		if node.goal == 'Exit' then return node.pos end
	end
	local frame = active.Frame
	local line, pad = gate:GetAttribute('LineZ'), gate:GetAttribute('PadZ')
	local side = (line and pad and pad < line) and -1 or 1
	local barrier = gate:FindFirstChild('Barrier', true)
	local at = barrier and frame:PointToObjectSpace(barrier.CFrame.Position) or Vector3.zero
	local floor = barrier and at.Y - barrier.Size.Y / 2 or 0
	return frame * Vector3.new(at.X, floor, (line or at.Z) + side * DOOR_IN)
end
-- Which step you are on: 'lane', 'exit' or ''.
local function guidePhase(n)
	if (player:GetAttribute('Rebirths') or 0) > 0 then return '', nil end
	local gate = stageOne()
	if not gate then return n < GUIDE_POWER and 'lane' or '', nil end
	local cleared = player:GetAttribute('StagesCleared')
	if (cleared or 0) >= 1 then return '', nil end
	if n < (gate:GetAttribute('Required') or 10) then return 'lane', gate end
	return cleared ~= nil and 'exit' or '', gate -- (not before the server has said you haven't cleared it)
end

-- Routes: floor points from your feet to the goal, the goal last.
local function clearLine(a, b) -- nothing solid between two floor points at knee height (true if it can't tell)
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		params.RespectCanCollide = true
		return workspace:Raycast(a + Vector3.new(0, 1, 0), b - a, params)
	end)
	return not ok or hit == nil
end
local function walkable(a, b) return math.abs(a.Y - b.Y) < LEVEL and clearLine(a, b) end
-- The lobby's GuideNodes: the shortest chain of linked nodes, entered and left on your own floor.
local function nodeRoute(from, to)
	local nodes = guideNodes()
	if next(nodes) == nil then return nil end
	if walkable(from, to) then return { to } end
	local dist, prev, open = {}, {}, {}
	for _, node in nodes do
		if walkable(from, node.pos) then dist[node], open[node] = (node.pos - from).Magnitude, true end
	end
	local best, bestCost
	while true do
		local u
		for node in open do
			if not u or dist[node] < dist[u] then u = node end
		end
		if not u or (bestCost and dist[u] >= bestCost) then break end
		open[u] = nil
		if walkable(u.pos, to) and (not bestCost or dist[u] + (to - u.pos).Magnitude < bestCost) then
			best, bestCost = u, dist[u] + (to - u.pos).Magnitude
		end
		for v in u.links do
			local d = dist[u] + (v.pos - u.pos).Magnitude
			if dist[v] == nil or d < dist[v] then dist[v], prev[v], open[v] = d, u, true end
		end
	end
	if not best then return nil end
	local route, node = { to }, best
	while node do
		table.insert(route, 1, node.pos)
		node = prev[node]
	end
	return route
end
-- Fewer, straighter legs: drop the points within 0.75 studs of the line through their neighbours.
local function simplify(points)
	local keep = { [1] = true, [#points] = true }
	local function split(i, j)
		local a, b, far, at = points[i], points[j], 0.75, nil
		local ab = b - a
		for k = i + 1, j - 1 do
			local t = ab:Dot(ab) > 0 and math.clamp((points[k] - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
			local d = (a + ab * t - points[k]).Magnitude
			if d > far then far, at = d, k end
		end
		if at then
			keep[at] = true
			split(i, at)
			split(at, j)
		end
	end
	split(1, #points)
	local out = {}
	for k, p in points do
		if keep[k] then table.insert(out, p) end
	end
	return out
end
-- The engine's pathfinding (no jumps: stairs, not terrace faces). Yields.
local function engineRoute(from, to)
	if not PathfindingService then return nil end
	local ok, route = pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4 })
		path:ComputeAsync(from, to)
		if path.Status ~= Enum.PathStatus.Success then return nil end
		local points = { from }
		for _, w in path:GetWaypoints() do table.insert(points, w.Position) end
		table.insert(points, to)
		points = simplify(points)
		table.remove(points, 1)
		return points
	end)
	return ok and route or nil
end

-- The trail: one beam per leg, the first from your feet (an attachment on your root).
local function beamOf(a0, a1, first, last)
	local beam = Instance.new('Beam')
	beam.Name = 'FloorGuide'
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true -- (a band along the floor from the follow camera, whatever the attachments' axes)
	beam.Width0, beam.Width1 = 1.2, 1.2
	beam.Segments = 1
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.LightEmission, beam.LightInfluence, beam.Brightness = 0.4, 0, 1
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, first and 1 or 0.15), NumberSequenceKeypoint.new(0.08, 0.15),
		NumberSequenceKeypoint.new(0.95, 0.15), NumberSequenceKeypoint.new(1, last and 0.5 or 0.15) })
	if HoodVFX and HoodVFX.applyTexture then HoodVFX.applyTexture(beam, 'chevron') else beam.Texture = 'rbxasset://textures/glow.png' end
	beam.TextureMode, beam.TextureLength, beam.TextureSpeed = Enum.TextureMode.Wrap, 2, 1.5 -- (chevrons point and scroll toward the goal)
	return beam
end
local function drawTrail()
	if guide.trail then guide.trail:ClearAllChildren() end
	local points = guide.points
	if not (points and guide.trail and guide.from) then return end
	local prev = guide.from
	for i, p in points do
		local a = Instance.new('Attachment')
		a.Name = 'GuidePoint'
		a.CFrame = CFrame.new(p + Vector3.new(0, HOVER, 0))
		a.Parent = guide.trail
		beamOf(prev, a, i == 1, i == #points).Parent = guide.trail
		prev = a
	end
end
local function feetOfGuide()
	return guide.root.CFrame.Position - Vector3.new(0, guide.feet, 0)
end
local function plan()
	local token = {}
	guide.token, guide.planned = token, os.clock()
	local from, to = feetOfGuide(), guide.goal.point
	task.spawn(function()
		local route = nodeRoute(from, to) or engineRoute(from, to) or { to }
		if guide.token ~= token then return end -- (a newer goal or plan took over)
		guide.points, guide.near = route, nil
		drawTrail()
	end)
end
-- Every frame: drop the turns you've reached (within 3 studs), and plan again when you wander 12+ studs
-- further from the next turn than you've been (at most every 2 seconds).
local function followTrail()
	local points = guide.points
	if not (points and guide.root and guide.root.Parent) then return end
	local feet = feetOfGuide()
	local reached = false
	while #points > 1 do
		local d = points[1] - feet
		if Vector3.new(d.X, 0, d.Z).Magnitude < 3 and math.abs(d.Y) < 2.5 then
			table.remove(points, 1)
			reached = true
		else
			break
		end
	end
	if reached then
		guide.near = nil
		drawTrail()
	end
	local d = points[1] - feet
	local flat = Vector3.new(d.X, 0, d.Z).Magnitude
	guide.near = math.min(guide.near or flat, flat)
	if flat > guide.near + 12 and os.clock() - (guide.planned or 0) > 2 then plan() end
end
local function pointCompass()
	local cam = workspace.CurrentCamera
	local target = guide.points and guide.points[1]
	local ok, vp = pcall(function() return cam.ViewportSize end)
	if guide.inBox or not (cam and target and ok and vp.X > 1) then return showCompass(false) end
	local rel = cam.CFrame:PointToObjectSpace(target + Vector3.new(0, 1, 0))
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
	for _, k in { 'trail', 'frame', 'from', 'door' } do
		if guide[k] then guide[k]:Destroy() end
	end
	guide = {}
	if compassConn then compassConn:Disconnect() compassConn = nil end
	showCompass(false)
end
-- goal: { key = the zone or 'exit', point = the floor point, zone = the lane's box or nil, title = the pointer's name }
local function showGuide(goal, inBox)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not (goal and root) then return clearGuide() end
	if guide.key == goal.key and guide.root == root and guide.trail and guide.trail.Parent then
		guide.inBox = inBox
		return
	end
	clearGuide()
	guide.key, guide.goal, guide.root, guide.inBox, guide.tweens = goal.key, goal, root, inBox, {}
	laneName.Text = goal.title or ''
	local h = c:FindFirstChildOfClass('Humanoid')
	guide.feet = (h and h.HipHeight or 2) + root.Size.Y / 2
	guide.from = Instance.new('Attachment')
	guide.from.Name = 'GuideFrom'
	guide.from.CFrame = CFrame.new(0, HOVER - guide.feet, 0)
	guide.from.Parent = root
	-- The trail's turns hang on an invisible part at the origin (so each attachment's CFrame is its world spot).
	local trail = Instance.new('Part')
	trail.Name = 'GuideTrail'
	trail.Anchored, trail.CanCollide, trail.CanQuery, trail.CanTouch, trail.CastShadow = true, false, false, false, false
	trail.Transparency, trail.Size, trail.CFrame = 1, Vector3.new(0.2, 0.2, 0.2), CFrame.new()
	trail.Parent = workspace
	guide.trail = trail
	if goal.zone then
		-- A pulsing frame just inside the box's edges.
		local zone = goal.zone
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
	else
		-- Something for the floating arrow to stand on at the door.
		local door = Instance.new('Part')
		door.Name = 'GuideDoor'
		door.Anchored, door.CanCollide, door.CanQuery, door.CanTouch, door.CastShadow = true, false, false, false, false
		door.Transparency, door.Size, door.CFrame = 1, Vector3.new(0.2, 0.2, 0.2), CFrame.new(goal.point + Vector3.new(0, 1, 0))
		door.Parent = workspace
		guide.door = door
	end
	plan()
	compassConn = RunService.PreRender:Connect(function()
		followTrail()
		pointCompass()
	end)
end
-- n: Power; station: TrainingStation; evolving: the arrow is on the evolve guidance; zone: the free lane's box.
local function updateGuide(n, station, evolving, zone, laneTitle)
	guideWant = { n, station, evolving, zone, laneTitle }
	local phase, gate = guidePhase(n)
	if player:GetAttribute('GuidePhase') ~= phase then player:SetAttribute('GuidePhase', phase) end
	local inBox = station ~= '' and not station:find('Locked:')
	local goal
	if phase == 'exit' then
		goal = { key = 'exit', point = exitPoint(gate), title = 'STAGE 1' }
	elseif phase == 'lane' and zone and not inBox then
		goal = { key = zone, point = (zone.CFrame * CFrame.new(0, zone.Size.Y / 2, 0)).Position, zone = zone, title = laneTitle }
	end
	if goal and not evolving then
		showGuide(goal, inBox)
	else
		clearGuide()
	end
	if guide.door then
		-- The floating arrow leaves the lanes for the door.
		indicator.Adornee = guide.door
		pointer.Text = 'STAGE 1 OPEN ↓'
	end
end
player.CharacterAdded:Connect(function(c)
	c:WaitForChild('HumanoidRootPart', 10)
	if guideWant then updateGuide(table.unpack(guideWant)) end
end)

---------------------------------------------------------------------------------------------- refresh
local lastPower
local pulse
local function refresh()
	local n = player:GetAttribute('Power')
	if n == nil then return end
	local id = player:GetAttribute('EquippedSkin') or 'CornerKid'
	local station = player:GetAttribute('TrainingStation') or ''
	for _, s in Skins.List do
		local unlocked = n >= s.Required
		if prompts[s.Id] then prompts[s.Id].ActionText = (id == s.Id and 'Equipped') or (unlocked and 'Equip  +' .. s.Gain .. '/sec') or (compact(s.Required) .. ' Power needed') end
		local stand = morphs and morphs:FindFirstChild('Skin_' .. s.Id)
		local anchor = stand and stand:FindFirstChild('LabelAnchor')
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
	end
	paintLooks(n, id)
	showLabels(n)
	fadeRows()
	paintStations(n)
	local bestGym = Skins.Stations[1]
	for _, g in Skins.Stations do
		if n >= g.Required and stations[g.Id] then bestGym = g end
	end
	-- (A new look unlocked is the HUD's job: its EVOLVE button wears a NEW! badge and the hint says to tap it.)
	if station == '' or station:find('Locked:') then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN HERE ↓' -- (the multiplier is on the bay's plaque and in the HUD hint, not floating)
	else
		indicator.Adornee = nil
	end
	updateGuide(n, station, false, zoneOf(bestGym.Id), string.upper(bestGym.Name))
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
for _, key in { 'Power', 'EquippedSkin', 'TrainingStation', 'PowerRate', 'StagesCleared', 'Rebirths' } do -- (the last two: the guide's steps)
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
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
