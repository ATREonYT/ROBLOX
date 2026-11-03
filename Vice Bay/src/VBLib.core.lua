-- Vice Bay map builder library (edit-time only; delete before publishing)
local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local L = {}
local M = Enum.Material
L.M = M
local TAU = math.pi * 2
L.TAU = TAU

L.rng = Random.new(1337)
function L.seed(s) L.rng = Random.new(s) end
function L.r(a, b) return a + L.rng:NextNumber() * (b - a) end
function L.ri(a, b) return L.rng:NextInteger(a, b) end
function L.pick(t) return t[L.rng:NextInteger(1, #t)] end
function L.chance(p) return L.rng:NextNumber() < p end
function L.C(r, g, b) return Color3.fromRGB(r, g, b) end
local C = L.C
function L.shade(c, k) return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1)) end

local hasVar = {}
for _, v in ipairs(MS:GetDescendants()) do
	if v:IsA("MaterialVariant") then hasVar[v.Name] = true end
end
L.hasVar = hasVar

function L.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
function L.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function apply(p, size, cf, color, mat, var, opt)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or C(200, 200, 200)
	p.Material = mat or M.SmoothPlastic
	if var and hasVar[var] then p.MaterialVariant = var end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if size.X * size.Y * size.Z < 60 then p.CastShadow = false end
	if opt then for k, v in pairs(opt) do p[k] = v end end
	return p
end
function L.P(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), size, cf, color, mat, var, opt)
	p.Parent = parent
	return p
end
function L.W(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("WedgePart"), size, cf, color, mat, var, opt)
	p.Parent = parent
	return p
end
-- vertical cylinder: height h, diameter d, centered at pos (CFrame)
function L.Cyl(parent, h, d, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, var, opt)
	p.Shape = Enum.PartType.Cylinder
	p.Parent = parent
	return p
end
function L.Ball(parent, d, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), Vector3.new(d, d, d), cf, color, mat, var, opt)
	p.Shape = Enum.PartType.Ball
	p.Parent = parent
	return p
end
-- box resting on ground: local frame cf (ground level), offset x,z, bottom y0, size
function L.B(parent, cf, x, y0, z, sx, sy, sz, color, mat, var, opt)
	return L.P(parent, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y0 + sy / 2, z), color, mat, var, opt)
end

-- SurfaceGui text on a part face
function L.text(part, face, txt, opt)
	opt = opt or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opt.pps or 25
	g.LightInfluence = opt.light or 0.6
	g.MaxDistance = opt.dist or 300
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = opt.bg and 0 or 1
	if opt.bg then t.BackgroundColor3 = opt.bg end
	t.Size = opt.size or UDim2.fromScale(1, 1)
	t.Position = opt.pos or UDim2.fromScale(0, 0)
	t.AnchorPoint = opt.anchor or Vector2.new(0, 0)
	t.Rotation = opt.rot or 0
	t.Text = txt
	t.TextScaled = true
	t.Font = opt.font or Enum.Font.GothamBlack
	t.TextColor3 = opt.color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = opt.stroke or 1
	t.TextTransparency = opt.trans or 0
	t.Parent = g
	return g
end
function L.sign(parent, cf, sx, sy, txt, bg, fg, font, opt)
	local p = L.P(parent, Vector3.new(sx, sy, 0.4), cf, bg or C(30, 30, 30), M.SmoothPlastic)
	p.Name = "Sign"
	opt = opt or {}
	opt.color = fg
	opt.font = font
	L.text(p, Enum.NormalId.Front, txt, opt)
	if opt.both then L.text(p, Enum.NormalId.Back, txt, opt) end
	return p
end

L.TAGS = { "LIL G", "WESTSIDE", "305", "VICE", "KING RO", "DREAMS", "NO LOVE", "LH GANG", "RIP TONY", "LOYALTY", "MONEY", "BLESSED", "OVERTOWN", "ZOE", "TRUST NO1", "FREE MIKE" }
L.TAGCOLORS = { C(255, 80, 160), C(80, 200, 255), C(255, 220, 60), C(120, 255, 120), C(255, 120, 40), C(240, 240, 240), C(180, 90, 255), C(255, 60, 60) }
function L.graffiti(part, face, txt)
	L.text(part, face, txt or L.pick(L.TAGS), {
		font = L.pick({ Enum.Font.PermanentMarker, Enum.Font.FredokaOne, Enum.Font.Bangers, Enum.Font.Creepster }),
		color = L.pick(L.TAGCOLORS), stroke = 0.4,
		size = UDim2.fromScale(L.r(0.35, 0.7), L.r(0.18, 0.3)),
		pos = UDim2.fromScale(L.r(0.05, 0.4), L.r(0.6, 0.72)), rot = L.r(-8, 8), dist = 220, pps = 12, light = 1,
	})
