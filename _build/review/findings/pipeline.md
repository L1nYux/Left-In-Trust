# 数据管线审查报告：《剧情演出方式设计方案》的数据前提核验

- 审查对象：`docs/剧情演出方式设计方案.md`（v0.1 建议稿，2026-10-27）中「§5 数据与架构」「§4C 记忆剧场」「§4D 材料悬浮窗」的数据前提
- 审查链：`docs/Demo剧情脚本.md` → `_build/validate_story.cjs` → `_build/export_story_runtime.cjs` → `game/data/story.json` → `game/scripts/story_db.gd` → `game/scripts/main_stage2.gd`
- 形态：只读审查。未修改 `docs/`、`game/` 下任何文件；未运行 `_build/run_stage2_tests.ps1`。临时脚本与产物只落在 `_build/tmp_review/` 与 `_build/review/findings/`。
- 审查时间点：2026-10-27；当时 `node _build/validate_story.cjs` → 117 事件 / 错误 0 / 警告 0 / PASS；`node _build/export_story_runtime.cjs --check` → `Runtime story is current (117 events, 3fbe9d51b45a8114c66f2fa99d8dcea3e93714ff3f4f19c6d2bfc95a986acbf5)`，退出码 0。即 `story.json` 与 Markdown 源同步。

---

## 1 事件总量与分布（实测）

命令：`node _build/validate_story.cjs`（统计块）与 `node _build/tmp_review/analyze_story.cjs`（产物 `_build/tmp_review/analyze_out.json`）。

| type | 事件数 |
| --- | --- |
| reality | 20 |
| recap | 20 |
| battle | 16 |
| story | 15 |
| accept | 8 |
| brief | 8 |
| check | 8 |
| appendix | 6 |
| ending | 4 |
| event | 4 |
| rest | 4 |
| shop | 4 |
| **合计** | **117** |

| node | 事件数 |
| --- | --- |
| prologue | 1 |
| open | 8 |
| N1 | 8 |
| N2 | 8 |
| N3 | 8 |
| B1 | 4 |
| B2 | 4 |
| boss | 4 |
| stageBoss | 2 |
| hidden | 2 |
| success | 8 |
| prepFail | 4 |
| acceptFail | 8 |
| close | 4 |
| rest | 4 |
| shop | 4 |
| event | 4 |
| recruit | 2 |
| ending | 4 |
| appendix | 6 |
| recap | 20 |

- stage 分布：student 51、employee 49、none 17。
- `story.json` 顶层：`version 1.0`、`events 117`、`chatPools 39`，事件字段集合为 `id, chapter, task, stage, node, type, facts, knowledge, focus, boss, see, title, sectionOrder, sections`（117 个事件全覆盖）。
- **全库 0 个事件带 `presentation` / `beats` 字段**（`hasPresentation = 0`）：设计稿 §5「后续只加可选 `presentation:` 键」目前连一个样例都还不存在，参见 §6。

---

## 2 reality 事件逐条清单（实测，含 ending 对照）

### 2.1 数量结构

- **reality 事件共 20 个，不是 12 个**；按 stage 分：student 10、employee 10（每版 10 个：success 4 + acceptFail 4 + prepFail 2）。
- node × stage 交叉：`success/student 4`、`acceptFail/student 4`、`prepFail/student 2`、`success/employee 4`、`acceptFail/employee 4`、`prepFail/employee 2`。
- 另有 **4 个 ending 事件也带 staging 段**（`ch2.{student,employee}.ending.{eligible,not_eligible}`），而设计稿 §3 表（`docs/剧情演出方式设计方案.md:28`）把 ending 划进「暗线·现实片段」剧场。**若剧场按设计覆盖暗线全部事件，映射表要覆盖的是 20 + 4 = 24 个事件**，不是 12 个 × 2。
- `branch`（分支）段出现在 8 个 reality 事件（全部 acceptFail）中，另有 story 2、ending 2、battle 2，共 14 个事件。所以设计稿 `:61`「约 12 个 × 2 分支」的「×2」若指 student/employee 两版，实际是 10 × 2 = 20；若指 branch 段，reality 里只有 8 个带 branch，也对不上 12。

