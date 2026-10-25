# 《未尽之托 / Left in Trust》Windows 阶段二切片

Godot 4.7.2 标准版 / GDScript。常规流程为：标题页 → 选择 1–2 名同行者 → 普通战 → 单人休息恢复 → Boss 战 → 结果页；三名角色可共同进入独立测试场。标题页会识别可继续的真实文件存档。

## 数据同步

`docs/首批内容.json` 是唯一人工编辑的数值源。`game/data/content.json` 与 `content.sha256` 都由脚本生成，不应手工修改。

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\_build\sync_game_data.ps1
powershell -ExecutionPolicy Bypass -File .\_build\sync_game_data.ps1 -Check
```

## 启动

先安装 Godot 4.7.2 Standard（Windows x86_64，非 .NET 版），同步数据后运行：

```powershell
godot --path .\game --editor
godot --path .\game -- --seed=20261025
```

也可在编辑器中打开 `game/project.godot` 后按 F6/F5。运行日志会输出 run seed 和每场 battle seed；`--seed=数字` 可复现实验。

## 测试

```powershell
node .\_build\validate_gameplay_v05.cjs
godot --headless --path .\game --script res://tests/test_rules.gd
godot --headless --path .\game --script res://tests/audit_probe.gd
godot --headless --path .\game --script res://tests/smoke_runs.gd
godot --headless --path .\game --script res://tests/test_ui_flows.gd
godot --headless --path .\game --script res://tests/test_multiplayer.gd
godot --headless --path .\game --script res://tests/test_save_manager.gd
```

`test_multiplayer.gd` 覆盖三种双人组合、三人行动顺序、替补牌过滤、下线封存、锁定目标、定向保护、额度转交与胜后恢复。`test_save_manager.gd` 使用真实文件覆盖临时文件截断、主档损坏、校验错误、上一有效档恢复、结算重载幂等和不支持 schema。

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
.\dist\windows\LeftInTrust.exe --seed=20261025
```

导出物为 `dist/windows/LeftInTrust.exe`，PCK 嵌入可执行文件。请从 PowerShell 或资源管理器直接启动一次，以验证非编辑器环境。

## 当前边界

本切片实现 1–2 人常规战斗、三人独立测试场与本地存档；仍不含随机地图、完整第一章、剧情事件、商店、正式招募、收藏、挑战难度、隐藏 Boss、进化或后续角色。角色图使用明确标注为 PLACEHOLDER 的内置占位 SVG，未改动现有美术原图。
