"""The 10 guns from hood/src/ReplicatedStorage/Shared/Config/Guns.lua, tier 1 to 10.

All guns share one grammar so they read as a set: origin at the centre of the grip (where the hand
holds), muzzle toward -z, up +y, 1 DU = 0.2 studs. The tier ladder stacks visual channels:
  1-2 plain toy plastic, a little wood       5-6 more parts, wood furniture, tier colour on big pieces
  3-4 tier colour accents, studs on top      7   gold + gems (first bling)
  8   first neon glow                        9   neon coils everywhere
  10  diamond glass + gold trim + glowing core
"""
import math

from boxkit import Model, euler, rot_x

UNIT = 0.2


def hole(m, pos, d, depth=0.12):
	"""Dark bore on a front (-z) face."""
	m.cyl(pos, depth, d, 'ink', 'smooth', axis='z', bevel=0.0, name='Bore')


def guard(m, z_front, z_back, y_bottom, color, mat='smooth', width=0.45, post=0.9, trigger='ink', trigger_z=None, trigger_mat='smooth'):
	"""Trigger guard (bottom bar + front post) and the trigger itself."""
	length = z_back - z_front
	# The post is a hair narrower and shorter than the bar so no two faces share a plane (z-fighting).
	m.box((0, y_bottom + 0.16, (z_front + z_back) / 2 + 0.02), (width, 0.32, length - 0.04), color, mat, name='Guard')
	m.box((0, y_bottom + 0.03 + (post - 0.03) / 2, z_front + 0.16), (width - 0.05, post - 0.03, 0.32), color, mat, name='GuardFront')
	tz = trigger_z if trigger_z is not None else z_front + length * 0.55
	m.box((0, y_bottom + 0.55, tz), (0.3, 0.7, 0.3), trigger, trigger_mat, rot=euler(-18), name='Trigger')


def pistol(id='Pistol', name='Rusty Pistol', slide='steel', frame='steeldark', grip='brown', rust=True, into=None):
	m = into or Model(id, name, UNIT)
	with m.at((0, 0, 0), euler(-14)):
		m.box((0, 0, 0), (1.24, 3.4, 1.8), grip, 'plastic', name='Grip')
		for sx in (-1, 1):
			m.box((sx * 0.64, 0.1, 0), (0.08, 2.4, 1.15), 'wooddark' if grip in ('brown', 'wood') else 'black', 'plastic', name='GripPanel')
		m.box((0, -1.85, 0.0), (1.45, 0.4, 1.95), 'gun', 'metal', name='MagBase')
	m.box((0, 1.8, -1.6), (1.3, 1.0, 5.6), frame, 'smooth', name='Frame')
	m.box((0, 2.8, -1.6), (1.4, 1.2, 6.4), slide, 'smooth', studs=True, skip=lambda x, z: abs(z) > 2.0, name='Slide')
	m.cyl((0, 2.75, -5.0), 0.6, 0.72, 'gun', 'metal', axis='z', name='Barrel')
	hole(m, (0, 2.75, -5.3), 0.42)
	m.box((0, 3.55, -4.35), (0.3, 0.32, 0.4), 'ink', name='FrontSight')
	for sx in (-1, 1):
		m.box((sx * 0.38, 3.55, 1.3), (0.3, 0.32, 0.35), 'ink', name='RearSight')
	for z in (0.55, 0.85, 1.15):
		for sx in (-1, 1):
			m.box((sx * 0.71, 2.8, z), (0.06, 0.8, 0.14), frame, 'smooth', bevel=0.02, name='Serration')
	m.box((0.71, 3.0, -0.9), (0.06, 0.5, 1.1), 'ink', bevel=0.02, name='Port')
	if rust:
		m.box((0.72, 2.75, -3.1), (0.07, 0.62, 1.2), 'rust', 'plastic', bevel=0.03, name='Rust')
		m.box((0.72, 2.45, -2.3), (0.1, 0.36, 0.6), 'rustdark', 'plastic', bevel=0.03, name='Rust')
		m.box((-0.72, 3.0, -2.0), (0.07, 0.5, 0.9), 'rust', 'plastic', bevel=0.03, name='Rust')
		m.box((0.67, 1.7, -3.5), (0.07, 0.42, 0.8), 'rust', 'plastic', bevel=0.03, name='Rust')
	m.box((0, 3.15, 1.85), (0.42, 0.7, 0.42), 'gun', 'metal', rot=euler(25), name='Hammer')
	guard(m, -3.1, -0.7, 0.45, frame)
	m.meta['muzzle'] = (0, 2.75, -5.36)
	return m


