# 妖怪夜市 v0.4.1

中式怪谈题材的车道塔防。用香火请草木出摊，在灯火与水道之间守住夜市。

## 内容与操作

- 三章十五夜，另有独立特殊关「鬼市深处」；20种草木、13种恶客（鬼新娘随喜轿出现）、3位原创首领。
- 每章五关分别4、4、6、6、8大波；进度每次展示四波，进入下一组时翻页。
- 每章关底的最后一大波迎战首领。看清落点预警，拆掉机关，趁破绽进攻。
- 鬼市深处十二大波，每四波清完后迎战一位首领，随后进入下一段布阵；阵容与香火保留，第三位首领退散后才通关。
- 14株可进化草木各有三条路线，最多开启两路，只有一路能到三阶。部分三阶有专属形态和对应动作帧。
- 首次守夜可先学教程；水路先放夜莲。备战页提供推荐配卡与夜莲换卡。

左键选卡、落子或查看草木，右键取消；数字键1–9切换卡牌，空格/P暂停，Esc返回或取消，F11切换全屏。设置可选自动收香火、战斗速度、血条与声音；0.1倍观察仅用于训练。

Windows成品为单文件 `YokaiNightMarket.exe`，解压即可运行。玩家数据位于 `%APPDATA%\YokaiNightMarket\`。旧版未结束的四波对局按原计划完成，新开的对局使用本版规则。

## 从源码运行

Godot 4.7.2、GDScript、原生2D，GL Compatibility。用对应编辑器打开 `project.godot`，按F5运行，不需要旧JS工程、图像生成服务或联网。

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -GodotPath "C:\path\to\Godot_console.exe"
```

Windows导出需要同版本模板。当前 `export_presets.cfg` 指向工作区便携模板 `../../tmp/godot-tools/templates/`；其他机器请将两个 `custom_template` 路径改为自己的模板路径，或清空并安装Godot默认模板。Python构建步骤使用Pillow、fonttools；numpy仅用于重制音效。运行素材与字体子集均已提供。

`build.ps1` 导入资源、处理字体和戳记，通过检查后导出 `build/YokaiNightMarket.exe`。本机曾在并行重导字体时发生原生崩溃，已改为串行导入，并使相同字表跳过重写；此编辑器设置不影响正式运行。设置说明见[Godot文档](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html#class-projectsettings-property-editor-import-use-multiple-threads)。

## 验证与维护

- `qa_logic.gd`、`qa_battle.gd`：规则、进化、正常费用与冷却对局、存档。
- `qa_boss.gd`、`qa_boss_balance.gd`：首领事务与27场三阵容三种子模拟。
- `qa_special.gd`：十二波三首领衔接；清敌辅助流程不冒充玩家通关。
- `qa_sweep.gd`：十五夜压力扫描，同长前四波比较，扩展普通波总量另列，首领不计入普通波压力。
- `ui_selftest.gd`、`qa_click.gd`、`qa_player_ui.gd`：界面、视口事件点击、全部备战按钮边界、图鉴和进化文案。

结果在 `qa/`，最终包哈希见发布验收记录。固定阵容模拟不是人类实时试玩，不代表所有卡组都在两分钟内击败首领。当前实测交付平台为Windows x64。

历史规则入口见 `V040_IMPLEMENTATION.md`，本版骨骼范式与动画接入见 `ANIMATION_RIG.md`。后续波次进度仍四波一页；玩家界面只用条形表示凶险度，不显示系数与开发说明。

## 授权与素材

引擎、字体声明见发布包的Godot MIT、第三方与OFL文件。新增立绘由内置图像生成工具原创制作，PNG原件保留，提示词和区域表随源码提供；49条新音效为原创模态合成，没有使用外部录音。
