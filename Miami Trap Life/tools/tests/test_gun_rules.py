# Unit + balance tests for Config/Guns + Rules/GunRules (pure Luau) under Lua 5.4 via lupa.
#   pip install lupa && python3 tools/tests/test_gun_rules.py
# Balance targets (Gun Mechanics research): body-shot time-to-kill on 100 HP at 20 studs between 0.25 s and 1.2 s,
# pistol 5 body shots, revolver 2 headshots, shotgun deadly close and weak far, aim tighter than hip for every gun.
import os, sys, re, math, lupa
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
Enum=setmetatable({},{__index=function() return anyEnum end})
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code = conv(open(SRC + path).read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
for n, p in [('Story', 'Config/Story.lua'), ('Locations', 'Config/Locations.lua'), ('Guns', 'Config/Guns.lua'), ('GunRules', 'Rules/GunRules.lua')]:
    load(n, p)
G = lua.globals().MODULES.Guns
R = lua.globals().MODULES.GunRules
fails = 0
def check(name, cond, info=''):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name + (('  ' + str(info)) if info else ''))
    fails += 0 if cond else 1

order = [G.Order[i] for i in range(1, len(G.Order) + 1)]
# ---------------------------------------------------------------- config sanity
check('5 guns in Order', len(order) == 5, order)
for gid in order:
    d = G.Defs[gid]
    ok = d is not None
    check(f'{gid}: has a def', ok)
    if not ok: continue
    check(f'{gid}: ammo type exists', G.Ammo[d.Ammo] is not None, d.Ammo)
    check(f'{gid}: falloff start < end <= range', d.FalloffStart < d.FalloffEnd <= d.Range)
    check(f'{gid}: aim tighter than hip', d.Spread.Aim < d.Spread.Hip)
    check(f'{gid}: mag, reload, rpm sane', d.Mag > 0 and 0.5 < d.Reload < 4 and 30 <= d.RPM <= 1200)
    check(f'{gid}: recoil return in 0..1', 0 <= d.Recoil.Return <= 1)
    check(f'{gid}: price + level', d.Price > 0 and d.Level >= 1)
    check(f'{gid}: slot', d.Slot in ('Primary', 'Secondary'))
check('starter gun exists', G.Defs[G.Starter.Gun] is not None)
levels = [G.Defs[g].Level for g in order]
check('shop unlocks in order of level', levels == sorted(levels), levels)

# ---------------------------------------------------------------- balance
for gid in order:
    d = G.Defs[gid]
    ttk = R.timeToKill(d, 100, 20)
    check(f'{gid}: TTK at 20 studs in 0..1.2 s', 0 <= ttk <= 1.2, round(ttk, 3))
check('pistol: 5 body shots', R.shotsToKill(G.Defs.Pistol, 100, 20) == 5)
check('revolver: 2 headshots', R.shotsToKill(G.Defs.Revolver, 100, 20, True) == 2)
check('shotgun: 2 shots point blank', R.shotsToKill(G.Defs.Shotgun, 100, 5) <= 2)
check('shotgun: weak at 60 studs', R.shotsToKill(G.Defs.Shotgun, 100, 60) >= 4)
check('AK beats Uzi at 150 studs', R.timeToKill(G.Defs.AK, 100, 150) < R.timeToKill(G.Defs.Uzi, 100, 150))

# ---------------------------------------------------------------- damage
p = G.Defs.Pistol
check('full damage up close', R.damage(p, 10, False) == p.Damage)
check('head multiplier', abs(R.damage(p, 10, True) - p.Damage * p.HeadMult) < 0.11)
check('falloff floor', abs(R.damage(p, 1000 if p.Range > 1000 else p.Range, False) - p.Damage * p.FalloffMin) < 0.11)
check('no damage past range', R.damage(p, p.Range + 1, False) == 0)
prev = 1e9; mono = True
for dist in range(0, int(p.Range), 5):
    v = R.damage(p, dist, False)
    mono = mono and v <= prev + 1e-9; prev = v
check('damage never rises with distance', mono)

