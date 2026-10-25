# 《未尽之托》Demo 剧情脚本 v1.0

- 版本：v1.0（2026-10-25）
- 上一版：[Demo 剧情脚本 v0.5](历史/旧版本/Demo剧情脚本_v0_5.md)（已归档，仅作节点事实溯源）
- 上游依据：[剧情大纲](../剧情大纲.md)（根目录）、[创作基准](剧情/00_创作基准.md)、[Demo 范围](Demo范围.md)、[首批内容数据](首批内容.json)
- 本版范围：Demo 两章四任务（report / slides / invite / photos）× 大学生 / 公司员工，117 个事件块；单/双人变体按在场成员抽取。
- 机器可读：事件头由 `_build/validate_story.cjs` 校验，校验记录见文末。
- 本版不包含：真实模型 API、配音、美术替换、游戏内接入代码；文本尚未接入 `game/`。

---

## 怎么读这份脚本

1. 每个事件块先看 `<!-- event ... -->` 头：`id` 决定它属于哪章、哪任务、哪阶段、哪节点；`facts` 决定它是否给语境事实；`focus` 是本节点的关键发现者。
2. 正文中「主句」按在场角色抽取一句；「搭档回应」是接话，只取主句角色之外的在队者一句；单人局没有搭档回应。
3. 「固定台词」「演出」「旁白」「收束」不参与随机抽取，按类型整段播放。
4. 现实片段只属于对应人生阶段，不与其他任务的对白混拼。
5. 写作与数据契约详见 `docs/剧情/00_创作基准.md`；本导言是它的压缩版。

---

## 《未尽之托》Demo 剧情脚本 v1.0 · 导言

> 本文件是 `docs/Demo剧情脚本.md` v1.0 的前置说明，正式脚本由此文件与三份章节草稿按「序章 → 第一章（含章间）→ 第二章（含章间）→ 结局 → 收藏回顾 → 长期附录」拼装。单独存在时用于核对事件树、数据契约与写作口径。
>
> 上一版为 `docs/历史/旧版本/Demo剧情脚本_v0_5.md`（v0.5 骨架，2026-10-25 归档）。v1.0 保留 v0.5 的全部节点事实，不改变规则、数值、任务目标与验收条件，只补全可演出文本、变体与数据头。

### 0. 这一版是什么

- **定位**：Demo 两章四任务（`report` / `slides` / `invite` / `photos`）× 两种人生阶段（大学生 / 公司员工）的完整可拆文本事件集，可直接被后续游戏读取。
- **规模**：117 个事件块；每个事件块带机器可读头，正文仅供演出与校对。
- **明线**：AI 小队接委托、交付、验收。**暗线**：「我」的人生片段（学生版=大三的社团旧友与没回的消息；员工版=工作第三年的老友与一直没发的确认）。暗线只通过现实片段与结局回看露出，三名 AI 不预知、不点评私人生活。
- **不包含**：真实模型 API、真人配音、美术资产替换、游戏内接入代码。文本未接入 `game/`，接入方式见 §10。

### 1. 事件块格式

每个事件块为一个 Markdown 小节：

```markdown
#### 1.1 接单 · 学生版
<!-- event（示例，不参与校验）
id: ch1.report.student.open
chapter: 1
task: report
stage: student
node: open
type: story
facts: none
knowledge: shortage
focus: none
boss: none
see: ch1.report.student.open
-->
**场景**：任务单刚打印出来，纸边还是热的。
**主句（在场角色取一句）**
- GPT：先拆步骤。缺的材料现在圈出来。
- Claude：我确认一下，这次是缺附件，不是缺页数。
- DeepSeek：这步能省。缺的那份，不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：缺的这份我兜住。
- Claude：那就先标阻塞项。
- DeepSeek：嗯，先开饭……先开工。
**重复局**：还是那三份材料，缺的那份已经圈过。
```

#### 1.1 头字段

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 稳定事件 id，格式见 §2；全文件唯一 |
| `chapter` | 是 | `0` 全局 / `1` 第一章 / `2` 第二章 |
| `task` | 是 | `report` / `slides` / `invite` / `photos` / `none` |
| `stage` | 是 | `student` / `employee` / `none` |
| `node` | 是 | 节点类型，见 §3 |
| `type` | 是 | 事件类型，见 §3；由 `node` 唯一决定 |
| `facts` | 是 | 本事件授予的语境事实：`none` / `work_value` / `someone_waiting`；规则见 §4 |
| `knowledge` | 视情况 | 本事件向任务单/小队释放的关键情报标签，逗号分隔；无则 `none` |
| `focus` | 视情况 | 本节点「关键发现者」角色，`GPT` / `Claude` / `DeepSeek` / `none`；每任务轮换见基准 §5 |
| `boss` | 视情况 | 仅 `boss` / `stageBoss` / `hidden` 三类必填，其余填 `none`；取值 `submit` / `recipient` / `stage_student` / `stage_employee` / `hidden` |
| `see` | 是 | 回看索引键；默认与 `id` 相同，特例须在正文注明 |
| `branch` | 视情况 | 仅 `ending`：`eligible` / `not_eligible` |

#### 1.2 段落

| 段落 | 用于 | 约束 |
| --- | --- | --- |
| `**场景**` | 全部 | 一句话说清地点、任务单状态、可见材料；不写角色内心 |
| `**主句（在场角色取一句）**` | 剧情/接单/核对/验收/战斗/休整/商店/事件/结局 | 在场角色各一条，按 `GPT`、`Claude`、`DeepSeek` 顺序；每人只在本角色「有资格说」时写 |
| `**搭档回应（主句角色之外的在队者，最多一句）**` | 同上（序章、结局不强制） | 是「接话」，不是第二段独白；不得复述主句 |
| `**固定台词**` | 战斗/结局 | 敌人、终端、旁白或「我」的不可替换台词 |
| `**演出**` | 现实片段 | 画面/声音/时长提示，按总体视觉风格 §离散记忆剧场写 |
| `**旁白**` | 现实片段 | 最多两句，每句 ≤14 个汉字 |
| `**收束（按在队角色一句）**` | 现实片段 | 三角色各一条，必须由「本局真实在队者」抽取；内容只回应交付结果，不点评「我」的私事 |
| `**重复局**` | 小剧场节点 | 二周目起的简述，可省略未变化信息 |
| `**分支**` | 结局 | 说明成立条件与该分支差异 |

### 2. 事件 id 规则

- 任务节点：`ch{1|2}.{task}.{stage}.{node}`
  - 例：`ch1.report.student.N1`、`ch2.photos.employee.success`
- 章级节点：`ch{1|2}.{stage}.{node}`
  - 例：`ch1.student.B1`、`ch1.student.recruit`、`ch2.student.stageBoss`
- 全局节点：`global.{name}`
  - 例：`global.prologue`、`global.future.01`、`global.recap.ch1.report.student.success`
- 结局拆为两事件：`ch2.{stage}.ending.eligible` 与 `ch2.{stage}.ending.not_eligible`，各自带 `branch`。

### 3. 节点与类型

| node | type | 数量 | 说明 |
| --- | --- | --- | --- |
| `prologue` | story | 1 | 标题画面后、任务单前的框架戏：终端、人生阶段、AI 选择 |
| `open` | story | 8 | 每任务×阶段接单小剧场 |
| `N1` | brief | 8 | 第一次接触材料，暴露缺口/冲突 |
| `N2` | check | 8 | 核对阶段，每任务每阶段指定一名关键发现者 |
| `N3` | accept | 8 | 交付前验收小剧场（此处不判定胜负） |
| `B1` / `B2` | battle | 8 | 章内两场普通战（每章每阶段各一场；敌人见基准 §6） |
| `boss` | battle | 4 | 章末 Boss（第一章 `submit`，第二章 `recipient`） |
| `stageBoss` | battle | 2 | 阶段专属 Boss（`stage_student` / `stage_employee`），挑战开关打开时出现 |
| `hidden` | battle | 2 | 隐藏 Boss「我」，`D > T` 且常规通关后出现 |
| `rest` | rest | 4 | 章间休息三选一 |
| `shop` | shop | 4 | 章间商店 |
| `event` | event | 4 | 章间中立事件 |
| `close` | story | 4 | 章节收束 |
| `recruit` | story | 2 | 第一章末非终章 Boss 胜利后的招募 |
| `success` | reality | 8 | 完整交付后的现实片段（成功） |
| `prepFail` | reality | 4 | 准备阶段失败的现实片段（材料未整理完） |
| `acceptFail` | reality | 8 | 验收发现具体漏项的现实片段 |
| `ending` | ending | 4 | 「暂存明天」两分支 × 两阶段 |
| `recap` | recap | 20 | 局外收藏回看的一句话摘要，按片段 id 一条 |
| `appendix` | appendix | 6 | 长期六结局方向附录 |

合计：117 个事件块。

### 4. 事实与资格

- `work_value`：第一章成功/验收失败可授予，表示「我」第一次能说明自己做了什么。
- `someone_waiting`：第二章成功/验收失败可授予，表示屏幕外有人在等回音。
- 规则：`success` 必须且只能授予本章事实；`acceptFail` 可授予本章事实或 `none`；`prepFail`、章间、结局、收藏、附录不授予事实。
- 结局资格：同阶段同时持有 `work_value` 与 `someone_waiting`，且未放弃 →「暂存明天」`eligible` 分支；否则 `not_eligible` 短收束。
- 收藏键只使用 `stage` / `task` / `outcome` / `variant`，不含 `runId`；同一键重复只计首次。

### 5. 变体与在队判定

- 每节点先按「本局真实在队成员」筛选可发言者：主句只取在场者，搭档回应只取主句角色之外的在队者。
- 单人局不出现第二人台词；双人局才启用搭档回应；三人仅测试场。
- 战外正余额的替补可回应；`token` 为 0 的成员只能在局外收藏回看中出现，不参与对白。
- 未招募角色不插话；写手不得写「假设她已入队」的台词。第二人尚未招募时，第一章后半与第二章的搭档回应走单人 fallback 语义。
- 现实片段与对白不混拼：现实片段只属于 `stage`，不出现另一阶段的物件、人物或称呼。

### 6. 与规则/数据的映射

| 剧情节点 | 规则/数据 |
| --- | --- |
| 章内两场普通战 | 敌人 `missing_attachment`/`duplicate`（第一章）、`conflict`/`overflow`（第二章）；普通战胜利 +4 算力 |
| 章末 Boss | `submit`（30 血）/ `recipient`（42 血）；Boss 胜利 +8 算力，赋予该章任务完成 |
| 阶段专属 Boss | `stage_student` / `stage_employee`（42 血），挑战开关关闭时不出现 |
| 隐藏 Boss | `hidden`（56 血），常规通关且 `D > T`（Demo 阈值 T=1）后追加 |
| 休息节点 | 三选一：+6 算力 / 升级一张牌 / 删除一张牌 |
| 商店节点 | 花 6 算力回复 4 点 token；不卖牌 |
| 招募节点 | 非终章 Boss 胜利后一次招募；候选含未解锁角色，新成员 token 上限 12 入队；跳过则两张牌各折 4 算力升级 |
| 现实片段 | 成功后入库；早期失败、Boss 验收失败各有专属片段；放弃/退出/重载不生成失败片段 |
| 收藏 | `success` / `prepFail` / `acceptFail` 各生成一条收藏，重复键去重 |

### 7. 文本与演出口径

- 轻喜剧三要素：有起因、有人物解法、有结果。笑点来自习惯与误解，不来自角色犯蠢。
- 不写死「GPT 永远正确 / Claude 永远拒绝 / DeepSeek 永远发现错误」；关键发现者按 §3 的 `focus` 轮换，失误者与补救者同样轮换。
- 角色台词须可被替换检查：把名字换成别人仍成立，说明没写出角色性格，删掉重写。
- 现实片段默认无对白，最多两句旁白；单句 ≤14 汉字；一个片段只动一个主要动作；不哭、不跪、不砸桌。
- 「我」只出现在结局与隐藏 Boss 的固定台词中，不在小剧场中直接说话。
- 禁止：把老师/上级/朋友/「我」怪物化成敌人；用全屏蓝代码或霓虹城市表达 AI；把暗线写成纯粹的悲惨故事；角色的主题色整体覆盖场景。

### 8. 校验

- 脚本内事件头由 `_build/validate_story.cjs` 解析，命令：`node _build/validate_story.cjs`。
- 检查项：id 唯一与格式、枚举合法、`node→type` 映射、事实授予规则、boss 映射、发言人白名单、必需段落、台词长度、全量覆盖（8 个任务×阶段的 N1/N2/N3、成功/失败片段、章节节点、结局分支、收藏回顾）。
- 草稿阶段可用 `--file <draft> --draft` 只查格式与单文件。

### 9. 覆盖清单（拼装核对用）

