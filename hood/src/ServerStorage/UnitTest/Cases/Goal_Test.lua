return function(t)
 local G=require(game:GetService('ReplicatedStorage').Shared.GoalRules)
 local function state(over) local s={Power=0,Stages=0,Wave=0,Waves=true,Guns=1,Range=0,Rebirths=0} for k,v in over or {} do s[k]=v end return s end
 t.test('every goal says what, where and what it pays, in a short World 1 chain',function()
  local ids,total={},0
  t.expect.truthy(#G.List>=10)
  for i,g in G.List do
   t.expect.truthy(type(g.Text)=='string' and #g.Text>0 and type(g.Where)=='string' and #g.Where>0)
   t.expect.truthy(g.Reward>0 and g.Reward%1==0);total+=g.Reward
   t.expect.falsy(ids[g.Id]);ids[g.Id]=true;t.expect.equal(g.Step,i)
   for k in g.Need do t.expect.truthy(k=='Power' or k=='Stages' or k=='Wave' or k=='CashOuts' or k=='CashOutStage' or k=='Guns' or k=='Range' or k=='Boxes' or k=='Rebirths') end
   -- the goal line always fits the tracker and tells a kid the next step: what, then where or how
   t.expect.truthy(#G.line(g)<=60)
   -- No look goals, and no "Power" prices on the ranges (they open by rebirths now).
   t.expect.falsy(string.find(string.lower(g.Text..g.Where),'look',1,true));t.expect.falsy(string.find(g.Where,'Power)',1,true))
  end
  t.expect.truthy(total<10000)
  t.expect.equal(G.List[1].Need.Power,10);t.expect.equal(G.List[2].Need.Stages,1);t.expect.equal(G.List[3].Need.Wave,1);t.expect.equal(G.List[4].Need.CashOuts,1);t.expect.equal(G.List[5].Need.Guns,2)
  -- (brief 23) the run loop: beat the crew, then cash out on a pad before the gate
  t.expect.equal(G.line(G.List[3]),'Beat the Stage 1 crew - hold to shoot them')
  t.expect.equal(G.line(G.List[4]),'Step on the yellow pad - by the gate: +10 Cash')
  t.expect.truthy(string.find(G.ById.Stage3.Where,'crew',1,true))
  -- (ECON) the first minute's goals pay less than the first pad: the yellow pad's Cash is the biggest number there
  local PadRules=require(game:GetService('ReplicatedStorage').Shared.PadRules)
  for step=1,G.ById.Shoe.Step do t.expect.truthy(G.List[step].Reward<PadRules.reward(1,false)) end
  -- Lane goals read ECON's ladder (Config/Skins): the lane's name and rebirths, never a Robux lane.
  local Skins=require(game:GetService('ReplicatedStorage').Shared.Config.Skins)
  for _,g in G.List do
   if g.Need.Range then
    local st=Skins.Stations[g.Need.Range];t.expect.truthy(st~=nil and st.Pass==nil)
    t.expect.truthy(string.find(g.Text,st.Name,1,true));t.expect.truthy(string.find(g.Where,tostring(st.Rebirths)..' rebirths',1,true))
   end
  end
  -- The armory is the stepped stand on the right (east) of the hall now.
  t.expect.truthy(string.find(G.ById.Gun.Where,'right',1,true));t.expect.falsy(string.find(G.ById.Gun.Where,'corner',1,true))
  -- Rebirth goals and lane goals by rebirths.
  t.expect.equal(G.ById.Rebirth1.Need.Rebirths,1);t.expect.equal(G.ById.Range2.Need.Range,2);t.expect.truthy(string.find(G.ById.Range2.Where,'2 rebirths',1,true))
  t.expect.equal(G.List[#G.List].Need.Range,9)
 end)
 t.test('a goal completes once it is met, one a check, and is returned to be paid',function()
  local goals={Step=1,Synced=true}
  t.expect.equal(G.advance(goals,state({Power=9})),nil);t.expect.equal(goals.Step,1)
  local done=G.advance(goals,state({Power=12,Stages=1}));t.expect.equal(done.Id,'FreeRange');t.expect.equal(goals.Step,2)
  done=G.advance(goals,state({Power=12,Stages=1}));t.expect.equal(done.Id,'Stage1');t.expect.equal(goals.Step,3)
  t.expect.equal(G.advance(goals,state({Power=12,Stages=1,Wave=0})),nil)
  done=G.advance(goals,state({Wave=1}));t.expect.equal(done.Id,'Wave1')
  t.expect.equal(G.advance(goals,state({Wave=1,Guns=2})),nil) -- (cash out first)
  done=G.advance(goals,state({CashOuts=1}));t.expect.equal(done.Id,'CashOut')
  done=G.advance(goals,state({Guns=2}));t.expect.equal(done.Id,'Gun')
  -- then the stage 2 pad, which pays for the shoe box after it
  t.expect.equal(G.advance(goals,state({CashOuts=2,CashOutStage=1})),nil)
  done=G.advance(goals,state({CashOutStage=2,ShoeBoxes=true}));t.expect.equal(done.Id,'CashOut2');t.expect.equal(G.List[goals.Step].Id,'Shoe')
  t.expect.equal(G.line(G.ById.CashOut2),'Beat Stage 2 and cash out - the yellow pad: +'..require(game:GetService('ReplicatedStorage').Shared.PadRules).reward(2,false)..' Cash')
  goals.Step=G.ById.Rebirth1.Step
  t.expect.equal(G.advance(goals,state({Power=1e6})),nil) -- (Power alone isn't a rebirth)
  done=G.advance(goals,state({Rebirths=1}));t.expect.equal(done.Id,'Rebirth1')
 end)
 t.test('a profile from before the chain catches up quietly (nothing paid)',function()
  local goals={Step=1,Synced=false}
  t.expect.equal(G.advance(goals,state({Power=9000,Stages=8,Wave=8,CashOuts=1,CashOutStage=2,Guns=4,Range=0})),nil)
  t.expect.truthy(goals.Synced);t.expect.equal(G.List[goals.Step].Id,'Rebirth1') -- (a first rebirth is still to do)
  -- never cashed out on a pad: that is the next step, whatever else they have done
  local veteran={Step=1,Synced=false};G.advance(veteran,state({Power=9000,Stages=8,Wave=8,Guns=4}));t.expect.equal(G.List[veteran.Step].Id,'CashOut')
  local fresh={Step=1,Synced=false};G.advance(fresh,state());t.expect.equal(fresh.Step,1);t.expect.truthy(fresh.Synced)
 end)
 t.test('wave goals are skipped on a map without waves; the chain ends',function()
  local goals={Step=3,Synced=true}
  local done=G.advance(goals,state({Waves=false,Guns=2}));t.expect.equal(done.Id,'Gun')
  goals={Step=#G.List,Synced=true};t.expect.equal(G.advance(goals,state({Waves=false})),nil)
  done=G.advance(goals,state({Waves=false,Range=9}));t.expect.equal(done.Id,'Ring');t.expect.equal(goals.Step,#G.List+1)
  t.expect.equal(G.at(goals.Step),nil);t.expect.equal(G.advance(goals,state({Power=1e9})),nil)
 end)
 t.test('saved goals are made safe',function()
  t.expect.deepEqual(G.sanitize(nil),{Step=1,Synced=false})
  t.expect.equal(G.sanitize({Step=0/0}).Step,1);t.expect.equal(G.sanitize({Step=999}).Step,#G.List+1);t.expect.equal(G.sanitize({Step=2.5}).Step,1)
  local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
  local old={SchemaVersion=3};S.migrate(old);t.expect.equal(old.Goals.Step,1);t.expect.falsy(old.Goals.Synced);t.expect.truthy(S.validate(old))
  t.expect.truthy(S.new().Goals.Synced)
  -- a new profile starts on this chain (the template's Chain is GoalRules.Chain: nothing to migrate)
  t.expect.equal(S.Template.Goals.Chain,G.Chain);t.expect.equal(S.new().Goals.Chain,G.Chain)
  local fresh=S.new();G.migrate(fresh.Goals);t.expect.equal(fresh.Goals.Step,1)
  -- a new profile, loaded, sits on the first goal of this chain
  local loaded=S.migrate(S.new());t.expect.equal(loaded.Goals.Chain,G.Chain);t.expect.equal(loaded.Goals.Step,1);t.expect.truthy(loaded.Goals.Synced)
 end)
 -- Brief 17 rewrote the chain (chain 3): a saved step moves to the same goal by id; a goal that is gone moves to the
 -- one that took its place; a step past the old end stays past the end.
 t.test('saves from the older chains land on the same goal',function()
  local function from(chain,step,back) return G.migrate({Chain=chain,Step=step,Back=back,Synced=true}) end
  local function id(goals) return G.List[goals.Step] and G.List[goals.Step].Id or 'done' end
  t.expect.equal(id(from(2,1)),'FreeRange');t.expect.equal(id(from(2,4)),'Gun');t.expect.equal(id(from(2,6)),'Stage3')
  t.expect.equal(id(from(2,7)),'Range2');t.expect.equal(id(from(2,9)),'Gun4');t.expect.equal(id(from(2,12)),'Range4')
  t.expect.equal(id(from(2,16)),'BossWave');t.expect.equal(id(from(2,17)),'done');t.expect.equal(from(2,16).Chain,G.Chain)
  local detour=from(2,5,7);t.expect.equal(id(detour),'Shoe');t.expect.equal(G.List[detour.Back].Id,'Range2')
  -- Chain 1 had no shoe goal: a player already past it gets it as a detour, back to their own goal.
  local v1=from(1,7);t.expect.equal(id(v1),'Shoe');t.expect.equal(G.List[v1.Back].Id,'Stage6')
  t.expect.equal(id(from(1,2)),'Stage1');t.expect.falsy(from(1,2).Back)
  -- Chain 3 (brief 17) -> 4 (brief 23: the pad goal after the Stage 1 crew; BAY 8 is a Robux lane now, BAY 6 takes its
  -- place). The new pad goal isn't handed out to a player already past it.
  t.expect.equal(id(from(3,3)),'Wave1');t.expect.equal(id(from(3,4)),'Gun');t.expect.falsy(from(3,4).Back)
  t.expect.equal(id(from(3,7)),'Rebirth1');t.expect.equal(id(from(3,19)),'Range6');t.expect.equal(id(from(3,20)),'Ring');t.expect.equal(id(from(3,21)),'done')
  local d3=from(3,5,7);t.expect.equal(id(d3),'Shoe');t.expect.equal(G.List[d3.Back].Id,'Rebirth1');t.expect.equal(d3.Chain,G.Chain)
  local current=G.migrate({Chain=4,Step=9,Synced=true});t.expect.equal(current.Step,9)
 end)
end
