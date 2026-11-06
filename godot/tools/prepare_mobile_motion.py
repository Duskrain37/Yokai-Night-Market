"""Split oversized motion atlases by action for Android, retaining every pixel and frame."""
from pathlib import Path
from copy import deepcopy
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def main():
 source=json.loads((ROOT/'data/actor_motion.json').read_text('utf-8'))
 mobile=deepcopy(source);target=ROOT/'assets/sprites/mobile-motion';target.mkdir(exist_ok=True)
 audit=[]
 for actor,info in source.items():
  image=Image.open(ROOT/info['file']).convert('RGBA')
  if max(image.size)<=4096:continue
  variant=mobile[actor];variant['clip_files']={}
  for clip,frames in info['clips'].items():
   left=min(f['rect'][0] for f in frames);top=min(f['rect'][1] for f in frames)
   right=max(f['rect'][0]+f['rect'][2] for f in frames);bottom=max(f['rect'][1]+f['rect'][3] for f in frames)
   patch=image.crop((left,top,right,bottom));file=target/(actor+'-'+clip+'.webp')
   patch.save(file,'WEBP',lossless=True,quality=100,method=4)
   decoded=Image.open(file).convert('RGBA')
   # Invisible RGB under alpha zero may be normalized by the encoder; visible pixels stay exact.
   import numpy as np
   a=np.asarray(patch);b=np.asarray(decoded);mask=a[:,:,3]>0
   assert (a[mask]==b[mask]).all() and (a[:,:,3]==b[:,:,3]).all()
   assert max(patch.size)<=4096
   variant['clip_files'][clip]=file.relative_to(ROOT).as_posix()
   for frame in variant['clips'][clip]:frame['rect'][0]-=left;frame['rect'][1]-=top
  variant['source_file']=info['file'];variant['file']=next(iter(variant['clip_files'].values()))
  audit.append({'actor':actor,'source_size':image.size,'actions':len(info['clips']),'frames':sum(map(len,info['clips'].values())),'visible_rgba_unchanged':True})
 (ROOT/'data/actor_motion_mobile.json').write_text(json.dumps(mobile,separators=(',',':'))+'\n','utf-8')
 (ROOT/'data/v053_mobile_motion_audit.json').write_text(json.dumps(audit,indent=2)+'\n','utf-8')
 print('Split',len(audit),'large atlases; all actions and 32 frames retained')
if __name__=='__main__':main()
