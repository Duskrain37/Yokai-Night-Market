"""Bake 32 motion samples per clip from the original transparent key poses."""
import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/actor_frames.json"
OUTPUT = ROOT / "data/actor_motion.json"
ASSETS = ROOT / "assets/sprites/motion"
FRAME_COUNT = 32
COLUMNS = 8
cv2.setNumThreads(1)


def aligned_poses(image, frames, scale):
    left = min(round(-frame["anchor"][0] * scale) for frame in frames) - 3
    top = min(round(-frame["anchor"][1] * scale) for frame in frames) - 3
    right = max(round((frame["rect"][2] - frame["anchor"][0]) * scale) for frame in frames) + 3
    bottom = max(round((frame["rect"][3] - frame["anchor"][1]) * scale) for frame in frames) + 3
    poses = []
    for frame in frames:
        x, y, w, h = frame["rect"]
        patch = image.crop((x, y, x + w, y + h)).resize(
            (max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (right - left, bottom - top))
        ax, ay = frame["anchor"]
        canvas.paste(patch, (round(-ax * scale) - left, round(-ay * scale) - top))
        pixels = np.asarray(canvas, dtype=np.float32) / 255
        pixels[..., :3] *= pixels[..., 3:]
        poses.append(pixels)
    return poses, [-left, -top]


def gray(pose):
    rgb = cv2.cvtColor(pose[..., :3], cv2.COLOR_RGB2GRAY)
    return np.uint8(np.clip(rgb * 0.75 + pose[..., 3] * 0.25, 0, 1) * 255)


def motion_pair(first, second, grid_x, grid_y):
    solver = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    a, b = gray(first), gray(second)
    forward = solver.calc(a, b, None)
    backward = solver.calc(b, a, None)

    def warp(image, flow, fraction):
        x = grid_x - flow[..., 0] * fraction
        y = grid_y - flow[..., 1] * fraction
        # Refine the inverse mapping where limbs move farther than a few pixels.
        for _ in range(2):
            local = cv2.remap(flow, x, y, cv2.INTER_LINEAR,
                              borderMode=cv2.BORDER_REPLICATE)
            x = grid_x - local[..., 0] * fraction
            y = grid_y - local[..., 1] * fraction
        return cv2.remap(image, x, y, cv2.INTER_LINEAR,
                         borderMode=cv2.BORDER_CONSTANT)

    def between(t):
        if t <= 0:
            return first
        a = warp(first, forward, t)
        b = warp(second, backward, 1 - t)
        blended = a * (1 - t) + b * t
        # At an occlusion, use the nearer silhouette. Blending unmatched
        # shapes leaves see-through hands, feet, and duplicate weapons.
        separation = np.abs(a[..., 3:] - b[..., 3:])
        unmatched = np.clip((separation - 0.14) / 0.45, 0, 1)
        primary = a if t < 0.5 else b
        return blended * (1 - unmatched) + primary * unmatched

    return between


def as_image(pixels):
    rgba = pixels.copy()
    alpha = rgba[..., 3:]
    np.divide(rgba[..., :3], np.maximum(alpha, 1 / 255), out=rgba[..., :3])
    return Image.fromarray(np.uint8(np.clip(rgba, 0, 1) * 255 + 0.5), "RGBA")


def bake_actor(item):
    actor, info = item
    image = Image.open(ROOT / info["file"]).convert("RGBA")
    # Match on-screen sizes while avoiding full source illustration dimensions in VRAM.
    body_px = 192 if actor.startswith("boss-") else 152
    scale = body_px / float(info["body_px"])
    clips = {}
    baked = {}
    total_h = 0
    total_w = 0
    for clip, keys in info["clips"].items():
        poses, anchor = aligned_poses(image, keys, scale)
        h, w = poses[0].shape[:2]
        grid_x, grid_y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
        motions = [motion_pair(poses[i], poses[(i + 1) % len(poses)], grid_x, grid_y)
                   for i in range(len(poses))]
        baked[clip] = (w, h, total_h, anchor, motions)
        total_h += h * (FRAME_COUNT // COLUMNS)
        total_w = max(total_w, w * COLUMNS)
    atlas = Image.new("RGBA", (total_w, total_h))
    for clip, (w, h, y, anchor, motions) in baked.items():
        frames = []
        for sample in range(FRAME_COUNT):
            if clip in {"reload_enter", "reload_exit", "land", "splash", "break", "sink", "collect", "release", "death", "steal", "pickup"}:
                position = min(len(motions) - 1.000001, sample * (len(motions) - 1) / (FRAME_COUNT - 1))
            else:
                position = sample * len(motions) / FRAME_COUNT
            index = int(position)
            pose = as_image(motions[index](position - index))
            left, top = sample % COLUMNS * w, y + sample // COLUMNS * h
            atlas.paste(pose, (left, top))
            frames.append({"rect": [left, top, w, h], "anchor": anchor})
        clips[clip] = frames
    file = ASSETS / (actor + ".webp")
    atlas.save(file, "WEBP", quality=86, alpha_quality=100, method=4)
    return actor, {"file": file.relative_to(ROOT).as_posix(), "body_px": body_px,
                   "facing": info["facing"], "clips": clips}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actor", action="append", help="Only bake selected actors. May repeat.")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    selected = {key: source[key] for key in args.actor} if args.actor else source
    ASSETS.mkdir(parents=True, exist_ok=True)
    catalog = json.loads(OUTPUT.read_text(encoding="utf-8")) if args.actor and OUTPUT.exists() else {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for i, (actor, info) in enumerate(executor.map(bake_actor, selected.items()), start=1):
            catalog[actor] = info
            if i % 10 == 0 or i == len(selected):
                print(f"Motion sheets {i}/{len(selected)}", flush=True)
    OUTPUT.write_text(json.dumps(catalog, separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
