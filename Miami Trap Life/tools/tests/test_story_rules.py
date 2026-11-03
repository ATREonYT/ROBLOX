# Unit tests for Piece 3 (story: the meet -> first mission): Rules/MissionRules, Rules/CutsceneRules, and checks on
# the data in Config/Missions + Cutscenes/*. Pure Luau run under Lua 5.4 via lupa:
#   pip install lupa && python3 tools/tests/test_story_rules.py
import os, sys, lupa
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
function math.clamp(x,a,b) if x<a then return a elseif x>b then return b end return x end
local V3={}; V3.__index=V3
Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__v3=true},V3) end}
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y) return {X=x,Y=y} end}
CFrame={new=function(...) return {__cf=true, args={...}} end, Angles=function(...) return {__cf=true} end}
setmetatable(CFrame, {})
local CFm={__mul=function(a,b) return {__cf=true} end}
local oldnew=CFrame.new
CFrame.new=function(...) return setmetatable({__cf=true,args={...}},CFm) end
CFrame.Angles=function(...) return setmetatable({__cf=true},CFm) end
Color3={fromRGB=function(r,g,b) return {r,g,b} end}
function typeof(v) if type(v)=="table" and v.__v3 then return "Vector3" end if type(v)=="table" and v.__cf then return "CFrame" end return type(v) end
MODULES={}
function require(m) return MODULES[m] end
''')
REQ = {
    'require(script.Parent.Economy)': 'require("Economy")',
    'require(script.Parent.Parent.Config.Missions)': 'require("Missions")',
}
def load(name, path):
    code = conv(open(SRC + path, encoding='utf-8').read())
    for a, b in REQ.items():
        code = code.replace(a, b)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
for n, p in [('Economy', 'Config/Economy.lua'), ('Story', 'Config/Story.lua'), ('Locations', 'Config/Locations.lua'),
             ('Missions', 'Config/Missions.lua'), ('MissionRules', 'Rules/MissionRules.lua'),
             ('CutsceneRules', 'Rules/CutsceneRules.lua'), ('GangIntro', 'Cutscenes/GangIntro.lua'),
             ('RobberyOutro', 'Cutscenes/RobberyOutro.lua')]:
    load(n, p)

fails = 0
def check(name, cond):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name); fails += (0 if cond else 1)

r = lua.execute(r'''
local R=MODULES.MissionRules; local M=MODULES.Missions; local E=MODULES.Economy; local L=MODULES.Locations
local out={}
local spots=L.MeetSpots
out.pick0 = R.pickSpot(spots,0).Id==spots[1].Id
out.pickHi = R.pickSpot(spots,0.9999).Id==spots[#spots].Id
out.pickAll = (function() local seen={} for i=0,99 do seen[R.pickSpot(spots,i/100).Id]=true end local n=0 for _ in pairs(seen) do n=n+1 end return n==#spots end)()
out.pickEmpty = R.pickSpot({},0.5)==nil
out.find = R.findSpot(spots,"Motel").Id=="Motel" and R.findSpot(spots,"Nope")==nil
local def=M.FirstMission
out.stepIdx = R.stepIndex(def,"Mask")==1 and R.stepIndex(def,"Escape")==#def.Steps and R.stepIndex(def,"x")==nil
out.last = R.isLast(def,#def.Steps) and not R.isLast(def,1)
out.hold = R.holdOk(2,1.5,0.75) and not R.holdOk(2,1.4,0.75)
-- facing: looking north (-Z) at a target north = ok; target south = no; too far = no
out.face1 = R.facingOk(0,0, 0,-1, 0,-10, 0.7, 26)
out.face2 = not R.facingOk(0,0, 0,-1, 0,10, 0.7, 26)
out.face3 = not R.facingOk(0,0, 0,-1, 0,-30, 0.7, 26)
out.face4 = not R.facingOk(0,0, 0,-1, 10,-2, 0.7, 26)
out.face5 = R.facingOk(0,0, 0,0, 0.1,0.1, 0.7, 26) -- standing on it
local take,bonus,clean = R.payout(def, 10)
out.pay1 = take==def.Pay and bonus==def.CleanGetaway.Bonus and clean
take,bonus,clean = R.payout(def, def.CleanGetaway.Seconds+1)
out.pay2 = bonus==0 and not clean
take,bonus,clean = R.payout(def, nil)
out.pay3 = bonus==0 and not clean
out.flat = def.Pay >= E.EndsFlatPrice -- the robbery is what buys the flat (story beat)
local cl = R.checklist(def,2)
out.check = cl[1].done and cl[2].current and not cl[2].done and not cl[3].done and #cl==#def.Steps
out.clock = R.clock(25)=="0:25" and R.clock(61.4)=="1:01" and R.clock(-3)=="0:00"
-- every step: known kind, a point that exists, text; holds/aims have seconds
local ok=true
for _,s in ipairs(def.Steps) do
  if not (s.kind=="hold" or s.kind=="zone" or s.kind=="aim") then ok=false end
  if not def.Points[s.point] then ok=false end
  if type(s.text)~="string" or s.text=="" then ok=false end
  if (s.kind=="hold" or s.kind=="aim") and not (type(s.seconds)=="number" and s.seconds>0 and s.seconds<=6) then ok=false end
  if s.bark and not MODULES.Story.Contacts[s.bark[1]] and s.bark[1]~="Kev" then ok=false end
end
out.steps=ok
out.lastIsEscape = def.Steps[#def.Steps].alarm==true and def.Steps[#def.Steps].kind=="zone"
out.actors = M.Actors.Dre and M.Actors.Smoke and M.Actors.Nina and M.Actors[def.Clerk] and true or false
out.offer = #M.Offer.Items==2
return out
''')
for k in ['pick0','pickHi','pickAll','pickEmpty','find','stepIdx','last','hold','face1','face2','face3','face4','face5',
          'pay1','pay2','pay3','flat','check','clock','steps','lastIsEscape','actors','offer']:
    check('MissionRules/Missions: ' + k, r[k])

c = lua.execute(r'''
local C=MODULES.CutsceneRules; local out={}
out.easeEnds = math.abs(C.ease("Sine",0))<1e-9 and math.abs(C.ease("Sine",1)-1)<1e-9 and math.abs(C.ease("Sine",0.5)-0.5)<1e-9
out.easeClamp = C.ease("Quad",-1)==0 and C.ease("Quad",2)==1
out.easeMono = (function() for _,n in ipairs({"Sine","Quad","QuadIn","QuadOut","Cubic","Linear"}) do local last=-1 for i=0,20 do local v=C.ease(n,i/20) if v<last-1e-9 then return false end last=v end end return true end)()
local items={{t=0},{t=2},{t=5}}
out.idx = C.indexAt(items,-1)==0 and C.indexAt(items,0)==1 and C.indexAt(items,4.9)==2 and C.indexAt(items,9)==3
out.alpha = C.shotAlpha({t=2,dur=4,ease="Linear"},4)==0.5 and C.shotAlpha({t=2},9)==1
local lines={{t=1,text="Hello there",dur=2},{t=5,text="Bye",dur=1.5}}
local l,i=C.lineAt(lines,1.5); out.line1 = l and l.text=="Hello there" and i==1
l,i=C.lineAt(lines,3.5); out.line2 = l==nil and i==1
out.typed = C.typed("Hello",0,0.05)==2 and C.typed("Hello",0,10)==5 and C.typed("Hello",1,0)==0
local tt,fin = C.tapTarget(lines,1.05); out.tapFinish = tt==1.05 and fin
tt,fin = C.tapTarget(lines,2.5); out.tapNext = tt==5 and not fin
tt,fin = C.tapTarget(lines,6); out.tapNone = tt==nil
out.len = C.length({shots={{t=0,dur=3}},lines={{t=2,text="x",dur=4}}})==6 and C.length({length=9})==9
local cr = C.crossed({{t=1},{t=2},{t=3}},1,2.5); out.crossed = #cr==1 and cr[1].t==2
out.valBad = #C.validate({shots={{t=1,ease="Linear",fov=100}},lines={{t=2,text=""}}})>=3
return out
''')
for k in ['easeEnds','easeClamp','easeMono','idx','alpha','line1','line2','typed','tapFinish','tapNext','tapNone','len','crossed','valBad']:
    check('CutsceneRules: ' + k, c[k])

for scene in ['GangIntro', 'RobberyOutro']:
    probs = lua.execute('''
local s=MODULES["%s"]; local sp={}
for k in pairs(MODULES.Story.Contacts) do sp[k]=true end
sp.Kev=true
local p=MODULES.CutsceneRules.validate(s, sp)
local out={} for i,v in ipairs(p) do out[i]=v end
out.n=#p; out.len=MODULES.CutsceneRules.length(s)
return out''' % scene)
    msgs = [probs[i] for i in range(1, probs['n'] + 1)]
    check(f'Cutscene {scene} validates ({probs["len"]:.1f} s)' + ('' if not msgs else ': ' + '; '.join(msgs)), probs['n'] == 0)

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
