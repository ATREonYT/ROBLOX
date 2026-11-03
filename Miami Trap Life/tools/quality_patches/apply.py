import json,sys
spec=json.load(open(sys.argv[1]))
for f in spec:
    p=f["path"]; s=open(p).read()
    for e in f["edits"]:
        n=s.count(e["old"])
        if n!=1: sys.exit("FAIL %s count=%d for %r"%(p,n,e["old"][:60]))
        s=s.replace(e["old"],e["new"])
    open(p,"w").write(s); print("ok",p)
