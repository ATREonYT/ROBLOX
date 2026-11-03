# Unit + balance tests for Config/Jobs + Rules/JobRules + Rules/LevelRules (pure Luau) under Lua 5.4 via lupa.
#   pip install lupa && python3 tools/tests/test_job_rules.py
# Balance targets (Master Plan §4): Level 2 in ~1 min, Level 4 (the gang call) in ~6 min, Level 5 in ~10 min of Food Mart work, Level 10 in ~1 hour.
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
local V3={}; V3.__index=V3
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z,__v3=true},V3) end}
Vector2={new=function(x,y) return {X=x,Y=y} end}
Color3={fromRGB=function(r,g,b) return {r,g,b} end, new=function(r,g,b) return {r,g,b} end}
function typeof(v) if type(v)=="table" and v.__v3 then return "Vector3" end return type(v) end
local anyEnum=setmetatable({},{__index=function(t,k) return k end})
Enum=setmetatable({KeyCode={M="M",DPadUp="DPadUp"}},{__index=function() return anyEnum end})
local CF={}; CF.__index=CF; CF.__mul=function(a,b) return a end
CFrame={new=function(...) return setmetatable({},CF) end, Angles=function(...) return setmetatable({},CF) end}
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
table.clone=function(t) local o={} for k,v in pairs(t) do o[k]=v end return o end
table.find=function(t,v) for i=1,#t do if t[i]==v then return i end end return nil end
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code = conv(open(SRC + path).read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
for n, p in [('Story', 'Config/Story.lua'), ('StoryRules', 'Rules/StoryRules.lua'), ('Locations', 'Config/Locations.lua'),
             ('Levels', 'Config/Levels.lua'), ('LevelRules', 'Rules/LevelRules.lua'), ('Jobs', 'Config/Jobs.lua'), ('JobRules', 'Rules/JobRules.lua')]:
    load(n, p)
G = lua.globals()
J, R, L, LR = G.MODULES.Jobs, G.MODULES.JobRules, G.MODULES.Levels, G.MODULES.LevelRules
fails = 0
def check(name, cond, extra=''):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name + (('  ' + str(extra)) if extra else '')); fails += (0 if cond else 1)

# --- config integrity: every task belongs to a job, every step's stations exist, every job has a TimeClock
ok = True; problems = []
for jid in list(J.Order.values()):
    d = J.Defs[jid]
    if d is None: problems.append('missing def ' + jid); continue
    if d.stations['TimeClock'] is None: problems.append(jid + ' no TimeClock')
    if d.kind == 'post':
        if d.stations['Post'] is None: problems.append(jid + ' post job without Post station')
        continue
    for tid in list(d.tasks.values()):
        t = J.Tasks[tid]
        if t is None: problems.append(jid + ' unknown task ' + tid); continue
        for step in list(t.steps.values()):
            if step.kind not in ('pickup', 'drop', 'press', 'hold', 'timing', 'sequence'): problems.append(tid + ' bad step kind ' + str(step.kind))
            for s in list(step.at.values()):
                if d.stations[s] is None: problems.append(f'{tid}: station {s} not in {jid}')
        kinds = [s.kind for s in t.steps.values()]
        if 'drop' in kinds and not any(s.carry for s in t.steps.values()): problems.append(tid + ' drop without carry')
check('config integrity', not problems, problems)
check('Levels.Unlocks mentions every job unlock level', all(L.Unlocks[J.Defs[j].level] is not None for j in J.Order.values() if J.Defs[j].level > 1))

# --- visibility / choosing / working
vis = lambda st: list(R.visibleJobs(st).values())
check('FirstShift sees only the story job', vis('FirstShift') == ['Supermarket'])
check('ChooseJob sees the 3 starter jobs', vis('ChooseJob') == ['Supermarket', 'Mechanic', 'Restaurant'])
check('FreePlay sees every job', len(vis('FreePlay')) == len(list(J.Order.values())))
check('cannot choose before ChooseJob', R.canChoose('Mechanic', 10, 'FirstShift')[0] is False)
check('can choose Mechanic at ChooseJob', R.canChoose('Mechanic', 5, 'ChooseJob')[0] is True)
check('cannot choose Cashier at ChooseJob (not listed)', R.canChoose('Cashier', 20, 'ChooseJob')[0] is False)
check('Cashier needs Level 8', R.canChoose('Cashier', 7, 'FreePlay')[0] is False and R.canChoose('Cashier', 8, 'FreePlay')[0] is True)
check('no work during the robbery', R.canWork('Supermarket', 5, 'FirstMission')[0] is False)
check('work during FirstShift', R.canWork('Supermarket', 1, 'FirstShift')[0] is True)
check('unknown job refused', R.canChoose('Nope', 99, 'FreePlay')[0] is False)
check('unlockedAt(8) = 3 tier-2 jobs', len(list(R.unlockedAt(8).values())) == 3)
check('unlockedAt(1) is empty', len(list(R.unlockedAt(1).values())) == 0)

