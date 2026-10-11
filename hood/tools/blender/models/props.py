"""Brief 29 props: what the crew bosses throw and roll, and the basketball court's players' tunnel.

Same kit and look as the guns and icons (chunky toy proportions, one main colour per model). Axes are Roblox axes:
x right, y up, front toward -z. The thrown props are centred on the origin (they spin about it in flight); the
tunnel stands on the origin (its floor at y = 0), its mouth toward -z.
  Dodgeball, Basketball      2 studs across
  MoneyBag                   a tied sack with a big "$" on its front
  Crate                      a 2.6-stud wooden crate with a cross brace
  Barrel                     a blue oil drum with hoops
  CourtTunnel                the court's players' tunnel: 7.2 wide, 8.6 tall, 7.6 deep; a dark mouth, padded walls in
                             team blue with orange ribs, a roof sign band
"""
import math

from boxkit import Model, euler

UNIT = 0.25  # thrown props: 1 DU = 0.25 studs


def ball_with_seams(m, d, color, seam, rings=2):
	m.ball((0, 0, 0), d, color, 'smooth', name='Ball')
	# seams: thin discs a hair wider than the ball, so only their rims show as lines round it
	m.cyl((0, 0, 0), 0.22, d + 0.08, seam, 'smooth', axis='x', name='Seam')
	if rings > 1:
		m.cyl((0, 0, 0), 0.22, d + 0.1, seam, 'smooth', axis='z', name='Seam')
	if rings > 2:
		m.cyl((0, 0, 0), 0.22, d + 0.06, seam, 'smooth', axis='y', name='Seam')


def dodgeball():
	m = Model('Dodgeball', 'Dodgeball', UNIT, kind='prop')
	m.ball((0, 0, 0), 8, 'red', 'smooth', name='Ball')
	m.cyl((0, 0, 0), 1.6, 8.06, 'white', 'smooth', axis='x', name='Stripe')
	return m


def basketball():
	m = Model('Basketball', 'Basketball', UNIT, kind='prop')
	ball_with_seams(m, 8, 'orange', 'ink', rings=3)
	return m


def money_bag():
	m = Model('MoneyBag', 'Money Bag', UNIT, kind='prop')
	sack, dark = (156, 122, 76), (118, 88, 52)
	# the round belly, the body above it, the gathered neck, the tie and the tuft
	m.ball((0, -1.2, 0), 7.6, sack, 'smooth', name='Belly')
	m.box((0, 0.6, 0), (6.2, 3.2, 5.4), sack, 'smooth', name='Body')
	m.box((0, 2.6, 0), (4.2, 1.4, 3.8), sack, 'smooth', name='Shoulder')
	m.cyl((0, 3.7, 0), 1.0, 2.2, dark, 'smooth', axis='y', name='Neck')
	m.cyl((0, 4.15, 0), 0.6, 2.7, 'gold', 'smooth', axis='y', name='Tie')
	for k, (x, z) in enumerate(((-0.9, -0.5), (0.8, -0.6), (0.1, 0.8), (-0.4, 0.2))):
		m.box((x, 5.0 + 0.2 * (k % 2), z), (1.0, 1.4, 1.0), sack, 'smooth', rot=euler(8 * (k - 1.5), 20 * k, 10 * (1.5 - k)), name='Tuft')
	# a big green "$" on the front (-z): an S of three bars and two side bars, a stroke through it
	g = 'cashdark'
	zf = -2.75
	for y in (1.9, 0.5, -0.9):
		m.box((0, y, zf), (2.6, 0.55, 0.3), g, 'smooth', name='Dollar')
	m.box((0.95, 1.2, zf - 0.04), (0.6, 1.0, 0.3), g, 'smooth', name='Dollar')   # (screen-left = +x seen from the front)
	m.box((-0.95, -0.2, zf - 0.04), (0.6, 1.0, 0.3), g, 'smooth', name='Dollar')
	m.box((0, 0.5, zf - 0.02), (0.45, 4.0, 0.32), g, 'smooth', name='DollarStroke')
	return m


def crate():
	m = Model('Crate', 'Wooden Crate', UNIT, kind='prop')
	s = 10.4
	m.box((0, 0, 0), (s - 0.4, s - 0.4, s - 0.4), 'woodlight', 'plastic', name='Box')
	e = 1.2
	# the frame: edges along x, y and z, each a hair proud of the box, alternating depth so no faces share a plane
	for a in (-1, 1):
		for b in (-1, 1):
			m.box((0, a * (s / 2 - e / 2), b * (s / 2 - e / 2)), (s, e, e), 'wood', 'plastic', name='EdgeX')
			m.box((a * (s / 2 - e / 2 + 0.02), 0, b * (s / 2 - e / 2 + 0.02)), (e, s - 0.1, e), 'wood', 'plastic', name='EdgeY')
			m.box((a * (s / 2 - e / 2 + 0.04), b * (s / 2 - e / 2 + 0.04), 0), (e, e, s - 0.2), 'wood', 'plastic', name='EdgeZ')
	# a cross brace on the front and back
	for zf in (-s / 2 + 0.2, s / 2 - 0.2):
		m.box((0, 0, zf), (0.9, s * 1.12, 0.5), 'wooddark', 'plastic', rot=euler(0, 0, 45), name='Brace')
	return m


