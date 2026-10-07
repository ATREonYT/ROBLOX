return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local ShotRules=require(RS.Shared.ShotRules)
 local GunTool=require(RS.Shared.GunTool)
 local Guns=require(RS.Shared.Config.Guns)
 local Net=require(RS.Shared.Net)
 local Skins=require(RS.Shared.Config.Skins)
 -- A shot pays a tenth of the per-second gain (at least 1) times the gun, whatever junk arrives.
 t.test('a shot pays a tenth of the gain times the gun',function()
  t.expect.equal(ShotRules.pay(0,1),1);t.expect.equal(ShotRules.pay(9,1),1);t.expect.equal(ShotRules.pay(10,1),1);t.expect.equal(ShotRules.pay(100,1),10)
  t.expect.equal(ShotRules.pay(100,3),30);t.expect.equal(ShotRules.pay(5,8),8);t.expect.equal(ShotRules.pay(Skins.gain('Kingpin',25),32),275*32)
  t.expect.equal(ShotRules.pay(0/0,0/0),1);t.expect.equal(ShotRules.pay(-50,-4),1);t.expect.equal(ShotRules.pay('x',nil),1);t.expect.equal(ShotRules.pay(math.huge,1),1)
 end)
 -- Only an unlocked range's box counts.
 t.test('shots count only on an unlocked range',function()
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
