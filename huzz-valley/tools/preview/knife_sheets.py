import subprocess, os
from PIL import Image, ImageDraw, ImageFont
V='/root/.claude/uploads/b94430ea-6886-5ca7-ae57-74bb7621594c/f1c7bb86-Screen_Recording_2026-10-16_compressed.mp4'
S='/tmp/claude-0/-home-user-ROBLOX/b94430ea-6886-5ca7-ae57-74bb7621594c/scratchpad/knife/fr'
OUT='/home/user/ROBLOX/huzz-valley/docs/previews'
os.makedirs(S,exist_ok=True)
F=ImageFont.load_default(size=22); FB=ImageFont.load_default(size=28)
def frame(t):
    p=f'{S}/{t:.3f}.png'
    if not os.path.exists(p):
        subprocess.run(['ffmpeg','-v','error','-y','-ss',f'{t:.3f}','-i',V,'-frames:v','1',p],check=True)
    return Image.open(p).convert('RGB')
def label(im,txt,sub=None):
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,im.width,34 if not sub else 60),fill=(0,0,0))
    d.text((8,4),txt,font=F,fill=(255,230,0))
    if sub: d.text((8,32),sub,font=F,fill=(255,255,255))
    return im
def sheet(cells,cols,cw,ch,title,name):
    rows=(len(cells)+cols-1)//cols
    c=Image.new('RGB',(cols*cw,rows*ch+44),(20,20,20))
    ImageDraw.Draw(c).text((10,8),title,font=FB,fill=(255,255,255))
    for i,(t,box,txt,sub) in enumerate(cells):
        im=frame(t).crop(box).resize((cw,ch),Image.LANCZOS)
        label(im,txt,sub); c.paste(im,((i%cols)*cw,44+(i//cols)*ch))
    c.save(f'{OUT}/{name}',quality=80,optimize=True)
    print(name,c.size,os.path.getsize(f'{OUT}/{name}')//1024,'KB')

# 1. where the knife sits
sheet([
 (5.0,(700,850,1700,1400),'5.0s lobby: knives across the LOWER back (Messi, far left, wears his upright)','~3 studs long, tilted ~12-20 deg, blade to their left'),
 (5.0,(1700,850,2900,1400),'5.0s skins: gold guards, gems, curved blades','same belt mount on every skin'),
 (33.0,(1150,880,1650,1480),'33.0s runner while running','plain steel default, fixed at belt, no sway'),
 (35.5,(1150,880,1650,1480),'35.5s same, other stride','grip on right hip, blade pokes out left'),
],2,760,440,'Huss Valley knives on the back (video f1c7bb86)','knife-study-back.jpg')

# 2. the slash
B=(1840,600,2280,940)
cells=[]
phase={43.200:'carry: knife low by right hip',43.267:'strike (arm sweeps out)',43.300:'HIT: victim fills solid red',43.333:'red fill 2nd frame',43.400:'follow-through: arm out to side',43.467:'hold, pink knife glow',43.533:'arm starts down',43.633:'back to carry',43.700:'victim tips over',43.767:'victim flat (0.47 s after hit)'}
for t,s in phase.items(): cells.append((t,B,f'{t:.2f}s',s))
sheet(cells,5,440,340,'HV catcher slash, 30 fps steps (Danilo catches sammy_x7814, video f1c7bb86)','knife-study-slash.jpg')

# 3. lunge chain + red flash
B2=(1660,560,2260,920)
ph={41.600:'lunge in, trail behind',41.667:'hit 1: solid red fill',41.733:'red fades to tint',41.800:'hit 2 (0.13 s later)',41.867:'long white-pink ribbon',41.933:'ribbon arcs up ~7 studs',42.067:'victim 1 flat (0.4 s)',42.133:'catcher dives low, lands'}
cells=[(t,B2 if t<41.9 else (1760,560,2360,920),f'{t:.2f}s',s) for t,s in ph.items()]
cells.append((44.333,(2150,620,2650,960),'44.33s grip close-up','blade along forearm, pink sparkles'))
sheet(cells,3,600,360,'HV lunge through two runners, red hit flash (video f1c7bb86)','knife-study-lunge.jpg')
