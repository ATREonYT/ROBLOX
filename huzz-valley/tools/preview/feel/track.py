import sys,subprocess,numpy as np
src,ss,dur,crop,thr=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4],float(sys.argv[5])
W,H=int(crop.split(':')[0])//4,int(crop.split(':')[1])//4
cmd=['ffmpeg','-v','error','-ss',ss,'-i',src,'-t',dur,'-vf',f'fps=60,crop={crop},scale={W}:{H}','-f','rawvideo','-pix_fmt','gray','-']
raw=subprocess.run(cmd,capture_output=True).stdout
n=len(raw)//(W*H); a=np.frombuffer(raw,np.uint8)[:n*W*H].reshape(n,H,W)
out=[]
for i,f in enumerate(a):
    m=f<thr
    ys,xs=np.nonzero(m)
    if len(xs)<30: out.append((i/60,np.nan,np.nan,np.nan,np.nan,0)); continue
    x0,x1=np.percentile(xs,[2,98]); y0,y1=np.percentile(ys,[2,98])
    out.append((i/60,xs.mean()/W,ys.mean()/H,(x1-x0)/W,(y1-y0)/H,len(xs)))
np.save(sys.argv[6],np.array(out))
o=np.array(out)
for r in o[::6]: print('%.2f cx=%.3f cy=%.3f w=%.3f h=%.3f n=%d'%tuple(r))
