# 《未尽之托》代码审查发现（只读审查）

审查者：code-auditor　日期：2026-10-27　范围：`game/`（scripts、tests、scenes、data）、`_build/run_stage2_tests.ps1`
方法：`read`/`grep`/`glob` + Node 读取 JSON/PNG 头信息；**未运行任何 Godot**（避免写 `_build/evidence`、`_build/test_saves`、`user://` 存档），因此涉及运行时行为的结论一律标注「静态推断」。

---

## 0 一句话结论

规则层（`game_rules.gd`）与存档层（`save_manager.gd`）边界干净、可承载扩展；**表现层是一个 2512 行单脚本 + 全坐标硬编码 + 假拆层立绘**，且演出类改动完全没有自动化验收通道（6 个 capture 脚本全不在门禁、门禁全 `--headless` 无像素）。设计方案的 P0（记忆剧场 + 分皮肤/打字机）在代码侧可行，但方案把「八层拆层」当作可复用资产是**事实性错误**，且方案 B 的立绘站位需要先补两处基建（region 裁切、overlay 重排），不是"加一条站位区"。

---

## 0.1 风险分级速查

| 级别 | 编号 | 一句话 |
|---|---|---|
| **高** | 2.1 / 2.3 / R1 / R3 | 八层立绘假拆层（四层不绘制）；面板上方仅 92px 无法放站位区；演出改动无自动化验收；立绘无 region 裁切 |
| **高** | R4 / 4.8 | 5/25 staging 被丢弃（含标题与全部结局）；beats 无数据结构，只能手写 |
| **中** | 1.1 / R2 / 1.3 / R5 / 4.5 / 4.6 / 4.7 | 2512 行单脚本与屏幕重建模式；出牌即写盘 + 存档非原子；剧情队列吞事件；同 speaker 只播第一句 |
| **低** | 1.4 / 4.1 / 4.2 / 4.3 / 4.4 / 4.9 / 4.10 / 3.3 | main.gd 死文件、_target_hint 死代码、三份重复文案器、assert 当不变量、tmp_lead_probe、缩进、盘点型测试 |

## 1 架构

### 1.1 单脚本承担全部界面与流程（最高结构性风险）

- `game/scripts/main_stage2.gd:1`：`extends Control`，全文 **2512 行 / 130 个 func**。
- 三种屏幕各自"清空全部子节点后重建"：
  - `game/scripts/main_stage2.gd:206-232` `_new_screen()`：`for child in get_children(): remove_child(child); child.queue_free()`
  - `game/scripts/main_stage2.gd:234-264` `_new_battle_screen()`
  - `game/scripts/main_stage2.gd:266-282` `_new_map_screen()`
- 布局全部绝对坐标：`.position = Vector2(` **27 处**、`.size = Vector2(` **17 处**、`custom_minimum_size` **25 处**（对 main_stage2.gd 的统计）。
- 后果：任何演出层改动（剧场/皮肤/气泡/转场）都必须改这个文件，回归面 = 整条切片；多人并行修改必冲突。设计方案的 `story_presenters.gd` 方向正确，但工作量不止"新增一个文件"，而是从这个 2512 行脚本里**切出**剧情渲染边界。

### 1.2 规则层干净（承载力最好的一层）

- `game/scripts/game_rules.gd:1-2`：`class_name GameRules` / `extends RefCounted`，502 行 29 func，**0 处 assert**，不依赖 UI。
- 拒绝语义集中在前置校验：`game/scripts/game_rules.gd:202` 注释
  `# Every rejection happens before this point. Mutation begins here.`
- 结算带幂等与实例校验：`game/scripts/game_rules.gd:299-327` `settle_battle()`（`battle_instance_mismatch`、`duplicate` 分支）。
- 结论：玩法侧改动风险低，问题都在表现层。

### 1.3 存档层独立，但写盘密度过高

