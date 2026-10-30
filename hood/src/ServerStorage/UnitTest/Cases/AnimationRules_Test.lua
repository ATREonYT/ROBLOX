-- The owner's movement pack on the characters (Oct 27; Shared/AnimationRules, Config/Animations).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local A = require(RS.Shared.AnimationRules)

	t.test('ids: numbers and digit strings become asset ids; junk and blanks are nil', function()
		t.expect.equal(A.id(123), 'rbxassetid://123'); t.expect.equal(A.id('456'), 'rbxassetid://456')
		t.expect.equal(A.id(' rbxassetid://789 '), 'rbxassetid://789')
		t.expect.equal(A.id(''), nil); t.expect.equal(A.id('abc'), nil); t.expect.equal(A.id(0), nil); t.expect.equal(A.id(1.5), nil); t.expect.equal(A.id(nil), nil)
	end)

	t.test('apply points only the moves that have an id, in the R15 Animate layout', function()
		local animate = Instance.new('Folder')
		local function set(name, kids)
			local v = Instance.new('StringValue'); v.Name = name; v.Parent = animate
			for _, k in kids do local a = Instance.new('Animation'); a.Name = k; a.AnimationId = 'rbxassetid://1'; a.Parent = v end
		end
		set('idle', { 'Animation1', 'Animation2' }); set('walk', { 'WalkAnim' }); set('run', { 'RunAnim' }); set('jump', { 'JumpAnim' })
		local n = A.apply(animate, { Idle = 11, Walk = '22', Run = '' })
		t.expect.equal(n, 3)
		t.expect.equal(animate.idle.Animation1.AnimationId, 'rbxassetid://11'); t.expect.equal(animate.idle.Animation2.AnimationId, 'rbxassetid://11')
		t.expect.equal(animate.walk.WalkAnim.AnimationId, 'rbxassetid://22')
		t.expect.equal(animate.run.RunAnim.AnimationId, 'rbxassetid://1') -- (no id: Roblox's own run stays)
		t.expect.equal(A.apply(animate, { Idle = 11, Walk = '22' }), 0) -- (already set: nothing to change)
		t.expect.equal(A.apply(nil), 0)
	end)

	t.test('every move in the config has its Animate slot (or is a fight move), and the config holds only ids or blanks', function()
		for move, v in A.Config do
			t.expect.truthy(A.Slots[move] ~= nil or A.FightMoves[move] == true) -- (Oct 28: Punch, Kick are played by CharMotion)
			t.expect.truthy(v == '' or A.id(v) ~= nil)
		end
	end)
end
