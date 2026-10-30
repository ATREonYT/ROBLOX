import sys,subprocess,numpy as np
src,ss,dur=sys.argv[1],sys.argv[2],sys.argv[3]; box=[float(v) for v in sys.argv[4].split(',')]; crop=sys.argv[5] if len(sys.argv)>5 else None
vf='fps=60,'+(f'crop={crop},' if crop else '')+'scale=1000:-2'
cmd=['ffmpeg','-v','error','-ss',ss,'-i',src,'-t',dur,'-vf',vf,'-f','rawvideo','-pix_fmt','gray','-']
p=subprocess.run(cmd,capture_output=True).stdout
# get H
W=1000; 
probe=subprocess.run(['ffmpeg','-v','error','-ss',ss,'-i',src,'-frames:v','1','-vf',vf,'-f','rawvideo','-pix_fmt','gray','-'],capture_output=True).stdout
H=len(probe)//W
n=len(p)//(W*H); a=np.frombuffer(p,np.uint8)[:n*W*H].reshape(n,H,W).astype(float)
x0,y0,x1,y1=int(box[0]*W),int(box[1]*H),int(box[2]*W),int(box[3]*H)
win=np.hanning(y1-y0)[:,None]*np.hanning(x1-x0)[None,:]
prev=None; res=[]
for i in range(n):
    f=a[i,y0:y1,x0:x1]; f=(f-f.mean())*win
    F=np.fft.fft2(f)
    if prev is not None:
        R=F*np.conj(prev); R/=np.abs(R)+1e-9; r=np.fft.ifft2(R).real
        dy,dx=np.unravel_index(r.argmax(),r.shape)
        if dy>r.shape[0]//2: dy-=r.shape[0]
        if dx>r.shape[1]//2: dx-=r.shape[1]
        res.append((i/60,dx,dy,r.max()))
    prev=F
res=np.array(res)
# skip duplicate frames (0,0)
for k in range(0,len(res),int(sys.argv[6]) if len(sys.argv)>6 else 3):
    seg=res[k:k+3]; mv=seg[(seg[:,1]!=0)|(seg[:,2]!=0)]
    m=mv[:,1:3].mean(0) if len(mv) else (0,0)
    print('%.2f dx=%6.1f dy=%6.1f px/frame(1000w) peak=%.2f'%(float(sys.argv[2])+res[k,0],m[0],m[1],seg[:,3].mean()))
