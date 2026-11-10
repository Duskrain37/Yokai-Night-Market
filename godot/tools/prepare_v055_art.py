from pathlib import Path
import json,shutil
from PIL import Image
G=Path(__file__).resolve().parents[1];R=G.parent;rows=json.loads((G/'data/v055_generation_prompts.json').read_text(encoding='utf-8'))
dest=G/'assets/sprites';original=G/'build-art/v055';original.mkdir(parents=True,exist_ok=True)
names={}
for x in rows:
 key=x['key'];source=Path(x['path']);shutil.copy2(source,original/(key+'.png'))
 if key=='fx':continue
 name=('year-banyan' if key.startswith('tree') else 'sky-mortar')+('' if key.endswith('base') else '-'+key.split('_')[1])
 im=Image.open(source).convert('RGBA');assert im.getchannel('A').getextrema()[0]==0
 box=im.getchannel('A').getbbox();im=im.crop(box);im.thumbnail((620,540),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(im.width+12,im.height+12));canvas.paste(im,(6,6));canvas.save(dest/(name+'.png'),optimize=True);names[name]={'source':source.as_posix(),'prompt':x['prompt'],'size':canvas.size}
fx=Image.open(next(x['path'] for x in rows if x['key']=='fx')).convert('RGBA')
sheet=Image.new('RGBA',(896,896));clips={}
for row,clip in enumerate(['seed','shell','soul','blast']):
 frames=[]
 for col in range(4):
  box=(round(col*fx.width/4),round(row*fx.height/4),round((col+1)*fx.width/4),round((row+1)*fx.height/4));patch=fx.crop(box);patch.thumbnail((206,206),Image.Resampling.LANCZOS)
  left=col*224+(224-patch.width)//2;top=row*224+(224-patch.height)//2
  sheet.paste(patch,(left,top));frames.append({'rect':[col*224,row*224,224,224],'anchor':[112,112]})
 clips[clip]=frames
file=dest/'animation/v055-projectiles.png';sheet.save(file,optimize=True)
catpath=G/'data/actor_frames.json';cat=json.loads(catpath.read_text(encoding='utf-8'));cat['v055-projectiles']={'file':file.relative_to(G).as_posix(),'body_px':180,'facing':'right','clips':clips};catpath.write_text(json.dumps(cat,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
(G/'data/v055_art_sources.json').write_text(json.dumps({'tool':'built-in image_gen','portraits':names,'projectiles':rows[-1]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('8 portraits and4 VFX clips installed')