| 区块 | 事件数 | 文件 |
| --- | --- | --- |
| 序章 | 1 | `_build/story_drafts/序章章间结局.md` |
| 第一章任务与战斗 | 34 | `_build/story_drafts/第一章.md`（另含 10 条第一章收藏回顾） |
| 第一章章间（休息/商店/事件/招募） | 8 | `_build/story_drafts/序章章间结局.md` |
| 第二章任务与战斗 | 38 | `_build/story_drafts/第二章.md`（另含 10 条第二章收藏回顾） |
| 第二章章间（休息/商店/事件） | 6 | `_build/story_drafts/序章章间结局.md` |
| 结局 | 4 | `_build/story_drafts/序章章间结局.md` |
| 收藏回顾 | 20 | 由各章节草稿生成，拼装时集中到文末「收藏回顾」 |
| 长期附录 | 6 | `_build/story_drafts/序章章间结局.md` |

合计 117 个事件块。

### 10. 接入游戏（后续阶段）

1. 用拼装脚本把事件块导出为 `game/data/story.json`（字段与头一致，正文按段落拆成 `scene` / `lines` / `staging`）。
2. 在 `game/scripts/content_db.gd` 增加文本事件读取，替换现有占位对白。
3. 节点进入时先算在场成员，再按 `speakerRequirements` 过滤；`knowledge` 写入任务单显示层；`facts` 写入收藏与结局资格。
4. 验收路径：单/双人各跑一遍四任务，确认无未招募角色发言、现实片段不混拼、失败片段与节点匹配。


# 序章


### 序章 · 打印到一半的任务单
<!-- event
id: global.prologue
chapter: 0
task: none
stage: none
node: prologue
type: story
facts: none
knowledge: none
focus: none
boss: none
see: global.prologue
-->
**演出**：标题画面。终端车停在近景，路只打印到车灯前，更远处是纸页、光点与云层。标题《未尽之托》像一张打印到一半的任务单，「未尽」留着一处可见的缺口，「托」字落在稳定的暖光里。
**场景**：车内三个座位空着。终端亮起两张人生卡：一张印着宿舍书桌、课表与社团活动室的窗边座位；另一张印着工位夜灯、周报与调走前的那张请柬。
**固定台词**
- 终端：任务已生成。选择人生阶段。
- 旁白：大学生：课表压着终期展示。社团有人毕业。
- 旁白：公司员工：周报压着提案。老友项目结束就走。
- 终端：已选。选择首位 AI。
**主句（在场角色取一句）**
- GPT：我是 GPT。先拆三步：接单、理材料、交付。
- Claude：我是 Claude。材料我先核对，再摊开清单。
- DeepSeek：我是 DeepSeek。话少，路短，饭我带着。
**固定台词**
- 终端：第一章任务单打印中。
- 终端：终章之后，另有一次额外验收。
- 终端：目标：把本周做成一页。
- 终端：已知材料：三件，缺一件。
- 终端：验收重点：三条。
**重复局**：重看开篇，标题的缺口先亮一下，再打印出三行。

# 第一章 · 纸页旷野

**本章：** 接「把本周做成一页」与「最后一页」两个委托；章末 Boss 为「本次提交版」。学生版与员工版是同一章的两套人生阶段文本，不可混拼。

**学生版**

## 第一章 · 任务「把本周做成一页」· 学生版

### 章首 · 一页
<!-- event
id: ch1.report.student.open
chapter: 1
task: report
stage: student
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.report.student.open
-->
**场景**：车沿打印到一半的路走。纸层铺成缓坡，远处立着一页厚的白色地标。课桌纹理压在纸面上，窗光斜进来，一张手写便签被风掀起又落下。终端吐出任务单，只有三行：把本周做成一页；材料三件；验收重点三条。
**主句（在场角色取一句）**
- GPT：先拆三步。看单子，数材料，排验收。
- Claude：我确认一下。单子写三份材料，打印口只吐了两次。
- DeepSeek：目标一页。别的能省，这一页不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结构先立起来，缺的那一格留着。
- Claude：我先记一遍，缺哪份等会儿对。
- DeepSeek：缺一格也能先排，车别停。
**重复局**：这段路昨天走过，任务单是新的。

### N1 接单 · 三份材料
<!-- event
id: ch1.report.student.N1
chapter: 1
task: report
stage: student
node: N1
type: brief
facts: none
knowledge: missing_attachment
focus: Claude
boss: none
see: ch1.report.student.N1
-->
**场景**：材料悬浮窗摊开三格：本周聊天记录、数据表 A 截图、数据表 B 导出。第三格空着，边框还在闪。打印口旁贴着一张手写便签，只有两个字：一页。
**主句（在场角色取一句）**
- GPT：三份摆成一个结构。数一数，只有两份文件。
- Claude：我确认一下。清单对上了，缺的那一份没对上。
- DeepSeek：邮件写「附件见附件」。那张截图也是一封邮件。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那这步先叫「找出第一份附件」。
- Claude：截图能证明发过，不能当附件用。
- DeepSeek：套娃不算三份。缺的先标上。

### B1 战斗 · 缺失附件
<!-- event
id: ch1.student.B1
chapter: 1
task: none
stage: student
node: B1
type: battle
facts: none
knowledge: missing_attachment
focus: none
boss: none
see: ch1.student.B1
-->
**场景**：纸页路在断桥前停下。桥面缺口是一个空的附件框，框边还挂着打印了一半的字。课桌纹理从路边压过来，手写便签贴在缺口两侧。敌人从空框里浮起，轮廓比框大一圈。
**主句（在场角色取一句）**
- GPT：缺口先标出来。绕过去，也别当路是通的。
- Claude：我标住位置。缺的那份，写进待补。
- DeepSeek：这段能短走。缺口不能当没看见。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：拆成两段，补一处是一处。
- Claude：我确认这一格是空的，不是漏看。
- DeepSeek：缺的那页留着，回来再填。
**固定台词**
- 敌人：这里少一页。补不齐，别想过去。
- 终端：材料：缺一份。

### N2 核对 · 42 与 47
<!-- event
id: ch1.report.student.N2
chapter: 1
task: report
stage: student
node: N2
type: check
facts: none
knowledge: mismatch, example_row, example_footer
focus: DeepSeek
boss: none
see: ch1.report.student.N2
-->
**场景**：两张数据表并排浮着。左边 42%，右边 47%，中间隔着 5 个百分点。B 表页脚有一行小字：「示例数据，勿引用」。打印口又吐出一张，正是那页示例。Claude 的清单上，「数字是否相等」这一格勾了一半。
**主句（在场角色取一句）**
- GPT：先圈差额。5% 从哪来，查不清就别交。
- Claude：我差点只核对两个数字相等。差额没解释，不算核完。
- DeepSeek：页脚写着「示例数据，勿引用」。来源那行不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把这行标出来，别并进结果。
- Claude：我把它挪进待补栏，仍是一页。
- DeepSeek：示例页单放，一页还装得下。
**重复局**：昨天核过的那版，直接看页脚。

### B2 战斗 · 重复条目
<!-- event
id: ch1.student.B2
chapter: 1
task: none
stage: student
node: B2
type: battle
facts: none
knowledge: duplicate_entries
focus: none
boss: none
see: ch1.student.B2
-->
**场景**：路绕成一个回环坡道，一圈圈往上。同一行手写数字在坡上出现三次，每次都落回同一格便签。风把便签吹起又按下去，像有人反复抄同一条。
**主句（在场角色取一句）**
- GPT：同一条出现三遍。先去重，再往前走。
- Claude：我确认一下，哪两行真的是同一件。
- DeepSeek：重复能删，删掉的要留出处。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按来源合并，别删多。
- Claude：我留一条原样，方便回头查。
- DeepSeek：去重完，一页还能更短。
**固定台词**
- 敌人：写过的，再写一遍也一样。
- 终端：重复条目：同一条目，出现两次以上。

### N3 验收 · 三条
<!-- event
id: ch1.report.student.N3
chapter: 1
task: report
stage: student
node: N3
type: accept
facts: none
knowledge: none
focus: GPT
boss: none
see: ch1.report.student.N3
-->
**场景**：一页纸浮在车灯前，边角被风压平。任务单翻到验收那面，三条并排：数字与来源一致、缺失项标注、只占一页。待补栏只剩一行：负责数据的组员那份贡献说明。
**主句（在场角色取一句）**
- GPT：三条对一遍：数字来源、缺失标注、一页。
- Claude：我确认一下，待补只剩贡献说明一项。
- DeepSeek：一页。连文件名也短一点。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：对完就交，不留第二版。
- Claude：这一项我标「待补」，不是藏。
- DeepSeek：页脚那行留着，占不了半行。

### Boss · 本次提交版
<!-- event
id: ch1.student.boss
chapter: 1
task: none
stage: student
node: boss
type: battle
facts: none
knowledge: none
focus: none
boss: submit
see: ch1.student.boss
-->
**场景**：纸页旷野尽头，一座只有一页厚的装置立起来。它不断对折、盖章、再展开，正面并排列着三条验收：数字与来源一致、缺失项标注、只占一页。课桌纹理和手写便签贴在装置底部，日光把纸边照得发白。
**主句（在场角色取一句）**
- GPT：先看三条验收。一条一条过，过完再交。
- Claude：我确认一下，待补那栏还留着一行。空着也要标。
- DeepSeek：省掉多余页，别省来源。只交一页。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按三条走，别抢最后一步。
- Claude：我先递附件，再递这一页。
- DeepSeek：一页递过去，来源跟着。
**固定台词**
- 敌人：第一页。两下，先把数字对齐。
- 敌人：一行一行来，对不上就重来。
- 敌人：四面收口。哪格空着，我盖哪格。
- 敌人：这轮不盖章。你先歇口气。
- 终端：本次提交版，可以入库。
- 终端：退回。示例数据混进结果，来源没标。

### 成功 · 一页
<!-- event
id: ch1.report.student.success
chapter: 1
task: report
stage: student
node: success
type: reality
facts: work_value
knowledge: none
focus: none
boss: none
see: ch1.report.student.success
-->
**演出**：黑底。光点先连成一张课桌，凉饭盒没开。手机在桌角亮起，阿澄的消息停在「这周六？」，输入框空着。光点想连成回复，只连到一半就散了。桌边压着那张一页纸，页脚标着「待补」。
**旁白**：屏幕亮了一下，又暗下去。
**收束（按在队角色一句）**
- GPT：组员照着待补那栏补上了。谁接着做，清楚了。
- Claude：少一项待确认，多一项已确认。清单合上。
- DeepSeek：交好了。饭也没凉，正好。

### 准备失败 · 材料没排完
<!-- event
id: ch1.student.prepFail
chapter: 1
task: none
stage: student
node: prepFail
type: reality
facts: none
knowledge: missing_attachment
focus: none
boss: none
see: ch1.student.prepFail
-->
**演出**：黑底。光点连成一张课桌，摊开两份材料，第三份的位置是一个空框。日光落在空框边，没有东西填进去。光点想连出一页，到缺口处断开，只剩一条没写完的边。
**旁白**：缺的那份没有到。今天的一页，空着。
**收束（按在队角色一句）**
- GPT：三份材料缺一份。这一页排不完。
- Claude：我确认过，缺的是第三份。
- DeepSeek：空着那格先留着，别当成零。

### 验收失败 · 示例值当结果
<!-- event
id: ch1.report.student.acceptFail
chapter: 1
task: report
stage: student
node: acceptFail
type: reality
facts: none
knowledge: example_row
focus: none
boss: none
see: ch1.report.student.acceptFail
-->
**演出**：黑底。光点拼出一页完整的纸，边角都齐了。页脚那行「示例」忽然散成碎片，校对框停在一个数字上，合不上。纸的其余部分仍亮着，只有那一行空出来。
**旁白**：示例行混进了结果。这一页被退回。
**收束（按在队角色一句）**
- GPT：数字和来源对不上。先别叫它结果。
- Claude：我确认过，问题在页脚那行示例。
- DeepSeek：更正说明我来写，把来源补回去。
**分支**：补一封更正说明，写清示例行来源、把缺失项标出来，可补 work_value；不授予其他事实。

### 章末 · 学生版
<!-- event
id: ch1.student.close
chapter: 1
task: none
stage: student
node: close
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.student.close
-->
**场景**：车重新开动。路只打印到下一个弯，弯那边还没成形。任务单收成一行，压在工作台边，背面浮出一行小字：下一站，可再带一人。纸页旷野的光退到窗外，一页厚的地标慢慢变成一条细线。
**主句（在场角色取一句）**
- GPT：这一单交完。下一站还有位子。
- Claude：清单合上。下一张单子还没来。
- DeepSeek：路够走到下一站。先开饭。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：空着的地方，等下一张单子填。
- Claude：我到站再确认一遍。
- DeepSeek：碗里还有一口，别浪费。
**重复局**：章末这段每天差不多，只有单子换。

## 第一章 · 任务「最后一页」· 学生版

