# 妖怪夜市 v0.5.2

## 下载后直接启动

1. [下载 Windows 64 位可执行文件](https://github.com/Duskrain37/Yokai-Night-Market/releases/latest/download/YokaiNightMarket-win64.exe)。
2. 下载完成后，双击 `YokaiNightMarket-win64.exe` 启动游戏。单文件无需安装或解压。
3. 更新公告见[最新发布页](https://github.com/Duskrain37/Yokai-Night-Market/releases/latest)。

中式怪谈题材的车道塔防。用香火请草木出摊，在灯火与水道之间守住夜市。

## 内容与操作

- 五章二十五夜，另有独立特殊关「鬼市深处」。28 种草木、24 种恶客（鬼新娘随喜轿出现）、5 位原创恶首。
- 每章五关分别4、4、6、6、8大波；进度每次展示四波，进入下一组时翻页。旗帜与执幡客在每大波的最后一拨登场。
- 每章关底的最后一大波迎战恶首。第五周关底第四大波还会先遭遇限制形态的玄冥判官。
- 鬼市深处二十大波，每四波清完迎战一位恶首，阵容和香火保留。第五位恶首退散后通关。
- 19 株可进化草木各有三条路线，最多开启两路，只有一路能到三阶。部分三阶有专属形态和对应动作帧，逐云鸢、清账匣和烬翼蝉各有三种三阶外观。
- 首次守夜可先学教程。每周初夜相对平和，第二至四夜各有不同挑战，第五夜迎来最凶险的来客。五张地图各有推荐卡组，在备战页可查看今夜主题、来客与恶首录。

左键选卡、落子或查看草木，右键取消。点青铜起土铲后可拆除龟甲罩或移除草木。数字键1–9切换卡牌，空格/P暂停，Esc返回或取消，F11切换全屏。方括号键调整倍速，选卡与倍速可在设置中改键。显示设置支持更大的字号、阶别形状和战斗文字提醒。战场右上角可随时切换 0.1、1、1.5、2、3 倍速，每场从 1 倍速开始。若卡关，可在设置里开启作弊菜单补充香火。

Windows 成品为单文件，下载后双击运行。玩家数据位于 `%APPDATA%\YokaiNightMarket\`。封面可切换三个独立对局存档槽，每槽留存最近一次守夜结局。旧版进行中的对局自动迁到第一槽。

## 本次更新

新增回春葫及三路独立三阶形态，调整逐云鸢、烬翼蝉、祈愿耕等草木。恶首的技能、援军和演出全面增强。图鉴支持发布顺序及分类排序；封面右上角可查看完整更新公告。常规恶客重新绘制朝左行走、攻击和游泳动作，护具随头部定位。

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
- `qa_sweep.gd`：二十五夜压力扫描，同长前四波比较，另列扩展普通波总量。
- `trim_export.py`：打包后校验全部动画清单和包内逐文件内容，剔除停用资源并去重。每次追加内容先完成运行验收，再更新裁剪依据。
- `ui_selftest.gd`、`qa_click.gd`、`qa_player_ui.gd`：界面、视口事件点击、全部备战按钮边界、图鉴和进化文案。

结果在 `qa/`，最终包哈希见发布验收记录。固定阵容模拟不是人类实时试玩，不代表所有卡组都在两分钟内击败恶首。当前实测交付平台为Windows x64。

历史规则入口见 `V040_IMPLEMENTATION.md`，本版骨骼范式与动画接入见 `ANIMATION_RIG.md`。后续波次进度仍四波一页；玩家界面只用条形表示凶险度，不显示系数与开发说明。

## 授权与素材

引擎、字体声明见仓库的 Godot MIT、第三方与 OFL 文件。新增美术由内置图像生成工具制作，提示词和区域表随源码提供。第四、第五周的六首新曲由本地 songgeneration-mcp 调用 ACE-Step 1.5 制作。
