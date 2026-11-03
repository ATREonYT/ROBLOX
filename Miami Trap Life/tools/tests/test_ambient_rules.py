# Unit tests for the living neighbourhood: Rules/AmbientRules + Config/Ambient (+ Config/AmbientMap when present):
# paths sample and wrap correctly, cars slow into corners and stop for blockers, spawns never pop in view, the crowd
# follows the clock, night windows land in the right share and switch off late, no pure colours, budgets hold.
#   pip install lupa && python3 tools/tests/test_ambient_rules.py
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
Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__v3=true},V3) end}
local CF={}; CF.__index=CF
CFrame={new=function(x,y,z) return setmetatable({__cf=true,X=x,Y=y,Z=z},CF) end}
Color3={fromRGB=function(r,g,b) return {r=r,g=g,b=b,__c3=true} end}
math.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
table.clone=function(t) local o={} for k,v in pairs(t) do o[k]=v end return o end
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code = conv(open(SRC + path, encoding='utf-8').read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
load('Ambient', 'Config/Ambient.lua')
load('AmbientRules', 'Rules/AmbientRules.lua')
has_map = os.path.exists(SRC + 'Config/AmbientMap.lua')
if has_map:
    load('AmbientMap', 'Config/AmbientMap.lua')
load('Locations', 'Config/Locations.lua')

fails = 0
def check(name, cond):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name); fails += (0 if cond else 1)