def revolver():
	m = Model('Revolver', 'Snub Revolver', UNIT)
	with m.at((0, 0, 0), euler(-22)):
		m.box((0, 0, 0), (1.2, 3.0, 1.55), 'wood', 'plastic', name='Grip')
		for sx in (-1, 1):
			m.box((sx * 0.62, 0.05, 0), (0.08, 2.2, 1.05), 'woodlight', 'plastic', name='GripPanel')
			m.cyl((sx * 0.68, 0.35, 0), 0.08, 0.36, 'chrome', 'metal', bevel=0.02, name='Screw')
		m.box((0, -1.62, 0.05), (1.3, 0.35, 1.7), 'gun', 'metal', name='GripCap')
	m.box((0, 2.0, -0.3), (1.3, 2.2, 1.5), 'green', 'smooth', name='Frame')
	# Big round cylinder with dark flutes and six chambers on the front face.
	m.cyl((0, 2.15, -2.1), 2.0, 2.3, 'chrome', 'metal', axis='z', name='Cylinder')
	for k in range(6):
		a = 60 * k
		ra = math.radians(a)
		m.box((1.1 * math.cos(ra), 2.15 + 1.1 * math.sin(ra), -2.1), (0.36, 0.16, 1.45), 'gunlight', 'metal', rot=euler(0, 0, a - 90), bevel=0.03, name='Flute')
		ca = math.radians(30 + 60 * k)
		m.cyl((0.66 * math.cos(ca), 2.15 + 0.66 * math.sin(ca), -3.12), 0.08, 0.4, 'ink', axis='z', bevel=0.0, name='Chamber')
	m.cyl((0, 2.15, -3.14), 0.1, 0.42, 'gunlight', 'metal', axis='z', bevel=0.02, name='Pin')
	m.box((0, 3.5, -2.3), (1.05, 0.45, 3.0), 'green', 'smooth', studs=True, name='TopStrap')
	m.box((0, 0.82, -2.1), (1.0, 0.5, 2.0), 'green', 'smooth', name='Crane')
	m.cyl((0, 2.8, -4.45), 2.7, 1.0, 'chrome', 'metal', axis='z', name='Barrel')
	m.box((0, 3.4, -4.5), (0.55, 0.34, 2.6), 'green', 'smooth', name='Rib')
	m.wedge((0, 3.78, -5.5), (0.24, 0.42, 0.55), 'ink', name='FrontSight')
	m.box((0, 2.1, -4.3), (0.66, 0.6, 2.2), 'green', 'smooth', name='Ejector')
	hole(m, (0, 2.8, -5.82), 0.52)
	m.box((0, 3.3, 0.7), (0.45, 0.9, 0.5), 'chrome', 'metal', rot=euler(32), name='Hammer')
	guard(m, -2.05, -0.6, 0.15, 'green', post=0.8, trigger='chrome', trigger_mat='metal')
	m.meta['muzzle'] = (0, 2.8, -5.88)
	return m


