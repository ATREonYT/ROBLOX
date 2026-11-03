-- "Lived-in" detail pass for the job interiors (Nov 3). ADDITIVE ONLY: each room gets one child Model named
-- "LivedIn" that this script rebuilds; nothing else in the room is touched (the props thread's PropSwap owns the
-- swapped meshes inside the rooms, and the JobSite_* builders must not be re-run any more).
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_LivedIn)({ "foodmart", "burger", "auto" })
-- Budget: every LivedIn part is decoration: no collision, no query/touch, no shadow (except a couple of big props),
-- so a room's clutter costs draw calls only. The report gives the part count per room.
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M
local V = Vector3.new

local function fresh(parent: Instance): (Model, any)
	local old = parent:FindFirstChild("LivedIn")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "LivedIn"
	m:SetAttribute("MTL_Style", "LivedInV1")
	return m, K.builder(m)
end

-- after building: everything decorative, no shadows on small things
local function finish(m: Model, parent: Instance)
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if not d:GetAttribute("Solid") then
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			end
			local s = d.Size
			if math.max(s.X, s.Y, s.Z) < 4 then
				d.CastShadow = false
			end
		end
	end
	m.Parent = parent
	return n
end

local function sign(b, name, size, cf, text, bg, fg, face, lit)
	local p = b.P(name, size, cf, bg, M.SmoothPlastic, {})
	K.sign(p, face or Enum.NormalId.Front, text, bg, fg, { lit = lit, font = Enum.Font.GothamBold })
	return p
end