r = lua.execute(r'''
local A=MODULES.Ambient; local R=MODULES.AmbientRules; local out={}
local function near(a,b,e) return math.abs(a-b) < (e or 1e-6) end
-- a 100 x 50 rectangle loop, corners at every point
local sq = R.path({{0,0},{100,0},{100,50},{0,50}}, true, {1,2,3,4})
out.loopLength = near(sq.total, 300)
local x,z,dx,dz = R.sample(sq, 50); out.sampleMid = near(x,50) and near(z,0) and near(dx,1) and near(dz,0)
x,z,dx,dz = R.sample(sq, 125); out.sampleSecond = near(x,100) and near(z,25) and near(dz,1)
x,z = R.sample(sq, 310); out.wraps = near(x,10) and near(z,0)
x,z = R.sample(sq, -10); out.wrapsBack = near(x,0) and near(z,10)
local open = R.path({{0,0},{10,0},{10,10}}, false)
out.openLength = near(open.total, 20)
x,z = R.sample(open, 99); out.openClamps = near(x,10) and near(z,10)
-- corners: at d=80 the next corner (point 2 at d=100) is 20 ahead
out.cornerAhead = near(R.cornerAhead(sq, 80, 60), 20)
out.cornerFar = R.cornerAhead(sq, 20, 30) == math.huge
out.cornerWraps = near(R.cornerAhead(sq, 290, 60), 10) -- point 1 again after the loop closes
local T = A.Traffic
local cruise = 28
out.cruise = near(R.targetSpeed(cruise, math.huge, T), cruise)
local slow = R.targetSpeed(cruise, 0, T)
out.cornerSlow = near(slow, cruise*T.CornerSpeed) and slow > 6
out.cornerEases = R.targetSpeed(cruise, T.CornerSlowDist*0.5, T) > slow and R.targetSpeed(cruise, T.CornerSlowDist*0.5, T) < cruise
out.stopsForBlock = R.targetSpeed(cruise, math.huge, T, 3) == 0
out.slowsForBlock = R.targetSpeed(cruise, math.huge, T, T.StopAhead-2) < cruise
out.ignoresFarBlock = near(R.targetSpeed(cruise, math.huge, T, T.StopAhead+5), cruise)
out.approach = near(R.approach(0, 10, 5, 20, 1), 5) and near(R.approach(10, 0, 5, 20, 0.25), 5) and near(R.approach(9, 10, 5, 20, 1), 10)
-- nearest point on a path
local d, dist = R.nearest(sq, 40, -7); out.nearest = near(d, 40) and near(dist, 7)
-- spawn visibility
local P = A.People
out.spawnFar = R.hiddenSpawn(0, -100, 0, -1, P.MinSpawnDist, P.BehindDot)
out.spawnInFront = not R.hiddenSpawn(0, -30, 0, -1, P.MinSpawnDist, P.BehindDot)
out.spawnBehind = R.hiddenSpawn(0, 30, 0, -1, P.MinSpawnDist, P.BehindDot)
out.spawnSide = not R.hiddenSpawn(30, -10, 0, -1, P.MinSpawnDist, P.BehindDot)
out.spawnOnCamera = not R.hiddenSpawn(0, 0, 0, -1, P.MinSpawnDist, P.BehindDot)
-- crowd
out.crowdNoon = R.crowd(P.Max, 12, P.Crowd) == P.Max
out.crowdLate = R.crowd(P.Max, 3, P.Crowd) <= math.ceil(P.Max*0.25)
out.crowdEvening = R.crowd(P.Max, 22, P.Crowd) < P.Max and R.crowd(P.Max, 22, P.Crowd) > R.crowd(P.Max, 3, P.Crowd)
out.crowdWraps = R.crowd(P.Max, 24, P.Crowd) == R.crowd(P.Max, 0, P.Crowd)
-- hash: deterministic and spread out
local sum, lo, hi, same = 0, 1, 0, true
for i=1,2000 do local h=R.hash(i, 5); sum=sum+h; lo=math.min(lo,h); hi=math.max(hi,h); if R.hash(i,5)~=h then same=false end end
out.hashSpread = sum/2000 > 0.45 and sum/2000 < 0.55 and lo < 0.02 and hi > 0.98 and same
-- windows
local W = A.Windows
local function share(hour, day)
  local lit, tv = 0, 0
  for i=1,3000 do local s=R.windowState(i, hour, day, W); if s>0 then lit=lit+1 end; if s==2 then tv=tv+1 end end
  return lit/3000, tv/3000
end
local s21, tv21 = share(21, 3)
out.windowsEvening = s21 >= W.LitShare[1]-0.03 and s21 <= W.LitShare[2]+0.03
out.windowsTV = tv21 > 0.02 and tv21 < 0.07
out.windowsNoon = share(12, 3) == 0
out.windowsFade = share(3, 3) < s21 and share(3, 3) > share(4.9, 3) - 0.001
out.windowsLate = math.abs(share(4.9, 3) - W.LateShare) < 0.03
out.windowsMorning = math.abs(share(5.7, 3) - W.MorningShare) < 0.03
-- switching off one by one: a window dark at 2 am stays dark at 3 am (same night)
local mono = true
for i=1,2000 do if R.windowState(i, 2, 3, W)==0 and R.windowState(i, 3, 3, W)>0 then mono=false end end
out.windowsOneByOne = mono
-- different nights, different patterns
local diff = 0
for i=1,500 do if (R.windowState(i, 21, 3, W)>0) ~= (R.windowState(i, 21, 4, W)>0) then diff=diff+1 end end
out.windowsVary = diff > 50
-- nearestN
local n = R.nearestN({30, nil, 5, 12, 5}, 3, 5)
out.nearestN = n[1]==3 and n[2]==5 and n[3]==4 and #n==3
-- palette: no pure colours anywhere
local pure = false
for _, list in pairs(A.Palette) do for _, c in ipairs(list) do if R.isPure(c.r, c.g, c.b) then pure = true end end end
for _, c in ipairs(A.Traffic.BodyColors) do if R.isPure(c.r, c.g, c.b) then pure = true end end
out.noPureColours = not pure and R.isPure(255,0,0) and R.isPure(255,255,255) and not R.isPure(236,234,228)
-- lines
out.lines = #A.Lines.Day >= 10 and #A.Lines.Night >= 4 and R.lineSet(23)=="Night" and R.lineSet(13)=="Day" and R.lineSet(3)=="Night"
local short = true
for _, set in pairs(A.Lines) do for _, l in ipairs(set) do if #l > 40 then short=false end end end
out.linesShort = short
-- head turn
out.lookAhead = near(R.lookYaw(0,-1, 0,-1), 0)
out.lookLeft = R.lookYaw(0,-1, -1,-1) > 0
out.lookBehind = R.lookYaw(0,-1, 0,1) == nil
-- budgets
out.budgetPeople = P.Max <= 14 and P.SpawnRadius <= 160 and P.DespawnRadius >= P.SpawnRadius + 40 and P.MinSpawnDist >= 90
out.budgetCars = T.Max <= 6 and T.Count[2] <= T.Max and T.LitCars <= 2
out.budgetBirds = A.Birds.MaxParts <= 60
out.budgetSound = A.Sound.MaxAudible <= 8
-- sound: no empty ids where a sound is planned (Playbook 11.6), volumes sane
local S = A.Sound
local empty = 0
for _, b in pairs(S.Beds) do if b.id == 0 then empty = empty + 1 end end
for _, m in ipairs(S.Music) do if m.id == 0 then empty = empty + 1 end end
for _, l in pairs(S.Loops) do if l.id == 0 then empty = empty + 1 end end
for _, o in pairs(S.OneShots) do if o.id == 0 then empty = empty + 1 end end
for _, d in ipairs(S.Distant) do if d.id == 0 then empty = empty + 1 end end
if S.NightLayer.id == 0 then empty = empty + 1 end
out.soundIdsFilled = empty == 0
local zonesHaveBeds = true
for _, z in pairs(S.Zones) do if not S.Beds[z.day] or not S.Beds[z.night] then zonesHaveBeds = false end end
out.soundZones = zonesHaveBeds and S.Crossfade >= 1.5 and S.Crossfade <= 3
-- corner groups: never crash when the pool runs low (math.clamp with max < min crashed the loop in play-test)
out.groupNoRoom = R.groupSize(3, 1) == 0 and R.groupSize(3, 0) == 0 and R.groupSize(nil, -2) == 0
out.groupCaps = R.groupSize(4, 2) == 2 and R.groupSize(9, 10) == 4 and R.groupSize(1, 10) == 2 and R.groupSize(3, 3) == 3
out.groupWeird = R.groupSize(0/0, 5) == 3 and R.groupSize(3, 0/0) == 0 and R.groupSize(3, math.huge) == 3 and R.groupSize(nil, 4) == 3
out.speeds = P.WalkSpeed[1] >= 4 and P.WalkSpeed[2] <= 6 and T.Speed[1] >= 22 and T.Speed[2] <= 32
return out
''')
for k in sorted(r.keys()):
    check(k, r[k])