### 2.2 逐条明细（reality 20 个，按源文件顺序）

「staging 句数」按 `。！？!?` 计数；「closing 字数」为三条收束句各自的字数（`+` 连接）；`s>n>c` 表 `staging > narration > closing`。

| # | id | node | stage | staging 条数 | staging 字数 | staging 句数 | narration 条数 | narration 字数 | closing line 数 | closing 字数 | sectionOrder |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ch1.report.student.success | success | student | 1 | 108 | 6 | 1 | 12 | 3 | 25+25+18 | s>n>c |
| 2 | ch1.student.prepFail | prepFail | student | 1 | 83 | 4 | 1 | 12 | 3 | 19+18+16 | s>n>c |
| 3 | ch1.report.student.acceptFail | acceptFail | student | 1 | 88 | 4 | 1 | 12 | 3 | 22+23+22 | s>n>c>branch |
| 4 | ch1.slides.student.success | success | student | 1 | 91 | 5 | 1 | 12 | 3 | 24+24+23 | s>n>c |
| 5 | ch1.slides.student.acceptFail | acceptFail | student | 1 | 86 | 3 | 1 | 12 | 3 | 24+24+23 | s>n>c>branch |
| 6 | ch1.report.employee.success | success | employee | 1 | 127 | 5 | 1 | 12 | 3 | 28+24+22 | s>n>c |
| 7 | ch1.employee.prepFail | prepFail | employee | 1 | 83 | 3 | 1 | 11 | 3 | 24+24+21 | s>n>c |
| 8 | ch1.report.employee.acceptFail | acceptFail | employee | 1 | 95 | 4 | 1 | 12 | 3 | 24+22+22 | s>n>c>branch |
| 9 | ch1.slides.employee.success | success | employee | 1 | 106 | 5 | 1 | 12 | 3 | 22+22+21 | s>n>c |
| 10 | ch1.slides.employee.acceptFail | acceptFail | employee | 1 | 87 | 4 | 1 | 11 | 3 | 24+24+21 | s>n>c>branch |
| 11 | ch2.invite.student.success | success | student | 1 | 115 | 5 | 1 | 14 | 3 | 19+22+23 | s>n>c |
| 12 | ch2.invite.student.acceptFail | acceptFail | student | 1 | 81 | 4 | 1 | 12 | 3 | 26+19+25 | s>n>branch>c |
| 13 | ch2.photos.student.success | success | student | 1 | 111 | 4 | 1 | 12 | 3 | 22+25+25 | s>n>c |
| 14 | ch2.photos.student.acceptFail | acceptFail | student | 1 | 95 | 5 | 1 | 12 | 3 | 22+22+23 | s>n>branch>c |
| 15 | ch2.student.prepFail | prepFail | student | 1 | 73 | 3 | 1 | 12 | 3 | 24+21+22 | s>n>c |
| 16 | ch2.invite.employee.success | success | employee | 1 | 110 | 5 | 1 | 13 | 3 | 25+25+27 | s>n>c |
| 17 | ch2.invite.employee.acceptFail | acceptFail | employee | 1 | 82 | 4 | 1 | 12 | 3 | 29+23+23 | s>n>branch>c |
| 18 | ch2.photos.employee.success | success | employee | 1 | 104 | 4 | 1 | 12 | 3 | 28+25+24 | s>n>c |
| 19 | ch2.photos.employee.acceptFail | acceptFail | employee | 1 | 89 | 4 | 1 | 12 | 3 | 26+24+19 | s>n>branch>c |
| 20 | ch2.employee.prepFail | prepFail | employee | 1 | 64 | 3 | 1 | 12 | 3 | 23+20+23 | s>n>c |

