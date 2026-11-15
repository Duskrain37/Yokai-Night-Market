"""Register generated key poses, extract portrait cells and reuse the 32-frame rig.

No repainting or background removal: alpha and pixels come from builtin imagegen.
Only atlas regions/anchors, lossless portrait cropping and packing are performed.
"""
from pathlib import Path
from PIL import Image
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SPRITES=ROOT/'assets/sprites'
manifest_path=ROOT/'data/actor_frames.json'
catalog=json.loads(manifest_path.read_text(encoding='utf-8'))
added=[]

def info(file,columns,rows,row,clips,facing):
    image=Image.open(ROOT/file).convert('RGBA')
    assert image.getchannel('A').getextrema()[0]==0,(file,'missing transparency')
    w,h=image.width/columns,image.height/rows
    region=[0,round(row*h),round(w),round(h)]
    alpha=np.array(image.crop((0,round(row*h),round(w),round((row+1)*h))))[:,:,3]
    ys,xs=np.where(alpha>80)
    assert len(ys)>0
    height=int(ys.max()-ys.min()+1)
    # Keep the same cell anchor for a clip, including a slumped/vanishing pose.
    anchor=[round(w*.5),round(h*.965)]
    result={'file':file,'body_px':height,'facing':facing,'clips':{}}
    for clip,cells in clips.items():
        result['clips'][clip]=[{'rect':[round(c*w),round(r*h),round((c+1)*w)-round(c*w),round((r+1)*h)-round(r*h)],'anchor':anchor} for r,c in cells]
    return result

for actor in ['watch-bloom','vow-toad']:
    file=f'assets/sprites/animation/{actor}-forms.png'
    source=Image.open(ROOT/file).convert('RGBA')
    for row in range(4):
        name=actor if row==0 else f'{actor}-e{row}'
        catalog[name]=info(file,6,4,row,{'idle':[(row,c) for c in range(3)],'action':[(row,c) for c in range(3,6)]},'right')
        box=(0,round(row*source.height/4),round(source.width/6),round((row+1)*source.height/4))
        portrait=source.crop(box)
        bbox=portrait.getchannel('A').getbbox()
        portrait.crop(bbox).save(SPRITES/f'{name}.png',optimize=True)
        added.append(name)

actor='root-palanquin';file=f'assets/sprites/animation/{actor}.png'
catalog[actor]=info(file,4,4,0,{clip:[(r,c) for c in range(4)] for r,clip in enumerate(['idle','pickup','walk','land'])},'right')
source=Image.open(ROOT/file).convert('RGBA')
portrait=source.crop((0,0,round(source.width/4),round(source.height/4)))
portrait.crop(portrait.getchannel('A').getbbox()).save(SPRITES/f'{actor}.png',optimize=True)
added.append(actor)
for boss in ['wind-warden','mask-master','market-lamplord']:
    actor='boss-'+boss;file=f'assets/sprites/animation/{actor}.png'
    catalog[actor]=info(file,4,5,0,{clip:[(r,c) for c in range(4)] for r,clip in enumerate(['idle','small','major','blink','death'])},'left')
    added.append(actor)

manifest_path.write_text(json.dumps(catalog,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
(ROOT/'data/v070_motion_actors.json').write_text(json.dumps(added,indent=2)+'\n',encoding='utf-8')
print('Registered',len(added),'actors. Existing manifests preserved; bake only these actors:')
print(' '.join('--actor '+actor for actor in added))
