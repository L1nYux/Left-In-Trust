# Demo 正式分层美术与 UI 定稿

版本 v1.0，2026-10-26。本文记录可运行 Demo 已采用的画面方案，作为后续角色、怪物和卡牌美术的制作基准。

## 本轮交付

- GPT、Claude、DeepSeek 三名角色均使用连续透明主立绘，并共用八层运行骨架：`shadow / aura / back / body / head / prop / front / effect`。六件独立部件继续保留为后续人工蒙版源，但不再直接拼接人物轮廓。
- “缺失附件”使用正式四件美术资源与六层运行骨架：`shadow / back / legs / body / core / effect`。
- 三名角色支持 `basic / light_attack / heavy_attack / guard / support / transfer` 六类动作标签；怪物支持 `idle / attack / hit`。
- 三人测试场已固定为三名角色对阵“缺失附件”，可直接查看完整构图和混合共享手牌。
- 卡面不再只显示名称与说明：当前按攻击、防御、支援等类型绘制图形插画，并叠加角色归属色；逐张正式卡图可在不修改交互结构的情况下替换。

## 最终人物比例

以 1280×720 为唯一验收画布：

| 对象 | 运行容器 | 画面占用 | 结论 |
| --- | --- | --- | --- |
| 单名角色 | 178×326 | 立绘约高 280px，状态条 174×68 | 保留半身以上的完整轮廓；三人同屏仍可清楚区分 |
| GPT | 正式图缩放 0.90 | 队伍左前位 | 略强化白龙轮廓，但不压住 Claude |
| Claude | 正式图缩放 0.88 | 队伍中位，Y=100 | 中间层略低，发型和书页特效不触碰顶栏 |
| DeepSeek | 正式图缩放 0.88 | 队伍右前位 | 水纹与尾部朝敌方展开，不侵入敌方血条 |
| 缺失附件 | 405×350 | 美术主体约 400×267 | 高度不碾压角色，依靠约 2.25 倍单角色宽度形成 Boss 感 |

三人站位为 `(42,118) / (222,100) / (404,108)`。一人和二人沿用相同舞台范围重新居中，因此无需为不同队伍人数制作另一套立绘比例。

## 新版战斗 UI 定稿

画面固定为三段：

1. `Y=0–54`：回合、场次、敌人名称、行动顺序与当前行动者。信息保持细条化，不与角色争夺焦点。
2. `Y=54–438`：左侧队伍、右侧敌人形成横向对峙。角色状态贴近脚边，敌人意图悬浮在头顶，敌人生命贴近主体下沿。
3. `Y=438–720`：全队共享手牌。基础牌常驻左侧，混合角色牌以 142×222 大卡、132px 间距轻微扇开；右侧只保留确认、牌堆信息与结束回合。

专属牌在卡角显示所属角色并自动切换行动者；通用牌由当前行动者使用。角色状态和牌面归属使用同一角色色，避免共享手牌中出现“这张牌是谁的”识别成本。

## 正式资源清单

每个角色目录包含竖版主立绘、2×3 部件母表和六个运行切片：

- `game/assets/actors/gpt/`
- `game/assets/actors/claude/`
- `game/assets/actors/deepseek/`

怪物目录包含横版主立绘、2×2 部件母表和四个运行切片：

- `game/assets/enemies/missing_attachment/`

`game/tools/slice_gpt_parts.gd` 与 `game/tools/slice_demo_parts.gd` 可从部件母表重建切片。Claude 头部格的跨格衣摆清理由脚本确定性完成，禁止手工覆盖切片后不回写脚本。

### 连续人物主层与缩放规则

- 当前 AI 生成的头部与身体部件不是从同一完整像素图蒙版拆出，衣领、颈线和姿态存在结构差异，不能作为运行时接缝。三名角色因此改用完整透明主立绘作为连续人物主层，头颈与身体永不分离。
- 八层运行协议继续保留；`shadow / aura / effect` 承担选中态、状态反馈和卡牌动作特效，人物主层承担整体位移、旋转与呼吸。六件独立部件保留为后续人工校准或骨骼蒙版制作源，不再直接拼成人物轮廓。
- 所有正式角色与怪物运行切片必须生成 mipmap，并使用 `LINEAR_WITH_MIPMAPS` 过滤。这样在约 0.88 倍人物缩放和 120px 头部缩放时仍保持平滑轮廓。
- 部件母表跨格产生的孤立碎片必须在可重复切片脚本中清理；当前已处理 Claude 魔法层上方发丝、DeepSeek 头部右上碎片与水效右缘碎片。
- 放大接缝验收图由 `game/tests/capture_layered_actor_closeups.gd` 生成，输出到 `_build/evidence/layered_actor_closeups.png`。

