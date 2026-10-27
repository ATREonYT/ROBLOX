-- World 2 (Oct 27): each world its own place sharing one profile (Shared/WorldInfo, HoodServer/WorldData).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local WI = require(RS.Shared.WorldInfo)
	local WD = require(game.ServerScriptService.HoodServer.WorldData)
	local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)

	t.test('this server is World 1 without a map that says otherwise', function()
		t.expect.equal(WI.current(), 1); t.expect.equal(WI.get(2).Name, 'Downtown'); t.expect.equal(WI.get(9), nil)
	end)

	t.test('entering World 2 sets World 1 aside and starts it fresh; coming back restores it; Power and Cash carry', function()
		local d = Schema.new(); d.Waves.Cleared = 16; d.Goals.Step = 20; d.Cash = 500; d.Rebirths = 9
		WD.enter(d, 2)
		t.expect.equal(d.CurrentWorld, 2); t.expect.equal(d.Waves.Cleared, 0); t.expect.equal(d.Goals.Step, 1)
		t.expect.equal(d.Worlds.W1.Waves.Cleared, 16); t.expect.equal(d.Cash, 500); t.expect.equal(d.Rebirths, 9)
		t.expect.equal(WI.beaten(d, 1), 16); t.expect.truthy(WI.unlocked(d, 2))
		d.Waves.Cleared = 3
		WD.enter(d, 1)
		t.expect.equal(d.Waves.Cleared, 16); t.expect.equal(d.Goals.Step, 20); t.expect.equal(d.Worlds.W2.Waves.Cleared, 3); t.expect.equal(d.Worlds.W1, nil)
		WD.enter(d, 1) -- (same world: nothing moves)
		t.expect.equal(d.Waves.Cleared, 16); t.expect.equal(WI.beaten(d, 2), 3)
	end)

	t.test('World 2 unlocks only once the World 1 boss yard is beaten', function()
		local d = Schema.new(); d.Waves.Cleared = 15
		t.expect.falsy(WI.unlocked(d, 2)); t.expect.truthy(WI.unlocked(d, 1))
		d.Waves.Cleared = 16; t.expect.truthy(WI.unlocked(d, 2))
		t.expect.falsy(WI.unlocked(nil, 2))
	end)

	t.test("World 2's numbers climb from past World 1's boss, pay more and hit harder; World 1 keeps its own", function()
		local B = require(RS.Shared.Config.Balance)
		local W1, W2 = B.Worlds[1], B.Worlds[2]
		t.expect.equal(B.World, 1); t.expect.equal(B.StagePower, W1.StagePower); t.expect.equal(B.LaneBoost, 1)
		t.expect.equal(#W2.StagePower, 16); t.expect.equal(#W2.PadCash, 16)
		t.expect.truthy(W2.StagePower[1] > W1.StagePower[16]); t.expect.truthy(W2.PadCash[1] > W1.PadCash[16])
		for s = 2, 16 do t.expect.truthy(W2.StagePower[s] > W2.StagePower[s - 1] and W2.PadCash[s] > W2.PadCash[s - 1]) end
		t.expect.truthy(W2.LaneBoost > 1)
		t.expect.truthy(W2.StagePower[16] <= B.MaxSafeValue)
	end)

	t.test('a profile from before the worlds migrates and validates in World 1', function()
		local d = Schema.new(); d.CurrentWorld = nil; d.Worlds = nil
		Schema.migrate(d); Schema.validate(d)
		t.expect.equal(d.CurrentWorld, 1); t.expect.equal(type(d.Worlds), 'table')
	end)
end