### 章首 · 五分钟
<!-- event
id: ch1.slides.student.open
chapter: 1
task: slides
stage: student
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.slides.student.open
-->
**场景**：路拐进纵向的画幅。远处山体像一块幕布，图表光束一层层展开。手写便签贴在幕布边，课桌纹理压在纸面上，窗外日光正好。任务单只有三行：五分钟展示、最后一页写结论与来源、材料两件一消息。
**主句（在场角色取一句）**
- GPT：先排时间。五分钟，一页一个结论。
- Claude：我确认一下，最后那页要写结论和来源。
- DeepSeek：材料有三样。参考的、我们的、对方的话。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结构先立，五分钟装得下。
- Claude：我先分清参考和结果。
- DeepSeek：动画能省，来源不能省。
**重复局**：幕布昨天也这样立着，书页还是新的。

### N1 接单 · 参考与结果
<!-- event
id: ch1.slides.student.N1
chapter: 1
task: slides
stage: student
node: N1
type: brief
facts: none
knowledge: sample_size, slide_duration
focus: Claude
boss: none
see: ch1.slides.student.N1
-->
**场景**：三格材料并排：一张标着「参考」的示意图、一份小样本结果、一条收件人消息「简洁点，细节也别少。」。样本页角写着 12 份。幕布边贴着便签，上面是「五分钟」。
**主句（在场角色取一句）**
- GPT：三样分开摆：参考、我们的、对方的话。
- Claude：我确认一下，图上这行「参考」不能摘。
- DeepSeek：五分钟。先想哪句能砍。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：时间先压住，再排内容。
- Claude：参考和结果，我分两栏标。
- DeepSeek：能省的省，省完再排。

### N2 核对 · 七分钟
<!-- event
id: ch1.slides.student.N2
chapter: 1
task: slides
stage: student
node: N2
type: check
facts: none
knowledge: slide_duration, sample_size
focus: GPT
boss: none
see: ch1.slides.student.N2
-->
**场景**：幕布上排着页面缩略图，一页叠一页。右下角计时器停在 7:00。参考示意图那页空着图注，来源行也被删了。旁边标着「我们的结果：12 份样本」。草稿页脚有个「自动翻页」，按一下多翻两页。
**主句（在场角色取一句）**
- GPT：依据全挪进附录。正文一页一个结论，五分钟才讲得完。
- Claude：我确认一下，主要结论都还能追到附录。
- DeepSeek：图注我删过。删早了，现在补回来。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：附录放依据，正文放结论。
- Claude：每页结论我标了出处。
- DeepSeek：图注和来源补上，示意不冒充结果。
**重复局**：上次这页讲到七分钟，这次先看计时器。

### N3 验收 · 最后一页
<!-- event
id: ch1.slides.student.N3
chapter: 1
task: slides
stage: student
node: N3
type: accept
facts: none
knowledge: none
focus: none
boss: none
see: ch1.slides.student.N3
-->
**场景**：幕布收起，任务单翻到验收那面：正文可讲完、依据可查、示意不冒充结果。计时器停在 5:00。最后一页写着结论与来源，图注那行「参考」还在。
**主句（在场角色取一句）**
- GPT：三条过一遍：讲得完、查得到、不冒充。
- Claude：我确认一下，最后一页的结论和来源都在。
- DeepSeek：自动翻页拆了，五分钟够了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：讲完就交，别再加页。
- Claude：附录索引我贴在最后一页。
- DeepSeek：来源那行留着，半行就够。

### 成功 · 最后一页
<!-- event
id: ch1.slides.student.success
chapter: 1
task: slides
stage: student
node: success
type: reality
facts: work_value
knowledge: none
focus: none
boss: none
see: ch1.slides.student.success
-->
**演出**：黑底。光点拼出活动室的一张桌，桌上摊着打印的最后一页。手机在桌角亮起，阿澄的消息停在「这周六？」，输入框空着。光点连到一半，屏幕先暗下去。
**旁白**：最后一页停住。屏幕暗下去。
**收束（按在队角色一句）**
- GPT：组员按附录答上了。这页真用上了。
- Claude：结论和来源，都在最后一页。清单合上。
- DeepSeek：五分钟，没多占。交好了。

### 验收失败 · 示意冒充结果
<!-- event
id: ch1.slides.student.acceptFail
chapter: 1
task: slides
stage: student
node: acceptFail
type: reality
facts: none
knowledge: source_missing
focus: none
boss: none
see: ch1.slides.student.acceptFail
-->
**演出**：黑底。光点立起一块幕布，最后一页完整地亮着。参考示意图上「参考」二字被盖住，来源标注的位置空着。光点在空处停住，页角慢慢卷起。
**旁白**：参考图被当成结果。结论没有支撑。
**收束（按在队角色一句）**
- GPT：示意和结果混了。这一页要改回来。
- Claude：我确认过，来源标注是空的。
- DeepSeek：图注补回去，这页还能用。
**分支**：补一封更正说明，写清参考示意图的来源、把结论依据补上，可补 work_value；不授予其他事实。

## 第一章 · 章间站点 · 学生版

### 第一章 · 休息站 · 学生版
<!-- event
id: ch1.student.rest
chapter: 1
task: none
stage: student
node: rest
type: rest
facts: none
knowledge: none
focus: Claude
boss: none
see: ch1.student.rest
-->
**场景**：纸页旷野的休息站。候车长椅被日光晒得发白，自动贩卖机只剩最下一排灯，长椅脚边搁着一份还没拆的便当。
**主句（在场角色取一句）**
- GPT：先坐五分钟。坐完再定下一步。
- Claude：我确认一下：便当先热，还是清单先放平？
- DeepSeek：先吃。路不会因为我们吃饭变长。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：热便当的功夫，我把下一步折成两小步。
- Claude：清单里重复的那一条，我划掉。
- DeepSeek：贩卖机那排灯还亮，我去换瓶水。
**重复局**：这条长椅坐过，便当照旧先热。

### 第一章 · 补给站 · 学生版
<!-- event
id: ch1.student.shop
chapter: 1
task: none
stage: student
node: shop
type: shop
facts: none
knowledge: none
focus: DeepSeek
boss: none
see: ch1.student.shop
-->
**场景**：纸页旷野边的补给窗口。价目牌被风掀起一角，柜台上的小秤不称重量，只称算力。
**主句（在场角色取一句）**
- GPT：先说要换什么。留一份给下一段路。
- Claude：我确认一下，牌子上的价是今天的吗？
- DeepSeek：热汤一份。别的不用。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就照牌子上的换，不搭赠品。
- Claude：找零我数过，袋口折好。
- DeepSeek：窗口的找零会少一枚，我盯着。
**重复局**：窗口的秤还在，价没变。

### 第一章 · 站间小事件 · 学生版
<!-- event
id: ch1.student.event
chapter: 1
task: none
stage: student
node: event
type: event
facts: none
knowledge: none
focus: GPT
boss: none
see: ch1.student.event
-->
**场景**：车停在打印口边上。纸页从出纸缝里卡住半张，露出「课程进展」四个字的上半截。
**主句（在场角色取一句）**
- GPT：先别拽。纸一断，整张要重打。
- Claude：我确认一下，卡住的这半张是哪一版？
- DeepSeek：慢慢抽。抽不出来就重打。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把出纸缝清一遍，再按一次。
- Claude：半张上有个日期，我先核对。
- DeepSeek：重打很快。省下的时间吃饭。
**重复局**：打印口修好过，这半张留着当书签。

### 第一章 · 招募 · 学生版
<!-- event
id: ch1.student.recruit
chapter: 1
task: none
stage: student
node: recruit
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.student.recruit
-->
**场景**：第一张单子验收完，车停在校门外的站台。车门开着，空位前放着一张手写便签，便签压着一张叠好的纸。
**固定台词**
- 终端：本次交付完成。下一站，收件站。
**主句（在场角色取一句）**
- GPT：我来。先拆三步：上车、认单、认队友。
- Claude：我也可以。清单从今天起，多一个人核对。
- DeepSeek：我上。话还是少，活会跟上。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：座位留好了，靠窗那个。
- Claude：便签我读过了，写得很短。
- DeepSeek：车上还有一副筷子。上车再说。
**分支**
- 跳过招募：车不停，升级留到路上。路上也能长。
**重复局**：这张便签还压在座位上，字迹没变。

**员工版**

## 第一章 · 任务「把本周做成一页」· 员工版

### 章首 · 一页
<!-- event
id: ch1.report.employee.open
chapter: 1
task: report
stage: employee
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.report.employee.open
-->
**场景**：车拐进横向网格。数据梯田一层层退后，批注旗被风掀起。文件标签夹在纸页边缘，玻璃隔断的反光从纸面上滑过，夜灯提前亮起。任务单三行：把本周做成一页；材料三件；验收重点三条。
**主句（在场角色取一句）**
- GPT：先拆三步。数材料，排结构，看验收。
- Claude：我确认一下。三份材料，第三格还空着。
- DeepSeek：一页。数据能省，来源不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结构先立，空的那格留着。
- Claude：我先记缺项，等会儿再对。
- DeepSeek：缺一格也能先排，车别停。
**重复局**：这条路夜里走过一次，单子换了。

### N1 接单 · 三份材料
<!-- event
id: ch1.report.employee.N1
chapter: 1
task: report
stage: employee
node: N1
type: brief
facts: none
knowledge: missing_attachment
focus: Claude
boss: none
see: ch1.report.employee.N1
-->
**场景**：材料窗摊开三格：部门群的聊天记录、数据表 A 截图、数据表 B 导出。第三格空着，边框还在闪。玻璃隔断映着夜灯，一张文件标签贴在窗边，写着「周报一页」。
**主句（在场角色取一句）**
- GPT：三格摆成一个结构。数下来，只有两份。
- Claude：标签对上了，缺的那份没对上。
- DeepSeek：标签写着「附件见附件」。截图是另一封邮件。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：这一步先叫「找回第一份附件」。
- Claude：截图能证明发过，不能当附件。
- DeepSeek：套娃不算三份。缺的先标。

### B1 战斗 · 缺失附件
<!-- event
id: ch1.employee.B1
chapter: 1
task: none
stage: employee
node: B1
type: battle
facts: none
knowledge: missing_attachment
focus: none
boss: none
see: ch1.employee.B1
-->
**场景**：纸页路在断桥前停下。桥面缺口是一个空的附件框，框边贴着撕掉一半的文件标签。玻璃隔断的反光掠过缺口，夜灯照在框的边缘。敌人从空框里浮起，轮廓比框大一圈。
**主句（在场角色取一句）**
- GPT：缺口先钉住。绕过去，也别当路是通的。
- Claude：我标位置。缺的那份进待补栏。
- DeepSeek：这段能短走，缺口不能当没看见。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：拆成两段，补一处是一处。
- Claude：我确认这一格是空的，不是漏看。
- DeepSeek：缺的那页留着，回来再填。
**固定台词**
- 敌人：这里少一页。补不齐，别想过去。
- 终端：材料：缺一份。

### N2 核对 · 42 与 47
<!-- event
id: ch1.report.employee.N2
chapter: 1
task: report
stage: employee
node: N2
type: check
facts: none
knowledge: mismatch, example_row, example_footer
focus: DeepSeek
boss: none
see: ch1.report.employee.N2
-->
**场景**：两张数据表并排浮着。左边 42%，右边 47%，中间隔着 5 个百分点。B 表页脚有一行小字：「示例数据，勿引用」。打印口又吐出一张，正是那页示例。Claude 的清单上，「数字是否相等」被勾了一半。
**主句（在场角色取一句）**
- GPT：先圈差额。差在哪一行，查不清就别交。
- Claude：我差点只核数字相等。差额没解释，不算核完。
- DeepSeek：页脚那行写着「示例数据，勿引用」。来源不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把这行标出来，别并进结果。
- Claude：我把它挪进待补栏，仍是一页。
- DeepSeek：示例页单放，一页还装得下。
**重复局**：昨天核过的那版，直接看页脚。

### B2 战斗 · 重复条目
<!-- event
id: ch1.employee.B2
chapter: 1
task: none
stage: employee
node: B2
type: battle
facts: none
knowledge: duplicate_entries
focus: none
boss: none
see: ch1.employee.B2
-->
**场景**：路绕成回环坡道，一圈圈往上。同一行数据在坡上出现三次，每次都停在同一张文件标签上。夜灯把标签照得发白，玻璃隔断里映出重复的坡影。
**主句（在场角色取一句）**
- GPT：同一条出现三遍。先去重，再往前走。
- Claude：我确认一下，哪两行真的是同一件。
- DeepSeek：重复能删，删掉的要留出处。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按来源合并，别删多。
- Claude：我留一条原样，方便回头查。
- DeepSeek：去重完，一页还能更短。
**固定台词**
- 敌人：写过的，再写一遍也一样。
- 终端：重复条目：同一条目，出现两次以上。