# --- tasks
seq = iter([0.0, 0.99, 0.5] * 1000)
rnd = lua.execute('return function(f) return function() return f() end end')(lambda: next(seq))
lvl1 = list(R.availableTasks('Supermarket', 1).values())
check('PriceGun locked at Level 1', 'PriceGun' not in lvl1 and 'PriceGun' in list(R.availableTasks('Supermarket', 2).values()))
# never 3 in a row
import random
random.seed(1)
rr = lua.execute('return function(f) return function() return f() end end')(lambda: random.random())
hist = lua.table(); n3 = 0; counts = {}
for i in range(3000):
    t = R.pickTask('Supermarket', 5, hist, rr)
    counts[t] = counts.get(t, 0) + 1
    hist[len(hist) + 1] = t
for i in range(3, len(hist) + 1):
    if hist[i] == hist[i - 1] == hist[i - 2]: n3 += 1
check('no task 3 times in a row', n3 == 0, counts)
n2 = sum(1 for i in range(2, len(hist) + 1) if hist[i] == hist[i - 1])
check('back-to-back repeats are rare (< 15%)', n2 / (len(hist) - 1) < 0.15, round(n2 / (len(hist) - 1), 3))
check('weights respected (Restock most common)', max(counts, key=counts.get) == 'Restock', counts)
check('pickStation avoids the last one', all(R.pickStation(lua.table('Shelf1', 'Shelf2'), 'Shelf1', rr) == 'Shelf2' for _ in range(20)))
items = list(R.sequenceItems(J.Tasks.BuildOrder.steps[1], rr).values())
check('burger ticket = 4 distinct items', len(items) == 4 and len(set(items)) == 4, items)
oil = list(R.sequenceItems(J.Tasks.OilChange.steps[1], rr).values())
check('oil change keeps its order', oil == ['Drain old oil', 'Swap filter', 'Pour new oil', 'Check dipstick'])
check('quick hands at Level 7', abs(R.holdSeconds(J.Tasks.Mop.steps[1], 7) - 3.4) < 1e-6 and R.holdSeconds(J.Tasks.Mop.steps[1], 6) == 4)
check('min hold time = 75% of hold', abs(R.minStepSeconds(J.Tasks.Mop.steps[1], 1) - 3.0) < 1e-6)

# --- scores and rewards
check('scores clamp', R.scoreHold(0) == 1 and R.scoreHold(10) == 0.4 and R.scoreTiming(3, 0) == 1 and R.scoreTiming(0, 5) == 0.4 and R.scoreSequence(1) == 0.8)
p, x, lab = R.taskReward('Restock', 1, 1, None)
check('Restock perfect at L1: no tips yet', (p, x, lab) == (8, 22, 'PERFECT'), (p, x, lab))
p, x, lab = R.taskReward('Restock', 4, 1, None)
check('Restock perfect at L4: no tips yet (L4 is the gang call)', (p, x, lab) == (8, 22, 'PERFECT'), (p, x, lab))
p, x, lab = R.taskReward('Restock', 5, 1, None)
check('Restock perfect at L5: +25%', (p, x, lab) == (10, 28, 'PERFECT'), (p, x, lab))
p, x, lab = R.taskReward('Restock', 1, 0.5, None)
check('sloppy -20%', (p, x, lab) == (6, 18, 'SLOPPY'), (p, x, lab))
p, x, lab = R.taskReward('Restock', 9, 0.8, None)
check('pay raise +20% at L9', p == 10 and x == 22, (p, x))
p, x, lab = R.taskReward('Delivery', 15, None, 300)
check('delivery distance pay', p == round(20 * 1.2 + 0.12 * 300), p)
# every local trucker drop is a short walk from the dock (no vehicles yet)
dock = J.Defs.Trucker.stations.Dock
import math
drops = list(J.Tasks.Delivery.steps[2].at.values())
far = [d for d in drops if J.Defs.Trucker.stations[d].pos is None]
check('Delivery only uses drops with a fixed position', not far, far)
d_ok = all(150 <= math.hypot(J.Defs.Trucker.stations[d].pos.X + 1189, J.Defs.Trucker.stations[d].pos.Z - 1121) <= 400 for d in drops)
check('trucker drops are 150-400 studs from the dock', d_ok, drops)
# tier 2/3 task jobs have more than one task (no endless repeats)
bad = [tid for tid, t in J.Tasks.items() for st in t.steps.values() if st.kind == 'sequence' and st.keepOrder and st.count != len(list(st.pool.values()))]
check('keepOrder sequences use the whole pool (count == #pool)', not bad, bad)
for j in ('Cashier', 'CarWash', 'Valet', 'Trucker'):
    check(j + ' has 3+ tasks', len(list(J.Defs[j].tasks.values())) >= 3, j)