# shop interiors: the zone bed must say Shop anywhere inside the rebuilt stores and never outside them. Floors / roofs
# as measured in Studio 2026-11-02: Food Mart InteriorV2 floor x -1522..-1412 z -325..-280 under a FoodMart shell roof
# that overhangs the sidewalk; BurgerShackV2 floor x -1452..-1413 z -493..-453 under a loose Shops.Part roof;
# Westside Auto on terrain under AutoShop's roof (x -1050..-980 z -495..-461); other AutoShops across the map.
r = lua.execute(r'''
local A=MODULES.Ambient; local R=MODULES.AmbientRules; local L=MODULES.Locations; local S=A.Sound; local out={}
local shops = {}
local keysOk = true
for _, s in ipairs(S.Shops) do
  local loc = L[s.key]
  if not (loc and loc.Inside and loc.Door and type(s.model)=="string" and s.r >= 0 and (s.by=="floor" or s.by=="roof")) then keysOk = false
  else shops[#shops+1] = { key=s.key, model=s.model, by=s.by, r=s.r, anchors={ {loc.Inside.X,loc.Inside.Y,loc.Inside.Z}, {loc.Door.X,loc.Door.Y,loc.Door.Z} } } end
end
out.shopsConfig = keysOk and #shops == 3 and S.Zones.Shop ~= nil
local function at(x, z, roof, floor) return R.shopAt(x, 3, z, roof, floor, shops, S.ShopFind) end
local fmRoof = { "Part", "FoodMart", "Hood", "Landmarks", "ViceBay" }
local fmFloor = { "FloorTiles", "Room", "InteriorV2", "FoodMart", "Hood" }
local terrain = { "Terrain" }
local bsRoof = { "Part", "Shops", "Hood", "Landmarks" }
local bsFloor = { "FloorKitchen", "Room", "BurgerShackV2", "Shops", "Hood" }
local asRoof = { "Part", "AutoShop", "Hood", "Landmarks" }
-- the bug: deep in the rebuilt Food Mart (60-80 studs from Inside) used to be "Street"
out.foodMartCentre = at(-1442, -312, fmRoof, fmFloor) == "FoodMart"
out.foodMartFarAisle = at(-1500, -300, { "Wing_Part", "FoodMart" }, { "FloorTilesX", "Room", "InteriorV2", "FoodMart" }) == "FoodMart"
out.foodMartFarCorner = at(-1520, -282, fmRoof, fmFloor) == "FoodMart"
out.foodMartAwning = at(-1442, -326, fmRoof, terrain) == nil -- under the shell's overhang, just outside the glass
out.foodMartSideOverhang = at(-1524, -319, fmRoof, terrain) == nil
out.foodMartDoorOutside = at(-1442, -330, nil, terrain) == nil
out.foodMartBackYard = at(-1500, -284, nil, terrain) == nil
out.foodMartNeedsRoof = at(-1480, -300, nil, fmFloor) == nil
out.burgerDining = at(-1416, -457, bsRoof, { "FloorDining", "Room", "BurgerShackV2" }) == "BurgerShack"
out.burgerKitchen = at(-1449, -485, bsRoof, bsFloor) == "BurgerShack"
out.burgerOnCounter = at(-1432, -473, bsRoof, { "CounterTop", "Counter", "BurgerShackV2" }) == "BurgerShack"
out.burgerSidewalk = at(-1442, -445, nil, { "Sidewalk", "Flagler St W" }) == nil
out.burgerFrontOverhang = at(-1441, -451, bsRoof, terrain) == nil -- Locations.Inside is out here, under the shell roof
out.autoInside = at(-1015, -478, asRoof, terrain) == "WestsideAuto"
out.autoCorner = at(-1048, -493, { "Beam", "AutoShopV2", "AutoShop" }, terrain) == "WestsideAuto"
out.autoForecourt = at(-1015, -458, nil, terrain) == nil
-- other buildings named AutoShop across the map are not Westside Auto
out.otherAutoShop = at(-1105, -193, asRoof, terrain) == nil
out.otherAutoShopFar = at(-1859, -348, asRoof, terrain) == nil
-- a neighbour's roof next to the Food Mart is not the Food Mart
out.neighbourRoof = at(-1400, -300, { "Roof", "House", "Hood" }, { "Floor", "House" }) == nil
-- fallback: a renamed Food Mart still counts right at Inside
out.renamedFallback = at(-1442, -305, { "Roof", "CornerStoreV3" }, { "Floor", "CornerStoreV3" }) == "FoodMart"
-- up on the roof, far above the floor, isn't inside
out.notOnRoofTop = R.shopAt(-1442, 40, -312, { "Antenna", "FoodMart" }, fmFloor, shops, S.ShopFind) == nil
return out
''')
for k in sorted(r.keys()):
    check('shop.' + k, r[k])

