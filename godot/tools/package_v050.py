"""Seal the validated standalone v0.5.0 Windows executable."""
import hashlib
import json
import re
import shutil

from package_v040 import PROJECT, ROOT
from stamp_build import source_hash

VERSION = "0.5.0"
RELEASES = ROOT / "releases"
RELEASE = RELEASES / f"v{VERSION}"
QA = PROJECT / "qa"
SUITES = (
    "logic-tests", "battle-tests", "boss-tests", "special-tests", "ui-tests",
    "click-tests", "player-ui-tests", "animation-tests", "v050-tests",
)
EVIDENCE = tuple(f"v050-shot-{scene}.png" for scene in
                 ("loading", "island", "cavern", "boss4", "boss-bound", "boss5", "prep", "almanac-boss")) + (
                     "v050-levels-5.png", "v050-levels-17.png", "v050-levels-22.png")


def load_qa(name):
    return json.loads((QA / f"{name}.json").read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_entries():
    directories = {"assets", "data", "scripts", "scenes", "ui", "tools"}
    for path in sorted(PROJECT.rglob("*")):
        rel = path.relative_to(PROJECT)
        if rel.parts[0] not in directories and len(rel.parts) != 1:
            continue
        if not path.is_file() or any(x in rel.parts for x in {"__pycache__", "fonts-cache"}):
            continue
        if path.suffix in {".pyc", ".tmp", ".exe", ".zip", ".bak"}:
            continue
        yield f"godot/{rel.as_posix()}", path
    for name in [*(f"{s}.json" for s in SUITES), "boss-balance.json",
                 "curve-v040.json", "curve.csv", "patch-tests.log", "pack-audit.json"]:
        yield f"qa/{name}", QA / name
    for path in sorted(RELEASE.iterdir()):
        if path.is_file() and path.suffix != ".exe":
            yield path.name, path


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    stamp, _ = source_hash()
    info = (PROJECT / "data/build_info.gd").read_text(encoding="utf-8")
    assert f'BUILD_HASH = "{stamp}"' in info and f'VERSION = "{VERSION}"' in info
    totals = {}
    for suite in SUITES:
        data = load_qa(suite)
        assert data["failures"] == 0 and data["total"] > 0, suite
        totals[suite] = data["total"]
    build_log = (QA / "build-v050-release.log").read_text(encoding="utf-8-sig")
    assert "SCRIPT ERROR" not in build_log and "Parse Error" not in build_log
    patch_log = (QA / "patch-tests.log").read_text(encoding="utf-8")
    patch = re.search(r"TOTAL (\d+)\s+FAILURES 0", patch_log)
    assert patch and "SCRIPT ERROR" not in patch_log
    totals["patch-tests"] = int(patch[1])
    balance = load_qa("boss-balance")
    assert balance["failures"] == 0 and len(balance["runs"]) == 33
    assert not load_qa("curve-v040")["problems"]
    release_log = (QA / "v050-release-smoke.log").read_text(encoding="utf-8")
    assert "Godot Engine" in release_log and "SCRIPT ERROR" not in release_log
    assert "V050_EXPORT_OK" in release_log
    pack_lines = (QA / "v050-final-pack-check.log").read_text(encoding="utf-8-sig").splitlines()
    pack_check = json.loads(pack_lines[-1])
    assert stamp in pack_lines and pack_check["failures"] == 0 and pack_check["checks"] > 0
    times = [r["combat_s"] for r in balance["runs"] if r["profile"] == "reference"]
    RELEASE.mkdir(parents=True, exist_ok=True)
    exe = RELEASE / "YokaiNightMarket.exe"
    shutil.copy2(PROJECT / "build/v0.5.0/YokaiNightMarket.exe", exe)
    for name in ["README.md", "ANIMATION_RIG.md"]:
        shutil.copy2(PROJECT / name, RELEASE / name)
    shutil.copy2(PROJECT / "V050_CHANGES.md", RELEASE / "更新说明.md")
    for name in ["LICENSE_Godot.txt", "THIRD_PARTY_Godot.txt", "字体授权_OFL.txt"]:
        shutil.copy2(RELEASES / "v0.4.0" / name, RELEASE / name)
    (RELEASE / "游玩说明.txt").write_text(
        "妖怪夜市 v0.5.0\n\n下载 Windows 64 位独立 EXE 后双击启动。第一次守夜建议先完成教程。\n"
        "左键选卡、落子、查看与进化；右键取消。数字键1–9切牌，空格或P暂停，Esc取消或返回，F11全屏。\n"
        "先请红灯笼产香火，再布置输出与阻挡。水面先放夜莲，才可种其他草木。\n"
        "每章第五夜会遇到首领。瞄准它占据的两行，留意出招预警和换行。鬼市深处二十大波，每四波迎战一位首领。\n"
        "进度和设置保存在 %APPDATA%\\YokaiNightMarket\\。新版可直接读取原有进度。\n",
        encoding="utf-8")
    screenshots = RELEASE / "验收画面"
    screenshots.mkdir(exist_ok=True)
    for name in EVIDENCE:
        shutil.copy2(QA / name, screenshots / name)
    record = {
        "version": VERSION, "build_hash": stamp, "exe_bytes": exe.stat().st_size,
        "exe_sha256": digest(exe), "assertions": totals, "assertion_total": sum(totals.values()),
        "failures": 0, "boss_simulations": 33, "boss_reference_seconds": [min(times), max(times)],
        "boss_reference_wins": sum(r["won"] for r in balance["runs"] if r["profile"] == "reference"),
        "boss_legacy_fixture_wins": sum(r["won"] for r in balance["runs"] if r["profile"] != "reference"),
        "motion_frames": sum(len(clip) for actor in json.loads(
            (PROJECT / "data/actor_motion.json").read_text(encoding="utf-8")).values()
            for clip in actor["clips"].values()),
        "pack_trim": load_qa("pack-audit"), "pack_checks": pack_check,
        "platform": "Windows x64", "verification": "自动检查、Windows 导出包启动、实机画面与首领阵容模拟。未做人手二十五夜全通。",
    }
    write_json(RELEASE / "验收记录.json", record)
    checksum = {"exe": record}
    write_json(RELEASES / "v0.5.0_包校验.json", checksum)
    print(json.dumps(checksum, ensure_ascii=False))


if __name__ == "__main__":
    main()
