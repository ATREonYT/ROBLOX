-- The ARMORY on your screen: a prompt on every gun pedestal (Buy / Equip / Equipped) that comes up when you step
-- onto the pad, pedestals painted in your state colours (pink locked, blue owned, green equipped) with the plate
-- and the nameplate's last line to match (the price in red, BUY + price in yellow when you can afford it, OWNED,
-- EQUIPPED), a small burst when a gun becomes yours, and everyone's equipped gun worn on the right hip while it
-- isn't in their hand (the held gun tool, Shoot.client, takes its place).
-- The server decides everything (GunService); this only asks and shows.
--
-- Reads the player attributes GunService keeps (OwnedGuns, EquippedGun) and Net 'ProfileUpdated' (Guns).
-- Slot contract: see the map builder (GunSlot_<Id> models in the active map).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local Guns = require(RS.Shared.Config.Guns)
local GunRules = require(RS.Shared.GunRules)
local Format = require(RS.Shared.Format)
local Juice = require(RS.Shared.Juice)
local okKit, Kit = pcall(require, RS.Shared.UIKit)
if not okKit or type(Kit) ~= 'table' then Kit = nil end

local player = Players.LocalPlayer

-- GunModels is made by another builder; until it exists the hip gun is skipped.
local function gunModels()
	local shared = RS:FindFirstChild('Shared')
	local folder = shared and shared:FindFirstChild('Models')
	local module = folder and folder:FindFirstChild('GunModels')
	if not module then return nil end
	local ok, m = pcall(require, module)
	return ok and type(m) == 'table' and m.build and m or nil
end

---------------------------------------------------------------------------------------------- hip gun
-- A scaled-down copy of the equipped gun hangs muzzle-down on the right hip of every character, welded and
-- massless, so the street can see who carries what. While the character holds a Tool (the gun, on a range)
-- the holster is taken off, and it comes back when the tool is put away.
local HIP_LENGTH = 1.7
-- Size of a model's visible parts in its own pivot frame.
local function extents(model)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local pp = model.PrimaryPart
	local frame = pp and pp.CFrame * pp.PivotOffset or model:GetPivot()
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local c = frame:ToObjectSpace(p.CFrame)
			local half = p.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1) } do
				local v = c * (half * s)
				lo, hi = lo:Min(v), hi:Max(v)
			end
		end
	end
	return hi - lo
end

local function holster(plr)
	local character = plr.Character
	if not character then return end
	local id = plr:GetAttribute('EquippedGun')
	local old = character:FindFirstChild('HoodHolster')
	if character:FindFirstChildOfClass('Tool') then
		-- The gun is in the hand: no second copy on the hip.
		if old then old:Destroy() end
		return
	end
	if old and old:GetAttribute('GunId') == id then return end
	if old then old:Destroy() end
	local models = gunModels()
	local hip = character:FindFirstChild('LowerTorso') or character:FindFirstChild('Torso')
	if not models or not hip or type(id) ~= 'string' or not Guns.ById[id] then return end
	local ok, model = pcall(models.build, id, 1)
	if not ok or not model then return end
	local size = extents(model)
	local length = math.max(size.X, size.Y, size.Z, 0.1)
	if length > HIP_LENGTH then
		model:Destroy()
		ok, model = pcall(models.build, id, HIP_LENGTH / length)
		if not ok or not model then return end
		size = size * (HIP_LENGTH / length)
	end
	-- Grip just outside the hip, muzzle down, the gun's top facing forward (like a thigh holster).
	local r15 = hip.Name == 'LowerTorso'
	local offset = CFrame.new(hip.Size.X / 2 + size.X / 2 + 0.04, r15 and -0.1 or -hip.Size.Y / 2 + 0.1, 0.05) * CFrame.Angles(-math.pi / 2, 0, 0)
	model:PivotTo(hip.CFrame * offset)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			local weld = Instance.new('WeldConstraint')
			weld.Part0, weld.Part1 = hip, p
			weld.Parent = p
		end
	end
	model.Name = 'HoodHolster'
	model:SetAttribute('GunId', id)
	model.Parent = character
end