- `game/scripts/save_manager.gd`：255 行、`class_name SaveManager`、schema 版本 1、temp → 校验 → backup → replace 的完整流程（`save_manager.gd:20-62`）。
- 写盘时机过密：每次出牌都落盘一次 ——
  `game/scripts/main_stage2.gd:1789` `_save_progress("battle")`（`_play_action()` 内，`1786-1791`）
  `game/scripts/main_stage2.gd:1919` `_save_progress("battle")`（`_finish_turn()` 末尾）
  一回合 3–6 张牌 = 3–6 次全量 JSON 序列化 + 写 temp + 反序列化校验 + backup + rename。
- 若 P0 剧场引入自动播放（中途退出即存），写盘频率还会上升。建议：只在 flow 切换/结算落盘，战斗内改为节流（如回合末）。

### 1.4 死文件：main.gd（478 行旧原型）

- `game/scenes/Main.tscn:3`：`[ext_resource path="res://scripts/main_stage2.gd" type="Script" id="1_main"]`
- 全仓库 `.gd`/`.tscn` 对 `main.gd` **零引用**（grep `main\.gd` 无命中；仅 `main_stage2.gd` 4 处命中）。
- 它与 main_stage2 大量重复 helper（`_label` / `_button` / `_panel_style` / `_error_text` / `_compact_effect` / `_intent_text`）。
- 处理成本：删除约 0.5h；但需先确认无美术/回滚诉求。

### 1.5 情节数据层是纯 static 工具（好）

- `game/scripts/story_db.gd`：10 个 `static func`，无状态；`load_story()`(8) 把 events 变成 `eventsById`；`compose_event()`(33) 纯函数式切片。
- `game/scripts/content_db.gd:6-21` `load_content()` 做版本校验（`"0.5"` 不匹配即 `push_error`）。
- 这层可以直接被 presenter / 测试复用，改动安全。

---

## 2 渲染链路契约

### 2.1 「八层立绘」契约名存实亡（双重不符）

运行时层 ID 与资源清单是两套互不接线的清单：

- `game/scripts/layered_actor_2d.gd:9`：`const LAYER_IDS := ["shadow", "aura", "back", "body", "head", "prop", "front", "effect"]`（8 层）
- 资源侧（实测 PNG，Node 读取 IHDR）：`game/assets/actors/<role>/layers/` 只有 **6 个 512×512 部件图**：back / body / head / near_arm / prop / front
  → `near_arm` 没有运行时层，`shadow`/`aura`/`effect` 没有资源（程序绘制）。两套清单**没有任何交叉校验**。
- 更关键：正式立绘只画一个层。`game/scripts/layered_actor_layer.gd:48-50`

  ```
  if FORMAL_MASTERS.has(role_id) and bool(profile.get("formal_art", false)) and layer_id in ["back", "body", "head", "prop", "front"]:
      _draw_formal_actor_layer()
      return
  ```
  `game/scripts/layered_actor_layer.gd:76-77`

  ```
  if layer_id != "body":
      return
  ```
  即：back/head/prop/front 四层**进入了正式立绘分支，然后什么都不画**；只有 `body` 层把整张 master 贴图画出。实际可见层只有 shadow / aura / body(master) / effect。
- 代码自己的注释已承认原因：`layered_actor_layer.gd:71-75`「neck and collar contours were painted independently and cannot form a reliable seam … Runtime therefore keeps the character silhouette on one coherent master layer.」
- **对设计方案的直接冲击**：`docs/剧情演出方式设计方案.md:13` 把「三角色正式主立绘与八层拆层（`game/assets/actors/*/`）」列为可复用资产 —— 这个说法在当前代码下不成立；八层只存在于节点树与测试断言里。

### 2.2 立绘走的是"整图缩放"，不是"裁切"

- `game/scripts/layered_actor_layer.gd:80`：`draw_texture_rect(master, _formal_actor_rect(master_rect), false)`
- `game/scripts/layered_actor_layer.gd:83-86`：
  ```
  var pivot := Vector2(size.x * 0.5, 160)
  var art_scale := float(FORMAL_SCALES.get(role_id, 0.88))
  return Rect2(pivot + (source.position - pivot) * art_scale, source.size * art_scale)
  ```
