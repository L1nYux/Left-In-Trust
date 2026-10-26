# GPT 对峙缺失附件 UI 概念图 v1

生成日期：2026-10-25  
用途：阶段 A 静态战斗垂直切片，用于验证战斗构图、信息层级和卡牌插画占比。  
生成方式：Codex 内置图像生成工具，先生成完整概念图，再仅校正两张专属牌标题。

## 参考图及用途

1. `_build/evidence/battle_gpt.png`：只参考当前战斗需要呈现的数据与交互层级。
2. `docs/美术/总体视觉基准图_v1.png`：参考纸页世界、暗色数据空间与珊瑚红验收压力的材质和明暗关系。
3. `角色设定/美术/GPT/gpt.webp`：参考 GPT 的白/淡紫长发、浅色服装、角、尾巴与小蓝云等识别特征。

上述角色图像仍按现有美术资产清单作为内部造型参考，不因进入概念图而改变授权状态。

## 主生成提示

```text
Use case: ui-mockup
Asset type: high-fidelity static game battle UI concept for a 2D PC card battler
Primary request: Create a polished 16:9 battle screen for the Chinese game “未尽之托”, showing the GPT heroine on the left confronting the enemy “缺失附件” on the right, with illustrated cards along the bottom. This is a practical interface mockup, not a poster or splash art.
Input images: Image 1: current prototype battle screen, use only as information-reference for the required combat data and interaction hierarchy; Image 2: project visual-style reference, use its warm paper-world, dark data-space and red validation-pressure materials; Image 3: GPT character reference, preserve her recognizable white/lilac hair, pale dress, horns, tail, small blue cloud companion and gentle anime appearance.
Scene/backdrop: a battle arena formed from layered report pages, spreadsheet grids and folded paper terrain, with a distant one-page landmark; the bright travel world has entered a tense validation state, with restrained coral-red warning geometry and dark ink-blue depth.
Subject: left side has one knee-up/full-body cutout-like GPT heroine in a battle-ready three-quarter pose facing right; right side has “Missing Attachment”, an original floating file-box/envelope creature with a large attachment-shaped hollow center, searching cables, clipped paper edges and a grounded shadow, facing left. It is a task-problem construct, not a gore monster.
Style/medium: shippable 2D anime game UI mockup, painted illustration plus crisp practical UI, warm paper textures, matte glass panels, subtle data particles; original design language, not a copy of any existing game.
Composition/framing: exact landscape game-screen composition, 1280×720 intent. Top slim status bar. Upper/middle 52% is a readable confrontation stage with ample space between hero and enemy. Hero state strip attached near her feet with TOKEN 12/12, shield 0 and a two-segment combo indicator. Enemy name and HP 16/16 near its base. A large readable intent icon above the enemy shows a single attack aimed at GPT for 2 damage, with a clear converging targeting line. Bottom 36% is the hand area: five separate vertical 5:7 illustrated cards in a shallow fan/row, each with a large art window, cost medallion, short title band and effect-number area. Keep two smaller permanent basic-action cards at far left. Large “结束回合” button at lower right, draw/discard counters beside it.
Card illustration motifs: a cyan path through three nodes; paper-bracket shield blocking a red annotation; three floating steps placed by the small blue cloud; three paths merging into one purple-white strike; a warm emergency supply case returning token particles. Every card must look like a real illustrated collectible card, never a plain text button.
Lighting/mood: clear neutral key light on character and cards, warm daylight from the paper landscape, restrained coral threat light around the enemy; adventurous, readable, tense but not grim.
Color palette: ink navy #0A101B, paper white #F2EFE7, cool cyan #69D7E7, warm amber #F2B85B, coral red #EF6A62, pale lilac role accents.
Text (verbatim where legible): “回合 1”, “缺失附件”, “TOKEN 12/12”, “结束回合”. Use no other long paragraphs; small secondary text may be abstract UI marks rather than fake writing.
Constraints: practical interaction hierarchy; crisp silhouettes; enemy intent must be the most obvious combat warning; card art must occupy about half of each card; keep character and enemy unobscured; no blood, no photorealism, no giant text, no logos, no watermark.
Avoid: current prototype’s large empty status panels, rows of rectangular text-only buttons, neon cyberpunk city, code-rain background, generic fantasy weapons, excessive glow, illegible clutter, direct imitation of Slay the Spire assets or layout styling.
```

## 局部校正提示

```text
Correct only two card-title labels in the bottom hand. Change the first large illustrated card title from “路径规划” to the exact Chinese text “分步推进”. Change the fourth large illustrated card title from “整合输出” to the exact Chinese text “一鼓作气”. Change only these two title labels and preserve the rest of the image as closely as possible.
```

## 本轮验收

- 角色与对手形成明确的左右对峙，视觉中心不再是大块状态面板。
- 敌方意图在头顶独立显示，伤害 2 与目标方向能在出牌前被快速识别。
- token、防护与连击贴近角色，敌人名称与完整度贴近对手。
- 五张大卡均具有独立插画，另有两张较小的常驻基础行动牌。
- 卡面插画、费用与主要效果数字在缩小后仍有层级。
- 生成图中的小图标、牌面文字和顶部功能键只作氛围参考，实装必须使用确定性的 Godot 组件。
