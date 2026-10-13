"""Hood UI icons: die-cut sticker style. Each icon = shape group drawn three times:
white sticker border (widest stroke), ink outline, then the coloured fills and cel shading on top.
Run: python3 make_icons.py  ->  writes <name>.svg next to this file."""
import math, os

INK = '#1C1830'
W_STICKER, W_INK = 34, 16   # total stroke widths (half shows outside the shape)

def sticker(name, shape, art, extra_defs=''):
    """shape: SVG elements (no fill/stroke) forming the silhouette; art: coloured layers on top."""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
<defs>
  <g id="s">{shape}</g>
  <clipPath id="clip">{shape}</clipPath>{extra_defs}
</defs>
<g transform="translate(0,6)" opacity="0.28"><use href="#s" fill="{INK}" stroke="{INK}" stroke-width="{W_STICKER}" stroke-linejoin="round" stroke-linecap="round"/></g>
<use href="#s" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="{W_STICKER}" stroke-linejoin="round" stroke-linecap="round"/>
<use href="#s" fill="{INK}" stroke="{INK}" stroke-width="{W_INK}" stroke-linejoin="round" stroke-linecap="round"/>
<g clip-path="url(#clip)">{art}</g>
</svg>'''
    open(f'{name}.svg', 'w').write(svg)

# Lightning bolt: Power
bolt = 'M152 18 L58 142 L116 142 L92 238 L200 104 L138 104 L166 18 Z'
sticker('power', f'<path d="{bolt}"/>', f'''
<path d="{bolt}" fill="#FFC21A"/>
<path d="M138 104 L200 104 L92 238 L120 128 Z" fill="#F29A00"/>
<path d="M152 18 L166 18 L140 96 L120 96 Z" fill="#FFE98A"/>
<path d="M62 136 L96 92 L104 98 L76 136 Z" fill="#FFF4C2"/>''')

# Cash: two bills and a paper band
def bill(x, y, a, base, edge):
    return (f'<g transform="rotate({a} {x} {y})"><rect x="{x-78}" y="{y-46}" width="156" height="92" rx="12" fill="{base}"/>'
            f'<rect x="{x-64}" y="{y-34}" width="128" height="68" rx="8" fill="none" stroke="{edge}" stroke-width="6"/>'
            f'<circle cx="{x}" cy="{y}" r="24" fill="{edge}"/></g>')
cash_shape = '<rect x="38" y="66" width="156" height="92" rx="12" transform="rotate(-12 116 112)"/><rect x="62" y="104" width="156" height="92" rx="12" transform="rotate(6 140 150)"/>'
sticker('cash', cash_shape, bill(116, 112, -12, '#2BA650', '#1F7F3C') + bill(140, 150, 6, '#3FD46B', '#2BA650') + '''
<g transform="rotate(6 140 150)"><text x="140" y="164" font-family="Luckiest Guy" font-size="40" text-anchor="middle" fill="#E9FFE9">$</text>
<rect x="98" y="104" width="22" height="92" fill="#FFEFD2"/><rect x="98" y="104" width="22" height="10" fill="#F4D9A8"/>
<rect x="62" y="104" width="156" height="14" fill="#7BEA97" opacity=".7"/></g>''')

# Hoodie: Outfits / Drip Shop
hood_path = 'M98 34 Q128 20 158 34 L210 62 L236 132 L200 146 L188 118 L188 226 L68 226 L68 118 L56 146 L20 132 L46 62 Z'
sticker('outfits', f'<path d="{hood_path}"/>', f'''
<path d="{hood_path}" fill="#E2553D"/>
<path d="M188 118 L188 226 L150 226 L150 110 Z" fill="#B83A27"/>
<path d="M210 62 L236 132 L200 146 L188 118 Z" fill="#B83A27"/>
<path d="M98 34 Q128 20 158 34 L170 64 Q128 98 86 64 Z" fill="#9C2F22"/>
<path d="M104 50 Q128 82 152 50" fill="none" stroke="#1C1830" stroke-width="8" stroke-linecap="round"/>
<rect x="88" y="160" width="80" height="40" rx="10" fill="#B83A27"/>
<path d="M114 80 L110 128 M142 80 L146 128" stroke="#FFEFD2" stroke-width="7" stroke-linecap="round"/>
<path d="M46 62 L98 34 L104 46 L58 74 Z" fill="#FF8A72"/>
<rect x="68" y="210" width="120" height="16" fill="#9C2F22"/>''')

# Paw: Crew
paw = '<ellipse cx="128" cy="164" rx="58" ry="50"/><ellipse cx="62" cy="102" rx="24" ry="30"/><ellipse cx="106" cy="66" rx="24" ry="32"/><ellipse cx="152" cy="66" rx="24" ry="32"/><ellipse cx="196" cy="102" rx="24" ry="30"/>'
sticker('crew', paw, f'''
<g fill="#FF9F43">{paw}</g>
<ellipse cx="146" cy="182" rx="44" ry="34" fill="#E07B1E"/>
<g fill="#FFB8C8"><ellipse cx="128" cy="168" rx="34" ry="26"/><ellipse cx="62" cy="106" rx="11" ry="14"/><ellipse cx="106" cy="70" rx="11" ry="15"/><ellipse cx="152" cy="70" rx="11" ry="15"/><ellipse cx="196" cy="106" rx="11" ry="14"/></g>
<g fill="#FFD9A8"><ellipse cx="96" cy="140" rx="14" ry="9"/><ellipse cx="98" cy="54" rx="7" ry="9"/><ellipse cx="144" cy="54" rx="7" ry="9"/></g>''')

# Rebirth: two curved arrows chasing each other
def arc(cx, cy, r, a0, a1):
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    return f'M{x0:.1f} {y0:.1f} A{r} {r} 0 0 1 {x1:.1f} {y1:.1f}'
def head(cx, cy, r, a, size):
    # arrowhead at angle a on the circle, pointing along the clockwise tangent
    px, py = cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))
    tx, ty = -math.sin(math.radians(a)), math.cos(math.radians(a))
    nx, ny = math.cos(math.radians(a)), math.sin(math.radians(a))
    tip = (px + tx * size, py + ty * size)
    l = (px + nx * size * 0.95, py + ny * size * 0.95); rr = (px - nx * size * 0.95, py - ny * size * 0.95)
    return f'M{tip[0]:.1f} {tip[1]:.1f} L{l[0]:.1f} {l[1]:.1f} L{rr[0]:.1f} {rr[1]:.1f} Z'
cx, cy, r = 128, 132, 74
arcs = arc(cx, cy, r, 200, 330) + ' ' + arc(cx, cy, r, 20, 150)
heads = head(cx, cy, r, 330, 34) + ' ' + head(cx, cy, r, 150, 34)
shape = f'<path d="{arcs}" fill="none" stroke-width="40" stroke="#000"/><path d="{heads}"/>'
# For stroked arcs the silhouette stroke must be thicker than the colour stroke, so build it explicitly.
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
<g transform="translate(0,6)" opacity="0.28"><path d="{arcs}" fill="none" stroke="{INK}" stroke-width="{40+W_STICKER}" stroke-linecap="round"/><path d="{heads}" fill="{INK}" stroke="{INK}" stroke-width="{W_STICKER}" stroke-linejoin="round"/></g>
<path d="{arcs}" fill="none" stroke="#fff" stroke-width="{40+W_STICKER}" stroke-linecap="round"/><path d="{heads}" fill="#fff" stroke="#fff" stroke-width="{W_STICKER}" stroke-linejoin="round"/>
<path d="{arcs}" fill="none" stroke="{INK}" stroke-width="{40+W_INK}" stroke-linecap="round"/><path d="{heads}" fill="{INK}" stroke="{INK}" stroke-width="{W_INK}" stroke-linejoin="round"/>
<path d="{arcs}" fill="none" stroke="#A64DFF" stroke-width="40" stroke-linecap="round"/><path d="{heads}" fill="#A64DFF"/>
<path d="{arc(cx, cy, r - 12, 205, 320)}" fill="none" stroke="#D7A6FF" stroke-width="9" stroke-linecap="round"/>
<path d="{arc(cx, cy, r - 12, 25, 140)}" fill="none" stroke="#D7A6FF" stroke-width="9" stroke-linecap="round"/>
<path d="{arc(cx, cy, r + 13, 215, 325)}" fill="none" stroke="#7A2FD0" stroke-width="10" stroke-linecap="round"/>
<path d="{arc(cx, cy, r + 13, 35, 145)}" fill="none" stroke="#7A2FD0" stroke-width="10" stroke-linecap="round"/>
</svg>'''
open('rebirth.svg', 'w').write(svg)

