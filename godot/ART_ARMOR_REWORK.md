# 门神与护具重画记录（2026-11-01）

使用内置 `image_gen.imagegen` 出图，所有目标为透明 PNG。参考现役角色和原护具仅作主题、视角与笔触参考；新文件以 `-v2`、`-atlas` 或 `-unarmored` 命名，旧图没有覆盖。

## 新资源

| 游戏用途 | 文件 | 生成主题 |
| --- | --- | --- |
| 第一周门神 | `assets/sprites/mower-day1-v2.png` | 青灰石狮，朱红系带，干笔水粉、墨线和有限暖光 |
| 第二周门神 | `assets/sprites/mower-day2-v2.png` | 古木铜锣架，铜面旧痕、朱红绳结，干笔水粉 |
| 第三周门神 | `assets/sprites/mower-day3-v2.png` | 洞窟石灯笼，青灰裂石、少量苔痕和暖火 |
| 石帽三态 | `assets/sprites/armor-stonehat-atlas.png` | 石锥帽，完好／缺口裂纹／残破 |
| 纸壳三态 | `assets/sprites/armor-paper-atlas.png` | 折纸护帽，完好／撕裂／残破 |
| 轿壳三态 | `assets/sprites/armor-sedan-atlas.png` | 只保留轿顶与短檐，完好／裂损／残破 |
| 斗笠三态 | `assets/sprites/armor-straw-atlas.png` | 旧草编笠，完好／破边／残破 |
| 陶瓮三态 | `assets/sprites/armor-urn-atlas.png` | 倒扣陶瓮，完好／碎口／残破 |
| 铁面三态 | `assets/sprites/armor-mask-atlas.png` | 古铁面具，完好／裂纹／残破 |
| 轿壳下本体 | `assets/sprites/sedan-unarmored.png` | 两只抬轿小鬼，扛杆但没有轿顶，碎裂后露出 |
| 纸壳下本体 | `assets/sprites/paper-unarmored-v2.png` | 无独立纸盔的纸人本体，墨点眼、残破纸层；碎裂后露出 |

生成提示词共同要求：`Use case: stylized-concept`；参照游戏原立绘的中国民俗、哑光干笔水粉与细墨线；低饱和青灰/褐赭配少量朱红和暖光；一张透明完整角色，或严格三等分的横排护具图集；护具三格同造型、同尺度、同角度，依次完好、受损、残破；不画白底、场景、字、网格、水印、发光青色塑料、光滑 CG。各护具具体主题见上表；轿壳提示词特别约束为**仅轿顶短檐，无抬轿鬼、无整轿身**。门神按每周对应的石狮、铜锣架、石灯笼分别生成。

代码在 `_ready()` 预载图集并按三等分建立 `AtlasTexture`，防止 `_draw()` 中加载贴图出现白块。`UnitView._draw_armor()` 在角色本体坐标系内摆放护具，跟随左右镜像、迈步、倾斜和受击形变；六类均按护甲比例 >66%、>33%、其余三个档位切换。护甲归零时五片图像碎块以不同横速、初始上抛和角速度飞散、重力下落并淡出；致命一击也触发。

## 本轮视觉检查

- `qa/armor-wear-day2.png`：第二周实机战场、门神与常见护具。
- `qa/armor-wear-six-types.png`：六种恶客各戴一种护具，包含不同破损档。
- `qa/armor-break-six-types.png`：六种护具同时碎裂后的中途帧；轿顶和纸盔碎掉后露出新本体。
- `qa/armor-mower-battle.png`、`qa/armor-mower-battle3.png`：第一周与第三周新门神在对应场景中的位置、比例和亮度。
- `qa/armor-release-boot.png`、`qa/armor-release-break.png`：最终单文件 exe 从发布目录隐藏后台冷启动后的穿戴与碎裂帧，证明内嵌素材生效。
- 上述截图用 Godot 隐藏后台窗口导出，未占用主机键鼠；游戏版本号仍为 0.3.1。

最终构建在独立 `build-art/` 完成，逻辑 125、自动对局 34、界面 51、真实视口点击 20，共 230 项，0 失败；导入、导出和测试日志无脚本/资源错误。发布 exe、Windows zip、源码 zip 已更新并校验 CRC、内嵌 exe 哈希一致。发布包可执行文件 190,880,816 字节，SHA-256 `8110565efc8437527a3a978dce5ed2df3bf82a558427dd6dca22a2b862aa01ff`。更新前本地 exe 和两个 zip 备份在工作区 `tmp/v031-before-armor-redraw-20261101/`。本轮没有修改版本号或推送 GitHub。

旧资源和第一版 `paper-unarmored.png` 保留在同目录，便于比较；第一版纸人眼睛偏大，游戏使用墨点眼的 v2。生成结果以实机截图为准；每件护具边缘与特定恶客头部在更大的动画幅度和全部窗口比例下仍可继续微调。
