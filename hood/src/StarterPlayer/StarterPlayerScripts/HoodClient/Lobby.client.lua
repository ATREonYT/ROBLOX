-- World-side guidance and feedback on the active map (The Block V2, or the original Block's SimulatorLobby):
-- Unlocked/Locked on the shooting ranges (a lane opens at a number of rebirths, Config/Skins.Stations; a locked lane
-- is a black silhouette under a label that stays readable: "Locked", the rebirths it needs, "xN Power"), the floating
-- arrow over your best open lane ("TRAIN x3 HERE"), the new player's floor guide (to BAY 1, then out through the
-- stage door), the "+N POWER" pop over your head for Power that comes from anywhere but a shot, and the sway of the
-- bag you train on. Players keep their own avatar: there are no looks to equip. The screen HUD is HUD.client.
-- (LOBBY6, BRIEF24) Also the lobby's pass boards (the reference hall's floor gamepass cards: e2_lobby Lobby.passBoard): a
-- hold on one buys its pass, and an owned pass reads OWNED.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local Skins = require(RS.Shared.Config.Skins)
local ActiveMap = require(RS.Shared.ActiveMap)
local RebirthRules = require(RS.Shared.RebirthRules)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local lobby = active.Lobby
local training = lobby:FindFirstChild('Training') or lobby

local C = Color3.fromRGB
-- (LOBBY6, BRIEF24: "use the same fonts as the references": the lobby's world words are the reference's FredokaOne with a
-- dark outline, the lane stacks' and the boards' font; the screen HUD keeps its own)
local DISPLAY = Font.fromEnum(Enum.Font.FredokaOne)
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
-- The shooting ranges on the map: shooter's box, label, targets. A lane opens at a number of rebirths
-- (Skins.Stations[i].Rebirths); a locked lane is a black silhouette, like the user's ref_lanes_spread.png and
-- ref_training_lanes.png (LOBBY5 r11/r12): in a lane built with the Silhouette attribute the station (its pad, rim,
-- bench, stands and targets, their textures and surface signs) goes flat black and its effects stop, while its side
-- walls and backstop and the plaza's deck between the lanes keep their colours (the black shapes stand out against
-- them) and the label stays readable over it; it comes back in colour when it unlocks. Older stations without the attribute (the Champ Ring, the original Block's
-- gym) black out their gear only.
--   Lane labels (code5/d2_stations Stations.labels, BRIEF23's superhero lanes: a BillboardGui with Chip + Icon + Cost,
--   Detail, Power): the chip shows the rebirth icon and the rebirths the lane needs (a Robux lane: the Robux icon and
--   its price), Detail "Unlocked" green / "Locked" red, and "xN Power" big in white. The chip's number and the
--   multiplier are rewritten here from the config too (RebirthRules.laneLabel), so the label always says what
--   Config/Skins.Stations says. A Robux lane (Pass) opens with its game pass (Pass_<Key>, RebirthRules.laneOpen with the
--   player) and is never blacked out while locked: it is for sale, so it keeps its colours and its premium trim.
--   The Champ Ring's sign (HoodProps): Detail "LOCKED • 🔄 16 REBIRTHS" / "UNLOCKED • TRAIN HERE".
--   (LABELS) How a lane's label shows is HoodClient/LabelFade's (Shared/LabelFade, kind Lane): it fades and shrinks a
--   little with the distance, shrinks up close, and declutters the row seen down the aisle. This only says which lane
--   reads from further (the next to open: FadeNear/FadeFar) and which fade out while you stand in a box (FadeHold).
local okVfx, HoodVFX = pcall(require, RS.Shared.HoodVFX)
local okKit, Kit = pcall(require, RS.Shared.UIKit)
if not okKit or type(Kit) ~= 'table' then Kit = nil end
-- (brief 23, UI5's UIKit.watchImage) An uploaded icon still in Roblox review draws nothing. While a label's icon (the
-- lane chip's rebirth / Robux icon, a shoe box label's Cash / Robux icon) doesn't draw, it hides, its text moves to the
-- middle of `span` (x0, w) and carries the glyph instead (the Glyph attribute chipText reads); back when it loads.
local function iconOrGlyph(icon, text, glyph, span, repaint)
	if not (Kit and Kit.watchImage and icon and text) or icon:GetAttribute('Watched') then return end
	icon:SetAttribute('Watched', true)
	local pos, size, align = text.Position, text.Size, text.TextXAlignment
	local function set(missing)
		icon.Visible = not missing
		text.Position = missing and UDim2.fromScale(span[1], pos.Y.Scale) or pos
		text.Size = missing and UDim2.fromScale(span[2], size.Y.Scale) or size
		text.TextXAlignment = missing and Enum.TextXAlignment.Center or align
		text:SetAttribute('Glyph', missing and glyph or '')
		repaint()
	end
	Kit.watchImage(icon, function() set(true) end, function() set(false) end)
end
-- The shoe boxes' labels (code5/e2_lobby Lobby.boxLabel: WorldLabel > PriceIcon beside Price, or beside Title on a Robux
-- box): the same fallback. Boxes stream in whole, so this looks again with every refresh.
local function watchBoxLabels()
	local boxes = active.Root:FindFirstChild('ShoeBoxes', true)
	for _, d in (boxes and boxes:GetDescendants() or {}) do
		if d:IsA('ImageLabel') and d.Name == 'PriceIcon' and not d:GetAttribute('Watched') then
			local g = d.Parent
			local robux = g:GetAttribute('Robux') == true
			local text = g:FindFirstChild(robux and 'Title' or 'Price')
			if text and text:IsA('TextLabel') then
				local base = text.Text
				local glyph = robux and (RebirthRules.RobuxMark or '⏣') or '💵'
				iconOrGlyph(d, text, glyph, { 0.04, 0.92 }, function()
					local gl = text:GetAttribute('Glyph') or ''
					text.Text = gl ~= '' and (gl .. (robux and '' or ' ') .. base) or base
				end)
			end
		end
	end
