# 单人操作调试 · 2026-09-12

针对“帧率偏低、操作粘滞”调整了玩家控制器和跟随镜头，并减少 GPU 阴影与抗锯齿开销。

## 控制器

- 跑速仍为 8；地面加速度 40 → 96，空中 19 → 42，松键制动 140，反向制动 200。
- 玩家模型转向响应系数 14 → 28；比赛镜头跟随系数 6.8 → 24。
- `tests/test_response.gd` 使用真实引擎输入验证：100ms 内达到至少 7.5 跑速；100ms 内反向达到至少 6；松键后 83ms 内停稳；镜头快速靠近跟随位置。这里衡量游戏逻辑响应，不是键盘到屏幕的端到端延迟。
- 原参数四项失败，修改后四项通过，日志为 `captures/response-red-output.log` 和 `captures/response-green-output.log`。
- `tests/test_solo.gd` 覆盖移动、停步、跳跃、滚动、相机相对移动、暂停、掉落复位、重开及冲线。原有退出资源警告仍待单独处理。

## 原生渲染短时对照

Apple M4 Pro，Godot 4.7.2 Metal Forward+，1440×900；单独运行一个游戏窗口，自动控制同一路线，预热 2 秒、采样第 2～10 秒。数据只代表本机短时样本，不代表全关稳定帧率。

| 设置 | 平均帧时间 | P95 | P99 |
|---|---:|---:|---:|
| 原设置：4× MSAA、四级阴影、阴影距离 110 | 15.20ms | 23.35ms | 24.11ms |
| 新设置：2× MSAA、两级阴影、阴影距离 70 | 12.46ms | 16.89ms | 18.00ms |

日志：`captures/solo-unbatched-warm.log`、`captures/solo-balanced.log`。新设置保留角色几何、材质、环境遮蔽与完整渲染分辨率；代价是边缘抗锯齿采样减少、远处阴影距离缩短。平均帧时间约降低 18%，不能据此宣称全程无卡顿。

低分辨率诊断（65%）显著改善帧时间，支持 GPU 负担是当前瓶颈之一；该分辨率没有作为默认设置。静态场景合批未测得明确收益，已撤回。

复测入口：

```
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/perf_short.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/perf_short.gd -- --original-quality
```

两次应顺序运行。最终手感需要人工试玩；32 人比赛性能及应用打包不属于本轮验收。

## 蛋仔岛新增验收

- 默认入口为蛋仔岛，`--practice` 仍可直接进入单人赛道。
- `tests/test_island.gd` 验证自由移动、无比赛计时、掉落复位、参赛、冲线回岛、再次参赛与暂停回岛。最终通过，见 `captures/island-final.log`。
- 既有单人操作和响应回归仍通过：`captures/island-solo.log`、`captures/island-response.log`。这些测试仍有既有退出资源警告；无界面运行也可能出现 macOS 证书访问提示。
- 原生画面检查修正了共面地板闪烁、雕塑埋入底座、文字加工缺笔画及树冠遮挡角色的相机问题。最终截图：`captures/island-front.png`、`captures/island-side.png`、`captures/island-to-race.png`。
- 雕塑由完整字形网格导出，再在 Blender 中添加圆角；可编辑源文件 `art/island_monument.blend`，生成入口 `art/export_letter_meshes.gd` → `art/build_island_letters.py`。
- 岛屿性能脚本 `tests/island_preview.gd`：预热 150 帧，然后在出生点静止采样 8 秒；不包含截图保存，不能代表整岛跑动的所有视角。
- 最终出生点静止样本：平均 11.11ms（约 90 FPS）、P95 16.65ms、P99 18.19ms，见 `captures/island-performance-final.log`。
- 新版原生窗口已打开并检查；自动流程测试调用与按钮相同的动作入口，鼠标命中测试不计入自动覆盖。

## 岛屿扩建与首关加长

