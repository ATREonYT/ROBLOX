-- Which parts of a place file use an asset id (Oct 20: the owner's Output said asset 120038515596009 is "not
-- approved"): every instance with a property or attribute holding that number, grouped by the model it is in.
-- lune run huzz-valley/tools/place/find_asset.luau <place.rbxl> <id> [<id>...]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local file = process.args[1]
local want = {}
for i = 2, #process.args do want[process.args[i]] = true end
local game = roblox.deserializePlace(fs.readFile(file))

local PROPS = { "MeshId", "MeshContent", "TextureID", "TextureContent", "TextureId", "Texture", "ColorMap", "ColorMapContent",
	"NormalMap", "RoughnessMap", "MetalnessMap", "Image", "ImageContent", "SoundId", "AnimationId", "SkyboxBk", "SkyboxDn",
	"SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "Graphic", "ShirtTemplate", "PantsTemplate", "LinkedSource" }

local hits = {}
local function check(inst, label, value)
	local s = tostring(value)
	for id in want do
		if string.find(s, id, 1, true) then
			local m = inst
			while m.Parent and not (m.Parent:IsA("Folder") or m.Parent.ClassName == "Workspace" or m.Parent.ClassName == "DataModel") do m = m.Parent end
			local key = id .. "  " .. m:GetFullName()
			hits[key] = hits[key] or {}
			table.insert(hits[key], string.sub(inst:GetFullName(), #m:GetFullName() + 2) .. "." .. label)
		end
	end
end
for _, svc in game:GetChildren() do
	local ok, list = pcall(function() return svc:GetDescendants() end)
	if ok then
		for _, d in list do
			for _, k in PROPS do
				local okK, v = pcall(function() return d[k] end)
				if okK and v ~= nil then check(d, k, v) end
			end
			local okA, attrs = pcall(function() return d:GetAttributes() end)
			if okA then for k, v in attrs do check(d, "@" .. k, v) end end
			if d:IsA("LuaSourceContainer") then
				local okS, src = pcall(function() return d.Source end)
				if okS then check(d, "Source", src) end
			end
		end
	end
end
local keys = {}
for k in hits do table.insert(keys, k) end
table.sort(keys)
if #keys == 0 then print("not used in " .. file) end
for _, k in keys do
	local list = hits[k]
	print(k .. "  (" .. #list .. ": " .. table.concat(list, ", ", 1, math.min(#list, 6)) .. (#list > 6 and ", ..." or "") .. ")")
end
