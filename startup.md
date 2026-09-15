# Codex 接手说明 · 宜之有之派对

更新日期：2026-09-13。本文面向换机器后的 Codex 开发会话。

本次交接的游戏代码基线为 `c065d21`。本文随后单独提交，进入 `main` 并同步远端。版本、分支、机器环境和实测结果都要以接手时的检查为准，不能把本文当作实时状态。

2026-09-13 后续更新：用户要求恢复巅峰赛多人参与。岛上“参赛”、Enter 和暂停菜单参赛现进入 1 名玩家 + 31 名人机比赛；默认启动仍在岛上，`--practice` 保留单人练习。新机验证见 `docs/verification.md` 的“恢复 32 人巅峰赛”。

同日道具更新：巅峰赛有十二种随机道具，玩家和 AI 从问号箱拾取，一次携带一个，R 使用，原 R 复位改为 T；详见 `docs/items.md`。道具模型由 `item_visuals.gd` 程序生成。字体已包含新中文；本机 Python 3.9.6 使用 fonttools 4.59.2 重建字体，运行游戏仍不需要 Python。

同日人机更新：修复后半程全部走中心线的问题，新增 `race_ai.gd`，按平台宽度、邻近选手和实体道具选择跑线，加入跳跃脱困与安全直道滚动。基础跑速为 6.4–8.0（玩家 8），道具改为按目标、地形和冷却判断；自动跑关复用同一套路线决策。回归入口及实测见 `docs/verification.md` 的“人机竞争与终点拥堵”。

同日盲盒更新：用户指定早期“断罪骑士”银白机甲；新增常驻与机甲主题抽取、回车 `+500` 加蛋币、十连、50 抽高阶保底与前三次高阶不重复。原六款外观仍免费拥有，新套装须抽到后穿着。岛上 Enter 现打开蛋币输入，不再直接参赛；衣柜和结果弹窗 Enter 保留焦点操作。完整规则及来源见 [盲盒说明](docs/gacha.md)。GitHub 写权限 SSH deploy key 已由用户添加并验证，仓库配置了专用 core.sshCommand；新机器须重新鉴权，不复制或提交私钥。

## 1. 新会话先做什么

2026-09-15 轻松竞速恢复（覆盖下方职业巅峰赛与道具赛规则）：用户要求巅峰赛回归仅滚动/飞扑。竞速及单人赛道暂停职业技能、通用 3—5 技能和随机道具；职业存档保留，岛上/决斗恢复。参赛不再强制创建职业。首位选手冲线后 30 秒收尾，总限时仍 150 秒，前 24 名晋级，名额满或期限到即结束。HUD 显示秒数、剩余名额、最后 10 秒变色/提示音及未晋级原因。`test_light_race.gd` 原生按键和截图、`test_rules.gd` 边界、`test_race.gd` 完整轻松竞速。

2026-09-15 固定职业体系更新（覆盖下面的决斗首版规则）：用户要求一个角色固定职业，岛屿/巅峰赛/决斗共用五个职业技能，仅由天赋调整。四职业二十技能已接入，猎人明确不要宝宝，2 号猛禽一击、5 号瞄准射击。C 创建职业或调整三行二选一天赋，职业保存到 `skin_save_path + '.career'`，原有外观与钱包文件不变；不要恢复入房换职业或通用 3—5 技能。`class_catalog/profile/room/kit/effects.gd` 分管目录、存档、UI、玩法、特效；`art/build_class_audio.py` 生成 28 个音效。说明和专项回归见 [职业体系](docs/classes.md)。用户表示暂时不玩，完成后不必自动启动游戏。

2026-09-15 决斗场首版：用户确认玩家对一名人机，3—5 号暂用咸鱼棒、冰锥术、破胆怒吼。岛上 J/决斗场按钮进入四职业选择；1、2 号专属技能留空待定，不要擅自当作已实现的职业招式。100 生命、咸鱼棒实际命中扣 20，控制技不扣血，归零结算。竞技场内禁用滚动/飞扑和 T 复位，竞速检查点/冲线仅在 racing/result 触发（玩家先结算后，人机仍需记录冲线）。模块和测试见 [决斗场说明](docs/duel.md)。

