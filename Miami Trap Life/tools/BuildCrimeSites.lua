-- Crime sites builder (crime loop thread). Builds Workspace.MTL_CrimeSites: every interior, prop and invisible point
-- the crime code reads (CrimeService.point(site, name) finds a part by name anywhere under MTL_CrimeSites.<site>).
-- Lives in Studio as ServerStorage.MTL_Tools.CrimeSites (Edit-time only, never runs in game).
-- Run one section at a time (each yields between rooms):
--   local B = require(game.ServerStorage.MTL_Tools.CrimeSites:Clone())
--   B.stickups()  B.laundromat()  B.cashForGoldN()  B.houses()  B.atms()  B.tips()  B.boosts()  B.props()
-- Re-running a section rebuilds it. Map parts it hides go to ServerStorage.MTL_ReplacedJobSites.Crime_<site>
-- (JobSiteKit.stash, attribute MTL_OriginalParent), never deleted.
--
-- Conventions for points (invisible 0.6 parts, CanQuery off):
--   people (Clerk, Owner): floor level, LookVector = the way they face
--   surfaces (Drawer, Tray, Stash, Bags): on the top surface, stacks are laid on it
--   Fence: where the player stands, looking at Marcus (he stands 2.5 ahead, facing back)
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local K = require(SS.MTL_Tools.JobSiteKit)
local C, M = K.C, K.M
local V = Vector3.new

local B = {}

---------------------------------------------------------------- basics

local function sitesRoot(): Folder
	local f = workspace:FindFirstChild("MTL_CrimeSites")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MTL_CrimeSites"
		f.Parent = workspace
	end
	return f :: Folder
end

local function newSite(id: string, kind: string): Model
	local old = sitesRoot():FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = id
	m:SetAttribute("MTL_CrimeKind", kind)
	return m
end