- staging 字数：min 64 / max 127 / 合计 1878 / 均值 93.9；**20 段 staging 文本两两互不相同**（set size 20）。
- staging 句数分布：3 句 4 个、4 句 9 个、5 句 6 个、6 句 1 个（合计 84 句）。→ 设计稿 `:58`「每个 reality 事件按 staging 文本拆 4–6 个 beat」若按标点句号 1:1 切分，**只有 7/20 个事件天然落在 4–6 句区间**；3 句的 4 个事件、4 句的 9 个事件（共 13/20）必须在句内再切（逗号级）或由映射表自定义 beat 边界。
- narration：20 个 reality 事件全部恰好 1 条、均为 `kind: text`（不是 `kind: line`），字数 11–14，按句末标点最多 2 句。→ 「旁白 ≤2 句、每句 ≤14 字」在**当前数据**上成立（20/20）。
- closing：20 个 reality 事件全部恰好 3 条 `kind: line`（GPT/Claude/DeepSeek 各一），单句 16–29 字，三句合计 53–77 字。
- 每个 reality 事件的 sectionOrder 均为 `staging > narration > closing`（12 个），或带 branch：branch 在 closing 之后 4 个、在 closing 之前 4 个。

### 2.3 ending 4 个（对照：设计稿把 ending 也划进剧场）

| id | stage | staging 字数 | staging 句数 | narration 条数 | narration 字数 | closing line 数 | sectionOrder |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ch2.student.ending.eligible | student | 71 | 4 | 1 | **18** | 3 | scene>main>partner>fixed>branch>staging>narration>closing |
| ch2.student.ending.not_eligible | student | 42 | 2 | 0 | — | 3 | scene>main>partner>fixed>staging>closing |
| ch2.employee.ending.eligible | employee | 74 | 4 | 1 | **18** | 3 | 同 eligible |
| ch2.employee.ending.not_eligible | employee | 49 | 2 | 0 | — | 3 | 同 not_eligible |

- ending 的 staging 只有 42–74 字（比 reality 的 64–127 更短），且 staging 在 sectionOrder 中排在 fixed 之后。
- **2 个 ending 的旁白是 18 字，超过「每句 ≤14 字」**（`ch2.student.ending.eligible`、`ch2.employee.ending.eligible`）；校验器不检查（见 §6 第 6 条）。
- 既有代码事实：`story_db.gd:58-62` 只在 `type == "reality"` 时输出 staging，因此 ending 的 staging 目前**根本不会到达渲染层**（设计稿 `:11` 自己也写了这一点，但 `:28`/`:84-85` 没有据此修正方案）。

---

## 3 staging 文本是否进入 story.json（问题 b）

**是，进入。** 实测（`_build/tmp_review/analyze_story.cjs`）：

- 带 `staging` 段的事件共 **25 个**：reality 20 + ending 4 + story 1（`global.prologue`）。
- 每事件恰好 1 条 staging，全部 `kind: text`，正文为整段散文（不含换行/编号/分号）。
- 段落键出现次数：`staging 25`、`scene 97`、`fixed 23`、`main 71`、`repeat 25`、`partner 66`、`narration 22`、`closing 24`、`branch 14`。
- 导出链路证据：`_build/export_story_runtime.cjs:20-32`（`演出` → `staging` 的段名映射）、`:68-94`（段内文本进入 `sections[key]`）、`:112-122`（写入 `runtime.events`）。

但「进入 story.json」≠「进入渲染层」：`story_db.gd:58-62` 只有 reality 会输出 staging 页（speaker `画面`、tone `stage`），ending 4 个与 story 1 个的 staging 被静默丢弃。

---

## 4 §5「管线全部不动」是否成立（问题 c）

设计稿原文（`docs/剧情演出方式设计方案.md:84-85`）：

> 「…全部不动；本方案只改渲染层（`main_stage2.gd` 拆出 presenter 分发）。」
> 「…`story_db.gd` 的 pages 输出保持不变，presenter 按 `tone` 决定呈现。」

### 4.1 成立的部分：四环数据链路确实可不动

