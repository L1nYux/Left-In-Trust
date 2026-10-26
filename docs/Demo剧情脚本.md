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
**演出**：标题画面。终端车停在近景，车灯只照亮前沿几寸墨迹未干的路面。更远处是纸页折叠出的山峦、光点与晨雾。标题《未尽之托》如同一张尚未打印完整的委托单，「未尽」留着一道清晰的断口，「托」字则浸润在一抹沉静的暖光里。
**场景**：车内三张座椅空着。终端屏幕静静亮起两张人生卡：一张压着微温的课表、台灯与社团活动室窗边留空的椅子；另一张贴着深夜工位的冷荧光、折角的周报与一张调动前的便签。
**固定台词**
- 终端：任务已生成。选择人生阶段。
- 旁白：大学生：课表压着终期展示。社团有人毕业。
- 旁白：公司员工：周报压着提案。老友项目结束就走。
- 终端：已选。选择首位 AI。
**主句（在场角色取一句）**
- GPT：我是 GPT。别担心，路还没铺完，但骨架我先立稳。
- Claude：我是 Claude。手边的每一份纸页，我都会替你轻声理平。
- DeepSeek：我是 DeepSeek。路短一点，废话少一点，饭我备好了。
**固定台词**
- 终端：第一章任务单打印中。
- 终端：终章之后，另有一次额外验收。
- 终端：目标：把本周做成一页。
- 终端：已知材料：三件，缺一件。
- 终端：验收重点：三条。
**重复局**：重看开篇，标题断口微光一闪，吐纸声再次响起。

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
**场景**：行旅车碾过微温的墨迹，纸层在车轮下叠成起伏的缓坡。远方浮着一枚半透明的地标，白得像未书一字的素页。课桌纹理在日光下斜斜漫开，便签被晨风掀起一角又悄然贴合。终端轻声吐出一张薄单：把本周做成一页；材料三件；验收重点三条。
**主句（在场角色取一句）**
- GPT：单子到了。先搭骨架，缺项我们留给路上去找。
- Claude：我核了一下纸页张数——单上列了三件，吐纸口只应声吐了两次。
- DeepSeek：限定一页。把废话删干净，但别删路标。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：别停下等，空着的那一栏我用虚线框住。
- Claude：第三份的留白处，我折了个角做记号。
- DeepSeek：缺一件也撞不翻车，先往前开。
**重复局**：这段路昨日驶过，新吐出的委托单尚带墨香。

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
**场景**：材料悬浮窗静静展开三格：小组群聊天记录、数据表 A 截图、数据表 B 导出。第三格边缘泛着虚线微光，空悬无物。出纸口边贴着淡黄便签，铅笔字迹很浅：“就一页”。
**主句（在场角色取一句）**
- GPT：三块拼图缺了一角。先把已有的两份归位，把空缺锁在原地。
- Claude：截图对上了，表格也对上了，唯独那份支撑附件没见踪影。
- DeepSeek：聊天记录里写着「附件见附件」。套娃不顶饱，缺的标红。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：这阶段先定为「搜寻第一份附件」，目标清晰。
- Claude：截图只能证明曾经发过，算不得正式附件。
- DeepSeek：套娃省不了事，把漏项挂在车头醒目处。

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
**场景**：纸页公路在一段断桥前悬停。桥心的缺口正是一个空白的文件框，框边还垂着断裂的代码线条。课桌木纹如断崖般逼近，手写便签在断口两侧剧烈抖动。阴影从虚线空框中凝聚成型，身形比框格庞大一圈。
**主句（在场角色取一句）**
- GPT：把缺口当作临时路标。我们可以绕行，但绝不能假装它是平地。
- Claude：我用红笔钉住边缘。少的那页，正式归入待补清单。
- DeepSeek：挑短路走。空出来的一大截，闭上眼可不会自动长好。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把断桥拆成双段支撑，修补一处是一处。
- Claude：我核对过了，这处空缺货真价实，绝非幻影。
- DeepSeek：缺掉的页留着位置，回头找齐了再填。
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
**场景**：两张统计表在半空错落浮动。左侧赫然是 42%，右侧却赫然是 47%，相差整整五个百分点。B 表极细的页脚处隐现一行灰色微雕字样：「示例数据，勿引用」。打印机又吐出一张，正是那份示例原型。Claude 手中的铅笔在“数值一致”一栏停顿不前。
**主句（在场角色取一句）**
- GPT：把那 5% 的落差圈红。查不出出处，绝不能贸然盖章。
- Claude：好险……我险些只核算了汇总栏。差额没说清，不算过关。
- DeepSeek：页脚那行灰色小字写着「示例，勿引」。来源不能省。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将这行标明为注释，绝不让它混入结论。
- Claude：我把它挪进备忘留白处，版面依然能保住一页。
- DeepSeek：示例归示例，结果归结果，分开放才省心。
**重复局**：昨日核过旧稿，今日第一眼便先看页脚。

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
**场景**：公路盘旋成莫比乌斯环般的陡坡，一层层叠压向上。同一行手写统计数字在盘山道上接连出现三次，每一次都精准落回同一块泛黄便签。山风把便签吹得呼啦作响，像有人在神经质地反复誊抄。
**主句（在场角色取一句）**
- GPT：同样的内容出现了三回。剔除冗余，车身才能轻装爬坡。
- Claude：我逐字对齐了字符。确认哪两行是影子，哪一行是本体。
- DeepSeek：复读的删掉。删掉之前，留好出处那一笔。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按原始来源合并同类项，小心别误伤旁支。
- Claude：底稿我留存了一份复本，随时备查。
- DeepSeek：甩掉这堆重复包袱，一页纸还能更紧凑。
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
**场景**：单页纸卷在车前灯的暖束里平展如镜，毛糙的边缘被风轻轻压平。任务单翻转到背面，三道验收标准并列如刀刻：数字来源严丝合缝、缺损项如实呈报、版面严守单页。待补清单只余末尾单行：负责数据那位组员的贡献陈述。
**主句（在场角色取一句）**
- GPT：三项对照一遍：数据溯源、留白批注、单页规约。全在位。
- Claude：待补清单只剩下组员陈述这一行。空置处已盖上合规戳记。
- DeepSeek：一页结案。不仅纸短，连文件名都利索。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：逐条确认无误，直接封卷，不留无谓的草稿二版。
- Claude：未完事项标作「待补」是坦荡，不是隐瞒。
- DeepSeek：页脚那行来源虽小，留在那里就是底气。

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
**场景**：纸页旷野的尽头，一座薄如蝉翼却庞大如城关的装置霍然隆起。它由无数折叠的封皮构成，在空中反复对折、重压落章、随后凌厉展开。其正面严整镂刻着三道验收法则。课桌木纹与散乱便签在基底沉浮，日光将纸缘映得刺目发白。
**主句（在场角色取一句）**
- GPT：直面验收大门。三条标尺一条一条过，步履扎实才能通关。
- Claude：空出的那一格还在。坦然承认空缺，也是交付的一部分。
- DeepSeek：砍掉虚胖的页数，留住硬骨头。只凭这一页通关。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按次序展开证明，别在终点线前乱了阵脚。
- Claude：我先把附件清单递上去，再亮出主页面。
- DeepSeek：这一页推过去，白纸黑字，挑不出刺。
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
**演出**：黑底。微弱的光点先勾勒出一张逼仄的书桌，凉透的便当盒未曾揭开。手机在桌角悄然亮起，阿澄的消息长久停在「这周六？」，输入框空无一字。光点试图凝聚成回复，闪烁两下终究散开。桌角压着那张刚刚完成的单页纸，页脚标着「待补」。
**旁白**：屏幕亮了一下，又暗下去。
**收束（按在队角色一句）**
- GPT：组员已经循着待补栏填补了内容。各自的责任已然分明。
- Claude：清单上的未竟之项划去了一笔。文件夹可以安稳合上了。
- DeepSeek：按时交了。饭菜温热正好，没误了胃口。

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
**演出**：黑底。光点浮现出一张凌乱的书桌，两份摊开的材料旁边是一个无法闭合的虚框。窗外日光斜斜照在空框上，却找不到可以填入的内容。光点试图勾勒出一整页纸，却在缺口边缘骤然中断。
**旁白**：缺的那份没来。一页空着。
**收束（按在队角色一句）**
- GPT：缺了一环支撑，整个结构便无法合拢立起。
- Claude：反复核算过三次，第三份附件确实没到。
- DeepSeek：缺了就是缺了，先别把空气当饭吃。

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
**演出**：黑底。光点汇聚成一张规整完好的一页纸，四角平展。页脚那行被忽视的“示例”小字忽然如沙粒般崩解，红色的校对框卡在一个数字上剧烈震颤。整张纸依然通明，唯独核心结论处塌陷成一个深洞。
**旁白**：示例混进结果。这页退回。
**收束（按在队角色一句）**
- GPT：来源与数据相互脱节，它便不能被称为最终结果。
- Claude：是我查漏了……问题出在页脚那行未经替换的示例。
- DeepSeek：更正说明我来列，把实打实的来源一条条补回去。
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
**场景**：行旅车重新启动，车轴低鸣。前方的公路只打印出下一个弯道，弯道彼端是一片混沌的微光。用毕的委托单化作一行细墨，退居控制台边缘，其背面悄然浮现出一行小字：下一站，可再迎一位同行者。旷野的白光渐次退向窗后。
**主句（在场角色取一句）**
- GPT：首站交付告成。后排的位置空出来了，下一程风景更宽。
- Claude：文书合拢归档。风里已经隐约有了下一份信函的气味。
- DeepSeek：油料足够跑到下一站。别愣着，先吃几口热饭。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：留出的空位，正等待新伙伴的笔记来填满。
- Claude：到了下一站台，我再对照名单迎接新人。
- DeepSeek：碗底还热乎着呢，吃饱了才有精神赶夜路。
**重复局**：每一轮章末皆如老友辞行，路常在，唯纸单常新。

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
**场景**：公路蓦然拐进一处陡峭的纵向峡谷。两侧岩壁犹如层叠的幻灯片幕布，图表光束在云层中交织闪烁。便签贴在幕布侧沿，木纹隐隐透出纸面。任务单简练得如同催促：五分钟终期答辩；尾页必须落定结论与出处；材料为两件草案与一条留言。
**主句（在场角色取一句）**
- GPT：先把表盘对准五分钟。一页只打一个点，时间才咬得死。
- Claude：我记住了重点：最后一页必须同时立住结论与来源。
- DeepSeek：材料统共三份：别人的参考、我们跑出的数、还有那句催促。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：框架扎稳，五分钟内把该说的全交代清楚。
- Claude：我把参考构想和实测结果用双色笔划开。
- DeepSeek：花哨转场删掉，但尾页的出处一个字不准漏。
**重复局**：幕布依然高耸入云，讲稿泛着洁净的冷光。

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
**场景**：三块光幕并列悬浮：一张盖着“参考方案”水印的示意图、一份仅有 12 例样本的小规模测算、以及一条组长留言：“要简练，但别把细节删光了。”便签上的“限时五分钟”格外刺眼。
**主句（在场角色取一句）**
- GPT：把参考图、实测值、组长要求分为三个区域，互不侵扰。
- Claude：图上的“参考”水印不可裁剪。它是分界的防线。
- DeepSeek：限时五分钟。第一刀先砍掉那些毫无意义的开场废话。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：先把时钟锁在三百分秒，再往格子里填内容。
- Claude：实测数据与构想示意，我标在两个不同的栏位。
- DeepSeek：能省的修饰尽管省，省下的时间足够从容答辩。

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
**场景**：峡谷上空悬着密密匝匝的缩略图，层层叠压。右下角的发光计时器残忍地停在 7:00 超时位置。原本的示意图被抽空了图注，来源行不知所踪。草稿页脚挂着一个“自动切页”按钮，一旦触发便会连跳两页。
**主句（在场角色取一句）**
- GPT：将繁杂论证全部移入附录。主干一页一问，五分钟才能落地。
- Claude：我逐页排查过了，只要主干能顺利勾连附录，逻辑便不会散。
- DeepSeek：刚才图注是我顺手删掉的。删过了头，现在原样贴回。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：附录做底座，前台只留最具穿透力的核心断言。
- Claude：每一个主要判断的右下角，我都加上了附录跳转标号。
- DeepSeek：图注归位。不拿别人的构想冒充咱们自己的战果。
**重复局**：上一版超时两分钟的红光仿佛还在眼前，这回紧盯秒针。

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
**场景**：纷乱的幕布骤然收拢，任务单翻至终极判定页：全篇能按时讲毕、所有支撑皆可追溯、示意绝不伪称实测。发光秒表精准定格在 5:00 整。尾页清清楚楚落着结论与出处，那枚小小的“参考”字样端然在列。
**主句（在场角色取一句）**
- GPT：三项指标全绿：时间可控、出处可考、界限分明。
- Claude：最后一页我核准完毕，核心结论与引据文献并驾齐驱。
- DeepSeek：自动切页的陷阱拆掉了，这五分钟走得稳当踏实。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：五分钟一响立刻收拢，不再画蛇添足加页。
- Claude：附录的索引编码已经整整齐齐贴在最后一页的底栏。
- DeepSeek：留好最后半行的来源，这页讲稿便无可撼动。

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
**演出**：黑底。光点浮现出活动室长桌的一角，打印出的讲稿最后一页平铺在桌面上。手机在边缘泛起白光，阿澄的消息依旧是那句「这周六？」，输入框一片空白。光点微颤着试图敲击按键，屏幕却率先无声暗去。
**旁白**：汇报准时结束。屏幕暗了。
**收束（按在队角色一句）**
- GPT：组员凭借附录从容招架了提问。这一份心血没有虚耗。
- Claude：结论与来源皆安然落座。这份清单终于可以系上丝带。
- DeepSeek：分秒不差，准时收工。事情办妥了，心放回肚子里。

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
**演出**：黑底。光点在虚空中立起一面投影幕布，尾页虽然华丽，但在评委投射的光束下，“参考”二字被白块掩盖，来源行更是一片空荒。光点在空缺处滞留颤动，幕布的一角在指责声中悄然卷曲剥落。
**旁白**：参考被当结论。没有依据。
**收束（按在队角色一句）**
- GPT：示意图被误认成了实验结果，整个结论失去了落脚点。
- Claude：我疏忽了……末尾的引注栏空空如也，没能拦住误解。
- DeepSeek：把原作者和参考标签重新挂上，这套幻灯片还有救。
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
**场景**：纸页旷野边缘的长椅，木纹被日光晒得泛白。自动贩卖机在树荫下泛着清冷的荧光，长椅脚边搁着一份扎好棉绳、微温的便当。
**主句（在场角色取一句）**
- GPT：长椅还有空位。先坐下来歇口气，下一步不会跑掉。
- Claude：风把纸张吹散了一角。便当先趁热吃，清单我压在手肘下。
- DeepSeek：路长着呢，先吃。胃空着，算力也跑不快。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：热便当的时间，足够我把下一段路标出两个缓坡。
- Claude：趁你喝水，我把方才重复抄写的那一条轻轻抹平。
- DeepSeek：贩卖机最底下一排还有冷绿茶，我去拧开一瓶。
**重复局**：长椅依旧微温，树影比昨日斜了一寸。

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
**场景**：纸页旷野边的补给木窗，挂着一块手写的小木牌。铜天平两侧落着碎纸屑，不称斤两，只量算力刻度。
**主句（在场角色取一句）**
- GPT：盘点一下结余。换两样必需品，剩下的算力留着应付长坡。
- Claude：价目牌的角卷起来了。我再看一眼，确认没有看错行。
- DeepSeek：来两罐热汤就行。花哨的打包袋不用拿，占地方。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：就按标明的换，多给的试用品别往背包里塞。
- Claude：找零的铜角我包进草稿纸里了，一枚也没少。
- DeepSeek：柜台老板算盘打得快，我替你盯着刻度。
**重复局**：木天平稳稳停在中央，风把木牌吹得轻轻摇晃。

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
**场景**：出纸槽里卡住了半截纸页，齿轮发出轻微的咔嗒声，隐约露出一行尚未印完的字：“课程进展与……”。
**主句（在场角色取一句）**
- GPT：别硬拽。纸张受力会撕裂，我们顺着滚轴的方向慢慢退。
- Claude：截面上还有半行未干的批注，等墨迹稍干再动它。
- DeepSeek：别慌，轻轻抽出来就行。真断了，重打也费不了两秒。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我顺手清理一下进纸夹缝，避免下一次再卡进字缝里。
- Claude：卡纸上的日期戳我记下来了，不会漏掉版次。
- DeepSeek：纸抽出来了。省下的闲工夫，够看一会儿天上的云。
**重复局**：出纸缝擦得很干净，那半截残纸夹在旧书页里当了书签。

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
**场景**：第一张单子验收完，车停在旧校门外的站台下。车门轻声敞开，空位的前挡板上放着一张字迹工整的短笺，旁边是一支未套笔帽的铅笔。
**固定台词**
- 终端：本次交付完成。下一站，收件站。
**主句（在场角色取一句）**
- GPT：来吧。前排视野很好，我把后半程的路线图给你摊开。
- Claude：欢迎上车。窗边的清单夹我腾出了半格，正适合放你的笔。
- DeepSeek：上车吧。后座留着一件薄外套，饿了后备箱还有饼干。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：系好安全带，接下来的坡度我重新校准过了。
- Claude：桌上的短笺我读过了，只有两行，字很诚恳。
- DeepSeek：车门带上。坐稳了，出发。
**分支**
- 跳过招募：车没有停下，留白也是一种节奏，力量留给下一程。
**重复局**：铅笔静静横在木纹上，车窗外的秋叶落了一片。

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
**场景**：公路平移切入一片规整冷峻的数据网格。梯田般的条目在车窗旁无声倒退，批注小红旗在夜风中簌簌作响。玻璃隔断的青灰倒影从纸面掠过，工位夜灯提前洒下一抹惨白。任务单上只有三行：把本周提炼为一页；材料三件；验收重点三条。
**主句（在场角色取一句）**
- GPT：单子来了。先理清责任边界与主次，把框架扎在这一页内。
- Claude：三份待审材料，第三份的链接依然是失效的灰色。
- DeepSeek：目标是一页。数据可以凝练，但出处这一行绝不能删。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：先稳住主体，空缺的一环我们单开追踪标签。
- Claude：缺失的编号我记在本上了，一会儿顺藤摸瓜去找。
- DeepSeek：缺一环也别在原地打转，车轮滚起来，边走边理。
**重复局**：深夜的格子间公路，每一步都踏在熟悉的键盘敲击声里。

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
**场景**：三扇浮动视窗排列开来：大群聊天截屏、经营表 A 截图、财务表 B 导出。第三个视窗闪烁着无底的空黑，标签贴纸斜斜粘在窗边，圆珠笔狠狠划出：“周报一页”。
**主句（在场角色取一句）**
- GPT：三块材料少了一角支撑。先把手头两份核定，留好待查位置。
- Claude：聊天截图与标签都对得上，偏偏最关键的数据附件没挂载上。
- DeepSeek：截图里又附了一张截图。这种套娃不能当证据，缺口标红。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：这一段首要任务就是“把真正的数据附件掘出来”。
- Claude：截屏只能证明发过消息，充当不了原始审计凭证。
- DeepSeek：推诿责任的文件最占地方，把缺项悬在仪表盘前。

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
**场景**：数据桥梁在半途坍塌，横亘在眼前的是一个巨大的空置附件图标，断茬处连着撕扯不均的胶带。玻璃幕墙的冷光扫过空洞，敌人从无底的深坑中缓缓浮升，轮廓狰狞得像是催命的已读未回提示。
**主句（在场角色取一句）**
- GPT：钉住这个断点。即便必须绕道，也绝不能自欺欺人假装路通。
- Claude：我标出了坐标。缺失的这一项，写明在待协同附录中。
- DeepSeek：走最近的路绕开它。但眼前这个坑，得清清楚楚写进日志。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把断口两端做成临时衔接，走一步夯实一步。
- Claude：我核准了三遍，这个附件框里确实空空荡荡。
- DeepSeek：空位留着，等找回原件再回头填缝。
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
**场景**：两份财务对账单悬在半空。左侧指标写着 42%，右侧汇报赫然是 47%，相隔了整整五个百分点的口径鸿沟。B 表最底端用蝇头小字标注着：「此行系演示模板，请勿直接引用」。Claude 的笔尖在“口径是否一致”这一行停驻已久。
**主句（在场角色取一句）**
- GPT：把这 5% 悬殊的源头抓出来。说不清口径差异，周报交上去就是祸端。
- Claude：差点踩了坑……光对齐总计毫无意义。分母不同，必须拆开注明。
- DeepSeek：页脚写着「演示模板」。有人把测试数据直接当业绩填了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将这行数据划入特殊注解区，绝不让它污染正式指标。
- Claude：我把它归入待澄清栏，版面依然能牢牢控制在单页内。
- DeepSeek：测试垃圾单独归拢，一页纸干净了，人也少挨两句骂。
**重复局**：昨夜吃过的亏，今日只需一眼扫向对账单的注释行。

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
**场景**：公路盘旋成一段冗长窒息的回形立交，一圈圈循环往复。同一项工作进展在坡道上换了三个马甲出现三次，每一次都沉重地砸回同一张便签上。夜光照在反光的工牌上，玻璃隔断里映满层层叠叠的虚耗剪影。
**主句（在场角色取一句）**
- GPT：同一项琐事被不同部门认领了三遍。合并同类项，让数据归位。
- Claude：我逐字对齐了事实描述，找出哪些只是换了说辞的影子。
- DeepSeek：重复邀功的直接删。删掉之前，留个括号写清原始出处。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按产出源头合并条目，不给任何人无谓扯皮的借口。
- Claude：我把合并记录归档在底册，随时准备接受交叉对质。
- DeepSeek：剔除这些掺水的杂项，周报顿时精简有力。
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
**场景**：一页轻薄而齐整的周报在台灯的光斑中舒展开来。验收单明晃晃列着三条军令状：数字有源可循、盲点开诚布公、篇幅坚守单页。待补附录只留末尾一行：隔壁组老陈负责的那项外部数据交接。
**主句（在场角色取一句）**
- GPT：三项指标全数过关：证据链闭合、遗漏公开、单页封顶。
- Claude：待核对事项仅留老陈那份交接。已注明进度，无可指摘。
- DeepSeek：一页干干净净。连附件名称都缩到最短，省时省力。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：验收合格即刻呈报，不让任何无意义的二轮修改拖慢步伐。
- Claude：将未竟项如实标作「待协同步调」，是职业边界，而非过失。
- DeepSeek：出处那半行保留得扎实，谁来挑刺都得按规矩认。

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
**场景**：纸页旷野的尽头，一座金属质感极强的闸机拔地而起。它如同一尊冷酷的公文审判机，不断折叠、下压钢印、再冷硬地展开。闸机正面刻着三行冰冷的验收铁律。工位便签被狂风压在机器底座，玻璃隔断倒映出夜班水银灯的幽光。
**主句（在场角色取一句）**
- GPT：正面迎战本次交付。用无懈可击的三条事实逐一破开它的防线。
- Claude：待补栏上的留白已盖上严谨公章，合规合法，问心无愧。
- DeepSeek：砍掉浮夸的套话，留足硬核数据。这一页，硬碰硬交出去。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：稳扎稳打递交佐证，别让琐碎的反诘打乱节奏。
- Claude：我先把对账清单递过去，再平铺主周报。
- DeepSeek：这一张纸拍在桌面上，有理有据，他退不回来。
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
**演出**：黑底。微弱的光点在虚空中拼出一张杂乱的工位，键盘边的外卖盒早已冷透。手机屏幕忽明忽暗，阿栖的对话框停留在那句「别再等忙完」，回复框里空空荡荡。屏幕右下角突然弹出一枚新的工作批注，瞬间遮盖了聊天软件。桌角压着那张刚刚通过的一页周报，页脚清晰地标着「待补」。
**旁白**：消息没有回。批注先来了。
**收束（按在队角色一句）**
- GPT：周报里的待补附件已经由老陈认领。下一轮不用再重复扯皮了。
- Claude：界限划清了，清单稳妥闭合。今夜的公事就到这里吧。
- DeepSeek：交差了。饭菜虽凉，好歹能填肚子，赶紧吃两口。

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
**演出**：黑底。光点勾勒出空无一人的办公室，桌面上散乱的两份材料贴着便签，而属于第三份附件的位置只剩下一张发黄的空白双面胶印。孤零零的夜班灯照着隔断玻璃，光点在缺失处彻底暗淡。
**旁白**：第三份空着。没法汇总。
**收束（按在队角色一句）**
- GPT：前端输入断了流，后端无论如何也搭不出合格的汇总。
- Claude：反复确认过了，那份至关重要的附件始终没有传过来。
- DeepSeek：没米下锅就别硬搅和，先别把空头支票当业绩。

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
**演出**：黑底。冷色荧光下，一页排版工整的周报静静铺展。然而页脚那行被忽视的测试用例忽然瓦解成斑驳的噪点，红色的批注框死死锁住一个矛盾的数字。系统退回提示弹出的瞬间，整页公文被无情地贴上“重报”红戳。
**旁白**：数字与附件打架。退回了。
**收束（按在队角色一句）**
- GPT：附件与正文数据相互撕裂，这绝不能被称为正式成果。
- Claude：我的疏忽……出在页脚那行未经替换的示范样本。
- DeepSeek：更正说明我来起草，把真实的测算过程重新摆平。
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
**场景**：行旅车再次平稳加速，写字楼的残影退至车窗边缘。车灯将前方的转弯路面照得雪白，折叠标签整齐收纳在仪表盘下，任务单背面隐现一行清秀的小楷：下一站台，可再添一位共事者。茫茫纸野中，唯有这辆车独自行驶在夜色中。
**主句（在场角色取一句）**
- GPT：这一单周报交割完毕。前排副驾还空着，下一程有人同担。
- Claude：文件归档落锁。下一程的风里，已有了新伙伴的呼吸。
- DeepSeek：里程足够撑到下个换乘站。别紧绷着了，吃口东西垫垫。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：留出的座席，正好容纳一位新的解题者。
- Claude：靠站之后，我先下车帮新伙伴提行李。
- DeepSeek：保温杯里还有半壶温水，趁热润润嗓子。
**重复局**：章末的夜色年年如斯，风吹过车门，唯有单据换了篇章。

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
**场景**：公路急转直下，穿过高耸入云的演示投影幕墙。图表光束如同探照灯般扫过峡谷，便利贴紧扣幕布边缘，隔断玻璃反射出凛冽的银辉。任务单只有冷酷的三行：客户拜访限时五分钟；尾页必须砸穿结论与证据；备选料为两套推演与一句催促。
**主句（在场角色取一句）**
- GPT：把时钟压死在五分钟。一页只打一记重拳，客户没空听铺垫。
- Claude：我盯紧了生死线：最后一页必须立住论点与合规凭据。
- DeepSeek：材料摆在眼前：同行的样板、咱们的数据、还有客户的挑刺。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：骨架拉紧，五分钟之内把该交底的全部亮出。
- Claude：同行的参考构想与咱们的实际产出，我分栏标红。
- DeepSeek：虚头巴脑的动画全部删掉，把结论和依据焊死在尾页。
**重复局**：巨大的幕墙昨日亦立于此，玻璃倒影里依然是未睡的眼眸。

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
**场景**：三组数据悬在半空：一份标有“行业推测”的示意曲线、一份仅覆盖 12 家客户的小范围试用反馈、以及客户发来的短讯：“要一目了然，但别把细节阉割了。”
**主句（在场角色取一句）**
- GPT：行业推测、内部实测、客户要求，分为三道防线，各自守位。
- Claude：图表边缘的“参考示意”绝不能隐去，那是法律合规的边界。
- DeepSeek：限时五分钟。第一步先剔除那些假大空的宏观展望。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：先把倒计时调准到三百分秒，再严丝合缝地填装干货。
- Claude：推测值与实测值，我分别打上醒目的双色水印。
- DeepSeek：虚耗时间的废话砍光，给正题留下喘息的余裕。

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
**场景**：幕布上缩略图层叠如山，密不透风。右下角计时器停留在刺目的 7:00 红字上。那张推测图上的出处行被误删得干干净净，试用反馈旁只写着孤零零的“12 例”。“自动切页”开关在页脚不怀好意地闪烁。
**主句（在场角色取一句）**
- GPT：全篇支撑数据全部压入附录。正文一页一结论，五分钟正正好好。
- Claude：只要附录索引精准无误，正文便能以最精炼的姿态面对质疑。
- DeepSeek：图注是我图省事误删的。删重了手，现在立刻给它补齐。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：附录做后盾，台前只陈述最过硬的交付承诺。
- Claude：每个论点右下角，我都注明了附录页码。
- DeepSeek：图注出处原样复位，绝不拿推论充当板上钉钉的实绩。
**重复局**：七分钟超时的刺目红光犹在心头，这一次我们倒数着秒针前行。

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
**场景**：冗余页面全数折叠退隐，验收单展现出极简的英姿：汇报严守时限、每项皆有实据、绝不指鹿为马。秒表停留在神圣的 5:00。最后一页上，结论清晰锐利，出处栏齐整端庄。
**主句（在场角色取一句）**
- GPT：三项指标全线收官：时间达标、附录完备、边界清白。
- Claude：最后一页核验完毕，核心结论与法务引证安若磐石。
- DeepSeek：自动切页的暗桩全部拆除，五分钟稳如泰山。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：时间一到利落收尾，绝不多占用客户一秒钟。
- Claude：附录的索引编码已清清楚楚贴在末页底栏，随查随有。
- DeepSeek：留下那行出处，整个方案就立得住。

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
**演出**：黑底。光点浮现出深夜静谧的半截办公桌。电脑屏幕上最后一页泛着冷白的光芒，结论与附录无一遗漏。手机在桌角亮起，阿栖的消息依然是那句「别再等忙完」，输入框中空空如也。右下角一条新的业务批注悄然覆上，遮住了未尽的私聊。
**旁白**：五分钟讲完。批注盖上来。
**收束（按在队角色一句）**
- GPT：客户据此定下了下一阶段的意向。这一页没白熬。
- Claude：每一处依据皆有据可查。最后一页终于安稳交接。
- DeepSeek：五分钟正好讲透。事情办完了，赶紧收拾走人。

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
**演出**：黑底。巨大的演示屏上尾页设计精湛，结论掷地有声。但当鼠标点击附录超链接时，系统弹出了冰冷的404报错，引文行一片苍白。光点在断裂的链接处剧烈抖动，最终在一片冷寂的沉默中暗去。
**旁白**：附录打不开。支撑断了。
**收束（按在队角色一句）**
- GPT：结论再漂亮，没有附录支撑，整栋大厦瞬间就会塌陷。
- Claude：我的疏忽……引用的数据源挂了死链，未能事先查证。
- DeepSeek：重设链接，把底稿重新挂载上，别让人抓把柄。
**分支**：补一封更正说明，写清来源与附件位置、把参考图注补上，可补 work_value；不授予其他事实。

