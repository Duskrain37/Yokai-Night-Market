# v0.5.6 差量更新说明

## 玩家使用

1. 第一次从GitHub下载 `YokaiNightMarket-win64.exe`（v0.5.6或更新），双击直接启动。
2. 封面右上角点“检查更新”。新版可用时自动准备；扫描与合成期间仍显示进度。
3. 点“重启并完成更新”。游戏先保存进度，再退出、替换并重新打开。
4. “停止更新”保留已校验的片段。断网或校验失败可重试；不必重新下载已成功的部分。

EXE应放在本人可写入目录，建议预留约2GB空间。已有版本可继续离线游玩；更新需要能访问GitHub。v0.5.5及更早没有此按钮，必须先手动下载一次。网络限制或服务器不支持分段时，界面会提示重试；可自行从发布页手动获取完整EXE，程序不会暗中改为全量下载。

## 发布规范

同一正式发布必须同时提供两个附件：

- `YokaiNightMarket-win64.exe`：完整、可直接运行的Windows成品。
- `YokaiNightMarket-update-map.json`：schema=1，版本、构建哈希、EXE总长度和SHA256，以及连续覆盖整个EXE的资源边界分块。由 `tools/update_manifest.py` 在最终裁剪EXE之后生成。

无需额外发布全量资源包、源码ZIP或逐版本补丁链。客户端读取固定仓库的latest正式发布，不读取移动版、草稿或预发布；即使跳过中间版本，仍可直接复用本地片段、升级到最新。小版本按既定规则覆盖原PC分支并改名，设为默认分支和latest；移动分支保持原样。

GitHub发布API提供附件的SHA256 `digest` 字段，客户端使用它核对索引和最终EXE；资料见[GitHub Release Assets](https://docs.github.com/en/rest/releases/assets)。这依赖GitHub HTTPS及仓库发布权限，不是独立的代码签名。

```powershell
python tools/update_manifest.py build/v0.5.6/YokaiNightMarket.exe --version 0.5.6 --build 构建哈希 --out ../releases/v0.5.6/YokaiNightMarket-update-map.json --compare ../releases/v0.5.5/YokaiNightMarket.exe
```

切勿在生成索引后修改EXE。上传后须核对两附件的大小及digest，实际请求EXE的HTTP206片段并核对Content-Range。

## 实现与限制

`delta_update.gd`按Godot嵌入包的资源边界分块，块内上限1MiB。扫描本地EXE建立SHA256索引，资源在新版中移动位置仍能复用；缺失相邻片段合并为最多4MiB的Range请求。缺失块逐块校验，完整重建后再次校验EXE总SHA256。当前支持Godot PCK格式4、Windows x64单文件、2GiB以下EXE。更换打包格式前必须同步分块器与QA。

扫描与合成在工作线程中执行。下载用Godot自带[HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)，关闭gzip、设置超时和响应上限。必须收到准确HTTP206、长度、Content-Range与块摘要；不接受返回完整EXE的HTTP200，不自动全量回退。已验证块存在 `user://updates/<目标SHA256>/`；成功安装后清除此目标的片段缓存，取消或失败保留以便继续。

候选文件以EXE旁的 `.update-<摘要前12位>.part` 保存；更新前检查可写权限和磁盘空间。现用EXE不在下载或合成时改动。

`update_installer.gd`通过[Godot OS进程接口](https://docs.godotengine.org/en/stable/classes/class_os.html)启动Windows系统自带PowerShell隐藏助手，不依赖Python、第三方运行库、管理员权限或额外下载的脚本。路径使用UTF8 base64，脚本使用UTF16编码参数。助手再验候选SHA256，最多等待原进程45秒，然后把旧文件保留为 `.previous`，换入新文件并打开游戏。游戏完成主界面加载后回写对应构建哈希；90秒内未确认启动则终止该子进程、恢复旧文件。只清理自己约定的文件，不触碰存档、音乐或其他EXE。

更新助手本身没有新增自动提权、防火墙或安全软件配置。系统策略禁止启动助手时会保留原版本并提示重试或手动下载。

## 已做的独立验证

- Python与Godot对v0.5.5 EXE的2793个块位置完全一致。
- 实际公开GitHub附件Range请求返回HTTP206及正确字节范围。
- 本地HTTP服务分别模拟拒绝Range、错误块、取消、部分成功后中断、恢复下载与缓存全复用；最终重建文件与目标EXE逐字节一致，原EXE始终未改。
- Windows真实进程测试覆盖正常替换及启动确认、启动即退出的回滚、错误候选不替换；覆盖中文、空格和单引号路径及缓存清理。
- 普通与最大字号的检查、下载、准备完成、失败界面均渲染验收，弹窗全部位于视野内。

这些是程序与Windows安装链的验证，不代表所有安全软件、代理、磁盘故障均已穷举测试。

## 本次最终成品的差量结果

目标EXE 895,521,524字节；相对v0.5.5可复用890,717,911字节，25个缺失块合计4,803,613字节（0.536%）。带少量区间间隙的实际Range传输4,804,491字节；中断后仅需补546,578字节，完整缓存再试0字节。重建SHA256与正式EXE一致。此为特定两版实测，未来下载量取决于修改的资源，不承诺每版固定大小。
