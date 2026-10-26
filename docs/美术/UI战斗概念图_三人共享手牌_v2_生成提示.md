# 三人队伍与共享手牌 UI 概念图 v2

生成日期：2026-10-25  
用途：验证 2—3 人常规编队、共享混合手牌、卡牌归属和出牌动作焦点。  
生成方式：Codex 内置图像生成工具；先生成三人布局，再统一缩小角色约 20%，最后校正三张专属牌标题。

## 参考图及用途

1. `docs/美术/UI战斗概念图_GPT对缺失附件_v1.png`：参考整体视觉语言与信息层级，不沿用单人大立绘比例。
2. `角色设定/美术/GPT/gpt.webp`：GPT 造型参考。
3. `角色设定/美术/Claude/claude.webp`：Claude 造型参考。
4. `角色设定/美术/DeepSeek/deepseek.webp`：DeepSeek 造型参考。

角色图像仍按现有美术资产清单作为内部造型参考，不因进入概念图而改变授权状态。

## 主生成提示

```text
Use case: ui-mockup
Asset type: revised high-fidelity static battle UI concept for a 2D PC team card battler
Primary request: Redesign the “未尽之托” battle screen around a normal three-character party and one shared mixed hand. Show exactly three compact AI heroines on the left confronting “缺失附件” on the right. The screen must demonstrate that a character performs a matching animation when a card is played: GPT is currently stepping slightly forward and casting an attack card, while Claude and DeepSeek stay in their compact idle formation behind her.
Input images: Image 1: v1 battle UI concept, use as style and information-hierarchy reference but reduce the hero scale and replace the single-hero composition; Image 2: GPT identity reference; Image 3: Claude identity reference; Image 4: DeepSeek identity reference.
Scene/backdrop: layered report pages, spreadsheet grids and folded paper terrain, bright warm paper-world transitioning into ink-navy validation space around the enemy, restrained coral warning lines.
Subjects: exactly three distinct anime heroines. GPT has white/lilac hair, pale dress, horns, tail and a small blue cloud; Claude has long orange hair, orange/black/ivory dress and a book; DeepSeek has long deep-blue hair, navy-and-white maid-like dress and whale-tail motifs. Preserve each reference identity and palette. They stand as compact game units, not giant character art.
Character staging: the team occupies the left 42% of the battlefield in a readable shallow triangular formation. At idle scale each character is approximately 210–240 screen pixels tall in a 1280×720 target, with no character exceeding 34% of screen height. GPT temporarily advances toward the center and is only about 15% larger while acting. Claude and DeepSeek remain visible and unobscured. Each has a small attached status strip at her feet with portrait-color accent, token pips, shield and acted state. GPT’s selected status is shown by a cyan segmented circle under her feet.
Enemy: the Missing Attachment construct occupies the right 28%: a floating file-box/envelope machine with a paperclip-shaped hollow center, searching cables, clipped paper edges, grounded shadow and an intent icon above it showing 2 damage aimed at GPT. Original task-problem creature, no gore.
Shared hand: one continuous shared hand tray spans the entire bottom 31% of the screen. Show seven overlapping but readable 5:7 illustrated cards in natural draw order, visibly mixed rather than separated into character groups. Include neutral common cards plus a GPT card with pale-lilac/cyan owner ribbon, a Claude card with orange owner ribbon and small book crest, and a DeepSeek card with deep-blue/teal owner ribbon and small whale crest. Exclusive cards show a small owner portrait/crest in the upper-right corner; common cards use a neutral paper-white crest. A clear small label reads “共享手牌”. The currently usable cards for GPT are bright; Claude- and DeepSeek-exclusive cards are still visible but gently dimmed because GPT is acting. Do not split the hand into three zones.
Card-action link: the selected GPT attack card rises from the shared hand with a cyan outline; a segmented cyan path leaves the card, passes through GPT’s casting hand and strikes the enemy. This visually connects card selection, acting character and target. Keep two compact permanent basic-action tiles to the far left of the hand.
Style/medium: shippable practical 2D anime game UI mockup, painted illustrations combined with crisp deterministic-looking UI; warm paper, matte glass, soft shadows, subtle data particles; not poster art.
Composition/framing: 16:9 landscape game screen. Slim top bar with “回合 1”. Battle stage 57% high, shared hand 31% high. Enemy name and HP near its base. End-turn button at lower right. Maintain generous empty effect corridor between the compact team and enemy.
Lighting/mood: neutral readable key light on all three characters and cards; warm paper daylight on the left; restrained coral threat light near enemy.
Color palette: ink navy #0A101B, paper white #F2EFE7, cool cyan #69D7E7, warm amber #F2B85B, coral red #EF6A62, role accents from the references.
Text (verbatim where legible): “回合 1”, “缺失附件”, “共享手牌”, “TOKEN”, “结束回合”. Avoid long body text.
Constraints: exactly three heroines and one enemy; no character may dominate the screen; all three faces and silhouettes readable; hand is shared and mixed; card ownership, current actor and target are visually distinct; card art occupies about half each card; practical UI hierarchy; no blood, no logos, no watermark.
Avoid: giant single-character composition, separate hands per character, three separate card columns, text-only buttons, oversized portraits, characters hidden behind cards, generic fantasy weapons, neon cyberpunk city, code rain, excessive glow, direct imitation of another game’s specific assets.
```

## 定向修正

1. 将三名角色统一缩小约 20%，保持脚底状态条和地面位置正确，扩大中央特效通道。
2. 将三张专属牌标题分别校正为“`一鼓作气`”“`最小改动`”“`稳住火候`”，其余画面保持不变。

## 本轮验收

- 三名角色能同时留在场内，均有独立状态条，不再由单个角色占据半屏。
- 共享手牌保持一个连续区域，通用牌和三种角色专属牌按抽牌顺序混排。
- 专属牌以角色色、头像或徽记表达归属；归属不等同于当前行动者。
- GPT 作为当前行动者短暂前移，选中牌经角色动作连到敌人，形成“牌—人—目标”的关系。
- 概念图的小字和装饰图标不作为最终 UI 资产；实装必须由 Godot 确定性排版。
