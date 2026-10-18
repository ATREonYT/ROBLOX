# Bakes the owner's 30 knife models (design/knives/Knives/NN_Rarity_Name.glb) into:
#   tools/knives/knives.json                          one line per knife: key, name, rarity, length, colours, glow
#   tools/knives/setup_knives.lua                     the Studio Command Bar script (paste it whole)
#   src/ServerStorage/HuzzStudioTools/SetupKnives.lua the same script, shipped in the place
#                                                     (run: require(game.ServerStorage.HuzzStudioTools.SetupKnives)())
# The script's data: every mesh node's name, centre (in the knife's own units), colour and whether it glows, so it
# can find each imported knife, line it up whatever way Studio imported it, and set glow parts to Neon.
# Usage (from huzz-valley/): python3 -I tools/knives/bake_knives.py   (re-run when the .glb files change)
import json, os, re, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb
import numpy as np

SRC = 'design/knives/Knives'
HERE = 'tools/knives'
# Keys kept from before the owner's models, so saves that own them keep them (Config/CoinShop):
# the quest knives and the Spin Knife keep their unlock rules on the model that fits them best.
KEYS = {
    'Training_Kunai': 'RookieKnife',   # quest, chapter 2 ("Rookie" = a training kunai)
    'Hunter_s_Hook': 'HunterKnife',    # quest, chapter 3 (the name says it)
    'Hollow_Moon': 'MoonlitKnife',     # quest, chapter 4 (moon)
    'Celestial_Edge': 'SpinKnife',     # the wheel's Legendary (its old colours were pink, purple and cyan)
    'Ice_Shard': 'IceKnife',           # sold before (Ice Knife)
    'Sakura_Blade': 'CandyKnife',      # sold before (Candy Knife, pink)
    'Shadow_Cleaver': 'ShadowKnife',   # sold before (Shadow Knife)
}
DANGLE = ('tassel', 'chain')  # hanging bits: not part of pommel-to-tip
HANDLE = ('handle',)          # the grip itself (the fist closes on its middle)
MIN_STUDS, MAX_STUDS = 2.4, 3.3  # pommel to tip in the game (Huss Valley's are 2.7 to 3.0)


def hexof(material_name):
    m = re.search(r'([0-9a-fA-F]{6})$', material_name)
    return m.group(1).lower() if m else 'cccccc'


