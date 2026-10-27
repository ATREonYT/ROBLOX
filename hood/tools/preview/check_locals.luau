-- Checks every script in hood/src against Roblox Studio's 200-local limit, the way Studio compiles them
-- (optimization level 0; the offline harness compiles at a higher level, which hides an overflow, and that is how
-- the HUD once failed only in Studio with "Out of local registers ... exceeded limit 200").
-- Run from the repo root:  lune run hood/tools/preview/check_locals.luau
-- Prints every script with fewer than 20 spare locals and exits 1 if any script fails to compile.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local WARN = 20
local function compiles(src, extra)
	local pre = ""
	if extra > 0 then
		local names = table.create(extra)
		for i = 1, extra do names[i] = "__pad" .. i end
		pre = "local " .. table.concat(names, ",") .. "\n"
	end
	local ok, bytecode = pcall(luau.compile, pre .. src, { optimizationLevel = 0 })
	if not ok then return false, tostring(bytecode) end
	local okLoad, err = pcall(luau.load, bytecode)
	return okLoad, okLoad and nil or tostring(err)
end

local failed, tight, total = 0, 0, 0
local function visit(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			visit(path)
		elseif string.sub(name, -4) == ".lua" or string.sub(name, -5) == ".luau" then
			total += 1
			local src = fs.readFile(path)
			local ok, err = compiles(src, 0)
			if not ok then
				failed += 1
				print("FAIL   " .. path .. "\n       " .. err)
			elseif not compiles(src, WARN) then
				local lo, hi = 0, WARN - 1
				while lo < hi do
					local mid = (lo + hi + 1) // 2
					if compiles(src, mid) then lo = mid else hi = mid - 1 end
				end
				tight += 1
				print(string.format("TIGHT  %s (%d spare locals at the top level)", path, lo))
			end
		end
	end
end
visit(process.args[1] or "hood/src")
print(string.format("checked %d scripts: %d failing, %d with fewer than %d spare locals", total, failed, tight, WARN))
process.exit(failed > 0 and 1 or 0)
