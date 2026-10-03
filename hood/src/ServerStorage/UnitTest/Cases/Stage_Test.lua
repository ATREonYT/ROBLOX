return function(t)
 local R=require(game.ReplicatedStorage.Shared.StageRules)
 local Maps=require(game.ReplicatedStorage.Shared.Config.Maps)
 local function gates()
  local list={}
  for i,w in Maps.ById.Block.Walls do table.insert(list,{Stage=i,WallId=w.Id,Required=w.RequiredRep,Reward=w.CashReward,Z=-20-(i-1)*36,HalfWidth=20}) end
  return list
 end
 t.test('standing in front of a gate clears nothing',function() local n,b=R.check(gates(),Vector3.new(0,3,-10),1e9,{});t.expect.equal(#n,0);t.expect.equal(b,nil) end)
 t.test('walking past an open gate clears it once',function()
  local g=gates();local cleared={}
  local n=R.check(g,Vector3.new(0,3,-25),50,cleared);t.expect.equal(#n,1);t.expect.equal(n[1].Stage,1)
  cleared[n[1].WallId]=true
  n=R.check(g,Vector3.new(0,3,-26),50,cleared);t.expect.equal(#n,0)
  t.expect.equal(R.count(g,cleared),1)
 end)
 t.test('gate number is inclusive',function() local n,b=R.check(gates(),Vector3.new(0,3,-25),49,{});t.expect.equal(#n,0);t.expect.equal(b.Stage,1) end)
 t.test('slipping past a locked gate is caught only near it',function()
  local _,b=R.check(gates(),Vector3.new(4,3,-60),60,{Block_never=true});t.expect.equal(b.Stage,2)
  local _,far=R.check(gates(),Vector3.new(4,3,-75),60,{});t.expect.equal(far,nil)
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
  for _,b in V2.TrainHere do t.expect.truthy(S.StationById[b.Id]~=nil) end
 end)
 t.test('every stage needs more power than the last, and each new bag works the moment you get in',function()
  local V2=require(game.ServerStorage.TheBlockV2);local S=require(game.ReplicatedStorage.Shared.Config.Skins)
  t.expect.equal(#V2.StagePower,16)
  for i=2,#V2.StagePower do t.expect.truthy(V2.StagePower[i]>V2.StagePower[i-1]) end
  for stage,id in V2.RouteTraining do t.expect.truthy(S.StationById[id].Required<=V2.StagePower[stage]) end
  t.expect.truthy(S.StationById.Ring.Required<=V2.StagePower[16])
 end)
end