- `docs/Demo剧情脚本.md` 源文件：C 需要的 staging（20 reality + 4 ending）、narration、closing 三条收束句**全部已经写在源文件里**，无需新增字段。样板见 `docs/Demo剧情脚本.md:429-448`（事件头 `430-442`、`**演出**` 段 `443`、`**旁白**` 段 `444`、`**收束**` 段 `445-448`）。
- `_build/validate_story.cjs`：当前 117 事件 0 错 0 警 PASS，无需改（但见 §6 的缺口）。
- `_build/export_story_runtime.cjs`：`--check` 通过；导出物已含 C/D 所需全部原始字段。
- `game/data/story.json`：`staging`/`narration`/`closing`/`knowledge`/`type` 都在（字段集合见 §1）。
- D 所需 `knowledge`：38 个事件的 `knowledge` 非 `none`，共 13 个 key，事件计数为 `missing_attachment 6、mismatch 2、example_row 4、example_footer 2、duplicate_entries 2、sample_size 4、slide_duration 4、source_missing 2、date_conflict 8、recipient_note 10、seat_saved 2、photo_same_name 6、blank_note 8`。设计稿 `:67` 点名的 `mismatch` / `photo_same_name` / `date_conflict` 都存在。

### 4.2 不成立的部分：`pages` 契约不足以支撑 C/D，必须动 `story_db.gd` 或改取数方式

实测 `story_db.compose_event` 的输出契约（`game/scripts/story_db.gd:33-72`）：

1. **收束 3 句只剩 1 句**。`:50-51` 对 `closing` 调用 `_append_speaker_line`，`:106-113` 只取「当前 `main_speaker`」的那一条 line 就 `return`。实测 20 个 reality 事件每个都有 3 条收束句，但 pages 里只有 1 条。设计稿 `:59` 要求「收束句…按在队角色一句」逐句显示——从 pages 拿不到。
2. **ending 的 staging 被丢弃**。`:58-62` 的 `if type == "reality"` 白名单导致 4 个 ending 事件剧场无词可演；设计稿 `:28` 又把 ending 划进了暗线剧场，自相矛盾。
3. **`type`/`knowledge` 不在返回字典里**。`:65-72` 只返回 `id, title, pages, see, node, facts`。按 `event.type` 分发（`:85`）和材料窗读 `knowledge`（`:67-68`）都拿不到字段；虽然 D 有手写映射表可绕开 knowledge，C 的 ending 分发绕不开。
4. **staging 到 pages 时是一整页**。实测 reality 事件的 pages 数为 3（12 个）、4（4 个）、5（2 个）、6（2 个）；其中 staging 永远只占 1 页（一整段 64–127 字散文），"4–6 个 beat"必须由 presenter 或映射表把这一页再切。
5. **`main_stage2.gd` 当前只保存 pages**：`:363-374` 调 `compose_event` 后只把 `presentation["pages"]` 存进 `story_pages`，overlay 内不保留事件原始字典。不过 `:96` 已声明 `var story_data: Dictionary`、`:155` 已 `story_data = StoryDBScript.load_story()`，presenter 若改为直读 `story_data["eventsById"][event_id]` 是可行的。

### 4.3 判定

- 「`docs/` → `validate_story.cjs` → `export_story_runtime.cjs` → `story.json` 四环不动」——**成立**（实测 PASS + `--check` current，所需文本与字段齐备）。
- 「只改渲染层 `main_stage2.gd`」——**不成立**。有两条路：
  - 路 A（保持 `pages` 契约）：必须改 `game/scripts/story_db.gd` —— `closing` 输出三条（`:50-51`）、staging 白名单加上 `ending`（`:58-62`）、返回字段补 `type`/`knowledge`（`:65-72`）。`story_db.gd` 不在「只改 `main_stage2.gd`」字面范围内。
  - 路 B（presenter 直读原始事件）：`story_db.gd` 不动，但设计稿 `:85`「pages 输出保持不变，presenter 按 `tone` 决定呈现」这句要作废——presenter 必须绕开 `pages`，用 `main_stage2.gd:96/155` 已有的 `story_data` 读 `sections`、`type`、`knowledge`。
- 另外，`:85` 的三分发（`reality_presenter` 按 `event.type`）漏了 ending：ending 的 `type` 是 `ending` 不是 `reality`，需要按 `node` 或 `type ∈ {reality, ending}` 分发，否则 4 个结局事件进不了剧场。

---

## 5 数据质量实测：导出层的 markdown 标题泄漏（127 条，其中 52 条会被当成台词显示）

这是审查中实测到的既有缺陷，直接影响「presenter 直读 `sections`」的方案（必须先过滤）。