def uzi():
	m = Model('Uzi', 'Street Uzi', UNIT)
	with m.at((0, 0, 0), euler(-4)):
		m.box((0, 0, 0), (1.3, 3.0, 1.6), 'black', 'plastic', name='Grip')
		for sx in (-1, 1):
			m.box((sx * 0.67, 0.1, 0), (0.08, 2.1, 1.1), 'blue', 'plastic', name='GripPanel')
		m.box((0, -2.75, 0.1), (1.0, 2.6, 1.15), 'gun', 'metal', name='Mag')
		m.box((0, -4.15, 0.12), (1.3, 0.4, 1.45), 'blue', 'smooth', name='MagBase')
	m.box((0, 2.5, -1.4), (1.7, 2.0, 7.6), 'gun', 'plastic', name='Receiver')
	m.box((0, 3.62, -1.3), (1.45, 0.25, 6.4), 'black', 'plastic', studs=True, skip=lambda x, z: abs(z - (-1.9)) < 0.6, name='TopCover')
	m.box((0, 4.0, -3.2), (0.8, 0.55, 0.8), 'blue', 'smooth', name='Knob')
	m.box((0, 1.15, -3.8), (1.5, 0.9, 2.6), 'gun', 'plastic', name='Front')
	m.cyl((0, 2.35, -5.9), 1.6, 0.85, 'gun', 'metal', axis='z', name='Barrel')
	m.prism((0, 2.35, -5.45), 0.5, 1.25, 'gunlight', 'metal', sides=6, axis='z', name='BarrelNut')
	hole(m, (0, 2.35, -6.72), 0.48)
	for sx in (-1, 1):
		m.box((sx * 0.45, 3.95, -4.85), (0.25, 0.65, 0.35), 'blue', 'smooth', name='FrontSight')
		m.box((sx * 0.45, 3.95, 1.95), (0.25, 0.65, 0.35), 'blue', 'smooth', name='RearSight')
		m.box((sx * 0.98, 1.7, -1.45), (0.2, 0.25, 6.4), 'gunlight', 'metal', name='StockArm')
		m.box((sx * 0.86, 2.95, -1.4), (0.06, 0.35, 5.6), 'blue', 'smooth', bevel=0.02, name='Stripe')
	m.box((0, 0.95, -4.85), (2.15, 1.0, 0.3), 'gunlight', 'metal', name='ButtPlate')
	m.box((0, 1.7, 2.55), (2.0, 0.6, 0.6), 'gun', 'metal', name='StockHinge')
	m.box((0.86, 2.3, -0.2), (0.06, 0.6, 1.2), 'ink', bevel=0.02, name='Port')
	guard(m, -2.9, -0.75, 0.45, 'black', mat='plastic', post=1.1)
	m.meta['muzzle'] = (0, 2.35, -6.78)
	return m


def shotgun():
	m = Model('Shotgun', 'Pump Shotgun', UNIT)
	with m.at((0, 0, 0), euler(-18)):
		m.box((0, 0, 0), (1.2, 2.7, 1.5), 'wood', 'plastic', name='Grip')
		m.box((0, -1.45, 0.0), (1.3, 0.3, 1.62), 'purple', 'smooth', name='GripCap')
	m.box((0, 2.0, -2.0), (1.6, 2.4, 4.6), 'purple', 'smooth', studs=True, name='Receiver')
	with m.at((0, 0, 0), euler(9)):
		m.box((0, 1.55, 1.7), (1.24, 1.5, 2.8), 'wood', 'plastic', name='StockNeck')
		m.box((0, 1.15, 4.1), (1.3, 2.7, 2.6), 'wood', 'plastic', name='Stock')
		m.box((0, 1.15, 5.55), (1.36, 2.8, 0.36), 'purple', 'smooth', name='ButtPad')
		for sx in (-1, 1):
			m.box((sx * 0.66, 1.2, 4.1), (0.06, 0.42, 2.2), 'purple', 'smooth', bevel=0.02, name='Stripe')
	m.cyl((0, 2.55, -8.0), 7.4, 1.05, 'gun', 'metal', axis='z', name='Barrel')
	m.cyl((0, 1.35, -7.2), 5.8, 1.0, 'gun', 'metal', axis='z', name='MagTube')
	m.box((0, 1.35, -7.2), (1.75, 1.55, 3.4), 'wood', 'plastic', name='Pump')
	for z in (-6.2, -7.2, -8.2):
		m.box((0, 1.35, z), (1.82, 1.62, 0.22), 'wooddark', 'plastic', bevel=0.03, name='PumpRidge')
	m.box((0, 1.95, -9.7), (1.1, 2.15, 0.5), 'purple', 'smooth', name='Clamp')
	m.cyl((0, 2.55, -11.55), 0.45, 1.2, 'gunlight', 'metal', axis='z', name='MuzzleRing')
	hole(m, (0, 2.55, -11.8), 0.62)
	m.stud((0, 3.05, -11.0), 'red', 'smooth')
	m.box((0.9, 1.7, -2.3), (0.22, 1.45, 3.2), 'gun', 'metal', name='ShellHolder')
	for z in (-3.35, -2.65, -1.95, -1.25):
		m.cyl((1.25, 1.85, z), 1.3, 0.58, 'shell', 'smooth', axis='y', name='Shell')
		m.cyl((1.25, 1.05, z), 0.3, 0.6, 'brass', 'gold', axis='y', bevel=0.03, name='ShellBrass')
	m.box((0.81, 2.8, -1.6), (0.06, 0.5, 1.4), 'ink', bevel=0.02, name='Port')
	guard(m, -2.7, -0.75, 0.25, 'gun', mat='metal', post=0.75)
	m.meta['muzzle'] = (0, 2.55, -11.86)
	return m


