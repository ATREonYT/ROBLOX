import sys,subprocess,numpy as np
from PIL import Image
src,ss,dur,x,y,w,out=sys.argv[1:8]; x,y,w=int(x),int(y),int(w)
cmd=['ffmpeg','-v','error','-ss',ss,'-i',src,'-t',dur,'-vf',f'fps=60,crop={w}:8:{x}:{y},scale={w//2}:1','-f','rawvideo','-pix_fmt','rgb24','-']
raw=subprocess.run(cmd,capture_output=True).stdout
W=w//2; n=len(raw)//(W*3); a=np.frombuffer(raw,np.uint8)[:n*W*3].reshape(n,W,3)
im=Image.fromarray(a).resize((W,n*4),Image.NEAREST)
# tick marks every 0.5s (30 rows -> 120px)
arr=np.array(im); 
for k in range(0,n*4,120): arr[k:k+2,:12]=(255,255,0)
Image.fromarray(arr).save(out); print(n,'frames')
