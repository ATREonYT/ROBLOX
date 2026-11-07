-- Compiles every Luau file (syntax check). lune run tools/syntax.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local bad = 0
local function walk(dir)
	for _, e in fs.readDir(dir) do
		local p = dir .. "/" .. e
		if fs.isDir(p) then
			walk(p)
		elseif string.match(e, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(p))
			if not ok then
				bad += 1
				print("SYNTAX", p, err)
			end
		end
	end
end
walk("src")
print(`[syntax] {bad} files with errors`)
