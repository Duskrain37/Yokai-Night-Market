# 妖怪夜市 v0.5.5

PC版可携带十二株草木，新增岁灯榕、镇霄炮，重绘烟花童三路满阶形态，并修正增益、灰烬退场和噩梦说明。更新内容见 [v0.5.5公告](V055_CHANGES.md)。本轮仅更新电脑版，安卓独立分支仍为 v0.5.3-mobile。

## 已发布版本：下载后直接启动

1. [下载 Windows 64 位可执行文件](https://github.com/Duskrain37/Yokai-Night-Market/releases/latest/download/YokaiNightMarket-win64.exe)。
2. 下载完成后，双击 `YokaiNightMarket-win64.exe` 启动游戏。单文件无需安装或解压。
3. 安卓手机请[下载 APK](https://github.com/Duskrain37/Yokai-Night-Market/releases/download/v0.5.3-mobile/YokaiNightMarket-android.apk)，允许浏览器安装此 APK 后，点开游戏图标即可游玩。横屏运行，支持 ARM64 / ARMv7，Android 7.0 及以上、OpenGL ES 3.0；建议至少预留 2 GB 存储空间。
4. 更新公告见[最新发布页](https://github.com/Duskrain37/Yokai-Night-Market/releases/latest)。

中式怪谈题材的车道塔防。用香火请草木出摊，在灯火与水道之间守住夜市。

## 内容与操作

- 五章二十五夜，另有独立特殊关「鬼市深处」。32 种草木、27 种恶客（鬼新娘随喜轿出现）、5 位原创恶首。
- 每章五关分别4、4、6、6、8大波；进度每次展示四波，进入下一组时翻页。旗帜与执幡客在每大波的最后一拨登场。
- 每章关底的最后一大波迎战恶首。第五周关底第四大波还会先遭遇限制形态的玄冥判官。
- 鬼市深处二十大波，每四波清完迎战一位恶首，阵容和香火保留。第五位恶首退散后通关。
- 23 株可进化草木各有三条路线，最多开启两路，只有一路能到三阶。部分三阶有专属形态和对应动作帧，逐云鸢、清账匣和烬翼蝉各有三种三阶外观。
- 首次守夜可先学教程。每周初夜相对平和，第二至四夜各有不同挑战，第五夜迎来最凶险的来客。五张地图各有推荐卡组，在备战页可查看今夜主题、来客与恶首录。

左键选卡、落子或查看草木，右键取消。点青铜起土铲后可拆除龟甲罩或移除草木。数字键1–9、0、-、=切换最多十二张卡牌，空格/P暂停，Esc返回或取消，F11切换全屏。方括号键调整倍速，选卡与倍速可在设置中改键。显示设置支持更大的字号、阶别形状和战斗文字提醒。战场右上角可随时切换 0.1、1、1.5、2、3 倍速，每场从 1 倍速开始。若卡关，可在设置里开启作弊菜单补充香火。

Windows 成品为单文件，下载后双击运行。玩家数据位于 `%APPDATA%\YokaiNightMarket\`。封面可切换三个独立对局存档槽，每槽留存最近一次守夜结局。旧版进行中的对局自动迁到第一槽。

## 本次更新

- 常规携带上限增至十二株，战斗牌栏与备战卡组重新排布；新增限带十株／八株的噩梦因子，分别计一／三因子。噩梦说明可滚动阅读。
- 岁灯榕随年轮成长、增加产出，可进化为连射与庇佑、明视、同心；镇霄炮锁定密集来客，一点五秒后全额范围轰击。两株均有本体、三路满阶独立形态和32帧待机、攻击。
- 烟花童三路满阶分别改为双筒双响、牡丹重炮、月架星箭，各自配套32帧动作。
- 攻击加成与生产节奏分开计算；五窍灵枢独立承受增伤并与原弹增伤乘算，放弹节奏不受攻速影响。灰烬击退不留尸体。
- 签筒全队额外弹叠加上限提高至五支；五路巡灯、透骨针、汤圆仔、铜铃的能力及费用同步调整，具体效果可在图鉴与升阶页查看。
- 移除“一夜重签”及其三张专用关卡。五周二十五夜、鬼市深处、自由训练、噩梦因子挑战保留。
- 本版本也包含此前本地完成的噩梦红星与十四种因子、独立双恶首、篁音簇、五窍灵枢、纸鸢鬼、授牌使与五桨阴舟等内容。移动版维持 v0.5.3-mobile。

## 从源码运行

Godot 4.7.2、GDScript、原生2D，GL Compatibility。用对应编辑器打开 `project.godot`，按F5运行，不需要旧JS工程、图像生成服务或联网。

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -GodotPath "C:\path\to\Godot_console.exe"
```

Windows导出需要同版本模板。当前 `export_presets.cfg` 指向工作区便携模板 `../../tmp/godot-tools/templates/`；其他机器请将两个 `custom_template` 路径改为自己的模板路径，或清空并安装Godot默认模板。Python构建步骤使用Pillow、fonttools；numpy仅用于重制音效。运行素材与字体子集均已提供。

`build.ps1` 导入资源、处理字体和戳记，通过检查后导出 `build/YokaiNightMarket.exe`。本机曾在并行重导字体时发生原生崩溃，已改为串行导入，并使相同字表跳过重写；此编辑器设置不影响正式运行。设置说明见[Godot文档](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html#class-projectsettings-property-editor-import-use-multiple-threads)。

## 验证与维护

- `qa_logic.gd`、`qa_battle.gd`：规则、进化、正常费用与冷却对局、存档。
- `qa_boss.gd`、`qa_boss_balance.gd`：恶首事务、参考阵容与多个种子模拟。
- `qa_special.gd`、`qa_v050.gd`：五恶首衔接、双形态、地形和换岸。流程检验使用清敌辅助。
- `qa_sweep.gd`：四档各25夜，同长前四波压力比较、扩展普通波总量和100场策略基线；支持分难度独立复验。
- `trim_export.py`：打包后校验全部动画清单和包内逐文件内容，剔除停用资源并去重。每次追加内容先完成运行验收，再更新裁剪依据。
- `ui_selftest.gd`、`qa_click.gd`、`qa_player_ui.gd`：界面、视口事件点击、全部备战按钮边界、图鉴和进化文案。

结果在 `qa/`，最终包哈希见发布验收记录。固定阵容模拟不是人类实时试玩，不代表所有卡组都在两分钟内击败恶首。本轮验证仅覆盖PC；安卓验收属于保留的v0.5.3-mobile，未重新封装。

历史规则入口见 `V040_IMPLEMENTATION.md`，本版骨骼范式与动画接入见 `ANIMATION_RIG.md`。后续波次进度仍四波一页；玩家界面只用条形表示凶险度，不显示系数与开发说明。

## 授权与素材

引擎、字体声明见仓库的 Godot MIT、第三方与 OFL 文件。新增美术由内置图像生成工具制作，提示词和区域表随源码提供。第四、第五周的六首新曲由本地 songgeneration-mcp 调用 ACE-Step 1.5 制作。


后续默认仅PC；GitHub发布附件仅EXE，不另封源码压缩包。`build.ps1 -VerifyOnly`只验证不导出。100场四档基线在`data/qa_campaign_baseline.json`，绑定机器人策略SHA与内容记录；改策略或出怪表后必须显式审查并重新记录，不能跨策略比较胜负。自动对局结果说明这套机器人，不代表玩家无法通关。
