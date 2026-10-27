-- The quick tutorial on your screen (brief 30, TUTORIAL; the rules and every measured number are Shared/TutorialRules; the
-- world steps come from HoodServer/OnboardingService's player attribute OnboardingStep). No cutscene, no intro, nothing
-- blocks input: everything here lets clicks and touches through.
--   * The WORLD steps (BAY 1, Stage 1's gate, the fight, the yellow pad, the welcome gift): the hint at the bottom centre
--     and the user's straight white arrows on the floor, every one pointing exactly at the target's centre, laid on the
--     straight line from you to it and fixed to the target, so they lie still while you walk over them and swing
--     smoothly when you step aside. One straight leg at a time: when a lane, a wall or a stand blocks the straight line,
--     the first leg goes to the lobby's spawn (the hub), and the hall's doorway is a leg on the way to the gate. No box
--     and no dim here: the reference's box only ever frames UI. Once the server moves past the gift (Gun, Run, Done)
--     the arrows are destroyed for good.
--   * The ONE boxed lesson, the reference's craft: the first rebirth. When the Rebirth bar first fills, a dark mask with a
--     hole dims the world and the rest of the HUD; a white rounded box locks on to the HUD's Rebirth button ("Open
--     REBIRTH!"), then to the window's Rebirth button ("Click REBIRTH!"; the hint docks just over it there, so the
--     window's "Rebirth resets your power" stays readable), then "Now go train again!" stays a moment and it is over. The box takes its place and size from the button's AbsolutePosition and AbsoluteSize every frame, in
--     the same GUI inset as the button's ScreenGui, with the hover/press pops and a window's opening spring taken out
--     (TutorialRules.restRect), so it never drifts, breathes or jumps; it waits (no box at all) until the button is on
--     screen and still, and follows a resize or a turn of the phone by locking on again.
--   * The HINT: a dark rounded box, bold white words with the key word yellow, the whole line at once (a short fade and grow).
-- It stays out of the way of everything else that owns the screen: the loading cover, a window (but the lesson's own),
-- the unboxing, the rank-up screen, the returning player's cards and offers; the lesson waits until you are in the lobby.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local UserInputService = game:GetService('UserInputService')
local Kit = require(RS.Shared.UIKit)
local Rules = require(RS.Shared.TutorialRules)
local ActiveMap = require(RS.Shared.ActiveMap)
local okSkins, Skins = pcall(require, RS.Shared.Config.Skins)
if not okSkins then Skins = nil end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local hex, BLACK, WHITE = Kit.hex, Kit.Color.black, Kit.Color.white
local px = UDim2.fromOffset
local V2 = Vector2.new
local B, H, A = Rules.Box, Rules.Hint, Rules.Arrows
local function attr(name) return player:GetAttribute(name) end
local function num(v) return type(v) == 'number' and v == v and v or 0 end
local function try(fn, ...) local ok, v = pcall(fn, ...); if ok then return v end return nil end

---------------------------------------------------------------------------------------------- the hint (bottom centre)
-- Its own full-screen ScreenGui, so its centre sits at 63.2 % of the whole screen's height whatever the top bar is.
local hintGui, hintRoot, hintFit = Kit.screen('HoodTutorialHint', nil, 10)
hintGui.IgnoreGuiInset = true
pcall(function() hintGui.ScreenInsets = Enum.ScreenInsets.None end)
local hint = Kit.new('Frame', { Name = 'Hint', AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, H.Y), Size = px(H.W, H.H), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false, Parent = hintRoot })
local face = Kit.new('Frame', { Name = 'Face', Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex(H.Fill), BackgroundTransparency = H.FillT, BorderSizePixel = 0, Active = false, ZIndex = 2, Parent = hint })
Kit.corner(H.Corner).Parent = face
local faceEdge = Kit.stroke(hex('737480'), H.Edge, true)
faceEdge.Parent = face
-- (the black ring just outside the light edge: a frame the edge's size with its own 1 px stroke)
local ring = Kit.new('Frame', { Name = 'Ring', AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 2 * H.Edge, 1, 2 * H.Edge), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 1, Parent = hint })
Kit.corner(H.Corner + H.Edge).Parent = ring
local ringEdge = Kit.stroke(BLACK, 1, true)
ringEdge.Parent = ring
local hintText = Kit.text({ Name = 'Text', Text = '', TextSize = H.TextSize, Stroke = BLACK, StrokeThickness = math.max(2, H.TextSize * 0.1), RichText = true, Position = px(0, -1), Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = face })
local hintStroke = hintText:FindFirstChildOfClass('UIStroke')
local hintPop = Kit.new('UIScale', { Name = 'HintPop', Scale = 1, Parent = face }) -- (a new line's short grow, H.Pop)

---------------------------------------------------------------------------------------------- the box and the dim
-- Unscaled pixels in a ScreenGui that takes the inset settings of the boxed button's ScreenGui, so a rect read from the
-- button's AbsolutePosition lands on the button exactly (TutorialRules.toOverlay keeps the conversion honest if they
-- ever differ). The mask reaches far past the edges, under the top bar and any notch.
local focusGui = Instance.new('ScreenGui')
focusGui.Name = 'HoodTutorial'
focusGui.ResetOnSpawn = false
focusGui.DisplayOrder = 9 -- over the HUD (5) and the windows (8), under the hint (10)
focusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
focusGui.IgnoreGuiInset = false
pcall(function() focusGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
pcall(function() focusGui.ClipToDeviceSafeArea = false end)
local layer = Kit.new('Frame', { Name = 'Focus', BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Size = UDim2.fromScale(1, 1), Visible = false, Parent = focusGui })
local function dimFrame(name, z)
	local f = Kit.new('Frame', { Name = name, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = z or 1, Parent = layer })
	pcall(function() f.Interactable = false end)
	return f
end
local maskRects = { dimFrame('MaskTop'), dimFrame('MaskBottom'), dimFrame('MaskLeft'), dimFrame('MaskRight') }
local MAX_ROWS = 40
local cornerRows = {} -- [corner 1..4] = { frames }
for c = 1, 4 do
	cornerRows[c] = {}
	for i = 1, MAX_ROWS do
		local f = dimFrame('Corner' .. c .. '_' .. i)
		f.Visible = false
		cornerRows[c][i] = f
	end
end
local box = Kit.new('Frame', { Name = 'WhiteBox', BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 3, Parent = layer })
local boxCorner = Kit.corner(10)
boxCorner.Parent = box
local boxLine = Kit.stroke(WHITE, 3, true)
boxLine.LineJoinMode = Enum.LineJoinMode.Round
boxLine.Parent = box
-- the new-thing badge (the reference's cyan "1" on the button that opens the window)
local badge = Kit.new('Frame', { Name = 'Badge', AnchorPoint = V2(0.5, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = false, Visible = false, ZIndex = 4, Parent = layer })
Kit.corner(UDim.new(0.5, 0)).Parent = badge
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('8DFFF6'), hex('3ED6CB')), Parent = badge })
local badgeEdge = Kit.stroke(hex('06231F'), 1.5, true)
badgeEdge.Parent = badge
local badgeText = Kit.text({ Name = 'N', Text = '1', TextSize = 14, Stroke = hex('06231F'), StrokeThickness = 1.5, Size = UDim2.fromScale(1, 1), Position = px(0, -0.5), ZIndex = 5, Parent = badge })
local badgeStroke = badgeText:FindFirstChildOfClass('UIStroke')

---------------------------------------------------------------------------------------------- the white arrows (world)
local world -- the HoodTutorialLocal folder, made when the first arrow is needed, destroyed when the tutorial is over
local arrows = {}
local over = false -- (the world tutorial is over for good: no arrows ever again)
local function part(parent, class, name, size, color, material)
	local p = Instance.new(class)
	p.Name = name
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	pcall(function() p.CanQuery, p.CanTouch = false, false end)
	p.Size, p.Color, p.Material = size, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.Parent = parent
	return p
end
local T = 0.05 -- (studs: the arrow's thickness)
local E = 0.12 -- (studs: the dark rim around it)
local SHAFT_LEN = A.Length - A.HeadLength
local function makeArrow(i)
	local m = Instance.new('Model')
	m.Name = 'GroundArrow' .. i
	local white, ink = Color3.new(1, 1, 1), Color3.fromRGB(20, 22, 30)
	local half = A.HeadWidth / 2
	local rimHalf, rimLen = half + 1.5 * E, A.HeadLength + 2.56 * E
	local a = {
		Model = m,
		Shaft = part(m, 'Part', 'Shaft', Vector3.new(A.ShaftWidth, T, SHAFT_LEN + 0.06), white, Enum.Material.Neon),
		HeadR = part(m, 'WedgePart', 'HeadR', Vector3.new(T, half, A.HeadLength), white, Enum.Material.Neon),
		HeadL = part(m, 'WedgePart', 'HeadL', Vector3.new(T, half, A.HeadLength), white, Enum.Material.Neon),
		RimShaft = part(m, 'Part', 'RimShaft', Vector3.new(A.ShaftWidth + 2 * E, T, SHAFT_LEN + 2 * E), ink, Enum.Material.SmoothPlastic),
		RimR = part(m, 'WedgePart', 'RimR', Vector3.new(T, rimHalf, rimLen), ink, Enum.Material.SmoothPlastic),
		RimL = part(m, 'WedgePart', 'RimL', Vector3.new(T, rimHalf, rimLen), ink, Enum.Material.SmoothPlastic),
		Alpha = -1,
	}
	m.Parent = world
	return a
end
-- Lays arrow `a` flat at `at` (its centre, on the floor at height y), pointing along `fwd` (unit, flat).
local UP = Vector3.new(0, 1, 0)
local function layArrow(a, at, fwd, y)
	local right = fwd:Cross(UP).Unit
	local c = Vector3.new(at.X, y + T / 2 + 0.03, at.Z)
	local tip = c + fwd * (A.Length / 2)
	local half = A.HeadWidth / 2
	local headMid = tip - fwd * (A.HeadLength / 2)
	local shaftMid = tip - fwd * (A.HeadLength + SHAFT_LEN / 2) + fwd * 0.03
	a.Shaft.CFrame = CFrame.fromMatrix(shaftMid, right, UP, -fwd)
	a.HeadR.CFrame = CFrame.fromMatrix(headMid + right * (half / 2), -UP, right, -fwd)
	a.HeadL.CFrame = CFrame.fromMatrix(headMid - right * (half / 2), UP, -right, -fwd)
	-- the rim: the same shapes grown by E, a hair lower
	local low = Vector3.new(0, -0.025, 0)
	local rimHalf, rimLen = half + 1.5 * E, A.HeadLength + 2.56 * E
	local rimTip = tip + fwd * (1.56 * E)
	local rimMid = rimTip - fwd * (rimLen / 2)
	a.RimShaft.CFrame = CFrame.fromMatrix(shaftMid - fwd * 0.03 + low, right, UP, -fwd)
	a.RimR.CFrame = CFrame.fromMatrix(rimMid + right * (rimHalf / 2) + low, -UP, right, -fwd)
	a.RimL.CFrame = CFrame.fromMatrix(rimMid - right * (rimHalf / 2) + low, UP, -right, -fwd)
end
local function fadeArrow(a, alpha)
	alpha = math.floor(alpha * 20 + 0.5) / 20 -- (steps of 5 %: no property churn every frame)
	if a.Alpha == alpha then return end
	a.Alpha = alpha
	local w, k = 1 - alpha, 1 - alpha * 0.55
	a.Shaft.Transparency, a.HeadR.Transparency, a.HeadL.Transparency = w, w, w
	a.RimShaft.Transparency, a.RimR.Transparency, a.RimL.Transparency = k, k, k
end
local function hideArrows(from)
	for i = from or 1, #arrows do fadeArrow(arrows[i], 0) end
end
local function newParams()
	return try(function()
		local r = RaycastParams.new()
		r.FilterType = Enum.RaycastFilterType.Exclude
		pcall(function() r.RespectCanCollide = true end) -- (only what you would bump into or stand on)
		return r
	end)
end
local rayParams = newParams()
local sightParams = newParams()
-- The floor under a point near your feet' height (ignores tops of things more than a step above or below).
local function floorAt(p, feetY)
	if not rayParams then return feetY end
	local hit = try(function() return workspace:Raycast(Vector3.new(p.X, feetY + 3, p.Z), Vector3.new(0, -8, 0), rayParams) end)
	if hit and math.abs(hit.Position.Y - feetY) <= 2.5 then return hit.Position.Y end
	return feetY
end

---------------------------------------------------------------------------------------------- targets (named, never coordinates)
local active = ActiveMap.get()
local function map() active = active or ActiveMap.get(); return active end
local function tagged(tag)
	local list = try(function() return CollectionService:GetTagged(tag) end) or {}
	local out = {}
	local m = map()
	for _, x in list do
		if not m or x:IsDescendantOf(m.Root) then table.insert(out, x) end
	end
	return out
end
-- A level designer may name any part as a step's target: tag it HoodTutorialTarget with the attribute Target = 'Lane' |
-- 'Gate' | 'Pad' | 'Gift'; it wins over the defaults below. Each part is found once by tag or name and kept while it is in
-- the game (only its live position is read each frame); one not found yet is looked for again every `retry` seconds.
local looked = {} -- [key] = { Value, At }
local function lookup(key, find, retry)
	local c = looked[key]
	local v = c and c.Value
	if v and v.Parent ~= nil then return v end
	local now = os.clock()
	if c and v == false and now - c.At < (retry or 2) then return nil end
	v = find()
	looked[key] = { Value = v or false, At = now }
	return v
end
-- (no part tagged yet: nothing to look for until one is added, so the tag is never scanned for again while there is none)
local anyOverride = nil
local overrideWatch = try(function()
	return CollectionService:GetInstanceAddedSignal('HoodTutorialTarget'):Connect(function()
		anyOverride = true
		for key in looked do
			if key:sub(1, 8) == 'Override' then looked[key] = nil end
		end
	end)
end)
local function override(kind)
	if anyOverride == nil then anyOverride = not overrideWatch or #tagged('HoodTutorialTarget') > 0 end
	if not anyOverride then return nil end
	return lookup('Override' .. kind, function()
		for _, p in tagged('HoodTutorialTarget') do
			if p:IsA('BasePart') and p:GetAttribute('Target') == kind then return p end
		end
		return nil
	end, 5)
end
local function gateOne()
	return lookup('Gate1', function()
		for _, g in tagged('HoodStageGate') do
			if g:GetAttribute('Stage') == 1 then return g end
		end
		return nil
	end)
end
local function centreTop(p) return (p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)).Position end
local BAY1 = 'Starter' -- (the first free lane in Config/Skins: BAY 1)
if Skins and type(Skins.Stations) == 'table' then
	for _, s in Skins.Stations do
		if (s.Rebirths or 0) == 0 and not s.Pass and not s.RobuxPrice then BAY1 = s.Id break end
	end
end
local Target = {}
function Target.Lane()
	local p = override('Lane') or lookup('Lane', function()
		local m = map()
		local lane = m and m.Root:FindFirstChild('Training_' .. BAY1, true)
		return lane and lane:FindFirstChild('TrainingZone', true)
	end)
	return p and centreTop(p) or nil
end
function Target.Gate(you)
	local over_ = override('Gate')
	if over_ then return centreTop(over_) end
	local gate = gateOne()
	if not gate then return nil end
	local m = map()
	local frameCF = m and m.Frame or CFrame.new()
	local barrier = lookup('Barrier', function() return gate:FindFirstChild('Barrier', true) end)
	local at = frameCF:PointToObjectSpace(barrier and barrier.CFrame.Position or gate:GetPivot().Position)
	local floor = barrier and at.Y - barrier.Size.Y / 2 or at.Y
	local lineZ = gate:GetAttribute('LineZ')
	local gz = type(lineZ) == 'number' and lineZ or at.Z
	local youMap = frameCF:PointToObjectSpace(you)
	local aim = Rules.gateAim(youMap, at.X, gz, gate:GetAttribute('DoorZ'), gate:GetAttribute('DoorHalf'))
	return frameCF:PointToWorldSpace(Vector3.new(aim.X, floor, aim.Z))
end
function Target.Pad()
	local p = override('Pad')
	if p then return centreTop(p) end
	local stage = math.max(1, num(attr('RunCleared')))
	p = lookup('Pad' .. stage, function()
		for _, x in tagged('HoodStagePad') do
			if x:IsA('BasePart') and x:GetAttribute('Kind') == 'Return' and x:GetAttribute('Stage') == stage then return x end
		end
		return nil
	end)
	return p and centreTop(p) or nil
end
function Target.Gift()
	local p = override('Gift')
	if p then return centreTop(p) end
	local at = attr('OnboardingGiftAt')
	return typeof(at) == 'Vector3' and at or nil
end

-- The lobby's hub: its spawn (the map's LobbySpawn, else the SpawnLocation), the point every walk across the plaza
-- passes, used as the waypoint when the straight line to the target is blocked (from inside a lane, say).
local hubCache
local function hub()
	if hubCache ~= nil then return hubCache or nil end
	local m = map()
	if not m then return nil end
	local at = m.Root:GetAttribute('LobbySpawn')
	if typeof(at) == 'Vector3' then
		hubCache = m.Frame * at
	else
		hubCache = false
		for _, d in m.Root:GetDescendants() do
			if d:IsA('SpawnLocation') then hubCache = centreTop(d) break end
		end
	end
	return hubCache or nil
end
-- Can you walk there in a straight line? Three rays at knee height (the line and one a little to each side), the floor's
-- lips and steps under them: clear when at least two meet nothing solid before the end, so a lamp post on the line is a
-- step round, a lane's bench or a wall is in the way. (No rays here: yes.)
local function clearTo(from, to)
	if not sightParams then return true end
	local a = Vector3.new(from.X, from.Y, from.Z)
	local b = Vector3.new(to.X, a.Y, to.Z)
	local d = b - a
	if d.Magnitude < 1 then return true end
	local side = Vector3.new(-d.Z, 0, d.X).Unit * 1.2
	local open = 0
	for _, o in { Vector3.zero, side, -side } do
		local hit = try(function() return workspace:Raycast(a + o, d, sightParams) end)
		if hit == nil or (hit.Position - (b + o)).Magnitude <= 1.5 then open += 1 end
	end
	return open >= 2
end
-- The lobby side of Stage 1's gate (where the hub helps)?
local function inLobby(pos)
	local m = map()
	if not m then return false end
	local z = m.Frame:PointToObjectSpace(pos).Z
	local g = gateOne()
	local line = g and g:GetAttribute('LineZ')
	return type(line) == 'number' and z > line + 1 or false
end

---------------------------------------------------------------------------------------------- what owns the screen
local function window()
	local w = playerGui:GetAttribute('HoodWindow')
	return type(w) == 'string' and w or ''
end
local function visibleChild(gui, names)
	if not gui then return false end
	for _, d in gui:GetDescendants() do
		if d:IsA('GuiObject') and names[d.Name] and d.Visible then return true end
	end
	return false
end
local startedAt, WELCOME_WAIT = os.clock(), 20
local function popupUp() -- the loading cover, the rank-up screen, a returning player's card or offer chip, an artboard dialog
	if playerGui:FindFirstChild('HoodLoading') then return true end
	if playerGui:GetAttribute('HoodWelcome') == true then return true end -- (Oct 27, flow: the first-join welcome goes first)
	if playerGui:FindFirstChild('HoodGunReveal') then return true end -- (and the new gun's moment: one voice at a time)
	-- (and before it starts: a first join waits for the welcome to have played, the server's word on it for a moment;
	-- WELCOME_WAIT seconds at most, so a welcome that never comes can't hold the tutorial)
	if os.clock() - startedAt < WELCOME_WAIT then
		local first = player:GetAttribute('FirstJoin')
		if first == nil and os.clock() - startedAt < 4 then return true end
		if first == true and playerGui:GetAttribute('HoodWelcome') ~= false then return true end
	end
	local art = playerGui:FindFirstChild('HoodArt') -- (ArtWindows' dialogs: a review, a confirmation, the reveal card, Inventory Full)
	local artRoot = art and art.Enabled ~= false and art:FindFirstChild('ArtRoot')
	local dialogs = artRoot and artRoot:FindFirstChild('Dialog')
	if dialogs and #dialogs:GetChildren() > 0 then return true end
	local card = playerGui:GetAttribute('HoodCard')
	if card == true or (type(card) == 'string' and card ~= '') then return true end
	local prog = playerGui:FindFirstChild('HoodProgress')
	if prog and prog:FindFirstChild('RankUp', true) then return true end
	local ret = playerGui:FindFirstChild('HoodRetention')
	if ret and ret.Enabled ~= false and visibleChild(ret, { Card = true, Offer = true }) then return true end
	return false
end
local function unboxing() return playerGui:GetAttribute('Unboxing') == true end
local function touchOnly()
	local v = try(function() return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled end)
	return v == true
end
local function inLane()
	local s = attr('TrainingStation')
	return type(s) == 'string' and s ~= '' and not s:find('Locked:')
end

---------------------------------------------------------------------------------------------- the boxed buttons
-- Found by name every time (the HUD may move or rebuild them): HoodHUD's Rebirth action button; the Rebirth window's
-- (HoodPanels) Rebirth button, named Action.
local function holderWithHit(root_, name)
	if not root_ then return nil end
	for _, d in root_:GetDescendants() do
		if d.Name == name and d:IsA('GuiObject') and d:FindFirstChild('Hit') then return d end
	end
	return nil
end
local Boxed = {}
function Boxed.Hud()
	local hud = playerGui:FindFirstChild('HoodHUD')
	local column = hud and hud:FindFirstChild('Actions', true)
	return (column and column:FindFirstChild('Rebirth')) or holderWithHit(hud, 'Rebirth')
end
-- (Oct 27, flow) HoodHUD's Power count (bottom centre: the icon and the number), boxed without the dim while BAY 1's
-- Power line says what it is for
function Boxed.Power()
	local hud = playerGui:FindFirstChild('HoodHUD')
	local status = hud and hud:FindFirstChild('Status', true)
	return status and status:FindFirstChild('Power')
end
function Boxed.Window()
	local panels = playerGui:FindFirstChild('HoodPanels')
	local overlay = panels and panels:FindFirstChild('RebirthOverlay', true)
	return holderWithHit(overlay, 'Action')
end
local function screenGuiOf(g)
	local x = g
	while x and not x:IsA('LayerCollector') do x = x.Parent end
	return x
end
-- Shown: visible all the way up, its ScreenGui on, a real size.
local function shown(g)
	local sg = screenGuiOf(g)
	if not sg or sg.Enabled == false or not sg:IsDescendantOf(playerGui) then return false end
	local x = g
	while x and x ~= sg do
		if x:IsA('GuiObject') and not x.Visible then return false end
		x = x.Parent
	end
	local s = g.AbsoluteSize
	return s.X >= 4 and s.Y >= 4
end
-- The pixel the ScreenGui measures from (Vector2.zero when it ignores the GUI inset).
local function insetOf(sg)
	if not sg or sg.IgnoreGuiInset then return Vector2.zero end
	local none = try(function() return sg.ScreenInsets == Enum.ScreenInsets.None end)
	if none then return Vector2.zero end
	local tl = try(function() local a = game:GetService('GuiService'):GetGuiInset(); return a end)
	return typeof(tl) == 'Vector2' and tl or Vector2.zero
end
-- The rect of one GuiObject at rest (see TutorialRules.restRect): its own pops and its windows' springs taken out. Also
-- whether everything around it has come to rest: no window spring or stagger still running above it (every MotionScale
-- over it at 1) and the button itself at rest or under the mouse (1 or the hover's 1.05). A window's parts rise into
-- place one after another (HudWindows' stagger: each sits 10 px low at 0.94 until its turn), so the box waits for that.
local function restOf(g, sg)
	local nodes = {}
	local x = g
	while x and x ~= sg do
		if x:IsA('GuiObject') then table.insert(nodes, 1, x) end
		x = x.Parent
	end
	local chain = {}
	local settled = true
	for i, n in nodes do
		local ms = n:FindFirstChild('MotionScale')
		local s = (ms and ms:IsA('UIScale')) and ms.Scale or 1
		if i < #nodes then
			if math.abs(s - 1) > 0.002 then settled = false end
		elseif math.abs(s - 1) > 0.002 and math.abs(s - 1.05) > 0.002 then
			settled = false
		end
		table.insert(chain, { Pos = n.AbsolutePosition, Size = n.AbsoluteSize, Anchor = n.AnchorPoint, Scale = s })
	end
	local p, sz = Rules.restRect(chain)
	return p, sz, settled
end
-- What the box frames: the pixels the target DRAWS, at rest (see drawnRect: its fill and strokes, its picture, its
-- words, the status pill hanging off it, the Rebirth button's "57%"), never its hit area or an empty padding frame. Also
-- its neighbours (the other buttons beside, above and below it), so the line stays in the gutter between them, its own
-- outline (the badge sits on its corner) and the stickers' rects (the badge keeps off them). All in the overlay's pixels.
local STICKERS = { Percent = true, Badge = true, Count = true }
local function shownWithin(d, top)
	local x = d
	while x and x ~= top do
		if x:IsA('GuiObject') and not x.Visible then return false end
		x = x.Parent
	end
	return true
end
-- The UIScales over a GuiObject (its own and its ancestors' up to its ScreenGui, the screen's fit included), the motion
-- pops left out (restOf takes them out of the rects too): what its strokes, corners and words are scaled by.
local function uiScaleOf(d, sg)
	local k, x = 1, d
	while x and x ~= sg do
		for _, c in x:GetChildren() do
			if c:IsA('UIScale') and c.Name ~= 'MotionScale' then k *= c.Scale end
		end
		x = x.Parent
	end
	return k
end
local ALIGN_X = { [Enum.TextXAlignment.Left] = 'Left', [Enum.TextXAlignment.Right] = 'Right' }
local ALIGN_Y = { [Enum.TextYAlignment.Top] = 'Top', [Enum.TextYAlignment.Bottom] = 'Bottom' }
local function isText(d) return d:IsA('TextLabel') or d:IsA('TextButton') or d:IsA('TextBox') end
-- The pixels one GuiObject draws at rest, in its ScreenGui's space (nil: it draws nothing): its fill and the strokes
-- round its box; its picture (our 3D icons' renders keep a clear margin, Box.IconInset, left out); its words (their
-- bounds placed by its alignment, not the label's box) and their outline. Also the outer edge's corner radius (px) when
-- it has a fill or a box stroke.
local function drawnRect(d, sg)
	local p, s = restOf(d, sg)
	if not p then return nil end
	local k = uiScaleOf(d, sg)
	local text = isText(d)
	local border, wordsLine = 0, 0
	for _, c in d:GetChildren() do
		if c:IsA('UIStroke') and c.Enabled and c.Transparency < 0.95 and c.Thickness > 0 then
			if text and c.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Border then
				wordsLine = math.max(wordsLine, c.Thickness * k)
			else
				border = math.max(border, c.Thickness * k)
			end
		end
	end
	local rects, radius = {}, nil
	if d.BackgroundTransparency < 0.95 or border > 0 then
		table.insert(rects, { p - V2(border, border), s + V2(2 * border, 2 * border) })
		local corner = d:FindFirstChildOfClass('UICorner')
		local r = corner and (corner.CornerRadius.Scale * math.min(s.X, s.Y) + corner.CornerRadius.Offset * k) or 0
		radius = math.min(r, math.min(s.X, s.Y) / 2) + border
	end
	if (d:IsA('ImageLabel') or d:IsA('ImageButton')) and d.Image ~= '' and d.ImageTransparency < 0.95 then
		local icon = d.Name:sub(1, 7) == 'Icon3D_' or (d.Parent ~= nil and d.Parent.Name:sub(1, 7) == 'Icon3D_')
		local inset = icon and B.IconInset or 0
		table.insert(rects, { p + s * inset, s * (1 - 2 * inset) })
	end
	if text and d.Text ~= '' and d.TextTransparency < 0.95 then
		local tb = try(function() return d.TextBounds end)
		local tp, ts
		if typeof(tb) == 'Vector2' and tb.X > 0 and tb.Y > 0 then
			tp, ts = Rules.textRect(p, s, tb, ALIGN_X[d.TextXAlignment], ALIGN_Y[d.TextYAlignment])
		elseif d.TextScaled then
			tp, ts = p, s
		else -- (no TextBounds: the offline harness; UIKit's own measure of the words)
			tp, ts = Rules.textRect(p, s, V2(Kit.textWidth(d.Text, d.TextSize) * k, d.TextSize * k), ALIGN_X[d.TextXAlignment], ALIGN_Y[d.TextYAlignment])
		end
		table.insert(rects, { tp - V2(wordsLine, wordsLine), ts + V2(2 * wordsLine, 2 * wordsLine) })
	end
	local up, us = Rules.union(rects)
	return up, us, radius
end
-- The union of what a target and everything shown inside it draw (cut by any clipping frame inside it), and its
-- outline: the biggest filled or stroked part (its block) with that part's corner radius.
local function drawnBounds(g, sg)
	local all, outline, outlineArea, outlineRadius = {}, nil, -1, 0
	local function add(d)
		local p, s, r = drawnRect(d, sg)
		if not p then return end
		local x = d.Parent
		while p and x and x ~= g.Parent do
			if x:IsA('GuiObject') and x.ClipsDescendants then
				local cp, cs = restOf(x, sg)
				if cp then p, s = Rules.clip(p, s, cp, cs) end
			end
			x = x.Parent
		end
		if not p then return end
		table.insert(all, { p, s })
		if r and s.X * s.Y > outlineArea then outline, outlineArea, outlineRadius = { p, s }, s.X * s.Y, r end
	end
	add(g)
	for _, d in g:GetDescendants() do
		if d:IsA('GuiObject') and shownWithin(d, g) then add(d) end
	end
	local p, s = Rules.union(all)
	return p, s, outline, outlineRadius
end
local function sticker(d)
	if not (STICKERS[d.Name] and d:IsA('GuiObject')) then return false end
	if d:IsA('TextLabel') then return d.Text ~= '' and d.TextTransparency < 0.9 end
	for _, t in d:GetDescendants() do -- (a pill: a frame with its words inside)
		if t:IsA('TextLabel') and t.Text ~= '' and t.TextTransparency < 0.9 then return true end
	end
	return d.BackgroundTransparency < 0.9
end
local function targetRect(g)
	local sg = screenGuiOf(g)
	local gp, gs, settled = restOf(g, sg)
	if not gp then return nil end
	local delta = insetOf(sg) - insetOf(focusGui)
	local p, s, outline, radius = drawnBounds(g, sg)
	if not p then p, s, outline, radius = gp, gs, { gp, gs }, 0 end
	local button = { outline[1] + delta, outline[2] }
	local stick = {}
	for _, d in g:GetDescendants() do
		if sticker(d) and shownWithin(d, g) then
			local dp, ds = restOf(d, sg)
			if dp then table.insert(stick, { dp + delta, ds }) end
		end
	end
	local nb = {}
	for _, o in g.Parent and g.Parent:GetChildren() or {} do
		if o ~= g and o:IsA('GuiObject') and o.Visible and o:FindFirstChild('Hit') then
			local op, os_ = restOf(o, sg)
			if op then table.insert(nb, { op + delta, os_ }) end
		end
	end
	return p + delta, s, button, nb, stick, settled, radius
end

---------------------------------------------------------------------------------------------- drawing the focus
local function viewport()
	local cam = workspace.CurrentCamera
	local v = cam and try(function() return cam.ViewportSize end)
	if typeof(v) == 'Vector2' and v.X > 1 and v.Y > 1 then return v end
	local g = focusGui.AbsoluteSize
	return (g.X > 1 and g.Y > 1) and g or V2(1280, 720)
end
local function setDim(f, pos, size, t)
	f.Position = px(pos.X, pos.Y)
	f.Size = px(size.X, size.Y)
	if f.BackgroundTransparency ~= t then f.BackgroundTransparency = t end
	if not f.Visible then f.Visible = true end
end
local lastRows = {} -- [corner] = rows used
-- Draws the box with its line's inner edge at (pos, size), radius r, the line `line` px at opacity `lineA`, and the dim
-- (`dimShare` 0..1 of the full dim) everywhere outside it.
local function drawFocus(pos, size, r, line, lineA, dimShare)
	pos = V2(math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5))
	size = V2(math.floor(size.X + 0.5), math.floor(size.Y + 0.5))
	r = math.clamp(math.floor(r + 0.5), 0, math.min(MAX_ROWS, math.floor(math.min(size.X, size.Y) / 2)))
	local t = 1 - (1 - B.Dim) * math.clamp(dimShare, 0, 1)
	local screen = focusGui.AbsoluteSize
	for i, rect in Rules.maskRects(pos, size, screen) do setDim(maskRects[i], rect[1], rect[2], t) end
	local rows = Rules.cornerRows(r)
	local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
	for c = 1, 4 do
		local used = 0
		for i, w in rows do
			if w > 0.05 then
				used = i
				local f = cornerRows[c][i]
				local left = (c == 1 or c == 3)
				local top = (c == 1 or c == 2)
				local x = left and x0 or (x1 - w)
				local y = top and (y0 + i - 1) or (y1 - i)
				setDim(f, V2(x, y), V2(w, 1), t)
			end
		end
		for i = used + 1, lastRows[c] or MAX_ROWS do
			local f = cornerRows[c][i]
			if f and f.Visible then f.Visible = false end
		end
		lastRows[c] = used
	end
	box.Position, box.Size = px(pos.X, pos.Y), px(size.X, size.Y)
	boxCorner.CornerRadius = UDim.new(0, r)
	boxLine.Thickness = line
	boxLine.Transparency = 1 - math.clamp(lineA, 0, 1)
	if not layer.Visible then layer.Visible = true end
end
local function hideFocus()
	if layer.Visible then layer.Visible = false end
	if badge.Visible then badge.Visible = false end
end

---------------------------------------------------------------------------------------------- the hint's state
local hintState = { Text = nil, Typed = 0, Since = 0, Alpha = 0, Want = false }
local function setHintAlpha(a)
	a = math.clamp(a, 0, 1)
	if hintState.Alpha == a and hint.Visible == (a > 0) then return end
	hintState.Alpha = a
	hint.Visible = a > 0
	face.BackgroundTransparency = 1 - (1 - H.FillT) * a
	faceEdge.Transparency = 1 - a
	ringEdge.Transparency = 1 - a
	hintText.TextTransparency = 1 - a
	if hintStroke then hintStroke.Transparency = 1 - a end
end
-- Where the hint sits: the reference's spot (the bottom centre, 63.2 % down, its full size), or, while the boxed button is
-- inside a window, a compact one docked just over the box, so it never hides the window's own words (the Rebirth
-- window's "Rebirth resets your power" stays readable over the button you are told to press, on a phone too).
-- dockTop: the box's top edge in screen px, or nil.
-- (on a phone the World Boss invite's card at the top centre reaches down to the hint's spot: the hint then sits just
-- under it instead of touching it)
local function inviteBottom()
	local wb = playerGui:FindFirstChild('HoodWorldBoss')
	local inv = wb and wb.Enabled ~= false and wb:FindFirstChild('Invite', true)
	if not (inv and inv:IsA('GuiObject') and inv.Visible) then return nil end
	return inv.AbsolutePosition.Y + inv.AbsoluteSize.Y + insetOf(wb).Y
end
local hintDock, hintDockText, hintLow, hintWorld = nil, nil, nil, nil
local function placeHint(dockTop, world)
	local k = Kit.scaleFor(hintGui.AbsoluteSize)
	local low
	if not dockTop then
		local under = inviteBottom()
		local full = hintGui.AbsoluteSize.Y
		if under and full > 1 and full * H.Y - H.H / 2 * k < under + 8 then low = math.floor((under + 8) / k + H.H / 2 + 0.5) end
	end
	world = world == true and not dockTop
	if dockTop == hintDock and low == hintLow and world == hintWorld and ((not dockTop and not world) or hintDockText == hintState.Text) then return end
	if (dockTop == nil) ~= (hintDock == nil) or low ~= hintLow or world ~= hintWorld then setHintAlpha(0) end -- (a clean cut to the other place, then it fades in)
	hintDock, hintDockText, hintLow, hintWorld = dockTop, hintState.Text, low, world
	if world and not low then
		-- (brief 32) the world steps: the compact strip under your character (TutorialRules.Hint.WorldY)
		local plainW = Rules.plain(hintState.Text or '')
		local ww = math.min(H.W, Kit.textWidth(plainW, hintText.TextSize) + 2 * H.DockPad)
		hint.AnchorPoint, hint.Size = V2(0.5, 0.5), px(ww, H.DockH)
		hint.Position = UDim2.fromScale(0.5, H.WorldY)
		return
	end
	if not dockTop then
		hint.AnchorPoint, hint.Size = V2(0.5, 0.5), px(H.W, H.H)
		hint.Position = low and UDim2.new(0.5, 0, 0, low) or UDim2.fromScale(0.5, H.Y)
		return
	end
	local plain = Rules.plain(hintState.Text or '')
	local w = math.min(H.W, Kit.textWidth(plain, hintText.TextSize) + 2 * H.DockPad)
	hint.AnchorPoint, hint.Size = V2(0.5, 1), px(w, H.DockH)
	hint.Position = UDim2.new(0.5, 0, 0, math.floor((dockTop - H.DockGap) / k + 0.5))
end
local function sayHint(text, now)
	if hintState.Text == text then return end
	hintState.Text = text
	hintState.Since = now
	hintState.Typed = -1
	if text then
		local size = Rules.hintSize(text, function(s, ts) return Kit.textWidth(s, ts) end)
		if hintText.TextSize ~= size then
			hintText.TextSize = size
			if hintStroke then hintStroke.Thickness = math.max(2, size * 0.1) end
		end
	end
end

---------------------------------------------------------------------------------------------- the frame
local clock = 0 -- (the frame clock: every animation runs on it, so a long frame never skips the lock-on)
local you -- your smoothed flat position (the arrows' line starts here)
local lesson = { Step = nil, Shown = 0, GaveUp = false, AfterLeft = 0, Rebirths = num(attr('Rebirths')) }
local lock = { Key = nil, Pos = nil, Size = nil, Settle = 0, LastPos = nil, LastSize = nil, At = nil, Badge = nil }
local worldShown = nil
local rayFor = nil -- (the character the floor rays leave out, set once per character)
local endedAt = nil
local leg = { At = -1, Kind = nil, Hub = false, Passed = {} }
local fight = { Since = nil, Left = nil } -- (brief 32: when the Fight step began, and the crew standing then)
local seq = { Key = nil, Index = 1 } -- (Oct 27, flow: where we are in the step's lines, TutorialRules.lines)
local guideShown = nil
local function setGuide(on) -- (Oct 27, flow: one guide at a time; PlayerGui HoodGuide = 'Tutorial' while our arrows are down)
	if guideShown == on then return end
	guideShown = on
	playerGui:SetAttribute('HoodGuide', on and 'Tutorial' or '')
end
-- The line of `list` to show now: the first, and each next one once the one on screen is typed out and read.
local function lineFrom(key, list, now)
	if seq.Key ~= key then seq.Key, seq.Index = key, 1 end
	local cur = list[seq.Index]
	if cur and seq.Index < #list and hintState.Text == cur.Text and hintState.Alpha > 0.5 and Rules.holdLeft(cur.Text, hintState.Since, now) <= 0 then
		seq.Index += 1
	end
	cur = list[math.min(seq.Index, #list)]
	return cur and cur.Text or nil
end

local function mirrorInsets(sg)
	if not sg then return end
	if focusGui.IgnoreGuiInset ~= sg.IgnoreGuiInset then focusGui.IgnoreGuiInset = sg.IgnoreGuiInset end
	pcall(function() if focusGui.ScreenInsets ~= sg.ScreenInsets then focusGui.ScreenInsets = sg.ScreenInsets end end)
end

local function stepFocus(info, key)
	-- info: the lesson step's rules (Box, Badge) or nil. Returns true while the box is on screen (locked).
	if not info or not info.Box then
		lock.Key, lock.At, lock.Settle, lock.LastPos = nil, nil, 0, nil
		hideFocus()
		return false
	end
	if lock.Key ~= key then
		-- a new target: the old box goes at once (the reference's one empty frame), the new one waits to settle
		lock.Key, lock.At, lock.Settle, lock.LastPos, lock.LastSize = key, nil, 0, nil, nil
		hideFocus()
	end
	local g = Boxed[info.Box] and Boxed[info.Box]()
	if not g or not shown(g) then
		lock.At, lock.Settle, lock.LastPos = nil, 0, nil
		hideFocus()
		return false
	end
	mirrorInsets(screenGuiOf(g))
	local p, s, button, nb, stick, settled, radius = targetRect(g)
	if not p then hideFocus() return false end
	local still = Rules.same(p, s, lock.LastPos, lock.LastSize)
	lock.LastPos, lock.LastSize = p, s
	lock.Settle = (still and (settled or lock.At)) and lock.Settle + 1 or 0 -- (locked: a hover or a press never unsettles it)
	if lock.At then
		if not Rules.same(p, s, lock.Pos, lock.Size) then
			if Rules.same(p, s, lock.Pos, lock.Size, 4) and still then
				lock.Pos, lock.Size, lock.Radius = p, s, radius -- (a few px, then still: it follows without a new lock-on)
			elseif lock.Settle >= B.Settle then
				-- it moved and stopped (a resize, the phone turned, the HUD re-laid): lock on again where it is now
				lock.Pos, lock.Size, lock.Radius, lock.At = p, s, radius, clock
			elseif not still then
				-- still moving: no box at a stale place
				lock.At = nil
				hideFocus()
				return false
			end
		end
	elseif lock.Settle >= B.Settle - 1 then
		lock.Pos, lock.Size, lock.Radius, lock.At = p, s, radius, clock
	else
		hideFocus()
		return false
	end
	local vp = viewport()
	local t = clock - lock.At
	local scale, lineA, dim = Rules.lockOn(t)
	if info.NoDim then dim = 0 end -- (Oct 27, flow: a box in the world steps points, it does not stop the game)
	if attr('ReducedMotion') == true then scale = 1 end
	local line = Rules.lineFor(vp.Y)
	local bp, bs, r = Rules.boxRect(lock.Pos, lock.Size, vp.Y, Rules.gutterPad(lock.Pos, lock.Size, nb, line), lock.Radius)
	lock.Top = bp.Y - line -- (the line's outer edge: the hint docks above it in a window)
	bp, bs = Rules.scaled(bp, bs, scale)
	drawFocus(bp, bs, r * scale, line, lineA, dim)
	local c, d
	if info.Badge then
		c, d = Rules.badgeFor(button[1], button[2]) -- (on the button's own corner, like the reference's "1")
		for _, st in stick or {} do
			local q, z = st[1], st[2]
			if c.X + d / 2 > q.X and c.X - d / 2 < q.X + z.X and c.Y + d / 2 > q.Y and c.Y - d / 2 < q.Y + z.Y then c = nil break end -- (the button's own sticker is there)
		end
	end
	if c then
		badge.Position, badge.Size = px(math.floor(c.X + 0.5), math.floor(c.Y + 0.5)), px(d, d)
		badgeText.Text = info.Badge
		badgeText.TextSize = math.floor(d * 0.72)
		if badgeStroke then badgeStroke.Thickness = math.max(1, d * 0.08) end
		badge.BackgroundTransparency = 1 - lineA
		badgeEdge.Transparency = 1 - lineA
		badgeText.TextTransparency = 1 - lineA
		badge.Visible = true
	else
		badge.Visible = false
	end
	return true
end

local popupAt, popupWas = -1, false
local function onFrame(dt)
	dt = math.clamp(type(dt) == 'number' and dt or 1 / 60, 0, 0.1)
	clock += dt
	local now = clock
	local stepName = attr('OnboardingStep')
	local worldStep = Rules.step(stepName)
	if now - popupAt >= 0.1 then popupAt, popupWas = now, popupUp() end -- (ten looks a second are plenty)
	local busyScreen = popupWas or unboxing()

	-------------------------------------------------------------- the lesson (the first rebirth)
	local n = num(attr('Rebirths'))
	if n >= 1 and lesson.Rebirths == 0 and (lesson.Step == 'Open' or lesson.Step == 'Press') then lesson.AfterLeft = Rules.AfterSeconds end
	lesson.Rebirths = n
	if lesson.AfterLeft > 0 then lesson.AfterLeft -= dt end
	local lessonStep = Rules.lessonStep({
		Rebirths = n, RebirthReady = attr('RebirthReady') == true, WorldStep = stepName, Window = window(),
		Busy = busyScreen or num(attr('WaveStage')) > 0, GaveUp = lesson.GaveUp, AfterLeft = lesson.AfterLeft, -- (in the lobby only)
	})
	if lessonStep ~= lesson.Step then lesson.Step, lesson.Shown = lessonStep, 0 end
	local info = lessonStep and Rules.Lesson[lessonStep] or nil
	local boxed = false
	local talk = type(stepName) == 'string' and Rules.Talk[stepName] ~= nil

	-------------------------------------------------------------- the hint
	local text
	if info then
		boxed = stepFocus(info, lessonStep)
		if boxed then
			lesson.Shown += dt
			if lesson.Shown > Rules.LessonGiveUp then lesson.GaveUp = true end -- (ignored: it leaves for this visit)
		end
		if lessonStep == 'After' then
			-- (Oct 27, flow) what you keep first, then "Now go train again!"
			local before = info.Before and Rules.Why[info.Before]
			text = before and lineFrom('Lesson:After', { before, { Text = info.Text } }, now) or info.Text
		elseif boxed then
			text = (touchOnly() and info.Touch) or info.Text
		end
	elseif (worldStep or talk) and not busyScreen and window() == '' then
		local inBay = stepName == 'Train' and inLane()
		text = lineFrom(tostring(stepName) .. (inBay and ':lane' or ''), (Rules.lines(stepName, inBay, touchOnly())), now)
		-- (brief 32) the fight's line leaves once you have got it (the first goon down, or a few seconds)
		if stepName == 'Fight' then
			if fight.Since == nil then fight.Since, fight.Left = now, num(attr('WaveLeft')) end
			if not Rules.fightHintOn(now - fight.Since, fight.Left, num(attr('WaveLeft'))) then text = nil end
		else
			fight.Since, fight.Left = nil, nil
		end
		-- (brief 32) a new line waits until the one on screen has been typed out and read
		if text and hintState.Text and text ~= hintState.Text and hintState.Alpha > 0 and Rules.holdLeft(hintState.Text, hintState.Since, now) > 0 then
			text = hintState.Text
		end
	end
	if not info then
		-- (Oct 27, flow) a line with a box (BAY 1's Power line): the white box round its HUD piece, no dim, while it shows
		local l = Rules.lineOf(text or (hintState.Alpha > 0 and hintState.Text) or nil)
		local okF, b = pcall(stepFocus, l and l.Box and { Box = l.Box, NoDim = true } or nil, l and l.Box and ('Line:' .. l.Box) or nil)
		boxed = okF and b == true
		focusGui:SetAttribute('Want', l and l.Box or '') -- (what the line points at, drawn or not)
	end
	focusGui:SetAttribute('Step', lessonStep or ((worldStep or talk) and stepName) or '')
	focusGui:SetAttribute('Boxed', boxed and ((info and info.Box) or 'Line') or '')
	if text then sayHint(text, (boxed and info and lock.At) or now) end
	if boxed and info and info.Box == 'Window' and lock.Top then
		placeHint(math.floor(lock.Top + insetOf(focusGui).Y + 0.5))
	elseif text then
		placeHint(nil, info == nil)
	end
	local want = text ~= nil
	if want then
		-- (Oct 27, flow r2) the whole line at once, its words fading in as the pill grows a little: no half-typed words
		if hintState.Typed ~= -2 then
			hintState.Typed = -2
			hintText.Text = Rules.rich(hintState.Text)
		end
		setHintAlpha(hintState.Alpha + dt / H.FadeIn)
		local e = math.clamp((now - hintState.Since) / H.Pop, 0, 1)
		local k = 1 - (1 - e) ^ 3
		hintPop.Scale = H.PopFrom + (1 - H.PopFrom) * k
		hintText.TextTransparency = 1 - hintState.Alpha * k
		if hintStroke then hintStroke.Transparency = 1 - hintState.Alpha * k end
	else
		-- (it keeps its words: the same line coming back after a popup is not typed again)
		setHintAlpha(hintState.Alpha - dt / H.FadeOut)
	end

	-------------------------------------------------------------- the arrows
	if over then return end
	if worldStep then endedAt = nil
	elseif stepName ~= nil and stepName ~= '' then
		-- past the gift (Gun, Run, Done): a beat later the arrows go for good
		endedAt = endedAt or now
		if now - endedAt > 1 then
			over = true
			setGuide(false)
			if world then world:Destroy() end
			world, arrows = nil, {}
			return
		end
	end
	local c = player.Character
	local rootPart = c and c:FindFirstChild('HumanoidRootPart')
	local hum = c and c:FindFirstChildOfClass('Humanoid')
	local _, target = Rules.worldHint(stepName, stepName == 'Train' and inLane(), false)
	local alive = hum == nil or hum.Health > 0
	-- (the arrows are in the world: a popup over the screen leaves them be; a window or the unboxing puts them away)
	local aim = (target and rootPart and alive and not unboxing() and window() == '') and Target[target] and Target[target](rootPart.Position) or nil
	if not aim then
		if world then hideArrows() end
		worldShown = nil
		setGuide(false)
		return
	end
	local feetY = rootPart.Position.Y - ((hum and hum.HipHeight or 2) + rootPart.Size.Y / 2)
	-- one straight leg at a time (TutorialRules.pickLeg): the target, or the hub first when a lane, a wall or a stand is
	-- in the way; looked at twice a second, so the arrows never flick
	if now - leg.At >= 0.5 or leg.Kind ~= target then
		leg.At, leg.Kind = now, target
		local knee = Vector3.new(rootPart.Position.X, feetY + 1.6, rootPart.Position.Z)
		local h = (target ~= 'Pad' and inLobby(rootPart.Position)) and hub() or nil
		if h and Vector3.new(h.X - knee.X, 0, h.Z - knee.Z).Magnitude <= A.Hide + 2 then leg.Passed[target] = true end
		if leg.Passed[target] then h = nil end -- (a waypoint once passed is never a leg again for this target)
		local cands = { aim }
		if h then table.insert(cands, h) end
		if sightParams then sightParams.FilterDescendantsInstances = { c, world, workspace:FindFirstChild('HoodGoons') } end
		local pick = Rules.pickLeg(knee, cands, function(p) return clearTo(knee, p) end, leg.Hub and h or nil)
		leg.Hub = h ~= nil and pick == h
	end
	if leg.Hub and hub() then aim = hub() end
	local flat = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
	local shownKey = target .. (leg.Hub and '>hub' or '')
	if not you or (flat - you).Magnitude > 8 or worldShown ~= shownKey then
		you = flat -- (a teleport, a new target or a new leg: start from where you are)
	else
		you = you:Lerp(flat, 1 - math.exp(-dt / A.Smooth))
	end
	worldShown = shownKey
	local list, dir = Rules.arrows(Vector3.new(you.X, feetY, you.Z), aim)
	if #list == 0 then
		if world then hideArrows() end
		setGuide(false)
		return
	end
	setGuide(true)
	if not world then
		world = Instance.new('Folder')
		world.Name = 'HoodTutorialLocal'
		world.Parent = workspace
		rayFor = nil
	end
	if rayParams and rayFor ~= c then rayParams.FilterDescendantsInstances = { c, world }; rayFor = c end
	for i, p in list do
		local a = arrows[i]
		if not a then
			a = makeArrow(i)
			arrows[i] = a
		end
		-- (an arrow is laid again only when its spot or the line's direction moved: they are anchored to the target, so
		-- most frames move none of them; the floor under it is looked for again only a step away or a step up)
		local moved = not a.At or (p.At - a.At).Magnitude > 0.02 or dir:Dot(a.Dir) < 0.99999
		if not a.FloorAt or (p.At - a.FloorAt).Magnitude > 0.3 or math.abs(feetY - a.Feet) > 0.5 then
			a.Y, a.FloorAt, a.Feet = floorAt(p.At, feetY), p.At, feetY
			moved = true
		end
		if moved then
			layArrow(a, p.At, dir, a.Y)
			a.At, a.Dir = p.At, dir
		end
		fadeArrow(a, p.Alpha)
	end
	hideArrows(#list + 1)
end

RunService.Heartbeat:Connect(onFrame)
local function relayout()
	local abs = hintGui.AbsoluteSize
	if abs.X >= 1 and abs.Y >= 1 then pcall(hintFit, abs) end
	lock.Settle = 0 -- (a new screen size: the box settles and locks on again)
end
hintGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
focusGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
hintGui.Parent = playerGui
focusGui.Parent = playerGui
relayout()
