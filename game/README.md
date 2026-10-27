# 《未尽之托 / Left in Trust》Windows Demo 垂直切片

Godot 4.7.2 标准版 / GDScript。常规流程为：标题页 → 选择 1–2 名同行者 → 序章/任务开场 → 第一章路线图 → 普通战 → 核对/可选休息 → Boss 前验收与战斗 → 胜负片段/结果页；三名角色可共同进入独立测试场。剧情覆盖层支持继续、跳过、最近剧情回看与旅途闲聊，已看标记随真实文件存档恢复。

战斗界面采用仿《杀戮尖塔》的舞台布局：左上只留“第 N 回合”，右上用暂停图标打开设置，2—3 名角色在左侧前后错落并与右侧放大的敌人对峙，角色状态贴在脚边。出牌为鼠标拖拽：把牌拖到敌人/友方/自己身上释放，非法落点回弹并提示。卡面缩为低占比操作带，只保留较小插画、卡名和左上角单个费用数字；悬停详情只显示“归属 + 数值效果”。每名在线角色每回合可不限次数行动，基础攻击与基础防御免费且每回合各限一次；右下圆形发送箭头用于结束回合，左下显示抽/弃数量。战斗与地图右上均可打开暂停/设置层并“返回标题界面”。战斗结束（失败或全部胜利）只显示“本次交付未完成/委托完成”与队内角色名。GPT、Claude、DeepSeek 均使用正式透明主立绘；“缺失附件”使用六层正式怪物资源，“本次提交版”使用正式透明 Boss 主立绘。卡牌插画本轮保持现有资源不变。

地图当前使用低饱和灰纸底、细虚线分支与单色任务符号；普通战后可经过休息或直接前往验收。编队页右上可选择玩家人生身份，大学生、研究员等六种身份轻微改变纸色与课表、实验记录等页边纹样；AI 队友构成不影响地图外观。身份保存在 `runState.stage`，旧存档没有此字段时默认为大学生。大学生/公司员工使用现有阶段专属剧情；研究生、研究员、行业大佬、富翁仅预览地图外观，不播放阶段剧情，专属文本、任务池与遭遇仍属后续范围。当前加载 `assets/map_icons/route_v2/` 的 SVG；旧风景地图和 v1 彩色图标保留为参考。

## 数据同步

`docs/首批内容.json` 是唯一人工编辑的数值源。`docs/Demo剧情脚本.md` 与 `docs/剧情/日常闲聊台词.json` 是运行时剧情源。`game/data/content.json`、`content.sha256`、`story.json` 均由脚本生成，不应手工修改。

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\_build\sync_game_data.ps1
powershell -ExecutionPolicy Bypass -File .\_build\sync_game_data.ps1 -Check
node .\_build\export_story_runtime.cjs
node .\_build\export_story_runtime.cjs --check
```

## 启动

先安装 Godot 4.7.2 Standard（Windows x86_64，非 .NET 版），同步数据后运行：

```powershell
godot --path .\game --editor
godot --path .\game -- --seed=20261025
```

也可在编辑器中打开 `game/project.godot` 后按 F6/F5。运行日志会输出 run seed 和每场 battle seed；`--seed=数字` 可复现实验。

## 测试

推荐在仓库根目录运行一键阶段门禁；命令会按退出码判断成功，并把完整输出同时写入 `_build/evidence/test-logs/` 和 `game/.godot/*-tests.log`：

```powershell
powershell -ExecutionPolicy Bypass -File .\_build\run_stage2_tests.ps1
```

也可以逐项运行：

```powershell
node .\_build\validate_gameplay_v05.cjs
node .\_build\validate_story.cjs
node .\_build\export_story_runtime.cjs --check
godot --headless --path .\game --script res://tests/test_rules.gd
godot --headless --path .\game --script res://tests/audit_probe.gd
godot --headless --path .\game --script res://tests/smoke_runs.gd
godot --headless --path .\game --script res://tests/test_layered_actors.gd
godot --headless --path .\game --script res://tests/test_ui_flows.gd
godot --headless --path .\game --script res://tests/test_ui_clicks.gd
godot --headless --path .\game --script res://tests/test_story_flow.gd
godot --headless --path .\game --script res://tests/test_multiplayer.gd
godot --headless --path .\game --script res://tests/test_save_manager.gd
```

`test_story_flow.gd` 覆盖 117 事件运行数据、单/双人在队过滤、跳过与已看存档、战斗覆盖层和扩展身份边界。`test_multiplayer.gd` 覆盖三种双人组合、三人行动顺序、替补牌过滤、下线封存、锁定目标、定向保护、额度转交与胜后恢复。`test_save_manager.gd` 使用真实文件覆盖临时文件截断、主档损坏、校验错误、上一有效档恢复、结算重载幂等、不支持 schema、剧情状态校验，以及 mode/flow 语义矛盾。

`test_layered_actors.gd` 校验三名正式角色都遵守同一套八层结构和六类动作协议、每套六件分层资源完整，并校验“缺失附件”和“本次提交版”的正式资源可加载。带渲染环境下可运行 `tests/capture_layered_actors.gd` 生成验收图。

## 存档

默认主档为 `user://left_in_trust.save.json`，同目录使用 `.tmp` 临时文件和 `.previous` 上一有效备份。格式的 `schemaVersion` 当前为 1；封套保存完整快照 JSON 与 SHA-256。写入顺序固定为“完整快照 → 临时文件 → 重读校验 → 更新上一有效备份 → 替换主档”。

## Windows x86_64 导出

Godot 需要先安装与 4.7.2 对应的 Export Templates。预设已写入 `export_presets.cfg`：

如果只需 Windows x86_64 模板，也可以使用仓库内的按范围下载脚本；它从 Godot 官方模板包中提取四个 Windows 文件，不下载其他平台：

```powershell
powershell -ExecutionPolicy Bypass -File .\_build\fetch_godot_windows_templates.ps1 -Destination "$env:APPDATA\Godot\export_templates\4.7.2.stable"
```

```powershell
New-Item -ItemType Directory -Force .\dist\windows | Out-Null
godot --headless --path .\game --export-release "Windows Desktop x86_64" ..\dist\windows\LeftInTrust.exe
.\dist\windows\LeftInTrust.exe -- --seed=20261025
```

导出物为 `dist/windows/LeftInTrust.exe`，PCK 嵌入可执行文件。请从 PowerShell 或资源管理器直接启动一次，以验证非编辑器环境。

## 当前边界

本切片实现第一章固定路线图、1–2 人普通战/休息/Boss 流程、首章关键剧情演出与旅途闲聊、三人独立测试场、共享混合手牌、本地存档、三名正式角色与两名正式敌人。仍不含随机地图、第二章可达路线、商店、正式招募、收藏、挑战难度、隐藏 Boss、战斗结算专属台词、进化或后续角色；动效与音效仍属后续范围。卡图当前为可运行的类型化程序插画，尚未逐张制作正式绘图。
