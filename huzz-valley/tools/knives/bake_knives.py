# Bakes the owner's 30 knife models (design/knives/Knives/NN_Rarity_Name.glb) and his 5 Game Pass knives (one file,
# design/knives/gamepass/Gamepass_Knives.glb, one child node per knife; rarity "Exclusive") into:
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
GAMEPASS = 'design/knives/gamepass/Gamepass_Knives.glb'  # (owner, Oct 18: "here are the gamepass knives")
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
NAMES = {'Dragons_Maw': "Dragon's Maw"}  # (display names where the node name lost an apostrophe)
DANGLE = ('tassel', 'chain')  # hanging bits: not part of pommel-to-tip
HANDLE = ('handle',)          # the grip itself (the fist closes on its middle)
MIN_STUDS, MAX_STUDS = 2.4, 3.3  # pommel to tip in the game (Huss Valley's are 2.7 to 3.0)


def hexof(material_name, js=None, binc=None, material=None):
    m = re.search(r'([0-9a-fA-F]{6})$', material_name)
    if m:
        return m.group(1).lower()
    # the gamepass knives: the colour is the material's little texture (names like "gold", "glow_ice_blade")
    if js is not None and material is not None:
        return glb.texture_colour(js, binc, material.get('texture')) or 'cccccc'
    return 'cccccc'


def knife_nodes(prims, js=None, binc=None, inv=None):
    """One knife's mesh nodes (centres in the knife's own frame: `inv` undoes the knife node's place in a file that
    holds several knives side by side)."""
    nodes = []
    for p in prims:
        lo, hi = p['local'].min(0), p['local'].max(0)
        m = p['matrix'] if inv is None else inv @ p['matrix']
        pos = p['pos'] if inv is None else (np.c_[p['pos'], np.ones(len(p['pos']))] @ inv.T)[:, :3]
        c = (m @ np.r_[(lo + hi) / 2, 1])[:3]
        mat = p['material']['name']
        nodes.append({'name': p['node'], 'c': [round(float(v), 4) for v in c], 'hex': hexof(mat, js, binc, p['material']), 'glow': mat.startswith('glow'),
                      'metal': round(float(p['material']['metal']), 2), 'kind': p['node'].rsplit('_', 1)[0],
                      'ymin': float(pos[:, 1].min()), 'ymax': float(pos[:, 1].max()),
                      'area': float(np.ptp(pos, 0)[0] * np.ptp(pos, 0)[1])})
    return nodes


def gamepass_knives():
    """(node name, mesh primitives, inverse of the knife node's world matrix, js, binc) per knife in the gamepass file."""
    if not os.path.exists(GAMEPASS):
        return []
    js, binc = glb.load(GAMEPASS)
    parent, world = {}, {}
    for i, n, m, depth, par in glb.walk(js):
        parent[i], world[i] = par, m
    root = js['scenes'][js.get('scene', 0)]['nodes'][0]
    prims = glb.meshes(js, binc)
    out = []
    for c in js['nodes'][root].get('children', []):
        def under(i, c=c):
            while i is not None:
                if i == c:
                    return True
                i = parent[i]
            return False
        mine = [p for p in prims if under(p['nodeIndex'])]
        out.append((js['nodes'][c]['name'], mine, np.linalg.inv(world[c]), js, binc))
    return out


def describe(node_name, nodes, rarity, file, root, num, key):
    core = [n for n in nodes if not n['kind'].startswith(DANGLE)]
    blade = [n for n in nodes if n['kind'] == 'blade'] or core
    handle = [n for n in nodes if n['kind'] in HANDLE] or core
    tip = max(n['ymax'] for n in blade)
    bottom = min(n['ymin'] for n in core)
    grip = (min(n['ymin'] for n in handle) + max(n['ymax'] for n in handle)) / 2
    glows = collections.Counter(n['hex'] for n in nodes if n['glow'])
    main_blade = max(blade, key=lambda n: n['area'])
    accent_kinds = ('guard_trim', 'guard', 'tsuba', 'guard_wing', 'ferrule', 'pommel', 'collar', 'crossguard', 'habaki', 'fuchi')
    accent = next((n['hex'] for k in accent_kinds for n in nodes if n['kind'] == k), main_blade['hex'])
    inlay = next((n['hex'] for n in nodes if n['kind'] == 'blade_inlay'), None)
    glow = glows.most_common(1)[0][0] if glows else None
    return {
        'file': file, 'node': root, 'num': num, 'rarity': rarity, 'key': key,
        'name': node_name.replace('_s_', "'s ").replace('_', ' '),
        'length': round(tip - bottom, 4), 'tip': round(tip, 4), 'bottom': round(bottom, 4), 'grip': round(grip, 4),
        'blade': main_blade['hex'], 'accent': accent, 'glow': glow, 'sheen': glow or inlay or 'ffffff',
        'glowParts': sum(1 for n in nodes if n['glow']), 'parts': len(nodes), 'nodes': nodes,
    }


def main():
    knives = []
    for f in sorted(os.listdir(SRC)):
        m = re.match(r'(\d\d)_(Common|Uncommon|Rare|Epic|Legendary|Mythic)_(.+)\.glb$', f)
        if not m:
            continue
        num, rarity, node_name = m.group(1), m.group(2), m.group(3)
        js, binc = glb.load(os.path.join(SRC, f))
        root = js['nodes'][js['scenes'][0]['nodes'][0]].get('name', node_name)
        nodes = knife_nodes(glb.meshes(js, binc))
        key = KEYS.get(node_name, node_name.replace('_s_', 's_').replace('_', ''))
        knives.append(describe(node_name, nodes, rarity, f[:-4], root, int(num), key))
    lengths = [k['length'] for k in knives]
    lo, hi = min(lengths), max(lengths)
    for k in knives:
        k['studs'] = round(MIN_STUDS + (k['length'] - lo) / (hi - lo) * (MAX_STUDS - MIN_STUDS), 2)
    # the Game Pass knives: numbered after the 30, sized on the same scale as the shop knives (kept in 2.4 to 3.3)
    for i, (node_name, prims, inv, js, binc) in enumerate(gamepass_knives()):
        key = node_name.replace('_s_', 's_').replace('_', '')
        k = describe(node_name, knife_nodes(prims, js, binc, inv), 'Exclusive', 'gamepass/Gamepass_Knives', node_name, 31 + i, key)
        k['name'] = NAMES.get(node_name, k['name'])
        # its effects' colour: the brightest, most colourful of its glowing parts (its blades are gradients, whose
        # average reads dull; the edges and gems carry the colour)
        def vivid(h):
            r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            return max(r, g, b) + (max(r, g, b) - min(r, g, b))
        glows = [n['hex'] for n in k['nodes'] if n['glow']]
        if glows:
            k['glow'] = k['sheen'] = max(glows, key=vivid)
        k['studs'] = round(min(MAX_STUDS, max(MIN_STUDS, MIN_STUDS + (k['length'] - lo) / (hi - lo) * (MAX_STUDS - MIN_STUDS))), 2)
        knives.append(k)

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
