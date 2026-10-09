return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local ShotRules=require(RS.Shared.ShotRules)
 local GunTool=require(RS.Shared.GunTool)
 local Guns=require(RS.Shared.Config.Guns)
 local Net=require(RS.Shared.Net)
 -- A shot pays ShotBase x lane x rebirth multiplier (x boosts) x gun x shoes, whatever junk arrives (brief 17).
 t.test('a shot pays base x lane x rebirth x gun',function()
  local Balance=require(RS.Shared.Config.Balance)
  t.expect.equal(Balance.ShotBase,1)
  t.expect.equal(ShotRules.perShot(1,0),1);t.expect.equal(ShotRules.perShot(3,0),3);t.expect.equal(ShotRules.perShot(3,4),15);t.expect.equal(ShotRules.perShot(25,14),375)
  t.expect.equal(ShotRules.perShot(0,9),0) -- (a locked lane)
  t.expect.equal(ShotRules.perShot(2,1,2),8);t.expect.equal(ShotRules.perShot(2,1,99),2*2*ShotRules.MaxBoost);t.expect.equal(ShotRules.perShot(2,1,0/0),4)
  t.expect.equal(ShotRules.pay(ShotRules.perShot(1,0),1),1);t.expect.equal(ShotRules.pay(ShotRules.perShot(3,4),8),120);t.expect.equal(ShotRules.pay(ShotRules.perShot(18,12),32,2),18*13*32*2)
  t.expect.equal(ShotRules.pay(0,8),0);t.expect.equal(ShotRules.pay(-50,-4),0) -- (a locked lane pays nothing)
  t.expect.equal(ShotRules.pay(0/0,0/0),1);t.expect.equal(ShotRules.pay('x',nil),1);t.expect.equal(ShotRules.pay(nil,3),3);t.expect.equal(ShotRules.pay(math.huge,1),1);t.expect.equal(ShotRules.pay(2.7,1),2)
  t.expect.equal(ShotRules.boost(true,nil),2);t.expect.equal(ShotRules.boost(false,3),3);t.expect.equal(ShotRules.boost(true,3),6);t.expect.equal(ShotRules.boost('yes',0/0),1);t.expect.equal(ShotRules.boost(true,1e9),ShotRules.MaxBoost)
 end)
 -- No Power per second any more: nothing in the shared rules pays by time, and the lobby service only adds Power in
 -- its Shoot handler (the source is checked where it can be read: the offline harness, the command bar).
 t.test('no passive gain: Power only comes from shots',function()
  local Skins=require(RS.Shared.Config.Skins);t.expect.equal(Skins.gain,nil)
  local ok,src=pcall(function() return game.ServerScriptService.HoodServer.LobbyService.Source end)
  if ok and type(src)=='string' and #src>0 then
   local writes=0;for _ in src:gmatch('profile%.Data%.Rep%s*=') do writes+=1 end
   t.expect.equal(writes,1)
   local shoot=src:find("Net.get('Shoot').OnServerEvent",1,true);local at=src:find('profile%.Data%.Rep%s*=')
   local loop=src:find('while task.wait',1,true)
   t.expect.truthy(shoot and at and at>shoot and loop and at<loop)
  end
 end)
 -- Only an open lane's box counts.
 t.test('shots count only on an open lane',function()
  t.expect.truthy(ShotRules.counts('Starter'));t.expect.truthy(ShotRules.counts('Gold'))
  t.expect.falsy(ShotRules.counts(''));t.expect.falsy(ShotRules.counts('Locked:Tape'));t.expect.falsy(ShotRules.counts(nil));t.expect.falsy(ShotRules.counts(7))
  t.expect.truthy(ShotRules.Burst>=ShotRules.PerSecond and ShotRules.PerSecond<=8 and 1/ShotRules.Cooldown>=ShotRules.PerSecond)
 end)
 -- Targets take turns: every other shot the main one; a target that is away is skipped, never shot at.
 t.test('shots skip targets that are away',function()
  local main,a,b={n='main'},{n='a'},{n='b'}
  local away={}
  local function there(x) return not away[x] end
  local st,seq={},{}
  for _=1,6 do table.insert(seq,ShotRules.pick(st,{a,main,b},main,there).n) end
  t.expect.equal(table.concat(seq,' '),'main a main b main a')
  away[a]=true
  local st2,seq2={},{}
  for _=1,4 do table.insert(seq2,ShotRules.pick(st2,{a,main,b},main,there).n) end
  t.expect.equal(table.concat(seq2,' '),'main b main b')
  away[main]=true
  local x,ok=ShotRules.pick({},{a,main,b},main,there);t.expect.equal(x,b);t.expect.truthy(ok)
  away[b]=true
  x,ok=ShotRules.pick({},{a,main,b},main,there);t.expect.equal(x,main);t.expect.falsy(ok)
  x,ok=ShotRules.pick({},{main},main,function() return true end);t.expect.equal(x,main);t.expect.truthy(ok)
 end)
 -- Sounds: the shot is clicks only (the pings are the hits'), no UI click anywhere, modest volumes, every
 -- unverified file behind a fallback, pools sized from the real length (a held trigger never cuts a voice).
 t.test('shot sounds are layered built-ins with safe pools',function()
  local ShotSounds=require(RS.Shared.ShotSounds)
  local verified={['clickfast.wav']=true,['electronicpingshort.wav']=true}
  for _,kind in ShotSounds.ORDER do
   t.expect.truthy(ShotSounds.LAYERS[kind])
   for _,layer in ShotSounds.LAYERS[kind] do
    t.expect.truthy(layer[1]~='button.wav');t.expect.truthy(layer[2]<=0.5)
    if kind=='Shot' then t.expect.truthy(layer[1]~='electronicpingshort.wav' and (not layer.fallback or layer.fallback[1]~='electronicpingshort.wav')) end
    t.expect.truthy(verified[layer[1]] or (layer.fallback and verified[layer.fallback[1]]))
   end
  end
  t.expect.equal(ShotSounds.poolSize(0,0.5,'Ding'),4);t.expect.equal(ShotSounds.poolSize(nil,1,'Shot'),4)
  t.expect.equal(ShotSounds.poolSize(0.3,0.5,'Ding'),6) -- 0.3 s at 0.475 lasts 0.63 s: 5 plays deep, plus one
  t.expect.equal(ShotSounds.poolSize(2,0.4,'Shot'),10);t.expect.equal(ShotSounds.poolSize(0.05,2,'Shot'),4)
  t.expect.truthy(type(ShotSounds.demo)=='function' and type(ShotSounds.play)=='function')
 end)
 -- The remote is Shoot now; Punch is gone.
 t.test('the Shoot remote replaces Punch',function()
  t.expect.falsy(pcall(Net.get,'Punch'))
  local folder=RS:FindFirstChild('HoodNet')
  if folder then t.expect.truthy(folder:FindFirstChild('Shoot'));t.expect.falsy(folder:FindFirstChild('Punch')) end
 end)
 -- Every gun builds as a held tool: a Handle, welded unanchored parts, the muzzle where the model says.
 t.test('every gun builds as a held tool',function()
  for _,gun in Guns.List do
   local tool=GunTool.build(gun.Id)
   t.expect.equal(tool.ClassName,'Tool');t.expect.equal(tool.Name,gun.Name);t.expect.equal(tool:GetAttribute('GunId'),gun.Id);t.expect.truthy(GunTool.is(tool))
   t.expect.falsy(tool.CanBeDropped);t.expect.truthy(tool.RequiresHandle);t.expect.truthy(tool.ManualActivationOnly)
   local handle=tool:FindFirstChild('Handle');t.expect.truthy(handle and handle:IsA('BasePart'))
   local muzzle=handle:FindFirstChild('Muzzle');t.expect.truthy(muzzle and handle:FindFirstChild('Eject'))
   t.expect.truthy(muzzle.CFrame.Position.Z<-0.5) -- in front of the grip
   local parts,welded=0,0
   for _,p in tool:GetDescendants() do
    if p:IsA('BasePart') then parts+=1;t.expect.falsy(p.Anchored);t.expect.falsy(p.CanCollide);t.expect.truthy(p.Massless) end
    if p:IsA('WeldConstraint') and p.Part0==handle then welded+=1 end
   end
   t.expect.truthy(parts>5);t.expect.equal(welded,parts-1)
   tool:Destroy()
  end
 end)
 -- The player always has exactly one gun tool of the equipped gun; a held one is swapped in the hand.
 t.test('the gun tool follows the equipped gun',function()
  local pack=Instance.new('Backpack');local character=Instance.new('Model')
  local player={Character=character,FindFirstChildOfClass=function(_,c) return c=='Backpack' and pack or nil end}
  local a=GunTool.sync(player,'Pistol');t.expect.equal(a.Parent,pack);t.expect.equal(GunTool.find(player),a)
  t.expect.equal(GunTool.sync(player,'Pistol'),a)
  a.Parent=character -- held
  local b=GunTool.sync(player,'Uzi');t.expect.equal(b.Parent,character);t.expect.equal(b:GetAttribute('GunId'),'Uzi');t.expect.falsy(a.Parent);t.expect.equal(GunTool.held(character),b)
  local n=0;for _,c in {pack,character} do for _,d in c:GetChildren() do if GunTool.is(d) then n+=1 end end end
  t.expect.equal(n,1)
  pack:Destroy();character:Destroy()
 end)
end
