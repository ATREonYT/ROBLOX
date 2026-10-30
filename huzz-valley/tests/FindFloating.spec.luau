-- lune run tests/FindFloating.spec.luau [finder.lua]   (from huzz-valley/)
-- The Studio finder for the owner's "black thing attached to my character" (tools/studio/find-floating-parts.lua,
-- pasted in the Command Bar in Play). His Oct 20 run printed no [HuzzFind] line at all: his avatar's hats and hair
-- are held on by AccessoryRigidConstraints (as his girls' are: Shared/GirlRig), which have Attachment0/1 and no
-- Part0, and the finder read Part0 on every joint, so it stopped at the first hat (nearest first). Here it runs on
-- fake parts that behave like Roblox's (reading a property a class doesn't have throws): a hat held by an
-- AccessoryRigidConstraint, a welded knife, a loose dark block and a far one. Every near part gets its line, with
-- what holds it, and the run ends with its Done line.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, Color3 = roblox.Vector3, roblox.Color3

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local FILE = process.args[1] or (ROOT .. "tools/studio/find-floating-parts.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- Fake instances: only the members their Roblox class has (anything else throws, as in Studio).
local BASEPART = { "Name", "ClassName", "Parent", "Size", "Position", "Color", "Transparency", "LocalTransparencyModifier",
	"Anchored", "CastShadow" }
local MEMBERS = {
	Part = BASEPART,
	Model = { "Name", "ClassName", "Parent" },
	Folder = { "Name", "ClassName", "Parent" },
	Accessory = { "Name", "ClassName", "Parent" },
	Attachment = { "Name", "ClassName", "Parent" },
	Weld = { "Name", "ClassName", "Parent", "Part0", "Part1" },
	AccessoryRigidConstraint = { "Name", "ClassName", "Parent", "Attachment0", "Attachment1" },
}
local IS = { Part = { BasePart = true, Part = true } }
local methods = {}
local function new(class, props)
	local data = { ClassName = class, Name = class, children = {}, joints = {} }
	for k, v in props or {} do data[k] = v end
	local allowed = {}
	for _, m in MEMBERS[class] do allowed[m] = true end
	local obj = setmetatable({}, {
		__index = function(_, k)
			if methods[k] then return methods[k] end
			if allowed[k] then return data[k] end
			error(k .. " is not a valid member of " .. class .. ' "' .. data.Name .. '"', 2)
		end,
		__newindex = function(_, k, v) data[k] = v end,
	})
	data.self = obj
	rawset(obj, "__data", nil)
	return obj, data
end
local datas = setmetatable({}, { __mode = "k" })
local function make(class, props, parent)
	local obj, data = new(class, props)
	datas[obj] = data
	if parent then
		data.Parent = parent
		table.insert(datas[parent].children, obj)
	end
	return obj
end
function methods.IsA(self, class)
	local d = datas[self]
	return d.ClassName == class or (IS[d.ClassName] or {})[class] == true
end
function methods.GetFullName(self)
	local d = datas[self]
	if d.Parent and datas[d.Parent].Name ~= "Workspace" then return methods.GetFullName(d.Parent) .. "." .. d.Name end
	return "Workspace." .. d.Name
end
function methods.GetChildren(self) return table.clone(datas[self].children) end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, c in datas[o].children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name)
	for _, c in datas[self].children do
		if datas[c].Name == name then return c end
	end
	return nil
end
function methods.IsDescendantOf(self, other)
	local p = datas[self].Parent
	while p do
		if p == other then return true end
		p = datas[p].Parent
	end
	return false
end
function methods.GetJoints(self) return table.clone(datas[self].joints) end

local workspace = make("Folder", { Name = "Workspace" })
local function part(name, parent, size, at, color, props)
	local p = make("Part", { Name = name, Size = size, Position = at, Color = color or Color3.new(0.6, 0.6, 0.6), Transparency = 0,
		LocalTransparencyModifier = 0, Anchored = false, CastShadow = true }, parent)
	for k, v in props or {} do datas[p][k] = v end
	return p
