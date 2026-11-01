# 《妖怪夜市》v0.3.0 — Godot 原生 2D 全端移植

中式夜市题材的车道塔防。玩家是夜市摊主，用「香火」种草木，挡住从右往左过来的「恶客」。
本工程把 **v0.2.4（JS + Canvas）的全部内容**用 Godot 4.7 原生 2D 重做，并统一了美术与界面。

- 编辑器：Godot **4.7.2 stable**（GL Compatibility 渲染后端）
- 语言：GDScript；场景只有一个 `scenes/main.tscn`，其余界面由代码构建
- 版本：`0.3.0`（`project.godot` 的 `application/config/version`，窗口标题为「妖怪夜市 v0.3.0」）
- 成品：`build/YokaiNightMarket.exe`（单文件，内嵌 pck）

## 1. 跑起来

```
编辑：用 Godot 4.7.2 打开本目录的 project.godot
运行：godot --path . （或编辑器里 F5）
构建：powershell -ExecutionPolicy Bypass -File build.ps1
```

`build.ps1` 依次做：导入资源 → 同步立绘与字体子集 → 三套自动检查 → 导出 Windows 单文件。
构建产物在 `build/YokaiNightMarket.exe`；单人玩家存档与设置在 `%APPDATA%\YokaiNightMarket\`。

操作：鼠标左键选卡 / 落子 / 选中草木，右键取消；`Esc` 取消或返回，`空格`/`P` 暂停，
`F11` 全屏。选卡后用数字键 `1–9` 也可快速切牌。

## 2. 内容与 v0.2.4 的对应关系

| 旧版（www/src） | 本作入口 | 状态 |
| --- | --- | --- |
| 18 种草木 `content.js` | `data/content.gd` `PLANTS` | 全量，数值一致 |
| 12 种恶客 `content.js` | `data/content.gd` `ZOMBIES` | 全量，含护具/轿壳分身/跳幡/发甲 |
| 三天十五夜 15 关 `content.js` | `data/content.gd` `LEVELS` | 全量，威胁 0.8—3.0，十二波构成同源 |
| 三路升阶 13 株 ×3 路 ×3 级 `upgrade.js` | `data/upgrades.gd` | 全量，含 `UPGRADE_COST_SCALE` 与「两路/一路三级」约束 |
| 逐阶数值表 `PLANT_EFFECTS` | `data/upgrades.gd` `EFFECTS` | 全量 |
| 图鉴 30 篇 `content/almanac.js` | `data/almanac.gd` | 来历/引语原文照搬；**本事与底细改由数据表推导** |
| 战斗主循环 `game.js`（152 个方法） | `scripts/sim.gd` | 重写为纯逻辑层，规则逐条对齐 |
| 绘制 `art.js` / `mapart.js` / `newart.js` | `scripts/unit_view.gd` / `board_view.gd` | 立绘沿用 v0.2.4 成套原画，动作与特效程序化补足 |
| 界面 `ui.js` / `levels.js` / `almanac.js` | `ui/screen_*.gd` | 重新排版（见 §4） |
| 存档 `storage.js` | `scripts/game.gd` | 新格式（JSON，`user://run.json` 等），不读旧 WebView2 存档 |
| 教学关 / 训练场 / 作弊 | `sim.start_tutorial()`、`ui/screen_hud.gd` | 全量，教学第二/三步已修 |

**没有移植的一项**：旧版「音乐风格：朴素 / 激昂」双轨。旧「朴素」是 Web Audio 实时声学建模，
属于旧技术栈；本作只保留 v0.2.4 的四条 OGG（菜单/常态/白热化/最终），按波次自动切换。
这一点写在更新说明里，不算静默删减。

## 3. 目录

