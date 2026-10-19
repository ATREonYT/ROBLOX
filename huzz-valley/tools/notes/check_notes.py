#!/usr/bin/env python3
"""Notes check: the split of huzz-valley/CLAUDE.md into a lean core + docs/notes/*.md lost nothing.

Why (owner, Oct 19: "this is also very important towards creating a good CLAUDE.md file. I want good results"):
the old notebook was 101 KB and every session read it. It became a core (CLAUDE.md) plus topic files. This script:
  1. takes the old file from git (default: commit 9d46d7b, the last one before the split),
  2. pulls out every `backticked` token and every "quoted" phrase,
  3. checks each one appears in the core or a topic file (whitespace and line wraps ignored),
  4. checks the core's index links resolve and every repo path the notes name exists.
DROPPED lists the few tokens left out on purpose, each with its reason.

Run from the repo root or anywhere:  python3 huzz-valley/tools/notes/check_notes.py [old-rev]
"""
import os, re, subprocess, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
REPO = os.path.dirname(GAME)
OLD_REV = sys.argv[1] if len(sys.argv) > 1 else "9d46d7b"

# Tokens left out on purpose (token -> why). Keep this short.
DROPPED = {
}
# Paths the notes name that only exist once the owner sends a file (path -> why).
NOT_YET = {
    "assets/props/": "made when the owner sends HuzzLobbyProps.rbxm",
    "HuzzLobbyProps.rbxm": "the owner's Studio export, not sent yet",
    "Fx/BeamGlow": "an effect picture name inside Config/ImageIds, filled once the owner uploads",
}

def norm(s):
    return re.sub(r"\s+", " ", s).strip()

old = subprocess.run(["git", "-C", REPO, "show", f"{OLD_REV}:huzz-valley/CLAUDE.md"],
                     capture_output=True, text=True, check=True).stdout
files = [os.path.join(GAME, "CLAUDE.md")] + sorted(glob.glob(os.path.join(GAME, "docs", "notes", "*.md")))
new = norm("\n".join(open(f, encoding="utf-8").read() for f in files))

flat = norm(old)
ticks = re.findall(r"`([^`]+)`", flat)
no_ticks = re.sub(r"`[^`]*`", " ", flat)
quotes = [q for q in re.findall(r"\"([^\"]*)\"", no_ticks) if len(q.strip()) > 1]

misses = []
for kind, items in (("tick", ticks), ("quote", quotes)):
    for t in dict.fromkeys(items):
        t = norm(t)
        if t in DROPPED:
            continue
        if t not in new:
            misses.append((kind, t))

print(f"old: {len(set(ticks))} backticked tokens, {len(set(quotes))} quoted phrases")
print(f"new: {len(files)} files, {sum(os.path.getsize(f) for f in files)} bytes")
for kind, t in misses:
    print(f"MISS {kind}: {t}")
print(f"misses: {len(misses)}")
for t, why in DROPPED.items():
    print(f"dropped on purpose: {t!r} ({why})")

# Index links in the core resolve.
core = open(files[0], encoding="utf-8").read()
bad_links = [l for l in re.findall(r"\]\(([^)#\s]+)", core) if not l.startswith("http")
             and not os.path.exists(os.path.join(GAME, l))]
for l in bad_links:
    print(f"BAD LINK: {l}")
# Links between topic files resolve too.
for f in files[1:]:
    for l in re.findall(r"\]\(([^)#\s]+)", open(f, encoding="utf-8").read()):
        if not l.startswith("http") and not os.path.exists(os.path.join(os.path.dirname(f), l)):
            bad_links.append(l)
            print(f"BAD LINK in {os.path.basename(f)}: {l}")
print(f"bad links: {len(bad_links)}")

# Every repo path named in the notes exists (tracked, or generated on disk).
tracked = set(subprocess.run(["git", "-C", REPO, "ls-files"], capture_output=True, text=True).stdout.split())
tracked_dirs = {os.path.dirname(p) for p in tracked}
for p in list(tracked_dirs):
    while p:
        p = os.path.dirname(p)
        tracked_dirs.add(p)
EXT = re.compile(r"\.(luau|lua|py|mjs|js|sh|jpg|png|mp4|ogg|json|rbxm|rbxl|md|glb|txt)$")
everything = tracked | tracked_dirs
def exists(p):
    p = p.rstrip("/").rstrip(".,;:")
    tries = [p]
    while "." in os.path.basename(tries[-1]):  # Shared/LobbyLayout.floors -> Shared/LobbyLayout
        tries.append(tries[-1].rsplit(".", 1)[0])
    for base in tries:
        for cand in (base, base + ".luau", base + ".lua", base + ".server.lua", base + ".client.lua"):
            if cand in everything or os.path.exists(os.path.join(GAME, cand)):
                return True
            if any(t.endswith("/" + cand) for t in everything):
                return True
    return False
missing = set()
for f in files:
    text = open(f, encoding="utf-8").read()
    for tok in re.findall(r"`([^`\s]+)`", text):
        tok = tok.split(":")[0] if tok.startswith(("src/", "tools/", "docs/")) else tok
        looks_like_path = ("/" in tok and not tok.startswith(("http", "/root", "@", "."))
                           and not re.match(r"^X\.", tok)) or (EXT.search(tok) and not tok.startswith(".") and not tok.startswith("X."))
        if looks_like_path and not tok.startswith("http") and not any(c in tok for c in "*<{$|()=") and not tok.endswith(".spec"):
            if not exists(tok) and tok not in NOT_YET:
                missing.add((os.path.basename(f), tok))
    for tok in re.findall(r"`(tests/[A-Za-z]+\.spec)`", text):
        if not exists(tok):
            missing.add((os.path.basename(f), tok))
for f, tok in sorted(missing):
    print(f"NO SUCH PATH ({f}): {tok}")
print(f"missing paths: {len(missing)}")
sys.exit(1 if misses or bad_links or missing else 0)