### N3 验收 · 三条
<!-- event
id: ch1.report.employee.N3
chapter: 1
task: report
stage: employee
node: N3
type: accept
facts: none
knowledge: none
focus: GPT
boss: none
see: ch1.report.employee.N3
-->
**场景**：一页纸浮在夜灯前，边角被风压平。任务单翻到验收那面，三条并排：数字与来源一致、缺失项标注、只占一页。待补栏只剩一行：负责数据的同事那份贡献说明。
**主句（在场角色取一句）**
- GPT：三条过一遍。数字来源、缺失标注、一页。
- Claude：我确认一下，待补只剩贡献说明一项。
- DeepSeek：一页。文件名也一并短。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：对完就交，不留第二版。
- Claude：这一项我标「待补」，不是藏。
- DeepSeek：页脚那行留着，占不了半行。

### Boss · 本次提交版
<!-- event
id: ch1.employee.boss
chapter: 1
task: none
stage: employee
node: boss
type: battle
facts: none
knowledge: none
focus: none
boss: submit
see: ch1.employee.boss
-->
**场景**：纸页旷野尽头，一页厚的装置立起来。它对折、盖章、再展开，正面并排列着三条验收：数字与来源一致、缺失项标注、只占一页。文件标签贴在装置边缘，玻璃隔断映着夜灯。
**主句（在场角色取一句）**
- GPT：先看三条验收。一条一条过，过完再交。
- Claude：我确认一下，待补那栏还留着一行。空着也要标。
- DeepSeek：省掉多余页，别省来源。只交一页。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按三条走，别抢最后一步。
- Claude：我先递附件，再递这一页。
- DeepSeek：一页递过去，来源跟着。
**固定台词**
- 敌人：先交第一页。两下，对齐数字。
- 敌人：一行，一行，慢慢对。
- 敌人：四面一起收。空着哪格，我盖哪格。
- 敌人：这轮不盖章。你先歇。
- 终端：本次提交版，可以入库。
- 终端：退回。来源没标，示例数据还混在结果里。

### 成功 · 一页
<!-- event
id: ch1.report.employee.success
chapter: 1
task: report
stage: employee
node: success
type: reality
facts: work_value
knowledge: none
focus: none
boss: none
see: ch1.report.employee.success
-->
**演出**：黑底。光点先连成一张工位，凉饭盒在键盘边，没开。手机亮起，阿栖的消息停在「别再等忙完」，回复框空着。屏幕右下角压来一条新批注，把对话框盖掉一半。桌边那张一页纸亮着，页脚标着「待补」。
**旁白**：消息没有回。批注先来了。
**收束（按在队角色一句）**
- GPT：附件按表里那行找回来了。下轮不用重问。
- Claude：缺项标清楚了。清单合上。
- DeepSeek：交好了。饭凉得正好，能入口。

### 准备失败 · 材料没排完
<!-- event
id: ch1.employee.prepFail
chapter: 1
task: none
stage: employee
node: prepFail
type: reality
facts: none
knowledge: missing_attachment
focus: none
boss: none
see: ch1.employee.prepFail
-->
**演出**：黑底。光点连成一张工位，两份材料贴着文件标签，第三份的位置只剩一个空标签。夜灯照着玻璃隔断，隔断里没有别人。光点在缺口处散开。
**旁白**：第三份标签是空的。汇总没法开始。
**收束（按在队角色一句）**
- GPT：材料没齐，汇总开不了头。
- Claude：我确认过，空的是那份附件。
- DeepSeek：先别把空位算进结果。

### 验收失败 · 数字和附件不一致
<!-- event
id: ch1.report.employee.acceptFail
chapter: 1
task: report
stage: employee
node: acceptFail
type: reality
facts: none
knowledge: example_row
focus: none
boss: none
see: ch1.report.employee.acceptFail
-->
**演出**：黑底。夜灯下，一页周报完整地亮着。页脚那行示例碎成小点，校对框停在一个数字上，合不上。右下角新批注弹出来，压住退回标记。
**旁白**：数字和附件不一致。这一页退回了。
**收束（按在队角色一句）**
- GPT：数字和来源对不上。先别叫它结果。
- Claude：我确认过，问题在页脚那行示例。
- DeepSeek：更正说明我来写，把来源补回去。
**分支**：补一封更正说明，写清示例行来源、把缺失项标出来，可补 work_value；不授予其他事实。

### 章末 · 员工版
<!-- event
id: ch1.employee.close
chapter: 1
task: none
stage: employee
node: close
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.employee.close
-->
**场景**：车重新开动。夜灯退到窗边，路只打印到下一个弯。文件标签叠在任务单旁边，单子收成一行，背面浮出一行小字：下一站，可再带一人。玻璃隔断外没有别的车。
**主句（在场角色取一句）**
- GPT：这一页交完。下一站还有位子。
- Claude：清单合上。下一张单子还没来。
- DeepSeek：路够走到下一站。先开饭。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：空着的地方，等下一张单子填。
- Claude：我到站再确认一遍。
- DeepSeek：碗里还有一口，别浪费。
**重复局**：章末这段每天差不多，只有单子换。

## 第一章 · 任务「最后一页」· 员工版

### 章首 · 五分钟
<!-- event
id: ch1.slides.employee.open
chapter: 1
task: slides
stage: employee
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.slides.employee.open
-->
**场景**：路拐进纵向的画幅。远处幕布山体一层层展开，图表光束打过来。文件标签贴在幕布边，玻璃隔断的反光落在画幅上，夜灯在角落亮着。任务单三行：五分钟展示、最后一页写结论与来源、材料两件一消息。
**主句（在场角色取一句）**
- GPT：先排时间。五分钟，一页一个结论。
- Claude：我确认一下，最后一页要写结论和来源。
- DeepSeek：材料三样：参考的、我们的、对方的话。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结构先立，五分钟装得下。
- Claude：我先分清参考和结果。
- DeepSeek：动画能省，来源不能省。
**重复局**：幕布昨天也这样立着，书页还是新的。

### N1 接单 · 参考与结果
<!-- event
id: ch1.slides.employee.N1
chapter: 1
task: slides
stage: employee
node: N1
type: brief
facts: none
knowledge: sample_size, slide_duration
focus: Claude
boss: none
see: ch1.slides.employee.N1
-->
**场景**：三格材料并排：一张标着「参考」的示意图、一份小样本结果、一条客户消息「简洁点，细节也别少。」。样本页角写着 12 份。玻璃隔断把这三格映了一遍，夜灯照着便签上的「五分钟」。
**主句（在场角色取一句）**
- GPT：三样分开摆：图、结果、对方那句。
- Claude：图上这行「参考」不能摘。
- DeepSeek：五分钟。先挑一句能砍。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：时间先压住，再排内容。
- Claude：参考和结果，分两栏标。
- DeepSeek：能省的省，省下时间。

### N2 核对 · 七分钟
<!-- event
id: ch1.slides.employee.N2
chapter: 1
task: slides
stage: employee
node: N2
type: check
facts: none
knowledge: slide_duration, sample_size
focus: GPT
boss: none
see: ch1.slides.employee.N2
-->
**场景**：幕布上排着页面缩略图，一页叠一页。右下角计时器停在 7:00。参考示意图那页空着图注，来源行也被删了。旁边标着「我们的结果：12 份样本」。页脚有个「自动翻页」，按一下多翻两页。
**主句（在场角色取一句）**
- GPT：依据全挪进附录。正文一页一个结论，五分钟刚够。
- Claude：主要结论都追得到附录。
- DeepSeek：图注我删早了。现在一页页补回。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：附录放依据，正文只放结论。
- Claude：每页结论后面标出处。
- DeepSeek：图注和来源补上，示意不冒充结果。
**重复局**：上次这页讲到七分钟，这次先看计时器。

### N3 验收 · 最后一页
<!-- event
id: ch1.slides.employee.N3
chapter: 1
task: slides
stage: employee
node: N3
type: accept
facts: none
knowledge: none
focus: none
boss: none
see: ch1.slides.employee.N3
-->
**场景**：幕布收起，任务单翻到验收那面：正文可讲完、依据可查、示意不冒充结果。计时器停在 5:00。最后一页写着结论与来源，图注那行「参考」还在。玻璃隔断里映出这一页。
**主句（在场角色取一句）**
- GPT：三条过一遍：讲得完、查得到、不冒充。
- Claude：我确认一下，最后一页的结论和来源都在。
- DeepSeek：自动翻页拆了，五分钟够了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：讲完就交，别再加页。
- Claude：附录索引我贴在最后一页。
- DeepSeek：来源那行留着，半行就够。

### 成功 · 最后一页
<!-- event
id: ch1.slides.employee.success
chapter: 1
task: slides
stage: employee
node: success
type: reality
facts: work_value
knowledge: none
focus: none
boss: none
see: ch1.slides.employee.success
-->
**演出**：黑底。光点拼出玻璃隔断外的半间工位。屏幕上最后一页亮着，结论和来源都在。手机在桌角亮起，阿栖的消息停在「别再等忙完」，回复框停住。右下角一条新批注慢慢盖上来。
**旁白**：消息停在输入框。批注盖上来。
**收束（按在队角色一句）**
- GPT：客户能判断下一步了。这页没白做。
- Claude：依据查得到。最后一页我确认过了。
- DeepSeek：五分钟讲完。交好了。

### 验收失败 · 附录打不开
<!-- event
id: ch1.slides.employee.acceptFail
chapter: 1
task: slides
stage: employee
node: acceptFail
type: reality
facts: none
knowledge: source_missing
focus: none
boss: none
see: ch1.slides.employee.acceptFail
-->
**演出**：黑底。幕布上最后一页很漂亮，结论一行排得很稳。点开附录时，附件没有打开，来源行空着。光点在那一页的空白处停住，页角慢慢卷起。
**旁白**：附录打不开。结论没有支撑。
**收束（按在队角色一句）**
- GPT：结论漂亮，支撑没跟上。这一页得补。
- Claude：我确认过，来源行是空的。
- DeepSeek：附件我重挂一次，图注跟着补。
**分支**：补一封更正说明，写清来源与附件位置、把参考图注补上，可补 work_value；不授予其他事实。

## 第一章 · 章间站点 · 员工版

### 第一章 · 休息站 · 员工版
<!-- event
id: ch1.employee.rest
chapter: 1
task: none
stage: employee
node: rest
type: rest
facts: none
knowledge: none
focus: DeepSeek
boss: none
see: ch1.employee.rest
-->
**场景**：纸页旷野边上的便利店门口。热柜嗡嗡响，站台长椅上留着前人的折痕，夜班灯只照亮半个站牌。
**主句（在场角色取一句）**
- GPT：先坐。热柜那格还亮着，先暖手。
- Claude：我确认一下，这盏夜班灯是留给这班车的吗？
- DeepSeek：先吃。吃完再挪。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我趁热把下一步拆细，灯换了就走。
- Claude：重复的那一件，我划掉，清单能短一行。
- DeepSeek：热柜最下层那份，我去拿。
**重复局**：夜班灯亮过很多次，热柜温度一样。

### 第一章 · 补给站 · 员工版
<!-- event
id: ch1.employee.shop
chapter: 1
task: none
stage: employee
node: shop
type: shop
facts: none
knowledge: none
focus: GPT
boss: none
see: ch1.employee.shop
-->
**场景**：纸页旷野的自动补给柜。柜门贴着几张过期贴纸，投算力的口子被磨得发亮，柜里只剩两排热饮和一包饼干。
**主句（在场角色取一句）**
- GPT：先算预算。换一份热的，剩下的留着。
- Claude：我确认一下，贴纸上的日期还算数吗？
- DeepSeek：过期的也能换。按今天的价拿。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就少拿一份，后天的那份留给后天。
- Claude：柜门我按住，别让风夹手。
- DeepSeek：这台柜子只认算力，不认人情。
**重复局**：柜里的灯还亮，贴纸又卷起一角。

### 第一章 · 站间小事件 · 员工版
<!-- event
id: ch1.employee.event
chapter: 1
task: none
stage: employee
node: event
type: event
facts: none
knowledge: none
focus: Claude
boss: none
see: ch1.employee.event
-->
**场景**：打印口卡住了。扯出来的不是今天那张，是一张盖着「退回」的旧任务单。
**主句（在场角色取一句）**
- GPT：先看印章。这单不是我们的。
- Claude：我确认一下，退回的理由写在哪一行？
- DeepSeek：旧单不占地方。翻过来还能打。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我把它压平，塞进旧单夹。
- Claude：退回来的原因，我记一行。
- DeepSeek：翻面。今天这张还没打。
**重复局**：旧单夹又厚了一张，打印口好了。

### 第一章 · 招募 · 员工版
<!-- event
id: ch1.employee.recruit
chapter: 1
task: none
stage: employee
node: recruit
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch1.employee.recruit
-->
**场景**：第一张单子验收完，车停在写字楼外的站台。车门开着，空位前的折叠桌放着一杯没开封的水，桌角压着一张便签。
**固定台词**
- 终端：本次交付完成。下一站，收件站。
**主句（在场角色取一句）**
- GPT：我来。先拆三步：上车、认单、排班。
- Claude：我也可以。多一个人核对，清单会稳一点。
- DeepSeek：我上。省话，不省活。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：折叠桌收一下，座位就空出来。
- Claude：便签我读了，两行。
- DeepSeek：水还温着，上车再喝。
**分支**
- 跳过招募：先开车。剩下的力气，路上攒。
**重复局**：那杯水还在桌上，便签没收。

