# Unit tests for Piece 4 (the Ends: the flat, move-in, choose job, sleep, commute, FreePlay goals):
# Rules/PropertyRules, Rules/GoalRules, Config/Property + Config/Goals, and the PowerOut / NextDay cutscenes
# (validated with CutsceneRules, and every "#Mark" checked against the room's points). Pure Luau under Lua 5.4:
#   pip install lupa && python3 tools/tests/test_flat_rules.py
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
''')
def load(name, path):
    code = conv(open(SRC + path, encoding='utf-8').read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
for n, p in [('Economy', 'Config/Economy.lua'), ('Story', 'Config/Story.lua'), ('StoryRules', 'Rules/StoryRules.lua'),
             ('Locations', 'Config/Locations.lua'), ('Levels', 'Config/Levels.lua'), ('Jobs', 'Config/Jobs.lua'),
             ('Property', 'Config/Property.lua'), ('PropertyRules', 'Rules/PropertyRules.lua'),
             ('Goals', 'Config/Goals.lua'), ('GoalRules', 'Rules/GoalRules.lua'),
             ('CutsceneRules', 'Rules/CutsceneRules.lua'), ('PowerOut', 'Cutscenes/PowerOut.lua'),
             ('NextDay', 'Cutscenes/NextDay.lua'), ('Phone', 'Config/Phone.lua')]:
    load(n, p)

fails = 0
def check(name, cond):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name); fails += (0 if cond else 1)

r = lua.execute(r'''
local P=MODULES.Property; local R=MODULES.PropertyRules; local E=MODULES.Economy; local S=MODULES.Story
local J=MODULES.Jobs; local L=MODULES.Locations; local out={}
local function save(stage, cash, owned) return { Cash=cash, Story={Stage=stage}, Home={Owned=owned or {}, PowerOn=false}, Path="Civilian" } end
-- buying
local ok,why,short = R.canBuy(save("FindAPlace", 1500), "EndsFlat"); out.buyOk = ok and short==0
ok,why,short = R.canBuy(save("FindAPlace", 1000), "EndsFlat"); out.buyShort = (not ok) and short==200
ok,why,short = R.canBuy(save("FirstShift", 9999), "EndsFlat"); out.buyEarly = not ok
ok,why,short = R.canBuy(save("FreePlay", 9999, {EndsFlat=1}), "EndsFlat"); out.buyTwice = not ok
ok = R.canBuy(save("FindAPlace", 9999), "Mansion"); out.buyUnknown = not ok
out.price = P.Homes.EndsFlat.price == E.EndsFlatPrice
-- the story beat: the robbery pays for the flat, and what's left (+ start cash) covers the first goal (power)
out.flatPaid = E.FirstMissionPay >= E.EndsFlatPrice
out.powerReachable = E.PowerBill <= (E.FirstMissionPay - E.EndsFlatPrice) + E.StartCash
-- slots
local a,b = R.slotOrigin(1), R.slotOrigin(2)
out.slotSpacing = (b.X - a.X) == P.Slots.Spacing and b.Y == a.Y and b.Z == a.Z
out.slotsApart = P.Slots.Spacing > P.Interior.Size.X + 40
out.free1 = R.freeSlot({}) == 1 and R.freeSlot({[1]=true,[2]=true}) == 3 and R.freeSlot({[1]=true,[3]=true}) == 2
local full = {} for i=1,P.Slots.Max do full[i]=true end
out.freeFull = R.freeSlot(full) == nil
-- far from the map (rooms must never overlap Vice Bay; the map sits within ~3000 studs of the origin)
out.slotsFar = math.abs(P.Slots.Origin.X) > 4000 or math.abs(P.Slots.Origin.Z) > 4000
-- every interior point inside the room box, floor spots on the floor
local okPts, floorOk = true, true
for name, p in pairs(P.Interior.Points) do
  if math.abs(p.X) > P.Interior.Size.X/2 or math.abs(p.Z) > P.Interior.Size.Z/2 or p.Y < 0 or p.Y > P.Interior.Size.Y then okPts=false end
end
for _, name in ipairs({"Entry","Exit","ChairSpot","BedSpot","BedStand"}) do
  if P.Interior.Points[name] == nil or P.Interior.Points[name].Y ~= 0 then floorOk=false end