- `FORMAL_MASTER_RECTS`（`layered_actor_layer.gd:14-18`）是 **208×325 / 222×332** 的目标矩形；实测 master 贴图是 **GPT 1003×1568、Claude 1024×1536、DeepSeek 1024×1536**。`draw_texture_rect` 会把**整张纹理**塞进目标矩形（不裁区域）。两者宽高比恰好接近（208/325=0.640 vs 1003/1568=0.640），所以当前"看起来是对的"——这是巧合级别的耦合。
- 后果（决定方案 B 的成本）：要"取 master 上半身"，必须改用 `draw_texture_rect_region` / `AtlasTexture`；否则换一张构图不同的 master（例如专用半身差分）就会整体拉伸变形，而不是裁切。**改法明确、成本约 0.5 天。**

### 2.3 剧情面板契约：`tone` 产出但无人消费；面板尺寸硬编码

- `game/scripts/story_db.gd` 产出 `{speaker, text, tone}`，tone ∈ dialogue/fixed/scene/stage：`story_db.gd:46,49,51,55,57,62,64,97,102,112,123`。
- 渲染侧完全不读 tone：
  `game/scripts/main_stage2.gd:440-446`
  ```
  var page: Dictionary = story_pages[story_page_index]
  var speaker := str(page.get("speaker", "旁白"))
  story_speaker_label.text = speaker
  ...
  story_body_label.text = str(page.get("text", ""))
  ```
- 面板固定：`game/scripts/main_stage2.gd:388-390`
  ```
  panel.name = "StoryPanel"
  panel.position = Vector2(170, 92)
  panel.size = Vector2(940, 536)
  ```
  正文区 `custom_minimum_size = Vector2(0, 280)`（`407-408`）、label `Vector2(820, 260)`（`414`）。
- **承载力量化**：`project.godot` 视口 1280×720；面板占 y=92..628，**面板上方只剩 92px**。方案 B 要求「对话框上方加 220–260px 站位区」→ 当前布局放不下，必须重排整个 overlay（不是追加一条）。这条直接决定 B 是一个"重排"任务而非"加条"任务。

### 2.4 无动效基建、无音频

- `main_stage2.gd` 中 `create_tween` **0 次**、`visible_characters` **0 处**（打字机所需机制不存在）。
- 角色侧反而有：`game/scripts/layered_actor_2d.gd:125` `_motion_tween = create_tween()`；`64-75` 用 `_process` 做呼吸位移。
- 音频：对 `game/` 全量 grep `AudioStream|AudioServer|BGM|SFX` → **No matches**（与 `docs/剧情演出方式设计方案.md:14`「音频管线：尚无」一致）。
- 结论：方案 A 的"打字机"是从零加状态机；方案 §7.3 的 BGM/SFX 是从零建管线（+1 天判断合理）。

### 2.5 屏幕重建模式会吞掉演出中间态

- `_new_screen()` 在 `main_stage2.gd:207` 第一件事就是 `_reset_story_overlay_state()`；而 `_close_story_overlay()`(490-498) 会把 `story_pages` / `story_page_index` 全部清空。
- 若剧场按"自动播放在 N 秒内跨多次 await"实现，任何一次 flow 切换（`_show_map` / `_show_result`）都会把剧场状态清掉。演出的生命周期必须挂在独立节点（而不是这套"每次重建"的屏上）——这条在实现前就要定，不能边写边试。

---

## 3 测试体系

### 3.1 门禁构成（`_build/run_stage2_tests.ps1`）

- `78-81`：4 个静态/数据校验
  `sync_game_data.ps1 -Check`、`_build/validate_story.cjs`、`_build/export_story_runtime.cjs --check`、`_build/validate_gameplay_v05.cjs`
- `83-94`：10 个 Godot 脚本，统一 `--headless`（`97`：`@("--headless", "--path", ".\game", "--log-file", $engineLogPath, "--script", $entry.Value)`）
  rule-tests / audit-probe / smoke-runs / layered-actor-tests / ui-flows / ui-click-tests / map-route-tests / story-flow-tests / multiplayer-tests / save-tests
- 失败判定 = 退出码非 0（`70-72` `if ($exitCode -ne 0) { throw ... }`）。

### 3.2 断言风格：无 assert，全部 `push_error + quit(1)`

- `game/tests/test_rules.gd:45-47`：
  ```
  func _fail(message: String) -> void:
      push_error("[FAIL] %s" % message)
      quit(1)
  ```
  全 18 个测试脚本 `assert(` 计数为 **0**。
