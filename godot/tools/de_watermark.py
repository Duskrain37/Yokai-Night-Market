"""抹掉底图右下角烧录的「Qoder AI生成」水印。

做法：在角上找出中性浅灰的水印像素 → 取外接框 → 用同一条水平带上左边的纹理盖过去，
边缘做羽化过渡，再叠一点同区域的颗粒噪声，避免留下一块明显的平滑补丁。
原图会先备份到 tmp/watermark-backup/，工具可以反复跑（已抹过的图找不到水印就跳过）。
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BACKUP = os.path.join(ROOT, "tmp", "watermark-backup")
BG = os.path.join(ROOT, "nightmarket", "godot", "assets", "bg")


def find_mark(a, window):
    """在 window (x0,y0,x1,y1) 里找水印像素的外接框。"""
    x0, y0, x1, y1 = window
    reg = a[y0:y1, x0:x1].astype(int)
    r, g, b = reg[..., 0], reg[..., 1], reg[..., 2]
    lum = reg.mean(axis=2)
    floor = float(np.median(lum)) + 26.0
    neutral = (np.abs(r - g) < 18) & (np.abs(r - b) < 30) & (np.abs(g - b) < 30)
    mask = neutral & (lum > floor) & (lum < 225)
    ys, xs = np.where(mask)
    if len(ys) < 400:
        return None
    # 用行/列直方图去掉零星的亮点，只留字所在的那一段
    hist_y = np.bincount(ys, minlength=y1 - y0)
    keep_y = np.where(hist_y >= max(6, hist_y.max() * 0.18))[0]
    rows = (ys >= keep_y.min()) & (ys <= keep_y.max())
    hist_x = np.bincount(xs[rows], minlength=x1 - x0)
    keep_x = np.where(hist_x >= max(4, hist_x.max() * 0.18))[0]
    return (x0 + int(keep_x.min()), y0 + int(keep_y.min()),
            x0 + int(keep_x.max()), y0 + int(keep_y.max()))


def erase(img, box, dx=460, pad=10, feather=12):
    a = np.asarray(img).astype(np.float64)
    H, W = a.shape[:2]
    x0, y0, x1, y1 = box
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(W - 1, x1 + pad)
    y1 = min(H - 1, y1 + pad)
    sx0 = x0 - dx
    if sx0 < 0:
        raise SystemExit("取样区越界：把 dx 调小到 %d 以内" % (x0 - 2))
    patch = a[y0:y1, sx0:sx0 + (x1 - x0)]
    if patch.shape[:2] != (y1 - y0, x1 - x0):
        raise SystemExit("取样区尺寸不匹配")
    h, w = patch.shape[:2]
    yy = np.arange(h)[:, None]
    xx = np.arange(w)[None, :]
    dist_y = np.minimum(yy, h - 1 - yy)
    dist_x = np.minimum(xx, w - 1 - xx)
    # 贴着画面边缘的那一侧不做羽化，否则水印最下面那几行会被留在原地
    if y0 == 0:
        dist_y = np.maximum(dist_y, h - 1 - yy)
    if y1 == H - 1:
        dist_y = np.maximum(dist_y, yy)
    if x0 == 0:
        dist_x = np.maximum(dist_x, w - 1 - xx)
    if x1 == W - 1:
        dist_x = np.maximum(dist_x, xx)
    alpha = np.clip(np.minimum(dist_y, dist_x) / float(feather), 0.0, 1.0)
    alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(2.0)).convert("L"),
                       dtype=np.float64) / 255.0
    alpha = alpha[..., None]
    # 补丁自己的高频颗粒：原区域里亮度最高的那些像素（正是笔画）换成取样区的颗粒
    grain = patch - np.asarray(Image.fromarray(patch.astype(np.uint8))
                               .filter(ImageFilter.GaussianBlur(3.0)))
    out = a[y0:y1, x0:x1] * (1.0 - alpha) + (patch + grain * 0.35) * alpha
    a[y0:y1, x0:x1] = out
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), (x0, y0, x1, y1)


def main(paths):
    os.makedirs(BACKUP, exist_ok=True)
    for path in paths:
        if not os.path.isabs(path):
            path = os.path.join(BG, path)
        img = Image.open(path).convert("RGB")
        W, H = img.size
        a = np.asarray(img).astype(int)
        box = find_mark(a, (W - 700, H - 200, W, H))
        if box is None:
            print("%s：右下角找不到水印，跳过" % os.path.basename(path))
            continue
        print("%s：水印框 %s" % (os.path.basename(path), box))
        result, used = erase(img, box)
        stem = os.path.basename(path)
        backup = os.path.join(BACKUP, stem)
        if not os.path.exists(backup):
            img.save(backup)
        quality = 90
        result.save(path, quality=quality, subsampling=2)
        print("   抹除区 %s（取样自左移 %d）→ 已写回，备份在 %s"
              % (used, 460, backup))
        check = np.asarray(Image.open(path).convert("RGB")).astype(int)
        again = find_mark(check, (W - 700, H - 200, W, H))
        print("   复查：%s" % ("仍有残留 %s" % (again,) if again else "干净"))


if __name__ == "__main__":
    args = sys.argv[1:] or ["map-day1.jpg"]
    main(args)
