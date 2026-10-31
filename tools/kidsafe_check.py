#!/usr/bin/env python3
"""Kid-safe check for every game in the repo (vault note 14 §8, CLAUDE.md "Never" list).

Usage (repo root):  python3 tools/kidsafe_check.py [game-folder ...]
With no folders it checks every folder that has a src/ (LihFolk is reference, skipped).

What it can check from the code alone:
  FAIL  more than one ProcessReceipt in a game, or one in client code
  FAIL  a client script granting on PromptProductPurchaseFinished / PromptGamePassPurchaseFinished
  FAIL  fake-pressure text in UI strings: crossed-out prices (<s>), "only N left", "limited time",
        "ends in", "last chance", "hurry", "was R$"
  WARN  rbxassetid / product ids that look made up (123456, 1111111, 0123...)
  WARN  a flash/blink in a while/repeat loop that waits under a second
  INFO  a ledger of every asset id per game, so the owner can confirm each one is theirs

What it cannot check: the real odds shown on screen, a pity counter's behaviour, real purchase
prompts. Those stay on the owner's Studio checklist. Exit code 1 if any FAIL.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {"LihFolk", "node_modules", ".git", "AI Video Library", "research_notes", "reports", "UnitTest", "tests"}
# Pressure words only count in shop/purchase code: a real round timer ("Hurry! Run") or a vote
# countdown is honest gameplay, a countdown on a price is fake scarcity.
SHOP = re.compile(r"shop|store|offer|pack|price|robux|R\$|product|gamepass|purchase|buy|deal|bundle", re.I)
EXTS = (".lua", ".luau")

PRESSURE = [
    (re.compile(r"<s>", re.I), "crossed-out price (<s>)"),
    (re.compile(r"only\s+\d+\s+left", re.I), '"only N left"'),
    (re.compile(r"limited[\s-]+time", re.I), '"limited time"'),
    (re.compile(r"\bends\s+in\b", re.I), '"ends in" countdown'),
    (re.compile(r"last\s+chance", re.I), '"last chance"'),
    (re.compile(r"\bhurry\b", re.I), '"hurry"'),
    (re.compile(r"\bwas\s+R\$", re.I), '"was R$" price'),
]
STRING = re.compile(r'"([^"\\]|\\.)*"|\'([^\'\\]|\\.)*\'|`([^`\\]|\\.)*`')
ASSET = re.compile(r"rbxassetid://(\d+)")
FAKE_ID = re.compile(r"^(?:0\d*|1234567?8?9?0?|(\d)\1{4,}|987654\d*)$")
GRANT_CLIENT = re.compile(r"Prompt(?:Product|GamePass)PurchaseFinished")
FAST_LOOP = re.compile(r"task\.wait\(\s*(0?\.\d+)\s*\)")


def is_client(path):
    p = path.replace("\\", "/").lower()
    return (".client." in p or "/client/" in p or "starterplayer" in p or "startergui" in p
            or "/gameclient/" in p)


def games(args):
    if args:
        return [a.rstrip("/") for a in args]
    out = []
    for name in sorted(os.listdir(ROOT)):
        full = os.path.join(ROOT, name)
        if name in SKIP_DIRS or not os.path.isdir(full):
            continue
        if os.path.isdir(os.path.join(full, "src")):
            out.append(name)
    return out


def code_files(game):
    base = os.path.join(ROOT, game, "src")
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            if f.endswith(EXTS):
                yield os.path.join(dirpath, f)


def check(game):
    fails, warns, ids = [], [], {}
    receipts = []
    for path in code_files(game):
        rel = os.path.relpath(path, ROOT)
        client = is_client(path)
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
        except OSError:
            continue
        shop_file = bool(SHOP.search(os.path.basename(path)))
        in_block = False
        for i, line in enumerate(lines, 1):
            if in_block:
                if "]]" in line:
                    in_block = False
                continue
            if re.match(r"\s*--\[=*\[", line) and "]]" not in line:
                in_block = True
                continue
            code = line.split("--", 1)[0] if "--" in line and '"' not in line.split("--", 1)[0] else line
            if re.search(r"\.ProcessReceipt\s*=", code):
                receipts.append(f"{rel}:{i}")
                if client:
                    fails.append(f"{rel}:{i} ProcessReceipt in client code")
            if client and GRANT_CLIENT.search(code):
                window = "\n".join(lines[i - 1:i + 8])
                if re.search(r"(Grant|Give|Add|\+=|FireServer)", window):
                    fails.append(f"{rel}:{i} client reacts to a purchase-finished event with a grant or a server call; grants belong in ProcessReceipt")
            for m in STRING.finditer(line):
                s = m.group(0)
                for rx, label in PRESSURE:
                    if rx.search(s) and (shop_file or SHOP.search(line) or label.startswith("crossed")):
                        fails.append(f"{rel}:{i} {label} in {s[:60]}")
            for m in ASSET.finditer(line):
                aid = m.group(1)
                ids.setdefault(aid, f"{rel}:{i}")
                if FAKE_ID.match(aid):
                    warns.append(f"{rel}:{i} asset id {aid} looks made up")
            m = FAST_LOOP.search(code)
            if m and re.search(r"flash|blink|strobe", "\n".join(lines[max(0, i - 4):i + 4]), re.I) \
                    and re.search(r"\bwhile\b|\brepeat\b", "\n".join(lines[max(0, i - 6):i])):
                warns.append(f"{rel}:{i} a flash/blink loop waits {m.group(1)} s (rule: at most 1 flash per second)")
    if len(receipts) > 1:
        fails.append("more than one ProcessReceipt: " + ", ".join(receipts))
    return fails, warns, ids


def main():
    total_fail = 0
    for game in games(sys.argv[1:]):
        fails, warns, ids = check(game)
        status = "FAIL" if fails else ("WARN" if warns else "PASS")
        print(f"[kidsafe] {game}: {status} ({len(fails)} fail, {len(warns)} warn, {len(ids)} asset ids)")
        for f in fails:
            print(f"  FAIL {f}")
        for w in warns:
            print(f"  WARN {w}")
        if "--ids" in os.environ.get("KIDSAFE", ""):
            for aid, where in sorted(ids.items()):
                print(f"  ID   {aid}  first at {where}")
        total_fail += len(fails)
    print("[kidsafe] " + ("all clear" if total_fail == 0 else f"{total_fail} problem(s) to fix"))
    return 1 if total_fail else 0


if __name__ == "__main__":
    sys.exit(main())