- 机制：`_build/export_story_runtime.cjs:59-61` 把「下一个 `<!-- event`」之前的全部内容算作上一事件正文，`:94` 把任何非段头、非 bullet 的非空行当 `{kind:"text"}` 压进当前段。事件之间的 Markdown 标题（如 `### 准备失败 · 材料没排完`）因此被写进**上一个事件**的最后一个段。
- 实测规模：`sections` 中形状为正则 `^\s*#{1,6}\s` 的 text 条目共 **127 条**（`_build/tmp_review/analyze3_out.json` 的 `artifactEntries`）。
- 落点分布：`fixed 15`、`scene 28`、`branch 9`、`closing 21`、`repeat 28`、`partner 26`（合计 127）。
- 会显示给玩家的部分：`story_db.gd:116-123` 的 `_append_all` 会把 `fixed`/`scene`/`branch` 段里的 text 条目原样成页，模拟 `compose_event` 后共 **52 条泄漏页**（`fixed 15 + scene 28 + branch 9`），speaker 为 `旁白` 或 `分支`。
- 证据位置：
  - 源头 `docs/Demo剧情脚本.md:450` 的 `### 准备失败 · 材料没排完` → `game/data/story.json:698-699`（落在 `ch1.report.student.success` 的 `closing` 段）。
  - `docs/Demo剧情脚本.md:322` 的 `### N2 核对 · 42 与 47` → `game/data/story.json:331-332`（落在 `ch1.student.B1` 的 `fixed` 段，会被 `_append_all` 当旁白页显示）。
  - 类似 `game/data/story.json:3367`、`:3746` 的 `### 验收失败 · 学生版`。
- `closing` 的 21 条泄漏因为 `_append_speaker_line` 只认 `kind:line` 而未显示；`partner` 的 26 条同理；`repeat` 的 28 条只在 `compose_repeat` 的 fallback 分支（`story_db.gd:98-103`）才可能显示。
- 校验器对此 **0 错误 0 警告**（`validate_story.cjs:291-298` 只遍历 `lines()`，标题 text 完全在检查范围外）。
- 对方案的含义：剧场/材料窗若「按事件 id 读 `sections`」，必须过滤 `kind === "text"` 且以 `#` 开头的条目，否则会把排版标题演进演出文本里。数据层并非「干净可用」，但也不需要改管线——过滤属于 presenter 职责。

---

## 6 校验器缺口清单（问题 d）

以下每条均有实测探针（探针文件 `_build/tmp_review/probe_*.md`，生成脚本 `make_probes.cjs`/`make_probes2.cjs`/`make_probes3.cjs`，均以 `docs/Demo剧情脚本.md` 为基线只替换一处，不触碰原件）。

