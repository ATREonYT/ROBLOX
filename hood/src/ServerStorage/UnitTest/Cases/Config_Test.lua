return function(t)
 local Maps=require(game.ReplicatedStorage.Shared.Config.Maps)
 local Crew=require(game.ReplicatedStorage.Shared.Config.Crew)
 -- Every map exposes the intended number of progression steps.
 t.test('four maps each have ten walls and five evolutions',function() t.expect.equal(#Maps.Ordered,4);for _,m in ipairs(Maps.Ordered) do t.expect.equal(#m.Walls,10);t.expect.equal(#m.Evolutions,5) end end)
 -- Currency thresholds remain within the documented precision budget.
 t.test('wall thresholds grow and stay below numeric cap',function() for _,m in ipairs(Maps.Ordered) do local last=0;for _,w in ipairs(m.Walls) do t.expect.truthy(w.RequiredRep>last and w.RequiredRep<=1e12);last=w.RequiredRep end end end)
 -- Unknown live places fail instead of silently becoming The Block.
 t.test('unconfigured live place is rejected',function() t.expect.throws(function() Maps.resolve(999999999,false) end) end)
 -- Local projects can preview their own map without live place IDs.
 t.test('Studio fallback selects build map',function() t.expect.equal(Maps.resolve(0,true,'Hills').Id,'Hills') end)
 -- Both advertised odds tables total exactly one hundred percent.
 t.test('normal and lucky box odds sum to one hundred',function() for _,box in pairs(Crew.Boxes) do local normal,lucky=0,0;for _,o in ipairs(box.Outcomes) do normal+=o.Percent;lucky+=o.LuckyPercent;t.expect.truthy(Crew.Members[o.CrewId]) end;t.expect.equal(normal,100);t.expect.equal(lucky,100) end end)
end