## 图像生成方式与提示归档

本轮使用 Codex 内置 `image_gen`，用途分类为 `stylized-concept`，全部要求透明背景、无文字、无水印。角色主立绘以项目现有角色设定图为身份参考，UI 概念图作为构图与尺度参考；部件母表从对应主立绘继续拆分。

### Claude 主立绘

```text
Use case: stylized-concept
Asset type: production-ready layered 2D battle character master
Primary request: Create Claude as a full-body anime fantasy AI heroine for a card-battler confrontation scene, preserving the established identity: long vivid orange hair, amber eyes, black-and-ivory formal dress with orange accents, flower ornament and black ribbons, holding an ornate dark book; project amber paper sheets and a protective page barrier from her free hand.
Composition/framing: single character, full silhouette visible, three-quarter view facing right, neutral combat-ready stance, generous transparent margin, readable at about 280 px tall.
Style/medium: polished 2D game key art, crisp cel-shaded rendering, delicate fabric and page details.
Constraints: transparent background; one character only; no UI, text, logo, watermark, floor, frame, or cropped limbs.
```

### DeepSeek 主立绘

```text
Use case: stylized-concept
Asset type: production-ready layered 2D battle character master
Primary request: Create DeepSeek as a full-body anime fantasy AI heroine for a card-battler confrontation scene, preserving the established identity: blue whale-themed maid, deep-blue flowing hair, blue eyes, navy-and-white maid dress, small whale-tail motifs, holding a white rice bowl; form cyan water ripples and flowing energy around the free hand and tail.
Composition/framing: single character, full silhouette visible, three-quarter view facing right, calm supportive combat stance, generous transparent margin, readable at about 280 px tall.
Style/medium: polished 2D game key art, crisp cel-shaded rendering, luminous but controlled water effects.
Constraints: transparent background; one character only; no UI, text, logo, watermark, floor, frame, or cropped limbs.
```

### “缺失附件”主立绘

```text
Use case: stylized-concept
Asset type: production-ready 2D card-battler enemy master
Primary request: Create “Missing Attachment” as a hostile document-spider machine: a bright red paperclip-shaped energy core inside a black-red mechanical hub, surrounded by torn white document shards, black cables and multiple angular spider legs; it should feel like a corrupted office-file error made physical.
Composition/framing: one wide enemy silhouette facing left, low horizontal mass, core centered and instantly readable, designed to occupy roughly 400×267 px opposite three heroes.
Style/medium: polished 2D game boss art, sharp graphic shapes, paper fibers, red emissive core, dark mechanical detail.
Constraints: transparent background; no character, UI, readable document text, logo, watermark, frame, or cropped legs.
```

### 角色部件母表

Claude 与 DeepSeek 分别使用同一结构生成独立母表：

```text
Use case: stylized-concept
Asset type: registered 2D puppet parts sheet derived from the supplied character master
Primary request: Separate the exact same character into six independently usable visual groups while preserving costume, colors, rendering and facing direction.
Composition/framing: strict 2-column by 3-row grid in this exact order: back hair/back silhouette; torso and dress body; head and front hair; near arm with held item; far hand and signature magic prop/effect; front skirt/foreground decorative layer. Center every part in its cell at a consistent registration point and do not add labels.
Constraints: truly transparent background; no grid lines, text, duplicate full character, invented costume changes, shadow, floor, watermark, or content crossing cell boundaries.
```

### 怪物部件母表

```text
Use case: stylized-concept
Asset type: registered 2D enemy puppet parts sheet derived from the supplied Missing Attachment master
Primary request: Separate the exact same enemy into four independently usable visual groups while preserving its paper, cable, machine and red-core design.
Composition/framing: strict 2-column by 2-row grid in this exact order: rear cables/document halo; mechanical body and paper mass; spider legs; glowing paperclip core. Center parts to the same registration point and add no labels.
Constraints: truly transparent background; no grid lines, text, extra enemy, full-scene background, watermark, or content crossing cell boundaries.
```

## 验收入口

- 实机静态图：`_build/evidence/layered_actors_trio.png`
- 动作中间帧：`_build/evidence/layered_actors_motion_sample.png`
- 分层协议测试：`game/tests/test_layered_actors.gd`
- 实机截图脚本：`game/tests/capture_layered_actors.gd`
- Windows 导出：`dist/windows/LeftInTrust.exe`
