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
		if slot.PriceIcon then slot.PriceIcon.Visible = pay end
		local price = slot.Gun.Cost == 0 and 'FREE' or Format.compact(slot.Gun.Cost)
		local text = pay and ((glyph ~= '' and glyph .. ' ' or '') .. price) or string.upper(state)
		if state == 'Buy' then text = 'BUY ' .. text end
		slot.Price.Text = text
		slot.Price.TextColor3 = look.Word or look.Text
	end
	local prompt = slot.Prompt
	local real = state == 'Buy' and 'Locked' or state
	prompt.ActionText = GunRules.actionText(real, slot.Gun.Cost)
	-- Buying holds a moment so a passing tap doesn't spend Cash; equipping is instant.
	prompt.HoldDuration = (real == 'Locked' and slot.Gun.Cost > 0) and 0.35 or 0
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
		end
	end
	local old = point:FindFirstChild('GunPrompt')
	if old then old:Destroy() end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'GunPrompt'
	prompt.ObjectText = gun.Name .. '  (x' .. gun.Multiplier .. ' Power)'
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

-- Celebrations only start once the server has told us what we own: loading your profile is not a purchase.
local primed = player:GetAttribute('OwnedGuns') ~= nil
local function refresh(next)
	guns = GunRules.sanitize(next)
	for id, slot in slots do
		local state = shownState(id, slot.Gun)
		if shown[id] ~= state then
			local before = shown[id]
			paint(slot, state)
			if primed and (before == 'Locked' or before == 'Buy') and state ~= 'Locked' and state ~= 'Buy' then celebrate(slot, 'NEW GUN!')
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
