from pathlib import Path
import json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
if (ROOT/'docs/全面审阅与修订记录.md').exists():
    raise SystemExit('本轮整理已完成；此脚本含一次性文本替换，后续请编辑当前来源并运行 audit_sources.py。')
old_docs=['玩法完善方案.md','玩法推演.md','角色驱动玩法方案.md','角色玩法推演.md','独立Token与跨战斗玩法方案.md','独立Token玩法推演.md','AI任务视角与高难隐藏Boss方案.md','人生阶段与随机Boss叙事方案.md','角色设定同步记录.md']
for name in old_docs:
    p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8')
    if not s.startswith('> 历史资料'):
        p.write_text('> 历史资料，已由2026-10-24综合整理版取代。当前执行入口：[规则基准](规则基准.md)、[剧情大纲](../剧情大纲.md)、[全面修订记录](全面审阅与修订记录.md)。以下数值、状态和页数仅描述历史轮次。\n\n'+s,encoding='utf-8')
for name in ['剧情大纲_v1.md','剧情大纲_v2.md','剧情大纲_v3.md']:
    p=ROOT/name;s=p.read_text(encoding='utf-8')
    if not s.startswith('> 历史资料'):p.write_text('> 历史资料，保留旧构思供溯源。当前版本请读 [未尽之托剧情大纲](剧情大纲.md)。以下暂名与制作状态不作为当前要求。\n\n'+s,encoding='utf-8')
p=ROOT/'角色设定/性格审阅与轻喜剧调整建议.md';s=p.read_text(encoding='utf-8')
if not s.startswith('> 历史资料'):p.write_text('> 历史资料。轻喜剧方向已结合当前任务视角落实到角色稿；其中共享token、日常行程及旧玩法建议不再执行。当前见 [角色索引](性格/00_索引.md) 与 [规则基准](../docs/规则基准.md)。\n\n'+s,encoding='utf-8')
for p in (ROOT/'角色设定/性格').glob('*.md'):
    s=p.read_text(encoding='utf-8').replace('当前原型每人最多一个插件','当前基础版不启用插件掉落与装配').replace('每个自己在线的回合结束时 +1 层','每个战斗仍进行且自己在线的回合结束时 +1 层')
    p.write_text(s,encoding='utf-8');(ROOT/'_build/src'/p.name).write_text(s,encoding='utf-8')
rows=['# 未尽之托 美术资产清单','','2026-10-24。本轮查看29份图像的联系表，核对角色归属、主图与衍生参考。未改原图；没有宣称完成逐像素绘画质量审查或逐图授权核验。现有来源记录只有角色设定/美术/形象来源.txt所列站点，不能推定每张均来自该页或可直接发行。','','当前图片用途：内部造型参考。以下逐图列出尺寸与用途；取得逐图出处、作者或许可记录后再更新使用范围。正式头像应统一裁切框与清晰度，额外表情和战斗差分仍未制作。','','| 文件 | 尺寸 | 当前用途 | 来源状态 |','| --- | --- | --- | --- |']
for p in sorted((ROOT/'角色设定/美术').rglob('*')):
    if p.suffix.lower()not in ['.png','.webp','.jpg']:continue
    with Image.open(p)as im:w,h=im.size
    extra=any(k in p.stem for k in ['reference','miniseek','harness','astra','image2'])
    rel=p.relative_to(ROOT).as_posix();rows.append(f'| [{p.name}](../{rel}) | {w} × {h} | {"形态或制作参考" if extra else "当前角色主图参考"} | 逐图来源与可用范围待补 |')
rows+=['','来源记录：[项目所列参考站点](https://genderswapai.com/zh-CN/ai-gijinka)。本轮没有据此核实作者或许可；不将角色文本的原创性等同于图片原创性。','',
'## 制作优先级','先为三名首批角色统一头像、安全裁切区、透明边缘与同一视觉尺寸；为token不足、防护、已行动和下线设计非颜色单独可辨的图标。下一轮按实际战斗界面补表情，不因已有进化参考提前扩大卡组范围。']
(ROOT/'docs/美术资产清单.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
print('Historical banners, character consistency, and 29-image asset register updated.')
