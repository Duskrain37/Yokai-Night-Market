"""Crop transparent production sheets and anchor guest animation key poses."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageOps
import numpy as np
from bake_motion_frames import motion_pair, as_image

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets/sprites"
FRAMES = ROOT / "data/actor_frames.json"
BASE = ["five-brew", "blank-orchid"]
GUESTS = ["mist-hat", "cloud-porter", "gong-imp", "curtain-effigy", "wick-pilgrim", "lantern-judge"]
ROWS = [
    ([0,345,715,1086], [[0,325,690,1120,1448],[0,305,660,1120,1448],[0,310,657,1120,1448]]),
    ([0,345,693,1086], [[0,320,675,1095,1448],[0,311,660,1100,1448],[0,305,644,1100,1448]]),
]
PIVOT = [[.50,.48,.53,.52],[.40,.44,.52,.55],[.50,.42,.53,.54],[.38,.32,.55,.42],[.50,.40,.53,.55],[.49,.54,.59,.57]]

def isolate(patch):
    alpha = patch.getchannel("A")
    assert alpha.getextrema()[0] == 0, "Opaque backdrop"
    rect = alpha.point(lambda value: 255 if value >= 76 else 0).getbbox()
    assert rect is not None
    return patch.crop((max(0,rect[0]-3),max(0,rect[1]-3),min(patch.width,rect[2]+3),min(patch.height,rect[3]+3)))

def portrait(img, actor):
    copy = img.copy()
    copy.thumbnail((310,310),Image.Resampling.LANCZOS)
    copy.save(SPR / (actor+".png"),optimize=True)

ALT_ROWS = [[0,490,1005,1536],[0,490,988,1536]]
ALT_CUTS = [[525,506,486],[516,506,478]]

def between(a, b, stage):
    grid_x, grid_y = np.meshgrid(np.arange(a.width,dtype=np.float32),
                                 np.arange(a.height,dtype=np.float32))
    def premultiply(img):
        data=np.asarray(img,dtype=np.float32)/255
        data[:,:,:3]*=data[:,:,3:]
        return data
    return as_image(motion_pair(premultiply(a),premultiply(b),grid_x,grid_y)(stage))

def register_guests(catalog, paths, alternates):
    for group, path in enumerate(paths):
        raw = Image.open(path).convert("RGBA")
        alternate = Image.open(alternates[group]).convert("RGBA")
        assert raw.size == (1448,1086), raw.size
        ys, cuts = ROWS[group]
        for row, xs in enumerate(cuts):
            index = group*3+row
            actor = GUESTS[index]
            authored = [isolate(raw.crop((xs[i],ys[row],xs[i+1],ys[row+1]))) for i in range(4)]
            authored = [ImageOps.mirror(pose) if not (index==3 and i==0) else pose for i,pose in enumerate(authored)]
            portrait(authored[0],actor)
            alt_y=ALT_ROWS[group];alt_x=ALT_CUTS[group][row]
            for col in range(2):
                x0,x1=(0,alt_x) if col==0 else (alt_x,alternate.width)
                frame=ImageOps.mirror(isolate(alternate.crop((x0,alt_y[row],x1,alt_y[row+1]))))
                target_h=round(authored[0].height*(.95 if col==0 else .70))
                authored.append(frame.resize((round(frame.width*target_h/frame.height),target_h),Image.Resampling.LANCZOS))
            cell = 260
            height = authored[0].height
            scale = min(184/height, min(218/img.width for img in authored))
            anchor = [130,218]
            images = []
            for i, img in enumerate(authored):
                img = img.resize((round(img.width*scale),round(img.height*scale)),Image.Resampling.LANCZOS)
                pivot=PIVOT[index][i] if i<4 else .49 if i==4 else .55
                left = max(4, min(cell-img.width-4, anchor[0]-round(img.width*(1-pivot))))
                key=Image.new("RGBA",(cell,cell));key.paste(img,(left,anchor[1]-img.height))
                images.append(key)
            images += [between(images[1],images[4],.5),between(images[0],images[2],.53),between(images[2],images[0],.72)]
            sheet=Image.new("RGBA",(cell*len(images),cell))
            poses=[]
            for i, key in enumerate(images):
                sheet.paste(key,(i*cell,0))
                poses.append({"rect":[i*cell,0,cell,cell],"anchor":anchor})
            clips = {"walk":[0,1,6,4], "attack":[0,7,2,8], "hurt":[3,0], "death":[0,3,5], "swim":[0,1,6,4], "swim_bite":[0,7,2,8]}
            dest = SPR / "animation" / ("v072-"+actor+"-poses.png")
            sheet.save(dest,optimize=True)
            catalog[actor]={"file":dest.relative_to(ROOT).as_posix(),"body_px":round(height*scale),"facing":"right","clips":{clip:[poses[i] for i in ids] for clip,ids in clips.items()}}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base")
    parser.add_argument("forms")
    parser.add_argument("guests",nargs=2)
    parser.add_argument("alternates",nargs=2)
    args = parser.parse_args()
    raw = Image.open(args.base).convert("RGBA")
    for i, actor in enumerate(BASE):
        portrait(isolate(raw.crop((raw.width*i//2,0,raw.width*(i+1)//2,raw.height))),actor)
    forms = Image.open(args.forms).convert("RGBA")
    for row, actor in enumerate(BASE):
        for path in range(3):
            patch = forms.crop((forms.width*path//3,forms.height*row//2,forms.width*(path+1)//3,forms.height*(row+1)//2))
            portrait(isolate(patch),f"{actor}-e{path+1}")
    catalog = json.loads(FRAMES.read_text(encoding="utf-8"))
    register_guests(catalog,args.guests,args.alternates)
    FRAMES.write_text(json.dumps(catalog,ensure_ascii=False,indent="\t")+"\n",encoding="utf-8")

if __name__ == "__main__":
    main()