def tommy():
	m = Model('Tommy', 'Tommy Gun', UNIT)
	with m.at((0, 0, 0), euler(-14)):
		m.box((0, 0, 0), (1.2, 2.7, 1.5), 'wood', 'plastic', name='Grip')
	m.box((0, 2.05, -2.2), (1.6, 2.1, 6.4), 'gun', 'metal', studs=True, skip=lambda x, z: z > 2.2, name='Receiver')
	m.box((0, 3.18, 0.65), (0.95, 0.5, 0.45), 'pink', 'smooth', name='RearSight')
	m.box((0.9, 2.55, -2.6), (0.35, 0.45, 0.55), 'chrome', 'metal', name='Knob')
	with m.at((0, 0, 0), euler(6)):
		m.box((0, 1.55, 2.1), (1.15, 1.4, 2.4), 'wood', 'plastic', name='StockNeck')
		m.box((0, 1.15, 4.3), (1.3, 2.5, 2.6), 'wood', 'plastic', name='Stock')
		m.box((0, 1.15, 5.72), (1.36, 2.6, 0.3), 'pink', 'smooth', name='ButtPlate')
	# Drum magazine: chunky octagon with a pink cap and winding key.
	m.prism((0, -0.15, -3.95), 1.3, 3.4, 'gun', 'metal', sides=8, axis='x', spin=22.5, name='Drum')
	m.prism((0, -0.15, -3.95), 1.55, 1.7, 'pink', 'smooth', sides=8, axis='x', spin=22.5, name='DrumCap')
	m.cyl((0, -0.15, -3.95), 1.8, 0.45, 'chrome', 'metal', axis='x', name='DrumKey')
	m.cyl((0, 2.1, -8.4), 6.0, 0.8, 'gun', 'metal', axis='z', name='Barrel')
	for z in (-5.8, -6.2, -6.6, -7.0, -7.4):
		m.cyl((0, 2.1, z), 0.2, 1.4, 'gunlight', 'metal', axis='z', bevel=0.03, name='Fin')
	m.box((0, 1.45, -8.7), (0.95, 0.6, 1.4), 'gun', 'metal', name='GripMount')
	with m.at((0, 0.2, -8.7), euler(-10)):
		m.box((0, 0, 0), (1.1, 2.3, 1.25), 'wood', 'plastic', name='FrontGrip')
		m.box((0, -1.2, 0), (1.2, 0.25, 1.35), 'pink', 'smooth', name='FrontGripCap')
	m.box((0, 2.1, -11.2), (1.15, 1.15, 1.3), 'pink', 'smooth', name='Compensator')
	m.box((0, 2.82, -11.3), (0.2, 0.35, 0.3), 'ink', name='FrontSight')
	hole(m, (0, 2.1, -11.87), 0.5)
	guard(m, -2.05, -0.7, 0.4, 'gun', mat='metal', post=0.7)
	m.meta['muzzle'] = (0, 2.1, -11.93)
	return m