local function point(parent: Instance, name: string, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = V(0.6, 0.6, 0.6)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Transparency = 1
	p.Color = C(255, 0, 255)
	p.Parent = parent
	return p
end

-- Raycast that skips invisible / non-colliding parts and our own sites.
local function cast(from: Vector3, dir: Vector3, extra: { Instance }?): RaycastResult?
	local ex: { Instance } = { sitesRoot() }
	if extra then
		for _, e in extra do
			table.insert(ex, e)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 16 do
		params.FilterDescendantsInstances = ex
		local r = workspace:Raycast(from, dir, params)
		if not r then
			return nil
		end
		local inst = r.Instance
		if inst:IsA("BasePart") and (inst.Transparency > 0.9 or not inst.CanCollide) then
			table.insert(ex, inst)
		else
			return r
		end
	end
	return nil
end
B.cast = cast

local function groundY(x: number, z: number, top: number?, extra: { Instance }?): number
	local r = cast(V(x, top or 60, z), V(0, -140, 0), extra)
	return if r then r.Position.Y else 3
end
B.groundY = groundY

-- Hides map parts inside a box (unit-local), except the shell pieces. Returns how many.
local KEEP = { Floor = true, Footprint = true, Back = true, Side = true, Roof = true, Parapet = true }
local function clearBox(site: string, F: CFrame, W: number, D: number, H: number, from: number?)
	local d0 = from or 0.4
	local box = F * CFrame.new(0, H / 2 + 0.3, -(d0 + D) / 2)
	local parts = workspace:GetPartBoundsInBox(box, V(W - 0.2, H - 0.2, D - d0))
	local n = 0
	for _, p in parts do
		if p:IsDescendantOf(sitesRoot()) or not p:IsDescendantOf(workspace.ViceBay) or KEEP[p.Name] then
			continue
		end
		local lp = F:PointToObjectSpace(p.Position)
		local big = math.max(p.Size.X, p.Size.Y, p.Size.Z)
		if math.abs(lp.X) < W / 2 - 0.15 and -lp.Z > d0 and -lp.Z < D - 0.3 and lp.Y > 0.05 and big < 16 then
			K.stash("Crime_" .. site, p)
			n += 1
		end
	end
	return n
end

-- The facade door leaf of a unit -> stash it, return its CFrame + size (for our swing door).
local function takeDoor(site: string, near: Vector3): (CFrame?, Vector3?)
	local best, bd = nil, 3
	for _, p in workspace:GetPartBoundsInRadius(near, 4) do
		if p:IsA("BasePart") and p.Name == "Door" and p:IsDescendantOf(workspace.ViceBay) then
			local d = (p.Position - near).Magnitude
			if d < bd then
				best, bd = p, d
			end
		end
	end
	if best then
		local cf, size = best.CFrame, best.Size
		K.stash("Crime_" .. site, best)
		return cf, size
	end
	return nil, nil
end

-- A glass shop door that swings (SwingDoors: leaf thin along local X, Hinge attribute). Built closed.
-- F = unit frame (LookVector inward), x = door centre (local), w/h = opening.
local function swingDoor(b, parent: Instance, F: CFrame, x: number, w: number, h: number, opts: { [string]: any }?)
	local o = opts or {}
	local g = b.group("ShopDoor", parent)
	-- leaf frame: local X = inward (thin), local Z = along the facade
	local leafCf = F * CFrame.new(x, h / 2 + 0.05, 0.05) * CFrame.Angles(0, math.rad(90), 0)
	local leaf = b.P("DoorLeaf", V(0.18, h - 0.1, w - 0.1), leafCf, o.glass or C(150, 170, 180), M.Glass, { parent = g, Transparency = o.solid and 0 or 0.45 })
	if o.solid then
		leaf.Material = M.Metal
		leaf.Color = o.color or C(70, 74, 80)
		leaf.Transparency = 0
	end
	leaf.CanCollide = false
	local frameCol = o.frame or C(150, 152, 156)
	local function welded(name, size, cf, col, mat)
		local p = b.P(name, size, cf, col, mat, { parent = g, deco = true })
		p.Anchored = false
		p.Massless = true
		local wc = Instance.new("WeldConstraint")
		wc.Part0 = leaf
		wc.Part1 = p
		wc.Parent = p
		return p
	end
	if not o.solid then
		-- aluminium stiles + rails around the glass
		for _, s in { -1, 1 } do
			welded("Stile", V(0.24, h - 0.1, 0.32), leafCf * CFrame.new(0, 0, s * (w / 2 - 0.21)), frameCol, M.Metal)
		end
		welded("Rail", V(0.24, 0.32, w - 0.1), leafCf * CFrame.new(0, h / 2 - 0.21, 0), frameCol, M.Metal)
		welded("KickRail", V(0.24, 0.9, w - 0.1), leafCf * CFrame.new(0, -h / 2 + 0.5, 0), frameCol, M.Metal)
	end
	-- pull handle on both faces, on the free edge (hinge at -w/2)
	for _, s in { -1, 1 } do
		welded("Handle", V(0.08, 1.6, 0.12), leafCf * CFrame.new(s * 0.22, 0, w / 2 - 0.55), C(200, 200, 204), M.Metal)
	end
	if o.sticker then
		local st = welded("Hours", V(0.02, 1.2, 1.0), leafCf * CFrame.new(-0.11, 0.6, w / 2 - 1.3), C(250, 250, 250), M.SmoothPlastic)
		K.sign(st, Enum.NormalId.Right, o.sticker, C(250, 250, 250), C(20, 20, 20), { font = Enum.Font.GothamBold })
	end
	local hinge = (F * CFrame.new(x - w / 2, 0, 0)).Position
	leaf:SetAttribute("Hinge", hinge)
	leaf:SetAttribute("OpenDeg", o.openDeg or 95)
	CS:AddTag(leaf, "MTL_SwingDoor")
	return leaf
end

-- Fluorescent 2x4 troffer + its light (lights are invisible parts with a PointLight).
local function troffer(b, parent, F: CFrame, x: number, d: number, H: number, opts: { [string]: any }?)
	local o = opts or {}
	local cf = F * CFrame.new(x, H - 0.06, -d)
	b.P("TrofferFrame", V(2.2, 0.1, 4.2), cf, C(200, 200, 198), M.SmoothPlastic, { parent = parent, deco = true })
	b.P("TrofferLens", V(1.9, 0.04, 3.9), cf * CFrame.new(0, -0.06, 0), o.color or C(236, 240, 244), M.Neon, { parent = parent, deco = true })
	if o.light ~= false then
		local l = b.P("LightPoint", V(0.2, 0.2, 0.2), cf * CFrame.new(0, -1.2, 0), C(255, 255, 255), M.SmoothPlastic, { parent = parent, deco = true, Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Range = o.range or 17
		pl.Brightness = o.brightness or 0.75
		pl.Color = o.color or C(236, 240, 244)
		pl.Shadows = o.shadows or false
		pl.Parent = l
	end
end

-- Flat sign on a wall: a thin part with text on its outward face. `cf` faces the reader (LookVector = toward them).
local function poster(b, parent, cf: CFrame, w: number, h: number, text: string, bg: Color3, fg: Color3, opts: { [string]: any }?)
	local p = b.P("Poster", V(w, h, 0.04), cf, bg, M.SmoothPlastic, { parent = parent, deco = true })
	K.sign(p, Enum.NormalId.Front, text, bg, fg, opts)
	return p
end

local function domeCam(b, parent, cf: CFrame)
	b.P("CamBase", V(0.9, 0.12, 0.9), cf, C(230, 230, 230), M.SmoothPlastic, { parent = parent, deco = true, shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.Angles(0, 0, math.rad(90)) })
	b.P("CamDome", V(0.7, 0.7, 0.7), cf * CFrame.new(0, -0.15, 0), C(20, 20, 24), M.Glass, { parent = parent, deco = true, shape = Enum.PartType.Ball, Transparency = 0.15 })
end

local function clone(folderPath: { string }, name: string): Model?
	local f: Instance? = SS
	for _, s in folderPath do
		f = f and f:FindFirstChild(s)
	end
	local src = f and f:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m :: Model
end
B.clone = clone

-- Puts a model with its bottom on `cf` (rotation from cf).
local function placeOn(m: any, cf: CFrame, parent: Instance)
	if m:IsA("BasePart") then
		m.CFrame = cf * CFrame.new(0, m.Size.Y / 2, 0)
		m.Parent = parent
		return m
	end
	local bcf, size = m:GetBoundingBox()
	local piv = m:GetPivot()
	local off = bcf:ToObjectSpace(piv)
	m:PivotTo(cf * CFrame.new(0, size.Y / 2, 0) * off)
	m.Parent = parent
	return m
end
B.placeOn = placeOn

---------------------------------------------------------------- shop units (stickups)

-- u: { front = facade centre line at the unit middle (Vector3, y ignored), inward = unit vector into the shop,
--      width = inner width, depth = facade centre -> back wall centre, door = door centre (local x, + = right
--      when facing inward), doorW, doorH }
local function unitFrame(u)
	local o0 = V(u.front.X, 0, u.front.Z) + u.inward * 0.5
	local fy = u.floor or groundY(o0.X + u.inward.X * 9, o0.Z + u.inward.Z * 9, 30)
	local o = o0 + V(0, fy, 0)
	return CFrame.lookAt(o, o + u.inward), fy
end
B.unitFrame = unitFrame

-- The teller line: customer ledge + bulletproof glass with a 2-stud gap (rays and aim pass, bodies don't), raised
-- teller platform, desks, a back partition with a steel door. Returns the clerk + drawer CFrames.
local function tellerLine(b, parent, F: CFrame, W: number, H: number, dc: number, dp: number, o: { [string]: any })
	local g = b.group("TellerLine", parent)
	local L = function(x, y, d)
		return F * CFrame.new(x, y, -d)
	end
	local IW = W - 1.2 -- between the side walls
	local gl = dc + 1.4 -- glass plane
	local LEDGE = 3.6
	local GAP0, GAP1 = 3.9, 5.9
	local GLASS_TOP = 8.4
	local steel = o.counter or C(64, 66, 72)
	local top = o.top or C(176, 170, 160)
	-- customer counter: steel front, laminate ledge
	b.P("CounterFront", V(IW, LEDGE - 0.15, 0.25), L(0, (LEDGE - 0.15) / 2, dc + 0.12), steel, M.Metal, { parent = g })
	b.P("CounterBody", V(IW, LEDGE - 0.15, 1.15), L(0, (LEDGE - 0.15) / 2, dc + 0.25 + 0.575), C(90, 86, 80), M.SmoothPlastic, { parent = g })
	local ledge = b.P("Ledge", V(IW, 0.15, 1.55), L(0, LEDGE - 0.075, dc + 0.7), top, M.SmoothPlastic, { parent = g })
	K.dressPart(ledge, "MTL_CounterWood")
	ledge.Color = top
	b.P("KickPlate", V(IW, 0.45, 0.04), L(0, 0.23, dc - 0.02), C(36, 36, 40), M.DiamondPlate, { parent = g, deco = true })
	-- glass: lip (solid), the gap pane (no collide, no query), the top pane (solid)
	b.P("GlassLip", V(IW, GAP0 - LEDGE, 0.5), L(0, (LEDGE + GAP0) / 2, gl), C(150, 152, 156), M.Metal, { parent = g })
	local mid = b.P("BulletGlass", V(IW, GAP1 - GAP0, 0.35), L(0, (GAP0 + GAP1) / 2, gl), C(170, 196, 190), M.Glass, { parent = g, Transparency = 0.62 })
	mid.CanCollide, mid.CanQuery, mid.CanTouch = false, false, false
	b.P("GlassRail", V(IW, 0.14, 0.42), L(0, GAP1 + 0.07, gl), C(150, 152, 156), M.Metal, { parent = g })
	b.P("BulletGlassTop", V(IW, GLASS_TOP - GAP1 - 0.14, 0.35), L(0, (GAP1 + 0.14 + GLASS_TOP) / 2, gl), C(170, 196, 190), M.Glass, { parent = g, Transparency = 0.62 })
	-- header wall above the glass (signs go here)
	local header = b.P("Header", V(IW, H - GLASS_TOP, 0.6), L(0, (GLASS_TOP + H) / 2, gl), C(200, 196, 186), M.SmoothPlastic, { parent = g })
	K.dressPart(header, "MTL_Drywall")
	-- invisible: nobody climbs over the ledge into the gap (bodies are taller than 2 studs, so this is belt and braces)
	-- windows: mullions, speak grille, deal tray, number plate
	local wins = o.windows or { -IW / 4, IW / 4 }
	for _, s in { -IW / 2 + 0.1, IW / 2 - 0.1 } do
		b.P("Mullion", V(0.2, GLASS_TOP - LEDGE, 0.42), L(s, (LEDGE + GLASS_TOP) / 2, gl), C(150, 152, 156), M.Metal, { parent = g, deco = true })
	end
	for i = 1, #wins - 1 do
		local x = (wins[i] + wins[i + 1]) / 2
		b.P("Mullion", V(0.2, GLASS_TOP - LEDGE, 0.42), L(x, (LEDGE + GLASS_TOP) / 2, gl), C(150, 152, 156), M.Metal, { parent = g, deco = true })
	end
	for i, x in wins do
		-- speak-through grille (a ring of holes reads as one dark disc with a rim)
		b.P("SpeakRim", V(0.06, 1.0, 1.0), L(x, 5.0, gl - 0.19) * CFrame.Angles(0, math.rad(90), 0), C(170, 170, 174), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		b.P("SpeakHoles", V(0.07, 0.8, 0.8), L(x, 5.0, gl - 0.19) * CFrame.Angles(0, math.rad(90), 0), C(30, 30, 32), M.DiamondPlate, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		-- deal tray: steel scoop sunk into the ledge, under the glass
		b.P("DealTray", V(2.4, 0.08, 1.2), L(x, LEDGE + 0.01, gl - 0.45), C(170, 172, 176), M.Metal, { parent = g, deco = true })
		b.P("DealTrayLip", V(2.4, 0.3, 0.08), L(x, LEDGE + 0.12, gl - 1.05), C(150, 152, 156), M.Metal, { parent = g, deco = true })
		local plate = b.P("WindowNo", V(1.6, 0.7, 0.04), L(x, 7.5, gl - 0.2) * CFrame.Angles(0, math.pi, 0), C(30, 32, 36), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(plate, Enum.NormalId.Front, (o.windowLabel or "TELLER ") .. i, C(30, 32, 36), C(250, 214, 80), { lit = true, font = Enum.Font.GothamBold })
		-- per-window "closed" plate on the second window
		if i == 2 and o.closedSecond then
			local cl = b.P("ClosedSign", V(1.4, 0.6, 0.03), L(x, 4.6, gl + 0.2) * CFrame.Angles(0, math.pi, 0), C(200, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
			K.sign(cl, Enum.NormalId.Front, "NEXT WINDOW PLEASE", C(200, 30, 30), C(255, 255, 255), { font = Enum.Font.GothamBold })
		end
	end
	-- teller side: raised platform, desk, monitors, money counter, chair (all deco: nobody goes back there)
	local PLAT = 1.2
	local plat = b.P("TellerFloor", V(IW, PLAT, dp - gl - 0.2), L(0, PLAT / 2, (gl + 0.2 + dp) / 2), C(150, 140, 126), M.SmoothPlastic, { parent = g, deco = true })
	K.dressPart(plat, o.backFloor or "MTL_VinylPlank")
	local deskTop = PLAT + 2.75
	b.P("TellerDesk", V(IW, 0.12, 1.4), L(0, deskTop - 0.06, gl + 0.95), C(170, 164, 154), M.SmoothPlastic, { parent = g, deco = true })
	b.P("TellerDeskBody", V(IW, deskTop - PLAT - 0.12, 0.9), L(0, PLAT + (deskTop - PLAT - 0.12) / 2, gl + 0.7), C(90, 86, 80), M.SmoothPlastic, { parent = g, deco = true })
	for i, x in wins do
		local w = L(x, deskTop, gl + 0.95)
		-- monitor
		b.P("Monitor", V(1.5, 0.95, 0.1), w * CFrame.new(-0.7, 0.85, 0.25) * CFrame.Angles(0, math.rad(200), 0), C(18, 18, 20), M.SmoothPlastic, { parent = g, deco = true })
		local scr = b.P("Screen", V(1.36, 0.82, 0.02), w * CFrame.new(-0.7, 0.85, 0.25) * CFrame.Angles(0, math.rad(200), 0) * CFrame.new(0, 0, 0.06), C(40, 80, 140), M.Neon, { parent = g, deco = true, Transparency = 0.15 })
		local _ = scr
		b.P("MonitorStand", V(0.2, 0.4, 0.2), w * CFrame.new(-0.7, 0.2, 0.25), C(18, 18, 20), M.SmoothPlastic, { parent = g, deco = true })
		b.P("Keyboard", V(1.2, 0.06, 0.4), w * CFrame.new(-0.4, 0.03, -0.25) * CFrame.Angles(0, math.rad(15), 0), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
		-- bill counter: body + hopper + display
		b.P("BillCounter", V(0.9, 0.55, 0.8), w * CFrame.new(0.75, 0.28, 0), C(40, 42, 46), M.SmoothPlastic, { parent = g, deco = true })
		b.P("BillHopper", V(0.6, 0.12, 0.35), w * CFrame.new(0.75, 0.6, 0.15) * CFrame.Angles(math.rad(-25), 0, 0), C(60, 62, 66), M.SmoothPlastic, { parent = g, deco = true })
		b.P("BillDisplay", V(0.4, 0.14, 0.02), w * CFrame.new(0.75, 0.38, -0.41), C(60, 220, 120), M.Neon, { parent = g, deco = true })
		-- receipt printer + a few bill straps
		b.P("Printer", V(0.5, 0.35, 0.5), w * CFrame.new(1.55, 0.18, 0.2), C(225, 225, 220), M.SmoothPlastic, { parent = g, deco = true })
		for k = 0, 2 do
			b.P("Strap", V(0.62, 0.08, 0.28), w * CFrame.new(0.1 + k * 0.2, 0.05 + k * 0.08, 0.45) * CFrame.Angles(0, math.rad(k * 9), 0), C(116, 170, 100), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- stool
		b.P("StoolSeat", V(1.3, 0.25, 1.3), L(x + (if i == 1 then 1.6 else -1.6), PLAT + 2.2, gl + 2.6), C(30, 30, 34), M.Fabric, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = L(x + (if i == 1 then 1.6 else -1.6), PLAT + 2.2, gl + 2.6) * CFrame.Angles(0, 0, math.rad(90)) })
		b.P("StoolPost", V(0.18, 2.1, 0.18), L(x + (if i == 1 then 1.6 else -1.6), PLAT + 1.05, gl + 2.6), C(120, 120, 124), M.Metal, { parent = g, deco = true })
	end
	-- back partition + steel office door with a vision slot
	local IWp = IW
	local doorX = o.officeDoor or (IW / 2 - 2.2)
	local left = doorX - 1.8 + IWp / 2
	local right = IWp / 2 - (doorX + 1.8)
	if left > 0.1 then
		local w1 = b.P("Partition", V(left, H, 0.5), L(-IWp / 2 + left / 2, H / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = g })
		K.dressPart(w1, "MTL_Drywall")
	end
	if right > 0.1 then
		local w2 = b.P("Partition", V(right, H, 0.5), L(IWp / 2 - right / 2, H / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = g })
		K.dressPart(w2, "MTL_Drywall")
	end
	b.P("PartitionHead", V(3.6, H - 8.2, 0.5), L(doorX, (8.2 + H) / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = g })
	b.P("OfficeDoor", V(3.4, 8.0 - PLAT, 0.25), L(doorX, PLAT + (8.0 - PLAT) / 2, dp - 0.05), C(84, 90, 98), M.Metal, { parent = g })
	b.P("DoorSlot", V(0.5, 1.6, 0.27), L(doorX - 0.9, 5.8, dp - 0.05), C(30, 40, 44), M.Glass, { parent = g, deco = true, Transparency = 0.2 })
	b.P("DoorKnob", V(0.25, 0.25, 0.4), L(doorX + 1.3, PLAT + 3.0, dp - 0.25), C(190, 190, 194), M.Metal, { parent = g, deco = true })
	local eo = b.P("EmployeesOnly", V(2.2, 0.6, 0.03), L(doorX, PLAT + 5.8, dp - 0.19) * CFrame.Angles(0, math.pi, 0), C(200, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
	K.sign(eo, Enum.NormalId.Front, "EMPLOYEES ONLY", C(200, 30, 30), C(255, 255, 255), { font = Enum.Font.GothamBold })
	-- time-lock safe in the teller corner + filing cabinet
	local sx = -IW / 2 + 1.3
	b.P("SafeBox", V(2.2, 3.2, 2.0), L(sx, PLAT + 1.6, dp - 1.3), C(60, 64, 70), M.Metal, { parent = g, deco = true })
	b.P("SafeDial", V(0.12, 0.6, 0.6), L(sx + 0.3, PLAT + 2.2, dp - 2.32) * CFrame.Angles(0, math.rad(90), 0), C(190, 190, 194), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
	b.P("SafeHandle", V(0.7, 0.12, 0.12), L(sx - 0.4, PLAT + 1.6, dp - 2.35), C(190, 190, 194), M.Metal, { parent = g, deco = true })
	b.P("Cabinet", V(1.6, 4.4, 2.0), L(IW / 2 - 1.0, PLAT + 2.2, dp - 1.3), C(120, 124, 128), M.Metal, { parent = g, deco = true })
	for k = 0, 2 do
		b.P("CabinetHandle", V(0.6, 0.1, 0.1), L(IW / 2 - 1.0, PLAT + 0.9 + k * 1.4, dp - 2.33), C(200, 200, 204), M.Metal, { parent = g, deco = true })
	end
	local clerk = L(wins[1], PLAT, gl + 1.75) * CFrame.Angles(0, math.pi, 0)
	local drawer = L(wins[1], LEDGE, gl - 0.72)
	return clerk, drawer, gl
end

-- Common room shell: tiled floor, drop ceiling, side walls, back wall skin, lights.
local function shell(b, parent, F: CFrame, W: number, D: number, H: number, o: { [string]: any })
	local g = b.group("Shell", parent)
	local fl = b.P("FloorTile", V(W - 0.1, 0.1, D - 0.1), F * CFrame.new(0, 0.05, -D / 2), C(220, 216, 206), M.SmoothPlastic, { parent = g })
	K.dressPart(fl, o.floor or "MTL_VCTTile")
	if o.floorTint then
		fl.Color = o.floorTint
	end
	local ce = b.P("CeilingTile", V(W - 0.1, 0.3, D - 0.1), F * CFrame.new(0, H + 0.15, -D / 2), C(220, 220, 216), M.SmoothPlastic, { parent = g })
	K.dressPart(ce, "MTL_CeilingTile")
	for _, s in { -1, 1 } do
		local w = b.P("SideWall", V(0.6, H, D - 0.06), F * CFrame.new(s * (W / 2 - 0.32), H / 2, -D / 2), C(200, 196, 186), M.SmoothPlastic, { parent = g })
		K.dressPart(w, o.wall or "MTL_Drywall")
		if o.wallTint then
			w.Color = o.wallTint
		end
		b.P("Baseboard", V(0.08, 0.45, D - 0.2), F * CFrame.new(s * (W / 2 - 0.66), 0.33, -D / 2), C(48, 46, 44), M.SmoothPlastic, { parent = g, deco = true })
		if o.wainscot then
			b.P("Wainscot", V(0.05, 3.2, D - 0.3), F * CFrame.new(s * (W / 2 - 0.645), 1.7, -D / 2), o.wainscot, M.SmoothPlastic, { parent = g, deco = true })
			b.P("ChairRail", V(0.1, 0.18, D - 0.3), F * CFrame.new(s * (W / 2 - 0.66), 3.35, -D / 2), C(60, 58, 54), M.SmoothPlastic, { parent = g, deco = true })
		end
	end
	local bw = b.P("BackSkin", V(W - 1.3, H, 0.3), F * CFrame.new(0, H / 2, -(D - 0.2)), C(200, 196, 186), M.SmoothPlastic, { parent = g })
	K.dressPart(bw, o.wall or "MTL_Drywall")
	-- front wall inner skin around the shopfront (stops seeing the facade's back faces); leaves the door + window
	return g
end

-- Lobby dressing shared by the teller shops.
local function lobby(b, parent, F: CFrame, W: number, H: number, dc: number, doorX: number, o: { [string]: any })
	local g = b.group("Lobby", parent)
	local L = function(x, y, d)
		return F * CFrame.new(x, y, -d)
	end
	local IW = W - 1.2
	-- the side away from the door gets the writing ledge; the door side gets chairs
	local ledgeSide = if doorX < 0 then 1 else -1
	local wx = ledgeSide * (IW / 2 - 0.6)
	if not o.noLedge then
		b.P("WriteLedge", V(1.2, 0.14, 6), L(wx, 3.4, dc - 4.2), C(150, 146, 138), M.SmoothPlastic, { parent = g })
		for _, dz in { -2.6, 2.6 } do
			b.P("LedgeBracket", V(1.0, 0.8, 0.12), L(wx + ledgeSide * 0.05, 2.95, dc - 4.2 + dz), C(60, 60, 64), M.Metal, { parent = g, deco = true })
		end
		-- slips + a pen on a chain
		for k = 0, 3 do
			b.P("Slip", V(0.55, 0.02, 0.8), L(wx - ledgeSide * 0.1, 3.49 + k * 0.012, dc - 6.2 + k * 0.9) * CFrame.Angles(0, math.rad(k * 7 - 10), 0), C(236, 232, 214), M.SmoothPlastic, { parent = g, deco = true })
		end
		b.P("Pen", V(0.06, 0.06, 0.6), L(wx, 3.5, dc - 3.4) * CFrame.Angles(0, math.rad(30), 0), C(20, 40, 160), M.SmoothPlastic, { parent = g, deco = true })
		-- brochure rack above the ledge
		for k = 0, 2 do
			local rcf = L(ledgeSide * (IW / 2 - 0.12), 5.2, dc - 6.0 + k * 1.8) * CFrame.Angles(0, ledgeSide * math.rad(90), 0)
			b.P("BrochureRack", V(1.4, 1.1, 0.25), rcf, C(200, 200, 204), M.Glass, { parent = g, deco = true, Transparency = 0.4 })
			local cols = { C(220, 60, 40), C(40, 110, 200), C(240, 190, 40) }
			b.P("Brochure", V(1.1, 0.9, 0.06), rcf * CFrame.new(0, 0.05, 0), cols[k + 1], M.SmoothPlastic, { parent = g, deco = true })
		end
	end
	-- queue stanchions in front of window 1
	local winX = (o.windows or { -IW / 4, IW / 4 })[1]
	local posts = {}
	for k = 0, 2 do
		local pcf = L(winX + 2.2, 0.1, dc - 2.2 - k * 2.4)
		local post = clone({ "MTL_PropKit" }, "StanchionPost")
		if post and post:IsA("BasePart") then
			post.Size = post.Size * (3.2 / post.Size.Y) -- the kit mesh is 50 studs tall
		end
		if post then
			placeOn(post, pcf, g)
		else
			b.P("StanchionPost", V(0.2, 3.2, 0.2), pcf * CFrame.new(0, 1.6, 0), C(190, 190, 194), M.Metal, { parent = g })
			b.P("StanchionBase", V(0.12, 1.1, 1.1), pcf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), C(40, 40, 44), M.Metal, { parent = g, shape = Enum.PartType.Cylinder })
		end
		table.insert(posts, pcf)
	end
	for k = 1, #posts - 1 do
		local a, c = posts[k].Position + V(0, 2.9, 0), posts[k + 1].Position + V(0, 2.9, 0)
		local mid = (a + c) / 2 - V(0, 0.15, 0)
		b.P("Belt", V(0.06, 0.18, (c - a).Magnitude), CFrame.lookAt(mid, c - V(0, 0.15, 0)), C(150, 20, 30), M.Fabric, { parent = g, deco = true })
	end
	-- two plastic chairs on the door side, against the wall
	if not o.noChairs then
		local cx = -ledgeSide * (IW / 2 - 1.0)
		for k = 0, 1 do
			local ccf = L(cx, 0, dc - 5.0 - k * 1.9) * CFrame.Angles(0, -ledgeSide * math.rad(90), 0)
			b.P("ChairSeat", V(1.5, 0.15, 1.5), ccf * CFrame.new(0, 1.55, 0), o.chair or C(30, 70, 140), M.Plastic, { parent = g })
			b.P("ChairBack", V(1.5, 1.6, 0.15), ccf * CFrame.new(0, 2.4, 0.72) * CFrame.Angles(math.rad(-8), 0, 0), o.chair or C(30, 70, 140), M.Plastic, { parent = g })
			for _, lx in { -0.65, 0.65 } do
				for _, lz in { -0.65, 0.65 } do
					b.P("ChairLeg", V(0.1, 1.5, 0.1), ccf * CFrame.new(lx, 0.75, lz), C(150, 150, 154), M.Metal, { parent = g, deco = true })
				end
			end
		end
	end
	-- floor mat at the door, trash can
	b.P("DoorMat", V(4.0, 0.05, 2.6), L(doorX, 0.12, 1.6), C(40, 40, 44), M.Fabric, { parent = g, deco = true })
	local tx = if doorX < 0 then doorX + 3.0 else doorX - 3.0
	b.P("TrashCan", V(1.6, 1.2, 1.2), L(tx, 0.85, 0.9) * CFrame.Angles(0, 0, math.rad(90)), C(60, 62, 66), M.Plastic, { parent = g, shape = Enum.PartType.Cylinder })
	-- cameras
	domeCam(b, g, L(-IW / 2 + 1.0, H - 0.06, dc - 0.8))
	domeCam(b, g, L(IW / 2 - 1.0, H - 0.06, 1.2))
	return g
end

-- One teller shop. kind = "CheckCashing" | "CashForGold"
local function tellerShop(id: string, kind: string, u)
	local site = newSite(id, kind)
	local F, fy = unitFrame(u)
	local W, D = u.width, u.depth - 1.0
	local H = 10.6
	local b = K.builder(site)
	local stashed = clearBox(id, F, W, D, H)
	local doorCf, doorSize = takeDoor(id, (F * CFrame.new(u.door, 4.5, -0.3)).Position)
	local doorW = if doorSize then math.max(doorSize.X, doorSize.Z) else 4.5
	local doorH = if doorSize then doorSize.Y else 9
	local _ = doorCf
	local isGold = kind == "CashForGold"
	shell(b, site, F, W, D, H, {
		floor = if isGold then "MTL_VinylPlank" else "MTL_VCTTile",
		wainscot = if isGold then C(40, 36, 34) else C(70, 90, 110),
	})
	local dc, dp = 12.5, 22.5
	local clerk, drawer = tellerLine(b, site, F, W, H, dc, dp, {
		windowLabel = if isGold then "WINDOW " else "TELLER ",
		closedSecond = true,
		counter = if isGold then C(30, 30, 34) else C(64, 66, 72),
	})
	lobby(b, site, F, W, H, dc, u.door, { noChairs = isGold, noLedge = isGold })
	swingDoor(b, site, F, u.door, doorW, doorH, { sticker = if isGold then "OPEN 10-7\nWE BUY GOLD" else "OPEN 9-7\nMON - SAT" })
	-- lights: two over the lobby, two over the tellers, one in the back
	local g = b.group("Lights", site)
	troffer(b, g, F, -W / 4, 4.5, H, { shadows = true })
	troffer(b, g, F, W / 4, 8.5, H)
	troffer(b, g, F, -W / 4, dc + 5.5, H, { brightness = 0.6 })
	troffer(b, g, F, W / 4, dc + 5.5, H, { light = false })
	-- signs + posters
	local sg = b.group("Signs", site)
	local L = function(x, y, d)
		return F * CFrame.new(x, y, -d)
	end
	local IW = W - 1.2
	local gl = dc + 1.4
	local headerText = if isGold then '<font color="#F2C230">CASH 4 GOLD</font>  ·  WE PAY MORE' else "ROYCE FINANCIAL  ·  CHECKS CASHED"
	poster(b, sg, L(0, 9.5, gl - 0.32) * CFrame.Angles(0, math.pi, 0), IW - 1, 1.3, headerText, C(24, 26, 30), C(240, 240, 236), { lit = true })
	local wallSide = function(side: number, d: number, y: number)
		-- a poster flat on a side wall, facing into the room
		return L(side * (IW / 2 - 0.03), y, d) * CFrame.Angles(0, side * math.rad(90), 0)
	end
	if isGold then
		poster(b, sg, wallSide(-1, 6, 6.2), 4.2, 2.6, "WE BUY\nGOLD · SILVER · DIAMONDS\nWATCHES · PHONES · GAME SYSTEMS", C(20, 20, 22), C(242, 194, 48))
		poster(b, sg, wallSide(1, 4.5, 6.4), 3.2, 2.0, "TOP $$$\nPAID TODAY", C(242, 194, 48), C(20, 20, 22))
		poster(b, sg, wallSide(1, 9.0, 6.0), 2.4, 1.6, "ALL SALES FINAL\nID REQUIRED", C(236, 236, 230), C(30, 30, 30))
	else
		poster(b, sg, wallSide(-1, 5, 6.6), 4.4, 2.4, "WE CASH ALL CHECKS\nPAYROLL · GOVERNMENT · TAX REFUND · INSURANCE", C(30, 90, 170), C(255, 255, 255))
		poster(b, sg, wallSide(1, 4.0, 6.8), 3.0, 1.8, "MONEY ORDERS\n99¢", C(250, 210, 50), C(20, 20, 20))
		poster(b, sg, wallSide(1, 8.0, 6.8), 3.0, 1.8, "BILL PAY\nPHONE · LIGHTS · CABLE", C(236, 236, 230), C(30, 60, 140))
		poster(b, sg, wallSide(-1, 10.2, 6.6), 2.6, 2.4, "PAYDAY\nADVANCE\nUP TO $500", C(40, 150, 70), C(255, 255, 255))
	end
	-- the rules everyone in Miami has seen on that glass
	poster(b, sg, L(u.door + (if u.door < 0 then 2.6 else -2.6), 7.6, 0.25) * CFrame.Angles(0, math.pi, 0), 2.0, 1.4, "NO HATS\nNO HOODS\nNO SHADES", C(200, 30, 30), C(255, 255, 255))
	poster(b, sg, L(IW / 2 - 0.9, 7.0, gl - 0.21) * CFrame.Angles(0, math.pi, 0), 1.2, 0.8, "SMILE\nYOU'RE ON CAMERA", C(250, 210, 50), C(20, 20, 20))
	if isGold then
		-- display cases along the left wall: glass top, felt, gold chains, rings, watches
		local cg = b.group("Cases", site)
		for k = 0, 1 do
			local ccf = L(-IW / 2 + 1.3, 0, 3.4 + k * 4.4)
			b.P("CaseBase", V(2.2, 3.0, 4.0), ccf * CFrame.new(0, 1.5, 0), C(30, 28, 28), M.Wood, { parent = cg })
			b.P("CaseFelt", V(2.0, 0.05, 3.8), ccf * CFrame.new(0, 3.03, 0), C(20, 30, 60), M.Fabric, { parent = cg, deco = true })
			b.P("CaseGlass", V(2.2, 0.8, 4.0), ccf * CFrame.new(0, 3.42, 0), C(200, 220, 230), M.Glass, { parent = cg, Transparency = 0.7 })
			local rng = Random.new(77 + k)
			for j = 1, 9 do
				local jx, jz = rng:NextNumber(-0.7, 0.7), rng:NextNumber(-1.6, 1.6)
				local kind2 = rng:NextInteger(1, 3)
				if kind2 == 1 then -- chain: a flat gold loop
					b.P("Chain", V(0.06, 0.5, 0.5), ccf * CFrame.new(jx, 3.08, jz) * CFrame.Angles(0, 0, math.rad(90)), C(222, 176, 60), M.Foil, { parent = cg, deco = true, shape = Enum.PartType.Cylinder })
				elseif kind2 == 2 then -- ring on a stand
					b.P("RingStand", V(0.2, 0.25, 0.2), ccf * CFrame.new(jx, 3.17, jz), C(20, 20, 24), M.Fabric, { parent = cg, deco = true })
					b.P("Ring", V(0.04, 0.2, 0.2), ccf * CFrame.new(jx, 3.36, jz), C(230, 186, 70), M.Foil, { parent = cg, deco = true, shape = Enum.PartType.Cylinder })
				else -- watch
					b.P("WatchFace", V(0.05, 0.3, 0.3), ccf * CFrame.new(jx, 3.1, jz) * CFrame.Angles(0, 0, math.rad(90)), C(210, 210, 214), M.Metal, { parent = cg, deco = true, shape = Enum.PartType.Cylinder })
					b.P("WatchBand", V(0.14, 0.03, 0.6), ccf * CFrame.new(jx, 3.06, jz), C(40, 40, 44), M.Metal, { parent = cg, deco = true })
				end
			end
		end
		-- pawn wall behind the glass: TVs, guitar, speakers, sneaker boxes, a game console
		local pw = b.group("PawnWall", site)
		local wd = dp - 0.35
		local function onWall(x, y)
			return L(x, y, wd) * CFrame.Angles(0, math.pi, 0)
		end
		b.P("WallShelf", V(IW - 4.5, 0.15, 1.2), L(-1.6, 6.2, wd - 0.6), C(90, 70, 50), M.Wood, { parent = pw, deco = true })
		b.P("TV", V(3.0, 1.8, 0.2), onWall(-3.6, 7.4) * CFrame.new(0, 0, -0.5), C(16, 16, 18), M.SmoothPlastic, { parent = pw, deco = true })
		b.P("TVScreen", V(2.8, 1.6, 0.02), onWall(-3.6, 7.4) * CFrame.new(0, 0, -0.61), C(30, 50, 90), M.Glass, { parent = pw, deco = true })
		b.P("Speaker", V(0.9, 1.4, 0.9), onWall(-0.6, 7.0) * CFrame.new(0, 0, -0.6), C(24, 24, 26), M.Fabric, { parent = pw, deco = true })
		b.P("Speaker", V(0.9, 1.4, 0.9), onWall(0.6, 7.0) * CFrame.new(0, 0, -0.6), C(24, 24, 26), M.Fabric, { parent = pw, deco = true })
		b.P("Console", V(1.2, 0.35, 1.0), onWall(2.2, 6.45) * CFrame.new(0, 0, -0.6), C(240, 240, 240), M.SmoothPlastic, { parent = pw, deco = true })
		for k = 0, 2 do
			b.P("ShoeBox", V(1.4, 0.55, 0.9), L(-4.4, 1.5 + 0.28 + k * 0.56, wd - 0.6), if k == 1 then C(230, 110, 30) else C(220, 220, 214), M.SmoothPlastic, { parent = pw, deco = true })
		end
		-- guitar: body + neck, leaning on the wall
		local gcf = L(3.9, 1.2, wd - 0.4) * CFrame.Angles(math.rad(-10), math.pi, 0)
		b.P("GuitarBody", V(1.5, 1.9, 0.35), gcf * CFrame.new(0, 1.2, 0), C(150, 40, 30), M.Wood, { parent = pw, deco = true })
		b.P("GuitarNeck", V(0.22, 2.6, 0.15), gcf * CFrame.new(0, 3.4, 0), C(60, 40, 30), M.Wood, { parent = pw, deco = true })
		b.P("GuitarHead", V(0.4, 0.6, 0.15), gcf * CFrame.new(0, 4.95, 0), C(30, 24, 20), M.Wood, { parent = pw, deco = true })
		-- a gold scale on the teller desk
		b.P("Scale", V(1.0, 0.25, 0.8), L(IW / 4, 1.2 + 2.75 + 0.12, gl + 0.95), C(40, 40, 44), M.SmoothPlastic, { parent = pw, deco = true })
		b.P("ScalePan", V(0.06, 0.7, 0.7), L(IW / 4, 1.2 + 2.75 + 0.28, gl + 0.95) * CFrame.Angles(0, 0, math.rad(90)), C(200, 200, 204), M.Metal, { parent = pw, deco = true, shape = Enum.PartType.Cylinder })
	end
	-- points
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = site
	point(pts, "Clerk", clerk)
	point(pts, "Drawer", drawer)
	point(pts, "Center", F * CFrame.new(0, 0.1, -6))
	point(pts, "Door", F * CFrame.new(u.door, 0.1, 1.2))
	site:SetAttribute("Floor", fy)
	site.Parent = sitesRoot()
	return string.format("%s floor %.2f stashed %d parts=%d", id, fy, stashed, b.n)
end

B.Units = {
	-- Check Cashing (Glades): facade x -1745 facing west, unit z -206.4..-190.3, door z -202
	CheckCashingN = { front = V(-1745, 0, -198.35), inward = V(1, 0, 0), width = 16.1, depth = 35, door = -3.65, floor = 6.4 },
	-- Check Cashing (south): facade z 395.5 facing +Z, unit x -1510.5..-1494, door x -1505.8
	CheckCashingS = { front = V(-1502.25, 0, 395.5), inward = V(0, 0, -1), width = 16.5, depth = 35, door = -3.55, floor = 6.4 },
	-- Cash 4 Gold (south): facade x -1412.9 facing +X, unit z 359.5..374.8, door z 371.6
	CashForGoldS = { front = V(-1412.9, 0, 367.15), inward = V(-1, 0, 0), width = 15.3, depth = 34.1, door = -4.45, floor = 6.4 },
	-- Liberty Laundromat ("WASH • DRY • FOLD", Hood shops at -1438,-930): facade x -1415 facing +X,
	-- unit z -920.9..-907.7, door z -910.4 (the old -1129,-367 unit is now Royce's Cash 4 Gold)
	Laundromat = { front = V(-1415, 0, -914.3), inward = V(-1, 0, 0), width = 13.2, depth = 34.5, door = -3.9, floor = 6.4 },
}

function B.stickups()
	local out = {}
	table.insert(out, tellerShop("CheckCashingN", "CheckCashing", B.Units.CheckCashingN))
	task.wait()
	table.insert(out, tellerShop("CheckCashingS", "CheckCashing", B.Units.CheckCashingS))
	task.wait()
	table.insert(out, tellerShop("CashForGoldS", "CashForGold", B.Units.CashForGoldS))
	return table.concat(out, "\n")
end

---------------------------------------------------------------- Liberty Laundromat (Benny's back room = the wash)

-- Front: washers down the middle, dryers stacked on the right wall, folding table, change machine, soap vending,
-- plastic chairs. Back: a wall with a Dutch door (half door with a shelf). Benny sits behind it; the shelf is the
-- "Counter" point where the player stands to wash.
function B.laundromat()
	local id = "Laundromat"
	local u = B.Units.Laundromat
	local site = newSite(id, "Laundromat")
	local F, fy = unitFrame(u)
	local W, D = u.width, u.depth - 1.0
	local H = 10.6
	local b = K.builder(site)
	local stashed = clearBox(id, F, W, D, H)
	local _, doorSize = takeDoor(id, (F * CFrame.new(u.door, 4.5, -0.3)).Position)
	local doorW = if doorSize then math.max(doorSize.X, doorSize.Z) else 4.5
	local doorH = if doorSize then doorSize.Y else 9
	shell(b, site, F, W, D, H, { floor = "MTL_VCTTile", wall = "MTL_WallTile", wainscot = C(40, 120, 150) })
	swingDoor(b, site, F, u.door, doorW, doorH, { sticker = "OPEN 6AM - 11PM\nLAST WASH 10PM" })
	local L = function(x, y, d)
		return F * CFrame.new(x, y, -d)
	end
	local IW = W - 1.2
	local g = b.group("Machines", site)
	local white, steel, dark = C(226, 226, 222), C(170, 172, 176), C(30, 32, 36)
	-- front-loader: box, round glass door with chrome ring, control strip, coin slot
	local function washer(cf: CFrame, big: boolean)
		local s = if big then 3.0 else 2.6
		b.P("WasherBody", V(s, s + 0.4, 2.6), cf * CFrame.new(0, (s + 0.4) / 2, 0), white, M.SmoothPlastic, { parent = g })
		b.P("WasherPanel", V(s, 0.6, 0.1), cf * CFrame.new(0, s + 0.1, -1.31), steel, M.Metal, { parent = g, deco = true })
		b.P("CoinSlot", V(0.25, 0.35, 0.05), cf * CFrame.new(s / 2 - 0.4, s + 0.1, -1.37), dark, M.Metal, { parent = g, deco = true })
		b.P("Price", V(0.7, 0.3, 0.03), cf * CFrame.new(-s / 2 + 0.6, s + 0.1, -1.37), C(30, 110, 60), M.Neon, { parent = g, deco = true })
		b.P("DoorRing", V(0.12, 1.9, 1.9), cf * CFrame.new(0, (s + 0.4) / 2 - 0.15, -1.33) * CFrame.Angles(0, math.rad(90), 0), steel, M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		b.P("DoorGlass", V(0.14, 1.55, 1.55), cf * CFrame.new(0, (s + 0.4) / 2 - 0.15, -1.34) * CFrame.Angles(0, math.rad(90), 0), C(60, 70, 80), M.Glass, { parent = g, deco = true, shape = Enum.PartType.Cylinder, Transparency = 0.3 })
	end
	local function dryerStack(cf: CFrame)
		for k = 0, 1 do
			local y = 0.6 + k * 3.4
			b.P("DryerBody", V(3.2, 3.3, 2.8), cf * CFrame.new(0, y + 1.65, 0), steel, M.Metal, { parent = g })
			b.P("DryerDoor", V(0.12, 2.3, 2.3), cf * CFrame.new(0, y + 1.6, -1.42) * CFrame.Angles(0, math.rad(90), 0), C(40, 44, 50), M.Glass, { parent = g, deco = true, shape = Enum.PartType.Cylinder, Transparency = 0.15 })
			b.P("DryerRim", V(0.1, 2.6, 2.6), cf * CFrame.new(0, y + 1.6, -1.41) * CFrame.Angles(0, math.rad(90), 0), C(210, 210, 214), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
			b.P("DryerTimer", V(0.8, 0.3, 0.04), cf * CFrame.new(1.0, y + 3.05, -1.42), C(150, 50, 24), M.Neon, { parent = g, deco = true })
		end
		b.P("DryerPlinth", V(3.2, 0.6, 2.8), cf * CFrame.new(0, 0.3, 0), C(60, 62, 66), M.Metal, { parent = g })
	end
	-- dryers on the right wall (facing into the room), from d 3 to 21
	for k = 0, 4 do
		local d = 4.2 + k * 3.35
		dryerStack(L(IW / 2 - 1.45, 0, d) * CFrame.Angles(0, math.rad(90), 0))
	end
	local narrow = IW < 14
	local foldD, foldLen = 17.5, 7.0
	if narrow then
		-- narrow unit: one row of washers down the left wall, dryers down the right, an aisle between
		for k = 0, 5 do
			washer(L(-IW / 2 + 1.35, 0, 4.4 + k * 2.75) * CFrame.Angles(0, math.rad(-90), 0), k < 2)
		end
		b.P("WasherCap", V(2.7, 0.1, 16.6), L(-IW / 2 + 1.35, 3.45, 11.3), C(150, 150, 154), M.Metal, { parent = g, deco = true })
		foldD, foldLen = 21.6, 4.6
	else
		-- an island of back-to-back washers down the middle-left (two rows of 4)
		local ix = -1.6
		for k = 0, 3 do
			local d = 6.0 + k * 2.75
			washer(L(ix - 1.35, 0, d) * CFrame.Angles(0, math.rad(90), 0), false)
			washer(L(ix + 1.35, 0, d) * CFrame.Angles(0, math.rad(-90), 0), false)
		end
		b.P("IslandCap", V(5.4, 0.12, 11.4), L(ix, 3.06, 10.1), C(150, 150, 154), M.Metal, { parent = g, deco = true })
		-- big washers along the left wall
		for k = 0, 2 do
			washer(L(-IW / 2 + 1.4, 0, 5.0 + k * 3.2) * CFrame.Angles(0, math.rad(-90), 0), true)
		end
	end
	-- folding table + carts
	local fg = b.group("Folding", site)
	b.P("FoldTop", V(2.6, 0.2, foldLen), L(-IW / 2 + 1.4, 3.0, foldD), C(200, 200, 196), M.SmoothPlastic, { parent = fg })
	for _, lz in { -(foldLen / 2 - 0.3), foldLen / 2 - 0.3 } do
		b.P("FoldLeg", V(2.4, 2.9, 0.2), L(-IW / 2 + 1.4, 1.45, foldD + lz), C(120, 120, 124), M.Metal, { parent = fg })
	end
	for k = 0, 1 do
		local ccf = L(1.6 + k * 2.0, 0, 18.5 + k * 1.2) * CFrame.Angles(0, math.rad(10 + k * 25), 0)
		b.P("CartBasket", V(1.8, 1.4, 2.4), ccf * CFrame.new(0, 2.2, 0), C(170, 172, 176), M.Metal, { parent = fg, Transparency = 0.25 })
		b.P("CartPole", V(0.12, 4.6, 0.12), ccf * CFrame.new(0, 2.3, 1.15), C(170, 172, 176), M.Metal, { parent = fg, deco = true })
		b.P("CartHook", V(1.9, 0.1, 0.1), ccf * CFrame.new(0, 4.6, 1.15), C(170, 172, 176), M.Metal, { parent = fg, deco = true })
		b.P("Clothes", V(1.5, 0.5, 2.0), ccf * CFrame.new(0, 2.8, 0), if k == 0 then C(60, 90, 160) else C(200, 190, 170), M.Fabric, { parent = fg, deco = true })
	end
	-- change machine + soap vending on the front-left wall
	local vg = b.group("Vending", site)
	local vcf = L(-IW / 2 + 0.95, 0, 1.4) * CFrame.Angles(0, math.rad(-90), 0)
	b.P("ChangeMachine", V(1.8, 5.2, 1.4), vcf * CFrame.new(0, 2.6, 0), C(40, 80, 150), M.Metal, { parent = vg })
	local cm = b.P("ChangeLabel", V(1.4, 0.5, 0.03), vcf * CFrame.new(0, 4.4, -0.72), C(250, 210, 50), M.SmoothPlastic, { parent = vg, deco = true })
	K.sign(cm, Enum.NormalId.Front, "CHANGE", C(250, 210, 50), C(20, 20, 20), { lit = true })
	b.P("BillSlot", V(0.5, 0.2, 0.05), vcf * CFrame.new(0, 3.4, -0.72), C(20, 20, 20), M.Metal, { parent = vg, deco = true })
	-- seating: plastic chairs facing the washers
	for k = 0, 2 do
		local ccf = if narrow then L(0.4 + k * 1.6, 0, 1.0) else L(2.0, 0, 3.0 + k * 1.7) * CFrame.Angles(0, math.rad(-90), 0)
		b.P("ChairSeat", V(1.5, 0.15, 1.5), ccf * CFrame.new(0, 1.55, 0), C(220, 120, 30), M.Plastic, { parent = vg })
		b.P("ChairBack", V(1.5, 1.6, 0.15), ccf * CFrame.new(0, 2.4, 0.72) * CFrame.Angles(math.rad(-8), 0, 0), C(220, 120, 30), M.Plastic, { parent = vg })
	end
	-- signs
	local sg = b.group("Signs", site)
	local wallSide = function(side: number, d: number, y: number)
		return L(side * (IW / 2 - 0.03), y, d) * CFrame.Angles(0, side * math.rad(90), 0)
	end
	poster(b, sg, wallSide(-1, 11.0, 7.4), 4.2, 1.6, "WASH $3.50 · DRY 25¢ / 8 MIN", C(40, 120, 150), C(255, 255, 255))
	poster(b, sg, wallSide(-1, 15.8, 7.0), 2.6, 2.0, "NOT RESPONSIBLE\nFOR LOST ITEMS", C(236, 236, 230), C(30, 30, 30))
	poster(b, sg, wallSide(-1, 1.4, 7.6), 1.8, 1.0, "NO DYEING\nNO PETS", C(200, 30, 30), C(255, 255, 255))
	-- back wall with Benny's Dutch door (the wash). Room behind: d 24.5..D
	local dp = 24.5
	local bdx = 2.6 -- Dutch door centre
	local bg = b.group("BackRoom", site)
	local leftW = (bdx - 1.8) + IW / 2
	local rightW = IW / 2 - (bdx + 1.8)
	local w1 = b.P("BackWall", V(leftW, H, 0.6), L(-IW / 2 + leftW / 2, H / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = bg })
	K.dressPart(w1, "MTL_WallTile")
	local w2 = b.P("BackWall", V(rightW, H, 0.6), L(IW / 2 - rightW / 2, H / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = bg })
	K.dressPart(w2, "MTL_WallTile")
	b.P("BackWallHead", V(3.6, H - 8.0, 0.6), L(bdx, (8 + H) / 2, dp), C(200, 196, 186), M.SmoothPlastic, { parent = bg })
	-- bottom half door (closed, solid) + shelf; top half swung open into the back room
	b.P("DutchLower", V(3.4, 3.6, 0.3), L(bdx, 1.8, dp), C(110, 70, 44), M.Wood, { parent = bg })
	b.P("DutchShelf", V(3.6, 0.15, 1.2), L(bdx, 3.68, dp - 0.2), C(150, 110, 70), M.Wood, { parent = bg })
	b.P("DutchUpper", V(3.4, 4.2, 0.3), L(bdx + 1.7, 5.9, dp + 1.7) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0, 0), C(110, 70, 44), M.Wood, { parent = bg })
	local pv = b.P("Private", V(2.0, 0.55, 0.03), L(bdx, 8.6, dp - 0.32) * CFrame.Angles(0, math.pi, 0), C(30, 30, 34), M.SmoothPlastic, { parent = bg, deco = true })
	K.sign(pv, Enum.NormalId.Front, "OFFICE · PRIVATE", C(30, 30, 34), C(240, 240, 236), { font = Enum.Font.GothamBold })
	-- Benny's office: desk, money counter, ledger, small TV, safe, boxes of detergent, a fan
	local og = b.group("Office", site)
	local back = D - 0.4
	local floorB = b.P("OfficeFloor", V(IW, 0.06, back - dp - 0.3), L(0, 0.13, (dp + 0.3 + back) / 2), C(150, 120, 90), M.SmoothPlastic, { parent = og, deco = true })
	K.dressPart(floorB, "MTL_VinylPlank")
	b.P("BennyDesk", V(5.0, 0.2, 2.4), L(bdx, 3.0, dp + 4.2), C(110, 80, 56), M.Wood, { parent = og })
	b.P("BennyDeskBody", V(5.0, 2.9, 0.2), L(bdx, 1.45, dp + 3.1), C(90, 64, 44), M.Wood, { parent = og })
	b.P("MoneyCounter", V(1.0, 0.6, 0.9), L(bdx - 1.4, 3.4, dp + 4.0), C(40, 42, 46), M.SmoothPlastic, { parent = og, deco = true })
	b.P("MoneyCounterLed", V(0.4, 0.14, 0.02), L(bdx - 1.4, 3.5, dp + 3.54), C(60, 220, 120), M.Neon, { parent = og, deco = true })
	b.P("Ledger", V(1.0, 0.1, 1.3), L(bdx + 0.6, 3.15, dp + 4.2) * CFrame.Angles(0, math.rad(12), 0), C(30, 60, 40), M.SmoothPlastic, { parent = og, deco = true })
	b.P("DeskLamp", V(0.3, 1.4, 0.3), L(bdx + 2.0, 3.8, dp + 4.8), C(30, 30, 30), M.Metal, { parent = og, deco = true })
	local lampHead = b.P("DeskLampHead", V(0.8, 0.4, 0.6), L(bdx + 1.8, 4.5, dp + 4.6), C(30, 120, 60), M.Metal, { parent = og, deco = true })
	local dl = Instance.new("SpotLight")
	dl.Face = Enum.NormalId.Bottom
	dl.Range = 10
	dl.Brightness = 1.4
	dl.Angle = 80
	dl.Color = C(255, 226, 180)
	dl.Parent = lampHead
	b.P("BennyChair", V(1.6, 0.25, 1.6), L(bdx, 1.9, dp + 6.3), C(30, 30, 30), M.Fabric, { parent = og })
	b.P("BennyChairBack", V(1.6, 2.0, 0.25), L(bdx, 3.0, dp + 7.1), C(30, 30, 30), M.Fabric, { parent = og })
	b.P("OfficeSafe", V(2.4, 3.4, 2.2), L(-IW / 2 + 1.5, 1.7, back - 1.4), C(50, 54, 60), M.Metal, { parent = og })
	b.P("OfficeSafeDial", V(0.12, 0.6, 0.6), L(-IW / 2 + 1.5, 2.3, back - 2.55) * CFrame.Angles(0, math.rad(90), 0), C(190, 190, 194), M.Metal, { parent = og, deco = true, shape = Enum.PartType.Cylinder })
	for k = 0, 3 do
		b.P("DetergentBox", V(1.8, 1.3, 1.4), L(IW / 2 - 1.2, 0.75 + k * 1.32, back - 1.2 - (k % 2) * 0.1), if k % 2 == 0 then C(240, 120, 30) else C(40, 90, 200), M.SmoothPlastic, { parent = og })
	end
	b.P("TV", V(2.2, 1.3, 0.2), L(-IW / 2 + 2.2, 7.0, back - 0.15) * CFrame.Angles(0, math.pi, 0), C(16, 16, 18), M.SmoothPlastic, { parent = og, deco = true })
	b.P("TVScreen", V(2.0, 1.1, 0.02), L(-IW / 2 + 2.2, 7.0, back - 0.27) * CFrame.Angles(0, math.pi, 0), C(60, 90, 70), M.Neon, { parent = og, deco = true, Transparency = 0.25 })
	-- lights: front room cool, office warm and dim
	local lg = b.group("Lights", site)
	for _, d in { 4.5, 11.5, 18.5 } do
		troffer(b, lg, F, -2.0, d, H, { shadows = d == 11.5, brightness = 0.7 })
	end
	troffer(b, lg, F, 2.0, back - 4.0, H, { color = C(255, 226, 180), brightness = 0.45, range = 12 })
	-- points: the player stands at the Dutch door shelf, Benny behind the desk
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = site
	point(pts, "Counter", L(bdx, 0.1, dp - 1.6))
	point(pts, "Owner", L(bdx, 0.2, dp + 1.6) * CFrame.Angles(0, math.pi, 0))
	point(pts, "Center", L(0, 0.1, 8))
	point(pts, "Door", L(u.door, 0.1, 1.2))
	site:SetAttribute("Floor", fy)
	site.Parent = sitesRoot()
	return string.format("%s floor %.2f stashed %d parts=%d", id, fy, stashed, b.n)
end

---------------------------------------------------------------- Royce's Cash 4 Gold (the building thread's story set)

-- The heist and Marcus's back door use Workspace.ViceBay.Buildings.Hood.RoyceCash4Gold (built by the building
-- thread, attribute MTL_StorySet = Cash4Gold). We never edit that model: our points and the few props we add
-- (alarm panel, safe door leaf, Marcus's tool table) live in MTL_CrimeSites.CashForGoldN.
-- Measured: alley door x -1130.9 z -337.5 (opens west onto a narrow alley, ground y 2.0), ground floor top y 2.6,
-- office floor top y 15.8, Royce's safe at (-1128.6, 17.5, -332.5) with its dial facing +X.
function B.cashForGoldN()
	local id = "CashForGoldN"
	local site = newSite(id, "CashForGoldN")
	local b = K.builder(site)
	local royce = workspace.ViceBay.Buildings.Hood:FindFirstChild("RoyceCash4Gold")
	assert(royce, "RoyceCash4Gold not found")
	local door = royce:FindFirstChild("AlleyDoor", true) :: BasePart
	local dz = if door then door.Position.Z else -337.5
	local dx = if door then door.Position.X else -1130.9
	local GROUND, FLOOR, UP = 2.0, 2.6, 15.8
	local west, east = -Vector3.xAxis, Vector3.xAxis
	local function at(x, y, z, look)
		local p = V(x, y, z)
		return CFrame.lookAt(p, p + look)
	end
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = site
	-- outside: the back door (look = out into the alley), Marcus's spot, the crew car
	point(pts, "HeistDoor", at(dx - 1.0, GROUND, dz, west))
	point(pts, "Fence", at(dx - 5.0, GROUND, dz + 3.2, east))
	point(pts, "Car", at(-1135.8, GROUND, -317.5, Vector3.zAxis))
	point(pts, "Center", at(dx - 3, GROUND, dz, east))
	-- inside: back room by the door, the alarm panel, the office safe upstairs
	point(pts, "Entry", at(dx + 3.0, FLOOR, dz, east))
	point(pts, "Exit", at(dx + 2.6, FLOOR, dz - 2.2, west))
	-- alarm panel on the back-room wall next to the door
	local ag = b.group("AlarmPanel", site)
	local pcf = at(dx + 0.62, FLOOR + 4.6, dz - 3.2, east)
	b.P("PanelBox", V(1.6, 2.0, 0.35), pcf, C(226, 224, 216), M.SmoothPlastic, { parent = ag })
	b.P("PanelDoor", V(1.4, 1.2, 0.05), pcf * CFrame.new(0, 0.25, -0.2), C(200, 198, 190), M.SmoothPlastic, { parent = ag, deco = true })
	b.P("Keypad", V(0.8, 0.6, 0.05), pcf * CFrame.new(0, -0.55, -0.2), C(30, 30, 34), M.SmoothPlastic, { parent = ag, deco = true })
	b.P("ArmedLed", V(0.12, 0.12, 0.05), pcf * CFrame.new(0.45, 0.8, -0.2), C(255, 30, 30), M.Neon, { parent = ag, deco = true })
	b.P("PowerLed", V(0.12, 0.12, 0.05), pcf * CFrame.new(0.25, 0.8, -0.2), C(30, 220, 60), M.Neon, { parent = ag, deco = true })
	b.P("Conduit", V(0.18, 5.0, 0.18), pcf * CFrame.new(0, 3.5, 0), C(170, 170, 170), M.Metal, { parent = ag, deco = true })
	local lbl = b.P("PanelLabel", V(1.2, 0.3, 0.03), pcf * CFrame.new(0, -1.25, -0.2), C(200, 30, 30), M.SmoothPlastic, { parent = ag, deco = true })
	K.sign(lbl, Enum.NormalId.Front, "ALARM · 24H MONITORED", C(200, 30, 30), C(255, 255, 255), { font = Enum.Font.GothamBold })
	point(pts, "AlarmBox", pcf * CFrame.new(0, 0, -1.0))
	-- the office safe: our door leaf on Royce's safe (CrimeJobs swings "SafeDoor" open on its local -X edge)
	local safe = royce:FindFirstChild("Safe", true) :: BasePart?
	local scf = if safe then safe.CFrame else CFrame.new(-1128.6, 17.5, -332.5)
	local ssz = if safe then safe.Size else V(2.6, 3.4, 2.4)
	local front = scf.Position + V(ssz.X / 2 + 0.09, 0, 0) -- the dial side (+X)
	local sg = b.group("SafeKit", site)
	local leaf = b.P("SafeDoor", V(ssz.Z - 0.3, ssz.Y - 0.3, 0.16), CFrame.lookAt(front, front + east), C(58, 62, 68), M.Metal, { parent = sg })
	b.P("SafeInside", V(ssz.X - 0.5, ssz.Y - 0.5, ssz.Z - 0.5), scf * CFrame.new(0.05, 0, 0), C(20, 20, 22), M.SmoothPlastic, { parent = sg, deco = true })
	for i = 0, 2 do
		b.P("SafeStack", V(0.5, 0.3, 0.9), scf * CFrame.new(0.3, -0.9 + i * 0.32, -0.5 + (i % 2) * 0.9), C(116, 170, 100), M.SmoothPlastic, { parent = sg, deco = true })
	end
	point(pts, "Safe", CFrame.lookAt(front + V(1.8, UP - scf.Position.Y + 0.1, 0), front + V(0, UP - scf.Position.Y + 0.1, 0)))
	point(pts, "Bags", CFrame.lookAt(V(front.X + 3.2, UP + 0.05, scf.Position.Z - 3.0), V(front.X + 3.2, UP + 0.05, scf.Position.Z - 4.0)))
	local _ = leaf
	-- the alley door itself sits inside the wall in Royce's model, so the alley shows a plain wall: give it a
	-- steel back door on the outside face (visual; going in/out is a fade, see CrimeJobs heist/fence)
	local dg = b.group("BackDoor", site)
	local wallX = dx - 0.32 -- outside face of the west wall is x -1131.2
	local dcf = at(wallX - 0.09, GROUND + 4.35, dz, west)
	b.P("DoorSlab", V(3.8, 8.1, 0.16), dcf, C(70, 78, 72), M.Metal, { parent = dg })
	b.P("DoorFrameL", V(0.3, 8.5, 0.3), dcf * CFrame.new(-2.05, 0.2, 0.05), C(40, 40, 42), M.Metal, { parent = dg, deco = true })
	b.P("DoorFrameR", V(0.3, 8.5, 0.3), dcf * CFrame.new(2.05, 0.2, 0.05), C(40, 40, 42), M.Metal, { parent = dg, deco = true })
	b.P("DoorFrameTop", V(4.4, 0.3, 0.3), dcf * CFrame.new(0, 4.3, 0.05), C(40, 40, 42), M.Metal, { parent = dg, deco = true })
	b.P("DoorPull", V(0.15, 1.2, 0.2), dcf * CFrame.new(1.4, -0.3, -0.15), C(170, 170, 174), M.Metal, { parent = dg, deco = true })
	b.P("DoorRust", V(3.6, 1.2, 0.02), dcf * CFrame.new(0, -3.4, -0.09), C(110, 70, 40), M.CorrodedMetal, { parent = dg, deco = true })
	local ds = b.P("DoorSign", V(2.2, 0.8, 0.03), dcf * CFrame.new(0, 1.6, -0.1), C(236, 236, 230), M.SmoothPlastic, { parent = dg, deco = true })
	K.sign(ds, Enum.NormalId.Front, "DELIVERIES\nRING BELL", C(236, 236, 230), C(30, 30, 30), { font = Enum.Font.GothamBold })
	b.P("Bell", V(0.3, 0.45, 0.12), dcf * CFrame.new(2.5, 0.2, -0.05), C(30, 30, 32), M.SmoothPlastic, { parent = dg, deco = true })
	-- Marcus's table under the alley lamp: a folding table with the tools he sells
	local mg = b.group("MarcusTable", site)
	local tcf = at(dx - 2.6, GROUND, dz + 6.6, east)
	b.P("TableTop", V(4.0, 0.15, 2.0), tcf * CFrame.new(0, 2.6, 0), C(90, 84, 70), M.WoodPlanks, { parent = mg })
	for _, lx in { -1.8, 1.8 } do
		b.P("TableLeg", V(0.12, 2.5, 1.8), tcf * CFrame.new(lx, 1.25, 0), C(60, 60, 60), M.Metal, { parent = mg, deco = true })
	end
	-- crowbar, sledgehammer, slim jim, a drill case, a duffel
	b.P("Crowbar", V(0.12, 0.12, 2.6), tcf * CFrame.new(-1.2, 2.75, 0) * CFrame.Angles(0, math.rad(80), 0), C(180, 30, 30), M.Metal, { parent = mg, deco = true })
	b.P("HammerHead", V(0.5, 0.5, 1.0), tcf * CFrame.new(0.2, 2.95, -0.4), C(50, 50, 54), M.Metal, { parent = mg, deco = true })
	b.P("HammerHandle", V(0.18, 0.18, 2.6), tcf * CFrame.new(0.2, 2.8, 0.6) * CFrame.Angles(0, math.rad(90), 0), C(150, 110, 60), M.Wood, { parent = mg, deco = true })
	b.P("SlimJim", V(0.05, 0.08, 2.2), tcf * CFrame.new(1.4, 2.72, 0.3) * CFrame.Angles(0, math.rad(70), 0), C(170, 170, 176), M.Metal, { parent = mg, deco = true })
	b.P("DrillCase", V(1.6, 0.6, 1.1), tcf * CFrame.new(1.2, 3.0, -0.4), C(220, 170, 20), M.Plastic, { parent = mg, deco = true })
	b.P("MilkCrate", V(1.4, 1.2, 1.4), tcf * CFrame.new(-2.6, 0.6, 1.4), C(30, 70, 160), M.Plastic, { parent = mg })
	site.Parent = sitesRoot()
	return string.format("%s parts=%d safe=%s door=%s", id, b.n, tostring(safe ~= nil), tostring(door ~= nil))
end

---------------------------------------------------------------- house licks (Royce's empty rentals on NW 52nd)

-- Outside: a back door on each real house (the map houses are solid blocks) + where Smoke backs the van up.
-- Inside: one furnished room per house, built off the map at Crime.LickRooms (Origin + i * Spacing along X); the
-- crime code fades the player between BackDoor and Entry. Loot1..5 are surfaces (loot is laid on top).
B.Houses = {
	-- back wall plane (measured by raycast), outward direction, along-wall offset of the door from the centre
	{ id = "Lick52A", back = V(-1892.9, 0, -932.4), out = V(1, 0, 0), door = 4, tint = C(214, 204, 186), rug = C(120, 40, 40) },
	{ id = "Lick52B", back = V(-1898.4, 0, -824.4), out = V(1, 0, 0), door = -4, tint = C(196, 206, 200), rug = C(40, 70, 120) },
	{ id = "Lick52C", back = V(-2027.6, 0, -612.5), out = V(-1, 0, 0), door = 4, tint = C(220, 200, 176), rug = C(70, 90, 50) },
	{ id = "Lick52D", back = V(-1924.1, 0, -1074.9), out = V(0, 0, -1), door = -4, tint = C(200, 196, 210), rug = C(90, 60, 110) },
}
B.LickOrigin, B.LickSpacing = V(7400, 400, 6000), 140

local function lickRoom(b, parent, R: CFrame, h, i: number)
	local W, D, H = 30, 28, 10
	local g = b.group("Room", parent)
	local L = function(x, y, z)
		return R * CFrame.new(x, y, z)
	end
	local rng = Random.new(520 + i)
	-- shell: floor, ceiling, four walls (the back door wall is +Z)
	local fl = b.P("RoomFloor", V(W, 1, D), L(0, -0.5, 0), C(150, 120, 90), M.SmoothPlastic, { parent = g })
	K.dressPart(fl, "MTL_VinylPlank")
	local ce = b.P("RoomCeiling", V(W, 1, D), L(0, H + 0.5, 0), C(230, 228, 222), M.SmoothPlastic, { parent = g })
	local _ = ce
	local walls = {
		{ V(W + 2, H + 2, 1), L(0, H / 2, -D / 2 - 0.5) },
		{ V(W + 2, H + 2, 1), L(0, H / 2, D / 2 + 0.5) },
		{ V(1, H + 2, D), L(-W / 2 - 0.5, H / 2, 0) },
		{ V(1, H + 2, D), L(W / 2 + 0.5, H / 2, 0) },
	}
	for _, w in walls do
		local p = b.P("RoomWall", w[1], w[2], h.tint, M.SmoothPlastic, { parent = g })
		K.dressPart(p, "MTL_Drywall")
		p.Color = h.tint
	end
	-- baseboards
	for _, w in { { V(W, 0.4, 0.1), L(0, 0.2, -D / 2 + 0.05) }, { V(W, 0.4, 0.1), L(0, 0.2, D / 2 - 0.05) }, { V(0.1, 0.4, D), L(-W / 2 + 0.05, 0.2, 0) }, { V(0.1, 0.4, D), L(W / 2 - 0.05, 0.2, 0) } } do
		b.P("Baseboard", w[1], w[2], C(236, 232, 222), M.SmoothPlastic, { parent = g, deco = true })
	end
	-- the inside of the back door (kicked: frame splintered, door ajar)
	local dx = -8
	b.P("BackDoorFrame", V(4.4, 8.4, 0.3), L(dx, 4.2, D / 2 - 0.1), C(236, 232, 222), M.Wood, { parent = g, deco = true })
	b.P("BackDoorGap", V(3.8, 7.9, 0.32), L(dx, 3.95, D / 2 - 0.1), C(14, 16, 22), M.SmoothPlastic, { parent = g, deco = true })
	b.P("BackDoorLeaf", V(3.7, 7.8, 0.2), L(dx - 1.85, 3.9, D / 2 - 0.25) * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(1.85, 0, 0), C(220, 216, 206), M.Wood, { parent = g, deco = true })
	for k = 1, 4 do
		b.P("Splinter", V(0.12, rng:NextNumber(0.4, 1.0), 0.08), L(dx + 1.9, 3.6 + k * 0.3, D / 2 - 0.3) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))), C(200, 170, 120), M.Wood, { parent = g, deco = true })
	end
	-- windows: dark blue night outside, blinds, a streetlight glow leaking in
	for _, wx in { -2, 7 } do
		local wcf = L(wx, 5.2, -D / 2 + 0.02)
		b.P("WindowNight", V(4.2, 3.6, 0.04), wcf, C(20, 30, 60), M.Neon, { parent = g, deco = true, Transparency = 0.35 })
		for k = 0, 9 do
			b.P("Blind", V(4.4, 0.08, 0.12), wcf * CFrame.new(0, -1.7 + k * 0.38, 0.12) * CFrame.Angles(math.rad(35), 0, 0), C(226, 222, 210), M.SmoothPlastic, { parent = g, deco = true })
		end
		b.P("WindowTrim", V(4.8, 4.2, 0.1), wcf * CFrame.new(0, 0, -0.02), C(236, 232, 222), M.SmoothPlastic, { parent = g, deco = true })
	end
	-- kitchen along the west wall: base cabinets, counter, fridge, stove, sink, upper cabinets
	local kx = -W / 2 + 1.3
	b.P("KitchenBase", V(2.4, 3.0, 12), L(kx, 1.5, -1), C(150, 110, 70), M.Wood, { parent = g })
	local kt = b.P("KitchenTop", V(2.6, 0.2, 12.2), L(kx + 0.05, 3.1, -1), C(60, 60, 64), M.Granite, { parent = g })
	local _ = kt
	b.P("Upper", V(1.4, 2.4, 12), L(-W / 2 + 0.7, 7.2, -1), C(150, 110, 70), M.Wood, { parent = g, deco = true })
	b.P("Fridge", V(2.6, 6.6, 2.8), L(kx, 3.3, -9.0), C(220, 220, 222), M.Metal, { parent = g })
	b.P("FridgeHandle", V(0.1, 2.0, 0.15), L(kx + 1.35, 4.4, -8.0), C(170, 170, 174), M.Metal, { parent = g, deco = true })
	b.P("Stove", V(2.5, 3.0, 2.6), L(kx, 1.5, 2.5), C(40, 40, 44), M.Metal, { parent = g })
	b.P("StoveTop", V(2.5, 0.12, 2.6), L(kx, 3.06, 2.5), C(20, 20, 22), M.Metal, { parent = g, deco = true })
	b.P("Sink", V(1.8, 0.15, 2.2), L(kx + 0.1, 3.16, -4.5), C(170, 172, 176), M.Metal, { parent = g, deco = true })
	b.P("Faucet", V(0.15, 0.9, 0.15), L(kx - 0.7, 3.6, -4.5), C(190, 190, 194), M.Metal, { parent = g, deco = true })
	-- dining table + two chairs
	local dt = L(-6.5, 0, -2.5)
	b.P("DiningTop", V(4.0, 0.2, 3.0), dt * CFrame.new(0, 2.8, 0), C(110, 80, 56), M.Wood, { parent = g })
	for _, lx in { -1.7, 1.7 } do
		for _, lz in { -1.2, 1.2 } do
			b.P("DiningLeg", V(0.2, 2.7, 0.2), dt * CFrame.new(lx, 1.35, lz), C(90, 64, 44), M.Wood, { parent = g, deco = true })
		end
	end
	for _, cz in { -2.2, 2.2 } do
		b.P("DiningChair", V(1.4, 0.2, 1.4), dt * CFrame.new(0, 1.8, cz), C(90, 64, 44), M.Wood, { parent = g })
		for _, lx in { -0.6, 0.6 } do
			for _, lz in { -0.6, 0.6 } do
				b.P("ChairLeg", V(0.15, 1.7, 0.15), dt * CFrame.new(lx, 0.85, cz + lz), C(80, 56, 38), M.Wood, { parent = g, deco = true })
			end
		end
		b.P("DiningChairBack", V(1.4, 1.8, 0.15), dt * CFrame.new(0, 2.8, cz + (if cz > 0 then 0.65 else -0.65)), C(90, 64, 44), M.Wood, { parent = g })
	end
	-- living room (east): rug, TV stand on the east wall, sofa facing it, coffee table, a lamp
	local lz = 6.5
	b.P("Rug", V(10, 0.05, 8), L(8.5, 0.03, lz), h.rug, M.Fabric, { parent = g, deco = true })
	local tvx = W / 2 - 1.0
	b.P("TVStand", V(1.6, 2.0, 6.0), L(tvx, 1.0, lz), C(40, 36, 34), M.Wood, { parent = g })
	local sofa = clone({ "VBFurniture" }, if i % 2 == 0 then "SofaLeather" else "SofaWalnut")
	if sofa then
		-- the kit sofas sit with their long side on X: turn them to face the TV (+X)
		placeOn(sofa, L(3.6, 0, lz) * CFrame.Angles(0, math.rad(-90), 0), g)
		sofa.Name = "Sofa"
	else
		b.P("SofaSeat", V(3.0, 1.6, 9.0), L(3.6, 0.8, lz), C(60, 60, 66), M.Fabric, { parent = g })
		b.P("SofaBack", V(1.0, 2.8, 9.0), L(2.4, 1.6, lz), C(60, 60, 66), M.Fabric, { parent = g })
	end
	b.P("CoffeeTable", V(2.6, 0.25, 4.2), L(8.5, 1.475, lz), C(110, 80, 56), M.Wood, { parent = g })
	b.P("CoffeeShelf", V(2.3, 0.12, 3.9), L(8.5, 0.45, lz), C(96, 70, 48), M.Wood, { parent = g, deco = true })
	for _, ox in { -1.15, 1.15 } do
		for _, oz in { -1.95, 1.95 } do
			b.P("CoffeeLeg", V(0.2, 1.35, 0.2), L(8.5 + ox, 0.675, lz + oz), C(70, 50, 34), M.Wood, { parent = g, deco = true })
		end
	end
	b.P("FloorLamp", V(0.2, 5.6, 0.2), L(W / 2 - 1.2, 2.8, 1.0), C(30, 30, 30), M.Metal, { parent = g, deco = true })
	local shade = b.P("LampShade", V(1.4, 1.1, 1.4), L(W / 2 - 1.2, 5.9, 1.0), C(236, 220, 190), M.Fabric, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = L(W / 2 - 1.2, 5.9, 1.0) * CFrame.Angles(0, 0, math.rad(90)) })
	local pl = Instance.new("PointLight")
	pl.Range = 16
	pl.Brightness = 0.9
	pl.Color = C(255, 214, 160)
	pl.Shadows = true
	pl.Parent = shade
	-- bedroom (north-east) behind a partition with a doorway
	local pz = -1
	b.P("Partition", V(4.0, H, 0.5), L(3.0, H / 2, pz), h.tint, M.SmoothPlastic, { parent = g })
	b.P("Partition", V(6.5, H, 0.5), L(W / 2 - 3.25, H / 2, pz), h.tint, M.SmoothPlastic, { parent = g })
	b.P("PartitionHead", V(3.5, H - 8, 0.5), L(6.75, H - (H - 8) / 2, pz), h.tint, M.SmoothPlastic, { parent = g })
	b.P("PartitionSide", V(0.5, H, D / 2 + pz), L(1.0, H / 2, (-D / 2 + pz) / 2), h.tint, M.SmoothPlastic, { parent = g })
	local bed = clone({ "VBFurniture" }, "BedWhite")
	if bed then
		placeOn(bed, L(9.6, 0, -D / 2 + 5.3) * CFrame.Angles(0, math.rad(180), 0), g)
		bed.Name = "Bed"
	else
		b.P("Bed", V(9.0, 2.0, 10.0), L(9.6, 1.0, -D / 2 + 5.3), C(220, 220, 226), M.Fabric, { parent = g })
	end
	b.P("Dresser", V(1.8, 3.2, 4.0), L(2.4, 1.6, -D / 2 + 3.0), C(120, 90, 60), M.Wood, { parent = g })
	for k = 0, 2 do
		b.P("DresserHandle", V(0.1, 0.1, 0.8), L(3.32, 0.7 + k * 0.9, -D / 2 + 3.0), C(200, 190, 150), M.Metal, { parent = g, deco = true })
	end
	-- ceiling light (warm, dim: nobody home)
	local cl = b.P("CeilingLight", V(0.3, 1.8, 1.8), L(-6, H - 0.15, -2), C(240, 230, 210), M.Neon, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = L(-6, H - 0.15, -2) * CFrame.Angles(0, 0, math.rad(90)) })
	local cl2 = Instance.new("PointLight")
	cl2.Range = 20
	cl2.Brightness = 0.55
	cl2.Color = C(255, 226, 190)
	cl2.Parent = cl
	-- picture frames and a calendar so walls aren't bare
	for _, f in { { L(-W / 2 + 0.06, 6, 9), 2.4, 1.8 }, { L(W / 2 - 0.06, 6.5, 11.5), 3.0, 2.0 } } do
		b.P("Frame", V(0.1, f[3], f[2]), f[1], C(40, 30, 24), M.Wood, { parent = g, deco = true })
	end
	-- points (Entry inside the back door facing in, Exit at the door, loot surfaces)
	return {
		Entry = L(dx, 0.05, D / 2 - 2.5) * CFrame.Angles(0, 0, 0),
		Exit = L(dx, 0.05, D / 2 - 1.2),
		Loot1 = L(tvx, 2.0, lz) * CFrame.Angles(0, math.rad(90), 0), -- TV stand (faces the sofa)
		Loot2 = L(8.5, 1.6, lz) * CFrame.Angles(0, math.rad(90), 0), -- coffee table
		Loot3 = L(kx + 0.1, 3.2, -1.0) * CFrame.Angles(0, math.rad(-90), 0), -- kitchen counter
		Loot4 = L(-6.5, 2.9, -2.5), -- dining table
		Loot5 = L(2.4, 3.2, -D / 2 + 3.0) * CFrame.Angles(0, math.rad(-90), 0), -- dresser
	}
end

function B.houses()
	local out = {}
	for i, h in B.Houses do
		local site = newSite(h.id, "House")
		local b = K.builder(site)
		local pts = Instance.new("Folder")
		pts.Name = "Points"
		pts.Parent = site
		-- outside: the back door on the real house
		local along = V(-h.out.Z, 0, h.out.X)
		local gy = groundY(h.back.X + h.out.X * 3, h.back.Z + h.out.Z * 3, 30)
		local doorPos = V(h.back.X, gy, h.back.Z) + along * h.door
		local outCf = CFrame.lookAt(doorPos, doorPos + h.out)
		local og = b.group("BackDoorOutside", site)
		-- the house kit has a 2-stud skirt (0.25 proud of the wall): the door sits on it, a concrete stoop leads up
		local sy = 2.0
		b.P("DoorSlab", V(3.6, 7.6, 0.18), outCf * CFrame.new(0, sy + 3.85, -0.1), C(236, 232, 222), M.Wood, { parent = og })
		b.P("DoorTrim", V(4.2, 8.0, 0.12), outCf * CFrame.new(0, sy + 3.95, -0.03), C(250, 248, 240), M.SmoothPlastic, { parent = og, deco = true })
		b.P("DoorKnob", V(0.25, 0.25, 0.3), outCf * CFrame.new(1.3, sy + 3.5, -0.25), C(190, 170, 110), M.Metal, { parent = og, deco = true })
		b.P("StoopTop", V(4.6, sy, 1.8), outCf * CFrame.new(0, sy / 2, -1.15), C(150, 150, 146), M.Concrete, { parent = og })
		b.P("StoopStep", V(4.6, sy / 2, 1.2), outCf * CFrame.new(0, sy / 4, -2.65), C(140, 140, 136), M.Concrete, { parent = og })
		b.P("DoorLight", V(0.5, 0.7, 0.4), outCf * CFrame.new(-2.6, sy + 7.2, -0.3), C(240, 230, 200), M.Neon, { parent = og, deco = true })
		point(pts, "BackDoor", outCf * CFrame.new(0, 0, -3.8))
		-- Smoke's van: parallel to the wall, rear near the door (the code's van rear = pivot * (0, 0, 9))
		local vanC = doorPos + h.out * 8.5 - along * 9 + V(0, 4.1, 0)
		point(pts, "Van", CFrame.lookAt(vanC, vanC - along))
		point(pts, "Center", outCf * CFrame.new(0, 0, -4))
		-- inside: the room off the map
		local R = CFrame.new(B.LickOrigin + V((i - 1) * B.LickSpacing, 0, 0))
		local inner = lickRoom(b, site, R, h, i)
		for name, cf in inner do
			point(pts, name, cf)
		end
		site.Parent = sitesRoot()
		table.insert(out, string.format("%s ground %.1f parts=%d", h.id, gy, b.n))
		task.wait()
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- Royce's ATM route (ATM drill now, skimmers later)

-- A walk-up ATM on Royce's private network ("ROYCE CASH"), built facing `cf.LookVector` with its face on cf
-- (cf at floor level). The card slot is its own part (CardSlot) so the card-swiping job can fit an overlay on it.
local function atmKiosk(b, g, F: CFrame)
	local L = function(x, y, z)
		return F * CFrame.new(x, y, z)
	end
	local body, dark, steel = C(46, 48, 54), C(24, 25, 28), C(150, 152, 158)
	b.P("AtmPlinth", V(3.0, 0.3, 2.4), L(0, 0.15, 1.0), C(110, 110, 112), M.Concrete, { parent = g })
	b.P("AtmCabinet", V(2.6, 5.3, 2.0), L(0, 2.95, 1.0), body, M.Metal, { parent = g })
	-- the safe (lower half): a slightly proud door with hinges and a lock plate (the drill goes here)
	b.P("AtmSafeDoor", V(2.2, 2.3, 0.08), L(0, 1.65, -0.04), C(62, 64, 70), M.DiamondPlate, { parent = g, deco = true })
	b.P("AtmLockPlate", V(0.5, 0.5, 0.06), L(0.55, 1.75, -0.1), steel, M.Metal, { parent = g, deco = true })
	b.P("AtmHinge", V(0.12, 0.5, 0.12), L(-1.08, 2.3, -0.1), steel, M.Metal, { parent = g, deco = true })
	b.P("AtmHinge", V(0.12, 0.5, 0.12), L(-1.08, 1.0, -0.1), steel, M.Metal, { parent = g, deco = true })
	local kick = b.P("AtmKick", V(2.2, 0.35, 0.06), L(0, 0.55, -0.04), C(200, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
	K.sign(kick, Enum.NormalId.Front, "24 HRS • SURCHARGE $4.99", C(200, 30, 30), C(255, 255, 255), { font = Enum.Font.GothamBold })
	-- upper fascia: recessed screen, keypad shelf, card slot, cash slot, receipt slot
	b.P("AtmFascia", V(2.4, 2.6, 0.06), L(0, 4.25, -0.03), C(34, 36, 40), M.SmoothPlastic, { parent = g, deco = true })
	b.P("AtmBezel", V(1.7, 1.25, 0.06), L(0, 4.75, -0.07), dark, M.SmoothPlastic, { parent = g, deco = true })
	local screen = b.P("AtmScreen", V(1.45, 1.0, 0.03), L(0, 4.75, -0.11), C(16, 60, 120), M.Neon, { parent = g, deco = true })
	K.sign(screen, Enum.NormalId.Front, "ROYCE CASH\nINSERT CARD", C(16, 60, 120), C(235, 245, 255), { lit = true, font = Enum.Font.GothamBold })
	b.P("AtmHood", V(2.0, 0.12, 0.5), L(0, 5.45, -0.25), dark, M.Metal, { parent = g, deco = true })
	b.P("AtmShelf", V(2.2, 0.14, 0.75), L(0, 3.55, -0.36) * CFrame.Angles(math.rad(-14), 0, 0), C(56, 58, 64), M.Metal, { parent = g })
	for r = 0, 3 do
		for c = 0, 2 do
			b.P("AtmKey", V(0.16, 0.05, 0.13), L(-0.35 + c * 0.2, 3.66 - r * 0.035, -0.5 + r * 0.14) * CFrame.Angles(math.rad(-14), 0, 0), if r == 3 and c == 2 then C(40, 160, 70) elseif r == 3 and c == 0 then C(200, 40, 40) else C(190, 190, 196), M.Metal, { parent = g, deco = true })
		end
	end
	local slot = b.P("CardSlot", V(0.55, 0.22, 0.14), L(0.75, 4.05, -0.12), C(30, 30, 34), M.SmoothPlastic, { parent = g, deco = true })
	slot:SetAttribute("MTL_CardSlot", true)
	b.P("CardSlotLight", V(0.42, 0.04, 0.02), L(0.75, 4.05, -0.2), C(30, 200, 90), M.Neon, { parent = g, deco = true })
	b.P("CashSlot", V(1.0, 0.16, 0.08), L(-0.2, 3.2, -0.07), C(10, 10, 12), M.SmoothPlastic, { parent = g, deco = true })
	b.P("CashSlotLip", V(1.1, 0.05, 0.14), L(-0.2, 3.1, -0.1), steel, M.Metal, { parent = g, deco = true })
	b.P("ReceiptSlot", V(0.4, 0.06, 0.06), L(0.75, 3.9, -0.1), C(10, 10, 12), M.SmoothPlastic, { parent = g, deco = true })
	-- privacy wings + lit topper with the network name
	for _, sx in { -1, 1 } do
		b.P("AtmWing", V(0.1, 2.0, 0.6), L(sx * 1.25, 4.4, -0.3), C(40, 42, 48), M.Metal, { parent = g })
	end
	local top = b.P("AtmTopper", V(2.8, 0.9, 2.1), L(0, 6.05, 1.0), C(16, 60, 120), M.SmoothPlastic, { parent = g })
	K.sign(top, Enum.NormalId.Front, "ROYCE CASH ATM", C(16, 60, 120), C(255, 214, 80), { lit = true, font = Enum.Font.GothamBlack })
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		K.sign(top, face, "ROYCE CASH", C(16, 60, 120), C(255, 255, 255), { lit = true, font = Enum.Font.GothamBlack })
	end
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 9
	glow.Brightness = 1.2
	glow.Angle = 70
	glow.Color = C(170, 200, 255)
	glow.Parent = top
	b.P("AtmTopTrim", V(2.9, 0.1, 2.2), L(0, 6.55, 1.0), steel, M.Metal, { parent = g, deco = true })
	-- a little dome camera under the topper, and a "NO LOITERING" sticker on the side
	domeCam(b, g, L(0.95, 5.52, 0.25))
	local side = b.P("AtmSticker", V(0.04, 0.9, 1.3), L(1.32, 3.6, 1.0), C(250, 250, 250), M.SmoothPlastic, { parent = g, deco = true })
	K.sign(side, Enum.NormalId.Right, "ROYCE CASH NETWORK\nNO LOITERING", C(250, 250, 250), C(20, 20, 20), { font = Enum.Font.GothamBold })
	return {
		Atm = L(0, 3.0, -1.4) * CFrame.Angles(0, math.rad(180), 0), -- where the prompt sits (player side, facing the ATM)
		-- core drill on its magnetic base on the ground; bit (pivot * (0, 1.2, -1.2)) lands on the safe door
		DrillMount = L(0.3, 0.25, -1.3) * CFrame.Angles(0, math.rad(180), 0),
		Tray = L(-0.2, 0.06, -1.2), -- the cash spills out at the foot of the machine
		Center = L(0, 0, -3),
	}
end
B.atmKiosk = atmKiosk

-- id, face position (floor y: 0 = probe), outward direction, map parts to stash (positions of the old ATM)
B.Atms = {
	{ id = "AtmGas", title = "the ATM at Sunshine Gas", at = V(-1313.8, 3.7, -915.3), out = V(0, 0, 1), stash = { V(-1313.8, 6.5, -916.2), V(-1313.8, 8.6, -915.3) } },
	{ id = "AtmCarWash", title = "the ATM at Sudz Car Wash", at = V(-1842.3, 0, -246), out = V(1, 0, 0) },
	{ id = "AtmPark", title = "the ATM by Liberty Park", at = V(-1560, 0, -171), out = V(0, 0, 1) },
}

function B.atms()
	local out = {}
	for _, a in B.Atms do
		local site = newSite(a.id, "Atm")
		site:SetAttribute("Title", a.title)
		local b = K.builder(site)
		local pts = Instance.new("Folder")
		pts.Name = "Points"
		pts.Parent = site
		local stashed = 0
		for _, sp in a.stash or {} do
			for _, q in workspace:GetPartBoundsInRadius(sp, 0.6) do
				if not q:IsDescendantOf(sitesRoot()) and q.Size.Magnitude < 12 then
					K.stash("Crime_" .. a.id, q)
					stashed += 1
				end
			end
		end
		local y = a.at.Y
		if y == 0 then
			y = groundY(a.at.X + a.out.X * 1.5, a.at.Z + a.out.Z * 1.5, 12)
		end
		local pos = V(a.at.X, y, a.at.Z)
		local F = CFrame.lookAt(pos, pos + a.out)
		local g = b.group("Kiosk", site)
		for name, cf in atmKiosk(b, g, F) do
			point(pts, name, cf)
		end
		site.Parent = sitesRoot()
		table.insert(out, string.format("%s floor %.1f stashed %d parts=%d", a.id, y, stashed, b.n))
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- car boosts (Royce's collector parks around the hood)

-- The boost car (ServerStorage.MTL_Cars.<Crime.Methods.CarBoost.carTemplate>) has a tilted pivot, and CrimeJobs
-- spawns it at Car point + (0, 1, 0). So the Car point carries the template's pivot rotation, turned so the car's
-- nose points along `dir`, with its wheels on the ground.
local function carPointFor(templateName: string, ground: Vector3, dir: Vector3): CFrame
	local f = SS:FindFirstChild("MTL_Cars")
	local t = f and f:FindFirstChild(templateName)
	local yaw = CFrame.fromMatrix(Vector3.zero, dir.Unit, Vector3.yAxis)
	if not t or not t:IsA("Model") then
		return CFrame.new(ground) * yaw
	end
	local piv = t:GetPivot()
	local seat = t:FindFirstChildWhichIsA("VehicleSeat", true)
	local nose = if seat then seat.CFrame.LookVector else piv.LookVector
	nose = V(nose.X, 0, nose.Z).Unit
	local lowest = math.huge
	for _, d in t:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						lowest = math.min(lowest, (d.CFrame * V(sx * h.X, sy * h.Y, sz * h.Z)).Y)
					end
				end
			end
		end
	end
	local above = piv.Y - lowest
	-- rotation that takes the template's nose to +X, then +X to dir
	local toX = CFrame.fromMatrix(Vector3.zero, nose, Vector3.yAxis):Inverse()
	local rot = yaw * toX * piv.Rotation
	return CFrame.new(ground + V(0, above - 1, 0)) * rot
end
B.carPointFor = carPointFor

B.Boosts = {
	{ id = "BoostCheckN", title = "Glades Rd, outside Royce's check cashing", at = V(-1764, 0, -206), dir = V(0, 0, -1) },
	{ id = "BoostGold", title = "Liberty Blvd, outside his Cash 4 Gold", at = V(-1391.5, 0, 371), dir = V(0, 0, 1) },
	{ id = "BoostLucky", title = "the front row at Lucky's Used Autos", at = V(-1311.5, 0, -596), dir = V(-1, 0, 0), featured = true },
}
B.ChopDrop = { at = V(-1834, 0, -348), dir = V(-1, 0, 0) } -- A1 Tires' apron, nose to the middle bay door

local function cone(b, g, cf: CFrame)
	b.P("ConeBase", V(1.2, 0.12, 1.2), cf * CFrame.new(0, 0.06, 0), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
	b.P("Cone", V(1.4, 0.8, 0.8), cf * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), C(255, 110, 20), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
	b.P("ConeStripe", V(0.25, 0.86, 0.86), cf * CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), C(240, 240, 240), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
end

function B.boosts()
	local out = {}
	local Crime = require(game:GetService("ReplicatedStorage").MTL.Config.Crime)
	local tpl = (Crime.Methods.CarBoost :: any).carTemplate or "Oros"
	for _, s in B.Boosts do
		local site = newSite(s.id, "BoostSpot")
		site:SetAttribute("Title", s.title)
		local b = K.builder(site)
		local pts = Instance.new("Folder")
		pts.Name = "Points"
		pts.Parent = site
		local gy = groundY(s.at.X, s.at.Z, 12)
		local ground = V(s.at.X, gy, s.at.Z)
		point(pts, "Car", carPointFor(tpl, ground, s.dir))
		point(pts, "Center", CFrame.lookAt(ground, ground + s.dir))
		local g = b.group("Dressing", site)
		local side = V(-s.dir.Z, 0, s.dir.X)
		-- the collector keeps two cones around his ride so nobody dings it
		for _, k in { -1, 1 } do
			local cp = ground + s.dir * (k * 11.5) + side * 3.5
			cone(b, g, CFrame.new(cp))
		end
		if s.featured then
			local sp = ground + side * 7.5
			local post = b.P("SignPost", V(0.3, 6, 0.3), CFrame.new(sp + V(0, 3, 0)), C(200, 200, 204), M.Metal, { parent = g })
			local _ = post
			local board = b.P("SignBoard", V(5.5, 2.2, 0.15), CFrame.lookAt(sp + V(0, 5.6, 0), sp + V(0, 5.6, 0) - side), C(250, 214, 60), M.SmoothPlastic, { parent = g })
			K.sign(board, Enum.NormalId.Front, "SOLD • HOLD FOR R.", C(250, 214, 60), C(20, 20, 20), { font = Enum.Font.GothamBlack })
			K.sign(board, Enum.NormalId.Back, "SOLD • HOLD FOR R.", C(250, 214, 60), C(20, 20, 20), { font = Enum.Font.GothamBlack })
		end
		site.Parent = sitesRoot()
		table.insert(out, string.format("%s ground %.1f parts=%d", s.id, gy, b.n))
	end
	-- A1 Tires: Smoke takes the car on the apron
	local site = newSite("ChopShop", "ChopShop")
	site:SetAttribute("Title", "A1 Tires & Rims")
	local b = K.builder(site)
	local pts = Instance.new("Folder")
	pts.Name = "Points"
	pts.Parent = site
	local d = B.ChopDrop
	local gy = groundY(d.at.X, d.at.Z, 12)
	local ground = V(d.at.X, gy, d.at.Z)
	point(pts, "Drop", CFrame.lookAt(ground, ground + d.dir))
	local g = b.group("Dressing", site)
	-- painted drop box on the apron
	local side = V(-d.dir.Z, 0, d.dir.X)
	for _, e in { { V(0.4, 0.04, 18), ground + side * 5.5 }, { V(0.4, 0.04, 18), ground - side * 5.5 }, { V(11.4, 0.04, 0.4), ground - d.dir * 9 } } do
		b.P("DropLine", e[1], CFrame.lookAt(e[2] + V(0, 0.03, 0), e[2] + V(0, 0.03, 0) + d.dir), C(240, 200, 40), M.SmoothPlastic, { parent = g, deco = true })
	end
	site.Parent = sitesRoot()
	table.insert(out, string.format("ChopShop ground %.1f parts=%d", gy, b.n))
	-- sites from the old map layout that no longer exist
	for _, old in { "BoostSpotA", "BoostSpotB", "BoostSpotC", "AtmLiquor", "AtmCourts", "TipAlleyFoodMart", "TipAlleyLaundromat", "TipAlleyWings" } do
		local o = sitesRoot():FindFirstChild(old)
		if o then
			o:Destroy()
			table.insert(out, "removed old " .. old)
		end
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- tip jobs (Dre hears about money in a wall)

-- A bricked-up utility chase built out from a real wall. The front ("Wall") is what the sledgehammer breaks:
-- CrimeJobs hides every part under Wall and shows every part under Hole. Swing faces the wall at chest height,
-- Stash is the shelf inside where the cash is laid.
B.Tips = {
	{ id = "TipTrap", title = "the side of the boarded-up house on NW 52nd", at = V(-1880, 0, -827), out = V(-1, 0, 0), brick = C(150, 96, 76) },
	{ id = "TipLaundromat", title = "the alley wall by the laundromat", at = V(-1418.5, 0, -906.5), out = V(0, 0, 1), brick = C(170, 160, 146) },
	{ id = "TipWings", title = "the back wall of the wing spot", at = V(-1604, 0, 46.0), out = V(-0.196, 0, -0.981), brick = C(140, 92, 70) },
	{ id = "TipCourts", title = "the old wall by Westside Courts", at = V(-1926.2, 0, 140), out = V(-1, 0, 0), brick = C(160, 150, 140) },
}

local function tipWall(b, site, F: CFrame, brick: Color3, i: number)
	local L = function(x, y, z)
		return F * CFrame.new(x, y, z)
	end
	local rng = Random.new(900 + i)
	local fixed = b.group("Chase", site)
	local mortar = C(196, 190, 178)
	-- permanent sides + cap of the chase (a little proud of the house wall)
	for _, sx in { -1.8, 1.8 } do
		b.P("ChaseSide", V(0.4, 6.6, 1.7), L(sx, 3.3, -0.85), mortar, M.Concrete, { parent = fixed })
	end
	b.P("ChaseCap", V(4.2, 0.5, 1.9), L(0, 6.85, -0.9), C(150, 148, 144), M.Concrete, { parent = fixed })
	-- the breakable front: old brick, a fresher mortar patch where someone sealed it up, a faded tag
	local wall = Instance.new("Model")
	wall.Name = "Wall"
	wall.Parent = site
	b.P("WallBrick", V(3.2, 6.6, 0.4), L(0, 3.3, -1.5), brick, M.Brick, { parent = wall })
	b.P("WallPatch", V(1.6, 1.4, 0.42), L(rng:NextNumber(-0.5, 0.5), rng:NextNumber(2.6, 3.8), -1.5), C(200, 196, 186), M.Concrete, { parent = wall, deco = true })
	b.P("WallPatch", V(0.9, 0.7, 0.42), L(rng:NextNumber(-0.9, 0.9), rng:NextNumber(4.6, 5.6), -1.5), C(190, 186, 176), M.Concrete, { parent = wall, deco = true })
	local tag = b.P("WallTag", V(2.6, 1.2, 0.02), L(0, 1.6, -1.72), brick, M.SmoothPlastic, { parent = wall, deco = true, Transparency = 0 })
	K.sign(tag, Enum.NormalId.Front, "NO DUMPING", brick, C(240, 240, 240), { font = Enum.Font.GothamBlack })
	-- the hole (hidden until the wall comes down): dark cavity, a plank shelf, a garbage-bag stash, rubble
	local hole = Instance.new("Model")
	hole.Name = "Hole"
	hole.Parent = site
	local hp = function(name, size, cf, color, mat, shape)
		local p = b.P(name, size, cf, color, mat, { parent = hole, deco = true, shape = shape })
		p.Transparency = 1
		return p
	end
	hp("Cavity", V(3.2, 6.6, 0.1), L(0, 3.3, -0.06), C(26, 22, 20), M.Concrete)
	hp("Shelf", V(3.0, 0.15, 1.2), L(0, 2.4, -0.7), C(120, 88, 56), M.Wood)
	hp("ShelfBracket", V(0.15, 0.6, 1.0), L(-1.2, 2.05, -0.65), C(80, 80, 84), M.Metal)
	hp("ShelfBracket", V(0.15, 0.6, 1.0), L(1.2, 2.05, -0.65), C(80, 80, 84), M.Metal)
	hp("StashBag", V(1.2, 0.9, 0.9), L(0.9, 0.45, -0.7), C(20, 20, 22), M.Plastic, Enum.PartType.Ball)
	for k = 1, 12 do
		local x = rng:NextNumber(-1.5, 1.5)
		local y = if k <= 6 then rng:NextNumber(0.15, 0.5) else rng:NextNumber(0.4, 6.4)
		local z = if k <= 6 then rng:NextNumber(-2.6, -1.3) else -1.5
		if k > 6 then
			x = (if k % 2 == 0 then -1 else 1) * rng:NextNumber(1.3, 1.6)
		end
		hp("Rubble", V(rng:NextNumber(0.4, 0.8), rng:NextNumber(0.3, 0.5), rng:NextNumber(0.3, 0.6)), L(x, y, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), brick, M.Brick)
	end
	-- street junk beside it (permanent)
	b.P("TrashBag", V(1.5, 1.3, 1.3), L(2.9, 0.6, -0.9), C(24, 24, 26), M.Plastic, { parent = fixed, deco = true, shape = Enum.PartType.Ball })
	b.P("TrashBag", V(1.2, 1.0, 1.1), L(3.5, 0.5, -1.9), C(30, 30, 34), M.Plastic, { parent = fixed, deco = true, shape = Enum.PartType.Ball })
	return {
		Swing = CFrame.lookAt((L(0, 3.2, -2.4)).Position, (L(0, 3.2, 0)).Position),
		Stash = L(-0.2, 2.48, -0.7),
		Center = L(0, 0, -4),
	}
end

function B.tips()
	local out = {}
	for i, t in B.Tips do
		local site = newSite(t.id, "TipWall")
		site:SetAttribute("Title", t.title)
		local b = K.builder(site)
		local pts = Instance.new("Folder")
		pts.Name = "Points"
		pts.Parent = site
		local o = t.out.Unit
		local gy = groundY(t.at.X + o.X * 3, t.at.Z + o.Z * 3, 12)
		local pos = V(t.at.X, gy, t.at.Z)
		local F = CFrame.lookAt(pos, pos + o)
		for name, cf in tipWall(b, site, F, t.brick, i) do
			point(pts, name, cf)
		end
		site.Parent = sitesRoot()
		table.insert(out, string.format("%s ground %.1f parts=%d", t.id, gy, b.n))
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- props (ServerStorage.MTL_CrimeProps)

-- Loot_<look>: the model's PrimaryPart "Body" is an invisible box around the whole prop (CrimeJobs puts
-- Body's bottom on the Loot point and welds everything to the torso for the Hug carry). Front = -Z.
-- Van: PrimaryPart Body at the pivot, 4.1 above the ground; rear doors at +Z (the van point backs it to the house).
local function propModel(name: string, bodySize: Vector3): (Model, (string, Vector3, CFrame, Color3, Enum.Material?, any?) -> BasePart)
	local m = Instance.new("Model")
	m.Name = name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = bodySize
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new()
	body.Parent = m
	m.PrimaryPart = body
	local function part(n: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, opts: any?): BasePart
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if opts then
			for k, v in opts do
				(p :: any)[k] = v
			end
		end
		p.Parent = m
		return p
	end
	return m, part
end

local function lootTV(): Model
	local m, part = propModel("Loot_TV", V(3.4, 2.25, 0.8))
	local bot = -2.25 / 2
	local black = C(16, 16, 18)
	part("Panel", V(3.3, 1.9, 0.1), CFrame.new(0, bot + 0.3 + 0.95, 0.05), black, M.SmoothPlastic)
	part("Screen", V(3.18, 1.78, 0.02), CFrame.new(0, bot + 1.25, -0.01), C(14, 18, 28), M.Glass, { Reflectance = 0.25 })
	part("Glare", V(0.5, 1.8, 0.01), CFrame.new(-0.9, bot + 1.25, -0.025) * CFrame.Angles(0, 0, math.rad(-25)), C(70, 80, 100), M.Glass, { Transparency = 0.8 })
	part("Back", V(2.2, 1.2, 0.22), CFrame.new(0, bot + 1.2, 0.2), C(28, 28, 30), M.SmoothPlastic)
	part("Logo", V(0.3, 0.05, 0.02), CFrame.new(0, bot + 0.36, -0.01), C(180, 180, 186), M.Metal)
	for _, x in { -1.3, 1.3 } do
		part("Foot", V(0.12, 0.3, 0.75), CFrame.new(x, bot + 0.15, 0.05) * CFrame.Angles(math.rad(10), 0, 0), C(40, 40, 44), M.Metal)
	end
	return m
end

local function lootSpeaker(): Model
	local m, part = propModel("Loot_Speaker", V(1.2, 2.0, 1.2))
	part("Cabinet", V(1.2, 2.0, 1.15), CFrame.new(0, 0, 0.025), C(26, 24, 24), M.Wood)
	part("Baffle", V(1.1, 1.9, 0.04), CFrame.new(0, 0, -0.56), C(14, 14, 16), M.Fabric)
	part("Woofer", V(0.06, 0.85, 0.85), CFrame.new(0, -0.35, -0.6) * CFrame.Angles(0, math.rad(90), 0), C(40, 40, 46), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part("WooferCap", V(0.08, 0.28, 0.28), CFrame.new(0, -0.35, -0.62) * CFrame.Angles(0, math.rad(90), 0), C(70, 70, 76), M.Metal, { Shape = Enum.PartType.Cylinder })
	part("Tweeter", V(0.06, 0.36, 0.36), CFrame.new(0, 0.45, -0.6) * CFrame.Angles(0, math.rad(90), 0), C(150, 150, 156), M.Metal, { Shape = Enum.PartType.Cylinder })
	part("Port", V(0.06, 0.22, 0.22), CFrame.new(0, 0.8, -0.6) * CFrame.Angles(0, math.rad(90), 0), C(4, 4, 6), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part("LED", V(0.08, 0.04, 0.02), CFrame.new(0.4, -0.85, -0.59), C(40, 120, 255), M.Neon)
	return m
end

local function lootConsole(): Model
	local m, part = propModel("Loot_Console", V(1.5, 0.55, 1.2))
	local bot = -0.55 / 2
	part("Shell", V(1.4, 0.32, 1.1), CFrame.new(0, bot + 0.16, 0), C(236, 236, 240), M.SmoothPlastic)
	part("Core", V(1.42, 0.08, 1.12), CFrame.new(0, bot + 0.16, 0), C(20, 20, 22), M.SmoothPlastic)
	part("Light", V(0.5, 0.02, 0.02), CFrame.new(0, bot + 0.16, -0.565), C(60, 140, 255), M.Neon)
	-- a controller left on top
	local cy = bot + 0.32 + 0.07
	part("Pad", V(0.55, 0.12, 0.3), CFrame.new(0.2, cy, 0.1) * CFrame.Angles(0, math.rad(15), 0), C(30, 30, 34), M.SmoothPlastic)
	for _, x in { -0.25, 0.25 } do
		part("Grip", V(0.16, 0.12, 0.3), CFrame.new(0.2, cy, 0.1) * CFrame.Angles(0, math.rad(15), 0) * CFrame.new(x, -0.01, 0.1), C(30, 30, 34), M.SmoothPlastic)
	end
	return m
end

local function lootLaptop(): Model
	local m, part = propModel("Loot_Laptop", V(1.3, 0.14, 0.95))
	part("Base", V(1.3, 0.06, 0.95), CFrame.new(0, -0.04, 0), C(170, 172, 178), M.Metal)
	part("Lid", V(1.3, 0.05, 0.95), CFrame.new(0, 0.035, 0), C(186, 188, 194), M.Metal)
	part("Seam", V(1.31, 0.012, 0.955), CFrame.new(0, -0.008, 0), C(60, 60, 64), M.SmoothPlastic)
	part("Logo", V(0.18, 0.01, 0.18), CFrame.new(0, 0.062, 0.05), C(230, 230, 236), M.Glass, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, 0.062, 0.05) * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.01, 0.18, 0.18) })
	return m
end

local function lootMicrowave(): Model
	local m, part = propModel("Loot_Microwave", V(1.9, 1.1, 1.3))
	part("Box", V(1.9, 1.1, 1.25), CFrame.new(0, 0, 0.025), C(222, 222, 226), M.SmoothPlastic)
	part("Door", V(1.3, 0.85, 0.04), CFrame.new(-0.25, 0, -0.62), C(20, 20, 24), M.Glass, { Reflectance = 0.15 })
	part("DoorMesh", V(1.0, 0.6, 0.01), CFrame.new(-0.25, 0, -0.645), C(40, 40, 46), M.DiamondPlate, { Transparency = 0.4 })
	part("Handle", V(0.06, 0.6, 0.08), CFrame.new(0.38, 0, -0.66), C(180, 180, 186), M.Metal)
	part("Panel", V(0.42, 0.95, 0.03), CFrame.new(0.68, 0, -0.62), C(40, 40, 44), M.SmoothPlastic)
	local clock = part("Clock", V(0.32, 0.14, 0.02), CFrame.new(0.68, 0.3, -0.64), C(10, 30, 14), M.SmoothPlastic)
	K.sign(clock, Enum.NormalId.Front, "12:00", C(10, 30, 14), C(80, 255, 120), { lit = true, font = Enum.Font.Code })
	for r = 0, 2 do
		for c2 = 0, 1 do
			part("Btn", V(0.12, 0.08, 0.02), CFrame.new(0.6 + c2 * 0.16, 0.08 - r * 0.13, -0.64), C(200, 200, 206), M.SmoothPlastic)
		end
	end
	return m
end

local function lootJewelry(): Model
	local m, part = propModel("Loot_Jewelry", V(0.9, 0.62, 0.62))
	local bot = -0.31
	part("Box", V(0.9, 0.36, 0.6), CFrame.new(0, bot + 0.18, 0), C(96, 30, 44), M.Fabric)
	part("Lid", V(0.92, 0.2, 0.62), CFrame.new(0, bot + 0.46, 0), C(110, 34, 50), M.Fabric)
	part("Trim", V(0.93, 0.03, 0.63), CFrame.new(0, bot + 0.36, 0), C(226, 196, 120), M.Metal)
	part("Clasp", V(0.16, 0.12, 0.04), CFrame.new(0, bot + 0.36, -0.32), C(226, 196, 120), M.Metal)
	-- a gold chain hanging out of the lid
	for k = 0, 5 do
		part("Chain", V(0.06, 0.06, 0.06), CFrame.new(0.25 + k * 0.03, bot + 0.36 - k * 0.05, -0.33 - k * 0.01), C(240, 200, 90), M.Metal, { Shape = Enum.PartType.Ball })
	end
	return m
end

local function vanProp(): Model
	local m, part = propModel("Van", V(7, 6.4, 15))
	local body = m.PrimaryPart :: BasePart
	body.Transparency = 0
	body.Color = C(226, 226, 222)
	body.Material = M.Metal
	local Y = -4.1 -- ground relative to the pivot
	local white, trim, glass = C(226, 226, 222), C(30, 30, 32), C(24, 30, 38)
	part("Cab", V(6.8, 4.2, 3.4), CFrame.new(0, Y + 3.2, -9.0), white, M.Metal)
	part("Hood", V(6.6, 0.6, 1.6), CFrame.new(0, Y + 3.0, -10.9) * CFrame.Angles(math.rad(-8), 0, 0), white, M.Metal)
	part("Windshield", V(6.2, 2.1, 0.12), CFrame.new(0, Y + 4.4, -10.55) * CFrame.Angles(math.rad(-14), 0, 0), glass, M.Glass, { Reflectance = 0.2 })
	for _, sx in { -1, 1 } do
		part("CabWindow", V(0.06, 1.7, 2.4), CFrame.new(sx * 3.42, Y + 4.4, -9.0), glass, M.Glass, { Reflectance = 0.2 })
		part("Mirror", V(0.2, 0.7, 0.5), CFrame.new(sx * 3.75, Y + 4.4, -10.2), trim)
		part("Headlight", V(1.1, 0.5, 0.08), CFrame.new(sx * 2.5, Y + 2.6, -11.68), C(255, 250, 230), M.Neon)
		part("Taillight", V(0.4, 1.2, 0.08), CFrame.new(sx * 3.2, Y + 3.0, 7.54), C(200, 20, 20), M.Neon)
		part("SideRust", V(0.06, 0.8, 4.5), CFrame.new(sx * 3.52, Y + 1.6, 3.5), C(140, 90, 60), M.CorrodedMetal)
	end
	part("Grille", V(4.0, 0.9, 0.1), CFrame.new(0, Y + 2.0, -11.7), trim, M.DiamondPlate)
	part("BumperF", V(7.0, 0.7, 0.6), CFrame.new(0, Y + 1.2, -11.6), trim)
	part("BumperR", V(7.2, 0.7, 0.6), CFrame.new(0, Y + 1.3, 7.7), trim)
	part("DoorL", V(3.4, 5.6, 0.15), CFrame.new(-1.75, Y + 4.1, 7.58), C(214, 214, 210), M.Metal)
	part("DoorR", V(3.4, 5.6, 0.15), CFrame.new(1.75, Y + 4.1, 7.58), C(214, 214, 210), M.Metal)
	part("DoorHandle", V(0.5, 0.12, 0.1), CFrame.new(0.3, Y + 4.2, 7.7), C(170, 170, 174), M.Metal)
	part("Plate", V(1.4, 0.7, 0.05), CFrame.new(0, Y + 1.9, 7.68), C(240, 240, 236), M.SmoothPlastic)
	part("RackL", V(0.15, 0.15, 13), CFrame.new(-3.0, Y + 7.45, 0.5), C(60, 60, 64), M.Metal)
	part("RackR", V(0.15, 0.15, 13), CFrame.new(3.0, Y + 7.45, 0.5), C(60, 60, 64), M.Metal)
	for z = -5, 6, 3.6 do
		part("RackBar", V(6.2, 0.15, 0.15), CFrame.new(0, Y + 7.45, z), C(60, 60, 64), M.Metal)
	end
	part("Ladder", V(1.6, 0.2, 10), CFrame.new(1.4, Y + 7.65, 0.5), C(190, 190, 196), M.Metal)
	for _, x in { -3.2, 3.2 } do
		for _, z in { -8.6, 4.8 } do
			part("Wheel", V(1.3, 2.8, 2.8), CFrame.new(x, Y + 1.4, z), C(18, 18, 20), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
			part("Hub", V(1.34, 1.3, 1.3), CFrame.new(x, Y + 1.4, z), C(150, 150, 156), M.Metal, { Shape = Enum.PartType.Cylinder })
		end
	end
	return m
end

function B.props()
	local lib = SS:FindFirstChild("MTL_CrimeProps")
	if not lib then
		lib = Instance.new("Folder")
		lib.Name = "MTL_CrimeProps"
		lib.Parent = SS
	end
	local made = {}
	for _, f in { lootTV, lootSpeaker, lootConsole, lootLaptop, lootMicrowave, lootJewelry, vanProp } do
		local m = f()
		local old = lib:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		m.Parent = lib
		table.insert(made, m.Name)
	end
	return "props: " .. table.concat(made, ", ")
end

return B