end

------------------------------------------------------------------
-- ROAD NETWORK
-- nodes: {[id] = {x, z, cul=bool}}, edges: {{a, b, width, style}}
-- style: {var, color, sw (sidewalk width, 0 = none), swVar, swColor, center ("single","double","dashed","none"),
--   lineColor, lineTrans, lanes (bool), edgeLines (bool), patches (n), cross ("ladder","zebra",nil), poles (bool), lights (bool), palms (bool), swDrop (chance a side has no sidewalk)}
local ROAD_Y = 0.25
function L.buildRoads(parent, net, folderName)
	local root = L.folder(parent, folderName or "Roads")
	local nodes, edges = net.nodes, net.edges
	local adj = {}
	for i, e in ipairs(edges) do
		for k = 1, 2 do
			local n = e[k]
			adj[n] = adj[n] or {}
			table.insert(adj[n], i)
		end
	end
	local function dirFrom(n, ei)
		local e = edges[ei]
		local o = (e[1] == n) and e[2] or e[1]
		local A, B = nodes[n], nodes[o]
		return Vector3.new(B[1] - A[1], 0, B[2] - A[2]).Unit
	end
	-- trim distance for edge ei at node n (how far from node center the crossing road extends along this edge)
	local function trimAt(n, ei)
		local list = adj[n]
		if #list == 1 then return 0, "end" end
		if #list == 2 then return 0, "bend" end
		local d0 = dirFrom(n, ei)
		local t = 0
		for _, oj in ipairs(list) do
			if oj ~= ei then
				local d1 = dirFrom(n, oj)
				local s = math.abs(d0:Cross(d1).Y)
				s = math.max(s, 0.45)
				t = math.max(t, (edges[oj][3] / 2) / s)
			end
		end
		return t, "junction"
	end
	local nodeDone = {}
	for i, e in ipairs(edges) do
		local st = e[4]
		local seg = Instance.new("Model")
		seg.Name = "Road_" .. i
		local A, B = nodes[e[1]], nodes[e[2]]
		local a = Vector3.new(A[1], 0, A[2])
		local b = Vector3.new(B[1], 0, B[2])
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local w = e[3]
		local hw = w / 2
		local yTop = ROAD_Y + (i % 5) * 0.012
		local cf0 = CFrame.lookAt(a, b) -- -Z along road from a to b; +X is right
		local ta, ka = trimAt(e[1], i)
		local tb, kb = trimAt(e[2], i)
		-- road surface (run to node centers, extend at dead ends)
		local s0 = (ka == "end") and -hw or -0.5
		local s1 = (kb == "end") and len + hw or len + 0.5
		local road = L.P(seg, Vector3.new(w, 0.6, s1 - s0), cf0 * CFrame.new(0, yTop - 0.3, -(s0 + s1) / 2), st.color, M.Asphalt, st.var)
		road.Name = "Asphalt"
		road.CastShadow = false
		-- sidewalks
		local sw = st.sw or 0
		if sw > 0 then
			local ext = 0.35 * (hw + sw)
			local sa = (ka == "junction") and ta or ((ka == "bend") and -ext or 0)
			local sb = (kb == "junction") and tb or ((kb == "bend") and -ext or 0)
			local l0, l1 = sa, len - sb
			if l1 - l0 > 1 then
				for side = -1, 1, 2 do
					if not (st.swDrop and L.chance(st.swDrop)) then
						local h = 0.9 + ((i + side) % 3) * 0.015
						local p = L.P(seg, Vector3.new(sw, h, l1 - l0), cf0 * CFrame.new(side * (hw + sw / 2), h / 2, -(l0 + l1) / 2), st.swColor, M.Concrete, st.swVar)
						p.Name = "Sidewalk"
						p.CastShadow = false
						if st.curb then
							L.P(seg, Vector3.new(0.6, h + 0.02, l1 - l0), cf0 * CFrame.new(side * (hw + 0.3), (h + 0.02) / 2, -(l0 + l1) / 2), st.curb, M.Concrete)
						end
					end
				end
			end
		end
		-- markings (skip near junctions)
		local la = (ka == "junction") and (ta + 3) or 0
		local lb = (kb == "junction") and (tb + 3) or 0
		local m0, m1 = la, len - lb
		local lc = st.lineColor or C(230, 230, 220)
		local lt = st.lineTrans or 0
		local ly = yTop + 0.02
		local function strip(x, z0, z1, width, col)
			if z1 - z0 < 0.5 then return end
			local p = L.P(seg, Vector3.new(width, 0.04, z1 - z0), cf0 * CFrame.new(x, ly, -(z0 + z1) / 2), col or lc, M.SmoothPlastic, nil, { Transparency = lt, CanCollide = false, CanQuery = false })
			p.Name = "Line"
			return p
		end
		local function dashes(x, z0, z1, col)
			local z = z0 + 4
			while z + 10 < z1 do
				strip(x, z, z + 10, 0.5, col)
				z += 30
			end
		end
		if m1 - m0 > 4 then
			if st.center == "single" then
				strip(0, m0, m1, 0.6)
			elseif st.center == "double" then
				strip(-0.55, m0, m1, 0.45, st.centerColor or C(240, 200, 60))
				strip(0.55, m0, m1, 0.45, st.centerColor or C(240, 200, 60))
			elseif st.center == "dashed" then
				dashes(0, m0, m1, st.centerColor)
			elseif st.center == "median" then
				local mw = st.medianW or 8
				local med = L.P(seg, Vector3.new(mw, 1.2, m1 - m0), cf0 * CFrame.new(0, 0.6, -(m0 + m1) / 2), C(170, 170, 165), M.Concrete, st.swVar)
				med.Name = "Median"
				L.P(seg, Vector3.new(mw - 1.2, 0.2, m1 - m0 - 1), cf0 * CFrame.new(0, 1.25, -(m0 + m1) / 2), C(78, 120, 52), M.Grass)
				if st.palms then
					local z = m0 + 12
					while z < m1 - 8 do
						L.palm(seg, (cf0 * CFrame.new(0, 1.3, -z)).Position)
						z += 36
					end
				end
			end
			if st.lanes then
				dashes(-hw / 2, m0, m1)
				dashes(hw / 2, m0, m1)
			end
			if st.edgeLines then
				strip(-hw + 1.6, m0, m1, 0.45)
				strip(hw - 1.6, m0, m1, 0.45)
			end
			if st.bike then
				strip(-hw + 6, m0, m1, 0.5)
				strip(hw - 6, m0, m1, 0.5)
				local g1 = L.P(seg, Vector3.new(4.6, 0.03, m1 - m0), cf0 * CFrame.new(-hw + 3.4, yTop + 0.015, -(m0 + m1) / 2), C(60, 140, 90), M.SmoothPlastic, nil, { CanCollide = false })
				local g2 = L.P(seg, Vector3.new(4.6, 0.03, m1 - m0), cf0 * CFrame.new(hw - 3.4, yTop + 0.015, -(m0 + m1) / 2), C(60, 140, 90), M.SmoothPlastic, nil, { CanCollide = false })
				g1.Name = "BikeLane"; g2.Name = "BikeLane"
			end
		end
		-- crosswalks at junction ends
		if st.cross then
			for endIdx = 1, 2 do
				local kk = endIdx == 1 and ka or kb
				if kk == "junction" then
					local t = endIdx == 1 and ta or tb
					local zc = endIdx == 1 and (t + 5) or (len - t - 5)
					if st.cross == "ladder" then
						strip(0, zc - 4.6, zc - 3.8, w - 1, C(235, 235, 230))
						strip(0, zc + 3.8, zc + 4.6, w - 1, C(235, 235, 230))
					else
						local n = math.floor((w - 2) / 4)
						for k = 0, n - 1 do
							local x = -hw + 2 + k * 4 + 1
							strip(x, zc - 4, zc + 4, 2, C(240, 240, 238))
						end
					end
					-- stop line
					local zs = endIdx == 1 and (t + 11) or (len - t - 11)
					local p = L.P(seg, Vector3.new(hw - 1, 0.04, 0.9), cf0 * CFrame.new((endIdx == 1 and 1 or -1) * hw / 2, ly, -zs), C(235, 235, 230), M.SmoothPlastic, nil, { Transparency = lt, CanCollide = false })
					p.Name = "StopLine"
				end
			end
		end
		-- patches & potholes (rundown)
		if st.patches and st.patches > 0 then
			local n = math.max(1, math.floor(st.patches * len / 120))
			for _ = 1, n do
				local pz = L.r(4, len - 4)
				local px = L.r(-hw + 3, hw - 3)
				local pw, pl = L.r(3, math.min(14, w - 4)), L.r(4, 22)
				local col = L.shade(st.color, L.r(0.72, 1.15))
				local p = L.P(seg, Vector3.new(pw, 0.03, pl), cf0 * CFrame.new(px, yTop + 0.012, -pz) * CFrame.Angles(0, L.r(-0.15, 0.15), 0), col, M.Asphalt, st.var, { CanCollide = false })
				p.Name = "Patch"
			end
			if L.chance(0.5) then
				local p = L.Cyl(seg, 0.05, L.r(1.5, 3), cf0 * CFrame.new(L.r(-hw + 3, hw - 3), yTop + 0.01, -L.r(5, len - 5)), C(35, 33, 31), M.Asphalt, nil, { CanCollide = false })
				p.Name = "Pothole"
			end
		end
		-- utility poles with sagging wires (Beams, no parts)
		if st.poles and len > 40 then
			local side = (i % 2 == 0) and 1 or -1
			local off = hw + (sw > 0 and sw - 1.5 or 2)
			local prevAtt
			local z = 12
			while z < len - 8 do
				local pc = cf0 * CFrame.new(side * off, 0, -z)
				local pole = L.Cyl(seg, 34, 1.1, pc * CFrame.new(0, 17, 0), C(92, 74, 58), M.Wood)
				pole.Name = "UtilityPole"
				pole.CastShadow = true
				local arm = L.P(seg, Vector3.new(7, 0.5, 0.5), pc * CFrame.new(0, 31.5, 0), C(92, 74, 58), M.Wood)
				if L.chance(0.35) then
					L.Cyl(seg, 3, 2, pc * CFrame.new(side * -1.4, 28, 0), C(120, 120, 118), M.Metal) -- transformer
				end
				local att = Instance.new("Attachment")
				att.Position = Vector3.new(0, 0.3, 0)
				att.Parent = arm
				local att2 = Instance.new("Attachment")
				att2.Position = Vector3.new(3, 0.3, 0)
				att2.Parent = arm
				if prevAtt then
					for k, a2 in ipairs({ att, att2 }) do
						local bm = Instance.new("Beam")
						bm.Attachment0 = prevAtt[k]
						bm.Attachment1 = a2
						bm.Width0 = 0.12
						bm.Width1 = 0.12
						bm.Color = ColorSequence.new(C(25, 25, 25))
						bm.CurveSize0 = -3
						bm.CurveSize1 = 3
						bm.FaceCamera = true
						bm.Segments = 8
						bm.LightInfluence = 1
						bm.Parent = arm
					end
				end
				prevAtt = { att, att2 }
				z += L.r(60, 80)
			end
		end
		-- street lights
		if st.lights and len > 40 then
			local z = 20
			local k = 0
			while z < len - 10 do
				local side = (k % 2 == 0) and 1 or -1
				L.streetlight(seg, cf0 * CFrame.new(side * (hw + 1.5), 0.9, -z) * CFrame.Angles(0, side > 0 and math.pi / 2 or -math.pi / 2, 0), st.modernLights)
				z += 70
				k += 1
			end
		end
		-- sidewalk palms
		if st.sidePalms and sw > 0 and len > 40 then
			local z = 18
			while z < len - 12 do
				for side = -1, 1, 2 do
					L.palm(seg, (cf0 * CFrame.new(side * (hw + sw - 2.5), 0.9, -z)).Position)
				end
				z += 46
			end
		end
		seg.Parent = root
		-- node disks for bends and cul-de-sacs
		for k = 1, 2 do
			local n = e[k]
			if not nodeDone[n] then
				nodeDone[n] = true
				local N = nodes[n]
				local deg = #adj[n]
				if deg == 2 then
					local d = L.Cyl(root, 0.6, w, CFrame.new(N[1], ROAD_Y + 0.07 - 0.3, N[2]), st.color, M.Asphalt, st.var)
					d.Name = "Bend"
					d.CastShadow = false
				elseif deg == 1 and N.cul then
					local d = L.Cyl(root, 0.6, w * 2.6, CFrame.new(N[1], ROAD_Y + 0.07 - 0.3, N[2]), st.color, M.Asphalt, st.var)
					d.Name = "CulDeSac"
					d.CastShadow = false
				end
			end
		end
	end
	return root
