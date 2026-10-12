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
  (brief 29, the Boss Yard warehouse and World 1's final boss)
  Forklift                   a chunky yellow forklift, 4.6 wide, 7 tall, 10 long, forks toward -z, on the origin; set
                             dressing, and the one the Harbor Boss shoves down its red lane
  CraneHook                  a crane's hook block, hanging from the origin (its cable's end) toward -y
  PalletStack                a pallet of taped cardboard boxes, 4.8 x 4 on the origin
  DropContainer              a short orange cargo container, 7.5 studs a side, centred (the container drop)
  HangingLamp                an industrial pendant lamp hanging from the origin, a glowing bulb under a dark shade
  (brief 30, FIGHTS: the strong enemies' arenas, set dressing in layers like the reference's (bible 2.4), one theme a crew;
  every set prop stands on the origin (its floor at y = 0), its front toward -z)
  SchoolBus                  Big Bully Brock's schoolyard: a yellow school bus, 8 x 9.6 x 25 studs, stop arm out
  DodgeballCart              a wire cart of red dodgeballs on casters
  Lockers                    a row of four blue school lockers, 6 x 6 x 1.6
  GetawayVan                 The Ringleader's van, back doors flung open, money bags inside; 7 x 8 x 18
  Safe                       a steel safe, its door ajar
  CementMixer                The Foreman's site: an orange drum mixer on a two-wheel frame
  Scaffold                   a two-deck scaffold tower, 6 x 12 x 4, planks and braces
  RoadBarrier                a striped A-frame barrier
  TrafficCone                an orange cone with a white band
  SpeakerStack               Big Shot's stage: two-by-two speaker cabinets and a tweeter top, purple trim
  FireBarrel                 a rusty drum with chunky flames (the reference's burning barrels)
  Lowrider                   Furcoat Frankie's purple lowrider, chrome trim, gold rims; 7 x 4.6 x 18
  CardTable                  a green card table, two folding chairs, cards and chips
  BallRack                   Court King's ball rack: two tiers of basketballs
  Bollard                    a mooring bollard (black iron, yellow cap) and RopeCoil, a coiled mooring rope
  TireStack                  three tyres stacked
  WaterTower                 a rooftop water tank on legs, cone roof (the back layer over the roofs)
  Billboard                  a rooftop billboard on two posts with lamps; its blank Face takes the crew's sign
  DockCrane                  the World Boss pier's dockside crane: legs on rails, cab, boom over the water, 20 x 34 x 44
  DockLamp                   a pier lamp post, 12 studs, its lamp toward -z
  Tugboat                    a tugboat moored off the pier, 12 x 13 x 30, tyre fenders
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


def forklift():
	m = Model('Forklift', 'Forklift', 0.5, kind='prop')
	tyre, hub = 'ink', 'steel'
	for x in (-3.9, 3.9):
		for z, d in ((-4.4, 3.8), (5.0, 3.2)):
			m.cyl((x, d / 2, z), 1.6, d, tyre, 'smooth', axis='x', name='Wheel')
			m.cyl((x * 1.03, d / 2, z), 1.7, d * 0.45, hub, 'smooth', axis='x', name='Hub')
	m.box((0, 3.6, 0.9), (7.2, 3.4, 10.2), 'yellow', 'plastic', name='Body')
	m.box((0, 2.15, 0.9), (7.4, 0.7, 10.4), 'gun', 'smooth', name='Skirt')
	m.box((0, 4.25, 6.8), (7.8, 4.6, 2.6), 'gun', 'smooth', name='Counterweight')
	for k in range(3):
		m.box((-2.6 + k * 2.6, 4.2, 8.15), (1.0, 4.4, 0.2), 'yellow', 'smooth', name='Hazard')
	m.box((3.0, 5.6, 8.2), (0.9, 0.7, 0.2), 'red', 'neon', name='TailLight')
	m.box((-3.0, 5.6, 8.2), (0.9, 0.7, 0.2), 'red', 'neon', name='TailLight')
	m.box((0, 6.0, 3.0), (3.4, 1.0, 2.8), 'ink', 'smooth', name='Seat')
	m.box((0, 7.6, 4.2), (3.2, 2.6, 0.8), 'ink', 'smooth', name='SeatBack')
	m.box((0, 6.6, -1.6), (0.6, 2.4, 0.6), 'gun', 'smooth', rot=euler(-25, 0, 0), name='Column')
	m.cyl((0, 7.9, -1.0), 0.4, 2.2, 'ink', 'smooth', axis='y', rot=euler(-25, 0, 0), name='SteeringWheel')
	for x in (-3.3, 3.3):
		for z in (-2.2, 5.0):
			m.box((x, 9.3, z), (0.5, 8.0, 0.5), 'gun', 'smooth', name='GuardPost')
	m.box((0, 13.45, 1.4), (7.2, 0.5, 7.8), 'gun', 'smooth', name='GuardRoof')
	for z in (-0.6, 1.4, 3.4):
		m.box((0, 13.8, z), (7.0, 0.3, 0.5), 'gunlight', 'smooth', name='GuardSlat')
	m.cyl((2.6, 14.3, 4.4), 1.0, 1.2, 'orange', 'neon', axis='y', name='Beacon')
	for x in (-2.5, 2.5):
		m.box((x, 7.4, -3.9), (0.9, 14.0, 0.9), 'gunlight', 'smooth', name='MastRail')
	for y in (1.2, 14.0):
		m.box((0, y, -3.9), (5.8, 0.7, 0.76), 'gunlight', 'smooth', name='MastBar')
	m.box((0, 3.4, -4.7), (6.2, 3.0, 0.6), 'gun', 'smooth', name='Carriage')
	for x in (-1.9, 1.9):
		m.box((x, 2.85, -5.2), (1.16, 4.0, 0.5), 'gun', 'smooth', name='ForkUpright')
		m.box((x, 0.55, -8.6), (1.2, 0.5, 7.4), 'gun', 'smooth', name='Fork')
	return m


def crane_hook():
	m = Model('CraneHook', 'Crane Hook', 0.25, kind='prop')
	m.box((0, -3.4, 0), (6.4, 6.0, 3.0), 'yellow', 'plastic', name='Block')
	for sx in (-1, 1):
		m.box((sx * 3.45, -3.4, 0), (0.6, 6.4, 3.4), 'gun', 'smooth', name='SidePlate')
		m.cyl((sx * 3.85, -2.6, 0), 0.4, 1.4, 'chrome', 'smooth', axis='x', name='Bolt')
	m.box((0, -5.4, 0), (6.5, 1.0, 3.1), 'ink', 'smooth', name='Band')
	m.cyl((0, -0.2, 0), 0.8, 2.4, 'gun', 'smooth', axis='y', name='Swivel')
	m.cyl((0, -7.6, 0), 2.6, 1.5, 'chrome', 'smooth', axis='y', name='Shank')
	m.box((-1.5, -10.6, 0), (1.5, 3.8, 1.5), 'steel', 'smooth', name='Hook')
	m.box((0.1, -12.6, 0), (4.6, 1.5, 1.46), 'steel', 'smooth', name='Hook')
	m.box((1.75, -11.4, 0), (1.5, 2.6, 1.5), 'steel', 'smooth', rot=euler(0, 0, -12), name='Hook')
	m.box((0.6, -9.3, 0), (2.6, 0.4, 0.7), 'red', 'smooth', rot=euler(0, 0, -28), name='Latch')
	return m


def pallet_stack():
	m = Model('PalletStack', 'Pallet Stack', 0.25, kind='prop')
	W, D = 19.2, 16.0
	for z in (-D / 2 + 1.2, 0, D / 2 - 1.2):
		m.box((0, 0.3, z), (W, 0.6, 2.4), 'wooddark', 'plastic', name='Runner')
		for x in (-W / 2 + 1.4, 0, W / 2 - 1.4):
			m.box((x, 1.2, z), (2.4, 1.2, 2.4), 'wood', 'plastic', name='Block')
	for k in range(5):
		m.box((-W / 2 + 1.6 + k * (W - 3.2) / 4, 2.1, 0), (2.8, 0.6, D), 'woodlight', 'plastic', name='Deck')
	card, tape = (200, 154, 98), (232, 206, 150)
	boxes = (((-4.6, -3.8), 9.0, 7.0, 7.4), ((4.6, -3.8), 9.0, 7.0, 7.4), ((-4.6, 3.9), 9.0, 7.0, 7.4), ((4.4, 3.9), 8.6, 6.0, 7.0), ((-2.4, -1.6), 8.4, 5.6, 6.6))
	for k, ((x, z), w, h, d) in enumerate(boxes):
		y0 = 2.4 if k < 4 else 9.4
		m.box((x, y0 + h / 2, z), (w, h, d), card if k % 2 == 0 else (186, 140, 86), 'plastic', name='Carton')
		m.box((x, y0 + h + 0.03, z), (1.4, 0.1, d + 0.06), tape, 'smooth', name='Tape')
	return m


def drop_container():
	m = Model('DropContainer', 'Cargo Container', 0.5, kind='prop')
	S = 15.0
	body, dark, rib = 'orange', (176, 86, 22), (255, 170, 80)
	m.box((0, 0, 0), (S - 0.6, S - 0.6, S - 0.6), body, 'plastic', name='Body')
	e = 1.2
	for a in (-1, 1):
		for b in (-1, 1):
			m.box((a * (S / 2 - e / 2), 0, b * (S / 2 - e / 2)), (e, S - 0.1, e), dark, 'smooth', name='Post')
			m.box((0, a * (S / 2 - e / 2), b * (S / 2 - e / 2 + 0.02)), (S - 0.1, e, e), dark, 'smooth', name='Rail')
	for sx in (-1, 1):
		for z in (-4.2, -1.4, 1.4, 4.2):
			m.box((sx * (S / 2 - 0.1), 0, z), (0.4, S - 2.6, 1.0), rib, 'smooth', name='Rib')
	for x in (-2.4, 2.4):
		m.box((x, 0, -S / 2 + 0.1), (0.5, S - 2.4, 0.5), 'gun', 'smooth', name='DoorBar')
	m.box((0, 1.0, -S / 2 + 0.05), (4.4, 2.2, 0.2), 'white', 'smooth', name='Label')
	return m


def hanging_lamp():
	m = Model('HangingLamp', 'Hanging Lamp', 0.25, kind='prop')
	m.cyl((0, -2.0, 0), 4.0, 0.5, 'ink', 'smooth', axis='y', name='Cord')
	m.cyl((0, -4.4, 0), 1.0, 2.2, 'gun', 'smooth', axis='y', name='Cap')
	m.cyl((0, -5.5, 0), 1.4, 6.4, 'gun', 'smooth', axis='y', name='Shade')
	m.cyl((0, -6.25, 0), 0.2, 6.8, 'gunlight', 'smooth', axis='y', name='Rim')
	m.ball((0, -6.5, 0), 2.8, (255, 236, 180), 'neon', name='Bulb')
	return m


PROPS = [dodgeball, basketball, money_bag, crate, barrel, court_tunnel, forklift, crane_hook, pallet_stack, drop_container, hanging_lamp]


# ------------------------------------------------------------------------------------------------ brief 30: the arenas
SET = 0.5  # set props: 1 DU = 0.5 studs
SMALL = 0.25


def wheel(m, pos, d, w, hub='steel', tyre='ink', name='Wheel'):
	m.cyl(pos, w, d, tyre, 'smooth', axis='x', name=name)
	m.cyl((pos[0] * 1.0 + (0.08 if pos[0] > 0 else -0.08), pos[1], pos[2]), w + 0.1, d * 0.5, hub, 'smooth', axis='x', name='Hub')


def school_bus():
	m = Model('SchoolBus', 'School Bus', SET, kind='prop')
	yellow, black, glass = (255, 196, 32), (28, 28, 34), (52, 70, 96)
	for x in (-7.0, 7.0):
		for z in (-15.0, 13.5):
			wheel(m, (x, 3.5, z), 7.0, 2.4)
	m.box((0, 2.6, 1.5), (15.2, 1.6, 42.0), black, 'smooth', name='Chassis')
	m.box((0, 10.6, 3.0), (16.0, 13.2, 38.0), yellow, 'plastic', name='Body')
	m.box((0, 7.0, -19.5), (15.0, 6.0, 7.0), yellow, 'plastic', name='Hood')
	m.box((0, 10.32, -16.05), (15.6, 0.6, 0.3), black, 'smooth', name='HoodSeam')
	m.box((0, 4.0, -23.3), (15.6, 1.8, 0.8), black, 'smooth', name='Bumper')
	m.box((0, 3.6, 22.3), (15.6, 1.8, 0.8), black, 'smooth', name='Bumper')
	m.box((0, 7.4, -23.05), (6.0, 2.6, 0.3), 'gunlight', 'smooth', name='Grille')
	for x in (-5.6, 5.6):
		m.box((x, 7.6, -23.1), (2.0, 1.6, 0.3), (255, 244, 200), 'neon', name='Headlight')
		m.box((x, 6.0, 22.0), (1.6, 1.6, 0.3), 'red', 'neon', name='TailLight')
	for sx in (-1, 1):
		m.box((sx * 8.05, 8.2, 3.0), (0.3, 0.7, 37.8), black, 'smooth', name='Stripe')
		m.box((sx * 8.08, 11.0, 3.0), (0.3, 0.7, 37.8), black, 'smooth', name='Stripe')
		for k in range(7):
			z = -12.6 + k * 4.9
			if sx > 0 and k == 0:
				continue
			m.box((sx * 8.1, 13.8, z), (0.3, 3.6, 4.0), glass, 'glass', name='Window')
		m.box((sx * 8.3, 13.5, -16.6), (0.6, 2.2, 0.8), black, 'smooth', name='Mirror')
	m.box((8.12, 10.0, -14.6), (0.3, 9.4, 3.4), black, 'smooth', name='Door')
	m.box((8.25, 12.6, -14.55), (0.3, 3.4, 2.6), glass, 'glass', name='DoorGlass')
	m.box((0, 13.8, -16.08), (13.4, 4.0, 0.3), glass, 'glass', name='Windshield')
	m.box((0, 13.8, 22.08), (9.0, 3.6, 0.3), glass, 'glass', name='RearWindow')
	m.box((0, 17.45, 3.0), (15.0, 0.8, 37.0), (246, 238, 214), 'plastic', name='Roof')
	for z in (-15.6, 21.6):
		m.box((0, 16.6, z), (5.0, 0.9, 0.3), 'red', 'neon', name='RoofLights')
	# the stop arm out on the driver's left (-x), folded half open
	with m.at((-8.6, 11.6, -11.0), euler(0, -55, 0)):
		m.box((0, 0, -0.9), (0.36, 0.5, 1.8), black, 'smooth', name='StopArm')
		m.prism((0, 0, -3.4), 0.3, 3.4, 'red', 'smooth', sides=8, axis='x', name='StopSign')
		m.prism((0.05, 0, -3.4), 0.32, 2.7, 'white', 'smooth', sides=8, axis='x', name='StopRim')
		m.prism((0.1, 0, -3.4), 0.34, 2.3, 'red', 'smooth', sides=8, axis='x', name='StopFace')
	return m


def dodgeball_cart():
	m = Model('DodgeballCart', 'Dodgeball Cart', SMALL, kind='prop')
	frame = 'steel'
	for x in (-5.4, 5.4):
		for z in (-3.6, 3.6):
			m.cyl((x, 1.1, z), 1.2, 2.2, 'ink', 'smooth', axis='x', name='Caster')
			m.box((x, 7.0, z), (0.6, 9.4, 0.6), frame, 'smooth', name='Post')
	m.box((0, 2.7, 0), (11.2, 0.6, 7.6), frame, 'smooth', name='Tray')
	for y, dy in ((11.5, 0.0), (7.2, 0.04)):
		for z in (-3.6, 3.6):
			m.box((0, y + dy, z), (11.2, 0.5, 0.5), frame, 'smooth', name='RailX')
		for x in (-5.4, 5.4):
			m.box((x, y + dy + 0.06, 0), (0.5, 0.5, 7.2), frame, 'smooth', name='RailZ')
	for k, (x, y, z) in enumerate(((-3.0, 5.4, -1.6), (0.0, 5.4, 1.6), (3.0, 5.4, -1.6), (-3.0, 5.4, 1.7), (3.0, 5.4, 1.7), (-1.5, 9.4, 0.0), (1.6, 9.5, -0.2))):
		m.ball((x, y, z), 4.4, 'red', 'smooth', name='Dodgeball')
		m.cyl((x, y, z), 0.9 + 0.04 * k, 4.46, 'white', 'smooth', axis='y' if k % 2 else 'x', name='BallStripe')
	m.box((0, 13.6, 4.4), (8.0, 0.6, 0.6), 'red', 'smooth', name='Handle')
	for x in (-3.6, 3.6):
		m.box((x, 12.55, 4.1), (0.5, 2.5, 0.5), frame, 'smooth', name='HandlePost')
	return m


def lockers():
	m = Model('Lockers', 'Lockers', SMALL, kind='prop')
	blue, dark = (52, 112, 214), (36, 80, 168)
	m.box((0, 0.5, 0), (24.4, 1.0, 6.6), 'gun', 'smooth', name='Base')
	m.box((0, 12.6, 0), (23.6, 23.0, 6.2), blue, 'plastic', name='Body')
	m.box((0, 24.45, 0), (24.4, 0.7, 6.8), dark, 'smooth', name='Cap')
	for k in range(4):
		x = -9.0 + k * 6.0
		m.box((x, 12.6, -3.2), (5.4, 21.6, 0.3), (60, 124, 226) if k % 2 == 0 else (66, 132, 232), 'smooth', name='Door')
		for v in range(3):
			m.box((x, 21.4 - v * 0.9, -3.42), (3.6, 0.4, 0.2), dark, 'smooth', name='Vent')
		m.box((x + 1.8, 12.0, -3.46), (0.5, 2.2, 0.3), 'chrome', 'smooth', name='Handle')
		m.box((x, 15.4, -3.43), (1.6, 1.0, 0.2), 'white', 'smooth', name='NumberPlate')
	return m


def getaway_van():
	m = Model('GetawayVan', 'Getaway Van', SET, kind='prop')
	body, trim, glass = (44, 48, 60), (64, 200, 96), (60, 78, 104)
	for x in (-6.4, 6.4):
		for z in (-10.5, 11.5):
			wheel(m, (x, 3.0, z), 6.0, 2.2)
	m.box((0, 2.4, 1.0), (12.4, 1.4, 31.4), 'ink', 'smooth', name='Chassis')
	m.box((0, 9.4, 4.0), (14.0, 12.0, 24.0), body, 'plastic', name='Body')
	m.box((0, 8.5, -11.0), (13.6, 10.0, 6.4), body, 'plastic', name='Cab')
	m.box((0, 5.2, -14.3), (13.0, 3.6, 0.6), 'gunlight', 'smooth', name='Grille')
	m.box((0, 3.6, -14.7), (13.6, 1.4, 0.6), 'ink', 'smooth', name='Bumper')
	m.box((0, 3.4, 16.4), (13.6, 1.4, 0.8), 'ink', 'smooth', name='Bumper')
	m.box((0, 11.0, -14.25), (11.6, 3.6, 0.3), glass, 'glass', name='Windshield')
	for sx in (-1, 1):
		m.box((sx * 4.8, 7.2, -14.4), (2.0, 1.4, 0.3), (255, 244, 200), 'neon', name='Headlight')
		m.box((sx * 6.83, 10.8, -11.0), (0.3, 3.2, 4.0), glass, 'glass', name='CabWindow')
		m.box((sx * 7.06, 8.0, 4.0), (0.3, 1.2, 23.6), trim, 'smooth', name='Stripe')
		m.box((sx * 7.08, 6.6, 4.0), (0.3, 0.5, 23.6), (40, 150, 70), 'smooth', name='StripeLow')
		m.box((sx * 6.0, 6.6, 16.05), (1.4, 1.4, 0.3), 'red', 'neon', name='TailLight')
	# the back: dark inside, the floor's edge, the doors flung open, money bags at the lip
	m.box((0, 9.6, 16.05), (12.4, 10.0, 0.2), (14, 14, 20), 'smooth', name='Inside')
	m.box((0, 4.15, 16.6), (12.4, 0.5, 1.4), 'gun', 'smooth', name='Floor')
	for sx, th in ((1, 100), (-1, -100)):
		with m.at((sx * 7.0, 9.4, 16.1), euler(0, th, 0)):
			m.box((-sx * 3.2, 0, 0.3), (6.2, 11.0, 0.5), body, 'plastic', name='BackDoor')
			m.box((-sx * 3.2, 2.4, 0.6), (4.4, 3.4, 0.2), glass, 'glass', name='BackGlass')
	sack, tie = (196, 158, 98), 'gold'
	for k, (x, z) in enumerate(((-3.4, 16.4), (0.4, 16.9), (3.6, 16.3))):
		m.ball((x, 6.6, z), 4.2, sack, 'smooth', name='MoneyBag')
		m.cyl((x, 8.75, z), 0.6, 1.6, tie, 'smooth', axis='y', name='BagTie')
		m.box((x, 6.6, z - 2.06), (1.4, 1.6, 0.2), 'cashdark', 'smooth', name='BagMark')
	return m


def safe():
	m = Model('Safe', 'Safe', SMALL, kind='prop')
	m.box((0, 6.4, 0), (10.0, 11.6, 9.0), 'steeldark', 'plastic', name='Body')
	for x in (-4.2, 4.2):
		for z in (-3.4, 3.4):
			m.box((x, 0.3, z), (1.4, 0.6, 1.4), 'ink', 'smooth', name='Foot')
	m.box((0, 6.4, -4.45), (8.0, 9.6, 0.2), (30, 30, 36), 'smooth', name='Inside')
	m.box((0.8, 7.6, -4.62), (5.8, 1.6, 0.3), 'gold', 'gold', name='GoldBar')
	m.box((-0.6, 5.9, -4.62), (5.8, 1.6, 0.3), 'gold', 'gold', name='GoldBar')
	with m.at((4.4, 6.4, -4.6), euler(0, 35, 0)):
		m.box((-4.2, 0, -0.5), (8.6, 10.0, 1.0), 'steel', 'plastic', name='Door')
		m.cyl((-4.2, 0.8, -1.2), 0.6, 3.0, 'chrome', 'smooth', axis='z', name='Dial')
		m.box((-4.2, -2.4, -1.15), (3.6, 0.6, 0.6), 'chrome', 'smooth', name='Handle')
	return m


def cement_mixer():
	m = Model('CementMixer', 'Cement Mixer', SMALL, kind='prop')
	orange, frame = (240, 120, 30), 'gun'
	for x in (-5.4, 5.4):
		m.cyl((x, 3.0, 2.0), 1.6, 6.0, 'ink', 'smooth', axis='x', name='Wheel')
	m.box((0, 3.0, 2.0), (10.4, 0.8, 0.8), frame, 'smooth', name='Axle')
	m.box((0, 5.0, 0.0), (6.0, 1.0, 9.0), frame, 'smooth', name='Frame')
	m.box((0, 2.6, -6.0), (0.9, 5.0, 0.9), frame, 'smooth', name='Leg')
	m.box((0, 1.0, -9.6), (0.8, 0.8, 7.4), frame, 'smooth', rot=euler(-8, 0, 0), name='TowBar')
	m.box((0, 9.0, 1.4), (1.2, 7.0, 1.2), frame, 'smooth', name='Yoke')
	with m.at((0, 12.2, 0.6), euler(-38, 0, 0)):
		m.cyl((0, 0, 0), 8.0, 10.6, orange, 'plastic', axis='y', name='Drum')
		m.cyl((0, 4.4, 0), 1.0, 7.6, orange, 'plastic', axis='y', name='Neck')
		m.cyl((0, 5.1, 0), 0.5, 6.4, (196, 92, 22), 'smooth', axis='y', name='Mouth')
		m.cyl((0, 5.18, 0), 0.4, 4.6, 'ink', 'smooth', axis='y', name='Hole')
		for y in (-2.0, 1.6):
			m.cyl((0, y, 0), 0.7, 10.9, (196, 92, 22), 'smooth', axis='y', name='DrumBand')
		m.cyl((0, -4.4, 0), 0.8, 7.0, (196, 92, 22), 'smooth', axis='y', name='DrumBase')
	m.box((5.6, 8.4, 1.0), (1.8, 2.6, 3.0), 'gunlight', 'smooth', name='Motor')
	return m


def scaffold():
	m = Model('Scaffold', 'Scaffold', SET, kind='prop')
	pole, plank = (250, 196, 40), 'woodlight'
	W, D, H = 12.0, 8.0, 24.0
	for x in (-W / 2, W / 2):
		for z in (-D / 2, D / 2):
			m.box((x, H / 2 + 0.05, z), (0.7, H, 0.7), pole, 'smooth', name='Pole')
			m.box((x, 0.25, z), (1.8, 0.5, 1.8), 'gun', 'smooth', name='Foot')
	for k, y in enumerate((8.0, 16.0, 23.4)):
		for z in (-D / 2, D / 2):
			m.box((0, y, z), (W, 0.5, 0.5), pole, 'smooth', name='Ledger')
		for x in (-W / 2, W / 2):
			m.box((x, y + 0.06, 0), (0.5, 0.5, D), pole, 'smooth', name='Transom')
		if k < 2:
			for q in range(4):
				m.box((-W / 2 + 1.6 + q * 2.95, y + 0.55, 0), (2.7, 0.5, D - 0.6), plank if q % 2 else 'wood', 'plastic', name='Plank')
			m.box((0, y + 1.6, -D / 2 - 0.05), (W - 0.8, 2.2, 0.3), (250, 120, 30), 'smooth', name='ToeBoard')
	# cross braces on the back (+z) and one side
	for a, (x0, y0) in enumerate(((0.0, 4.0), (0.0, 12.0))):
		m.box((x0, y0, D / 2 + 0.45), (0.45, 13.6, 0.45), (200, 156, 30), 'smooth', rot=euler(0, 0, 56 if a == 0 else -56), name='Brace')
	m.box((-W / 2 - 0.45, 12.0, 0), (0.45, 0.45, 13.8), (200, 156, 30), 'smooth', rot=euler(52, 0, 0), name='Brace')
	# a ladder up the front-right
	for x in (3.6, 5.0):
		m.box((x, 8.1, -D / 2 - 0.9), (0.4, 16.0, 0.4), 'steel', 'smooth', name='LadderRail')
	for q in range(7):
		m.box((4.3, 1.5 + q * 2.1, -D / 2 - 0.9), (1.4, 0.3, 0.3), 'steel', 'smooth', name='Rung')
	m.box((0, 12.0, D / 2 + 0.2), (W - 1.0, 7.0, 0.15), (60, 170, 90), 'smooth', name='Net')
	return m


def road_barrier():
	m = Model('RoadBarrier', 'Road Barrier', SMALL, kind='prop')
	for x in (-7.0, 7.0):
		for s in (-1, 1):
			m.box((x + 0.06 * s, 4.0, s * 1.4), (0.8, 8.6, 0.8), 'white', 'smooth', rot=euler(s * 14, 0, 0), name='Leg')
		m.box((x, 0.3, 0), (1.6, 0.6, 5.6), 'gun', 'smooth', name='Foot')
	for k in range(6):
		m.box((-6.75 + k * 2.7, 6.8, -0.75), (2.7, 2.2, 0.5), (250, 120, 30) if k % 2 == 0 else 'white', 'smooth', name='Board')
	m.box((0, 8.25, 0), (15.6, 0.6, 2.0), 'gun', 'smooth', name='TopBar')
	m.box((-6.2, 9.0, 0), (1.2, 0.9, 1.2), 'orange', 'neon', name='Lamp')
	return m


def traffic_cone():
	m = Model('TrafficCone', 'Traffic Cone', SMALL, kind='prop')
	m.box((0, 0.3, 0), (6.4, 0.6, 6.4), (232, 100, 24), 'smooth', name='Base')
	for k, (h, d) in enumerate(((2.4, 4.6), (2.2, 3.8), (2.2, 3.0), (2.0, 2.2), (1.2, 1.4))):
		y = 0.6 + sum(q[0] for q in ((2.4, 4.6), (2.2, 3.8), (2.2, 3.0), (2.0, 2.2), (1.2, 1.4))[:k]) + h / 2
		m.cyl((0, y, 0), h, d, 'white' if k == 2 else (255, 120, 30), 'smooth', axis='y', name='Cone')
	return m


def speaker_stack():
	m = Model('SpeakerStack', 'Speaker Stack', SET, kind='prop')
	cab, trim = (26, 26, 32), (160, 86, 230)
	for col, x in enumerate((-3.6, 3.6)):
		for row, y in enumerate((3.6, 10.8)):
			m.box((x, y, 0), (7.0, 7.0, 5.6), cab, 'plastic', name='Cabinet')
			m.cyl((x, y - 0.4, -2.85), 0.3, 5.4, 'gunlight', 'smooth', axis='z', name='WooferRim')
			m.cyl((x, y - 0.4, -2.95), 0.3, 4.4, 'gun', 'smooth', axis='z', name='Woofer')
			m.cyl((x, y - 0.4, -3.05), 0.3, 1.4, 'chrome', 'smooth', axis='z', name='DustCap')
			m.box((x, y + 2.9, -2.86), (6.2, 0.4, 0.2), trim, 'neon', name='Trim')
	m.box((0, 0.05, 0), (14.8, 0.1, 6.2), 'gun', 'smooth', name='Riser')
	m.box((0, 16.0, 0.2), (9.0, 3.4, 4.8), cab, 'plastic', name='Tweeters')
	for x in (-2.4, 2.4):
		m.cyl((x, 16.0, -2.25), 0.3, 2.4, 'chrome', 'smooth', axis='z', name='Horn')
	m.box((0, 17.86, 0.2), (9.2, 0.3, 5.0), trim, 'neon', name='TopTrim')
	return m


def fire_barrel():
	m = Model('FireBarrel', 'Burning Barrel', SMALL, kind='prop')
	h, d = 12.0, 9.0
	m.cyl((0, h / 2, 0), h, d, (150, 74, 38), 'plastic', axis='y', name='Drum')
	for y in (1.0, 4.4, 7.8, 11.4):
		m.cyl((0, y, 0), 0.6, d + 0.4, (110, 50, 28), 'smooth', axis='y', name='Hoop')
	m.cyl((0, h + 0.1, 0), 0.4, d - 1.2, (30, 22, 18), 'smooth', axis='y', name='Ash')
	for k, (x, z, hh, w, c) in enumerate(((0.0, 0.0, 6.0, 3.0, (255, 150, 30)), (-1.8, 1.2, 4.2, 2.4, (255, 96, 24)), (1.8, -0.8, 4.6, 2.4, (255, 96, 24)), (0.6, 1.8, 3.0, 2.0, (255, 214, 64)), (-0.8, -1.6, 3.4, 2.0, (255, 214, 64)))):
		m.box((x, h + hh / 2, z), (w, hh, w), c, 'neon', rot=euler(0, 25 * k, 8 * (k % 3 - 1)), name='Flame')
	return m


def lowrider():
	m = Model('Lowrider', 'Lowrider', SET, kind='prop')
	paint, light, glass = (126, 52, 186), (178, 112, 236), (60, 78, 104)
	for x in (-6.4, 6.4):
		for z in (-11.0, 11.6):
			wheel(m, (x, 2.6, z), 5.2, 1.8, hub='gold')
	m.box((0, 4.4, 0.5), (14.0, 3.6, 36.0), paint, 'plastic', name='Body')
	m.box((0, 2.5, 0.5), (13.6, 0.6, 35.6), 'chrome', 'smooth', name='Skirt')
	m.box((0, 6.6, -11.9), (13.4, 0.9, 11.0), light, 'plastic', name='Hood')
	m.box((0, 6.6, 13.4), (13.4, 0.9, 9.0), light, 'plastic', name='Trunk')
	m.box((0, 8.6, 1.4), (12.0, 4.2, 12.0), paint, 'plastic', name='Cabin')
	m.box((0, 10.95, 1.4), (11.0, 0.5, 11.0), light, 'plastic', name='Roof')
	m.box((0, 8.8, -4.65), (10.8, 3.0, 0.2), glass, 'glass', name='Windshield')
	m.box((0, 8.8, 7.45), (10.8, 2.8, 0.2), glass, 'glass', name='RearGlass')
	for sx in (-1, 1):
		m.box((sx * 6.05, 8.8, 1.4), (0.2, 2.8, 10.0), glass, 'glass', name='SideGlass')
		m.box((sx * 7.06, 5.2, 0.5), (0.2, 0.5, 34.0), 'chrome', 'smooth', name='Trim')
		m.box((sx * 5.0, 5.0, -17.62), (2.2, 1.4, 0.2), (255, 244, 200), 'neon', name='Headlight')
		m.box((sx * 5.2, 5.0, 18.62), (2.0, 1.2, 0.2), 'red', 'neon', name='TailLight')
	m.box((0, 3.6, -17.9), (14.2, 1.2, 0.8), 'chrome', 'smooth', name='Bumper')
	m.box((0, 3.6, 18.9), (14.2, 1.2, 0.8), 'chrome', 'smooth', name='Bumper')
	m.box((0, 5.0, -17.75), (6.0, 1.6, 0.3), 'chrome', 'smooth', name='Grille')
	return m


def card_table():
	m = Model('CardTable', 'Card Table', SMALL, kind='prop')
	felt, edge = (40, 140, 80), 'wooddark'
	m.box((0, 7.6, 0), (10.0, 0.6, 10.0), felt, 'plastic', name='Top')
	m.box((0, 7.25, 0), (10.6, 0.4, 10.6), edge, 'smooth', name='Edge')
	for x in (-4.4, 4.4):
		for z in (-4.4, 4.4):
			m.box((x, 3.6, z), (0.6, 7.2, 0.6), 'gun', 'smooth', name='Leg')
	for k, (x, z) in enumerate(((-2.0, -1.4), (1.4, 1.8), (2.6, -2.2), (-1.6, 2.4))):
		m.box((x, 8.0, z), (1.6, 0.14, 2.2), 'white', 'smooth', rot=euler(0, 20 * k - 15, 0), name='Card')
	for k, (x, z) in enumerate(((0.4, -0.4), (-3.0, 0.4), (3.2, 1.0))):
		m.cyl((x, 8.3 + 0.2 * k, z), 0.9 + 0.4 * k, 1.2, 'gold' if k != 1 else 'red', 'smooth', axis='y', name='Chips')
	for sx in (-1, 1):
		with m.at((sx * 8.4, 0, 0.4), euler(0, sx * 90, 0)):
			m.box((0, 4.6, 0), (4.6, 0.5, 4.4), 'steel', 'smooth', name='ChairSeat')
			m.box((0, 7.8, 2.1), (4.6, 4.6, 0.5), 'steel', 'smooth', rot=euler(-6, 0, 0), name='ChairBack')
			for x in (-2.0, 2.0):
				m.box((x, 2.2, 0), (0.4, 4.6, 0.4), 'gun', 'smooth', rot=euler(12, 0, 0), name='ChairLeg')
	return m


def ball_rack():
	m = Model('BallRack', 'Ball Rack', SMALL, kind='prop')
	frame = 'steel'
	for x in (-7.2, 7.2):
		m.box((x, 7.1, 0), (0.7, 14.0, 4.6), frame, 'smooth', name='Side')
		m.box((x, 0.3, 0), (1.4, 0.6, 6.0), 'gun', 'smooth', name='Foot')
	for y in (3.0, 9.6):
		m.box((0, y, -1.3), (14.0, 0.5, 0.5), frame, 'smooth', name='Rail')
		m.box((0, y + 0.04, 1.3), (14.0, 0.5, 0.5), frame, 'smooth', name='Rail')
		for k in range(4):
			x = -5.2 + k * 3.45
			m.ball((x, y + 2.0, 0), 3.4, 'orange', 'smooth', name='Ball')
			m.cyl((x, y + 2.0, 0), 0.18, 3.46, 'ink', 'smooth', axis='x', name='Seam')
	m.box((0, 14.2, 0), (15.0, 0.6, 4.8), 'red', 'smooth', name='TopBar')
	return m


def bollard():
	m = Model('Bollard', 'Mooring Bollard', SMALL, kind='prop')
	m.box((0, 0.3, 0), (6.4, 0.6, 6.4), 'gun', 'smooth', name='Plate')
	m.cyl((0, 3.0, 0), 4.8, 4.0, (30, 32, 38), 'plastic', axis='y', name='Post')
	m.cyl((0, 5.8, 0), 1.0, 5.6, (30, 32, 38), 'plastic', axis='y', name='Head')
	m.cyl((0, 6.45, 0), 0.3, 5.0, 'yellow', 'smooth', axis='y', name='Cap')
	for x in (-2.6, 2.6):
		for z in (-2.6, 2.6):
			m.cyl((x, 0.7, z), 0.3, 0.8, 'steel', 'smooth', axis='y', name='Bolt')
	return m


def rope_coil():
	m = Model('RopeCoil', 'Rope Coil', SMALL, kind='prop')
	rope, dark = (206, 170, 110), (168, 132, 78)
	for k, d in enumerate((7.6, 7.0, 7.4, 6.6)):
		m.cyl((0.2 * (k % 2), 0.5 + k * 0.9, 0.15 * k), 0.9, d, rope if k % 2 == 0 else dark, 'smooth', axis='y', name='Coil')
	m.cyl((0.2, 4.1, 0.4), 0.3, 3.2, (60, 50, 40), 'smooth', axis='y', name='Hole')
	m.box((4.2, 0.45, 1.2), (3.6, 0.9, 0.9), rope, 'smooth', rot=euler(0, -25, 0), name='RopeEnd')
	return m


def tire_stack():
	m = Model('TireStack', 'Tire Stack', SMALL, kind='prop')
	for k in range(3):
		x, z = (0.3 * (k % 2), -0.25 * k)
		m.cyl((x, 1.3 + k * 2.65, z), 2.6, 8.0, (26, 26, 30), 'plastic', axis='y', name='Tire')
		m.cyl((x, 1.3 + k * 2.65, z), 2.64, 4.2, (60, 62, 70), 'smooth', axis='y', name='Rim')
	return m


def water_tower():
	m = Model('WaterTower', 'Water Tower', SET, kind='prop')
	wood, band, leg = (150, 98, 58), (60, 62, 70), 'gun'
	for x in (-4.6, 4.6):
		for z in (-4.6, 4.6):
			m.box((x, 5.0, z), (0.9, 10.0, 0.9), leg, 'smooth', name='Leg')
	for a, (y, r) in enumerate(((3.0, 0), (7.0, 0))):
		m.box((0, y, -4.6), (9.2, 0.5, 0.5), leg, 'smooth', name='Brace')
		m.box((0, y + 0.05, 4.6), (9.2, 0.5, 0.5), leg, 'smooth', name='Brace')
		m.box((-4.6, y + 0.1, 0), (0.5, 0.5, 9.2), leg, 'smooth', name='Brace')
		m.box((4.6, y + 0.15, 0), (0.5, 0.5, 9.2), leg, 'smooth', name='Brace')
	m.box((0, 10.3, 0), (12.0, 0.6, 12.0), 'gunlight', 'smooth', name='Deck')
	m.prism((0, 16.6, 0), 12.0, 11.0, wood, 'plastic', sides=8, axis='y', name='Tank')
	for y in (12.0, 15.6, 19.2, 22.2):
		m.prism((0, y, 0), 0.6, 11.4, band, 'smooth', sides=8, axis='y', name='Hoop')
	for k, (h, d) in enumerate(((1.2, 11.6), (1.2, 8.8), (1.2, 6.0), (1.0, 3.4))):
		m.prism((0, 23.2 + k * 1.2, 0), h, d, (96, 74, 54), 'plastic', sides=8, axis='y', name='Roof')
	m.ball((0, 28.1, 0), 1.2, band, 'smooth', name='Finial')
	for q in range(6):
		m.box((5.9, 1.0 + q * 1.8, -1.0), (0.3, 0.3, 1.6), 'steel', 'smooth', name='Rung')
	m.box((5.9, 5.6, -1.85), (0.35, 11.2, 0.35), 'steel', 'smooth', name='LadderRail')
	m.box((5.9, 5.6, -0.15), (0.35, 11.2, 0.35), 'steel', 'smooth', name='LadderRail')
	return m


def billboard():
	m = Model('Billboard', 'Billboard', SET, kind='prop')
	frame = 'gun'
	for x in (-8.0, 8.0):
		m.box((x, 7.0, 1.6), (1.0, 14.0, 1.0), frame, 'smooth', name='Post')
	m.box((0, 12.2, 1.6), (17.4, 0.6, 0.6), frame, 'smooth', name='Strut')
	m.box((0, 19.0, 0.6), (24.0, 12.0, 0.8), 'white', 'smooth', name='Face')
	m.box((0, 19.0, 1.2), (24.8, 12.8, 0.4), (40, 44, 56), 'smooth', name='Frame')
	m.box((0, 12.6, -1.0), (24.0, 0.4, 2.6), 'steel', 'smooth', name='Catwalk')
	for x in (-7.0, 0.0, 7.0):
		m.box((x, 25.6, -0.8), (0.4, 0.4, 2.4), frame, 'smooth', name='LampArm')
		m.box((x, 25.4, -2.0), (1.6, 0.6, 0.8), (255, 240, 190), 'neon', name='Lamp')
	return m


def dock_crane():
	m = Model('DockCrane', 'Dock Crane', 1.0, kind='prop')
	red, white, dark = (214, 56, 40), (240, 240, 236), (52, 56, 66)
	# two legs a side on rails (x = +-9, along z), portal beams, the tower, cab and boom toward -z (over the water)
	for x in (-9.0, 9.0):
		m.box((x, 0.35, 0), (1.6, 0.7, 20.0), dark, 'smooth', name='Bogie')
		for z in (-7.0, 7.0):
			m.box((x, 10.0, z), (1.5, 19.4, 1.5), red, 'plastic', name='Leg')
			m.cyl((x, 0.9, z - 1.6), 1.0, 1.6, 'ink', 'smooth', axis='x', name='Wheel')
			m.cyl((x, 0.9, z + 1.6), 1.0, 1.6, 'ink', 'smooth', axis='x', name='Wheel')
		m.box((x, 19.6, 0), (2.0, 1.6, 17.6), red, 'plastic', name='Sill')
		m.box((x, 10.0, 0), (0.8, 0.8, 18.6), white, 'smooth', rot=euler(43, 0, 0), name='Brace')
	for z in (-7.0, 7.0):
		m.box((0, 20.8, z), (19.6, 1.6, 2.0), red, 'plastic', name='Portal')
	m.box((0, 22.4, 0), (16.0, 1.6, 16.0), dark, 'smooth', name='Deck')
	m.box((0, 25.6, 2.0), (10.0, 5.0, 8.0), red, 'plastic', name='Machinery')
	for z in (-1.0, 3.0):
		m.box((5.06, 26.2, z), (0.2, 1.4, 2.4), white, 'smooth', name='Vent')
	m.box((-3.8, 24.6, -4.6), (4.4, 3.6, 4.0), white, 'plastic', name='Cab')
	m.box((-3.8, 25.0, -6.65), (3.6, 2.0, 0.2), (60, 90, 120), 'glass', name='CabGlass')
	# the A-frame and the boom
	for x in (-3.0, 3.0):
		m.box((x, 31.0, 3.6), (0.9, 12.0, 0.9), red, 'plastic', rot=euler(-12, 0, 0), name='AFrame')
	m.box((0, 36.8, 4.8), (7.0, 0.9, 0.9), red, 'plastic', name='AFrameTop')
	m.box((0, 28.8, -18.0), (3.2, 2.0, 40.0), red, 'plastic', name='Boom')
	for z in range(-34, 0, 6):
		m.box((0, 28.8, z), (3.3, 0.5, 0.5), white, 'smooth', name='BoomRib')
	m.box((0, 32.8, -14.0), (0.4, 0.4, 41.0), dark, 'smooth', rot=euler(10, 0, 0), name='Stay')
	m.box((0, 27.4, -26.0), (2.6, 0.9, 3.4), dark, 'smooth', name='Trolley')
	m.box((0, 22.4, -26.0), (0.25, 9.4, 0.25), 'ink', 'smooth', name='Cable')
	m.box((0, 17.0, -26.0), (2.0, 1.6, 1.2), 'yellow', 'plastic', name='Hook')
	m.box((0, 15.6, -26.0), (0.6, 1.4, 0.6), 'steel', 'smooth', name='HookTip')
	m.box((0, 30.6, 9.4), (5.0, 3.6, 4.0), dark, 'smooth', name='Counterweight')
	m.box((0, 29.0, 6.0), (2.4, 1.4, 6.0), red, 'plastic', name='Tail')
	m.box((0, 37.6, 4.8), (1.2, 1.0, 1.2), 'red', 'neon', name='Beacon')
	return m


def dock_lamp():
	m = Model('DockLamp', 'Dock Lamp', SMALL, kind='prop')
	m.box((0, 0.4, 0), (4.0, 0.8, 4.0), 'gun', 'smooth', name='Base')
	m.cyl((0, 1.6, 0), 1.6, 2.6, 'gun', 'smooth', axis='y', name='Collar')
	m.cyl((0, 24.0, 0), 44.0, 1.2, (40, 70, 110), 'smooth', axis='y', name='Pole')
	m.box((0, 45.55, -2.4), (0.8, 0.8, 5.6), (40, 70, 110), 'smooth', name='Arm')
	m.box((0, 45.0, -5.2), (3.0, 1.6, 4.0), (40, 70, 110), 'smooth', name='Head')
	m.box((0, 44.0, -5.2), (2.4, 0.4, 3.2), (255, 236, 180), 'neon', name='Bulb')
	m.box((0, 30.0, -0.7), (0.3, 6.0, 0.3), 'yellow', 'smooth', name='Band')
	return m


def tugboat():
	m = Model('Tugboat', 'Tugboat', 1.0, kind='prop')
	red, black, white, dark = (196, 44, 40), (30, 30, 36), (240, 240, 236), (60, 64, 74)
	m.box((0, 1.0, 0), (11.0, 3.0, 26.0), red, 'plastic', name='HullLow')
	m.box((0, 3.2, 0), (12.0, 1.6, 27.0), black, 'plastic', name='Hull')
	m.wedge((0, 3.2, -15.75), (12.0, 1.6, 4.5), black, 'plastic', rot=euler(0, 180, 0), name='Bow')
	m.wedge((0, 1.0, -14.5), (11.0, 3.0, 3.0), red, 'plastic', rot=euler(0, 180, 0), name='BowLow')
	m.box((0, 4.15, 0.5), (11.4, 0.3, 26.4), (150, 140, 120), 'plastic', name='Deck')
	m.box((0, 6.4, 3.0), (8.0, 4.2, 10.0), white, 'plastic', name='Cabin')
	m.box((0, 10.0, 0.5), (6.6, 3.0, 5.6), white, 'plastic', name='Wheelhouse')
	m.box((0, 11.7, 0.5), (7.4, 0.4, 6.4), red, 'smooth', name='WheelhouseRoof')
	m.box((0, 10.2, -2.32), (5.8, 1.4, 0.2), (60, 90, 120), 'glass', name='WheelhouseGlass')
	for sx in (-1, 1):
		m.box((sx * 4.06, 6.8, 3.0), (0.2, 1.4, 7.0), (60, 90, 120), 'glass', name='Portholes')
	m.cyl((0, 11.6, 6.6), 4.6, 2.2, 'yellow', 'plastic', axis='y', name='Funnel')
	m.cyl((0, 13.0, 6.6), 0.8, 2.3, black, 'smooth', axis='y', name='FunnelTop')
	m.cyl((0, 11.4, 6.6), 0.7, 2.3, red, 'smooth', axis='y', name='FunnelBand')
	m.box((0, 14.4, 0.0), (0.3, 4.6, 0.3), dark, 'smooth', name='Mast')
	m.box((0, 16.6, 0.0), (0.5, 0.5, 0.5), 'red', 'neon', name='MastLight')
	for sx in (-1, 1):
		for z in (-8.0, -3.0, 2.0, 7.0):
			m.cyl((sx * 6.25, 2.8, z), 0.9, 2.4, (26, 26, 30), 'plastic', axis='x', name='TyreFender')
	m.box((0, 4.7, 11.0), (8.0, 0.8, 2.0), dark, 'smooth', name='Winch')
	m.box((0, 4.9, -10.0), (2.0, 1.2, 2.0), dark, 'smooth', name='Bitt')
	return m


PROPS += [school_bus, dodgeball_cart, lockers, getaway_van, safe, cement_mixer, scaffold, road_barrier, traffic_cone,
	speaker_stack, fire_barrel, lowrider, card_table, ball_rack, bollard, rope_coil, tire_stack, water_tower, billboard,
	dock_crane, dock_lamp, tugboat]


def build_all():
	out = []
	for fn in PROPS:
		m = fn()
		m.meta.pop('muzzle', None)
		out.append(m)
	return out