- 岛屿半径从约 26 扩至 48，面积约为原来的 3.4 倍。新增旋转摩天轮（保持座舱水平）、环岛飞行的小飞机、动态喷泉、载人升降台和约 30 单位高的巨型蛋仔。游戏名改成灯柱广告牌。
- 改为 W/S 前后、Q/E 平移、A/D 转向，方向键对应前后与转向。身体摇摆和脚步动作是视觉动画，不放缓移动响应。
- 赛程从 159 延至 318 单位；断口 3 → 13，增加错位跳台和无护栏窄桥；途中检查点增至 6 个，进度标记按检查点实际距离计算。
- 新控制、长赛道路面、升降台与摩天轮载人测试通过；单人流程、岛屿往返、响应、规则和场景回归通过。日志：`captures/test_*-expansion-final.log`、`captures/rides-final.log`。
- 正常控制接口的单人自动跑关在 41.22 秒抵达新终点（`captures/long-route.log`）；32 人回归有 24 人完成，玩家第 1，整局 78.77 秒（`captures/expanded-race.log`）。这些是自动控制数据，不代替人工手感验收。
- 实际渲染图：`expanded-island-spawn.png`、`expanded-island-overview.png`、`expanded-ferris-wheel.png`、`expanded-lift.png`、`expanded-course-gaps.png`，均在 `captures/`。
- 世界光照改用 ACES，调整曝光、环境光、主光、对比度和饱和度，保留动态阴影与环境遮蔽。岛屿镜头扩大视野并抬高视线，以容纳高设施。
- 试验性静态合批减少了绘制次数，但非均匀缩放表面的光照出现失真，且未证明平均帧时间提升，因此撤回。最终使用共享基础网格与岛屿 90% 内部渲染比例、FSR 画面重建，保持界面原分辨率；赛道使用 100% 渲染比例。
- 最终配置的出生点短时采样：平均 13.52ms（约 74 FPS），P95 23.29ms，P99 54.70ms，约 230 次绘制。仍存在偶发帧时间波动，不宣称整岛各视角稳定同一帧率。完整日志：`captures/expanded-performance-final.log`。
- 最终渲染复核已恢复扁平景物与圆形小屋的正确光照；`captures/expanded-visual-checked.log` 无原生渲染错误。
- 最后一次场景、单人、岛屿、按键、响应、新赛道和设施载人回归均通过，见 `captures/test_*-expansion-final.log`。


## 2026-09-12：蛋仔外形与衣柜

- 重新建模黄色球形蛋仔，保留五个动画节点与原碰撞体；GLB 为 453 KB，约 1.95 万三角形。Blender 源文件与生成脚本一并保留。
- `test_skins.gd` 验证六款切换、独立材质、保存重载、无效与损坏存档回退；`test_wardrobe.gd` 验证试穿取消、确认保存、重启恢复、参赛回岛、飞行禁用与键盘焦点，均通过。测试存档使用独立路径，不覆盖玩家选择。
- 原生 `wardrobe_preview.gd` 通过 B 键与完整鼠标移动、按下和松开事件检查取消、卡片选择和确认。检查了经典款、贝雷帽、皇冠以及岛上正面近景。图像保存在本机 `captures/wardrobe-*.png` 与 `captures/character-island-closeup.png`。
- 操控响应、技能碰撞、飞机完整往返回归通过。数字键测试在多个无界面游戏同时运行时出现过 3–5 键触发断言失败，单独重跑通过；未据此修改游戏技能参数。无界面退出仍存在此前的 ObjectDB/resource 警告。
- 发现并修复衣柜吞掉 Tab / 方向键的问题；焦点落在“取消”时按 Enter 不会保存试穿，回归已覆盖。
- 这些结果验证实现与实际渲染，不等同于用户对原版形象还原程度的最终认可。

## 2026-09-13：恢复 32 人巅峰赛