2026-09-15 起跑站位更新：用户不希望玩家固定最后起跑。`game.reset_racers()` 在 32 人比赛中独立随机打乱站位，保留选手数组和 ID，重开重新分配。删掉玩家专属后排位置；单人练习仍从中央出发，岛屿出生点不变。`start_rng` 不消费道具/抽取 RNG；`start_seed` 供回归重现，普通游戏默认随机。专项 `test_start_grid.gd`；完整赛测试同步设置起跑和道具种子。

2026-09-15 咸鱼棒更新：用户要求有下压弧度和侧扫力量感，黄金至臻的武器外观换成粉色激光剑。`swing_motion.gd` 共享斜向运动曲线，`swing_visual.gd` 处理握持、拖尾和首次命中的 45 ms 视觉顿挫；不暂停全局物理。两种武器仍用技能 3、4 秒冷却、地面击退和空中击飞，皮肤不提供攻击加成。命中改为弧线武器段与目标胶囊的最近点采样。专项 `test_swing_visual.gd -- --visual`，另回归 `test_impacts.gd`。

2026-09-15 用户再次调整至臻：上一版金披风、刻度环、金色大光粒和暗金甲均未获认可。当前改为更亮的暖黄金、蓝紫渐变披风、向后喷射的金橙火焰和随机彩色细星屑。不要恢复金色披风、刻度标记或金色大光球；`supreme_flames.gdshader` 负责喷焰，颜色与方向须以原生侧/背面画面核对。

2026-09-15 至臻特效更新：用户要求明显区别于紫皮的耀眼黄金机甲。`supreme_effects.gd` 和两个 supreme shader 只接入 `mecha`：抛光覆膜金甲、移动高光、日冕光环、双片流光披风与 GPU 光粒。跑动扬起，滚动/飞扑收拢，世界暂停和隐藏预览停止动画；换装自动释放，远处减少粒子。预览环境支持辉光；不改玩法属性和抽取/存档规则。原生验证用 `test_supreme_effects.gd -- --visual`，细节见验证记录。

2026-09-14 配色更新：用户要求“金色机甲大佬”，至臻 `mecha` 改为金色装甲、深金包边、浅金高光和金色发光眼；名称仍为断罪骑士·极。不要依据旧截图或早期银白参考将它改回蓝眼银甲；岚/烈配色保留。

同日动作声音更新：`gameplay_audio.gd` 接管 14 种动作音效、附近人机空间声与 13 句随机中文台词。跳跃/落地/碰撞和技能均接真实事件，语音有间隔与字幕，背景音乐说话时降低，暂停及场景切换清理声音。`docs/audio.md` 记录规则与离线生成方式；游戏只播放已提交 WAV，不依赖 `.tools/` 中的语音模型。原生 `test_gameplay_audio.gd` 检测真实混音输出，无界面只能检查触发逻辑。

同日外观精修：机甲改为封闭倒角装甲、连续内壳与动态四肢连接；开盒加入 3D 蓄能、开壳、品质粒子、登场音效及逐张结果。新增 `test_gacha_presentation.gd`，加 `-- --visual` 检查原生效果。预览关闭 mesh LOD 以修复面部穿插；套装固定部件按材质合并，法线使用逆转置处理。未改比赛场景的合批或全局画质；本轮未作帧时间收益承诺。

请先完整阅读本文，再看 [README.md](README.md)、[验证记录](docs/verification.md) 和 [资产来源](docs/ASSETS.md)。`startup.md` 是普通仓库文档，不要假定每个 Codex 会话都会自动读取；新会话可直接告知：“先阅读根目录 startup.md，然后在 dev 继续开发。”

```sh
git status --short --branch
git remote -v
git log --oneline --all -8
git fetch origin
```

- 仓库：<https://github.com/ghostxmerlin/eggy>，公开库。GitHub 账户为 `ghostxmerlin`。
- **所有新开发在 `dev`，功能验证后合并到 `main`，推送两个分支，再回到 `dev`。** 这是用户明确要求，已经授权该常规流程，不要每次重复询问是否合并。
- 先查看工作区，不覆盖用户未提交文件；有分叉就先检查差异，不使用强制推送、硬重置或删除分支来“修复”。`dev` 是持续开发分支，不在合并后删除。
- 跨机器接手时确认本机分支追踪正确，GitHub 认证和提交身份需要在新机器配置。旧机器的 CLI 登录、工具目录、Codex 会话和授权环境不会随 Git 迁移。
- 当前仓库没有专门的 `AGENTS.md`；后续若出现，读取适用指令，但用户当前指示优先。