end

------------------------------------------------------------------
-- PROPS
function L.palm(parent, pos, h)
	h = h or L.r(24, 36)
	local m = Instance.new("Model")
	m.Name = "Palm"
	local lean = L.r(0.03, 0.14)
	local base = CFrame.new(pos) * CFrame.Angles(0, L.r(0, TAU), 0) * CFrame.Angles(lean, 0, 0)
	local seg = h / 2
	local tc = C(140, 118, 92)
	L.Cyl(m, seg + 0.4, 1.7, base * CFrame.new(0, seg / 2, 0), tc, M.Wood)
	local b2 = base * CFrame.new(0, seg, 0) * CFrame.Angles(lean * 0.8, 0, 0)
	L.Cyl(m, seg, 1.35, b2 * CFrame.new(0, seg / 2, 0), L.shade(tc, 1.08), M.Wood)
	local top = (b2 * CFrame.new(0, seg, 0)).Position
	L.Ball(m, 2.4, CFrame.new(top), C(88, 112, 52), M.Grass)
	local n = 7
	local fc = L.pick({ C(64, 112, 44), C(76, 124, 50), C(58, 100, 42) })
	for k = 1, n do
		local a = k / n * TAU + L.r(-0.2, 0.2)
		local fl = L.r(10, 13)
		local cf = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(-L.r(0.25, 0.65), 0, 0)
		local f = L.P(m, Vector3.new(3, 0.25, fl), cf * CFrame.new(0, 0, -fl / 2), fc, M.LeafyGrass, nil, { CanCollide = false })
		f.CastShadow = true
	end
	m.Parent = parent
	return m
