#!/usr/bin/env python3
"""Build the one-time Studio import package from the user's blocky designs (brief 32).

Plain python3, no Blender. Reads the user's per-object .glb files (each: a body mesh `<Name>` plus `<Name>_2`, ...,
and glow meshes `<Name>_Glow_<RRGGBB>`, one palette PNG per object, studs, front -Z, pivot at the bottom / the gun
grip) and writes, into hood/art/models/items/:

  Items_Pads.glb, Items_Lobby.glb, Items_Scenery.glb, Items_Guns.glb
      every object of a category in one glTF binary, each under an empty node named by its GAME id, its meshes
      renamed `<GameId>`, `<GameId>_2`, `<GameId>_Glow_<hex>` (so the Studio script can file them by name), laid out
      in a row with gaps so the import shows them side by side. Mesh data and palette textures are copied byte for
      byte.
  manifest.json
      per id: source file, category, size / min / max in studs (design frame), pivot, glow parts, triangles,
      meshes, its offset in the package, and (guns) the muzzle point.

and regenerates hood/tools/blender/studio_item_meshes.lua and the ItemMeshes.Design table in Shared/ItemMeshes.lua from studio_item_meshes.template.lua (the design bounds,
the id list and each id's collision class go into the script).

  python3 hood/tools/blender/build_item_package.py --src <dir with Guns/ RobuxPads/ Lobby/> --src <...> [--list]
"""
import argparse, json, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HOOD, 'art', 'models', 'items')

# category -> (package file, [(source folder, source name, game id)])
GUNS = ['Pistol', 'Revolver', 'Uzi', 'Shotgun', 'Tommy', 'AK', 'Deagle', 'Minigun', 'Blaster', 'Diamond']
EXCLUSIVE = ['NeonViper', 'GalaxyRay', 'InfernoCannon', 'Frostbite', 'RoyalCrown']  # Robux guns: packaged, not wired
PADS = ['Base', 'VIP', 'DoubleCash', 'DoubleRep', 'AutoShoot', 'AutoCollect', 'AutoOpen', 'TripleOpen', 'Lucky',
	'Speed2x', 'ExtraEquip']
LOBBY = ['Gate_Stage1', 'Board_Boxes', 'Pedestal_Box', 'Stand_Guns', 'Board_Leaderboard', 'Chest_Codes',
	'Chest_GroupReward', 'Stand_SpinWheel', 'Portal_World2', 'Spawn_Pad']
SCENERY = ['Tree_1', 'Tree_2', 'Bush_1', 'Cliff_Block', 'Building_1', 'Building_2', 'Building_3', 'Building_4',
	'Hydrant', 'StreetLamp', 'Bench', 'TrashCan', 'Barrel', 'Crate', 'Cone', 'Fence', 'Sandbag', 'Car', 'Hoop',
	'GraffitiWall']

CATEGORIES = [
	('Pads', 'Items_Pads.glb', [('RobuxPads', 'Pad_' + n, 'Pad_' + n) for n in PADS]),
	('Lobby', 'Items_Lobby.glb', [('Lobby', n, n) for n in LOBBY] + [('ShootingRanges', 'Target_Dummy', 'Target_Dummy')]),
	('Scenery', 'Items_Scenery.glb', [('PlazaScenery', n, 'Scn_' + n) for n in SCENERY]),
	('Guns', 'Items_Guns.glb', [('Guns', 'Gun_' + n, 'Gun_' + n) for n in GUNS + EXCLUSIVE]),
]

# Collision class for the Studio script: 'solid' = CanCollide on with Box collision (big things players walk into),
# 'gun' = Massless, no collision; everything else ('prop') has CanCollide off.
# The low slabs players stand on (pad bases, the spawn, the box pedestals) are solid too, so feet do not sink in.
SOLID = {'Gate_Stage1', 'Stand_Guns', 'Board_Leaderboard', 'Stand_SpinWheel', 'Portal_World2', 'Pad_Base', 'Spawn_Pad',
	'Pedestal_Box', 'Scn_Cliff_Block', 'Scn_Building_1', 'Scn_Building_2', 'Scn_Building_3', 'Scn_Building_4',
	'Scn_Car', 'Scn_GraffitiWall', 'Scn_Fence', 'Scn_Tree_1', 'Scn_Tree_2'}