- `test_policy.gd`（32 行、无 quit）是 smoke_runs 的 helper，不计入门禁测试数。

### 3.3 门禁是"不崩即通过"的地方不少

- `audit_probe.gd` 1368 行、`audit_numeric.gd` 917 行：0 assert、仅 `print` + `quit(0)` → 它们 PASS 只表示脚本跑完没抛错，**不表达任何期望值**。
- `test_layered_actors.gd` 属于"盘点型断言"：它断言的是**资源存在 + 节点层名列表**，不是"第 i 层渲染第 i 个资源"。
  - `game/tests/test_layered_actors.gd:32-34`：`if actor.get_layer_names() != EXPECTED_LAYERS: _fail(...)`
  - `55-63`：只检查 6 个 part PNG 存在且有 mipmaps
  - 因此它**在四层不绘制的情况下依然全绿**（见 2.1）——测试给了虚假信心。

### 3.4 抓图脚本全部不在门禁（演出改动无法自动验收）

`game/tests/` 下 6 个 capture：`capture_title.gd`(32)、`capture_story_overlay.gd`(37)、`capture_map_routes.gd`(100)、`capture_layered_actors.gd`(40)、`capture_layered_actor_closeups.gd`(36)、`capture_life_stage_comparison.gd`(76) —— `run_stage2_tests.ps1:83-94` 一个都没列。
它们的产物是 `_build/evidence/*.png`（`capture_title.gd` 等写 evidence）。→ 方案 §4A/§4C 的验收条件（"抓图脚本抓三类皮肤"/"抓图脚本记录每 beat 帧"）**目前没有可执行通道**。

### 3.5 headless 无像素，UI 测试验的是节点与字符串

- 门禁全 `--headless`：Control 会算布局，但不产生像素。
- `game/tests/test_ui_flows.gd:62` 的"视觉细则"实际是文本禁词检查：
  ```
  for retired_detail in ["费用", "归属", "目标", "token", "拖到"]:
  ```
  即它保证"详情面板不再出现这些词"，而不是版面正确。
- `game/tests/test_ui_clicks.gd:37-44` 绕过真实输入链路，直接调内部方法：
  ```
  if not game.call("_begin_drag", "basic_attack"):
  ```
  真实 `InputEvent` → `gui_input` → 当前 Control 命中分发**未被覆盖**。
- 连带证据：`main_stage2.gd:1418` `func _target_hint(definition)` 产出「拖到敌人身上释放」等旧文案，全仓库**无调用者**（grep 仅命中定义处 + `1091` 的 tooltip + `1617` 的提示）—— 死代码，且与 `test_ui_flows.gd:62` 的禁词规则方向相反。

### 3.6 测试会写真实路径（本次未运行的原因）

- `game/tests/test_ui_clicks.gd:16`：
  ```
  var save_path := ProjectSettings.globalize_path("res://../_build/test_saves/ui_clicks.json")
  ```
  同理 `test_story_flow` / `test_save_manager` 落 `_build/test_saves/*`。我按要求未执行门禁。

---

## 4 代码质量

