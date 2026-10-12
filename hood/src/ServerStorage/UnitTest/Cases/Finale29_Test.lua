-- (brief 29, P3b; brief 30) The last stage, the warehouse: the Harbor crew's strongest (three moves, each with a RED
-- telegraph of at least a second; no phases, perch, entrance or reserve doors any more) with its crew in front of the far
-- door, won when the last of them falls; and the World Boss (the clock, its HP from who is there, the Cash split by damage
-- share, its moves, the SKIP).
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local E=require(RS.Shared.EnemyRules)
 local W=require(RS.Shared.WaveRules)
 local WB=require(RS.Shared.WorldBossRules)
 local Balance=require(RS.Shared.Config.Balance)
 local function gates() local g={} for i=1,16 do table.insert(g,{Stage=i,WallId='HoodW1Stage'..i,Required=Balance.StagePower[i],Z=-(i-1)*64,HalfWidth=36}) end return g end

 t.test('the last stage\'s strongest (brief 30, no extras): three moves, each telegraphed in red for at least a second',function()
  local b=E.Bosses.harbor
  t.expect.truthy(b.Final);t.expect.equal(b.Perch,nil);t.expect.equal(b.Entrance,nil);t.expect.equal(b.Card,nil);t.expect.equal(b.PhaseAt,nil)
  t.expect.equal(E.shownName('harbor_boss'),'The Harbor Captain')
  local moves=E.movesOf({Kind='Boss',Look='harbor_boss'})
  t.expect.equal(table.concat(moves,','),'Forklift,Anchor,Containers')
  -- every move: where it shows is a hit, outside it a miss
  local g={Kind='Boss',Look='harbor_boss',Pos=Vector3.new(0,0,-1030)}
  local you=Vector3.new(4,0,-1020)
  for n,name in moves do
   g.MoveN=n-1
   local a=E.planAttack(g,you,nil,{})
   t.expect.truthy(a~=nil and a.Move==name)
   t.expect.truthy(a.Tele>=1.0 and a.Damage>0 and a.Damage<=E.MaxPunch)
   local inside=(a.Shape=='Line' or a.Shape=='Cone') and a.O+a.D*4 or a.P[1]
   t.expect.truthy(E.inAttack(a,inside))
   t.expect.falsy(E.inAttack(a,a.O+Vector3.new(80,0,0)))
   if a.Shape=='Square' then t.expect.equal(#a.P,3);t.expect.truthy(a.Drop) end
  end
 end)

 t.test('the warehouse fight: the Harbor crew waits in front of the far door and charges as one; the last one down wins it',function()
  local world,arenas=E.world(gates())
  local crew=world[16]
  t.expect.equal(#crew,6);t.expect.equal(crew[1].Kind,'Boss')
  for _,e in crew do t.expect.equal(e.Reserve,nil) end
  t.expect.equal(arenas[16].X,31);t.expect.equal(#arenas[16].Blocks,0)
  local c={t=0};local s=W.session(world,function() return c.t end,arenas);s:move(16)
  local w=s:current()
  local boss=w.Goons[1]
  -- walk up: within Notice of any of them, the whole crew comes, its strongest too
  local spot=crew[5].Home+Vector3.new(0,0,E.Notice-2)
  for _=1,10 do c.t+=0.1;s:tick(0.1,spot) end
  for _,g in w.Goons do t.expect.truthy(g.State~=E.Idle) end
  t.expect.truthy(boss.State~=E.Idle)
  -- its strongest down first: the rest fight on (brief 30: no crew giving up with it)
  local hit,downed,cleared=W.hit(w,1,w.HP[1])
  t.expect.truthy(hit and downed);t.expect.falsy(cleared)
  t.expect.equal(w.Left,5)
  for i=2,6 do
   local _,_,all=W.hit(w,i,w.HP[i])
   t.expect.equal(all,i==6)
  end
  t.expect.equal(w.Left,0);t.expect.truthy(w.Cleared)
 end)

 t.test('the world boss: on the clock, HP from who is there, the Cash split by damage share',function()
  local I=WB.Interval
  t.expect.equal(WB.nextAt(1),I);t.expect.equal(WB.nextAt(I),I);t.expect.equal(WB.nextAt(I+1),2*I)
  t.expect.equal((WB.phase(I-WB.Warn-5)),'Wait');t.expect.equal((WB.phase(I-10)),'Invite')
  local ph,ends=WB.phase(I+5,I);t.expect.equal(ph,'Fight');t.expect.equal(ends,I+WB.FightTime)
  local ph2,at2=WB.phase(I+5,I,true);t.expect.truthy(ph2~='Fight' and at2==2*I)
  t.expect.equal(WB.clock(75),'1:15');t.expect.equal(WB.clock(0),'0:00');t.expect.equal(WB.clock(-3),'0:00')
  t.expect.truthy(WB.Warn>=30 and WB.Interval>=WB.FightTime+WB.Warn)
  t.expect.equal(WB.hpFor({}),WB.MinHp)
  t.expect.equal(WB.hpFor({1000,10}),1010*WB.ShotsEach)
  local hp,max=WB.join(500,600,100);t.expect.equal(hp,500+100*WB.ShotsEach);t.expect.equal(max,600+100*WB.ShotsEach)
  local r,sh=WB.split({a=300,b=100},1000)
  t.expect.equal(r.a,750);t.expect.equal(r.b,250);t.expect.equal(sh.a,0.75)
  local r2=WB.split({big=100000,tiny=1,none=0},1000)
  t.expect.equal(r2.tiny,WB.MinReward);t.expect.equal(r2.none,nil)
  t.expect.equal(next((WB.split({},1000))),nil)
  t.expect.truthy(WB.pool(1)<WB.pool(5) and WB.pool(1000)==WB.Pool.Max)
  local seen={}
  for k=0,#WB.Roster-1 do seen[WB.lookFor(k)]=true;t.expect.truthy(E.Bosses[E.crewOf(WB.lookFor(k))]~=nil) end
  for _,look in WB.Roster do t.expect.truthy(seen[look]);t.expect.falsy(E.bossOf(look).Final) end
  t.expect.equal(WB.titleOf('muscle_boss'),'GIANT THE FOREMAN')
  local a=WB.grow({L=10,R=4,W=2});t.expect.truthy(a.L>10 and a.R>4 and a.W>2)
  -- (brief 30) a giant has its crew's move and three more, each a known move; the timer's short name; a 3-4 minute cadence
  for _,look in WB.Roster do
   local m=WB.movesFor(look);t.expect.truthy(#m>=3)
   for _,name in m do t.expect.truthy(E.Moves[name]~=nil) end
   t.expect.falsy(string.find(WB.shortName(look),'BOSS',1,true))
  end
  t.expect.truthy(WB.Interval>=180 and WB.Interval<=240 and WB.SkipLead>=5)
  t.expect.equal(WB.grow(nil),nil)
 end)
end
