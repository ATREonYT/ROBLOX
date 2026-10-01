return function(t)
 local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
 -- Players must never share nested default state.
 t.test('defaults are independent',function() local a,b=S.new(),S.new();a.Settings.Music=false;a.Crew.owned.x={CrewId='BlockCrew1'};t.expect.truthy(b.Settings.Music);t.expect.equal(b.Crew.owned.x,nil) end)
 -- Migration adds fields without losing earned currency.
 t.test('legacy migration preserves progress',function() local d={Rep=123,Cash=456,Evolution=3};S.migrate(d);t.expect.equal(d.Cash,456);t.expect.equal(d.Rep,123);t.expect.equal(d.Evolution.Block,3);t.expect.truthy(S.validate(d)) end)
 -- Older builds may not overwrite profiles written by newer code.
 t.test('rejects future schema',function() t.expect.throws(function() S.migrate({SchemaVersion=99}) end) end)
 -- Corrupt currency must fail closed.
 t.test('rejects nonfinite Rep',function() local p=S.new();p.Rep=0/0;t.expect.throws(function() S.validate(p) end) end)
 -- Client snapshots must not expose private receipt records.
 t.test('snapshot excludes receipts and passes',function() local p=S.new();p.ProcessedReceipts.secret=true;local view=S.public(p);t.expect.equal(view.ProcessedReceipts,nil);t.expect.equal(view.Passes,nil) end)
 -- Client snapshot mutation cannot modify the stored profile.
 t.test('snapshot uses independent nested tables',function() local p=S.new();local view=S.public(p);view.Settings.Music=false;t.expect.truthy(p.Settings.Music) end)
end