def ak():
	m = Model('AK', 'Block AK', UNIT)
	with m.at((0, 0, 0), euler(-20)):
		m.box((0, 0, 0), (1.2, 2.7, 1.45), 'wooddark', 'plastic', name='Grip')
	m.box((0, 2.0, -2.0), (1.55, 2.1, 6.2), 'gun', 'metal', name='Receiver')
	m.box((0, 3.3, -1.4), (1.45, 0.5, 5.0), 'gunlight', 'metal', studs=True, name='DustCover')
	m.box((0, 3.25, -4.5), (1.1, 0.8, 0.9), 'gun', 'metal', name='RearSight')
	with m.at((0, 0, 0), euler(10)):
		m.box((0, 1.75, 2.2), (1.25, 1.55, 2.6), 'wood', 'plastic', name='StockNeck')
		m.box((0, 1.25, 4.4), (1.35, 2.8, 2.4), 'wood', 'plastic', name='Stock')
		m.box((0, 1.25, 5.72), (1.4, 2.9, 0.3), 'gun', 'metal', name='ButtPlate')
		for sx in (-1, 1):
			m.box((sx * 0.69, 1.3, 4.4), (0.06, 0.55, 1.7), 'cyan', 'smooth', bevel=0.02, name='Inlay')
	m.box((0, 1.95, -6.8), (1.65, 1.6, 3.4), 'wood', 'plastic', name='Handguard')
	for sx in (-1, 1):
		m.box((sx * 0.84, 1.95, -6.8), (0.06, 0.22, 2.6), 'wooddark', 'plastic', bevel=0.02, name='Groove')
	m.box((0, 3.2, -6.5), (1.15, 0.9, 2.8), 'wood', 'plastic', name='UpperGuard')
	m.cyl((0, 3.2, -8.75), 1.7, 0.62, 'gun', 'metal', axis='z', name='GasTube')
	m.box((0, 2.7, -9.75), (0.9, 1.6, 0.65), 'gun', 'metal', name='GasBlock')
	m.cyl((0, 2.15, -8.9), 7.6, 0.78, 'gunlight', 'metal', axis='z', name='Barrel')
	m.box((0, 2.75, -11.6), (0.85, 1.15, 0.65), 'gun', 'metal', name='SightBlock')
	for sx in (-1, 1):
		m.box((sx * 0.33, 3.6, -11.6), (0.2, 0.65, 0.38), 'gun', 'metal', name='SightEar')
	m.box((0, 3.5, -11.6), (0.18, 0.5, 0.18), 'cyan', 'smooth', bevel=0.02, name='SightPost')
	m.cyl((0, 2.15, -13.15), 1.1, 1.05, 'cyan', 'smooth', axis='z', name='MuzzleBrake')
	hole(m, (0, 2.15, -13.72), 0.5)
	# Curved magazine: three cyan segments, each tipped further toward the muzzle.
	pos, ang, h = (0, 0.4, -2.55), 10.0, 1.65
	for k in range(3):
		m.box(pos, (1.15 + 0.04 * (k % 2), h, 1.8 + 0.08 * k), 'cyan', 'smooth', rot=euler(ang), name='Mag')
		last_pos, last_ang = pos, ang
		nxt = ang + 13.0
		down0 = (0, -math.cos(math.radians(ang)), -math.sin(math.radians(ang)))
		down1 = (0, -math.cos(math.radians(nxt)), -math.sin(math.radians(nxt)))
		pos = tuple(pos[i] + (down0[i] + down1[i]) * h / 2 * 0.98 for i in range(3))
		ang = nxt
	down = (0, -math.cos(math.radians(last_ang)), -math.sin(math.radians(last_ang)))
	base = tuple(last_pos[i] + down[i] * (h / 2 + 0.1) for i in range(3))
	m.box(base, (1.28, 0.3, 2.05), 'cyandark', 'smooth', rot=euler(last_ang), name='MagBase')
	m.box((0.92, 2.5, -0.5), (0.4, 0.38, 0.55), 'chrome', 'metal', name='ChargingHandle')
	m.box((0.8, 2.25, -1.3), (0.08, 0.32, 1.7), 'gunlight', 'metal', bevel=0.02, name='Selector')
	m.box((0, 0.8, -1.1), (0.42, 0.3, 1.3), 'gun', 'metal', name='Guard')
	m.box((0, 1.0, -0.95), (0.28, 0.65, 0.28), 'ink', rot=euler(-18), name='Trigger')
	m.meta['muzzle'] = (0, 2.15, -13.78)
	return m


