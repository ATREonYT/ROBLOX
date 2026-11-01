#!/bin/sh
# Downloads every texture in texture-manifest.json (free CC0 from Poly Haven and ambientCG)
# into ./downloaded/<VariantName>/ as ColorMap.png, NormalMap.png, RoughnessMap.png, MetalnessMap.png.
# Run on the Mac:  sh download_textures.sh      (needs only curl, unzip and python3, all built into macOS)
set -e
cd "$(dirname "$0")"
python3 - <<'PY'
import json, os, subprocess, zipfile, glob, shutil
m = json.load(open("texture-manifest.json"))
ok = miss = 0
for t in m:
    d = os.path.join("downloaded", t["name"]); os.makedirs(d, exist_ok=True)
    if t["source"] == "Poly Haven":
        for k, url in t["maps"].items():
            f = os.path.join(d, k + ".png")
            if os.path.exists(f) and os.path.getsize(f) > 1000: ok += 1; continue
            r = subprocess.run(["curl", "-sfL", "-o", f, url])
            if r.returncode == 0: ok += 1
            else:
                miss += 1
                if os.path.exists(f): os.remove(f)
                print("  missing", t["name"], k, "(fine for MetalnessMap)")
    else:
        z = os.path.join(d, "src.zip")
        if not os.path.exists(z):
            subprocess.run(["curl", "-sfL", "-o", z, t["zip1k"]], check=False)
        try:
            with zipfile.ZipFile(z) as zf: zf.extractall(d)
        except Exception as e:
            print("  could not unzip", t["name"], e); miss += 1; continue
        pick = {"ColorMap": "_Color", "NormalMap": "_NormalGL", "RoughnessMap": "_Roughness", "MetalnessMap": "_Metalness", "Opacity": "_Opacity"}
        for k, suf in pick.items():
            hits = glob.glob(os.path.join(d, "*" + suf + ".png"))
            if hits: shutil.copy(hits[0], os.path.join(d, k + ".png")); ok += 1
    print("done", t["name"])
print("maps downloaded:", ok, " missing:", miss)
PY