end
out.points = okPts; out.floorSpots = floorOk
local o = Vector3.new(100, 50, 100)
out.inside = R.insideRoom(o, o + Vector3.new(5, 2, -5)) and not R.insideRoom(o, o + Vector3.new(60, 0, 0))
-- door text + home spawn
out.doorText = R.doorText(save("FindAPlace", 0), "EndsFlat") == "For sale · $1200" and R.doorText(save("FreePlay", 0, {EndsFlat=1}), "EndsFlat") == "Go inside"
out.spawnHome = R.spawnsAtHome(save("ChooseJob", 0, {EndsFlat=1})) and not R.spawnsAtHome(save("FindAPlace", 0, {})) and not R.spawnsAtHome(save("FirstShift", 0, {EndsFlat=1}))
-- locations
out.locs = L.EndsFlat.Door ~= nil and L.EndsFlat.Out ~= nil
-- story wiring: every starter job has a story line on its card and a boss who texts on the morning
local hooks, wake = true, true
for _, id in ipairs(J.StarterJobs) do
  if type(P.JobHooks[id]) ~= "string" then hooks=false end
  local boss = J.Defs[id].boss
  if not (boss and S.Contacts[boss] and P.Texts.Wake[boss]) then wake=false end
end
out.hooks = hooks and #J.StarterJobs == 3; out.wake = wake
out.texts = S.Contacts[P.Texts.FreePlay.who] ~= nil and S.Contacts[P.Texts.FindAPlace[1].who] ~= nil
out.storyJob = table.find(J.StarterJobs, J.StoryJob) ~= nil -- the store you robbed is one of the 3 choices
out.blocked = J.BlockedStages.MoveIn and J.BlockedStages.FirstNight and not J.BlockedStages.ChooseJob and not J.BlockedStages.CommuteToWork
-- the phone: a Goals app that starts hidden; the Home place exists
local goalsApp=false for _,a in ipairs(MODULES.Phone.Apps) do if a.id=="Goals" and a.default==false then goalsApp=true end end
out.goalsApp = goalsApp
local home=false for _,p in ipairs(MODULES.Phone.Places) do if p.id==P.Homes.EndsFlat.place then home=true end end
out.homePlace = home
return out
''')
for k in ['buyOk','buyShort','buyEarly','buyTwice','buyUnknown','price','flatPaid','powerReachable','slotSpacing','slotsApart',
          'free1','freeFull','slotsFar','points','floorSpots','inside','doorText','spawnHome','locs','hooks','wake','texts',
          'storyJob','blocked','goalsApp','homePlace']:
    check('Property: ' + k, r[k])

g = lua.execute(r'''
local G=MODULES.Goals; local R=MODULES.GoalRules; local out={}
local function save(t) local d={Cash=0,Level=1,Path="Civilian",Home={Owned={EndsFlat=1},PowerOn=false},Job={Current="Mechanic",Shifts={}},Inventory={Guns={}},Goals={Done={}},Story={Stage="FreePlay"}}
  for k,v in pairs(t or {}) do d[k]=v end return d end
-- ids unique, kinds known, actions known
local ids, okKinds, okActs = {}, true, true
local kinds={power=true,shifts=true,level=true,cash=true,guns=true,car=true,soon=true}
for _, g in ipairs(G.List) do
  if ids[g.id] then okKinds=false end ids[g.id]=true
  if not kinds[g.kind] then okKinds=false end
  if g.action and not (g.action.kind=="payPower" or g.action.kind=="route" or g.action.kind=="app") then okActs=false end
  if g.kind ~= "soon" and type(g.reward) ~= "number" then okKinds=false end
  if g.kind == "soon" and (g.action or g.reward) then okKinds=false end -- nothing fake to press or earn
