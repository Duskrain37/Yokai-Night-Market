"""用现有的手绘素材，重做三张「正投影、无灭点」的战场底图。

为什么要重做：v0.2.4 的三张地图是照片式透视（街道/栈桥向远处收敛到一个灭点），
9×5 的棋盘压上去必然打架。样板《初灯》的 courtyard 是按「高角度俯瞰、没有灭点、
中间一块空旷石板地」画的，单位站上去就自然。这里照那个公式重建三张：

  * 底板统一用 courtyard（同一套画风、同一块广场），只做裁切与调色；
  * 第一天：原图，暖调；
  * 第二天：广场换成木栈板（tex-boardwalk），两边补缆桩，上方加雾，冷调；
  * 第三天：广场换成暗河水面（tex-water），留三条石板路，水里点鬼火，深青调。

输出 2560×1440 的 map-dayN.jpg，直接替换 assets/bg/ 里的同名文件。
棋盘在 1600×900 里的矩形是 (332,232)-(1268,712)，乘 1.6 即 2560×1440 下的活动区。

运行：python tools/build_backgrounds.py
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent            # nightmarket/godot
WS = ROOT.parent.parent                                   # 神秘创作
SRC_BG = ROOT.parent / "www" / "assets" / "bg"
COURTYARD = ROOT.parent / "godot-sample" / "assets" / "courtyard.png"
OUT = ROOT / "assets" / "bg"

CANVAS = (2560, 1440)
SCALE = 1.6                       # 1600×900 → 2560×1440
BOARD = (332 * SCALE, 232 * SCALE, 1268 * SCALE, 712 * SCALE)


def cover(path: Path, size=CANVAS) -> Image.Image:
    im = Image.open(path).convert("RGB")
    ratio = max(size[0] / im.width, size[1] / im.height)
    im = im.resize((int(im.width * ratio + 0.5), int(im.height * ratio + 0.5)),
                   Image.LANCZOS)
    left = (im.width - size[0]) // 2
    top = (im.height - size[1]) // 2
    return im.crop((left, top, left + size[0], top + size[1]))


def tile(path: Path, size, scale=1.0) -> Image.Image:
    """把一张纹理铺满 size。"""
    src = Image.open(path).convert("RGB")
    if scale != 1.0:
        src = src.resize((max(1, int(src.width * scale)),
                          max(1, int(src.height * scale))), Image.LANCZOS)
    out = Image.new("RGB", size)
    for y in range(0, size[1], src.height):
        for x in range(0, size[0], src.width):
            out.paste(src, (x, y))
    return out


def feather_mask(size, inset=0, blur=90) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((inset, inset, size[0] - inset, size[1] - inset), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur))


def grade(im: Image.Image, color, strength: float, brightness=1.0,
          contrast=1.0) -> Image.Image:
    """整幅压一层色，再调亮度/对比。"""
    overlay = Image.new("RGB", im.size, color)
    im = Image.blend(im, overlay, strength)
    if brightness != 1.0:
        im = ImageEnhance.Brightness(im).enhance(brightness)
    if contrast != 1.0:
        im = ImageEnhance.Contrast(im).enhance(contrast)
    return im


def edge_shadow(im: Image.Image, rect, spread=70, alpha=110) -> Image.Image:
    """给活动区压一圈内阴影，让地面和四周布景之间有过渡（不是黑框）。"""
    x0, y0, x1, y1 = rect
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((x0 - spread, y0 - spread, x1 + spread, y1 + spread), fill=alpha)
    draw.rectangle(rect, fill=0)
    mask = mask.filter(ImageFilter.GaussianBlur(spread * 0.6))
    dark = Image.new("RGB", im.size, (4, 6, 8))
    return Image.composite(dark, im, mask)


def pil_soft_light(im: Image.Image, color, alpha_mask_size) -> Image.Image:
    return im


def add_mist(im: Image.Image, height_ratio=0.42, color=(150, 185, 205),
             alpha=58) -> Image.Image:
    w, h = im.size
    grad = Image.new("L", (1, h), 0)
    for y in range(h):
        k = max(0.0, 1.0 - y / (h * height_ratio))
        grad.putpixel((0, y), int(alpha * k * k))
    mask = grad.resize((w, h))
    overlay = Image.new("RGB", im.size, color)
    return Image.composite(overlay, im, mask)


def _band_mask(size, rect, blur=34) -> Image.Image:
    """羽化的矩形遮罩：让水面/木板边缘化进石板里，而不是切出一个直角。"""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rectangle(rect, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur))


def add_planks(im: Image.Image) -> Image.Image:
    """第二天：把活动区压成木栈板——用乘性的板纹理，边缘羽化，不切直角。"""
    x0, y0, x1, y1 = [int(v) for v in BOARD]
    planks = tile(SRC_BG / "tex-boardwalk.jpg", (x1 - x0, y1 - y0), scale=1.4)
    planks = grade(planks, (40, 28, 18), 0.35, brightness=0.72, contrast=1.05)
    draw = ImageDraw.Draw(planks)
    for i, y in enumerate(range(0, planks.height, 48)):
        draw.line((0, y, planks.width, y), fill=(20, 14, 9), width=2 if i % 3 == 0 else 1)
    region = im.crop((x0, y0, x1, y1))
    # 只保留板纹的明暗，乘到原石板上，避免"贴了一张木板"的塑料感
    wood = Image.blend(region, planks, 0.62)
    mask = _band_mask((x1 - x0, y1 - y0), (18, 14, (x1 - x0) - 18, (y1 - y0) - 14), 44)
    region = Image.composite(wood, region, mask)
    im.paste(region, (x0, y0))
    return im


def add_berths(im: Image.Image) -> Image.Image:
    """活动区两侧补几根系缆桩，让「河埠口」有设施感。"""
    draw = ImageDraw.Draw(im, "RGBA")
    x0, y0, x1, y1 = [int(v) for v in BOARD]
    for side in (x0 - 30, x1 + 14):
        for i in range(5):
            y = int(y0 + 40 + i * ((y1 - y0) / 5.2))
            draw.rectangle((side - 11, y - 52, side + 11, y + 16),
                           fill=(44, 32, 22, 225))
            draw.rectangle((side - 16, y - 58, side + 16, y - 44),
                           fill=(64, 48, 30, 225))
            draw.line((side, y - 46, side + (40 if side < 1200 else -40), y + 4),
                      fill=(76, 64, 42, 130), width=3)
    return im


def add_water(im: Image.Image) -> Image.Image:
    """第三天：只在第二、四行铺水，边缘羽化进石板；石板路就用底图本身。"""
    x0, y0, x1, y1 = [int(v) for v in BOARD]
    rows = 5
    row_h = (y1 - y0) / rows
    for row in (1, 3):
        top = int(y0 + row * row_h)
        bottom = int(y0 + (row + 1) * row_h)
        h = bottom - top
        water = tile(SRC_BG / "tex-water.jpg", (x1 - x0, h), scale=1.1)
        water = grade(water, (10, 40, 48), 0.55, brightness=0.82, contrast=1.02)
        draw = ImageDraw.Draw(water, "RGBA")
        for i in range(40):
            wy = random.randint(2, water.height - 3)
            wx = random.randint(0, max(1, water.width - 40))
            length = random.randint(50, 210)
            draw.line((wx, wy, min(water.width, wx + length), wy),
                      fill=(130, 200, 200, random.randint(8, 22)), width=1)
        region = im.crop((x0, top, x1, bottom))
        # 羽化得更狠一点，横向再内收，避免出现一条笔直的"色带"
        mask = _band_mask((x1 - x0, h), (34, 12, (x1 - x0) - 34, h - 12), 54)
        region = Image.composite(Image.blend(region, water, 0.9), region, mask)
        im.paste(region, (x0, top))
        # 岸边：水带上下各压一道浅浅的湿石，解释水陆交界
        bank = Image.new("RGBA", (x1 - x0, h), (0, 0, 0, 0))
        bdraw = ImageDraw.Draw(bank)
        bdraw.line((30, 10, (x1 - x0) - 30, 10), fill=(150, 170, 165, 40), width=3)
        bdraw.line((30, h - 11, (x1 - x0) - 30, h - 11),
                   fill=(120, 145, 140, 34), width=3)
        bank = bank.filter(ImageFilter.GaussianBlur(6))
        im.alpha_composite(bank.convert("RGBA"), (x0, top)) if im.mode == "RGBA" \
            else im.paste(bank, (x0, top), bank)
    # 水里点几团鬼火
    draw = ImageDraw.Draw(im, "RGBA")
    for row in (1, 3):
        for i in range(9):
            cx = random.randint(x0 + 60, x1 - 60)
            cy = int(y0 + (row + 0.5) * row_h + random.randint(-24, 24))
            r = random.randint(4, 10)
            draw.ellipse((cx - r * 3, cy - r * 2, cx + r * 3, cy + r * 2),
                         fill=(70, 200, 205, 22))
            draw.ellipse((cx - r, cy - r, cx + r, cy + r),
                         fill=(160, 245, 235, random.randint(40, 80)))
    return im


def build() -> None:
    random.seed(20261101)
    base = cover(COURTYARD)
    OUT.mkdir(parents=True, exist_ok=True)

    # 第一天：原图，暖一点、对比稍收
    day1 = grade(base.copy(), (36, 20, 12), 0.10, brightness=0.97, contrast=1.02)
    day1 = edge_shadow(day1, BOARD, spread=80, alpha=96)
    day1.save(OUT / "map-day1.jpg", quality=90)

    # 第二天：河埠口，木栈板 + 缆桩 + 雾
    day2 = add_planks(base.copy())
    day2 = add_berths(day2)
    day2 = grade(day2, (16, 30, 42), 0.20, brightness=0.95, contrast=1.04)
    day2 = add_mist(day2, 0.36, (140, 170, 190), 46)
    day2 = edge_shadow(day2, BOARD, spread=74, alpha=104)
    day2.save(OUT / "map-day2.jpg", quality=90)

    # 第三天：暗河，水面 + 三条石板路 + 鬼火
    day3 = add_water(base.copy())
    day3 = grade(day3, (12, 26, 40), 0.30, brightness=0.88, contrast=1.05)
    day3 = add_mist(day3, 0.30, (110, 140, 165), 52)
    day3 = edge_shadow(day3, BOARD, spread=70, alpha=118)
    day3.save(OUT / "map-day3.jpg", quality=90)

    for name in ("map-day1", "map-day2", "map-day3"):
        p = OUT / f"{name}.jpg"
        print(f"  {name}.jpg {p.stat().st_size/1024:.0f} KB")


if __name__ == "__main__":
    build()
