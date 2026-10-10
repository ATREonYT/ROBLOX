-- Shoes on your screen (brief 16: the game's eggs and pets, the hood way). ShoeService decides everything; this asks
-- and shows:
--   * Box prompts: an "Open" prompt on every BoxPoint_<Id> of the shoe-box dais (map: a Model tagged HoodShoeBoxes with
--     ShoeBox_<Id> models), bound as boxes stream in, like Armory.client's gun slots. A Cash box opens for Cash (the
--     OpenShoeBox remote); a Robux box (brief 21: Config.Shoes box.Robux = its developer-product key) prompts Roblox's
--     purchase when it is live (Products.canBuy: an id and Wired), else says "Coming soon!". The receipt opens it on
--     the server (StoreService) and the same unboxing moment plays.
--   * The chances board: over the box you stand nearest to (within BOARD_RANGE), its shoes with their chances (6, or 5
--     on a Robux box: no Commons), like a pet-sim egg board. An unowned Secret shows as a dark "???" until you have one.
--   * The unboxing moment (remote ShoeOpened; brief 24: all 2D, flat PNGs over a blurred world): the box drops in,
--     shakes, the lid pops with a light burst, and the pair flies out big over its rarity splat with its rarity word,
--     name and bonus (NEW!, EQUIPPED!); rarer pairs get a bigger moment (SHOES2's ShoeFX.tier). A Buy 3 / Buy 8 (brief
--     22: one ShoeOpened with Shoes = the N pairs, Buy = N, Best = the pair the top-level fields describe) plays the same
--     box, then the N pairs fly out into a row. PlayerGui `Unboxing` is true while a moment plays and 0.3 s after
--     its last fade (the hint, the goal line, the toasts and the guide wait); `UnboxingCalm` is true until the pairs fly
--     back (the HUD steps aside). A tap moves it on a beat.
--   * Worn pairs: every player's best equipped pair (attribute ShoeWorn) on their feet via ShoeModels.wear, re-applied
--     on respawn and when SkinArt rebuilds the look's costume; the costume's own shoes are hidden locally meanwhile.
--   * Followers: every player's other equipped pairs (ShoesEquipped minus the worn one) hover and hop behind them like
--     pets. They are built and moved on each client, for every player within FOLLOW.Range: the server only replicates
--     two short attributes, so followers cost no network traffic, move at the frame rate with no jitter, and appear for
--     everyone (each client draws everyone's). Each follower is one anchored root with its parts welded to it, so a
--     frame moves one part per follower.
--   * (brief 22) The inventory window (your pairs, equip, recycle, equip best, the Index) is HoodClient/Inventory.client
--     now, and the HUD's Shoes square is HUD.client's; this script keeps no window.
-- Shared/Models/ShoeModels (another builder) builds the worn and follower shoes; until it exists, or if it fails, simple
-- stand-in models are used so nothing breaks.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local CollectionService = game:GetService('CollectionService')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local Shoes = require(Shared.Config.Shoes)
local ShoeRules = require(Shared.ShoeRules)
local Products = require(Shared.Config.Products)

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
local ShoeFX = optional('ShoeFX') -- (SHOES2: the rarity tiers, pure data; the reveal reads ShoeFX.tier)
local IK = require(Shared.InventoryKit)

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
	-- (a 3rd follower with the +1 Shoe Slot pass: centred, a step further back)
	if i == 3 then return V3(0, 0, FOLLOW.Back + 2.6) end
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
local function cashNow()
	local c = player:GetAttribute('Cash')
	return type(c) == 'number' and c or 0
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
-- What a board shows changes with your rack and with the Lucky pass (a Lucky owner's Cash boxes have better odds).
local function boardKey()
	return (player:GetAttribute('ShoesOwned') or '') .. '|' .. tostring(player:GetAttribute('Pass_Lucky') == true)
end
local function cellFor(board, i, id, rack, n)
	local shoe = Shoes.ById[id]
	local rarity = Shoes.RarityById[shoe.Rarity]
	local owned = ShoeRules.copies(rack, id) > 0
	local hidden = shoe.Rank == #Shoes.Rarities and not owned
	-- (n cells centred in a row: six fill it, a Robux box's five sit in the middle)
	local x0 = (1 - (n * 0.163 - 0.013)) / 2
	local cell = Kit.new('Frame', { Name = 'Cell' .. i, BackgroundColor3 = Color.white, BorderSizePixel = 0, Position = UDim2.fromScale(x0 + (i - 1) * 0.163, 0.28), Size = UDim2.fromScale(0.15, 0.68), Parent = board })
	Kit.corner(UDim.new(0.14, 0)).Parent = cell
	Kit.stroke(Color.ink, 2.5, true).Parent = cell
	local g = Kit.gradient(rarity.Color:Lerp(Color.white, 0.5), rarity.Color, 0.6)
	if shoe.Rank == #Shoes.Rarities then g.Color = rainbow(); g.Rotation = 45 end
	g.Parent = cell
	-- (brief 24) the shoe's flat PNG (or its flat stand-in), the same picture as the inventory's; never a 3D model
	local icon = IK.shoeIcon(id, 96, { ZIndex = 2, Locked = hidden })
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.02)
	icon.Size = UDim2.fromScale(0.96, 0.62)
	Kit.new('UIAspectRatioConstraint', { AspectRatio = 1, Parent = icon })
	icon.Parent = cell
	local chance = Kit.text({ Name = 'Chance', Text = ShoeRules.chanceText(ShoeRules.chanceOf(id, player:GetAttribute('Pass_Lucky') == true)), Stroke = Color.ink, Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.24), ZIndex = 3, Parent = cell })
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
	local priceText = Kit.text({ Name = 'Text', Text = box.Robux and (tostring(box.RobuxPrice) .. ' ROBUX') or (Format.compact(box.Price) .. ' CASH'), Stroke = Tone.green.stroke, Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.8), ZIndex = 3, Parent = price })
	priceText.TextScaled = true
	entry.Price = price
	if box.Exclusive then
		-- (a Robux box: a green EXCLUSIVE tag next to the title, like the reference's "Robux Exclusive" eggs)
		title.Size = UDim2.fromScale(0.36, 0.22)
		local tag = Kit.text({ Name = 'Exclusive', Text = 'EXCLUSIVE', TextColor3 = Kit.hex('7CFF4F'), Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.4, 0.07), Size = UDim2.fromScale(0.26, 0.15), ZIndex = 2, Parent = panel })
		tag.TextScaled = true
	end
	for i, id in box.Shoes do cellFor(panel, i, id, rack, #box.Shoes) end
	gui.Enabled = false
	gui.Parent = entry.Point
	entry.Board = gui
	entry.BoardKey = boardKey()
end

-- A short line in the upper middle of the screen (the HUD's notice style), for answers given here ("Coming soon!").
local _, sayRoot = Kit.screen('HoodShoeNotice', player:WaitForChild('PlayerGui'), 10)
local saying = 0
local function say(text)
	saying += 1
	local mine = saying
	for _, c in sayRoot:GetChildren() do
		if c.Name == 'Say' then c:Destroy() end
	end
	local t = Kit.text({ Name = 'Say', Text = text, TextSize = 30, TextColor3 = Kit.hex('5AE0FF'), Stroke = Color.black, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = px(900, 40), ZIndex = 44, Parent = sayRoot })
	t.TextScaled = true
	Motion.toast(t, 2.6)
	task.delay(3, function() if mine == saying and t.Parent then t:Destroy() end end)
end

-- A Robux box's prompt: Roblox's purchase once the product is live, "Coming soon!" until then (id 0).
local function robuxPrompt(box)
	if Products.canBuy(box.Robux) then return 'Buy  ' .. tostring(box.RobuxPrice) .. ' Robux' end
	return 'Coming soon!'
end
local function buyBox(box)
	if not Products.canBuy(box.Robux) then
		say(box.Name .. ' is coming soon!')
		return
	end
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, Products.idOf(box.Robux)) end)
	if not ok then say('Try again!') end
