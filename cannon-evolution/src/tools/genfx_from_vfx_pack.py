import xml.etree.ElementTree as ET, base64, struct, re
root = ET.parse('vfxpack/pack.rbxlx').getroot()
BAD = {"11749129449","11895782540","11917388916","12123878312","12906276200","13365068138"}
def props(item):
    p = item.find('Properties'); return {s.get('name'): s for s in (p if p is not None else [])}
def text(s):
    if s is None: return None
    u = s.find('uri')
    if u is not None: return (u.text or '').strip()
    if len(s): return {c.tag: (c.text or '').strip() for c in s}
    return (s.text or '').strip()
def nm(item): return text(props(item).get('Name'))
ws = [i for i in root.findall('Item') if i.get('class') == 'Workspace'][0]
def find(item, path):
    for c in item.findall('Item'):
        if nm(c) == path[0]:
            return c if len(path) == 1 else find(c, path[1:])
def g(x):
    v = round(float(x), 3); s = ('%g' % v)
    return '0' if s == '-0' else s
def flat(v, step, drop=None):
    f = v.split(); out = []
    for j in range(0, len(f), step):
        chunk = f[j:j+step]
        if drop is not None: chunk = [c for i, c in enumerate(chunk) if i not in drop]
        out += [g(c) for c in chunk]
    return '{' + ','.join(out) + '}'
def attrs(s):
    raw = text(s)
    if not raw: return {}
    b = base64.b64decode(raw); out = {}; i = 4
    for _ in range(struct.unpack_from('<I', b, 0)[0]):
        ln = struct.unpack_from('<I', b, i)[0]; i += 4
        k = b[i:i+ln].decode(); i += ln; t = b[i]; i += 1
        if t == 6: out[k] = struct.unpack_from('<d', b, i)[0]; i += 8
        elif t == 3: out[k] = bool(b[i]); i += 1
        else: break
    return out
DEF = {'Drag':'0','TimeScale':'1','VelocityInheritance':'0','ZOffset':'0','LightInfluence':'0','Brightness':'1','Rate':'20','LightEmission':'0'}
ENUM = {'EmissionDirection':'Dir','Orientation':'Ori','FlipbookLayout':'FbL','FlipbookMode':'FbM','Shape':'Shp','ShapeStyle':'ShS','ShapeInOut':'ShIO'}
def emitter(it):
    p = props(it); tid = re.sub(r'\D', '', text(p.get('TextureContent')) or '')
    if tid in BAD: return None
    L = [f'T={tid}']
    for k in ['Rate','LightEmission','LightInfluence','Brightness','ZOffset','Drag','TimeScale']:
        if k in p and g(text(p[k])) != DEF.get(k): L.append(f"{k}={g(text(p[k]))}")
    for k in ['LockedToPart','FlipbookStartRandom']:
        if k in p and text(p[k]) == 'true': L.append(f"{k}=true")
    if 'Enabled' in p and text(p['Enabled']) == 'false': L.append("Enabled=false")
    L.append(f"Size={flat(text(p['Size']),3)}")
    t = text(p['Transparency']);
    if t.split()[1::3] != ['0','0'] : L.append(f"Tr={flat(t,3)}")
    sq = text(p.get('Squash'));
    if sq and any(float(x) != 0 for x in sq.split()[1::3]): L.append(f"Sq={flat(sq,3)}")
    L.append(f"Col={flat(text(p['Color']),5,drop={4})}")
    for k, s in [('Lifetime','Life'),('Rotation','Rot'),('RotSpeed','RotS'),('FlipbookFramerate','FbR'),('Speed','Spd')]:
        v = text(p.get(k))
        if v and not (k in ('Rotation','RotSpeed') and all(float(x) == 0 for x in v.split()[:2])): L.append(f"{s}={{{g(v.split()[0])},{g(v.split()[1])}}}")
    sa = text(p.get('SpreadAngle'))
    if sa and (float(sa['X']) or float(sa['Y'])): L.append(f"Spr={{{g(sa['X'])},{g(sa['Y'])}}}")
    ac = text(p.get('Acceleration'))
    if ac and any(float(ac[k]) for k in 'XYZ'): L.append(f"Acc={{{g(ac['X'])},{g(ac['Y'])},{g(ac['Z'])}}}")
    for k, s in ENUM.items():
        v = text(p.get(k))
        if v not in (None, '') and int(float(v)) != 0: L.append(f"{s}={int(float(v))}")
    em = {k[4:]: v for k, v in attrs(p.get('AttributesSerialize')).items() if k.startswith('Emit')}
    if em: L.append("Emit={" + ",".join(f"{k}={g(v)}" for k, v in em.items()) + "}")
    return "{" + ",".join(L) + "}"
