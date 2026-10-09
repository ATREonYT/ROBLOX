return function(t)
 local F=require(game.ReplicatedStorage.Shared.LabelFade)
 -- A lane-like label: a Sign part with a BillboardGui 'Label' (a chip Frame with a stroke, two texts with strokes).
 local function lane(parent,pos,name)
  local sign=Instance.new('Part');sign.Name='Sign';sign.Anchored=true;sign.Size=Vector3.new(0.2,0.2,0.2);sign.CFrame=CFrame.new(pos);sign.Parent=parent
  local g=Instance.new('BillboardGui');g.Name=name or 'Label';g.Size=UDim2.fromScale(12,7.2);g.MaxDistance=250;g.Parent=sign
  local chip=Instance.new('Frame');chip.Name='Chip';chip.BackgroundTransparency=0.55;chip.Parent=g
  local cs=Instance.new('UIStroke');cs.Parent=chip
  for _,n in {'Detail','Power'} do
   local l=Instance.new('TextLabel');l.Name=n;l.BackgroundTransparency=1;l.TextTransparency=0;l.TextStrokeTransparency=1;l.Parent=g
   local s=Instance.new('UIStroke');s.Transparency=0;s.Parent=l
  end
  return g,sign
 end
 local function eye(z) return CFrame.lookAt(Vector3.new(0,10,z),Vector3.new(0,10,0)) end
 local function run(f,seconds,cam) local n=math.floor(seconds*60+0.5);for _=1,n do f:step(1/60,cam) end end
 local function texts(g) return g.Power.TextTransparency,g.Power.UIStroke.Transparency,g.Chip.BackgroundTransparency,g.Chip.UIStroke.Transparency end

 t.test('the band is whole up close, gone far away, smooth between',function()
  t.expect.equal(F.band(10,45,75),1);t.expect.equal(F.band(45,45,75),1);t.expect.equal(F.band(75,45,75),0);t.expect.equal(F.band(300,45,75),0)
  t.expect.near(F.band(60,45,75),0.5,1e-9)
  local last=1
  for d=45,75,0.5 do local b=F.band(d,45,75);t.expect.truthy(b<=last+1e-12);last=b end
  t.expect.equal(F.shrink(10,34,0.35),0.35);t.expect.near(F.shrink(17,34,0.35),0.5,1e-9);t.expect.equal(F.shrink(50,34,0.35),1);t.expect.equal(F.shrink(5,nil,0.35),1)
 end)
 t.test('fades run at a steady rate, so a camera jump never flickers',function()
  local a=0;local n=0
  while a<1 do a=F.approach(a,1,1/60);n+=1 end
  t.expect.near(n/60,F.IN_TIME,1/60+1e-9)
  a=1;n=0
  while a>0 do a=F.approach(a,0,1/60);n+=1 end
  t.expect.near(n/60,F.OUT_TIME,1/60+1e-9)
  -- one frame away and back (a camera cut and its return): the label barely moves
  a=F.approach(1,0,1/60);t.expect.truthy(a>0.95);a=F.approach(a,1,1/60);t.expect.equal(a,1)
 end)
 t.test('the pop grows a little and settles back without a jolt',function()
  t.expect.equal(F.pop(0),1);t.expect.equal(F.pop(1),1)
  local peak=1
  for u=0,1,0.01 do local p=F.pop(u);t.expect.truthy(p>=1);peak=math.max(peak,p) end
  t.expect.truthy(peak>1.05 and peak<1.1)
  t.expect.truthy(math.abs(F.pop(0.99)-1)<0.002)
  t.expect.equal(F.fadeSize(1,0.85),1);t.expect.near(F.fadeSize(0,0.85),0.85,1e-9)
 end)
 t.test('the map labels are found by name, the gate sign never',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0));t.expect.equal(F.kindOf(g),'Lane')
  local function anchored(partName,guiName,h,md)
   local p=Instance.new('Part');p.Name=partName;p.Parent=root
   local b=Instance.new('BillboardGui');b.Name=guiName;b.Size=UDim2.fromScale(6,h or 2);b.MaxDistance=md or 90;b.Parent=p
   return b
  end
  t.expect.equal(F.kindOf(anchored('LabelAnchor','GunLabel')),'Gun')
  t.expect.equal(F.kindOf(anchored('BoxLabel_Gold','WorldLabel')),'Box')
  t.expect.equal(F.kindOf(anchored('LobbyPadLabel','WorldLabel')),'Pad')
  t.expect.equal(F.kindOf(anchored('FurthestPadLabel','WorldLabel')),'Pad')
  t.expect.equal(F.kindOf(anchored('LabelAnchor','WorldLabel',2.4,120)),'Sign')
  t.expect.equal(F.kindOf(anchored('LabelAnchor','WorldLabel',6.8,160)),'Title')
  t.expect.equal(F.kindOf(anchored('SignAnchor','GateSign',9.6,1000)),nil)
  t.expect.equal(F.kindOf(anchored('Head','GoonTag')),nil)
  local off=anchored('LabelAnchor','WorldLabel');off:SetAttribute('FadeOff',true);t.expect.equal(F.kindOf(off),nil)
  local other=anchored('Anything','Board');other:AddTag(F.Tag);t.expect.equal(F.kindOf(other),'Sign')
  root:Destroy()
 end)
 t.test('each kind has its band, attributes win',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0))
  local c=F.config(g,'Lane',250);t.expect.equal(c.Near,45);t.expect.equal(c.Far,75);t.expect.equal(c.Shrink,34);t.expect.equal(c.Group,'Lanes')
  g:SetAttribute('FadeNear',65);g:SetAttribute('FadeFar',105);g:SetAttribute('FadeMin',0.7)
  c=F.config(g,'Lane',250);t.expect.equal(c.Near,65);t.expect.equal(c.Far,105);t.expect.near(c.Min,0.7,1e-9)
  g:SetAttribute('FadeFar',10);c=F.config(g,'Lane',250);t.expect.truthy(c.Far>c.Near) -- (a far edge inside the near one is pushed out)
  local s=F.config(g,'Sign',120);t.expect.truthy(s.Far>s.Near)
  local p=Instance.new('Part');local w=Instance.new('BillboardGui');w.Name='WorldLabel';w.Parent=p
  c=F.config(w,'Sign',120);t.expect.equal(c.Far,70);t.expect.near(c.Near,42,1e-9)
  c=F.config(w,'Sign',50);t.expect.equal(c.Far,50)
  c=F.config(w,'Title',160);t.expect.equal(c.Far,160);t.expect.equal(c.Near,120)
  t.expect.equal(c.Group,nil);t.expect.equal(c.Shrink,nil)
  root:Destroy()
 end)
 t.test('walking away fades text, outlines and chip out and shrinks it; coming back fades in with a pop',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0))
  local f=F.new();t.expect.truthy(f:add(g))
  t.expect.near(g.MaxDistance,75+75*0.35,1e-3) -- (the engine stops drawing it a margin past the band)
  f:decide(eye(40),500);run(f,0.1,eye(40))
  local tt,ts,cb,cs=texts(g);t.expect.equal(tt,0);t.expect.equal(ts,0);t.expect.near(cb,0.55,1e-6);t.expect.equal(cs,0)
  t.expect.near(g.Size.X.Scale,12,1e-9)
  f:decide(eye(200),500);run(f,F.OUT_TIME+0.05,eye(200))
  tt,ts,cb,cs=texts(g);t.expect.equal(tt,1);t.expect.equal(ts,1);t.expect.equal(cb,1);t.expect.equal(cs,1)
  t.expect.near(g.Size.X.Scale,12*F.MIN,1e-6)
  t.expect.equal(g.Detail.TextStrokeTransparency,1) -- (a hidden property stays hidden)
  t.expect.equal(f:awakeCount(),0) -- (faded and still: nothing runs per frame)
  f:decide(eye(40),500)
  local biggest=0
  for _=1,math.floor((F.IN_TIME+F.POP_TIME+0.1)*60) do f:step(1/60,eye(40));biggest=math.max(biggest,g.Size.X.Scale) end
  t.expect.truthy(biggest>12*1.04) -- the pop
  tt,ts,cb,cs=texts(g);t.expect.equal(tt,0);t.expect.equal(ts,0);t.expect.near(cb,0.55,1e-6);t.expect.equal(cs,0)
  t.expect.near(g.Size.X.Scale,12,1e-9);t.expect.equal(f:awakeCount(),0)
  root:Destroy()
 end)
 t.test('inside the band it follows the distance smoothly, and does not pop when it only dips',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0))
  local f=F.new();f:add(g)
  f:decide(eye(60),500);run(f,0.05,eye(60))
  t.expect.near(g.Power.TextTransparency,0.5,0.03)
  -- walking in at 16 studs/s: the label follows every frame (live), no steps bigger than a paint step
  local last=g.Power.TextTransparency
  local z=60
  for _=1,60 do z-=16/60;f:step(1/60,eye(z));local v=g.Power.TextTransparency;t.expect.truthy(math.abs(v-last)<=F.PAINT_STEP*2);last=v end
  f:decide(eye(z),500);run(f,0.5,eye(z))
  t.expect.equal(g.Power.TextTransparency,0)
  -- a dip to 0.9 and back: no pop
  f:decide(eye(48),500);run(f,0.2,eye(48));f:decide(eye(40),500)
  local biggest=0
  for _=1,30 do f:step(1/60,eye(40));biggest=math.max(biggest,g.Size.X.Scale) end
  t.expect.truthy(biggest<=12+1e-9)
  root:Destroy()
 end)
 t.test('up close a lane label shrinks like the gate sign, never under its least size',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0))
  local f=F.new();f:add(g)
  f:decide(eye(17),500);run(f,0.5,eye(17))
  t.expect.near(g.Size.X.Scale,6,0.05)
  f:decide(eye(3),500);run(f,0.5,eye(3))
  t.expect.near(g.Size.X.Scale,12*0.35,0.05)
  root:Destroy()
 end)
 t.test('FadeHold fades a label out and back in; a switched-off label comes back by fading in',function()
  local root=Instance.new('Model')
  local g=lane(root,Vector3.new(0,10,0))
  local f=F.new();f:add(g)
  f:decide(eye(30),500);run(f,0.1,eye(30))
  g:SetAttribute('FadeHold',true);f:decide(eye(30),500);run(f,0.1,eye(30))
  t.expect.truthy(g.Power.TextTransparency>0.1 and g.Power.TextTransparency<1) -- (fading, not switched)
  run(f,F.OUT_TIME,eye(30));t.expect.equal(g.Power.TextTransparency,1);t.expect.truthy(g.Enabled)
  g:SetAttribute('FadeHold',nil);f:decide(eye(30),500);run(f,F.IN_TIME+F.POP_TIME+0.05,eye(30))
  t.expect.equal(g.Power.TextTransparency,0)
  g.Enabled=false;f:decide(eye(30),500);t.expect.equal(g.Power.TextTransparency,1)
  g.Enabled=true;f:decide(eye(30),500);f:step(1/60,eye(30))
  t.expect.truthy(g.Power.TextTransparency>0.8) -- (fading in from nothing)
  run(f,F.IN_TIME+F.POP_TIME,eye(30));t.expect.equal(g.Power.TextTransparency,0)
  root:Destroy()
 end)
 t.test('lanes lined up down the aisle declutter: the nearer stack wins, with hysteresis',function()
  local root=Instance.new('Model')
  local near=lane(root,Vector3.new(0,10,0))
  local far=lane(root,Vector3.new(1,10,-12))
  local side=lane(root,Vector3.new(30,10,10))
  local f=F.new();f:add(near);f:add(far);f:add(side)
  local cam=eye(30)
  f:decide(cam,500);run(f,0.5,cam)
  t.expect.equal(near.Power.TextTransparency,0);t.expect.equal(side.Power.TextTransparency,0)
  -- the first sight is not a fade: the covered one is hidden at once, then waits
  f:decide(cam,500);run(f,F.OUT_TIME+0.05,cam)
  t.expect.equal(far.Power.TextTransparency,1);t.expect.truthy(f:get(far).hidden)
  -- labels of another group, or none, never hide each other
  far:SetAttribute('FadeGroup','Other');f:get(far).stale=true
  f:decide(cam,500);run(f,0.1,cam);f:decide(cam,500);run(f,0.1,cam)
  t.expect.equal(far.Power.TextTransparency,1) -- (showing again waits three decisions: no blinking at an edge)
  f:decide(cam,500);run(f,F.IN_TIME+F.POP_TIME+0.05,cam)
  t.expect.equal(far.Power.TextTransparency,0)
  -- a held stack does not cover the ones behind it
  far:SetAttribute('FadeGroup',nil);f:get(far).stale=true;near:SetAttribute('FadeHold',true)
  for _=1,5 do f:decide(cam,500);run(f,0.1,cam) end
  t.expect.equal(far.Power.TextTransparency,0);t.expect.equal(near.Power.TextTransparency,1)
  -- a single decision that wants it covered doesn't hide it (two running do)
  near:SetAttribute('FadeHold',nil);f:decide(cam,500);run(f,0.1,cam)
  t.expect.falsy(f:get(far).hidden)
  f:decide(cam,500);run(f,0.5,cam);t.expect.truthy(f:get(far).hidden);t.expect.equal(far.Power.TextTransparency,1)
  root:Destroy()
 end)
 t.test('sixty labels standing still cost nothing per frame; remove gives the label back',function()
  local root=Instance.new('Model')
  local f=F.new()
  local list={}
  for i=1,60 do local g=lane(root,Vector3.new((i%10)*14,10,-(i//10)*14),'GunLabel');f:add(g);table.insert(list,g) end
  t.expect.equal(f.count,60)
  local cam=CFrame.lookAt(Vector3.new(0,10,900),Vector3.new(0,10,0))
  f:decide(cam,500);run(f,0.6,cam)
  t.expect.equal(f:awakeCount(),0)
  for _,g in list do t.expect.equal(g.Power.TextTransparency,1) end
  f:remove(list[1]);t.expect.equal(list[1].Power.TextTransparency,0);t.expect.near(list[1].Size.X.Scale,12,1e-9);t.expect.equal(list[1].MaxDistance,250);t.expect.equal(f.count,59)
  list[2]:Destroy();f:decide(cam,500);t.expect.equal(f.count,58)
  -- FadeOff set while running: let go within ten decisions, as built
  list[3]:SetAttribute('FadeOff',true)
  for _=1,10 do f:decide(cam,500) end
  t.expect.equal(f:get(list[3]),nil);t.expect.equal(list[3].Power.TextTransparency,0);t.expect.equal(list[3].MaxDistance,250);t.expect.equal(f.count,57)
  root:Destroy()
 end)
end
