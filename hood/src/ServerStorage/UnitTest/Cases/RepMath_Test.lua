return function(t)
 local M=require(game.ReplicatedStorage.Shared.RepMath)
 local maps=require(game.ReplicatedStorage.Shared.Config.Maps)
 local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
 -- A new Block player earns exactly +1 per base tick.
 t.test('new player base rate is one',function() t.expect.equal(M.getRepPerTick(S.new(),maps.ById.Block),1) end)
 -- Each map supplies its specified progression multiplier.
 t.test('map multiplier is applied',function() t.expect.equal(M.getRepPerTick(S.new(),maps.ById.Suburbs),5) end)
 -- The guaranteed companion improves the base rate.
 t.test('equipped Bodega Cat adds fifty percent',function() local p=S.new();p.Crew.owned.cat={CrewId='BlockCrew1'};p.Crew.equipped={'cat'};t.expect.equal(M.getRepPerTick(p,maps.ById.Block),1.5) end)
 -- Duplicate instance IDs do not produce duplicate bonuses.
 t.test('duplicate equipped UID counts once',function() local p=S.new();p.Crew.owned.cat={CrewId='BlockCrew1'};p.Crew.equipped={'cat','cat'};t.expect.equal(M.getRepPerTick(p,maps.ById.Block),1.5) end)
 -- Unowned companions cannot grant multipliers.
 t.test('ignores unowned crew',function() local p=S.new();p.Crew.equipped={'missing'};t.expect.equal(M.getRepPerTick(p,maps.ById.Block),1) end)
 -- Saved pass cache is not authorization for monetized bonuses.
 t.test('ignores cached entitlement',function() local p=S.new();p.Passes.DoubleRep=true;t.expect.equal(M.getRepPerTick(p,maps.ById.Block),1) end)
 -- Friend bonus is capped at fifty percent.
 t.test('caps friend bonus',function() t.expect.near(M.getRepPerTick(S.new(),maps.ById.Block,{Friends=50}),1.5) end)
 -- Independent multipliers compose under a known scenario.
 t.test('combines evolution rebirth and verified pass',function() local p=S.new();p.Evolution.Block=2;p.Rebirths=2;t.expect.equal(M.getRepPerTick(p,maps.ById.Block,{DoubleRep=true}),6) end)
end