def deagle():
	m = Model('Deagle', 'Gold Deagle', UNIT)
	with m.at((0, 0, 0), euler(-14)):
		m.box((0, 0, 0), (1.45, 3.4, 1.95), 'black', 'plastic', name='Grip')
		for sx in (-1, 1):
			m.cyl((sx * 0.74, 0.2, 0), 0.12, 0.95, 'gold', 'gold', bevel=0.03, name='Medallion')
			m.box((sx * 0.8, 0.2, 0), (0.12, 0.42, 0.42), 'red', 'glass', rot=euler(45), bevel=0.03, name='Gem')
		m.box((0, -1.85, 0.0), (1.55, 0.36, 2.05), 'gold', 'gold', name='GripCap')
	m.box((0, 1.9, -3.0), (1.46, 1.45, 6.2), 'gold', 'gold', name='Frame')
	m.box((0, 3.0, -0.9), (1.7, 1.6, 5.0), 'gold', 'gold', studs=True, skip=lambda x, z: z > 1.9, name='Slide')
	m.box((0, 3.18, -5.6), (1.5, 1.2, 4.8), 'gold', 'gold', name='Barrel')
	# Triangle barrel: a peaked roof of two wedges along the barrel.
	for sx, ry in ((1, -90), (-1, 90)):
		m.wedge((sx * 0.375, 4.05, -5.6), (4.8, 0.5, 0.75), 'gold', 'gold', rot=euler(0, ry, 0), name='BarrelRidge')
	m.box((0, 4.4, -7.6), (0.2, 0.3, 0.45), 'ink', name='FrontSight')
	hole(m, (0, 3.2, -8.05), 0.78)
	m.box((0, 3.95, 1.25), (1.0, 0.35, 0.4), 'ink', name='RearSight')
	m.box((0, 3.55, 1.85), (0.5, 0.75, 0.5), 'black', 'plastic', rot=euler(25), name='Hammer')
	for z in (0.25, 0.6, 0.95):
		for sx in (-1, 1):
			m.box((sx * 0.86, 3.0, z), (0.06, 1.05, 0.16), 'golddark', 'gold', bevel=0.02, name='Serration')
	for sx in (-1, 1):
		m.box((sx * 0.86, 3.0, -1.8), (0.14, 0.6, 0.6), 'cyan', 'glass', rot=euler(45), bevel=0.03, name='Gem')
		m.box((sx * 0.76, 3.2, -5.6), (0.06, 0.25, 3.6), 'golddark', 'gold', bevel=0.02, name='Engraving')
	guard(m, -3.4, -0.85, 0.35, 'gold', mat='gold', width=0.55, post=1.1)
	m.meta['muzzle'] = (0, 3.2, -8.12)
	return m


def minigun():
	m = Model('Minigun', 'Mini Gun', UNIT)
	with m.at((0, 0, 0), euler(-10)):
		m.box((0, 0, 0), (1.3, 2.8, 1.6), 'black', 'plastic', name='Grip')
	m.box((0, 2.9, -1.4), (2.8, 2.8, 5.2), 'red', 'smooth', studs=True, skip=lambda x, z: abs(z) > 1.5, name='Housing')
	for z in (-3.2, 0.3):
		m.box((0, 4.85, z), (0.5, 1.2, 0.5), 'gun', 'metal', name='HandlePost')
	m.box((0, 5.55, -1.45), (0.65, 0.5, 4.1), 'black', 'plastic', name='Handle')
	for sx in (-1, 1):
		m.box((sx * 1.42, 3.55, -1.4), (0.08, 0.32, 4.4), 'orange', 'neon', bevel=0.02, name='Neon')
		m.box((sx * 1.42, 2.25, -1.4), (0.08, 0.32, 4.4), 'orange', 'neon', bevel=0.02, name='Neon')
	m.prism((0, 2.9, 1.7), 1.0, 2.4, 'gun', 'metal', sides=8, axis='z', spin=22.5, name='MotorCap')
	m.cyl((0, 2.9, -4.4), 0.8, 2.5, 'gun', 'metal', axis='z', name='Hub')
	for k in range(6):
		a = math.radians(60 * k)
		x, y = 0.8 * math.cos(a), 2.9 + 0.8 * math.sin(a)
		m.cyl((x, y, -8.5), 8.6, 0.6, 'chrome', 'metal', axis='z', name='Barrel')
		hole(m, (x, y, -12.82), 0.34, 0.1)
	m.cyl((0, 2.9, -7.6), 0.5, 2.3, 'gun', 'metal', axis='z', name='Clamp')
	m.cyl((0, 2.9, -11.6), 0.6, 2.35, 'gun', 'metal', axis='z', name='Clamp')
	m.cyl((0, 2.9, -12.1), 0.25, 2.45, 'red', 'neon', axis='z', bevel=0.02, name='NeonRing')
	m.box((2.45, 1.25, -1.6), (1.8, 2.2, 2.8), 'olive', 'smooth', name='AmmoBox')
	m.box((2.45, 2.45, -1.6), (1.95, 0.3, 2.95), 'olivedark', 'smooth', name='AmmoLid')
	m.box((3.36, 1.1, -1.6), (0.06, 0.45, 2.6), 'yellow', 'smooth', bevel=0.02, name='AmmoStripe')
	m.box((1.6, 2.6, -1.6), (0.8, 0.5, 1.3), 'gun', 'metal', name='Chute')
	for z in (-2.4, -1.6, -0.8):
		m.cyl((2.45, 2.82, z), 1.3, 0.42, 'brass', 'gold', axis='x', bevel=0.03, name='Round')
	guard(m, -2.3, -0.8, 0.45, 'gun', mat='metal', post=1.05)
	with m.at((0, 0.5, -3.4), euler(-6)):
		m.box((0, 0, 0), (1.1, 2.3, 1.2), 'black', 'plastic', name='FrontGrip')
	m.meta['muzzle'] = (0, 2.9, -12.9)
	return m


