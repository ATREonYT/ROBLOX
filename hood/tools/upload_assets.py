#!/usr/bin/env python3
"""Upload the HUD icons and UI textures to Roblox (Open Cloud Assets API) and write the ids into the game code.

Plain python3 (3.8+), standard library only: runs on a Mac with no pip installs.

  export ROBLOX_API_KEY='...'          # Creator Dashboard > Open Cloud > API Keys, with "Assets" Read + Write
  export ROBLOX_CREATOR_ID=1234567     # your user id (roblox.com/users/<id>/profile) or the group id
  export ROBLOX_CREATOR_TYPE=User      # or Group
  python3 hood/tools/upload_assets.py --dry-run    # what would be uploaded and written; no network, no file changes
  python3 hood/tools/upload_assets.py              # upload new/changed PNGs, write the ids

What it uploads: every PNG in hood/art/icons3d/ (-> IconModels.Images[<file name>]) and hood/art/ui/ (-> the UIKit line
`Kit.<Name> = '...' -- hood/art/ui/<file>.png`). Ids go in as 'rbxassetid://<id>'.

Idempotent: hood/art/asset_ids.json remembers the sha256 and asset id of every uploaded file. Unchanged files are not
uploaded again (their ids are still written, so a re-run repairs the Lua files); a changed PNG is uploaded as a new
asset. Options: --only Basket,stud_tile (names without .png), --force (re-upload everything), --write-only (no uploads:
write the ids already in the manifest), --asset-type Image|Decal (default Image: ImageLabels need image ids),
--status (no uploads: ask Roblox whether each uploaded picture is approved, still in review or rejected).

The API key is only ever sent in the x-api-key header. It is never printed or written anywhere, and any text that
comes back from the server is scrubbed of it before it is shown.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.abspath(os.path.join(HERE, '..'))  # the hood/ folder
API = 'https://apis.roblox.com'
ICON_MODULE = os.path.join('src', 'ReplicatedStorage', 'Shared', 'Models', 'IconModels.lua')
UIKIT = os.path.join('src', 'ReplicatedStorage', 'Shared', 'UIKit.lua')
MANIFEST = os.path.join('art', 'asset_ids.json')
SOURCES = (('icons3d', 'icon'), ('ui', 'texture'))
SECRET = []  # the key, only so it can be scrubbed from server text


class UploadError(Exception):
	pass


def scrub(text):
	text = str(text)
	for s in SECRET:
		if s:
			text = text.replace(s, '***')
	return text


def log(*parts):
	print(scrub(' '.join(str(p) for p in parts)), flush=True)


# ------------------------------------------------------------------------------------------------- files
def sha256(path):
	h = hashlib.sha256()
	with open(path, 'rb') as f:
		for chunk in iter(lambda: f.read(1 << 16), b''):
			h.update(chunk)
	return h.hexdigest()


def png_size(path):
	with open(path, 'rb') as f:
		head = f.read(24)
	if head[:8] != b'\x89PNG\r\n\x1a\n':
		raise UploadError('%s is not a PNG' % path)
	return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def collect(root, only):
	"""[(key, abs_path, kind, name)] for every PNG to handle. key = path relative to hood/art (e.g. icons3d/Basket.png)."""
	out = []
	for folder, kind in SOURCES:
		d = os.path.join(root, 'art', folder)
		if not os.path.isdir(d):
			continue
		for fn in sorted(os.listdir(d)):
			if not fn.lower().endswith('.png'):
				continue
			name = fn[:-4]
			if only and name not in only:
				continue
			out.append(('%s/%s' % (folder, fn), os.path.join(d, fn), kind, name))
	return out


def load_manifest(root):
	p = os.path.join(root, MANIFEST)
	if os.path.exists(p):
		with open(p) as f:
			return json.load(f)
	return {}


def save_manifest(root, data):
	p = os.path.join(root, MANIFEST)
	tmp = p + '.tmp'
	with open(tmp, 'w') as f:
		json.dump(data, f, indent=1, sort_keys=True)
		f.write('\n')
	os.replace(tmp, p)


def write_text(path, text):
	tmp = path + '.tmp'
	with open(tmp, 'w', newline='') as f:
		f.write(text)
	os.replace(tmp, path)


# ------------------------------------------------------------------------------------------------- Lua writers
IMAGES_BLOCK = re.compile(r'(M\.Images = \{\n)(.*?)(\n\})', re.S)


def set_icon_images(text, ids):
	"""Set M.Images[<Id>] = 'rbxassetid://N' in IconModels.lua; new ids are appended to the block.
	Returns (text, changes)."""
	m = IMAGES_BLOCK.search(text)
	if not m:
		raise UploadError('IconModels.lua: no "M.Images = {" block found')
	lines = m.group(2).split('\n') if m.group(2) else []
	changes = []
	for iid, value in sorted(ids.items()):
		pat = re.compile(r"^(\s*)%s(\s*=\s*)'([^']*)'(.*)$" % re.escape(iid))
		for i, line in enumerate(lines):
			mm = pat.match(line)
			if mm:
				if mm.group(3) != value:
					lines[i] = "%s%s%s'%s'%s" % (mm.group(1), iid, mm.group(2), value, mm.group(4))
					changes.append('IconModels.Images.%s: %r -> %r' % (iid, mm.group(3), value))
				break
		else:
			lines.append("\t%s = '%s', -- %s" % (iid, value, iid))
			changes.append('IconModels.Images.%s: (new key) -> %r' % (iid, value))
	text = text[:m.start()] + m.group(1) + '\n'.join(lines) + m.group(3) + text[m.end():]
	return text, changes


# The UIKit field each texture belongs to (used when a line has no `-- hood/art/ui/<file>.png` comment).
TEXTURE_FIELDS = {'stud_tile.png': 'StudTile', 'stud_bevel.png': 'StudBevel', 'stud_checker.png': 'StudChecker',
	'gloss_band.png': 'GlossBand', 'gloss_stripes.png': 'GlossStripes', 'splat.png': 'Splat', 'splat_rainbow.png': 'SplatRainbow',
	'splat_black.png': 'SplatBlack'}
KIT_LINE = re.compile(r"^(\s*Kit\.(\w+)\s*=\s*)'([^']*)'([^\n]*?--\s*(?:hood/)?art/ui/([\w.\-]+\.png)[^\n]*)$", re.M)


def set_kit_textures(text, files):
	"""files: {'stud_tile.png': 'rbxassetid://N'}. Rewrites each `Kit.<Name> = '...' -- hood/art/ui/<file>.png` line.
	Returns (text, changes, missing files)."""
	changes, seen = [], set()

	def sub(mm):
		fn = mm.group(5)
		if fn not in files:
			return mm.group(0)
		seen.add(fn)
		value = files[fn]
		if mm.group(3) != value:
			changes.append('UIKit Kit.%s (%s): %r -> %r' % (mm.group(2), fn, mm.group(3), value))
		return "%s'%s'%s" % (mm.group(1), value, mm.group(4))
	text = KIT_LINE.sub(sub, text)
	# Fallback: a known field written without the trailing file comment (e.g. `Kit.StudTile = ''`).
	for fn in sorted(set(files) - seen):
		field = TEXTURE_FIELDS.get(fn)
		if not field:
			continue
		pat = re.compile(r"^(\s*Kit\.%s\s*=\s*)'([^']*)'(.*)$" % field, re.M)
		mm = pat.search(text)
		if mm:
			seen.add(fn)
			if mm.group(2) != files[fn]:
				changes.append('UIKit Kit.%s (%s): %r -> %r' % (field, fn, mm.group(2), files[fn]))
			text = text[:mm.start()] + "%s'%s'%s" % (mm.group(1), files[fn], mm.group(3)) + text[mm.end():]
	missing = sorted(set(files) - seen)
	return text, changes, missing


def apply_ids(root, ids_by_key, dry):
	"""Write ids into IconModels.lua and UIKit.lua. ids_by_key: {'icons3d/Basket.png': 'rbxassetid://N', ...}."""
	icons = {k.split('/', 1)[1][:-4]: v for k, v in ids_by_key.items() if k.startswith('icons3d/')}
	textures = {k.split('/', 1)[1]: v for k, v in ids_by_key.items() if k.startswith('ui/')}
	all_changes = []
	if icons:
		p = os.path.join(root, ICON_MODULE)
		with open(p) as f:
			old = f.read()
		new, changes = set_icon_images(old, icons)
		all_changes += changes
		if new != old and not dry:
			write_text(p, new)
	if textures:
		p = os.path.join(root, UIKIT)
		with open(p) as f:
			old = f.read()
		new, changes, missing = set_kit_textures(old, textures)
		all_changes += changes
		for fn in missing:
			log("  ! UIKit.lua has no line for %s; add one like:  Kit.<Name> = '' -- hood/art/ui/%s  then re-run with "
				"--write-only (its id is kept in %s)" % (fn, fn, MANIFEST))
		if new != old and not dry:
			write_text(p, new)
	return all_changes


# ------------------------------------------------------------------------------------------------- HTTP
def ssl_context():
	ctx = ssl.create_default_context()
	return ctx


def http(method, url, key, body=None, ctype=None, tries=6):
	headers = {'x-api-key': key, 'Accept': 'application/json', 'User-Agent': 'hood-upload-assets/1.0'}
	if ctype:
		headers['Content-Type'] = ctype
	delay = 2.0
	for attempt in range(tries):
		req = urllib.request.Request(url, data=body, method=method, headers=headers)
		try:
			with urllib.request.urlopen(req, timeout=60, context=ssl_context() if url.startswith('https') else None) as r:
				raw = r.read().decode('utf-8', 'replace')
				return json.loads(raw) if raw.strip() else {}
		except urllib.error.HTTPError as e:
			text = scrub(e.read().decode('utf-8', 'replace'))[:400]
			if e.code == 429 or e.code >= 500:
				wait = float(e.headers.get('Retry-After') or delay)
				log('  .. HTTP %d, retrying in %.0fs' % (e.code, wait))
				time.sleep(wait)
				delay = min(delay * 2, 60)
				continue
			hint = ''
			if e.code in (401, 403):
				hint = (' (check: the key has the Assets API with Read + Write, the key\'s IP allow-list includes this '
					'machine (or 0.0.0.0/0), ROBLOX_CREATOR_ID/TYPE are you or a group you can upload to)')
			raise UploadError('HTTP %d from %s: %s%s' % (e.code, url.split('?')[0], text, hint))
		except urllib.error.URLError as e:
			if isinstance(getattr(e, 'reason', None), ssl.SSLCertVerificationError):
				raise UploadError('TLS certificate check failed. On a Mac with python.org Python run "/Applications/Python 3.x/'
					'Install Certificates.command" once, or use /usr/bin/python3.')
			if attempt < tries - 1:
				log('  .. network error (%s), retrying in %.0fs' % (scrub(e.reason), delay))
				time.sleep(delay)
				delay = min(delay * 2, 60)
				continue
			raise UploadError('network error: %s' % scrub(e.reason))
	raise UploadError('gave up after %d tries: %s' % (tries, url))


def multipart(fields):
	"""fields: [(name, filename or None, bytes, content_type or None)] -> (body, content type)."""
	boundary = '----hood' + uuid.uuid4().hex
	out = bytearray()
	for name, filename, data, ctype in fields:
		out += ('--%s\r\n' % boundary).encode()
		disp = 'form-data; name="%s"' % name
		if filename:
			disp += '; filename="%s"' % filename
		out += ('Content-Disposition: %s\r\n' % disp).encode()
		if ctype:
			out += ('Content-Type: %s\r\n' % ctype).encode()
		out += b'\r\n' + data + b'\r\n'
	out += ('--%s--\r\n' % boundary).encode()
	return bytes(out), 'multipart/form-data; boundary=%s' % boundary


def upload_one(cfg, path, display, description):
	creator = {'userId': cfg.creator_id} if cfg.creator_type == 'user' else {'groupId': cfg.creator_id}
	request = {'assetType': cfg.asset_type, 'displayName': display[:50], 'description': description[:1000],
		'creationContext': {'creator': creator}}
	with open(path, 'rb') as f:
		data = f.read()
	body, ctype = multipart([('request', None, json.dumps(request).encode('utf-8'), None),
		('fileContent', os.path.basename(path), data, 'image/png')])
	op = http('POST', cfg.api + '/assets/v1/assets', cfg.key, body, ctype)
	op_id = op.get('operationId') or (op.get('path') or '').split('/')[-1]
	if not op_id:
		raise UploadError('no operation id in the response: %s' % scrub(json.dumps(op))[:300])
	deadline = time.time() + cfg.timeout
	wait = 1.0
	while not op.get('done'):
		if time.time() > deadline:
			raise UploadError('operation %s still not done after %ds (re-run later; nothing is lost)' % (op_id, cfg.timeout))
		time.sleep(wait)
		wait = min(wait * 1.5, 5)
		op = http('GET', cfg.api + '/assets/v1/operations/' + op_id, cfg.key)
	if op.get('error'):
		raise UploadError('upload failed: %s' % scrub(json.dumps(op['error']))[:300])
	resp = op.get('response') or {}
	asset_id = str(resp.get('assetId') or (resp.get('path') or '').split('/')[-1])
	if not asset_id.isdigit():
		raise UploadError('no asset id in the finished operation: %s' % scrub(json.dumps(op))[:300])
	state = ((resp.get('moderationResult') or {}).get('moderationState') or '').replace('MODERATION_STATE_', '').lower()
	return asset_id, state or 'unknown', (resp.get('assetType') or cfg.asset_type)


def moderation_of(cfg, asset_id):
	"""The picture's moderation state now: 'approved', 'reviewing', 'rejected' or 'unknown'."""
	resp = http('GET', cfg.api + '/assets/v1/assets/' + asset_id + '?readMask=moderationResult', cfg.key)
	state = ((resp.get('moderationResult') or {}).get('moderationState') or '').replace('MODERATION_STATE_', '').lower()
	return state or 'unknown'


