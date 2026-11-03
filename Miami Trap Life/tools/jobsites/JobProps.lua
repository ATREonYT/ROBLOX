-- Real low-poly job items, replacing the plain placeholder parts:
--   ReplicatedStorage.MTL_JobProps.<Prop>        static station props JobFX draws where a station has no map object
--                                                (TimeClock, Podium, Crates, Boxes, Shelf, Bin, Dumpster, Grill,
--                                                Counter, Register, Table, TireRack). Pivot = bottom centre.
--   ReplicatedStorage.MTL_JobProps.Carry.<Kind>  what you hold while carrying (Box, Bag, Tire, Tray, Keys, Crate).
--                                                Pivot = centre; JobService.addCarry welds it in your hands.
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_JobProps)()
local RS = game:GetService("ReplicatedStorage")
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M
local V = Vector3.new

return function()
	local root = RS:FindFirstChild("MTL_JobProps")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "MTL_JobProps"
	local carry = Instance.new("Folder")
	carry.Name = "Carry"
	carry.Parent = root
	local count = 0

	-- static prop: built with its floor point at the origin
	local function static(name: string, build: (any) -> ())
		local m = Instance.new("Model")
		m.Name = name
		local b = K.builder(m)
		build(b)
		local o = b.P("Origin", V(0.2, 0.2, 0.2), CFrame.new(0, 0, 0), C(255, 255, 255), M.SmoothPlastic, { deco = true, Transparency = 1 })
		m.PrimaryPart = o
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		m.Parent = root
		count += b.n
	end
	-- carried item: built around the origin (its centre)
	local function held(name: string, build: (any) -> ())
		local m = Instance.new("Model")
		m.Name = name
		local b = K.builder(m)
		build(b)
		local o = b.P("Origin", V(0.2, 0.2, 0.2), CFrame.new(), C(255, 255, 255), M.SmoothPlastic, { deco = true, Transparency = 1 })
		m.PrimaryPart = o
		m.Parent = carry
		count += b.n
	end
	local function cf(x, y, z)
		return CFrame.new(x, y, z)
	end
	local CARD, TAPE = C(182, 138, 88), C(206, 176, 120)

	---------------------------------------------------------------- carried items
	held("Box", function(b)
		b.P("Box", V(2, 1.6, 1.6), cf(0, 0, 0), CARD, M.Cardboard)
		b.P("Tape", V(0.35, 0.04, 1.62), cf(0, 0.8, 0), TAPE, M.SmoothPlastic)
		b.P("TapeFront", V(0.35, 0.5, 0.04), cf(0, 0.55, -0.8), TAPE, M.SmoothPlastic)
		local l = b.P("Label", V(0.9, 0.6, 0.03), cf(-0.45, -0.1, -0.81), C(250, 250, 246), M.SmoothPlastic)
		K.sign(l, Enum.NormalId.Front, "LIBERTY\nFOOD MART", C(250, 250, 246), C(30, 96, 58))
		b.P("Arrow", V(0.3, 0.4, 0.03), cf(0.6, -0.2, -0.81), C(30, 30, 30), M.SmoothPlastic)
	end)
	held("Bag", function(b)
		local BAG = C(28, 28, 30)
		b.P("Body", V(1.5, 1.7, 1.4), cf(0, -0.1, 0), BAG, M.Plastic, { Reflectance = 0.05 })
		b.P("Lump", V(1.0, 0.8, 1.0), cf(0.25, 0.5, 0.1) * CFrame.Angles(0, 0.4, 0.2), BAG, M.Plastic)
		b.P("Lump2", V(0.9, 0.7, 0.9), cf(-0.4, -0.7, -0.2) * CFrame.Angles(0.3, 0, 0), BAG, M.Plastic)
		b.P("Knot", V(0.45, 0.5, 0.45), cf(0, 0.95, 0), BAG, M.Plastic)
		b.P("Tie", V(0.5, 0.15, 0.5), cf(0, 0.8, 0), C(250, 200, 30), M.Plastic)
	end)
	held("Tire", function(b)
		b.P("Tire", V(0.9, 2.4, 2.4), cf(0, 0, 0), C(26, 26, 28), M.Rubber, { shape = Enum.PartType.Cylinder })
		b.P("Tread", V(0.7, 2.46, 2.46), cf(0, 0, 0), C(40, 40, 42), M.Rubber, { shape = Enum.PartType.Cylinder })
		b.P("Rim", V(0.92, 1.5, 1.5), cf(0, 0, 0), C(170, 172, 176), M.Metal, { shape = Enum.PartType.Cylinder })
		b.P("Hub", V(0.96, 0.5, 0.5), cf(0, 0, 0), C(90, 92, 96), M.Metal, { shape = Enum.PartType.Cylinder })
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			b.P("Spoke", V(0.94, 0.12, 0.55), cf(0, math.cos(a) * 0.45, math.sin(a) * 0.45) * CFrame.Angles(a, 0, 0), C(150, 152, 156), M.Metal)
		end
	end)
	held("Tray", function(b)
		b.P("Tray", V(2.2, 0.15, 1.4), cf(0, 0, 0), C(200, 40, 40), M.Plastic)
		b.P("Paper", V(1.9, 0.02, 1.1), cf(0, 0.085, 0), C(250, 240, 214), M.SmoothPlastic)
		-- burger: bun, patty, cheese, bun
		b.P("BunLow", V(0.25, 0.75, 0.75), cf(-0.5, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)), C(214, 150, 70), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		b.P("Patty", V(0.18, 0.8, 0.8), cf(-0.5, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), C(110, 60, 40), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		b.P("Cheese", V(0.62, 0.05, 0.62), cf(-0.5, 0.53, 0) * CFrame.Angles(0, math.rad(45), 0), C(250, 200, 50), M.SmoothPlastic)
		b.P("Lettuce", V(0.06, 0.82, 0.82), cf(-0.5, 0.57, 0) * CFrame.Angles(0, 0, math.rad(90)), C(90, 170, 60), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		b.P("BunTop", V(0.7, 0.4, 0.7), cf(-0.5, 0.78, 0), C(214, 150, 70), M.SmoothPlastic, { shape = Enum.PartType.Ball })
		-- fries + cup
		b.P("FryBox", V(0.45, 0.6, 0.3), cf(0.25, 0.37, 0.2), C(200, 30, 30), M.SmoothPlastic)
		for i = 0, 4 do
			b.P("Fry", V(0.07, 0.4, 0.07), cf(0.1 + i * 0.07, 0.75, 0.2) * CFrame.Angles(0, 0, math.rad((i - 2) * 6)), C(250, 200, 70), M.SmoothPlastic)
		end
		b.P("Cup", V(0.45, 0.85, 0.45), cf(0.75, 0.5, -0.2), C(250, 250, 246), M.SmoothPlastic)
		b.P("CupBand", V(0.47, 0.25, 0.47), cf(0.75, 0.5, -0.2), C(200, 30, 30), M.SmoothPlastic)
		b.P("Lid", V(0.48, 0.06, 0.48), cf(0.75, 0.95, -0.2), C(240, 240, 240), M.SmoothPlastic)
		b.P("Straw", V(0.06, 0.45, 0.06), cf(0.8, 1.15, -0.2), C(200, 30, 30), M.SmoothPlastic)
	end)
	held("Keys", function(b)
		b.P("Fob", V(0.28, 0.42, 0.1), cf(0, 0, 0), C(26, 26, 28), M.SmoothPlastic)
		b.P("FobBtn", V(0.14, 0.08, 0.02), cf(0, 0.08, -0.06), C(200, 30, 30), M.SmoothPlastic)
		b.P("Ring", V(0.04, 0.3, 0.3), cf(0, 0.32, 0) * CFrame.Angles(0, math.rad(90), 0), C(200, 200, 204), M.Metal, { shape = Enum.PartType.Cylinder })
		b.P("Key", V(0.08, 0.4, 0.03), cf(0.05, 0.55, 0) * CFrame.Angles(0, 0, math.rad(15)), C(220, 190, 70), M.Metal)
		b.P("Tag", V(0.25, 0.35, 0.02), cf(-0.12, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-20)), C(250, 210, 40), M.SmoothPlastic)
	end)
	held("Crate", function(b)
		local WOOD, DARK = C(160, 118, 72), C(120, 86, 52)
		b.P("Core", V(2.2, 1.8, 1.8), cf(0, 0, 0), C(90, 70, 50), M.WoodPlanks)
		for _, y in { -0.6, 0, 0.6 } do
			for _, z in { -0.92, 0.92 } do
				b.P("Slat", V(2.4, 0.45, 0.08), cf(0, y, z), WOOD, M.WoodPlanks)
			end
			for _, x in { -1.12, 1.12 } do
				b.P("SlatSide", V(0.08, 0.45, 2.0), cf(x, y, 0), WOOD, M.WoodPlanks)
			end
		end
		for _, x in { -1.12, 1.12 } do
			for _, z in { -0.92, 0.92 } do
				b.P("Corner", V(0.2, 2.0, 0.2), cf(x, 0, z), DARK, M.WoodPlanks)
			end
		end
		b.P("Lid", V(2.4, 0.1, 2.0), cf(0, 0.95, 0), WOOD, M.WoodPlanks)
		local st = b.P("Stencil", V(1.4, 0.5, 0.02), cf(0, 0.3, -0.97), WOOD, M.SmoothPlastic, { Transparency = 1 })
		K.sign(st, Enum.NormalId.Front, "FRAGILE", nil, C(40, 30, 20), { font = Enum.Font.Arcade })
	end)

	---------------------------------------------------------------- static station props (bottom centre at origin)
	static("TimeClock", function(b)
		b.P("Post", V(0.35, 4.0, 0.35), cf(0, 2.0, 0), C(60, 60, 66), M.Metal)
		b.P("Foot", V(1.4, 0.15, 1.0), cf(0, 0.075, 0), C(60, 60, 66), M.Metal)
		b.P("Box", V(1.4, 1.7, 0.7), cf(0, 4.6, 0), C(214, 210, 196), M.SmoothPlastic)
		b.P("Face", V(1.0, 0.6, 0.04), cf(0, 4.95, -0.37), C(250, 250, 250), M.SmoothPlastic)
		b.P("Digits", V(0.7, 0.24, 0.03), cf(0, 4.95, -0.39), C(255, 80, 60), M.Neon)
		b.P("Slot", V(0.6, 0.1, 0.04), cf(0, 4.25, -0.37), C(20, 20, 20), M.SmoothPlastic)
		b.P("CardRack", V(1.2, 1.6, 0.25), cf(0, 2.7, -0.3), C(150, 150, 154), M.Metal)
		for i = 0, 5 do
			b.P("Card", V(0.16, 0.8, 0.04), cf(-0.45 + i * 0.18, 3.1, -0.45), C(240, 236, 210), M.SmoothPlastic)
		end
	end)
	static("Podium", function(b)
		b.P("Base", V(2.0, 0.2, 1.5), cf(0, 0.1, 0), C(30, 30, 32), M.Metal)
		b.P("Stand", V(1.6, 3.4, 1.1), cf(0, 1.9, 0), C(110, 26, 36), M.Wood)
		b.P("Top", V(1.9, 0.15, 1.4), cf(0, 3.65, 0) * CFrame.Angles(math.rad(10), 0, 0), C(40, 30, 24), M.Wood)
		b.P("Trim", V(1.62, 0.15, 1.12), cf(0, 0.8, 0), C(200, 170, 80), M.Metal)
		local s = b.P("Sign", V(1.3, 0.7, 0.03), cf(0, 2.6, -0.57), C(110, 26, 36), M.SmoothPlastic)
		K.sign(s, Enum.NormalId.Front, "VALET", C(110, 26, 36), C(230, 200, 110), { font = Enum.Font.Garamond })
		b.P("KeyBox", V(1.0, 0.9, 0.2), cf(0, 3.0, 0.62), C(50, 50, 54), M.Metal)
		for i = 0, 5 do
			b.P("Hook", V(0.06, 0.25, 0.06), cf(-0.35 + i * 0.14, 3.1, 0.75), C(220, 190, 70), M.Metal)
		end
		b.P("Umbrella", V(0.15, 4.0, 0.15), cf(1.4, 2.0, 0.3) * CFrame.Angles(0, 0, math.rad(8)), C(30, 30, 34), M.Fabric)
		b.P("Lamp", V(0.25, 0.25, 0.25), cf(-0.6, 3.85, 0.2), C(255, 220, 160), M.Neon)
	end)
	static("Crates", function(b)
		b.P("Pallet", V(4.4, 0.45, 3.6), cf(0, 0.225, 0), C(170, 130, 80), M.WoodPlanks)
		for i, p in { V(-1.1, 1.45, 0), V(1.1, 1.45, 0), V(0, 3.45, 0) } do
			b.P("Crate" .. i, V(2.1, 2.0, 2.0), CFrame.new(p) * CFrame.Angles(0, math.rad((i - 2) * 4), 0), C(160, 118, 72), M.WoodPlanks)
			b.P("Band" .. i, V(2.14, 0.2, 2.04), CFrame.new(p) * CFrame.Angles(0, math.rad((i - 2) * 4), 0), C(60, 60, 64), M.Metal)
		end
		b.P("Wrap", V(4.3, 2.0, 2.2), cf(0, 1.45, 0), C(230, 236, 240), M.Glass, { Transparency = 0.75 })
		local tag = b.P("Manifest", V(0.8, 1.0, 0.03), cf(-1.1, 1.6, -1.02), C(250, 250, 246), M.SmoothPlastic)
		K.sign(tag, Enum.NormalId.Front, "SHIP\nTO:", C(250, 250, 246), C(20, 20, 20), { font = Enum.Font.Arcade })
	end)
	static("Boxes", function(b)
		b.P("Pallet", V(3.6, 0.4, 3.6), cf(0, 0.2, 0), C(170, 130, 80), M.WoodPlanks)
		for i, p in { V(-0.9, 1.2, -0.9), V(0.9, 1.2, -0.9), V(-0.9, 1.2, 0.9), V(0.9, 1.2, 0.9), V(0, 2.8, 0) } do
			b.P("Box" .. i, V(1.75, 1.55, 1.7), CFrame.new(p) * CFrame.Angles(0, math.rad(i * 3 - 6), 0), CARD, M.Cardboard)
			b.P("Tape" .. i, V(0.3, 0.03, 1.72), CFrame.new(p + V(0, 0.78, 0)) * CFrame.Angles(0, math.rad(i * 3 - 6), 0), TAPE, M.SmoothPlastic)
		end
	end)
	static("Bin", function(b)
		b.P("Can", V(2.6, 2.0, 2.0), cf(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), C(60, 64, 70), M.Metal, { shape = Enum.PartType.Cylinder })
		b.P("Rim", V(0.15, 2.1, 2.1), cf(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C(40, 40, 44), M.Metal, { shape = Enum.PartType.Cylinder })
		b.P("Liner", V(0.4, 1.9, 1.9), cf(0, 2.75, 0) * CFrame.Angles(0, 0, math.rad(90)), C(26, 26, 28), M.Plastic, { shape = Enum.PartType.Cylinder })
	end)
	static("Dumpster", function(b)
		b.P("Body", V(6, 3.6, 3.4), cf(0, 2.1, 0), C(40, 110, 70), M.Metal)
		b.P("LidA", V(3.0, 0.2, 3.6), cf(-1.5, 4.0, 0) * CFrame.Angles(math.rad(4), 0, 0), C(30, 30, 34), M.Plastic)
		b.P("LidB", V(3.0, 0.2, 3.6), cf(1.5, 4.0, 0) * CFrame.Angles(math.rad(-3), 0, 0), C(30, 30, 34), M.Plastic)
		for _, x in { -2.4, 2.4 } do
			b.P("Wheel", V(0.4, 0.6, 0.6), cf(x, 0.3, 1.2), C(20, 20, 20), M.Rubber, { shape = Enum.PartType.Cylinder })
		end
		local s = b.P("Stencil", V(3.0, 0.8, 0.03), cf(0, 2.5, -1.72), C(40, 110, 70), M.SmoothPlastic, { Transparency = 1 })
		K.sign(s, Enum.NormalId.Front, "DRY GARBAGE", nil, C(240, 240, 230), { font = Enum.Font.Arcade })
	end)
	static("Shelf", function(b)
		b.P("Back", V(6, 6, 0.3), cf(0, 3, 0.9), C(210, 212, 218), M.SmoothPlastic)
		for i = 0, 3 do
			b.P("Board" .. i, V(6, 0.2, 1.8), cf(0, 0.2 + i * 1.6, 0), C(225, 226, 230), M.Metal)
		end
		for _, x in { -3, 3 } do
			b.P("Side", V(0.2, 6.2, 1.9), cf(x, 3.1, 0), C(132, 136, 142), M.Metal)
		end
	end)
	static("Grill", function(b)
		b.P("Base", V(4, 2.85, 2.6), cf(0, 1.425, 0), C(196, 198, 202), M.Metal)
		b.P("Plate", V(3.8, 0.15, 2.4), cf(0, 2.92, 0), C(40, 40, 42), M.Metal)
		b.P("Splash", V(4, 1, 0.15), cf(0, 3.4, 1.22), C(196, 198, 202), M.Metal)
	end)
	static("Counter", function(b)
		b.P("Body", V(6, 3.2, 2.2), cf(0, 1.6, 0), C(178, 34, 34), M.SmoothPlastic)
		b.P("Top", V(6.2, 0.15, 2.4), cf(0, 3.27, 0), C(196, 198, 202), M.Metal)
	end)
	static("Register", function(b)
		b.P("Counter", V(5, 3.2, 2.2), cf(0, 1.6, 0), C(122, 74, 46), M.Wood)
		b.P("Top", V(5.2, 0.15, 2.4), cf(0, 3.27, 0), C(44, 44, 48), M.Slate)
		b.P("Till", V(1.2, 0.5, 1.1), cf(-1, 3.6, 0), C(40, 42, 50), M.SmoothPlastic)
		b.P("Screen", V(1.0, 0.7, 0.08), cf(-1, 4.2, 0.2) * CFrame.Angles(math.rad(-15), 0, 0), C(110, 200, 255), M.Neon)
	end)
	static("Table", function(b)
		b.P("Top", V(3.4, 0.2, 3.4), cf(0, 2.6, 0), C(220, 214, 200), M.Marble)
		b.P("Post", V(0.35, 2.5, 0.35), cf(0, 1.25, 0), C(50, 50, 54), M.Metal)
		b.P("Foot", V(1.4, 0.12, 1.4), cf(0, 0.06, 0), C(50, 50, 54), M.Metal)
	end)
	static("TireRack", function(b)
		for _, x in { -2.4, 2.4 } do
			b.P("Upright", V(0.2, 4.6, 1.8), cf(x, 2.3, 0), C(200, 60, 30), M.Metal)
		end
		for _, y in { 0.3, 2.6 } do
			b.P("Bar", V(5, 0.2, 0.2), cf(0, y, -0.6), C(200, 60, 30), M.Metal)
			b.P("Bar", V(5, 0.2, 0.2), cf(0, y, 0.6), C(200, 60, 30), M.Metal)
			for i = -1, 1 do
				b.P("Tire", V(0.95, 2.2, 2.2), cf(i * 1.4, y + 1.2, 0), C(26, 26, 28), M.Rubber, { shape = Enum.PartType.Cylinder })
				b.P("Rim", V(0.97, 1.2, 1.2), cf(i * 1.4, y + 1.2, 0), C(150, 152, 156), M.Metal, { shape = Enum.PartType.Cylinder })
			end
		end
	end)

	-- make every prop part harmless (JobFX draws these client-side only)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
	root.Parent = RS
	return string.format("MTL_JobProps: %d parts (%d static props, %d carried items)", count, #root:GetChildren() - 1, #carry:GetChildren())
end
