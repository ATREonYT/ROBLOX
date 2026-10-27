return function(t)
 local R=require(game.ReplicatedStorage.Shared.RebirthRules)
 local Balance=require(game.ReplicatedStorage.Shared.Config.Balance)
 -- Players keep their own avatar (brief 17): walk speed no longer comes from a look. Everyone starts at Roblox's
 -- default 16 and walks a stud and a half a second faster per rebirth, up to 24 (the old top look's speed; Oct 27
 -- pacing: reached at the world's 6th rebirth); never slower
 -- with more rebirths; junk counts as none.
 t.test('walk speed starts at 16 and tops out at 24',function()
  t.expect.equal(Balance.Walk.Base,16);t.expect.equal(R.walkSpeed(0),16);t.expect.equal(R.walkSpeed(1),17.5);t.expect.equal(R.walkSpeed(6),24);t.expect.equal(R.walkSpeed(1e6),24)
 end)
 t.test('walk speed never drops with more rebirths',function()
  local last=0
  for n=0,40 do local v=R.walkSpeed(n);t.expect.truthy(v>=last and v>=16 and v<=24);last=v end
 end)
 t.test('junk rebirth counts walk at the default',function()
  t.expect.equal(R.walkSpeed(nil),16);t.expect.equal(R.walkSpeed('9'),16);t.expect.equal(R.walkSpeed(0/0),16);t.expect.equal(R.walkSpeed(-5),16)
 end)
end