def show_status(cfg, root, files):
	"""--status: ask Roblox about every uploaded picture, print the list, and remember the answers in the manifest."""
	manifest = load_manifest(root)
	groups = {}
	for key_, path, kind, name in files:
		rec = manifest.get(key_) or {}
		if not rec.get('assetId'):
			groups.setdefault('not uploaded', []).append(name)
			continue
		try:
			state = moderation_of(cfg, rec['assetId'])
		except UploadError as e:
			log('  ? %s: %s' % (key_, e))
			state = 'unknown'
		if state != 'unknown':
			rec['moderation'] = state
			manifest[key_] = rec
		groups.setdefault(state, []).append(name)
	save_manifest(root, manifest)
	for state in ('approved', 'reviewing', 'rejected', 'unknown', 'not uploaded'):
		names = groups.get(state) or []
		if names:
			log('  %-12s %3d  %s' % (state.upper(), len(names), ', '.join(sorted(names))))
	if groups.get('rejected'):
		log('Rejected pictures stay blank in the game. Tell Claude which ones; they get redrawn and uploaded again.')
	if groups.get('reviewing'):
		log('Pictures in review show as simple stand-ins until Roblox approves them (usually minutes, sometimes hours).')
	if groups.get('not uploaded'):
		log('Not uploaded yet: run this tool without --status to upload them.')
	return 1 if groups.get('rejected') else 0