# ---------------------------------------------------------------- fire rate bucket
tol, burst = G.Tuning.FireRateTolerance, G.Tuning.FireBurst
for gid in ('Pistol', 'Uzi', 'AK'):
    d = G.Defs[gid]
    b = R.newBucket(burst, 0)
    accepted = sum(1 for i in range(1000) if R.rateAllow(b, d, i * 0.001, tol, burst))  # spam for 1 s
    cap = d.RPM / 60 / tol + burst + 1
    check(f'{gid}: spam capped near RPM', accepted <= cap, f'{accepted} <= {cap:.1f}')
    # legit fire at exactly RPM with +-40 ms network jitter: nothing rejected
    import random
    random.seed(7)
    b = R.newBucket(burst, 0); iv = 60 / d.RPM; rej = 0; t = 0
    for i in range(300):
        t += iv
        arr = t + random.uniform(-0.04, 0.04)
        if not R.rateAllow(b, d, max(arr, 0), tol, burst): rej += 1
    check(f'{gid}: legit jittery fire never eaten', rej == 0, rej)

# ---------------------------------------------------------------- spread / cone
for gid in order:
    d = G.Defs[gid]
    st = lua.table_from({'aiming': False, 'moving': True, 'airborne': True, 'bloom': 99})
    check(f'{gid}: maxSpread covers the worst case', R.maxSpread(d) >= R.spread(d, st))
    a = R.spread(d, lua.table_from({'aiming': True, 'moving': False, 'airborne': False, 'bloom': 0}))
    h = R.spread(d, lua.table_from({'aiming': False, 'moving': False, 'airborne': False, 'bloom': 0}))
    m = R.spread(d, lua.table_from({'aiming': False, 'moving': True, 'airborne': False, 'bloom': 0}))
    check(f'{gid}: aim < hip < moving', a < h < m)
bl = 0
for _ in range(50): bl = R.bloomAfterShot(p, bl)
check('bloom caps at MaxBloom', abs(bl - p.Spread.MaxBloom) < 1e-9)
check('bloom recovers', R.bloomRecover(p, bl, 10) == 0)
random.seed(3); inside = True; far = 0
for _ in range(2000):
    x, y = R.coneOffset(3, random.random(), random.random())
    r = math.degrees(math.hypot(x, y))
    inside = inside and r <= 3 + 1e-9
    far += r > 3 * math.sqrt(0.5)
check('cone offsets stay inside the cone', inside)
check('cone is uniform over the disc (half outside r/sqrt2)', 850 < far < 1150, far)
check('angle 90', abs(R.angle(1, 0, 0, 0, 1, 0) - 90) < 1e-6)
check('angle 0', R.angle(0, 0, -1, 0, 0, -2) < 1e-6)

# ---------------------------------------------------------------- recoil spring
k, z = G.Tuning.RecoilStiffness, G.Tuning.RecoilDamping
s = lua.table_from({'x': 0, 'v': R.kickVelocity(1.0, k)})
peak = 0; t = 0
while t < 0.6:
    R.springStep(s, k, z, 1 / 60); t += 1 / 60; peak = max(peak, s.x)
check('spring peak about the asked kick (0.8..1.4)', 0.8 <= peak <= 1.4, round(peak, 3))
check('spring settles in 0.6 s', abs(s.x) < 0.05, round(s.x, 4))
s2 = lua.table_from({'x': 0, 'v': R.kickVelocity(1.0, k)})
R.springStep(s2, k, z, 0.6)  # one big step (lag spike) stays stable
check('spring stable on a 0.6 s frame', abs(s2.x) < 0.1, round(s2.x, 4))
st_, bo = R.recoilSplit(p, 2)
check('recoil split sums to the kick', abs(st_ + bo - 2) < 1e-9)

# ---------------------------------------------------------------- ammo
check('reload fills from reserve', tuple(R.reload(3, 12, 48)) == (12, 39))
check('reload with a thin reserve', tuple(R.reload(3, 12, 4)) == (7, 0))
check('no reload when full', not R.canReload(12, 12, 10))
check('no reload without reserve', not R.canReload(0, 12, 0))