local function watchPlayer(plr)
	plr:GetAttributeChangedSignal('EquippedGun'):Connect(function() holster(plr) end)
	local function spawned(character)
		-- Equipping or putting away a tool swaps the hip gun out or back.
		character.ChildAdded:Connect(function(child) if child:IsA('Tool') then holster(plr) end end)
		character.ChildRemoved:Connect(function(child) if child:IsA('Tool') then holster(plr) end end)
		-- Wait for the body (and the hip part) before hanging the gun on it.
		local hip = character:WaitForChild('LowerTorso', 5) or character:FindFirstChild('Torso')
		if hip then holster(plr) end
	end
	plr.CharacterAdded:Connect(spawned)
	if plr.Character then task.spawn(spawned, plr.Character) end
end
for _, plr in Players:GetPlayers() do watchPlayer(plr) end
Players.PlayerAdded:Connect(watchPlayer)

---------------------------------------------------------------------------------------------- pedestals
-- The map tags the armory HoodArmory and makes each GunSlot_<Id> stream as one piece (Atomic), so slots are
-- bound as they arrive and dropped if they stream out; the prompt lives on the slot and goes with it.
local CollectionService = game:GetService('CollectionService')
local active = ActiveMap.wait(20)
if not active then return end

local guns = GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
local slots, shown = {}, {}

-- What a pad shows: GunRules.state, except that a Locked gun you can afford shows as Buy (like the soldier game's
-- stand: Equipped, Owned, Buy, Locked). Display only; the server still decides.
local function shownState(id, gun)
	local state = GunRules.state(guns, id)
	if state == 'Locked' then
		local cash = player:GetAttribute('Cash')
		if type(cash) == 'number' and cash >= gun.Cost then return 'Buy' end
	end
	return state
end

local function paint(slot, state)
	local look = GunRules.Colors[state] or GunRules.Colors.Locked
	local shade = look.Shade or look.Strip
	for _, p in slot.Tops do p.Color = look.Top end
	for _, p in slot.Glows do p.Color = look.Glow end
	for _, p in slot.Shades do p.Color = shade end
	for _, p in slot.Mats do p.Color = look.Mat or look.Glow end
	for _, l in slot.Lights do l.Color = look.Top end
	for _, e in slot.Hazes do e.Color = ColorSequence.new(look.Top) end
	if slot.Strip then slot.Strip.Color = look.Strip end
	local label = slot.StateLabel
	if label then
		label.Text = string.upper(state)
		local stroke = label:FindFirstChildOfClass('UIStroke')
		if stroke then stroke.Color = look.Strip:Lerp(Color3.new(0, 0, 0), 0.45) end
	end
	if slot.Price then
		-- The nameplate's third line: the price with the Cash glyph or icon while the gun is to buy (red while you
		-- can't afford it, BUY in yellow when you can), else the state word (OWNED blue, EQUIPPED green).
		local glyph = slot.Price:GetAttribute('Glyph') or ''
		local pay = state == 'Locked' or state == 'Buy'
		if slot.PriceIcon then slot.PriceIcon.Visible = pay and not slot.PriceIconMissing end
		local price = slot.Gun.Cost == 0 and 'FREE' or Format.compact(slot.Gun.Cost)
		-- (lobby round 2, the critic: one short line per gun) the price only while it is to buy; the state word (BUY,
		-- OWNED, EQUIPPED, LOCKED) is the plate's alone
		local text = pay and ((glyph ~= '' and glyph .. ' ' or '') .. price) or ''
		slot.Price.Text = text
		slot.Price.TextColor3 = look.Word or look.Text
	end
	local prompt = slot.Prompt
	local real = state == 'Buy' and 'Locked' or state
	prompt.ActionText = GunRules.actionText(real, slot.Gun.Cost)
	-- Buying holds a moment so a passing tap doesn't spend Cash; equipping is instant.
	prompt.HoldDuration = (real == 'Locked' and slot.Gun.Cost > 0) and 0.35 or 0
end

-- (brief 23, UI5's UIKit.watchImage) An uploaded icon still in Roblox review draws nothing: while the Power or Cash icon
-- on a nameplate doesn't draw, it hides, its line centres and carries the text glyph instead (the Glyph attribute the
-- painter reads); the icon comes back the moment it loads.
local function iconOrGlyph(icon, text, glyph, repaint, onMissing)
	if not (Kit and Kit.watchImage and icon and text) then return end
	local pos, size, align = text.Position, text.Size, text.TextXAlignment
	local function set(missing)
		if onMissing then onMissing(missing) end
		icon.Visible = not missing
		text.Position = missing and UDim2.fromScale(0.04, pos.Y.Scale) or pos
		text.Size = missing and UDim2.fromScale(0.92, size.Y.Scale) or size
		text.TextXAlignment = missing and Enum.TextXAlignment.Center or align
		text:SetAttribute('Glyph', missing and glyph or '')
		repaint()
	end
	Kit.watchImage(icon, function() set(true) end, function() set(false) end)
