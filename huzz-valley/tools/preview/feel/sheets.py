import subprocess,io,sys,numpy as np
from PIL import Image,ImageDraw,ImageFont
U='/mnt/project-files/uploads/hearth/'
HV=U+'f1c7bb86-f9d7-4f99-8569-0d2e6e4db131'; OG=U+'d5670b97-ca8f-4243-962f-d6ae3b0a782e'; OU=U+'766d03b6-65ba-4423-b6e9-d86ee79223c6'
OUT=sys.argv[1]
FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
FS=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)
def grab(src,t):
    p=subprocess.run(['ffmpeg','-v','error','-ss',str(t),'-i',src,'-frames:v','1','-f','image2pipe','-vcodec','png','-'],capture_output=True).stdout
    return Image.open(io.BytesIO(p)).convert('RGB')
VP=(385,243,2585,1747) # our Studio viewport
def frame(src,t):  # game view only
    im=grab(src,t); return im.crop(VP) if src==OU else im
def crop_frac(im,box): w,h=im.size; return im.crop((int(box[0]*w),int(box[1]*h),int(box[2]*w),int(box[3]*h)))
def label(im,txt,sub=None,col=(255,255,255)):
    d=ImageDraw.Draw(im); d.rectangle((0,0,im.width,30 if not sub else 52),fill=(0,0,0))
    d.text((6,3),txt,font=FB,fill=col)
    if sub: d.text((6,30),sub,font=FS,fill=(220,220,220))
    return im
def sheet(rows,w,gap=6,bg=(20,20,24)):
    H=sum(r.height for r in rows)+gap*(len(rows)-1); c=Image.new('RGB',(w,H),bg); y=0
    for r in rows: c.paste(r,(0,y)); y+=r.height+gap
    return c
def strip(src,t0,dt,n,box,tw,lab=True):
    tiles=[]
    for i in range(n):
        t=t0+i*dt; im=crop_frac(frame(src,t),box); im=im.resize((tw,int(tw*im.height/im.width)))
        if lab: ImageDraw.Draw(im).text((3,1),'%.2f'%t,font=FS,fill=(255,255,0),stroke_width=2,stroke_fill=(0,0,0))
        tiles.append(im)
    c=Image.new('RGB',(tw*n+2*(n-1),tiles[0].height),(20,20,24))
    for i,tl in enumerate(tiles): c.paste(tl,(i*(tw+2),0))
    return c
def head(txt,w,sub=None):
    im=Image.new('RGB',(w,34 if not sub else 56),(0,0,0)); return label(im,txt,sub)
which=sys.argv[2]
W=1600
if which=='colour':
    st=sys.argv[3:]
    items=[(HV,40,'Huss Valley (round)',st[0]),(OG,1,'Other game (lobby)',st[1]),(OU,5,'Ours (lobby, Studio)',st[2]),(OU,18.5,'Ours (round, Studio)',st[3])]
    tiles=[]
    for src,t,name,s in items:
        im=frame(src,t); im=im.resize((795,int(795*im.height/im.width)))
        if im.height>500: im=im.crop((0,(im.height-500)//2,795,(im.height-500)//2+500))
        tiles.append(label(im,name,s))
    c=Image.new('RGB',(W,1006),(20,20,24))
    for i,tl in enumerate(tiles): c.paste(tl,((i%2)*805,(i//2)*506))
    c.save(OUT,quality=80)
if which=='run':
    a=strip(HV,33.0,1/30,12,(0.33,0.40,0.60,0.82),132)
    b=strip(OU,3.4,1/30,12,(0.36,0.30,0.64,0.80),132)
    c=sheet([head('Huss Valley run, 30 fps (one crop = 42% of screen height). Hunched, big arm swing, ~4.6 steps/s',W),a,
             head('Ours, lobby run in Studio, 30 fps, same crop share. Upright, small swing; camera higher and further',W),b],W)
    c.save(OUT,quality=80)
if which=='huss':
    a=strip(HV,36.70,1/30,12,(0.26,0.40,0.62,0.85),132)
    b=strip(HV,37.10,1/30,12,(0.26,0.40,0.62,0.85),132)
    c=sheet([head('Huss Valley huss (Space), 30 fps. 36.80 crouch + lean, white speed lines 36.83-37.13, upright 37.20, running 37.30',W),a,b],W)
    c.save(OUT,quality=80)
if which=='cuts':
    a=strip(HV,11.40,0.05,12,(0,0.1,1,0.9),132)
    b=strip(OU,15.95,0.05,12,(0,0.1,1,0.9),132)
    d=strip(OU,20.15,0.05,12,(0,0.1,1,0.9),132)
    c=sheet([head('Huss Valley: lineup to front shot, one 0.2 s swing with motion blur, then a held shot (20 fps)',W),a,
             head('Ours 15.95-16.5 s: after the old cutscene the camera flies back in 0.3 s, through a wall and the sky',W),b,
             head('Ours 20.15-20.7 s: 0.6 s whip that flies through the player at ground level',W),d],W)
    c.save(OUT,quality=80)
if which=='ui':
    # same screen-height scale: 1000 px = full screen height
    hv=grab(HV,40); s=1000/hv.height; hvt=hv.crop((800,0,2220,250)).resize((int(1420*s),int(250*s)))
    ou=frame(OU,18); s2=1000/ou.height; out=ou.crop((540,100,1660,400)).resize((int(1120*s2),int(300*s2)))
    o2=frame(OU,18); ov=o2.crop((850,700,1450,1050)); ov=ov.resize((int(600*s2*1.4),int(350*s2*1.4)))
    o3=frame(OU,23.5); ov3=o3.crop((500,120,1700,700)); ov3=ov3.resize((int(1200*s2*0.6),int(580*s2*0.6)))
    hvtag=hv.crop((1000,700,1600,1000)).resize((int(600*s*1.4),int(300*s*1.4)))
    row1=Image.new('RGB',(W,max(hvt.height,out.height)),(20,20,24)); row1.paste(hvt,(0,0)); row1.paste(out,(hvt.width+20,0))
    row2=Image.new('RGB',(W,max(ov.height,ov3.height,hvtag.height)),(20,20,24)); row2.paste(hvtag,(0,0)); row2.paste(ov,(hvtag.width+15,0)); row2.paste(ov3,(hvtag.width+ov.width+30,0))
    c=sheet([head('Top of screen at the same scale. Left: Huss Valley (text only, 3.7% tall, coloured). Right: ours (panels, 1.7% white line)',W),row1,
             head('Tags. Left: HV. Middle: ours 18 s, banner printed on your own tag. Right: ours 23.5 s, tag 6% tall hits the top line',W),row2],W)
    c.save(OUT,quality=80)
if which=='ability':
    ts=[4.30,4.50,4.62,4.65,4.70,4.80,4.95,5.10,5.25]
    tiles=[]
    for t in ts:
        im=crop_frac(frame(OG,t),(0.08,0.28,0.52,0.66)); im=im.resize((176,int(176*im.height/im.width)))
        ImageDraw.Draw(im).text((3,1),'%.2f'%t,font=FS,fill=(255,255,0),stroke_width=2,stroke_fill=(0,0,0)); tiles.append(im)
    r=Image.new('RGB',(W,tiles[0].height),(20,20,24))
    for i,tl in enumerate(tiles): r.paste(tl,(i*178,0))
    full=frame(OG,4.8).resize((W//2,int(W//2*1882/3020)))
    c=sheet([head('Other game, Soul Reaper demo: wind-up 0.25 s (glow builds), 1-frame white flash, 0.35 s crescent slash, 0.15 s fade',W),r,full],W)
    c.save(OUT,quality=80)
