-- InstanceMap: per-instance memory that never loses an entry while the instance lives (the weak-table bug from Huzz
-- Valley). Entries read back, survive a garbage collection pass, clear by hand, and work for keys that aren't instances.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local InstanceMap = require(RS.Shared.InstanceMap)
	local e = t.expect
	t.test('an entry stays while its instance lives, even with no other reference to its handle', function()
		local map = InstanceMap.new()
		local folder = Instance.new('Folder')
		local part = Instance.new('Part')
		part.Parent = folder
		map[part] = 'kept'
		part = nil
		for j = 1, 2000000 do local _ = { j } end
		local again = folder:GetChildren()[1]
		e.equal(map[again], 'kept')
	end)
	t.test('entries clear by hand and come back', function()
		local map = InstanceMap.new()
		local p = Instance.new('Part')
		map[p] = 1
		map[p] = nil
		e.falsy(map[p])
		map[p] = 2
		e.equal(map[p], 2)
	end)
	t.test('keys that are not instances work like a plain table', function()
		local map = InstanceMap.new()
		map.lane = 'a'
		map[3] = 'b'
		e.equal(map.lane, 'a')
		e.equal(map[3], 'b')
		local n = 0
		for _ in map do n += 1 end
		e.equal(n, 2)
	end)
end