end
local function watchIcons(slot, id)
	local gun = slot.Gun
	if slot.Power then
		iconOrGlyph(slot.PowerIcon, slot.Power, '💪', function()
			local glyph = slot.Power:GetAttribute('Glyph') or ''
			slot.Power.Text = (glyph ~= '' and glyph .. ' ' or '') .. 'x' .. gun.Multiplier .. ' Power'
		end)
	end
	if slot.Price then
		iconOrGlyph(slot.PriceIcon, slot.Price, '💵', function()
			if slots[id] == slot then paint(slot, shown[id] or shownState(id, gun)) end
		end, function(missing) slot.PriceIconMissing = missing end)
	end
end

local function bind(model)
	local id = model:GetAttribute('GunId')
	local gun = type(id) == 'string' and Guns.ById[id]
	if not gun or (slots[id] and slots[id].Model == model) then return end
	local point = model:FindFirstChild('GunPoint_' .. id, true) or model:WaitForChild('GunPoint_' .. id, 5)
	if not point or not model.Parent then return end
	local slot = { Gun = gun, Model = model, Tops = {}, Glows = {}, Shades = {}, Mats = {}, Lights = {}, Hazes = {} }
	for _, d in model:GetDescendants() do
		if d.Name == 'StateTop' and d:IsA('BasePart') then table.insert(slot.Tops, d)
		elseif d.Name == 'StateGlow' and d:IsA('BasePart') then table.insert(slot.Glows, d)
		elseif d.Name == 'StateShade' and d:IsA('BasePart') then table.insert(slot.Shades, d)
		elseif d.Name == 'StateMat' and d:IsA('BasePart') then table.insert(slot.Mats, d)
		elseif d.Name == 'StateStrip' and d:IsA('BasePart') then slot.Strip = d
		elseif d:IsA('PointLight') and d.Parent and d.Parent.Name == 'StateGlow' then table.insert(slot.Lights, d)
		elseif d:IsA('ParticleEmitter') and d.Name == 'StateHaze' then table.insert(slot.Hazes, d)
		elseif d:IsA('TextLabel') and d.Name == 'State' then slot.StateLabel = d
		elseif d:IsA('TextLabel') and d.Name == 'Price' and d:FindFirstAncestor('GunLabel') then slot.Price = d
		elseif d:IsA('ImageLabel') and d.Name == 'PriceIcon' then slot.PriceIcon = d
		elseif d:IsA('ImageLabel') and d.Name == 'Icon' and d:FindFirstAncestor('GunLabel') then slot.PowerIcon = d
		elseif d:IsA('TextLabel') and d.Name == 'Multiplier' and d:FindFirstAncestor('GunLabel') then slot.Power = d
		end
	end
	local old = point:FindFirstChild('GunPrompt')
	if old then old:Destroy() end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'GunPrompt'
	prompt.ObjectText = gun.Name -- (brief 29: just the name; the stand's label shows the Power, so the prompt can be small)
	-- (short: the prompt comes up when you step onto the pad, not from the next one)
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function()
		local state = GunRules.state(guns, id)
		if state == 'Locked' then Net.get('BuyGun'):FireServer(id)
		elseif state == 'Owned' then Net.get('EquipGun'):FireServer(id) end
	end)
	slot.Prompt = prompt
	slots[id] = slot
	watchIcons(slot, id)
	-- A slot arriving (or coming back) is painted as it is now, without a celebration.
	local state = shownState(id, gun)
	paint(slot, state)
	shown[id] = state
end

local function watchArmory(armory)
	if not armory:IsDescendantOf(active.Root) then return end
	local function added(child)
		if child:IsA('Model') and child:GetAttribute('GunId') then task.spawn(bind, child) end
	end
	armory.ChildAdded:Connect(added)
	armory.ChildRemoved:Connect(function(child)
		local id = child:GetAttribute('GunId')
		if id and slots[id] and slots[id].Model == child then slots[id], shown[id] = nil, nil end
	end)
	for _, child in armory:GetChildren() do added(child) end
