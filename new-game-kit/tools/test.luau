--!nonstrict
-- New Game Kit: run every spec in tests/ offline with Lune.
--   lune run tools/test.luau            (from the kit folder)
-- Uses the fake Roblox in tools/lune/RobloxMock.luau. Exit code 1 on any failure.
local process = require("@lune/process")
local Mock = require("./lune/RobloxMock")

local function makeExpectation(value, negated)
	local e = {}
	local function check(condition, message)
		if negated then
			condition = not condition
			message = "NOT " .. message
		end
		if not condition then
			error(message, 3)
		end
	end
	e.to = e
	e.be = e
	e.been = e
	e.have = e
	function e.equal(expected)
		check(value == expected, `expected {tostring(expected)}, got {tostring(value)}`)
	end
	function e.ok()
		check(value ~= nil and value ~= false, `expected a truthy value, got {tostring(value)}`)
	end
	function e.near(expected, limit)
		local tolerance = limit or 1e-7
		check(type(value) == "number" and math.abs(value - expected) <= tolerance, `expected {expected} +/- {tolerance}, got {tostring(value)}`)
	end
	function e.a(typeName)
		check(Mock.typeof(value) == typeName, `expected a {typeName}, got {Mock.typeof(value)}`)
	end
	e.an = e.a
	function e.throw(fragment)
		local ok, err = pcall(value)
		local matches = not ok and (fragment == nil or string.find(tostring(err), fragment, 1, true) ~= nil)
		check(matches, `expected function to throw{if fragment then " '" .. fragment .. "'" else ""}`)
	end
	return setmetatable(e, {
		__index = function(_, key)
			if key == "never" then
				return makeExpectation(value, not negated)
			end
			error(`expect: unknown matcher '{tostring(key)}'`, 2)
		end,
	})
end

local only = process.args[1]
local passed, failed = 0, 0
local world = Mock.newWorld({ studio = false })
world.mount("test.project.json")
local testsFolder = world.game.ServerScriptService.KitTests
local specs = {}
for _, child in testsFolder:GetChildren() do
	if string.sub(child.Name, -5) == ".spec" and (only == nil or string.find(child.Name, only, 1, true)) then
		table.insert(specs, child)
	end
end
table.sort(specs, function(a, b)
	return a.Name < b.Name
end)

for _, spec in specs do
	local path = { spec.Name }
	local env = {}
	function env.describe(name, fn)
		table.insert(path, name)
		local ok, err = pcall(fn)
		if not ok then
			failed += 1
			print(`FAIL {table.concat(path, " > ")} (describe): {err}`)
		end
		table.remove(path)
	end
	function env.it(name, fn)
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {table.concat(path, " > ")} > {name}: {err}`)
		end
	end
	function env.expect(v)
		return makeExpectation(v, false)
	end
	local okLoad, specFn = pcall(function()
		return world.load(spec._path, spec, env)()
	end)
	if not okLoad or type(specFn) ~= "function" then
		failed += 1
		print(`FAIL {spec.Name} (load): {specFn}`)
	else
		local ok, err = pcall(specFn)
		if not ok then
			failed += 1
			print(`FAIL {spec.Name} (body): {err}`)
		end
	end
end
-- Every source file must compile (catches syntax errors in client code the specs don't load).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function compileAll(dir)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			compileAll(path)
		elseif string.match(entry, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if ok then
				passed += 1
			else
				failed += 1
				print(`FAIL compile {path}: {err}`)
			end
		end
	end
end
compileAll("src")
print(`[KitTests] {passed} passed, {failed} failed, {#specs} spec modules`)
process.exit(if failed == 0 then 0 else 1)
