"""用智谱 CogView 出一批美术图（Key 从环境变量 ZHIPU_API_KEY 读，绝不落盘）。

用法：
  python tools/zhipu_gen.py 任务.json 输出目录

任务.json 是一串对象：
  [{"name": "mower-day1", "size": "768x1344", "prompt": "..."}, ...]

已生成的同名文件会跳过（便于断点续跑）。
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

API = "https://open.bigmodel.cn/api/paas/v4/images/generations"


def generate(prompt: str, size: str, model: str) -> str:
    key = os.environ.get("ZHIPU_API_KEY", "").strip()
    if not key:
        raise SystemExit("缺少环境变量 ZHIPU_API_KEY")
    body = json.dumps({"model": model, "prompt": prompt, "size": size}).encode()
    req = urllib.request.Request(API, data=body, method="POST")
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.loads(resp.read().decode())
    return data["data"][0]["url"]


def download(url: str, dst: Path) -> None:
    with urllib.request.urlopen(url, timeout=180) as resp:
        dst.write_bytes(resp.read())


def main() -> None:
    jobs_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs = json.loads(jobs_path.read_text(encoding="utf-8"))
    for job in jobs:
        name = job["name"]
        dst = out_dir / f"{name}.jpg"
        if dst.exists() and dst.stat().st_size > 20000:
            print(f"  跳过 {name}（已有）")
            continue
        for attempt in range(3):
            try:
                url = generate(job["prompt"], job.get("size", "1024x1024"),
                               job.get("model", "cogview-3-flash"))
                download(url, dst)
                print(f"  {name}  {dst.stat().st_size // 1024} KB")
                break
            except Exception as exc:                      # 限流/网络都重试
                print(f"  {name} 第 {attempt + 1} 次失败: {exc}")
                time.sleep(4 + attempt * 4)
        else:
            print(f"  {name} 放弃")
        time.sleep(1.5)


if __name__ == "__main__":
    main()
