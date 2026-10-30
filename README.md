# 妖怪夜市 v0.2

PvZ-like 5×9 车道塔防，中式夜市题材。当前版本包含 8 张卡、6 种僵尸、十关、备战镜头、10 个出战槽位、三档清晰度与四套合成音乐。

## 直接运行
- 双击 `release/妖怪夜市v0.2.exe`。这是单文件 exe，不需要旁边的 `www` 或 DLL。
- 首次启动会把内置资源解包到 `%LOCALAPPDATA%/YaoguaiNightMarket/runtime`。
- 环境：Windows 10/11 x64，需要系统 WebView2 Runtime（Win11 与大部分更新过的 Win10 自带；缺失时安装 Microsoft Edge WebView2 Runtime）。
- 存档在 `%LOCALAPPDATA%/YaoguaiNightMarket/WebView2`。

## 源码结构
- `www/`：完整游戏前端、2560×1440 背景、角色贴图与 Web Audio 音频。
- `shell/`：单文件 WebView2 壳，含 `Program.cs`、`build.ps1` 与 WebView2 依赖。
- `开发模式.bat`：本地开发服务器。
- `CODEX_PROJECT_CONTEXT.md`：项目上下文与开发记录。

## 重新生成单文件 exe
```powershell
powershell -ExecutionPolicy Bypass -File shell/build.ps1 -Version 0.2 -Force
```

音乐与音效为 Web Audio 实时合成，尚未做人耳精调混音。