end
function L.tree(parent, pos, s)
	s = s or L.r(0.8, 1.3)
	local m = Instance.new("Model")
	m.Name = "Tree"
	L.Cyl(m, 10 * s, 1.6 * s, CFrame.new(pos + Vector3.new(0, 5 * s, 0)), C(96, 76, 58), M.Wood)
	local gc = L.pick({ C(70, 110, 50), C(84, 122, 56), C(62, 98, 46), C(96, 126, 60) })
	local b1 = L.Ball(m, 14 * s, CFrame.new(pos + Vector3.new(0, 13 * s, 0)), gc, M.LeafyGrass, nil, { CanCollide = false })
	local b2 = L.Ball(m, 10 * s, CFrame.new(pos + Vector3.new(L.r(-3, 3) * s, 17 * s, L.r(-3, 3) * s)), L.shade(gc, 1.1), M.LeafyGrass, nil, { CanCollide = false })
	b1.CastShadow = true; b2.CastShadow = true
	m.Parent = parent
	return m
end
function L.bush(parent, pos, s)
	s = s or L.r(3, 6)
	return L.Ball(parent, s, CFrame.new(pos + Vector3.new(0, s * 0.3, 0)), L.pick({ C(64, 100, 44), C(76, 110, 50) }), M.LeafyGrass, nil, { CanCollide = false, Size = Vector3.new(s * 1.3, s * 0.8, s) })
