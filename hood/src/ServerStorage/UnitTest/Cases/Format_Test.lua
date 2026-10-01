return function(t)
 local f=require(game.ReplicatedStorage.Shared.Format).compact
 -- Display the boundaries without misleading suffix overflow.
 for _,row in ipairs({{0,'0'},{999,'999'},{1000,'1K'},{1234,'1.2K'},{999999,'1M'},{-1234,'-1.2K'},{1e12,'1T'},{1e15,'1Qa'},{1e18,'1Qi'}}) do
  t.test('formats '..tostring(row[1]),function() t.expect.equal(f(row[1]),row[2]) end)
 end
 -- Invalid economic values must not silently appear as valid numbers.
 t.test('rejects NaN',function() t.expect.throws(function() f(0/0) end) end)
 t.test('rejects infinity',function() t.expect.throws(function() f(math.huge) end) end)
end
