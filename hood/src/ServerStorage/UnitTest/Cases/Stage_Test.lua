return function(t)
 local R=require(game.ReplicatedStorage.Shared.StageRules)
 local Maps=require(game.ReplicatedStorage.Shared.Config.Maps)
 local function gates()
  local list={}
  for i,w in Maps.ById.Block.Walls do table.insert(list,{Stage=i,WallId=w.Id,Required=w.RequiredRep,Reward=w.CashReward,Z=-20-(i-1)*36,HalfWidth=20}) end
  return list
 end
 -- (brief 23: runs) open = the furthest gate open this run (RunStage); passed = the gates ever passed (saved).
 t.test('standing in front of a gate records nothing',function() local n,b=R.check(gates(),Vector3.new(0,3,-10),1,{});t.expect.equal(#n,0);t.expect.equal(b,nil) end)
 t.test('walking past an open gate records it once (the saved best)',function()
  local g=gates();local passed={}
  local n=R.check(g,Vector3.new(0,3,-25),1,passed);t.expect.equal(#n,1);t.expect.equal(n[1].Stage,1)
  passed[n[1].WallId]=true
  n=R.check(g,Vector3.new(0,3,-26),1,passed);t.expect.equal(#n,0)
  t.expect.equal(R.count(g,passed),1)
 end)
 t.test('a gate opens when the crew before it is down, every run; gate 1 always; Power has no say',function()
  t.expect.truthy(R.gateOpen(1,0));t.expect.falsy(R.gateOpen(2,0));t.expect.truthy(R.gateOpen(2,1));t.expect.falsy(R.gateOpen(3,1));t.expect.truthy(R.gateOpen(3,7))
  t.expect.falsy(R.gateOpen(nil,5));t.expect.falsy(R.gateOpen(2.5,5));t.expect.falsy(R.gateOpen(2,0/0))
  t.expect.equal(R.runStage(0,16),1);t.expect.equal(R.runStage(3,16),4);t.expect.equal(R.runStage(15,16),16);t.expect.equal(R.runStage(16,16),16)
  t.expect.equal(R.runStage(nil,16),1);t.expect.equal(R.runStage(-2,16),1);t.expect.equal(R.runStage(2.5,16),1);t.expect.equal(R.runStage(4),5)
  -- the same rule as the run's furthest gate: gate n is open exactly when n <= runStage
  for c=0,16 do for n=1,16 do t.expect.equal(R.gateOpen(n,c),n<=R.runStage(c,16)) end end
 end)
 t.test('past a gate not open this run is caught at any depth, whatever your Power',function()
  local g=gates()
  local _,b=R.check(g,Vector3.new(4,3,-60),1,{});t.expect.equal(b.Stage,2)
  local _,deep=R.check(g,Vector3.new(4,3,-75),1,{});t.expect.equal(deep.Stage,2) -- (no "only near it" any more)
  local _,far=R.check(g,Vector3.new(0,3,-20-5*36-3),2,{});t.expect.equal(far.Stage,3) -- (the first shut gate you are past)
  local n,none=R.check(g,Vector3.new(4,3,-75),2,{});t.expect.equal(none,nil);t.expect.equal(#n,2)
 end)
 t.test('the run is over in the lobby (gate 1\'s lobby side, any X)',function()
  local g=gates()
  t.expect.truthy(R.inLobby(g,Vector3.new(0,3,-20+R.LOBBY_MARGIN+0.5)));t.expect.truthy(R.inLobby(g,Vector3.new(60,3,40)))
  t.expect.falsy(R.inLobby(g,Vector3.new(0,3,-20+R.LOBBY_MARGIN-0.5)));t.expect.falsy(R.inLobby(g,Vector3.new(0,3,-30)));t.expect.falsy(R.inLobby({},Vector3.new(0,3,99)))
 end)
 t.test('a stage\'s pads pay once its crew is down this run',function()
  t.expect.falsy(R.padReady(1,0));t.expect.truthy(R.padReady(1,1));t.expect.falsy(R.padReady(2,1));t.expect.truthy(R.padReady(2,9));t.expect.truthy(R.padReady(16,16))
  t.expect.falsy(R.padReady(0,5));t.expect.falsy(R.padReady(nil,5));t.expect.falsy(R.padReady(1,nil));t.expect.falsy(R.padReady(1.5,5))
 end)
 t.test('alcoves beside the street do not count as the street',function() local n=R.check(gates(),Vector3.new(30,3,-25),1e9,{});t.expect.equal(#n,0) end)
 t.test('gates read from tagged models come back in stage order',function()
  local models={}
  for _,i in {3,1,2} do local m=Instance.new('Model');m:SetAttribute('Stage',i);m:SetAttribute('WallId','W'..i);m:SetAttribute('Required',i*10);m:SetAttribute('LineZ',-i*10);table.insert(models,m) end
  local g=R.fromModels(models);t.expect.equal(g[1].Stage,1);t.expect.equal(g[3].WallId,'W3');t.expect.equal(g[2].HalfWidth,20)
 end)
 t.test('the hood map runs 15 fights in walking order, then the boss',function()
  local V2=require(game.ServerStorage.TheBlockV2);local S=require(game.ReplicatedStorage.Shared.Config.Skins)
  t.expect.equal(#V2.Fights,16)
  for i,f in V2.Fights do
   t.expect.equal(f.Fight,i)
   if i>1 then t.expect.truthy(f.Z<=V2.Fights[i-1].Z) end
  end
  t.expect.truthy(V2.Fights[16].Boss)
 end)
 t.test('every stage needs more power than the last, from the economy table, and the Champ Ring opens last',function()
  local V2=require(game.ServerStorage.TheBlockV2);local S=require(game.ReplicatedStorage.Shared.Config.Skins)
  local Balance=require(game.ReplicatedStorage.Shared.Config.Balance)
  t.expect.equal(#V2.StagePower,16);t.expect.equal(#Balance.StagePower,16);t.expect.equal(#Balance.StageCash,16);t.expect.equal(#Balance.WaveCash,16)
  for i=1,16 do t.expect.equal(V2.StagePower[i],Balance.StagePower[i]) end
  t.expect.equal(V2.StagePower[1],10)
  for i=2,#V2.StagePower do t.expect.truthy(V2.StagePower[i]>V2.StagePower[i-1]);t.expect.truthy(Balance.PadCash[i]>Balance.PadCash[i-1]) end
  -- (brief 23) gates and goon clears pay no Cash: the pad at the end of the run is the one big Cash moment
  for i=1,16 do t.expect.equal(Balance.StageCash[i],0);t.expect.equal(Balance.WaveCash[i],0) end
  t.expect.equal(Balance.WaveRepeatShare,0)
  for _,s in S.Stations do t.expect.truthy(s.Rebirths<=S.StationById.Ring.Rebirths) end
 end)
 -- A gate you passed once stays saved (the leaderboard's Stage), but a new run opens only what its crews allow.
 t.test('gates ever passed stay saved; a new run still opens only what its crews allow',function()
  local g=gates();local passed={}
  for i=1,3 do passed[g[i].WallId]=true end
  local n,b=R.check(g,Vector3.new(0,3,-20-2*36-5),1,passed);t.expect.equal(#n,0);t.expect.equal(b.Stage,2) -- (a fresh run: gate 2 is shut again)
  n,b=R.check(g,Vector3.new(0,3,-20-2*36-5),3,passed);t.expect.equal(#n,0);t.expect.equal(b,nil)
  n,b=R.check(g,Vector3.new(0,3,-20-3*36-4),4,passed);t.expect.equal(#n,1);t.expect.equal(n[1].Stage,4);t.expect.equal(b,nil)
  t.expect.equal(R.furthest(g,passed),3);t.expect.equal(R.furthest(g,{}),0)
 end)
 -- The server's run tracker (HoodServer/Runs): a separate one per test, players stood in by Folders.
 t.test('a run: crews open gates one by one, a pad pays once, the lobby shuts everything again',function()
  local Runs=require(game.ServerScriptService.HoodServer.Runs).new()
  Runs.LastGate=16
  Runs.setCrews({[1]={'Goon'},[2]={'Goon'},[3]={'Goon'},[16]={'Boss'}},16)
  local p=Instance.new('Folder')
  local ended={};Runs.onReset(function(who,why) table.insert(ended,why) end)
  Runs.publish(p);t.expect.equal(p:GetAttribute('RunCleared'),0);t.expect.equal(p:GetAttribute('RunStage'),1)
  t.expect.falsy(Runs.reset(p,'lobby'));t.expect.equal(#ended,0) -- (nothing started: nothing to end)
  Runs.start(p)
  t.expect.falsy(Runs.claim(p,1)) -- (the crew still stands)
  t.expect.truthy(Runs.clear(p,1));t.expect.equal(p:GetAttribute('RunStage'),2);t.expect.falsy(Runs.clear(p,1))
  t.expect.truthy(Runs.claim(p,1));t.expect.falsy(Runs.claim(p,1)) -- (once a run)
  t.expect.falsy(Runs.claim(p,2))
  t.expect.truthy(Runs.clear(p,2));t.expect.equal(Runs.stage(p),3)
  -- stages 4..15 have no goons here: beating stage 3 opens everything up to the boss yard
  t.expect.truthy(Runs.clear(p,3));t.expect.equal(Runs.cleared(p),15);t.expect.equal(p:GetAttribute('RunStage'),16)
  t.expect.truthy(Runs.reset(p,'pad'));t.expect.equal(ended[1],'pad')
  t.expect.equal(p:GetAttribute('RunCleared'),0);t.expect.equal(p:GetAttribute('RunStage'),1);t.expect.truthy(Runs.claim(p,1)==false)
  -- a new run: the pad of stage 1 pays again once its crew falls again
  Runs.clear(p,1);t.expect.truthy(Runs.claim(p,1))
  t.expect.falsy(Runs.clear(p,0/0));t.expect.falsy(Runs.clear(p,'2'))
  -- a map with gates and no goons at all: every gate is open
  local open=require(game.ServerScriptService.HoodServer.Runs).new();open.LastGate=16;open.setCrews({},16)
  local q=Instance.new('Folder');open.publish(q);t.expect.equal(q:GetAttribute('RunStage'),16)
 end)
end