# ------------------------------------------------------------------------------------------------- main
def parse(argv):
	ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument('--dry-run', action='store_true', help='show the plan; no network, no file changes')
	ap.add_argument('--only', default='', help='comma-separated file names without .png (e.g. Basket,stud_tile)')
	ap.add_argument('--force', action='store_true', help='upload even files whose sha256 is already in the manifest')
	ap.add_argument('--write-only', action='store_true', help='no uploads: write the ids already in the manifest')
	ap.add_argument('--status', action='store_true', help='no uploads: show which uploaded pictures Roblox has approved')
	ap.add_argument('--asset-type', default='Image', choices=['Image', 'Decal'])
	ap.add_argument('--timeout', type=int, default=120, help='seconds to wait for each upload operation')
	ap.add_argument('--root', default=DEFAULT_ROOT, help=argparse.SUPPRESS)  # the hood/ folder (tests)
	ap.add_argument('--api', default=API, help=argparse.SUPPRESS)  # API base URL (tests)
	return ap.parse_args(argv)


def main(argv=None):
	a = parse(sys.argv[1:] if argv is None else argv)
	root = os.path.abspath(a.root)
	only = set(x.strip() for x in a.only.split(',') if x.strip())
	key = os.environ.get('ROBLOX_API_KEY', '').strip()
	SECRET.append(key)
	creator_id = os.environ.get('ROBLOX_CREATOR_ID', '').strip()
	creator_type = os.environ.get('ROBLOX_CREATOR_TYPE', 'User').strip().lower()
	log('hood upload_assets: root %s%s' % (root, ' (DRY RUN: no network, no writes)' if a.dry_run else ''))
	log('  ROBLOX_API_KEY: %s   ROBLOX_CREATOR_ID: %s   ROBLOX_CREATOR_TYPE: %s' % (
		'set (hidden)' if key else 'MISSING', creator_id or 'MISSING', creator_type))
	need_net = (not a.write_only and not a.dry_run) or a.status
	problems = []
	if need_net or a.dry_run:
		if not key:
			problems.append('ROBLOX_API_KEY is not set')
		if not creator_id.isdigit() and not a.status:
			problems.append('ROBLOX_CREATOR_ID must be your numeric user id or group id')
		if creator_type not in ('user', 'group') and not a.status:
			problems.append('ROBLOX_CREATOR_TYPE must be User or Group')
	if problems and need_net:
		for p in problems:
			log('error:', p)
		return 2
	for p in problems:
		log('  ! (needed for a real run) %s' % p)

	files = collect(root, only)
	if not files:
		log('nothing to do: no PNGs in art/icons3d or art/ui%s' % (' matching --only' if only else ''))
		return 0
	if a.status:
		class StatusCfg:
			pass
		scfg = StatusCfg()
		scfg.key, scfg.api = key, a.api.rstrip('/')
		log('  asking Roblox about %d pictures ...' % len(files))
		return show_status(scfg, root, files)
	manifest = load_manifest(root)
	plan = []
	for key_, path, kind, name in files:
		digest = sha256(path)
		rec = manifest.get(key_)
		w, h = png_size(path)
		if a.write_only:
			status = 'keep' if rec and rec.get('assetId') else 'no-id'
		elif rec and rec.get('assetId') and rec.get('sha256') == digest and not a.force:
			status = 'unchanged'
		else:
			status = 'changed' if rec and rec.get('assetId') else 'new'
		plan.append((key_, path, kind, name, digest, status, (w, h)))
	counts = {}
	for p in plan:
		counts[p[5]] = counts.get(p[5], 0) + 1
	log('  %d PNGs: %s' % (len(plan), ', '.join('%d %s' % (n, s) for s, n in sorted(counts.items()))))
	for key_, path, kind, name, digest, status, (w, h) in plan:
		target = "IconModels.Images.%s" % name if kind == 'icon' else "Kit line '-- hood/art/ui/%s.png'" % name
		rec = manifest.get(key_) or {}
		have = (' (has rbxassetid://%s)' % rec['assetId']) if rec.get('assetId') else ''
		log('  %-9s %-28s %4dx%-4d -> %s%s' % (status.upper(), key_, w, h, target, have))

	class Cfg:
		pass
	cfg = Cfg()
	cfg.key, cfg.api, cfg.timeout = key, a.api.rstrip('/'), a.timeout
	cfg.creator_id, cfg.creator_type, cfg.asset_type = creator_id, creator_type, a.asset_type

	ids = {}
	failures = 0
	uploaded = 0
	for key_, path, kind, name, digest, status, size in plan:
		rec = manifest.get(key_) or {}
		if status in ('unchanged', 'keep'):
			ids[key_] = 'rbxassetid://%s' % rec['assetId']
			continue
		if status == 'no-id':
			continue
		if a.dry_run:
			ids[key_] = 'rbxassetid://<new>'
			continue
		display = 'Hood %s %s' % ('Icon' if kind == 'icon' else 'UI', name)
		desc = '+1 Hood Evolution %s (%s)' % ('HUD icon' if kind == 'icon' else 'UI texture', key_)
		try:
			log('  uploading %s ...' % key_)
			asset_id, state, atype = upload_one(cfg, path, display, desc)
		except UploadError as e:
			failures += 1
			log('  FAILED %s: %s' % (key_, e))
			continue
		manifest[key_] = {'sha256': digest, 'assetId': asset_id, 'assetType': atype, 'moderation': state,
			'uploaded': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}
		save_manifest(root, manifest)  # after every upload, so an interrupted run loses nothing
		ids[key_] = 'rbxassetid://%s' % asset_id
		uploaded += 1
		log('  ok %s -> rbxassetid://%s (moderation: %s)' % (key_, asset_id, state))
		if a.asset_type == 'Decal':
			log('  ! uploaded as a Decal: ImageLabels need the IMAGE id. Paste rbxassetid://%s into any ImageLabel.Image '
				'in Studio; it turns into the image id: put that one in the Lua file (or re-run with --asset-type Image).' % asset_id)

	changes = apply_ids(root, ids, a.dry_run)
	verb = 'would write' if a.dry_run else 'wrote'
	if changes:
		log('  %s %d id(s):' % (verb, len(changes)))
		for c in changes:
			log('    ' + c)
	else:
		log('  Lua files already up to date')
	if failures:
		log('%d upload(s) failed; fix the cause and re-run (finished ones are kept in %s).' % (failures, MANIFEST))
		return 1
	if uploaded:
		log('done: %d uploaded. Moderation can take a few minutes: until an image is approved Roblox shows it blank.' % uploaded)
	elif not a.dry_run:
		log('done: nothing new to upload.')
	return 0


if __name__ == '__main__':
	try:
		sys.exit(main())
	except UploadError as e:
		log('error:', e)
		sys.exit(1)
	except KeyboardInterrupt:
		log('interrupted; finished uploads are saved in', MANIFEST)
		sys.exit(130)
