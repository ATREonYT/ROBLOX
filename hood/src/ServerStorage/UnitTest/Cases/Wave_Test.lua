return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local W=require(RS.Shared.WaveRules)
 local StageRules=require(RS.Shared.StageRules)
 local ShotRules=require(RS.Shared.ShotRules)
 -- Gates like the hood map's: stage i's line at z = -(i-1)*64, 16 of them (16 opens the boss yard).
 local function gates() local g={} for i=1,16 do table.insert(g,{Stage=i,WallId='HoodW1Stage'..i,Required=i*10,Z=-(i-1)*64,HalfWidth=36}) end return g end
 -- A small world: stage 1 has a board (at x 13, 20 into the stage) and cans; stage 2 one cone.
 local function world() return {[1]={{Kind='Board',Pos=Vector3.new(13,3,-20)},{Kind='Cans',Pos=Vector3.new(13,3,-28)}},[2]={{Kind='Cone',Pos=Vector3.new(-13,3,-90)}}} end
 local function clock() local c={t=0} return c,function() return c.t end end
 t.test('targets get tougher every stage, each kind has a weight, every stage has a lineup',function()
  t.expect.equal(#W.HP,16);t.expect.equal(#W.Lineups,16)
  for i=2,#W.HP do t.expect.truthy(W.HP[i]>W.HP[i-1]) end
  for _,lineup in W.Lineups do for _,k in lineup do t.expect.truthy(W.Kinds[k]~=nil) end end
  t.expect.truthy(#W.Lineups[16]>#W.Lineups[15]);t.expect.truthy(table.find(W.Lineups[16],'MegaBoard')~=nil)
  t.expect.equal(W.maxHp(1,'Board'),10);t.expect.equal(W.maxHp(1,'Cans'),6);t.expect.equal(W.maxHp(16,'MegaBoard'),7500);t.expect.equal(W.maxHp(99,'Board'),2500)
 end)
 t.test('a hit deals its damage; the last target down clears the wave; a downed target takes nothing',function()
  local w=W.spawn(1,{'Board','Cans'})
  t.expect.equal(w.Left,2);t.expect.equal(w.HP[1],10)
  local hit,down,clear=W.hit(w,1,4);t.expect.truthy(hit);t.expect.falsy(down);t.expect.equal(w.HP[1],6)
  hit,down,clear=W.hit(w,1,50);t.expect.truthy(down);t.expect.falsy(clear);t.expect.equal(w.HP[1],0);t.expect.equal(w.Left,1)
  hit=W.hit(w,1,5);t.expect.falsy(hit)
  hit,down,clear=W.hit(w,2,6);t.expect.truthy(clear);t.expect.truthy(w.Cleared);t.expect.equal(w.Left,0)
  t.expect.falsy((W.hit(w,2,1)));t.expect.falsy((W.hit(w,3,1)))
 end)
 t.test('your wave spawns when you walk in, keeps its HP while you step out, respawns after a clear',function()
  local _,now=clock()
  local s=W.session(world(),now)
  t.expect.truthy(s:move(1)~=nil);t.expect.equal(s.Stage,1)
  t.expect.truthy((s:shoot(1,1,Vector3.new(0,3,-10),4)))
  t.expect.equal(s:move(nil),nil);t.expect.equal(s.Stage,0)
  t.expect.equal(s:move(1),nil);t.expect.equal(s:current().HP[1],6) -- (kept: not cleared yet)
  s:shoot(1,1,Vector3.new(0,3,-10),99);local ok,_,_,_,cleared=s:shoot(1,2,Vector3.new(0,3,-10),99);t.expect.truthy(ok);t.expect.truthy(cleared)
  t.expect.equal(s:move(1),nil) -- (still here: stays cleared)
  s:move(2);t.expect.truthy(s:move(1)~=nil);t.expect.equal(s:current().HP[1],10);t.expect.equal(s:current().Left,2)
  t.expect.equal(s:move(5),nil);t.expect.equal(s.Stage,0) -- (a stage with no targets is no wave)
 end)
 t.test('shots at another stage, out of range, at a missing target or with junk arguments are refused',function()
  local c,now=clock()
  local s=W.session(world(),now);s:move(1)
  local function why(...) local ok,r=s:shoot(...) c.t+=1 return ok and 'ok' or r end
  t.expect.equal(why(2,1,Vector3.new(0,3,-10),1),'stage')
  t.expect.equal(why(1,1,Vector3.new(13,3,-20+W.Range+5),1),'range')
  t.expect.equal(why(1,3,Vector3.new(0,3,-10),1),'target')
  t.expect.equal(why('1',1,Vector3.new(),1),'bad');t.expect.equal(why(1,1.5,Vector3.new(),1),'bad');t.expect.equal(why(1,0/0,Vector3.new(),1),'bad');t.expect.equal(why(0,1,Vector3.new(),1),'bad');t.expect.equal(why(1,999,Vector3.new(),1),'bad')
  t.expect.equal(why(1,1,Vector3.new(0,3,-10),1),'ok')
 end)
 t.test('shots are rate limited like the ranges: a burst, then the refill rate',function()
  local c,now=clock()
  local s=W.session({[1]={{Kind='MegaBoard',Pos=Vector3.new(0,0,-20)}}},now);s:move(1)
  local n=0
  for _=1,30 do if s:shoot(1,1,Vector3.new(0,0,-10),1) then n+=1 end end
  t.expect.equal(n,ShotRules.Burst)
  c.t+=1;n=0
  for _=1,30 do if s:shoot(1,1,Vector3.new(0,0,-10),1) then n+=1 end end
  t.expect.equal(n,ShotRules.PerSecond)
 end)
 t.test('you stand in a stage between its gate and the next; the boss yard runs past the last gate',function()
  local g=gates()
  t.expect.equal(W.stageAt(g,Vector3.new(0,3,10)),nil);t.expect.equal(W.stageAt(g,Vector3.new(0,3,-1)),1);t.expect.equal(W.stageAt(g,Vector3.new(14,3,-63)),1)
  t.expect.equal(W.stageAt(g,Vector3.new(0,3,-64)),1);t.expect.equal(W.stageAt(g,Vector3.new(0,3,-65)),2);t.expect.equal(W.stageAt(g,Vector3.new(0,3,-1000)),16);t.expect.equal(W.stageAt(g,Vector3.new(0,3,-960-W.LastDepth-1)),nil)
  t.expect.equal(W.stageAt(g,Vector3.new(50,3,-20)),nil)
 end)
 t.test('a gate needs the wave before it down, as well as its Power; no wave system keeps Power only',function()
  local g=gates()
  -- Walking the street with plenty of Power: only the gates whose waves are down count as passed.
  local n,b=StageRules.check(g,Vector3.new(0,3,-520),1000,{},0);t.expect.equal(#n,1);t.expect.equal(b.Stage,9)
  n=StageRules.check(g,Vector3.new(0,3,-520),1000,{},3);t.expect.equal(#n,4)
  n,b=StageRules.check(g,Vector3.new(0,3,-520),1000,{},16);t.expect.equal(#n,9);t.expect.equal(b,nil)
  n,b=StageRules.check(g,Vector3.new(0,3,-520),1000,{},nil);t.expect.equal(#n,9);t.expect.equal(b,nil)
  -- Just past gate 2: held back until stage 1's wave is down.
  n,b=StageRules.check(g,Vector3.new(0,3,-70),1000,{HoodW1Stage1=true},0);t.expect.equal(#n,0);t.expect.equal(b.Stage,2)
  n,b=StageRules.check(g,Vector3.new(0,3,-70),1000,{HoodW1Stage1=true},1);t.expect.equal(#n,1);t.expect.equal(b,nil)
  t.expect.truthy(W.gateOpen(1,0));t.expect.falsy(W.gateOpen(2,0));t.expect.truthy(W.gateOpen(2,1));t.expect.truthy(W.gateOpen(9,nil))
 end)
 t.test('stages with no targets never hold a gate; the first clear pays a little Cash',function()
  t.expect.equal(W.effective(0,{[1]=true,[2]=true},16),0);t.expect.equal(W.effective(1,{[1]=true,[3]=true},16),2)
  t.expect.equal(W.effective(0,{},16),16);t.expect.equal(W.effective('x',{[1]=true},16),0)
  t.expect.equal(W.reward(10),5);t.expect.equal(W.reward(20000),1000);t.expect.equal(W.reward(0/0),5)
 end)
 t.test('clears persist in the profile; old profiles keep every gate they had passed',function()
  local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
  local fresh=S.new();t.expect.equal(fresh.Waves.Cleared,0);t.expect.truthy(S.validate(fresh))
  local old={SchemaVersion=3,Rep=500,Cash=50,ClearedWalls={HoodW1Stage1=true,HoodW1Stage2=true,HoodW1Stage5=true,Block_Wall1=true}}
  S.migrate(old);t.expect.equal(old.Waves.Cleared,5);t.expect.truthy(S.validate(old))
  local kept={SchemaVersion=3,Waves={Cleared=3},ClearedWalls={HoodW1Stage9=true}};S.migrate(kept);t.expect.equal(kept.Waves.Cleared,3)
  local bad={SchemaVersion=3,Waves={Cleared=2.5}};S.migrate(bad);t.expect.equal(bad.Waves.Cleared,0)
  local junk={SchemaVersion=3,Waves={Cleared=1e9}};S.migrate(junk);t.expect.equal(junk.Waves.Cleared,W.MaxStage)
  t.expect.equal(S.public(old).Waves.Cleared,5)
  local p=S.new();p.Waves.Cleared=-1;t.expect.throws(function() S.validate(p) end)
 end)
 t.test('aiming picks the target nearest the middle of the screen and keeps it while it stands',function()
  local list={a={Pos=Vector3.new(10,0,-30),Up=true},b={Pos=Vector3.new(-2,0,-30),Up=true},c={Pos=Vector3.new(0,0,-30),Up=false},far={Pos=Vector3.new(0,0,-500),Up=true}}
  local eye,look,from=Vector3.new(0,5,0),Vector3.new(0,0,-1),Vector3.new(0,0,0)
  t.expect.equal(W.pick(list,eye,look,from,nil),'b')
  t.expect.equal(W.pick(list,eye,look,from,'a'),'a')
  list.a.Up=false;t.expect.equal(W.pick(list,eye,look,from,'a'),'b')
  list.b.Up=false;t.expect.equal(W.pick(list,eye,look,from,nil),nil)
 end)
 t.test('the map reads targets by stage and index, and leaves out broken ones',function()
  local function m(st,ix,kind,aim) local x=Instance.new('Model');x.Name='T'..tostring(st)..'_'..tostring(ix);x:SetAttribute('Stage',st);x:SetAttribute('Index',ix);x:SetAttribute('Kind',kind);x:SetAttribute('Aim',aim);return x end
  local v=Vector3.new(1,2,3)
  local wld,bad=W.worldFrom({m(1,2,'Cans',v),m(1,1,'Board',v),m(2,2,'Cone',v),m(3,1,'Sword',v),m(4,1,'Board',nil)})
  t.expect.equal(#wld[1],2);t.expect.equal(wld[1][1].Kind,'Board');t.expect.equal(wld[2],nil);t.expect.equal(wld[3],nil);t.expect.equal(#bad,3)
 end)
 t.test('every stage sets up its own wave in its district: off the road, past the gate, in range, no spot repeated',function()
  local V2=require(game.ServerStorage.TheBlockV2)
  local Waves=V2.Waves;t.expect.truthy(Waves~=nil)
  for stage=1,16 do
   local set=Waves.Sets[stage];t.expect.truthy(set~=nil)
   t.expect.truthy(#set>=#W.Lineups[stage])
   for _,s in ipairs(set) do t.expect.truthy(math.abs(s[1])>=9.5 and math.abs(s[1])-8.5<=W.Range-20 and s[2]>=6 and s[2]<=48) end
  end
  -- (three stages a district: no spot is used twice within one; every district has its own kind of target)
  local own={'Board','Sign','Bottles','Backboard','Tyres'}
  for d=0,4 do
   local seen,dup={},0
   for stage=d*3+1,d*3+3 do
    for _,s in ipairs(Waves.Sets[stage]) do local key=math.floor(s[1]+0.5)..':'..math.floor(s[2]+0.5);if seen[key] then dup+=1 end;seen[key]=true end
   end
   t.expect.truthy(dup<=1)
   local found=false
   for stage=d*3+1,d*3+3 do if table.find(W.Lineups[stage],own[d+1]) then found=true end end
   t.expect.truthy(found)
  end
 end)
end