```
data/content.gd      草木 / 恶客 / 三天 / 十五夜 / 波次构成
data/upgrades.gd     三路升阶树、费用系数、逐阶数值表、path_status
data/almanac.gd      图鉴文案（来历/引语手写）+ 本事与底细（由数据推导）
scripts/geo.gd       棋盘几何（9 列，行数与格高随关卡变）
scripts/sim.gd       对局模拟：种植/升阶/索敌/射弹/状态/护具/波次/门神/训练/教学/存档
scripts/board_view.gd 三天地图底、格子、水面与物件、悬停与射程、门神
scripts/unit_view.gd  草木 / 恶客 / 射弹 / 香火 / 粒子 / 飘字；护罩光弧与状态标记
scripts/theme.gd      配色、字体、控件样式、立绘图标
scripts/game.gd       屏幕状态机、输入、音频、设置与存档
ui/screen_*.gd        封面 / 选关 / 备战 / 局内 HUD / 图鉴 / 设置 / 训练菜单
tools/                资源与字体脚本、三套自动检查
qa/                   检查结果 JSON、日志与截图
```

## 4. 这一版的美术与界面改动

1. **字体**：正文换成 LXGW 文楷（SIL OFL），标题用马善政毛笔字；两者都做了**子集化**
   （`tools/subset_fonts.py`，只保留游戏里实际出现的 1200 余字），字库从 50MB 压到 1.9MB。
2. **排版**：封面「门楼」、选关三天三列、备战「名册 / 卡组」分栏、局内左经济右工具、
   图鉴左名录右书页。旧版训练备战文字交叠、HUD 裁切一类问题在结构上不再可能出现。
3. **场内描格子写进设置**：设置 → 显示 → 「场内描格子」，可关掉每一格的线只留外框。
4. **草木与妖怪的差异化**：33 张立绘沿用同一套画风，但每株/每种各有自己的待机节奏、
   光色、受击与出手特效（`unit_view.gd` 的 `PLANT_IDLE` / `PLANT_GLOW` / `ZOMBIE_GLOW`），
   护具不再叠一层手绘帽子盖住原画，改为护罩光弧 + 型号色徽记 + 头顶双段血条。
5. **修掉旧版四个已知缺陷**：教学香火不再过期（旧版落地后被改成 10 秒）、
   教学里的升阶费用由数据表取值（旧版写死 75，实际 90）、训练备战不再文字交叠、
   结算文案不再写「十夜」。

## 5. 验证

`build.ps1` 会跑三套检查，全部通过才会导出（共 165 项）：

| 套件 | 入口 | 覆盖 |
| --- | --- | --- |
| 逻辑检查 88 项 | `tools/qa_logic.gd` | 内容表、升阶约束与费用、状态不叠加、护具与尸体、三天地图规则、波次倍率、训练场、教学关、存档往返 |
| 自动对局 34 项 | `tools/qa_battle.gd` | 第一夜 / 第六夜用正常经济+冷却真打通关、暗河水面机制、不设防必失守、中段存档续局、教学关全流程 |
| 界面联调 43 项 | `tools/ui_selftest.gd` | 封面→选关→备战→对局→升阶→暂停→图鉴→设置→结算→继续守夜，每一步的状态与扣费 |

结果写在 `qa/logic-tests.json`、`qa/battle-tests.json`、`qa/ui-tests.json`；截图在 `qa/shot-*.png`。

**已验证**：Windows 10/11 x64 上独立 exe 冷启动、窗口标题、封面/对局/图鉴渲染；
1280×720、1440×810、1600×900 三种窗口尺寸排版正常。

**未验证**：macOS / Linux / Web / Android / iOS 均未构建、未实测；移动端触控、安全区、
跨平台字体与音频尚未处理。混音未做人耳精调。第 15 夜等后期关卡的「人手可通性」没有结论——
脚本策略只能证明第一夜与第六夜可通，暗河只推进到第 8 波，不能当作平衡结论。

## 6. 素材与授权

- 立绘 33 张、三天地图、封面、四条配乐沿用 v0.2.4 项目内的既有素材（本项目自有）。
- 字体：LXGW 文楷（SIL Open Font License 1.1）、马善政（SIL OFL 1.1），授权文本在 `assets/fonts/`。
- 引擎：Godot Engine 4.7.2，MIT；导出包的声明见 `LICENSE_Godot.txt`、`THIRD_PARTY_Godot.txt`。
- 对外文案不使用任何外部作品的专名；机制说明一律用本作自己的说法（夜莲 / 缠魂藻 等）。
