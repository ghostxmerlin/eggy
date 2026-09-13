# 宜之有之派对

Godot 4.7.2 + GDScript 的 Q 版 3D 单机派对游戏。默认从蛋仔岛开始，点击“参赛”进入云端冲冲赛第一关。角色按经典蛋仔外形自行建模，场景、配饰与配乐在本项目中制作。

换机器或开启新的 Codex 开发会话，请先阅读根目录 [startup.md](startup.md)：环境准备、开发历史、当前状态、测试方式和排障记录。

## 蛋仔与皮肤

默认角色为圆润的黄色蛋仔：浅肤色面部、黑色小眼睛、球形触角、短手与白鞋，保留走路摇摆、跳跃伸缩和滚动动画。

在岛上点击右侧“衣柜”或按 **B**，可试穿经典小黄、蜜桃软糖、薄荷汽水、晴空蓝蓝、草莓贝雷和金冠派对六套皮肤。拖动预览或点击左右转按钮查看模型；点击“穿上这套”保存，取消或 Esc 返回。Tab / 方向键切换按钮焦点，空格 / Enter 操作当前按钮。

皮肤保存在 Godot 用户数据目录中的 `appearance.cfg`，重新启动、参赛和返回岛屿都会保留。换装期间暂停世界，试穿不会更改实际穿着；飞行、腾空或施放技能期间暂不能打开衣柜。皮肤不改变碰撞体、移动速度和技能参数。

## 开发分支

后续开发在 `dev` 分支进行，每个功能完成相应自动测试及实际画面检查后合并到 `main`，同步 GitHub，然后切回 `dev` 继续开发。`main` 保留已通过验证的版本。

## 蛋仔岛、巅峰赛与单人练习

启动后可在浮岛广场自由移动、跳跃和滚动。中央是“宜之有之派对”灯柱广告牌，扩大后的岛上有摩天轮、环岛小飞机、喷泉、可承载玩家的升降观景台，以及巨型蛋仔。右下角“参赛”进入第一关；比赛暂停和结算界面提供“返回岛屿”。

小飞机停在岛右侧升降台旁的高平台。乘升降台到顶后向右走，沿坡道进入机舱；靠近会打开灰色舱盖，站稳后自动关盖、起飞，约半分钟绕岛返回。飞机停稳并开盖后恢复行走，沿原坡道下机；留在舱内不会马上再飞。飞行时可右键看风景、Esc 暂停，R 可回广场。

岛上点击“参赛”、按 Enter，或在暂停菜单参赛，进入 1 名玩家 + 31 名人机的巅峰赛。3 秒倒计时后出发，前 24 名晋级，限时 150 秒。重开保留 32 名选手；返回岛屿会移除比赛人机，再次参赛重新组队。岛上 R 回到广场，比赛中 R 返回检查点，Esc 暂停。

岛屿出生点左前方有「技能练习区」，三只练习蛋仔可被击退、冻结或恐惧，受控结束后会返回原位；第三只会间歇跳跃，旁边两个方块与角色质量相同，可用飞扑撞开。练习目标只出现在岛上，不参与单人比赛。技能也能作用于原有 32 人比赛的其他选手。

喷泉使用连续的宽扁水带、动态高光和落水涟漪。蛋仔岛播放轻快木琴与拨弦配乐，比赛切换到更快的合成旋律与鼓点；两首原创无歌词音乐分别循环播放，场景切换用 1.2 秒淡入淡出，暂停时音乐继续。

单人练习仍可通过 `./play.command -- --practice` 进入，不限时、不淘汰。`./play.command -- --race` 直接打开 32 人比赛准备界面；默认启动仍是蛋仔岛。

当前手感调整：加快玩家起步、反向、松键刹停和镜头跟随。窗口为 1440×900；岛屿使用 90% 内部渲染比例与 FSR 重建、赛道使用 100%，搭配 2× MSAA 和两级动态阴影；单人性能对照和限制见 [调试记录](docs/verification.md)。

## 运行

1. 安装 Godot 4.7.2（标准版，无需 .NET）；开发和实际画面验证使用 macOS Metal Forward+。
2. 克隆项目：`git clone https://github.com/ghostxmerlin/eggy.git`。
3. 在 Godot 项目管理器中导入 `eggy/project.godot`，等待资源导入完成，按 F6 运行主场景或 F5 运行项目。

macOS 也可以在项目目录运行 `./play.command`：启动脚本优先使用 `.tools/Godot.app`，其次使用 PATH 中的 `godot`。其他系统可在项目目录运行 `godot --editor --path .` 导入后，再运行 `godot --path .`；其他系统尚未进行实际运行验证。

仓库包含运行所需模型、字体和音频，以及可编辑资产源文件；不包含 Godot 引擎、导入缓存和打包产物。当前使用源码启动，应用安装包尚未完成验证。

