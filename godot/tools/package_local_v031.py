"""Refresh the local v0.3.1 archives without touching GitHub or version fields."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent
RELEASES = ROOT / "releases"
RELEASE = RELEASES / "v0.3.1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_zip(path: Path, files: dict[str, bytes]) -> None:
    temporary = path.with_suffix(path.suffix + ".new")
    with ZipFile(temporary, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
        for name in sorted(files):
            archive.writestr(name, files[name])
    with ZipFile(temporary) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"CRC mismatch in {bad}")
    os.replace(temporary, path)


def main() -> None:
    win_zip = RELEASES / "妖怪夜市v0.3.1_win64.zip"
    src_zip = RELEASES / "妖怪夜市v0.3.1_源码.zip"
    with ZipFile(win_zip) as archive:
        win_names = archive.namelist()
    win_files = {name: (RELEASE / name).read_bytes() for name in win_names}
    replace_zip(win_zip, win_files)

    with ZipFile(src_zip) as archive:
        old_names = set(archive.namelist())
        source_files = {name: archive.read(name) for name in old_names}
    for name in old_names:
        disk_file = PROJECT / name
        if disk_file.is_file():
            source_files[name] = disk_file.read_bytes()
    for directory in ("assets", "data", "scenes", "scripts", "ui", "tools"):
        for disk_file in (PROJECT / directory).rglob("*"):
            if not disk_file.is_file():
                continue
            relative = disk_file.relative_to(PROJECT)
            if any(part in {"__pycache__", "fonts-cache"} for part in relative.parts):
                continue
            if disk_file.suffix in {".pyc", ".tmp"}:
                continue
            source_files[relative.as_posix()] = disk_file.read_bytes()
    for name in ("ART_ARMOR_REWORK.md", "README.md", "project.godot", "build.ps1", "export_presets.cfg"):
        source_files[name] = (PROJECT / name).read_bytes()
    source_files["更新说明.txt"] = (RELEASE / "更新说明.txt").read_bytes()
    replace_zip(src_zip, source_files)

    with ZipFile(win_zip) as archive:
        bundled_exe = hashlib.sha256(archive.read("YokaiNightMarket.exe")).hexdigest()
    exported_exe = sha256(RELEASE / "YokaiNightMarket.exe")
    if bundled_exe != exported_exe:
        raise RuntimeError("Windows archive executable does not match release executable")
    print(f"win64 entries={len(win_files)} bytes={win_zip.stat().st_size} sha256={sha256(win_zip)}")
    print(f"source entries={len(source_files)} bytes={src_zip.stat().st_size} sha256={sha256(src_zip)}")
    print(f"exe bytes={(RELEASE / 'YokaiNightMarket.exe').stat().st_size} sha256={exported_exe}")


if __name__ == "__main__":
    main()