## 2. 产品范围与用户偏好

目标是 Q 版 3D 单机派对游戏，名称 **宜之有之派对**。目前重点为蛋仔岛与巅峰赛第一关的质量：模型好看、场景有立体感、操控跟手、运行流畅。不要未经要求扩展联机、账号服务、多关赛季、商店或移动端。

用户先要求单人操作调试，后要求恢复巅峰赛的 31 名人机。**默认启动为岛屿自由活动，岛上参赛进入 32 人巅峰赛**，3 秒倒计时、前 24 名晋级、150 秒限时；这是本地 AI 比赛。`--practice` 的单人练习继续不限时、不淘汰。

用户重视实际试玩。生成资产、编译成功、测试通过、自动跑完赛道、原生画面检查、用户认可手感，是不同层面的证据；不能互相替代。尤其不能把平均 FPS 当作“全程流畅”，也不能把当前自建模型宣称为官方原版资源或已获用户最终认可的还原效果。

## 3. 环境与首次启动

### 运行必需

| 项目 | 已验证环境 / 说明 |
|---|---|
| 引擎 | Godot **4.7.2 stable** 标准版，`4.7.2.stable.official.ed1daf0bf`；不需要 .NET |
| 代码 | GDScript，无 Node/npm、Unity、Rust、后端服务或第三方 Godot 插件依赖 |
| 渲染 | Forward+，原机器为 macOS Apple M4 Pro，Metal，1440×900 |
| 物理 | Jolt Physics，60 Hz，开启物理插值 |
| 运行资产 | 已提交 GLB、字体、网格、音效和音乐，正常启动不需要先运行 Blender 或 Python |

`project.godot` 的 `config/features` 尚保留 `4.5` 标记，**这不是已验证的最低兼容版本**；先使用上述实测引擎，不要因为该标记降级。Windows/Linux 的原生画面与打包尚未验证，不保证与 macOS 完全一致。

新机器克隆并切到开发分支：

```sh
git clone https://github.com/ghostxmerlin/eggy.git
cd eggy
git switch dev
git pull --ff-only origin dev
```

已有本地 `dev` 时直接切换；只有远端分支时，Git 通常会自动建立追踪，也可用 `git switch --track origin/dev`。不要在已有同名分支时重复创建。

先安装 Godot。下面命令以 macOS 安装到 `/Applications/Godot.app` 为例；若放在项目 `.tools/Godot.app`，修改 `GODOT_BIN` 即可。这是当前 shell 变量，不需要写死进项目文件：

```sh
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --version
"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --path .
```

也可在 Godot 项目管理器导入 `project.godot`，等待资源导入，按 **F5** 运行项目。F6 运行当前场景，不要在打开了别的场景时把它误当主入口。

macOS 的 `./play.command` 使用 zsh，优先查找项目 `.tools/Godot.app`，其次查找 PATH 中的 `godot`。仅把 Godot 放到 `/Applications` 并不保证此脚本能找到它；此时使用上面的完整路径，或自行配置 PATH。

Windows 不直接执行 `.command`。可先通过项目管理器运行；命令行需把示例中的引擎调用改成自己的可执行文件，例如 PowerShell：

```powershell
$GodotBin = 'C:\Tools\Godot\Godot.exe' # 替换为实际文件
& $GodotBin --headless --editor --path . --import --quit
& $GodotBin --path .
```

Linux 可将 Godot 可执行文件放入 PATH 后使用 `godot --path .`。跨平台失败时先记录版本、显卡和 renderer；不要直接改全局画质或物理参数来掩盖环境问题。

常用入口（引擎参数和游戏参数由 `--` 分隔）：

```sh
"$GODOT_BIN" --path .                         # 蛋仔岛
"$GODOT_BIN" --path . -- --practice          # 单人赛道
"$GODOT_BIN" --path . -- --race              # 直接打开 32 人 AI 比赛准备界面
"$GODOT_BIN" --path . -- --autoplay --profile # 自动跑关 / 性能记录
```

### 仅重建资产时需要

原开发机实际工具：**Blender 4.4.3**、Python **3.14.7**、fonttools **4.65.0**；这些是已用版本，不是宣称其他 Python 版本都不能使用。音乐合成需要 NumPy，Ogg 编码需要 ffmpeg。