end
function L.streetlight(parent, cf, modern)
	local m = Instance.new("Model")
	m.Name = "StreetLight"
	local col = modern and C(60, 62, 66) or C(130, 130, 125)
	L.Cyl(m, 24, 0.7, cf * CFrame.new(0, 12, 0), col, M.Metal)
	L.P(m, Vector3.new(0.4, 0.4, 7), cf * CFrame.new(0, 23.8, -3.3), col, M.Metal)
	local head = L.P(m, Vector3.new(1.6, 0.5, 3), cf * CFrame.new(0, 23.5, -7), col, M.Metal)
	L.P(m, Vector3.new(1.3, 0.1, 2.6), cf * CFrame.new(0, 23.2, -7), C(255, 236, 200), M.Neon, nil, { CanCollide = false })
	m.Parent = parent
	return m
end
function L.trafficLight(parent, cf, armLen)
	armLen = armLen or 18
	local m = Instance.new("Model")
	m.Name = "TrafficLight"
	local col = C(70, 72, 70)
	L.Cyl(m, 20, 0.9, cf * CFrame.new(0, 10, 0), col, M.Metal)
	L.P(m, Vector3.new(0.5, 0.5, armLen), cf * CFrame.new(0, 19, -armLen / 2), col, M.Metal)
	local box = L.P(m, Vector3.new(1.4, 4.2, 1.4), cf * CFrame.new(0, 17, -armLen + 2), C(30, 30, 30), M.Metal)
	L.Ball(m, 0.9, cf * CFrame.new(0, 18.3, -armLen + 2 + 0.7), C(255, 60, 50), M.Neon)
	L.Ball(m, 0.9, cf * CFrame.new(0, 17, -armLen + 2 + 0.7), C(70, 50, 20), M.SmoothPlastic)
	L.Ball(m, 0.9, cf * CFrame.new(0, 15.7, -armLen + 2 + 0.7), C(20, 60, 30), M.SmoothPlastic)
	m.Parent = parent
	return m
