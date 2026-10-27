# avatar.py scene.json out.json x,z,yaw[;x,z,yaw...] [y]: adds a blocky R15-ish avatar (map frame; world x + 2400) per spot
import json, sys, math
d = json.load(open(sys.argv[1])); spots = [s.split(',') for s in sys.argv[3].split(';')]
y0 = float(sys.argv[4]) if len(sys.argv) > 4 else 0.12
def C(r, g, b): return [r / 255, g / 255, b / 255]
for sp in spots:
    x, z, yaw = 2400 + float(sp[0]), float(sp[1]), math.radians(float(sp[2]) if len(sp) > 2 else 0)
    base = float(sp[3]) if len(sp) > 3 else y0
    c, s = math.cos(yaw), math.sin(yaw)
    def part(n, size, off, col):
        ox, oy, oz = off
        wx, wz = x + c * ox + s * oz, z - s * ox + c * oz
        d['parts'].append({'c': col, 'cf': [wx, base + oy, wz, c, 0, s, 0, 1, 0, -s, 0, c], 'k': 'Part', 'm': 'SmoothPlastic', 'n': n, 's': size, 'sh': 'Block', 'shadow': True, 't': 0})
    part('AvLegL', [0.95, 2, 1], (-0.5, 1.0, 0), C(40, 110, 60)); part('AvLegR', [0.95, 2, 1], (0.5, 1.0, 0), C(40, 110, 60))
    part('AvTorso', [2, 2, 1], (0, 3.0, 0), C(30, 110, 190))
    part('AvArmL', [0.95, 2, 1], (-1.5, 3.0, 0), C(245, 205, 48)); part('AvArmR', [0.95, 2, 1], (1.5, 3.0, 0), C(245, 205, 48))
    part('AvHead', [1.25, 1.2, 1.2], (0, 4.6, 0), C(245, 205, 48))
json.dump(d, open(sys.argv[2], 'w'))
