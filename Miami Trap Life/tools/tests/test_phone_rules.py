# Unit tests for Rules/PhoneRules (pure Luau) run under Lua 5.4 via lupa:  pip install lupa && python3 tools/tests/test_phone_rules.py
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luau2lua import conv
SRC=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','src','ReplicatedStorage','MTL')+'/'
lua=lupa.LuaRuntime(unpack_returned_tuples=True)
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
local V3={}; V3.__index=V3
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z,__v3=true},V3) end}
Vector2={new=function(x,y) return {X=x,Y=y} end}
function typeof(v) if type(v)=="table" and v.__v3 then return "Vector3" end return type(v) end
Enum={KeyCode={M="M",DPadUp="DPadUp"}}
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code=conv(open(SRC+path).read())
    code=code.replace('require(script.Parent.Parent.Config.Phone)','require("Phone")').replace('require(script.Parent.StoryRules)','require("StoryRules")').replace('require(script.Parent.Parent.Config.Story)','require("Story")')
    f=lua.execute('return function() '+code+'\nend')
    lua.globals().MODULES[name]=f()
for n,p in [('Story','Config/Story.lua'),('StoryRules','Rules/StoryRules.lua'),('Phone','Config/Phone.lua'),('Locations','Config/Locations.lua'),('PhoneRules','Rules/PhoneRules.lua')]:
    load(n,p)
fails=0
def check(name, cond):
    global fails
    print(('ok   ' if cond else 'FAIL ')+name); fails+= (0 if cond else 1)
r=lua.execute('''
local R=MODULES.PhoneRules; local out={}
local th={}; for i=1,70 do R.appendText(th,{text="m"..i,t=i}) end
out.trim = (#th==60 and th[1].text=="m11" and th[60].text=="m70")
local rec={}; for i=1,35 do R.addRecent(rec,{call="Recruit",kind="missed",callBack=true,seen=false,t=i}) end
out.recentsTrim = (#rec==30 and rec[1].t==35)
out.missed = R.missedCount({Recents=rec})==30
R.clearCallBack(rec,"Recruit")
out.clearCB = R.findCallBack(rec,"Recruit")==nil
R.addRecent(rec,{call="Recruit",kind="declined",callBack=true,t=99})
out.findCB = R.findCallBack(rec,"Recruit").t==99
out.unread = R.unreadTotal({Unread={Patel=2,Dre=3}})==5
local b=R.badges({Unread={Patel=1},Recents={{kind="missed",seen=false},{kind="missed",seen=true}}})
out.badges = b.Messages==1 and b.Calls==1
local ts=R.threads({Texts={Patel={{text="a",t=5}},Dre={{text="b",t=9}}},Unread={Dre=1}})
out.threads = ts[1].contact=="Dre" and ts[1].unread==1 and ts[2].contact=="Patel"
out.ago = R.ago(5)=="now" and R.ago(300)=="5m" and R.ago(7200)=="2h" and R.ago(200000)=="2d"
out.clock = R.clock(0)=="12:00 AM" and R.clock(13*60+5)=="1:05 PM" and R.clock(12*60)=="12:00 PM" and R.clock(1440+61)=="1:01 AM"
local home=R.place("Home")
out.placeHidden = not R.placeVisible(home,"Arrive",false)
out.placeShown = R.placeVisible(home,"FindAPlace",false) and R.placeVisible(R.place("FoodMart"),"Arrive",false)
local pos,rad=R.placePosition(R.place("FoodMart"),MODULES.Locations)
out.placePos = pos.X==-1442 and pos.Z==-330 and rad==14
out.noPlace = R.place("Nope")==nil
out.choice = R.validChoice("Recruit","accept") and R.validChoice("Recruit","decline") and not R.validChoice("Recruit","x") and not R.validChoice("Nope","accept") and not R.validChoice(5,"accept")
local ok1,why1=R.canSwitchPath("FirstShift","Civilian","Criminal",-1e9,0)
out.pathLocked = (not ok1) and why1=="Unlocks after your first mission"
local ok2=R.canSwitchPath("FreePlay","Civilian","Criminal",-1e9,0)
out.pathOk = ok2
local ok3,why3=R.canSwitchPath("FreePlay","Civilian","Criminal",100,110)
out.pathCooldown = (not ok3) and why3=="Wait 20s to switch again"
local ok4=R.canSwitchPath("FreePlay","Criminal","Criminal",-1e9,0)
local ok5=R.canSwitchPath("FreePlay","Civilian","Hacker",-1e9,0)
out.pathBad = (not ok4) and (not ok5)
out.pathAtMissionDone = R.canSwitchPath("MissionDone","Civilian","Criminal",-1e9,0)
out.setting = R.validSetting("Sound",false) and not R.validSetting("Sound","no") and not R.validSetting("Cash",1)
local info,idx=R.appInfo("Map")
out.appInfo = info.title=="GPS" and idx==4 and R.appInfo("X")==nil
return out
''')
for k in sorted(r.keys()):
    check(k, r[k])
print('fails', fails)
sys.exit(1 if fails else 0)