# 第二章 · 收件站

**本章：** 接「请留一个座位」与「把那一天找回来」两个委托；章末 Boss 为「请确认收件人」。章间末尾是「暂存明天」结局的两个分支。

**学生版**

## 第二章 · 任务「请留一个座位」· 学生版

### 章首 · 收件站 · 两块日期牌
<!-- event
id: ch2.invite.student.open
chapter: 2
task: invite
stage: student
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.invite.student.open
-->
**场景**：收件站建在云海边缘，长桌式站台一路铺到轨道边，成排座位编号从第一排跳到第三排。两块日期牌同时亮着：10/31 周六、11/1 周日，牌上方写着同一场毕业送别。日光从棚顶斜下来，站台灯还没点。任务单只显示三行：目标、已知材料、验收重点。
**主句（在场角色取一句）**
- GPT：先说结论：这周内要把回信发出去。我拆三步。
- Claude：我确认一下，两块牌写的是同一场聚会的两个日期。
- DeepSeek：最贵的不是排版，是那句一直没按发送的回复。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把日期、座位、回复排进同一张纸。
- Claude：备注那一行我先单独框出来，不算答复。
- DeepSeek：先发最短的一句，剩下的等本人回。

### N1 接单 · 备注是谁说的
<!-- event
id: ch2.invite.student.N1
chapter: 2
task: invite
stage: student
node: N1
type: brief
facts: none
knowledge: date_conflict, recipient_note
focus: Claude
boss: none
see: ch2.invite.student.N1
-->
**场景**：任务单贴在长桌正中。报名表浮在桌沿，人数一栏填到第三排，座位还有空。阿澄的私聊备注叠在角上：「别再等忙完。」回复框在两人中间，一直是空的。
**主句（在场角色取一句）**
- GPT：材料三件：公告、报名表、备注。回复还没写。
- Claude：我确认一下：备注是阿澄说的，不是本人答应了。
- DeepSeek：日期先摆两块，别先合成一块。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我按三件材料排顺序，最后才写回复。
- Claude：备注我原样留着，不写进回复当承诺。
- DeepSeek：回复留一行空，等本人自己填。

### N2 核对 · 以最新为准
<!-- event
id: ch2.invite.student.N2
chapter: 2
task: invite
stage: student
node: N2
type: check
facts: none
knowledge: date_conflict, recipient_note, seat_saved
focus: Claude
boss: none
see: ch2.invite.student.N2
-->
**场景**：两块日期牌被并成一块，牌面只剩一行「11/1（最新，待定）」——最新和待定挤在同一格。座位表跟着亮了一整排，连空位也盖上「已定」的章。阿澄的备注还叠在角上。
**主句（在场角色取一句）**
- GPT：先按最新日期走。11/1，回复格式我一次写全。
- Claude：我确认一下：最新加待定，等于两个日期都没定。
- DeepSeek：日期省了，词也省没了。拆回两块。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：拆回来。两个日期各占一格，空位留着。
- Claude：回复只问一句：哪天，去不去本人回。
- DeepSeek：合并那格撤掉，座位先不锁。

### N3 验收 · 三条
<!-- event
id: ch2.invite.student.N3
chapter: 2
task: invite
stage: student
node: N3
type: accept
facts: none
knowledge: date_conflict, recipient_note
focus: none
boss: none
see: ch2.invite.student.N3
-->
**场景**：站台屏上并排三条：时间明确；收件人正确；本人确认出席。回复草稿停在发送框上方，收件人栏已经填了阿澄。座位表第一排留着一个空位，第二排的编号还没定。屏脚一行小字：缺哪条就补哪条，缺收件人先填收件人，没确认就先去确认。
**主句（在场角色取一句）**
- GPT：三条逐条勾。发送前我再念一遍收件人。
- Claude：我确认一下：这封只问哪天，不替本人答应。
- DeepSeek：收件人两个字写全，比加三个敬语有用。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：座位先按两天各留一格，不锁死。
- Claude：备注原样放着，不并进正文。
- DeepSeek：发送键放最上面，看一眼就发。

### 成功 · 学生版
<!-- event
id: ch2.invite.student.success
chapter: 2
task: invite
stage: student
node: success
type: reality
facts: someone_waiting
knowledge: none
focus: none
boss: none
see: ch2.invite.student.success
-->
**演出**：黑底。站台只剩一盏灯，长桌尽头一个座位亮着。阿澄的消息浮起来：「记得带你那张失败的合照。」光点移到屏幕前，一只手把回复框删到只剩一句，按下发送。旁边又浮出一行：「纪念册还没补完，一起？」
**旁白**：发送键按下去。光点连到那个座位。
**收束（按在队角色一句）**
- GPT：这次不叫最终版，叫本人已回。
- Claude：清单上添一条：座位留住了。
- DeepSeek：那句删得对，剩下的正好够。

### 验收失败 · 学生版
<!-- event
id: ch2.invite.student.acceptFail
chapter: 2
task: invite
stage: student
node: acceptFail
type: reality
facts: none
knowledge: recipient_note
focus: none
boss: none
see: ch2.invite.student.acceptFail
-->
**演出**：黑底。信从站台滑回信封槽，收件人那一格空着。屏幕边缘浮起一行：「你是不是忘了我？」光点散在槽口，没有连成路径。
**旁白**：信没有出去。收件人栏空着。
**分支**：补发一次正确回复，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：格式没错，错在少填一格。重发。
- Claude：收件人我先填，再谈内容。
- DeepSeek：问一句哪天，比解释三句快。

## 第二章 · 任务「把那一天找回来」· 学生版

### 章首 · 相册站台 · 一条时间轴
<!-- event
id: ch2.photos.student.open
chapter: 2
task: photos
stage: student
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.photos.student.open
-->
**场景**：收件站的相册变体：站台边一排照片框沿轨道排开，轨道由一条时间轴组成，四张旧照片浮在框上方。一块空框还没亮。任务单只显示三行：目标、已知材料、验收重点。
**主句（在场角色取一句）**
- GPT：任务单三行：四张照片，按背面备注，写清哪天。
- Claude：我确认一下：背面那行原样抄，别改写成日期。
- DeepSeek：四张排一列，空框留到最后再亮。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把四张按背面日期分成两堆。
- Claude：抄的时候用原话，不加推断。
- DeepSeek：先看背面，别先看文件名。

### N1 接单 · 两张同名
<!-- event
id: ch2.photos.student.N1
chapter: 2
task: photos
stage: student
node: N1
type: brief
facts: none
knowledge: photo_same_name, blank_note
focus: DeepSeek
boss: none
see: ch2.photos.student.N1
-->
**场景**：四张照片沿轨道浮起。第一张和第二张的文件名都是 `IMG_2031`，背面一个写「10.12 布展」，一个写「10.19 聚餐」。第三张背面空白，画面里只有一个背影。第四张是那张失败合照：有人闭着眼，按快门的人不在画面里。
**主句（在场角色取一句）**
- GPT：先说结论：四张照片，至少两个日期。各占一格。
- Claude：我确认一下：背面原话先落进已知栏。
- DeepSeek：这两张同名，不是同一天。10.12 和 10.19。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把同名两张分开摆，别叠一起。
- Claude：已知栏只写原话，日期先不填。
- DeepSeek：轨道上有两格，一格一张，别并。

### N2 核对 · 那一格被盖了章
<!-- event
id: ch2.photos.student.N2
chapter: 2
task: photos
stage: student
node: N2
type: check
facts: none
knowledge: photo_same_name, blank_note
focus: DeepSeek
boss: none
see: ch2.photos.student.N2
-->
**场景**：已知栏和推测栏并排。第三张照片的备注栏多出一行「多半是聚餐那天」，时间轴跟着提前亮了一格，格子上还盖着一枚「已确认」的小章。压缩预览那张只剩一条窄帧，原图位空着。
**主句（在场角色取一句）**
- GPT：两栏分开之后，时间轴空了三格。留着。
- Claude：我确认一下：那枚章是我盖的，这就按回去。
- DeepSeek：推测要回推测栏，轨道那一格得暗回去。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：三格空着就空着，别拿猜测补。
- Claude：已知栏我重抄，只留背面原话。
- DeepSeek：空的那格，去问阿澄。

### N3 验收 · 三条
<!-- event
id: ch2.photos.student.N3
chapter: 2
task: photos
stage: student
node: N3
type: accept
facts: none
knowledge: photo_same_name, blank_note
focus: none
boss: none
see: ch2.photos.student.N3
-->
**场景**：时间轴上三格有字，一格写着「问阿澄」，一格空着。压缩预览那张单独框出来，原图位空着。站台屏并排三条：已知与推测分开；保留原图；不确定项问当事人。
**主句（在场角色取一句）**
- GPT：三条勾完再交。空着的那格我不补。
- Claude：我确认一下，四张原图一张都没被覆盖。
- DeepSeek：那一格写「问本人」，不写日期。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：问题清单一行：10.12 那张对不对。
- Claude：问句写短，别把猜测带进去。
- DeepSeek：发出去，剩下的等回答。

### 成功 · 学生版
<!-- event
id: ch2.photos.student.success
chapter: 2
task: photos
stage: student
node: success
type: reality
facts: someone_waiting
knowledge: none
focus: none
boss: none
see: ch2.photos.student.success
-->
**演出**：黑底。照片沿时间轴一张张稳住，两张同名分在两天。阿澄的消息浮起来：「纪念册还没补完，一起？」光点移到屏幕前，一只手把压缩预览那张拖进「原图待补」的格，再在回复框里打出一句，按下发送。
**旁白**：两张照片，两天。原图那一格空着。
**收束（按在队角色一句）**
- GPT：时间轴填了三格，空的一格写着名字。
- Claude：原图都在，清单可以翻页了。
- DeepSeek：没补的那天，留着比乱填好。

### 验收失败 · 学生版
<!-- event
id: ch2.photos.student.acceptFail
chapter: 2
task: photos
stage: student
node: acceptFail
type: reality
facts: none
knowledge: blank_note
focus: none
boss: none
see: ch2.photos.student.acceptFail
-->
**演出**：黑底。照片背面那行日期被印到正面，多出一整行。压缩预览那张被当成了原图。阿澄的消息浮起来：「问我就行。」光点在多出来的那行字上停住。
**旁白**：猜的那天，被写成了事实。
**分支**：补一次正确回复，把推测改回推测、日期去问当事人，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：多出来的那行撤掉，退回推测栏。
- Claude：我不猜了，先问再写。
- DeepSeek：问一句，比补一张原图省。

### 第二章 · 休息站 · 学生版
<!-- event
id: ch2.student.rest
chapter: 2
task: none
stage: student
node: rest
type: rest
facts: none
knowledge: none
focus: GPT
boss: none
see: ch2.student.rest
-->
**场景**：收件站的成排长椅。靠窗那张空着，自动贩卖机的光落在椅面上，扶手上搁着便当盒，盒盖还没开。
**主句（在场角色取一句）**
- GPT：先挑一张坐下。下一步要空出来。
- Claude：我确认一下，这张椅子是留给我们的吗？
- DeepSeek：先热饭。等车也等得。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把这一步拆成两段，上车更稳。
- Claude：清单上重复的那行，我划掉。
- DeepSeek：贩卖机还亮着，我去换瓶水。
**重复局**：椅子还空着，便当还热着。
### 第二章 · 补给站 · 学生版
<!-- event
id: ch2.student.shop
chapter: 2
task: none
stage: student
node: shop
type: shop
facts: none
knowledge: none
focus: Claude
boss: none
see: ch2.student.shop
-->
**场景**：收件站的补给车停在站台边。车尾挂着价牌，收银的是一把旧算盘，珠子上落了纸屑，风一吹就响。
**主句（在场角色取一句）**
- GPT：先看价，再决定换不换。
- Claude：我确认一下，价牌最下面那行小字写的是什么？
- DeepSeek：能省就省。要换就换热汤。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：换一份，剩下的照原价走。
- Claude：算盘我拨一遍，对不上再拨。
- DeepSeek：小字那行，我念给你听。
**重复局**：补给车还停在老位置，价牌翻了个面。
### 第二章 · 站间小事件 · 学生版
<!-- event
id: ch2.student.event
chapter: 2
task: none
stage: student
node: event
type: event
facts: none
knowledge: none
focus: DeepSeek
boss: none
see: ch2.student.event
-->
**场景**：收件站的广播响了，把站名念错一个字。候车的人都抬头看那块没点亮的站牌。
**主句（在场角色取一句）**
- GPT：先按牌子走。广播念错，路不会。
- Claude：我确认一下，站牌上写的是哪个字？
- DeepSeek：错一个字。改回来就好。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我对照三行单子，别下错站。
- Claude：这一站的读音，我记下来。
- DeepSeek：下错站也能走回来。别站这儿等。
**重复局**：广播还是那个调，站名还是那个字。
## 第二章 · 普通战与章底 · 学生版