```sh
# 字体：仅在增加 UI 字符等情况下执行，生成物会更新
python3 -m venv .tools/font-venv
.tools/font-venv/bin/python -m pip install fonttools==4.65.0
.tools/font-venv/bin/python art/build_fonts.py

# 只重建角色：会覆盖 art/cloud_racer.blend 和 assets/models/racer.glb
BLENDER_BIN="/Applications/Blender.app/Contents/MacOS/Blender"
"$BLENDER_BIN" --background --factory-startup --python art/build_character.py
```

- `art/build_assets.py` 调用角色生成器，再重建圆角方块和音效；只改角色时不要无谓重建其他资产。
- `art/build_music.py` 可通过 Blender 的 Python/NumPy 运行：`"$BLENDER_BIN" --background --factory-startup --python art/build_music.py`，生成两首 WAV 后用 ffmpeg 编码。示例：`ffmpeg -i assets/audio/bgm_island.wav -c:a libvorbis -q:a 5 assets/audio/bgm_island.ogg`，race 同理。已有文件时 ffmpeg 会询问覆盖；先确认音乐确实需要重建。
- 中文雕塑的旧生成链为 `art/export_letter_meshes.gd` → `art/build_island_letters.py`。当前标题主体是灯柱广告牌，先确认修改对象，再决定是否重建旧雕塑资源。
- 改完字体/GLB 后再次执行 Godot `--headless --editor --path . --import --quit`，然后检查原生渲染。
- `.blend`、生成 Python 与导出 GLB 要同步提交。生成器会覆盖源文件，别先手工改 `.blend`，再盲目运行生成器把修改覆盖掉。

## 4. 开发历史与当前状态

大部分早期工作完成于首次建立 Git 之前，**不是每项功能都有独立提交可以回退**。

| 阶段 | 已完成内容 |
|---|---|
| 首关原型 | Godot/GDScript、云端竞速赛道、角色物理、AI、倒计时、检查点、跳跃/滚动、结算 |
| 单人调试 | 默认单人练习，改善起步、反向、松键制动和镜头跟随；降低阴影/MSAA 开销 |
| 蛋仔岛 | 自由活动、参赛与返回；岛半径约 48，摩天轮、升降台、大蛋仔、灯柱广告牌、饱和色彩 |
| 首关加长 | 赛程约 318 单位、13 处断口、错位跳台/窄桥、6 个途中检查点 |
| 喷泉与音乐 | 宽扁连续水带、中央水冠/涟漪；岛屿和比赛两首无歌词配乐，循环及 1.2 秒淡入淡出 |
| 技能 | 1–5 键技能、飞扑撞开等质量物体、咸鱼横扫击退/打飞、雪花扩散冻结、头顶骷髅恐惧效果 |
| 载人飞机 | 停靠 → 靠近开盖 → 入舱关盖 → 起飞绕岛 → 返回开盖下机，含暂停及中途退出清理 |
| `a796503` | 初次建立 Git、公开推送 GitHub，包含上述功能、资产、测试与文档 |
| `c065d21` | 经典黄蛋仔自建模型、六款皮肤、3D 衣柜、保存/取消与重启恢复；dev 合并 main，远端两分支已同步 |

当前角色不是早期的头盔耳机/围巾造型。默认是黄色球形身体、浅肤色面部、小眼睛、触角、短手白鞋；岛上的练习角色与巨型蛋仔也使用新基础网格。用户要求接近原版蛋仔，目前是按外形参考自行建模，观感仍可继续由用户反馈调整。

### 已约定的操作

