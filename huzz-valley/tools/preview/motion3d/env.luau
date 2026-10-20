-- Loads a game ModuleScript source file the way Roblox would, so shared modules run unchanged in Lune.
-- game:GetService("X") maps to huzz-valley/src/X, script.Parent to the file's folder; require(node) loads <path>.lua.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Env = {}

-- Repo root: the folder holding huzz-valley (works from anywhere inside the repo).
local cwd = string.gsub(process.cwd, "/$", "")
Env.root = string.match(cwd, "^(.*)/huzz%-valley") or cwd
Env.src = Env.root .. "/huzz-valley/src"

local info = {} -- node -> {path, name, parent}
local cache, loading = {}, {}
local Node = {}

local function fileOf(path)
	for _, f in { path .. ".lua", path .. ".luau", path .. "/init.lua", path .. "/init.luau" } do
		if fs.isFile(f) then return f end
	end
	return nil
end

local function node(path, parent)
	local n = setmetatable({}, Node)
	info[n] = { path = path, name = string.match(path, "([^/]+)$"), parent = parent }
	return n
end

local methods = {}
function methods.FindFirstChild(self, name)
	local path = info[self].path .. "/" .. name
	if fileOf(path) or fs.isDir(path) then return node(path, self) end
	return nil
end
function methods.WaitForChild(self, name)
	return methods.FindFirstChild(self, name) or error("WaitForChild: no " .. info[self].path .. "/" .. name)
end
function methods.GetFullName(self) return info[self].path end

Node.__index = function(self, key)
	if methods[key] then return methods[key] end
	local i = info[self]
	if key == "Name" then return i.name end
	if key == "Parent" then
		i.parent = i.parent or node(string.match(i.path, "^(.*)/[^/]+$"))
		return i.parent
	end
	return node(i.path .. "/" .. key, self) -- no file check here: Lune can't read files inside a metamethod
end
Node.__tostring = function(self) return info[self].name end

local game = { GetService = function(_, name) return node(Env.src .. "/" .. name) end }

local load
local function requireNode(target)
	if type(target) == "string" then return require(target) end -- @lune/... still works
	local i = assert(info[target], "require expects a module node")
	local file = assert(fileOf(i.path), "no module file for " .. i.path)
	return load(file, target)
end

local env = {
	game = game, require = requireNode, typeof = typeof, task = task,
	math = math, table = table, string = string,
}
for _, k in { "CFrame", "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "Ray" } do
	env[k] = roblox[k]
end
Env.globals = env -- (what every loaded module sees: a scene may swap one before loading, e.g. a fixed CFrame.lookAt)

function load(file, scriptNode)
	if cache[file] ~= nil then return cache[file] end
	assert(not loading[file], "cyclic require: " .. file)
	loading[file] = true
	scriptNode = scriptNode or node((string.gsub(file, "%.luau?$", "")))
	local e = { script = scriptNode } -- copied in, not __index: Lune's own globals would shadow require
	for k, v in env do e[k] = v end
	local result = luau.load(fs.readFile(file), { debugName = file, environment = e })()
	loading[file] = nil
	cache[file] = result
	return result
end

-- path: absolute, or relative to the repo root (e.g. "huzz-valley/src/ReplicatedStorage/Shared/CarryMath.lua").
function Env.load(path)
	if string.sub(path, 1, 1) ~= "/" then path = Env.root .. "/" .. path end
	return load(path)
end
Env.game = game

return Env
