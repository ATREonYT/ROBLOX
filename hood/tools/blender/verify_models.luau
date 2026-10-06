-- Unit checks for the generated GunModels / IconModels modules, plus .rbxmx export.
-- Usage: lune run hood/tools/blender/verify_models.luau <hood dir> [rbxmx out dir]
-- Builds every model the way the game does, checks the contract (PrimaryPart at the origin, anchored,
-- no collision/touch/query, part sizes, part budget, icon fits 2x2x2, gun muzzle points -Z) and writes
-- one .rbxmx per model that can be dragged into Studio.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local HOOD = process.args[1] or "hood"
local OUT = process.args[2]
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local env = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
	UDim2 = roblox.UDim2, math = math, table = table, string = string, assert = assert, tostring = tostring,
	ipairs = ipairs, pairs = pairs, error = error, type = type, typeof = typeof, print = print,
}
local function load(name)
	local path = HOOD .. "/src/ReplicatedStorage/Shared/Models/" .. name .. ".lua"
	return luau.load(fs.readFile(path), { debugName = name, environment = env })()
end

local failures, checks = 0, 0
local function check(ok, msg)
	checks += 1
	if not ok then
		failures += 1
		print("FAIL " .. msg)
	end
end

local function partsOf(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then table.insert(list, d) end
	end
	return list
end

-- Exact bounds per shape: wedges by their six corners, cylinders/balls by their round extents.
local function bounds(parts, skip)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, p in parts do
		if p ~= skip then
			local x, y, z, a, b, c, d, e, f, g, h, i = p.CFrame:GetComponents()
			local R = { { a, b, c }, { d, e, f }, { g, h, i } }
			local C = { x, y, z }
			local s = p.Size
			local shape = p:IsA("Part") and p.Shape.Name or "Wedge"
			for k = 1, 3 do
				local vals = {}
				if shape == "Cylinder" then
					local ax = math.abs(R[k][1])
					local ext = ax * s.X / 2 + math.sqrt(math.max(0, 1 - ax * ax)) * s.Y / 2
					vals = { C[k] - ext, C[k] + ext }
				elseif shape == "Ball" then
					vals = { C[k] - s.X / 2, C[k] + s.X / 2 }
				else
					local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
					local corners = { { -hx, -hy, -hz }, { hx, -hy, -hz }, { hx, -hy, hz }, { -hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } }
					if shape ~= "Wedge" then
						table.insert(corners, { -hx, hy, -hz })
						table.insert(corners, { hx, hy, -hz })
					end
					for _, v in corners do
						table.insert(vals, C[k] + R[k][1] * v[1] + R[k][2] * v[2] + R[k][3] * v[3])
					end
				end
				for _, v in vals do
					lo[k] = math.min(lo[k], v)
					hi[k] = math.max(hi[k], v)
				end
			end
		end
	end
	return Vector3.new(lo[1], lo[2], lo[3]), Vector3.new(hi[1], hi[2], hi[3])
end

local function near(a: Vector3, b: Vector3, tol)
	return (a - b).Magnitude <= (tol or 1e-3)
end

local summary = {}
local function verify(moduleName, rootName, kind)
	local M = load(moduleName)
	check(type(M.Ids) == "table" and #M.Ids > 0, moduleName .. ".Ids")
	for _, id in M.Ids do
		check(M.Images[id] == "", moduleName .. ".Images." .. id .. " should start empty")
		check(M.Meta[id] ~= nil, moduleName .. ".Meta." .. id)
		for _, scale in { 1, 0.5, 3 } do
			local model = M.build(id, scale)
			local tag = string.format("%s.%s@%g", moduleName, id, scale)
			local parts = partsOf(model)
			check(model.ClassName == "Model" and model.Name == id, tag .. " is a Model named after its id")
			check(model.PrimaryPart ~= nil and model.PrimaryPart.Name == rootName, tag .. " PrimaryPart is " .. rootName)
			local root = model.PrimaryPart
			if root then
				check(near(root.CFrame.Position, Vector3.zero) and near(root.CFrame.LookVector, Vector3.new(0, 0, -1)), tag .. " pivot at the origin")
				check(root.Transparency == 1, tag .. " root invisible")
			end
			check(#parts <= 120, tag .. " part budget " .. #parts)
			local thin = 0
			for _, p in parts do
				local ok = p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery
				if not ok then check(false, tag .. " " .. p.Name .. " physics flags") end
				local m = math.min(p.Size.X, p.Size.Y, p.Size.Z)
				check(m >= 0.001, tag .. " " .. p.Name .. " size >= 0.001")
				if m < 0.05 then thin += 1 end
				if p:IsA("Part") and p.Shape == roblox.Enum.PartType.Ball then
					check(math.abs(p.Size.X - p.Size.Y) < 1e-4 and math.abs(p.Size.Y - p.Size.Z) < 1e-4, tag .. " ball is uniform")
				end
			end
			local lo, hi = bounds(parts, root)
			local size = hi - lo
			check(near(size, M.Meta[id].Size * scale, 0.01 * scale + 1e-3), tag .. " size matches Meta")
			if kind == "icon" then
				check(size.X <= 2 * scale + 1e-3 and size.Y <= 2 * scale + 1e-3 and size.Z <= 2 * scale + 1e-3, tag .. " fits 2x2x2")
				check(near((lo + hi) / 2, Vector3.zero, 0.01 * scale), tag .. " centred")
			else
				local muzzle = M.Meta[id].Muzzle * scale
				check(muzzle.Z < lo.Z + 0.25 * scale, tag .. " muzzle at the front (-Z) end")
				check(lo.Y < 0 and hi.Y > 0 and lo.Z < 0 and hi.Z > 0, tag .. " grip origin inside the gun")
			end
			if scale == 1 then
				summary[#summary + 1] = string.format("%-9s %-8s parts %3d (thin<0.05: %2d)  size %.2f x %.2f x %.2f", moduleName == "GunModels" and "gun" or "icon", id, #parts, thin, size.X, size.Y, size.Z)
				if OUT then
					fs.writeDir(OUT)
					fs.writeFile(OUT .. "/" .. id .. ".rbxmx", roblox.serializeModel({ model }, true))
				end
			end
		end
		-- Welding for held tools.
		local welded = M.weld(M.build(id, 1))
		local unanchored, welds = true, 0
		for _, d in welded:GetDescendants() do
			if d:IsA("BasePart") and d.Anchored then unanchored = false end
			if d.ClassName == "WeldConstraint" then welds += 1 end
		end
		check(unanchored and welds == #partsOf(welded) - 1, moduleName .. "." .. id .. " weld()")
	end
	return M
end

verify("GunModels", "Handle", "gun")
verify("IconModels", "Root", "icon")
for _, line in summary do print(line) end
print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then process.exit(1) end