| 操作 | 行为 |
|---|---|
| W/S | 前进/后退 |
| Q/E | 左右平移 |
| A/D | 转向，镜头跟随；不要擅自改回 A/D 平移 |
| 空格 | 跳跃，140 ms 缓冲、120 ms 离地宽限 |
| 1 / Shift | 滚动，持续 0.85 秒、CD 3.3 秒 |
| 2 | 飞扑，CD 3 秒，实际碰撞传递冲量 |
| 3 | 咸鱼横扫，CD 4 秒；地面击退，跳起目标按碰撞方向打飞 |
| 4 | 冰锥术，冻结 **2 秒**、CD 10 秒，地面扩散雪花 |
| 5 | 破胆怒吼，失控 **2 秒**、CD 15 秒，头顶骷髅图标 |
| 鼠标右键拖动 | 看向其他方向 |
| 鼠标左右键同时按 | 沿镜头方向前进，松开任一键停止鼠标驱动 |
| B / 衣柜按钮 | 岛上换装，独立预览，确认才保存 |
| R | 使用随机拾取的道具，右键转动镜头调整投掷方向 |
| T | 岛上回广场；比赛回检查点；乘机中可退出回广场 |
| Esc / Enter | 暂停/继续；岛上 Enter 输入 `+500` 加蛋币，结算 Enter 重试；衣柜 Esc 取消，Enter 操作焦点按钮 |
| G / 盲盒按钮 | 岛上进入常驻盲盒与机甲主题抽取 |
| F3 / F12 | 性能面板 / 截图 |

岛出生点左前方有三个练习蛋仔，第三个间歇跳跃，旁边有两个等质量可移动方块。它们是岛屿中的训练目标，不能据 `game.racers.size() == 1` 推断场景没有其他可攻击对象。

飞机在右侧升降台旁高平台，乘升降台到顶后沿右边坡道入舱。固定停靠点 `(36, 11.9, 13)`；起飞 5 秒、巡航 20 秒、降落 6 秒，另有开关盖/等待时间。留在舱内不会立即再飞，必须走出后才可重新登机。

## 5. 代码地图与不能随意破坏的接口

| 文件 | 职责 / 修改注意 |
|---|---|
| `main.tscn` → `scripts/game.gd` | 场景装配、岛屿/比赛切换、输入、相机、音效、截图 |
| `scripts/racer.gd` | CharacterBody3D 移动与动画；玩家、AI、练习目标共用 |
| `scripts/race_rules.gd` | 排名、计时、晋级、重开规则 |
| `scripts/course.gd` | 首关布局、检查点、机关与 AI 路径 |
| `scripts/race_ai.gd` | 路宽约束、局部避让、卡住恢复与滚动时机；使用 course 的共享平台数据 |
| `scripts/island.gd` | 岛屿、建筑、练习区与可移动方块 |
| `scripts/attractions.gd` | 摩天轮、升降台、飞机实例、巨型蛋仔 |
| `scripts/plane_ride.gd` | 载人飞机状态机、舱盖网格、登机坡道、曲线路径、乘客退出 |
| `scripts/skills.gd` / `skill_shapes.gd` | 技能时序、碰撞判定、控制状态、特效 |
| `scripts/fountain.gd` / `assets/shaders/` | 连续宽水带、水池和水流着色 |
| `scripts/background_music.gd` | 两首 BGM、循环、快速切场景时的淡入淡出处理 |
| `scripts/hud.gd` | 按 1440×900 设计坐标绘制的游戏界面及点击区 |
| `scripts/skin_catalog.gd` / `outfit_models.gd` | 基础外观与套装 ID、品质、按实例应用材质及装甲几何 |
| `scripts/skin_store.gd` | 皮肤、蛋币、收藏和保底的完整交易，临时文件写入后重命名保存 |
| `scripts/gacha_rules.gd` / `gacha_room.gd` / `coin_console.gd` | 抽取规则、盲盒界面及正整数加币指令 |
| `scripts/wardrobe.gd` | 原生按钮、独立 SubViewport 预览、试穿/确认/取消、焦点 |
| `art/build_character.py` | 当前模型可重建源程序，默认只导出角色 |

关键约束：

- 模型必须保留 `Body`、`ArmL`、`ArmR`、`FootL`、`FootR`，不要随意移动四肢局部原点。模型脚底为 Y=0，全身约高 2，约 1.95 万三角形。Blender Z 向上、前方 -Y，导出 GLTF 后 Godot Y 向上。
- 换色依赖材质名称 `Shell`、`Face`、`White`、`Sole`，五官还使用 `Eye`、`Mouth`、`Blush`。材质修改必须按角色实例隔离，不能改共享导入材质导致所有蛋仔变色。
- 皮肤只影响外观：现有角色胶囊半径 `.51`、高度 `1.7`、中心 Y `.88`，质量 `1.0`，collision layer `2` / mask `7`。不要为穿皮肤偷偷改动速度、质量或命中规则。
- 暂停使用 `game.paused` 布尔状态，不是整个 SceneTree 暂停。移动、设施、技能自行检查；BGM 暂停时继续播放。新增会动的设施需纳入这一机制。
- 飞机乘客通过 `racer.vehicle` 绑定，飞行中位置跟随 `passenger_position()`，跳跃/技能关闭。重生、回岛、参赛和飞机退出场景都必须清理绑定及碰撞例外。
- 衣柜仅在岛上、落地、未乘机、未受控且未施放相关动作时开放。试穿改预览模型，确认才改玩家并保存；打开时暂停世界，关闭时释放输入/焦点。
- 当前皮肤 ID 为 `classic / peach / mint / sky / berry / royal`。重命名 ID 会影响旧存档；失效 ID 目前回退到 classic。测试使用独立保存路径 `game.skin_save_path`，不要覆盖玩家真实存档。

