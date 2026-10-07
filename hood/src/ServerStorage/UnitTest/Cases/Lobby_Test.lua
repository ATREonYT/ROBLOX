return function(t)
 local S=require(game.ReplicatedStorage.Shared.Config.Skins)
 local R=require(game.ReplicatedStorage.Shared.LobbyRules)
 local Schema=require(game.ServerScriptService.HoodServer.ProfileSchema)
 t.test('skin thresholds are inclusive',function() t.expect.falsy(S.available(24,'Pickpocket'));t.expect.truthy(S.available(25,'Pickpocket')) end)
 t.test('unlocked looks equip from anywhere',function()
  t.expect.truthy(R.canEquip(2000,'StreetBoss'));t.expect.truthy(R.canEquip(10000,'StreetBoss',math.huge));t.expect.truthy(R.canEquip(0,'CornerKid')) end)
 t.test('unknown, locked or malformed looks never equip',function()
  t.expect.falsy(R.canEquip(10000,'fake'));t.expect.falsy(R.canEquip(10000,nil));t.expect.falsy(R.canEquip(10000,7))
  t.expect.falsy(R.canEquip(1999,'StreetBoss'));t.expect.falsy(R.canEquip(0/0,'StreetBoss'));t.expect.falsy(R.canEquip(nil,'StreetBoss'));t.expect.falsy(R.canEquip('9999','StreetBoss')) end)
 local function streetZone() return {{Station=S.StationById.Street,X=-50,Z=66,HalfX=5,HalfZ=5,Top=1}} end
 t.test('locked bag grants no multiplier',function() local m,id=R.training(149,Vector3.new(-50,4,66),streetZone());t.expect.equal(m,1);t.expect.equal(id,'Locked:Street') end)
 t.test('training requires standing on the mat',function() local z=streetZone();t.expect.equal(R.training(150,Vector3.new(-50,4,66),z),4);t.expect.equal(R.training(150,Vector3.new(-50,30,66),z),1);t.expect.equal(R.training(150,Vector3.new(-56,4,66),z),1) end)
 t.test('zones are read from the built mats',function()
  local lobby=Instance.new('Model')
  local bay=Instance.new('Model');bay.Name='Training_Street';bay.Parent=lobby
  local mat=Instance.new('Part');mat.Name='TrainingZone';mat.Size=Vector3.new(10,0.25,8);mat.CFrame=CFrame.new(20,2,30)*CFrame.Angles(0,math.pi/2,0);mat.Parent=bay
  local zones=R.zonesFrom(lobby,CFrame.new())
  t.expect.equal(#zones,1);t.expect.near(zones[1].HalfX,4,1e-4);t.expect.near(zones[1].HalfZ,5,1e-4);t.expect.near(zones[1].Top,2.125,1e-4)
  t.expect.equal(R.training(150,Vector3.new(23,5,34),zones),4)
  lobby:Destroy()
 end)
 t.test('bags climb in power needed and payoff',function() for i=2,#S.Stations do t.expect.truthy(S.Stations[i].Required>S.Stations[i-1].Required);t.expect.truthy(S.Stations[i].Multiplier>S.Stations[i-1].Multiplier) end end)
 t.test('every station has gear the lobby builder knows',function() local L=require(game.ServerStorage.SimulatorLobby);for _,s in S.Stations do t.expect.truthy(s.Gear=='Ring' or L.Gear[s.Gear]) end end)
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
