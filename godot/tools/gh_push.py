"""GitHub 仓库操作（走 REST API，不需要本地 git）。

用法：
    python tools/gh_push.py inspect                     # 查看分支、默认分支、v0.2.4 树
    python tools/gh_push.py build-branch                # 由 v0.2.4 提交新建 v0.3 分支（树=新工程）
    python tools/gh_push.py release                     # 建 v0.3.0 Release 并上传两个 zip
    python tools/gh_push.py cleanup                     # 只保留 v0.2.4 与 v0.3
    python tools/gh_push.py default-branch              # 把默认分支设成 v0.3

令牌来源：Windows 凭据管理器里的 git:https://github.com（不写进任何文件）。
"""
from __future__ import annotations

import base64
import ctypes
import json
import os
import sys
import time
import urllib.error
import urllib.request
from ctypes import wintypes
from pathlib import Path

OWNER = "Duskrain37"
REPO = "Yokai-Night-Market"
API = "https://api.github.com"
ROOT = Path(__file__).resolve().parent.parent.parent  # nightmarket/
PROJECT = ROOT / "godot"
RELEASE_DIR = ROOT / "releases" / "v0.3.0"
VERSION = "0.3.0"
SOURCE_BRANCH = "v0.2.4"
TARGET_BRANCH = "v0.3"
KEEP_BRANCHES = {"v0.2.4", "v0.3"}

# 新分支的树：只保留这些顶层路径（其余旧文件从树上移除，历史仍在 v0.2.4 分支）
DROP_PREFIXES = ("www/", "shell/", "release/", "releases/", "reviews/", "tmp/")
# 单文件也要从 v0.3 的树上摘掉：旧版开发服务器入口与 v0.2.4 时代的项目记忆
DROP_FILES = {"开发模式.bat", "CODEX_PROJECT_CONTEXT.md"}

DOC_FILES = ["README.md", "更新说明.txt", "游玩说明.txt", "LICENSE_Godot.txt",
             "THIRD_PARTY_Godot.txt", "字体授权_OFL.txt"]


def token() -> str:
    class CREDENTIAL(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD), ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR), ("Comment", wintypes.LPWSTR),
            ("LastWritten", wintypes.FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.POINTER(ctypes.c_byte)),
            ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR), ("UserName", wintypes.LPWSTR),
        ]

    advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)
    ptr = ctypes.c_void_p()
    ok = advapi32.CredReadW(ctypes.c_wchar_p("git:https://github.com"), 1, 0,
                            ctypes.byref(ptr))
    if not ok:
        raise SystemExit("找不到 GitHub 凭据（凭据管理器 git:https://github.com）")
    cred = ctypes.cast(ptr, ctypes.POINTER(CREDENTIAL)).contents
    raw = ctypes.string_at(cred.CredentialBlob, cred.CredentialBlobSize)
    advapi32.CredFree(ptr)
    return raw.decode("utf-16-le")


TOKEN = token()


def call(method: str, path: str, payload=None, raw: bytes | None = None,
         base: str = API, content_type: str = "application/json"):
    url = path if path.startswith("http") else f"{base}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "dsh-nightmarket",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    elif raw is not None:
        data = raw
        headers["Content-Type"] = content_type
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            body = response.read()
            if not body:
                return {}
            return json.loads(body)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:600]
        raise SystemExit(f"{method} {url} -> {exc.code}: {detail}")


def repo() -> dict:
    return call("GET", f"/repos/{OWNER}/{REPO}")


def branch_sha(branch: str) -> str:
    ref = call("GET", f"/repos/{OWNER}/{REPO}/git/ref/heads/{branch}")
    return ref["object"]["sha"]


def commit_info(sha: str) -> dict:
    return call("GET", f"/repos/{OWNER}/{REPO}/git/commits/{sha}")


def tree_paths(sha: str) -> list[dict]:
    out = []
    page = call("GET", f"/repos/{OWNER}/{REPO}/git/trees/{sha}?recursive=1")
    out.extend(page.get("tree", []))
    return out