| # | 问题 | 证据 | 成本 |
|---|------|------|------|
| 4.1 | 死文件 main.gd 478 行，全仓库零引用 | `game/scenes/Main.tscn:3`、grep `main\.gd` 无命中 | 0.5h |
| 4.2 | 死代码 `_target_hint()` 无调用者 | `game/scripts/main_stage2.gd:1418-1428` | 5min |
| 4.3 | 三份重复效果文案生成器 | `main_stage2.gd:1381 _effect_text` / `1399 _compact_effect_text` / `2131 _compact_effect` | 0.5d |
| 4.4 | `assert` 当不变量，release 导出会被剥离 | `main_stage2.gd:1927`：`assert(int(battle_state["accounts"][role_id]["token"]) == int(before_accounts[role_id]["token"]))` | 0.5h |
| 4.5 | 存档 replace 非原子（先删后 rename） | `save_manager.gd:245-255`：`DirAccess.remove_absolute(destination_absolute)` → `DirAccess.rename_absolute(...)` | 0.5d |
| 4.6 | 剧情队列会静默吞事件 | `main_stage2.gd:356-357` `pop_front()` 后调用返回值被丢弃；`360-362` `if story_overlay != null ...: return false`（不标记 seen） | 1h |
| 4.7 | 同一 speaker 多句只播第一句 | `story_db.gd:106-113` `_append_speaker_line()` 命中第一条即 `return`；`partner` 段多句时只出 1 页 | 1h |
| 4.8 | 25 个 staging 段中 5 个被丢弃 | `story_db.gd:58-62` 仅 `type=="reality"` 渲染；实测 `game/data/story.json` 25 个事件含 staging，仅 20 个是 reality；被丢：`global.prologue`(标题画面)、`ch2.student.ending.eligible/not_eligible`、`ch2.employee.ending.eligible/not_eligible` | 0.5d |
| 4.9 | 遗留探针脚本进仓库 | `game/tests/tmp_lead_probe.gd`（15 行，不入门禁、命名不在 test_/capture_ 约定内） | 5min |
| 4.10 | 缩进不一致 | `_build/run_stage2_tests.ps1:79-81,91` 用 tab，其余 4 空格 | 2min |

补充说明 4.8 的影响：标题画面与四个结局的演出指导文字在运行时**完全不可见**（数据在、页面不生成），而方案 C 恰要基于 staging 文本拆 beat —— 这 5 条若不改渲染分支，剧场永远拿不到它们。

---

## 5 风险 Top5（按"会返工"排序）

**R1 演出层无自动化验收（最高）**
capture 脚本全不在门禁 + headless 无像素 + `test_story_flow` 只断言 overlay 存在与 event id（`game/tests/test_story_flow.gd` 断言 `story_event_id=="global.prologue"` 等）。
→ P0 上线后"皮肤/剧场/打字机"只能人工看图回归；每轮改动都要人眼，无法在 CI 里挡住退化。
缓解（约 1 天）：把 `capture_story_overlay` 等纳入门禁并做像素采样/关键区域 hash；同时给 `compose_event` 输出加 pages 快照断言（speaker/tone/顺序），至少把"数据→页面"这半段自动化。

**R2 2512 行单脚本 + 三种屏幕重建模式**
剧场/皮肤/气泡/转场全部要挤进 `main_stage2.gd`；且 `_new_screen()` 的 `_reset_story_overlay_state()` 会清演出态（2.5）。
缓解（2–3 天，方案已提方向正确）：先切出 `story_presenter`（分发 + 3 个 presenter），再加任何视觉。

**R3 立绘是"假拆层 + 整图缩放"**
四层不绘制（2.1）、无 region 裁切（2.2）、面板顶部只有 92px（2.3）。方案 B 直接照做会得到"变形立绘 + 放不下的站位区"。
缓解（1–1.5 天）：`draw_texture_rect_region`/AtlasTexture + overlay 纵向分区重排，先各做一个金标准截图再铺开。

**R4 演出数据不可结构化推导**
staging 只有 `kind: text|line`（实测 story.json 全事件 kind 只有 text/line），没有 beat 结构；方案 C 的 4–6 beat 只能**手写映射表**，20 个 reality 事件 × 双分支 = 内容工程量，不是代码工程量。另 5 条非 reality staging 被丢弃（4.8）。
缓解：先做 1 个事件（如 `ch1.report.student.success`）的 beat 金标准 + 截图，验证节奏后再铺；映射表加"覆盖所有 reality id"的门禁断言（方案 §5 已提，正确）。

**R5 存档写入密度 + 非原子 replace**
出牌即写盘（`main_stage2.gd:1789`）、`_replace_file` 有"删主档→崩"窗口（`save_manager.gd:245-255`）。
缓解（0.5 天，低风险高收益）：写盘时机收敛到 flow 切换/结算；replace 改两段 rename（或写 `.new` 后 rename 覆盖前先 rename 旧档为 `.old`）。

---

## 6 对设计方案（`docs/剧情演出方式设计方案.md` v0.1）承载力的判断