# Items whose one-box collision would block a walkway: invisible collider boxes (centre, size; design studs) instead,
# and the mesh itself does not collide. The gate's opening is |x| < 4.4 under the beam (y < 10).
COLLIDERS = {'Gate_Stage1': [((-7.25, 5, -0.15), (5.7, 10, 4.7)), ((7.25, 5, -0.15), (5.7, 10, 4.7)),
	((0, 12.1, -0.15), (20.2, 4.1, 4.4))]}

GAP = 4.0  # studs between items in the package row


def read_glb(path):
	b = open(path, 'rb').read()
	magic, _ver, _total = struct.unpack('<III', b[:12])
	assert magic == 0x46546C67, path
	jlen, jtype = struct.unpack('<II', b[12:20])
	j = json.loads(b[20:20 + jlen])
	off = 20 + jlen
	blen, _btype = struct.unpack('<II', b[off:off + 8])
	return j, b[off + 8:off + 8 + blen]


def accessor_floats(j, binary, idx):
	a = j['accessors'][idx]
	bv = j['bufferViews'][a['bufferView']]
	start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
	n = {'VEC3': 3, 'VEC2': 2, 'SCALAR': 1}[a['type']]
	stride = bv.get('byteStride', 4 * n)
	out = []
	for i in range(a['count']):
		out.append(struct.unpack_from('<%df' % n, binary, start + i * stride))
	return out


def find_src(srcs, folder, name):
	for s in srcs:
		for cand in (os.path.join(s, folder, 'glb', name + '.glb'), os.path.join(s, name + '.glb')):
			if os.path.exists(cand):
				return cand
	raise SystemExit('missing source %s/%s.glb (pass --src)' % (folder, name))


def r3(v):
	return [round(x, 3) for x in v]


def analyse(path, src_name, gid, category):
	j, binary = read_glb(path)
	lo, hi = [1e9] * 3, [-1e9] * 3
	meshes, glow, tris = [], [], 0
	muzzle_pts = []
	for nd in j['nodes']:
		if 'mesh' not in nd:
			continue
		assert not nd.get('rotation') and not nd.get('scale') and not nd.get('children'), (path, nd.get('name'))
		t = nd.get('translation', [0, 0, 0])
		name = nd['name']
		assert name == src_name or name.startswith(src_name + '_'), (path, name)
		new = gid + name[len(src_name):]
		ntri = 0
		mlo, mhi = [1e9] * 3, [-1e9] * 3
		for pr in j['meshes'][nd['mesh']]['primitives']:
			ntri += j['accessors'][pr['indices']]['count'] // 3
			a = j['accessors'][pr['attributes']['POSITION']]
			for k in range(3):
				lo[k] = min(lo[k], a['min'][k] + t[k])
				hi[k] = max(hi[k], a['max'][k] + t[k])
				mlo[k] = min(mlo[k], a['min'][k] + t[k])
				mhi[k] = max(mhi[k], a['max'][k] + t[k])
			if category == 'Guns':
				muzzle_pts += [tuple(p[k] + t[k] for k in range(3)) for p in accessor_floats(j, binary, pr['attributes']['POSITION'])]
		tris += ntri
		m = re.search(r'_Glow_([0-9A-Fa-f]{6})$', name)
		entry = {'name': new, 'tris': ntri, 'kind': 'glow' if m else 'body', 'min': r3(mlo), 'max': r3(mhi)}
		if m:
			entry['color'] = m.group(1).upper()
			glow.append(new)
		if t != [0, 0, 0]:
			entry['at'] = r3(t)
		meshes.append(entry)
	item = {
		'id': gid, 'category': category, 'source': os.path.relpath(path, os.path.dirname(os.path.dirname(os.path.dirname(path)))),
		'size': r3([hi[k] - lo[k] for k in range(3)]), 'min': r3(lo), 'max': r3(hi),
		'pivot': 'grip (origin), muzzle -Z' if category == 'Guns' else 'bottom centre (origin), front -Z',
		'glow': glow, 'triangles': tris, 'meshes': meshes,
		'collision': 'gun' if category == 'Guns' else ('solid' if gid in SOLID else 'prop'),
	}
	if gid in COLLIDERS:
		item['colliders'] = [{'centre': list(c), 'size': list(z)} for c, z in COLLIDERS[gid]]
	if category == 'Guns':
		zmin = min(p[2] for p in muzzle_pts)
		front = [p for p in muzzle_pts if p[2] < zmin + 0.12]
		item['muzzle'] = r3([0.0, sum(p[1] for p in front) / len(front), zmin])
		item['exclusive'] = gid[4:] in EXCLUSIVE
	return item, j, binary