## 6. 测试与实际验证

以下为当前仓库可用入口，默认从项目根目录运行。先导入资源，再测试；**按顺序运行引擎实例**，不要并行跑性能或短间隔输入用例。

快速接手检查：

```sh
mkdir -p captures
"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --headless --path . --quit-after 1800 --script tests/test_rules.gd
"$GODOT_BIN" --headless --path . --quit-after 1800 --script tests/test_island.gd
"$GODOT_BIN" --headless --path . --quit-after 1800 --script tests/test_skins.gd
"$GODOT_BIN" --headless --path . --quit-after 1800 --script tests/test_wardrobe.gd
"$GODOT_BIN" --path .
```

每个命令都检查退出码、脚本自己的 `PASS`/`FAIL` 和错误日志。`--quit-after` 是引擎帧数上限，不是秒；到了上限被结束而没有 PASS，不能计为通过。慢机器可以提高上限，先分清运行慢、挂起和脚本异常。

按改动选择回归：

| 改动 | 主要测试 |
|---|---|
| 移动/相机/按键 | `test_response.gd`、`test_solo.gd`、`test_new_controls.gd`、`test_skill_input.gd` |
| 技能/冲量/命中 | `test_skills.gd`、`test_impacts.gd`、`test_skill_input.gd` |
| 场景/赛道 | `test_world.gd`、`test_island.gd`、`test_long_course.gd`、`test_solo_route.gd` |
| 升降台/摩天轮 | `test_lift.gd` |
| 飞机 | `test_plane_access.gd`、`test_plane.gd`（建议帧上限 5000） |
| 音乐 | `test_music.gd`，另需实际听循环与场景切换 |
| 角色/皮肤/衣柜 | `test_skins.gd`、`test_wardrobe.gd`、原生 `wardrobe_preview.gd` |
| 盲盒、钱包与套装 | `test_gacha.gd`、`test_gacha_ui.gd`；后者加 `-- --visual` 原生验证点击、文本输入和截图 |
| 道具 | `test_items.gd`（至少 5000 帧），检查实际弹道、击飞、传送、部署、增益、AI、R/T 与清理 |
| 完整 AI 比赛 | `test_race.gd`，帧上限至少 12000；从岛屿参赛入口创建 32 人道具赛，并检查 AI 拾取和使用 |
| 人机拥堵与决策 | `test_race_ai.gd`，至少 7500 帧；停住领跑者、实体箱、最后窄桥、错位跳台、攻击提前量与遮挡、道具使用条件 |

完整单人路线测试也应给至少 12000 帧。`test_race.gd` 加 `-- --visual` 可在原生窗口生成倒计时、比赛中和结算截图。`test_plane.gd` 自行使用 4 倍时间和 240 Hz 物理加速逻辑测试，不能用其耗时评价渲染性能。

`test_race.gd -- --seed=91` 可切换道具种子；自动玩家也可能被淘汰，测试检查实际晋级状态而不保证玩家总能晋级。`test_race_ai.gd -- --visual` 在原生窗口额外保存终点绕人与绕箱截图；专项布置场景冻结比赛计时，整局用时以 `test_race.gd` 为准。

原生视觉入口（不要带 `--headless`）：

```sh
"$GODOT_BIN" --path . --script tests/wardrobe_preview.gd
"$GODOT_BIN" --path . --script tests/plane_preview.gd
"$GODOT_BIN" --path . --script tests/skills_preview.gd
"$GODOT_BIN" --path . --script tests/fountain_preview.gd
```

