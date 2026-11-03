import json,sys,os
root=sys.argv[1]; P=json.load(open(sys.argv[2]))
for f,a,b in P:
    p=os.path.join(root,f); s=open(p,encoding="utf-8").read()
    n=s.count(a)
    if n==1: s=s.replace(a,b); open(p,"w",encoding="utf-8").write(s); r="ok"
    elif n>1: r="MULTI"
    elif b.split("\n")[0] in s: r="already"
    else: r="NOT FOUND"
    print(r, f, repr(a[:50]))
