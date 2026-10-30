-- Oct 27, the owner: footsteps "exactly when a step is taken on screen". FootstepRules hears a step the frame the
-- falling foot reaches the ground, at any walk rate, and none while standing, swaying or in the air.
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local R=require(RS.Shared.FootstepRules)
 local Sound=require(RS.Shared.Config.Sound)
 -- a foot in a walk cycle: on the ground (-3) for half the cycle, lifted 0.6 studs in the other half
 local function height(time,period,phase)
  local p=((time/period)+phase)%1
  return p<0.5 and -3 or -3+0.6*math.sin((p-0.5)*2*math.pi)
 end
 local function run(period,frames,dt,moving,amp)
  local f=R.foot();local hits={}
  for i=1,frames do
   local time=i*dt
   local h=amp and (-3+amp*math.sin(time*2*math.pi/period)) or height(time,period,0)
   if R.step(f,h,dt,moving) then table.insert(hits,time) end
  end
  return hits
 end
 t.test('a step is heard once per cycle, as the foot touches down',function()
  local hits=run(0.8,600,1/60,true)
  t.expect.truthy(#hits>=11 and #hits<=13) -- 10 s of a 0.8 s cycle
  for i=2,#hits do t.expect.near(hits[i]-hits[i-1],0.8,1/30) end
  -- the foot lands at the cycle's start; the sound is within 30 ms of it (people notice sound off the picture from ~45 ms)
  for _,time in hits do local p=(time/0.8)%1;t.expect.truthy(math.min(p,1-p)*0.8<=0.03) end
 end)
 t.test('a run (faster cycle) and a slow frame rate still land once per cycle',function()
  t.expect.truthy(#run(0.45,600,1/60,true)>=21)
  local slow=run(0.8,300,1/30,true)
  t.expect.truthy(#slow>=11 and #slow<=13)
 end)
 t.test('no steps standing still, swaying, or when not moving on the ground',function()
  t.expect.equal(#run(0.8,600,1/60,false),0) -- in the air or stopped
  t.expect.equal(#run(2,600,1/60,true,0.04),0) -- an idle sway: too small a swing
 end)
 t.test('soft set for grass, dirt and sand; hard for floors',function()
  t.expect.truthy(R.soft(Enum.Material.Grass));t.expect.truthy(R.soft('Sand'))
  t.expect.falsy(R.soft(Enum.Material.Plastic));t.expect.falsy(R.soft('Concrete'));t.expect.falsy(R.soft(nil))
 end)
 t.test('footsteps have their own switch; no id, no sound (Roblox footsteps stay)',function()
  t.expect.equal(Sound.Footsteps,true)
  t.expect.equal(Sound.step('',0.4,workspace),nil)
  for _,k in {'StepHard1','StepHard2','StepHard3','StepSoft1','StepSoft2','StepSoft3'} do t.expect.equal(type(Sound.Steps[k]),'string') end
 end)
end