| # | 缺口 | 代码位置 | 实测证据 |
| --- | --- | --- | --- |
| 1 | **「旁白 ≤2 句」与「每句 ≤14 字」两条断言对现有写法是死代码**。源文件写 `**旁白**：文本`，解析为 `kind: text`；校验器却用 `lines(ev,'narration')`（只认 bullet `- 旁白：`） | `_build/validate_story.cjs:140-142`（`lines()` 只留 line）、`:280-283`；解析同构 `:95-130`；导出侧 `_build/export_story_runtime.cjs:68-78` | `probe_01b_narration16_text`：旁白 16 字 → 错误 0 警告 0 PASS；`probe_04b_narration_3_lines_text`：3 条 `**旁白**：` → PASS。即当前 20 个 reality 事件的两条断言**恒不触发** |
| 2 | 只有 bullet 写法才进入检查，且「超长」只是 warning，不阻断 | `_build/validate_story.cjs:281-283` | `probe_11_narration_bullet16`：`**旁白**` 段头 + 1 条 bullet 15 字 → `! 旁白过长（15 字）`，错误 0 警告 1，PASS（exit 0）；`probe_12_narration_bullet3`：3 条 bullet → `✗ 旁白最多两句，当前 3 条`，FAIL（exit 1） |
| 3 | `staging`（演出段）除「存在」外零断言：无字数上限、无句数/beat 数、无格式（编号/分号/换行）检查 | `_build/validate_story.cjs:247-249`、`:274-276` | `probe_09b_staging_beat_markup`（加 `1、2、3、`+分号）→ PASS；`probe_10b_staging_huge`（402 字）→ PASS |
| 4 | 事件头未知字段静默透传：无字段白名单、无「未知字段」警告 | `_build/validate_story.cjs:164-167`（只查必填）；`_build/export_story_runtime.cjs:34-41`（`parseHeader` 全收） | `probe_05_unknown_header_field`（加 `presentation: theater`）→ 错误 0 警告 0 PASS。设计稿 `:87`「只加可选 `presentation:` 键，校验器向后兼容」的真实含义是「校验器完全不校验它」 |
| 5 | `sections` 形状无断言：markdown 标题泄漏（§5）不被检测；无「closing 恰好 3 条 line 且无多余 text」断言 | `_build/validate_story.cjs:291-298`（只走 `lines()`） | 目前 127 条泄漏、52 条会显示，校验器 0/0 PASS |
| 6 | ending 的旁白不适用「≤2 句 / 每句 ≤14 字」：`validate_story.cjs:274` 只判 `type === "reality"` | `_build/validate_story.cjs:274-284` | 实测 `ch2.student.ending.eligible`、`ch2.employee.ending.eligible` 各有 1 条 18 字旁白，validate 仍 0 警告。若设计把 ending 划进剧场（`:28`），该约束在数据层已被违反且无校验 |
| 7 | 无 `presentation`/`beats` 与 staging 的一致性断言（未被定义、不被检查） | 全文件无 `presentation`/`beats` 关键字 | 设计稿 `:86` 要求 `test_story_flow.gd` 断言映射覆盖全部 reality id，但当前测试没有这层断言，也没有从 `story.json` 生成 reality id 清单的机制 |
| 8 | 测试层 speaker 白名单与 `story_db` 实际输出不一致：`test_story_flow.gd:17/21` 白名单含 `演出`（`story_db` 从不输出），不含 `画面`（`story_db.gd:62` 实际输出） | `game/tests/test_story_flow.gd:17`、`:21`、`:89-91` | 实测 `compose_event` 全库 speaker 计数：`旁白 238、GPT 161、画面 20、分支 27`。现有断言只测 `open` 事件（无 staging），所以没暴露；剧场/材料窗若沿用 pages + 该断言会误判 |
| 9 | 收束「在队角色各一句」无法从 pages 获得（见 §4.2 第 1 条），属渲染契约缺口而非校验器缺口，但同样会卡住 C 的验收 | `game/scripts/story_db.gd:50-51`、`:106-113` | 20/20 reality 事件有 3 条收束 line，pages 只输出 1 条 |

校验器当前**有效**的部分（供对照，非缺口）：117 事件硬编码计数（`export:124-127`）、必填字段与 `type`/`node` 白名单及 `NODE_TYPE` 一致性（`validate:164-177`）、`facts` 规则（`:188-205`）、发言人合法性（`:228-242`）、`场景`/`演出` 存在性（`:247-249`）、reality 的 staging + 收束三角色（`:274-279`）、ending 固定台词（`:286-288`）、覆盖集合与 recap 配对（`:312-373`）。探针 `probe_06_bad_type`（type: theater → 2 错 FAIL）、`probe_07_ending_type_to_reality`（4 错 FAIL）、`probe_08_reality_no_staging`（2 错 FAIL）证明这些断言是活的。

---

## 7 设计稿数字 vs 实测（差异汇总）

