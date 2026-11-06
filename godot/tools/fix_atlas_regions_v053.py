"""Repair uneven hand-drawn row bounds without changing any source artwork."""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ACTORS=["reedboat"]
ROWS=["walk","attack","swim","swim_bite"]

def main():
    path=ROOT/"data/actor_frames.json"
    data=json.loads(path.read_text("utf-8"))
    pins_path=ROOT/"data/actor_attachment_pins.json"
    pins=json.loads(pins_path.read_text("utf-8"))
    audit={}
    for actor in ACTORS:
        info=data[actor]
        image=Image.open(ROOT/info["file"]).convert("RGBA")
        alpha=np.asarray(image)[:,:,3]
        heights=[]
        audit[actor]=[]
        for col in range(4):
            x,_,width,_=info["clips"]["walk"][col]["rect"]
            mask=np.uint8(alpha[:,x:x+width]>80)
            count,labels,stats,_=cv2.connectedComponentsWithStats(mask,8)
            majors=sorted(range(1,count),key=lambda k:int(stats[k,cv2.CC_STAT_AREA]),reverse=True)[:4]
            majors.sort(key=lambda k:int(stats[k,cv2.CC_STAT_TOP]))
            assert len(majors)==4
            for row,(clip,key) in enumerate(zip(ROWS,majors)):
                _,top,_,height,area=map(int,stats[key])
                assert area>3000
                bottom=top+height
                low=max(0,top-3);high=min(image.height,bottom+3)
                frame=info["clips"][clip][col]
                before=frame["rect"].copy()
                frame["rect"]=[x,low,width,high-low]
                frame["anchor"]=[frame["anchor"][0],bottom-low]
                if row==0: heights.append(height)
                if actor in pins:
                    face_y=top+round(height*(0.18 if row<2 else 0.24))
                    xs=np.nonzero(labels[face_y]==key)[0]
                    assert len(xs)>0
                    pins[actor][clip][col]=[float(x+(xs[0]+xs[-1])/2),int(face_y)]
                audit[actor].append({"clip":clip,"pose":col,"old":before,"rect":frame["rect"],"body_bounds":[top,bottom]})
        info["body_px"]=int(np.median(heights))
        frame=info["clips"]["walk"][0];x,y,w,h=frame["rect"]
        image.crop((x,y,x+w,y+h)).save(ROOT/f"assets/sprites/{actor}.png")
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n","utf-8")
    pins_path.write_text(json.dumps(pins,ensure_ascii=False,indent=2)+"\n","utf-8")
    (ROOT/"data/v053_region_audit.json").write_text(json.dumps(audit,indent=2)+"\n","utf-8")
    print("Repaired bounds and grounding for",len(audit),"actors")

if __name__=="__main__":main()
