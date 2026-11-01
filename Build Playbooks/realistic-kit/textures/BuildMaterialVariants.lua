--!strict
-- Command Bar: builds the realistic MaterialVariants in MaterialService from uploaded image ids.
-- 1. Paste the IDS table (Claude fills it after uploading, or copy ids from Asset Manager).
-- 2. Run. It only ADDS variants that don't exist yet, never changes or overrides existing ones,
--    and never sets "Set as Override", so nothing already in the place changes look.
-- 3. Cmd+S to save.
local IDS: { [string]: { [string]: any } } = {
	-- ["HoodAsphaltCracked"] = { base = "Asphalt", pattern = "Organic", studs = 11,
	--     ColorMap = "rbxassetid://0", NormalMap = "rbxassetid://0", RoughnessMap = "rbxassetid://0" },
}
local MaterialService = game:GetService("MaterialService")
local folder = MaterialService:FindFirstChild("Realistic") or Instance.new("Folder")
folder.Name = "Realistic"
folder.Parent = MaterialService
local made, skipped = 0, 0
for name, t in IDS do
	if MaterialService:FindFirstChild(name, true) then
		skipped += 1
		continue
	end
	local v = Instance.new("MaterialVariant")
	v.Name = name
	v.BaseMaterial = (Enum.Material :: any)[t.base]
	v.MaterialPattern = (Enum.MaterialPattern :: any)[t.pattern or "Regular"]
	v.StudsPerTile = t.studs or 10
	for _, map in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
		local id = t[map]
		if id and id ~= "" and id ~= "rbxassetid://0" then
			local ok = pcall(function() (v :: any)[map .. "Content"] = Content.fromUri(id) end)
			if not ok then (v :: any)[map] = id end
		end
	end
	v.Parent = folder
	made += 1
end
print(("Realistic materials: %d added, %d already there. Press Cmd+S to save."):format(made, skipped))
