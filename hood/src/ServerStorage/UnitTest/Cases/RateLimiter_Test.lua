return function(t)
 local R=require(game.ServerScriptService.HoodServer.RateLimiter)
 -- Excess bursts are refused, then a token refills after one second.
 t.test('limits bursts and refills over time',function() local now=0;local l=R.new(2,1,function() return now end);t.expect.truthy(l.allow('a'));t.expect.truthy(l.allow('a'));t.expect.falsy(l.allow('a'));now=1;t.expect.truthy(l.allow('a'));t.expect.falsy(l.allow('a')) end)
 -- One player's requests must not consume another player's budget.
 t.test('budgets are independent',function() local l=R.new(1,1,function() return 0 end);l.allow('a');t.expect.truthy(l.allow('b')) end)
end