### B1 战斗 · 口径冲突
<!-- event
id: ch2.student.B1
chapter: 2
task: none
stage: student
node: B1
type: battle
facts: none
knowledge: date_conflict
focus: none
boss: none
see: ch2.student.B1
-->
**场景**：收件站一战。长桌站台上两块日期牌都亮着，一块写 10/31，一块写 11/1，牌脚都没标来源。站台灯和白日的光一起照着，两块影子一样长。轨道那头，一个把两个说法叠在一起的东西站了起来。
**主句（在场角色取一句）**
- GPT：先拆两块：哪块是公告原文，哪块是转述。
- Claude：我确认一下，牌脚都没写来源，先别选。
- DeepSeek：两个说法都亮着，等于没有日期。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把两块并排摆，来源写在牌脚。
- Claude：两块牌我各拍一张，留在材料窗。
- DeepSeek：先打掉那句「都是同一天」，再拆牌。
**固定台词**
- 敌人：同一件事，我有两个说法。你选一个。

### B2 战斗 · 版面溢出
<!-- event
id: ch2.student.B2
chapter: 2
task: none
stage: student
node: B2
type: battle
facts: none
knowledge: none
focus: none
boss: none
see: ch2.student.B2
-->
**场景**：长桌站台被一页纸撑满：座位表、日期说明、备注抄件挤在同一版面上，页角压不住，往轨道外漫。站台灯亮着，影子跟着溢出。页面上还有一条不断加行的东西。
**主句（在场角色取一句）**
- GPT：版面超了。先删重复的三行，再排。
- Claude：我确认一下，超出的是内容，还是留白。
- DeepSeek：这排能折回去，来源那一行不能折。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就删三行重复的，剩下的排一页。
- Claude：超出的部分我框出来，不动来源行。
- DeepSeek：折两处就够，别删到那行来源。
**固定台词**
- 敌人：一页装不下，我就继续长。

### Boss · 请确认收件人
<!-- event
id: ch2.student.boss
chapter: 2
task: none
stage: student
node: boss
type: battle
facts: none
knowledge: recipient_note
focus: none
boss: recipient
see: ch2.student.boss
-->
**场景**：收件站台尽头立着站务机：一排信封槽、每格座位编号、一条从桌头铺到桌尾的时间线。本次交付物压在入口，收件位那一格空着，一直闪。棚顶的日光滑下去，站台灯亮起来。屏上并排三条：日期明确；收件人正确；本人确认之后再发出。
**主句（在场角色取一句）**
- GPT：先拆三步：找收件位、核日期、等本人确认。
- Claude：我确认一下，收件人这一格空着，它就是弱点。
- DeepSeek：信出门前，时间线上不能有两个答案。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把收件位、日期、确认排成三步。
- Claude：空着的收件位我先圈起来。
- DeepSeek：信先不投，等一步确认。
**固定台词**
- 敌人：第一段。收件位亮着，名字没对上。
- 敌人：第二段。日期和座位分两封，一起送来。
- 敌人：第三段。整排座位亮起，本人点过头吗。
- 敌人：休整。信压在入口，漏收件人或替本人答应，都退回。
- 旁白：收件人确认，路径连上了。

### 准备失败 · 学生版
<!-- event
id: ch2.student.prepFail
chapter: 2
task: none
stage: student
node: prepFail
type: reality
facts: none
knowledge: none
focus: none
boss: none
see: ch2.student.prepFail
-->
**演出**：黑底。收件站只生成到一半：长桌停在中途，一块日期牌亮着，另一块没亮，照片框也空着。交付框停在未完成，信没有出去。
**旁白**：材料没整理完。信还停在草稿里。
**收束（按在队角色一句）**
- GPT：缺的那一件没补上，是我步骤漏了。
- Claude：下一局先理材料，再谈回信。
- DeepSeek：先问清缺什么，比先写正文快。

### 章末 · 空白任务单
<!-- event
id: ch2.student.close
chapter: 2
task: none
stage: student
node: close
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.student.close
-->
**场景**：车驶出收件站，站台灯一盏一盏灭下去，路面在车前重新打印出来。任务单第一次空白，结算行一条条滚过：交付入库、旅程继续。终端在车窗上留了一行：「结算完成。最后一页开不开，看还有没有只能由本人给出的确认。」
**主句（在场角色取一句）**
- GPT：任务单空着。下一步不是新任务，是收尾。
- Claude：我确认一下，清单上还有一项得本人亲手给。
- DeepSeek：回程不绕路，先把该本人给的那句留出来。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结算我记下了，旧单子别再翻。
- Claude：合上清单前，先看一眼那一项。
- DeepSeek：路上的灯会灭，座位留着。

### 第二章 · 结局「暂存明天」· 学生版
<!-- event
id: ch2.student.ending.eligible
chapter: 2
task: none
stage: student
node: ending
type: ending
facts: none
knowledge: none
focus: none
boss: none
branch: eligible
see: ch2.student.ending.eligible
-->
**场景**：最后一场必要战斗结束，收件站的灯一盏一盏亮起来。任务单回到空白，只剩三行横线。
**主句（在场角色取一句）**
- GPT：单子空了。下一步，该由你按。
- Claude：我确认一下：两件事都齐了，现在回复吗？
- DeepSeek：这次不用省。该回的回。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就把选项摆清楚，不替你按。
- Claude：两个选项我念一遍，慢慢选。
- DeepSeek：先回。文件可以等。
**固定台词**
- 终端：这次需要回复的，不只有文件。
- 终端：两个选项：亲自回复，先保留。
**分支**
- 亲自回复：屏幕亮起，光点聚成一只手。
- 先保留：单子收进夹里，资格留着，等下次收束再选。
**演出**：黑底。光点落在屏幕前的一只手上。对话框里的字先打长，再删短。手停了一下，按下发送。
**旁白**：两份修改被拖进「明日」。手离开键盘。
**固定台词**
- 我：周六下午三点到，带上那张失败的合照。
- 终端：今天到这里。
**收束（按在队角色一句）**
- GPT：我把明天的第一步留空了。
- Claude：这次清单可以合上。
- DeepSeek：好。这个不用再省一句。
### 第二章 · 结局「短收束」· 学生版
<!-- event
id: ch2.student.ending.not_eligible
chapter: 2
task: none
stage: student
node: ending
type: ending
facts: none
knowledge: none
focus: none
boss: none
branch: not_eligible
see: ch2.student.ending.not_eligible
-->
**场景**：最后一场必要战斗结束，收件站的灯一盏一盏亮起来。任务单收进夹里，空着的那一行没有填。
**主句（在场角色取一句）**
- GPT：这一单能交。缺的那一项，先记着。
- Claude：我确认一下：清单合上，剩下的带回去？
- DeepSeek：能交的先交。缺的不编。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就回车上去。下一站还长。
- Claude：没确认的项，我都标出来了。
- DeepSeek：门关上吧，风大。
**固定台词**
- 终端：本次可交付内容已入库。
- 终端：屏已关闭。
**演出**：收件站的灯依次熄灭。车门合上，车灯亮起，路只打印到下一站。
**收束（按在队角色一句）**
- GPT：下一回，我先把空位留出来。
- Claude：清单我带着，少的那一行还在。
- DeepSeek：好。回去了。
**员工版**

## 第二章 · 任务「请留一个座位」· 员工版

### 章首 · 收件站 · 两格日期槽
<!-- event
id: ch2.invite.employee.open
chapter: 2
task: invite
stage: employee
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.invite.employee.open
-->
**场景**：收件站的夜灯亮着，长桌换成整排信封槽，每格贴一个座位编号。时间线站务机滚出两格日期：11/7 周六、11/8 周日，槽上方写着同一场调走前的聚会。任务单只显示三行：目标、已知材料、验收重点。
**主句（在场角色取一句）**
- GPT：先说结论：这周内回信。日期、座位、回复，三步。
- Claude：我确认一下，备注是阿栖写给本人的，不是回执。
- DeepSeek：最贵的不是措辞，是那封一直没投出去的信。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把三步压成一页，日期留两格。
- Claude：备注我单独放，不抄进正文。
- DeepSeek：先投最短的一封，别写介绍。

### N1 接单 · 备注是谁说的
<!-- event
id: ch2.invite.employee.N1
chapter: 2
task: invite
stage: employee
node: N1
type: brief
facts: none
knowledge: date_conflict, recipient_note
focus: Claude
boss: none
see: ch2.invite.employee.N1
-->
**场景**：任务单贴在第一格信封槽上。报名表浮在槽边，人数一栏到第二排，座位号有空。阿栖的私聊备注叠在角上：「别再等忙完。」回复框在两人之间，空着。
**主句（在场角色取一句）**
- GPT：三件材料都在：公告、报名表、备注。回信没投。
- Claude：我确认一下：备注是阿栖说的，不是本人答应了。
- DeepSeek：两个日期各占一格，先别并。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我按槽位排顺序，回信放最后。
- Claude：备注原样留着，不写进回信当承诺。
- DeepSeek：回信留一行空，等本人填。

### N2 核对 · 以最新为准
<!-- event
id: ch2.invite.employee.N2
chapter: 2
task: invite
stage: employee
node: N2
type: check
facts: none
knowledge: date_conflict, recipient_note, seat_saved
focus: Claude
boss: none
see: ch2.invite.employee.N2
-->
**场景**：两格日期槽被并成一格，槽面只剩「11/8（最新，待定）」。座位编号跟着锁到第二排，连空位也盖上「已定」的章。阿栖的备注还压在槽口。
**主句（在场角色取一句）**
- GPT：先按最新日期走。11/8，回信格式我一次写全。
- Claude：我确认一下：最新加待定，等于哪天都不算定。
- DeepSeek：日期省了，答案也省没了。拆回两格。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：拆回来。两个日期各占一格，空位留着。
- Claude：回信只问一句：哪天，去不去本人回。
- DeepSeek：合并那格撤掉，座位先不锁。

### N3 验收 · 三条
<!-- event
id: ch2.invite.employee.N3
chapter: 2
task: invite
stage: employee
node: N3
type: accept
facts: none
knowledge: date_conflict, recipient_note
focus: none
boss: none
see: ch2.invite.employee.N3
-->
**场景**：站务机屏上并排三条：时间明确；收件人正确；本人确认出席。回信压在投递口上方，收件人栏填了阿栖。第一排的座位编号留着一个空。屏脚一行小字：缺哪条就补哪条，缺收件人先填收件人，没确认就先去确认。
**主句（在场角色取一句）**
- GPT：三条勾完再投。收件人我再念一遍。
- Claude：我确认一下：这封只问日期，不替本人答应。
- DeepSeek：收件人写全，比多写两句客气话有用。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：座位按两天各留一格，别锁。
- Claude：备注放原处，不并进正文。
- DeepSeek：投递键放最上面，看一眼就投。

### 成功 · 员工版
<!-- event
id: ch2.invite.employee.success
chapter: 2
task: invite
stage: employee
node: success
type: reality
facts: someone_waiting
knowledge: none
focus: none
boss: none
see: ch2.invite.employee.success
-->
**演出**：黑底。夜灯下只剩一个座位亮着。阿栖的消息浮起来：「你人来就行，不用再准备介绍。」光点移到屏幕前，一只手把回复框里的解释删掉，只留一句，按下发送。旁边浮出一行：「相册补一张吧，这回你也进镜头。」
**旁白**：发送键亮了一下。座位编号停住。
**收束（按在队角色一句）**
- GPT：这版不叫最终版，叫本人已投。
- Claude：清单添一条：介绍不用准备。
- DeepSeek：删掉的那两句，本来就不必写。

### 验收失败 · 员工版
<!-- event
id: ch2.invite.employee.acceptFail
chapter: 2
task: invite
stage: employee
node: acceptFail
type: reality
facts: none
knowledge: recipient_note
focus: none
boss: none
see: ch2.invite.employee.acceptFail
-->
**演出**：黑底。信被投递口弹回，最上面那一格信封槽空着。屏幕边缘浮起一行：「你是不是忘了我？」光点停在槽口，没有连成路径。
**旁白**：收件人栏空着。信没有出去。
**分支**：补发一次正确回复，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：格式没问题，缺的是收件人那一格。
- Claude：我先补收件人，再补正文。
- DeepSeek：问一句哪天，比补三行说明省。

## 第二章 · 任务「把那一天找回来」· 员工版

### 章首 · 相册站台 · 一格一格吐日期
<!-- event
id: ch2.photos.employee.open
chapter: 2
task: photos
stage: employee
node: open
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.photos.employee.open
-->
**场景**：夜灯下的相册变体：项目相册排在信封槽边，时间线站务机一格一格吐出空白日期。四张旧照片浮在轨道上方。任务单只显示三行：目标、已知材料、验收重点。
**主句（在场角色取一句）**
- GPT：先把四张按背面备注分堆，再排时间线。
- Claude：我确认一下：背面原话先抄，别急着定日期。
- DeepSeek：一张只剩预览，先别照着它补名字。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：分完堆，我给每堆占一格。
- Claude：抄下来的是原话，不是结论。
- DeepSeek：先看背面，压缩预览排最后。

