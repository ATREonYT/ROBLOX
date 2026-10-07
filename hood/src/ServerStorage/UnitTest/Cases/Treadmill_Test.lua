return function(t)
 local T=require(game.ReplicatedStorage.Shared.Config.Treadmills)
 local Skins=require(game.ReplicatedStorage.Shared.Config.Skins)
 local S=require(game.ServerScriptService.HoodServer.ProfileSchema)
 -- Jog is free and x1; every treadmill after it costs more Power and pays more Speed, on a bag's unlock step.
 t.test('treadmill ladder climbs and Jog is free',function()
  t.expect.equal(#T.List,3)
  t.expect.equal(T.List[1].Id,'Jog');t.expect.equal(T.List[1].Required,0);t.expect.equal(T.List[1].Multiplier,1)
  t.expect.equal(T.ById.Run.Multiplier,3);t.expect.equal(T.ById.Sprint.Multiplier,10)
  local steps={};for _,s in Skins.Stations do steps[s.Required]=true end
  for i,row in T.List do
   t.expect.equal(row.Tier,i);t.expect.equal(T.ById[row.Id],row)
   t.expect.truthy(type(row.Name)=='string' and #row.Name>0 and typeof(row.Color)=='Color3')
   t.expect.truthy(steps[row.Required])
   if i>1 then t.expect.truthy(row.Required>T.List[i-1].Required);t.expect.truthy(row.Multiplier>T.List[i-1].Multiplier) end
  end
 end)
 t.test('unlocks follow Power and gains follow the multiplier',function()
  t.expect.truthy(T.unlocked(0,'Jog'));t.expect.falsy(T.unlocked(149,'Run'));t.expect.truthy(T.unlocked(150,'Run'))
  t.expect.falsy(T.unlocked(999,'Sprint'));t.expect.truthy(T.unlocked(1000,'Sprint'));t.expect.falsy(T.unlocked(1e9,'Nope'))
  t.expect.equal(T.gain('Sprint'),10);t.expect.equal(T.gain('Nope'),0)
 end)
 -- Walk speed starts at Roblox's 16, never goes down as Speed grows, and stops at the cap.
 t.test('speed curve is monotonic and capped',function()
  local w=T.WalkSpeed
  t.expect.equal(T.walkSpeed(0),w.Base);t.expect.equal(T.walkSpeed(w.Full),w.Max);t.expect.equal(T.walkSpeed(1e12),w.Max)
  t.expect.equal(T.walkSpeed(-5),w.Base);t.expect.equal(T.walkSpeed(0/0),w.Base);t.expect.equal(T.walkSpeed(nil),w.Base)
  local last=T.walkSpeed(0)
  for s=1,60000,7 do local v=T.walkSpeed(s);t.expect.truthy(v>=last and v<=w.Max);last=v end
  t.expect.truthy(T.walkSpeed(w.Full*0.9)<w.Max)
 end)
 -- Diminishing returns: the first minute on Jog is worth a lot more than a minute much later.
 t.test('early runs feel fast, later ones less',function()
  t.expect.truthy(T.walkSpeed(60)>=20)
  t.expect.truthy(T.walkSpeed(100)-T.walkSpeed(0)>4*(T.walkSpeed(5100)-T.walkSpeed(5000)))
  local w=T.WalkSpeed;t.expect.truthy(T.walkSpeed(w.Full/2)-w.Base>0.85*(w.Max-w.Base))
 end)
 -- Profiles carry Speed: new ones at 0, old saves get it on migration, the client sees it, bad values fail.
 t.test('profiles carry Speed',function()
  local p=S.new();t.expect.equal(p.Speed,0);t.expect.truthy(S.validate(p));t.expect.equal(S.public(p).Speed,0)
  local old={Rep=50,Cash=5,SchemaVersion=3};S.migrate(old);t.expect.equal(old.Speed,0);t.expect.truthy(S.validate(old))
  local a=S.new();a.Speed=-1;t.expect.throws(function() S.validate(a) end)
  local b=S.new();b.Speed=0/0;t.expect.throws(function() S.validate(b) end)
  local c=S.new();c.Speed='fast';t.expect.throws(function() S.validate(c) end)
 end)
 -- The belt's chevron pieces stay on the belt, repeat every period, and the period is whole slats.
 t.test('belt chevrons stay on the belt',function()
  local pat=T.Pattern
  t.expect.near(pat.Period/pat.Spacing,math.floor(pat.Period/pat.Spacing+0.5))
  local shown=0
  for s=0,2*pat.Period,0.05 do
   local x,w=T.chevron(s,pat)
   if x then
    shown+=1
    t.expect.truthy(x-w/2>=-1e-6 and x+w/2<=pat.HalfWidth+1e-6 and w>0)
    local x2,w2=T.chevron(s+pat.Period,pat);t.expect.near(x2,x,1e-6);t.expect.near(w2,w,1e-6)
   end
  end
  t.expect.truthy(shown>0)
 end)
end