end
function L.hydrant(parent, pos)
	local m = L.model(parent, "Hydrant")
	L.Cyl(m, 2.2, 1, CFrame.new(pos + Vector3.new(0, 1.1, 0)), C(190, 70, 40), M.Metal)
	L.Ball(m, 1, CFrame.new(pos + Vector3.new(0, 2.2, 0)), C(190, 70, 40), M.Metal)
	return m
end
function L.trashcan(parent, pos)
	return L.Cyl(parent, 3.2, 2, CFrame.new(pos + Vector3.new(0, 1.6, 0)), L.pick({ C(40, 70, 50), C(50, 50, 55), C(30, 60, 120) }), M.Plastic)
end
function L.dumpster(parent, cf)
	local m = L.model(parent, "Dumpster")
	L.B(m, cf, 0, 0, 0, 7, 4.5, 4, L.pick({ C(40, 80, 50), C(30, 60, 110), C(70, 70, 70) }), M.DiamondPlate)
	L.B(m, cf, 0, 4.5, 0.2, 7.2, 0.4, 4.4, C(30, 30, 30), M.Plastic)
	return m
end
function L.bench(parent, cf)
	local m = L.model(parent, "Bench")
	L.B(m, cf, 0, 1.6, 0, 6, 0.4, 2, C(120, 86, 56), M.Wood)
	L.B(m, cf, 0, 2, 0.9, 6, 1.8, 0.3, C(120, 86, 56), M.Wood)
	L.B(m, cf, -2.6, 0, 0, 0.4, 1.6, 1.8, C(40, 40, 40), M.Metal)
	L.B(m, cf, 2.6, 0, 0, 0.4, 1.6, 1.8, C(40, 40, 40), M.Metal)
	return m
end
function L.fence(parent, a, b, h, kind)
	-- kind: "chain" (chain-link look), "wall" (low CMU wall), "wood", "iron"
	h = h or 7
	local d = (b - a)
	local len = d.Magnitude
	local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
	local m = L.model(parent, "Fence")
	if kind == "wall" then
		L.P(m, Vector3.new(1, h, len), cf * CFrame.new(0, h / 2, 0), C(196, 190, 178), M.Concrete, "VB_GrimeStucco")
		L.P(m, Vector3.new(1.4, 0.4, len), cf * CFrame.new(0, h + 0.2, 0), C(170, 165, 155), M.Concrete)
	elseif kind == "wood" then
		L.P(m, Vector3.new(0.4, h, len), cf * CFrame.new(0, h / 2, 0), C(130, 104, 76), M.WoodPlanks)
	else
		local col = kind == "iron" and C(30, 30, 30) or C(150, 152, 150)
		L.P(m, Vector3.new(0.12, h - 0.4, len), cf * CFrame.new(0, h / 2, 0), col, kind == "iron" and M.Metal or M.DiamondPlate, nil, { Transparency = kind == "iron" and 0.55 or 0.62 })
		L.P(m, Vector3.new(0.3, 0.3, len), cf * CFrame.new(0, h, 0), col, M.Metal)
		local n = math.max(1, math.floor(len / 10))
		for k = 0, n do
			L.P(m, Vector3.new(0.35, h, 0.35), cf * CFrame.new(0, h / 2, -len / 2 + k * len / n), col, M.Metal)
		end
	end
	return m
