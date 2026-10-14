# Brings the owner's sharp asset pack (design/sharp/Huzz-Valley-UI-Sharp.zip: transparent PNGs on square
# canvases) into assets/art and assets/icons under the names the game uses. Nothing is redrawn. Each picture is only
# framed to the shape of its slot and sized for the game:
#   top    - cropped to the slot's shape from the top (characters: head and shoulders stay in view);
#   center - cropped to the slot's shape around the middle;
#   fit    - the whole picture, with see-through margins added to reach the slot's shape (objects, crowns).
# The slot shape is (w, h) in reference px; the file is SCALE times that: windows show reference px at about 1.82x
# on a 1080p screen, so 2x is sharp there and on phones. Crowns also show larger than their slot, so they get 3x.
# Usage (from huzz-valley/): python3 tools/icons/import_sharp.py   (then run pack_images.py)
import io, zipfile
from PIL import Image

ZIP, ROOT = 'design/sharp/Huzz-Valley-UI-Sharp.zip', 'Huzz-Valley-UI-Sharp/'
SCALE, CROWN_SCALE = 2.0, 3.0
ART = {  # game name: (file in the pack, mode, slot w, slot h)
    'tier-crown-sub-1': ('crowns/sub-1.png', 'fit', 28, 24),
    'tier-crown-sub-3': ('crowns/sub-3.png', 'fit', 28, 24),
    'tier-crown-sub-5': ('crowns/sub-5.png', 'fit', 28, 24),
    'tier-crown-mtb': ('crowns/mtb.png', 'fit', 28, 24),
    'tier-crown-htb': ('crowns/htb.png', 'fit', 28, 24),
    'tier-crown-stacy': ('crowns/stacy.png', 'fit', 28, 24),
    'tier-crown-true-eve': ('crowns/true-eve.png', 'fit', 28, 24),
    'char-aiko': ('characters/card-aiko.png', 'top', 151, 83),
    'char-ren': ('characters/card-ren.png', 'top', 151, 83),
    'char-sora': ('characters/card-sora.png', 'top', 151, 83),
    'char-locked': ('characters/card-hina.png', 'fit', 151, 83),
    'char-ren-full': ('characters/card-ren.png', 'fit', 216, 238),
    'char-sora-full': ('characters/card-sora.png', 'fit', 216, 238),
    'char-locked-full': ('characters/card-hina.png', 'fit', 216, 238),
    'char-aiko-full': ('characters/selected-character-model.png', 'fit', 216, 238),
    'char-aiko-tiers': ('characters/selected-character-model.png', 'center', 157, 218),
    'dance-step': ('dances/dance-card-step.png', 'fit', 178, 79),
    'dance-shuffle': ('dances/dance-card-shuffle.png', 'fit', 178, 79),
    'dance-wave': ('dances/dance-card-wave.png', 'fit', 178, 79),
    'dance-locked': ('dances/dance-card-spin.png', 'fit', 178, 79),
    'dance-preview': ('dances/selected-dance-preview.png', 'fit', 277, 132),
    'vip': ('shop/vip-promotion-character.png', 'top', 168, 92),
    'dance-pack': ('shop/dance-pack-promotion-character.png', 'top', 168, 97),
    'sunset-trail': ('shop/sunset-trail-demonstration.png', 'center', 155, 104),
    'blossom-aura': ('shop/blossom-aura-demonstration.png', 'top', 132, 104),
    'crown-pose': ('shop/crown-pose-demonstration.png', 'top', 155, 104),
    'midnight-outfit': ('shop/midnight-outfit-mesh.png', 'fit', 132, 104),
    'coins-500': ('shop/coin-pack-500.png', 'fit', 209, 109),
    'coins-2000': ('shop/coin-pack-2000.png', 'fit', 206, 109),
    'coins-5000': ('shop/coin-pack-5000.png', 'fit', 231, 109),
    'reward-coins': ('rewards/reward-coins.png', 'fit', 68, 62),
    'reward-gems': ('rewards/reward-gems.png', 'fit', 59, 62),
    'outfit-aiko': ('rewards/aiko-outfit-reward.png', 'fit', 79, 62),
    'bonus-aiko-outfit': ('rewards/bonus-aiko_outfit.png', 'fit', 80, 55),
    'bonus-ren-outfit': ('rewards/bonus-ren_outfit.png', 'fit', 91, 55),
    'bonus-silver-hair': ('rewards/bonus-silver_hair.png', 'fit', 87, 55),
    'bonus-sora': ('rewards/bonus-sora_character.png', 'top', 81, 55),
}
# Icons: trimmed to the drawing and stored at 256 px (pack_images.py shrinks the in-game copy to 128).
# Kept from the earlier icon sheet: cart, book, note, trophy, coin, gem. The favourites stay the kit's stars (the
# pack's hearts were a mix-up in the request; the reference uses stars).
# The second pack (design/sharp/Huzz-Valley-Additional-Icons.zip): the star, tick, sneaker and a navy shirt for the
# EQUIP / UNEQUIP button. The shop's "Exclusive Cosmetics" row keeps the kit's white shirt (navy would vanish on the
# dark card).
ZIP2, ROOT2 = 'design/sharp/Huzz-Valley-Additional-Icons.zip', 'Huzz-Valley-Additional-Icons/'
ICONS2 = {
    'favourite-outline': 'favourite-outline.png', 'check-equipped': 'check-equipped.png', 'sneaker': 'sneaker.png',
    'shirt-equip': 'shirt-benefit.png',
}
ICONS = {
    'lock': 'icons/lock.png', 'search': 'icons/search.png', 'play': 'icons/play.png', 'stop': 'icons/stop.png',
    'xp-badge': 'icons/xp-badge.png', 'currency-plus': 'icons/currency-plus.png', 'controls-menu': 'icons/main-menu-lines.png',
}


