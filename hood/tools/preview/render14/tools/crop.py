# crop.py in.json scene.json plan.json [S]: keep the lobby hall, the forecourt and the first ~3 stages (for the spawn's
# sightline), and anything huge; plan.json also drops the roof (Roof*) and the hall's hanging lamps (Lamp* over 20 up) for the top-down view, and the south wall's
# tall parts (z > S - 6, above 5 studs) so the oblique overview from over the south wall sees the hall.
import json, sys
d = json.load(open(sys.argv[1]))
S = float(sys.argv[4]) if len(sys.argv) > 4 else 122
def keep(p):
    x, y, z = p['cf'][0], p['cf'][1], p['cf'][2]
    if max(p['s']) > 150: return True
    return 2400 - 140 <= x <= 2400 + 140 and -200 <= z <= 200
out = {k: v for k, v in d.items() if k != 'parts'}
out['parts'] = [p for p in d['parts'] if keep(p)]
json.dump(out, open(sys.argv[2], 'w'))
def southWall(p):
    x, y, z = p['cf'][0], p['cf'][1], p['cf'][2]
    return z > S - 6 and y > 5 and max(p['s']) < 150
plan = dict(out)
plan['parts'] = [p for p in out['parts'] if not str(p.get('n', '')).startswith('Roof') and not (str(p.get('n', '')).startswith('Lamp') and p['cf'][1] > 20) and p['cf'][2] > -30 and not southWall(p)]
json.dump(plan, open(sys.argv[3], 'w'))
print('crop', len(d['parts']), '->', len(out['parts']), 'plan', len(plan['parts']))
