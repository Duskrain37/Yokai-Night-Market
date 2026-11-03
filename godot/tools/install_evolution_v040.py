"""Install original generated PNGs; inspect alpha to describe AtlasTexture regions.
No bitmap pixels are edited. Diagnostic contact sheets are QA-only composites.
"""
from pathlib import Path
import json,shutil,hashlib,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
TASK=ROOT/'qa/evolution-preview'

def cut(projection,center,radius):
 lo,hi=int(center-radius),int(center+radius)
 runs=[];start=None
 for i in range(lo,hi):
  if projection[i]==0 and start is None:start=i
  if projection[i]>0 and start is not None:runs.append((start,i));start=None
 if start is not None:runs.append((start,hi))
 assert runs,('No transparent gutter',center)
 a,b=max(runs,key=lambda x:x[1]-x[0]);assert b-a>=3
 return (a+b)//2

def main():
 destination=ROOT/'assets/sprites/evolution/v040';destination.mkdir(parents=True,exist_ok=True)
 jobs=Path(sys.argv[1]) if len(sys.argv)>1 else destination/'generation_prompts.json'
 data=json.loads(jobs.read_text(encoding='utf-8'))
 TASK.mkdir(parents=True,exist_ok=True)
 result={}
 for row in data['records']:
  target=destination/(row['id']+'-capstones.png')
  source=Path(row.get('source',str(ROOT/row.get('file',''))))
  if source.resolve()!=target.resolve():shutil.copy2(source,target)
  row['file']=target.relative_to(ROOT).as_posix();row.pop('source',None)
  im=Image.open(target);assert im.mode=='RGBA'
  a=np.asarray(im)[:,:,3];h,w=a.shape
  borders=[0,cut((a>32).sum(0),w/3,w*.075),cut((a>32).sum(0),2*w/3,w*.075),w]
  frames=[]
  for index in range(3):
   left,right=borders[index:index+2]
   yy,xx=np.where(a[:,left:right]>32)
   x1=max(left,left+int(xx.min())-4);x2=min(right,left+int(xx.max())+5)
   y1=max(0,int(yy.min())-4);y2=min(h,int(yy.max())+5)
   frames.append({'path':index+1,'region':[x1,y1,x2-x1,y2-y1]})
  result[row['id']]={'file':target.relative_to(ROOT).as_posix(),'size':[w,h],'frames':frames,
   'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
 (ROOT/'data/evolution_art_v040.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 (destination/'generation_prompts.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 font=ImageFont.truetype(str(ROOT/'assets/fonts/LXGWWenKai-Regular.ttf'),18)
 ids=list(result)
 for page,group in enumerate([ids[:6],ids[6:]]):
  im=Image.new('RGB',(1000,len(group)*180+36),'#1c3039');d=ImageDraw.Draw(im)
  for i,t in enumerate(group):
   sheet=Image.open(ROOT/result[t]['file'])
   for j,f in enumerate(result[t]['frames']):
    x,y,w,h=f['region'];a=sheet.crop((x,y,x+w,y+h));a.thumbnail((270,145))
    im.paste(a,(j*330+40,i*180+10),a)
    d.text((j*330+40,i*180+155),t+' / '+str(j+1),font=font,fill='#e3cfac')
  im.save(TASK/f'evolution-final-{page}.png')
 print('Installed 13 original atlases, 39 measured capstone regions.')

if __name__=='__main__':main()