def frame(im, mode, w, h):
    im = im.crop(im.getbbox())  # the drawing itself, without the square canvas's empty margins
    want = w / h
    if mode == 'fit':
        cw, ch = im.size
        if cw / ch < want:
            cw = round(ch * want)
        else:
            ch = round(cw / want)
        out = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        out.paste(im, ((cw - im.width) // 2, (ch - im.height) // 2))
        return out
    cw, ch = im.size
    if cw / ch > want:  # wider than the slot: trim the sides
        nw = round(ch * want)
        x = (cw - nw) // 2
        return im.crop((x, 0, x + nw, ch))
    nh = round(cw / want)  # taller than the slot: trim the bottom (top) or both ends (center)
    y = 0 if mode == 'top' else (ch - nh) // 2
    return im.crop((0, y, cw, y + nh))


z = zipfile.ZipFile(ZIP)
for name, (src, mode, w, h) in ART.items():
    im = Image.open(io.BytesIO(z.read(ROOT + src))).convert('RGBA')
    k = CROWN_SCALE if name.startswith('tier-crown') else SCALE
    out = frame(im, mode, w, h).resize((round(w * k), round(h * k)), Image.LANCZOS)
    out.save(f'assets/art/{name}.png')
for name, src in ICONS.items():
    im = Image.open(io.BytesIO(z.read(ROOT + src))).convert('RGBA')
    im = im.crop(im.getbbox())
    im.thumbnail((256, 256), Image.LANCZOS)
    im.save(f'assets/icons/{name}.png')
z2 = zipfile.ZipFile(ZIP2)
for name, src in ICONS2.items():
    im = Image.open(io.BytesIO(z2.read(ROOT2 + src))).convert('RGBA')
    im = im.crop(im.getbbox())
    im.thumbnail((256, 256), Image.LANCZOS)
    im.save(f'assets/icons/{name}.png')
print('imported', len(ART), 'pictures and', len(ICONS) + len(ICONS2), 'icons')