if has_map:
    m = lua.execute(r'''
local M=MODULES.AmbientMap; local R=MODULES.AmbientRules; local out={}
out.hasLanes = #M.Lanes >= 1
local okLanes = true
for _, l in ipairs(M.Lanes) do
  if #l.pts < 3 then okLanes=false end
  local p = R.path(l.pts, l.loop, l.corners)
  if p.total < 60 then okLanes=false end
end
out.lanesValid = okLanes
out.hasWalks = #M.Walks >= 1
local kinds = {}
for _, s in ipairs(M.Spots) do kinds[s[1]] = (kinds[s[1]] or 0) + 1 end
out.spotKinds = (kinds.Stoop or 0) > 0 and (kinds.Corner or 0) > 0
out.windowsCap = #M.Windows <= 600
-- every sound kind a map spot or the runtime asks for has a real id (radios went silent once)
local S = MODULES.Ambient.Sound
local soundKinds = { AC = true, Dog = true, Ball = true, Grill = true }
local missing = {}
for _, s in ipairs(M.Spots) do
  if soundKinds[s[1]] and not (S.Loops[s[1]] and S.Loops[s[1]].id > 0) then missing[#missing+1] = s[1] end
  if s[1] == "Window" and #S.Music == 0 then missing[#missing+1] = "Window" end
end
for _, k in ipairs({ "Murmur", "Coo", "CarMusic", "Engine" }) do
  if not (S.Loops[k] and S.Loops[k].id > 0) then missing[#missing+1] = k end
end
for _, k in ipairs({ "Horn", "Flap" }) do
  if not (S.OneShots[k] and S.OneShots[k].id > 0) then missing[#missing+1] = k end
end
for _, m in ipairs(S.Music) do if not (m.id > 0) then missing[#missing+1] = m.name end end
out.mapSoundIds = #missing == 0
-- a radio near spawn and the Food Mart door (where players spend their first minutes)
local function nearest(x, z) local b = 1e9 for _, s in ipairs(M.Spots) do if s[1] == "Window" then b = math.min(b, math.sqrt((s[2]-x)^2 + (s[4]-z)^2)) end end return b end
out.radioSpawn = nearest(-1432, -368) <= 40
out.radioFoodMart = nearest(-1442, -330) <= 40
local inArea = true
for _, s in ipairs(M.Spots) do if s[2] < -2100 or s[2] > -700 then inArea=false end end
out.spotsInHood = inArea
return out
''')
    for k in sorted(m.keys()):
        check('map.' + k, m[k])
else:
    print('skip map checks (Config/AmbientMap.lua not generated yet)')

print('\n%d failed' % fails)
sys.exit(1 if fails else 0)
