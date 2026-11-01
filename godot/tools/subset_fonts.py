"""Trim the downloaded OFL fonts down to the glyphs this game actually shows.

Godot embeds every byte it imports, and a full CJK font is ~26 MB. The build only
needs the characters that appear in the game data and UI strings, so this script
collects the character set from the project's own sources and writes a compact
subset per font.

Character set = every character in:
  * scripts/**/*.gd, data/**/*.gd   (all in-game text lives here)
  * ../www/src/**/*.js              (v0.2.4 wording reused by the port)
plus printable ASCII and common CJK / typographic punctuation.

Run after prepare_assets.py and whenever new Chinese text is added:
    python tools/subset_fonts.py
`tools/check_font_coverage.py --check` then proves nothing is missing.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "fonts-cache"
OUT = ROOT / "assets" / "fonts"

SOURCES = [
    *ROOT.glob("scripts/**/*.gd"),
    *ROOT.glob("data/**/*.gd"),
    *ROOT.glob("ui/**/*.gd"),
    *ROOT.glob("tools/*.gd"),
    *(ROOT.parent / "www" / "src").glob("**/*.js"),
]

EXTRA = (
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "　、。〈〉《》「」『』【】〔〕・ー—…‘’“”·×÷±°％‰　"
    + "，．：；！？（）［］｛｝＋－＝＜＞｜＼／＾＿｀～￥"
    + "0123456789０１２３４５６７８９"
    + "←→↑↓★☆♠♣♥♦✓✕▲▼◆◇●○■□"
)

FONTS = [
    ("LXGWWenKai-Regular.ttf", "LXGWWenKai-Regular.ttf"),
    ("LXGWWenKai-Medium.ttf", "LXGWWenKai-Medium.ttf"),
    ("MaShanZheng-Regular.ttf", "MaShanZheng-Regular.ttf"),
]


def collect_charset() -> set[str]:
    chars: set[str] = set(EXTRA)
    for path in SOURCES:
        if not path.exists():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        chars.update(text)
    chars = {c for c in chars if c.isprintable() or c == " "}
    return chars


def main() -> int:
    chars = collect_charset()
    OUT.mkdir(parents=True, exist_ok=True)
    text_file = ROOT / "tools" / "fonts-cache" / "charset.txt"
    text_file.parent.mkdir(parents=True, exist_ok=True)
    ordered = "".join(sorted(chars))
    text_file.write_text(ordered, encoding="utf-8")
    print(f"charset: {len(chars)} characters -> {text_file.relative_to(ROOT)}")

    for source_name, out_name in FONTS:
        source = CACHE / source_name
        if not source.exists():
            print(f"  !! missing source font {source.name}; run prepare_assets.py first",
                  file=sys.stderr)
            continue
        target = OUT / out_name
        cmd = [
            sys.executable, "-m", "fontTools.subset", str(source),
            f"--text-file={text_file}",
            "--layout-features=*",
            "--no-hinting", "--desubroutinize", "--drop-tables+=DSIG",
            f"--output-file={target}",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  !! subset failed for {source_name}\n{result.stderr}", file=sys.stderr)
            continue
        print(f"  {source_name} {source.stat().st_size // 1024} KB -> "
              f"{target.name} {target.stat().st_size // 1024} KB")

    for licence in CACHE.glob("*-OFL.txt"):
        (OUT / licence.name).write_bytes(licence.read_bytes())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
