--!strict
local RateLimiter={}
function RateLimiter.new(capacity: number, refillPerSecond: number, clock)
 assert(capacity>0 and refillPerSecond>0,'Invalid rate limit')
 local buckets={}
 local now=clock or os.clock
 local limiter={}
 function limiter.allow(key)
  local time=now()
  local bucket=buckets[key] or {tokens=capacity,last=time}
  bucket.tokens=math.min(capacity,bucket.tokens+math.max(0,time-bucket.last)*refillPerSecond)
  bucket.last=time;buckets[key]=bucket
  if bucket.tokens<1 then return false end
  bucket.tokens-=1;return true
 end
 function limiter.remove(key) buckets[key]=nil end
 return limiter
end
return RateLimiter