-- small reusable bits -------------------------------------------------------------------------
local function wallClock(b, cf: CFrame) -- cf: centre, LookVector = out of the wall
	b.P("ClockRim", V(0.2, 1.6, 1.6), cf * CFrame.Angles(0, math.rad(90), 0), C(30, 30, 32), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	b.P("ClockFace", V(0.05, 1.4, 1.4), cf * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, math.rad(90), 0), C(236, 234, 226), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	b.P("HandH", V(0.08, 0.45, 0.03), cf * CFrame.new(0.1, 0.15, -0.12) * CFrame.Angles(0, 0, math.rad(-35)), C(20, 20, 20), M.SmoothPlastic, {})
	b.P("HandM", V(0.06, 0.6, 0.03), cf * CFrame.new(-0.05, 0.25, -0.13) * CFrame.Angles(0, 0, math.rad(10)), C(20, 20, 20), M.SmoothPlastic, {})
end

local function scuff(b, cf: CFrame, w: number, l: number, a: number?)
	b.P("Scuff", V(w, 0.02, l), cf * CFrame.Angles(0, a or 0, 0), C(60, 56, 50), M.SmoothPlastic, { Transparency = 0.82 })
end

local function exitSign(b, cf: CFrame)
	local p = b.P("ExitSign", V(1.6, 0.6, 0.15), cf, C(30, 30, 30), M.SmoothPlastic, {})
	K.sign(p, Enum.NormalId.Front, "EXIT", C(20, 20, 20), C(255, 60, 50), { lit = true, font = Enum.Font.GothamBlack })
	K.sign(p, Enum.NormalId.Back, "EXIT", C(20, 20, 20), C(255, 60, 50), { lit = true, font = Enum.Font.GothamBlack })
end

local function cart(b, cf: CFrame) -- shopping cart, ~11 parts; cf at floor, LookVector = push direction
	local G = C(170, 172, 176)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	b.P("Basket", V(1.9, 1.5, 2.8), at(0, 2.65, 0), G, M.DiamondPlate, { Transparency = 0.35 })
	b.P("BasketRim", V(2.0, 0.1, 2.9), at(0, 3.4, 0), G, M.Metal, {})
	b.P("Handle", V(1.9, 0.18, 0.18), at(0, 3.9, 1.6), C(200, 30, 30), M.Plastic, {})
	for _, x in { -0.9, 0.9 } do
		b.P("HandleArm", V(0.1, 0.9, 0.1), at(x, 3.45, 1.5), G, M.Metal, {})
		b.P("Frame", V(0.1, 0.1, 3.2), at(x * 0.8, 0.45, -0.1), G, M.Metal, {})
		for _, z in { -1.4, 1.2 } do
			b.P("Wheel", V(0.2, 0.45, 0.45), at(x * 0.85, 0.22, z), C(30, 30, 30), M.Rubber, { shape = Enum.PartType.Cylinder })
		end
	end
	b.P("BottomRack", V(1.6, 0.06, 2.6), at(0, 0.6, -0.1), G, M.DiamondPlate, { Transparency = 0.3 })
end

local function basketStack(b, cf: CFrame, n: number)
	b.P("BasketStand", V(1.6, 0.3, 1.2), cf * CFrame.new(0, 0.15, 0), C(60, 60, 64), M.Metal, {})
	for i = 0, n - 1 do
		local y = 0.3 + 0.55 + i * 0.32
		b.P("Basket", V(1.5, 0.9, 1.1), cf * CFrame.new(0, y, 0), C(196, 30, 36), M.Plastic, { Transparency = 0.1 })
	end
	b.P("BasketHandle", V(0.08, 0.5, 1.0), cf * CFrame.new(-0.55, 0.3 + n * 0.32 + 1.0, 0) * CFrame.Angles(0, 0, math.rad(25)), C(40, 40, 44), M.Plastic, {})
end

local function openBox(b, cf: CFrame, fill: Color3)
	b.P("Box", V(1.8, 1.3, 1.5), cf * CFrame.new(0, 0.65, 0), C(182, 138, 88), M.Cardboard, {})
	b.P("Fill", V(1.6, 0.2, 1.3), cf * CFrame.new(0, 1.25, 0), fill, M.SmoothPlastic, {})
	b.P("Flap", V(1.8, 0.05, 0.7), cf * CFrame.new(0, 1.45, 0.95) * CFrame.Angles(math.rad(-60), 0, 0), C(182, 138, 88), M.Cardboard, {})
	b.P("Flap", V(1.8, 0.05, 0.7), cf * CFrame.new(0, 1.45, -0.95) * CFrame.Angles(math.rad(60), 0, 0), C(182, 138, 88), M.Cardboard, {})
end

local function sprinklers(b, x0, x1, z0, z1, y, step)
	local x = x0
	while x <= x1 do
		local z = z0
		while z <= z1 do
			b.P("Sprinkler", V(0.25, 0.25, 0.25), CFrame.new(x, y - 0.15, z), C(200, 180, 120), M.Metal, {})
			z += step
		end
		x += step
	end
end

---------------------------------------------------------------- Liberty Food Mart
local function foodmart()
	local store = workspace.ViceBay.Landmarks.Hood.FoodMart
	local room = store:FindFirstChild("InteriorV2")
	if not room then
		return "foodmart: InteriorV2 missing"
	end
	local m, b = fresh(room)
	local FY, CEIL = 2.15, 15.85
	local function W(x, y, z)
		return CFrame.new(x, FY + y, z)
	end
	-- entrance: carts, basket stack, flyer rack, mat scuffs
	-- (kept off the FirstDay cutscene path: player walks (-1427,-321) -> (-1439,-319), cameras near x -1451)
	cart(b, W(-1486.5, 0, -321.2) * CFrame.Angles(0, math.rad(90), 0))
	cart(b, W(-1486.5, 0, -318.6) * CFrame.Angles(0, math.rad(90), 0))
	basketStack(b, W(-1433.0, 0, -322.6), 5)
	local rack = b.P("FlyerRack", V(1.4, 3.4, 0.6), W(-1430.6, 1.7, -322.7), C(30, 90, 170), M.Metal, {})
	_ = rack
	for i = 0, 2 do
		local p = sign(b, "Flyer", V(1.1, 0.8, 0.04), W(-1430.6, 1.2 + i * 0.95, -322.38) * CFrame.Angles(math.rad(-10), 0, 0), ({ "WEEKLY\nDEALS", "APARTMENTS\nFOR RENT", "AUTO\nTRADER" })[i + 1], ({ C(250, 214, 60), C(240, 240, 236), C(200, 40, 40) })[i + 1], C(20, 20, 20))
		_ = p
	end
	for i, s in { { -1442, -320.5, 3.2, 2.2, 0.2 }, { -1440.5, -318.2, 2.0, 1.4, 0.9 }, { -1424.6, -320.6, 1.6, 3.0, 0 }, { -1439.1, -310, 1.4, 5.0, 0.05 }, { -1449.1, -303, 1.2, 4.0, -0.04 } } do
		scuff(b, W(s[1], 0.03, s[2]), s[3], s[4], s[5])
		_ = i
	end
	-- community board + help wanted + wall clock near the door
	local board = b.P("CorkBoard", V(3.2, 2.2, 0.12), W(-1476.0, 6.3, -306.32), C(170, 120, 70), M.Fabric, {})
	_ = board
	local notes = { "LOST CAT\n305-555-0110", "GUITAR LESSONS", "ROOM 4 RENT", "BRAIDS $40", "JESUS SAVES", "CAR 4 SALE" }
	for i, t in notes do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		sign(b, "Note", V(0.85, 0.75, 0.03), W(-1477.0 + col * 1.0, 6.75 - row * 0.95, -306.4) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 4)), t, Color3.fromHSV(0.1 + i * 0.12, 0.25, 0.98), C(30, 30, 30), Enum.NormalId.Front)
	end
	sign(b, "HelpWanted", V(2.2, 1.4, 0.03), W(-1430.5, 5.0, -323.85), "HELP WANTED\nAPPLY INSIDE", C(250, 250, 246), C(200, 30, 30), Enum.NormalId.Front)
	wallClock(b, W(-1420.0, 9.6, -323.0) * CFrame.Angles(0, math.rad(180), 0))
	-- checkout counter life: bag dispenser, receipt rolls, phone, coffee, tip jar, impulse rack
	b.P("BagRoll", V(0.9, 1.2, 0.9), W(-1424.4, 4.15, -320.6), C(240, 240, 236), M.Plastic, {})
	b.P("BagHolder", V(1.0, 0.1, 1.0), W(-1424.4, 3.55, -320.6), C(150, 150, 154), M.Metal, {})
	for i = 0, 2 do
		b.P("ReceiptRoll", V(0.35, 0.5, 0.5), W(-1424.4, 3.75, -316.6 + i * 0.35) * CFrame.Angles(0, 0, math.rad(90)), C(245, 245, 240), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	end
	b.P("Phone", V(0.35, 0.05, 0.7), W(-1424.5, 3.53, -318.9), C(20, 20, 24), M.Glass, {})
	b.P("Coffee", V(0.35, 0.5, 0.35), W(-1424.3, 3.75, -319.6), C(250, 250, 246), M.SmoothPlastic, {})
	b.P("CoffeeSleeve", V(0.37, 0.2, 0.37), W(-1424.3, 3.7, -319.6), C(150, 100, 60), M.Cardboard, {})
	-- stocking in progress: open boxes + box cutter in the aisles, a pallet jack by the stockroom door
	openBox(b, W(-1441.4, 0, -306.5), C(200, 40, 40))
	openBox(b, W(-1441.2, 0, -304.6) * CFrame.Angles(0, math.rad(12), 0), C(250, 214, 60))
	b.P("BoxCutter", V(0.5, 0.08, 0.15), W(-1441.0, 1.32, -306.1), C(250, 200, 30), M.Plastic, {})
	b.P("JackFork", V(1.6, 0.25, 4.2), W(-1460.6, 0.15, -297.5), C(200, 40, 30), M.Metal, {})
	b.P("JackBody", V(1.0, 1.2, 0.8), W(-1460.6, 0.7, -299.9), C(200, 40, 30), M.Metal, {})
	b.P("JackHandle", V(0.15, 3.8, 0.15), W(-1460.6, 2.6, -300.5) * CFrame.Angles(math.rad(-15), 0, 0), C(30, 30, 30), M.Metal, {})
	-- wet floor sign + mop bucket where the floor gets mopped
	local wet = b.P("WetSign", V(1.0, 2.2, 0.08), W(-1418.0, 1.1, -306.0) * CFrame.Angles(math.rad(10), math.rad(30), 0), C(250, 210, 30), M.Plastic, {})
	K.sign(wet, Enum.NormalId.Front, "⚠\nCAUTION\nWET FLOOR", C(250, 210, 30), C(20, 20, 20))
	b.P("MopBucket", V(1.3, 1.1, 1.0), W(-1416.6, 0.55, -304.6), C(250, 200, 30), M.Plastic, {})
	b.P("Wringer", V(1.0, 0.5, 0.8), W(-1416.6, 1.3, -304.6), C(40, 40, 44), M.Plastic, {})
	b.P("Mop", V(0.12, 5.0, 0.12), W(-1416.4, 2.8, -304.4) * CFrame.Angles(math.rad(-10), 0, math.rad(8)), C(200, 180, 140), M.Wood, {})
	-- sale danglers on the gondola ends facing the front
	for i, x in { -1434.1, -1444.1 } do
		local d = b.P("Dangler", V(1.2, 1.2, 0.03), W(x, 6.6, -312.0), C(250, 214, 60), M.SmoothPlastic, {})
		K.sign(d, Enum.NormalId.Front, i == 1 and "BUY 1\nGET 1" or "$1.99\nEACH", C(250, 214, 60), C(200, 20, 20))
		b.P("DanglerWire", V(0.03, 0.9, 0.03), W(x, 7.65, -312.0), C(40, 40, 40), M.Metal, {})
	end
	-- ceiling services: sprinklers, smoke detectors, exit signs over both doors
	sprinklers(b, -1517, -1415, -320, -290, CEIL, 10)
	for _, p in { V(-1440, 0, -315), V(-1470, 0, -300), V(-1505, 0, -305), V(-1425, 0, -296) } do
		b.P("SmokeDet", V(0.25, 0.9, 0.9), CFrame.new(p.X, CEIL - 0.12, p.Z), C(236, 236, 230), M.SmoothPlastic, { shape = Enum.PartType.Cylinder, CFrame = CFrame.new(p.X, CEIL - 0.12, p.Z) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	exitSign(b, W(-1442, 9.2, -322.9))
	exitSign(b, CFrame.new(-1478, FY + 9.0, -287.2))
	return "foodmart LivedIn: " .. finish(m, room) .. " parts"
end

---------------------------------------------------------------- Burger Shack
local function burger()
	local shop
	for _, x in workspace.ViceBay.Landmarks.Hood:GetChildren() do
		if x.Name == "Shops" and x:FindFirstChild("BurgerShackV2") then
			shop = x.BurgerShackV2
		end
	end
	if not shop then
		return "burger: missing"
	end
	local m, b = fresh(shop)
	local FY, CEIL = 2.15, 15.85
	local function W(x, y, z)
		return CFrame.new(x, FY + y, z)
	end
	-- a finished meal left on booth 2, crumpled napkins on booth 3
	b.P("Tray", V(1.4, 0.08, 1.0), W(-1430.0, 2.74, -457.2), C(178, 34, 34), M.Plastic, {})
	b.P("Wrapper", V(0.9, 0.06, 0.8), W(-1430.0, 2.8, -457.2) * CFrame.Angles(0, 0.5, 0), C(240, 228, 200), M.SmoothPlastic, {})
	b.P("Cup", V(0.45, 0.85, 0.45), W(-1430.7, 3.15, -456.4), C(250, 250, 246), M.SmoothPlastic, {})
	b.P("Lid", V(0.47, 0.05, 0.47), W(-1430.7, 3.6, -456.4), C(240, 240, 236), M.SmoothPlastic, {})
	b.P("Straw", V(0.06, 0.5, 0.06), W(-1430.6, 3.85, -456.4) * CFrame.Angles(0, 0, math.rad(8)), C(200, 30, 30), M.SmoothPlastic, {})
	b.P("FryBox", V(0.45, 0.5, 0.3), W(-1429.4, 2.95, -456.6) * CFrame.Angles(0, 0, math.rad(80)), C(178, 34, 34), M.SmoothPlastic, {})
	for i = 0, 2 do
		b.P("Napkin", V(0.35, 0.25, 0.35), W(-1421.4 + i * 0.4, 2.82, -455.4 - (i % 2) * 0.4) * CFrame.Angles(i, i * 2, 0), C(250, 250, 246), M.SmoothPlastic, {})
	end
	-- high chair, tray return with stacked trays, wall TV with a game on
	b.P("HighChairSeat", V(1.0, 0.2, 1.0), W(-1443.0, 2.5, -467.0), C(150, 100, 60), M.Wood, {})
	for _, dx in { -0.4, 0.4 } do
		for _, dz in { -0.4, 0.4 } do
			b.P("HighChairLeg", V(0.12, 2.5, 0.12), W(-1443.0 + dx, 1.25, -467.0 + dz), C(150, 100, 60), M.Wood, {})
		end
	end
	b.P("HighChairBack", V(1.0, 1.0, 0.12), W(-1443.0, 3.1, -467.45), C(150, 100, 60), M.Wood, {})
	for i = 0, 5 do
		b.P("StackTray", V(1.4, 0.07, 1.0), W(-1450.9, 3.85 + i * 0.08, -468.4), C(178, 34, 34), M.Plastic, {})
	end
	local tv = b.P("TV", V(5.0, 2.9, 0.25), W(-1413.6, 9.2, -463.0) * CFrame.Angles(0, math.rad(90), 0), C(20, 20, 22), M.SmoothPlastic, {})
	local screen = b.P("TVScreen", V(4.6, 2.5, 0.02), tv.CFrame * CFrame.new(0, 0, -0.14), C(30, 60, 30), M.SmoothPlastic, {})
	K.sign(screen, Enum.NormalId.Front, "HEAT 102 - 99 CELTICS · Q4 1:12", C(30, 110, 50), C(255, 255, 255), { lit = true, font = Enum.Font.GothamBold })
	b.P("TVMount", V(0.6, 0.6, 0.5), W(-1413.3, 9.2, -463.0), C(40, 40, 44), M.Metal, {})
	-- ceiling fans over the dining room
	for _, x in { -1440, -1424 } do
		b.P("FanRod", V(0.15, 1.2, 0.15), CFrame.new(x, CEIL - 0.6, -464), C(40, 40, 44), M.Metal, {})
		b.P("FanHub", V(0.5, 0.8, 0.8), CFrame.new(x, CEIL - 1.25, -464) * CFrame.Angles(0, 0, math.rad(90)), C(40, 40, 44), M.Metal, { shape = Enum.PartType.Cylinder })
		for k = 0, 3 do
			b.P("FanBlade", V(2.6, 0.06, 0.55), CFrame.new(x, CEIL - 1.3, -464) * CFrame.Angles(0, math.rad(k * 90 + 20), 0) * CFrame.new(1.5, 0, 0), C(120, 84, 50), M.Wood, {})
		end
	end
	-- kitchen grease, ticket printer, sauce bottles, mop bucket, wall clock, employee board
	for _, s in { { -1439, -488.2, 4.0, 2.0 }, { -1446.5, -487.6, 2.2, 1.6 }, { -1436, -478.0, 3.0, 1.6 } } do
		b.P("Grease", V(s[3], 0.02, s[4]), W(s[1], 0.03, s[2]), C(70, 50, 30), M.SmoothPlastic, { Transparency = 0.7 })
	end
	b.P("TicketPrinter", V(0.7, 0.5, 0.7), W(-1431.0, 3.72, -473.3), C(30, 30, 32), M.SmoothPlastic, {})
	b.P("TicketPaper", V(0.4, 0.04, 0.6), W(-1431.0, 3.75, -473.75) * CFrame.Angles(math.rad(30), 0, 0), C(250, 250, 246), M.SmoothPlastic, {})
	for i, col in { C(200, 20, 20), C(250, 210, 30), C(200, 20, 20), C(240, 240, 236) } do
		b.P("Squeeze", V(0.3, 0.8, 0.3), W(-1435.5 + i * 0.4, 3.62, -480.6), col, M.SmoothPlastic, {})
	end
	wallClock(b, W(-1452.25, 10.0, -480.0) * CFrame.Angles(0, math.rad(-90), 0))
	sign(b, "EmployeeBoard", V(0.04, 1.2, 1.6), W(-1452.28, 6.5, -482.4), "EMPLOYEE\nOF THE MONTH\nTASHA", C(255, 255, 255), C(178, 34, 34), Enum.NormalId.Right)
	exitSign(b, W(-1449.3, 9.0, -453.9))
	sprinklers(b, -1450, -1416, -488, -458, CEIL, 10)
	return "burger LivedIn: " .. finish(m, shop) .. " parts"
end

---------------------------------------------------------------- Westside Auto
local function auto()
	local shop = workspace.ViceBay.Landmarks.Hood.AutoShop:FindFirstChild("AutoShopV2")
	if not shop then
		return "auto: missing"
	end
	local m, b = fresh(shop)
	local FY, CEIL = 2.15, 17.0
	local function W(x, y, z)
		return CFrame.new(x, FY + y, z)
	end
	-- red rolling tool cart by lift 1
	local cx, cz = -1031.5, -473.5
	b.P("CartBody", V(2.6, 2.6, 1.6), W(cx, 1.6, cz), C(200, 30, 30), M.Metal, {})
	for i = 0, 3 do
		b.P("Drawer", V(2.4, 0.05, 0.05), W(cx, 0.8 + i * 0.6, cz - 0.82), C(200, 200, 204), M.Metal, {})
	end
	b.P("CartTop", V(2.7, 0.12, 1.7), W(cx, 2.96, cz), C(40, 40, 44), M.Rubber, {})
	for i, col in { C(200, 200, 204), C(30, 30, 30), C(240, 196, 30), C(200, 30, 30) } do
		b.P("Tool", V(0.9, 0.12, 0.2), W(cx - 0.9 + i * 0.4, 3.08, cz - 0.3 + (i % 2) * 0.4) * CFrame.Angles(0, i, 0), col, M.Metal, {})
	end
	for _, dx in { -1.1, 1.1 } do
		for _, dz in { -0.6, 0.6 } do
			b.P("Caster", V(0.25, 0.3, 0.3), W(cx + dx, 0.15, cz + dz), C(30, 30, 30), M.Rubber, { shape = Enum.PartType.Cylinder })
		end
	end
	-- air hose reel on a pier + hose on the floor, used tire stack by bay D, rag pile, coffee can of bolts
	b.P("HoseReel", V(0.6, 2.2, 2.2), W(-1015.5, 6.5, -462.9) * CFrame.Angles(0, math.rad(90), 0), C(240, 196, 30), M.Plastic, { shape = Enum.PartType.Cylinder })
	b.P("AirHose", V(0.15, 0.15, 8), W(-1017, 0.08, -467) * CFrame.Angles(0, math.rad(35), 0), C(30, 30, 30), M.Rubber, {})
	for i = 0, 3 do
		b.P("UsedTire", V(0.95, 2.6, 2.6), W(-984.5 + (i % 2) * 0.3, 0.5 + i * 0.95, -490.5) * CFrame.Angles(0, 0, math.rad(90)), C(26, 26, 28), M.Rubber, { shape = Enum.PartType.Cylinder })
	end
	for i = 0, 2 do
		b.P("Rag", V(0.8, 0.12, 0.6), W(-1041.5 + i * 0.3, 3.42 + i * 0.05, -492.8) * CFrame.Angles(0, i, 0.1), Color3.fromHSV(0.02 + i * 0.3, 0.5, 0.7), M.Fabric, {})
	end
	b.P("BoltCan", V(0.5, 0.6, 0.5), W(-1044.6, 3.6, -492.9), C(150, 40, 40), M.Metal, {})
	-- radio on the bench, wall fan, car calendar, oil spill under bay C, extension cord
	b.P("Radio", V(1.2, 0.7, 0.5), W(-1042.6, 3.7, -493.0), C(40, 40, 44), M.SmoothPlastic, {})
	b.P("RadioDial", V(0.4, 0.4, 0.05), W(-1042.9, 3.75, -492.73), C(220, 160, 60), M.Neon, {})
	b.P("RadioAntenna", V(0.04, 1.4, 0.04), W(-1042.2, 4.6, -493.0) * CFrame.Angles(0, 0, math.rad(-20)), C(180, 180, 184), M.Metal, {})
	b.P("FanCage", V(0.6, 2.4, 2.4), W(-1035.4, 9.5, -478.0), C(60, 60, 64), M.DiamondPlate, { shape = Enum.PartType.Cylinder, Transparency = 0.3 })
	b.P("FanMount", V(0.5, 0.5, 0.5), W(-1035.65, 9.5, -478.0), C(40, 40, 44), M.Metal, {})
	sign(b, "Calendar", V(1.4, 2.0, 0.04), W(-1038.5, 7.0, -494.42), "NOVEMBER\n<font size=\"14\">CLASSIC CARS</font>", C(250, 250, 246), C(30, 70, 150), Enum.NormalId.Back)
	b.P("OilSpill", V(3.2, 0.02, 2.4), W(-1005.0, 0.03, -485.5), C(30, 28, 24), M.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	b.P("ExtCord", V(0.1, 0.1, 10), W(-1000.2, 0.06, -488) * CFrame.Angles(0, math.rad(-10), 0), C(250, 140, 20), M.Rubber, {})
	exitSign(b, W(-1042.0, 9.2, -462.6))
	return "auto LivedIn: " .. finish(m, shop) .. " parts"
end


---------------------------------------------------------------- Bayside Mall
local function mall()
	local bm = workspace.ViceBay.Buildings.Hood:FindFirstChild("BaysideMall")
	local inside = bm and bm:FindFirstChild("Inside")
	if not inside then
		return "mall: missing"
	end
	local m, b = fresh(inside)
	local FY, CH = 2.65, 14
	local XC, ZC, Z0, Z1 = -1016, -579.5, -593.5, -565.5
	local function W(x, y, z)
		return CFrame.new(x, FY + y, z)
	end
	-- window posters in the shop fronts (corridor side)
	local posters = { { -1021.2, -569.0, "SALE\n50% OFF", C(200, 30, 30) }, { -1021.2, -590.5, "NEW\nDROPS", C(20, 20, 20) }, { -1010.8, -569.0, "GRILLZ\nFROM $99", C(200, 160, 40) }, { -1010.8, -590.5, "WALK-INS\nWELCOME", C(230, 110, 170) } }
	for _, ps in posters do -- on the corridor face of each unit's glass, clear of the door gaps
		local face = if ps[1] < XC then Enum.NormalId.Right else Enum.NormalId.Left
		local x = if ps[1] < XC then ps[1] + 0.14 else ps[1] - 0.14
		sign(b, "WindowPoster", V(0.03, 1.8, 2.2), W(x, 5.2, ps[2]), ps[3], ps[4], C(255, 255, 255), face)
	end
	-- shopping bags left on the benches, a trash can, wet floor sign, wall clock, speakers, exit sign
	for i, col in { C(200, 30, 30), C(250, 250, 246), C(30, 30, 30) } do
		b.P("ShopBag", V(0.9, 1.1, 0.4), W(XC + 3.8, 1.95, Z1 - 4.8 + i * 0.6), col, M.SmoothPlastic, {})
		b.P("BagHandle", V(0.05, 0.4, 0.3), W(XC + 3.8, 2.7, Z1 - 4.8 + i * 0.6), col, M.SmoothPlastic, {})
	end
	b.P("TrashCan", V(2.8, 1.8, 1.8), W(XC + 3.9, 1.4, ZC + 4.0) * CFrame.Angles(0, 0, math.rad(90)), C(60, 64, 68), M.Metal, { shape = Enum.PartType.Cylinder })
	b.P("TrashLid", V(0.3, 1.9, 1.9), W(XC + 3.9, 2.95, ZC + 4.0) * CFrame.Angles(0, 0, math.rad(90)), C(36, 36, 38), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	local wet = b.P("WetSign", V(1.0, 2.2, 0.08), W(XC - 2.5, 1.1, Z0 + 7.5) * CFrame.Angles(math.rad(10), math.rad(-25), 0), C(250, 210, 30), M.Plastic, {})
	K.sign(wet, Enum.NormalId.Front, "⚠\nCAUTION\nWET FLOOR", C(250, 210, 30), C(20, 20, 20))
	wallClock(b, W(XC, 11.0, Z0 + 1.12))
	for _, z in { Z1 - 8, Z0 + 8 } do
		b.P("Speaker", V(1.2, 0.2, 1.2), W(XC, CH - 0.12, z), C(236, 236, 230), M.SmoothPlastic, { shape = Enum.PartType.Cylinder, CFrame = W(XC, CH - 0.12, z) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	sprinklers(b, XC - 4, XC + 4, Z0 + 3, Z1 - 3, FY + CH, 8)
	exitSign(b, W(XC, 9.6, Z1 - 1.2))
	for i, s in { { XC - 1, Z1 - 3, 3, 2 }, { XC + 1.5, ZC + 2, 1.6, 4 }, { XC - 0.5, Z0 + 4, 2, 2 } } do
		scuff(b, W(s[1], 0.06, s[2]), s[3], s[4], i * 0.3)
	end
	return "mall LivedIn: " .. finish(m, inside) .. " parts"
end

return function(which: { string }?)
	local out = {}
	for _, w in which or { "foodmart", "burger", "auto" } do
		if w == "foodmart" then
			table.insert(out, foodmart())
		elseif w == "burger" then
			table.insert(out, burger())
		elseif w == "auto" then
			table.insert(out, auto())
		elseif w == "mall" then
			table.insert(out, mall())
		end
		task.wait()
	end
	return table.concat(out, " | ")
end
