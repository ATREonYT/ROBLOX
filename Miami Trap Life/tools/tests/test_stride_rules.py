# Unit tests + a simulated walker for Rules/StrideRules (stride sync, Controllers/StrideController.lua).
# The walker has hidden "true" authored clip speeds; the controller's maths starts from a wrong guess and must make
# the planted foot stop sliding at carry (14), walk (16) and sprint (24) speeds, with noisy foot measurements.
#   pip install lupa && python3 tools/tests/test_stride_rules.py
import os, sys, re, random, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luau2lua import conv
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'ReplicatedStorage', 'MTL') + '/'
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
__ifx = function(c,a,b) if c then return a() else return b() end end
math.clamp=function(x,a,b) if x<a then return a elseif x>b then return b end return x end
Enum=setmetatable({},{__index=function() return setmetatable({},{__index=function(t,k) return k end}) end})
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
Color3={fromRGB=function(r,g,b) return {r,g,b} end, new=function(r,g,b) return {r,g,b} end}
UDim2={new=function() return {} end}
MODULES={}
function require(m) return MODULES[m] end
''')
def load(name, path):
    code = conv(open(SRC + path, encoding='utf-8').read())
    code = re.sub(r'require\(script(?:\.Parent)+\.(?:Config\.|Rules\.)?(\w+)\)', r'require("\1")', code)
    f = lua.execute('return function() ' + code + '\nend')
    lua.globals().MODULES[name] = f()
load('StrideRules', 'Rules/StrideRules.lua')
load('Movement', 'Config/Movement.lua')
R = lua.globals().MODULES.StrideRules
S = lua.globals().MODULES.Movement.Stride

fails = 0
def check(name, cond, info=''):
    global fails
    print(('ok   ' if cond else 'FAIL ') + name + ('  ' + str(info) if info != '' else '')); fails += (0 if cond else 1)

# --- pure functions
check('run weight 0 at walk speed', R.runWeight(16, S.BlendStart, S.BlendEnd) == 0, R.runWeight(16, S.BlendStart, S.BlendEnd))
check('unblend takes the other clip back out', abs(R.unblend(12, 20, 0.25) - (12 - 5) / 0.75) < 1e-9 and R.unblend(12, None, 0.25) is None and R.unblend(12, None, 0) == 12)
check('run weight 1 at sprint speed', R.runWeight(24, S.BlendStart, S.BlendEnd) == 1)
check('run weight 0 while carrying (14)', R.runWeight(14, S.BlendStart, S.BlendEnd) == 0)
check('run weight is monotonic', all(R.runWeight(v / 4, 15, 23) <= R.runWeight((v + 1) / 4, 15, 23) for v in range(0, 120)))
check('authored speed from a sliding-forward foot is smaller', abs(R.authoredSpeed(16, 2, 1) - 14) < 1e-9)
check('no authored speed from a standing sample', R.authoredSpeed(0.2, 0, 1) is None)
check('no authored speed when the foot outruns the body', R.authoredSpeed(10, 9.9, 1) is None)
check('rate clamps', R.rateFor(100, 10, S.MinRate, S.MaxRate) == S.MaxRate and R.rateFor(0, 10, S.MinRate, S.MaxRate) == S.MinRate)
check('blend authored mixes linearly', abs(R.blendAuthored(10, 20, 0.25) - 12.5) < 1e-9)

# --- simulated walker: the controller loop at 60 fps
def simulate(speed_plan, true_walk, true_run, seed, noise, rng):
    dt = 1 / 60
    walkA, runA, runW, rate = seed, seed, 0.0, 1.0
    wn, rn = 0.0, 0.0
    slips = []
    t = 0.0
    for (speed, seconds) in speed_plan:
        n = int(seconds / dt)
        for i in range(n):
            # preAnimation: weights + rate from the learned speeds
            want = R.runWeight(speed, S.BlendStart, S.BlendEnd)
            runW = R.follow(runW, want, 3 / S.WeightEase, dt)
            authored = R.blendAuthored(walkA, runA, runW if rn > 0 else 0)
            rate = R.rateFor(speed, authored, S.MinRate, S.MaxRate)
            # the "real" animation: the planted foot moves back at the TRUE authored speed x rate
            true_a = true_walk + (true_run - true_walk) * runW
            footVel = speed - true_a * rate + rng.gauss(0, noise)
            # postSimulation: learn
            a = R.authoredSpeed(speed, footVel, rate)
            if a is not None:
                if runW < 0.5:
                    own = R.unblend(a, runA if rn > 0 else None, runW)
                    if own is not None:
                        walkA, wn = R.learn(walkA, wn, own, dt, S.Memory)
                else:
                    own = R.unblend(a, walkA, 1 - runW)
                    if own is not None:
                        runA, rn = R.learn(runA, rn, own, dt, S.Memory)
            if i > n - int(1.0 / dt):  # the last second at this speed
                slips.append(abs(speed - true_a * rate))
            t += dt
    return slips, walkA, runA

rng = random.Random(7)
for (tw, tr, seed) in [(11.0, 19.0, 16.0), (14.5, 25.0, 9.0), (8.0, 15.0, 20.0)]:
    plan = [(14, 3), (16, 3), (24, 4), (16, 3), (12, 3)]
    slips, wa, ra = simulate(plan, tw, tr, seed, 1.5, rng)
    worst = max(slips)
    check(f'feet stick after settling (true walk {tw}, run {tr}, start guess {seed}): worst slip < 0.3 studs/s', worst < 0.3, round(worst, 3))
    check(f'learned walk/run authored speeds within 5% ({tw},{tr})', abs(wa - tw) / tw < 0.05 and abs(ra - tr) / tr < 0.05, (round(wa, 2), round(ra, 2)))

# settles fast enough to feel right: from a 40% wrong guess, slip < 1 stud/s within 1.5 s of walking
slips, _, _ = simulate([(16, 1.5)], 11.0, 19.0, 15.4, 0.0, rng)
check('settles from a 40% wrong guess within 1.5 s', slips[-1] < 1.0, round(slips[-1], 3))

print('\n%d failures' % fails)
sys.exit(1 if fails else 0)
