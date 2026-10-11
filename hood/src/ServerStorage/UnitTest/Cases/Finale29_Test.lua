-- (brief 29, P3b) World 1's final boss in its warehouse (three phases, five moves, each with a RED telegraph of at least
-- a second; its crew behind the dock's doors till it calls them; its fall ends the fight) and the World Boss (the clock,
-- its HP from who is there, the Cash split by damage share).
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local E=require(RS.Shared.EnemyRules)
 local W=require(RS.Shared.WaveRules)
 local WB=require(RS.Shared.WorldBossRules)
 local Balance=require(RS.Shared.Config.Balance)
 local function gates() local g={} for i=1,16 do table.insert(g,{Stage=i,WallId='HoodW1Stage'..i,Required=Balance.StagePower[i],Z=-(i-1)*64,HalfWidth=36}) end return g end

 t.test('the final boss: three phases, five moves, each telegraphed in red for at least a second',function()
  local b=E.Bosses.harbor
  t.expect.truthy(b.Final and b.Perch and b.Entrance>=1)
  t.expect.equal(E.phaseFor('harbor_boss',1),1);t.expect.equal(E.phaseFor('harbor_boss',0.6),2);t.expect.equal(E.phaseFor('harbor_boss',0.3),3)
  t.expect.equal(E.phaseFor('bullies_boss',0.6),1);t.expect.equal(E.phaseFor('bullies_boss',0.4),2) -- (a crew boss: angry at half)
  local all={}
  for ph,want in {2,4,5} do
   local moves=E.movesOf({Kind='Boss',Look='harbor_boss',Phase=ph})
   t.expect.equal(#moves,want)
   for _,m in moves do all[m]=true end
   t.expect.truthy(E.teleTime(ph)>=1.0)
   if ph>1 then t.expect.truthy(E.teleTime(ph)<=E.teleTime(ph-1) and E.bossRest(ph)<E.bossRest(ph-1)) end
  end
  for _,m in {'Forklift','Anchor','Containers','Shockwave','Crew'} do t.expect.truthy(all[m]) end
  -- every move but the crew call: where it shows is a hit, outside it a miss (the shockwave spares you right by it)
  local g={Kind='Boss',Look='harbor_boss',Pos=Vector3.new(0,0,-1030),Phase=3}
  local you=Vector3.new(4,0,-1020)
  for n,name in E.movesOf(g) do
   if name~='Crew' then
    g.MoveN=n-1
    local a=E.planAttack(g,you,nil,{})
    t.expect.truthy(a~=nil and a.Move==name)
    t.expect.truthy(a.Tele>=1.0 and a.Damage>0 and a.Damage<=E.MaxPunch)
    local inside=(a.Shape=='Line' or a.Shape=='Cone') and a.O+a.D*4 or a.Shape=='Ring' and a.P[1]+Vector3.new((a.Ri+a.R)/2,0,0) or a.P[1]
    t.expect.truthy(E.inAttack(a,inside))
    t.expect.falsy(E.inAttack(a,a.O+Vector3.new(80,0,0)))
    if a.Shape=='Ring' then t.expect.falsy(E.inAttack(a,a.P[1]+Vector3.new(1,0,0))) end
    if a.Shape=='Square' then t.expect.equal(#a.P,3);t.expect.truthy(a.Drop) end
   end
  end
  -- the crew call: only with someone waiting at the dock; it hurts nobody, it brings them out
  local idx=table.find(E.movesOf(g),'Crew')
  g.MoveN=idx-1
  local waiting={Kind='Goon',Reserve=1,State=E.Idle,Home=Vector3.new(-24,0,-1052)}
  local a=E.planAttack(g,you,nil,{g,waiting})
  t.expect.truthy(a~=nil and a.Move=='Crew' and a.Calls and #a.P==1)
  t.expect.falsy(E.inAttack(a,a.P[1]))
  g.MoveN=idx-1
  local other=E.planAttack(g,you,nil,{g})
  t.expect.truthy(other==nil or other.Move~='Crew')
 end)

 t.test('the warehouse fight: the crew waits at the dock till the boss calls, it drops in, and its fall ends the fight',function()
  local world,arenas=E.world(gates())
  local crew=world[16]
  t.expect.equal(#crew,6);t.expect.equal(crew[1].Kind,'Boss')
  t.expect.equal(crew[4].Reserve,1);t.expect.equal(crew[5].Reserve,2);t.expect.equal(crew[6].Reserve,3)
  t.expect.equal(arenas[16].X,31);t.expect.equal(#arenas[16].Blocks,0)
  local c={t=0};local s=W.session(world,function() return c.t end,arenas);s:move(16)
  local w=s:current()
  local boss,res=w.Goons[1],w.Goons[4]
  t.expect.equal(res.Reserve,1)
  -- standing right by a reserve goon's door: it doesn't notice; the boss does, and makes its entrance
  for _=1,10 do c.t+=0.1;s:tick(0.1,res.Home+Vector3.new(0,0,3)) end
  t.expect.equal(res.State,E.Idle)
  t.expect.equal(boss.State,E.Alert) -- (it saw you from its catwalk)
  local fresh=E.new('Boss',Vector3.zero,0,'harbor_boss');E.alert(fresh,0)
  t.expect.truthy(math.abs(fresh.T-E.Bosses.harbor.Entrance)<1e-6) -- (its entrance: the drop off the catwalk)
  -- phase 3 at a third of its HP; its crew call brings the dock out
  t.expect.truthy(W.hit(w,1,math.floor(w.Max[1]*0.7)))
  boss.Phase=E.phaseFor(boss.Look,w.HP[1]/w.Max[1]);t.expect.equal(boss.Phase,3)
  boss.State,boss.CD=E.Chase,0
  boss.MoveN=table.find(E.movesOf(boss),'Crew')-1
  local called=false
  local spot=boss.Pos+Vector3.new(0,0,14)
  for _=1,60 do
   c.t+=0.1
   for _,ev in s:tick(0.1,spot) do
    if ev.Kind=='tele' then t.expect.truthy(ev.Attack.Tele>=1.0) end
    if ev.Kind=='blast' and ev.Attack and ev.Attack.Calls then called=true end
   end
   if called then break end
  end
  t.expect.truthy(called)
  t.expect.truthy(res.State~=E.Idle)
  -- the boss down: its crew gives up and the wave is won
  local hit,downed,cleared=W.hit(w,1,w.HP[1])
  t.expect.truthy(hit and downed and cleared)
  t.expect.equal(w.Left,0)
  for i,o in w.Goons do t.expect.equal(o.State,E.Down);t.expect.equal(w.HP[i],0) end
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
  t.expect.equal(WB.grow(nil),nil)
 end)
end