**总体**：代码侧的瓶颈不是"能不能画"，而是"画了没法验 + 单文件改不动"。方案 §5「不破坏现有链路、只改渲染层、`story_db.gd` 输出不变、presenter 按 tone 分发」**判断成立**：`tone` 已经产出（`story_db.gd:97,102,112,123`），只是渲染层从未消费（`main_stage2.gd:440-446`）。这是本方案最省力的一点，应当保留。

| 方案项 | 代码侧是否可承载 | 关键依据 | 修正后的成本 |
|---|---|---|---|
| A 分皮肤 + 打字机 | **可**，需改状态机 | 皮肤：StoryOverlay 是单点构造（`360-434`），加 `event.type→skin` 即可；打字机：`_render_story_page()` 是同步一次性赋值（`444`），要改为"赋值+补全"；与 `_advance_story_page()`(449-454) 单击翻页语义冲突，必须定"首点补全/再点翻页" | 1 天（含补测试断言） |
| B 立绘站位 | **不能照做** | 无 region 裁切（2.2）；顶部仅 92px（2.3）；master 是整图非拆层（2.1） | 1.5–2 天（先补裁切 + overlay 重排） |
| C 记忆剧场 | **渲染可行，数据是主成本** | 新建 Control/粒子/Line2D 不碰 rules；但 staging 无 beat 结构、5 条非 reality staging 被丢（4.8）；facts 授予时序要与 `_offer_result_story()`(`540-547`) 的 success/acceptFail 分流一致；验收无自动化（R1） | 3–4 天（方案估 2–3 天偏低 1 天） |
| D 材料悬浮窗 | **需先补数据** | 事件头有 `knowledge` 字段但多为 `none`，只有部分 check/accept 事件有具体 key | 1–1.5 天 |
| E 战斗气泡 | **可** | `_render_battle()`(1049) 每动作全量重建，气泡可挂在 `battle_hint_text`/`_show_battle_hint`(1460) 旁边；"不阻塞出牌"需补真实命中或 `_drop_drag_at` 断言 | 0.5–1 天 |
| F 公路转场 | **可** | `map_route_canvas.gd:37-83` 全 `_draw()`；在 `_show_map()`(711) 入口加 Tween 覆盖层即可 | 0.5 天 |
| BGM/SFX | **从零** | `game/` 内 Audio 相关 API **0 命中**；需新增 bus/Autoload/资源 | 1 天（与方案 §7.3 一致） |

**必须更正的方案事实**：
1. `docs/剧情演出方式设计方案.md:13`「三角色正式主立绘与八层拆层」→ 实际运行时只用单张 master（`layered_actor_layer.gd:76-77`），四层空转；写进方案的"可复用资产"应改为「单张 master + 程序绘制的 shadow/aura/effect」。
2. §2.4「无打字机/淡入等基础动效」成立（`create_tween` 0 次）。
3. §4C「先用手写映射表」判断正确且必要 —— 数据里没有 beats 字段（staging 仅 text/line）。

**方案漏掉的一条**：`global.prologue` 的 staging（"标题画面。终端车停在近景…"）现在被丢弃（4.8），而它恰好是方案 A/F 想要的第一个演出点；建议 P0 顺手把这 5 条 staging 的渲染分支补上（把 `type=="reality"` 放宽为「有 staging 且事件类型 ∈ 白名单」），成本约 0.5 天，收益是标题/结局的演出文本立刻可用。

---

## 7 未验证项（静态审查的边界，请 lead 决定是否补跑）

1. 未运行任何 Godot：`--headless` 下是否存在布局报错、`test_ui_clicks` 12 轮是否仍全绿、6 个 capture 脚本当前是否可跑，**均未验证**。
2. `FORMAL_MASTER_RECTS` 与贴图宽高比"巧合接近"已实测（PNG 头 1003×1568 / 1024×1536），但未在运行中确认立绘是否真的按预期尺寸落在角色槽位。
3. `story.json` 的 `supportedStoryStages` 与 6 个人生阶段的对应未逐条核对（`main_stage2.gd:334-336` 有兜底为空 → 剧情静默不播）。
4. 未检查 `_build/sync_game_data.ps1` 与 `validate_gameplay_v05.cjs` 的校验强度（本次范围是 `game/` 代码）。