end
function L.car(parent, cf, color, style)
	-- cf at ground, facing -Z
	local m = Instance.new("Model")
	m.Name = "ParkedCar"
	color = color or L.pick({ C(30, 30, 32), C(200, 200, 205), C(140, 20, 25), C(25, 50, 110), C(90, 92, 96), C(230, 230, 228), C(60, 30, 20), C(40, 90, 70) })
	style = style or "sedan"
	local L2, W2 = 15, 6.6
	local bodyH = style == "suv" and 3.2 or 2.3
	local y0 = 1.1
	if style == "sports" then bodyH = 1.9; y0 = 0.8 end
	L.P(m, Vector3.new(W2, bodyH, L2), cf * CFrame.new(0, y0 + bodyH / 2, 0), color, M.SmoothPlastic, nil, { Reflectance = 0.12 })
	local cabL = style == "suv" and 9 or (style == "sports" and 5.5 or 7.2)
	local cabH = style == "sports" and 1.5 or 2.1
	local cz = style == "sports" and 0.8 or 0.9
	L.P(m, Vector3.new(W2 - 0.6, cabH, cabL), cf * CFrame.new(0, y0 + bodyH + cabH / 2, cz), C(28, 32, 38), M.Glass, nil, { Reflectance = 0.25 })
	L.P(m, Vector3.new(W2 - 0.5, 0.25, cabL - 1.2), cf * CFrame.new(0, y0 + bodyH + cabH + 0.12, cz), color, M.SmoothPlastic)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local wc = cf * CFrame.new(sx * (W2 / 2 - 0.4), 1.35, sz * 4.8)
			local wh = L.P(m, Vector3.new(1.1, 2.7, 2.7), wc, C(22, 22, 22), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
		end
	end
	L.P(m, Vector3.new(W2 - 1, 0.5, 0.2), cf * CFrame.new(0, y0 + bodyH - 0.5, -L2 / 2 - 0.05), C(255, 250, 235), M.Neon)
	L.P(m, Vector3.new(W2 - 1, 0.5, 0.2), cf * CFrame.new(0, y0 + bodyH - 0.5, L2 / 2 + 0.05), C(200, 20, 20), M.Neon)
	m.Parent = parent
	return m
end
function L.boat(parent, cf, len, color, kind)
	-- simple yacht / speedboat; cf at water level (y = waterline), facing -Z
	local m = Instance.new("Model")
	m.Name = (kind or "Boat")
	len = len or 30
	local w = len * 0.3
	color = color or C(245, 245, 245)
	L.P(m, Vector3.new(w, len * 0.12, len * 0.75), cf * CFrame.new(0, len * 0.03, len * 0.1), color, M.SmoothPlastic)
	L.W(m, Vector3.new(len * 0.12, w / 2, len * 0.25), cf * CFrame.new(w / 4, len * 0.03, -len * 0.4) * CFrame.Angles(0, 0, -math.pi / 2), color, M.SmoothPlastic)
	L.W(m, Vector3.new(len * 0.12, w / 2, len * 0.25), cf * CFrame.new(-w / 4, len * 0.03, -len * 0.4) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic)
	L.P(m, Vector3.new(w * 1.01, len * 0.03, len * 0.75), cf * CFrame.new(0, -len * 0.015, len * 0.1), C(25, 40, 70), M.SmoothPlastic)
	L.P(m, Vector3.new(w * 0.8, len * 0.02, len * 0.6), cf * CFrame.new(0, len * 0.095, len * 0.12), C(200, 175, 130), M.WoodPlanks, "VB_DockPlanks")
	if len >= 40 then
		L.P(m, Vector3.new(w * 0.75, len * 0.09, len * 0.4), cf * CFrame.new(0, len * 0.15, len * 0.12), color, M.SmoothPlastic)
		L.P(m, Vector3.new(w * 0.76, len * 0.035, len * 0.38), cf * CFrame.new(0, len * 0.15, len * 0.12), C(20, 25, 35), M.Glass)
		L.P(m, Vector3.new(w * 0.55, len * 0.07, len * 0.22), cf * CFrame.new(0, len * 0.23, len * 0.14), color, M.SmoothPlastic)
		L.P(m, Vector3.new(w * 0.56, len * 0.03, len * 0.2), cf * CFrame.new(0, len * 0.23, len * 0.14), C(20, 25, 35), M.Glass)
	else
		L.P(m, Vector3.new(w * 0.7, len * 0.1, len * 0.12), cf * CFrame.new(0, len * 0.14, -len * 0.02), C(30, 40, 50), M.Glass, nil, { Transparency = 0.3 })
	end
	m.Parent = parent
	return m
end

------------------------------------------------------------------
-- POINTS OF INTEREST (tagged for gameplay scripts + floating map icons)
L.CAT = {
	Job = { tag = "JobSpot", color = C(242, 153, 74), glyph = "JOB", prompt = "Start Job" },
	Service = { tag = "JobSpot", color = C(255, 107, 107), glyph = "+", prompt = "Clock In" },
	Finance = { tag = "Finance", color = C(255, 210, 74), glyph = "$", prompt = "Open" },
	Dealer = { tag = "Dealership", color = C(78, 168, 255), glyph = "CAR", prompt = "Browse" },
	Shop = { tag = "Shop", color = C(180, 140, 255), glyph = "SHOP", prompt = "Shop" },
	Park = { tag = "Park", color = C(63, 199, 181), glyph = "PARK" },
	Property = { tag = "Property", color = C(255, 143, 199), glyph = "HOME", prompt = "View Property" },
	Dock = { tag = "BoatDock", color = C(150, 210, 240), glyph = "DOCK", prompt = "Spawn Boat" },
	Gas = { tag = "GasStation", color = C(255, 190, 90), glyph = "GAS", prompt = "Refuel" },
	ATM = { tag = "ATM", color = C(120, 220, 140), glyph = "ATM", prompt = "Use ATM" },
}
L.POIS = workspace:FindFirstChild("ViceBay") and workspace.ViceBay:FindFirstChild("POIs")
function L.poi(pos, cat, name, attrs, opts)
	local c = L.CAT[cat]
	local root = L.folder(L.folder(workspace, "ViceBay"), "POIs")
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 4, 4)
	p.Position = pos + Vector3.new(0, 2.5, 0)
	p:SetAttribute("Category", cat)
	p:SetAttribute("DisplayName", name)
	if attrs then for k, v in pairs(attrs) do p:SetAttribute(k, v) end end
	CS:AddTag(p, c.tag)
	CS:AddTag(p, "POI")
	if c.prompt and not (opts and opts.noPrompt) then
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = (opts and opts.action) or c.prompt
		pp.ObjectText = name
		pp.MaxActivationDistance = 10
		pp.RequiresLineOfSight = false
		pp.HoldDuration = 0.3
		pp.Parent = p
	end
	if not (opts and opts.noIcon) then
		local bb = Instance.new("BillboardGui")
		bb.Name = "MapIcon"
		bb.Size = UDim2.fromOffset(46, 46)
		bb.StudsOffsetWorldSpace = Vector3.new(0, (opts and opts.iconH) or 22, 0)
		bb.MaxDistance = (opts and opts.iconDist) or 450
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		bb.Parent = p
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = C(20, 22, 26)
		f.BackgroundTransparency = 0.1
		f.Parent = bb
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(1, 0)
		cr.Parent = f
		local sk = Instance.new("UIStroke")
		sk.Color = c.color
		sk.Thickness = 3
		sk.Parent = f
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.78, 0.78)
		t.Position = UDim2.fromScale(0.11, 0.11)
		t.Text = (opts and opts.glyph) or c.glyph
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = c.color
		t.Parent = f
	end
	p.Parent = root
	return p
end

return L