| 设计稿位置 | 设计稿说法 | 实测 | 判定 |
| --- | --- | --- | --- |
| `docs/剧情演出方式设计方案.md:61` | 「demo 全部 reality 事件约 12 个 × 2 分支」 | reality **20** 个（student 10 + employee 10，即 10×2）；带 branch 段的 reality 8 个；若含 ending 共 24 个 | 数字不符，映射表规模要按 20 或 24 写 |
| `:58` | 「每个 reality 事件按 staging 文本拆 4–6 个 beat」 | staging 句数 3/4/5/6 分别 4/9/6/1 个事件；按句 1:1 只有 7/20 落进 4–6 | 「按句拆」不可直接成立，需句内切分或映射表定义 |
| `:58` | 「（≤14 字/句的校验已在写稿层保证）」 | 20/20 现状合规（11–14 字），但校验器两条断言对现有写法恒不触发（§6 #1）；ending 已有 2 条 18 字 | 「已保证」没有校验支撑，只是当前写稿结果 |
| `:59` | 收束句「按在队角色一句」逐句显示 | 源数据 3 条齐备；`story_db` pages 只输出 1 条 | 数据够，pages 契约不够 |
| `:28` + `:84-85` | ending 进暗线剧场；只改 `main_stage2.gd`、pages 不变 | ending 的 staging 被 `story_db.gd:61` 丢弃 | 自相矛盾，需修正方案文字或 `story_db.gd` |
| `:67` | 材料窗内容与 `knowledge` key 对应（mismatch/photo_same_name/date_conflict 等） | 13 个 key、38 个事件非 none，点名的三个都存在且分别覆盖 2/6/8 个事件 | 数据前提成立 |
| `:85` | 按 `event.type` 分发到三个 presenter | type 有 12 种（reality/recap/battle/story/accept/brief/check/appendix/ending/event/rest/shop）；ending 的 staging 需剧场但 type 不是 reality | 分发键需按 node 或 {reality, ending} 组合 |
| `:87` | 后续加可选 `presentation:` 键，校验器向后兼容 | 导出会静默透传任意事件头字段，校验器不检查；当前 0 个事件有该键 | 「兼容」成立但「校验」不存在（§6 #4） |

---

## 8 结论与最小改动建议

1. **reality 数量**：20 个（每 stage 10 个），不是 12 个；剧场若含 ending 则是 24 个。映射表与验收断言都应按 24 个事件 id 生成。
2. **staging 入 runtime**：已在 `story.json`（25 个事件，每事件 1 段整文），但只有 reality 的 20 段会到渲染层；ending 4 段被 `story_db.gd:58-62` 丢掉。
3. **§5 判定**：数据管线四环（md/validate/export/story.json）确实可以不动；但「只改 `main_stage2.gd`」不成立。二选一：
   - 路 A：改 `game/scripts/story_db.gd`（收束三条、ending staging、返回 `type`/`knowledge`）；
   - 路 B：presenter 直读 `main_stage2.gd:96/155` 的 `story_data`（`eventsById`），并在报告中改掉「pages 保持不变、按 tone 分发」这句。
4. **校验器必须补的断言**（优先级序）：① 把旁白检查改为对 `texts(ev,'narration') ∪ lines(...)` 生效，并把 >14 字升级为 error；② 给 staging 加字数上限/句数区间；③ 加事件头字段白名单（或至少对未知字段 warn）；④ 加「section 里的 text 不得以 `#` 开头」断言（顺手消灭 127 条泄漏）；⑤ 若 ending 进剧场，把旁白约束扩展到 ending。
5. **实测陷阱提醒**：`test_story_flow.gd` 的 speaker 白名单缺 `画面`、多 `演出`；presenter 若复用 pages 会踩到（§6 #8）。

---

## 9 复现命令

```powershell
node _build/validate_story.cjs                       # 117 事件 / 0 错 0 警 / PASS
node _build/export_story_runtime.cjs --check         # current (117, 3fbe9d51…)
node _build/tmp_review/analyze_story.cjs             # 分布、reality 清单 → analyze_out.json
node _build/tmp_review/analyze3.cjs                  # sections kind / 标题泄漏 / 模拟 pages → analyze3_out.json
node _build/tmp_review/analyze4.cjs                  # reality+ending 明细表 → table_reality.md / stats_reality.json
node _build/tmp_review/make_probes2.cjs; node _build/tmp_review/make_probes3.cjs
node _build/validate_story.cjs --file _build/tmp_review/probe_01b_narration16_text.md --draft
```

临时产物：`_build/tmp_review/analyze_out.json`、`analyze2_out.json`、`analyze3_out.json`、`stats_reality.json`、`table_reality.md`、`probe_*.md`、`make_probes*.cjs`；本报告 `_build/review/findings/pipeline.md`。

> 说明：本文所有数字均来自上述命令输出或 `文件:行号`，没有估计值；凡未实测的（如「剧场 8–18 秒」这类时间预算）本报告不作判定。