def merge(entries, out_path):
	"""entries: [(item, gltf json, binary)] -> one GLB, each item under an empty node named by its id, in a row."""
	J = {'asset': {'version': '2.0', 'generator': 'hood build_item_package.py'}, 'scene': 0,
		'scenes': [{'name': 'HoodItemMeshes', 'nodes': []}], 'nodes': [], 'meshes': [], 'materials': [],
		'textures': [], 'images': [], 'samplers': [], 'accessors': [], 'bufferViews': [], 'buffers': []}
	blob = bytearray()
	x = 0.0
	for item, j, binary in entries:
		base = {k: len(J[k]) for k in ('nodes', 'meshes', 'materials', 'textures', 'images', 'samplers', 'accessors', 'bufferViews')}
		boff = len(blob)
		blob += binary
		while len(blob) % 4:
			blob.append(0)
		for bv in j['bufferViews']:
			bv = dict(bv)
			bv['buffer'] = 0
			bv['byteOffset'] = bv.get('byteOffset', 0) + boff
			J['bufferViews'].append(bv)
		for a in j['accessors']:
			a = dict(a)
			a['bufferView'] += base['bufferViews']
			J['accessors'].append(a)
		for s in j.get('samplers', []):
			J['samplers'].append(s)
		for im in j.get('images', []):
			im = dict(im)
			im['bufferView'] += base['bufferViews']
			im['name'] = item['id'] + '_palette' + im.get('name', '').split('_palette')[-1]
			J['images'].append(im)
		for t in j.get('textures', []):
			t = dict(t)
			t['source'] += base['images']
			if 'sampler' in t:
				t['sampler'] += base['samplers']
			J['textures'].append(t)
		for m in j.get('materials', []):
			m = json.loads(json.dumps(m))
			bct = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
			if bct:
				bct['index'] += base['textures']
			J['materials'].append(m)
		names = {mm['name'] for mm in item['meshes']}
		children = []
		src = item['_src']
		for nd in j['nodes']:
			if 'mesh' not in nd:
				continue
			new = item['id'] + nd['name'][len(src):]
			assert new in names
			mesh = json.loads(json.dumps(j['meshes'][nd['mesh']]))
			mesh['name'] = new
			for pr in mesh['primitives']:
				pr['indices'] += base['accessors']
				pr['attributes'] = {k: v + base['accessors'] for k, v in pr['attributes'].items()}
				if 'material' in pr:
					pr['material'] += base['materials']
			J['meshes'].append(mesh)
			node = {'name': new, 'mesh': len(J['meshes']) - 1}
			if nd.get('translation'):
				node['translation'] = nd['translation']
			J['nodes'].append(node)
			children.append(len(J['nodes']) - 1)
		lo, hi = item['min'], item['max']
		ox = round(x - lo[0], 3)
		x += (hi[0] - lo[0]) + GAP
		item['package_offset'] = [ox, 0, 0]
		J['nodes'].append({'name': item['id'], 'translation': [ox, 0, 0], 'children': children})
		J['scenes'][0]['nodes'].append(len(J['nodes']) - 1)
	# the row is centred on the origin so the import lands around the scene origin
	shift = -x / 2
	for i in J['scenes'][0]['nodes']:
		J['nodes'][i]['translation'][0] = round(J['nodes'][i]['translation'][0] + shift, 3)
	for item, _, _ in entries:
		item['package_offset'][0] = round(item['package_offset'][0] + shift, 3)
	J['buffers'] = [{'byteLength': len(blob)}]
	js = json.dumps(J, separators=(',', ':')).encode()
	while len(js) % 4:
		js += b' '
	total = 12 + 8 + len(js) + 8 + len(blob)
	with open(out_path, 'wb') as f:
		f.write(struct.pack('<III', 0x46546C67, 2, total))
		f.write(struct.pack('<II', len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack('<II', len(blob), 0x004E4942))
		f.write(blob)
	return total


def lua_vec(v):
	return '%s, %s, %s' % tuple(('%.3f' % c).rstrip('0').rstrip('.') for c in v)


def write_script(items):
	tpl = open(os.path.join(HERE, 'studio_item_meshes.template.lua')).read()
	lines = []
	for it in items:
		extra = ''
		if it.get('muzzle'):
			extra = ', muzzle = { %s }' % lua_vec(it['muzzle'])
		if it.get('colliders'):
			extra += ', colliders = { %s }' % ', '.join('{ %s, %s }' % (lua_vec(c['centre']), lua_vec(c['size'])) for c in it['colliders'])
		lines.append("\t%s = { %s, %s, '%s'%s }," % (it['id'], lua_vec(it['min']), lua_vec(it['max']), it['collision'], extra))
	text = tpl.replace('--@DESIGN@', '\n'.join(lines))
	text = text.replace('-- (Generated by', '-- (GENERATED by', 1)
	with open(os.path.join(HERE, 'studio_item_meshes.lua'), 'w') as f:
		f.write(text)


ITEMMESHES = os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'ItemMeshes.lua')


