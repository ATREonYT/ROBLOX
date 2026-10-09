-- Shoes on your screen (brief 16: the game's eggs and pets, the hood way). ShoeService decides everything; this asks
-- and shows:
--   * Box prompts: an "Open" prompt on every BoxPoint_<Id> of the shoe-box dais (map: a Model tagged HoodShoeBoxes with
--     ShoeBox_<Id> models), bound as boxes stream in, like Armory.client's gun slots.
--   * The chances board: over the box you stand nearest to (within BOARD_RANGE), its 6 shoes with their chances, like a
--     pet-sim egg board. An unowned Secret shows as a dark "???" until you have one.
--   * The unboxing moment (remote ShoeOpened): the box flies up in front of your camera, shakes, the lid pops with a light
--     burst, and the pair rises spinning out of it under a rarity banner (the name, the bonus, NEW!, EQUIPPED).
--   * Worn pairs: every player's best equipped pair (attribute ShoeWorn) on their feet via ShoeModels.wear, re-applied
--     on respawn and when SkinArt rebuilds the look's costume; the costume's own shoes are hidden locally meanwhile.
--   * Followers: every player's other equipped pairs (ShoesEquipped minus the worn one) hover and hop behind them like
--     pets. They are built and moved on each client, for every player within FOLLOW.Range: the server only replicates
--     two short attributes, so followers cost no network traffic, move at the frame rate with no jitter, and appear for
--     everyone (each client draws everyone's). Each follower is one anchored root with its parts welded to it, so a
--     frame moves one part per follower.
--   * The SHOES button (in the HUD's action column, slot ShoesSlot next to Rebirth) and the inventory: your pairs in rarity frames, the
--     selected pair's card with EQUIP / UNEQUIP / RECYCLE, EQUIP BEST, and the total bonus.
-- Shared/Models/ShoeModels and BoxModels (other builders) build the shoes and boxes; until they exist, or if one fails,
-- simple stand-in models are used so nothing breaks.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local CollectionService = game:GetService('CollectionService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local Shoes = require(Shared.Config.Shoes)
local ShoeRules = require(Shared.ShoeRules)

local player = Players.LocalPlayer
local Color, Tone = Kit.Color, Kit.Tone
local px = UDim2.fromOffset
local V3, CF = Vector3.new, CFrame.new

local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and type(result) == 'table' and result or nil
end
local ShoeModels = optional('Models', 'ShoeModels')
local BoxModels = optional('Models', 'BoxModels')

local BOARD_RANGE = 20 -- studs: the nearest box within this shows its chances board
local FOLLOW = { Range = 150, MaxPlayers = 12, Scale = 1.15, Back = 4.0, Side = 2.4, Hover = 0.5, Hop = 0.7 }
local COSTUME_SHOE_PIECES = { Sole = true, Shoe = true, ToeCap = true, Swoosh = true, HighTop = true, Boot = true, BootShaft = true, BootLace = true, ShoeToe = true, Wingtip = true }

local function rarityOf(id)
	local s = Shoes.ById[id]
	return s and Shoes.RarityById[s.Rarity] or Shoes.Rarities[1]
end
local function rainbow()
	local keys = {}
	for i, c in Shoes.Rainbow do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#Shoes.Rainbow - 1), c)) end
	return ColorSequence.new(keys)
end

---------------------------------------------------------------------------------------------- stand-in models
-- Plain stand-ins with the same contracts as ShoeModels / BoxModels, used only when those are missing or fail.
local Stub = {}
local function stubPart(parent, name, size, cf, color)
	local p = Instance.new('Part')
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- One shoe: Fit (the R15 foot box, invisible) at `at`, a chunky high-top round it, toe toward -Z.
function Stub.shoe(id, side, scale, at)
	local s = Shoes.ById[id] or Shoes.List[1]
	local k = scale or 1
	local o = at or CFrame.identity
	local m = Instance.new('Model')
	m.Name = 'Shoe' .. (side or 'R')
	local fit = stubPart(m, 'Fit', V3(1, 0.3, 1) * k, o, s.Colors.Main)
	fit.Transparency = 1
	m.PrimaryPart = fit
	stubPart(m, 'Sole', V3(1.12, 0.16, 1.42) * k, o * CF(0, -0.2 * k, -0.12 * k), s.Colors.Sole)
	stubPart(m, 'Upper', V3(1.06, 0.4, 1.26) * k, o * CF(0, 0.08 * k, -0.06 * k), s.Colors.Main)
	stubPart(m, 'ToeCap', V3(1.08, 0.2, 0.34) * k, o * CF(0, -0.02 * k, -0.62 * k), s.Colors.Sole)
	stubPart(m, 'Collar', V3(1.1, 0.4, 0.92) * k, o * CF(0, 0.42 * k, 0.12 * k), s.Colors.Main)
	stubPart(m, 'Stripe', V3(1.1, 0.1, 0.62) * k, o * CF(0, 0.1 * k, 0.04 * k), s.Colors.Accent)
	return m
end
-- A pair side by side, pivot at the soles' centre.
function Stub.pair(id, scale)
	local k = scale or 1
	local m = Instance.new('Model')
	m.Name = 'Pair_' .. tostring(id)
	local root = stubPart(m, 'Root', V3(0.2, 0.2, 0.2) * k, CFrame.identity, Color.white)
	root.Transparency = 1
	m.PrimaryPart = root
	for _, side in { 'L', 'R' } do
		Stub.shoe(id, side, k, CF((side == 'L' and -0.58 or 0.58) * k, 0.28 * k, 0)).Parent = m
	end
	return m
end
-- Weld a stand-in shoe to each foot (R15 feet, or the bottoms of R6 legs), scaled to the foot.
function Stub.wear(character, id)
	local made = {}
	for _, side in { 'L', 'R' } do
		local foot = character:FindFirstChild(side == 'L' and 'LeftFoot' or 'RightFoot')
		local r6 = false
		if not foot then
			foot = character:FindFirstChild(side == 'L' and 'Left Leg' or 'Right Leg')
			r6 = true
		end
		if foot and foot:IsA('BasePart') then
			local k = foot.Size.X
			local at = r6 and foot.CFrame * CF(0, -foot.Size.Y / 2 + 0.15 * k, 0) or foot.CFrame
			local shoe = Stub.shoe(id, side, k, at)
			for _, p in shoe:GetDescendants() do
				if p:IsA('BasePart') then
					p.Anchored, p.Massless = false, true
					local w = Instance.new('WeldConstraint')
					w.Part0, w.Part1 = foot, p
					w.Parent = p
				end
			end
			shoe.Name = 'HoodShoe' .. side
			shoe.Parent = character
			table.insert(made, shoe)
		end
	end
	return function()
		for _, m in made do m:Destroy() end
	end
end
-- A plain box: body, name plate and a Lid sub-model hinged on the body's back top edge. Pivot bottom centre.
function Stub.box(boxId, scale)
	local b = Shoes.BoxById[boxId] or Shoes.Boxes[1]
	local k = scale or 1
	local m = Instance.new('Model')
	m.Name = b.Id .. 'Box'
	local root = stubPart(m, 'Root', V3(1, 0.2, 1) * k, CFrame.identity, Color.white)
	root.Transparency = 1
	m.PrimaryPart = root
	stubPart(m, 'Body', V3(4.4, 2.1, 3.4) * k, CF(0, 1.05 * k, 0), b.Color)
	stubPart(m, 'Plate', V3(3, 0.8, 0.1) * k, CF(0, 1.05 * k, -1.75 * k), Color.ink)
	local lid = Instance.new('Model')
	lid.Name = 'Lid'
	lid.Parent = m
	local hinge = stubPart(lid, 'Hinge', V3(0.2, 0.2, 0.2) * k, CF(0, 2.1 * k, 1.7 * k), Color.white)
	hinge.Transparency = 1
	lid.PrimaryPart = hinge
	stubPart(lid, 'LidTop', V3(4.6, 0.6, 3.6) * k, CF(0, 2.4 * k, 0), b.Color:Lerp(Color.white, 0.25))
	m:SetAttribute('Scale', k)
	return m
end
function Stub.openLid(model, t)
	local lid, root = model:FindFirstChild('Lid'), model.PrimaryPart
	if not (lid and root and lid.PrimaryPart) then return end
	local k = model:GetAttribute('Scale') or 1
	local target = root.CFrame * CF(0, 2.1 * k, 1.7 * k) * CFrame.Angles(math.rad(110) * math.clamp(t, 0, 1), 0, 0)
	local delta = target * lid.PrimaryPart.CFrame:Inverse()
	for _, p in lid:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end
	end
end

local function call(module, name, ...)
	if module and type(module[name]) == 'function' then
		local ok, result = pcall(module[name], ...)
		if ok then return result end
		warn('[Shoes] ' .. name .. ': ' .. tostring(result))
	end
	return nil
end
local function makePair(id, scale)
	local m = call(ShoeModels, 'pair', id, scale)
	if typeof(m) == 'Instance' then return m end
	return Stub.pair(id, scale)
end
local function makeBox(boxId, scale)
	local m = call(BoxModels, 'build', boxId, scale)
	if typeof(m) == 'Instance' then return m, false end
	return Stub.box(boxId, scale), true
end
-- Returns the cleanup and whether the stand-in was used (ShoeModels.wear hides the look's own shoes itself).
local function wearPair(character, id)
	local cleanup = call(ShoeModels, 'wear', character, id)
	if type(cleanup) == 'function' then return cleanup, false end
	return Stub.wear(character, id), true
end
local function addFx(model, rarity)
	if ShoeModels and type(ShoeModels.fx) == 'function' then pcall(ShoeModels.fx, model, rarity) end
end
local function parts(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then table.insert(list, d) end
	end
	return list
end
-- A model's pivot and moving it there, without GetPivot / PivotTo (the same in Studio and the preview harness, like
-- the armory's builder). list: the model's parts, when the caller keeps them.
local function pivotOf(model)
	local pp = model.PrimaryPart
	if pp then return pp.CFrame * pp.PivotOffset end
	local ok, pivot = pcall(function() return model.WorldPivot end)
	return ok and typeof(pivot) == 'CFrame' and pivot or CFrame.new()
end
local function place(model, target, list)
	local delta = target * pivotOf(model):Inverse()
	for _, p in list or parts(model) do p.CFrame = delta * p.CFrame end
	if not model.PrimaryPart then model.WorldPivot = target end
end
-- A model's parts made into one assembly: an anchored invisible root at the model's pivot, every other part welded to
-- it, massless and untouchable. Moving the root moves the whole model.
local function assemble(model)
	local pivot = pivotOf(model)
	local root = Instance.new('Part')
	root.Name = 'FollowRoot'
	root.Size = V3(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = true, false, false, false, false
	root.CFrame = pivot
	root.Parent = model
	for _, p in parts(model) do
		if p ~= root then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			local w = Instance.new('Weld')
			w.Name = 'FollowWeld'
			w.Part0, w.Part1 = root, p
			w.C0 = pivot:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
	model.PrimaryPart = root
	return root
end

---------------------------------------------------------------------------------------------- worn pairs
-- Everyone's best equipped pair on their feet. The look's own shoes (SkinArt's BlockCostume pieces) are hidden while a
-- pair is worn and shown again when it comes off: ShoeModels.wear does that itself (also when the look is re-dressed);
-- with the stand-in, this script hides them locally.
local worn = {}
local function costumeFeet(character)
	local list = {}
	local costume = character:FindFirstChild('BlockCostume')
	if not costume then return list end
	for _, p in costume:GetChildren() do
		if p:IsA('BasePart') and COSTUME_SHOE_PIECES[p.Name] then table.insert(list, p) end
	end
	return list
end
local function showFeet(list, shown)
	for _, p in list do
		if p.Parent then p.LocalTransparencyModifier = shown and 0 or 1 end
	end
end
local function takeOff(plr)
	local st = worn[plr]
	if not st then return end
	worn[plr] = nil
	if st.Cleanup then pcall(st.Cleanup) end
	showFeet(st.Hidden, true)
end
local function applyWorn(plr)
	local character = plr.Character
	local id = plr:GetAttribute('ShoeWorn')
	local st = worn[plr]
	local valid = type(id) == 'string' and Shoes.ById[id] ~= nil and character ~= nil and character.Parent ~= nil
	if st and valid and st.Character == character and st.Id == id then
		-- Same pair on the same body: only a rebuilt costume (a new look) needs its shoes hidden again.
		local costume = character:FindFirstChild('BlockCostume')
		if st.Stub and st.Costume ~= costume then
			st.Costume = costume
			st.Hidden = costumeFeet(character)
			showFeet(st.Hidden, false)
		end
		return
	end
	takeOff(plr)
	if not valid then return end
	if not (character:FindFirstChild('LeftFoot') or character:FindFirstChild('Left Leg')) then return end
	local cleanup, stub = wearPair(character, id)
	local hidden = stub and costumeFeet(character) or {}
	showFeet(hidden, false)
	worn[plr] = { Character = character, Id = id, Cleanup = cleanup, Stub = stub, Costume = character:FindFirstChild('BlockCostume'), Hidden = hidden }
end

---------------------------------------------------------------------------------------------- followers
local followFolder = Instance.new('Folder')
followFolder.Name = 'HoodShoeFollowers'
followFolder.Parent = workspace
local follow = {} -- [player] = { Key, Character, Pets = { { Id, Model, Root, Pos, Yaw, Phase } } }

-- The equipped pairs that follow (all but the worn one), best first.
local function followerIds(plr)
	local ids = {}
	for id in string.gmatch(plr:GetAttribute('ShoesEquipped') or '', '[^,]+') do
		if Shoes.ById[id] then table.insert(ids, id) end
	end
	table.remove(ids, 1)
	return ids
end
local function clearFollowers(plr)
	local st = follow[plr]
	if not st then return end
	follow[plr] = nil
	for _, pet in st.Pets do pet.Model:Destroy() end
end
local function rootOf(character)
	return character and character:FindFirstChild('HumanoidRootPart')
end
-- The slot behind the owner (owner space) for follower i of n.
local function slot(i, n)
	if n == 1 then return V3(-FOLLOW.Side * 0.75, 0, FOLLOW.Back) end
	return V3((i == 1 and -1 or 1) * FOLLOW.Side, 0, FOLLOW.Back + (i - 1) * 0.4)
end
-- Where the owner's feet are (the lowest foot or leg), so followers hover just over the floor they walk on.
local function feetY(character, root)
	local y = math.huge
	for _, name in { 'LeftFoot', 'RightFoot', 'Left Leg', 'Right Leg' } do
		local p = character:FindFirstChild(name)
		if p and p:IsA('BasePart') then y = math.min(y, p.CFrame.Y - p.Size.Y / 2) end
	end
	if y == math.huge then y = root.CFrame.Y - 3 end
	return y
end
local function buildFollowers(plr)
	local character = plr.Character
	local root = rootOf(character)
	local ids = followerIds(plr)
	local key = table.concat(ids, ',')
	local st = follow[plr]
	if st and st.Key == key and st.Character == character then return end
	clearFollowers(plr)
	if not root or #ids == 0 then return end
	st = { Key = key, Character = character, Pets = {} }
	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
	for i, id in ids do
		local model = makePair(id, FOLLOW.Scale)
		model.Name = 'Follower_' .. plr.Name .. '_' .. i
		addFx(model, rarityOf(id).Id) -- (before the welds, so its parts follow too)
		local froot = assemble(model)
		local start = (root.CFrame * CF(slot(i, #ids))).Position
		start = V3(start.X, feetY(character, root) + FOLLOW.Hover, start.Z)
		froot.CFrame = CF(start) * CFrame.Angles(0, yaw, 0)
		model.Parent = followFolder
		table.insert(st.Pets, { Id = id, Model = model, Root = froot, Pos = start, Yaw = yaw, Phase = i * 1.7 })
	end
	follow[plr] = st
end
-- Who gets followers drawn: you, and the nearest others within FOLLOW.Range (at most FOLLOW.MaxPlayers in all).
local function refreshFollowers()
	local me = rootOf(player.Character)
	local here = me and me.CFrame.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
	local near = {}
	for _, plr in Players:GetPlayers() do
		local r = rootOf(plr.Character)
		if r and here then
			local d = plr == player and 0 or (r.CFrame.Position - here).Magnitude
			if d <= FOLLOW.Range then table.insert(near, { plr, d }) end
		end
	end
	table.sort(near, function(a, b) return a[2] < b[2] end)
	local keep = {}
	for i = 1, math.min(#near, FOLLOW.MaxPlayers) do keep[near[i][1]] = true end
	for plr in follow do
		if not keep[plr] then clearFollowers(plr) end
	end
	for plr in keep do buildFollowers(plr) end
end
local clock = 0
local lastRoot = {}
local function stepFollowers(dt)
	clock += dt
	for plr, st in follow do
		local character = st.Character
		local root = rootOf(character)
		if not root or not character.Parent then
			clearFollowers(plr)
			continue
		end
		local here = root.CFrame.Position
		local before = lastRoot[plr] or here
		lastRoot[plr] = here
		local speed = dt > 0 and (here - before).Magnitude / dt or 0
		local moving = math.clamp((speed - 1) / 6, 0, 1)
		local ownerYaw = select(2, root.CFrame:ToEulerAnglesYXZ())
		local ground = feetY(character, root)
		local n = #st.Pets
		local a = 1 - math.exp(-9 * dt)
		for i, pet in st.Pets do
			local target = (root.CFrame * CF(slot(i, n))).Position
			pet.Pos = pet.Pos:Lerp(V3(target.X, ground, target.Z), a)
			local dyaw = (ownerYaw - pet.Yaw + math.pi) % (2 * math.pi) - math.pi
			pet.Yaw += dyaw * (1 - math.exp(-6 * dt))
			local t = clock + pet.Phase
			local bob = math.sin(t * 2.4) * 0.14 * (1 - moving)
			local hop = math.abs(math.sin(t * 8.5)) * FOLLOW.Hop * moving
			local tilt = math.sin(t * 8.5) * 0.12 * moving
			pet.Root.CFrame = CF(pet.Pos + V3(0, FOLLOW.Hover + bob + hop, 0)) * CFrame.Angles(0, pet.Yaw, 0) * CFrame.Angles(-0.1 * moving, 0, tilt)
		end
	end
end

---------------------------------------------------------------------------------------------- every player
local function watchPlayer(plr)
	local function refresh()
		applyWorn(plr)
		refreshFollowers()
	end
	plr:GetAttributeChangedSignal('ShoeWorn'):Connect(function() applyWorn(plr) end)
	plr:GetAttributeChangedSignal('ShoesEquipped'):Connect(function()
		applyWorn(plr)
		if follow[plr] or plr == player then buildFollowers(plr) end
	end)
	local function spawned(character)
		-- A new look rebuilds SkinArt's costume: hide its shoes again (the worn pair stays welded to the feet).
		character.ChildAdded:Connect(function(child)
			if child.Name == 'BlockCostume' then task.defer(applyWorn, plr) end
		end)
		-- wait for the feet (R15) or the legs (R6) before dressing them
		local humanoid = character:WaitForChild('Humanoid', 5)
		local r6 = humanoid and humanoid:IsA('Humanoid') and humanoid.RigType == Enum.HumanoidRigType.R6
		local foot = character:FindFirstChild('LeftFoot') or character:FindFirstChild('Left Leg') or character:WaitForChild(r6 and 'Left Leg' or 'LeftFoot', 5)
		if foot then refresh() end
	end
	plr.CharacterAdded:Connect(spawned)
	if plr.Character then task.spawn(spawned, plr.Character) end
end
for _, plr in Players:GetPlayers() do watchPlayer(plr) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(plr)
	takeOff(plr)
	clearFollowers(plr)
	lastRoot[plr] = nil
end)
RunService:BindToRenderStep('HoodShoeFollowers', Enum.RenderPriority.Character.Value + 1, stepFollowers)
task.spawn(function()
	while true do
		task.wait(1)
		refreshFollowers()
	end
end)

---------------------------------------------------------------------------------------------- the local rack
local function myRack()
	return ShoeRules.fromAttributes(player:GetAttribute('ShoesOwned'), player:GetAttribute('ShoesEquipped'), player:GetAttribute('ShoesOpened'))
end
local newIds = {} -- pairs unboxed since you last opened the inventory (the SHOES button's NEW!)
local paintBadge -- (the SHOES button's sticker; set once the button exists)
local stickers = {} -- the ones the open inventory marks NEW!
local function cashNow()
	local c = player:GetAttribute('Cash')
	return type(c) == 'number' and c or 0
end

-- A pair in a ViewportFrame, 3/4 from above. locked: a dark silhouette.
local function pairViewport(id, size, z, locked)
	local model = makePair(id, 1)
	-- (from ShoeModels' own viewing side when it gives one, like the mock-ups; else 3/4 from above)
	local view = ShoeModels and typeof(ShoeModels.View) == 'Vector3' and ShoeModels.View or nil
	local vp = Kit.viewport(model, size, { Direction = view, Yaw = 32, Pitch = 22, Zoom = 1.04, ZIndex = z })
	vp:SetAttribute('PreviewImage', 'shoe:' .. id)
	if locked then
		vp.ImageColor3 = Color3.new(0, 0, 0)
		vp:SetAttribute('PreviewSilhouette', true)
	end
	return vp
end

---------------------------------------------------------------------------------------------- box prompts + chances boards
local boxes = {} -- [boxId] = { Box, Model, Point, Prompt, Board }
local unboxing = false

local function boardAnchorOffset(entry)
	-- 2.5 studs over the box model's top (or at its ChancesPoint attachment)
	local att = entry.Model:FindFirstChild('ChancesPoint', true)
	if att and att:IsA('Attachment') then return nil, att end
	local box, size = entry.Model:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	return V3(0, top - entry.Point.CFrame.Y + 2.5 + 2.5, 0), nil
end
local function cellFor(board, i, id, rack)
	local shoe = Shoes.ById[id]
	local rarity = Shoes.RarityById[shoe.Rarity]
	local owned = ShoeRules.copies(rack, id) > 0
	local hidden = shoe.Rank == #Shoes.Rarities and not owned
	local cell = Kit.new('Frame', { Name = 'Cell' .. i, BackgroundColor3 = Color.white, BorderSizePixel = 0, Position = UDim2.fromScale(0.02 + (i - 1) * 0.163, 0.28), Size = UDim2.fromScale(0.15, 0.68), Parent = board })
	Kit.corner(UDim.new(0.14, 0)).Parent = cell
	Kit.stroke(Color.ink, 2.5, true).Parent = cell
	local g = Kit.gradient(rarity.Color:Lerp(Color.white, 0.5), rarity.Color, 0.6)
	if shoe.Rank == #Shoes.Rarities then g.Color = rainbow(); g.Rotation = 45 end
	g.Parent = cell
	local vp = pairViewport(id, 96, 2, hidden)
	vp.AnchorPoint = Vector2.new(0.5, 0)
	vp.Position = UDim2.fromScale(0.5, 0.02)
	vp.Size = UDim2.fromScale(0.96, 0.62)
	vp.Parent = cell
	local chance = Kit.text({ Name = 'Chance', Text = ShoeRules.chanceText(rarity.Chance), Stroke = Color.ink, Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.24), ZIndex = 3, Parent = cell })
	chance.TextScaled = true
	local name = Kit.text({ Name = 'Name', Text = hidden and '???' or string.upper(shoe.Name), FontFace = Kit.Font.body, TextColor3 = Color.white, Stroke = Color.ink, Position = UDim2.fromScale(0.04, 0.85), Size = UDim2.fromScale(0.92, 0.13), ZIndex = 3, Parent = cell })
	name.TextScaled = true
	if owned then
		local tick = Kit.text({ Name = 'Owned', Text = '✔', FontFace = Kit.Font.body, TextColor3 = Tone.green.top, Stroke = Color.ink, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1.04, -0.06), Size = UDim2.fromScale(0.32, 0.2), ZIndex = 4, Parent = cell })
		tick.TextScaled = true
	end
	return cell
end
local function buildBoard(entry)
	local box = entry.Box
	local rack = myRack()
	local gui = Instance.new('BillboardGui')
	gui.Name = 'ShoeChances'
	gui.Size = UDim2.fromScale(13, 5)
	gui.LightInfluence = 0
	gui.MaxDistance = BOARD_RANGE + 15
	local offset, att = boardAnchorOffset(entry)
	if att then
		gui.Adornee = att
	else
		gui.Adornee = entry.Point
		gui.StudsOffsetWorldSpace = offset
	end
	local panel = Kit.new('Frame', { Name = 'Panel', BackgroundColor3 = Color.asphalt, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = gui })
	Kit.corner(UDim.new(0.08, 0)).Parent = panel
	Kit.stroke(Color.ink, 3, true).Parent = panel
	local title = Kit.text({ Name = 'Title', Text = string.upper(box.Name), Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.03, 0.03), Size = UDim2.fromScale(0.6, 0.22), ZIndex = 2, Parent = panel })
	title.TextScaled = true
	title.TextColor3 = box.Color:Lerp(Color.white, 0.35)
	local price = Kit.new('Frame', { Name = 'Price', BackgroundColor3 = Tone.green.base, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.04), Size = UDim2.fromScale(0.3, 0.2), ZIndex = 2, Parent = panel })
	Kit.corner(UDim.new(0.5, 0)).Parent = price
	Kit.stroke(Color.ink, 2.5, true).Parent = price
	Kit.gradient(Tone.green.top, Tone.green.base, 0.55).Parent = price
	local priceText = Kit.text({ Name = 'Text', Text = Format.compact(box.Price) .. ' CASH', Stroke = Tone.green.stroke, Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.8), ZIndex = 3, Parent = price })
	priceText.TextScaled = true
	entry.Price = price
	for i, id in box.Shoes do cellFor(panel, i, id, rack) end
	gui.Enabled = false
	gui.Parent = entry.Point
	entry.Board = gui
	entry.BoardKey = ShoeRules.ownedString(rack)
end

local function bindBox(model)
	local id = model:GetAttribute('BoxId')
	local box = type(id) == 'string' and Shoes.BoxById[id]
	if not box or (boxes[id] and boxes[id].Model == model) then return end
	local point = model:FindFirstChild('BoxPoint_' .. id, true) or model:WaitForChild('BoxPoint_' .. id, 5)
	if not point or not model.Parent then return end
	local old = point:FindFirstChild('ShoePrompt')
	if old then old:Destroy() end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'ShoePrompt'
	prompt.ObjectText = box.Name
	prompt.ActionText = 'Open  ' .. Format.compact(box.Price) .. ' Cash'
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3 -- (it spends Cash: a passing tap doesn't open a box)
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function()
		if unboxing then return end
		Net.get('OpenShoeBox'):FireServer(id)
	end)
	boxes[id] = { Box = box, Model = model, Point = point, Prompt = prompt }
end
local function watchDais(dais)
	local function added(child)
		if child:IsA('Model') and child:GetAttribute('BoxId') then task.spawn(bindBox, child) end
	end
	dais.ChildAdded:Connect(added)
	dais.ChildRemoved:Connect(function(child)
		local id = child:GetAttribute('BoxId')
		if id and boxes[id] and boxes[id].Model == child then boxes[id] = nil end
	end)
	for _, child in dais:GetChildren() do added(child) end
end
CollectionService:GetInstanceAddedSignal('HoodShoeBoxes'):Connect(watchDais)
for _, dais in CollectionService:GetTagged('HoodShoeBoxes') do watchDais(dais) end

-- The board's price pill: green while you can afford the box, red while you can't.
local function paintPrice(entry)
	local pill = entry.Price
	if not pill then return end
	local tone = cashNow() >= entry.Box.Price and Tone.green or Tone.red
	pill.BackgroundColor3 = tone.base
	local g = pill:FindFirstChildOfClass('UIGradient')
	if g then g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, tone.top), ColorSequenceKeypoint.new(0.55, tone.base), ColorSequenceKeypoint.new(1, tone.base) }) end
	local stroke = pill.Text:FindFirstChildOfClass('UIStroke')
	if stroke then stroke.Color = tone.stroke end
end
-- Show the board of the box you stand nearest to (only that one exists: walking off drops it); rebuild it when your
-- rack changes what it shows.
local shownBoard
-- (brief 19, LOOP) Standing at a box, the board above it lands in the screen's top band, over the hint, the goal line and
-- the GOAL DONE moment: it steps away while its top edge is in the top 17% of the screen (back below 22%) or while a
-- GOAL DONE moment is up. Walking up to a box, it shows mid-screen as before.
local boardHidden = false
local function boardClear(entry)
	local cam = workspace.CurrentCamera
	local gui = entry.Board
	if not cam or not gui then return true end
	if player.PlayerGui:GetAttribute('GoalMoment') == true then return false end
	local adornee = gui.Adornee
	local ok, pos = pcall(function() return adornee:IsA('Attachment') and adornee.WorldPosition or adornee.Position end)
	if not ok or typeof(pos) ~= 'Vector3' then return true end
	local p, onScreen = cam:WorldToViewportPoint(pos + gui.StudsOffsetWorldSpace + Vector3.new(0, gui.Size.Y.Scale / 2, 0))
	if not onScreen then return true end
	local line = cam.ViewportSize.Y * (boardHidden and 0.22 or 0.17)
	boardHidden = p.Y < line
	return not boardHidden
end
local function refreshBoards()
	local root = rootOf(player.Character)
	local best, bestD = nil, BOARD_RANGE
	if root and not unboxing then
		for _, entry in boxes do
			if entry.Point.Parent then
				local d = (entry.Point.CFrame.Position - root.CFrame.Position).Magnitude
				if d <= bestD then best, bestD = entry, d end
			end
		end
	end
	if best and best.Board and best.BoardKey ~= (player:GetAttribute('ShoesOwned') or '') then
		best.Board:Destroy()
		best.Board = nil
	end
	if shownBoard and shownBoard ~= best and shownBoard.Board then
		shownBoard.Board:Destroy()
		shownBoard.Board, shownBoard.Price = nil, nil
	end
	if best and not best.Board then buildBoard(best) end
	if best and best.Board then
		paintPrice(best)
		best.Board.Enabled = boardClear(best)
	end
	shownBoard = best
end
task.spawn(function()
	while true do
		task.wait(0.25)
		local ok, err = pcall(refreshBoards)
		if not ok then warn('[Shoes] board: ' .. tostring(err)) end
	end
end)

---------------------------------------------------------------------------------------------- unboxing moment
local momentGui, momentRoot, momentFit = Kit.screen('HoodUnboxing', nil, 9)
momentGui.IgnoreGuiInset = true
local Sound = require(RS.Shared.Config.Sound) -- (COMBAT: every game sound behind one switch, off for now)
local chime = Sound.new('rbxasset://sounds/electronicpingshort.wav', 0.6, momentGui)

local queue = {}
local function cameraFrame()
	local cam = workspace.CurrentCamera
	if cam then return cam.CFrame, cam.FieldOfView end
	local root = rootOf(player.Character)
	local at = root and root.CFrame.Position or Vector3.zero
	return CFrame.lookAt(at + V3(0, 5, 12), at + V3(0, 2, 0)), 70
end
local function ease(t) return 1 - (1 - math.clamp(t, 0, 1)) ^ 3 end
local function backOut(t)
	t = math.clamp(t, 0, 1)
	local c = 1.70158
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

-- The light burst: thin neon rays fanned round the view axis behind the shoe, spinning slowly.
local function makeRays(parent, color, count)
	local list = {}
	for i = 1, count do
		local p = Instance.new('Part')
		p.Name = 'Ray'
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 1
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Size = V3(0.32, 7.5, 0.05)
		p.Parent = parent
		table.insert(list, { Part = p, Angle = (i - 1) / count * math.pi * 2 })
	end
	return list
end

-- The banner: rarity word up top, the name, bonus and stickers under the shoe.
local function banner(info, shoe, rarity)
	local holder = Kit.new('Frame', { Name = 'Unboxed', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = momentRoot })
	local flash = Kit.new('Frame', { Name = 'Flash', BackgroundColor3 = Color.white, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = holder })
	local top = Kit.new('Frame', { Name = 'Top', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.17), Size = px(760, 90), ZIndex = 5, Parent = holder })
	local topScale = Kit.new('UIScale', { Scale = 0.2, Parent = top })
	-- (brief 18: the reference's text: Gotham Black, white lit tops, thick black strokes, no boxes)
	local word = Kit.text({ Name = 'Rarity', Text = string.upper(rarity.Name) .. '!', TextSize = 76, Stroke = Color.black, StrokeThickness = 7, ZIndex = 6, Parent = top })
	if rarity.Rank == #Shoes.Rarities then
		local g = Kit.new('UIGradient', { Color = rainbow(), Parent = word })
		g.Rotation = 0
	else
		Kit.gradient(Color.white, rarity.Color, 0.5).Parent = word
	end
	local bottom = Kit.new('Frame', { Name = 'Bottom', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = px(760, 150), ZIndex = 5, Parent = holder })
	local name = Kit.text({ Name = 'Name', Text = shoe.Name, TextSize = 50, Stroke = Color.black, StrokeThickness = 5.5, Size = UDim2.new(1, 0, 0, 56), ZIndex = 6, Parent = bottom })
	local bonus = Kit.text({ Name = 'Bonus', Text = ShoeRules.bonusText(shoe.Bonus) .. ' Power', TextSize = 38, Stroke = Color.black, StrokeThickness = 4.5, Position = px(0, 56), Size = UDim2.new(1, 0, 0, 44), ZIndex = 6, Parent = bottom })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFA81A')), Parent = bonus })
	local box = Shoes.BoxById[shoe.Box]
	local note
	if info.Equipped then
		note = 'EQUIPPED!'
	elseif info.Better then
		note = 'Tap SHOES > EQUIP BEST to wear it'
	else
		note = 'From the ' .. (box and box.Name or 'box') .. '  •  you have x' .. tostring(info.Count or 1)
	end
	local line = Kit.text({ Name = 'Note', Text = note, TextSize = 28, TextColor3 = info.Equipped and Kit.hex('7CFF4F') or Color.white, Stroke = Color.black, StrokeThickness = 3.5, Position = px(0, 104), Size = UDim2.new(1, 0, 0, 34), ZIndex = 6, Parent = bottom })
	local sticker
	if info.New then
		sticker = Kit.text({ Name = 'New', Text = 'NEW!', TextSize = 44, TextColor3 = Kit.hex('7CFF4F'), Stroke = Color.black, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 260, 0, 24), Size = px(160, 54), Rotation = 12, ZIndex = 7, Parent = bottom })
	end
	local fadeables = { word, name, bonus, line, sticker }
	for _, t in fadeables do
		t.TextTransparency = 1
		t:FindFirstChildOfClass('UIStroke').Transparency = 1
	end
	return {
		Holder = holder, Flash = flash, TopScale = topScale, Fade = fadeables,
		Reveal = function()
			flash.BackgroundTransparency = 0.15
			TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			word.TextTransparency = 0
			word:FindFirstChildOfClass('UIStroke').Transparency = 0
			TweenService:Create(topScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			local show = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			for i, t in fadeables do
				if t and t ~= word then
					task.delay(0.15 + i * 0.08, function()
						if not t.Parent then return end
						TweenService:Create(t, show, { TextTransparency = 0 }):Play()
						TweenService:Create(t:FindFirstChildOfClass('UIStroke'), show, { Transparency = 0 }):Play()
					end)
				end
			end
			if sticker then Motion.wobble(sticker, 8, 0.7) end
		end,
		Out = function()
			local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, t in fadeables do
				if t then
					TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
					TweenService:Create(t:FindFirstChildOfClass('UIStroke'), fade, { Transparency = 1 }):Play()
				end
			end
		end,
	}
end

-- Timeline (seconds): box flies in, shakes three times, the lid pops (flash, rays, light), the pair rises spinning out of
-- the box, holds under the banner (longer for Legendary and up), then everything goes. A tap after the reveal skips.
local T = { In = 0.35, Shake = 1.0, Pop = 0.22, Rise = 0.75, Hold = 1.5, Out = 0.35 }
local skipRequested = false
local function play(info)
	local shoe = Shoes.ById[info.Shoe]
	local boxDef = Shoes.BoxById[info.Box]
	if not shoe or not boxDef then return end
	local rarity = Shoes.RarityById[shoe.Rarity]
	unboxing = true
	if shownBoard and shownBoard.Board then shownBoard.Board.Enabled = false end
	local folder = Instance.new('Model')
	folder.Name = 'HoodUnboxing'
	folder.Parent = workspace.CurrentCamera or workspace
	local BOX_SCALE, PAIR_SCALE, D = 0.62, 1.5, 6.5
	-- a dark sheet behind the stage dims the world while the moment plays (the box and pair stay bright in front)
	local dim = Instance.new('Part')
	dim.Name = 'Dim'
	dim.Size = V3(60, 40, 0.2)
	dim.Color = Color3.fromRGB(8, 8, 20)
	dim.Material = Enum.Material.Neon -- (unlit: a plain dark veil whatever the light)
	dim.Transparency = 1
	dim.Anchored, dim.CanCollide, dim.CanTouch, dim.CanQuery, dim.CastShadow = true, false, false, false, false
	dim.Parent = folder
	-- and the world past the stage goes soft (a local depth-of-field: the box and pair, D studs away, stay sharp)
	local focus = Instance.new('DepthOfFieldEffect')
	focus.Name = 'HoodUnboxingFocus'
	focus.FocusDistance = D
	focus.InFocusRadius = 4
	focus.NearIntensity = 0
	focus.FarIntensity = 0
	focus.Parent = game:GetService('Lighting')
	local box, stub = makeBox(info.Box, BOX_SCALE)
	box.Parent = folder
	if not stub then pcall(BoxModels.fx, box) end
	local boxParts = parts(box)
	local pair = makePair(info.Shoe, PAIR_SCALE)
	pair.Parent = folder
	addFx(pair, rarity.Id)
	local pairParts = parts(pair)
	local light = Instance.new('PointLight')
	light.Color = rarity.Color
	light.Range = 14
	light.Brightness = 0
	light.Shadows = false
	light.Parent = pairParts[1]
	local rays = makeRays(folder, rarity.Rank == #Shoes.Rarities and Color3.fromRGB(255, 236, 140) or rarity.Color, rarity.Rank >= 4 and 14 or 10)
	local ui = banner(info, shoe, rarity)
	local hold = T.Hold + (rarity.Rank >= 4 and 0.9 or 0)
	local tReveal = T.In + T.Shake + T.Pop
	local tEnd = tReveal + T.Rise + hold + T.Out
	local skip = Kit.new('TextButton', { Name = 'Skip', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = ui.Holder })
	skipRequested = false
	skip.Activated:Connect(function() skipRequested = true end)
	local start = os.clock()
	-- The pair grows from small as it rises (Model:ScaleTo, where the engine has it).
	local canScale = pcall(function() return pair:GetScale() end)
	local scaled = 1
	local revealed = false
	local finished = false
	local yawSpin = 0
	local function frameAt(t)
		local cam = cameraFrame()
		-- the stage: D studs in front of the camera, facing it (its -Z toward the camera), level with the view's centre.
		-- The box stands below the centre, its top tipped toward you and turned three-quarters; the pair ends up in the
		-- middle of the screen, between the rarity word above and the name below.
		local stage = cam * CF(0, 0, -D) * CFrame.Angles(0, math.pi, 0)
		local pose = CFrame.Angles(-0.28, 0, 0) * CFrame.Angles(0, 0.5, 0)
		local BOX_Y = -2.7
		local boxCf
		if t < T.In then
			local k = backOut(t / T.In)
			boxCf = stage * CF(0, BOX_Y - 6 * (1 - k), 0) * pose
		elseif t < T.In + T.Shake then
			local s = (t - T.In) / T.Shake
			local wave = math.sin(s * math.pi * 6) * (0.05 + 0.14 * s)
			local hopY = math.abs(math.sin(s * math.pi * 3)) * 0.25 * s
			boxCf = stage * CF(0, BOX_Y + hopY, 0) * pose * CFrame.Angles(0, 0, wave)
		else
			local s = math.clamp((t - tReveal - T.Rise * 0.4) / 0.6, 0, 1)
			boxCf = stage * CF(0, BOX_Y - 5 * ease(s), 0) * pose
		end
		place(box, boxCf, boxParts)
		local fade = math.clamp(t / T.In, 0, 1) * math.clamp((tEnd - t) / T.Out, 0, 1)
		dim.Transparency = 1 - 0.45 * fade
		focus.FarIntensity = 0.75 * fade
		dim.CFrame = stage * CF(0, 0, 14)
		local lidT = t < T.In + T.Shake and 0 or ease((t - T.In - T.Shake) / T.Pop)
		if stub then Stub.openLid(box, lidT) else pcall(BoxModels.openLid, box, lidT) end
		-- the pair: hidden in the box until the pop, then rises and spins (fast, slowing to a slow turn)
		local r = math.clamp((t - tReveal + T.Pop * 0.5) / T.Rise, 0, 1)
		local riseY = BOX_Y + 0.6 + 1.1 * ease(r) -- (soles: from inside the box to just under the screen's centre)
		yawSpin = 6 * math.pi * ease(r) + math.max(0, t - tReveal - T.Rise) * 1.4
		local pairCf = stage * CF(0, riseY, 0) * CFrame.Angles(-0.22, 0, 0) * CFrame.Angles(0, yawSpin + 0.45, 0)
		if r <= 0 then pairCf = cam * CF(0, -60, 40) end -- (out of sight, behind the camera, until the lid pops)
		if canScale then
			local k = 0.35 + 0.65 * backOut(r)
			if math.abs(k - scaled) > 0.002 then
				scaled = k
				pcall(pair.ScaleTo, pair, k)
			end
		end
		place(pair, pairCf, pairParts)
		-- the burst behind it
		local glow = r > 0 and math.clamp(1 - (t - tReveal) / (T.Rise + hold), 0.35, 1) or 0
		light.Brightness = 3.5 * glow
		local center = stage * CF(0, riseY + 1.0, 0)
		local back = (center.Position - cam.Position).Unit
		local face = CFrame.lookAt(center.Position + back * 2.2, center.Position + back * 3.2)
		for _, ray in rays do
			local a = ray.Angle + t * 0.6
			ray.Part.CFrame = face * CFrame.Angles(0, 0, a) * CF(0, 3.9, 0)
			ray.Part.Transparency = r > 0 and (1 - 0.55 * ease(r) * glow) or 1
		end
	end
	local function finish()
		if finished then return end
		finished = true
		RunService:UnbindFromRenderStep('HoodUnboxing')
		ui.Holder:Destroy()
		folder:Destroy()
		focus:Destroy()
		unboxing = false
	end
	RunService:BindToRenderStep('HoodUnboxing', Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		if skipRequested and revealed and t < tEnd - T.Out then
			start -= (tEnd - T.Out) - t -- jump to the way out
			t = tEnd - T.Out
		end
		skipRequested = false
		if not revealed and t >= tReveal - T.Pop * 0.4 then
			revealed = true
			ui.Reveal()
			Sound.play(chime, 0.9 + rarity.Rank * 0.12)
		end
		if t >= tEnd - T.Out and not ui.Leaving then
			ui.Leaving = true
			ui.Out()
		end
		frameAt(math.min(t, tEnd))
		if t >= tEnd then finish() end
	end)
	-- (a safety net: the moment always ends, even if the render step stops being called)
	task.delay(tEnd + 2, finish)
	return tEnd
end
local function drain()
	if unboxing then return end
	local info = table.remove(queue, 1)
	if not info then return end
	local ok, length = pcall(play, info)
	if not ok then
		warn('[Shoes] unboxing: ' .. tostring(length))
		unboxing = false
		return drain()
	end
	task.delay((length or 0) + 0.1, drain)
end
Net.get('ShoeOpened').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or not Shoes.ById[info.Shoe] then return end
	newIds[info.Shoe] = true
	-- Better than a pair you have on (and it didn't go straight on): the banner says how to wear it.
	if not info.Equipped then
		local rack = myRack()
		local worst = math.huge
		for _, id in rack.Equipped do worst = math.min(worst, Shoes.bonus(id)) end
		info.Better = #rack.Equipped >= ShoeRules.MaxEquipped and Shoes.bonus(info.Shoe) > worst
	end
	if paintBadge then paintBadge() end
	table.insert(queue, info)
	drain()
end)

---------------------------------------------------------------------------------------------- HUD button + inventory
local hudGui = player:WaitForChild('PlayerGui'):WaitForChild('HoodHUD', 10)
local hudRoot = hudGui and hudGui:FindFirstChild('Root')
local column = hudRoot and hudRoot:FindFirstChild('Actions')
local gui, root, fit = Kit.screen('HoodShoes', nil, 8) -- (8: the window sits over the goal line, like the HUD's and the Store's)
-- (brief 17) The HUD keeps an empty square, ShoesSlot, in its button column (next to Rebirth); the button is the
-- HUD's own Kit.actionButton, so it matches the others. Without that slot: our own button at the left edge.
local slot = column and column:FindFirstChild('ShoesSlot')
if not slot then
	slot = Kit.new('Frame', { Name = 'ShoesSlot', BackgroundTransparency = 1, Position = px(126, 200), Size = px(96, 96), Parent = column or root })
end
-- (brief 18: the reference's Pets square: magenta, the icon filling it and rising over its top edge, like the HUD's)
local GRID_W, GRID_H, POP, ICON = slot.Size.X.Offset, slot.Size.Y.Offset, 14, 84
local buttonHolder, buttonHit = Kit.actionButton({ Name = 'Shoes', Tone = 'magenta', Width = GRID_W, Height = GRID_H, Position = px(0, 0), Text = 'Shoes', TextSize = 22, IconNode = Kit.new('Frame', { Name = 'IconSpot', BackgroundTransparency = 1, Size = px(ICON, ICON) }), Pop = POP })
buttonHolder.Parent = slot
local buttonSpot = buttonHolder.Body:FindFirstChild('IconSpot')
local buttonIcon
local buttonIconId
local function setButtonIcon()
	-- (brief 19) ICONS' Sneaker render once uploaded (the reference's Pets square shows one fixed glossy icon); until then
	-- the pair you wear, live
	if Kit.iconImage('Sneaker') ~= '' then
		if buttonIconId == 'Sneaker' then return end
		buttonIconId = 'Sneaker'
		if buttonIcon then buttonIcon:Destroy() end
		buttonIcon = Kit.icon3d('Sneaker', ICON, { ZIndex = buttonSpot.ZIndex })
		buttonIcon.Parent = buttonSpot
		return
	end
	local id = player:GetAttribute('ShoeWorn')
	if type(id) ~= 'string' or not Shoes.ById[id] then id = Shoes.Boxes[1].Shoes[1] end
	if id == buttonIconId and buttonIcon and buttonIcon.Parent then return end
	buttonIconId = id
	if buttonIcon then buttonIcon:Destroy() end
	buttonIcon = pairViewport(id, ICON, buttonSpot.ZIndex)
	buttonIcon.Parent = buttonSpot
end
setButtonIcon()
-- (the reference's red "!" over the top-right corner, like its Items square: new pairs to look at)
local buttonBadge = Kit.sticker(buttonHolder, { Name = 'Badge', Text = '', TextSize = 40, TextColor3 = Kit.hex('FF3A1A'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 4), Width = 40, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
local badgeWobble
paintBadge = function()
	local fresh = next(newIds) ~= nil
	buttonBadge.Text = fresh and '!' or ''
	if fresh and not badgeWobble then
		badgeWobble = Motion.wobble(buttonBadge, 10, 0.8)
	elseif not fresh and badgeWobble then
		badgeWobble:Cancel()
		badgeWobble = nil
		buttonBadge.Rotation = 0
	end
end

-- The panel: a Kit.window like the HUD's (brief 17): a green studded header with a pair of shoes, "Shoes" and a red
-- X over the dark see-through body. PlayerGui's HoodWindow attribute keeps one window open at a time.
local headerArt = Kit.new('Frame', { Name = 'HeaderArt', BackgroundTransparency = 1, Size = px(110, 110), ZIndex = 27 })
local panel, well, closeHit, overlay = Kit.window(root, { Name = 'Shoes', Title = 'Shoes', IconNode = headerArt, IconSize = 110, Tone = 'headerMagenta', Width = 940, Height = 642 })
do
	local art
	if Kit.iconImage('Sneaker') ~= '' then
		art = Kit.icon3d('Sneaker', 110, { ZIndex = 27 })
	else
		art = pairViewport(Shoes.Boxes[1].Shoes[1], 110, 27)
	end
	art.Parent = headerArt
end
overlay.Visible = false
local isOpen = false
local function closePanel()
	if not isOpen then return end
	isOpen = false
	table.clear(stickers)
	Motion.blur('Shoes', false)
	Motion.close(overlay, panel)
	if player.PlayerGui:GetAttribute('HoodWindow') == 'Shoes' then player.PlayerGui:SetAttribute('HoodWindow', '') end
end
player.PlayerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and player.PlayerGui:GetAttribute('HoodWindow') ~= 'Shoes' then closePanel() end
end)
local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
backdrop.Activated:Connect(closePanel)
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
Motion.button(closeHit.Parent, closePanel)

local function body(parent, text, props)
	props = props or {}
	return Kit.text({
		Name = props.Name or 'Body', Text = text, FontFace = Kit.Font.body, TextSize = props.TextSize or 16, TextColor3 = props.Color or Color.white,
		Stroke = props.Stroke or Color.ink, StrokeThickness = props.StrokeThickness or 2,
		TextXAlignment = props.Align or Enum.TextXAlignment.Left, TextYAlignment = props.YAlign or Enum.TextYAlignment.Center, TextWrapped = true,
		Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 25, Parent = parent,
	})
end
-- A small chip (WORN, the rarity line): square-ish, a thick ink outline, the tone's gradient, an outlined label.
local function pill(parent, text, tone, props)
	local t = Tone[tone]
	local p = Kit.new('Frame', { Name = props.Name or 'Pill', BackgroundColor3 = t and t.base or Color.asphalt, BorderSizePixel = 0, AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position, Size = props.Size, ZIndex = props.ZIndex or 26, Parent = parent })
	Kit.corner(3).Parent = p
	Kit.stroke(Color.black, 2.5, true).Parent = p
	if t then Kit.gradient(t.top, t.base, 0.6).Parent = p end
	local label = Kit.text({ Name = 'Text', Text = text, TextSize = props.TextSize or 15, Stroke = Color.black, StrokeThickness = math.max(1.5, (props.TextSize or 15) * 0.13), ZIndex = (props.ZIndex or 26) + 1, Parent = p })
	return p, label
end
local function actionIn(parent, old, props, onClick)
	if old then old:Destroy() end
	props.ZIndex = props.ZIndex or 27
	if props.Studs == nil then props.Studs = 18 end
	local holder = Kit.blockButton(props)
	holder.Parent = parent
	if not props.Disabled then Motion.button(holder, onClick) end
	return holder
end

-- Top bar: the total bonus, how many pairs are on, the rack, EQUIP BEST.
-- (brief 18: the reference's window body: the total in gold Gotham Black, the grid of pairs left, the selected pair's
-- studded card right, all on the grey see-through body of Kit.window 940 x 642)
local total = Kit.text({ Name = 'Total', Text = '', TextSize = 32, Stroke = Color.black, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(6, 0), Size = px(560, 38), ZIndex = 25, Parent = well })
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFA81A')), Parent = total })
local summary = body(well, '', { Name = 'Summary', Position = px(6, 38), Size = px(600, 24), TextSize = 17, Stroke = Color.black })
local bestButton
local grid = Kit.new('ScrollingFrame', {
	Name = 'Pairs', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(0, 70), Size = px(606, 422), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.white, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = well,
})
Kit.new('UIGridLayout', { CellSize = px(138, 168), CellPadding = px(10, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = grid })
local empty = body(well, 'No shoes yet!\nOpen a shoe box at the back of the hall.\nEvery pair you wear adds Power to every shot.', { Name = 'Empty', FontFace = Kit.Font.display, Stroke = Color.black, StrokeThickness = 3, Align = Enum.TextXAlignment.Center, Position = px(20, 170), Size = px(560, 140), TextSize = 26 })

-- The selected pair's card on the right.
local DETAIL_W, DETAIL_H = 286, 422
local detail = Kit.new('Frame', { Name = 'Detail', BackgroundColor3 = Color.white, BorderSizePixel = 0, Position = px(618, 70), Size = px(DETAIL_W, DETAIL_H), ZIndex = 24, Parent = well })
Kit.stroke(Color.black, 5, true, 0, Enum.LineJoinMode.Miter).Parent = detail
local detailGradient = Kit.gradient(Color.white, Color.cardboardInset, 0.6)
detailGradient.Parent = detail
Kit.studs(detail, { Width = DETAIL_W, Height = DETAIL_H, Pitch = 26, Color = Color.black, Transparency = 0.92, ZIndex = 24 })
do
	local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, Position = px(5, 5), Size = UDim2.new(1, -10, 1, -10), ZIndex = 24, Parent = detail })
	Kit.stroke(Color.white, 5, true, 0.55, Enum.LineJoinMode.Miter).Parent = rim
end
local detailView
local detailName = Kit.text({ Name = 'Name', Text = '', TextSize = 30, Stroke = Color.black, StrokeThickness = 4, Position = px(8, 168), Size = px(DETAIL_W - 16, 36), ZIndex = 26, Parent = detail })
local detailRarity, detailRarityText = pill(detail, '', nil, { Name = 'Rarity', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 206), Size = px(176, 28), TextSize = 17 })
local detailBonus = Kit.text({ Name = 'Bonus', Text = '', TextSize = 30, Stroke = Color.black, StrokeThickness = 4, Position = px(8, 238), Size = px(DETAIL_W - 16, 36), ZIndex = 26, Parent = detail })
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFA81A')), Parent = detailBonus })
local detailFrom = body(detail, '', { Name = 'From', Align = Enum.TextXAlignment.Center, Stroke = Color.black, Position = px(8, 274), Size = px(DETAIL_W - 16, 22), TextSize = 16, ZIndex = 26 })
local detailEquip, detailRecycle
local selected
local confirmRecycle = { Id = nil, Until = 0 }

local function rarityFill(frame, id)
	local shoe = Shoes.ById[id]
	local rarity = rarityOf(id)
	local g = frame:FindFirstChildOfClass('UIGradient')
	if shoe and shoe.Rank == #Shoes.Rarities then
		g.Color = rainbow()
		g.Rotation = 45
	else
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rarity.Color:Lerp(Color.white, 0.6)), ColorSequenceKeypoint.new(0.6, rarity.Color:Lerp(Color.white, 0.1)), ColorSequenceKeypoint.new(1, rarity.Color:Lerp(Color.white, 0.1)) })
		g.Rotation = 90
	end
end

local refreshPanel -- (forward)
local function paintDetail(rack)
	local id = selected
	local shoe = id and Shoes.ById[id]
	detail.Visible = shoe ~= nil and ShoeRules.copies(rack, id) > 0
	if not detail.Visible then return end
	local rarity = rarityOf(id)
	rarityFill(detail, id)
	if detailView then detailView:Destroy() end
	detailView = pairViewport(id, Vector2.new(270, 160), 26)
	detailView.Position = px(8, 6)
	detailView.Parent = detail
	detailName.Text = shoe.Name
	detailName.TextSize = Kit.fitSize(shoe.Name, 30, DETAIL_W - 24, 14)
	detailRarity.BackgroundColor3 = rarity.Color
	detailRarityText.Text = rarity.Name .. '  ' .. ShoeRules.chanceText(rarity.Chance)
	detailBonus.Text = ShoeRules.bonusText(shoe.Bonus) .. ' Power'
	local copies, on = ShoeRules.copies(rack, id), ShoeRules.equippedCount(rack, id)
	detailFrom.Text = (Shoes.BoxById[shoe.Box] and Shoes.BoxById[shoe.Box].Name or '') .. '  •  x' .. copies .. (on > 0 and ('  •  ' .. on .. ' on') or '')
	local canEquip, why = ShoeRules.canEquip(rack, id)
	local equipProps
	if on > 0 and not canEquip then
		equipProps = { Name = 'Equip', Tone = 'cardRed', Text = 'Unequip', TextSize = 32, Width = 240, Height = 58, Outline = 4, RimWidth = 3, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 304) }
		detailEquip = actionIn(detail, detailEquip, equipProps, function() Net.get('ShoeAction'):FireServer('Unequip', id) end)
	else
		equipProps = { Name = 'Equip', Tone = 'lime', Text = why == 'full' and 'Slots full' or 'Equip', TextSize = 32, Width = 240, Height = 58, Outline = 4, RimWidth = 3, Disabled = not canEquip, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 304) }
		detailEquip = actionIn(detail, detailEquip, equipProps, function() Net.get('ShoeAction'):FireServer('Equip', id) end)
	end
	local canRecycle = ShoeRules.canRecycle(rack, id)
	local confirming = canRecycle and confirmRecycle.Id == id and os.clock() < confirmRecycle.Until
	local refund = ShoeRules.refund(id)
	detailRecycle = actionIn(detail, detailRecycle, {
		Name = 'Recycle', Tone = confirming and 'cardRed' or 'grey', Disabled = not canRecycle, TextSize = 18, Width = 240, Height = 40, Outline = 3, RimWidth = 2, Studs = false,
		Text = confirming and 'Tap again to recycle' or (canRecycle and ('Recycle  +' .. Format.compact(refund) .. ' Cash') or 'Take it off to recycle'),
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 370),
	}, function()
		if confirmRecycle.Id == id and os.clock() < confirmRecycle.Until then
			confirmRecycle.Id = nil
			Net.get('ShoeAction'):FireServer('Recycle', id)
		else
			confirmRecycle.Id, confirmRecycle.Until = id, os.clock() + 3
			task.delay(3.05, function() if isOpen then refreshPanel() end end)
		end
		refreshPanel()
	end)
end

-- Card viewports are kept per shoe and moved into each new card (a rebuilt grid builds no new models).
local cardViews = {}
local function cardView(id)
	local vp = cardViews[id]
	if not vp then
		vp = pairViewport(id, Vector2.new(130, 96), 26)
		vp.Position = px(4, 8)
		cardViews[id] = vp
	end
	return vp
end
local function paintSelection()
	for _, c in grid:GetChildren() do
		local stroke = c:IsA('Frame') and c:FindFirstChildOfClass('UIStroke')
		if stroke then
			local on = c.Name == selected
			stroke.Color = on and Kit.hex('FFE600') or Color.black
			stroke.Thickness = on and 5 or 3.5
		end
	end
end
local function pairCard(id, rack, order)
	local shoe = Shoes.ById[id]
	local rarity = rarityOf(id)
	local copies, on = ShoeRules.copies(rack, id), ShoeRules.equippedCount(rack, id)
	-- (brief 19) the Store's card family: square corners, a mitred black outline, a light rim, faint studs once they're a
	-- texture (a frame grid on every card of a long list would cost too much)
	local c = Kit.new('Frame', { Name = id, BackgroundColor3 = Color.white, BorderSizePixel = 0, Size = px(138, 168), LayoutOrder = order, ZIndex = 25 })
	Kit.stroke(Color.black, 3.5, true, 0, Enum.LineJoinMode.Miter).Parent = c
	Kit.gradient(Color.white, Color.white, 0.6).Parent = c
	rarityFill(c, id)
	if Kit.studsAreCheap() then Kit.studs(c, { Width = 138, Height = 168, Pitch = 26, Shade = 0.45, ZIndex = 25 }) end
	local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, Position = px(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 25, Parent = c })
	Kit.stroke(Color.white, 3, true, 0.5, Enum.LineJoinMode.Miter).Parent = rim
	if shoe.Rank >= 4 then
		for k = 0, 5 do
			local ray = Kit.new('Frame', { BackgroundTransparency = 0.72, BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52), Size = px(12, 112), Rotation = k * 30, ZIndex = 25, Parent = c })
			Kit.corner(UDim.new(0.5, 0)).Parent = ray
		end
	end
	cardView(id).Parent = c
	Kit.text({ Name = 'ItemName', Text = shoe.Name, TextSize = Kit.fitSize(shoe.Name, 20, 126, 11), Stroke = Color.black, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102), Size = UDim2.new(1, -8, 0, 22), ZIndex = 27, Parent = c })
	local bonusText = Kit.text({ Name = 'Bonus', Text = ShoeRules.bonusText(shoe.Bonus), TextSize = 20, Stroke = Color.black, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.new(1, -8, 0, 22), ZIndex = 27, Parent = c })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFA81A')), Parent = bonusText })
	local tag = Kit.new('Frame', { Name = 'Rarity', BackgroundColor3 = rarity.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = px(-6, 12), Size = px(math.max(62, #rarity.Name * 8 + 14), 20), Rotation = -6, ZIndex = 28, Parent = c })
	Kit.corner(6).Parent = tag
	Kit.stroke(Color.ink, 2, true).Parent = tag
	Kit.text({ Text = rarity.Name, TextSize = 14, Stroke = Color.ink, StrokeThickness = 2, ZIndex = 29, Parent = tag })
	if copies > 1 then
		Kit.text({ Name = 'Copies', Text = 'x' .. copies, FontFace = Kit.Font.number, TextSize = 18, Stroke = Color.ink, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = px(40, 20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 28, Parent = c })
	end
	if on > 0 then
		-- the best pair on is the one on your feet; the others follow you
		local wornHere = ShoeRules.worn(rack) == id
		local text = wornHere and 'Worn' or 'Follows'
		if on > 1 then text = wornHere and ('Worn +' .. (on - 1)) or ('Follows x' .. on) end
		pill(c, text, wornHere and 'yellow' or 'green', { Name = 'On', AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -28, 0, 18), TextSize = 13, ZIndex = 28 })
	end
	if stickers[id] then
		Kit.text({ Name = 'New', Text = 'NEW!', TextSize = 18, TextColor3 = Tone.green.top, Stroke = Tone.green.stroke, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 6, 0, 30), Size = px(52, 22), Rotation = 10, ZIndex = 29, Parent = c })
	end
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = c })
	hit.Activated:Connect(function()
		selected = id
		refreshPanel()
		if c.Parent then Motion.pop(c, 0.06) end
	end)
	return c
end

local shownKey
refreshPanel = function(force)
	if not isOpen then return end
	local rack = myRack()
	local list = {}
	for id in rack.Owned do table.insert(list, id) end
	table.sort(list, function(a, b)
		local ea, eb = ShoeRules.equippedCount(rack, a) > 0, ShoeRules.equippedCount(rack, b) > 0
		if ea ~= eb then return ea end
		return ShoeRules.before(a, b)
	end)
	if not selected or ShoeRules.copies(rack, selected) == 0 then selected = list[1] end
	local bonus = ShoeRules.bonus(rack)
	total.Text = ShoeRules.bonusText(bonus) .. ' Power  (x' .. string.format('%.2f', 1 + bonus / 100):gsub('%.?0+$', '') .. ' per shot)'
	summary.Text = #rack.Equipped .. '/' .. ShoeRules.MaxEquipped .. ' on: the best is worn, the others follow you  •  ' .. ShoeRules.count(rack) .. '/' .. ShoeRules.MaxOwned .. ' pairs'
	local bestNow = ShoeRules.best(rack)
	local isBest = #bestNow == #rack.Equipped
	if isBest then
		local current = ShoeRules.equippedList(rack)
		for i, idb in bestNow do
			if current[i] ~= idb then isBest = false end
		end
	end
	local bestKey = (#list == 0 and 'none') or (isBest and 'done') or 'ready'
	if not (bestButton and bestButton:GetAttribute('Key') == bestKey) then
		bestButton = actionIn(well, bestButton, {
			Name = 'EquipBest', Tone = 'aqua', Disabled = bestKey ~= 'ready', Text = bestKey == 'done' and 'Best on' or 'Equip Best', TextSize = 30, Width = 286, Height = 58, Outline = 4, RimWidth = 3,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2),
		}, function() Net.get('ShoeAction'):FireServer('EquipBest') end)
		bestButton:SetAttribute('Key', bestKey)
	end
	empty.Visible = #list == 0
	local fresh = {}
	for id in stickers do table.insert(fresh, id) end
	table.sort(fresh)
	local key = ShoeRules.ownedString(rack) .. '|' .. table.concat(rack.Equipped, ',') .. '|' .. table.concat(fresh, ',')
	if force or key ~= shownKey then
		shownKey = key
		for _, vp in cardViews do vp.Parent = nil end
		for _, child in grid:GetChildren() do
			if child:IsA('GuiObject') then child:Destroy() end
		end
		for i, id in list do pairCard(id, rack, i).Parent = grid end
	end
	paintSelection()
	paintDetail(rack)
end

local function openPanel()
	if isOpen then
		closePanel()
		return
	end
	isOpen = true
	player.PlayerGui:SetAttribute('HoodWindow', 'Shoes')
	shownKey = nil
	stickers = table.clone(newIds)
	table.clear(newIds)
	refreshPanel(true)
	paintBadge()
	Motion.blur('Shoes', true)
	Motion.open(overlay, panel, 1)
end
Motion.button(buttonHolder, openPanel)

---------------------------------------------------------------------------------------------- wiring
for _, key in { 'ShoesOwned', 'ShoesEquipped', 'ShoeBonus', 'Cash' } do
	player:GetAttributeChangedSignal(key):Connect(function()
		paintBadge()
		if isOpen then refreshPanel() end
	end)
end
player:GetAttributeChangedSignal('ShoeWorn'):Connect(setButtonIcon)

local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	Kit.fitWindow(panel, abs)
	momentFit(momentGui.AbsoluteSize)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = player:WaitForChild('PlayerGui')
momentGui.Parent = player:WaitForChild('PlayerGui')
relayout()
paintBadge()
