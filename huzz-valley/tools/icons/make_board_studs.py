# Draws the leaderboard slab's stud texture (assets/icons/board-stud.png): one Roblox stud seen straight on, as Huss
# Valley's boards show them (design/lobby-ref/lb_f1.jpg, measured on the straightened board: one stud every 50 canvas
# px, the raised square about 23 px = 46% of the pitch, a dark shadow along its bottom and right, a thin light top
# edge, the face the slab's own colour). White/black with alpha, so it lies over any colour: Shared/LeaderboardLook
# tiles it across the face (TileSize 50) over the slab colour. Drawn at 2x (100 px a tile) for Retina screens.
# Usage (from huzz-valley/): python3 tools/icons/make_board_studs.py   (then python3 tools/icons/pack_images.py)
from PIL import Image, ImageDraw, ImageFilter

T = 100  # px a tile (one stud at 2x)
SS = 4
big = Image.new('RGBA', (T * SS, T * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
u = T * SS / 50.0  # one canvas px


def box(x0, y0, x1, y1, fill, r=2.0):
    d.rounded_rectangle((x0 * u, y0 * u, x1 * u, y1 * u), radius=r * u, fill=fill)


# the stud: 23 x 23 canvas px, centred
a, b = 13.5, 36.5
box(a + 1.2, a + 2.4, b + 1.6, b + 3.0, (0, 0, 0, 150))       # shadow below and right (the ref's dark lower edge)
box(a - 0.4, a - 0.6, b, b, (255, 255, 255, 70))                # light top / left rim
box(a, a, b + 0.4, b + 0.6, (0, 0, 0, 100))                    # dark bottom / right rim
box(a + 0.2, a + 0.2, b - 0.2, b - 0.2, (255, 255, 255, 16))   # the face, a touch lighter than the slab
img = big.resize((T, T), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.4))
img.save('assets/icons/board-stud.png')
print('board stud', img.size)
