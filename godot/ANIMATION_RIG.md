# 妖怪夜市动画制作与接入

v0.4.2 的战斗图集按每个动作 32 帧播放。原画四个关键姿势仍存于 `actor_frames.json`，并保留脚底或水线锚点。烘焙脚本在锚点坐标里计算相邻姿势的双向光流，补出运动中间帧，对遮挡处优先采用近端轮廓。成品是 `assets/sprites/motion/*.webp` 与 `data/actor_motion.json`。游戏按动作经过的时间逐帧采样。构建时只使用已经烘焙的图集，改过原画时才需要 Python、Pillow、NumPy 和 `opencv-python-headless`。

```powershell
python tools/bake_motion_frames.py --actor ironjudge
python tools/bake_motion_frames.py
```

第一条命令仅更新一个角色，第二条重建全体角色的动作。三阶草木和首领仍可先用下文骨骼模板重新生成关键姿势，再烘焙 32 帧图集。大型铁面与铁桶的脸部锚点和关键姿势一同插值，走路、攻击与入水后的护具位置随头部变化。

战斗从 `data/actor_frames.json` 读取透明 PNG 图集。草木按事件切换 `idle` 与 `action`，恶客在地面使用 `walk`、`attack`，水里使用 `swim`、`swim_bite`。下水时播放溅水并由行走帧过渡到游泳帧。所有动作帧以脚底或水线为锚点；同一角色的缩放基准取待机或行走高度，动作幅度不通过逐帧拉伸修正。护具应对准穿戴部位，轿厢与两只抬轿小鬼分图层，随行走与攻击同步播放。

## 同形草木快速出帧

`tools/plant_rig.gd` 使用 Godot 的 Skeleton2D、Bone2D 和绑定权重的 Polygon2D。Root 固定脚底，Body 驱动躯干，Crown 驱动冠部，Left 和 Right 驱动两侧。模板按可见像素范围拟合关节；同一类草木更换原画后，复用待机与出手两组姿势，批量烘焙为逐帧图集。五种范式：

| 范式 | 适用形态 |
| --- | --- |
| upright | 直立人形、签筒、钟馗像 |
| canopy | 伞面、平铺叶片 |
| vessel | 石磨、火盆、香炉等较重器物 |
| lantern | 灯笼、铜铃、灯焰类 |
| quadruped | 舞狮等四足形态 |

原画须有透明底，完整显示脚底与出手会移动的部位。先导入 PNG，再从 godot 项目目录运行以下命令；烘焙需要图形渲染：

```powershell
& "C:/path/to/Godot_console.exe" --path . --script res://tools/bake_capstone_frames.gd -- --actor=new-plant --sprite=res://assets/sprites/new-plant.png --profile=upright
```

命令写出图集及区域表。批量烘焙不传末尾参数，会更新现有的 39 套三阶形态及 Boss 姿态。现有草木的三阶异形以 `<id>-e1`、`<id>-e2`、`<id>-e3` 命名，同时在 `data/evolution_art_v040.json` 或独立三阶立绘中登记形态图。没有形态变化的三阶（例如烟花童）沿用同一图集。从本次 v0.5.1 同版更新起，每株新增草木在提交时必须同时交付本体立绘，以及每条可升至三阶路线的独立三阶立绘与动作。三阶立绘用 `<id>-e1.png` 等名称，放入 `assets/sprites/`。原画帧表与动作表沿用同一角色 ID。一次性、无升阶路线的草木只需要本体。烬翼蝉等有多阶段动作的形态还需继承本体所有状态，每个动作交付 32 帧。新草木另在 `Content.PLANTS`、`PLANT_ORDER`、推荐顺序和图鉴登记；出手事件写入 `action_at`，无需在渲染器为常规攻击单独写分支。

## 手绘帧与动作验收

复杂动作优先制作独立帧：抬脚、伸手、合嘴、甩尾、推水、收招等要在角色本身发生。工作稿为透明底、横排四格，每格一个动作阶段；上下行分组。原画使用内置图像生成工具生成，采用暗青、旧金和朱砂，强调干笔水粉肌理、单一光源、稳定轮廓，保持透视与面向一致。两种轿厢以同款漆木轿与帘幕为基础，喜轿在窗口加鬼新娘；归风扇用乌羽、铜饰与青色风纹，烟花童用铜筒、红纸烟花和腰带。正式 PNG 与区域表随源码提供。

```powershell
python tools/register_actor_atlas.py new-plant "C:/art/new-plant.png" idle,action --facing right
python tools/register_actor_atlas.py new-guest "C:/art/new-guest.png" walk,attack,swim,swim_bite --facing left
& "C:/path/to/Godot_console.exe" --headless --editor --path . --import
& "C:/path/to/Godot_console.exe" --headless --path . --script res://tools/qa_animation.gd
```

先看脚底与轮廓有无跳动、动作是否在技能触发时读得清，再看近远两行、遮挡和破损。烟花与推风的落点须与模拟一致；水路帧脚部收在水线下；Boss 闪影末帧和碰撞占行必须同时切换。动画自检会验证透明图集可加载、帧区域有效，以及每组 32 帧至少四分之三的画面不同。实机还应逐段查看手脚和护具是否重影。

参考：[Godot 的 2D 骨骼文档](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)。

## v0.5.2 新资源

回春葫本体及 e1/e2/e3 独立形态使用同一套 upright 范式，每种包含 idle/action 各32帧。十二套常规恶客与轿厢改为朝左侧身，游泳与攻击分别绘制。特殊异形维持原轮廓。护具的逐姿势头部锚点存于 `data/actor_attachment_pins.json`，侧身面具与陶瓮战损图存于 `data/armor_profiles_v052.json`；不得使用固定胸前位置替代。

`v052-boss-fx` 六组施法、`v052-plant-fx` 五组治疗与状态、`v052-projectiles` 四组射弹、`v052-craters` 两类坑洞均注册到动作清单，运行32帧图集。特效帧采用稳定格心锚点，禁止随亮区包围盒漂移。轿厢图已含两名轿夫，完整轿厢显示时不再叠画额外轿夫。原始提示词与来源记录见 `data/v052_art_prompts.json`、`data/v052_guest_art_prompts.json`。
