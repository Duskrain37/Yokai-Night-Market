# v0.5.4 美术、动作与声音资源记录

全部新增图像使用内置 `image_gen` 制作，未调用CLI或外部图像服务。资源均已复制到项目，不依赖生成器在线运行。

- 本体及六张三阶立绘：`assets/sprites/reed-chime*.png`、`soul-casket*.png`；共八套骨骼动作，使用既有canopy/vessel范式。
- 纸鸢鬼、授牌使、五桨阴舟：`assets/sprites/animation/{sky-wick,shield-envoy,oar-barge}.png`。飞行／破翼／陆地落下／落水、授牌／行走、同步划桨／撞击／沉舟分别绘制。其后依既有光流烘焙流程生成32帧，保存到`assets/sprites/motion/`。
- 范围借弹与草木特效：`assets/sprites/animation/v054-relay-fx.png`、`motion/v054-relay-fx.webp`。四组分别为莲籽范围弹、竹叶气束、内收与外放；固定中心锚点，不追踪每帧亮区边缘。
- 孤灯屿／冥判窟门神：`assets/sprites/mower-day4.png`、`mower-day5.png`。完整提示词在`data/v054_art_prompts.json`。
- 新图原始输出与映射：`data/v054_new_art_sources.json`；六个三阶形态和最终去底、恶客、特效完整提示词在`data/v054_new_art_prompts.json`。本机生成原图亦镜像在`build-art/v054/`，不会进入运行包。
- 11条低响度材质音效：`assets/sfx/v040/`，制作参数和电平／频谱检查在`data/v054_sfx_mastering.json`，顺序试听在`qa/v054-sfx-audition.wav`。本轮没有改动五周配乐。

以下是未在上述JSON中重复保存的本体／前两张竹篁进化／纸鸢动作原始提示词。参考图仅用于统一身份与笔触，不把已有草木重新涂色作为独立形态。

## 篁音簇本体

Use case: stylized-concept. Asset: transparent 2D Chinese folklore tower-defense plant character sprite, full body alone, three-quarter facing RIGHT. A sentient clump of dark jade bamboo reeds growing from a squat weathered earthen footed bowl, seven hollow bamboo whistles fan upward, each mouth holding a tiny pale amber wind wisp; carved sleepy guardian eyes on the vessel, knotted faded vermilion cord. This is the BASE form, modest readable silhouette; no projectiles outside the silhouette. Style dry-brush gouache with grain and hand-painted ink contours, restrained moss jade, old brass, ochre, muted vermilion, moonlit night-market palette, low saturation, matte materials, no shiny CG, no neon, no text, no UI, no environment, no cast ground shadow. Complete silhouette and root feet comfortably inside frame. True transparent background.

## 五窍灵枢本体

Use case: stylized-concept. Asset transparent 2D Chinese folklore tower-defense plant character sprite, full body alone three-quarter facing RIGHT. BASE form of a sentient seed-grown soul collecting casket: squat dark aged wood coffer nestled in two curled muted jade lotus leaves, round open brass funnel facing right to catch friendly projectiles, five small empty translucent amber seed windows in its lid, tiny carved curious eyes under funnel, old red tassel, visible little root feet. Matte weathered copper and wood, dry-brush gouache with paper grain and hand-painted contours. Muted night-market jade/ochre/old brass/vermilion, soft subdued lantern light, low saturation. Clear squat silhouette, no balls fired, no background, no lettering, no neon, no photorealistic shiny 3D. Transparent background, generously padded full object.

## 篁音簇分篁三阶

Use reference only as visual identity. Draw independent TIER THREE EVOLUTION form for this bamboo-whistle plant: the modest bamboo cluster becomes an elegant HALF-FAN of seven flared bamboo pipes, pointing in seven radial directions from vertically up to vertically down across its RIGHT half, a carved weathered temple ceramic guardian bowl anchored at bottom. Strong coherent full silhouette, amber breath in each pipe, red tassels. Keep original dry-brush gouache and muted palette and root feet. Single full character, three-quarter facing right, no scene/halo/groundshadow/text, transparent background. Distinct upgraded shape, not just recoloring.

## 篁音簇凝露三阶

Use reference as identity. Independent TIER THREE EVOLUTION for this bamboo-whistle plant: thick jade bamboo pipes wrapped with pale blue frost-rime silk prayer cords, five folded icy paper wind feathers cradled between pipes, heavier archaic turquoise earthen guardian vessel, roots and faded scarlet tassel retained. A readable chilled wind silhouette with matte soft frost; NO bright neon. Preserve dry-brush gouache texture, muted night-market palette. Full character isolated at three-quarter facing right, transparent background, no halo, scenery or text. Distinct physical upgraded form.

## 纸鸢鬼动作

Use case: stylized-concept. Production sprite animation atlas, transparent background. Strict GRID 4 columns x 4 equal-height rows, every cell isolated with padding, no marks or text. All same small LEFT-FACING emaciated Chinese hungry ghost in ragged faded brown hemp, pale grey skin, huge tired eyes, messy black topknot, barefoot, dry-brush gouache texture and desaturated night-market palette. Has wearable flight apparatus: large torn ochre paper swallow kite strapped to its back with bamboo spars, muted red ties. ROW 1 four distinct flying poses at equal body scale, legs dangling, kite tilts, ghost reaching LEFT. ROW 2 LAND landing sequence: descends with torn kite, feet reach down, crouches on landing, rises; final pose without kite. ROW 3 WATER landing sequence: falls with torn kite, dives, surfaces, swims to LEFT at a constant low waterline, no visible feet above head. ROW 4 four stages of paper kite snapping and dropping while ghost drops, same LEFT-facing ghost. No scenery or ground planes, actual alpha background; no checker pattern. Each row/column precisely aligned, fixed center anchors, nothing crosses cells. Hand-painted matte ink/gouache, not cartoon vector, not shiny CG.

## 使用与验收

最终PNG已做常规alpha包围盒裁切及头像高度适配。动作图按实际不透明横带测量行界，未盲目四等分不均匀的行距。脚底／水线锚点见actor_frames，FX使用固定格心。新增34组动作均为32帧，且各组至少24帧像素不同，检测记录在`qa/v054-new-motion-uniqueness.json`。