def cmd_inspect() -> None:
    info = repo()
    print(f"repo: {info['full_name']}  default={info['default_branch']} "
          f"size={info['size']}KB private={info['private']}")
    branches = call("GET", f"/repos/{OWNER}/{REPO}/branches?per_page=100")
    for item in branches:
        print(f"  branch {item['name']:10s} {item['commit']['sha'][:10]} "
              f"protected={item['protected']}")
    sha = branch_sha(SOURCE_BRANCH)
    commit = commit_info(sha)
    print(f"{SOURCE_BRANCH} tip={sha} tree={commit['tree']['sha']} "
          f"parents={[p['sha'][:8] for p in commit['parents']]}")
    entries = tree_paths(commit["tree"]["sha"])
    tops: dict[str, int] = {}
    for entry in entries:
        top = entry["path"].split("/")[0]
        tops[top] = tops.get(top, 0) + 1
    print(f"  tree entries={len(entries)} top-level: {tops}")
    for entry in entries:
        if "/" not in entry["path"]:
            print(f"    {entry['path']} ({entry['type']}, {entry.get('size', '-')})")


def collect_files() -> list[tuple[str, Path]]:
    """要上传到新分支的文件：(仓库内路径, 本地路径)。"""
    files: list[tuple[str, Path]] = []
    for path in sorted(PROJECT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(PROJECT)
        parts = rel.parts
        if parts[0] in {".godot", "build", "qa"}:
            continue
        if len(parts) > 1 and parts[0] == "tools" and parts[1] == "fonts-cache":
            continue
        files.append((f"godot/{rel.as_posix()}", path))
    for name in ("logic-tests.json", "battle-tests.json", "ui-tests.json",
                 "click-tests.json"):
        qa_path = PROJECT / "qa" / name
        if qa_path.exists():
            files.append((f"qa/{name}", qa_path))
    for name in DOC_FILES:
        candidate = RELEASE_DIR / name
        if name == "README.md":
            candidate = PROJECT / "README.md"
        if candidate.exists():
            files.append((name, candidate))
    return files


def cmd_build_branch() -> None:
    info = repo()
    base_sha = branch_sha(SOURCE_BRANCH)
    base_commit = commit_info(base_sha)
    base_tree = base_commit["tree"]["sha"]
    print(f"base {SOURCE_BRANCH} {base_sha[:10]} tree={base_tree[:10]}")

    files = collect_files()
    total = sum(path.stat().st_size for _, path in files)
    print(f"upload {len(files)} files, {total/1024/1024:.1f} MB")

    entries = []
    done = 0
    for repo_path, local in files:
        blob = call("POST", f"/repos/{OWNER}/{REPO}/git/blobs", {
            "content": base64.b64encode(local.read_bytes()).decode("ascii"),
            "encoding": "base64",
        })
        entries.append({"path": repo_path, "mode": "100644", "type": "blob",
                        "sha": blob["sha"]})
        done += 1
        if done % 20 == 0:
            print(f"  {done}/{len(files)}")

    # 旧文件从树上移除（历史仍在 v0.2.4）
    for entry in tree_paths(base_tree):
        path = entry["path"]
        if entry["type"] != "blob":
            continue
        if path in DROP_FILES or path.startswith(DROP_PREFIXES) \
                or path.split("/")[0] in {"www", "shell", "release", "releases",
                                          "reviews", "tmp"}:
            entries.append({"path": path, "mode": entry["mode"], "type": "blob",
                            "sha": None})
    # 被新文件覆盖的同名旧文件不需要额外处理

    tree = call("POST", f"/repos/{OWNER}/{REPO}/git/trees", {
        "base_tree": base_tree,
        "tree": entries,
    })
    print(f"new tree {tree['sha'][:10]}")

    message = (f"v{VERSION}: Godot 原生 2D 全端移植\n\n"
               "把 v0.2.4 的三天十五夜、18 种草木、12 种恶客、完整三路升阶、"
               "备战/图鉴/设置/训练场/教学与存档用 Godot 4.7 重做；\n"
               "字体换成文楷+毛笔字（子集化），界面重排，新增「场内描格子」开关；\n"
               "旧版 www/shell 源码保留在 v0.2.4 分支。")
    commit = call("POST", f"/repos/{OWNER}/{REPO}/git/commits", {
        "message": message, "tree": tree["sha"], "parents": [base_sha],
    })
    print(f"commit {commit['sha'][:10]}")

    try:
        call("POST", f"/repos/{OWNER}/{REPO}/git/refs", {
            "ref": f"refs/heads/{TARGET_BRANCH}", "sha": commit["sha"]})
        print(f"created branch {TARGET_BRANCH}")
    except SystemExit as exc:
        if "422" in str(exc) or "Reference already exists" in str(exc):
            call("PATCH", f"/repos/{OWNER}/{REPO}/git/refs/heads/{TARGET_BRANCH}",
                 {"sha": commit["sha"], "force": True})
            print(f"updated branch {TARGET_BRANCH}")
        else:
            raise
    print(f"branch {TARGET_BRANCH} -> {commit['sha']}")


def cmd_cleanup() -> None:
    info = repo()
    print(f"default branch: {info['default_branch']}")
    if info["default_branch"] not in KEEP_BRANCHES:
        call("PATCH", f"/repos/{OWNER}/{REPO}", {"default_branch": TARGET_BRANCH})
        print(f"默认分支改为 {TARGET_BRANCH}")
    branches = call("GET", f"/repos/{OWNER}/{REPO}/branches?per_page=100")
    for item in branches:
        name = item["name"]
        if name in KEEP_BRANCHES:
            print(f"  keep {name}")
            continue
        print(f"  delete {name} ({item['commit']['sha'][:10]})")
        call("DELETE", f"/repos/{OWNER}/{REPO}/git/refs/heads/{name}")
    left = call("GET", f"/repos/{OWNER}/{REPO}/branches?per_page=100")
    print("remaining:", [b["name"] for b in left])


def cmd_default_branch() -> None:
    call("PATCH", f"/repos/{OWNER}/{REPO}", {"default_branch": TARGET_BRANCH})
    print("default branch ->", repo()["default_branch"])


def cmd_release() -> None:
    tag = f"v{VERSION}"
    body = (RELEASE_DIR / "更新说明.txt").read_text(encoding="utf-8-sig")
    try:
        release = call("POST", f"/repos/{OWNER}/{REPO}/releases", {
            "tag_name": tag,
            "name": f"妖怪夜市 {tag}",
            "body": body[:6000],
            "draft": False,
            "prerelease": False,
            "target_commitish": TARGET_BRANCH,
        })
        print("created release", release["html_url"])
    except SystemExit as exc:
        if "422" not in str(exc) and "already_exists" not in str(exc):
            raise
        release = call("GET", f"/repos/{OWNER}/{REPO}/releases/tags/{tag}")
        print("release exists", release["html_url"])

    # GitHub 的 asset 名对非 ASCII 不友好（传上去会被截成 v0.3.0_.zip），
    # 附件统一用 ASCII 名，中文说明放在 Release 正文与压缩包内。
    assets = [
        (ROOT / "releases" / f"妖怪夜市v{VERSION}_win64.zip",
         f"YokaiNightMarket-v{VERSION}-win64.zip", "application/zip"),
        (ROOT / "releases" / f"妖怪夜市v{VERSION}_源码.zip",
         f"YokaiNightMarket-v{VERSION}-source.zip", "application/zip"),
    ]
    existing = {a["name"]: a for a in release.get("assets", [])}
    for asset in list(existing.values()):
        call("DELETE", asset["url"])
        print("removed old asset", asset["name"])
    existing = {}
    for path, name, mime in assets:
        if not path.exists():
            print(f"!! missing {path}")
            continue
        url = (f"https://uploads.github.com/repos/{OWNER}/{REPO}/releases/"
               f"{release['id']}/assets?name={urllib.parse.quote(name)}")
        for attempt in range(3):
            try:
                asset = call("POST", url, raw=path.read_bytes(), content_type=mime)
                print(f"uploaded {asset['name']} {asset['size']/1024/1024:.1f} MB")
                break
            except SystemExit as exc:
                print(f"attempt {attempt+1} failed: {exc}")
                time.sleep(5)
        else:
            print(f"!! failed to upload {path.name}")
    final = call("GET", f"/repos/{OWNER}/{REPO}/releases/tags/{tag}")
    print("release:", final["html_url"], "assets:",
          [(a["name"], a["size"]) for a in final.get("assets", [])])


def cmd_status() -> None:
    info = repo()
    print("default:", info["default_branch"], "size:", info["size"], "KB")
    for item in call("GET", f"/repos/{OWNER}/{REPO}/branches?per_page=100"):
        print(f"  {item['name']:10s} {item['commit']['sha'][:10]}")
    for item in call("GET", f"/repos/{OWNER}/{REPO}/releases?per_page=20"):
        print(f"  release {item['tag_name']:10s} {item['html_url']} "
              f"assets={[a['name'] for a in item.get('assets', [])]}")


if __name__ == "__main__":
    import urllib.parse  # noqa: F401  (release upload 用)
    cmds = {
        "inspect": cmd_inspect,
        "build-branch": cmd_build_branch,
        "release": cmd_release,
        "cleanup": cmd_cleanup,
        "default-branch": cmd_default_branch,
        "status": cmd_status,
    }
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        print(__doc__)
        raise SystemExit(2)
    globals()["urllib"].parse = urllib.parse
    cmds[sys.argv[1]]()