def write_design_table(items):
	"""ItemMeshes.Design between the BEGIN/END DESIGN markers of Shared/ItemMeshes.lua."""
	def v(x):
		return 'Vector3.new(%s)' % lua_vec(x)
	lines = ['ItemMeshes.Design = {']
	for it in items:
		extra = ", Muzzle = %s" % v(it['muzzle']) if it.get('muzzle') else ''
		if it.get('exclusive'):
			extra += ', Exclusive = true'
		lines.append("\t%s = { Min = %s, Max = %s, Collision = '%s'%s }," % (it['id'], v(it['min']), v(it['max']), it['collision'], extra))
	lines.append('}')
	text = open(ITEMMESHES).read()
	a = text.index('-- BEGIN DESIGN')
	a = text.index('\n', a) + 1
	b = text.index('-- END DESIGN')
	text = text[:a] + '\n'.join(lines) + '\n' + text[b:]
	with open(ITEMMESHES, 'w') as f:
		f.write(text)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--src', action='append', default=[], help='a folder holding Guns/ RobuxPads/ Lobby/ PlazaScenery/ ShootingRanges/')
	ap.add_argument('--list', action='store_true')
	ap.add_argument('--out', default=OUT)
	args = ap.parse_args()
	os.makedirs(args.out, exist_ok=True)
	manifest = {'about': 'The user\'s blocky designs (brief 32) as game ids. Studs, front -Z; pivot = bottom centre '
		'(props) or the grip (guns). size/min/max = the design bounds the game fits by (Shared/ItemMeshes). '
		'Import: hood/art/MESH_IMPORT.md.', 'packages': {}, 'items': []}
	for cat, fname, rows in CATEGORIES:
		entries = []
		for folder, src_name, gid in rows:
			path = find_src(args.src, folder, src_name)
			item, j, binary = analyse(path, src_name, gid, cat)
			item['_src'] = src_name
			item['package'] = fname
			entries.append((item, j, binary))
		size = merge(entries, os.path.join(args.out, fname))
		manifest['packages'][fname] = {'items': len(entries), 'bytes': size, 'triangles': sum(e[0]['triangles'] for e in entries)}
		for item, _, _ in entries:
			del item['_src']
			manifest['items'].append(item)
	with open(os.path.join(args.out, 'manifest.json'), 'w') as f:
		json.dump(manifest, f, indent=1)
	write_script(manifest['items'])
	write_design_table(manifest['items'])
	for it in manifest['items']:
		print('%-22s %-8s size %-22s tris %6d  meshes %d  glow %s%s' % (it['id'], it['category'], it['size'], it['triangles'],
			len(it['meshes']), ','.join(g.split('_Glow_')[1] for g in it['glow']) or '-', '  muzzle %s' % it['muzzle'] if 'muzzle' in it else ''))
	for k, v in manifest['packages'].items():
		print(k, v)
	big = [(it['id'], m['name'], m['tris']) for it in manifest['items'] for m in it['meshes'] if m['tris'] > 20000]
	if big:
		print('OVER 20k triangles:', big)
		return 1
	return 0


if __name__ == '__main__':
	sys.exit(main())
