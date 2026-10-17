# One side-by-side for the round HUD after the feel-study fixes: Huss Valley's top of screen (cut from
# docs/previews/feel-ui.jpg) next to ours, at the same scale (same screen height), and our 3-2-1 frame under it.
# Usage (from huzz-valley/): python3 tools/preview/feel_ui_after.py <round-hud-runner.png> <round-count.png> [out.jpg]
#   (both from shots.sh: round-hud-runner, round-count)
# Scale: in feel-ui.jpg Huss Valley's screen is ~890 px tall (its message caps are 33 px = the study's 3.7%). Our
# preview draws the HUD's 1280 x 720 layout (a 16:9 screen's height) at 1.2x, so our screen is 864 px: HV x 864/890.
# The preview draws Montserrat for Gotham: its capitals are ~12% taller than Gotham's at the same TextSize.
import sys
from PIL import Image, ImageDraw, ImageFont

HV_BOX = (0, 40, 754, 172)  # Huss Valley's top of screen in feel-ui.jpg
HV_SCREEN_H, OUR_SCREEN_H = 890, 864
LABEL, GAP, BG = 40, 16, (20, 20, 26)


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([700])
        return f
    except (OSError, AttributeError):
        return ImageFont.load_default()


def main():
    ours_msg, ours_count = Image.open(sys.argv[1]).convert('RGB'), Image.open(sys.argv[2]).convert('RGB')
    out = sys.argv[3] if len(sys.argv) > 3 else 'docs/previews/feel-ui-after.jpg'
    k = OUR_SCREEN_H / HV_SCREEN_H
    hv = Image.open('docs/previews/feel-ui.jpg').convert('RGB').crop(HV_BOX)
    hv = hv.resize((round(hv.width * k), round(hv.height * k)), Image.LANCZOS)
    w = hv.width
    cx = ours_msg.width // 2
    top_h = max(120, hv.height)  # 14% of our screen: round line, message, role line, help line
    msg = ours_msg.crop((cx - w // 2, 0, cx - w // 2 + w, top_h))
    count = ours_count.crop((cx - w // 2, 0, cx - w // 2 + w, 330))  # down to 38% of the screen: the "3" sits at 27%
    W = GAP + w + GAP + w + GAP
    H = LABEL + top_h + GAP + LABEL + count.height + GAP
    sheet = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(sheet)
    f = font(17)
    d.text((GAP, 10), 'Huss Valley: news text only, coloured, 3.7% tall', fill=(255, 255, 255), font=f)
    d.text((GAP * 2 + w, 10), 'Ours now (preview font draws ~12% bigger than Gotham)', fill=(255, 255, 255), font=f)
    sheet.paste(hv, (GAP, LABEL + (top_h - hv.height) // 2))
    sheet.paste(msg, (GAP * 2 + w, LABEL))
    y = LABEL + top_h + GAP
    d.text((GAP, y + 10), 'Ours: 3-2-1 at 27% from the top (HV has no 3-2-1 in its clip)', fill=(255, 255, 255), font=f)
    d.text((GAP * 2 + w, y + 10), 'Ours: the same frame, whole screen, small', fill=(255, 255, 255), font=f)
    sheet.paste(count, (GAP, y + LABEL))
    full = ours_count.resize((w, round(ours_count.height * w / ours_count.width)), Image.LANCZOS)
    sheet.paste(full.crop((0, 0, w, count.height)), (GAP * 2 + w, y + LABEL))
    sheet.save(out, quality=90)
    print('wrote', out, sheet.size)


if __name__ == '__main__':
    main()