end
local function bindBox(model)
	local id = model:GetAttribute('BoxId')
	local box = type(id) == 'string' and Shoes.BoxById[id]
	if not box or (boxes[id] and boxes[id].Model == model) then return end
	-- (a later world's box is never on this world's dais; if a map shows one anyway, it gets no prompt)
	if not ShoeRules.inWorld(id) then return end
	local point = model:FindFirstChild('BoxPoint_' .. id, true) or model:WaitForChild('BoxPoint_' .. id, 5)
	if not point or not model.Parent then return end
	local old = point:FindFirstChild('ShoePrompt')
	if old then old:Destroy() end
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'ShoePrompt'
	prompt.ObjectText = box.Name
	prompt.ActionText = box.Robux and robuxPrompt(box) or ('Open  ' .. Format.compact(box.Price) .. ' Cash')
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3 -- (it spends Cash or opens a purchase: a passing tap doesn't)
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function()
		if unboxing then return end
		if box.Robux then
			buyBox(box)
		else
			Net.get('OpenShoeBox'):FireServer(id)
		end
	end)
	boxes[id] = { Box = box, Model = model, Point = point, Prompt = prompt }
	if not box.Robux then
		-- (brief 22) The Triple Open pass: a second prompt opens 3 at once for 3x the price (the server checks the pass,
		-- the Cash and the room; one ShoeOpened with Buy = 3 comes back). Shown only while you own the pass.
		local triple = Instance.new('ProximityPrompt')
		triple.Name = 'ShoePromptTriple'
		triple.ObjectText = box.Name
		triple.ActionText = 'Open x3  ' .. Format.compact(box.Price * 3) .. ' Cash'
		triple.KeyboardKeyCode = Enum.KeyCode.F
		triple.UIOffset = Vector2.new(0, 72)
		triple.HoldDuration = 0.3
		triple.MaxActivationDistance = 8
		triple.RequiresLineOfSight = false
		triple.Enabled = player:GetAttribute('Pass_TripleOpen') == true
		triple.Parent = point
		triple.Triggered:Connect(function()
			if unboxing then return end
			Net.get('OpenShoeBox'):FireServer(id, 3)
		end)
		boxes[id].Triple = triple
	end
end
player:GetAttributeChangedSignal('Pass_TripleOpen'):Connect(function()
	for _, entry in boxes do
		if entry.Triple then entry.Triple.Enabled = player:GetAttribute('Pass_TripleOpen') == true end
	end
end)
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
	-- (a Robux box's pill stays green: Roblox's own purchase window checks the Robux)
	local tone = (entry.Box.Robux or cashNow() >= entry.Box.Price) and Tone.green or Tone.red
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
	if best and best.Board and best.BoardKey ~= boardKey() then
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
	-- (CRITIC4 r1) while a board is up, the HUD's hint and Goals' goal line (it stands over them) step away
	player.PlayerGui:SetAttribute('BoxBoard', best ~= nil and best.Board ~= nil and best.Board.Enabled)
end
task.spawn(function()
	while true do
		task.wait(0.25)
		local ok, err = pcall(refreshBoards)
		if not ok then warn('[Shoes] board: ' .. tostring(err)) end
	end
end)

---------------------------------------------------------------------------------------------- unboxing moment (brief 24)
-- The user: "make the box opening animation way better, right now there is a half black screen ... maybe just blur the
-- back and add a nice animation". All 2D now (ART2's flat PNGs, or their flat stand-ins; no 3D model, no dark sheet):
--   0.00  the world blurs (a BlurEffect tweened in: Motion.blur) and stays bright; the HUD steps aside (PlayerGui
--         Unboxing: HUD.client slides its columns and bottom bar out). The box drops in and lands with a squash.
--   0.40  it shakes: three hops, each a squash and a stretch, the wobble growing, a soft light swelling behind it.
--   1.15  POP: a deep squash, the lid flies off spinning, a white flash ring and a burst of sparkles.
--   1.18  the shoe flies out of the box, big, over a splat in its rarity colour; its rarity word, its name and
--         "+N% Power" (NEW! / EQUIPPED! / BETTER!). Rarer means a bigger moment (SHOES2's ShoeFX.tier, the same ladder
--         as the worn and follower effects): a glow from Rare, rays from Epic, more sparkles for Legendary, a glow round
--         the screen's edge for Mythic, a rainbow (rays, splat, words, edge) and a halo for Secret, and a longer hold.
--   then  it holds, bobbing, and flies into the HUD's Shoes square as the HUD comes back.
-- A Buy 3 / Buy 8 (one ShoeOpened, Shoes = the N pairs): the same box, then the pairs fly out one by one into a row
-- (two rows of 4 for 8), each over its splat with its name and bonus; the best one leads the rarity effects.
-- A tap skips: during the box straight to the pop, after the reveal to the way out. A Common takes ~3 s.
-- (the same safe area as the HUD, under Roblox's top bar, so its words and pairs line up with the HUD's squares)
local momentGui, momentRoot, momentFit = Kit.screen('HoodUnboxing', nil, 9)
local Sound = require(RS.Shared.Config.Sound) -- (COMBAT: every game sound behind one switch, off for now)
local chime = Sound.new('rbxasset://sounds/electronicpingshort.wav', 0.6, momentGui)

local queue = {}
local function c01(t) return math.clamp(t, 0, 1) end
local function easeOut(t) return 1 - (1 - c01(t)) ^ 3 end
local function easeIn(t) return c01(t) ^ 2 end
local function backOut(t)
	t = c01(t)
	local c = 1.70158
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end
local function lerp(a, b, t) return a + (b - a) * t end
local NK = NumberSequenceKeypoint.new

