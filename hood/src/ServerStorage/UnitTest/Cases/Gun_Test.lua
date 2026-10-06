return function(t)
 local Guns=require(game.ReplicatedStorage.Shared.Config.Guns)
 local R=require(game.ReplicatedStorage.Shared.GunRules)
 local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
 local Net=require(game.ReplicatedStorage.Shared.Net)
 local function fresh() return {Owned={Pistol=true},Equipped='Pistol'} end
 -- Every gun costs more and pays more than the one before it; the first one is free and the starter.
 t.test('gun ladder climbs and the pistol is free',function()
  t.expect.equal(#Guns.List,10)
  t.expect.equal(Guns.List[1].Id,Guns.Starter);t.expect.equal(Guns.List[1].Cost,0);t.expect.equal(Guns.List[1].Multiplier,1)
  for i,g in Guns.List do
   t.expect.equal(g.Tier,i);t.expect.equal(Guns.ById[g.Id],g)
   t.expect.truthy(type(g.Name)=='string' and #g.Name>0 and typeof(g.Color)=='Color3')
   if i>1 then t.expect.truthy(g.Cost>Guns.List[i-1].Cost);t.expect.truthy(g.Multiplier>Guns.List[i-1].Multiplier) end
  end
  t.expect.equal(Guns.multiplier('Nope'),1)
 end)
 -- New and old profiles both start with the pistol, owned and equipped, and show it to the client.
 t.test('profiles start with the pistol',function()
  local p=S.new();t.expect.truthy(p.Guns.Owned.Pistol);t.expect.equal(p.Guns.Equipped,'Pistol');t.expect.truthy(S.validate(p))
  local old={Rep=5,Cash=9,SchemaVersion=3};S.migrate(old);t.expect.equal(old.Guns.Equipped,'Pistol');t.expect.truthy(S.validate(old))
  local view=S.public(p);t.expect.equal(view.Guns.Equipped,'Pistol');view.Guns.Owned.Uzi=true;t.expect.equal(p.Guns.Owned.Uzi,nil)
 end)
 -- A retired gun id in a save is dropped and the player falls back to the pistol instead of being kicked.
 t.test('migration cleans unknown guns',function()
  local d=S.new();d.Guns={Owned={Retired=true,Uzi=true},Equipped='Retired'};S.migrate(d)
  t.expect.equal(d.Guns.Owned.Retired,nil);t.expect.truthy(d.Guns.Owned.Uzi);t.expect.truthy(d.Guns.Owned.Pistol);t.expect.equal(d.Guns.Equipped,'Pistol')
  t.expect.truthy(S.validate(d))
 end)
 -- Validation fails closed on a gun the player does not own or that does not exist.
 t.test('validation rejects bad gun state',function()
  local a=S.new();a.Guns.Equipped='Uzi';t.expect.throws(function() S.validate(a) end)
  local b=S.new();b.Guns.Owned.Ghost=true;t.expect.throws(function() S.validate(b) end)
  local c=S.new();c.Guns.Owned.Uzi='yes';t.expect.throws(function() S.validate(c) end)
 end)
 t.test('buying needs the gun, the distance and the cash',function()
  local g=fresh()
  t.expect.truthy(R.canBuy(g,60,'Uzi',5))
  t.expect.equal(select(2,R.canBuy(g,59,'Uzi',5)),'cash')
  t.expect.equal(select(2,R.canBuy(g,1e6,'Uzi',R.Range+0.1)),'far')
  t.expect.equal(select(2,R.canBuy(g,1e6,'Uzi',0/0)),'far')
  t.expect.equal(select(2,R.canBuy(g,1e6,'Pistol',1)),'owned')
  t.expect.equal(select(2,R.canBuy(g,1e6,'Nope',1)),'unknown')
  t.expect.equal(select(2,R.canBuy(g,1e6,{},1)),'unknown')
  t.expect.equal(select(2,R.canBuy(g,0/0,'Uzi',1)),'cash')
 end)
 t.test('equipping needs an owned gun at the pedestal',function()
  local g=fresh();g.Owned.Uzi=true
  t.expect.truthy(R.canEquip(g,'Uzi',3))
  t.expect.equal(select(2,R.canEquip(g,'Shotgun',3)),'locked')
  t.expect.equal(select(2,R.canEquip(g,'Pistol',3)),'equipped')
  t.expect.equal(select(2,R.canEquip(g,'Uzi',99)),'far')
  t.expect.equal(select(2,R.canEquip(g,7,3)),'unknown')
 end)
 t.test('states, multiplier and the attribute round trip agree',function()
  local g=fresh();g.Owned.Shotgun=true;g.Equipped='Shotgun'
  t.expect.equal(R.state(g,'Shotgun'),'Equipped');t.expect.equal(R.state(g,'Pistol'),'Owned');t.expect.equal(R.state(g,'Uzi'),'Locked')
  t.expect.equal(R.multiplier(g),4)
  t.expect.equal(R.ownedList(g),'Pistol,Shotgun')
  local back=R.fromAttributes(R.ownedList(g),'Shotgun');t.expect.deepEqual(back,g)
  local none=R.fromAttributes(nil,nil);t.expect.equal(none.Equipped,'Pistol');t.expect.truthy(none.Owned.Pistol)
  t.expect.equal(R.actionText('Locked',60),'Buy 60 Cash');t.expect.equal(R.actionText('Locked',25000),'Buy 25K Cash')
  t.expect.equal(R.actionText('Owned',60),'Equip');t.expect.equal(R.actionText('Equipped',60),'Equipped')
  for _,state in {'Locked','Owned','Equipped'} do t.expect.truthy(R.Colors[state] and R.Colors[state].Top) end
 end)
 -- Once the server has made its remotes, the armory's are among them (Net.get refuses unknown names).
 t.test('armory remotes are declared',function()
  t.expect.falsy(pcall(Net.get,'Nope'))
  local folder=game.ReplicatedStorage:FindFirstChild('HoodNet')
  if folder then for _,name in {'BuyGun','EquipGun'} do t.expect.truthy(folder:FindFirstChild(name)) end end
 end)
end
