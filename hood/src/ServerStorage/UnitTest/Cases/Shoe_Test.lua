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

 t.test('ten Cash boxes of six shoes, one per rarity, priced and bonused in order (then the two Robux boxes)',function()
  t.expect.equal(#Shoes.Boxes,12);t.expect.equal(#Shoes.List,70);t.expect.equal(#Shoes.Rarities,6)
  local ids,weight,chance={},0,0
  for i,r in Shoes.Rarities do t.expect.equal(r.Rank,i);weight+=r.Weight;chance+=r.Chance;if i>1 then t.expect.truthy(r.Chance<Shoes.Rarities[i-1].Chance and r.Power>Shoes.Rarities[i-1].Power) end end
  t.expect.equal(weight,Shoes.TotalWeight);t.expect.near(chance,100,1e-9)
  local want={'Street','Graffiti','Frost','Lava','Toxic','Candy','Ocean','Gem','Galaxy','Gold','Exclusive','Grail'}
  for i,box in Shoes.Boxes do
   t.expect.equal(box.Id,want[i]);t.expect.equal(Shoes.BoxById[box.Id],box);t.expect.equal(box.Tier,i)
   if i>10 then
    -- the Robux boxes: no Cash price, a product key and a Robux price, five shoes Rare..Secret
    t.expect.equal(box.Price,nil);t.expect.truthy(type(box.Robux)=='string');t.expect.truthy(box.RobuxPrice>0);t.expect.equal(box.Exclusive,true);t.expect.equal(#box.Shoes,5)
    for j,id in box.Shoes do
     local sh=Shoes.ById[id];t.expect.falsy(ids[id]);ids[id]=true
     t.expect.equal(sh.Box,box.Id);t.expect.equal(sh.Rank,j+1);t.expect.equal(sh.Rarity,Shoes.Rarities[j+1].Id);t.expect.equal(sh.Exclusive,true);t.expect.equal(sh.World,box.World)
     t.expect.truthy(type(sh.Name)=='string' and #sh.Name>0 and typeof(sh.Colors.Main)=='Color3')
     if j>1 then t.expect.truthy(sh.Bonus>Shoes.ById[box.Shoes[j-1]].Bonus) end
    end
    continue
   end
   t.expect.equal(#box.Shoes,6);t.expect.equal(box.Robux,nil);t.expect.equal(box.RobuxPrice,nil);t.expect.equal(box.Exclusive,false)
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
  -- (the Gold box opens in its own world, World 5)
  t.expect.truthy(R.canOpen(s,10000,'Gold',R.Range,5))
 end)

 -- brief 21: each world keeps two Cash boxes; World 1 adds the two Robux boxes.
 t.test('worlds: boxesForWorld(1) is Street, Graffiti, Exclusive, Grail; two Cash boxes for each later world',function()
  local function ids(world) local l={} for _,b in Shoes.boxesForWorld(world) do table.insert(l,b.Id) end return table.concat(l,',') end
  t.expect.equal(Shoes.ActiveWorld,1)
  t.expect.equal(ids(1),'Street,Graffiti,Exclusive,Grail')
  t.expect.equal(ids(2),'Frost,Lava');t.expect.equal(ids(3),'Toxic,Candy');t.expect.equal(ids(4),'Ocean,Gem');t.expect.equal(ids(5),'Galaxy,Gold')
  t.expect.equal(ids(6),'');t.expect.equal(ids(nil),'');t.expect.equal(ids('1'),'')
  -- every box is in exactly one world, and the list is a fresh copy each call
  local seen=0;for w=1,Shoes.Worlds do seen+=#Shoes.boxesForWorld(w) end;t.expect.equal(seen,#Shoes.Boxes)
  local a=Shoes.boxesForWorld(1);table.remove(a,1);t.expect.equal(#Shoes.boxesForWorld(1),4);t.expect.equal(Shoes.BoxById.Street.World,1)
  -- the saves and the art keep every box
  for _,id in {'Frost','Lava','Toxic','Candy','Ocean','Gem','Galaxy','Gold'} do t.expect.truthy(Shoes.BoxById[id] and Shoes.BoxById[id].World>1) end
  t.expect.truthy(S.validate((function() local p=S.new();p.Shoes.Owned.PlusOneInfinity=1;p.Shoes.Owned.TheGrail=1;p.Shoes.Equipped={'TheGrail'};return p end)()))
 end)

 t.test('World 1 refuses the later worlds\' boxes, and never opens a Robux box for Cash',function()
  local s=rack()
  for _,b in Shoes.Boxes do
   local ok,why=R.canOpen(s,1e12,b.Id,1)
   if b.World~=1 then t.expect.falsy(ok);t.expect.equal(why,'world');t.expect.falsy(R.inWorld(b.Id))
   elseif b.Robux then t.expect.falsy(ok);t.expect.equal(why,'robux');t.expect.truthy(R.inWorld(b.Id))
   else t.expect.truthy(ok);t.expect.truthy(R.inWorld(b.Id)) end
  end
  -- not even in its own world, nor with junk Cash
  t.expect.equal(select(2,R.canOpen(s,1e12,'Grail',1,1)),'robux');t.expect.equal(select(2,R.canOpen(s,1e12,'Exclusive',1,5)),'world')
  t.expect.equal(select(2,R.canOpen(s,0/0,'Exclusive',1)),'robux')
  t.expect.falsy(R.inWorld('Nope'));t.expect.falsy(R.inWorld(nil))
 end)

 t.test('Robux boxes: no Commons, odds sum, fair bonuses (Lava..Gem per rarity, under Gold), better than Graffiti',function()
  for _,box in Shoes.Boxes do
   local c,w=0,0
   for i in box.Shoes do c+=box.Chances[i];w+=box.Weights[i];t.expect.truthy(box.Chances[i]>0) end
   t.expect.near(c,100,1e-9);t.expect.equal(w,Shoes.TotalWeight)
  end
  local function at(boxId,rank) for _,id in Shoes.BoxById[boxId].Shoes do if Shoes.ById[id].Rank==rank then return Shoes.ById[id].Bonus end end end
  local function mean(boxId) local b=Shoes.BoxById[boxId];local m=0;for i,id in b.Shoes do m+=b.Chances[i]/100*Shoes.ById[id].Bonus end;return m end
  for rank=2,6 do
   t.expect.truthy(at('Lava',rank)<=at('Exclusive',rank));t.expect.truthy(at('Exclusive',rank)<at('Grail',rank))
   t.expect.truthy(at('Grail',rank)<=at('Gem',rank));t.expect.truthy(at('Grail',rank)<at('Gold',rank))
  end
  for _,id in {'Exclusive','Grail'} do
   for _,sid in Shoes.BoxById[id].Shoes do t.expect.truthy(Shoes.ById[sid].Rank>=2);t.expect.truthy(Shoes.ById[sid].Bonus<Shoes.ById.PlusOneInfinity.Bonus) end
  end
  t.expect.truthy(mean('Exclusive')>mean('Graffiti'));t.expect.truthy(mean('Grail')>mean('Exclusive'));t.expect.truthy(mean('Grail')<mean('Gold'))
  t.expect.truthy(mean('Exclusive')>=mean('Lava'))
  -- the roll and the chances board use the box's own odds
  local ex=Shoes.BoxById.Exclusive
  local cases={{0,1},{0.5999,1},{0.6,2},{0.8799,2},{0.88,3},{0.9699,3},{0.97,4},{0.9949,4},{0.995,5},{0.99999999,5}}
  for _,c in cases do local id,rarity=R.roll('Exclusive',c[1]);t.expect.equal(id,ex.Shoes[c[2]]);t.expect.equal(rarity,Shoes.ById[ex.Shoes[c[2]]].Rarity) end
  local list=R.chances('Grail');t.expect.equal(#list,5);t.expect.equal(list[1].Rarity,'Rare');t.expect.equal(list[5].Id,'TheGrail');t.expect.equal(list[5].Chance,1)
  t.expect.equal(R.chanceOf('SilverStreak'),60);t.expect.equal(R.chanceOf('FreshCanvas'),62);t.expect.equal(R.chanceOf('Nope'),0)
  -- 200k rolls: never a Common, each shoe at its chance
  local n,hits,rnd=200000,{},lcg(777)
  for _=1,n do local id=R.roll('Grail',rnd());hits[id]=(hits[id] or 0)+1 end
  for i,id in Shoes.BoxById.Grail.Shoes do
   local p=Shoes.BoxById.Grail.Chances[i]/100;local got=(hits[id] or 0)/n
   t.expect.truthy(math.abs(got-p)<=4*math.sqrt(p*(1-p)/n)+1e-9)
  end
  for id in hits do t.expect.truthy(Shoes.ById[id].Rarity~='Common') end
  -- a recycled exclusive pair pays a tenth of its box's set value
  t.expect.equal(R.refund('SilverStreak'),100);t.expect.equal(R.refund('TheGrail'),200)
 end)

 t.test('the receipt path: a product key opens its Robux box through ShoeOpening, the same roll and save',function()
  local Products=require(RS.Shared.Config.Products)
  local Opening=require(game.ServerScriptService.HoodServer.ShoeOpening)
  for _,box in Shoes.boxesForWorld(1) do
   if box.Robux then
    -- the product exists (id 0 until the owner makes it: nothing can be bought, the prompt says Coming soon) and
    -- its Store card matches the box
    t.expect.equal(Products.DeveloperProducts[box.Robux],0)
    local entry=Products.ByKey[box.Robux];t.expect.truthy(entry and entry.Kind=='Product' and entry.Section=='Box' and entry.Wired==true)
    t.expect.equal(entry.Price,box.RobuxPrice);t.expect.equal(entry.Art,'box:'..box.Id)
    t.expect.equal(select(2,Products.canBuy(box.Robux)),'noid')
    t.expect.equal(R.canGrant(box.Robux),box);t.expect.equal(Shoes.boxForProduct(box.Robux),box)
   end
  end
  t.expect.equal(R.canGrant('PowerPack1'),nil);t.expect.equal(select(2,R.canGrant('Nope')),'unknown');t.expect.equal(R.canGrant(nil),nil)
  -- a stand-in player (attributes only; not in Players, so no remotes) and a profile
  local attrs={}
  local fake={DisplayName='Tester',Parent=nil}
  function fake:GetAttribute(k) return attrs[k] end
  function fake:SetAttribute(k,v) attrs[k]=v end
  local profile={Data=S.new()}
  profile.Data.Shoes.Owned.FreshCanvas=R.MaxOwned -- (a full rack: a paid box is still given)
  local id,info=Opening.open(fake,profile,R.canGrant('ShoeBoxExclusive').Id,0)
  t.expect.equal(id,'SilverStreak');t.expect.equal(info.Box,'Exclusive');t.expect.equal(info.Rarity,'Rare');t.expect.truthy(info.New);t.expect.truthy(info.Equipped)
  t.expect.equal(profile.Data.Shoes.Owned.SilverStreak,1);t.expect.equal(profile.Data.Shoes.Opened,1);t.expect.equal(R.count(profile.Data.Shoes),R.MaxOwned+1)
  t.expect.truthy(string.find(attrs.ShoesOwned,'SilverStreak:1',1,true)~=nil);t.expect.equal(attrs.ShoeWorn,'SilverStreak');t.expect.equal(attrs.ShoesOpened,1)
  id=Opening.open(fake,profile,R.canGrant('ShoeBoxGrail').Id,0.99999)
  t.expect.equal(id,'TheGrail');t.expect.equal(profile.Data.Shoes.Owned.TheGrail,1);t.expect.equal(attrs.ShoeWorn,'TheGrail')
  t.expect.truthy(S.validate(profile.Data))
  -- the Cash never moves on a receipt
  t.expect.equal(profile.Data.Cash,S.new().Cash)
 end)

 t.test('the Robux boxes and their shoes have models: premium boxes within budget, exclusive shoes within budget',function()
  local BoxModels=require(RS.Shared.Models.BoxModels)
  local ShoeModels=require(RS.Shared.Models.ShoeModels)
  local function parts(m) local n=0 for _,d in m:GetDescendants() do if d:IsA('BasePart') then n+=1 end end return n end
  for _,box in Shoes.Boxes do
   local m=BoxModels.build(box.Id,1)
   t.expect.truthy(m:FindFirstChild('Lid') and m.PrimaryPart);t.expect.truthy(parts(m)<=150)
   m:Destroy()
  end
  t.expect.equal(#ShoeModels.Ids,60);t.expect.equal(#ShoeModels.ExclusiveIds,10);t.expect.equal(#ShoeModels.AllIds,70)
  for _,id in ShoeModels.ExclusiveIds do
   local sh=Shoes.ById[id];t.expect.truthy(sh and sh.Exclusive);t.expect.equal(ShoeModels.Meta[id].Box,sh.Box);t.expect.equal(ShoeModels.Meta[id].Rarity,sh.Rank)
   local m=ShoeModels.shoe(id,'R',1);t.expect.truthy(parts(m)-1<=60);m:Destroy()
   local p=ShoeModels.pair(id,1);t.expect.truthy(parts(p)<=123);p:Destroy()
  end
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
  -- (brief 22: up to R.MaxSlots on, one more than MaxEquipped for the +1 Shoe Slot pass; never more)
  local d=S.new();d.Shoes.Owned.Ember=9;d.Shoes.Equipped={'Ember','Ember','Ember','Ember','Ember'};t.expect.throws(function() S.validate(d) end)
  d.Shoes.Equipped={'Ember','Ember','Ember','Ember'};t.expect.truthy(S.validate(d))
  local e=S.new();e.Shoes.Opened=1.5;t.expect.throws(function() S.validate(e) end)
  -- The client snapshot gets a copy.
  local view=S.public(kept);t.expect.equal(view.Shoes.Owned.Ember,2);view.Shoes.Owned.Ember=99;t.expect.equal(kept.Shoes.Owned.Ember,2)
 end)

 t.test('the goal chain: the shoe box goal sits after the gun goal',function()
  local gun,shoe=G.ById.Gun.Step,G.ById.Shoe.Step
  -- (brief 23: the stage 2 cash-out sits between them, so the kid has the box's Cash when the box goal comes)
  t.expect.equal(shoe,gun+2);t.expect.equal(G.List[gun+1].Id,'CashOut2');t.expect.equal(G.List[shoe].Need.Boxes,1)
  t.expect.equal(G.line(G.List[shoe]),'Open a shoe box - at the back of the hall')
  t.expect.equal(S.Template.Goals.Chain,G.Chain);t.expect.equal(S.migrate(S.new()).Goals.Chain,G.Chain)
  local st={Power=20,Stages=1,Wave=1,CashOuts=1,CashOutStage=2,Waves=true,Guns=2,Range=0,Boxes=0,ShoeBoxes=true}
  local goals={Step=gun,Synced=true}
  t.expect.equal(G.advance(goals,st).Id,'Gun');t.expect.equal(G.advance(goals,st).Id,'CashOut2');t.expect.equal(goals.Step,shoe)
  t.expect.equal(G.advance(goals,st),nil)
  st.Boxes=1;t.expect.equal(G.advance(goals,st).Id,'Shoe');t.expect.equal(G.List[goals.Step].Id,'Stage3')
  -- A map without shoe boxes skips it quietly.
  local none={Step=shoe,Synced=true};t.expect.equal(G.advance(none,{Power=20,Stages=1,Waves=true,Guns=2,Range=0}),nil);t.expect.equal(G.List[none.Step].Id,'Stage3')
 end)

 t.test('saved goal steps move with the new goal: nobody skips or repeats one',function()
  local function migrated(step,synced,back)
   local d={SchemaVersion=3,Goals={Step=step,Synced=synced~=false,Back=back}};S.migrate(d);t.expect.truthy(S.validate(d));return d.Goals
  end
  -- Before the gun goal: unchanged, and the shoe goal comes in its turn.
  local g=migrated(4);t.expect.equal(G.List[g.Step].Id,'Gun');t.expect.equal(g.Back,nil);t.expect.equal(g.Chain,G.Chain)
  g=migrated(1,false);t.expect.equal(g.Step,1);t.expect.equal(g.Back,nil)
  -- Past it: the shoe goal now, then back to the goal they were on (the same goal by id; a goal brief 17's chain
  -- dropped comes back as the one that took its place, GoalRules.Renamed).
  local old={'FreeRange','Stage1','Wave1','Gun','Stage3','Range2','Stage6','Gun3','Range4','Stage10','Range6','Stage13','Wave15','BossYard','BossWave'}
  for step=5,#old do
   g=migrated(step);t.expect.equal(G.List[g.Step].Id,'Shoe');t.expect.equal(G.List[g.Back].Id,G.Renamed[old[step]] or old[step])
  end
  g=migrated(#old+1);t.expect.equal(g.Step,G.ById.Shoe.Step);t.expect.equal(g.Back,#G.List+1) -- (all done: the shoe goal, then done again)
  -- Already migrated: nothing moves twice.
  local d={SchemaVersion=3,Goals={Step=5,Synced=true,Back=9,Chain=G.Chain}};S.migrate(d);t.expect.equal(d.Goals.Step,5);t.expect.equal(d.Goals.Back,9)
  -- The detour: done once, paid once, then the old goal again (it is not repeated: it was never done).
  local goals={Step=G.ById.Shoe.Step,Synced=true,Back=G.ById.Range4.Step}
  local st={Power=600,Stages=6,Wave=6,CashOuts=1,CashOutStage=2,Waves=true,Guns=3,Range=0,Boxes=0,ShoeBoxes=true}
  t.expect.equal(G.advance(goals,st),nil);t.expect.equal(goals.Step,G.ById.Shoe.Step)
  st.Boxes=1;t.expect.equal(G.advance(goals,st).Id,'Shoe');t.expect.equal(G.List[goals.Step].Id,'Range4');t.expect.equal(goals.Back,nil)
  t.expect.equal(G.advance(goals,st),nil)
  -- A pre-chain profile catches up to the shoe goal, with the first unmet goal after it kept.
  local pre={Step=1,Synced=false}
  t.expect.equal(G.advance(pre,{Power=9000,Stages=8,Wave=8,CashOuts=1,CashOutStage=2,Waves=true,Guns=4,Range=0,Boxes=0,ShoeBoxes=true}),nil)
  t.expect.equal(G.List[pre.Step].Id,'Shoe');t.expect.equal(G.List[pre.Back].Id,'Rebirth1') -- (brief 17's chain: a first rebirth is next)
  local done={Step=1,Synced=false};G.advance(done,{Power=9000,Stages=8,Wave=8,CashOuts=1,CashOutStage=2,Waves=true,Guns=4,Range=0,Boxes=2,ShoeBoxes=true})
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
