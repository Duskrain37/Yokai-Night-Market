from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
path=root/'data/actor_frames.json'
catalog=json.loads(path.read_text(encoding='utf-8'))
actors=[]
spec={
    'flare':['rise','burst','stun'],
    'bloom':['tally','cast'],
    'toad':['coin','burst','pact'],
    'wind-warden':['warning','impact'],
    'mask-master':['warning','impact'],
    'market-lamplord':['warning','impact'],
}
for key,clips in spec.items():
    actor='v070-fx-'+key
    file='assets/sprites/animation/'+actor+'.png'
    im=Image.open(root/file).convert('RGBA')
    assert im.getchannel('A').getextrema()[0]==0
    w,h=im.width/4,im.height/len(clips)
    catalog[actor]={'file':file,'body_px':h*.80,'facing':'right','clips':{
        clip:[{'rect':[round(c*w),round(r*h),round((c+1)*w)-round(c*w),round((r+1)*h)-round(r*h)],'anchor':[round(w*.5),round(h*.90)]} for c in range(4)] for r,clip in enumerate(clips)}}
    actors.append(actor)
path.write_text(json.dumps(catalog,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
print('Registered',len(actors),'VFX atlases')
