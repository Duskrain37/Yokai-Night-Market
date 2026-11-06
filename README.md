# 妖怪夜市 v0.5.3 安卓横屏版

## 安装后直接玩

1. [下载安卓 APK](https://github.com/Duskrain37/Yokai-Night-Market/releases/download/v0.5.3-mobile/YokaiNightMarket-android.apk)。
2. 按系统提示允许浏览器安装本次 APK，安装完成后点游戏图标开始。资源已包含在包内，无需再次下载。
3. 请横屏游玩。轻点选择和种植，长按约0.45秒取消；列表可滑动，说明点开阅读。

这是独立手机版分支。电脑用户请前往 [PC 默认分支](https://github.com/Duskrain37/Yokai-Night-Market/tree/v0.5.3)，[下载独立 EXE 后双击直接启动](https://github.com/Duskrain37/Yokai-Night-Market/releases/download/v0.5.3/YokaiNightMarket-win64.exe)。

安装下载的 APK，按系统提示允许本次安装，再点图标启动。无需再下载资源，离线可玩。最低 Android 7.0、OpenGL ES 3.0，兼容 ARM64 与 ARMv7。建议4 GB及以上运行内存，预留至少2 GB空间；低内存设备可在设置中选择30帧。APK 使用固定发行证书签名，后续同包名、同证书更新可覆盖安装。卸载会移除本地存档，正常升级请直接覆盖安装。



## 触屏操作

- 轻点卡牌选择，再点棋盘种植；点其他卡牌直接切换。拖动选卡后也可在落点松手种植。
- 长按约0.45秒相当于右键取消，不会在松手时再补一次种植。滑动列表不会触发卡牌选择。
- 说明不依赖悬停：选卡后顶部显示主要数值；右侧图鉴可阅读完整本事和九阶进化。回到战场保留原选择。
- 点场上草木打开进化，点路线查看效果，再点下方确认按钮付费。阅读时暂停对局，已满阶路线仍能查看效果。
- 左侧双列卡牌；右侧为暂停、起土铲、唤波、倍速、图鉴等操作。默认1倍速，点倍速依次切换。
- 备战的草木和今夜来客独立上下滚动；图鉴左右栏目独立滚动。切到后台自动保存并暂停，回来后手动继续。

## 画面与性能

固定横屏，棋盘与角色保持同一等比投影，保留完整九列；较长或较方的屏幕采用留边，避免裁掉棋盘。刘海和手势区域另做安全区。界面字号高于电脑默认，可再选择中/大字号。

所有角色、三阶形态和特效保留32帧，未减帧或降低素材分辨率。对超过4096像素的图集，按动作无损拆成独立GPU纹理；原像素、透明度、区域与锚点逐一验证。动作按需异步读取、回收不再使用的缓存；只读取当前音乐并释放已淡出的段落。正式包移除未在役备用图集与工具，不删有效玩法。

## 开发与签名

Godot 4.7.2、OpenJDK 17、Android SDK。安装 Godot 官方相同版本安卓导出模板，设置编辑器的 Java SDK / Android SDK 路径。`export_presets.cfg` 的 Android 为正式 ARM 双架构；Android QA 为本地 x86_64 模拟器用包，禁止将它冒充手机版成品上传。

发行密钥在项目外保存，不随源码发布。构建前通过环境变量 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`、`GODOT_ANDROID_KEYSTORE_RELEASE_USER`、`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` 提供。使用 `tools/build_android.py` 导出并验签；不要把密钥或口令写进 preset、日志或仓库。以后必须沿用原证书才能覆盖安装。

正式移动分支 `v0.5.3-mobile`，人工发布附件只放 `YokaiNightMarket-android.apk`；PC 默认分支和最新发布仍为 `v0.5.3`。