def main():
    knives = []
    for f in sorted(os.listdir(SRC)):
        m = re.match(r'(\d\d)_(Common|Uncommon|Rare|Epic|Legendary|Mythic)_(.+)\.glb$', f)
        if not m:
            continue
        num, rarity, node_name = m.group(1), m.group(2), m.group(3)
        js, binc = glb.load(os.path.join(SRC, f))
        root = js['nodes'][js['scenes'][0]['nodes'][0]].get('name', node_name)
        prims = glb.meshes(js, binc)
        nodes = []
        for p in prims:
            lo, hi = p['local'].min(0), p['local'].max(0)
            c = (p['matrix'] @ np.r_[(lo + hi) / 2, 1])[:3]
            mat = p['material']['name']
            nodes.append({'name': p['node'], 'c': [round(float(v), 4) for v in c], 'hex': hexof(mat), 'glow': mat.startswith('glow'),
                          'metal': round(float(p['material']['metal']), 2), 'kind': p['node'].rsplit('_', 1)[0],
                          'ymin': float(p['pos'][:, 1].min()), 'ymax': float(p['pos'][:, 1].max()),
                          'area': float(np.ptp(p['pos'], 0)[0] * np.ptp(p['pos'], 0)[1])})
        core = [n for n in nodes if not n['kind'].startswith(DANGLE)]
        blade = [n for n in nodes if n['kind'] == 'blade'] or core
        handle = [n for n in nodes if n['kind'] in HANDLE] or core
        tip = max(n['ymax'] for n in blade)
        bottom = min(n['ymin'] for n in core)
        grip = (min(n['ymin'] for n in handle) + max(n['ymax'] for n in handle)) / 2
        glows = collections.Counter(n['hex'] for n in nodes if n['glow'])
        main_blade = max(blade, key=lambda n: n['area'])
        accent_kinds = ('guard_trim', 'guard', 'tsuba', 'guard_wing', 'ferrule', 'pommel')
        accent = next((n['hex'] for k in accent_kinds for n in nodes if n['kind'] == k), main_blade['hex'])
        inlay = next((n['hex'] for n in nodes if n['kind'] == 'blade_inlay'), None)
        glow = glows.most_common(1)[0][0] if glows else None
        knives.append({
            'file': f[:-4], 'node': root, 'num': int(num), 'rarity': rarity,
            'key': KEYS.get(node_name, node_name.replace('_s_', 's_').replace('_', '')),
            'name': node_name.replace('_s_', "'s ").replace('_', ' '),
            'length': round(tip - bottom, 4), 'tip': round(tip, 4), 'bottom': round(bottom, 4), 'grip': round(grip, 4),
            'blade': main_blade['hex'], 'accent': accent, 'glow': glow, 'sheen': glow or inlay or 'ffffff',
            'glowParts': sum(1 for n in nodes if n['glow']), 'parts': len(nodes), 'nodes': nodes,
        })
    lengths = [k['length'] for k in knives]
    lo, hi = min(lengths), max(lengths)
    for k in knives:
        k['studs'] = round(MIN_STUDS + (k['length'] - lo) / (hi - lo) * (MAX_STUDS - MIN_STUDS), 2)

    summary = [{x: k[x] for x in ('num', 'file', 'node', 'key', 'name', 'rarity', 'length', 'studs', 'grip', 'tip', 'bottom', 'blade', 'accent', 'glow', 'sheen', 'parts', 'glowParts')} for k in knives]
    with open(os.path.join(HERE, 'knives.json'), 'w') as out:
        out.write('[\n' + ',\n'.join(json.dumps(s) for s in summary) + '\n]\n')

    # The Studio script's data: compact Luau rows.
    rows = []
    for k in knives:
        ns = ', '.join('{"%s",%g,%g,%g,"%s",%d}' % (n['name'], n['c'][0], n['c'][1], n['c'][2], n['hex'], 1 if n['glow'] else 0) for n in k['nodes'])
        rows.append('\t{ key = "%s", node = "%s", file = "%s", name = "%s", rarity = "%s", len = %g, studs = %g, grip = %g, tip = %g, glow = %s,\n\t\tnodes = { %s } },'
                    % (k['key'], k['node'], k['file'], k['name'].replace("'", "\\'"), k['rarity'], k['length'], k['studs'], k['grip'], k['tip'],
                       '"%s"' % k['glow'] if k['glow'] else 'nil', ns))
    data = 'local KNIVES = {\n' + '\n'.join(rows) + '\n}'
    template = open(os.path.join(HERE, 'setup_knives.template.lua')).read()
    body = template.replace('--@@KNIVES@@', data)
    head = '-- GENERATED by tools/knives/bake_knives.py from tools/knives/setup_knives.template.lua: edit those, not this.\n'
    with open(os.path.join(HERE, 'setup_knives.lua'), 'w') as out:
        out.write(head + body.replace('--@@RUN@@', 'run()'))
    with open('src/ServerStorage/HuzzStudioTools/SetupKnives.lua', 'w') as out:
        out.write(head + body.replace('--@@RUN@@', 'if script == nil then run() end -- (pasted whole into the Command Bar)\nreturn run'))
    for s in summary:
        print('%2d %-10s %-18s %-14s len %.3f -> %.2f studs  glow %s  parts %d' % (s['num'], s['rarity'], s['name'], s['key'], s['length'], s['studs'], s['glow'], s['parts']))


if __name__ == '__main__':
    main()
