# Demo 路线图与 Boss v1 生成记录

生成日期：2026-10-26。使用 Codex 内置 imagegen；两张最终图均已复制到工程目录，原始生成目录不作为运行时依赖。

## 1. 「本次提交版」Boss

- 工程文件：`game/assets/enemies/submit/submit_master_v1.png`
- 用途：第一章 Boss 战透明主立绘；运行时复用通用敌人显示控制器。
- 关键规格：办公物料异化、面向左、纸白/珊瑚红/墨蓝、非人形、无血腥、无可读文字、透明背景。

```text
Use case: stylized-concept
Asset type: 2D game boss cutout for a Godot battle scene
Primary request: Create the boss entity “本次提交版” as a single transparent full-body monster sprite. It is a colossal animated typographic checkpoint gate assembled from layered ivory paper, rigid dark binding boards, rulers, binder clips, paper cutters, and a central coral-red mechanical approval stamp. The silhouette must face left toward the player team and read clearly at medium size.
Scene/backdrop: none; genuine transparent background
Subject: non-human office-material construct, wide monumental gate-like body, three shallow horizontal validation grooves without readable words, central floating red stamp core, loose draft pages and red proofing marks integrated into the silhouette
Style/medium: polished anime game concept art, painterly 2D, crisp cutout edges, production-ready enemy sprite, compatible with warm paper-road fantasy visuals
Composition/framing: centered, landscape-friendly, complete silhouette, facing left, no cropping, generous transparent padding, about 3:2 subject bounds
Lighting/mood: warm morning key light with cool blue-gray paper bounce, strict but not horrific
Color palette: paper white #F2EFE7, coral red #EF6A62, ink navy #0A101B, muted metal gray, small mint green accents
Constraints: office materials only; no human or humanoid; no blood; no gore; no real logos; no readable text; no watermark; transparent background; strong left-facing battle silhouette
Avoid: cyberpunk neon, photorealism, generic robot, castle architecture, duplicate limbs, random letters, black rectangular background
```

## 2. 第一章路线图

- 工程文件：`game/assets/maps/chapter1_route_v1.png`
- 用途：第一章路线图背景；节点名称、状态和按钮由 Godot 绘制。
- 关键规格：16:9、纸页旷野、从左下到右上的清楚路线、三个留白停靠区、无人物与文字。

```text
Use case: stylized-concept
Asset type: 16:9 chapter map background for a 2D Godot game
Primary request: Create a quiet illustrated route map background for the Demo chapter “纸页旷野”. The world is a warm task-road landscape built from layered sheets of ivory paper, spreadsheet grid roads, graph-shaped terraces, folded page hills, a distant one-page checkpoint gate, and a small rest pavilion made from a sticky note and binder clip.
Scene/backdrop: wide sunrise paper wilderness, readable winding route from lower left to upper right, three broad empty stopping areas for code-drawn encounter buttons
Subject: environment only, no characters, no monsters
Style/medium: polished 2D anime game background, painterly paper diorama, soft tactile paper grain, warm road-movie mood, coherent with a card-battle UI
Composition/framing: 16:9 landscape, route visible and uncluttered, important scenery in upper half, safe empty margins around three route stops, suitable for 1280x720
Lighting/mood: clear warm morning light, hopeful but slightly wistful
Color palette: paper white #F2EFE7, warm amber #F2B85B, cool cyan #69D7E7, deep navy #0A101B, restrained coral #EF6A62
Constraints: no text, no labels, no UI icons, no readable numbers, no logos, no watermark, no people, no vehicles; keep the route and three stopping clear for overlay UI
Avoid: cyberpunk city, photorealism, dense clutter, dark horror, floating characters, written language
```