-- The rarity tiers: SHOES2's ShoeFX.tier (the worn and follower effects' ladder) over these defaults.
local TIERS = {
	Common = { Rays = 0, Sparkles = 0, Glow = 0, Hold = 0 }, -- (and Glint from Rare, Trail from Legendary, Shake by rank)
	Rare = { Rays = 0, Sparkles = 3, Glow = 0.15, Hold = 0 },
	Epic = { Rays = 6, Sparkles = 8, Glow = 0.35, Hold = 0.3 },
	Legendary = { Rays = 10, Sparkles = 14, Glow = 0.55, Hold = 0.8 },
	Mythic = { Rays = 14, Sparkles = 20, Glow = 0.8, EdgeGlow = true, Hold = 1.2 },
	Secret = { Rays = 16, Sparkles = 24, Glow = 1, EdgeGlow = true, Rainbow = true, Halo = true, Hold = 1.8 },
}
local function tierOf(rarity)
	local tier = table.clone(TIERS[rarity.Id] or TIERS.Common)
	if ShoeFX and type(ShoeFX.tier) == 'function' then
		local ok, t = pcall(ShoeFX.tier, rarity.Id)
		if ok and type(t) == 'table' then
			for k, v in t do tier[k] = v end
		end
	end
	tier.Color = typeof(tier.Color) == 'Color3' and tier.Color or rarity.Color
	tier.Accent = typeof(tier.Accent) == 'Color3' and tier.Accent or tier.Color:Lerp(Color.white, 0.5)
	tier.Glint = tier.Glint == true or (tier.Glint == nil and rarity.Rank >= 2)
	tier.Trail = tier.Trail == true or (tier.Trail == nil and rarity.Rank >= 4)
	tier.Shake = math.clamp(tonumber(tier.Shake) or (rarity.Rank - 1) / 5, 0, 1)
	tier.Rank = rarity.Rank
	tier.Rainbow = tier.Rainbow == true or rarity.Rank == #Shoes.Rarities
	tier.Rays = math.clamp(tonumber(tier.Rays) or 0, 0, 16)
	tier.Sparkles = math.clamp(tonumber(tier.Sparkles) or 0, 0, 24)
	tier.Glow = math.clamp(tonumber(tier.Glow) or 0, 0, 1)
	tier.Hold = math.clamp(tonumber(tier.Hold) or 0, 0, 2.5)
	return tier
end
local function hue(t, i) return Color3.fromHSV((t * 0.35 + (i or 0) * 0.137) % 1, 0.62, 1) end

-- The pieces (design px on the moment's root; every one a plain frame, text or PNG).
local Fx = {}
function Fx.frame(props)
	props.BorderSizePixel = 0
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return Kit.new('Frame', props)
end
function Fx.disc(parent, size, color, transparency, z)
	local f = Fx.frame({ Name = 'Disc', BackgroundTransparency = transparency, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(size, size), ZIndex = z, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = f
	return f
end
-- A soft round light: three discs, the outer ones fainter. Fx.setLight(light, 0..1) sets its strength.
function Fx.light(parent, size, color, z)
	local holder = Fx.frame({ Name = 'Light', AnchorPoint = Vector2.new(0.5, 0.5), Size = px(size, size), ZIndex = z, Parent = parent })
	for _, k in { { 1, 0.86 }, { 0.7, 0.76 }, { 0.44, 0.64 } } do
		Fx.disc(holder, size * k[1], color, 1, z):SetAttribute('Base', k[2])
	end
	return holder
end
function Fx.setLight(light, a, color)
	for _, d in light:GetChildren() do
		local b = d:GetAttribute('Base')
		if b then
			d.BackgroundTransparency = 1 - (1 - b) * c01(a)
			if color then d.BackgroundColor3 = color end
		end
	end
end
-- Light rays round a centre: bars through it, bright in the middle and fading out to both tips (each bar is two rays).
function Fx.rays(parent, count, size, z)
	local holder = Fx.frame({ Name = 'Rays', AnchorPoint = Vector2.new(0.5, 0.5), Size = px(size, size), ZIndex = z, Parent = parent })
	local n = math.max(1, math.floor(count / 2))
	for i = 1, n do
		local bar = Fx.frame({ Name = 'Ray' .. i, BackgroundTransparency = 1, BackgroundColor3 = Color.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, math.floor(size * 0.085), 1, 0), Rotation = (i - 1) / n * 180, ZIndex = z, Parent = holder })
		Kit.new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NK(0, 1), NK(0.18, 0.7), NK(0.5, 0.05), NK(0.82, 0.7), NK(1, 1) }), Parent = bar })
	end
	return holder
end
-- A four-point sparkle: two crossed bars and a white core.
function Fx.sparkle(parent, size, color, z)
	local holder = Fx.frame({ Name = 'Sparkle', AnchorPoint = Vector2.new(0.5, 0.5), Size = px(size, size), ZIndex = z, Parent = parent })
	for _, rot in { 0, 90 } do
		local bar = Fx.frame({ Name = 'Arm', BackgroundTransparency = 0, BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.2), Rotation = rot, ZIndex = z, Parent = holder })
		Kit.corner(UDim.new(0.5, 0)).Parent = bar
	end
	Fx.disc(holder, size * 0.34, Color.white, 0, z + 1).Name = 'Core'
	return holder
end
function Fx.paint(holder, transparency, color)
	for _, d in holder:GetChildren() do
		if d:IsA('Frame') then
			d.BackgroundTransparency = transparency
			if color and d.Name == 'Arm' then d.BackgroundColor3 = color end
		end
	end
end
-- Glow along the screen's four edges (Mythic and up): bands fading inward.
function Fx.edges(parent, z)
	local list = {}
	-- (the bands reach OUT past the safe area by M design px: under Roblox's top bar and a phone's side insets too)
	local M = 90
	for _, e in { { Vector2.zero, UDim2.new(0, -M, 0, -M), UDim2.new(1, 2 * M, 0.24, M), 90 }, { Vector2.new(0, 1), UDim2.new(0, -M, 1, M), UDim2.new(1, 2 * M, 0.24, M), -90 },
		{ Vector2.zero, UDim2.new(0, -M, 0, -M), UDim2.new(0.14, M, 1, 2 * M), 0 }, { Vector2.new(1, 0), UDim2.new(1, M, 0, -M), UDim2.new(0.14, M, 1, 2 * M), 180 } } do
		local f = Fx.frame({ Name = 'Edge', BackgroundTransparency = 1, BackgroundColor3 = Color.white, AnchorPoint = e[1], Position = e[2], Size = e[3], ZIndex = z, Parent = parent })
		Kit.new('UIGradient', { Rotation = e[4], Transparency = NumberSequence.new({ NK(0, 0), NK(0.45, 0.6), NK(1, 1) }), Parent = f })
		table.insert(list, f)
	end
	return list
end
-- Text that fades: its fill and its stroke together.
function Fx.fade(label, transparency)
	label.TextTransparency = transparency
	local st = label:FindFirstChildOfClass('UIStroke')
	if st then st.Transparency = transparency end
end
function Fx.label(parent, props)
	props.Stroke = props.Stroke or Color.black
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	props.Parent = parent
	local t = Kit.text(props)
	Fx.fade(t, 1)
	return t
end
function Fx.rainbowText(label)
	local keys = {}
	for i, c in Shoes.Rainbow do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#Shoes.Rainbow - 1), c)) end
	return Kit.new('UIGradient', { Color = ColorSequence.new(keys), Parent = label })
end

