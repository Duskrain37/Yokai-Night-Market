"""Register hand-painted frame sheets without modifying their pixels."""
import argparse
import json
import shutil
from pathlib import Path
from statistics import median

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/sprites/animation"
MANIFEST = ROOT / "data/actor_frames.json"


def register(actor, source, clips, facing):
    with Image.open(source) as sheet:
        if "A" not in sheet.getbands():
            raise ValueError("Atlas has no alpha channel")
        alpha = sheet.getchannel("A")
        transparent = alpha.histogram()[0] / (sheet.width * sheet.height)
        if transparent < 0.12:
            raise ValueError(f"Only {transparent:.1%} of the atlas is clear")
        frames = {}
        base_heights = []
        for row, clip in enumerate(clips):
            y0 = round(row * sheet.height / len(clips))
            y1 = round((row + 1) * sheet.height / len(clips))
            frames[clip] = []
            for col in range(4):
                x0 = round(col * sheet.width / 4)
                x1 = round((col + 1) * sheet.width / 4)
                cell = alpha.crop((x0, y0, x1, y1))
                bbox = cell.point(lambda a: 255 if a >= 156 else 0).getbbox()
                if not bbox or bbox[3] - bbox[1] < cell.height * 0.20:
                    raise ValueError(f"Missing pose {clip} {col + 1}")
                if row == 0:
                    base_heights.append(bbox[3] - bbox[1])
                frames[clip].append({"rect": [x0, y0, cell.width, cell.height],
                                     "anchor": [cell.width / 2, bbox[3]]})
    DEST.mkdir(parents=True, exist_ok=True)
    target = DEST / f"{actor}.png"
    shutil.copy2(source, target)
    catalog = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    catalog[actor] = {"file": target.relative_to(ROOT).as_posix(),
                      "body_px": median(base_heights), "facing": facing, "clips": frames}
    MANIFEST.write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("actor")
    parser.add_argument("sheet", type=Path)
    parser.add_argument("clips", help="Comma separated row names in order")
    parser.add_argument("--facing", choices=["left", "right"], required=True)
    args = parser.parse_args()
    register(args.actor, args.sheet, args.clips.split(","), args.facing)
