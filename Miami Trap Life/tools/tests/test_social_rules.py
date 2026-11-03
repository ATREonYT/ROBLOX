# Unit + balance tests for Config/Social + Rules/SocialRules (pure Luau) under Lua 5.4 via lupa.
#   pip install lupa && python3 tools/tests/test_social_rules.py
# Balance targets (Research/Social Media Hustle.md): a player who posts about every 2.5 minutes of play reaches
# 1K followers in ~20-35 min, 10K in ~1.5-3 h, 100K in ~5-10 h, 1M in ~15-30 h. Income grows with followers and
# swings day to day.
import os, sys, re, random, statistics, lupa
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
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
Color3={fromRGB=function(r,g,b) return {r,g,b} end}
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code = conv(open(SRC + path).read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
load('Social', 'Config/Social.lua'); load('SocialRules', 'Rules/SocialRules.lua')
G = lua.globals(); S, R = G.MODULES.Social, G.MODULES.SocialRules
fails = 0
def check(name, cond, extra=''):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name + (('  ' + str(extra)) if extra else '')); fails += (0 if cond else 1)
T = lua.table_from

# --- formatting + tiers
check('short', [R.short(x) for x in (950, 1000, 1234, 12345, 123456, 1234567, 25000000)] == ['950','1K','1.2K','12.3K','123K','1.2M','25M'],
      [R.short(x) for x in (950, 1000, 1234, 12345, 123456, 1234567, 25000000)])
check('tier', R.tier(0).id == 'New' and R.tier(1500).id == 'Nano' and R.tier(2_000_000).id == 'Mega')
check('rand in 0..1 and repeatable', all(0 <= R.rand(s, n) < 1 for s in range(50) for n in range(20)) and R.rand(5, 3) == R.rand(5, 3))
ms = R.milestones(900, 12000, None)
check('milestones crossed 900 -> 12K', [m.at for m in ms.values()] == [1000, 10000])
check('milestones skip done', len(list(R.milestones(900, 12000, T({'1000': 1})).values())) == 1)
check('verified needs low bots', R.verified(T({'Real': 120000, 'Bots': 0})) and not R.verified(T({'Real': 120000, 'Bots': 90000})))

# --- spots + config integrity
ids = [s.id for s in S.Spots.values()]
check('spot ids unique', len(ids) == len(set(ids)))
check('every spot has palette + scene', all(s.palette is not None and s.scene for s in S.Spots.values()))
check('every brand spot exists', all((b.spot is None) or (b.spot in ids) for b in S.Brands.values()))
check('every format has captions', all(S.Captions[f.id] is not None for f in S.Formats.values()))

# --- market: varies by day, stays in range, same seed -> same day
m1, m2 = R.market(1, 77, None), R.market(2, 77, None)
check('market repeatable', R.market(1, 77, None).trendSpot == m1.trendSpot and R.market(1, 77, None).mood == m1.mood)
moods = [R.market(d, 3, None).mood for d in range(200)]
check('mood range', min(moods) >= S.Day.MoodMin and max(moods) <= S.Day.MoodMax and statistics.pstdev(moods) > 0.1, (min(moods), max(moods)))
check('trend spot never the Ends', all(R.market(d, 9, None).trendSpot != 'Ends' for d in range(200)))
prev = None; series = []
for d in range(60):
    mk = R.market(d, 11, prev); prev = mk.demand; series.append(mk.demand['Trading'])
check('demand random walk in range', min(series) >= S.Day.DemandMin and max(series) <= S.Day.DemandMax and len(set(series)) > 10, (min(series), max(series)))

# --- quality / post sanity
base = dict(spot='Wynwood', phase='Day', carFlex=1.25, format='CarFlex', collab=0, framing=0.6, market=m1)
def post(acc, **kw):
    sh = dict(base); sh.update(kw)
    return R.post(T(acc), T(sh), T(dict(luck=kw.get('luck', 0.5), spread=0.5, noise=0.5)))
check('better spot -> more views', post({'Real': 500}, spot='StarIsland').views > post({'Real': 500}, spot='Ends').views)
check('car meet without car is worse', post({'Real': 500}, spot='SohoMeet', carFlex=0).views < post({'Real': 500}, spot='SohoMeet').views)
check('viral roll is huge', post({'Real': 500}, luck=0.0).views > 5 * post({'Real': 500}).views)
check('flop roll is small', post({'Real': 500}, luck=0.999).views < post({'Real': 500}).views)
check('spam fatigue', post({'Real': 500}, recentPosts=8).views < 0.5 * post({'Real': 500}, recentPosts=0).views)
check('3 posts per 10 min is free', post({'Real': 500}, recentPosts=3).views == post({'Real': 500}, recentPosts=0).views)
check('bots add no reach', post({'Real': 500, 'Bots': 50000}).views == post({'Real': 500}).views)
check('bots add a little follow rate', post({'Real': 500, 'Bots': 50000}).gained > post({'Real': 500}).gained)
check('fund only from 1K', post({'Real': 900}).fund == 0 and post({'Real': 5000}).fund >= 0)
check('xp capped', all(post({'Real': 10}, luck=l).xp <= S.Post.XPMax + S.Post.XPViral + S.Post.XPNewSpot for l in (0, 0.5)))

