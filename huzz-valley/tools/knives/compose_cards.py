# Finishes the shop card pictures of the owner's 30 knives in the style of his mock-up
# (design/knives/knifepictures-mockup.png: the knife big and diagonal, glowing in its own colour, a few soft
# sparkles and wisps on a dark background tinted to match). The knife itself is his model as rendered by
# tools/knives/render_cards.mjs (his geometry and colours, not redrawn); only the background, the glow round it and
# the sparkles are drawn here. Calm by rarity, so it reads at card size: Common = a faint steel glow and no
# sparkles ... Mythic = the strongest glow, 7 sparkles and two wisps.
# The card's frame, name, "KNIFE" and button are the game's UI (Screens/Shop), not part of the picture.
# Writes assets/art/knife-<key>.png (384 px; tools/icons/pack_images.py packs them at 192 px for the game) and
# docs/previews/knife-cards.jpg (all 53 as cards next to a crop of the mock-up).
# Usage (from huzz-valley/): python3 -I tools/knives/compose_cards.py <raw render dir>
#   ONLY=Exclusive (env) remakes only that rarity's pictures, ONLY=halloween only his Halloween file's (the sheet
#   reuses the other cards already in assets/art), so adding knives doesn't redraw the 30 shop cards.
import json, math, os, random, re, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = 384
RARITY = {
    #           glow, bloom, sparkles, wisps, background tint
    'Common':    (0.22, 0.0, 0, 0, 0.18),
    'Uncommon':  (0.32, 0.5, 2, 0, 0.24),
    'Rare':      (0.50, 0.9, 4, 0, 0.32),
    'Epic':      (0.62, 1.0, 5, 1, 0.36),
    'Legendary': (0.70, 1.1, 6, 2, 0.40),
    'Mythic':    (0.75, 1.1, 7, 2, 0.42),
    'Exclusive': (0.80, 1.2, 7, 2, 0.44),  # the 5 Game Pass knives (never sold for coins)
}
NAVY = (9, 12, 34)


def kebab(key):
    return re.sub(r'([a-z])([A-Z])', r'\1-\2', key).lower()


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tinted(alpha, colour, strength):
    layer = Image.new('RGB', alpha.size, colour)
    return layer, alpha.point(lambda v: int(v * strength))


def star(draw, x, y, r, colour, alpha):
    # a soft four-point sparkle: two thin diamonds and a small core
    w = max(1.0, r * 0.22)
    for dx, dy in ((1, 0), (0, 1)):
        pts = [(x - dx * r, y - dy * r), (x + dy * w, y + dx * w), (x + dx * r, y + dy * r), (x - dy * w, y - dx * w)]
        draw.polygon(pts, fill=colour + (alpha,))
    draw.ellipse((x - w * 1.3, y - w * 1.3, x + w * 1.3, y + w * 1.3), fill=(255, 255, 255, alpha))