## 操作

| 按键 | 功能 |
|---|---|
| W / S（↑ / ↓） | 前进 / 后退 |
| Q / E | 左右平移 |
| A / D（← / →） | 转向，镜头随朝向转动 |
| 空格 | 跳跃；支持 140ms 缓冲、120ms 离地宽限 |
| 1（兼容 Shift） | 滚动加速；持续 0.85 秒、冷却 3.3 秒 |
| 2 | 飞扑；向前扑出并按碰撞方向、双方质量撞开可移动目标，冷却 3 秒 |
| 3 | 咸鱼棒横扫；按武器轨迹命中，地面击退、空中按接触位置击飞，冷却 4 秒 |
| 4 | 冰锥术；地面雪花展开，前方 6 单位扇形范围冻结 2 秒，冷却 10 秒 |
| 5 | 破胆怒吼；周围 6 单位范围失控乱跑 2 秒，目标头顶显示骷髅，冷却 15 秒 |
| 鼠标右键拖动 | 调整镜头 |
| 鼠标左右键同时按住 | 沿镜头朝向前进，移动鼠标转向；松开任一键停止鼠标驱动的前进 |
| R | 回到最近检查点 |
| Esc | 暂停 / 继续；结算页返回首页 |
| Enter | 岛上参赛 / 再跑一局 |
| B | 岛上打开衣柜 |
| F3 | 显示性能面板 |
| F12 | 保存当前画面 |

## 内容

- 经典蛋仔外形的自建选手模型：球形身体、触角、短手白鞋、可换皮肤、脚步动画、跳跃伸缩、滚动动画。
- 云上玩具赛道：约 318 单位赛程（原版的两倍），13 处断口、无护栏窄桥、错位跳台、旋转杆、移动门与 6 处途中检查点。
- 电脑选手使用实际角色物理、跳跃与障碍判断；已晋级选手退出碰撞，避免堵住终点。
- Metal Forward+、MSAA、环境遮蔽、动态阴影、柔和色调映射。
- 所有运行资产在本地；Noto Sans SC 随包附 SIL OFL 许可证。

## 文件

- `art/cloud_racer.blend`：可编辑角色源文件。
- `art/build_character.py`：角色建模、语义材质、动画节点和 GLB 导出程序。
- `scripts/skin_catalog.gd`：皮肤颜色与可替换配饰目录。
- `scripts/skin_store.gd`：皮肤选择保存与无效存档回退。
- `scripts/wardrobe.gd`：独立 3D 试穿预览、旋转及换装交互。
- `art/island_monument.blend`：保留圆角修改器的可编辑雕塑源文件。
- `art/export_letter_meshes.gd`、`art/build_island_letters.py`：导出中文字网格并生成圆角雕塑。
- `scripts/island.gd`：蛋仔岛布局、Q 版建筑、植被与灯柱广告牌。
- `scripts/attractions.gd`：摩天轮座舱、飞机、喷泉、升降台与巨型蛋仔。
- `scripts/plane_ride.gd`：飞机停靠、感应开盖、登机、载人航线、返航和下机。
- `art/build_assets.py`：Blender 资产与原创音效生成脚本。
- `art/build_music.py`：两首原创 32 小节配乐的乐谱与合成源程序，使用 Blender 自带 Python / NumPy 生成 WAV，再用 ffmpeg 编码为游戏里的 Ogg Vorbis。
- `scripts/background_music.gd`：场景音乐、循环和淡入淡出。
- `scripts/fountain.gd`：连续水带网格、水面与飞溅动画。
- `scripts/course.gd`：赛道、机关与地图装饰。
- `scripts/racer.gd`：共享角色运动与动画。
- `scripts/skills.gd`：五个技能、冷却、范围命中、冻结、恐惧与技能特效。暂停时冷却和控制时长停止，重生清除受控状态，场景切换清理练习目标。
- `scripts/game.gd`：比赛、相机、音效与性能记录。
- `scripts/hud.gd`：中文界面。
- `tests/`：规则、真实场景操控与完整比赛回归。
- `captures/`：本地生成的实际渲染截图与测试记录，不纳入 Git。调试记录中引用的历史截图和日志保存在开发机器上。

## 验证

```
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/test_island.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_rules.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_world.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_skins.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_wardrobe.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/test_solo.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/test_response.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/test_race.gd
./play.command -- --autoplay --profile
```

自动控制仅通过正常移动、跳跃与滚动接口跑关。性能测试需单独运行，避免同时运行 Blender、另一场游戏或无界面模拟。截图测试与无截图性能测试分开记录；最终实测见 `docs/verification.md`。自动检查不能代替用户对模型观感与操控手感的最终认可。