end
out.defs = okKinds; out.acts = okActs
-- a fresh FreePlay save (you just clocked in at your new job): the top goal is finishing that shift
local d = save({Cash=120})
local top = R.top(d)
out.topShift = top and top.id=="FirstShift" and R.objective(d) == "Goal: Finish a full shift  (0 / 1)"
-- shift done -> the power bill, with cash progress on the HUD line
d = save({Cash=120, Job={Current="Mechanic",Shifts={Mechanic=1}}})
out.next = R.top(d).id == "Power"
out.objective = R.objective(d) == "Goal: Turn the power on  ($120 / $300)"
-- newlyDone: done but not claimed; claimed ones stay done even after the cash is spent
d = save({Cash=6000, Home={Owned={EndsFlat=1},PowerOn=true}})
local nd = R.newlyDone(d); local seen={} for _,e in ipairs(nd) do seen[e.id]=true end
out.newly = seen.Power and seen.Save5k and not seen.FirstShift
d = save({Cash=10, Goals={Done={Save5k=1}}})
local save5k for _,e in ipairs(R.evaluate(d)) do if e.id=="Save5k" then save5k=e end end
out.claimedSticks = save5k.done and save5k.claimed and #R.newlyDone(save({Cash=10, Goals={Done={Save5k=1}}})) == 0
-- soon goals are never the top goal and never "done"
local allDone = save({Cash=99999, Level=99, Home={Owned={EndsFlat=1},PowerOn=true}, Job={Current="Mechanic",Shifts={Mechanic=3}}, Inventory={Guns={Pistol=true,Uzi=true}}, Garage={Owned={Cafe=true,Cruiser=true},Bought={Cruiser=true}}})
out.noSoonTop = R.top(allDone) == nil and R.objective(allDone) == ""
local soonOk=true for _,e in ipairs(R.evaluate(allDone)) do if e.soon and e.done then soonOk=false end end
out.soonNeverDone = soonOk
-- path filter: the criminal-only goals don't show for civilians
local civ, crim = 0, 0
for _,e in ipairs(R.evaluate(save({Path="Civilian"}))) do if e.id=="SecondGun" or e.id=="NextJob" then civ=civ+1 end end
for _,e in ipairs(R.evaluate(save({Path="Criminal"}))) do if e.id=="SecondGun" or e.id=="NextJob" then crim=crim+1 end end
out.path = civ==0 and crim==2
-- progress clamps to 0..1
local pOk=true for _,e in ipairs(R.evaluate(save({Cash=1e9, Level=500}))) do if e.progress<0 or e.progress>1 then pOk=false end end
out.clamp = pOk
-- first car: cash progress toward the cheapest car; the free bike doesn't count; a bought car does
local fc = function(dd) for _,e in ipairs(R.evaluate(dd)) do if e.id=="FirstCar" then return e end end end
local a = fc(save({Cash=1000, Garage={Owned={Cafe=true}}}))
local b = fc(save({Cash=0, Garage={Owned={Cafe=true,Cruiser=true},Bought={Cruiser=true}}}))
out.firstCar = (not a.done) and (not a.soon) and a.progressText=="$1,000 / $2,500" and b.done
out.money = R.money(1200)=="$1,200" and R.money(50)=="$50" and R.money(1234567)=="$1,234,567"
return out
''')
for k in ['defs','acts','topShift','next','objective','newly','claimedSticks','noSoonTop','soonNeverDone','path','clamp','firstCar','money']:
    check('Goals: ' + k, g[k])

for scene in ['PowerOut', 'NextDay']:
    probs = lua.execute('''
local s=MODULES["%s"]; local sp={}
for k in pairs(MODULES.Story.Contacts) do sp[k]=true end
local p=MODULES.CutsceneRules.validate(s, sp)
local out={} for i,v in ipairs(p) do out[i]=v end
-- every mark the scene uses exists in the room's points
local pts=MODULES.Property.Interior.Points
local function chk(v) if type(v)=="string" and v:sub(1,1)=="#" then if not pts[v:sub(2)] then out[#out+1]="unknown mark "..v end
  elseif type(v)=="table" and v.mark then if not pts[v.mark] then out[#out+1]="unknown mark "..v.mark end end end
for _,a in pairs(s.actors or {}) do chk(a.at); chk(a.face) end
for _,a in ipairs(s.actions or {}) do chk(a.walk); chk(a.turn) end
for _,sh in ipairs(s.shots or {}) do for _,c in ipairs({sh.from, sh.to}) do if c then chk(c.pos); chk(c.look) end end end
-- custom beats used by the scene are ones PropertyController registers
local known={BulbFlicker=true,BulbOff=true,PcPower=true,KeyboardBounce=true,PhoneOut=true,MorningLight=true,WorldMorning=true}
for _,a in ipairs(s.actions or {}) do if a.call and not known[a.call] then out[#out+1]="unknown beat "..a.call end end
out.n=#out; out.len=MODULES.CutsceneRules.length(s)
return out''' % scene)
    msgs = [probs[i] for i in range(1, probs['n'] + 1)]
    check(f'Cutscene {scene} validates ({probs["len"]:.1f} s)' + ('' if not msgs else ': ' + '; '.join(msgs)), probs['n'] == 0)

# the gag's comedy timing (Research: Cutscenes): a hold on the dead screen before the smash, 3 smash hits, 8-16 s
t = lua.execute(r'''
local s=MODULES.PowerOut; local out={}
local press, smash, keys = nil, nil, 0
for _,a in ipairs(s.actions) do
  if a.gesture=="Press" and not press then press=a.t end
  if a.gesture=="Smash" then smash=a.t end
  if a.sound=="Keys" then keys=keys+1 end
end
out.pause = press and smash and (smash - press) >= 2.5
out.hits = keys == 3
out.len = s.length >= 8 and s.length <= 18
out.endsOnPhone = s.actions[#s.actions].call == "PhoneOut" or s.actions[#s.actions-1].call == "PhoneOut"
local n=MODULES.NextDay; local title=false
for _,a in ipairs(n.actions) do if a.title=="NEXT DAY" then title=true end end
out.nextDay = title and n.length <= 12
return out
''')
for k in ['pause', 'hits', 'len', 'endsOnPhone', 'nextDay']:
    check('Timing: ' + k, t[k])

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