# Gift: Daily rewards
gift = '<rect x="40" y="108" width="176" height="120" rx="10"/><rect x="28" y="74" width="200" height="48" rx="10"/><path d="M128 76 C92 20 52 40 74 74 Z"/><path d="M128 76 C164 20 204 40 182 74 Z"/>'
sticker('gift', gift, '''
<rect x="40" y="108" width="176" height="120" fill="#FF4757"/><rect x="150" y="108" width="66" height="120" fill="#C9283C"/>
<rect x="28" y="74" width="200" height="48" fill="#FF6B78"/><rect x="28" y="110" width="200" height="12" fill="#B01E35"/>
<rect x="110" y="74" width="36" height="160" fill="#FFC21A"/><rect x="134" y="74" width="12" height="160" fill="#D57D00"/>
<path d="M128 76 C92 20 52 40 74 74 Z M128 76 C164 20 204 40 182 74 Z" fill="#FFC21A"/>
<path d="M96 56 C100 50 110 52 116 64" fill="none" stroke="#FFF1A8" stroke-width="7" stroke-linecap="round"/>''')

# Trophy: Leaderboards
trophy = '<path d="M64 36 L192 36 L186 112 Q178 160 128 166 Q78 160 70 112 Z"/><rect x="112" y="160" width="32" height="34"/><rect x="72" y="190" width="112" height="40" rx="10"/><path d="M68 54 Q22 54 30 96 Q38 128 78 132" fill="none" stroke="#000" stroke-width="18"/><path d="M188 54 Q234 54 226 96 Q218 128 178 132" fill="none" stroke="#000" stroke-width="18"/>'
handles = '<path d="M68 54 Q22 54 30 96 Q38 128 78 132" fill="none" stroke-width="18"/><path d="M188 54 Q234 54 226 96 Q218 128 178 132" fill="none" stroke-width="18"/>'
body = '<path d="M64 36 L192 36 L186 112 Q178 160 128 166 Q78 160 70 112 Z"/><rect x="112" y="160" width="32" height="34"/><rect x="72" y="190" width="112" height="40" rx="10"/>'
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
<g transform="translate(0,6)" opacity="0.28"><g stroke="{INK}" stroke-width="{18+W_STICKER}" stroke-linecap="round">{handles.replace('stroke-width="18"','')}</g><g fill="{INK}" stroke="{INK}" stroke-width="{W_STICKER}" stroke-linejoin="round">{body}</g></g>
<g stroke="#fff" stroke-width="{18+W_STICKER}" stroke-linecap="round" fill="none">{handles.replace('stroke-width="18"','')}</g><g fill="#fff" stroke="#fff" stroke-width="{W_STICKER}" stroke-linejoin="round">{body}</g>
<g stroke="{INK}" stroke-width="{18+W_INK}" stroke-linecap="round" fill="none">{handles.replace('stroke-width="18"','')}</g><g fill="{INK}" stroke="{INK}" stroke-width="{W_INK}" stroke-linejoin="round">{body}</g>
<g stroke="#FFC21A" stroke-linecap="round" fill="none">{handles}</g>
<defs><clipPath id="tc">{body}</clipPath></defs>
<g clip-path="url(#tc)"><g fill="#FFC21A">{body}</g><path d="M150 36 L192 36 L186 112 Q178 160 128 166 L128 36 Z" fill="#E59A00"/>
<rect x="72" y="214" width="112" height="16" fill="#B86E00"/><path d="M86 48 L100 48 L96 112 L88 112 Z" fill="#FFF1A8"/>
<rect x="96" y="202" width="64" height="12" rx="4" fill="#1C1830" opacity=".25"/></g>
<text x="128" y="122" font-family="Luckiest Guy" font-size="54" text-anchor="middle" fill="#FFF7D1" stroke="#B86E00" stroke-width="4" paint-order="stroke">1</text>
</svg>'''
open('trophy.svg', 'w').write(svg)

# Gear: Settings
pts = []
for i in range(10):
    for a_off, rad in ((-11, 104), (11, 104), (14, 80), (25, 80)):
        a = math.radians(i * 36 + a_off)
        pts.append((128 + rad * math.cos(a), 128 + rad * math.sin(a)))
gear = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
sticker('settings', f'<path d="{gear}"/>', f'''
<path d="{gear}" fill="#B8BEC8"/><circle cx="148" cy="148" r="80" fill="#8A93A3"/><path d="{gear}" fill="#B8BEC8" transform="translate(-6,-6)" opacity=".9"/>
<circle cx="128" cy="128" r="34" fill="#1C1830"/><circle cx="128" cy="128" r="22" fill="#2B2E45"/>
<path d="M70 92 A68 68 0 0 1 112 62" fill="none" stroke="#EEF1F6" stroke-width="10" stroke-linecap="round"/>''')

# Street sign: Stages / teleport
sign = '<rect x="114" y="96" width="28" height="140" rx="6"/><path d="M24 40 L196 40 L234 74 L196 108 L24 108 Z"/>'
sticker('stages', sign, '''
<rect x="114" y="96" width="28" height="140" fill="#8A93A3"/><rect x="130" y="96" width="12" height="140" fill="#5E6676"/>
<path d="M24 40 L196 40 L234 74 L196 108 L24 108 Z" fill="#2E9E5B"/><path d="M24 92 L212 92 L196 108 L24 108 Z" fill="#1F7442"/>
<path d="M36 52 L190 52 L218 74 L190 96 L36 96 Z" fill="none" stroke="#FFFFFF" stroke-width="5"/>
<text x="118" y="88" font-family="Luckiest Guy" font-size="38" text-anchor="middle" fill="#FFFFFF">GO</text>''')

# Ticket: Codes
ticket = 'M30 70 L226 70 L226 112 A18 18 0 0 0 226 148 L226 190 L30 190 L30 148 A18 18 0 0 0 30 112 Z'
sticker('codes', f'<path d="{ticket}"/>', f'''
<path d="{ticket}" fill="#2F9BFF"/><rect x="30" y="160" width="196" height="30" fill="#1A5FB4"/>
<path d="M172 78 L172 182" stroke="#BFE3FF" stroke-width="7" stroke-dasharray="12 10"/>
<text x="100" y="146" font-family="Luckiest Guy" font-size="44" text-anchor="middle" fill="#FFFFFF" stroke="#1A5FB4" stroke-width="5" paint-order="stroke">CODE</text>
<rect x="40" y="80" width="120" height="8" rx="4" fill="#7CCBFF"/>''')

# Boxing glove: Train / punch
glove = 'M70 120 Q56 48 120 36 Q196 26 212 90 Q224 150 186 178 L178 184 L178 214 L84 214 L84 184 Q66 160 70 120 Z'
sticker('train', f'<path d="{glove}"/>', f'''
<path d="{glove}" fill="#FF4757"/>
<path d="M150 34 Q196 30 212 90 Q224 150 186 178 L160 184 Q200 130 150 34 Z" fill="#C9283C"/>
<path d="M70 124 Q66 90 92 78 Q128 70 132 104 Q134 134 100 140 Q74 142 70 124 Z" fill="#E8364A"/>
<path d="M76 118 Q78 96 98 90" fill="none" stroke="#1C1830" stroke-width="7" stroke-linecap="round"/>
<path d="M96 54 Q120 40 150 44" fill="none" stroke="#FFB0B8" stroke-width="10" stroke-linecap="round"/>
<rect x="80" y="180" width="102" height="38" fill="#FFEFD2"/><rect x="80" y="180" width="102" height="10" fill="#F4D9A8"/>
<rect x="150" y="180" width="32" height="38" fill="#E9D3AE"/>''')
print('icons:', sorted(f for f in os.listdir('.') if f.endswith('.svg')))
