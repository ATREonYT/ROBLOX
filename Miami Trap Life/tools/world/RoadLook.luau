-- Hood road look (Quality pass, LihFolk Build List item 13). Edit-time, run once.
-- 1. Hood asphalt was painted near-black (38-46 RGB), which hides the AsphaltWorn / HoodAsphaltCracked texture
--    and reads as flat black. Lift it to a sun-bleached Miami grey so the texture, cracks and patches show.
-- 2. RoadWear.HoodWear patches were translucent SmoothPlastic: they picked up sky reflection and read as blue
--    glass sheets. Make them real tar patches / stained concrete / oil stains with matte materials.
-- Stores each part's original look in attribute MTL_RoadLookOrig ("Material|Variant|r,g,b|T") so it can be undone.
local ARGS = ... or {}
local MIN = ARGS.min or Vector3.new(-1720, -10, -960)
local MAX = ARGS.max or Vector3.new(-980, 40, -60)
local ROAD = Color3.fromRGB(74, 73, 71)
local ALLEY = Color3.fromRGB(80, 77, 72)

local function inside(p: Vector3)
	return p.X > MIN.X and p.X < MAX.X and p.Z > MIN.Z and p.Z < MAX.Z and p.Y > MIN.Y and p.Y < MAX.Y
end
local function rgb(c: Color3)
	return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
end
local function remember(p: BasePart)
	if p:GetAttribute("MTL_RoadLookOrig") == nil then
		local r, g, b = rgb(p.Color)
		p:SetAttribute("MTL_RoadLookOrig", string.format("%s|%s|%d,%d,%d|%.2f", p.Material.Name, p.MaterialVariant, r, g, b, p.Transparency))
	end
end

local roads, wear = 0, 0
local vb = workspace:FindFirstChild("ViceBay")
for i, p in (vb and vb:FindFirstChild("Roads") or workspace):GetDescendants() do
	if p:IsA("BasePart") and p.Material == Enum.Material.Asphalt and inside(p.Position) then
		local r = rgb(p.Color)
		if r < 60 then
			remember(p)
			p.Color = if string.find(p.Parent.Name, "Alley") then ALLEY else ROAD
			roads += 1
		end
	end
end

local hw = vb and vb:FindFirstChild("RoadWear") and vb.RoadWear:FindFirstChild("HoodWear")
if hw then
	for _, p in hw:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 1 and inside(p.Position) then
			local r = rgb(p.Color)
			local orig = p:GetAttribute("MTL_RoadLookOrig")
			if orig then
				-- already converted; keep it idempotent
				continue
			end
			if p.Material == Enum.Material.SmoothPlastic then
				remember(p)
				if r <= 32 then -- tar patches / crack seal
					p.Material = Enum.Material.Asphalt
					p.MaterialVariant = "AsphaltTarPatch"
					p.Color = Color3.fromRGB(46, 46, 48)
					p.Transparency = 0
				elseif r >= 100 then -- sun-faded / dusty strips
					p.Material = Enum.Material.Concrete
					p.MaterialVariant = "ConcreteStained"
					p.Color = Color3.fromRGB(110, 107, 100)
					p.Transparency = 0.45
				else -- oil stains
					p.Material = Enum.Material.Asphalt
					p.MaterialVariant = ""
					p.Color = Color3.fromRGB(28, 26, 24)
					p.Transparency = 0.5
				end
				p.Reflectance = 0
				wear += 1
			end
		end
	end
end
return string.format("roads lifted %d, wear patches converted %d", roads, wear)
