"""Find icons in the FOLK Icon Pack zip, and copy the chosen ones out to upload. Needs only Python.

py icons.py where                      where the pack is
py icons.py find cash gem              best matches for each word
py icons.py get <folder> "<path>" ...  copy these paths from `find` into a folder
py icons.py test                       check this script

Add --pack "<zip or folder>" if the pack is not in Downloads, Desktop or Documents.
"""
import fnmatch, os, struct, sys, tempfile, zipfile

IMAGE = (".png", ".jpg")


def locate(given=None):
    if given:
        return given
    found = []
    for place in ("Downloads", "Desktop", "Documents"):
        for d, dirs, files in os.walk(os.path.join(os.path.expanduser("~"), place)):
            for name in files + dirs:
                low = name.lower()
                if fnmatch.fnmatch(low, "*icon*pack*") and (low.endswith(".zip") or name in dirs):
                    found.append(os.path.join(d, name))
            if d.count(os.sep) - os.path.expanduser("~").count(os.sep) >= 3:
                dirs[:] = []
    return next((f for f in found if "folk" in os.path.basename(f).lower()), found[0] if found else None)


def listing(pack):
    if os.path.isdir(pack):
        return [os.path.relpath(os.path.join(d, f), pack).replace(os.sep, "/") for d, _, fs in os.walk(pack) for f in fs]
    with zipfile.ZipFile(pack) as z:
        return [n for n in z.namelist() if not n.endswith("/")]


def read(pack, path):
    if os.path.isdir(pack):
        return open(os.path.join(pack, path), "rb").read()
    with zipfile.ZipFile(pack) as z:
        return z.read(path)


def score(path, word):
    """Whole words beat parts of words; the styles that suit stud menus rank first; tiny files rank last."""
    low = path.lower()
    name = low.rsplit("/", 1)[-1]
    if not low.endswith(IMAGE) or word not in low:
        return None
    s = 0 if word in name else 40
    if name.startswith(word):
        s -= 20
    for rank, style in enumerate(("glossy", "bold", "sim", "outline", "256")):
        if style in name:
            s += rank
            break
    else:
        s += 8
    if low.startswith("keyboard keys/"):
        s += 30
    return s + len(name) / 100


def find(paths, word, n=8):
    hits = [(score(p, word), p) for p in paths]
    return [p for s, p in sorted((h for h in hits if h[0] is not None), key=lambda h: h[0])[:n]]


def size(data):
    return struct.unpack(">II", data[16:24]) if data[:8] == b"\x89PNG\r\n\x1a\n" else None


def get(pack, out, wanted):
    os.makedirs(out, exist_ok=True)
    known = set(listing(pack))
    saved = []
    for path in wanted:
        if path not in known:
            sys.exit(f"Not in the pack: {path}")
        dest = os.path.join(out, os.path.basename(path).replace(" ", "_"))   # spaces break the upload URL
        with open(dest, "wb") as f:
            f.write(read(pack, path))
        saved.append(dest)
    return saved


def test():
    buf = os.path.join(tempfile.mkdtemp(), "My Icon Pack.zip")
    with zipfile.ZipFile(buf, "w") as z:
        for n in ("Items/Gem_Flat_Regular.png", "Items/Gem_Glossy.png", "Items/Gem.svg", "Keyboard Keys/g.png", "Items/Regem_Glossy.png"):
            z.writestr(n, b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + struct.pack(">II", 256, 128))
    paths = listing(buf)
    top = find(paths, "gem")
    assert top[0] == "Items/Gem_Glossy.png", top
    assert "Items/Gem.svg" not in top, top
    assert locate(buf) == buf
    out = get(buf, os.path.join(os.path.dirname(buf), "out"), ["Items/Gem_Glossy.png"])
    assert size(open(out[0], "rb").read()) == (256, 128)
    print("icons.py ok")


def main(argv):
    pack = None
    if "--pack" in argv:
        i = argv.index("--pack")
        pack = argv[i + 1]
        del argv[i:i + 2]
    cmd = argv[0] if argv else ""
    if cmd == "test":
        return test()
    pack = locate(pack)
    if not pack or not os.path.exists(pack):
        sys.exit("No icon pack found. Put the zip in Downloads, Desktop or Documents, or pass --pack.")
    if cmd == "where":
        print(pack)
    elif cmd == "find" and argv[1:]:
        paths = listing(pack)
        for word in argv[1:]:
            print(f"# {word}")
            for p in find(paths, word.lower()):
                print(p)
    elif cmd == "get" and argv[2:]:
        print("\n".join(get(pack, argv[1], argv[2:])))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
