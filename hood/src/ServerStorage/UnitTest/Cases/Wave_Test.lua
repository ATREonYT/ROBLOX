-- Stage goons (brief 18): Shared/EnemyRules (who, how tough, how they chase and punch) and Shared/WaveRules (each
-- player's waves, shots, clears, the gate rule).
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local W=require(RS.Shared.WaveRules)
 local E=require(RS.Shared.EnemyRules)
 local StageRules=require(RS.Shared.StageRules)
 local ShotRules=require(RS.Shared.ShotRules)
 local Balance=require(RS.Shared.Config.Balance)
 -- Gates like the hood map's: stage i's line at z = -(i-1)*64, 16 of them (16 opens the boss yard).
 local function gates() local g={} for i=1,16 do table.insert(g,{Stage=i,WallId='HoodW1Stage'..i,Required=Balance.StagePower[i],Z=-(i-1)*64,HalfWidth=36}) end return g end
 local function clock() local c={t=0} return c,function() return c.t end end
 local function session() local c,now=clock();local world,arenas=E.world(gates());return W.session(world,now,arenas),c,world,arenas end
 local function flat(v) return Vector3.new(v.X,0,v.Z) end

 t.test('damage per shot is your Power; goon HP is shots x the stage Recommended Power, so it grows every stage',function()
  t.expect.equal(E.damage(0),1);t.expect.equal(E.damage(37.9),37);t.expect.equal(E.damage(-5),1);t.expect.equal(E.damage(0/0),1);t.expect.equal(E.damage('x'),1);t.expect.equal(E.damage(1e9),1e9)
  t.expect.equal(E.recommended(1),Balance.StagePower[1]);t.expect.equal(E.recommended(99),Balance.StagePower[16]);t.expect.equal(E.recommended(nil),Balance.StagePower[1])
  -- Stage 1's goons read like the video's guards ("Guard 1 40/40"): a few shots at the gate's Power.
  t.expect.equal(E.maxHp(1,'Goon'),E.HpShots*Balance.StagePower[1])
  t.expect.equal(math.ceil(E.maxHp(1,'Goon')/E.damage(Balance.StagePower[1])),E.HpShots)
  for s=2,16 do
   t.expect.truthy(E.maxHp(s,'Goon')>E.maxHp(s-1,'Goon'))
   -- at the stage's Recommended Power a plain goon falls in about HpShots shots (rounding aside), a Runner sooner, a Bruiser later
   local shots=E.maxHp(s,'Goon')/E.damage(E.recommended(s))
   t.expect.truthy(shots>E.HpShots*0.9 and shots<E.HpShots*1.1)
   t.expect.truthy(E.maxHp(s,'Runner')<E.maxHp(s,'Goon') and E.maxHp(s,'Bruiser')>E.maxHp(s,'Goon') and E.maxHp(s,'Boss')>E.maxHp(s,'Bruiser'))
  end
  t.expect.equal(E.maxHp(3,'Nope'),E.maxHp(3,'Goon'))
 end)

 t.test('every stage has a small crew on its own spots in front of the next gate; the boss waits in the boss yard',function()
  t.expect.equal(#E.Lineups,16);t.expect.equal(#E.Spots,16);t.expect.equal(#E.Crews,16)
  for s=1,16 do
   local l=E.Lineups[s]
   t.expect.truthy(#l>=3 and #l<=5) -- (the video: three a stage; a few more later on, never a crowd)
   t.expect.equal(#E.Spots[s],#l)
   for _,k in l do t.expect.truthy(E.Kinds[k]~=nil) end
   for i,spot in E.Spots[s] do
    t.expect.truthy(math.abs(spot[1])<=34)
    if s<16 then t.expect.truthy(spot[2]>=34 and spot[2]<=56) end -- (far side of the street: they see you come in)
    for j=i+1,#E.Spots[s] do local o=E.Spots[s][j];t.expect.truthy((Vector3.new(spot[1],0,spot[2])-Vector3.new(o[1],0,o[2])).Magnitude>=4) end
   end
  end
  t.expect.equal(E.Lineups[16][1],'Boss');for s=1,15 do t.expect.falsy(table.find(E.Lineups[s],'Boss')) end
  t.expect.truthy(#E.Lineups[1]==3 and #E.Lineups[16]>=#E.Lineups[15])
  -- The map's gates give every stage its crew, homes inside the stage, and an arena between its two gates.
  local world,arenas=E.world(gates())
  for s=1,16 do
   t.expect.equal(#world[s],#E.Lineups[s])
   local a=arenas[s];t.expect.truthy(a.Z0<-(s-1)*64 and a.Z1<a.Z0)
   for _,e in world[s] do t.expect.truthy(e.Home.Z<=a.Z0 and e.Home.Z>=a.Z1 and math.abs(e.Home.X)<=a.X);t.expect.truthy(W.stageAt(gates(),Vector3.new(e.Home.X,3,e.Home.Z))==s) end
  end
  t.expect.equal(world[1][1].Name,'Goon 1');t.expect.equal(world[16][1].Name,'BOSS');t.expect.equal(E.tagName(7,'Runner'),'Runner 7')
  t.expect.equal(#arenas[16].Blocks,1) -- (the Champ Ring: goons walk round it)
 end)

 t.test('goons notice you, call their crew, run at you, wind up and punch; a punch out of reach misses',function()
  local s,c,world=session();s:move(1)
  local w=s:current();local g=w.Goons[1]
  t.expect.equal(g.State,E.Idle)
  -- far away: nothing happens, nobody moves
  local you=Vector3.new(0,0,-1)
  local ev,moved=s:tick(0.1,Vector3.new(0,0,30));t.expect.equal(#ev,0);t.expect.equal(next(moved),nil)
  -- walk in (a few steps past the gate): the nearest one notices and the whole crew comes, staggered
  you=Vector3.new(0,0,-12)
  local notices=0
  for _=1,10 do c.t+=0.1;ev=s:tick(0.1,you);for _,e in ev do if e.Kind=='notice' then notices+=1 end end end
  t.expect.equal(notices,3)
  for _,x in w.Goons do t.expect.truthy(x.State==E.Alert or x.State==E.Chase) end
  -- they close in on you and punch; you take punches only when in reach
  local punches,landed,minD=0,0,math.huge
  for _=1,60 do c.t+=0.1;for _,e in s:tick(0.1,you) do if e.Kind=='punch' then punches+=1;if e.Landed then landed+=1;t.expect.equal(e.Damage,E.punch('Goon')) end end end
   for _,x in w.Goons do minD=math.min(minD,(flat(x.Pos)-you).Magnitude) end
  end
  t.expect.truthy(punches>=3 and landed>=3)
  t.expect.truthy(minD>=E.Kinds.Goon.Reach*0.4) -- (they stop in front of you, not inside you)
  -- spread round you, not stacked
  for i=1,3 do for j=i+1,3 do t.expect.truthy((flat(w.Goons[i].Pos)-flat(w.Goons[j].Pos)).Magnitude>1.2) end end
  -- wind-up, then you step away: it misses
  local k=E.new('Goon',Vector3.new(0,0,-40));k.State=E.Windup;k.T=0.05
  local evk,hit=E.step(k,0.1,Vector3.new(0,0,-40-E.Kinds.Goon.Reach-3),0,nil,nil,{k});t.expect.equal(evk,'punch');t.expect.falsy(hit)
  k.State=E.Windup;k.T=0.05;evk,hit=E.step(k,0.1,Vector3.new(0,0,-42),0,nil,nil,{k});t.expect.equal(evk,'punch');t.expect.truthy(hit)
 end)

 t.test('goons stay in their stage, walk round the ring, go home when you leave, and are calm after your KO',function()
  local s,c,world,arenas=session();s:move(2)
  local w=s:current()
  -- you walk in, then run back toward the lobby: they never pass the gate line
  for _=1,20 do c.t+=0.1;s:tick(0.1,Vector3.new(0,0,-64-14)) end
  local you=Vector3.new(0,0,-64-2)
  for _=1,80 do c.t+=0.1;s:tick(0.1,you) end
  for _,g in w.Goons do t.expect.truthy(g.Pos.Z<=arenas[2].Z0+1e-6 and g.Pos.Z>=arenas[2].Z1) end
  -- you leave the stage: they walk home and stand there
  s:move(nil);t.expect.equal(s.Stage,0)
  local homes=0
  for _=1,200 do c.t+=0.1;for _,e in s:tick(0.1,nil) do if e.Kind=='home' then homes+=1 end end end
  t.expect.equal(homes,3)
  for i,g in w.Goons do t.expect.equal(g.State,E.Idle);t.expect.equal(g.Pos,world[2][i].Home) end
  -- a KO: everyone goes home and ignores you for a while, even standing among them
  s:move(2)
  for _=1,30 do c.t+=0.1;s:tick(0.1,Vector3.new(0,0,-64-30)) end
  s:knockout()
  for _,g in w.Goons do t.expect.truthy(g.State==E.Return or g.State==E.Idle) end
  local fought=false
  for _=1,math.floor(E.Calm*10)-2 do c.t+=0.1;for _,e in s:tick(0.1,Vector3.new(0,0,-64-30)) do if e.Kind=='punch' or e.Kind=='notice' then fought=true end end end
  t.expect.falsy(fought)
  -- the boss yard: a step into the Champ Ring's box slides along its side
  local a=arenas[16];local b=a.Blocks[1]
  local p=E.clamp(Vector3.new(0,0,(b[2]+b[4])/2),a);t.expect.truthy(p.X<=b[1] or p.X>=b[3] or p.Z<=b[2] or p.Z>=b[4])
  local g=E.new('Goon',Vector3.new(0,0,b[4]+3));g.State=E.Chase
  for _=1,120 do E.step(g,0.1,Vector3.new(0,0,b[2]-6),0,nil,a,{g});t.expect.falsy(g.Pos.X>b[1] and g.Pos.X<b[3] and g.Pos.Z>b[2] and g.Pos.Z<b[4]) end
  t.expect.truthy((g.Pos-Vector3.new(0,0,b[2]-6)).Magnitude<8) -- (and gets round it to you)
 end)

 t.test('a hit deals its damage; the last goon down clears the wave; a downed goon takes nothing',function()
  local w=W.spawn(1,{'Goon','Runner'})
  t.expect.equal(w.Left,2);t.expect.equal(w.HP[1],E.maxHp(1,'Goon'));t.expect.equal(#w.Goons,2)
  local hit,down,clear=W.hit(w,1,4);t.expect.truthy(hit);t.expect.falsy(down);t.expect.equal(w.HP[1],E.maxHp(1,'Goon')-4)
  hit,down,clear=W.hit(w,1,1e6);t.expect.truthy(down);t.expect.falsy(clear);t.expect.equal(w.HP[1],0);t.expect.equal(w.Left,1);t.expect.equal(w.Goons[1].State,E.Down)
  hit=W.hit(w,1,5);t.expect.falsy(hit)
  hit,down,clear=W.hit(w,2,1e6);t.expect.truthy(clear);t.expect.truthy(w.Cleared);t.expect.equal(w.Left,0)
  t.expect.falsy((W.hit(w,2,1)));t.expect.falsy((W.hit(w,3,1)))
  -- a downed goon never moves or punches again
  local g=w.Goons[1];local ev=E.step(g,0.1,Vector3.new(),0,nil,nil,w.Goons);t.expect.equal(ev,nil);t.expect.equal(g.State,E.Down)
 end)

 t.test('your wave spawns when you walk in, keeps its HP while you step out, respawns a while after a clear',function()
  local s,c=session()
  t.expect.truthy(s:move(1)~=nil);t.expect.equal(s.Stage,1)
  local w=s:current();local g=w.Goons[1]
  t.expect.truthy((s:shoot(1,1,g.Pos,4)))
  t.expect.equal(s:move(nil),nil);t.expect.equal(s.Stage,0)
  t.expect.equal(s:move(1),nil);t.expect.equal(s:current().HP[1],E.maxHp(1,'Goon')-4) -- (kept: not cleared yet)
  for i=1,3 do c.t+=1;s:shoot(1,i,s:current().Goons[i].Pos,1e6) end
  t.expect.truthy(s:current().Cleared)
  t.expect.equal(s:move(1),nil) -- (still here: stays cleared)
  s:move(2);t.expect.equal(s:move(1),nil) -- (back too soon: it comes back RespawnDelay seconds after the clear)
  c.t+=W.RespawnDelay;s:move(2);t.expect.truthy(s:move(1)~=nil);t.expect.equal(s:current().HP[1],E.maxHp(1,'Goon'));t.expect.equal(s:current().Left,3)
  t.expect.equal(s:move(99),nil);t.expect.equal(s.Stage,0) -- (a stage with no goons is no wave)
 end)

 t.test('a shot wakes its goon and the crew; shots at another stage, out of reach, at a missing goon or with junk are refused',function()
  local s,c=session();s:move(1)
  local w=s:current();local g=w.Goons[1]
  local near=g.Pos+Vector3.new(0,0,10)
  local ok=s:shoot(1,1,near,1);t.expect.truthy(ok);t.expect.equal(g.State,E.Alert)
  for i=2,3 do t.expect.equal(w.Goons[i].State,E.Alert) end
  local function why(...) c.t+=1 local okk,r=s:shoot(...) return okk and 'ok' or r end
  t.expect.equal(why(2,1,near,1),'stage')
  t.expect.equal(why(1,1,g.Pos+Vector3.new(0,0,W.Range+E.Slack+2),1),'range')
  t.expect.equal(why(1,1,g.Pos+Vector3.new(0,0,W.Range+E.Slack-2),1),'ok') -- (the server allows a little lag)
  t.expect.equal(why(1,9,near,1),'target')
  t.expect.equal(why('1',1,near,1),'bad');t.expect.equal(why(1,1.5,near,1),'bad');t.expect.equal(why(1,0/0,near,1),'bad');t.expect.equal(why(0,1,near,1),'bad');t.expect.equal(why(1,999,near,1),'bad')
  t.expect.equal(why(1,1,near,1e9),'ok');t.expect.equal(why(1,1,near,1),'down')
 end)

 t.test('shots at goons are rate limited: a burst, then the refill rate; the client fires a little under it',function()
  local c,now=clock()
  local world={[1]={{Kind='Boss',Home=Vector3.new(0,0,-20)}}}
  local s=W.session(world,now);s:move(1)
  local n=0
  for _=1,30 do if s:shoot(1,1,Vector3.new(0,0,-10),1) then n+=1 end end
  t.expect.equal(n,ShotRules.Burst)
  c.t+=1;n=0
  for _=1,30 do if s:shoot(1,1,Vector3.new(0,0,-10),1) then n+=1 end end
  t.expect.equal(n,ShotRules.PerSecond)
  t.expect.truthy(1/ShotRules.Cooldown<=ShotRules.PerSecond)
 end)

 t.test('the moves message packs every goon in order; aim assist picks the nearest in reach and sticks to it',function()
  local w=W.spawn(1,{{Kind='Goon',Home=Vector3.new(1.234,0,-5.678)},{Kind='Runner',Home=Vector3.new(-3,0,-7)}})
  w.Goons[2].State=E.Chase
  local d=W.pack(w);t.expect.equal(#d,6);t.expect.equal(d[1],1.23);t.expect.equal(d[2],-5.68);t.expect.equal(d[3],E.Idle);t.expect.equal(d[6],E.Chase)
  local list={a={Pos=Vector3.new(10,0,-10),Up=true},b={Pos=Vector3.new(-2,0,-12),Up=true},c={Pos=Vector3.new(0,0,-3),Up=false},far={Pos=Vector3.new(0,0,-500),Up=true}}
  local from,look=Vector3.new(0,0,0),Vector3.new(0,0,-1)
  t.expect.equal(W.pick(list,from,look,nil),'b')
  t.expect.equal(W.pick(list,from,look,'a'),'a')
  list.a.Up=false;t.expect.equal(W.pick(list,from,look,'a'),'b')
  -- a goon behind you counts a little further than one in front
  local two={front={Pos=Vector3.new(0,0,-11),Up=true},back={Pos=Vector3.new(0,0,9),Up=true}};t.expect.equal(W.pick(two,from,look,nil),'front')
  list.b.Up=false;t.expect.equal(W.pick(list,from,look,nil),nil)
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
  local n,b=StageRules.check(g,Vector3.new(0,3,-520),1e9,{},0);t.expect.equal(#n,1);t.expect.equal(b.Stage,9)
  n=StageRules.check(g,Vector3.new(0,3,-520),1e9,{},3);t.expect.equal(#n,4)
  n,b=StageRules.check(g,Vector3.new(0,3,-520),1e9,{},16);t.expect.equal(#n,9);t.expect.equal(b,nil)
  n,b=StageRules.check(g,Vector3.new(0,3,-520),1e9,{},nil);t.expect.equal(#n,9);t.expect.equal(b,nil)
  -- Just past gate 2: held back until stage 1's goons are down.
  n,b=StageRules.check(g,Vector3.new(0,3,-70),1e9,{HoodW1Stage1=true},0);t.expect.equal(#n,0);t.expect.equal(b.Stage,2)
  n,b=StageRules.check(g,Vector3.new(0,3,-70),1e9,{HoodW1Stage1=true},1);t.expect.equal(#n,1);t.expect.equal(b,nil)
  t.expect.truthy(W.gateOpen(1,0));t.expect.falsy(W.gateOpen(2,0));t.expect.truthy(W.gateOpen(2,1));t.expect.truthy(W.gateOpen(9,nil))
 end)

 t.test('stages with no goons never hold a gate; the first clear pays Cash, a re-clear a little',function()
  t.expect.equal(W.effective(0,{[1]=true,[2]=true},16),0);t.expect.equal(W.effective(1,{[1]=true,[3]=true},16),2)
  t.expect.equal(W.effective(0,{},16),16);t.expect.equal(W.effective('x',{[1]=true},16),0)
  t.expect.equal(W.reward(1),Balance.WaveCash[1]);t.expect.equal(W.reward(16),Balance.WaveCash[16]);t.expect.equal(W.reward(0/0),5);t.expect.equal(W.reward(99),5)
  t.expect.equal(W.repeatReward(1),1);t.expect.equal(W.repeatReward(10),math.floor(Balance.StageCash[10]*0.05));t.expect.equal(W.repeatReward(16),700);t.expect.equal(W.repeatReward(nil),1)
  for i=2,16 do t.expect.truthy(W.repeatReward(i)>=W.repeatReward(i-1) and W.repeatReward(i)<W.reward(i)) end
  -- staying in a cleared stage: it comes back RespawnDelay after the clear
  local c,now=clock()
  local s=W.session({[1]={{Kind='Runner',Home=Vector3.new(0,0,-20)}}},now);s:move(1)
  local _,_,_,_,cleared=s:shoot(1,1,Vector3.new(0,0,-10),1e9);t.expect.truthy(cleared)
  c.t+=W.RespawnDelay-1;t.expect.equal(s:revive(),nil)
  c.t+=1;local w=s:revive();t.expect.truthy(w~=nil);t.expect.equal(w.Left,1);t.expect.equal(s:current(),w);t.expect.equal(s:revive(),nil)
  s:move(nil);t.expect.equal(s:revive(),nil)
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

 t.test('a fight at the gate Power is short and easily won; well under it, the goons win (go train)',function()
  -- A player who walks in and holds the trigger at the client rate, on the real rules.
  local function fight(stage,power)
   local s,c,_,arenas=session();s:move(stage)
   local w=s:current();local top=-(stage-1)*64;local you=Vector3.new(0,0,top-3)
   local hp,kos,shotAt=100,0,0
   while c.t<120 and not w.Cleared do
    c.t+=E.Tick
    local best,bd=nil,math.huge
    for i,g in w.Goons do if g.State~=E.Down then local d=(g.Pos-you).Magnitude;if d<bd then best,bd=i,d end end end
    if bd>E.FightRange-4 then you+=Vector3.new(0,0,-16*E.Tick) end
    you=E.clamp(you,arenas[stage])
    if best and bd<=E.FightRange and c.t>=shotAt then shotAt=c.t+ShotRules.Cooldown;s:shoot(stage,best,you,E.damage(power)) end
    for _,e in s:tick(E.Tick,you) do if e.Kind=='punch' and e.Landed then if hp-e.Damage<=0 then kos+=1;hp=100;s:knockout();you=Vector3.new(0,0,top-4) else hp-=e.Damage end end end
   end
   return c.t,hp,kos,w.Cleared
  end
  for _,stage in {1,4,9,15} do
   local time,hp,kos,cleared=fight(stage,E.recommended(stage))
   t.expect.truthy(cleared and time<15 and kos==0 and hp>=20)
   local time2,hp2,kos2=fight(stage,E.recommended(stage)*3)
   t.expect.truthy(time2<time and kos2==0 and hp2>=hp)
  end
  local _,_,kos=fight(10,E.recommended(10)*0.2);t.expect.truthy(kos>=1)
 end)
end