def blaster():
	m = Model('Blaster', 'Neon Blaster', UNIT)
	with m.at((0, 0, 0), euler(-16)):
		m.box((0, 0, 0), (1.3, 2.8, 1.6), 'black', 'plastic', name='Grip')
		m.box((0, 0, 0.82), (0.55, 2.2, 0.1), 'violetneon', 'neon', bevel=0.02, name='GripNeon')
		m.box((0, -1.5, 0.0), (1.4, 0.3, 1.72), 'violet', 'smooth', name='GripCap')
	m.box((0, 2.6, -1.8), (2.0, 2.4, 6.0), 'white', 'smooth', studs=True, skip=lambda x, z: z < -0.4, name='Body')
	m.wedge((0, 4.55, -3.4), (0.4, 1.7, 2.6), 'violet', 'smooth', name='Fin')
	for sx in (-1, 1):
		m.box((sx * 1.02, 2.35, -2.0), (0.12, 1.3, 4.2), 'violet', 'smooth', name='SidePanel')
		m.box((sx * 1.06, 3.3, -1.8), (0.08, 0.24, 4.8), 'violetneon', 'neon', bevel=0.02, name='SideNeon')
	m.box((0, 2.6, 1.75), (1.7, 2.0, 1.2), 'gun', 'metal', name='RearBlock')
	m.cyl((0, 4.35, 0.5), 2.4, 1.25, 'violetneon', 'glass', axis='z', name='Cell')
	m.cyl((0, 4.35, 0.5), 2.5, 0.6, 'violetneon', 'neon', axis='z', name='CellCore')
	for z in (-0.75, 1.75):
		m.cyl((0, 4.35, z), 0.3, 1.45, 'gun', 'metal', axis='z', name='CellCap')
	m.prism((0, 2.6, -7.2), 5.0, 1.3, 'gun', 'metal', sides=8, axis='z', spin=22.5, name='Barrel')
	for z in (-5.4, -6.4, -7.4, -8.4):
		m.cyl((0, 2.6, z), 0.38, 1.95, 'violetneon', 'neon', axis='z', bevel=0.03, name='Coil')
	m.prism((0, 2.6, -10.0), 0.9, 1.9, 'white', 'smooth', sides=8, axis='z', spin=22.5, name='Emitter')
	m.cyl((0, 2.6, -10.47), 0.12, 1.15, 'violetneon', 'neon', axis='z', bevel=0.0, name='EmitterGlow')
	m.box((0, 1.45, -6.1), (1.1, 0.75, 3.2), 'violet', 'smooth', name='UnderRail')
	for sx in (-1, 1):
		m.box((sx * 1.45, 1.75, -4.1), (1.2, 0.22, 1.9), 'violet', 'smooth', rot=euler(0, 0, sx * -22), name='Wing')
	guard(m, -3.1, -0.8, 0.35, 'gun', mat='metal', post=1.1, trigger='violetneon', trigger_mat='neon')
	m.meta['muzzle'] = (0, 2.6, -10.55)
	return m