end
if not okVfx then HoodVFX = nil end
local stations = {}
-- (LABELS) Label bands in studs from the camera: every lane's stack reads from the spawn and the aisle mouth (LOBBY5 r12,
-- CRITIC3: the Robux lanes at the aisle's far end sell, so they must read from the spawn too: 60 -> 90, over LabelFade's
-- lane band 45 -> 75); the next lane to open from further; a middle lane's stack only up close.
local LANE_NEAR, LANE_FAR = 60, 90
local GOAL_NEAR, GOAL_FAR, MIDDLE_NEAR, MIDDLE_FAR, NEXT_LIFT = 65, 105, 14, 22, Vector3.new(0, 6.5, 0)
-- (LOBBY6) a Robux lane's big stack reads from further still: GOLD BAY at the aisle's far end is ~60 studs from the spawn
-- and the armory, and both Robux lanes sell from across the hall
local PROMO_NEAR, PROMO_FAR = 80, 120
-- The chip's text: the number alone next to the label's icon (its Glyph attribute is ''), else the glyph and the
-- number (a map built before the icons: the old "FREE" / "🔄 n").
local function chipText(s, cost)
	local pass = RebirthRules.lanePass and RebirthRules.lanePass(s)
	local number = pass and tostring(s.RobuxPrice or '') or tostring(RebirthRules.laneNeed(s))
	local glyph = cost:GetAttribute('Glyph')
	if glyph == '' then return number end
	if glyph ~= nil then return pass and (glyph .. number) or (glyph .. ' ' .. number) end
	if pass then return (RebirthRules.RobuxMark or '') .. number end
	return s.Rebirths == 0 and 'FREE' or ('🔄 ' .. s.Rebirths)
