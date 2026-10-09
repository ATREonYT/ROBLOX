return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local R=require(RS.Shared.RebirthRules)
 local Balance=require(RS.Shared.Config.Balance)
 local Skins=require(RS.Shared.Config.Skins)
 local Schema=require(game.ServerScriptService.HoodServer.ProfileSchema)
 -- Brief 17: "Rebirth n -> n+1, Nx -> (N+1)x", a requirement that grows every time, the first one a few minutes of
 -- shooting at BAY 1.
 t.test('the rebirth multiplier is 1x, 2x, 3x ... and the labels read like the reference',function()
  t.expect.equal(R.multiplier(0),1);t.expect.equal(R.multiplier(1),2);t.expect.equal(R.multiplier(8),9)
  local a,b=R.labels(8);t.expect.equal(a,'Rebirth 8 → Rebirth 9');t.expect.equal(b,'9x → 10x')
  t.expect.equal(R.multiplier(-3),1);t.expect.equal(R.multiplier(0/0),1);t.expect.equal(R.multiplier('7'),1);t.expect.equal(R.multiplier(2.7),3)
 end)
 t.test('each rebirth needs more Power than the last, in round numbers',function()
  t.expect.equal(R.need(0),2000);t.expect.equal(R.need(1),7500);t.expect.equal(R.need(2),21000)
  local last=0
  for n=0,30 do
   local v=R.need(n);t.expect.truthy(v>last);last=v
   local digits=string.format('%d',v):gsub('0+$','') -- (two significant figures)
   t.expect.truthy(#digits<=2)
  end
  t.expect.truthy(R.need(25)>Balance.MaxSafeValue/10) -- (the 1e12 Power cap ends the ladder long before MaxRebirths)
 end)
 t.test('you can rebirth at the need, not a point before; junk never rebirths',function()
  t.expect.falsy(R.canRebirth(1999,0));t.expect.truthy(R.canRebirth(2000,0));t.expect.falsy(R.canRebirth(7499,1));t.expect.truthy(R.canRebirth(7500,1))
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
 t.test('lanes open by rebirths: BAY 1 at once, then 2, 4 ... 14, the Champ Ring at 16, each paying more',function()
  local want={0,2,4,6,8,10,12,14,16}
  t.expect.equal(#Skins.Stations,9)
  for i,s in Skins.Stations do
   t.expect.equal(s.Rebirths,want[i]);t.expect.equal(s.Required,0)
   if i>1 then t.expect.truthy(s.Multiplier>Skins.Stations[i-1].Multiplier) end
  end
  t.expect.equal(Skins.Stations[1].Multiplier,1);t.expect.equal(Skins.StationById.Ring.Rebirths,16)
  t.expect.truthy(R.laneOpen(Skins.Stations[1],0));t.expect.falsy(R.laneOpen(Skins.Stations[2],1));t.expect.truthy(R.laneOpen(Skins.Stations[2],2))
  t.expect.equal(R.bestLane(0).Id,'Starter');t.expect.equal(R.bestLane(5).Id,'Street');t.expect.equal(R.bestLane(99).Id,'Ring')
  t.expect.equal(R.nextUnlock(1).Name,'BAY 2');t.expect.equal(R.nextUnlock(2),nil);t.expect.equal(R.nextUnlock(15).Id,'Ring')
  t.expect.equal(R.nextLane(3).Id,'Street');t.expect.equal(R.nextLane(16),nil)
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
