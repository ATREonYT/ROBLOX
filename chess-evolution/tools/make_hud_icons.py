#!/usr/bin/env python3
"""Draws the +1 Chess Evolution HUD icons as SVG, then renders 512 px PNGs with headless Chrome.
   python3 tools/make_hud_icons.py   (run from chess-evolution/). Original art, chess themed.
   Style: thick navy ink, crisp two-tone facets, white specular streak, top-left light."""
import os, subprocess, tempfile
INK = "#1c2440"
OUT = os.path.join("assets", "hud-icons")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def grad(i, a, b, x2=0, y2=1):
    return f'<linearGradient id="{i}" x1="0" y1="0" x2="{x2}" y2="{y2}"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'

def s(d, fill, w=20, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'

def p(d, fill, op=1):
    return f'<path d="{d}" fill="{fill}" opacity="{op}"/>'

def streak(d, w=14):
    return f'<path d="{d}" fill="none" stroke="#fff" stroke-width="{w}" stroke-linecap="round" opacity=".92"/>'

PAWN = "M256 96a62 62 0 0 1 44 106h18a18 18 0 0 1 0 36h-24c4 50 22 86 50 112h6a26 26 0 0 1 26 26v30a14 14 0 0 1-14 14H150a14 14 0 0 1-14-14v-30a26 26 0 0 1 26-26h6c28-26 46-62 50-112h-24a18 18 0 0 1 0-36h18a62 62 0 0 1 44-106z"
CROWN = "M92 372 66 170l104 76 86-136 86 136 104-76-26 202z"

def pawn(tf, a="#ffffff", b="#b9c6d8", w=20):
    return f'<g transform="{tf}">' + s(PAWN, "url(#pw)", w) + p("M256 110v304h108v-26c0-10-8-20-20-22h-10c-30-28-48-66-52-116h26a14 14 0 0 0 0-30h-22a58 58 0 0 0-30-110z", b, .85) + streak("M214 150c4-18 16-30 30-34", 12) + '</g>' + f'<defs>{grad("pw", a, "#e8eef6")}</defs>'

def crown_art(tf=""):
    return f'<g transform="{tf}">' + s(CROWN, "url(#cg)") + p("M256 110v262h164l26-202-104 76z", "#f09a12", .75) + s("M92 372h328v44a12 12 0 0 1-12 12H104a12 12 0 0 1-12-12z", "url(#cb)") \
        + f'<circle cx="256" cy="310" r="36" fill="#ff3b4e" stroke="{INK}" stroke-width="14"/><circle cx="244" cy="298" r="10" fill="#fff"/>' \
        + f'<circle cx="66" cy="160" r="26" fill="#ffe27a" stroke="{INK}" stroke-width="14"/><circle cx="446" cy="160" r="26" fill="#ffe27a" stroke="{INK}" stroke-width="14"/><circle cx="256" cy="96" r="28" fill="#ffe27a" stroke="{INK}" stroke-width="14"/>' \
        + streak("M112 214l14 110", 12) + '</g>' + f'<defs>{grad("cg", "#ffe45c", "#ffb31a")}{grad("cb", "#ffcf3a", "#e8890c")}</defs>'

ICONS = {}
ICONS["trophy"] = f'<defs>{grad("g", "#ffe66a", "#ffae1a", 1, 1)}{grad("h", "#c98a3a", "#8a4f1c")}</defs>' \
    + s("M136 124H70c0 96 34 150 104 166M376 124h66c0 96-34 150-104 166", "none", 34) \
    + '<path d="M136 124H70c0 96 34 150 104 166M376 124h66c0 96-34 150-104 166" fill="none" stroke="#ffc933" stroke-width="16" stroke-linecap="round"/>' \
    + s("M122 74h268c8 124-30 216-98 240v46h-72v-46C152 290 114 198 122 74z", "url(#g)") \
    + p("M256 80h128c6 118-30 208-92 232v44h-36z", "#f09a12", .6) \
    + s("M162 372h188a18 18 0 0 1 18 18v42H144v-42a18 18 0 0 1 18-18z", "url(#h)") \
    + f'<ellipse cx="256" cy="86" rx="134" ry="24" fill="#a85a14" stroke="{INK}" stroke-width="18"/>' \
    + streak("M160 130c2 60 14 104 40 136")
ICONS["crown"] = crown_art()
ICONS["promote"] = pawn("translate(30,70) scale(.84)") + crown_art("translate(150,-8) scale(.56) rotate(10 256 256)") \
    + f'<defs>{grad("ar", "#ff5d6d", "#d3142c")}</defs>' + s("M60 330c-4-90 30-158 96-192l-20-34 104 14-44 96-18-30c-42 24-62 80-58 146z", "url(#ar)", 18)
ICONS["evolve"] = f'<defs>{grad("f", "#b08cff", "#2b7cff")}{grad("f2", "#9fe8ff", "#3f9bff")}</defs>' \
    + s("M256 24c26 80 118 100 142 214 22 110-54 226-142 226S92 348 114 238c8-44 30-64 46-96 10 30 24 40 40 46C194 124 218 66 256 24z", "url(#f)") \
    + p("M256 120c16 50 74 72 88 144 12 74-36 150-88 150s-100-76-88-150c6-30 18-46 30-64 8 16 18 24 28 28-2-40 12-76 30-108z", "url(#f2)", .9) \
    + pawn("translate(106,168) scale(.6)", w=26) \
    + '<path d="M410 70l12 34 34 12-34 12-12 34-12-34-34-12 34-12z" fill="#fff"/><path d="M90 96l8 24 24 8-24 8-8 24-8-24-24-8 24-8z" fill="#fff"/>'
ICONS["gift"] = f'<defs>{grad("r", "#ff5468", "#d3122c")}{grad("r2", "#ff7a88", "#ef2c44")}{grad("y", "#ffd84a", "#ff9c1a")}</defs>' \
    + s("M250 180C190 60 96 70 104 136c6 44 86 58 146 44zM262 180c60-120 154-110 146-44-6 44-86 58-146 44z", "url(#y)") \
    + s("M96 242h320v196a22 22 0 0 1-22 22H118a22 22 0 0 1-22-22z", "url(#r)") \
    + s("M74 176h364a14 14 0 0 1 14 14v52a14 14 0 0 1-14 14H74a14 14 0 0 1-14-14v-52a14 14 0 0 1 14-14z", "url(#r2)") \
    + s("M214 176h84v284h-84z", "url(#y)", 16) + streak("M92 200h90", 12)
ICONS["calendar"] = f'<defs>{grad("w", "#ffffff", "#d7dfea")}{grad("r", "#ff5a6c", "#d3142c")}</defs>' \
    + s("M82 110h348a26 26 0 0 1 26 26v290a26 26 0 0 1-26 26H82a26 26 0 0 1-26-26V136a26 26 0 0 1 26-26z", "url(#w)") \
    + s("M82 110h348a26 26 0 0 1 26 26v76H56v-76a26 26 0 0 1 26-26z", "url(#r)") \
    + s("M150 60v94M362 60v94", "none", 44) + '<path d="M150 60v94M362 60v94" stroke="#c9d3e0" stroke-width="20" stroke-linecap="round"/>' \
    + f'<text x="256" y="408" font-family="Arial Black,Arial" font-weight="900" font-size="186" text-anchor="middle" fill="{INK}">31</text>' + streak("M84 150h110", 12)
ICONS["power"] = f'<defs>{grad("r", "#ff5468", "#d6112b")}</defs>' \
    + s("M90 96h332c34 0 58 24 58 58v204c0 34-24 58-58 58H90c-34 0-58-24-58-58V154c0-34 24-58 58-58z", "url(#r)") \
    + p("M256 104h166c30 0 50 22 50 50v204c0 30-20 50-50 50H256z", "#a80c20", .35) \
    + pawn("translate(66,48) scale(.74)", w=22) + streak("M64 160c0-22 14-36 40-36h120", 12)
ICONS["wheel"] = '<defs>' + grad("st", "#ffffff", "#b9c6d8") + '</defs>' \
    + s("M176 446h160l-26-60H202z", "url(#st)") \
    + f'<circle cx="256" cy="212" r="176" fill="#fff" stroke="{INK}" stroke-width="22"/>' \
    + ''.join(f'<path d="M256 212L{x1} {y1}A170 170 0 0 1 {x2} {y2}z" fill="{c}"/>' for x1,y1,x2,y2,c in [(256,42,403,127,"#ff3b4e"),(403,127,403,297,"#ff9c1a"),(403,297,256,382,"#ffd83a"),(256,382,109,297,"#35d65a"),(109,297,109,127,"#2b8cff"),(109,127,256,42,"#b04cff")]) \
    + f'<circle cx="256" cy="212" r="172" fill="none" stroke="{INK}" stroke-width="16"/><circle cx="256" cy="212" r="34" fill="#fff" stroke="{INK}" stroke-width="14"/>' \
    + streak("M122 150c20-40 54-68 96-80", 14) + '<path d="M420 60l10 30 30 10-30 10-10 30-10-30-30-10 30-10z" fill="#fff"/>'
ICONS["gear"] = f'<defs>{grad("b", "#8fc6ff", "#2c7be5")}</defs>' \
    + '<g transform="translate(26,26) scale(.9)">' + s("M216 44h80l12 56 42 18 48-30 56 56-30 48 18 42 56 12v80l-56 12-18 42 30 48-56 56-48-30-42 18-12 56h-80l-12-56-42-18-48 30-56-56 30-48-18-42-56-12v-80l56-12 18-42-30-48 56-56 48 30 42-18z", "url(#b)") \
    + f'<circle cx="256" cy="256" r="70" fill="#123a78" stroke="{INK}" stroke-width="18"/>' + streak("M150 150c16-16 34-28 56-34", 12) + '</g>'
ICONS["smile"] = f'<defs>{grad("y", "#ffec6a", "#ffb81f")}</defs>' \
    + s("M120 60h272c34 0 60 26 60 60v272c0 34-26 60-60 60H120c-34 0-60-26-60-60V120c0-34 26-60 60-60z", "url(#y)") \
    + f'<ellipse cx="190" cy="210" rx="26" ry="42" fill="{INK}"/><ellipse cx="322" cy="210" rx="26" ry="42" fill="{INK}"/><path d="M150 310c50 76 162 76 212 0" fill="none" stroke="{INK}" stroke-width="26" stroke-linecap="round"/>' + streak("M92 150c0-30 16-52 46-58", 14)
ICONS["cursor"] = f'<defs>{grad("c", "#ffffff", "#c9d6e6", 1, 1)}</defs>' \
    + s("M112 52l300 186-120 34 76 136-74 42-74-136-92 88z", "url(#c)", 24) + p("M112 52l300 186-120 34z", "#ffffff", .9) + p("M128 402l-16-350 180 220 76 136-74 42-74-136z", "#a9b9cf", .55) + streak("M136 96l10 200", 12)
ICONS["lock"] = f'<defs>{grad("y", "#ffdc55", "#ffa41a")}{grad("g", "#e6ecf4", "#98a8bd")}</defs>' \
    + s("M150 230v-64a106 106 0 0 1 212 0v64", "none", 62) + '<path d="M150 230v-64a106 106 0 0 1 212 0v64" fill="none" stroke="url(#g)" stroke-width="28"/>' \
    + s("M112 214h288a30 30 0 0 1 30 30v176a30 30 0 0 1-30 30H112a30 30 0 0 1-30-30V244a30 30 0 0 1 30-30z", "url(#y)") \
    + f'<circle cx="256" cy="316" r="34" fill="{INK}"/><path d="M240 330h32l10 62h-52z" fill="{INK}"/>' + streak("M108 256v110", 12)
ICONS["check"] = f'<defs>{grad("g", "#8cff5a", "#16c43a")}</defs>' + s("M48 276l76-78 92 92L392 76l84 66-258 306z", "url(#g)", 22) + streak("M86 276l34-34", 12)
ICONS["arrow"] = f'<defs>{grad("w", "#ffffff", "#c6d5e6")}</defs>' + s("M48 186h216V86l200 170-200 170V326H48z", "url(#w)", 24)

os.makedirs(OUT, exist_ok=True)
with tempfile.TemporaryDirectory() as d:
    for name, body in ICONS.items():
        f = os.path.join(d, name + ".html")
        open(f, "w").write(f'<!doctype html><html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{body}</svg></body></html>')
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000", "--window-size=512,512", f"--screenshot={os.path.abspath(os.path.join(OUT, name + '.png'))}", "file://" + f], check=True, capture_output=True, timeout=60)
print("made", len(ICONS))