end
local kid = make("Model", { Name = "Kid" }, workspace)
local root = part("HumanoidRootPart", kid, Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), nil, { Transparency = 1 })
local head = part("Head", kid, Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.5, 0))
part("LowerTorso", kid, Vector3.new(2, 0.4, 1), Vector3.new(0, 2.6, 0))
-- his hair, on the new avatar joint: an AccessoryRigidConstraint between two Attachments
local hair = make("Accessory", { Name = "Braids" }, kid)
local hairHandle = part("Handle", hair, Vector3.new(1.4, 2, 1.4), Vector3.new(0, 4.4, 0.3))
local a0 = make("Attachment", { Name = "HairAttachment" }, hairHandle)
local a1 = make("Attachment", { Name = "HairAttachment" }, head)
local rigid = make("AccessoryRigidConstraint", { Name = "AccessoryRigidConstraint", Attachment0 = a0, Attachment1 = a1 }, hairHandle)
table.insert(datas[hairHandle].joints, rigid)
table.insert(datas[head].joints, rigid)
-- a knife welded to the hip (a Weld: Part0 / Part1)
local knife = make("Model", { Name = "HuzzBackKnife" }, kid)
local grip = part("Handle", knife, Vector3.new(0.22, 0.75, 0.26), Vector3.new(1.18, 2.5, 0.82), Color3.fromRGB(32, 30, 38), { CastShadow = false })
local lower = methods.FindFirstChild(kid, "LowerTorso")
local mount = make("Weld", { Name = "BackMount", Part0 = lower, Part1 = grip }, grip)
table.insert(datas[grip].joints, mount)
-- a dark block on the floor beside him, held by nothing, and a far one
part("Slab", workspace, Vector3.new(1, 2, 0.4), Vector3.new(2.5, 0.2, -1.5), Color3.fromRGB(20, 22, 50), { Anchored = true, CastShadow = false })
part("FarBlock", workspace, Vector3.new(1, 1, 1), Vector3.new(40, 0.5, 0))

local player = { Name = "Owner", Character = kid }
local game = {
	GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = player, GetPlayers = function() return { player } end } end
		if name == "RunService" then return { IsServer = function() return true end } end
		error("no service " .. name)
	end,
}
local lines = {}
local env = {
	game = game, workspace = workspace,
	print = function(...) table.insert(lines, table.concat(table.pack(...), " ")) end,
	warn = function(...) table.insert(lines, "WARN " .. table.concat(table.pack(...), " ")) end,
}
local ok, err = pcall(function()
	luau.load(fs.readFile(FILE), { debugName = "find-floating-parts", environment = env })()
end)
if not ok then print("  the finder stopped: " .. tostring(err)) end
local function line(pattern)
	for _, l in lines do
		if string.find(l, pattern) then return l end
	end
	return nil
end
for _, l in lines do print("  " .. l) end
check("it runs to the end on an avatar whose hair is held by an AccessoryRigidConstraint", ok)
check("the hair gets its line, held by its constraint to the head",
	line("Braids%.Handle") ~= nil and string.find(line("Braids%.Handle") or "", "AccessoryRigidConstraint%->Workspace%.Kid%.Head") ~= nil)
check("the worn knife gets its line, held by its weld to the LowerTorso, shadow off",
	string.find(line("HuzzBackKnife%.Handle") or "", "Weld%->Workspace%.Kid%.LowerTorso") ~= nil
		and string.find(line("HuzzBackKnife%.Handle") or "", "shadow OFF") ~= nil)
check("the loose dark block gets its line: anchored, held by nothing, shadow off",
	string.find(line("Workspace%.Slab") or "", "nothing: anchored") ~= nil and string.find(line("Workspace%.Slab") or "", "shadow OFF") ~= nil)
check("nearest first: the block beside him before nothing farther", (function()
	local at = {}
	for i, l in lines do
		if string.find(l, "Slab") then at.slab = i end
		if string.find(l, "Done") then at.done = i end
	end
	return at.slab ~= nil and at.done ~= nil and at.slab < at.done
end)())
check("his body's own limbs and far parts aren't listed", line("Kid%.LowerTorso ") == nil and line("FarBlock") == nil and line("HumanoidRootPart") == nil)
check("it ends with its Done line", line("%[HuzzFind%] Done: 3 small parts") ~= nil)

print(string.format("FindFloating: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