def card(raw, k):
    glow_s, bloom_s, n_sparkles, n_wisps, tint = RARITY[k['rarity']]
    colour = rgb(k['glow']) if k['glow'] else rgb(k['sheen']) if k['sheen'] != 'ffffff' else (150, 170, 205)
    if not k['glow']:
        colour = mix(colour, (150, 170, 205), 0.5)  # (no glowing parts: a quiet steel-blue light)
    big = OUT * 2
    lit = Image.open(os.path.join(raw, k['key'] + '.png')).convert('RGBA').resize((big, big), Image.LANCZOS)
    glowmask = Image.open(os.path.join(raw, k['key'] + '_glow.png')).convert('RGBA').resize((big, big), Image.LANCZOS)
    alpha = lit.getchannel('A')
    bbox = alpha.getbbox() or (0, 0, big, big)
    cx, cy = (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2
    # background: dark navy tinted with the knife's colour, a soft light behind the knife, darker corners
    bg = Image.new('RGB', (big, big), mix(NAVY, colour, tint * 0.35))
    light = Image.new('L', (big, big), 0)
    ImageDraw.Draw(light).ellipse((cx - big * 0.42, cy - big * 0.32, cx + big * 0.42, cy + big * 0.32), fill=int(255 * tint * 1.4))
    light = light.filter(ImageFilter.GaussianBlur(big * 0.12))
    bg.paste(Image.new('RGB', (big, big), colour), (0, 0), light)
    vignette = Image.new('L', (big, big), 0)
    ImageDraw.Draw(vignette).ellipse((-big * 0.25, -big * 0.25, big * 1.25, big * 1.25), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(big * 0.12))
    bg = Image.composite(bg, Image.new('RGB', (big, big), (4, 6, 18)), vignette)
    # wisps: a soft curl or two round the blade (Epic and up)
    rnd = random.Random(k['key'])
    if n_wisps:
        wl = Image.new('L', (big, big), 0)
        d = ImageDraw.Draw(wl)
        for i in range(n_wisps):
            rx, ry = big * (0.30 + 0.06 * i), big * (0.11 + 0.03 * i)
            a0 = rnd.uniform(160, 220)
            d.arc((cx - rx, cy - ry, cx + rx, cy + ry), a0, a0 + rnd.uniform(110, 150), fill=200, width=int(big * 0.012))
        wl = wl.rotate(35, center=(cx, cy), resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(big * 0.008))
        bg.paste(Image.new('RGB', (big, big), mix(colour, (255, 255, 255), 0.25)), (0, 0), wl.point(lambda v: int(v * 0.45)))
    # the glow round the knife (its outline, blurred) and the bloom off its glowing parts
    halo = alpha.filter(ImageFilter.GaussianBlur(big * 0.03))
    bg.paste(Image.new('RGB', (big, big), colour), (0, 0), halo.point(lambda v: int(min(255, v * glow_s * 1.6))))
    if bloom_s:
        gm = glowmask.convert('RGB')
        for radius, amount in ((big * 0.006, 0.9), (big * 0.02, 0.6)):
            b = gm.filter(ImageFilter.GaussianBlur(radius))
            bg = ImageChops.add(bg, b.point(lambda v: int(v * amount * bloom_s)))
    bg = bg.convert('RGBA')
    bg.alpha_composite(lit)
    # sparkles round the blade (never on the handle end), small and soft
    sp = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(sp)
    ux, uy = math.cos(math.radians(-35)), math.sin(math.radians(-35))  # along the blade, toward the tip
    for i in range(n_sparkles):
        t = rnd.uniform(-0.05, 0.42)
        side = rnd.choice((-1, 1)) * rnd.uniform(0.10, 0.22)
        x = cx + ux * t * big + (-uy) * side * big
        y = cy + uy * t * big + ux * side * big
        star(d, x, y, big * rnd.uniform(0.012, 0.026), mix(colour, (255, 255, 255), 0.45), int(255 * rnd.uniform(0.55, 0.85)))
    sp = sp.filter(ImageFilter.GaussianBlur(1.2))
    bg.alpha_composite(sp)
    return bg.convert('RGB').resize((OUT, OUT), Image.LANCZOS)


def sheet(cards, knives):
    # all 30 as the Shop's ITEMS cards draw them (161 x 170: picture 157 x 124 behind the name and rarity line,
    # the button under), next to a crop of the owner's mock-up; 2x for a sharp look
    S = 2
    W, H, GAP, COLS = 161 * S, 170 * S, 8 * S, 6
    def font(size, want):
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)  # (the preview's Gotham stand-in)
        try:
            f.set_variation_by_name({'bold': 'Bold', 'semibold': 'SemiBold', 'black': 'Black'}[want])
        except Exception:
            pass
        return f
    name_f, slot_f, btn_f = font(14 * S, 'bold'), font(11 * S, 'semibold'), font(20 * S, 'black')
    rare = {'Common': (190, 196, 210), 'Uncommon': (110, 220, 120), 'Rare': (90, 170, 255), 'Epic': (190, 110, 255), 'Legendary': (255, 190, 60), 'Mythic': (255, 84, 120), 'Exclusive': (255, 110, 230)}
    rows = math.ceil(len(cards) / COLS)
    grid_w, grid_h = COLS * W + (COLS - 1) * GAP, rows * H + (rows - 1) * GAP
    mock = Image.open('design/knives/knifepictures-mockup.png').convert('RGB')
    crop = mock.crop((0, 0, 1536, 610))
    crop = crop.resize((int(crop.width * grid_h / crop.height * 0.5), int(grid_h * 0.5)), Image.LANCZOS)
    pad = 40
    out = Image.new('RGB', (pad * 3 + grid_w + crop.width, pad * 2 + grid_h + 60), (14, 16, 30))
    d = ImageDraw.Draw(out)
    title = font(26, 'black')
    d.text((pad, 18), 'OURS: his %d real knives (renders of his .glb), as the ITEMS cards' % len(cards), font=title, fill=(255, 255, 255))
    d.text((pad * 2 + grid_w, 18), "HIS MOCK-UP (style only)", font=title, fill=(255, 255, 255))
    out.paste(crop, (pad * 2 + grid_w, pad + 40))
    for i, (k, img) in enumerate(zip(knives, cards)):
        x, y = pad + (i % COLS) * (W + GAP), pad + 40 + (i // COLS) * (H + GAP)
        c = Image.new('RGB', (W, H), (11, 28, 62))
        pic = img.resize((157 * S, 157 * S), Image.LANCZOS).crop((0, (157 - 124) * S // 2, 157 * S, (157 + 124) * S // 2))
        m = Image.new('L', pic.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, pic.width - 1, pic.height - 1), 5 * S, fill=255)
        c.paste(pic, (2 * S, 2 * S), m)
        cd = ImageDraw.Draw(c)
        cd.rounded_rectangle((0, 0, W - 1, H - 1), 6 * S, outline=rare[k['rarity']], width=2 * S)
        cd.text((W // 2, 16 * S), k['name'], font=name_f, fill=(255, 255, 255), anchor='mm', stroke_width=2 * S // 2, stroke_fill=(10, 14, 40))
        cd.text((W // 2, 31 * S), k['rarity'].upper() + ' · KNIFE', font=slot_f, fill=rare[k['rarity']], anchor='mm', stroke_width=1, stroke_fill=(10, 14, 40))
        cd.rounded_rectangle((7 * S, H - 42 * S, W - 7 * S, H - 6 * S), 5 * S, fill=(110, 82, 248))
        label = 'EARN IT' if k.get('unlock') else 'SPIN' if k['key'] == 'SpinKnife' else 'GAME PASS' if k['price'] is None else '{:,}'.format(k['price'])
        cd.text((W // 2, H - 24 * S), label, font=btn_f, fill=(255, 255, 255), anchor='mm')
        m2 = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m2).rounded_rectangle((0, 0, W - 1, H - 1), 6 * S, fill=255)
        out.paste(c, (x, y), m2)
    out = out.resize((out.width // 2, out.height // 2), Image.LANCZOS)
    out.save('docs/previews/knife-cards.jpg', quality=90)
    print('sheet -> docs/previews/knife-cards.jpg', out.size)


def main(raw):
    knives = json.load(open('tools/knives/knives.json'))
    prices = {'Common': 200, 'Uncommon': 500, 'Rare': 1000, 'Epic': 2000, 'Legendary': 4000, 'Mythic': 8000}
    unlock = {'RookieKnife', 'HunterKnife', 'MoonlitKnife'}
    only = os.environ.get('ONLY')
    cards = []
    for k in knives:
        k['price'] = prices.get(k['rarity'])  # (None: a Game Pass knife)
        k['unlock'] = k['key'] in unlock
        path = 'assets/art/knife-%s.png' % kebab(k['key'])
        if only and k['rarity'] != only and not k['file'].startswith(only + '/'):
            cards.append(Image.open(path).convert('RGB'))
            continue
        img = card(raw, k)
        img.save(path, optimize=True)
        cards.append(img)
    print('cards -> assets/art/knife-*.png (%d)' % len(cards))
    sheet(cards, knives)


if __name__ == '__main__':
    main(sys.argv[1])