-- The box: ART2's Box_<id> PNG, whole while it shakes, in two pieces when it pops (ART2's BoxLid_ / BoxBase_ PNGs, or two
-- copies of Box_ masked by gradients: the lid above IconModels.BoxLidLine, the body below), or the flat stand-in drawn in
-- two pieces.
-- Returns { Holder, Whole?, Lid, Body }.
function Fx.box(parent, boxId, size, z)
	local def = Shoes.BoxById[boxId]
	local color = def and def.Color or Color.white
	local holder = Fx.frame({ Name = 'Box', AnchorPoint = Vector2.new(0.5, 1), Size = px(size, size), ZIndex = z, Parent = parent })
	local out = { Holder = holder }
	local models = Kit.iconModels()
	-- (ART2: each box's lid line, IconModels.BoxLidLines[id], else the shared BoxLidLine)
	local lines = models and type(models.BoxLidLines) == 'table' and models.BoxLidLines or {}
	local line = tonumber(lines[boxId]) or (models and tonumber(models.BoxLidLine)) or 0.5
	out.Line = line
	local function flat()
		local white, ink = Color.white, Kit.FlatInk
		local function shade(f, c)
			Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c:Lerp(white, 0.3)), ColorSequenceKeypoint.new(0.6, c), ColorSequenceKeypoint.new(1, c:Lerp(Color3.new(0, 0, 0), 0.22)) }), Parent = f })
			Kit.stroke(ink, math.max(2, size * 0.028), true).Parent = f
		end
		local body = Fx.frame({ Name = 'FlatBody', BackgroundTransparency = 0, BackgroundColor3 = white, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.93), Size = UDim2.fromScale(0.8, 0.52), ZIndex = z + 1, Parent = holder })
		Kit.corner(UDim.new(0.08, 0)).Parent = body
		shade(body, color)
		local plate = Fx.frame({ Name = 'Plate', BackgroundTransparency = 0, BackgroundColor3 = white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.62, 0.36), ZIndex = z + 2, Parent = body })
		Kit.corner(UDim.new(0.18, 0)).Parent = plate
		Kit.stroke(ink, math.max(1.5, size * 0.016), true).Parent = plate
		local name = def and string.upper((def.Name:gsub(' Box$', ''))) or 'BOX'
		Kit.text({ Name = 'Name', Text = name, TextSize = Kit.fitSize(name, math.floor(size * 0.1), size * 0.44, 8), TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.15), ZIndex = z + 3, Parent = plate })
		local lid = Fx.frame({ Name = 'FlatLid', BackgroundTransparency = 0, BackgroundColor3 = white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.92, 0.2), ZIndex = z + 4, Parent = holder })
		Kit.corner(UDim.new(0.14, 0)).Parent = lid
		shade(lid, color:Lerp(white, 0.12))
		out.Whole, out.Lid, out.Body, out.Flat, out.Line = nil, lid, body, true, 0.42
	end
	local image = Kit.iconImage('Box_' .. tostring(boxId))
	if image == '' then
		flat()
		return out
	end
	local function picture(name, keep, zz, content, preview)
		local l = Kit.new('ImageLabel', { Name = name, BackgroundTransparency = 1, Image = content, ScaleType = Enum.ScaleType.Stretch, Size = UDim2.fromScale(1, 1), ZIndex = zz, Parent = holder })
		l:SetAttribute('PreviewImage', 'icon3d:' .. preview)
		if keep then
			local a, b = keep == 'top' and 0 or 1, keep == 'top' and 1 or 0
			Kit.new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new({ NK(0, a), NK(line - 0.004, a), NK(line + 0.004, b), NK(1, b) }), Parent = l })
		end
		-- (the pieces stay Visible, see-through until the pop: Kit.watchImage only judges an image that is on screen)
		if name ~= 'Whole' then l.ImageTransparency = 1 end
		return l
	end
	local id = 'Box_' .. tostring(boxId)
	-- the pieces: ART2's BoxLid_ / BoxBase_ PNGs (the box's own framing, laid over each other) when both are uploaded,
	-- else the Box_ PNG split at its lid line by two gradient masks
	local function split()
		for _, k in { 'Body', 'Lid' } do
			if out[k] then out[k]:Destroy() end
		end
		out.Body = picture('BodyPart', 'bottom', z + 1, image, id)
		out.Lid = picture('LidPart', 'top', z + 4, image, id)
	end
	out.Whole = picture('Whole', nil, z + 1, image, id)
	local lidImage, baseImage = Kit.iconImage('BoxLid_' .. tostring(boxId)), Kit.iconImage('BoxBase_' .. tostring(boxId))
	if lidImage ~= '' and baseImage ~= '' then
		out.Body = picture('BodyPart', nil, z + 1, baseImage, 'BoxBase_' .. tostring(boxId))
		out.Lid = picture('LidPart', nil, z + 4, lidImage, 'BoxLid_' .. tostring(boxId))
		for _, k in { 'Body', 'Lid' } do
			Kit.watchImage(out[k], function() if not out.Flat then split() end end)
		end
	else
		split()
	end
	-- (an upload that can't draw: the flat box instead, for the rest of this moment)
	Kit.watchImage(out.Whole, function()
		for _, k in { 'Whole', 'Body', 'Lid' } do
			if out[k] then out[k]:Destroy() end
		end
		flat()
	end)
	return out
end
-- How much of the box shows (0 = gone): its pictures or its flat frames.
function Fx.boxAlpha(box, a)
	for _, d in box.Holder:GetDescendants() do
		if d:IsA('ImageLabel') then
			d.ImageTransparency = 1 - a
		elseif d:IsA('Frame') and d.Name ~= 'Box' then
			d.BackgroundTransparency = 1 - a
			local st = d:FindFirstChildOfClass('UIStroke')
			if st then st.Transparency = 1 - a end
		elseif d:IsA('TextLabel') then
			d.TextTransparency = 1 - a
		end
	end
end

-- Where a pair flies at the end: the HUD's Shoes square (its centre on this screen, design px), else about there.
local function shoesSquare(W, H)
	local k = Kit.scaleFor(momentGui.AbsoluteSize)
	local ok, at = pcall(function()
		local square = player.PlayerGui.HoodHUD.Root.Actions.Shoes
		local p = square.AbsolutePosition + square.AbsoluteSize / 2 - momentRoot.AbsolutePosition
		return Vector2.new(p.X / k + 360, p.Y / k) -- (the column is still stepped aside 360 px; it slides back now)
	end)
	if ok and typeof(at) == 'Vector2' and at.X > 0 and at.X < W and at.Y > 0 and at.Y < H then return at end
	return Vector2.new(66, H * 0.6)
end

local drain -- (forward: the next moment in the queue)
local T = { Drop = 0.28, Land = 0.4, Shake = 1.02, Pop = 1.15, Fly = 0.45, Text = 1.3, Out = 0.35, Stagger = 0.14 }
local skipRequested = false
local function play(info)
	local shoe = Shoes.ById[info.Shoe]
	local boxDef = Shoes.BoxById[info.Box]
	if not shoe or not boxDef then return end
	local rarity = Shoes.RarityById[shoe.Rarity]
	-- (brief 22) a Buy 3 / Buy 8: the pairs fly out into a row
	local list = {}
	if type(info.Shoes) == 'table' and #info.Shoes > 1 then
		for _, e in info.Shoes do
			if type(e) == 'table' and Shoes.ById[e.Shoe] then table.insert(list, e) end
		end
	end
	local batch = #list > 1 and list or nil
	local tier = tierOf(rarity)
	unboxing = true
	local pg = player.PlayerGui
	pg:SetAttribute('Unboxing', true) -- (Goals, the toasts and the guide wait for it: until the moment has fully faded)
	pg:SetAttribute('UnboxingCalm', true) -- (the HUD steps aside: until the pairs fly back into it)
	pg:SetAttribute('HoodWindow', '') -- (a window open over it closes: the moment owns the screen)
	if shownBoard and shownBoard.Board then shownBoard.Board.Enabled = false end
	pg:SetAttribute('BoxBoard', false)
	Motion.blur('Unboxing', true, 18)

	local abs = momentGui.AbsoluteSize
	if abs.X < 2 or abs.Y < 2 then abs = Vector2.new(1280, 720) end
	momentFit(abs)
	local k = Kit.scaleFor(abs)
	local W, H = abs.X / k, abs.Y / k
	local s = math.clamp(H / 720, 0.74, 1.1) -- (text and art follow the screen's height: a phone's is ~554)
	local cx = W / 2
	local stage = Fx.frame({ Name = 'Unboxed', Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = momentRoot })

	-- the screen-wide pieces
	local edges = tier.EdgeGlow and Fx.edges(stage, 2) or {}
	local flash = Fx.frame({ Name = 'Flash', BackgroundTransparency = 1, BackgroundColor3 = Color.white, Position = UDim2.fromOffset(-90, -90), Size = UDim2.new(1, 180, 1, 180), ZIndex = 3, Parent = stage })

	-- the box, its light, the burst
	local B = math.floor(H * (batch and 0.32 or 0.38))
	local boxY = H * (batch and 0.6 or 0.5) + B / 2 -- (its bottom)
	local mouthY = boxY - B * 0.62
	local boxLight = Fx.light(stage, B * 1.9, Color.white, 5)
	boxLight.Position = px(cx, boxY - B * 0.5)
	local box = Fx.box(stage, info.Box, B, 6)
	box.Holder.Position = px(cx, boxY)
	mouthY = boxY - B * (1 - (box.Line or 0.42)) -- (where the lid comes off: the pairs fly out from there)
	local ring = Fx.disc(stage, B, Color.white, 1, 26)
	ring.BackgroundTransparency = 1
	local ringStroke = Kit.stroke(Color.white, 10, true, 1)
	ringStroke.Parent = ring
	local core = Fx.disc(stage, B, Color.white, 1, 25)
	local burst = {}
	for i = 1, 10 + math.floor(tier.Sparkles / 2) do
		local size = math.floor((18 + (i * 7) % 16) * s)
		local sp = Fx.sparkle(stage, size, i <= 10 and Color.white or tier.Color, 24)
		sp:SetAttribute('S', size)
		sp.Visible = false
		local a = (i / (10 + math.floor(tier.Sparkles / 2))) * math.pi * 2 + (i % 3) * 0.4
		table.insert(burst, { Node = sp, Dir = Vector2.new(math.cos(a), math.sin(a)), Dist = H * (0.22 + ((i * 37) % 10) / 30), Life = 0.55 + ((i * 13) % 7) / 20 })
	end

	-- the reveal: one pair (single) or the cards (batch)
	local revealDone, hold
	local focus = Vector2.new(cx, H * 0.42) -- (where the rays, the glow and the twinkles sit)
	local S = math.floor(math.min(H * 0.5, W * 0.32)) -- (a single pair: half the screen's height, its words still on screen)
	local cards = {}
	local word, sub, name, bonus, note, newTag
	local shoeNode, shoeScale, splat, glow, rays, halo
	local wordScale
	if not batch then
		splat = IK.splat(math.floor(S * 1.3), IK.SplatColor[rarity.Id] or rarity.Color, { Kind = tier.Rainbow and 'rainbow' or nil, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(focus.X, focus.Y + S * 0.04), ZIndex = 14 })
		splat.Parent = stage
		Kit.new('UIScale', { Name = 'Pop', Scale = 0.001, Parent = splat })
		-- (the pair is on screen from the start at scale 0: Kit.watchImage swaps a PNG that can't draw for its stand-in
		-- only while it is on screen)
		shoeNode = IK.shoeIcon(info.Shoe, S, { ZIndex = 16 })
		shoeNode.AnchorPoint = Vector2.new(0.5, 0.5)
		shoeNode.Position = px(focus.X, mouthY)
		shoeNode.Parent = stage
		shoeScale = Kit.new('UIScale', { Scale = 0.001, Parent = shoeNode }) -- (not 0: some renderers read 0 as unset)
		local top = H * 0.12
		word = Fx.label(stage, { Name = 'Rarity', Text = string.upper(rarity.Name) .. '!', TextSize = math.floor(78 * s), StrokeThickness = 7 * s, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, top), Size = px(W, 96 * s), ZIndex = 32 })
		-- (the lead, r1: the reveal is the biggest, clearest thing on screen: the name big in FredokaOne with a dark
		-- stroke, the bonus in the rarity's colour)
		local nameY = focus.Y + S * 0.52 + 4
		name = Fx.label(stage, { Name = 'Name', Text = shoe.Name, FontFace = Kit.Font.reveal, TextSize = Kit.fitSize(shoe.Name, math.floor(72 * s), W - 80, 24), StrokeThickness = 7 * s, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, nameY), Size = px(W, 76 * s), ZIndex = 32 })
		bonus = Fx.label(stage, { Name = 'Bonus', Text = ShoeRules.bonusText(shoe.Bonus) .. ' Power', FontFace = Kit.Font.reveal, TextSize = math.floor(48 * s), StrokeThickness = 5.5 * s, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, nameY + 70 * s), Size = px(W, 54 * s), ZIndex = 32 })
		if tier.Rainbow then Fx.rainbowText(bonus) else Kit.gradient(Color.white, rarity.Color, 0.35).Parent = bonus end
		local text
		if info.Equipped then
			text = 'EQUIPPED!'
		elseif info.Better then
			text = 'BETTER!' -- (a better pair than one you have on: the inventory's star puts it on)
		else
			text = 'You have x' .. tostring(info.Count or 1)
		end
		note = Fx.label(stage, { Name = 'Note', Text = text, TextSize = math.floor(28 * s), StrokeThickness = 3.5 * s, TextColor3 = (info.Equipped or info.Better) and Kit.hex('7CFF4F') or Color.white, AnchorPoint = Vector2.new(0.5, 0), Position = px(cx, nameY + 124 * s), Size = px(W, 34 * s), ZIndex = 32 })
		if info.New then
			newTag = Fx.label(stage, { Name = 'New', Text = 'NEW!', TextSize = math.floor(46 * s), StrokeThickness = 5 * s, TextColor3 = Kit.hex('7CFF4F'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(focus.X + S * 0.62, focus.Y - S * 0.3), Size = px(170 * s, 56 * s), Rotation = 12, ZIndex = 33 })
		end
		revealDone = T.Pop + 0.05 + T.Fly
		hold = 1.6 + tier.Hold -- (time to read it: a Common holds 1.6 s)
	else
		-- the cards: a row (two rows of up to 4 for more than 4), sized to the room between the words and the bottom
		local n = #batch
		local perRow = n <= 4 and n or math.ceil(n / 2)
		local rows = math.ceil(n / perRow)
		local cw = math.min((n <= 3 and 340 or 250) * s, (W - 160) / perRow - 26) -- (a Buy 3's pairs bigger, a Buy 8's in two rows)
		-- (a card's slot: the pair, then its name and bonus under it, all inside the screen)
		local roomTop, roomBottom = H * 0.2, H * 0.95
		cw = math.min(cw, ((roomBottom - roomTop) - (rows - 1) * 14) / rows / 1.28)
		local ch = cw * 1.28
		local gap = math.min(26, cw * 0.12)
		local gh = rows * ch + (rows - 1) * 14
		local y0 = roomTop + math.max(0, (roomBottom - roomTop - gh) / 2)
		local best = math.clamp(tonumber(info.Best) or 1, 1, n)
		for i, e in batch do
			local sh = Shoes.ById[e.Shoe]
			local r = Shoes.RarityById[sh.Rarity]
			local row, col = math.ceil(i / perRow) - 1, (i - 1) % perRow
			local inRow = row == rows - 1 and (n - row * perRow) or perRow
			local x = cx - (inRow * cw + (inRow - 1) * gap) / 2 + col * (cw + gap) + cw / 2
			local y = y0 + row * (ch + 14) + cw * 0.5
			local holder = Fx.frame({ Name = 'Card' .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = px(cw, cw), ZIndex = 14, Parent = stage })
			local cScale = Kit.new('UIScale', { Scale = 0.001, Parent = holder })
			local sp = IK.splat(math.floor(cw * 0.96), IK.SplatColor[r.Id] or r.Color, { Kind = r.Rank == #Shoes.Rarities and 'rainbow' or nil, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Rotation = (i * 47) % 50 - 25, ZIndex = 14 })
			sp.Parent = holder
			local ic = IK.shoeIcon(e.Shoe, math.floor(cw * 0.82), { ZIndex = 16 })
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.5)
			ic.Parent = holder
			holder.Position = px(cx, mouthY)
			local nm = Fx.label(stage, { Name = 'Name' .. i, Text = sh.Name, TextSize = Kit.fitSize(sh.Name, math.floor(cw * 0.15), cw + gap * 0.5 - 4, 15), StrokeThickness = math.max(2.5, cw * 0.016), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y + cw * 0.5 + cw * 0.06), Size = px(cw + 30, cw * 0.17), ZIndex = 32 })
			local bn = Fx.label(stage, { Name = 'Bonus' .. i, Text = ShoeRules.bonusText(sh.Bonus), TextSize = math.max(16, math.floor(cw * 0.13)), StrokeThickness = math.max(2.5, cw * 0.014), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y + cw * 0.5 + cw * 0.2), Size = px(cw + 30, cw * 0.15), ZIndex = 32 })
			if r.Rank == #Shoes.Rarities then Fx.rainbowText(bn) else Kit.gradient(Color.white, r.Color, 0.45).Parent = bn end
			local nw
			if e.New then
				nw = Fx.label(stage, { Name = 'New' .. i, Text = 'NEW!', TextSize = math.floor(cw * 0.15), StrokeThickness = math.max(2.5, cw * 0.017), TextColor3 = Kit.hex('7CFF4F'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x + cw * 0.34, y - cw * 0.38), Size = px(cw * 0.6, cw * 0.18), Rotation = 12, ZIndex = 33 })
			end
			table.insert(cards, { Node = holder, Scale = cScale, Splat = sp, At = Vector2.new(x, y), Name = nm, Bonus = bn, New = nw, Rank = r.Rank, Start = T.Pop + 0.07 + (i - 1) * T.Stagger })
			if i == best then focus = Vector2.new(x, y) end
		end
		word = Fx.label(stage, { Name = 'Rarity', Text = string.upper(rarity.Name) .. '!', TextSize = math.floor(66 * s), StrokeThickness = 6.5 * s, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, H * 0.085), Size = px(W, 80 * s), ZIndex = 32 })
		sub = Fx.label(stage, { Name = 'Count', Text = boxDef.Name .. '  x' .. n, TextSize = math.floor(30 * s), StrokeThickness = 3.5 * s, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, H * 0.085 + 48 * s), Size = px(W, 36 * s), ZIndex = 32 })
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFF27A'), Kit.hex('FFA81A')), Parent = sub })
		S = math.floor(cards[1].Node.Size.X.Offset)
		revealDone = T.Pop + 0.07 + (n - 1) * T.Stagger + T.Fly
		hold = 1.3 + 0.08 * n + tier.Hold * 0.6
	end
	wordScale = Kit.new('UIScale', { Scale = 0.3, Parent = word })
	if tier.Rainbow then
		Fx.rainbowText(word)
	else
		Kit.gradient(Color.white, rarity.Color, 0.5).Parent = word
	end
	-- the rarity look behind the pair (or the best card)
	glow = Fx.light(stage, S * 2.1, tier.Color, 12)
	glow.Position = px(focus.X, focus.Y)
	if tier.Rays > 0 then
		rays = Fx.rays(stage, tier.Rays, math.floor(math.max(S * 3.4, H * 1.05)), 4)
		rays.Position = px(focus.X, focus.Y)
	end
	if tier.Halo then
		halo = Fx.disc(stage, S * 1.32, Color.white, 1, 13)
		halo.Position = px(focus.X, focus.Y)
		Kit.stroke(Kit.hex('FFE24A'), math.max(4, S * 0.03), true, 0).Parent = halo
	end
	local twinkles = {}
	for i = 1, tier.Sparkles do
		local size = math.floor((16 + (i * 11) % 18) * s)
		local sp = Fx.sparkle(stage, size, tier.Accent, 24)
		sp:SetAttribute('S', size)
		sp.Visible = false
		local a = i * 2.39996 -- (the golden angle: spread round the pair)
		local d = S * (0.55 + ((i * 7) % 10) / 22)
		table.insert(twinkles, { Node = sp, At = Vector2.new(focus.X + math.cos(a) * d * 1.15, focus.Y + math.sin(a) * d * 0.85), Period = 0.8 + ((i * 3) % 7) / 10, Phase = ((i * 17) % 10) / 10 })
	end

	-- the glint (Rare and up): a quick white star on the pair once it lands; the trail (Legendary and up): a streak of
	-- light behind the pair (or the best card) as it flies out of the box
	local glint = tier.Glint and Fx.sparkle(stage, math.floor(S * 0.34), Color.white, 34) or nil
	if glint then glint.Visible = false end
	local trail = {}
	if tier.Trail then
		for i = 1, 5 do
			local d = Fx.disc(stage, S * (0.5 - i * 0.06), tier.Accent, 1, 13)
			d.Visible = false
			table.insert(trail, d)
		end
	end
	local tOut = revealDone + hold
	local tEnd = tOut + T.Out
	local skip = Kit.new('TextButton', { Name = 'Skip', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = stage })
	skipRequested = false
	skip.Activated:Connect(function() skipRequested = true end)
	local start = os.clock() -- (the moment's clock; a tap moves it on)
	local popped, leaving, finished = false, false, false
	local target -- (where the pairs fly at the end)
	local function frameAt(t: number)
		mouthY = boxY - B * (1 - (box.Line or 0.42)) -- (again: a box image that can't draw turns into the flat box)
		-- the box: drop, land, shake, squash, pop
		local x, y, sx, sy, rot = cx, boxY, 1, 1, 0
		if t < T.Drop then
			local u = easeIn(t / T.Drop)
			y = lerp(-B * 0.2, boxY, u)
			sx, sy = 0.9, 1.12
		elseif t < T.Land then
			local q = 1 - (t - T.Drop) / (T.Land - T.Drop)
			sx, sy = 1 + 0.2 * q * q, 1 - 0.24 * q * q
		elseif t < T.Shake then
			local u = (t - T.Land) / (T.Shake - T.Land)
			local p = u * 3 % 1
			local air, land = math.sin(p * math.pi), math.max(0, 1 - p / 0.22)
			y = boxY - air * B * (0.07 + 0.05 * u)
			sx, sy = 1 - 0.06 * air + 0.13 * land, 1 + 0.1 * air - 0.15 * land
			rot = math.sin(u * math.pi * 7) * (3 + 10 * u) * (0.8 + 0.5 * tier.Shake) -- (a rarer pair shakes its box harder)
		elseif t < T.Pop then
			local e = easeOut((t - T.Shake) / (T.Pop - T.Shake))
			sx, sy = 1 + 0.18 * e, 1 - 0.22 * e
			rot = math.sin(t * 90) * 2
		else
			local u = (t - T.Pop) / 0.16
			sx, sy = lerp(0.9, 1, easeOut(u)), lerp(1.16, 1, easeOut(u))
			local fallAt = batch and (revealDone - T.Fly + 0.2) or (T.Pop + 0.25)
			if t > fallAt then y = boxY + H * 0.75 * easeIn((t - fallAt) / 0.45) end
		end
		local bh = box.Holder
		bh.Position = px(x, y)
		bh.Size = px(B * sx, B * sy)
		bh.Rotation = rot
		Fx.setLight(boxLight, t < T.Pop and (0.2 + 0.8 * c01((t - T.Land) / (T.Pop - T.Land))) * 0.85 or (1 - c01((t - T.Pop) / 0.3)), Color.white)
		boxLight.Position = px(x, y - B * 0.5)
		local s2 = 0.7 + 0.5 * c01((t - T.Land) / (T.Pop - T.Land))
		boxLight.Size = px(B * 1.9 * s2, B * 1.9 * s2)
		-- the pop: the lid flies, the whole picture splits
		if t >= T.Pop then
			if box.Whole then box.Whole.Visible = false end
			local u = t - T.Pop
			if box.Lid then
				local dx, dy = W * 0.1 * u, -H * 1.3 * u + H * 1.9 * u * u
				box.Lid.Position = box.Flat and UDim2.new(0.5, dx, 0.42, dy) or UDim2.new(0, dx, 0, dy)
				box.Lid.Rotation = 280 * u
			end
			local fade = batch and c01((t - (revealDone - T.Fly + 0.2)) / 0.4) or c01((t - (T.Pop + 0.25)) / 0.4)
			Fx.boxAlpha(box, 1 - fade)
		end
		-- the flash: a white core and a ring opening out from the box's mouth, and the whole screen for Legendary+
		local f = (t - T.Pop) / 0.4
		if f >= 0 and f <= 1 then
			ring.Visible, core.Visible = true, true
			ring.Position, core.Position = px(cx, mouthY), px(cx, mouthY)
			local rs = lerp(B * 0.3, B * 2.6, easeOut(f))
			ring.Size = px(rs, rs)
			ringStroke.Transparency = lerp(0.1, 1, f)
			ringStroke.Thickness = lerp(14, 2, f) * s
			local cs = lerp(B * 0.5, B * 1.5, easeOut(f))
			core.Size = px(cs, cs)
			core.BackgroundTransparency = lerp(0.2, 1, c01(f * 1.8))
			flash.BackgroundTransparency = tier.Rank >= 4 and lerp(0.4, 1, c01(f * 1.2)) or 1
		else
			ring.Visible, core.Visible = false, false
			flash.BackgroundTransparency = 1
		end
		for _, b in burst do
			local age = t - T.Pop
			local u = age / b.Life
			b.Node.Visible = u >= 0 and u <= 1
			if b.Node.Visible then
				local d = b.Dist * easeOut(u)
				b.Node.Position = px(cx + b.Dir.X * d, mouthY + b.Dir.Y * d * 0.8 - 30 * u)
				local sz = b.Node:GetAttribute('S') * (0.4 + math.sin(u * math.pi))
				b.Node.Size = px(sz, sz)
				b.Node.Rotation = age * 200
			end
		end
		-- the reveal's look, in and out
		local inA = c01((t - (T.Pop + 0.05)) / 0.35)
		local outA = 1 - c01((t - tOut) / T.Out)
		local textA = 1 - c01((t - tOut) / 0.14) -- (the words go first, before the HUD's bottom bar slides back under them)
		local a = inA * outA
		Fx.setLight(glow, a * (0.12 + 0.6 * tier.Glow) * (0.9 + 0.1 * math.sin(t * 5)), tier.Rainbow and hue(t) or nil)
		if rays then
			rays.Rotation = (t * 24) % 360
			for i, bar in rays:GetChildren() do
				if bar:IsA('Frame') then
					bar.BackgroundTransparency = 1 - a * 0.9
					if tier.Rainbow then bar.BackgroundColor3 = hue(t, i) else bar.BackgroundColor3 = tier.Accent end
				end
			end
		end
		if halo then
			local hs = halo:FindFirstChildOfClass('UIStroke')
			hs.Transparency = 1 - a * (0.7 + 0.3 * math.sin(t * 4))
			halo.Rotation = t * 30
		end
		for i, e in edges do
			e.BackgroundTransparency = 1 - a * (0.38 + 0.14 * math.sin(t * 4 + i))
			e.BackgroundColor3 = tier.Rainbow and hue(t, i * 2) or tier.Color
		end
		for i, tw in twinkles do
			local live = t > revealDone - 0.2 and t < tEnd
			local u = ((t + tw.Phase * tw.Period) / tw.Period) % 1
			tw.Node.Visible = live and a > 0.05
			if tw.Node.Visible then
				local sz = tw.Node:GetAttribute('S')
				local sc = math.sin(u * math.pi) * a
				tw.Node.Size = px(sz * sc, sz * sc)
				tw.Node.Position = px(tw.At.X, tw.At.Y - 16 * u)
				tw.Node.Rotation = 45 * u
				if tier.Rainbow then Fx.paint(tw.Node, 0, hue(t, i)) end
			end
		end
		-- the glint and the trail
		if glint then
			local gu = (t - (revealDone + 0.05)) / 0.5
			glint.Visible = gu >= 0 and gu <= 1
			if glint.Visible then
				local gs = math.sin(gu * math.pi) * S * 0.34
				glint.Size = px(gs, gs)
				glint.Position = px(focus.X + S * 0.3, focus.Y - S * 0.22)
				glint.Rotation = 90 * gu
			end
		end
		if #trail > 0 then
			local start0 = batch and cards[math.clamp(tonumber(info.Best) or 1, 1, #cards)].Start or (T.Pop + 0.03)
			for i, d in trail do
				local u = (t - start0) / T.Fly - i * 0.07
				d.Visible = u > 0 and u < 1 and t < revealDone + 0.1
				if d.Visible then
					local e = easeOut(u)
					local from = Vector2.new(cx, mouthY)
					d.Position = px(lerp(from.X, focus.X, e), lerp(from.Y, focus.Y, e) - math.sin(u * math.pi) * H * (batch and 0.08 or 0.06))
					d.BackgroundTransparency = 0.35 + i * 0.12
				end
			end
		end
		-- the words
		local wu = (t - T.Text) / 0.35
		wordScale.Scale = lerp(0.3, 1, backOut(wu)) * (1 + 0.04 * math.sin(math.max(0, t - T.Text - 0.35) * 5))
		Fx.fade(word, 1 - c01(wu * 3) * textA)
		local g = word:FindFirstChildOfClass('UIGradient')
		if tier.Rainbow and g then g.Offset = Vector2.new((t * 0.4) % 1 - 0.5, 0) end
		if sub then Fx.fade(sub, 1 - c01((t - T.Text - 0.1) / 0.25) * textA) end
		if not target and t >= tOut then target = shoesSquare(W, H) end
		if not batch then
			-- the pair flies out of the box's mouth, spinning, and settles big in the middle
			local u = (t - (T.Pop + 0.03)) / T.Fly
			if u < 0 then shoeScale.Scale = 0.001 end
			if u >= 0 then
				local e = easeOut(u)
				local sy0 = lerp(mouthY, focus.Y, e) - math.sin(c01(u) * math.pi) * H * 0.06
				local bob = math.max(0, t - revealDone)
				local px0, py0 = focus.X, sy0 + math.sin(bob * 2.6) * 6 * c01(bob * 2)
				local sc = lerp(0.2, 1, backOut(u))
				local r = -220 * (1 - e) + math.sin(bob * 2) * 4 * c01(bob * 2)
				if target and t >= tOut then
					local o = easeIn((t - tOut) / T.Out)
					px0, py0 = lerp(px0, target.X, o), lerp(py0, target.Y, o)
					sc = lerp(sc, 0.22, o)
					r += 140 * o
				end
				shoeNode.Position = px(px0, py0)
				shoeScale.Scale = sc
				shoeNode.Rotation = r
				local pu = (t - (T.Pop + 0.15)) / 0.32
				splat.Pop.Scale = math.max(0.001, backOut(pu) * outA)
				splat.Rotation = (t * 10) % 360
			end
			local function line(label, at, dy)
				local u2 = (t - at) / 0.25
				Fx.fade(label, 1 - c01(u2) * textA)
				label:SetAttribute('Y', label:GetAttribute('Y') or label.Position.Y.Offset)
				label.Position = px(cx, label:GetAttribute('Y') + (dy or 18) * (1 - easeOut(u2)))
			end
			line(name, T.Text + 0.1)
			line(bonus, T.Text + 0.18)
			line(note, T.Text + 0.26)
			if newTag then
				local nu = (t - (T.Text + 0.3)) / 0.3
				Fx.fade(newTag, 1 - c01(nu * 3) * textA)
				newTag.Rotation = 12 + math.sin(t * 6) * 6
				newTag.Size = px(170 * s * lerp(0.4, 1, backOut(nu)), 56 * s * lerp(0.4, 1, backOut(nu)))
			end
		else
			for i, c in cards do
				local u = (t - c.Start) / T.Fly
				if u < 0 then c.Scale.Scale = 0.001 end
				if u >= 0 then
					local e = easeOut(u)
					local px0 = lerp(cx, c.At.X, e)
					local py0 = lerp(mouthY, c.At.Y, e) - math.sin(c01(u) * math.pi) * H * 0.08
					local sc = lerp(0.15, 1, backOut(u))
					local r = -180 * (1 - e)
					if target and t >= tOut then
						local o = easeIn((t - tOut - (i - 1) * 0.02) / T.Out)
						px0, py0 = lerp(px0, target.X, o), lerp(py0, target.Y, o)
						sc = lerp(sc, 0.2, o)
					end
					c.Node.Position = px(px0, py0)
					c.Scale.Scale = sc
					c.Node.Rotation = r
					local lu = c01((u - 0.85) / 0.3) * textA
					Fx.fade(c.Name, 1 - lu)
					Fx.fade(c.Bonus, 1 - lu)
					if c.New then
						Fx.fade(c.New, 1 - lu)
						c.New.Rotation = 12 + math.sin(t * 6 + i) * 6
					end
				end
			end
		end
	end
	local function finish()
		if finished then return end
		finished = true
		RunService:UnbindFromRenderStep('HoodUnboxing')
		stage:Destroy()
		unboxing = false
		if #queue == 0 then
			Motion.blur('Unboxing', false)
			pg:SetAttribute('UnboxingCalm', false)
			-- (CRITIC4 r1: one message at a time: GOAL DONE, the toasts and the guide's callouts wait a beat after the
			-- moment's last fade)
			task.delay(0.3, function()
				if not unboxing and #queue == 0 then pg:SetAttribute('Unboxing', false) end
			end)
		end
		task.defer(drain)
	end
	RunService:BindToRenderStep('HoodUnboxing', Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		if skipRequested then
			skipRequested = false
			-- a tap moves the moment on a beat: the shake to the pop, the flight to the landed pair, the hold to the way out
			local to = (t < T.Shake and T.Shake) or (t < revealDone - 0.1 and revealDone) or (t < tOut and tOut) or t
			start -= to - t
			t = to
		end
		stage:SetAttribute('T', t) -- (where the moment is: the offline harness shoots it at set moments)
		if not popped and t >= T.Pop then
			popped = true
			Sound.play(chime, 0.9 + rarity.Rank * 0.12)
		end
		if not leaving and t >= tOut then
			leaving = true
			-- the HUD comes back as the pairs fly into its Shoes square
			if #queue == 0 then
				Motion.blur('Unboxing', false)
				pg:SetAttribute('UnboxingCalm', false)
			end
		end
		frameAt(math.min(t, tEnd))
		if t >= tEnd then finish() end
	end)
	frameAt(0)
	-- (a safety net: the moment always ends, even if the render step stops being called)
	task.delay(tEnd + 2, finish)
	return tEnd
end
function drain()
	if unboxing then return end
	local info = table.remove(queue, 1)
	if not info then return end
	local ok, length = pcall(play, info)
	if not ok then
		warn('[Shoes] unboxing: ' .. tostring(length))
		unboxing = false
		player.PlayerGui:SetAttribute('Unboxing', false)
		player.PlayerGui:SetAttribute('UnboxingCalm', false)
		return drain()
	end
	task.delay((length or 0) + 0.3, drain) -- (finish starts the next one sooner; this is the safety net)
end
Net.get('ShoeOpened').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or not Shoes.ById[info.Shoe] then return end
	-- Better than a pair you have on (and it didn't go straight on): the banner says how to wear it.
	if not info.Equipped then
		local rack = myRack()
		local worst = math.huge
		for _, id in rack.Equipped do worst = math.min(worst, Shoes.bonus(id)) end
		info.Better = #rack.Equipped >= ShoeRules.MaxEquipped and Shoes.bonus(info.Shoe) > worst
	end
	table.insert(queue, info)
	drain()
end)

---------------------------------------------------------------------------------------------- screen
-- (brief 22) The inventory window and the HUD's Shoes square moved to Inventory.client and HUD.client: only the unboxing
-- moment's screen is left here.
local function relayout()
	local abs = momentGui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	momentFit(abs)
end
momentGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
momentGui.Parent = player:WaitForChild('PlayerGui')
relayout()