def diamond():
	m = Model('Diamond', 'Diamond Cannon', UNIT)
	with m.at((0, 0, 0), euler(-14)):
		m.box((0, 0, 0), (1.4, 3.0, 1.7), 'gold', 'gold', name='Grip')
		for sx in (-1, 1):
			m.box((sx * 0.74, 0.1, 0), (0.14, 0.7, 0.7), 'diamond', 'glass', rot=euler(45), bevel=0.03, name='Gem')
		m.box((0, -1.65, 0.0), (1.5, 0.35, 1.85), 'golddark', 'gold', name='GripCap')
	# Breech: a diamond block with a glowing core, held by studded gold bands.
	m.box((0, 3.2, -1.0), (2.6, 2.8, 4.6), 'diamonddeep', 'glass', name='Breech')
	m.box((0, 3.2, -1.0), (1.3, 1.5, 3.8), 'cyan', 'neon', bevel=0.03, name='Core')
	for z in (-3.05, 1.05):
		m.box((0, 3.2, z), (2.8, 3.0, 0.7), 'gold', 'gold', studs=True, name='Band')
	m.box((0, 4.75, -1.0), (1.6, 0.35, 2.6), 'gold', 'gold', studs=True, name='TopPlate')
	m.box((1.36, 3.2, -1.0), (0.2, 1.7, 1.7), 'gold', 'gold', name='GemFrame')
	m.box((1.5, 3.2, -1.0), (0.3, 1.05, 1.05), 'diamond', 'glass', rot=euler(45), bevel=0.04, name='Gem')
	m.prism((0, 3.2, 1.65), 0.6, 2.3, 'gold', 'gold', sides=8, axis='z', spin=22.5, name='RearCap')
	# Barrel: octagonal diamond tube, white-hot core, gold rings and a flared gold muzzle.
	# Barrel blocks alternate two diamond shades so it reads as cut blocks, not one tube.
	for z0, z1, col in ((-3.3, -4.3, 'diamond'), (-4.3, -7.3, 'diamonddeep'), (-7.3, -10.2, 'diamond'), (-10.2, -11.3, 'diamonddeep')):
		m.prism((0, 3.2, (z0 + z1) / 2), abs(z1 - z0), 2.6, col, 'glass', sides=8, axis='z', spin=22.5, name='Barrel')
	m.cyl((0, 3.2, -7.5), 8.3, 1.1, 'cyan', 'neon', axis='z', bevel=0.03, name='BarrelCore')
	for z in (-4.3, -7.3, -10.2):
		m.prism((0, 3.2, z), 0.55, 2.95, 'gold', 'gold', sides=8, axis='z', spin=22.5, name='Ring')
	m.prism((0, 3.2, -11.75), 0.9, 3.5, 'gold', 'gold', sides=8, axis='z', spin=22.5, name='Muzzle')
	m.cyl((0, 3.2, -12.24), 0.12, 2.0, 'cyan', 'neon', axis='z', bevel=0.0, name='MuzzleGlow')
	# Crystal growths: tilted diamond shards on the breech and barrel.
	m.box((0.25, 5.55, -1.6), (0.9, 1.7, 0.9), 'diamond', 'glass', rot=euler(14, 45, -16), bevel=0.04, name='Crystal')
	m.box((-0.45, 5.25, -0.3), (0.6, 1.1, 0.6), 'diamond', 'glass', rot=euler(-18, 30, 22), bevel=0.04, name='Crystal')
	m.box((0.7, 4.75, -8.7), (0.7, 1.3, 0.7), 'diamond', 'glass', rot=euler(-20, 30, 25), bevel=0.04, name='Crystal')
	m.box((-0.6, 4.6, -5.9), (0.6, 1.0, 0.6), 'diamond', 'glass', rot=euler(25, -35, -20), bevel=0.04, name='Crystal')
	with m.at((0, 1.0, -6.0), euler(-8)):
		m.box((0, 0, 0), (1.2, 2.4, 1.2), 'gold', 'gold', name='FrontGrip')
		m.box((0, -1.3, 0), (1.3, 0.3, 1.3), 'golddark', 'gold', name='FrontGripCap')
	guard(m, -3.1, -0.85, 0.35, 'gold', mat='gold', width=0.55, post=1.4, trigger='cyan', trigger_mat='neon')
	m.meta['muzzle'] = (0, 3.2, -12.3)
	return m


GUNS = [
	('Pistol', pistol),
	('Revolver', revolver),
	('Uzi', uzi),
	('Shotgun', shotgun),
	('Tommy', tommy),
	('AK', ak),
	('Deagle', deagle),
	('Minigun', minigun),
	('Blaster', blaster),
	('Diamond', diamond),
]


def build_all():
	out = []
	for tier, (gid, fn) in enumerate(GUNS, 1):
		m = fn()
		m.meta['tier'] = tier
		out.append(m)
	return out