# ---------------------------------------------------------------- rules
check('civilian cannot equip live', not R.canEquip('Civilian', 'Live', False, False, True)[0])
check('criminal can equip live', R.canEquip('Criminal', 'Live', False, False, True)[0])
check('no live gun on shift', not R.canEquip('Criminal', 'Live', True, False, True)[0])
check('no live gun in safe zone', not R.canEquip('Criminal', 'Live', False, True, True)[0])
check('story gun works for a civilian in a safe zone', R.canEquip('Civilian', 'Intimidate', True, True, True)[0])
check('dead cannot equip', not R.canEquip('Criminal', 'Intimidate', False, False, False)[0])
def tgt(**kw): return lua.table_from(kw)
check('criminal hits criminal', R.canDamage('Live', 'Criminal', False, tgt(isPlayer=True, path='Criminal', safe=False))[0])
check('civilians are protected', not R.canDamage('Live', 'Criminal', False, tgt(isPlayer=True, path='Civilian', safe=False))[0])
check('civilian cannot hurt players', not R.canDamage('Live', 'Civilian', False, tgt(isPlayer=True, path='Criminal', safe=False))[0])
check('no damage into a safe zone', not R.canDamage('Live', 'Criminal', False, tgt(isPlayer=True, path='Criminal', safe=True))[0])
check('no damage out of a safe zone', not R.canDamage('Live', 'Criminal', True, tgt(isPlayer=True, path='Criminal', safe=False))[0])
check('story gun never damages', not R.canDamage('Intimidate', 'Criminal', False, tgt(isPlayer=True, path='Criminal', safe=False))[0])
check('NPCs protected by default', not R.canDamage('Live', 'Criminal', False, tgt(isPlayer=False))[0])
check('MTL_Damageable NPC takes damage', R.canDamage('Live', 'Criminal', False, tgt(isPlayer=False, damageable=True))[0])
check('no self damage', not R.canDamage('Live', 'Criminal', False, tgt(isPlayer=True, path='Criminal', self=True))[0])

# ---------------------------------------------------------------- hit checks
check('inside box = 0', R.boxDistance(0.2, 0.3, 0, 1, 1, 0.5) == 0)
check('outside box distance', abs(R.boxDistance(2, 0, 0, 1, 1, 0.5) - 1) < 1e-9)
times = lua.table_from([i * 0.05 for i in range(21)])  # 0 .. 1.0
idx = list(R.rewindSamples(times, 0.8, 1.0, 0.4, 0.25).values())
ts = [times[i] for i in idx]
check('rewind window = [t-0.25, now]', min(ts) >= 0.55 - 1e-9 and max(ts) <= 1.0 + 1e-9 and len(ts) >= 9, ts)
idx = list(R.rewindSamples(times, 0.1, 1.0, 0.4, 0.25).values())
ts = [times[i] for i in idx]
check('rewind never older than MaxRewind', min(ts) >= 0.6 - 1e-9, ts)
check('in fight', R.inFight(10, 25, 20) and not R.inFight(10, 31, 20) and not R.inFight(None, 31, 20))
check('zone', R.inZone(5, 2, 5, 0, 2, 0, 10, 5) and not R.inZone(5, 20, 5, 0, 2, 0, 10, 5) and not R.inZone(11, 2, 0, 0, 2, 0, 10, 5))

# ---------------------------------------------------------------- safe zones resolve from Locations
L = lua.globals().MODULES.Locations
for i in range(1, len(G.SafeZones) + 1):
    zz = G.SafeZones[i]
    loc = L[zz.location]
    pos = loc if (loc is not None and loc['__v3']) else (loc[zz.field or 'Door'] if loc is not None else None)
    check(f'safe zone {zz.id} has a position', pos is not None)

# ---------------------------------------------------------------- shop
check('shop: civilian refused', not R.canBuyGun(p, 30, 1e6, 'Civilian', False)[0])
check('shop: level gate', R.canBuyGun(G.Defs.AK, 19, 1e6, 'Criminal', False)[1] == 'Level 20')
check('shop: cash gate', not R.canBuyGun(p, 30, 10, 'Criminal', False)[0])
check('shop: owned', not R.canBuyGun(p, 30, 1e6, 'Criminal', True)[0])
check('shop: ok', R.canBuyGun(p, 5, 1200, 'Criminal', False)[0])
pk = G.Ammo['9mm']
check('ammo: full', not R.canBuyAmmo(pk, pk.Max, 1e6, 'Criminal', True)[0])
check('ammo: need a gun', not R.canBuyAmmo(pk, 0, 1e6, 'Criminal', False)[0])
check('ammo: ok', R.canBuyAmmo(pk, 0, 1e6, 'Criminal', True)[0])
check('crosshair gap grows with spread', R.crosshairGap(3, 70, 1080) > R.crosshairGap(1, 70, 1080) > 0)

print(('ALL PASS' if fails == 0 else f'{fails} FAILED'))
sys.exit(1 if fails else 0)