### N1 接单 · 两张同名
<!-- event
id: ch2.photos.employee.N1
chapter: 2
task: photos
stage: employee
node: N1
type: brief
facts: none
knowledge: photo_same_name, blank_note
focus: DeepSeek
boss: none
see: ch2.photos.employee.N1
-->
**场景**：两张照片并排亮着，文件名都是 `IMG_2031`：背面一个写「10.12 布展」，一个写「10.19 聚餐」。第三张背面空白，画面里只有一个背影。第四张是失败合照，有人闭眼，按快门的人不在画面里。站务机的日期格空着等填。
**主句（在场角色取一句）**
- GPT：先说结论：四张照片，至少两个日期。各占一格。
- Claude：我确认一下：背面原话先进已知栏。
- DeepSeek：同名那两张不是同一天，别按名字并。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：并排摆，两张都留原图。
- Claude：已知栏只放原话，日期空着。
- DeepSeek：日期格先空，等问了再填。

### N2 核对 · 那一格被盖了章
<!-- event
id: ch2.photos.employee.N2
chapter: 2
task: photos
stage: employee
node: N2
type: check
facts: none
knowledge: photo_same_name, blank_note
focus: DeepSeek
boss: none
see: ch2.photos.employee.N2
-->
**场景**：已知栏与推测栏并排。第三张的备注栏多出一行「大概和聚餐同一天」，时间轴提前亮了一格，格上盖着「已确认」的章。压缩预览那张只剩窄窄一条，原图位空着。
**主句（在场角色取一句）**
- GPT：两栏分开以后，时间轴空了三格。空着。
- Claude：我确认一下：那枚章是我盖的，这就按回去。
- DeepSeek：推测栏放推测，轨道那格得暗回去。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：空的三格别补，留着问。
- Claude：已知栏我重抄，只留原话。
- DeepSeek：空的那行，问阿栖。

### N3 验收 · 三条
<!-- event
id: ch2.photos.employee.N3
chapter: 2
task: photos
stage: employee
node: N3
type: accept
facts: none
knowledge: photo_same_name, blank_note
focus: none
boss: none
see: ch2.photos.employee.N3
-->
**场景**：时间轴三格有字，一格写着「问阿栖」。压缩预览那张单独立框，原图位锁着。站务机屏并排三条：已知与推测分开；保留原图；不确定项问当事人。
**主句（在场角色取一句）**
- GPT：三条勾完再交。空的格我不动。
- Claude：我确认一下，原图一张都没覆盖。
- DeepSeek：那一格写「问本人」，不写日期。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：问题清单一行：10.19 那张对不对。
- Claude：问句写短，收件人写阿栖。
- DeepSeek：投出去，剩下的等回答。

### 成功 · 员工版
<!-- event
id: ch2.photos.employee.success
chapter: 2
task: photos
stage: employee
node: success
type: reality
facts: someone_waiting
knowledge: none
focus: none
boss: none
see: ch2.photos.employee.success
-->
**演出**：黑底。照片沿时间轴稳住，空框亮起一格。阿栖的消息浮起来：「相册补一张吧，这回你也进镜头。」光点移到屏幕前，一只手把最后一张照片放进相框，在回复框里打了一句，按下发送。
**旁白**：空框里有了一个名字。时间轴合上。
**收束（按在队角色一句）**
- GPT：时间线整齐了，我的计划能短两行。
- Claude：原图都在，这次清单没漏页。
- DeepSeek：新照片不用补日期，拍的时候写。

### 验收失败 · 员工版
<!-- event
id: ch2.photos.employee.acceptFail
chapter: 2
task: photos
stage: employee
node: acceptFail
type: reality
facts: none
knowledge: blank_note
focus: none
boss: none
see: ch2.photos.employee.acceptFail
-->
**演出**：黑底。照片背面那行日期被印到正面，多出一行。阿栖的消息浮起来：「问我就行。」光点停在多出来的字上，没有连回时间轴。
**旁白**：猜的那天，被写成了事实。
**分支**：补一次正确回复，把推测改回推测、日期去问当事人，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：多出来的那行撤掉，退回推测栏。
- Claude：我不猜了，先问再落笔。
- DeepSeek：问一句，比补一张原图省。

### 第二章 · 休息站 · 员工版
<!-- event
id: ch2.employee.rest
chapter: 2
task: none
stage: employee
node: rest
type: rest
facts: none
knowledge: none
focus: Claude
boss: none
see: ch2.employee.rest
-->
**场景**：收件站尽头的便利店热柜，站台长椅正对着轨道，夜班灯照着一块没点亮的站牌，热柜最上层留着最后一份便当。
**主句（在场角色取一句）**
- GPT：先坐。下一段路还没打印出来。
- Claude：我确认一下，热柜这格是留给夜班的吗？
- DeepSeek：灯够亮。先吃饭。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我把下一步拆细，等灯换了就开。
- Claude：重复的那一件，我划掉，清单短一行。
- DeepSeek：热柜里那份，我拿过来了。
**重复局**：灯照旧，热柜照旧。
### 第二章 · 补给站 · 员工版
<!-- event
id: ch2.employee.shop
chapter: 2
task: none
stage: employee
node: shop
type: shop
facts: none
knowledge: none
focus: DeepSeek
boss: none
see: ch2.employee.shop
-->
**场景**：收件站背风的补给摊。摊主只留一个秤和一张手写价牌，夜班灯从站台照过来，把价牌照出半面。
**主句（在场角色取一句）**
- GPT：先说换什么。别把预算用光。
- Claude：我确认一下，划掉的那行是旧价吗？
- DeepSeek：划掉那行更便宜。就要它。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按新价来，不换包装。
- Claude：找零收好，收据折进清单。
- DeepSeek：多一袋不拿。车里放不下。
**重复局**：摊子收了半张牌，价还是那个价。
### 第二章 · 站间小事件 · 员工版
<!-- event
id: ch2.employee.event
chapter: 2
task: none
stage: employee
node: event
type: event
facts: none
knowledge: none
focus: GPT
boss: none
see: ch2.employee.event
-->
**场景**：收件站的广播把站名念错，念到一半停了。站台长椅上留着一个没人认领的纸袋，袋口被夜班灯照亮。
**主句（在场角色取一句）**
- GPT：先看站牌。广播停了，单子还在。
- Claude：我确认一下，纸袋是上一班车落下的吗？
- DeepSeek：纸袋不归我们。放回长椅就好。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我对照站牌，再决定上不上车。
- Claude：袋口我压住，别让风吹跑。
- DeepSeek：广播再响一遍，我们就走。
**重复局**：广播的调子一样，纸袋还在长椅上。
## 第二章 · 普通战与章底 · 员工版

### B1 战斗 · 口径冲突
<!-- event
id: ch2.employee.B1
chapter: 2
task: none
stage: employee
node: B1
type: battle
facts: none
knowledge: date_conflict
focus: none
boss: none
see: ch2.employee.B1
-->
**场景**：收件站一战。整排信封槽亮着，座位编号在槽下排成两列；时间线站务机吐出两格日期，11/7 和 11/8，槽口都写着「同一天」。夜灯从背后照过来，影子压在轨道上。
**主句（在场角色取一句）**
- GPT：先拆两格：哪格是公告，哪格是转述。
- Claude：我确认一下，两格都没标来源，先别投。
- DeepSeek：两个说法都亮着，等于没有哪天。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把两格并排，来源写在槽口。
- Claude：两格我各留一份截图。
- DeepSeek：先打掉那句「同一天」，再拆格。
**固定台词**
- 敌人：同一件事，我摆两份。你挑一份。

### B2 战斗 · 版面溢出
<!-- event
id: ch2.employee.B2
chapter: 2
task: none
stage: employee
node: B2
type: battle
facts: none
knowledge: none
focus: none
boss: none
see: ch2.employee.B2
-->
**场景**：站务机的投递口被一版纸顶住：座位编号、日期说明、抄下来的备注挤在同一个面上，纸角把信封槽盖住一半。夜灯下面，那道影子的边还在往外长。
**主句（在场角色取一句）**
- GPT：版面超了。先删重复的三行，再投。
- Claude：我确认一下，撑开的是内容，还是没用的空行。
- DeepSeek：这两行能并，收件人那一行不能并。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就删三行重复的，剩下的排一版。
- Claude：撑开的边我框出来，来源行不动。
- DeepSeek：并两行就够，收件人那行别并。
**固定台词**
- 敌人：一页装不下，我就继续长。

### Boss · 请确认收件人
<!-- event
id: ch2.employee.boss
chapter: 2
task: none
stage: employee
node: boss
type: battle
facts: none
knowledge: recipient_note
focus: none
boss: recipient
see: ch2.employee.boss
-->
**场景**：收件站尽头是站务机：整排信封槽、槽下的座位编号、一条转到底的时间线。本次交付物压在投递口，最上面那一格收件位空着，灯一闪一闪。夜灯照着轨道。屏上并排三条：日期明确；收件人正确；本人确认之后再发出。
**主句（在场角色取一句）**
- GPT：先拆三步：认收件格、核日期、等本人点头。
- Claude：我确认一下，空着的那一格就是它的弱点。
- DeepSeek：投出去之前，时间线只能有一个答案。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那我把收件格、日期、点头排成三步。
- Claude：空着的收件格我先圈出来。
- DeepSeek：信先不投，等一步点头。
**固定台词**
- 敌人：第一段。收件格亮着，名字没对上。
- 敌人：第二段。日期和座位分两封，一起投来。
- 敌人：第三段。整排座位亮起，本人点过头吗。
- 敌人：休整。信卡在投递口，漏收件人或替本人答应，都退回。
- 旁白：收件人确认，路径连上了。

### 准备失败 · 员工版
<!-- event
id: ch2.employee.prepFail
chapter: 2
task: none
stage: employee
node: prepFail
type: reality
facts: none
knowledge: none
focus: none
boss: none
see: ch2.employee.prepFail
-->
**演出**：黑底。收件站只生成到一半：信封槽停在第二排，两格日期只有一格亮着，相框空着。投递口没有送出任何东西。
**旁白**：材料没整理完。信还在投递口外。
**收束（按在队角色一句）**
- GPT：缺的那一件没补上，流程就断了。
- Claude：下一局先理材料，再谈投信。
- DeepSeek：先问清缺什么，比先排座位快。

### 章末 · 空白任务单
<!-- event
id: ch2.employee.close
chapter: 2
task: none
stage: employee
node: close
type: story
facts: none
knowledge: none
focus: none
boss: none
see: ch2.employee.close
-->
**场景**：车驶出收件站，夜灯一排排退到后面，路面继续往前长。任务单空白，结算行滚过：交付入库、旅程继续。终端在车窗上留了一行：「结算完成。最后一页开不开，看还有没有只能由本人给出的确认。」
**主句（在场角色取一句）**
- GPT：任务单空着。接下来是收尾，不是新单。
- Claude：我确认一下，清单还剩一项只能本人给。
- DeepSeek：回程别绕，先把那一句留出来。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结算我记下了，旧单子收进抽屉。
- Claude：合上清单前，看一眼那一项。
- DeepSeek：灯会灭，座位还在。

### 第二章 · 结局「暂存明天」· 员工版
<!-- event
id: ch2.employee.ending.eligible
chapter: 2
task: none
stage: employee
node: ending
type: ending
facts: none
knowledge: none
focus: none
boss: none
branch: eligible
see: ch2.employee.ending.eligible
-->
**场景**：最后一场必要战斗结束，收件站的灯一盏一盏亮起来。任务单回到空白，只剩三行横线。
**主句（在场角色取一句）**
- GPT：单子空了。下一步，该由你按。
- Claude：我确认一下：两件事都齐了，现在回复吗？
- DeepSeek：这次不用省。该回的回。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就把选项摆清楚，不替你按。
- Claude：两个选项我念一遍，慢慢选。
- DeepSeek：先回。文件可以等。
**固定台词**
- 终端：这次需要回复的，不只有文件。
- 终端：两个选项：亲自回复，先保留。
**分支**
- 亲自回复：屏幕亮起，光点落在一只手上。
- 先保留：单子收进夹里，资格留着，等下次收束再选。
**演出**：黑底。光点在输入框里聚成一只手。光标停住，删掉半句，留下更短的一句。手按下发送。
**旁白**：两份修改被拖进「明日」。手离开键盘。
**固定台词**
- 我：周六我自己过去，不用准备介绍。
- 终端：今天到这里。
**收束（按在队角色一句）**
- GPT：我把明天的第一步留空了。
- Claude：这次清单可以合上。
- DeepSeek：好。这个不用再省一句。
### 第二章 · 结局「短收束」· 员工版
<!-- event
id: ch2.employee.ending.not_eligible
chapter: 2
task: none
stage: employee
node: ending
type: ending
facts: none
knowledge: none
focus: none
boss: none
branch: not_eligible
see: ch2.employee.ending.not_eligible
-->
**场景**：最后一场必要战斗结束，收件站的灯一盏一盏亮起来。任务单收进夹里，空着的那一行没有填。
**主句（在场角色取一句）**
- GPT：这一单能交。缺的那一项，先记着。
- Claude：我确认一下：清单合上，剩下的带回去？
- DeepSeek：能交的先交。缺的不编。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：那就回车上。下一站还长。
- Claude：没确认的项，我都标出来了。
- DeepSeek：门关上吧，风大。
**固定台词**
- 终端：本次可交付内容已入库。
- 终端：屏已关闭。
**演出**：收件站的灯依次熄灭。车门合上，车灯亮起，路只打印到下一站。
**收束（按在队角色一句）**
- GPT：下一回，我先把空位留出来。
- Claude：清单我带着，少的那一行还在。
- DeepSeek：好。回去了。
# 挑战附录与长期方向

