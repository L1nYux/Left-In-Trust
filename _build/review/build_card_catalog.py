from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
data = json.loads((ROOT/'docs/首批内容.json').read_text(encoding='utf-8'))
labels = {'damage':'伤害', 'shield':'防护', 'heal':'回复'}
lines = ['# 未尽之托 首批卡牌表', '', '由 [首批内容.json](首批内容.json) 生成，规则 v'+data['version']+'。数值修改请编辑 JSON 后重新生成本表。', '',
         '所有牌占使用者一次行动；专属牌只能由本人使用。费用从本人 token 扣除，支付后至少剩 1。防护为本回合效果，回复不能在战内复活。', '',
         '| ID | 名称 | 归属 | 费用 | 基础效果 | 一次升级增量 |', '| --- | --- | --- | --- | --- | --- |']
for c in data['cards']:
    parts=[]
    if c.get('damage'): parts.append(f'对敌伤害 {c["damage"]}')
    target={'self':'自己','ally':'一名在线己方（可自己）','other':'另一名在线己方'}.get(c.get('target'),'自己')
    if c.get('shield'): parts.append(f'{target}防护 {c["shield"]}')
    if c.get('heal'): parts.append(f'{target}回复 {c["heal"]}')
    if c.get('fullStreakBonus'): parts.append(f'出牌前满连击时另加伤害 {c["fullStreakBonus"]}')
    if c.get('riceGain'): parts.append(f'行动时白饭 +{c["riceGain"]}（最多3层）')
    if c.get('cashRice'): parts.append('每层白饭另加2伤害后清空，不叠通用满层加成')
    if c.get('consume'): parts.append('本战消耗；整套牌组最多1份')
    if c.get('kind')=='transfer': parts.append('目标至少缺2；总 token 不增加；至少两人入队才进奖励池')
    up='；'.join(f'{labels[k]} +{v}'+('（给转交目标）' if c['id']=='T' and k=='shield' else '') for k,v in c['upgrade'].items())
    lines.append(f'| {c["id"]} | {c["name"]} | {c.get("owner","通用")} | {c["cost"]} | {"；".join(parts)} | {up} |')
lines += ['', '## 起始牌组与被动', '', '每位开局角色十二张：A×3、D×3、H×2、R×1、本人第一专属×2、第二专属×1。T、V 来自后续奖励。', '',
          '- GPT：攻击卡按出牌前连击层数每层加2伤害，再加一层至最多2；基础动作、非攻击牌和跳过断连击。',
          '- Claude：本回合保护对象实际挡伤且本人仍在线，获得一次反击；下一次攻击的一段 +4，基础攻击可用，最多存一次。',
          '- DeepSeek：仍在进行的在线回合末白饭 +1，最多3；普通费用至少2的攻击在满层时 +6 后清空，S2 按自身提前兑现规则结算。', '',
          '免费基础攻击伤害3；免费基础防御给自己防护3，都占行动，不是牌。更完整的支付、封存、目标和回合顺序见 [战斗规格](战斗规格.md)。', '']
(ROOT/'docs/卡牌表.md').write_text('\n'.join(lines),encoding='utf-8')
print('Generated card catalog:',len(data['cards']))
