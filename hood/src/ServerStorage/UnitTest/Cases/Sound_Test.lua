-- Brief 18: "remove these bad sound effects, we will work on better sound effects later". Every game sound is behind
-- Shared/Config/Sound (Enabled = false): nothing makes a Sound but that module and ShotSounds, and both make nothing
-- while it is off.
return function(t)
 local RS=game:GetService('ReplicatedStorage')
 local Sound=require(RS.Shared.Config.Sound)
 t.test('sounds are off: nothing is created and nothing plays',function()
  t.expect.equal(Sound.Enabled,false)
  t.expect.equal(Sound.new('rbxasset://sounds/electronicpingshort.wav',0.5,workspace),nil)
  Sound.play(nil);Sound.play(nil,1.2) -- (nil-safe)
  local ShotSounds=require(RS.Shared.ShotSounds)
  t.expect.equal(ShotSounds.init(),nil);ShotSounds.play('Shot',1)
  t.expect.equal(game:GetService('SoundService'):FindFirstChild('Shots'),nil)
 end)
 t.test('no script makes its own Sound: they all go through Config/Sound',function()
  local found={}
  local roots={RS:FindFirstChild('Shared'),game:GetService('StarterPlayer'):FindFirstChild('StarterPlayerScripts'),game:GetService('ServerScriptService')}
  for _,root in roots do
   for _,s in (root and root:GetDescendants() or {}) do
    if s:IsA('LuaSourceContainer') and s.Name~='Sound' and s.Name~='ShotSounds' and s.Name~='Sound_Test' then
     local ok,src=pcall(function() return s.Source end)
     if ok and type(src)=='string' and (src:find("Instance.new('Sound')",1,true) or src:find('Instance.new("Sound")',1,true)) then table.insert(found,s:GetFullName()) end
    end
   end
  end
  t.expect.equal(table.concat(found,', '),'')
 end)
end