检查截图后还需真人试玩：走停/转向/跳跃/滚动、双鼠标驱动；打跳起目标；冻结/恐惧；乘升降台登机与下机；衣柜鼠标选择、Tab/Enter/Esc、取消不保存、重启恢复；参赛与返回。

截至 `c065d21`，皮肤/衣柜、操控响应、技能碰撞、飞机往返及原生衣柜交互检查通过。更早的完整赛道、32 人 AI 跑关和性能数据见 `docs/verification.md`。本次 startup 文档提交不是新的全量游戏验收；新机器仍需实测。

## 7. 排障记录：先核对这些已踩过的坑

| 症状 | 已知原因 / 处理经验 |
|---|---|
| 克隆后报资源缺失或脚本依赖加载失败 | `.godot/` 是本地生成缓存，先用同版本编辑器导入；核对 GLB、字体和脚本实际存在。不要把旧机缓存当必需资产提交 |
| 新中文显示成方块/缺字 | 字体是按 `scripts/*.gd` 字符集裁剪的。新增 UI 中文后运行 `build_fonts.py`，提交两份 TTF 再导入；以后把文案移到 JSON/子目录时，也要扩展收集范围 |
| 本机有字体但 Godot 报 `FreeType: Error loading font: ''` | 历史上 SystemFont 不可靠，已改为仓库内 CloudSans；不要恢复依赖系统字体 |
| Blender 背景生成查不到 Principled BSDF，或空节点后失败 | 节点显示名可能本地化；用 `node.type == 'BSDF_PRINCIPLED'` 查找，当前脚本已如此实现。重现时先用 `--factory-startup`，检查日志而非直接换模型参数 |
| Godot 环境反射常量解析失败 | 当前使用 `Environment.REFLECTION_SOURCE_SKY`；曾误用 `REFLECTED_SOURCE_SKY` / `REFLECTED_LIGHT_SOURCE_SKY` |
| 模型预览图颜色异常 | 游戏启用 HDR 2D，截图用 `game.screenshot()`，其中处理 RGBA8 和 linear→sRGB；不要直接保存未经颜色转换的 viewport 图像 |
| 模型背面对着镜头 | 角色 physics 会按控制朝向更新 pivot。静态特写需要停止该测试角色的物理更新再摆朝向，不能只停 `game._process()` |
| 鼠标转向跳动/缩放后变敏感 | 使用 `screen_relative`，不要直接以缩放后的 relative 作为唯一输入；释放任一鼠标键、暂停或失焦要释放捕获状态 |
| 多实例无界面运行时数字键 3–5 测试失败 | 曾出现，单独重跑通过；原因尚未完全定位。不要直接降低技能约束以“修测试”，先单独复现，检查输入事件与物理帧时序，并做原生验证 |
| 衣柜 Tab/方向键/空格不能操作按钮 | 曾在 `game._input` 把衣柜期间所有按键标记 handled。现只主动消费 Escape，其余交给 GUI；关闭时释放焦点，Enter 应执行当前聚焦按钮，而非一律保存 |
| 自动鼠标测试首次点取消没反应 | 只注入按下/松开不等于完整鼠标操作；当前原生测试先发送 MouseMotion 更新位置/悬停，再按下/松开。不能只调用 ui_action 就声称点击已验证 |
| 灰色舱盖变成细高尖顶 | 初版 SphereMesh 半球缩放与轮廓不匹配；已换成 `canopy_mesh()` 生成的扁椭球壳，边框与壳面同尺寸 |
| 走上登机坡道却卡住 | 早期低坡道撞上机翼侧面。当前先升至 Y=12.17，再经平桥跨过机翼；不要只测直接传送进座位，必须回归实际步行登机 |
| 登机时舱盖没及时打开 | 靠近检测曾过小，现水平 8 单位、相对高度差小于 3；先检查检测空间和停靠/开盖状态 |
| 下机马上再次起飞 / 中途回广场后还跟着飞机 | 需要 disembark 状态等待离舱，以及重生/换场景解除 vehicle 和碰撞例外；已有完整测试覆盖 |
| 喷泉只有散落小水珠 | 用户明确要求有形状、连续且宽扁的水流。保留带状网格/着色器，不要用几个粒子替代主水流 |
| 共面地板闪烁、文字缺笔画、雕塑埋入底座、树冠遮镜头 | 历史上已分别调整几何/完整字形导出/底部对齐/镜头和布局；改场景后要查看多个实际角度 |
| 合批后扁平物体或圆屋光照失真 | 试验性静态合批对非均匀缩放的法线处理有问题，且未证实帧时间收益，已撤回；不要只凭 draw call 少就恢复 |

