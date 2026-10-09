return function(t)
 local G=require(game:GetService('ReplicatedStorage').Shared.GoalRules)
 local function state(over) local s={Power=0,Stages=0,Wave=0,Waves=true,Guns=1,Range=0} for k,v in over or {} do s[k]=v end return s end
 t.test('every goal says what, where and what it pays, in a short World 1 chain',function()
  local ids,total={},0
  t.expect.truthy(#G.List>=10)
  for i,g in G.List do
   t.expect.truthy(type(g.Text)=='string' and #g.Text>0 and type(g.Where)=='string' and #g.Where>0)
   t.expect.truthy(g.Reward>0 and g.Reward%1==0);total+=g.Reward
   t.expect.falsy(ids[g.Id]);ids[g.Id]=true;t.expect.equal(g.Step,i)
   for k in g.Need do t.expect.truthy(k=='Power' or k=='Stages' or k=='Wave' or k=='Guns' or k=='Range' or k=='Boxes') end
  end
  t.expect.truthy(total<5000)
  t.expect.equal(G.List[1].Need.Power,10);t.expect.equal(G.List[2].Need.Stages,1);t.expect.equal(G.List[3].Need.Wave,1);t.expect.equal(G.List[4].Need.Guns,2)
  t.expect.equal(G.List[#G.List].Need.Wave,16)
  t.expect.equal(G.line(G.List[3]),"Clear Stage 1's targets - in the side yard past the door")
 end)
 t.test('a goal completes once it is met, one a check, and is returned to be paid',function()
  local goals={Step=1,Synced=true}
  t.expect.equal(G.advance(goals,state({Power=9})),nil);t.expect.equal(goals.Step,1)
  local done=G.advance(goals,state({Power=12,Stages=1}));t.expect.equal(done.Id,'FreeRange');t.expect.equal(goals.Step,2)
  done=G.advance(goals,state({Power=12,Stages=1}));t.expect.equal(done.Id,'Stage1');t.expect.equal(goals.Step,3)
  t.expect.equal(G.advance(goals,state({Power=12,Stages=1,Wave=0})),nil)
  done=G.advance(goals,state({Wave=1}));t.expect.equal(done.Id,'Wave1')
  done=G.advance(goals,state({Guns=2}));t.expect.equal(done.Id,'Gun')
 end)
 t.test('a profile from before the chain catches up quietly (nothing paid)',function()
  local goals={Step=1,Synced=false}
  t.expect.equal(G.advance(goals,state({Power=9000,Stages=8,Wave=8,Guns=4,Range=0})),nil)
  t.expect.truthy(goals.Synced);t.expect.equal(G.List[goals.Step].Id,'Range2') -- (standing on BAY 2+ is still to do)
  local fresh={Step=1,Synced=false};G.advance(fresh,state());t.expect.equal(fresh.Step,1);t.expect.truthy(fresh.Synced)
 end)
 t.test('wave goals are skipped on a map without waves; the chain ends',function()
  local goals={Step=3,Synced=true}
  local done=G.advance(goals,state({Waves=false,Guns=2}));t.expect.equal(done.Id,'Gun')
  goals={Step=#G.List,Synced=true};t.expect.equal(G.advance(goals,state({Waves=false})),nil);t.expect.equal(goals.Step,#G.List+1)
  t.expect.equal(G.at(goals.Step),nil);t.expect.equal(G.advance(goals,state({Power=1e9})),nil)
 end)
 t.test('saved goals are made safe',function()
  t.expect.deepEqual(G.sanitize(nil),{Step=1,Synced=false})
  t.expect.equal(G.sanitize({Step=0/0}).Step,1);t.expect.equal(G.sanitize({Step=999}).Step,#G.List+1);t.expect.equal(G.sanitize({Step=2.5}).Step,1)
  local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
  local old={SchemaVersion=3};S.migrate(old);t.expect.equal(old.Goals.Step,1);t.expect.falsy(old.Goals.Synced);t.expect.truthy(S.validate(old))
  t.expect.truthy(S.new().Goals.Synced)
 end)
end
