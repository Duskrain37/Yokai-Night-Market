"""Collect the shared art/audio assets for the Godot build of 妖怪夜市 v0.3.0.

Sources (read-only): ../www/assets/**  — the shipped v0.2.4 art and music.
Outputs (written):   assets/sprites/*.png, assets/bg/*.jpg, assets/music/*.ogg,
                     assets/fonts/*.ttf, assets/sprite_meta.json

The v0.2.4 sprites are the art baseline for every plant and zombie in this build,
so the game keeps one continuous look with the painted maps. The script only
copies the files plus records each sprite's opaque bounding box (units are anchored
by their feet, and several sheets have large transparent margins of different size).

Run:  python tools/prepare_assets.py
"""
from __future__ import annotations

import json
import shutil
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WWW = ROOT.parent / "www" / "assets"
ASSETS = ROOT / "assets"

SPRITES = [
    "lantern", "shooter", "wall", "bomb", "bell", "censer", "umbrella", "lion",
    "mushroom", "cat", "lobber", "torch", "star", "needle", "judge", "lily", "kelp",
    "ghost", "paper", "mountain", "tongue", "mourner", "sedan", "straw", "stonehat",
    "bucket", "vault", "artisan", "ironjudge", "guardian",
]
BACKGROUNDS = ["menu", "board", "map-day1", "map-day2", "map-day3"]
MUSIC = ["menu", "battle", "hot", "final"]

FONT_CACHE = ROOT / "tools" / "fonts-cache"

FONTS = [
    (
        "LXGWWenKai-Regular.ttf",
        "https://github.com/lxgw/LxgwWenKai/releases/download/v1.530/LXGWWenKai-Regular.ttf",
        "LXGWWenKai-OFL.txt",
        "https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/OFL.txt",
    ),
    (
        "LXGWWenKai-Medium.ttf",
        "https://github.com/lxgw/LxgwWenKai/releases/download/v1.530/LXGWWenKai-Medium.ttf",
        "LXGWWenKai-OFL.txt",
        "https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/OFL.txt",
    ),
    (
        "MaShanZheng-Regular.ttf",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/mashanzheng/MaShanZheng-Regular.ttf",
        "MaShanZheng-OFL.txt",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/mashanzheng/OFL.txt",
    ),
]


def ensure(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def copy_tree() -> dict:
    ensure(ASSETS / "sprites")
    ensure(ASSETS / "bg")
    ensure(ASSETS / "music")

    meta = {}
    for name in SPRITES:
        src = WWW / "sprites" / f"{name}.png"
        if not src.exists():
            print(f"  !! missing sprite {name}", file=sys.stderr)
            continue
        dst = ASSETS / "sprites" / f"{name}.png"
        shutil.copyfile(src, dst)
        im = Image.open(dst).convert("RGBA")
        bbox = im.getchannel("A").getbbox()
        meta[name] = {
            "size": list(im.size),
            "bbox": list(bbox) if bbox else [0, 0, im.size[0], im.size[1]],
        }

    for name in BACKGROUNDS:
        src = WWW / "bg" / f"{name}.jpg"
        if src.exists():
            shutil.copyfile(src, ASSETS / "bg" / f"{name}.jpg")

    for name in MUSIC:
        src = WWW / "music" / f"{name}.ogg"
        if src.exists():
            shutil.copyfile(src, ASSETS / "music" / f"{name}.ogg")

    (ASSETS / "sprite_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    return meta


def fetch_fonts() -> None:
    """Download the source fonts into tools/fonts-cache; subset_fonts.py trims them."""
    ensure(FONT_CACHE)
    for filename, url, licence_name, licence_url in FONTS:
        target = FONT_CACHE / filename
        licence = FONT_CACHE / licence_name
        for path, link in ((target, url), (licence, licence_url)):
            if path.exists() and path.stat().st_size > 1024:
                continue
            print(f"  downloading {path.name}")
            try:
                with urllib.request.urlopen(link, timeout=120) as response:
                    path.write_bytes(response.read())
            except Exception as exc:  # noqa: BLE001 - report and continue
                print(f"  !! failed {path.name}: {exc}", file=sys.stderr)


def main() -> int:
    ensure(ASSETS)
    meta = copy_tree()
    fetch_fonts()
    print(f"sprite meta: {len(meta)} entries")
    for name, info in sorted(meta.items()):
        print(f"  {name:12s} {info['size']} bbox={info['bbox']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