end
local function paidLane(s) return RebirthRules.lanePass ~= nil and RebirthRules.lanePass(s) ~= nil end
local function track(s)
	local model = training:FindFirstChild('Training_' .. s.Id, true) or active.Root:FindFirstChild('Training_' .. s.Id, true)
	if not model then return nil end
	local sign = model:FindFirstChild('Sign', true) or model:FindFirstChild('Nameplate', true)
	local entry = { Zone = model:FindFirstChild('TrainingZone', true), Sign = sign, Parts = {}, Swing = {}, Fx = model:FindFirstChild('Theme'), Skins = {}, Guis = {} }
	entry.Bag = sign ~= nil and sign:FindFirstChild('Power', true) ~= nil
	if model:GetAttribute('Silhouette') and not paidLane(s) then
		entry.Whole = model
		-- (LOBBY5 r12, CRITIC3: the lane's side walls and its backstop keep their colours, so the black pad, bench, stands
		-- and targets stand out against them as shapes, like the reference's black figures before their sandbag walls)
		local function framing(p)
			local a = p.Parent
			while a and a ~= model do
				if a.Name == 'Walls' or a.Name == 'Backstop' then return true end
				a = a.Parent
			end
			return false
		end
		for _, p in model:GetDescendants() do
			if framing(p) then continue end
			if p:IsA('BasePart') and p.Transparency < 1 then
				table.insert(entry.Parts, { Part = p, Color = p.Color, Material = p.Material })
			elseif p:IsA('Texture') or p:IsA('Decal') then
				table.insert(entry.Skins, { Item = p, Transparency = p.Transparency })
			elseif p:IsA('SurfaceGui') then
				table.insert(entry.Guis, p)
			end
		end
	end
	local gear = model:FindFirstChild('Equipment')
	if gear then
		if not entry.Bag and not entry.Whole then
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
	-- Range-lane labels like the video's training row: the near lanes' stacks big and clear, the far ones faded
	-- (LabelFade). (Middle stays for a station that should only show up close; none does now.)
	if entry.Bag and entry.Zone then
		entry.Label = sign:FindFirstChildWhichIsA('BillboardGui')
		entry.Middle = false
		local cost = sign:FindFirstChild('Cost', true)
		if cost and cost:IsA('TextLabel') then
			cost.Text = chipText(s, cost)
			local icon = sign:FindFirstChild('Icon', true)
			if icon and icon:IsA('ImageLabel') then
				-- (the chip spans x 0.33..0.67 of the label: the glyph and the number centre in it)
				local glyph = paidLane(s) and (RebirthRules.RobuxMark or '⏣') or '🔄'
				iconOrGlyph(icon, cost, glyph, { 0.35, 0.3 }, function() cost.Text = chipText(s, cost) end)
			end
		end
		local power = sign:FindFirstChild('Power', true)
		if power and power:IsA('TextLabel') then power.Text = 'x' .. s.Multiplier .. ' Power' end
	end
	stations[s.Id] = entry
	return entry
end
for _, s in Skins.Stations do track(s) end
-- The lanes whose box is within 25 studs of each lane's box (any direction, any height): their stacks hide while
-- you stand in that box, so the shooter's view isn't a pile of labels under the HUD hint.
local NEIGHBOUR = 25
local function neighbours()
	for _, e in stations do
		e.Near = {}
		for id, o in stations do
			if o ~= e and e.Zone and o.Zone and (o.Zone.CFrame.Position - e.Zone.CFrame.Position).Magnitude < NEIGHBOUR then e.Near[id] = true end
		end
	end
end
neighbours()
-- A station that hasn't streamed in yet (the Champ Ring is far down the street) is looked for again now and then.
local nextLook = 0
local function retrack()
	if os.clock() < nextLook then return end
	nextLook = os.clock() + 5
	local found = false
	for _, s in Skins.Stations do
		if not stations[s.Id] and track(s) then found = true end
	end
	if found then neighbours() end
end
local SILHOUETTE = C(0, 0, 0) -- (flat black on Plastic: SmoothPlastic's sky sheen showed it navy)
local UNLOCKED, LOCKED = C(40, 235, 90), C(240, 40, 60) -- (the video's green Unlocked and red Locked, as the lanes build them)
-- n: your rebirths.
local function paintStations(n)
	retrack()
	local goal = RebirthRules.nextLane(n) -- the next lane to open shows its stack from afar (lifted clear if it's a middle one)
	-- While you're still before the first rebirth lane, the next lane stays a plain lane (no lift, no long range):
	-- lifted, its stack landed on the FREE lane's from the side, and the free lane is the one a new player needs.
	local free = n < (Skins.Stations[2] and Skins.Stations[2].Rebirths or 0)
	-- Your own lane's label hides while you stand in its box (the HUD hint already says its multiplier, or the
	-- rebirths it needs), and so do your neighbours' (within 25 studs): from the shooter's spot they pile up under it.
	local here = player:GetAttribute('TrainingStation') or ''
	local hereId = here:gsub('^Locked:', '')
	local box = stations[hereId]
	for _, s in Skins.Stations do
		local e = stations[s.Id]
		if e and e.Label then
			local lift = goal == s and not free
			local own = hereId == s.Id
			local beside = box ~= nil and not own and not lift and (box.Near or {})[s.Id] == true
			local state = (e.Middle and 'M' or 'E') .. (lift and 'G' or '') .. (own and 'O' or '') .. (beside and 'N' or '')
			if e.LabelState ~= state then
				e.LabelState = state
				-- (LABELS) LabelFade owns MaxDistance, Enabled stays on: the band and the hold are attributes it reads
				-- (nil: the lane band), so the hold fades the stack out and back in instead of switching it.
				local middle = e.Middle and not lift
				local promo = paidLane(s)
				e.Label:SetAttribute('FadeNear', promo and PROMO_NEAR or middle and MIDDLE_NEAR or (lift and GOAL_NEAR or LANE_NEAR))
				e.Label:SetAttribute('FadeFar', promo and PROMO_FAR or middle and MIDDLE_FAR or (lift and GOAL_FAR or LANE_FAR))
				e.Label.StudsOffset = (e.Middle and lift) and NEXT_LIFT or Vector3.zero
				e.Label:SetAttribute('FadeHold', (own or beside) or nil)
			end
		end
		if e then
			local locked = not RebirthRules.laneOpen(s, n, player)
			if e.Locked ~= locked then
				e.Locked = locked
				for _, r in e.Parts do
					r.Part.Color = locked and SILHOUETTE or r.Color
					r.Part.Material = locked and Enum.Material.Plastic or r.Material
				end
				if e.Whole then
					for _, k in e.Skins do k.Item.Transparency = locked and 1 or k.Transparency end
					for _, g in e.Guis do g.Enabled = not locked end
					if HoodVFX then HoodVFX.setEnabled(e.Whole, not locked) end -- (the theme's effects and the lane's own flames)
				elseif e.Fx and HoodVFX then
					HoodVFX.setDensity(e.Fx, locked and 0.5 or 1)
				end
				local detail = e.Sign and e.Sign:FindFirstChild('Detail', true)
				if detail then
					if e.Bag then
						-- Locked/Unlocked, the chip and "xN Power" all stay up at every distance.
						detail.Text = locked and 'Locked' or 'Unlocked'
						detail.TextColor3 = locked and LOCKED or UNLOCKED
					else
						detail.Text = locked and ('LOCKED • 🔄 ' .. s.Rebirths .. ' REBIRTHS') or (s.Rebirths == 0 and 'FREE • TRAIN HERE' or 'UNLOCKED • TRAIN HERE')
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
local GUIDE_POWER = 10 -- (a map without stage gates: to BAY 1 until 10 Power)
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
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
-- n: Power; station: TrainingStation; evolving: true hides the guide (nothing sets it now); zone: the free lane's box.
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
		-- The floating arrow leaves the lanes. (LOOP: it used to float "STAGE 1 OPEN ↓" at the door, right on the gate
		-- sign's own "Open! Walk through" badge: the sign says it, the trail leads there.)
		indicator.Adornee = nil
	end
end
player.CharacterAdded:Connect(function(c)
	c:WaitForChild('HumanoidRootPart', 10)
	if guideWant then updateGuide(table.unpack(guideWant)) end
end)

---------------------------------------------------------------------------------------------- pass boards
-- The lobby's pass boards (code5/e2_lobby Lobby.passBoard: PassBoard_<Key> tagged HoodPassBoard, PassPoint >
-- PassPrompt with the Pass attribute): a hold buys the pass (Products.canBuy: an id and Wired; Roblox's own purchase
-- window, the player's choice), else the HUD's "<pass> is coming soon!" toast (the prompt's ComingSoon attribute, which
-- HUD.client reads). A pass you own: the board's chip reads OWNED and its prompt hides. Nothing here opens by itself.
local okProducts, Products = pcall(require, RS.Shared.Config.Products)
if not okProducts or type(Products) ~= 'table' then Products = nil end
local MarketplaceService = game:GetService('MarketplaceService')
local boards = {}
local function paintBoard(b)
	local owned = player:GetAttribute('Pass_' .. b.Key) == true
	if b.Owned == owned then return end
	b.Owned = owned
	if b.Prompt then b.Prompt.Enabled = not owned end
	if b.Price then
		local price = b.Price:GetAttribute('Price')
		b.Price.Text = owned and 'OWNED' or ((Products and Products.RobuxMark or '') .. tostring(price or ''))
	end
end
local function watchBoards()
	local ok, tagged = pcall(function() return CollectionService:GetTagged('HoodPassBoard') end)
	for _, m in ok and tagged or {} do
		local key = m:GetAttribute('Pass')
		if boards[m] or type(key) ~= 'string' or not m:IsDescendantOf(active.Root) then continue end
		local prompt = m:FindFirstChild('PassPrompt', true)
		local b = { Key = key, Prompt = prompt, Price = m:FindFirstChild('Price', true) }
		boards[m] = b
		if prompt and prompt:IsA('ProximityPrompt') then
			local live = Products ~= nil and Products.canBuy(key)
			prompt:SetAttribute('ComingSoon', not live) -- (HUD.client toasts "<ObjectText> is coming soon!")
			prompt.Triggered:Connect(function()
				if not (Products and Products.canBuy(key)) or player:GetAttribute('Pass_' .. key) == true then return end
				pcall(function() MarketplaceService:PromptGamePassPurchase(player, Products.idOf(key)) end)
			end)
		end
		player:GetAttributeChangedSignal('Pass_' .. key):Connect(function() paintBoard(b) end)
		paintBoard(b)
	end
end

---------------------------------------------------------------------------------------------- refresh
local lastPower
local pulse
local function refresh()
	pcall(watchBoxLabels)
	pcall(watchBoards)
	local n = player:GetAttribute('Power')
	if n == nil then return end
	local rebirths = RebirthRules.count(player:GetAttribute('Rebirths'))
	local station = player:GetAttribute('TrainingStation') or ''
	paintStations(rebirths)
	-- The arrow floats over your best open lane while you're not in one.
	local bestGym = Skins.Stations[1]
	for _, g in Skins.Stations do
		if RebirthRules.laneOpen(g, rebirths, player) and stations[g.Id] then bestGym = g end
	end
	if station == '' or station:find('Locked:') then
		indicator.Adornee = zoneOf(bestGym.Id)
		pointer.Text = 'TRAIN x' .. bestGym.Multiplier .. ' HERE ↓'
	else
		indicator.Adornee = nil
	end
	updateGuide(n, station, false, zoneOf(bestGym.Id), string.upper(bestGym.Name))
	-- "+N POWER" over your head when Power comes from anything but a shot (a pack from the store, say): not on a range
	-- (Shoot.client puts each shot's "+N" on the target) and not in a stage with targets (Waves.client does there).
	local inWave = (player:GetAttribute('WaveStage') or 0) ~= 0
	if lastPower and n > lastPower and not require(RS.Shared.ShotRules).counts(station) and not inWave then
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
for _, key in { 'Power', 'TrainingStation', 'StagesCleared', 'Rebirths' } do -- (the last two: the guide's steps and the lanes)
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
-- (a Robux lane opens the moment its pass arrives: Pass_RangeVIP1, Pass_RangeVIP2)
for _, s in Skins.Stations do
	local pass = RebirthRules.lanePass and RebirthRules.lanePass(s)
	if pass then player:GetAttributeChangedSignal('Pass_' .. pass):Connect(refresh) end
end
refresh()
-- (Lanes that stream in later get painted too.)
task.spawn(function()
	while true do
		task.wait(5)
		refresh()
	end
end)

-- (LOOP's two label rules, the shrink inside 34 studs of the camera and the declutter of the lanes lined up down the
-- aisle (a stack more than 12% covered on screen by a nearer one waits, showing again under 6%), live on in
-- HoodClient/LabelFade (Shared/LabelFade, kind Lane), merged with the distance fade so the two never fight over a label.)

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
