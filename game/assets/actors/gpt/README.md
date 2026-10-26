# GPT 正式分层立绘 v1

生成日期：2026-10-26  
生成方式：Codex 内置 `image_gen`，透明背景模式。

## 身份基准

- 主身份图：`角色设定/美术/GPT/gpt.webp`
- 三视图：`角色设定/美术/GPT/gpt-reference.webp`
- 当前形态：白龙形态；没有使用 Astra 或 Image2 进化外观。

## 文件

- `gpt_master_v1.png`：正式全身母版，不直接承担逐部件动作。
- `gpt_parts_sheet_v1.png`：2 列 × 3 行透明拆件源表。
- `gpt_white_dragon_v1.p2l`：PSD2Live 基础工程；以全身母版建立，包含自动生成的网格、标准变形器和 20 个参数。
- `layers/gpt_back_v1.png`：后发、翼、尾。
- `layers/gpt_body_v1.png`：无头无臂的身体、主裙和腿。
- `layers/gpt_head_v1.png`：头、角、耳和面部发丝。
- `layers/gpt_near_arm_v1.png`：靠近胸前的手臂与袖子。
- `layers/gpt_prop_v1.png`：前伸施法手、小蓝云和魔法轨迹。
- `layers/gpt_front_v1.png`：前发、腰链、前裙和垂饰。
- `res://tools/slice_gpt_parts.gd`：按固定网格重复裁切源表。

## PSD2Live 工程说明

- 画布：1003 × 1568，与 `gpt_master_v1.png` 一致。
- 当前结构：1 个全身母版网格、7 个基础变形器、20 个标准参数；已验证从磁盘重新打开后，默认姿态与多参数组合可正常渲染。受单图层素材限制，面部、手臂、翼尾和发丝参数目前主要作为后续拆层绑定骨架。
- 六件拆分表的各格不是同一坐标系下可直接叠合的切片，其中后发、翼和尾为背视组合，因此暂作为精修参考，不直接叠入工程。
- 后续若要制作面部细动、手臂施法、翼尾物理和发丝物理，应先补充同一画布、同一视角、遮挡区域完整的正式拆层素材，再在此工程上替换或追加图层。

## 实机比例

- 1280 × 720 基准画面下，可见高度约 300 px。
- 身体核心宽度约 150 px；翼、发尾和魔法允许扩展至约 195—205 px。
- 三人队脚底视觉基线约为 y=395；状态条从 y=372 起覆盖裙摆末端。
- 点击热区保持 178 × 326 px，透明素材可越界但不能侵入手牌标题区。

## 最终提示词：全身母版

```text
Use case: stylized-concept
Asset type: production-ready 2D game character master for a layered battle puppet
Input images: Image 1 is the authoritative GPT identity and costume reference; Image 2 is the authoritative front/side/back proportion reference.
Primary request: Create a polished full-body neutral battle pose of the same GPT white-dragon woman, suitable as the master image for later layer extraction.
Subject: preserve her exact identity: long white-lavender hair, pale lavender eyes, two white scaled dragon horns, pointed elf ears, elegant pure-white high-neck asymmetrical long dress with lavender shadows and ruffled detached sleeves, silver diamond jewelry, interwoven rosette ornaments, compact pale-lavender batlike dragon wings, and a long white scaled dragon tail. Include the tiny friendly blue cloud companion hovering near her raised forward hand.
Pose: three-quarter view facing screen-right, calm confident expression, weight balanced on the back leg, forward hand open and slightly extended as if beginning a structured spell, other hand near the chest. Keep both arms clearly separated from the torso, wings separated from hair, and tail readable behind the dress so the artwork can be split into animation layers.
Style/medium: premium anime-style 2D game character illustration, crisp clean linework, refined cel shading with soft painterly highlights, production character art rather than sketch or concept sheet.
Composition/framing: single full body from horn tips to shoes, centered on a tall transparent canvas, generous clear padding around horns, wings, sleeves, tail, feet and cloud. No cropping. Her body silhouette should remain relatively narrow for a three-character horizontal battle formation.
Lighting/mood: luminous cool daylight, composed and helpful, subtle cyan-blue magic glow only around the forward hand and cloud.
Color palette: pearl white, pale lavender, cool silver, restrained cyan-blue accents; do not turn the outfit dark.
Constraints: preserve the reference face, hairstyle, costume design, ornaments, wings and tail; one character only; genuinely transparent background; clean alpha edges; no floor, no environment, no UI, no text, no watermark. Avoid motion blur, extreme perspective, oversized wings, spread-eagle pose, extra limbs, extra fingers, extra horns, detached anatomy, or cropped feet.
```

## 最终提示词：六件拆分表

```text
Use case: stylized-concept
Asset type: transparent 2D cutout-animation parts sheet for a game character
Input images: Image 1 is the authoritative GPT character master. Preserve this exact identity, costume, palette and three-quarter screen-right orientation.
Primary request: Create one clean 2-column by 3-row parts sheet containing exactly six isolated animation components of the same character, each centered inside its own equal cell and not touching any other cell.
Cell layout, exact: top-left rear assembly; top-right headless and armless main body; middle-left head assembly; middle-right near-chest arm; bottom-left forward casting arm with cloud; bottom-right front overlay.
Style/medium: same premium anime-style 2D game art as the master, crisp linework and refined cool cel shading.
Composition/framing: orthographic asset sheet, consistent component scale derived from the master, generous transparent padding inside every cell. No character assembled anywhere; only the six separated components.
Constraints: genuinely transparent background; no grid lines, labels, text, watermark or extra parts. Keep all components in the same three-quarter screen-right orientation. Do not show the character from the back. Do not redesign the outfit. No cropped component edges, no extra limbs, no duplicate hands, no full-body figure.
```
