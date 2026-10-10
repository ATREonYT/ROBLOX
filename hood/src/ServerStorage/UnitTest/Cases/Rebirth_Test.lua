return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local R=require(RS.Shared.RebirthRules)
 local Balance=require(RS.Shared.Config.Balance)
 local Skins=require(RS.Shared.Config.Skins)
 local Schema=require(game.ServerScriptService.HoodServer.ProfileSchema)
 -- Brief 17: "Rebirth n -> n+1, Nx -> (N+1)x", a requirement that grows every time, the first one a few minutes of
 -- shooting at BAY 1. Brief 23: steeper (x2.1 a rebirth) for the steeper lane ladder: 2K, 8.5K, 26K ... 85M at 11.
 t.test('the rebirth multiplier is 1x, 2x, 3x ... and the labels read like the reference',function()
  t.expect.equal(R.multiplier(0),1);t.expect.equal(R.multiplier(1),2);t.expect.equal(R.multiplier(8),9)
  local a,b=R.labels(8);t.expect.equal(a,'Rebirth 8 → Rebirth 9');t.expect.equal(b,'9x → 10x')
  t.expect.equal(R.multiplier(-3),1);t.expect.equal(R.multiplier(0/0),1);t.expect.equal(R.multiplier('7'),1);t.expect.equal(R.multiplier(2.7),3)
 end)
 t.test('each rebirth needs more Power than the last, in round numbers',function()
  t.expect.equal(R.need(0),2000);t.expect.equal(R.need(1),8500);t.expect.equal(R.need(2),26000);t.expect.equal(R.need(4),190000);t.expect.equal(R.need(11),85000000)
  local last=0
  for n=0,30 do
   local v=R.need(n);t.expect.truthy(v>last);last=v
   local digits=string.format('%d',v):gsub('0+$','') -- (two significant figures)
   t.expect.truthy(#digits<=2)
  end
  t.expect.truthy(R.need(25)>Balance.MaxSafeValue/10) -- (the 1e12 Power cap ends the ladder long before MaxRebirths)
 end)
 t.test('you can rebirth at the need, not a point before; junk never rebirths',function()
  t.expect.falsy(R.canRebirth(1999,0));t.expect.truthy(R.canRebirth(2000,0));t.expect.falsy(R.canRebirth(8499,1));t.expect.truthy(R.canRebirth(8500,1))
  t.expect.falsy(R.canRebirth(0/0,0));t.expect.falsy(R.canRebirth(nil,0));t.expect.falsy(R.canRebirth('1e9',0))
  t.expect.falsy(R.canRebirth(1e300,R.Max))
  t.expect.near(R.progress(1000,0),0.5);t.expect.equal(R.progress(1e9,0),1);t.expect.equal(R.progress(-5,0),0)
 end)
 t.test('a rebirth resets Power only: Cash, guns, shoes, stage clears, waves and goals stay',function()
  local d=Schema.new()
  d.Rep=3000;d.Cash=777;d.Guns.Owned.Uzi=true;d.Guns.Equipped='Uzi';d.Shoes.Owned.FreshCanvas=2;d.Shoes.Equipped={'FreshCanvas'};d.Shoes.Opened=2
  d.ClearedWalls.HoodW1Stage1=true;d.ClearedWalls.HoodW1Stage2=true;d.Waves.Cleared=2;d.Goals.Step=6
  local ok=R.apply(d);t.expect.truthy(ok)
  t.expect.equal(d.Rep,0);t.expect.equal(d.Rebirths,1);t.expect.equal(d.Cash,777);t.expect.equal(d.Guns.Equipped,'Uzi');t.expect.truthy(d.Guns.Owned.Uzi)
  t.expect.equal(d.Shoes.Owned.FreshCanvas,2);t.expect.equal(d.Shoes.Equipped[1],'FreshCanvas');t.expect.truthy(d.ClearedWalls.HoodW1Stage2)
  t.expect.equal(d.Waves.Cleared,2);t.expect.equal(d.Goals.Step,6)
  t.expect.truthy(Schema.validate(d))
  -- Not enough Power: nothing changes. A paid skip needs no Power.
  local ok2,why=R.apply(d);t.expect.falsy(ok2);t.expect.equal(why,'power');t.expect.equal(d.Rebirths,1)
  t.expect.truthy((R.apply(d,true)));t.expect.equal(d.Rebirths,2);t.expect.equal(d.Rep,0)
 end)
 -- Brief 23: the superhero game's ladder. Six rebirth lanes x1/0, x4/2, x10/4, x20/6, x35/8, x50/10, the Champ Ring
 -- (boss yard) x75/12, and the two best lanes for Robux: PRO BAY x100 (RangeVIP1, 99) and GOLD BAY x250 (RangeVIP2, 249).
 t.test('the lane ladder: rebirth lanes 0..10 and the Champ Ring at 12, then the two Robux lanes on top',function()
  local want={{'Starter',0,1},{'Tape',2,4},{'Street',4,10},{'Heavy',6,20},{'Speed',8,35},{'DoubleEnd',10,50},{'Pro',0,100,'RangeVIP1',99},{'Gold',0,250,'RangeVIP2',249},{'Ring',12,75}}
  t.expect.equal(#Skins.Stations,#want)
  for i,w in want do
   local s=Skins.Stations[i]
   t.expect.equal(s.Id,w[1]);t.expect.equal(s.Rebirths,w[2]);t.expect.equal(s.Multiplier,w[3]);t.expect.equal(s.Pass,w[4]);t.expect.equal(s.RobuxPrice,w[5]);t.expect.equal(s.Required,0)
  end
  -- the free lanes climb in rebirths and pay more each; both Robux lanes pay more than every free lane
  local free,topFree={},0
  for _,s in Skins.Stations do if not s.Pass then table.insert(free,s);topFree=math.max(topFree,s.Multiplier) end end
  table.sort(free,function(a,b) return a.Rebirths<b.Rebirths end)
  for i=2,#free do t.expect.truthy(free[i].Rebirths>free[i-1].Rebirths);t.expect.truthy(free[i].Multiplier>free[i-1].Multiplier) end
  t.expect.truthy(Skins.StationById.Pro.Multiplier>topFree);t.expect.truthy(Skins.StationById.Gold.Multiplier>Skins.StationById.Pro.Multiplier)
  t.expect.truthy(R.laneOpen(Skins.Stations[1],0));t.expect.falsy(R.laneOpen(Skins.Stations[2],1));t.expect.truthy(R.laneOpen(Skins.Stations[2],2))
  t.expect.equal(R.bestLane(0).Id,'Starter');t.expect.equal(R.bestLane(5).Id,'Street');t.expect.equal(R.bestLane(11).Id,'DoubleEnd');t.expect.equal(R.bestLane(99).Id,'Ring')
  t.expect.equal(R.bestLane(0,{RangeVIP1=true}).Id,'Pro');t.expect.equal(R.bestLane(99,{RangeVIP1=true,RangeVIP2=true}).Id,'Gold');t.expect.equal(R.bestLane(3,{RangeVIP2=true}).Id,'Gold')
  t.expect.equal(R.nextUnlock(1).Name,'BAY 2');t.expect.equal(R.nextUnlock(2),nil);t.expect.equal(R.nextUnlock(11).Id,'Ring');t.expect.equal(R.nextUnlock(12),nil)
  t.expect.equal(R.nextLane(3).Id,'Street');t.expect.equal(R.nextLane(10).Id,'Ring');t.expect.equal(R.nextLane(12),nil);t.expect.equal(R.nextLane(0).Id,'Tape')
 end)
 t.test('a Robux lane opens with its pass only (the player, a table or a function), at any rebirth; a pass never opens a rebirth lane',function()
  local pro,gold,tape=Skins.StationById.Pro,Skins.StationById.Gold,Skins.StationById.Tape
  t.expect.falsy(R.laneOpen(pro,0));t.expect.falsy(R.laneOpen(pro,999));t.expect.falsy(R.laneOpen(gold,999,{}))
  t.expect.truthy(R.laneOpen(pro,0,{RangeVIP1=true}));t.expect.falsy(R.laneOpen(pro,0,{RangeVIP2=true}));t.expect.truthy(R.laneOpen(gold,0,{RangeVIP2=true}))
  t.expect.truthy(R.laneOpen(pro,0,function(k) return k=='RangeVIP1' end));t.expect.falsy(R.laneOpen(gold,0,function(k) return k=='RangeVIP1' end))
  local p=Instance.new('Folder')
  t.expect.falsy(R.laneOpen(pro,5,p));p:SetAttribute('Pass_RangeVIP1',true);t.expect.truthy(R.laneOpen(pro,5,p));t.expect.falsy(R.laneOpen(gold,5,p))
  p:SetAttribute('Pass_RangeVIP1','yes');t.expect.falsy(R.laneOpen(pro,5,p)) -- (only a real true counts)
  p:Destroy()
  t.expect.falsy(R.laneOpen(tape,1,{RangeVIP1=true,RangeVIP2=true}));t.expect.falsy(R.laneOpen(tape,1,'RangeVIP1'))
  t.expect.equal(R.laneNeed(pro),0);t.expect.equal(R.lanePass(pro),'RangeVIP1');t.expect.equal(R.lanePass(gold),'RangeVIP2');t.expect.equal(R.lanePass(tape),nil);t.expect.equal(R.lanePass(nil),nil)
  t.expect.falsy(R.hasPass({RangeVIP1=true},''));t.expect.falsy(R.hasPass(nil,'RangeVIP1'))
 end)
 t.test('every Robux lane sells as a wired Store pass at its label price',function()
  local Products=require(RS.Shared.Config.Products)
  for _,s in Skins.Stations do
   if s.Pass then
    local e=Products.ByKey[s.Pass]
    t.expect.truthy(e~=nil and e.Kind=='Pass' and e.Section=='Gamepass');t.expect.equal(type(Products.Passes[s.Pass]),'number')
    t.expect.equal(e.Price,s.RobuxPrice);t.expect.equal(e.Wired,true);t.expect.truthy(string.find(e.Big,'x'..s.Multiplier,1,true)~=nil)
   end
  end
 end)
 t.test('lane labels read like the reference: rebirths or the Robux price / Unlocked or Locked / xN Power',function()
  local top,state,power=R.laneLabel(Skins.StationById.Tape,true);t.expect.equal(top,'2');t.expect.equal(state,'Unlocked');t.expect.equal(power,'x4 Power')
  top,state,power=R.laneLabel(Skins.StationById.Starter,true);t.expect.equal(top,'0');t.expect.equal(power,'x1 Power')
  local price
  top,state,power,price=R.laneLabel(Skins.StationById.Gold,false);t.expect.equal(top,R.RobuxMark..'249');t.expect.equal(state,'Locked');t.expect.equal(power,'x250 Power');t.expect.equal(price,249)
  top,_,_,price=R.laneLabel(Skins.StationById.Pro,false);t.expect.equal(top,R.RobuxMark..'99');t.expect.equal(price,99)
  -- the Robux sign is U+E002 (Roblox fonts draw it as the Robux icon), the same one the pads' price uses
  t.expect.equal(R.RobuxMark,utf8.char(0xE002));t.expect.equal(top,'\u{E002}99')
  t.expect.equal(select(4,R.laneLabel(Skins.StationById.Tape,true)),nil)
  top,state,power=R.laneLabel(nil,true);t.expect.equal(top,'');t.expect.equal(power,'')
 end)
 t.test('rebirths come back whole from junk, and saves are migrated and validated',function()
  t.expect.equal(R.count(3.9),3);t.expect.equal(R.count(-1),0);t.expect.equal(R.count(math.huge),0);t.expect.equal(R.count(1e9),R.Max)
  local old={SchemaVersion=3,Rep=50000,Cash=12,Rebirths=2.5,EquippedSkin='Kingpin'};Schema.migrate(old)
  t.expect.equal(old.SchemaVersion,4);t.expect.equal(old.Rebirths,2);t.expect.equal(old.Rep,50000);t.expect.equal(old.EquippedSkin,'Kingpin')
  t.expect.truthy(Schema.validate(old))
  local gone={SchemaVersion=3,EquippedSkin='RetiredLook'};Schema.migrate(gone);t.expect.equal(gone.EquippedSkin,'CornerKid');t.expect.truthy(Schema.validate(gone))
  local bad=Schema.new();bad.Rebirths=1.5;t.expect.throws(function() Schema.validate(bad) end)
  local huge=Schema.new();huge.Rebirths=Balance.MaxRebirths+1;t.expect.throws(function() Schema.validate(huge) end)
 end)
 t.test('walk speed: 16 to start, half a stud faster a rebirth, 24 at most',function()
  t.expect.equal(R.walkSpeed(0),16);t.expect.equal(R.walkSpeed(4),18);t.expect.equal(R.walkSpeed(16),24);t.expect.equal(R.walkSpeed(500),24);t.expect.equal(R.walkSpeed(nil),16)
 end)
end
