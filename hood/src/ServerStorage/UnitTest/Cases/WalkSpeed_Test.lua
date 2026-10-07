return function(t)
 local S=require(game.ReplicatedStorage.Shared.Config.Skins)
 -- Each look walks a little faster: Roblox's default 16 for Corner Kid, about 24 for the Kingpin, never slower
 -- up the ladder; an unknown id (or none) walks at the default.
 t.test('walk speed starts at 16 and tops out near 24',function()
  t.expect.equal(S.List[1].Id,'CornerKid');t.expect.equal(S.walkSpeed('CornerKid'),16)
  t.expect.near(S.walkSpeed('Kingpin'),24,0.5);t.expect.equal(S.walkSpeed(S.List[#S.List].Id),S.walkSpeed('Kingpin'))
 end)
 t.test('walk speed rises with every look',function()
  local last=0
  for _,s in S.List do local v=S.walkSpeed(s.Id);t.expect.truthy(v>last and v>=16 and v<=24);last=v end
 end)
 t.test('unknown looks walk at the default',function()
  t.expect.equal(S.walkSpeed('NotALook'),16);t.expect.equal(S.walkSpeed(nil),16);t.expect.equal(S.walkSpeed(42),16)
 end)
end