# --- deals
br = S.brand('NoCap')
pays = {n: R.dealPay(T({'Real': n}), br, 1.0, 0.05, 0.5) for n in (1000, 10000, 100000, 1000000)}
check('deal pay ladder (real tier ratios)', 50 <= pays[1000] <= 90 and 200 <= pays[10000] <= 450 and 1000 <= pays[100000] <= 2300 and 5000 <= pays[1000000] <= 11000, pays)
check('bots halve deal pay', R.dealPay(T({'Real': 10000, 'Bots': 10000}), br, 1, 0.05, 0.5) < 0.6 * pays[10000])
check('no deals over 60% bots', not R.dealsOpen(T({'Real': 2000, 'Bots': 8000})) and R.dealsOpen(T({'Real': 2000})))

# --- courses
ctx = T(dict(day=0, demand=T({'Larp': 1.0}), trust=1, promo=False, proof=False))
c97 = T(dict(topic='Larp', price=97, launchDay=0)); c997 = T(dict(topic='Larp', price=997, launchDay=0))
b97, b997 = R.courseBuyers(T({'Real': 10000}), c97, ctx), R.courseBuyers(T({'Real': 10000}), c997, ctx)
check('pricier course sells fewer copies', b997 < b97 / 5, (b97, b997))
check('novelty decays', R.novelty(0) > R.novelty(3) > R.novelty(30) == S.Courses.NoveltyFloor)
check('bots hurt trust', R.trust(T({'Real': 1000, 'Bots': 1000}), 1) < 0.6)
check('sales roll', R.sales(0.3, 0.1) == 1 and R.sales(0.3, 0.9) == 0 and 6 <= R.sales(10, 0.0) <= 7 and 13 <= R.sales(10, 0.99) <= 14)

# --- balance sim: one player, one post per ~150 s of play, good-but-not-perfect choices
DAY = 28 * 60
def sim(seed, hours=30, cadence=150, bots_at=None):
    rng = random.Random(seed)
    acc = {'Real': 0, 'Bots': 0}; t = 0; hit = {}; prev = None; posts = []
    spots = [s for s in S.Spots.values()]
    income = {'fund': 0, 'deals': 0, 'courses': 0}; daily = []
    day_income = 0; day = -1; courses = []
    while t < hours * 3600:
        d = int(t // DAY)
        if d != day:
            if day >= 0: daily.append((day, acc['Real'], day_income))
            day = d; day_income = 0; mk = R.market(d, seed, prev); prev = mk.demand
            # launch a course when allowed (one per 2 days, max 3 live)
            if acc['Real'] >= S.Unlock.CoursesFollowers and (not courses or d - courses[-1]['launchDay'] >= 2):
                topic = rng.choice(['Larp', 'Trading', 'Grow', 'Rich'])
                courses.append({'topic': topic, 'price': 97, 'launchDay': d}); courses = courses[-3:]
        sp = rng.choice(spots)
        while sp.id == 'Ends' and rng.random() < 0.8: sp = rng.choice(spots)
        phase = rng.choice(['Morning', 'Day', 'Day', 'Evening', 'Night', 'Night'])
        has_car = rng.random() < 0.75
        recent = len([p for p in posts if t - p < 600])
        r = R.post(T(acc), T(dict(spot=sp.id, phase=phase, carFlex=1.25 if has_car else 0, format='CarFlex' if has_car else 'Spot',
                                 collab=1 if rng.random() < 0.1 else 0, framing=rng.random(), newSpotToday=rng.random() < 0.5,
                                 repeatSpot=rng.random() < 0.15, recentPosts=recent, market=mk, verified=R.verified(T(acc)))),
                   T(dict(luck=rng.random(), spread=rng.random(), noise=rng.random())))
        acc['Real'] += r.gained; posts.append(t); income['fund'] += r.fund; day_income += r.fund
        # one deal per day once open (~ every 10th post)
        if R.dealsOpen(T(acc)) and rng.random() < cadence / DAY * 2.5:
            pay = R.dealPay(T(acc), br, mk.mood, 0.05, rng.random()); income['deals'] += pay; day_income += pay
        for c in courses:
            exp = R.courseBuyers(T(acc), T(c), T(dict(day=d, demand=mk.demand, trust=1, promo=True, proof=False)))
            got = R.sales(exp * cadence / DAY, rng.random()) * R.net(c['price'])
            income['courses'] += got; day_income += got
        for k in (1000, 10000, 100000, 1000000):
            if acc['Real'] >= k and k not in hit: hit[k] = t / 3600
        t += cadence * (0.7 + 0.6 * rng.random())
    return hit, acc, income, daily
runs = [sim(s) for s in range(12)]
def med(k): 
    v = sorted(r[0].get(k, 99) for r in runs); return v[len(v)//2]
print('median hours to 1K %.2f  10K %.2f  100K %.2f  1M %.2f' % (med(1000), med(10000), med(100000), med(1000000)))
check('1K in 20-40 min', 0.33 <= med(1000) <= 0.67, med(1000))
check('10K in 1.5-3 h', 1.5 <= med(10000) <= 3.0, med(10000))
check('100K in 5-10 h', 5 <= med(100000) <= 10, med(100000))
check('1M in 15-30 h', 15 <= med(1000000) <= 30, med(1000000))
h, acc, inc, daily = runs[0]
print('run0 income after 30h:', {k: int(v) for k, v in inc.items()}, 'followers', acc['Real'])
for d, f, i in daily[::6]: print('  day %3d  followers %9s  income that day $%s' % (d, R.short(f), int(i)))
late = [i for d, f, i in daily[-12:]]
check('income swings day to day (late game cv > 0.12)', statistics.pstdev(late) / max(1, statistics.mean(late)) > 0.12, round(statistics.pstdev(late) / max(1, statistics.mean(late)), 2))
print('\n%d failures' % fails); sys.exit(1 if fails else 0)