- 默认启动仍为蛋仔岛；“参赛”、岛上 Enter 和暂停菜单参赛统一进入 1 名玩家 + 31 名人机比赛，3 秒倒计时、150 秒限时、前 24 名晋级。复用原有 AI、物理与技能，保留玩家实例和已穿皮肤；重开不重复添加人机，返回岛屿会清理比赛人机。
- `test_island.gd` 通过：精确核对 1 名玩家、31 名 AI 和唯一选手 ID；倒计时、暂停冻结、玩家晋级、重试、返回后销毁旧人机、Enter 再次参赛及暂停菜单参赛均覆盖。
- `test_world.gd`、`test_wardrobe.gd` 通过；`test_solo.gd -- --practice` 通过，单人入口仍无倒计时、无时限并可重开及完成赛道。
- 普通游戏窗口实际鼠标点击“参赛”后，确认 31 名人机向前跑动、排名为第 32 名、晋级计数及倒计时正常显示；Esc 暂停后点击“返回岛屿”成功，最终保留岛屿窗口供用户试玩。
- 在新机 Apple M4 上使用 Godot `4.7.2.stable.official.ed1daf0bf`、Metal Forward+、1440×900 原生窗口运行完整比赛。从岛屿实际参赛动作创建选手，再通过正常移动、跳跃、滚动接口自动控制玩家；两轮均在 43.30 秒到达终点并获第 1 名，82.22 秒满 24 名晋级，测试退出码为 0。
- 本地日志：`captures/multiplayer-island.log`、`multiplayer-world.log`、`multiplayer-wardrobe.log`、`multiplayer-solo.log`、`multiplayer-full-native.log`。原生画面：`race-32-island-entry.png`、`race-32-countdown.png`、`race-32-running.png`、`race-32-result.png`。截图前将测试窗口移到前台，并等待 HUD 绘制，避免记录到后台窗口或上一帧的画面。
- 岛屿、衣柜、单人测试及第二轮原生完整比赛退出仍出现此前记录的 ObjectDB/resource 释放提示；无脚本解析或原生渲染报错。本次验证功能与画面，未进行全程帧时间分布测量，不据此宣称 32 人全程稳定帧率。

原生完整比赛复测命令：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --quit-after 12000 --log-file captures/multiplayer-full-native.log --script tests/test_race.gd -- --visual
```

## 2026-09-13：巅峰赛随机道具

- 加入十二种道具及其自制 3D 外观，十排平台共 44 个问号箱。碰触随机拾取、一次携带一个、R 使用，原复位键改为 T。人机遵循相同拾取和消耗规则，按附近目标投掷攻击道具。具体行为与数值见 [道具说明](items.md)。
- `test_items.gd` 通过：真实接触拾取、满槽不覆盖、重复拾取限制、四秒刷新、十二种抽取覆盖、R 使用／长按不连发、T 回检查点、受控禁止使用、真实弹球击出边界与复位、墨汁及爆炸命中、烟雾范围、跨断口传送、墙面与无效落点、绳索拉动两人、弹板弹飞、一次性地雷、实体箱站立、加速／喷气／秒表、AI 使用、暂停和重开回岛清理。
- 原生 `items_preview.gd` 通过，并逐张检查六张实际截图：`items-picked-ball.png`、`items-ball-knockout.png`、`items-portals.png`、`items-ink-hit.png`、`items-springboard.png`、`items-jetpack.png`，均在 `captures/`。预览使用隔离的两名选手布置，调用真实拾取、R 输入、弹道和物理效果；完整 32 人流程另行验证。
- 首次原生完整道具赛（固定道具种子 2026）：30 名人机拾取并使用道具，玩家使用一次；玩家 48.25 秒获第 2 名，108.42 秒满 24 名晋级。记录到墨汁命中 15 次、炸弹 13 次、地雷 20 次、弹球 16 次、绳索 8 次，传送 33 次、弹板触发 48 次。日志 `captures/items-full-native.log`。这些结果包含道具实际生效后的比赛进程，不是关闭道具的 AI 跑关。
- 加入近墙投掷检查后的最终原生全场复测通过：30 名人机拾取并使用，玩家使用三次；玩家 41.55 秒获第 1 名，113.43 秒满 24 名晋级。墨汁／炸弹各命中 16 次、地雷 27 次、弹球 34 次、绳索 7 次，传送 17 次、弹板触发 83 次；结算截图确认 24 / 24。日志 `captures/items-race-final.log`，退出码 0。
- `test_world.gd`、`test_solo.gd -- --practice`、`test_wardrobe.gd`、`test_impacts.gd` 回归通过；单人练习、既有技能、皮肤与衣柜继续工作。日志为 `captures/items-*-final.log`；专项为 `captures/test-items-final.log`。
- Godot 4.7.2、Apple M4、Metal Forward+、1440×900。部分测试退出仍出现 ObjectDB/resource 释放提示，已与断言及脚本错误分开记录；没有把这些日志称为全绿。未测全程帧时间分布，随机局的名次与用时不保证一致。

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5000 --script tests/test_items.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --quit-after 5000 --script tests/items_preview.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --quit-after 12000 --script tests/test_race.gd -- --visual
```