### 仍存在或未验证的事项

- **偶发帧时间尖峰尚未彻底解决。** 扩岛后旧机出生点短样本约 13.52 ms 平均、P95 23.29 ms、P99 54.70 ms；这是旧配置/固定视角样本，不是新机器或新模型的性能承诺。
- 画质取舍目前是 2× MSAA、两级阴影、阴影距离 70、岛屿 90% 内部分辨率/FSR、赛道 100%。降低到 65% 曾帮助诊断 GPU 负担，但不是默认画质；提高/降低参数前做同路段、同视角、预热后的 A/B。
- 无界面退出仍可能报告 `ObjectDB instances were leaked at exit` 和 `resources still in use at exit`。它们在本轮皮肤开发之前已存在，尚未根治；不能称日志全绿。另有 Parse Error / SCRIPT ERROR 或缺少 PASS 时必须单独排查，不要全部归为旧警告。
- 原生 macOS 以外的平台、不同 GPU、完整 32 人性能、发行安装包都没有完成当前版本的全面验证。
- `tools-build-app.sh` 假设本地已经存在 `.tools/Godot.app` 和 `dist/CloudClub.app` 壳，只更新资源包并签名；**不能在全新 clone 上当作完整打包器使用**。`export_presets.cfg` 也是早期配置，保留 `CloudClub` 命名。
- 最终角色还原程度与操作手感仍需要用户反馈，不能把生成图或测试通过当作用户验收。

性能测试只运行一个原生游戏，关闭本项目其他测试/Blender；不要终止无关应用。`tests/perf_short.gd` 与 `-- --original-quality` 可做历史对照，但新机器需记录版本、分辨率、renderer、预热方式、平均/P95/P99/max。写截图会干扰帧时间，分开测。

## 8. 哪些东西不随 Git 迁移

`.gitignore` 排除了 `.tools/`、`.godot/`、`captures/`、`dist/`、Python 缓存、Blender 备份、临时文件和 `.env` 等。本仓库没有需要搬运的后端密钥，也不要把认证文件放入公开库。

- `captures/` 中的旧日志和截图只在原机上。本文和验证记录引用这些文件并不意味着新 clone 会有它们。重新运行预览即可生成新的证据。
- `game.output_path()` 优先使用已存在的项目 `captures/`，否则写到 `OS.get_user_data_dir()/captures`。想把结果留在项目目录，先 `mkdir -p captures`。
- 真实皮肤选择是 `user://appearance.cfg`，不在 Git；想保留旧机穿着可另外迁移该文件，不迁移则回到经典黄蛋仔。用 Godot 的用户数据目录入口或 `OS.get_user_data_dir()` 找路径，不把旧机绝对路径写死进代码。
- `.tools/font-venv` 不能跨机器复制当作可移植环境，按上面的命令重建。Godot/Blender/ffmpeg 也分别安装。
- `.import` 资源设置和 `.uid` 脚本标识已经纳入 Git；不要将它们与 `.godot/` 缓存一并删掉。
- 不要求新机器具备旧机的特定 Codex 插件、MCP 或权限配置；命令行 Godot/Blender 足够完成主要工作。遇到沙箱拒绝，先区分工具权限与程序自身失败，并说明实际受阻命令。

## 9. 后续提交与收尾

确认当前在 dev → 完成修改 → 跑相关测试 → 对视觉/交互变化看原生效果 → 更新必要说明 → 提交。工作区干净且确认远端无意外分叉后可用：

```sh
git fetch origin
git switch main
git merge --ff-only origin/main
git merge --ff-only dev
git switch dev
git merge --ff-only main
git push -u origin dev main
git status --short --branch
git ls-remote origin refs/heads/dev refs/heads/main
```

这些是线性历史下的常规命令，某一步失败就停下来核对，不继续执行后面的推送。需要真正解决分叉时先阅读双方改动并重新验证；不要默认 force push。

向用户报告：做了什么、实测到什么、还未验证什么、提交号与远端是否同步。常规完成后回到 dev；不要只口头说“已合并/已推送”，要核对本地和远端引用。
