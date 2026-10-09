return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local Shoes=require(RS.Shared.Config.Shoes)
 local R=require(RS.Shared.ShoeRules)
 local ShotRules=require(RS.Shared.ShotRules)
 local G=require(RS.Shared.GoalRules)
 local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
 local RateLimiter=require(game.ServerScriptService.HoodServer.RateLimiter)
 local function rack(owned,equipped) return R.sanitize({Owned=owned or {},Equipped=equipped or {},Opened=0}) end
 -- A deterministic uniform stream for the statistics test (Park-Miller).
 local function lcg(seed) local s=seed return function() s=(s*48271)%2147483647 return s/2147483647 end end

 t.test('ten boxes of six shoes, one per rarity, priced and bonused in order',function()
  t.expect.equal(#Shoes.Boxes,10);t.expect.equal(#Shoes.List,60);t.expect.equal(#Shoes.Rarities,6)
  local ids,weight,chance={},0,0
  for i,r in Shoes.Rarities do t.expect.equal(r.Rank,i);weight+=r.Weight;chance+=r.Chance;if i>1 then t.expect.truthy(r.Chance<Shoes.Rarities[i-1].Chance and r.Power>Shoes.Rarities[i-1].Power) end end
  t.expect.equal(weight,Shoes.TotalWeight);t.expect.near(chance,100,1e-9)
  local want={'Street','Graffiti','Frost','Lava','Toxic','Candy','Ocean','Gem','Galaxy','Gold'}
  for i,box in Shoes.Boxes do
   t.expect.equal(box.Id,want[i]);t.expect.equal(Shoes.BoxById[box.Id],box);t.expect.equal(box.Tier,i);t.expect.equal(#box.Shoes,6)
   if i>1 then local prev=Shoes.Boxes[i-1];t.expect.truthy(box.Price>prev.Price);t.expect.truthy(Shoes.ById[box.Shoes[1]].Bonus>Shoes.ById[prev.Shoes[1]].Bonus) end
   for rank,id in box.Shoes do
    local s=Shoes.ById[id];t.expect.falsy(ids[id]);ids[id]=true
    t.expect.equal(s.Box,box.Id);t.expect.equal(s.Rarity,Shoes.Rarities[rank].Id);t.expect.equal(s.Rank,rank);t.expect.truthy(s.Bonus>=1 and s.Bonus%1==0)
    t.expect.truthy(type(s.Name)=='string' and #s.Name>0 and typeof(s.Colors.Main)=='Color3')
    if rank>1 then t.expect.truthy(s.Bonus>Shoes.ById[box.Shoes[rank-1]].Bonus) end
   end
  end
  t.expect.equal(Shoes.ById.PlusOneInfinity.Name,'+1 Infinity');t.expect.equal(Shoes.ById.TwentyFourKarat.Name,'24 Karat');t.expect.equal(Shoes.ById.KingsCrown.Box,'Gold')
  t.expect.equal(Shoes.bonus('Nope'),0);t.expect.equal(Shoes.bonus(nil),0)
 end)

 t.test('odds: the roll lands on each rarity at its weight boundaries',function()
  local box=Shoes.BoxById.Street
  local cases={{0,1},{0.6199,1},{0.62,2},{0.8699,2},{0.87,3},{0.9649,3},{0.965,4},{0.9949,4},{0.995,5},{0.99949,5},{0.9995,6},{0.99999999,6}}
  for _,c in cases do local id,rarity=R.roll('Street',c[1]);t.expect.equal(id,box.Shoes[c[2]]);t.expect.equal(rarity,Shoes.Rarities[c[2]].Id) end
  t.expect.equal(R.roll('Street',0/0),box.Shoes[1]);t.expect.equal(R.roll('Street',-3),box.Shoes[1]);t.expect.equal(R.roll('Street',7),box.Shoes[6]);t.expect.equal(R.roll('Street','x'),box.Shoes[1])
  t.expect.equal(R.roll('Nope',0.5),nil);t.expect.equal(R.roll(nil,0.5),nil)
  local list=R.chances('Gold');t.expect.equal(#list,6);t.expect.equal(list[1].Id,'GoldRush');t.expect.equal(list[6].Id,'PlusOneInfinity');t.expect.equal(list[6].Chance,0.05)
  t.expect.equal(#R.chances('Nope'),0)
  t.expect.equal(R.chanceText(62),'62%');t.expect.equal(R.chanceText(9.5),'9.5%');t.expect.equal(R.chanceText(3),'3%');t.expect.equal(R.chanceText(0.45),'0.45%');t.expect.equal(R.chanceText(0.05),'0.05%')
 end)

 t.test('odds: 200k rolls come out at the advertised chances',function()
  local n,hits,rnd=200000,{},lcg(12345)
  local rank={};for i,id in Shoes.BoxById.Frost.Shoes do rank[id]=i end
  for _=1,n do local id=R.roll('Frost',rnd());hits[rank[id]]=(hits[rank[id]] or 0)+1 end
  for i,r in Shoes.Rarities do
   local got=(hits[i] or 0)/n*100
   -- within 4 standard deviations of the binomial
   local sd=math.sqrt(r.Chance/100*(1-r.Chance/100)/n)*100
   t.expect.truthy(math.abs(got-r.Chance)<=4*sd+1e-9)
  end
 end)

 t.test('opening needs the box, the distance, the Cash and room in the rack',function()
  local s=rack()
  t.expect.truthy(R.canOpen(s,25,'Street',3))
  t.expect.equal(select(2,R.canOpen(s,24,'Street',3)),'cash')
  t.expect.equal(select(2,R.canOpen(s,0/0,'Street',3)),'cash')
  t.expect.equal(select(2,R.canOpen(s,'25','Street',3)),'cash')
  t.expect.equal(select(2,R.canOpen(s,1e9,'Street',R.Range+0.01)),'far')
  t.expect.equal(select(2,R.canOpen(s,1e9,'Street',0/0)),'far')
  t.expect.equal(select(2,R.canOpen(s,1e9,'Street',nil)),'far')
  t.expect.equal(select(2,R.canOpen(s,1e9,'Nope',1)),'unknown')
  t.expect.equal(select(2,R.canOpen(s,1e9,{},1)),'unknown')
  t.expect.truthy(R.canOpen(s,10000,'Gold',R.Range))
 end)

 t.test('opening adds the pair, counts the box and fills free slots',function()
  local s=rack()
  local id,fresh=R.open(s,'Street',0.1);t.expect.equal(id,'FreshCanvas');t.expect.truthy(fresh)
  t.expect.equal(s.Owned.FreshCanvas,1);t.expect.equal(s.Opened,1);t.expect.deepEqual(s.Equipped,{'FreshCanvas'})
  id,fresh=R.open(s,'Street',0.2);t.expect.equal(id,'FreshCanvas');t.expect.falsy(fresh);t.expect.equal(s.Owned.FreshCanvas,2)
  R.open(s,'Street',0.7);t.expect.equal(#s.Equipped,3)
  R.open(s,'Gold',0.996);t.expect.equal(s.Owned.KingsCrown,1);t.expect.equal(#s.Equipped,3);t.expect.falsy(table.find(s.Equipped,'KingsCrown'))
  t.expect.equal(s.Opened,4);t.expect.equal(R.count(s),4)
  t.expect.equal(R.open(s,'Nope',0.5),nil);t.expect.equal(s.Opened,4)
 end)

 t.test('the rack holds MaxOwned pairs; recycling a spare makes room and pays a tenth back',function()
  t.expect.equal(R.MaxOwned,Shoes.MaxOwned);t.expect.truthy(R.MaxOwned>=50)
  local s=rack({FreshCanvas=R.MaxOwned-1},{'FreshCanvas'})
  t.expect.truthy(R.canOpen(s,25,'Street',1))
  R.open(s,'Street',0.1);t.expect.equal(R.count(s),R.MaxOwned)
  t.expect.equal(select(2,R.canOpen(s,1e9,'Street',1)),'full')
  t.expect.equal(R.refund('FreshCanvas'),2);t.expect.equal(R.refund('GoldRush'),1000);t.expect.equal(R.refund('Nope'),0)
  t.expect.equal(R.recycle(s,'FreshCanvas'),2);t.expect.equal(R.count(s),R.MaxOwned-1);t.expect.truthy(R.canOpen(s,25,'Street',1))
  local one=rack({Ember=1},{'Ember'})
  t.expect.equal(select(2,R.canRecycle(one,'Ember')),'equipped');t.expect.equal(R.recycle(one,'Ember'),0);t.expect.equal(one.Owned.Ember,1)
  t.expect.equal(select(2,R.canRecycle(one,'Phoenix')),'locked');t.expect.equal(select(2,R.canRecycle(one,'Nope')),'unknown')
  local two=rack({Ember=2},{'Ember'});t.expect.equal(R.recycle(two,'Ember'),45);t.expect.equal(two.Owned.Ember,1);t.expect.deepEqual(two.Equipped,{'Ember'})
  local last=rack({Ember=1});t.expect.equal(R.recycle(last,'Ember'),45);t.expect.equal(last.Owned.Ember,nil)
 end)

 t.test('equipping: three pairs at most, only what you own, copies count',function()
  local s=rack({FreshCanvas=2,Ember=1,Phoenix=1})
  t.expect.truthy(R.equip(s,'FreshCanvas'));t.expect.truthy(R.equip(s,'FreshCanvas'))
  t.expect.equal(select(2,R.canEquip(s,'FreshCanvas')),'all')
  t.expect.truthy(R.equip(s,'Ember'))
  t.expect.equal(select(2,R.canEquip(s,'Phoenix')),'full');t.expect.falsy(R.equip(s,'Phoenix'));t.expect.equal(#s.Equipped,3)
  t.expect.equal(select(2,R.canEquip(s,'Glacier')),'locked');t.expect.equal(select(2,R.canEquip(s,'Nope')),'unknown');t.expect.equal(select(2,R.canEquip(s,5)),'unknown')
  t.expect.truthy(R.unequip(s,'FreshCanvas'));t.expect.equal(R.equippedCount(s,'FreshCanvas'),1)
  t.expect.equal(select(2,R.unequip(s,'Phoenix')),'off');t.expect.equal(select(2,R.unequip(s,'Nope')),'unknown')
  t.expect.truthy(R.equip(s,'Phoenix'))
  t.expect.deepEqual(R.equippedList(s),{'Phoenix','Ember','FreshCanvas'});t.expect.equal(R.worn(s),'Phoenix')
  t.expect.equal(R.worn(rack()),nil)
 end)

 t.test('EQUIP BEST picks the three biggest bonuses, copies included',function()
  local s=rack({FreshCanvas=3,Glacier=2,Ember=1,IceCold=1},{'FreshCanvas'})
  t.expect.truthy(R.equipBest(s));t.expect.deepEqual(R.equippedList(s),{'Glacier','Glacier','Ember'})
  t.expect.falsy(R.equipBest(s))
  local small=rack({FreshCanvas=1});R.equipBest(small);t.expect.deepEqual(small.Equipped,{'FreshCanvas'})
  local none=rack();t.expect.falsy(R.equipBest(none));t.expect.equal(#none.Equipped,0)
  -- Equal bonuses: the rarer pair first (Street's Rare and Graffiti's Common are both +6%).
  t.expect.truthy(R.before('Glacier','Flurry'));t.expect.falsy(R.before('Flurry','Glacier'))
  t.expect.equal(Shoes.bonus('RedRocket'),Shoes.bonus('SprayTag'));t.expect.truthy(R.before('RedRocket','SprayTag'));t.expect.falsy(R.before('SprayTag','RedRocket'))
  t.expect.equal(Shoes.bonus('BlockRoyalty'),Shoes.bonus('NightSky'));t.expect.truthy(R.before('BlockRoyalty','NightSky'))
 end)

 t.test('bonus maths: the equipped bonuses add up and multiply a shot',function()
  local s=rack({FreshCanvas=1,Ember=1,Phoenix=1},{'FreshCanvas','Ember','Phoenix'})
  t.expect.equal(R.bonus(s),4+11+130);t.expect.near(R.multiplier(s),2.45);t.expect.equal(R.bonusText(R.bonus(s)),'+145%')
  t.expect.equal(R.bonus(rack()),0);t.expect.equal(R.multiplier(rack()),1)
  -- No shoes: a shot pays what it always did (ShotRules.pay(perShot, gun, shoes): 10 x3 = 30).
  t.expect.equal(ShotRules.pay(10,3),30);t.expect.equal(ShotRules.pay(10,3,1),30);t.expect.equal(ShotRules.pay(10,3,nil,{}),30)
  -- Shoes without a carry: rounded.
  t.expect.equal(ShotRules.pay(10,3,2.45),74);t.expect.equal(ShotRules.pay(1,1,1.04),1);t.expect.equal(ShotRules.pay(1,1,1.5),2)
  -- Bad multipliers count as none; a huge one is capped.
  t.expect.equal(ShotRules.pay(10,3,0/0),30);t.expect.equal(ShotRules.pay(10,3,0.5),30);t.expect.equal(ShotRules.pay(10,3,-2),30);t.expect.equal(ShotRules.pay(10,3,'x'),30)
  t.expect.equal(ShotRules.pay(1,1,1e9),ShotRules.MaxShoeMultiplier)
  -- With a carry the fraction is paid over the next shots: +4% on 1-Power shots pays 1 extra every 25 shots.
  local carry,total={},0
  for _=1,100 do total+=ShotRules.pay(1,1,1.04,carry) end
  t.expect.equal(total,104)
  carry,total={},0
  for _=1,20 do total+=ShotRules.pay(1,2,2.45,carry) end
  t.expect.equal(total,98)
  local bad={Shoes=0/0};t.expect.equal(ShotRules.pay(1,1,1.5,bad),1);t.expect.near(bad.Shoes,0.5)
 end)

 t.test('attributes round trip: the rack and the equipped list as strings',function()
  local s=rack({Phoenix=1,FreshCanvas=2,PlusOneInfinity=1},{'FreshCanvas','Phoenix'})
  t.expect.equal(R.ownedString(s),'FreshCanvas:2,Phoenix:1,PlusOneInfinity:1')
  local back=R.fromAttributes(R.ownedString(s),table.concat(R.equippedList(s),','),3)
  t.expect.deepEqual(back.Owned,s.Owned);t.expect.deepEqual(R.equippedList(back),R.equippedList(s));t.expect.equal(back.Opened,3)
  local junk=R.fromAttributes('Nope:3,Ember:x,Ember:2',',Ghost,Ember,Ember,Ember',nil)
  t.expect.deepEqual(junk.Owned,{Ember=2});t.expect.deepEqual(junk.Equipped,{'Ember','Ember'});t.expect.equal(junk.Opened,0)
  t.expect.deepEqual(R.fromAttributes(nil,nil).Owned,{})
 end)

 t.test('saving: new and old profiles carry a clean Shoes table',function()
  local p=S.new();t.expect.deepEqual(p.Shoes,{Owned={},Equipped={},Opened=0});t.expect.truthy(S.validate(p))
  local old={SchemaVersion=3,Rep=50,Cash=80};S.migrate(old);t.expect.deepEqual(old.Shoes,{Owned={},Equipped={},Opened=0});t.expect.truthy(S.validate(old));t.expect.equal(old.Cash,80)
  local kept=S.new();kept.Shoes={Owned={Ember=2,Phoenix=1},Equipped={'Phoenix','Ember'},Opened=7};S.migrate(kept)
  t.expect.deepEqual(kept.Shoes,{Owned={Ember=2,Phoenix=1},Equipped={'Phoenix','Ember'},Opened=7});t.expect.truthy(S.validate(kept))
  local bad=S.new();bad.Shoes={Owned={Ember=2.5,Ghost=1,Phoenix=-1,Glacier=1e9,[7]=1},Equipped={'Ghost','Glacier','Glacier','Ember','Ember','Ember'},Opened=-4};S.migrate(bad)
  t.expect.deepEqual(bad.Shoes.Owned,{Glacier=R.MaxCopies});t.expect.deepEqual(bad.Shoes.Equipped,{'Glacier','Glacier'});t.expect.equal(bad.Shoes.Opened,0);t.expect.truthy(S.validate(bad))
  local broken=S.new();broken.Shoes='lots';S.migrate(broken);t.expect.deepEqual(broken.Shoes,{Owned={},Equipped={},Opened=0})
  -- Validation fails closed on shoes nobody could own.
  local a=S.new();a.Shoes.Owned.Ghost=1;t.expect.throws(function() S.validate(a) end)
  local b=S.new();b.Shoes.Equipped={'Ember'};t.expect.throws(function() S.validate(b) end)
  local c=S.new();c.Shoes.Owned.Ember=1;c.Shoes.Equipped={'Ember','Ember'};t.expect.throws(function() S.validate(c) end)
  local d=S.new();d.Shoes.Owned.Ember=9;d.Shoes.Equipped={'Ember','Ember','Ember','Ember'};t.expect.throws(function() S.validate(d) end)
  local e=S.new();e.Shoes.Opened=1.5;t.expect.throws(function() S.validate(e) end)
  -- The client snapshot gets a copy.
  local view=S.public(kept);t.expect.equal(view.Shoes.Owned.Ember,2);view.Shoes.Owned.Ember=99;t.expect.equal(kept.Shoes.Owned.Ember,2)
 end)

 t.test('the goal chain: the shoe box goal sits after the gun goal',function()
  t.expect.equal(G.List[4].Id,'Gun');t.expect.equal(G.List[5].Id,'Shoe');t.expect.equal(G.List[5].Need.Boxes,1)
  t.expect.equal(G.line(G.List[5]),'Open a shoe box - the boxes are at the back of the hall')
  t.expect.equal(S.Template.Goals.Chain,G.Chain)
  local st={Power=20,Stages=1,Wave=1,Waves=true,Guns=2,Range=0,Boxes=0,ShoeBoxes=true}
  local goals={Step=4,Synced=true}
  t.expect.equal(G.advance(goals,st).Id,'Gun');t.expect.equal(goals.Step,5)
  t.expect.equal(G.advance(goals,st),nil)
  st.Boxes=1;t.expect.equal(G.advance(goals,st).Id,'Shoe');t.expect.equal(G.List[goals.Step].Id,'Stage3')
  -- A map without shoe boxes skips it quietly.
  local none={Step=5,Synced=true};t.expect.equal(G.advance(none,{Power=20,Stages=1,Waves=true,Guns=2,Range=0}),nil);t.expect.equal(G.List[none.Step].Id,'Stage3')
 end)

 t.test('saved goal steps move with the new goal: nobody skips or repeats one',function()
  local function migrated(step,synced,back)
   local d={SchemaVersion=3,Goals={Step=step,Synced=synced~=false,Back=back}};S.migrate(d);t.expect.truthy(S.validate(d));return d.Goals
  end
  -- Before the gun goal: unchanged, and the shoe goal comes in its turn.
  local g=migrated(4);t.expect.equal(g.Step,4);t.expect.equal(g.Back,nil);t.expect.equal(g.Chain,G.Chain)
  g=migrated(1,false);t.expect.equal(g.Step,1);t.expect.equal(g.Back,nil)
  -- Past it: the shoe goal now, then back to the goal they were on (the same goal by id; a goal brief 17's chain
  -- dropped comes back as the one that took its place, GoalRules.Renamed).
  local old={'FreeRange','Stage1','Wave1','Gun','Stage3','Range2','Stage6','Gun3','Range4','Stage10','Range6','Stage13','Wave15','BossYard','BossWave'}
  for step=5,#old do
   g=migrated(step);t.expect.equal(G.List[g.Step].Id,'Shoe');t.expect.equal(G.List[g.Back].Id,G.Renamed[old[step]] or old[step])
  end
  g=migrated(#old+1);t.expect.equal(g.Step,5);t.expect.equal(g.Back,#G.List+1) -- (all done: the shoe goal, then done again)
  -- Already migrated: nothing moves twice.
  local d={SchemaVersion=3,Goals={Step=5,Synced=true,Back=9,Chain=G.Chain}};S.migrate(d);t.expect.equal(d.Goals.Step,5);t.expect.equal(d.Goals.Back,9)
  -- The detour: done once, paid once, then the old goal again (it is not repeated: it was never done).
  local goals={Step=5,Synced=true,Back=G.ById.Range4.Step}
  local st={Power=600,Stages=6,Wave=6,Waves=true,Guns=3,Range=0,Boxes=0,ShoeBoxes=true}
  t.expect.equal(G.advance(goals,st),nil);t.expect.equal(goals.Step,5)
  st.Boxes=1;t.expect.equal(G.advance(goals,st).Id,'Shoe');t.expect.equal(G.List[goals.Step].Id,'Range4');t.expect.equal(goals.Back,nil)
  t.expect.equal(G.advance(goals,st),nil)
  -- A pre-chain profile catches up to the shoe goal, with the first unmet goal after it kept.
  local pre={Step=1,Synced=false}
  t.expect.equal(G.advance(pre,{Power=9000,Stages=8,Wave=8,Waves=true,Guns=4,Range=0,Boxes=0,ShoeBoxes=true}),nil)
  t.expect.equal(G.List[pre.Step].Id,'Shoe');t.expect.equal(G.List[pre.Back].Id,'Rebirth1') -- (brief 17's chain: a first rebirth is next)
  local done={Step=1,Synced=false};G.advance(done,{Power=9000,Stages=8,Wave=8,Waves=true,Guns=4,Range=0,Boxes=2,ShoeBoxes=true})
  t.expect.equal(G.List[done.Step].Id,'Rebirth1');t.expect.equal(done.Back,nil)
  -- Damaged Back values are dropped.
  t.expect.equal(G.sanitize({Step=5,Synced=true,Back=5}).Back,nil);t.expect.equal(G.sanitize({Step=5,Synced=true,Back=99}).Back,nil);t.expect.equal(G.sanitize({Step=5,Synced=true,Back=6.5}).Back,nil)
  t.expect.equal(G.sanitize({Step=5,Synced=true,Back=8}).Back,8)
 end)

 t.test('rate limits: one open per 1.25 s, a burst of six inventory actions',function()
  local now=0
  local open=RateLimiter.new(R.OpenBurst,R.OpenPerSecond,function() return now end)
  t.expect.truthy(open.allow('p'));t.expect.falsy(open.allow('p'))
  now=1.2;t.expect.falsy(open.allow('p'))
  now=1.26;t.expect.truthy(open.allow('p'));t.expect.falsy(open.allow('p'))
  t.expect.truthy(open.allow('other'))
  local act=RateLimiter.new(R.ActionBurst,R.ActionPerSecond,function() return now end)
  local n=0;for _=1,20 do if act.allow('p') then n+=1 end end;t.expect.equal(n,6)
  now+=0.5;n=0;for _=1,20 do if act.allow('p') then n+=1 end end;t.expect.equal(n,2)
  t.expect.truthy(1/R.OpenPerSecond>=1 and 1/R.OpenPerSecond<=2)
 end)
end