check('AFK/route tier-3 jobs give less XP/min than hands-on jobs', R.perMinute('Trucker', 15)[1] < min(R.perMinute(j, 1)[1] for j in J.StarterJobs.values()), R.perMinute('Trucker', 15))
check('post tick (Security, L15)', R.postTick('Security', 15) == (42, 15), R.postTick('Security', 15))
check('shift bonus by level', R.shiftBonusShare(2) == 0 and R.shiftBonusShare(3) == 0.25 and R.shiftBonusShare(10) == 0.5)

# --- balance simulation: an average player at the Food Mart (avg score ~0.9 = mostly "good", some perfect)
def simulate(target_level, job='Supermarket', perfect_share=0.35, sloppy_share=0.05):
    random.seed(7)
    level, xp, t, cash, done = 1, 0, 0.0, 0, 0
    hist = lua.table(); shift_cash = 0
    times = {}
    while level < target_level and t < 6 * 3600:
        tid = R.pickTask(job, level, hist, rr); hist[len(hist) + 1] = tid
        task = J.Tasks[tid]
        r = random.random()
        score = 1.0 if r < perfect_share else (0.5 if r < perfect_share + sloppy_share else 0.8)
        has_game = any(R.isMinigame(s.kind) for s in task.steps.values())
        pay, gx, _ = R.taskReward(tid, level, score if has_game else None, None)
        t += task.est * random.uniform(0.85, 1.25)
        cash += pay; shift_cash += pay; done += 1
        if done % J.Shift.Tasks == 0:
            cash += int(shift_cash * R.shiftBonusShare(level) + 0.5); shift_cash = 0; t += 4
        nl, nx, gained = LR.add(level, xp, gx)
        for g in gained.values(): times[g] = t
        level, xp = nl, nx
    return times, cash, done
times, cash, done = simulate(11)
mins = {k: round(v / 60, 1) for k, v in times.items()}
print('     minutes to reach each level at the Food Mart:', mins, f'cash ${cash} after {done} tasks')
check('Level 2 in about 1 minute', 0.6 <= mins[2] <= 1.6, mins[2])
check('Level 3 (the Unknown tease text) in about 3 minutes', 2.0 <= mins[3] <= 4.0, mins[3])
check('Level 4 (the gang call) in about 6 minutes', 4.5 <= mins[4] <= 7.5, mins[4])
check('Level 5 in about 10 minutes', 8.5 <= mins[5] <= 11.5, mins[5])
check('Level 10 in about an hour (tier 1 only)', 50 <= mins[10] <= 85, mins[10])
t5, cash5, _ = simulate(4)
print(f'     cash at Level 4 (the call): ${cash5 + 50} (start $50); flat costs ${J and 1200}, first mission pays $1500')
check('cash at the call (Level 4) is pocket money, not the flat', 80 <= cash5 <= 400, cash5)

# $/min ladder: each tier pays clearly more than the one below
pm = {j: R.perMinute(j, J.Defs[j].level) for j in J.Order.values()}
print('     $/min, XP/min at unlock level:', pm)
t1 = max(pm[j][0] for j in J.Order.values() if J.Defs[j].tier == 1)
t2 = [pm[j][0] for j in J.Order.values() if J.Defs[j].tier == 2]
t3 = [pm[j][0] for j in J.Order.values() if J.Defs[j].tier == 3]
check('tier 2 pays more per minute than tier 1', min(t2) > t1, (t1, t2))
check('tier 3 pays more per minute than tier 2', min(t3) > max(t2), (t2, t3))
check('tier 1 jobs are within 25% of each other ($/min)', max(pm[j][0] for j in J.StarterJobs.values()) <= 1.25 * min(pm[j][0] for j in J.StarterJobs.values()))
check('AFK jobs give less XP/min than hands-on jobs', max(pm[j][1] for j in ('Security', 'Dockworker')) < min(pm[j][1] for j in J.StarterJobs.values()))

print('\n%d failures' % fails)
sys.exit(1 if fails else 0)
