return function(t)
 local S=require(game.ReplicatedStorage.Shared.Config.Skins)
 local R=require(game.ReplicatedStorage.Shared.LobbyRules)
 local Schema=require(game.ServerScriptService.HoodServer.ProfileSchema)
 t.test('skin thresholds are inclusive',function() t.expect.falsy(S.available(24,'Pickpocket'));t.expect.truthy(S.available(25,'Pickpocket')) end)
 t.test('cannot equip remotely or unknown skin',function() t.expect.falsy(R.canEquip(10000,'StreetBoss',15));t.expect.falsy(R.canEquip(10000,'fake',1));t.expect.falsy(R.canEquip(10000,'StreetBoss',0/0));t.expect.truthy(R.canEquip(2000,'StreetBoss',5)) end)
 t.test('locked gym grants no multiplier',function() local m,id=R.training(149,Vector3.new(-50,5,66));t.expect.equal(m,1);t.expect.equal(id,'Locked:Street') end)
 t.test('training requires physical mat and correct height',function() local m=R.training(150,Vector3.new(-50,5,66));t.expect.equal(m,4);t.expect.equal(R.training(150,Vector3.new(-50,30,66)),1);t.expect.equal(R.training(150,Vector3.new(-61,5,66)),1) end)
 t.test('skin and gym gains multiply once',function() t.expect.equal(S.gain('Pickpocket',4),8);t.expect.equal(S.gain('StreetBoss',8),128) end)
 t.test('version one migration retains currency and adds starter look',function() local d=Schema.new();d.SchemaVersion=1;d.EquippedSkin=nil;d.Rep=47;Schema.migrate(d);t.expect.equal(d.SchemaVersion,3);t.expect.equal(d.EquippedSkin,'CornerKid');t.expect.equal(d.Rep,47);t.expect.truthy(Schema.validate(d)) end)
 t.test('locked equipped look fails validation',function() local d=Schema.new();d.EquippedSkin='StreetBoss';t.expect.throws(function() Schema.validate(d) end) end)
 t.test('v2 selections migrate without losing earned power',function()
  local aliases={Rookie={'CornerKid',0},RoadRunner={'Pickpocket',25},Crook={'Bandit',150},Gangster={'Crook',600},MafiaBoss={'StreetBoss',2000},Legend={'Capo',6000}}
  for old,row in aliases do local d=Schema.new();d.SchemaVersion=2;d.EquippedSkin=old;d.Rep=row[2];Schema.migrate(d);t.expect.equal(d.EquippedSkin,row[1]);t.expect.equal(d.Rep,row[2]);t.expect.truthy(Schema.validate(d)) end
 end)
 t.test('fifteen unique morphs are available',function() t.expect.equal(#S.List,15);local ids={};for _,s in S.List do t.expect.falsy(ids[s.Id]);ids[s.Id]=true end;t.expect.equal(S.List[15].Id,'Kingpin') end)
 t.test('all skins have strictly increasing thresholds and gains',function() for i=2,#S.List do t.expect.truthy(S.List[i].Required>S.List[i-1].Required);t.expect.truthy(S.List[i].Gain>S.List[i-1].Gain) end end)
end
