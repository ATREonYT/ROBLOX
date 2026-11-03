-- Gas station shop interiors (Hood + the 4 County stations share one layout). In-place upgrade, Nov 3:
--   * the 3 plain white shelf blocks -> real two-sided gondolas with stocked shelves (originals stashed)
--   * the cooler doors' flat neon panels -> dark cooler interiors with shelves of drinks behind the glass
--   * the counter gets a register, card reader, candy rack, lotto tickets and a coffee cup
--   * floor / ceiling get the MTL_Interior tile variants; sprinklers, exit sign, wet-floor sign, flyer rack
-- Every added part is decoration (no collide/query/touch/shadow) except the gondola bodies, which stay solid.
-- Re-runnable: each Interior gets one "UpgradeV1" model that is rebuilt; stashed originals are not touched again.
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_GasStations)()
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M
local V = Vector3.new

local function stations()
	local list = {}
	local H = workspace.ViceBay.Landmarks.Hood:FindFirstChild("GasStation")
	if H and H:FindFirstChild("Interior") then
		table.insert(list, H)
	end
	for _, g in workspace.ViceBay.Buildings.County:GetChildren() do
		if g.Name == "GasStation" and g:FindFirstChild("Interior") then
			table.insert(list, g)
		end
	end
	return list
end

local function upgrade(gs: Model, idx: number)
	local interior = gs.Interior
	local old = interior:FindFirstChild("UpgradeV1")
	if old then
		old:Destroy()
	end
	-- re-runnable: put back whatever an earlier run stashed for this station, then rebuild
	local stash = game:GetService("ServerStorage"):FindFirstChild("MTL_ReplacedJobSites")
	stash = stash and stash:FindFirstChild("GasStation" .. idx)
	if stash then
		for _, p in stash:GetChildren() do
			if p:GetAttribute("MTL_OriginalParent") == interior:GetFullName() then
				p.Parent = interior
			end
		end
	end
	local m = Instance.new("Model")
	m.Name = "UpgradeV1"
	local b = K.builder(m)
	local rng = Random.new(900 + idx)
	local site = "GasStation" .. idx

	-- 1. shelf blocks -> gondolas
	local shelves, coolerGlow, counter, ceiling = {}, {}, nil, nil
	for _, p in interior:GetChildren() do
		if p:IsA("BasePart") then
			local s = p.Size
			if p.Material == M.SmoothPlastic and s.Y > 4.5 and s.Y < 6 and math.max(s.X, s.Z) > 10 and math.min(s.X, s.Z) > 2 then
				table.insert(shelves, p)
			elseif (p.Material == M.Neon or (p.Material == M.SmoothPlastic and p.Color.R < 0.2)) and s.Y > 6 and math.min(s.X, s.Z) < 0.15 then
				table.insert(coolerGlow, p)
			elseif p.Material == M.Wood and math.max(s.X, s.Z) > 8 and math.max(s.X, s.Z) < 11 then
				counter = p
			elseif (p.Material == M.SmoothPlastic or p.Material == M.Plastic) and s.Y < 0.3 and math.max(s.X, s.Z) > 30 then
				ceiling = p
			end
		end
	end
	-- the orange shelf tops sit on the blocks; stash them with the blocks
	for _, blk in shelves do
		for _, p in interior:GetChildren() do
			if p:IsA("BasePart") and p ~= blk and p.Material == M.SmoothPlastic and math.abs(p.Size.Y - 0.4) < 0.05 and math.max(p.Size.X, p.Size.Z) > 10 and (p.Position - (blk.Position + V(0, blk.Size.Y / 2 + 0.2, 0))).Magnitude < 0.6 then
				K.stash(site, p)
			end
		end
	end
	local palettes = { K.Snacks, K.Grocery, K.Household }
	for i, blk in shelves do
		local cf = blk.CFrame
		local long = if blk.Size.Z >= blk.Size.X then "Z" else "X"
		local rot = if long == "Z" then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
		local base = CFrame.new(cf.Position - V(0, blk.Size.Y / 2, 0)) * (cf - cf.Position) * rot -- floor centre, local Z = long axis
		local L = math.max(blk.Size.X, blk.Size.Z)
		K.stash(site, blk)
		local g = b.group("Gondola", m)
		local function at(x, y, z)
			return base * CFrame.new(x, y, z)
		end
		b.P("Kick", V(1.8, 0.45, L), at(0, 0.225, 0), C(70, 72, 76), M.Metal, { parent = g })
		b.P("Spine", V(0.15, 5.0, L), at(0, 2.95, 0), C(186, 188, 192), M.SmoothPlastic, { parent = g })
		b.P("Cap", V(1.7, 0.12, L), at(0, 5.5, 0), C(132, 136, 142), M.Metal, { parent = g })
		for _, z in { -L / 2 + 0.1, L / 2 - 0.1 } do
			b.P("Upright", V(1.8, 5.5, 0.18), at(0, 2.75, z), C(132, 136, 142), M.Metal, { parent = g })
		end
		for side = -1, 1, 2 do
			local pal = palettes[(i + (side + 1) / 2 - 1) % #palettes + 1]
			for lvl, y in { 0.45, 2.0, 3.55 } do
				if lvl > 1 then
					b.P("Board", V(0.8, 0.08, L - 0.2), at(side * 0.48, y - 0.04, 0), C(196, 196, 196), M.Metal, { parent = g })
				end
				b.P("PriceStrip", V(0.04, 0.2, L - 0.2), at(side * 0.9, y - 0.1, 0), if lvl == 2 then C(250, 214, 60) else C(236, 236, 230), M.SmoothPlastic, { parent = g, deco = true })
				local shelfCf = base * CFrame.new(side * 0.48, y, 0)
				local look = CFrame.lookAt(shelfCf.Position, shelfCf.Position + (base:VectorToWorldSpace(V(side, 0, 0))))
				K.fillShelf(b, look, L - 0.4, 0.72, 1.2, rng, pal, g)
			end
		end
	end

	-- 2. cooler glow panels -> dark interiors + drinks behind the doors
	for _, glow in coolerGlow do
		local cf = glow.CFrame
		local w = math.max(glow.Size.X, glow.Size.Z)
		local alongX = glow.Size.X >= glow.Size.Z
		glow.Material = M.SmoothPlastic
		glow.Color = C(30, 34, 40)
		local axis = if alongX then V(1, 0, 0) else V(0, 0, 1)
		-- the back of the cooler is away from the shop: find which side the glass is on
		local glass
		for _, p in interior:GetChildren() do
			if p:IsA("BasePart") and p.Material == M.Glass and (p.Position - glow.Position).Magnitude < 0.3 then
				glass = p
			end
		end
		local outN = if glass then (glass.Position - glow.Position) else V(0, 0, 1)
		outN = if outN.Magnitude > 0.001 then outN.Unit else V(0, 0, 1)
		-- the glow panel sits right behind the glass (no depth), so the drinks are flat label faces on it
		for lvl, dy in { -1.6, 0.4, 2.3 } do
			local x = -w / 2 + 0.15
			while x < w / 2 - 0.5 do
				local pal = K.Drinks[rng:NextInteger(1, #K.Drinks)]
				local dw = rng:NextNumber(0.5, 0.8)
				local h = if lvl == 3 then 0.9 else rng:NextNumber(1.0, 1.4)
				local p = cf.Position + axis * (x + dw / 2) + V(0, dy + h / 2 - 0.6, 0) + outN * 0.04
				b.P("Drink", V(if alongX then dw else 0.03, h, if alongX then 0.03 else dw), CFrame.new(p), pal[1], M.SmoothPlastic, { parent = m, deco = true })
				x += dw + 0.07
			end
			b.P("CoolerShelf", V(if alongX then w else 0.03, 0.08, if alongX then 0.03 else w), CFrame.new(cf.Position + V(0, dy - 0.64, 0) + outN * 0.045), C(150, 152, 156), M.Metal, { parent = m, deco = true })
		end
	end

	-- 3. counter life (register on top, impulse items, coffee)
	if counter then
		local top = counter.CFrame * CFrame.new(0, counter.Size.Y / 2 + 0.15, 0)
		local alongX = counter.Size.X >= counter.Size.Z
		local function on(a, y, c)
			return top * (if alongX then CFrame.new(a, y, c) else CFrame.new(c, y, a))
		end
		b.P("Register", V(1.2, 0.5, 1.0), on(-2.6, 0.25, 0.2), C(40, 42, 50), M.SmoothPlastic, { parent = m, deco = true })
		b.P("RegScreen", V(1.0, 0.7, 0.08), on(-2.6, 0.85, 0.5), C(110, 200, 255), M.Neon, { parent = m, deco = true })
		b.P("CardReader", V(0.4, 0.2, 0.3), on(-1.5, 0.1, -0.6), C(30, 30, 30), M.SmoothPlastic, { parent = m, deco = true })
		for j = 0, 4 do
			local pal = K.Snacks[rng:NextInteger(1, #K.Snacks)]
			b.P("Candy", V(0.5, 0.35, 0.4), on(1.0 + j * 0.55, 0.18, -0.7), pal[1], M.SmoothPlastic, { parent = m, deco = true })
		end
		b.P("LottoCase", V(1.4, 0.9, 0.5), on(3.2, 0.45, 0.4), C(200, 220, 230), M.Glass, { parent = m, deco = true, Transparency = 0.5 })
		b.P("Coffee", V(0.35, 0.5, 0.35), on(-0.5, 0.25, 0.6), C(240, 240, 236), M.SmoothPlastic, { parent = m, deco = true })
	end

	-- 4. surfaces: tile ceiling + the interior floor slab under the shop (largest flat part just under the shelves)
	if ceiling then
		K.dressPart(ceiling, "MTL_CeilingTile")
	end
	-- tile floor just above the shop's ground, sized to the ceiling
	local floorY = math.huge
	for _, blk in shelves do
		floorY = math.min(floorY, blk.Position.Y - blk.Size.Y / 2)
	end
	if ceiling and floorY < math.huge then
		local f = b.P("ShopFloor", V(ceiling.Size.X - 0.4, 0.04, ceiling.Size.Z - 0.4), CFrame.new(ceiling.Position.X, floorY + 0.02, ceiling.Position.Z) * (ceiling.CFrame - ceiling.CFrame.Position), C(232, 228, 216), M.Pavement, { parent = m, deco = true })
		K.dressPart(f, "MTL_VCTTile")
	end
	for _, p in interior:GetChildren() do -- see-through cooler doors
		if p:IsA("BasePart") and p.Material == M.Glass and p.Size.Y > 6 then
			p.Transparency = 0.65
		end
	end

	-- decoration flags
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			local s = d.Size
			if math.max(s.X, s.Y, s.Z) < 4 then
				d.CastShadow = false
			end
		end
	end
	m.Parent = interior
	return n
end

return function()
	local out = {}
	for i, gs in stations() do
		local ok, res = pcall(upgrade, gs, i)
		table.insert(out, gs:GetFullName():gsub("Workspace.ViceBay.", "") .. ": " .. (if ok then tostring(res) .. " parts" else "ERROR " .. tostring(res)))
		task.wait()
	end
	return table.concat(out, "\n")
end
