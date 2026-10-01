local expect={}
function expect.equal(a,b) assert(a==b,string.format('Expected %s; got %s',tostring(b),tostring(a))) end
function expect.truthy(a) assert(a,'Expected truthy value') end
function expect.falsy(a) assert(not a,'Expected falsy value') end
function expect.near(a,b,tolerance) assert(type(a)=='number' and a==a and math.abs(a-b)<=(tolerance or 1e-6),'Values differ') end
function expect.throws(fn) local ok=pcall(fn);assert(not ok,'Expected an error') end
function expect.deepEqual(a,b)
 local function eq(x,y)
  if x==y then return true end
  if type(x)~='table' or type(y)~='table' then return false end
  for k,v in pairs(x) do if not eq(v,y[k]) then return false end end
  for k in pairs(y) do if x[k]==nil then return false end end
  return true
 end
 assert(eq(a,b),'Tables differ')
end
return function(filter,timeout)
 local results={run=0,passed=0,failed=0,failures={}}
 for _,module in ipairs(script.Parent.Cases:GetChildren()) do
  if module:IsA('ModuleScript') and (not filter or string.find(module.Name,filter,1,true)) then
   local t={expect=expect}
   function t.test(name,fn)
    results.run+=1
    local done,ok,err=false,false,nil
    local thread=task.spawn(function() ok,err=pcall(fn);done=true end)
    local start=os.clock()
    while not done and os.clock()-start<(timeout or 5) do task.wait() end
    if not done then task.cancel(thread);ok=false;err='timeout' end
    if ok then results.passed+=1;print('[PASS] '..module.Name..' / '..name)
    else results.failed+=1;table.insert(results.failures,module.Name..' / '..name..': '..tostring(err));warn('[FAIL] '..results.failures[#results.failures]) end
   end
   local ok,err=pcall(function() require(module)(t) end)
   if not ok then results.run+=1;results.failed+=1;table.insert(results.failures,tostring(err));warn(err) end
  end
 end
 print(string.format('[SUMMARY] %d run, %d passed, %d failed',results.run,results.passed,results.failed))
 return results
end
