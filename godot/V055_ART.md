# v0.5.5 美术资源

使用内置 image_gen 生成透明立绘，未使用外部API脚本。完整原始提示词与来源位于 data/v055_generation_prompts.json、data/v055_firework_art_prompts.json；处理后资产在 assets/sprites/year-banyan*.png、sky-mortar*.png、firework-e*.png，独立射弹/落地爆烟在 assets/sprites/animation/v055-projectiles.png。原始大图留在 build-art/v055，不进入发行包。

岁灯榕使用 canopy 骨骼，镇霄炮使用 vessel，烟花童使用 upright。配置在 tools/plant_rig.gd 的 BY_TYPE。每个本体/满阶形态经 bake_capstone_frames.gd 的 --actor=<id> --profile=<profile> 烘焙关键姿势，再经 bake_motion_frames.py --actor <id> 输出32帧WebP。帧表为 data/actor_frames.json、actor_motion.json；透明边缘与脚底锚点保持统一。运行时通过 ActorFrames.draw_pose 读取，无需逐株加入绘制分支。

本次11张肖像、4条射弹特效加22条草木动作共26条新clip。各clip含32帧且至少24帧像素不同，详细结果在 qa/v055-motion-check.json。烟花童的双筒、圆花炮、月架三种轮廓在战场100像素附近也能分辨。新炮弹没有套用狐尾灯火球。

五条新声音由原有低频材质共振链制作：榕果产出、成长、吐籽、重炮发射、落地。峰值和高频受限，原有十五首五周配乐未修改。