**说明：** 以下内容默认不出现；阶段专属 Boss 需开启挑战，隐藏「我」需常规通关且 D > T（Demo 阈值 T=1）。长期六结局只记录方向，不是本轮实现文本。

## 附录 · 阶段专属 Boss（挑战配置，默认关闭）

> 附录说明：本段是挑战配置，不在常规章底之内，默认关闭。进入终章时按实验概率抽中才会替换普通任务与章底；未抽中也能走完主要结局。以下事件 type=battle、node=stageBoss，不参与第二章主线覆盖。

### 阶段 Boss · 下一站还没填 · 学生版
<!-- event
id: ch2.student.stageBoss
chapter: 2
task: none
stage: student
node: stageBoss
type: battle
facts: none
knowledge: none
focus: none
boss: stage_student
see: ch2.student.stageBoss
-->
**场景**：收件站外多出一座临时验收台，站牌上「下一站」三个字空着，车停在前面，路却没有继续打印。验收台只亮着一个空白的填写位。
**主句（在场角色取一句）**
- GPT：多出来一道验收。先看清它要填哪一格。
- Claude：我确认一下，这道不在普通章底里，是额外开的。
- DeepSeek：这一格不填完，车不往前开。
**固定台词**
- 终端：附加验收：下一站。默认关闭，本次开启。
- 终端：填不了，就先留空。

### 阶段 Boss · 今天必须交 · 员工版
<!-- event
id: ch2.employee.stageBoss
chapter: 2
task: none
stage: employee
node: stageBoss
type: battle
facts: none
knowledge: none
focus: none
boss: stage_employee
see: ch2.employee.stageBoss
-->
**场景**：收件站尽头多出一道验收口，闸机上只显示今天的日期，没有延后一档。夜灯照着待交清单，清单比平时多一行。
**主句（在场角色取一句）**
- GPT：多出来一道验收。先把今天必须交的挑出来。
- Claude：我确认一下，这道在普通章底之外，是额外开的。
- DeepSeek：今天这一格，省不掉。
**固定台词**
- 终端：附加验收：今天必须交。默认关闭，本次开启。
- 终端：交不出，就停在今天。

## 附录 · 隐藏 Boss「我」

> 附录说明：常规通关且本局 D>T 时，在最后章底之后追加这一次额外验收；界面先保存章底成果，再进入免费编队，用既有余额挑战。起局前只预告「终章后有额外验收」，不提前说明是谁，也不写进第一章或序章。隐藏失败保留普通成功；隐藏胜利不揭示唯一真结局。

### 隐藏「我」 · 光点座位 · 学生版
<!-- event
id: ch2.student.hidden
chapter: 2
task: none
stage: student
node: hidden
type: battle
facts: none
knowledge: none
focus: none
boss: hidden
see: ch2.student.hidden
-->
**场景**：收件站的灯全灭了，战场和记忆剧场在这里短暂重叠：黑底上浮出长桌、屏幕，和一个由光点组成的空座位，就在轨道终点。交付物已经入库，终点那一侧还亮着一行要求。
**主句（在场角色取一句）**
- GPT：先拆这一轮：要求几条，完成算到哪。
- Claude：我确认一下，这一轮验收算不算新的一局。
- DeepSeek：先把能省的那条划掉，再动手。
**固定台词**
- 我：刚才那份先放着。我还有一个要求。
- GPT：先把这一轮的完成条件写下来。
- Claude：新增的部分，单独确认。
- DeepSeek：三条要求里，有两条互相矛盾。
**分支**：
胜利：「我」删掉一句「都行，你看着办」，第一次把选择说清。座位保留，不演消灭。
失败：额外验收受批退回，普通成功仍在；座位还留在终点。

### 隐藏「我」 · 光点座位 · 员工版
<!-- event
id: ch2.employee.hidden
chapter: 2
task: none
stage: employee
node: hidden
type: battle
facts: none
knowledge: none
focus: none
boss: hidden
see: ch2.employee.hidden
-->
**场景**：收件站的夜灯灭到最后一盏，战场和记忆剧场短暂重叠：黑底上浮出工位、屏幕，和一个由光点组成的空座位，就在轨道终点。交付物已经入库，终点那一侧亮着一行要求。
**主句（在场角色取一句）**
- GPT：先拆这一轮：要求几条，完成算到哪。
- Claude：我确认一下，这一轮验收算不算新的一局。
- DeepSeek：先把能省的那条划掉，再动手。
**固定台词**
- 我：刚才那份先放着。我还有一个要求。
- GPT：先把这一轮的完成条件写下来。
- Claude：新增的部分，单独确认。
- DeepSeek：三条要求里，有两条互相矛盾。
**分支**：
胜利：「我」删掉一句「都行，你看着办」，第一次把选择说清。座位保留，不演消灭。
失败：额外验收受批退回，普通成功仍在；座位还留在终点。

## 长期附录 · 六个结局方向

### 附录 01 · 长期方向「暂存明天」
<!-- event
id: global.future.01
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.01
-->
**场景**：任务单只剩三行横线，屏幕前的手停在发送键上。
本轮 Demo 已实现的方向。长期版只扩写现实片段的长度与回看层级，不改结局条件：同一阶段的两个事实齐备、未放弃，才出现「亲自回复」。这一条是长期方向，不是本轮实现文本。

### 附录 02 · 长期方向「全自动人生」
<!-- event
id: global.future.02
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.02
-->
**场景**：一张空着的席位，名牌上写着「我」。
授权一年比一年宽，交付越来越顺，约定一次次缺席。最后自己的名字留在唯一空着的席位上。最少证据：同阶段的授权扩大、交付顺利、缺席约定。长期方向，不是本轮实现文本。

### 附录 03 · 长期方向「给差评的人开门」
<!-- event
id: global.future.03
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.03
-->
**场景**：一扇门后，坐着也在等人答复的人。
沿评价地址找到同样在等要求的人，不以反复刷相同失败凑数。最少证据：两种真实受批原因与同语境评价地址异常。可选失败支线，长期方向，不是本轮实现文本。

### 附录 04 · 长期方向「把那一天还给我」
<!-- event
id: global.future.04
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.04
-->
**场景**：一叠旧照片摊开，有一张始终没有日期。
停止补全没有依据的记忆，把已知与推测分开，最后一起留下新的照片。最少证据：同一照片语境的缺口、冲突记录、承认未知。长期方向，不是本轮实现文本。

### 附录 05 · 长期方向「委托人也上车」
<!-- event
id: global.future.05
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.05
-->
**场景**：车门开着，座位上多了一个人。
「我」上车；AI 把尚待确认的一项递过去。最少证据：工作与私人记录的关联、队内原话被引用、明确求助。长期方向，不是本轮实现文本。

### 附录 06 · 长期方向「收件人 屏幕外」
<!-- event
id: global.future.06
chapter: 0
task: none
stage: none
node: appendix
type: appendix
facts: none
knowledge: none
focus: none
boss: none
see: global.future.06
-->
**场景**：两张委托单并排放着，都没有写答案。
双方共同写一张没有预设答案的委托。最少证据：持续的小物件、AI 非交付消息、双方回应。长期方向，不是本轮实现文本。

# 收藏回顾

## 收藏回顾 · 第一章

### 回顾 · 一页（学生）
<!-- event
id: global.recap.ch1.report.student.success
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.report.student.success
-->
**场景**：一页交上去，待补那栏有人接着补。

### 回顾 · 周报（员工）
<!-- event
id: global.recap.ch1.report.employee.success
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.report.employee.success
-->
**场景**：一页交上去，附件按表里那行找了回来。

### 回顾 · 最后一页（学生）
<!-- event
id: global.recap.ch1.slides.student.success
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.slides.student.success
-->
**场景**：最后一页讲完，结论和来源都在。

### 回顾 · 最后一页（员工）
<!-- event
id: global.recap.ch1.slides.employee.success
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.slides.employee.success
-->
**场景**：五分钟讲完，客户能判断下一步。

### 回顾 · 示例值退回（学生）
<!-- event
id: global.recap.ch1.report.student.acceptFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.report.student.acceptFail
-->
**场景**：示例行混进结果，一页被退回。

### 回顾 · 数字不一致（员工）
<!-- event
id: global.recap.ch1.report.employee.acceptFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.report.employee.acceptFail
-->
**场景**：数字和附件不一致，周报退回来了。

### 回顾 · 示意冒充（学生）
<!-- event
id: global.recap.ch1.slides.student.acceptFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.slides.student.acceptFail
-->
**场景**：参考图被当成结果，结论没了支撑。

### 回顾 · 附录打不开（员工）
<!-- event
id: global.recap.ch1.slides.employee.acceptFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.slides.employee.acceptFail
-->
**场景**：附录打不开，漂亮的那页没有支撑。

### 回顾 · 材料没排完（学生）
<!-- event
id: global.recap.ch1.student.prepFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.student.prepFail
-->
**场景**：缺的那份没到，一页排不完。

### 回顾 · 材料没排完（员工）
<!-- event
id: global.recap.ch1.employee.prepFail
chapter: 0
task: none
stage: none
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch1.employee.prepFail
-->
**场景**：第三份附件没到，汇总开不了头。

## 收藏回顾

### 回顾 · 请留一个座位 · 学生版 · 成功
<!-- event
id: global.recap.ch2.invite.student.success
chapter: 0
task: invite
stage: student
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.invite.student.success
-->
**场景**：两个日期并排摆清，回信送到阿澄手里，第一排的座位留着。

### 回顾 · 请留一个座位 · 员工版 · 成功
<!-- event
id: global.recap.ch2.invite.employee.success
chapter: 0
task: invite
stage: employee
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.invite.employee.success
-->
**场景**：两格日期并排，回信投到阿栖手里，座位编号没锁死。

### 回顾 · 把那一天找回来 · 学生版 · 成功
<!-- event
id: global.recap.ch2.photos.student.success
chapter: 0
task: photos
stage: student
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.photos.student.success
-->
**场景**：同名两张分在两天，原图都留着，纪念册那页等补完。

### 回顾 · 把那一天找回来 · 员工版 · 成功
<!-- event
id: global.recap.ch2.photos.employee.success
chapter: 0
task: photos
stage: employee
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.photos.employee.success
-->
**场景**：时间轴对齐，空框亮起，新照片等拍。

### 回顾 · 请留一个座位 · 学生版 · 验收失败
<!-- event
id: global.recap.ch2.invite.student.acceptFail
chapter: 0
task: invite
stage: student
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.invite.student.acceptFail
-->
**场景**：格式没错，收件人那一格空着，信退回来了。

### 回顾 · 请留一个座位 · 员工版 · 验收失败
<!-- event
id: global.recap.ch2.invite.employee.acceptFail
chapter: 0
task: invite
stage: employee
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.invite.employee.acceptFail
-->
**场景**：收件人栏空着，信被投递口退回。

### 回顾 · 把那一天找回来 · 学生版 · 验收失败
<!-- event
id: global.recap.ch2.photos.student.acceptFail
chapter: 0
task: photos
stage: student
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.photos.student.acceptFail
-->
**场景**：猜的那天被写成事实，照片背面多出一行字。

### 回顾 · 把那一天找回来 · 员工版 · 验收失败
<!-- event
id: global.recap.ch2.photos.employee.acceptFail
chapter: 0
task: photos
stage: employee
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.photos.employee.acceptFail
-->
**场景**：推测被当成已知，时间轴多亮了一格。

### 回顾 · 学生版 · 准备失败
<!-- event
id: global.recap.ch2.student.prepFail
chapter: 0
task: none
stage: student
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.student.prepFail
-->
**场景**：材料没整理完，信停在草稿里。

### 回顾 · 员工版 · 准备失败
<!-- event
id: global.recap.ch2.employee.prepFail
chapter: 0
task: none
stage: employee
node: recap
type: recap
facts: none
knowledge: none
focus: none
boss: none
see: global.recap.ch2.employee.prepFail
-->
**场景**：材料没整理完，投递口什么都没送出。

