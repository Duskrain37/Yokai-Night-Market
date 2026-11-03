"""用与「三天配乐包 v2」同一套母带链，重做通用四条配乐（menu / battle / hot / final）。

背景：现役这四条是早期「单程 loudnorm」产物，loudnorm 会在文件里加时变增益，
对循环素材等于每圈一次音量爬坡（实测首尾差 battle 1.85 / hot 2.02 / final 6.18 /
menu 7.86 dB）。这里改成「测量 + 固定增益」的时不变做法，并沿用配乐包的
无缝循环与去刺耳链路。

链路（每一条）：
  1. 读 48 kHz / f32 源（nightmarket/tmp/music-gen/<name>.wav）；
  2. 去刺耳 EQ：highpass 32 Hz + 160 / 2700 / 3600 / 5200 peaking + 9 kHz treble。
     final 原本不扎，只撤旧提升、不加新凹陷，所以只留 highpass；
  3. 等功率循环交叉淡化：头部 X 秒与原曲尾部混合，输出长度 = 原长 − X，
     循环点两侧是原曲相邻采样，接缝天然连续；X 在 0.46—1.92 秒（2—4 拍）内搜索，
     取接缝首尾 50 ms 能量差最小的一条；
  4. ebur128 测整体响度 → 一次性固定增益到 −17.0 LUFS（时不变，不会每圈爬坡）；
  5. 峰值前视限制到 −1.5 dBFS；
  6. 编码 44.1 kHz 立体声 OGG q6，写回 assets/music/（旧文件先备份）。

运行：python tools/master_common_tracks.py
      加 --dry 只测量不写文件。
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent          # nightmarket/godot
WORKSPACE = ROOT.parent.parent                          # 神秘创作
SOURCE = WORKSPACE / "tmp" / "music-gen"               # 原始 48k 母带
OUT = ROOT / "assets" / "music"
BACKUP = WORKSPACE / "tmp" / "audio-backup-generic"
FFMPEG = Path(r"C:\TempD\Python313\Lib\site-packages\imageio_ffmpeg\binaries"
              r"\ffmpeg-win-x86_64-v7.1.exe")
# ffmpeg 这个 build 打不开含中文的路径（fopen 走 ANSI），中间文件统一放到纯 ASCII 目录
STAGE = Path(r"C:\TempD\ynm-audio")
RATE = 44100
TARGET_LUFS = -17.0
PEAK_LIMIT_DB = -1.5

# 与配乐包 day1 的母带 EQ 相同；final 只撤旧提升
EQ = {
    "menu": "highpass=f=32,equalizer=f=160:t=q:w=0.9:g=-1.2,"
            "equalizer=f=2700:t=q:w=1.5:g=-1.8,equalizer=f=3600:t=q:w=1.8:g=-1.5,"
            "equalizer=f=5200:t=q:w=2.0:g=-1.0,treble=f=9000:w=0.6:g=-1.2",
    "final": "highpass=f=32",
}
EQ_DEFAULT = EQ["menu"]


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, check=True, **kw)


def staged_source(name: str) -> Path:
    """把源文件复制到 ASCII 临时目录，绕开 ffmpeg 的中文路径问题。"""
    STAGE.mkdir(parents=True, exist_ok=True)
    target = STAGE / f"src-{name}.wav"
    if not target.exists() or target.stat().st_size != (SOURCE / f"{name}.wav").stat().st_size:
        shutil.copyfile(SOURCE / f"{name}.wav", target)
    return target


def decode(name: str) -> np.ndarray:
    """48k 源 → EQ + 44.1k 立体声 float32（形状 [n, 2]）。"""
    chain = EQ.get(name, EQ_DEFAULT)
    cmd = [str(FFMPEG), "-hide_banner", "-loglevel", "error", "-i",
           str(staged_source(name)), "-af",
           f"{chain},aresample={RATE},aformat=sample_fmts=flt:channel_layouts=stereo",
           "-f", "f32le", "-"]
    raw = run(cmd).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def rms_db(block: np.ndarray) -> float:
    value = float(np.sqrt(np.mean(block ** 2)) + 1e-12)
    return 20.0 * np.log10(value)


def trim_fades(audio: np.ndarray, keep_ratio: float = 0.5) -> tuple[np.ndarray, float, float]:
    """掐掉生成模型自带的淡入淡出：否则尾部是被压低的一段，混进开头就是一圈掉音量。"""
    hop = int(0.05 * RATE)
    frames = len(audio) // hop
    block = audio[:frames * hop].reshape(frames, hop, 2)
    rms = np.sqrt((block ** 2).mean(axis=(1, 2)))
    threshold = float(np.median(rms)) * keep_ratio
    start_frame = 0
    for i in range(max(0, frames - 4)):
        if np.all(rms[i:i + 4] > threshold):
            start_frame = i
            break
    end_frame = frames
    for i in range(frames - 1, 3, -1):
        if np.all(rms[i - 4:i] > threshold):
            end_frame = i + 1
            break
    return (audio[start_frame * hop:end_frame * hop],
            start_frame * hop / RATE, end_frame * hop / RATE)


def make_loop(audio: np.ndarray, crossfade: float) -> np.ndarray:
    """头部 X 秒与原曲尾部等功率混合，输出长度 = 原长 − X。"""
    n = len(audio)
    x = max(1, int(round(crossfade * RATE)))
    if x * 2 >= n:
        raise ValueError("交叉淡化比曲子还长")
    loop_len = n - x
    out = audio[:loop_len].copy()
    a = np.linspace(0.0, np.pi / 2, x, endpoint=False)[:, None]
    tail = audio[loop_len:loop_len + x]
    out[:x] = tail * np.cos(a) + audio[:x] * np.sin(a)
    return out


def seam_db(out: np.ndarray) -> float:
    """接缝处「首 50 ms」与「尾 50 ms」的能量差（dB）。"""
    w = int(0.05 * RATE)
    return abs(rms_db(out[:w]) - rms_db(out[-w:]))


def search_crossfade(audio: np.ndarray) -> tuple[float, float]:
    best = (0.0, 1e9)
    for step in range(0, 38):
        crossfade = 0.46 + step * 0.04
        if crossfade >= 1.92:
            break
        out = make_loop(audio, crossfade)
        score = seam_db(out)
        if score < best[1]:
            best = (crossfade, score)
    return best


def measure_lufs(audio: np.ndarray, tag: str) -> float:
    STAGE.mkdir(parents=True, exist_ok=True)
    tmp = STAGE / f"_lufs_{tag}.wav"
    write_wav(tmp, audio)
    result = subprocess.run(
        [str(FFMPEG), "-hide_banner", "-nostats", "-i", str(tmp), "-af",
         "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True)
    text = result.stderr
    integrated = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("I:") and "LUFS" in line:
            integrated = float(line.split()[1])
    tmp.unlink(missing_ok=True)
    if integrated is None:
        raise RuntimeError("ebur128 没读到整体响度：\n" + text[-800:])
    return integrated


def write_wav(path: Path, audio: np.ndarray) -> None:
    data = audio.astype("<f4").tobytes()
    run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-f", "f32le",
         "-ar", str(RATE), "-ac", "2", "-i", "-", "-c:a", "pcm_f32le",
         str(path)], input=data)


def limit(audio: np.ndarray, ceiling_db: float = PEAK_LIMIT_DB,
          attack_ms: float = 5.0, release_ms: float = 90.0) -> np.ndarray:
    """简单的峰值前视限制器：只压低超过 ceiling 的地方，不整体归一化。"""
    ceiling = 10 ** (ceiling_db / 20.0)
    peak = np.max(np.abs(audio))
    if peak <= ceiling:
        return audio
    need = ceiling / peak
    # 逐样本目标增益（<=1），再前后各平滑一次，避免抽气
    target = np.ones(len(audio))
    over = np.abs(audio).max(axis=1) > ceiling
    target[over] = ceiling / np.abs(audio[over]).max(axis=1)
    attack = max(1, int(attack_ms / 1000 * RATE))
    release = max(1, int(release_ms / 1000 * RATE))
    smoothed = target.copy()
    gain = 1.0
    up = 1.0 / release
    down = 1.0 / attack
    for i in range(len(smoothed)):
        want = target[i]
        rate = down if want < gain else up
        gain += max(-rate, min(rate, want - gain))
        smoothed[i] = gain
    return audio * smoothed[:, None]


def encode(audio: np.ndarray, path: Path) -> None:
    STAGE.mkdir(parents=True, exist_ok=True)
    staged = STAGE / path.name
    data = audio.astype("<f4").tobytes()
    run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le",
         "-ar", str(RATE), "-ac", "2", "-i", "-", "-c:a", "libvorbis",
         "-q:a", "6", str(staged)], input=data)
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(staged, path)


def verify_ogg(path: Path) -> dict:
    """把写出的 OGG 读回来，核对响度、峰值与循环接缝（不只看中间结果）。"""
    raw = run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-i",
               str(path), "-f", "f32le", "-"]).stdout
    audio = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)
    peak = 20 * np.log10(float(np.max(np.abs(audio))) + 1e-12)
    return {
        "seconds": round(len(audio) / RATE, 2),
        "peak_dbfs": round(peak, 2),
        "seam_db": round(seam_db(audio), 2),
        "lufs": round(measure_lufs(audio, "verify"), 2),
    }


def master(name: str, dry: bool = False) -> dict:
    print(f"\n=== {name} ===")
    audio = decode(name)
    total = len(audio) / RATE
    audio, fade_in, fade_out = trim_fades(audio)
    print(f"  去掉首尾淡化：{fade_in:.2f}s … {fade_out:.2f}s（原长 {total:.2f}s）")
    crossfade, score = search_crossfade(audio)
    print(f"  交叉淡化 {crossfade:.2f} s（搜索接缝 {score:.2f} dB）")
    loop = make_loop(audio, crossfade)
    seam_before = seam_db(loop)

    lufs = measure_lufs(loop, f"{name}_pre")
    gain_db = TARGET_LUFS - lufs
    print(f"  响度 {lufs:+.2f} LUFS → 固定增益 {gain_db:+.2f} dB 到 {TARGET_LUFS} LUFS")
    loop = loop * (10 ** (gain_db / 20.0))
    loop = limit(loop)
    # 限制器的增益包络有平滑，可能漏过几个采样；再整体压一丝，保证不超上限
    ceiling = 10 ** (PEAK_LIMIT_DB / 20.0)
    peak_now = float(np.max(np.abs(loop)))
    if peak_now > ceiling:
        loop *= ceiling / peak_now
        print(f"  补一刀 {20*np.log10(ceiling/peak_now):+.2f} dB 压到上限内")
    peak = 20 * np.log10(float(np.max(np.abs(loop))) + 1e-12)
    lufs_final = measure_lufs(loop, f"{name}_post")
    seam_after = seam_db(loop)
    seconds = len(loop) / RATE
    print(f"  峰值 {peak:+.2f} dBFS  响度 {lufs_final:+.2f} LUFS  "
          f"时长 {seconds:.2f}s  接缝 {seam_after:.2f} dB")

    target = OUT / f"{name}.ogg"
    if not dry:
        BACKUP.mkdir(parents=True, exist_ok=True)
        if target.exists():
            shutil.copyfile(target, BACKUP / f"{name}.ogg")
        encode(loop, target)
        print(f"  写出 {target.relative_to(ROOT)} "
              f"{target.stat().st_size/1024/1024:.2f} MB")
        check = verify_ogg(target)
        print(f"  回读校验：{check['seconds']}s  {check['lufs']:+} LUFS  "
              f"峰值 {check['peak_dbfs']:+} dBFS  接缝 {check['seam_db']} dB")
    return {
        "track": name, "crossfade": round(crossfade, 2),
        "seam_before_db": round(seam_before, 2),
        "seam_after_db": round(seam_after, 2),
        "lufs_before": round(lufs, 2),
        "gain_db": round(gain_db, 2),
        "lufs_after": round(lufs_final, 2),
        "peak_dbfs": round(peak, 2),
        "seconds": round(seconds, 2),
    }


def main() -> int:
    dry = "--dry" in sys.argv
    (ROOT / "qa").mkdir(exist_ok=True)
    rows = [master(name, dry) for name in ("menu", "battle", "hot", "final")]
    out = ROOT / "qa" / "master-common-tracks.json"
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print("\n汇总（写进 qa/master-common-tracks.json）")
    for row in rows:
        print(f"  {row['track']:<7} 交叉 {row['crossfade']:4.2f}s  "
              f"响度 {row['lufs_before']:+6.2f} -> {row['lufs_after']:+6.2f} LUFS  "
              f"增益 {row['gain_db']:+5.2f} dB  峰值 {row['peak_dbfs']:+5.2f} dBFS  "
              f"接缝 {row['seam_after_db']:.2f} dB  时长 {row['seconds']:6.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
