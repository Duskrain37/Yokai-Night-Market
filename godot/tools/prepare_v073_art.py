"""Bake the v0.7.3 authored art to exact reusable board layers and actor poses."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from bake_motion_frames import as_image, motion_pair

root = Path(__file__).resolve().parents[1]
source = root.parent / 'tmp/v073/art-input'
props = root / 'assets/scenery/shore'
props.mkdir(parents=True, exist_ok=True)
L = Image.Resampling.LANCZOS

def isolate(im, box):
    im = im.crop(box).convert('RGBA')
    pix = np.array(im)
    rgb = pix[:,:,:3].astype(int)
    # Remove high-chroma fringe outside the muted gouache palette.
    fringe = (rgb[:,:,0] > 180) & (rgb[:,:,0] > rgb[:,:,1]*2.5) & (rgb[:,:,2]<30)
    pix[fringe,3] = 0
    im = Image.fromarray(pix)
    bbox = im.getchannel('A').point(lambda v: 255 if v >= 80 else 0).getbbox()
    assert bbox is not None
    x,y,r,b = bbox
    return im.crop((max(0,x-2),max(0,y-2),min(r+2,im.width),min(b+2,im.height)))

def board():
    anchor = Image.open(root/'assets/bg/map-day4.png').convert('RGB')
    low = Image.open(source/'island-low.png').convert('RGB').resize(anchor.size,L)
    high = Image.open(source/'island-high.png').convert('RGB').resize(anchor.size,L)
    bounds = (1168,144,1672,810)
    a, l, h = [np.asarray(i.crop(bounds).resize((336,444),L),dtype=np.float32)/255 for i in (anchor,low,high)]
    w, height = 336,444
    xx, yy = np.meshgrid(np.linspace(0,1,w),np.linspace(0,1,height))
    # Planting surface and the two full-width middle lanes keep their original pixels.
    fade_x = np.clip(xx/.085,0,1)
    fade_y = np.clip(yy/.06,0,1)*np.clip((1-yy)/.065,0,1)
    bay = np.maximum(np.clip((.335-yy)/.06,0,1),np.clip((yy-.64)/.08,0,1))
    strength = (fade_x * fade_y * bay)[:,:,None]
    # Draw a progressive foam line chased inland by the surge; the shore is not crossfaded all at once.
    axis = np.clip(1-xx - .055*np.sin(yy*22),0,1)
    atlas = Image.new('RGBA',(w*8,height*4))
    for i in range(32):
        progress = i/31
        edge = np.clip((progress * 1.27-.12-axis)/.15,0,1)
        edge = edge*edge*(3-2*edge)
        flow = np.exp(-((progress*1.24-.12-axis)/.035)**2)*np.sin(np.pi*progress)**.7
        mix = l*(1-edge[:,:,None])+h*edge[:,:,None]
        mix = np.minimum(1,mix+flow[:,:,None]*np.array([.12,.17,.19]))
        rgba = np.uint8(np.dstack((mix,strength[:,:,0]))*255+.5)
        atlas.paste(Image.fromarray(rgba),((i%8)*w,(i//8)*height))
    atlas.save(props/'tide.webp','WEBP',quality=84,alpha_quality=100,method=5)

def things():
    sheet = Image.open(source/'props.png')
    names = ['incense-boat','freight-boat','cargo','dock','mat','gate','bridge','buoy']
    for i, name in enumerate(names):
        col,row = i%4,i//4
        crop = isolate(sheet,(col*sheet.width//4,row*sheet.height//2,(col+1)*sheet.width//4,(row+1)*sheet.height//2))
        crop.thumbnail((350,310),L)
        crop.save(props/(name+'.webp'),'WEBP',quality=91,alpha_quality=100,method=5)
    gate = Image.open(source/'gate-parts.png')
    for i,name in enumerate(['gate','gate-panel']):
        img = isolate(gate,(i*gate.width//2,0,(i+1)*gate.width//2,gate.height))
        img.thumbnail((320,310),L)
        img.save(props/(name+'.webp'),'WEBP',quality=92,alpha_quality=100,method=5)


def guests():
    walk=Image.open(source/'guests.png')
    attack=Image.open(source/'guests-action.png')
    names = ['freight-yokel','river-fisher','reef-haunter','timber-bearer']
    frames_path = root/'data/actor_frames.json'
    frames = json.loads(frames_path.read_text(encoding='utf-8'))
    sprites = root/'assets/sprites'
    cuts = [
        [[0,409,891,1341,1774],[0,398,885,1346,1774]],
        [[0,418,892,1349,1774],[0,395,890,1348,1774]],
    ]
    split = [444,469]
    def between(a,b):
        x,y = np.meshgrid(np.arange(a.width,dtype=np.float32), np.arange(a.height,dtype=np.float32))
        def rgba(img):
            v=np.asarray(img,dtype=np.float32)/255
            v[:,:,:3]*=v[:,:,3:]
            return v
        return as_image(motion_pair(rgba(a),rgba(b),x,y)(.5))
    for i,name in enumerate(names):
        keys=[]
        for sheet_no, sheet in enumerate([walk,attack]):
            yy=[0,split[sheet_no],sheet.height]
            for row in range(2):
                xs=cuts[sheet_no][row]
                keys.append(isolate(sheet,(xs[i],yy[row],xs[i+1],yy[row+1])))
        portrait=keys[0].copy();portrait.thumbnail((300,300),L)
        portrait.save(sprites/(name+'.png'),optimize=True)
        cell=240; anchor=(120,211); body=165
        def place(img):
            image=Image.new('RGBA',(cell,cell)); img=img.copy(); img.thumbnail((220,body),L)
            image.paste(img,(anchor[0]-img.width//2,anchor[1]-img.height));return image
        aligned=[place(k) for k in keys]
        aligned.extend([between(aligned[0],aligned[1]),between(aligned[2],aligned[3])])
        # Water silhouettes keep shoulders, back and forearms above the waterline.
        for i_key in [0,1,2,3,4,5]:
            pose=aligned[i_key]
            pix=np.array(pose)
            for y in range(133,cell): pix[y,:,3]=np.uint8(pix[y,:,3]*max(0,(152-y)/19))
            swim=Image.fromarray(pix).crop((0,0,cell,153))
            image=Image.new('RGBA',(cell,cell));image.paste(swim,(0,58))
            aligned.append(image)
        atlas=Image.new('RGBA',(cell*len(aligned),cell))
        poses=[]
        for n,img in enumerate(aligned):
            atlas.paste(img,(n*cell,0))
            poses.append({'rect':[n*cell,0,cell,cell],'anchor':list(anchor)})
        file=sprites/'animation'/('v073-'+name+'-poses.png')
        atlas.save(file,optimize=True)
        clips={'walk':[0,4,1,4],'attack':[0,2,3,5], 'swim':[6,10,7,10],'swim_bite':[6,8,9,11]}
        frames[name]={'file':file.relative_to(root).as_posix(),'body_px':body,'facing':'left','clips':{k:[poses[n] for n in v] for k,v in clips.items()}}
    frames_path.write_text(json.dumps(frames,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

if __name__=='__main__':
    things(); board(); guests()
