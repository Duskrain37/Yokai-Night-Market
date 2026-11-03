"""画护具的三档破损小图：斗笠 / 陶瓮 / 铁面。

没有出图工具，就用「分层手绘」的办法自己画：每一步都是画布上的一笔——
底色渐变 → 纸纹噪点 → 墨线勾边 → 明暗 → 笔触高光 → 破损（缺口、裂纹、污渍）。
尺寸 320×320 透明 PNG，绘制时按 4 倍超采样再缩回去，边缘才不毛。

输出：godot/assets/sprites/armor-{straw,urn,mask}-{1,2,3}.png
运行：python tools/paint_armor.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"
SIZE = 320
SS = 4                      # 超采样倍数
W = SIZE * SS

PALETTES = {
    # 草/竹：偏黄的枯草色，墨线偏暖
    "straw": {
        "dark": (74, 58, 32), "mid": (146, 118, 70), "light": (206, 180, 126),
        "ink": (38, 28, 16), "accent": (233, 214, 170),
    },
    # 陶：赭红陶土
    "urn": {
        "dark": (78, 44, 30), "mid": (148, 96, 62), "light": (196, 140, 96),
        "ink": (36, 20, 14), "accent": (226, 176, 130),
    },
    # 铁：冷灰蓝，带一点铜绿
    "mask": {
        "dark": (44, 50, 54), "mid": (92, 102, 106), "light": (146, 158, 160),
        "ink": (20, 24, 26), "accent": (188, 200, 198),
    },
}


def shaded_fill(mask, palette, form="cone", light_dir=(-0.45, -0.55)):
    """给形状上底色、体积明暗和笔触：这是"画"出来的那一步。"""
    w = mask.size[0]
    yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
    nx = (xx / w) - 0.5
    ny = (yy / w) - 0.5
    # 光源方向上的投影：越朝光越亮
    t = np.clip(0.5 - (nx * light_dir[0] + ny * light_dir[1]) * 1.15, 0.0, 1.0)
    if form == "cone":
        # 锥面：顶部亮、边缘暗，再叠一圈径向的收暗
        r = np.sqrt(nx * nx + (ny * 0.65) ** 2) * 2.0
        t = np.clip(t * 0.85 - r * 0.25 + 0.22, 0.0, 1.0)
    elif form == "urn":
        # 圆柱：中间亮、两侧暗
        t = np.clip(t * 0.55 + (1.0 - abs(nx) * 1.9) * 0.55, 0.0, 1.0)
    else:
        t = np.clip(t * 0.8 + 0.14, 0.0, 1.0)
    out = np.zeros((w, w, 3), np.float32)
    for i in range(3):
        out[:, :, i] = palette["dark"][i] + (palette["mid"][i] - palette["dark"][i]) * t
    base = Image.fromarray(out.astype(np.uint8), "RGB").convert("RGBA")
    # 笔触：沿受光方向刷一层短笔，颜色在 mid/light 之间跳
    dabs = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dabs)
    rng = random.Random(23)
    for _ in range(w * 3):
        x = rng.uniform(0, w)
        y = rng.uniform(0, w)
        ln = rng.uniform(w * 0.02, w * 0.09)
        ang = rng.uniform(-0.5, 0.5) + (0.5 if form == "urn" else -0.9)
        ex = x + math.cos(ang) * ln
        ey = y + math.sin(ang) * ln
        k = rng.random()
        col = palette["light"] if k > 0.55 else (palette["mid"] if k > 0.15
            else palette["dark"])
        dd.line((x, y, ex, ey), fill=col + (rng.randrange(14, 40),),
            width=max(1, int(w * rng.uniform(0.003, 0.009))))
    dabs = dabs.filter(ImageFilter.GaussianBlur(w * 0.003))
    base = Image.alpha_composite(base, dabs)
    # 只保留落在形状里的部分
    arr = np.array(base, np.float32)
    arr[:, :, 3] = np.array(mask, np.float32)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def noisy_gradient(size, dark, light, angle=90.0):
    """沿某个方向的渐变，叠一层低频噪声，像笔brush 的厚薄不匀。"""
    w = size
    yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
    a = math.radians(angle)
    proj = (xx * math.cos(a) + yy * math.sin(a))
    proj = (proj - proj.min()) / max(1e-3, (proj.max() - proj.min()))
    rng = np.random.default_rng(7)
    grain = rng.normal(0.0, 0.08, (w // 16 + 1, w // 16 + 1))
    grain = np.array(Image.fromarray(((grain - grain.min()) /
        max(1e-6, grain.max() - grain.min()) * 255).astype(np.uint8))
        .resize((w, w), Image.BICUBIC), dtype=np.float32) / 255.0
    t = np.clip(proj * 0.85 + grain * 0.3, 0.0, 1.0)
    out = np.zeros((w, w, 3), np.float32)
    for i in range(3):
        out[:, :, i] = dark[i] + (light[i] - dark[i]) * t
    return Image.fromarray(out.astype(np.uint8), "RGB")


def fibre_texture(size, strength=18):
    """宣纸/草编的纤维感：横竖短划 + 细点。"""
    layer = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(layer)
    rng = random.Random(11)
    for _ in range(size // 2):
        x = rng.randrange(size)
        y = rng.randrange(size)
        ln = rng.randrange(size // 30, size // 10)
        v = rng.randrange(strength // 2, strength)
        if rng.random() < 0.5:
            d.line((x, y, x + ln, y + rng.randint(-2, 2)), fill=v, width=1)
        else:
            d.line((x, y, x + rng.randint(-2, 2), y + ln), fill=v, width=1)
    for _ in range(size):
        x = rng.randrange(size)
        y = rng.randrange(size)
        d.point((x, y), fill=rng.randrange(6, strength))
    return layer


def mask_from(mask_img):
    return mask_img


def wobbly(mask, amount=0.006):
    """把边缘抖一下，位置别是数学完美曲线。"""
    w = mask.size[0]
    rng = random.Random(5)
    shift = Image.new("L", mask.size, 0)
    d = ImageDraw.Draw(shift)
    for _ in range(28):
        x = rng.uniform(0, w)
        y = rng.uniform(0, w)
        r = rng.uniform(w * 0.02, w * 0.07)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.randrange(0, 90))
    shift = shift.filter(ImageFilter.GaussianBlur(w * 0.02))
    a = np.array(mask, np.float32) + (np.array(shift, np.float32) - 45.0) * amount * 26
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def outline(mask, color, width=3):
    """墨线：把 alpha 往外扩一圈再减去原形，得到贴边的线。"""
    m = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    edge = Image.fromarray(np.clip(np.asarray(m, np.int16) - np.asarray(mask, np.int16),
        0, 255).astype(np.uint8))
    layer = Image.new("RGBA", mask.size, color + (0,))
    layer.putalpha(edge)
    return layer


def paint_cone(side=0):
    """斗笠：圆锥 + 帽檐，略带三点透视。"""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx, cy = W * 0.5, W * 0.5
    brim_w = W * 0.40
    brim_h = W * 0.13
    top = cy - W * 0.30
    base = cy + W * 0.10
    # 帽檐（椭圆）与锥体合成一个形状
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((cx - brim_w, base - brim_h, cx + brim_w, base + brim_h), fill=255)
    d.polygon([(cx, top), (cx + brim_w * 0.72, base - brim_h * 0.25),
        (cx - brim_w * 0.72, base - brim_h * 0.25)], fill=255)
    mask = wobbly(mask.filter(ImageFilter.GaussianBlur(W * 0.006)))
    img = shaded_fill(mask, PALETTES["straw"], "cone")

    # 帽檐下的一圈阴影，让帽子压在头上
    under = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    du = ImageDraw.Draw(under)
    du.ellipse((cx - brim_w * 0.98, base - brim_h * 0.35, cx + brim_w * 0.98,
        base + brim_h * 0.9), fill=(20, 14, 8, 90))
    under = under.filter(ImageFilter.GaussianBlur(W * 0.02))
    img = Image.alpha_composite(img, under)

    # 草编的放射状编织纹
    lines = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lines)
    rng2 = random.Random(31)
    # 草编：一圈圈同心弧 + 稀疏的放射短笔，线要断断续续
    for i in range(7):
        rr = 0.22 + i * 0.115
        bb = (cx - brim_w * rr, base - brim_h * 1.5 * rr, cx + brim_w * rr,
            base + brim_h * 1.1 * rr)
        for k in range(3):
            a0 = rng2.uniform(0, math.tau)
            a1 = a0 + rng2.uniform(0.5, 1.4)
            dl.arc(bb, math.degrees(a0), math.degrees(a1),
                fill=PALETTES["straw"]["ink"] + (44,), width=int(W * 0.005))
    for _ in range(26):
        a = rng2.uniform(-math.pi, 0)
        r0 = rng2.uniform(0.25, 0.55)
        r1 = r0 + rng2.uniform(0.15, 0.4)
        dl.line((cx + math.cos(a) * brim_w * r0, base + math.sin(a) * brim_h * 3.2 * r0,
            cx + math.cos(a) * brim_w * r1, base + math.sin(a) * brim_h * 3.2 * r1),
            fill=PALETTES["straw"]["ink"] + (30,), width=int(W * 0.004))
    lines.putalpha(Image.composite(lines.getchannel("A"), Image.new("L", (W, W), 0), mask))
    img = Image.alpha_composite(img, lines)

    # 纸纹
    tex = fibre_texture(W, 16)
    tex_col = Image.new("RGBA", (W, W), PALETTES["straw"]["ink"] + (255,))
    tex_col.putalpha(Image.composite(tex, Image.new("L", (W, W), 0), mask).point(
        lambda v: int(v * 0.9)))
    img = Image.alpha_composite(img, tex_col)

    # 墨线
    img = Image.alpha_composite(img, outline(mask, PALETTES["straw"]["ink"],
        int(W * 0.006)))
    return img, mask


def paint_urn():
    """陶瓮：口沿、鼓腹、底足。"""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx, cy = W * 0.5, W * 0.5
    body_w = W * 0.34
    lip_y = cy - W * 0.26
    base_y = cy + W * 0.28
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((cx - body_w, lip_y, cx + body_w, lip_y + W * 0.16), fill=255)
    d.polygon([(cx - body_w * 0.92, lip_y + W * 0.05),
        (cx + body_w * 0.92, lip_y + W * 0.05),
        (cx + body_w * 1.06, base_y - W * 0.16),
        (cx - body_w * 1.06, base_y - W * 0.16)], fill=255)
    d.ellipse((cx - body_w * 1.06, base_y - W * 0.20, cx + body_w * 1.06, base_y), fill=255)
    mask = wobbly(mask.filter(ImageFilter.GaussianBlur(W * 0.006)))
    img = shaded_fill(mask, PALETTES["urn"], "urn")

    # 口沿与底足各压一道暗，鼓腹才立得起来
    for y, a in ((lip_y + W * 0.10, 70), (base_y - W * 0.12, 90)):
        band = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        db = ImageDraw.Draw(band)
        db.rectangle((cx - body_w * 1.1, y - W * 0.02, cx + body_w * 1.1, y + W * 0.03),
            fill=(22, 12, 8, a))
        band = band.filter(ImageFilter.GaussianBlur(W * 0.012))
        img = Image.alpha_composite(img, band)

    # 口沿、弦纹、绳痕
    det = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    dd = ImageDraw.Draw(det)
    dd.ellipse((cx - body_w, lip_y, cx + body_w, lip_y + W * 0.16),
        outline=PALETTES["urn"]["ink"] + (150,), width=int(W * 0.008))
    dd.ellipse((cx - body_w * 0.86, lip_y + W * 0.012, cx + body_w * 0.86,
        lip_y + W * 0.10), outline=PALETTES["urn"]["dark"] + (120,), width=int(W * 0.006))
    for i in range(3):
        y = lip_y + W * (0.14 + i * 0.11)
        dd.line((cx - body_w * 0.95, y, cx + body_w * 0.95, y),
            fill=PALETTES["urn"]["ink"] + (70,), width=int(W * 0.006))
    det.putalpha(Image.composite(det.getchannel("A"), Image.new("L", (W, W), 0), mask))
    img = Image.alpha_composite(img, det)

    tex = fibre_texture(W, 12)
    tex_col = Image.new("RGBA", (W, W), PALETTES["urn"]["dark"] + (255,))
    tex_col.putalpha(Image.composite(tex, Image.new("L", (W, W), 0), mask).point(
        lambda v: int(v * 0.8)))
    img = Image.alpha_composite(img, tex_col)
    img = Image.alpha_composite(img, outline(mask, PALETTES["urn"]["ink"], int(W * 0.006)))
    return img, mask


def paint_mask():
    """铁面：圆角方牌、眉脊、眼缝、铆钉。"""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx, cy = W * 0.5, W * 0.5
    mw = W * 0.30
    top = cy - W * 0.30
    bot = cy + W * 0.26
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    d.polygon([(cx - mw, top + W * 0.06), (cx + mw, top + W * 0.06),
        (cx + mw * 0.86, bot - W * 0.12), (cx + mw * 0.30, bot),
        (cx - mw * 0.30, bot), (cx - mw * 0.86, bot - W * 0.12)], fill=255)
    mask = wobbly(mask.filter(ImageFilter.GaussianBlur(W * 0.006)))
    img = shaded_fill(mask, PALETTES["mask"], "mask")

    det = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    dd = ImageDraw.Draw(det)
    # 眉脊
    dd.polygon([(cx - mw * 0.86, top + W * 0.10), (cx + mw * 0.86, top + W * 0.10),
        (cx + mw * 0.70, top + W * 0.155), (cx - mw * 0.70, top + W * 0.155)],
        fill=PALETTES["mask"]["light"] + (170,))
    # 眼缝
    for sign in (-1, 1):
        ex = cx + sign * mw * 0.42
        dd.ellipse((ex - mw * 0.26, top + W * 0.185, ex + mw * 0.26, top + W * 0.245),
            fill=PALETTES["mask"]["ink"] + (230,))
    # 鼻梁
    dd.line((cx, top + W * 0.24, cx, top + W * 0.40),
        fill=PALETTES["mask"]["dark"] + (120,), width=int(W * 0.012))
    # 嘴缝
    dd.line((cx - mw * 0.34, top + W * 0.44, cx + mw * 0.34, top + W * 0.44),
        fill=PALETTES["mask"]["ink"] + (150,), width=int(W * 0.006))
    # 铆钉
    for i in range(4):
        rx = cx + (i - 1.5) * mw * 0.5
        for ry in (top + W * 0.075, bot - W * 0.035):
            dd.ellipse((rx - W * 0.008, ry - W * 0.008, rx + W * 0.008, ry + W * 0.008),
                fill=PALETTES["mask"]["accent"] + (200,))
    det.putalpha(Image.composite(det.getchannel("A"), Image.new("L", (W, W), 0), mask))
    img = Image.alpha_composite(img, det)

    tex = fibre_texture(W, 10)
    tex_col = Image.new("RGBA", (W, W), PALETTES["mask"]["ink"] + (255,))
    tex_col.putalpha(Image.composite(tex, Image.new("L", (W, W), 0), mask).point(
        lambda v: int(v * 0.5)))
    img = Image.alpha_composite(img, tex_col)
    img = Image.alpha_composite(img, outline(mask, PALETTES["mask"]["ink"], int(W * 0.007)))
    return img, mask


def damage(img, mask, palette, tier, seed):
    """按档位砸缺口、裂纹、污渍。tier 1=完好 2=裂 3=残。"""
    if tier <= 1:
        return img
    rng = random.Random(seed)
    alpha = np.array(mask, np.float32)
    w = alpha.shape[0]
    cut = Image.new("L", (w, w), 0)
    dc = ImageDraw.Draw(cut)
    bites = 1 if tier == 2 else 3
    for _ in range(bites):
        cx = rng.uniform(w * 0.2, w * 0.8)
        cy = rng.uniform(w * 0.16, w * 0.34) if rng.random() < 0.6 \
            else rng.uniform(w * 0.62, w * 0.82)
        r = rng.uniform(w * 0.05, w * 0.10) * (1.35 if tier == 3 else 1.0)
        pts = []
        steps = 9
        for i in range(steps):
            a = i / steps * math.tau
            rr = r * (0.55 + rng.random() * 0.9)
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        dc.polygon(pts, fill=255)
    cut = cut.filter(ImageFilter.GaussianBlur(w * 0.004))
    keep = np.clip(alpha - np.array(cut, np.float32), 0, 255)
    arr = np.array(img.convert("RGBA"), np.float32)
    arr[:, :, 3] = keep
    img = Image.fromarray(arr.astype(np.uint8), "RGBA")

    # 断口的厚度：沿缺口内侧压一道暗，再在亮面那侧提一道细高光
    keep_img = Image.fromarray(keep.astype(np.uint8))
    grown = np.array(cut.filter(ImageFilter.MaxFilter(int(w * 0.02) | 1)), np.float32)
    inner = np.clip(grown - (255.0 - keep), 0, 255) * (keep / 255.0)
    inner_img = Image.fromarray(inner.astype(np.uint8))
    shade = Image.new("RGBA", (w, w), (26, 16, 10, 255))
    shade.putalpha(inner_img.point(lambda v: int(v * 0.75)))
    img = Image.alpha_composite(img, shade)
    thin = np.array(cut.filter(ImageFilter.MaxFilter(int(w * 0.006) | 1)), np.float32)
    rim = np.clip(thin - grown, 0, 255) * (keep / 255.0)
    rim_img = Image.fromarray(rim.astype(np.uint8))
    hi = Image.new("RGBA", (w, w), palette["accent"] + (255,))
    hi.putalpha(rim_img.point(lambda v: int(v * 0.55)))
    img = Image.alpha_composite(img, hi)

    # 裂纹：深色线 + 旁边一道亮边，像釉面崩开
    cracks = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    dc2 = ImageDraw.Draw(cracks)
    count = 2 if tier == 2 else 4
    for _ in range(count):
        x = rng.uniform(w * 0.25, w * 0.75)
        y = rng.uniform(w * 0.2, w * 0.45)
        for _ in range(rng.randrange(3, 6)):
            nx = x + rng.uniform(-w * 0.09, w * 0.09)
            ny = y + rng.uniform(w * 0.03, w * 0.12)
            dc2.line((x, y, nx, ny), fill=palette["ink"] + (210,),
                width=int(w * rng.uniform(0.004, 0.008)))
            dc2.line((x + w * 0.004, y, nx + w * 0.004, ny),
                fill=palette["accent"] + (60,), width=1)
            x, y = nx, ny
    keep_img = Image.fromarray(keep.astype(np.uint8))
    cracks.putalpha(Image.composite(cracks.getchannel("A"), Image.new("L", (w, w), 0),
        keep_img))
    img = Image.alpha_composite(img, cracks)

    # 污渍：被熏黑/蹭脏
    if tier == 3:
        soot = Image.new("L", (w, w), 0)
        dso = ImageDraw.Draw(soot)
        for _ in range(3):
            sx = rng.uniform(w * 0.25, w * 0.75)
            sy = rng.uniform(w * 0.25, w * 0.7)
            dso.ellipse((sx - w * 0.1, sy - w * 0.08, sx + w * 0.1, sy + w * 0.08),
                fill=rng.randrange(40, 90))
        soot = soot.filter(ImageFilter.GaussianBlur(w * 0.03))
        soot = Image.composite(soot, Image.new("L", (w, w), 0), keep_img)
        dark = Image.new("RGBA", (w, w), (18, 12, 8, 255))
        dark.putalpha(soot)
        img = Image.alpha_composite(img, dark)
    return img


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("straw", paint_cone, PALETTES["straw"]),
            ("urn", paint_urn, PALETTES["urn"]),
            ("mask", paint_mask, PALETTES["mask"])]
    for name, painter, palette in jobs:
        base, mask = painter()
        for tier in (1, 2, 3):
            img = damage(base.copy(), mask, palette, tier, seed=hash(name) % 1000 + tier)
            small = img.resize((SIZE, SIZE), Image.LANCZOS)
            path = OUT / f"armor-{name}-{tier}.png"
            small.save(path)
            print(f"  {path.name} {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    build()
