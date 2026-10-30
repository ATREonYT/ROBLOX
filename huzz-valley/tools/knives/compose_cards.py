# Finishes the shop card pictures of the owner's knives (his 30, his 5 Game Pass and 18 Halloween knives): his knife
# big and diagonal like his mock-up (design/knives/knifepictures-mockup.png), on a calm, flat dark panel.
# Owner, Oct 20 14:07: "for all of the knifes, can you make the background look a bit less ai. the glow just gives
# it away like crazy": so no glow halo, no bloom, no sparkles and no swoosh lines any more. Only a plain dark panel
# with a faint tint of the knife's rarity (slightly lighter at the top, like a lit table) and a soft shadow under the
# knife so it sits on the panel. The knife itself is his model as rendered by tools/knives/render_cards.mjs (his
# geometry and colours, not redrawn); its own Neon parts are as Roblox draws Neon (flat bright), not bloomed.
# The card's frame, name, "KNIFE" and button are the game's UI (Screens/Shop), not part of the picture.
# Writes assets/art/knife-<key>.png (384 px; tools/icons/pack_images.py packs them at 192 px for the game) and
# docs/previews/knife-cards.jpg (all 53 as cards next to a crop of the mock-up).
# Usage (from huzz-valley/): python3 -I tools/knives/compose_cards.py <raw render dir>
#   ONLY=Exclusive (env) remakes only that rarity's pictures, ONLY=halloween only his Halloween file's (the sheet
#   reuses the other cards already in assets/art), so adding knives doesn't redraw the 30 shop cards.
import json, math, os, re, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = 384
# the rarity's colour (as the card's rim and rarity line in Screens/Shop) and how much of it tints the panel
RARITY = {
    'Common':    ((190, 196, 210), 0.05),
    'Uncommon':  ((110, 220, 120), 0.06),
    'Rare':      ((90, 170, 255), 0.07),
    'Epic':      ((190, 110, 255), 0.08),
    'Legendary': ((255, 190, 60), 0.08),
    'Mythic':    ((255, 84, 120), 0.08),
    'Exclusive': ((255, 110, 230), 0.08),  # the 5 Game Pass knives (never sold for coins)
}
PANEL_TOP, PANEL_BOTTOM = (26, 30, 48), (14, 16, 28)  # a plain dark slate, a little lighter at the top


def kebab(key):
    return re.sub(r'([a-z])([A-Z])', r'\1-\2', key).lower()


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def card(raw, k):
    rare, tint = RARITY[k['rarity']]
    big = OUT * 2
    lit = Image.open(os.path.join(raw, k['key'] + '.png')).convert('RGBA').resize((big, big), Image.LANCZOS)
    alpha = lit.getchannel('A')
    # the panel: flat, a gentle top-to-bottom shade, a faint tint of the rarity (no light behind the knife, no vignette)
    top, bottom = mix(PANEL_TOP, rare, tint), mix(PANEL_BOTTOM, rare, tint * 0.6)
    grad = Image.linear_gradient('L').resize((big, big))
    bg = Image.composite(Image.new('RGB', (big, big), bottom), Image.new('RGB', (big, big), top), grad)
    # a soft shadow under the knife: its own outline, dropped a little and blurred, never coloured
    shadow = Image.new('L', (big, big), 0)
    shadow.paste(alpha, (int(big * 0.012), int(big * 0.035)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(big * 0.018)).point(lambda v: int(v * 0.55))
    bg.paste(Image.new('RGB', (big, big), (0, 0, 0)), (0, 0), shadow)
    bg = bg.convert('RGBA')
    bg.alpha_composite(lit)
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
