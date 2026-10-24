import sys,glob,numpy as np
from PIL import Image
def stats(p,box):
    a=np.asarray(Image.open(p).convert('RGB')).astype(float)/255
    h,w,_=a.shape; x0,y0,x1,y1=box
    a=a[int(y0*h):int(y1*h),int(x0*w):int(x1*w)]
    mx=a.max(2); mn=a.min(2); S=np.where(mx>0,(mx-mn)/np.maximum(mx,1e-6),0)
    L=0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
    R,G,B=a[...,0],a[...,1],a[...,2]; rg=R-G; yb=0.5*(R+G)-B
    col=np.sqrt(rg.std()**2+yb.std()**2)+0.3*np.sqrt(rg.mean()**2+yb.mean()**2)
    return dict(sat=S.mean(),val=mx.mean(),luma=L.mean(),contrast=L.std(),colorful=col,clip=(mx>0.98).mean(),dark=(L<0.08).mean(),
      r=R.mean(),g=G.mean(),b=B.mean())
groups={'HV lineup':(['hv_5','hv_8'],(0.06,0.13,0.94,0.86)),
 'HV running':(['hv_%d'%t for t in (33,36,40,44,48,52,56)],(0.06,0.13,0.94,0.86)),
 'Other game':(['og_%s'%t for t in ('0.5','1','1.5','2.5','4','6')],(0.06,0.13,0.94,0.86)),
 'Ours lobby':(['our_%d'%t for t in (3,5,7)],(0.08,0.22,0.94,0.9)),
 'Ours round':(['our_%s'%t for t in ('17.5','18.5','19.5','21','22')],(0.08,0.22,0.94,0.9))}
d=sys.argv[1]
for g,(fs,box) in groups.items():
    ss=[stats(f'{d}/{f}.png',box) for f in fs]
    m={k:np.mean([s[k] for s in ss]) for k in ss[0]}
    print(f"{g:12s} "+" ".join(f"{k}={v:.3f}" for k,v in m.items()))