def beam(it):
    p = props(it); tid = re.sub(r'\D', '', text(p.get('TextureContent')) or '')
    if tid in BAD: return None
    L = [f'T={tid}']
    for k in ['LightEmission','LightInfluence','Brightness','TextureLength','TextureSpeed','CurveSize0','CurveSize1','Width0','Width1','ZOffset','Segments']:
        if k in p: L.append(f"{k}={g(text(p[k]))}")
    if 'FaceCamera' in p and text(p['FaceCamera']) == 'true': L.append("FaceCamera=true")
    L.append(f"Tr={flat(text(p['Transparency']),3)}")
    L.append(f"Col={flat(text(p['Color']),5,drop={4})}")
    L.append(f"TM={int(float(text(p['TextureMode'])))}")
    return "{" + ",".join(L) + "}", text(p.get('Attachment0')), text(p.get('Attachment1'))
def template(key, g0):
    atts, beams = [], []
    def walk(it, part):
        cls = it.get('class')
        if cls in ('Part', 'MeshPart'): part = it
        ems = [emitter(c) for c in it.findall('Item') if c.get('class') == 'ParticleEmitter']
        ems = [e for e in ems if e]
        for c in it.findall('Item'):
            if c.get('class') == 'Beam':
                b = beam(c)
                if b: beams.append(b)
        if cls == 'Attachment' or ems:
            pos = text(props(it)['CFrame']) if cls == 'Attachment' else {'X':'0','Y':'0','Z':'0'}
            atts.append((it.get('referent'), nm(part) if part is not None else '', [g(pos[k]) for k in 'XYZ'], ems))
        for c in it.findall('Item'): walk(c, part)
    walk(g0, None)
    idx = {a[0]: i + 1 for i, a in enumerate(atts)}
    s = f"\t{key} = {{\n\t\tAtt = {{\n"
    for ref, pn, pos, ems in atts:
        s += f'\t\t\t{{P="{pn}",At={{{",".join(pos)}}},E={{' + (",\n\t\t\t\t".join(ems) if ems else "") + "}},\n"
    s += "\t\t},\n\t\tBeams = {" + ",".join(f"{{A0={idx.get(a0,0)},A1={idx.get(a1,0)},B={b}}}" for b, a0, a1 in beams) + "},\n\t},"
    return s
SEL = [('Charge', ['Anime','Charge-01']), ('Shoot', ['Anime','Shoot-01']), ('Stars', ['Anime','Stars-01']), ('Shiny', ['Anime','Shiny-01']),
 ('Lightning', ['Big','Lighting-01']), ('Lightning2', ['Anime','Lighting-03']), ('Explosion', ['Big','Explosion-01']),
 ('Crack', ['Big','Big-Crack-01']), ('HolyAura', ['Auras','RNG-Aura-02'])]
parts = [template(k, find(ws, p)) for k, p in SEL]
# fire aura: one emitter spec, used on every limb
fa = find(ws, ['Auras','Fire-Aura-01']); fe = [emitter(e) for e in fa.iter('Item') if e.get('class') == 'ParticleEmitter' and nm(e) == 'T'][0]
parts.append(f"\tFireAura = {fe},")
for c in ws.findall('Item'):
    if c.get('class') == 'Part' and any(nm(e) == 'Flash' and e.get('class') == 'ParticleEmitter' for e in c.findall('Item')):
        parts.append(template('Flash', c)); break
print("--[[\n\tRareFXPack (ModuleScript): effect templates from Alex's \"VFX PACK.rbxl\" (Oct 31), as data, built by\n\tAnimeFX at run time (scripts/genfx2.py made this file). Texture owners checked with GetProductInfo:\n\tcommunity Creator Store uploads; textures that look ripped from commercial games (T_eff_*, Okami*) are left out.\n\tKeys: T texture id, Size/Tr/Sq {time, value, envelope, ...}, Col {time, r, g, b, ...}, Life/Rot/RotS/FbR/Spd {min, max},\n\tSpr {x, y}, Acc {x, y, z}, Dir/Ori/FbL/FbM/Shp enum values, Emit {Count, Delay, Duration} (VFX Forge attributes).\n]]\nreturn {\n" + "\n".join(parts) + "\n}")
