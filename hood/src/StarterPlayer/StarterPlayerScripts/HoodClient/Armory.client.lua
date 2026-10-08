-- The ARMORY (the gun shop) on your screen: a prompt on the counter in front of every gun in the shop (Buy /
-- Equip / Equipped), the card behind each gun painted in your state colours (a plain grey card and a small
-- padlock under its tag while locked, blue owned, green equipped, the equipped gun taken off its mount because it
-- is in your hands) and its tag's price or state word to match, a small burst in the gun's rarity metal when it
-- becomes yours, and everyone's equipped gun worn on the right hip while it isn't in their hand (the held gun
-- tool, Shoot.client, takes its place).
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

---------------------------------------------------------------------------------------------- the shop
-- The map tags the armory HoodArmory and makes each GunSlot_<Id> stream as one piece (Atomic), so slots are
-- bound as they arrive and dropped if they stream out; the prompt lives on the slot and goes with it.
local CollectionService = game:GetService('CollectionService')
local active = ActiveMap.wait(20)
if not active then return end

local guns = GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
local slots, shown = {}, {}

-- Which colour of GunRules.Colors[state] each named slot part takes (the map builder names them).
local ROLES = { StatePanel = 'Top' }

local function paint(slot, state)
	local look = GunRules.Colors[state]
	for _, p in slot.Parts do
		local color = look[ROLES[p.Name]]
		if color then p.Color = color end
	end
	-- the padlock only while it is locked; the gun leaves its mount while it is equipped (it is in your hands)
	for _, p in slot.Locks do p.Transparency = state == 'Locked' and 0 or 1 end
	for p, t in slot.GunParts do p.Transparency = state == 'Equipped' and 1 or t end
	if slot.Price then
		local glyph = slot.Price:GetAttribute('Glyph') or ''
		-- (the cash glyph or icon only goes with a price: a tick for OWNED, a star for EQUIPPED)
		if state ~= 'Locked' then glyph = state == 'Equipped' and '⭐' or '✅' end
		if slot.PriceIcon then slot.PriceIcon.Visible = state == 'Locked' end
		local word = state == 'Locked' and (slot.Gun.Cost == 0 and 'FREE' or Format.compact(slot.Gun.Cost)) or string.upper(state)
		slot.Price.Text = (glyph ~= '' and glyph .. ' ' or '') .. word
		slot.Price.TextColor3 = look.Text
	end
	local prompt = slot.Prompt
	prompt.ActionText = GunRules.actionText(state, slot.Gun.Cost)
	-- Buying holds a moment so a passing tap doesn't spend Cash; equipping is instant.
	prompt.HoldDuration = (state == 'Locked' and slot.Gun.Cost > 0) and 0.35 or 0
end

local function bind(model)
	local id = model:GetAttribute('GunId')
	local gun = type(id) == 'string' and Guns.ById[id]
	if not gun or (slots[id] and slots[id].Model == model) then return end
	local point = model:FindFirstChild('GunPoint_' .. id, true) or model:WaitForChild('GunPoint_' .. id, 5)
	if not point or not model.Parent then return end
	local slot = { Gun = gun, Model = model, Parts = {}, Locks = {}, GunParts = {} }
	local display = model:FindFirstChild('Display')
	for _, d in model:GetDescendants() do
		if ROLES[d.Name] and d:IsA('BasePart') then table.insert(slot.Parts, d)
		elseif d.Name == 'StateLock' and d:IsA('BasePart') then table.insert(slot.Locks, d)
		elseif display and d:IsA('BasePart') and d:IsDescendantOf(display) then
			-- (its look as built, remembered on the part the first time, so a slot bound again while its gun is
			-- off the rack still knows how to hang it back)
			local t = d:GetAttribute('RackTransparency')
			if t == nil then
				t = d.Transparency
				d:SetAttribute('RackTransparency', t)
			end
			slot.GunParts[d] = t
		elseif d:IsA('TextLabel') and d.Name == 'Price' and d:FindFirstAncestor('GunLabel') then slot.Price = d
		elseif d:IsA('ImageLabel') and d.Name == 'PriceIcon' then slot.PriceIcon = d
		end
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
	slots[id] = slot
	-- A slot arriving (or coming back) is painted as it is now, without a celebration.
	local state = GunRules.state(guns, id)
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

-- A gun that just became yours (or just got equipped) gets a burst in its rarity metal and a flash: on the gun
-- if it is still on its mount, else on its green card (an equipped gun has left the shop for your hands).
local function celebrate(slot, text, state)
	local display = slot.Model:FindFirstChild('Display')
	local position = display and display:GetPivot().Position or slot.Model:GetPivot().Position
	local flash = state == 'Equipped' and slot.Parts[1] or display
	local band = GunRules.rarity and GunRules.rarity(slot.Gun.Tier)
	local color = band and band.Color or slot.Gun.Color
	pcall(function()
		Juice.burst(position, color, 1.6)
		if flash then Juice.flash(flash) end
		Juice.popNumber(position + Vector3.new(0, 2, 0), text, color)
	end)
end

-- Celebrations only start once the server has told us what we own: loading your profile is not a purchase.
local primed = player:GetAttribute('OwnedGuns') ~= nil
local function refresh(next)
	guns = GunRules.sanitize(next)
	for id, slot in slots do
		local state = GunRules.state(guns, id)
		if shown[id] ~= state then
			local before = shown[id]
			paint(slot, state)
			if primed and before == 'Locked' then celebrate(slot, 'NEW GUN!', state)
			elseif primed and before == 'Owned' and state == 'Equipped' then celebrate(slot, 'EQUIPPED!', state) end
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
Net.get('ProfileUpdated').OnClientEvent:Connect(function(data)
	if type(data) == 'table' and type(data.Guns) == 'table' and type(data.Guns.Owned) == 'table' then
		refresh({ Owned = table.clone(data.Guns.Owned), Equipped = data.Guns.Equipped })
	end
end)