end
CollectionService:GetInstanceAddedSignal('HoodArmory'):Connect(watchArmory)
for _, armory in CollectionService:GetTagged('HoodArmory') do watchArmory(armory) end

-- A gun that just became yours (or just got equipped) gets a burst and a flash.
local function celebrate(slot, text)
	local display = slot.Model:FindFirstChild('Display')
	local position = display and display:GetPivot().Position or slot.Model:GetPivot().Position
	pcall(function()
		Juice.burst(position, slot.Gun.Color, 1.6)
		if display then Juice.flash(display) end
		Juice.popNumber(position + Vector3.new(0, 2, 0), text, slot.Gun.Color)
	end)
end

-- (Oct 27, flow: the audit's "buying the first gun isn't a moment") A gun that just became yours gets its own moment:
-- the gun itself turning slowly in the middle of the screen, "NEW GUN!", its name and what it does ("x2 POWER PER SHOT"),
-- for a couple of seconds, in its turn in the moment queue (Shared/MomentQueue). The server's "Bought ..." notice says
-- the same, so it is muted. It never blocks: no input is taken, the game runs under it. Reduced Motion: it doesn't turn.
-- (Oct 27, round 8) It is one of our windows now: a solid navy panel (Kit.windowBody) with the yellow header bar, in
-- the middle of the screen over a soft dark backdrop, not see-through text on a band.
local RunService = game:GetService('RunService')
local MomentQueue = require(RS.Shared.MomentQueue)
local okStyle, TextStyle = pcall(require, RS.Shared.TextStyle)
local okToasts, HudToasts = pcall(require, RS.Shared.HudToasts)
local REVEAL_FOR = 2.6
local function reveal(gun)
	if not Kit or type(gun) ~= 'table' then return end
	if okToasts and HudToasts.mute then HudToasts.mute('Bought ', 8) end
	local pg = player:FindFirstChildOfClass('PlayerGui')
	if not pg then return end
	local function free()
		local w = pg:GetAttribute('HoodWindow')
		return not (type(w) == 'string' and w ~= '') and pg:GetAttribute('Unboxing') ~= true
	end
	local token = MomentQueue.acquire('NewGun', { Ready = free, Timeout = 10 })
	if not token then return end
	local gui, spin
	local ok, err = pcall(function()
		gui = Kit.screen('HoodGunReveal', pg, 55)
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		local root = gui:FindFirstChild('Root')
		local TS = game:GetService('TweenService')
		-- the soft dark backdrop (it takes no input: the game runs under it)
		local backdrop = Kit.new('Frame', { Name = 'Backdrop', BackgroundColor3 = Kit.hex('070912'), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
		root.ZIndex = 2
		TS:Create(backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.45 }):Play()
		-- the window: a solid navy body under a yellow header bar, centred
		local W, H, HH = 520, 380, 64
		local card = Kit.new('Frame', { Name = 'Card', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), ZIndex = 2, Parent = root })
		local sc = Kit.new('UIScale', { Scale = 0.85, Parent = card })
		local body = Kit.new('Frame', { Name = 'Body', BorderSizePixel = 0, Position = UDim2.fromOffset(0, HH - 14), Size = UDim2.new(1, 0, 1, -(HH - 14)), ZIndex = 2, Parent = card })
		Kit.windowBody(body, W, H - HH + 14, { Outline = 5 })
		local header = Kit.block({ Name = 'Header', Tone = 'headerYellow', Width = W, Height = HH, Outline = 5, OutlineColor = Kit.Skin.outline, Radius = Kit.Skin.headerCorner, Studs = 30, StudShade = 0.22, RimWidth = 4, ZIndex = 4 })
		header.Parent = card
		if Kit.headerBand then Kit.headerBand(header, 'headerYellow') end
		local head = Kit.text({ Name = 'Head', Text = 'NEW GUN!', FontFace = Kit.Font.display, TextSize = 44, Stroke = Kit.Skin.outline, StrokeThickness = 5, ZIndex = 8, Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), Parent = header:FindFirstChild('Body') or header })
		-- the gun turns in a dark well
		local well = Kit.new('Frame', { Name = 'Well', BackgroundColor3 = Kit.Skin.well, BackgroundTransparency = 0.2, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, HH + 10), Size = UDim2.fromOffset(W - 60, 176), ZIndex = 5, Parent = card })
		Kit.new('UICorner', { CornerRadius = UDim.new(0, 12), Parent = well })
		local view
		local models = gunModels()
		if models and models.viewport then
			local ok, vf = pcall(models.viewport, gun.Id, UDim2.fromOffset(300, 170))
			if ok and vf then
				view = vf
				vf.AnchorPoint, vf.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
				vf.BackgroundTransparency = 1
				vf.ZIndex = 6
				vf.Parent = well
			end
		end
		local nameLabel = Kit.text({ Name = 'GunName', Text = string.upper(gun.Name), TextSize = 34, ZIndex = 7, Position = UDim2.fromOffset(0, HH + 194), Size = UDim2.new(1, 0, 0, 42), Parent = card })
		local what = Kit.text({ Name = 'What', Text = 'x' .. tostring(gun.Multiplier) .. ' POWER PER SHOT', TextSize = 30, ZIndex = 7, Position = UDim2.fromOffset(0, HH + 240), Size = UDim2.new(1, 0, 0, 38), Parent = card })
		nameLabel.TextSize = Kit.fitSize and Kit.fitSize(nameLabel.Text, 34, W - 40, 18) or 34
		if okStyle then
			TextStyle.apply(head, 'white', { Thickness = 5 })
			TextStyle.apply(nameLabel, 'white', { Shadow = true })
			TextStyle.apply(what, 'gold', { Shadow = true })
		end
		TS:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- the gun turns, slowly (a third of a turn while it shows)
		local meta = models and models.Meta and models.Meta[gun.Id]
		local cam = view and select(2, pcall(function() return view.CurrentCamera end))
		if typeof(cam) == 'Instance' and meta and player:GetAttribute('ReducedMotion') ~= true then
			local center = meta.Center
			local offset = cam.CFrame.Position - center
			local t = 0
			spin = RunService.Heartbeat:Connect(function(dt)
				t += math.clamp(type(dt) == 'number' and dt or 1 / 60, 0, 0.1)
				pcall(function() cam.CFrame = CFrame.lookAt(center + CFrame.Angles(0, t * 0.8, 0):VectorToWorldSpace(offset), center) end)
			end)
		end
		task.wait(REVEAL_FOR)
		-- out: the window shrinks away (Back In) while the backdrop clears
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		TS:Create(sc, out, { Scale = 0 }):Play()
		TS:Create(backdrop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		task.wait(0.35)
	end)
	if spin then spin:Disconnect() end
	if not ok then warn('[Armory] the new-gun moment: ' .. tostring(err)) end
	if gui then gui:Destroy() end
	MomentQueue.release(token)
