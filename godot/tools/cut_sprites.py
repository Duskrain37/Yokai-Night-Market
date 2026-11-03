"""把生成图切成可用的透明立绘。

生图模型给的是"平背景 + 主体"，这里负责：
  1) 去掉纯色底（chroma 绿 / 品红 / 白 都认），边缘做一次收边，去掉绿边；
  2) 按内容裁掉空白，四周留 6% 余量；
  3) 统一缩到目标高度（不放大超过原图）；
  4) 存成 PNG（带 alpha）。

用法：
  python tools/cut_sprites.py <输入图> <输出png> [--key green|magenta|white|auto] [--pivot bottom]

一次多张：
  python tools/cut_sprites.py --batch 清单.txt
  清单每行：输入图 → 输出png
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

KEYS = {
    "green": (0, 255, 0),
    "magenta": (255, 0, 255),
    "white": (255, 255, 255),
}


def guess_key(im: Image.Image) -> str:
    """看四角是什么颜色，猜是哪种底。"""
    w, h = im.size
    px = [im.getpixel(p) for p in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]
    r = sum(p[0] for p in px) / 4.0
    g = sum(p[1] for p in px) / 4.0
    b = sum(p[2] for p in px) / 4.0
    if g > 150 and r < 110 and b < 110:
        return "green"
    if r > 150 and b > 150 and g < 110:
        return "magenta"
    if r > 190 and g > 190 and b > 190:
        return "white"
    return "green"


def measure(img: Image.Image) -> tuple[float, float]:
    """按《美术风格提示词规范》口径量：只算 alpha>200 的像素。"""
    arr = np.array(img.convert("RGBA")).astype(np.float32)
    mask = arr[:, :, 3] > 200
    if not mask.any():
        return 0.0, 0.0
    rgb = arr[:, :, :3][mask]
    bright = float(rgb.mean())
    sat = float((rgb.max(axis=1) - rgb.min(axis=1)).mean())
    return bright, sat


def grade_to(img: Image.Image, target_bright: float, target_sat: float) -> Image.Image:
    """把亮度/饱和度拉到实测中位数附近，让新图和老立绘一个调子。"""
    bright, sat = measure(img)
    if bright <= 1.0 or sat <= 1.0:
        return img
    arr = np.array(img.convert("RGBA")).astype(np.float32)
    mask = arr[:, :, 3] > 8
    rgb = arr[:, :, :3]
    # 饱和度：朝灰轴收缩或外扩
    grey = rgb.mean(axis=2, keepdims=True)
    ratio = 0.0 if sat <= 0.0 else target_sat / sat
    ratio = max(0.35, min(1.6, ratio))
    rgb = grey + (rgb - grey) * ratio
    # 亮度：乘法但保留高光
    factor = max(0.55, min(1.5, target_bright / max(1.0, bright)))
    rgb = rgb * factor
    arr[:, :, :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def cut(src: Path, dst: Path, key: str = "auto", target_h: int = 512,
        feather: int = 2, target_bright: float = 0.0,
        target_sat: float = 0.0, crop_watermark: bool = False) -> None:
    im = Image.open(src).convert("RGB")
    if crop_watermark:
        # 右下角"AI生成"水印：先切掉右边 9% 与底边 7%，主体居中不受影响
        w0, h0 = im.size
        im = im.crop((0, 0, int(w0 * 0.91), int(h0 * 0.93)))
    if key == "auto":
        key = guess_key(im)
    base = np.array(im).astype(np.float32)
    kc = np.array(KEYS[key], np.float32)
    # 与底色的距离 → alpha
    dist = np.sqrt(((base - kc) ** 2).sum(axis=2))
    alpha = np.clip((dist - 26.0) / 60.0, 0.0, 1.0)
    # 收边：把半透明的边缘压一下，避免一圈底色光晕
    alpha = np.array(Image.fromarray((alpha * 255).astype(np.uint8))
                     .filter(ImageFilter.MinFilter(3 if feather == 2 else 1)),
                     np.float32) / 255.0
    # 去溢色：把接近底色的通道拉回邻域的中值
    if key in ("green", "magenta"):
        ch = 1 if key == "green" else 0
        other = [c for c in (0, 1, 2) if c != ch]
        ref = np.maximum(base[:, :, other[0]], base[:, :, other[1]])
        # 只在边缘（alpha 0.1—0.9）处理，主体内部保留原色
        edge = (alpha > 0.05) & (alpha < 0.95)
        base[:, :, ch] = np.where(edge, np.minimum(base[:, :, ch], ref), base[:, :, ch])
    out = np.dstack([base, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    # 按 alpha 裁内容
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    pad = int(max(w, h) * 0.06)
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    canvas.paste(img, (pad, pad), img)
    if target_bright > 0.0 or target_sat > 0.0:
        b, s = measure(canvas)
        canvas = grade_to(canvas,
                          target_bright if target_bright > 0 else b,
                          target_sat if target_sat > 0 else s)
        nb, ns = measure(canvas)
        print(f"    调色: 亮度 {b:.0f}→{nb:.0f}  饱和 {s:.0f}→{ns:.0f}")
    if target_h > 0 and canvas.height > target_h:
        scale = target_h / canvas.height
        canvas = canvas.resize((max(1, int(canvas.width * scale)), target_h),
                               Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst)
    print(f"  {dst.name}  {canvas.size}  ({dst.stat().st_size // 1024} KB)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--key", default="auto", choices=["auto", "green", "magenta", "white"])
    ap.add_argument("--height", type=int, default=512, help="成品高度，立绘按规范是 512")
    ap.add_argument("--batch", default="")
    ap.add_argument("--target-brightness", type=float, default=0.0)
    ap.add_argument("--target-saturation", type=float, default=0.0)
    ap.add_argument("--crop-watermark", action="store_true")
    args = ap.parse_args()
    if args.batch:
        for line in Path(args.batch).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            a, b = [p.strip() for p in line.split("->")]
            cut(Path(a), Path(b), args.key, args.height,
                target_bright=args.target_brightness,
                target_sat=args.target_saturation,
                crop_watermark=args.crop_watermark)
        return
    if not args.src or not args.dst:
        print(__doc__)
        sys.exit(1)
    cut(Path(args.src), Path(args.dst), args.key, args.height,
        target_bright=args.target_brightness,
        target_sat=args.target_saturation,
        crop_watermark=args.crop_watermark)


if __name__ == "__main__":
    main()
