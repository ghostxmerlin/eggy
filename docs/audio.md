# 动作声音与角色台词

2026-09-13。声音在本地播放，运行游戏不需要联网、Python、语音服务或系统朗读声音。

## 动作反馈

14 种音效：跳跃、轻落地、碰撞、击倒/重落地、掉落复位、滚动、飞扑、咸鱼挥击、实际命中、冻结、解冻、怒吼、道具拾取和使用。音效来自 `art/build_action_audio.py` 的合成波形，素材位于 `assets/audio/actions/`。

起跳在实际获得向上速度时发声，空中无效跳跃不发声。落地要求从空中接触地面且下落速度超过 2，超过 12 使用重落地声；普通站立不重复播放。侧面碰撞检查相对法向速度，低于 2.5 不播放，同一角色碰撞/击倒间隔至少 0.42 秒。击倒音效对应现有强受击、机关击飞及重落地事件，本轮没有新增倒地控制或碰撞规则。

玩家保留 4 个声音通道，附近人机最多 6 个空间通道，超过玩家 20 单位距离不播放；同类人机音效共享 0.16 秒间隔。技能冷却失败不会播施法声，咸鱼挥空和实际接触使用不同声音。声音使用独立随机数生成器，不改变 AI、道具或抽取结果。

## 随机台词

13 句中文语音：

| 情境 | 台词 |
|---|---|
| 出发 | 冲呀，出发！ / 准备好了吗？我先走啦！ |
| 催促 | 来不及了！ / 搞快点，搞快点！ |
| 跑动 | 嘿嘿，追不上我吧！ / 向前冲，别停下！ / 今天也要玩个痛快！ |
| 受挫 | 哎哟！稳住，稳住！ / 没关系，再来一次！ |
| 技能 | 看我的！ / 让一让，我来啦！ |
| 冲线 | 耶，我到终点啦！ / 这把跑得真不错！ |

只让玩家角色说完整台词，附近 AI 保留动作声音，避免 32 人同时说话。普通跑动约每 18–30 秒尝试一句；技能有 22% 概率触发、受挫 65%，均受全局语音间隔限制。每句后至少间隔 10–18 秒，不重叠、不连续重复同句。比赛最后 30 秒催促至多一次，接近终点时也可能随机催促；出发和冲线使用对应台词。静止、乘机、衣柜、盲盒等暂停界面不产生闲聊。

台词显示头顶字幕。说话时背景音乐降低 7 dB，结束后平滑恢复；音乐换曲淡入淡出继续有效。暂停会暂停当前动作音效与语音、隐藏字幕，继续后恢复；重开和切场景停止旧音效与台词。

## 素材生成

`art/build_character_voice.py` 读取 `scripts/gameplay_audio.gd` 的台词目录，用 [MeloTTS-Chinese](https://huggingface.co/myshell-ai/MeloTTS-Chinese) 的通用合成女声离线生成 WAV，再稍微提高音调和速度。不是官方配音或真人录音。模型通过 [sherpa-onnx 官方转换包](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html#vits-melo-tts-zh-en-chinese-english-1-speaker) 运行；MIT 许可副本随生成声音保存于 `assets/audio/voice/MeloTTS-LICENSE.txt`。

开发依赖为 Python 3.9、sherpa-onnx 1.13.8、numpy 2.0.2；模型和虚拟环境放 `.tools/`，不提交 Git。下载 `vits-melo-tts-zh_en.tar.bz2` 并解压到 `.tools/` 后：

```sh
python3 art/build_action_audio.py
.tools/voice-venv/bin/python art/build_character_voice.py
.tools/font-venv/bin/python art/build_fonts.py
.tools/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import --quit
.tools/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --quit-after 5000 --script tests/test_gameplay_audio.gd
```

最后一项用原生混音器检测实际声音，不能用无界面静音结果代替。音色、台词节奏和音量的主观感受仍以试玩为准。