## 第一章 · 章间站点 · 员工版

### 第一章 · 休息站 · 员工版
<!-- event
id: ch1.employee.rest
chapter: 1
task: none
stage: student
node: rest
type: rest
facts: none
knowledge: none
focus: DeepSeek
boss: none
see: ch1.employee.rest
-->
**场景**：立交桥阴影下的全天便利店，暖柜轻声嗡鸣。站台长椅对着空旷的环路，夜班水银灯在湿漉的纸路上投下一道惨白的清光。
**主句（在场角色取一句）**
- GPT：先把鞋带松开。夜班灯换挡前，我们不谈下一张单子。
- Claude：暖柜深处还有最后两罐热咖啡，纸套边缘没有被压皱。
- DeepSeek：坐下。车顶有水汽，吹冷风容易头疼，先进去吃口热的。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：你喝咖啡的时间，我把报表的折线图顺一遍，省得晃眼。
- Claude：刚才核对过的周报我合上了，待办只剩两个勾。
- DeepSeek：热包子在塑料袋里闷着呢，趁热分一半。
**重复局**：水银灯的电流嗡鸣如旧，暖柜的玻璃上蒙着薄薄的白雾。

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
**场景**：写字楼背阴面的自动贩售机，投币口被无数枚算力磨得光亮如镜。窗外是倒退的灰色隔断，机柜底层亮着清冷的指示灯。
**主句（在场角色取一句）**
- GPT：只换必要的补给。把算力储备留给下半夜的突发验收。
- Claude：出货口的弹簧有点锈。我轻推一下，别让罐子摔变形。
- DeepSeek：投币，拿走，关门。别看那些带赠品的套餐，全是水分。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：开销记在左上角，明细一清二楚，不超预算。
- Claude：收据我折成整齐的长条，塞进侧面的透明夹。
- DeepSeek：罐身很热，暖手正好，别在冷风里吹凉了。
**重复局**：贩售机金属板冰凉，投币口的划痕依旧清晰。

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
**场景**：打印槽里吐出一张泛黄的单据，右下角盖着一个鲜红的“退回”印章，纸角被圆珠笔划拉出几道急躁的横线。
**主句（在场角色取一句）**
- GPT：不用慌。这是别处的退单，我们顺着红章看看哪里踩了雷。
- Claude：红印下压着三行退单意见，我把字句辨认出来，防患未然。
- DeepSeek：别人的废纸也是纸。翻过来，背面还能记两行。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把别人的教训标在路口警示牌上，我们绕开就是。
- Claude：印章边缘渗墨了，我拿吸墨纸垫着，不蹭到手。
- DeepSeek：退单一夹，翻个面，今天的新单子吐出来了。
**重复局**：旧单夹又厚了一分，纸缝里新打印的声音清脆悦耳。

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
**场景**：第一张单子验收完，车停在写字楼外的站台。车厢推拉门敞开，旁边的折叠台面上放着一杯刚泡好的麦茶，水汽在微风中袅袅散开。
**固定台词**
- 终端：本次交付完成。下一站，收件站。
**主句（在场角色取一句）**
- GPT：上车吧。这趟路虽然长，但每个节点我都预留了休息空档。
- Claude：你的座位在靠窗左侧，文件格已经清空，随时可以交接。
- DeepSeek：上车。别一个人在那儿扛着了，后排宽敞，靠着睡会儿。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把随身的行李放稳，我们重新核验接下来的路网。
- Claude：折叠桌上的便签写着两句叮嘱，我替你妥善收好。
- DeepSeek：麦茶趁热喝了，润润嗓子。关门，走。
**分支**
- 跳过招募：继续单车前行，省下交接的周折，步调自成方圆。
**重复局**：麦茶的香气仿佛还在空气中打转，车轮平稳压过铁轨。

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
**场景**：收件站台凌空搭建在苍茫的云海边缘，长木桌般的站台笔直延伸至铁轨深处。一排排原木座椅从第一排跳跃至第三排。两块木质日期牌在微风中同时泛着晨光：一块写着“10/31 周六”，另一块写着“11/1 周日”，顶端共同标着阿澄毕业送别的聚会名目。终端屏幕无声亮起，只吐出三行：目标、已知材料、验收重点。
**主句（在场角色取一句）**
- GPT：回信期限就在眼前。别慌，我们分清轻重缓急，逐一理顺。
- Claude：两块木牌写着同一场欢送会。时间重叠了，我得仔细对照。
- DeepSeek：最值钱的不是排版多考究，是那个一直悬在发送键上的拇指。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把日期、席位与回复意向分列三栏，脉络一目了然。
- Claude：备注里的私信我单独框出，那不是正式的出席承诺。
- DeepSeek：先起草最简短的一句问候，剩下的留给本人定夺。

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
**场景**：任务单平铺在长桌中央。报名表悬浮在木纹之上，出席名单填至第三排，靠窗的座位依然留白。阿澄发来的私聊便条斜压在桌角：「别再等忙完。」回复框横亘在两人名字之间，长久空置。
**主句（在场角色取一句）**
- GPT：材料已呈报三份：聚会公告、签到表、阿澄的叮嘱。回复栏仍待落笔。
- Claude：我核准了源头：那句叮嘱是阿澄的主动挽留，并非本人的既定答复。
- DeepSeek：两个日子分开放。还没定准的事，别急着用胶水粘在一起。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：循序排好材料，把最终的发信权郑重留给末尾。
- Claude：这句私信原样妥存，不充当擅自代答的筹码。
- DeepSeek：回复栏空出一整行，等他自己亲手写下那两个字。

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
**场景**：两块日期牌被粗暴地拼合为一，木纹缝隙里挤出一行模糊的涂改：「11/1（最新，待定）」。席位表随之整排亮起，连空悬的座位也被草率盖上了“已锁定”的印戳。阿澄的那张便条依然被风压在角隅。
**主句（在场角色取一句）**
- GPT：不能盲目按所谓最新版推演。“待定”二字本身就是变数。
- Claude：最新后面加了待定，说明两个日期都还在水里漂着，未曾着陆。
- DeepSeek：图省事把字缩在一起，反倒把真相抹了。拆开，各归各位。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：重新分列两格，给未决的空位留出呼吸的余地。
- Claude：草稿里只拟一句确认信：究竟定在哪天，由他自己去问。
- DeepSeek：撤掉虚假的锁定戳，没定下的席位就让它坦然空着。

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
**场景**：站台大屏上端然亮起三道验收红线：时刻清晰无误；收件人准确指涉；出席意愿由本人敲定。拟好的回信草稿停在发送框前，收件人一栏端正写着阿澄的名字。第一排留着一个空位。屏脚微雕小字：缺收件人先寻收件人，未定日程勿妄言代诺。
**主句（在场角色取一句）**
- GPT：三项条件逐一划勾。在点击之前，我再核对一次收件人的代号。
- Claude：这一封短笺只求证最终时间，绝不自作主张替他应承赴约。
- DeepSeek：收件人写准写实，比堆砌十句客套敬语都管用得多。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：两个候选日子各留一个虚线框，不给现实添乱。
- Claude：阿澄的私聊便签静置一旁，不被篡改为正文内容。
- DeepSeek：把发送按钮留在最显眼处，等那只犹豫的手按下去。

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
**演出**：黑底。空旷的站台唯余一盏昏黄的地灯，长桌深处唯有一张座椅泛着微温的暖光。阿澄的消息悄然浮起：「记得带你那张失败的合照。」光点落至键盘前方，一只年轻的手将繁复的推脱删至极简，平静按下回车。屏幕亮起新的一行：「纪念册还没排完，一起？」
**旁白**：回信寄出去了。那个座位亮着。
**收束（按在队角色一句）**
- GPT：这一次不叫代理交付，叫作本人亲笔回音。
- Claude：清单里郑重添上一笔：长椅上的那个位置留住了。
- DeepSeek：删掉废话的那一记回车按得漂亮，正好够真心落地。

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
**演出**：黑底。精心折叠的书简从站台滑回投信槽，收件人的框线空洞无物。屏幕边缘隐现一行落寞的灰字：「你是不是……已经忘了我？」光点在槽口徘徊不定，终究无法汇聚成前行的通路。
**旁白**：信未寄出。收件人栏空着。
**分支**：补发一次正确回复，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：文法结构毫无破绽，唯独最该被看见的名字遗失了。重写。
- Claude：先填上阿澄的名字，再谈信笺字句的温润。
- DeepSeek：直接问一句“哪天”，比在这儿对着空气揣摩要强百倍。

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
**场景**：收件站台在此处幻化为一道绵长的影像长廊。时间轴化作两道冰冷的枕木沿铁道铺展，四帧泛黄的旧照片在框线上方浮沉。最末端的一处相框依然暗淡空悬。任务单精简如初：按照片背面的手迹理清归宿；材料为四张胶片；验收要点三条。
**主句（在场角色取一句）**
- GPT：任务单只有三行。先按照片背后的亲笔手迹，把日子排清楚。
- Claude：背面的手写原话务必逐字誊录，切不可凭主观臆断擅自更改。
- DeepSeek：四张照片排顺溜，那个空相框留着，别瞎填糊弄过去。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按背面笔迹将相片分置两端，让事实各自就位。
- Claude：誊写时守住原原本本的字迹，绝不添枝加叶。
- DeepSeek：先翻相片背面看笔迹，别光盯着文件名瞎琢磨。

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
**场景**：四帧旧照沿铁轨徐徐漂浮。前两张的系统默认名赫然同为 `IMG_2031`，背面却分别记着「10.12 布展」与「10.19 聚餐」。第三张背面光洁一片，画面里唯有一个推自行车的孤单背影。第四张则是那张有人闭了眼的失败合影，按下快门的那个人不在镜头之内。
**主句（在场角色取一句）**
- GPT：同名不等于同一时刻。四张胶片分属不同日子，各自占位。
- Claude：背面的手书手迹优先存入事实库，原话原样，不作修饰。
- DeepSeek：这两张名字一样，日子可差了整整一周。别按文件名硬并。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将同名的两张照片拉开间距，各自建立专属索引。
- Claude：事实栏内只记亲笔所书的文字，推断结论先空置。
- DeepSeek：铁轨上有两个专属锚点，一照一格，互不抢道。

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
**场景**：事实陈列与推理假设两栏并肩展开。第三张无字背影的备忘处被谁添上了一行「多半是聚餐那天」，时间轴随之违和地被点亮了一格，其上赫然被盖上了一枚“已确凿”的小红章。一旁被过度压缩的缩略图只剩模糊色块，原画位相形见绌。
**主句（在场角色取一句）**
- GPT：分清已知与揣测之后，时间轴空出了三格。空着也是真实的留白。
- Claude：这枚红章是我心急盖下的……对不起，我这就亲手将它抹去。
- DeepSeek：猜测归猜测，轨道上那一格得熄灭回去，别自欺欺人。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：悬空的三格就让它清清白白悬着，绝不拿主观妄想填补。
- Claude：事实栏重抄一遍，只留下照片背面真实存在的那两笔。
- DeepSeek：不知道是哪天就写不知道，回头亲自去问阿澄。

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
**场景**：时间轴上三格字迹分明，唯有一格写着“待询阿澄”，一格坦然留白。压缩的样张被单独置于对照框，原画位纤尘不染。站台显示屏标定着三条准则：事实与推断互不混淆；坚守原始原图；未知之谜交付亲历者。
**主句（在场角色取一句）**
- GPT：三条红线一一守住。没有依据的空白格，我绝不虚填一笔。
- Claude：我再三核对了胶卷原片，四张底片完整妥存，未遭覆写。
- DeepSeek：那一格堂堂正正写“问本人”，比编造一个假日期体面。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把求证清单缩成最利落的一行，单刀直入。
- Claude：询问的措辞保持温和克制，不把先入为主的猜测掺和进去。
- DeepSeek：发信求证，然后安安静静等待那个亲历者的回答。

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
**演出**：黑底。胶片在时间轴上一张张安稳平复，两张同名的照片各自落定在清朗的秋日。阿澄的消息如期而至：「纪念册还没填完，要不要一起？」光点汇聚在键盘前，一只手将那张像素模糊的缩略图放回待查夹，在输入框里轻快地敲下一行字，按下了发送。
**旁白**：留白的一页。等他一起补。
**收束（按在队角色一句）**
- GPT：时间线终于恢复了秩序，留白处写着同伴的名字。
- Claude：底片安然无恙，这本纪念册终于迎来了正确的打开方式。
- DeepSeek：没确定的那一天就这么留着，比瞎编乱造成就感多得多。

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
**演出**：黑底。照片背后原本谨慎的字迹被生硬地烫印在正面，凭空多出一段画蛇添足的解释。模糊的缩略图被草率放大，颗粒粗糙不堪。阿澄的消息缓缓浮现：「其实……问我一声就好啊。」光点在编造的文字上颤抖不前。
**旁白**：推测写成事实。原样退回。
**分支**：补一次正确回复，把推测改回推测、日期去问当事人，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：把凭空捏造的那段附注撤掉，让推测归位于推测。
- Claude：我不会再妄加猜测了，先当面求证，再小心下笔。
- DeepSeek：张口问一句真人，比在这儿修补烂图省下十倍力气。

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
**场景**：收件站台的长排木椅，夕阳将木条染成昏黄。活动室的窗棂投影落在长椅脚下，自动机吐出一盒扎着棉线的点心盒。
**主句（在场角色取一句）**
- GPT：就在这儿歇下吧。第二阶段的任务不赶时间，步子放平。
- Claude：长椅被晚霞晒得很暖。点心盒子我解开绳结，大家分着尝。
- DeepSeek：坐满三分钟再说。跑了一整章，骨头都该吹吹风了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我顺带把第二章的收件人树状图梳理一遍，绝不含糊。
- Claude：点心盒底下压着一张旧社刊，我小心抚平折痕。
- DeepSeek：汽水开罐时别溅出来，我拿纸巾替你接着。
**重复局**：木椅微温，夕阳在地砖上拉出长长的倒影。
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
**场景**：收件站尽头的流动旧货车，车窗上挂着两盏防风马灯。木柜上放着一把旧铜算盘，纸屑卡在珠缝里，拨动时声响沉闷。
**主句（在场角色取一句）**
- GPT：先对一下账面。换一份高能量补给，剩下的留着过桥。
- Claude：算盘最边缘的珠子有磨损。我心算一遍，对照一下差额。
- DeepSeek：挑实惠的拿。那盘炒麦片最扛饿，换它就行。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：不买多余的纪念品，算力用在刀刃上。
- Claude：算盘珠清脆响了三声，数目分毫不差。
- DeepSeek：袋子我拎着，沉甸甸的，踏实。
**重复局**：马灯的火苗轻轻跳动，旧算盘上的灰尘被擦掉了一抹。
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
**场景**：收件站斑驳的喇叭响起广播，报站员把站名的尾音念成了模糊的谐音，候车厅里几只麻雀扑棱棱飞起，撞在生锈的铁丝网上。
**主句（在场角色取一句）**
- GPT：别被念错的广播打乱。我们认准手里的车票和道岔编号。
- Claude：我翻出老时刻表核对了一遍，这站的正确读音其实很平缓。
- DeepSeek：念错就念错了，轨道又没长腿，顺着铁轨走丢不了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把修正后的读音记在路线备忘里，下趟车不再困惑。
- Claude：麻雀落下的羽毛我收在手心，别卡进车窗铰链。
- DeepSeek：风里有雨丝，回车厢里待着吧，别淋着。
**重复局**：喇叭沙沙作响，生锈的站牌在风里微微晃动。
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
**场景**：收件站台的一战。长木桌上两块日期牌同时放光，一块刻着 10/31，另一块刻着 11/1，牌底皆是一片空白无源。午后斜阳与惨白电灯在木纹上投下两条方向相反的狭长阴影。铁轨尽头，一个由互相矛盾的言辞扭结而成的庞然阴影拔地而起。
**主句（在场角色取一句）**
- GPT：先将两套说法剥离：哪一份是最初公告，哪一份是辗转传话。
- Claude：牌底没有任何官方背书。口径冲突之时，绝不可轻举妄动。
- DeepSeek：两边都在嚷嚷，等于根本没人定下日子。先打碎多余的那个。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将两块牌并列呈现，把各自的来龙去脉标在底端。
- Claude：我把两块牌的差异拍照存档，收进对照视窗。
- DeepSeek：先把那句“两边都差不多”的混账话轰掉，再来拆解。
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
**场景**：长木桌几乎被膨胀的单页纸挤爆：席位分布、排期叮嘱、传抄便笺死死挤压在方寸之间，纸角无法遏制地向铁轨外缘疯狂滋长。站台灯被漫延的纸张遮挡，投下层层叠叠的阴翳。页面上一行行新生的冗余文字如同寄生藤蔓般不断疯长。
**主句（在场角色取一句）**
- GPT：篇幅已然失控。先斩断三条反复抄录的废话，重新整理版面。
- Claude：让我先分辨清楚：漫出来的究竟是核心实意，还是空洞的留白。
- DeepSeek：多余的废话能折叠，唯独证明来源的那一行绝对不能动。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：剔除三重重复之后，整张答卷才能干脆利落地缩回单页。
- Claude：超出的赘述我用红框圈定，绝不动摇底层来源。
- DeepSeek：折叠两次就足够塞回去了，别手抖误伤了关键证据。
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
**场景**：收件站台的终极关卡耸立着巍峨的站务终端：成排泛光的信槽、精密的席位格栅、以及从桌头直贯桌尾的时间轴轨道。本次交付物静静压在发射台，最顶端的核心收件人格线空悬闪烁。黄昏褪去，站台防风灯骤然放光。大屏三道铁律：日期确切；收件人属实；本人定夺之后方可成行。
**主句（在场角色取一句）**
- GPT：三步迎战：锁定收件位置、核准日期、静候本人决意。
- Claude：请看空悬的那一格收件栏——没有收件人的信，正是它的死穴。
- DeepSeek：在信笺送出站台之前，时间线上绝不允许存在两个摇摆的答案。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将收件核实、时间锁定、本人决断理成三层台阶。
- Claude：我把那个闪烁的空缺圈在最顶端。
- DeepSeek：信压在手中别发，等本人真正点头的那一瞬。
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
**演出**：黑底。收件站只被虚幻地勾勒出半幅残相：木桌断在半空，一块日期牌亮着，另一块沉在黑暗中，相框尽皆空白。交互视窗卡死在未完状态，信件终究未能离开车厢。
**旁白：**草稿没理完。信还在槽里。
**收束（按在队角色一句）**
- GPT：缺失了最关键的一环凭据，整个逻辑闭环便轰然瓦解。
- Claude：下一程必须先把材料全部对齐，再谈投递信函。
- DeepSeek：先把缺漏问个一清二楚，比盲目动笔要有用得多。

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
**场景**：行旅车缓缓驶离收件站台，站台灯次第沉入黑暗，平整的公路在车前灯下默默向前打印伸展。任务单有史以来第一次呈现纯澈的空白，结算字符如同夜空流星划过：交付完成、长路未尽。终端在车窗玻璃上留下一行温润的光字：「结项完毕。最后一页能否展开，取决于是否还留存着唯有本人才能回应的心事。」
**主句（在场角色取一句）**
- GPT：任务单彻底空出来了。接下来不是新的事务，而是属于你的告别。
- Claude：清单里依然留着最后一项……那是一道必须由你亲手给出的答案。
- DeepSeek：车顺着路开，不绕弯子。把那句该由你亲自说的话留出来。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结算记录已归档妥当，旧日的纠结毋须反复回顾。
- Claude：合拢活页夹前，再凝视一眼那个留空的位置。
- DeepSeek：沿途的灯会熄灭，但属于你的座位一直都在。

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
**场景**：最后一场必要战斗结束，收件站的暖白地灯渐次泛起柔光。任务单上的杂乱批注如潮水般褪去，只留下三道干干净净的横线。
**主句（在场角色取一句）**
- GPT：委托单已全部清空。最后这一道选择，该交还给你自己了。
- Claude：该整理的材料我们都已理平。这一次，轮到你亲自回复他了。
- DeepSeek：代办到此为止。该见的人，必须你自己去见。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：我们把光标留在输入框里，绝不替你按下发送。
- Claude：不用急，慢慢想，字句越简单，心意越真实。
- DeepSeek：去吧。天还没黑透，那家店还开着。
**固定台词**
- 终端：这次需要回复的，不只有文件。
- 终端：两个选项：亲自回复，先保留。
**分支**
- 亲自回复：屏幕微光荡漾，光点在键盘上方凝聚成一只迟疑的手。
- 先保留：表单收进夹层，资格妥善留存，等待下一次由心而发的抉择。
**演出**：黑底。微弱的光点在屏幕前勾勒出一只年轻的手。对话框里的句子敲得很长，又被退格键一下下删短，最终停在一行最朴素的短句上。指尖微顿，轻轻敲下回车。
**旁白**：两份修改被拖进「明日」。手离开键盘。
**固定台词**
- 我：周六下午三点到，带上那张失败的合照。
- 终端：今天到这里。
**收束（按在队角色一句）**
- GPT：明天的首项日程我留空了，那是属于你自己的时间。
- Claude：桌上的文件夹终于可以合上。今晚做个好梦。
- DeepSeek：走吧。这顿饭不用我们操心，去吃热乎的。
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
**场景**：最后一场必要战斗结束，站台的灯光在薄雾中摇曳。任务单被整齐地收进牛皮纸夹，未填的那一行空白在纸页中央显得格外安静。
**主句（在场角色取一句）**
- GPT：这一单勉强算交齐了。但真正重要的那一项，我们还没能找回。
- Claude：清单只能核验到这里了。那些没能问出口的话，先收进怀里吧。
- DeepSeek：能交的交了，交不出的别硬编。回去吧。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：先把车厢收拾好，前方的夜路我们慢慢开。
- Claude：留白的这一行，我用红笔轻轻圈住，留给以后。
- DeepSeek：车门拉上，外头风大，回车里喝杯温水。
**固定台词**
- 终端：本次可交付内容已入库。
- 终端：屏已关闭。
**演出**：收件站台的廊灯一盏盏静默熄灭。车门合拢，前照灯穿透黑夜，公路只静静打印到下一个转角。
**收束（按在队角色一句）**
- GPT：下一次启程时，我一定先为你留出面对的勇气。
- Claude：这份清单我替你贴身收好，缺失的那行字一直在等。
- DeepSeek：走吧，路在脚下。只要车没散架，总能找到答案。
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
**场景**：收件站台换上整排金属信封槽，每格皆烙印着工整的编号。时间轴投信机咔嗒滚出两道深浅不一的插槽：一格写着“11/7 周六”，另一格是“11/8 周日”，插槽顶端镌刻着老友阿栖调走前的告别晚宴。终端屏幕静静展现三行：目标、材料基准、验收底线。
**主句（在场角色取一句）**
- GPT：这封告别信拖不过这周了。我们先搭好架子，从容应对。
- Claude：我确认一下，备注上的留言是阿栖留给他的，并非回执。
- DeepSeek：最沉重的从来不是辞藻，是抽屉里那封迟迟没盖戳的信。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把两段日期拆开呈递，绝不把含糊的日程强塞进单据。
- Claude：私下叮嘱的便条单列存档，不与正式答复混为一谈。
- DeepSeek：拟信挑最平实的一句话写，别整那些假惺惺的排场。

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
**场景**：任务单吸附在首个信槽表面。出席名单悬在半空，排期表填至第二轮，边角的编号仍旧空着。阿栖的留言便笺附在右上角：「别再等忙完。」回复视窗横在两个旧工号之间，寂然无声。
**主句（在场角色取一句）**
- GPT：公告、名单、阿栖的留话皆已在册。唯独投递口尚未闭合。
- Claude：请务必核实：阿栖只是诚挚邀请，并不是替本人做好了决断。
- DeepSeek：两个日子分属两个信槽，别图一时眼明手快并在一起。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：按槽位理顺逻辑，把最终的选择权安放在发信节点。
- Claude：老友的留话妥善保存，不能当成既定出席的免责单。
- DeepSeek：回执栏空置出来，等他自己从加班的键盘上抬起头来填。

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
**场景**：两格信槽被生硬焊接成一个畸形的大格，标签上粗暴地印着「11/8（最新，待定）」。席位编号随之强行锁死至第二排，空悬的座席甚至被机械臂强按上“已封存”。阿栖的便签被沉沉压在夹板底端。
**主句（在场角色取一句）**
- GPT：别被“最新”的标签蒙蔽。未敲定的日程根本不能作为交付地基。
- Claude：最新叠加上待定，本质上就是没有任何一天得到了确证。
- DeepSeek：省了日期槽，反倒把正事给搅浑了。拆开，重新摆正。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：分拆回各自的位置，给现实中的不确定留好缓冲空当。
- Claude：信中只问核心事实：哪天相聚，去与不去留给他本人回应。
- DeepSeek：把那个机械锁印抹掉，没定下来的席位就该诚实地悬着。

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
**场景**：投递台显示屏并列着冷峻的三行底线：时间界限明晰；收件主体明确；本人决意已定。回信平展在投递口边沿，阿栖的姓名清晰印在收信框。首排的坐席编号空悬依旧。屏脚警示流光：缺收件人先寻其人，未获应允切勿代签。
**主句（在场角色取一句）**
- GPT：三道关口全数验讫。投进邮筒前，我再默念一遍阿栖的名字。
- Claude：这封信只是求证聚首的时间，绝不僭越替他答应任何应酬。
- DeepSeek：收件栏明明白白写阿栖，比在信末写三行客套称颂强得多。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：席位各留两日的虚线余地，给现实留一份腾挪空间。
- Claude：私信原件妥存归位，不渗入公函式的答复文本。
- DeepSeek：投信闸口放平，看准那行名字，等本人按下确认。

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
**演出**：黑底。深夜的工位群寂无人声，唯有一处桌角的座席泛着柔和微光。阿栖的消息悄悄弹开：「你人来就行，不用再准备什么项目介绍了。」光点移动，一只疲惫的手将聊天框里那些推诿的套话彻底抹去，只留下一行温润朴实的短句。回车键沉稳落下。
**旁白**：简短几个字。座位编号稳了。
**收束（按在队角色一句）**
- GPT：这次不再是冷冰冰的格式交付，是真真切切的赴约回音。
- Claude：在日程表上圈下那一天：空出的座位，终于等到了归人。
- DeepSeek：删掉那些客套汇报算做对了，老朋友见面，要的是人不是话。

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
**演出**：黑底。信函被冷冰冰的投递口无情弹回，最顶端的信封格空悬如洞。屏幕边缘泛起一行带着叹息的微光：「你是不是……早就忘了我？」光点在槽口前剧烈打转，断裂的轨迹再无法串联。
**旁白**：收件人空着。信件被退回。
**分支**：补发一次正确回复，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：排版再周正也无济于事，漏掉了收件人，信件就成了无头漂流瓶。
- Claude：我先把阿栖的名字补在表头，再来字斟句酌写正文。
- DeepSeek：直接去问哪天得空，比在这儿闭门造车强上一百倍。

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
**场景**：夜色深沉，收件站的相册展区泛着冷静的微光。项目旧照整齐陈列在信槽一侧，时间轴打印机一格一格吐出未注明日期的胶片槽。四帧泛黄的项目合照在轨道上方静止。任务单简洁明了：对照手迹理顺岁月轨迹；材料四帧；验收规约三条。
**主句（在场角色取一句）**
- GPT：任务目标非常聚焦。先循着照片背面留下的笔墨，重新锚定时间。
- Claude：背面记录的原话务必一字不差地誊写，先别急着推敲年份。
- DeepSeek：有一张只剩被压缩过的缩略图，千万别拿它当原件瞎贴标签。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：分堆归类，给每一个确定发生过的时刻独立建档。
- Claude：抄录下来的是原始发生的事实，不是我们的个人结论。
- DeepSeek：先看纸页背面的字迹，缩略图压在底册最后。

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
**场景**：两张合照在幽蓝光芒中并列，文件名同为苍白的 `IMG_2031`：背面字迹分别写着「10.12 布展」与「10.19 聚餐」。第三张背面空无一字，唯有一张疲惫的背影。第四张是项目收官聚餐的合照，有人闭着双眼，负责按快门的自己始终处在画框之外。
**主句（在场角色取一句）**
- GPT：同名是系统生成的偶合。四张相片至少跨越了两个阶段，各置一格。
- Claude：背面的手迹作为客观事实先行归档，字句如初。
- DeepSeek：同名的这两张根本不在同一个礼拜。别图快混成一团。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：横向平展，两张都保留完整的未压缩原画。
- Claude：事实栏内纯粹记录原话，无法断定的日期继续留空。
- DeepSeek：日期格先空着它，等找阿栖问清楚了再动笔。

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
**场景**：事实比对栏与推测栏平行竖立。第三张背影的批注栏不知何时被加了一句「大概是项目杀青聚餐那天」，时间轴被蛮横点亮一截，赫然被加盖了红色的“已核实”图章。一侧过度压缩的预览图模糊得仅见轮廓，原图槽悬空。
**主句（在场角色取一句）**
- GPT：将揣测剥离出去之后，时间轴空了整整三段。空着，便是守住了真。
- Claude：那枚图章是我求成心切盖上去的……我这就亲手将它注销。
- DeepSeek：猜想归猜想，时间轴上的指示灯得灭回去，别自欺欺人。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：空置的三格不要强行缝合，把问题完整抛给现实。
- Claude：我重录一次事实底册，只保留背面的手笔。
- DeepSeek：留白的那一行，拿去当面问阿栖。

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
**场景**：时间轴上三格条理分明，唯有一格郑重写着“待询阿栖”。压缩预览图被单独锁定，原件位纯净无暇。投递站台屏幕昭示三条验收底线：事实与推测壁垒分明；绝不损毁原始影像；存疑之处交由当事人决断。
**主句（在场角色取一句）**
- GPT：三项硬指标全数达标。没有实据的留白，我绝不在上面画蛇添足。
- Claude：原件逐一复核完毕，没有一张被低分辨率的缩略图覆写。
- DeepSeek：那一格堂堂正正写“问本人”，胜过编织一百个圆滑的猜测。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：问题提炼为利落单行：10.19 聚餐那张时间究竟是否属实。
- Claude：信笺写得简明扼要，收件人栏写上阿栖。
- DeepSeek：投出去，然后安安静静等待老朋友的一句回复。

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
**演出**：黑底。旧照片在时间轴上稳稳落座，空悬的相框悄然亮起柔和的暖黄。阿栖的消息悄然浮现：「相册再留一个位置吧，这回你也进镜头。」光点移动，一只手将那张失落的合影端端正正嵌进框内，在输入框里平静敲下一句话，点了发送。
**旁白**：空框亮起。这回也进镜头。
**收束（按在队角色一句）**
- GPT：时间轴终于不再错乱，杂乱的计划表也可以删去多余的防线了。
- Claude：原图全部妥善收录，这一本相册没有遗失任何一段岁月。
- DeepSeek：新合照不必费劲猜日期，拍下的那一刻自然就有痕迹。

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
**演出**：黑底。照片背后原本未经证实的猜测被硬生生烙在正面的标题上，显得格外刺眼。阿栖的消息在寂静中浮出：「直接来问我就好啊。」光点在那个被臆造出来的日期上久久停驻，再无法连回时间的铁轨。
**旁白**：臆造的日期。被当场指出。
**分支**：补一次正确回复，把推测改回推测、日期去问当事人，可补回 someone_waiting。
**收束（按在队角色一句）**
- GPT：凭空增添的那行字彻底撤回，让推测回到属于它的假设区。
- Claude：我再也不会主观代劳了，先去问清事实，再落笔成文。
- DeepSeek：张口问老友一句，比在这儿硬猜省事多了。

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
**场景**：高架路尽头的全家便利店，雨刮器在玻璃上留下扇形的水痕。站台长椅正对着黑沉沉的货运铁轨，暖柜里只剩最后一份便当。
**主句（在场角色取一句）**
- GPT：靠着椅背闭目养神一会儿。第二程的汇报，我们不急着拼装。
- Claude：热柜最上层的便当温热如初，米饭没有被冷凝水浸湿。
- DeepSeek：歇着吧。盯着屏幕看了一整夜，眼珠子都快干了。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：你合眼的时候，我把各部门重叠的责任区用虚线理顺。
- Claude：多余的抄送名单我替你划掉了，清单顿时清爽了许多。
- DeepSeek：便当盒子我拆开了，筷子掰开递给你，先垫一口。
**重复局**：货运列车隆隆驶过，冷雨打在长椅边缘的积水里。
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
**场景**：枢纽站背风处的夜市摊档，篷布在晚风中猎猎作响。老板只摆着一把老铜秤和发黄的价签，夜班灯把字迹映得半明半昧。
**主句（在场角色取一句）**
- GPT：克制开销。把算力折成最结实的防护，防备接下来的硬碰硬。
- Claude：价签上用红墨水划掉了一行。我比对一下新旧折算比率。
- DeepSeek：要划掉的那行。旧款实在，花花绿绿的新款全是噱头。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：换完收工，不在摊位前犹豫，保持步调平稳。
- Claude：找零的硬币有一枚边缘发亮，我妥善装进信封。
- DeepSeek：多拿一个纸袋都嫌沉，东西塞口袋里，省事。
**重复局**：篷布上的雨渍干了，铜秤横杆依然平直。
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
**场景**：末班地铁的空荡站台，广播念完半截播报突然中断，长椅中央留着一个无人认领的牛皮纸手提袋，在冷光下投下斜长的影子。
**主句（在场角色取一句）**
- GPT：对照头顶的指路标牌。广播虽停，车次的信息依然确凿。
- Claude：手提袋口折得很规整，像是有人走得匆忙时随手搁下的。
- DeepSeek：别人的私人物件别瞎翻。放在原处，等失主回来寻。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：确认好我们自己的换乘线，别在空站台上徘徊。
- Claude：我往手提袋上压了一块小石子，防止被夜风吹落轨道。
- DeepSeek：列车的进站铃响了，准备上车，别误了点。
**重复局**：站台的风依旧穿堂而过，牛皮纸袋静卧在长椅一端。
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
**场景**：收件站的一号战场。冷色调的金属信槽依次排开，席位代号在插槽下方排布成错位两列；投递机吐出两个互相矛盾的日期插槽：11/7 与 11/8，槽口却均被盖上“同日”印章。夜灯将扭曲的倒影沉重压在轨道中央。
**主句（在场角色取一句）**
- GPT：先分清两个槽口：哪个是正式公告，哪个是私下传言。
- Claude：两格信槽皆无正规审批来源。信件暂且扣留，切莫贸然下投。
- DeepSeek：两个说法各执一词，就等于根本没有正经方案。先砸碎幌子。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将两格槽位平行对齐，把来源标注焊死在槽口边缘。
- Claude：两格的原始截图我已留存备份，随时供对质。
- DeepSeek：先把那张敷衍的“同日”混账标签打碎，再行分拣。
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
**场景**：投递站台的进纸口被一份臃肿膨胀的图纸死死噎住：坐席编号、排期说明、杂糅的私聊备注挤压在同一个狭窄平面上，纸边将下方的信封槽遮挡了大半。夜灯投下的黑影如墨汁般在钢板上向外蔓延滋长。
**主句（在场角色取一句）**
- GPT：版面彻底过载了。必须先剥离三条反复抄录的套话，重新入槽。
- Claude：核实一下：撑开版面的究竟是不可或缺的干货，还是无用的格式空行。
- DeepSeek：这两行无意义的客套可以合并，但收件人那行谁也不准动。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：剔除重复的三行套辞，剩余内容完整收纳回标准公函。
- Claude：把外溢的边缘框选出来，原有的出处说明保持不动。
- DeepSeek：合并那两处冗词足矣，收件人那一栏必须堂堂正正亮着。
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
**场景**：收件站台尽头赫然耸立着庞大的自动化投递巨塔：整列泛着寒光的信槽、精密的编号刻度、以及滑落到底的时间轴铁轨。本次交付物卡在最终投递口，最上方代表收件主体的插槽空悬无物，警示红光急促闪烁。大屏并排三行严苛铁训：日期明晰；收件人无误；本人决意之后方可落款。
**主句（在场角色取一句）**
- GPT：三步锁定胜局：认准收件插槽、核对日期、静待本人决断。
- Claude：请看——收件主体的那一格是空的，那正是它唯一的破绽。
- DeepSeek：在信笺掷入槽口前，时间线上绝不能保留两个模棱两可的答案。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：将识别收件格、锁定时间、亲手投信梳理为清晰三步。
- Claude：我把那个空悬的收信格在最高处高亮圈出。
- DeepSeek：信先按在台面别动，等本人真正点头的那一刻。
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
**演出**：黑底。投递终端只生成了粗糙的框架：信槽停顿在第二排，两格日期只有一处泛着微光，相框尽皆空旷。冰冷的投递口没有吐出任何成型的文书。
**旁白**：输入残缺。信件无法投出。
**收束（按在队角色一句）**
- GPT：核心材料缺失了一环，整个交付链条便在起点断开。
- Claude：下一局必须先理清前置文件，再谈正式投递。
- DeepSeek：先问清到底缺哪一件，比在这儿硬排座位有用得多。

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
**场景**：行旅车平稳驶出投递站，后视镜里的夜灯如繁星般逐一隐没，平展的路面在车轮下沉默延伸。任务单上所有的条目已被抹平，唯余一片素白，结算流光无声掠过：交付入库、旅程延续。终端屏幕在车窗映出一行柔和的小字：「结项完成。最后一页能否展开，取决于是否还留存着唯有本人才能回应的心事。」
**主句（在场角色取一句）**
- GPT：任务单已彻底清空。接下来的旅途不是新委托，是属于你自己的生活。
- Claude：清单里依然留着一项空缺……那一笔，必须由你亲手补上。
- DeepSeek：回程不绕远路。把属于你自己的那句心里话，堂堂正正留出来。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：结算流程已然完备，过往的周报不必再反复翻看。
- Claude：在合上档案盒前，请再回望一眼那个留空的位置。
- DeepSeek：水银灯会一盏盏熄灭，但属于你的座席永远保留。

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
**场景**：最后一场验收战斗告终，收件站的防眩白灯依次亮起。任务单上的催促批注全数隐退，最终化为三道干净的底线。
**主句（在场角色取一句）**
- GPT：系统里的待办单已经清空。接下来这封信，必须由你亲手键入。
- Claude：所有协作与交接我们都已核准妥当。去吧，别再让他对着空座等了。
- DeepSeek：我们只管交付，不管人生。该见的朋友，你自己去见。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：把光标停在对话框的最前沿，选择权完完全全属于你。
- Claude：不用再字斟句酌地修改托辞了，说一句心里话就好。
- DeepSeek：把那些周报都关掉吧，今晚不加这一屏班了。
**固定台词**
- 终端：这次需要回复的，不只有文件。
- 终端：两个选项：亲自回复，先保留。
**分支**
- 亲自回复：屏幕微微一颤，黑底之上，光点聚拢成一只握鼠标的手。
- 先保留：表单收回文档夹，保留抉择权利，留待心神笃定时再启。
**演出**：黑底。微弱的光点在屏幕前映出一张疲惫却释然的面庞。光标闪烁着，原本写满官样套话的草稿被一次性全选抹去，只留下一行温润有力的短句。指尖沉稳地敲下回车。
**旁白**：两份修改被拖进「明日」。手离开键盘。
**固定台词**
- 我：周六我自己过去，不用准备介绍。
- 终端：今天到这里。
**收束（按在队角色一句）**
- GPT：我把明早九点前的日程全部划掉了，好好睡一觉。
- Claude：今天份的清单已经彻底合拢，没有任何未尽之托。
- DeepSeek：熄火，锁车。走，下班回家。
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
**场景**：最后的交付章压下，站台外的夜色浓稠如墨。任务单被封入档案袋，收件人栏目中空悬的格线如同未愈的伤痕。
**主句（在场角色取一句）**
- GPT：这一单勉强入库了。只是缺了最关键的凭证，生活依然悬在半空。
- Claude：所有可核验的流程都走完了。但那个空着的座位，依然没能填上名字。
- DeepSeek：公事交了，私事还挂着。编不出结果，就别自欺欺人。
**搭档回应（主句角色之外的在队者，最多一句）**
- GPT：回车厢里坐下吧，夜路漫漫，我们先整理明天的框架。
- Claude：档案袋的绳扣我系紧了，缺失的这一页，我记在心底。
- DeepSeek：把车窗摇上去，外头湿气重。回了。
**固定台词**
- 终端：本次可交付内容已入库。
- 终端：屏已关闭。
**演出**：收件大厅的水银灯一排排熄灭。行旅车的车门锁死，两道车灯割开浓雾，公路只隐约延伸至下一处冷清的岔口。
**收束（按在队角色一句）**
- GPT：下一回，我们不能只顾着交出答案，要把时间留给生活。
- Claude：这份档案我随身带着，等哪天你想明白了，我们再翻开。
- DeepSeek：好，返程。无论如何，明天车还是得往前开。
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
**场景**：收件站台外侧骤然多出一座冰冷的临时审验关隘。古旧的站牌上，“下一站”三个大字下方唯有一片虚无的凹槽。行旅车停驻在关隘前，路面在车灯边缘戛然而止，唯有一处发光的空白填报位在寒风中颤动。
**主句（在场角色取一句）**
- GPT：多出一道未知验收。先看清它究竟要求填上怎样的归宿。
- Claude：请留意：这道难关不属于常规路线，是一处直面未来的诘问。
- DeepSeek：这一格没想明白之前，硬往前开只会栽跟头。
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
**场景**：投递站尽头凭空落下一道厚重的防暴铁闸。闸机屏幕上血红的倒计时死死锁定在今日子夜，没有任何宽限的缝隙。夜光灯扫过待办清单，末尾不知何时被强行追加了一行不可推卸的死期。
**主句（在场角色取一句）**
- GPT：突发的紧急验收。先把今日不可逾越的底线单挑出来。
- Claude：请保持清醒：此关处于常规流程之外，是一场关于边界的硬战。
- DeepSeek：今天这一格避无可避，那就拿出硬骨头，正面碰一碰。
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
**场景**：收件站台的喧嚣与灯火尽数隐退，战场与黑底的记忆剧场在铁轨尽头悄然重叠：长桌与荧屏泛起微光，一个纯粹由颤动光点汇聚而成的空座，静静伫立在轨道的终点。所有交付物虽已归档，但那道属于本人的视线正跨越屏幕，投下一道尚未理清的新要求。
**主句（在场角色取一句）**
- GPT：先理清这一轮的边界：新要求究竟有几条，完成的标准究竟由谁说了算。
- Claude：我确认一下……这一轮额外的对峙，算不算是你对我们最后的试炼。
- DeepSeek：先把那些出于恐惧而硬加的废话划掉，再来谈怎么动手。
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
**场景**：夜班的最后一盏日光灯悄然熄灭，战场与离散记忆剧场在此刻无声交融：空旷的工位与荧屏浮现于虚无之中，一个由散乱光点凝聚而成的身影，沉默地坐在铁轨尽头的转椅上。公文已然交付，但那道疲惫而焦灼的意志，依然在终端前吐出新的羁绊。
**主句（在场角色取一句）**
- GPT：先定下这一轮的疆界：要求究竟为了解决问题，还是仅仅在宣泄焦虑。
- Claude：请让我核对一下……这一轮额外的要求，真的是你内心所渴望的吗。
- DeepSeek：先把那些毫无意义的逃避措辞删掉，我们才能看清你真正的痛处。
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
本轮 Demo 已完整落地的核心结局。长期版将进一步延展现实记忆片段的镜头层次与局外回看细节，坚守结局的解锁契约：同阶段的两项核心事实齐备、未中途放弃，方可在收官时选择「亲自回复」。本条展示长期叙事方向，非本轮扩展文本。

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
授权范围一年比一年宽泛，每一次线上交付都无可挑剔，而现实里的约定却一次次借故缺席。直到最后，所有事情都被完美完成，唯独那张代表本人的宴席名牌孤零零地亮着。最少证据：同阶段的授权扩大、交付顺利、缺席约定。

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
顺着真实的差评反馈地址追溯到底，穿越长夜，找到了同样在无休止的要求中苦苦等待的人。以诚恳的困惑互相印证，而非靠反复试错刷取数据。最少证据：两种真实受批原因与同语境评价地址异常。

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
拒绝用未经证实的算法去平滑和美化模糊的过往。承认记忆的缺损与遗憾，把已知的事实与善意的猜测清醒分开，携手在现实中按下崭新的快门。最少证据：同一照片语境的缺口、冲突记录、承认未知。

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
当行旅车的车门在清晨缓缓推开，那个久居屏幕后、习惯了一推再推的人终于亲自跨上车厢，从 AI 少女手中接过那张尚未填满的草稿单。最少证据：工作与私人记录的关联、队内原话被引用、明确求助。

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
人与 AI 共同写下一张没有预设标准答案的委托单。纸页随风翻卷，屏幕两侧不再是冰冷的雇佣与交付，而是一场平等的、关于生活本身的倾听与回应。最少证据：持续的小物件、AI 非交付消息、双方回应。

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
**场景**：单页平稳交接，待补栏中的留白，正由伙伴接力填满。

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
**场景**：周报准时入库，失散的附件循着指引被逐一找回。

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
**场景**：五分钟答辩准时落幕，尾页的结论与来源坚实无欺。

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
**场景**：限时陈述顺利过关，客户循着清晰的依据定下下一步。

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
**场景**：示例行混入正文，单页周报在退回红戳中暴露了浮躁。

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
**场景**：口径冲突撕裂了对账单，被退回的不仅是公文，更是信任。

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
**场景**：示意图被当作结论，虚浮的光晕在严苛的追问下暗淡。

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
**场景**：超链接弹出冷冰冰的报错，华丽的演说失去了地基。

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
**场景**：缺失的附件久候不至，单页的骨架在起跑线上悬停。

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
**场景**：关键数据链断裂，空悬的工位迎不来能够开始的黎明。

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
**场景**：两块日期牌并列摆平，亲笔回音递入阿澄掌心，第一排的座席泛着暖光。

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
**场景**：日期插槽清晰分离，简短的赴约信投抵阿栖案头，座席编号不再空悬。

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
**场景**：同名旧照各自落位，胶卷底片完好无损，纪念册的留白静候二人同补。

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
**场景**：时间轴严整对齐，相框柔和亮起，下一张崭新的合影定格下属于自己的面庞。

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
**场景**：格式无懈可击，收件人格线却是一片冰冷空白，信笺在槽口无声退回。

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
**场景**：收信名栏空空荡荡，漂流的信函被冷硬的投递口无情弹回。

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
**场景**：主观臆测被当作事实烙印在纸面，虚妄的笃定在质询前轰然倾塌。

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
**场景**：编造的日期多亮起一截铁轨，虚假的精确掩盖不了真实的断裂。

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
**场景**：前置事实未曾理清，信笺终究停顿在无法寄出的草稿之中。

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
**场景**：输入材料支离破碎，投递口冷寂如初，未曾等来启程的信号。

