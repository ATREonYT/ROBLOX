local fs = require('@lune/fs')
local luau = require('@lune/luau')
local process = require('@lune/process')
for _, path in process.args do
	local ok, err = pcall(luau.compile, fs.readFile(path))
	print(ok and 'ok  ' or 'FAIL', path, ok and '' or tostring(err))
end
