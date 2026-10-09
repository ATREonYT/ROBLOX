return function(t)
 local S=require(game.ReplicatedStorage.Shared.Config.Skins)
 local R=require(game.ReplicatedStorage.Shared.LobbyRules)
 local Schema=require(game.ServerScriptService.HoodServer.ProfileSchema)
 local function streetZone() return {{Station=S.StationById.Street,X=-50,Z=66,HalfX=5,HalfZ=5,Top=1}} end
 -- BAY 3 (Street) opens at 4 rebirths: before that its box pays nothing and says what it needs.
 t.test('a lane that needs more rebirths pays nothing and names itself',function()
  local m,id=R.training(3,Vector3.new(-50,4,66),streetZone());t.expect.equal(m,0);t.expect.equal(id,'Locked:Street')
  t.expect.equal(R.need(id,3),4);t.expect.equal(R.need('Street',9),0);t.expect.equal(R.need('',0),0);t.expect.equal(R.need(nil,0),0)
  t.expect.equal(R.need('Locked:Street',4),0) -- (opened since)
 end)
 t.test('training requires standing on the mat of an open lane',function()
  local z=streetZone()
  t.expect.equal(R.training(4,Vector3.new(-50,4,66),z),3);t.expect.equal(select(2,R.training(4,Vector3.new(-50,4,66),z)),'Street')
  t.expect.equal(R.training(4,Vector3.new(-50,30,66),z),1);t.expect.equal(select(2,R.training(4,Vector3.new(-56,4,66),z)),'')
 end)
 t.test('zones are read from the built mats',function()
  local lobby=Instance.new('Model')
  local bay=Instance.new('Model');bay.Name='Training_Street';bay.Parent=lobby
  local mat=Instance.new('Part');mat.Name='TrainingZone';mat.Size=Vector3.new(10,0.25,8);mat.CFrame=CFrame.new(20,2,30)*CFrame.Angles(0,math.pi/2,0);mat.Parent=bay
  local zones=R.zonesFrom(lobby,CFrame.new())
  t.expect.equal(#zones,1);t.expect.near(zones[1].HalfX,4,1e-4);t.expect.near(zones[1].HalfZ,5,1e-4);t.expect.near(zones[1].Top,2.125,1e-4)
  t.expect.equal(R.training(4,Vector3.new(23,5,34),zones),3)
  lobby:Destroy()
 end)
 t.test('lanes climb in rebirths needed and payoff',function() for i=2,#S.Stations do t.expect.truthy(S.Stations[i].Rebirths>S.Stations[i-1].Rebirths);t.expect.truthy(S.Stations[i].Multiplier>S.Stations[i-1].Multiplier) end end)
 t.test('every station has gear the lobby builder knows',function() local L=require(game.ServerStorage.SimulatorLobby);for _,s in S.Stations do t.expect.truthy(s.Gear=='Ring' or L.Gear[s.Gear]) end end)
 -- The looks are art only now: nothing equips them, gains from them or walks faster with them.
 t.test('the looks give nothing: no gain, no equip, no walk speed',function()
  t.expect.equal(S.gain,nil);t.expect.equal(S.available,nil);t.expect.equal(S.walkSpeed,nil);t.expect.equal(S.nextSkin,nil);t.expect.equal(R.canEquip,nil)
  t.expect.equal(#S.List,15);t.expect.truthy(S.ById.Kingpin) -- (SkinArt and old saves still know the ids)
 end)
 t.test('version one migration retains currency and adds starter look',function() local d=Schema.new();d.SchemaVersion=1;d.EquippedSkin=nil;d.Rep=47;Schema.migrate(d);t.expect.equal(d.SchemaVersion,4);t.expect.equal(d.EquippedSkin,'CornerKid');t.expect.equal(d.Rep,47);t.expect.truthy(Schema.validate(d)) end)
 -- A look you once wore never blocks a save, whatever your Power (a rebirth puts Power back to 0).
 t.test('a saved top look with no Power still loads',function() local d=Schema.new();d.EquippedSkin='Kingpin';d.Rep=0;t.expect.truthy(Schema.validate(d)) end)
 t.test('v2 selections migrate without losing earned power',function()
  local aliases={Rookie={'CornerKid',0},RoadRunner={'Pickpocket',25},Crook={'Bandit',150},Gangster={'Crook',600},MafiaBoss={'StreetBoss',2000},Legend={'Capo',6000}}
  for old,row in aliases do local d=Schema.new();d.SchemaVersion=2;d.EquippedSkin=old;d.Rep=row[2];Schema.migrate(d);t.expect.equal(d.EquippedSkin,row[1]);t.expect.equal(d.Rep,row[2]);t.expect.truthy(Schema.validate(d)) end
 end)
end
