"""打包前盖一个构建戳记：把 VERSION 同步进 export_presets，并生成 data/build_info.gd。

短哈希不是 git 提交号——本作目录没有 git 仓库——而是对源码与资源内容算的摘要，
同样能回答「我手上这份 exe 是哪一份代码打出来的」。
"""
import hashlib
import os
import re
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODE_DIRS = ["scripts", "data", "ui", "tools", "scenes"]
CODE_EXT = (".gd", ".tscn", ".godot", ".cfg", ".json")
ASSET_DIRS = ["assets"]
ASSET_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".ttf", ".otf", ".ogg", ".wav")


def _files():
    yield os.path.join(ROOT,"project.godot")
    yield os.path.join(ROOT,"export_presets.cfg")
    for folder in CODE_DIRS:
        base = os.path.join(ROOT, folder)
        for dirpath, names, filenames in os.walk(base):
            if "__pycache__" in dirpath:
                continue
            for name in filenames:
                # 戳记文件自己不算进去，否则每次跑哈希都会跟着上一次的时间戳漂
                if name == "build_info.gd":
                    continue
                if name.endswith(CODE_EXT):
                    yield os.path.join(dirpath, name)
    for folder in ASSET_DIRS:
        base = os.path.join(ROOT, folder)
        for dirpath, _, filenames in os.walk(base):
            for name in filenames:
                if name.endswith(ASSET_EXT):
                    yield os.path.join(dirpath, name)


def source_hash():
    digest = hashlib.sha256()
    count = 0
    for path in sorted(_files()):
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        digest.update(rel.encode("utf-8"))
        with open(path, "rb") as handle:
            digest.update(handle.read())
        count += 1
    return digest.hexdigest()[:7], count


def read_version():
    with open(os.path.join(ROOT, "scripts", "game.gd"), encoding="utf-8") as handle:
        text = handle.read()
    found = re.search(r'const VERSION = "([^"]+)"', text)
    if found is None:
        raise SystemExit("scripts/game.gd 里找不到 const VERSION")
    return found.group(1)


def sync_presets(version):
    path = os.path.join(ROOT, "export_presets.cfg")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    pairs = [
        (r'application/file_version="[^"]*"', 'application/file_version="%s.0"' % version),
        (r'application/product_version="[^"]*"',
         'application/product_version="%s.0"' % version),
        (r'application/file_description="[^"]*"',
         'application/file_description="妖怪夜市 v%s · Godot 原生 2D"' % version),
    ]
    changed = 0
    for pattern, replacement in pairs:
        if re.search(pattern, text) is None:
            raise SystemExit("export_presets.cfg 里找不到 %s" % pattern)
        new = re.sub(pattern, replacement, text)
        if new != text:
            changed += 1
        text = new
    if changed:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    project = os.path.join(ROOT,"project.godot")
    with open(project,encoding="utf-8") as f: text=f.read()
    text=re.sub(r'config/version="[^"\n]*"','config/version="%s"'%version,text)
    with open(project,"w",encoding="utf-8",newline="\n") as f:f.write(text)
    return changed


def write_build_info(version, stamp, short, files):
    path = os.path.join(ROOT, "data", "build_info.gd")
    body = "".join([
        "## 构建戳记：由 tools/stamp_build.py 在打包时生成，别手改。\n",
        'const VERSION = "%s"\n' % version,
        'const BUILD_TIME = "%s"\n' % stamp,
        'const BUILD_HASH = "%s"\n' % short,
        "const BUILD_FILES = %d\n" % files,
    ])
    old = ""
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            old = handle.read()
    if old != body:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(body)


if __name__ == "__main__":
    version = read_version()
    changed = sync_presets(version)
    short, files = source_hash()
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    write_build_info(version, stamp, short, files)
    print("BUILD v%s  %s  %s(%d 文件)  export_presets 改动 %d 处"
          % (version, stamp, short, files, changed))
