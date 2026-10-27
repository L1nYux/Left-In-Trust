# 《未尽之托》Demo 基础实现验证报告

日期：2026-10-27  
工程：Godot 4.7.2 / Windows / GDScript  
范围：角色与怪物立绘、第一章路线图、战斗场景、战斗 UI、首章关键剧情、1–3 人完整战斗流程。

## 已验证

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 数值同步 | PASS；docs/首批内容.json 与运行时数据一致 | _build/evidence/test-logs/data-sync.log |
| 剧情格式与运行数据 | PASS；117 事件、39 闲聊池，源与 `game/data/story.json` 一致 | _build/evidence/test-logs/story-validation.log、story-data-sync.log |
| 离线规则模型 | PASS；34 项 | _build/evidence/test-logs/node-validation.log |
| Godot 规则 | PASS；13/13 | _build/evidence/test-logs/rule-tests.log |
| 数值与状态边界 | PASS；106/106 | _build/evidence/test-logs/audit-probe.log |
| 单人烟测 | PASS；GPT、Claude、DeepSeek 均完成普通战→休息→Boss | _build/evidence/test-logs/smoke-runs.log |
| 角色/怪物资源 | PASS；三角色、缺失附件、本次提交版均可加载 | _build/evidence/test-logs/layered-actor-tests.log |
| UI 完整流程 | PASS；三种单人、三种双人、三人测试场 | _build/evidence/test-logs/ui-flows.log |
| 真实按钮生命周期 | PASS；12 轮 | _build/evidence/test-logs/ui-click-tests.log |
| 多人语义 | PASS；7/7 | _build/evidence/test-logs/multiplayer-tests.log |
| 剧情流程 | PASS；在队过滤、跳过/已看存档、战斗覆盖层、身份边界 | _build/evidence/test-logs/story-flow-tests.log |
| 存档与恢复 | PASS；10/10，含战前地图、身份与剧情状态 | _build/evidence/test-logs/save-tests.log |
| 实机路线图画面 | PASS；节点落在三处留白，状态/队伍/算力可读 | _build/evidence/demo_chapter_map.png |
| 实机 Boss 战画面 | PASS；透明边缘正常，角色/敌人/意图/手牌无遮挡 | _build/evidence/demo_submit_boss_battle.png |
| 实机剧情覆盖层 | PASS；标题、说话人、正文、页码、跳过/继续无遮挡 | _build/evidence/story_opening_overlay.png |
| 战斗 UI 密度调整 | PASS；卡区缩小、费用数字徽标、简化详情、发送/暂停控件、角色缩放均可读 | _build/evidence/ui_compact_battle_v7.png、ui_compact_card_detail_v7.png |
| 地图科幻环境语言 | PASS；低亮度线路位于节点外留白，不遮挡路线与事件图标 | _build/evidence/ui_map_scifi_v7.png |
| Windows x86_64 导出 | PASS；GPT+Claude 完成普通战与 Boss，结果均为 win；运行数据与新版 UI 已打包 | dist/windows/LeftInTrust.exe、_build/evidence/ui_refresh_export_smoke.stdout.log |

完整门禁命令：

    powershell -ExecutionPolicy Bypass -File .\_build\run_stage2_tests.ps1

## 已实现但未宣称完成

- 当前地图是固定的第一章 Demo 路线，不是随机地图或两章完整地图。
- 117 个事件已导出到运行数据；当前只接通通用序章与第一章固定路线所需的开场、战斗、核对、休息、验收、Boss、胜负片段。第二章、商店、招募与收藏事件尚无入口。
- 当前正式怪物覆盖主流程所需的“缺失附件”和“本次提交版”；首批内容数据中的其余七类敌人尚未接入正式画面与入口。
- 既有轻量动作控制器继续存在；本轮只优化补间更新方式、节奏与缓动，没有新增逐帧角色动作或音效。

Windows 导出包 SHA-256：465F5235590B140F7891670DAB5B256F9730BB4086AB65C31F6090DAD062DF7B，大小 177,403,336 字节。

## 明确范围外

音效/BGM、战斗结算专属台词、商店、招募、收藏、第二章可玩入口、挑战与隐藏战入口。研究生/研究员/行业大佬/富翁目前只有地图外观，不播放阶段剧情。
