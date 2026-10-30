# Draws icons/RoundStud.png: one classic Roblox stud per tile, grey-scale on a
# clear background so a Texture over any coloured part shows it in that colour.
# Light from the top-left: white rim highlight, dark lower-right shadow, a faint
# seam around the tile edge. 256 px, drawn 4x and scaled down for smooth edges.
from PIL import Image, ImageDraw, ImageFilter
import sys
N, K = 256, 4
W = N * K
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# seam between studs
d.rectangle([0, 0, W - 1, W - 1], outline=(0, 0, 0, 70), width=3 * K)
d.line([(3 * K, 3 * K), (W - 3 * K, 3 * K)], fill=(255, 255, 255, 45), width=3 * K)
d.line([(3 * K, 3 * K), (3 * K, W - 3 * K)], fill=(255, 255, 255, 45), width=3 * K)
c, r = W / 2, W * 0.30
# drop shadow down-right
sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(sh).ellipse([c - r + 14 * K, c - r + 16 * K, c + r + 14 * K, c + r + 16 * K], fill=(0, 0, 0, 95))
img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8 * K)))
# stud side (darker ring) then top face
d = ImageDraw.Draw(img)
d.ellipse([c - r, c - r + 6 * K, c + r, c + r + 6 * K], fill=(0, 0, 0, 60))
# the top face hides the shadow and side under it
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).ellipse([c - r, c - r, c + r, c + r], fill=255)
a = img.getchannel("A")
img.putalpha(Image.composite(Image.new("L", (W, W), 0), a, mask))
top = Image.new("RGBA", (W, W), (0, 0, 0, 0))
td = ImageDraw.Draw(top)
td.ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, 30))
# rim highlight on the upper-left of the top face
hl = Image.new("L", (W, W), 0)
ImageDraw.Draw(hl).ellipse([c - r, c - r, c + r, c + r], fill=255)
inner = Image.new("L", (W, W), 0)
ImageDraw.Draw(inner).ellipse([c - r + 10 * K, c - r + 12 * K, c + r + 4 * K, c + r + 6 * K], fill=255)
ring = Image.composite(Image.new("L", (W, W), 0), hl, inner)
white = Image.new("L", (W, W), 255)
top.alpha_composite(Image.merge("RGBA", (white, white, white, ring.point(lambda v: v * 150 // 255))).filter(ImageFilter.GaussianBlur(2 * K)))
img.alpha_composite(top)
img.resize((N, N), Image.LANCZOS).save(sys.argv[1])