def barrel():
	m = Model('Barrel', 'Barrel', UNIT, kind='prop')
	h, d = 12.0, 9.6
	m.cyl((0, 0, 0), h, d, 'bluedark', 'smooth', axis='y', name='Drum')
	for y in (-h / 2 + 0.5, -h / 6, h / 6, h / 2 - 0.5):
		m.cyl((0, y, 0), 0.6, d + 0.4, 'blue', 'smooth', axis='y', name='Hoop')
	m.cyl((0, h / 2 + 0.05, 0), 0.2, d - 1.0, 'gun', 'smooth', axis='y', name='Lid')
	m.cyl((d / 4, h / 2 + 0.25, 0), 0.4, 1.2, 'chrome', 'metal', axis='y', name='Cap')
	m.box((0, 0, -d / 2 - 0.05), (3.0, 3.0, 0.2), 'yellow', 'smooth', name='Label')
	return m


def court_tunnel():
	m = Model('CourtTunnel', 'Players Tunnel', 0.5, kind='prop')
	W, H, D = 14.4, 15.0, 15.2   # outside: 7.2 x 7.5 x 7.6 studs
	wall = 1.6
	blue, orange, dark = 'bluedark', 'orange', (20, 22, 30)
	# floor mat, the dark inside, side walls, roof
	m.box((0, 0.17, 0), (W - 0.2, 0.3, D - 0.1), (52, 56, 70), 'smooth', name='Floor')
	m.box((0, H / 2, D / 2 - 0.5), (W - 2 * wall, H - 0.4, 1.0), dark, 'smooth', name='Back')
	m.box((0, H / 2, D / 2 - 3.4), (W - 2 * wall - 0.2, H - 0.6, 4.6), dark, 'smooth', name='Shade')
	for sx in (-1, 1):
		m.box((sx * (W / 2 - wall / 2), (H - 0.1) / 2, 0), (wall, H - 0.1, D), blue, 'smooth', name='Wall')
		# padded ribs along the outside, in orange
		for z in (-D / 2 + 1.2, -D / 6, D / 6, D / 2 - 1.2):
			m.box((sx * (W / 2 + 0.25), H / 2, z), (0.5, H - 0.6, 1.2), orange, 'smooth', name='Rib')
	m.box((0, H - 0.8, 0), (W + 0.1, 1.6, D + 0.1), blue, 'smooth', name='Roof')
	for z in (-D / 2 + 1.2, -D / 6, D / 6, D / 2 - 1.2):
		m.box((0, H + 0.25, z), (W + 1.0, 0.5, 1.2), orange, 'smooth', name='RoofRib')
	# the mouth: an orange frame, the inside edge in white
	f = 1.2
	m.box((0, H + 0.1, -D / 2 - 0.4), (W + 1.2, 2.6, 0.8), orange, 'smooth', name='Arch')
	for sx in (-1, 1):
		m.box((sx * (W / 2 + 0.1), H / 2 - 0.39, -D / 2 - 0.4), (f + 0.8, H - 0.82, 0.9), orange, 'smooth', name='Post')
		m.box((sx * (W / 2 - wall - 0.15), H / 2 - 0.6, -D / 2 - 0.02), (0.3, H - 2.6, 0.3), 'white', 'smooth', name='Trim')
	m.box((0, H - 2.15, -D / 2 - 0.02), (W - 2 * wall - 0.6, 0.3, 0.3), 'white', 'smooth', name='Trim')
	# the sign band over the mouth: a white panel with a basketball on it
	m.box((0, H + 2.6, -D / 2 + 0.6), (W - 2.0, 2.8, 0.6), 'white', 'smooth', name='Sign')
	m.ball((0, H + 2.6, -D / 2 + 0.15), 2.2, 'orange', 'smooth', name='SignBall')
	m.cyl((0, H + 2.6, -D / 2 + 0.15), 0.12, 2.3, 'ink', 'smooth', axis='x', name='SignSeam')
	m.cyl((0, H + 2.6, -D / 2 + 0.15), 0.12, 2.32, 'ink', 'smooth', axis='z', name='SignSeam')
	for sx in (-1, 1):
		m.box((sx * 3.6, H + 2.6, -D / 2 + 0.25), (3.4, 0.7, 0.2), 'bluedark', 'smooth', name='SignStripe')
	return m


PROPS = [dodgeball, basketball, money_bag, crate, barrel, court_tunnel]


def build_all():
	out = []
	for fn in PROPS:
		m = fn()
		m.meta.pop('muzzle', None)
		out.append(m)
	return out
