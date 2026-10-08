-- The ARMORY on your screen: a prompt on every gun plinth (Buy / Equip / Equipped), each plinth's ring, plate,
-- lights and price painted for you (LOCKED, NEXT UP, OWNED, EQUIPPED; colours in GunRules.Colors), a short
-- celebration when a gun becomes yours, and everyone's equipped gun worn on the right hip while it isn't in
-- their hand (the held gun tool, Shoot.client, takes its place).
-- The server decides everything (GunService); this only asks and shows.
--
-- Reads the player attributes GunService keeps (OwnedGuns, EquippedGun), Cash, and Net 'ProfileUpdated'.
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
-- What a slot shows (calm: the state is a thin ring and a plate, never a big glowing face):
--   LOCKED    no ring, a padlock on the plate, a dimmer spot and a slightly dimmer gun; price red or green
--   NEXT UP   the next gun to buy (the cheapest you don't own): amber NEXT UP and a fill bar of your Cash
--             against its price; once you can afford it, an amber ring, a brighter spot and a slow bob
--   OWNED     a steel-blue ring; EQUIPPED a soft sage glowing ring, a glow under the gun and a gentle bob
local CollectionService = game:GetService('CollectionService')
local TweenService = game:GetService('TweenService')
local active = ActiveMap.wait(20)
if not active then return end

local guns = GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
local cash = type(player:GetAttribute('Cash')) == 'number' and player:GetAttribute('Cash') or 0
local slots, shown = {}, {}

local WORD = { Locked = 'LOCKED', Next = 'NEXT UP', Owned = 'OWNED', Equipped = 'EQUIPPED' }
local SPOT = { Locked = 0.6, Next = 1, Ready = 2, Owned = 1, Equipped = 1.2 } -- downlight brightness
local BOB = { Ready = { 0.3, 3.5 }, Equipped = { 0.15, 4.5 } } -- studs, seconds per cycle
local DIM, DIM_BY = Color3.fromRGB(70, 72, 78), 0.22 -- a locked gun is pulled this far toward grey
local CASH_GREEN = Color3.fromRGB(126, 214, 155)

-- The gun to buy next: the cheapest one you don't own (the ladder is in price order).
local function nextGun()
	for _, gun in Guns.List do
		if GunRules.state(guns, gun.Id) == 'Locked' then return gun.Id end
	end
	return nil
end
-- The look of a slot: its rule state, except the next gun to buy shows NEXT UP.
local function lookOf(id, upNext)
	local state = GunRules.state(guns, id)
	if state == 'Locked' and id == upNext then return 'Next' end
	return state
end

local function paint(slot, state)
	local colors = GunRules.Colors
	local look = colors[state] or colors.Locked
	local gun = slot.Gun
	local afford = cash >= gun.Cost
	local ready = state == 'Next' and afford
	local key = ready and 'Ready' or state
	-- the ring: off (the cap's graphite) while locked or not yet affordable, sage neon only when equipped
	local ringOn = state == 'Owned' or state == 'Equipped' or ready
	local wiping = slot.WipeEnd and os.clock() < slot.WipeEnd
	for _, p in slot.Rings do
		if not wiping then p.Color = ringOn and look.Top or colors.Locked.Top end
		p.Material = state == 'Equipped' and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
	-- the plate: the word, the padlock, the Cash-to-price bar
	if slot.Strip then slot.Strip.Color = look.Strip end
	if slot.StateLabel then
		slot.StateLabel.Text = WORD[state]
		slot.StateLabel.TextColor3 = look.Text
	end
	for _, p in slot.Locks do p.Transparency = state == 'Locked' and 0 or 1 end
	if slot.Bar then
		slot.Bar.Visible = state == 'Next'
		if slot.Fill then
			-- (the fill lies over the track: its width is the track's times Cash / price)
			local track = slot.Bar.Size
			slot.Fill.Visible = state == 'Next'
			slot.Fill.Size = UDim2.fromScale(track.X.Scale * (gun.Cost > 0 and math.clamp(cash / gun.Cost, 0, 1) or 1), track.Y.Scale)
			slot.Fill.BackgroundColor3 = colors.Next.Top
		end
	end
	-- lights: the downlight per state, the glow under the equipped gun only
	for _, l in slot.Spots do l.Brightness = SPOT[key] end
	for _, l in slot.Glows do
		l.Color = look.Glow
		l.Enabled = state == 'Equipped'
	end
	-- a locked gun sits a little dimmer (the colours are restored once it's yours or next)
	local dim = state == 'Locked'
	if slot.Dimmed ~= dim then
		slot.Dimmed = dim
		for _, r in slot.GunParts do r.part.Color = dim and r.color:Lerp(DIM, DIM_BY) or r.color end
	end
	-- motion only marks the next affordable gun and the equipped one
	if slot.Display then
		local bob = BOB[key]
		if not bob and slot.Display:GetAttribute('Bob') and slot.Home then
			slot.Display:PivotTo(slot.Home) -- (a gun that stops bobbing settles back where it rests)
		end
		slot.Display:SetAttribute('Bob', bob and bob[1] or nil)
		slot.Display:SetAttribute('BobPeriod', bob and bob[2] or nil)
	end
	-- the nameplate's price row: the price (red until you can afford it, then green), or OWNED / EQUIPPED
	if slot.Price then
		local owned = state == 'Owned' or state == 'Equipped'
		local glyph = slot.Price:GetAttribute('Glyph') or ''
		local word = owned and WORD[state] or (gun.Cost == 0 and 'FREE' or Format.compact(gun.Cost))
		slot.Price.Text = (not owned and glyph ~= '' and glyph .. ' ' or '') .. word
		slot.Price.TextColor3 = owned and look.Text or (afford and colors.Price.Afford or colors.Price.Short)
		if slot.PriceIcon then
			-- (the cash icon only goes with a price; the word then takes the whole row, centred)
			slot.PriceIcon.Visible = not owned
			local l = slot.PriceLayout
			slot.Price.Position = owned and UDim2.fromScale(0, l.Position.Y.Scale) or l.Position
			slot.Price.Size = owned and UDim2.fromScale(1, l.Size.Y.Scale) or l.Size
			slot.Price.TextXAlignment = owned and Enum.TextXAlignment.Center or l.Align
		end
	end
	local rule = state == 'Next' and 'Locked' or state
	local prompt = slot.Prompt
	prompt.ActionText = GunRules.actionText(rule, gun.Cost)
	-- Buying holds a moment so a passing tap doesn't spend Cash; equipping is instant.
	prompt.HoldDuration = (rule == 'Locked' and gun.Cost > 0) and 0.35 or 0
end

local function bind(model)
	local id = model:GetAttribute('GunId')
	local gun = type(id) == 'string' and Guns.ById[id]
	if not gun or (slots[id] and slots[id].Model == model) then return end
	local point = model:FindFirstChild('GunPoint_' .. id, true) or model:WaitForChild('GunPoint_' .. id, 5)
	if not point or not model.Parent then return end
	local slot = { Gun = gun, Model = model, Rings = {}, Locks = {}, Spots = {}, Glows = {}, GunParts = {} }
	slot.Display = model:FindFirstChild('Display')
	slot.Home = slot.Display and slot.Display:GetPivot()
	local gunModel = slot.Display and slot.Display:FindFirstChild('Gun')
	for _, d in model:GetDescendants() do
		if d.Name == 'StateRing' and d:IsA('BasePart') then table.insert(slot.Rings, d)
		elseif d.Name == 'StateLock' and d:IsA('BasePart') then table.insert(slot.Locks, d)
		elseif d.Name == 'StateStrip' and d:IsA('BasePart') then slot.Strip = d
		elseif d:IsA('SpotLight') and d.Name == 'StateSpot' then table.insert(slot.Spots, d)
		elseif d:IsA('PointLight') and d.Name == 'StateGlow' then table.insert(slot.Glows, d)
		elseif d:IsA('TextLabel') and d.Name == 'State' then slot.StateLabel = d
		elseif d:IsA('Frame') and d.Name == 'NextBar' then slot.Bar = d
		elseif d:IsA('Frame') and d.Name == 'NextFill' then slot.Fill = d
		elseif d:IsA('TextLabel') and d.Name == 'Price' and d:FindFirstAncestor('GunLabel') then slot.Price = d
		elseif d:IsA('ImageLabel') and d.Name == 'PriceIcon' then slot.PriceIcon = d
		elseif d:IsA('BasePart') and gunModel and d:IsDescendantOf(gunModel) then table.insert(slot.GunParts, { part = d, color = d.Color })
		end
	end
	if slot.Price then
		slot.PriceLayout = { Position = slot.Price.Position, Size = slot.Price.Size, Align = slot.Price.TextXAlignment }
	end
	local old = point:FindFirstChild('GunPrompt')
	if old then old:Destroy() end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'GunPrompt'
	prompt.ObjectText = gun.Name .. '  (x' .. gun.Multiplier .. ' Power)'
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function()
		local state = GunRules.state(guns, id)
		if state == 'Locked' then Net.get('BuyGun'):FireServer(id)
		elseif state == 'Owned' then Net.get('EquipGun'):FireServer(id) end
	end)
	slot.Prompt = prompt
	slot.Repaint = function() if slots[id] == slot then paint(slot, lookOf(id, nextGun())) end end
	slots[id] = slot
	-- A slot arriving (or coming back) is painted as it is now, without a celebration.
	paint(slot, lookOf(id, nextGun()))
	shown[id] = GunRules.state(guns, id)
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

---------------------------------------------------------------------------------------------- the moment you get it
-- One short beat (about a second), cheap and pooled: the ring wipes round to the new colour, one burst of cash
-- confetti (a purchase only), the gun spins once, and "EQUIPPED! xN POWER" pops over it.
local WIPE = 0.3 -- seconds the ring takes to go round
local function wipe(slot, from)
	-- (paint leaves the ring alone until the wipe is done, then the last segment's tween repaints it for sure)
	slot.WipeEnd = os.clock() + WIPE
	local last
	for i, p in slot.Rings do
		local to = p.Color
		p.Color = from
		last = TweenService:Create(p, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, (i - 1) % 6 * 0.035), { Color = to })
		last:Play()
	end
	if last then
		last.Completed:Connect(function()
			slot.WipeEnd = nil
			if slot.Repaint then slot.Repaint() end
		end)
	end
end
local function spin(slot)
	local display = slot.Display
	local gun = display and display:FindFirstChild('Gun')
	if not gun then return end
	pcall(function()
		local RunService = game:GetService('RunService')
		local rel = display:GetPivot():ToObjectSpace(gun:GetPivot())
		local started, conn = os.clock(), nil
		conn = RunService.Heartbeat:Connect(function()
			local t = math.min(1, (os.clock() - started) / 0.7)
			local eased = 1 - (1 - t) ^ 3
			gun:PivotTo(display:GetPivot() * CFrame.Angles(0, eased * 2 * math.pi, 0) * rel)
			if t >= 1 then conn:Disconnect() end
		end)
	end)
end
local function celebrate(slot, bought)
	local display = slot.Display
	local position = display and display:GetPivot().Position or slot.Model:GetPivot().Position
	local gun = slot.Gun
	-- (each beat on its own: one failing never stops the others)
	pcall(wipe, slot, GunRules.Colors.Locked.Top)
	if bought then pcall(Juice.shards, position, CASH_GREEN, 'confetti') end
	if display then pcall(Juice.flash, display) end
	spin(slot)
	pcall(Juice.popNumber, position + Vector3.new(0, 2.6, 0), 'EQUIPPED! x' .. gun.Multiplier .. ' POWER', GunRules.Colors.Equipped.Text, Font.fromEnum(Enum.Font.GothamBlack), { size = Vector2.new(7, 1.4) })
end

---------------------------------------------------------------------------------------------- keeping up
-- Celebrations only start once the server has told us what we own: loading your profile is not a purchase.
local primed = player:GetAttribute('OwnedGuns') ~= nil
local function repaint(lastCash)
	local upNext = nextGun()
	for id, slot in slots do
		local state = GunRules.state(guns, id)
		local before = shown[id]
		paint(slot, lookOf(id, upNext))
		if before ~= state then
			if primed and before == 'Locked' then celebrate(slot, true)
			elseif primed and before == 'Owned' and state == 'Equipped' then celebrate(slot, false) end
			shown[id] = state
		elseif id == upNext and lastCash and lastCash < slot.Gun.Cost and cash >= slot.Gun.Cost and slot.Display then
			-- the next gun just became affordable: one soft flash, then its bob and amber ring say "buy me"
			pcall(Juice.flash, slot.Display)
		end
	end
end
local function refresh(next, lastCash)
	guns = GunRules.sanitize(next)
	repaint(lastCash)
	primed = true
end
local function setCash(value)
	if type(value) ~= 'number' or value == cash then return end
	local last = cash
	cash = value
	repaint(last)
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
-- Cash comes from the Cash attribute (LobbyService keeps it in step) and from every profile push (sooner, right
-- after a purchase); either way the prices, the NEXT UP bar and the amber ring follow it.
player:GetAttributeChangedSignal('Cash'):Connect(function() setCash(player:GetAttribute('Cash')) end)
Net.get('ProfileUpdated').OnClientEvent:Connect(function(data)
	if type(data) ~= 'table' then return end
	local last = cash
	if type(data.Cash) == 'number' then cash = data.Cash end
	if type(data.Guns) == 'table' and type(data.Guns.Owned) == 'table' then
		refresh({ Owned = table.clone(data.Guns.Owned), Equipped = data.Guns.Equipped }, last)
	else
		repaint(last)
	end
end)