end

-- Celebrations only start once the server has told us what we own: loading your profile is not a purchase.
local primed = player:GetAttribute('OwnedGuns') ~= nil
local function refresh(next)
	guns = GunRules.sanitize(next)
	for id, slot in slots do
		local state = shownState(id, slot.Gun)
		if shown[id] ~= state then
			local before = shown[id]
			paint(slot, state)
			if primed and (before == 'Locked' or before == 'Buy') and state ~= 'Locked' and state ~= 'Buy' then
				celebrate(slot, 'NEW GUN!')
				task.spawn(reveal, slot.Gun)
			elseif primed and before == 'Owned' and state == 'Equipped' then celebrate(slot, 'EQUIPPED!') end
			shown[id] = state
		end
	end
	primed = true
end

-- EquippedGun and OwnedGuns change together on a purchase: read them once, at the end of the frame.
local pending = false
local function fromAttributes()
	if pending then return end
	pending = true
	task.defer(function()
		pending = false
		if player:GetAttribute('OwnedGuns') == nil then return end
		refresh(GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun')))
	end)
end
player:GetAttributeChangedSignal('OwnedGuns'):Connect(fromAttributes)
player:GetAttributeChangedSignal('EquippedGun'):Connect(fromAttributes)
-- Cash going up or down turns LOCKED into BUY and back (a repaint, never a celebration).
player:GetAttributeChangedSignal('Cash'):Connect(function()
	for id, slot in slots do
		local state = shownState(id, slot.Gun)
		if shown[id] ~= state then
			paint(slot, state)
			shown[id] = state
		end
	end
end)
Net.get('ProfileUpdated').OnClientEvent:Connect(function(data)
	if type(data) == 'table' and type(data.Guns) == 'table' and type(data.Guns.Owned) == 'table' then
		refresh({ Owned = table.clone(data.Guns.Owned), Equipped = data.Guns.Equipped })
	end
end)
