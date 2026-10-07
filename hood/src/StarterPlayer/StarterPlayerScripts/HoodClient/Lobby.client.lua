-- World-side guidance and feedback on the active map (the original Block's SimulatorLobby, or The Block V2):
-- look stand / EVOLVE booth prompts, locked training gear painted as black silhouettes with LOCKED signs, the
-- floating arrow over where to go next ("TRAIN x4 HERE", "EVOLVE HERE"), the "+N POWER" pop over your head
-- and the sway of the bag you train on. The screen HUD (Power, LEVEL bar, hint line, notices) is HUD.client.
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
local prompts = {}
for _, s in (morphs and Skins.List or {}) do
	local stand = morphs:WaitForChild('Skin_' .. s.Id)
	local target = stand:WaitForChild('Interact')
	local p = Instance.new('ProximityPrompt')
	p.Name = 'Equip_' .. s.Id
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.ObjectText = s.Name
	p.ActionText = 'Equip'
	p.Parent = target
	p.Triggered:Connect(function() Net.get('EquipSkin'):FireServer(s.Id) end)
	prompts[s.Id] = p
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
-- the label; effects marked UnlockedOnly or held by a part marked so; all optional):
--   locked     the figure in a dark shade of its band colour, padlock shown, unlock-only effects off, frozen
--   next look  (the first one you can't wear yet) in full colour with its padlock: your goal on show
--   unlocked   full colour, effects on, breathing (a small HoodMotion bob, phased by column)
--   worn       the same, turning slowly on its disc
-- A stand with the Showcase attribute (the featured Kingpin) keeps its own colours and motion. On the
-- podium's stands (Look attribute) the full label shows only on your next look and on stands within 14 studs
-- of you on your level or the one above (so the rows behind don't pile their labels over the row in front).
local LOOK_SHADOW = C(26, 27, 36)
local LABEL_RANGE, LABEL_RISE = 14, 4.5
local looks = {}
for _, s in (morphs and Skins.List or {}) do
	local stand = morphs:FindFirstChild('Skin_' .. s.Id)
	local band = stand and stand:GetAttribute('BandColor')
	local entry = { Parts = {}, Lock = {}, Fx = {}, Disc = {}, Column = stand and stand:GetAttribute('Column') or 1 }
	entry.Shadow = typeof(band) == 'Color3' and band:Lerp(Color3.new(0, 0, 0), 0.72) or LOOK_SHADOW
	entry.Showcase = stand and stand:GetAttribute('Showcase')
	entry.Display = stand and not entry.Showcase and stand:FindFirstChild('Display')
	if entry.Display then entry.Pivot = entry.Display:GetPivot() end
	for _, p in (entry.Display and entry.Display:GetDescendants() or {}) do
		if p:IsA('BasePart') and p.Transparency < 1 then table.insert(entry.Parts, { Part = p, Color = p.Color, Material = p.Material }) end
	end
	for _, name in { 'Lock', 'Turntable' } do
		local m = stand and stand:FindFirstChild(name)
		for _, p in (m and m:GetDescendants() or {}) do
			if p:IsA('BasePart') then table.insert(name == 'Lock' and entry.Lock or entry.Disc, p) end
		end
	end
	for _, d in (stand and stand:GetDescendants() or {}) do
		if (d:IsA('ParticleEmitter') or d:IsA('Beam')) and (d:GetAttribute('UnlockedOnly') or d.Parent:GetAttribute('UnlockedOnly')) then table.insert(entry.Fx, d) end
	end
	local anchor = stand and stand:GetAttribute('Look') and stand:FindFirstChild('LabelAnchor')
	entry.Label = anchor and anchor:FindFirstChildWhichIsA('BillboardGui')
	entry.Point = stand and stand:FindFirstChild('Interact')
	looks[s.Id] = entry
end
local function paintLooks(n, worn)
	local goal = Skins.nextSkin(n)
	for _, s in Skins.List do
		local e = looks[s.Id]
		local locked = n < s.Required
		local shaded = locked and goal ~= s
		local state = (locked and 'L' or 'U') .. (shaded and 'S' or '') .. (worn == s.Id and 'W' or '')
		if e and e.State ~= state then
			e.State = state
			for _, r in e.Parts do
				r.Part.Color = shaded and e.Shadow or r.Color
				r.Part.Material = shaded and Enum.Material.SmoothPlastic or r.Material
			end
			for _, p in e.Lock do p.Transparency = locked and 0 or 1 end
			for _, p in e.Disc do p.Transparency = worn == s.Id and 0 or 1 end
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
		end
	end
end
local function showLabels(n)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local goal = n and Skins.nextSkin(n)
	for _, s in Skins.List do
		local e = looks[s.Id]
		if e and e.Label and e.Point then
			local near = false
			if root then
				local d = e.Point.Position - root.Position
				near = Vector3.new(d.X, 0, d.Z).Magnitude <= LABEL_RANGE and math.abs(d.Y) <= LABEL_RISE
			end
			e.Label.Enabled = goal == s or near
		end
	end
end
if morphs then
	-- Labels follow you round the stand (a few checks a second).
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + 0.25
		showLabels(player:GetAttribute('Power'))
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
-- Training stations in the built lobby: mat, sign, gear. Locked gear shows as a black silhouette.
local stations = {}
for _, s in Skins.Stations do
	local model = training:FindFirstChild('Training_' .. s.Id, true)
	if model then
		local entry = { Zone = model:FindFirstChild('TrainingZone', true), Sign = model:FindFirstChild('Sign', true) or model:FindFirstChild('Nameplate', true), Parts = {}, Decals = {}, Swing = {} }
		local gear = model:FindFirstChild('Equipment')
		if gear then
			for _, p in gear:GetDescendants() do
				if p:IsA('BasePart') and p.Transparency < 1 then table.insert(entry.Parts, { Part = p, Color = p.Color, Material = p.Material, Transparency = p.Transparency }) end
				-- Stamped textures (the bag stations' X) vanish while locked so the silhouette stays flat black.
				if p:IsA('Decal') then table.insert(entry.Decals, { Decal = p, Transparency = p.Transparency }) end
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
local SILHOUETTE = C(18, 18, 22)
local UNLOCKED, LOCKED = C(20, 235, 70), C(235, 25, 50)
local FAR_TIERS = 2 -- stations more than this many tiers above your best unlocked one show only "xN Power"
local function paintStations(n)
	local best = 0
	for i, s in Skins.Stations do
		if n >= s.Required then best = i end
	end
	for i, s in Skins.Stations do
		local e = stations[s.Id]
		if e then
			local locked = n < s.Required
			-- Far-away goals keep their label short so a row of bags doesn't read as a wall of text.
			local far = i > best + FAR_TIERS
			if e.Far ~= far and e.Sign and e.Sign:FindFirstChild('Power', true) then
				e.Far = far
				for _, name in { 'Chip', 'Cost', 'Detail' } do
					local g = e.Sign:FindFirstChild(name, true)
					if g and g:IsA('GuiObject') then g.Visible = not far end
				end
			end
			if e.Locked ~= locked then
				e.Locked = locked
				-- Locked gear (the bag and, on the bag stations, the whole gallows) turns into a solid black
				-- silhouette; glass parts go opaque so the ice bag reads as one shape too.
				for _, r in e.Parts do
					r.Part.Color = locked and SILHOUETTE or r.Color
					r.Part.Material = locked and Enum.Material.SmoothPlastic or r.Material
					r.Part.Transparency = locked and 0 or (r.Transparency or 0)
				end
				for _, r in e.Decals do r.Decal.Transparency = locked and 1 or r.Transparency end
				local detail = e.Sign and e.Sign:FindFirstChild('Detail', true)
				if detail then
					-- The bag stations' floating label (chip, Unlocked/Locked, "xN Power") has a Power row; older
					-- signs get the long form.
					if e.Sign:FindFirstChild('Power', true) then
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

---------------------------------------------------------------------------------------------- refresh
-- The HUD's EVOLVE panel asks for directions by setting the local GuideEvolve attribute: the arrow then points
-- at the EVOLVE booth (or the next look's stand) until you get there or 45 seconds pass.
local GUIDE_TIME, GUIDE_ARRIVED = 45, 12
local guideUntil = 0
local function evolveTarget(skin, best, nextSkin)
	if morphs then
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
			detail.TextColor3 = id == s.Id and (split and C(120, 220, 255) or C(255, 126, 119)) or unlocked and C(109, 244, 133) or (split and C(255, 90, 90) or C(255, 255, 255))
		end
		if unlocked then best = s end
	end
	paintLooks(n, id)
	showLabels(n)
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
		pointer.Text = morphs and 'YOUR NEXT LOOK ↓' or 'EVOLVE HERE ↓'
	elseif station:find('Locked:') then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN x' .. bestGym.Multiplier .. ' HERE ↓'
	elseif (morphs or evolvePoint) and best.Gain > skin.Gain then
		indicator.Adornee = morphs and morphs['Skin_' .. best.Id].Interact or evolvePoint
		pointer.Text = morphs and 'EQUIP YOUR LOOK ↓' or 'EVOLVE HERE ↓'
	elseif station == '' then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN x' .. bestGym.Multiplier .. ' HERE ↓'
	else
		indicator.Adornee = nil
	end
	-- "+N POWER" over your head whenever Power goes up.
	if lastPower and n > lastPower then
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
