# Unit tests for the day-night cycle: Rules/DayNightRules + Config/DayNight (phases cover the day, the clock is
# continuous and invertible, every keyframe has every field, the look blends smoothly, story hours land in the right
# phase). Pure Luau under Lua 5.4:
#   pip install lupa && python3 tools/tests/test_daynight_rules.py
import os, sys, re, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luau2lua import conv
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'ReplicatedStorage', 'MTL') + '/'
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
__ifx = function(c,a,b) if c then return a() else return b() end end
function __iter(t)
  local n=#t; local i=0; local keys={}
  for k in pairs(t) do if not (math.type(k)=="integer" and k>=1 and k<=n) then keys[#keys+1]=k end end
  local j=0
  return function()
    if i<n then i=i+1; return i,t[i] end
    j=j+1; local k=keys[j]; if k~=nil then return k,t[k] end
  end
end
local V3={}
V3.__index=V3
V3.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
V3.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__v3=true},V3) end}
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y) return {X=x,Y=y} end}
Color3={fromRGB=function(r,g,b) return {r,g,b} end, new=function(r,g,b) return {r,g,b} end}
function typeof(v) if type(v)=="table" and v.__v3 then return "Vector3" end if type(v)=="table" and v.__cf then return "CFrame" end return type(v) end
local anyEnum=setmetatable({},{__index=function(t,k) return k end})
Enum=setmetatable({KeyCode={M="M",DPadUp="DPadUp"}},{__index=function() return anyEnum end})
local CF={}; CF.__index=CF; CF.__mul=function(a,b) return a end
CFrame={new=function(...) return setmetatable({__cf=true},CF) end, Angles=function(...) return setmetatable({__cf=true},CF) end}
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
table.clone=function(t) local o={} for k,v in pairs(t) do o[k]=v end return o end
table.find=function(t,v) for i=1,#t do if t[i]==v then return i end end return nil end
MODULES={}
function require(m) return MODULES[m] end
Color3.fromRGB=function(r,g,b) return {r,g,b,__c3=true} end
''')
def load(name, path):
    code = conv(open(SRC + path, encoding='utf-8').read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
load('DayNight', 'Config/DayNight.lua')
load('DayNightRules', 'Rules/DayNightRules.lua')

fails = 0
def check(name, cond):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name); fails += (0 if cond else 1)

r = lua.execute(r'''
local D=MODULES.DayNight; local R=MODULES.DayNightRules; local out={}
-- phases: in clock order, back to back, covering exactly 24 hours
local cover, chained = 0, true
for i,p in ipairs(D.Phases) do
  cover = cover + (p.to - p.from)
  local nxt = D.Phases[i+1]
  if nxt and math.abs(nxt.from - p.to) > 1e-9 then chained=false end
end
out.cover24 = math.abs(cover - 24) < 1e-9
out.chained = chained and math.abs((D.Phases[#D.Phases].to - 24) - D.Phases[1].from) < 1e-9
local total = R.cycleSeconds()
out.cycleLen = total >= 15*60 and total <= 45*60
local dayShare = 0
for _,p in ipairs(D.Phases) do if p.id=="Day" then dayShare = p.minutes*60/total end end
out.dayLongest = dayShare >= 0.35
-- clock is continuous over the whole cycle (no jumps bigger than one step's worth)
local cont, prev = true, R.clockAt(0)
for s=1,total do
  local c = R.clockAt(s)
  local d = (c - prev) % 24
  if d > 0.05 then cont=false end
  prev = c
end
out.continuous = cont
out.wraps = math.abs(R.clockAt(total) - R.clockAt(0)) < 1e-9
-- inverse round-trips
local inv = true
for h=0,23.75,0.25 do
  local back = R.clockAt(R.positionFor(h))
  if math.abs(((back - h + 12) % 24) - 12) > 1e-6 then inv=false end
end
out.inverse = inv
-- phases
out.phaseNoon = R.phaseOf(12)=="Day" and R.phaseOf(7)=="Morning" and R.phaseOf(18)=="Evening"
out.phaseNight = R.phaseOf(23)=="Night" and R.phaseOf(2)=="Night" and R.phaseOf(5.5)=="Night"
out.start = R.phaseOf(D.StartClock)=="Morning"
out.storyHours = R.phaseOf(D.Story.MoveIn)=="Night" and R.phaseOf(D.Story.Sleep)=="Night" and R.phaseOf(D.Story.Wake)=="Morning"
-- keys: sorted, inside 0-24, and every key has the same fields as the first
local fields = {}
for k,_ in pairs(D.Keys[1]) do fields[#fields+1]=k end
local sorted, complete = true, true
for i,k in ipairs(D.Keys) do
  if k.at < 0 or k.at >= 24 then sorted=false end
  if i>1 and k.at <= D.Keys[i-1].at then sorted=false end
  for _,f in ipairs(fields) do if k[f]==nil then complete=false end end
  for f,_ in pairs(k) do if D.Keys[1][f]==nil then complete=false end end
end
out.keysSorted = sorted
out.keysComplete = complete
-- sample: exact on a key, alpha in range everywhere, and wraps midnight
local a,b,t = R.sample(12); out.sampleDay = a.at==9.8 and t>0 and t<1
local okA = true
for h=0,23.95,0.05 do local _,_,x = R.sample(h); if x<0 or x>1 then okA=false end end
out.alpha = okA
a,b,t = R.sample(22); out.sampleWrap = a.at==19.7 and b.at==0
-- night is darker than day, lamps on at night only
local function at(h) local a,b,t = R.sample(h); return a.Brightness+(b.Brightness-a.Brightness)*t, a.Lamps+(b.Lamps-a.Lamps)*t end
local bn, ln = at(23); local bd, ld = at(12)
out.nightDarker = bn < bd
out.lamps = ln >= 1 and ld == 0
-- clockDelta takes the short way round
out.delta = math.abs(R.clockDelta(23, 1) - 2) < 1e-9 and math.abs(R.clockDelta(1, 23) + 2) < 1e-9
-- lamps config
out.lampCfg = D.Lamps.MaxLights <= 64 and D.Lamps.Shadows <= D.Lamps.MaxLights and D.Lamps.Models.StreetLight == true
return out
''')
for k in sorted(r.keys()):
    check(k, r[k])
print('\n%d failed' % fails)
sys.exit(1 if fails else 0)
