// v0.4 design fixture: persistent individual accounts, not a playable game.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
let checks = 0;
const eq = (a, b, m) => { assert.deepEqual(a, b, m); checks++; };
const ok = (v, m) => { assert.ok(v, m); checks++; };
const throws = (f, m) => { assert.throws(f, new RegExp(m)); checks++; };
const defs = {
  A: { name: '标准指令', kind: 'attack', cost: 1, damage: 6 },
  D: { name: '防护指令', kind: 'guard', cost: 0, shield: 4 },
  H: { name: '强力指令', kind: 'attack', cost: 2, damage: 10 },
  R: { name: '应急补给', kind: 'supply', cost: 0, heal: 2, consume: true },
  T: { name: '额度转交', kind: 'transfer', cost: 2, heal: 2 },
  GA: { name: 'GPT专属攻击', owner: 'GPT', kind: 'attack', cost: 1, damage: 6 },
  CD: { name: 'Claude专属防护', owner: 'Claude', kind: 'guard', cost: 0, shield: 4 },
  KA: { name: '通读', owner: 'Kimi', kind: 'attack', tag: '分析', cost: 1, damage: 4 },
  KG: { name: '落笔', owner: 'Kimi', kind: 'attack', tag: '生成', cost: 1, damage: 6 },
  KV: { name: '校稿', owner: 'Kimi', kind: 'guard', tag: '校验', cost: 0, shield: 4 },
};
const defaultDeck = ['A', 'D', 'H', 'R', 'T', 'A', 'A', 'H', 'D', 'A', 'D', 'A'];
const prior = { 分析: '校验', 生成: '分析', 校验: '生成' };
function roster(balances = { GPT: 12, Claude: 12 }) {
  return { accounts: Object.fromEntries(Object.entries(balances).map(([id, token]) =>
    [id, { id, role: id, token, maxToken: 12 }])), settled: new Set(), usedServices: new Set() };
}
const balances = r => Object.fromEntries(Object.entries(r.accounts).map(([id, a]) => [id, a.token]));
function start(r, id, ids = ['GPT', 'Claude'], options = {}) {
  if (r.settled.has(id)) throw new Error('already_settled');
  if (ids.length < 1 || ids.length > 3 || new Set(ids).size !== ids.length) throw new Error('invalid_lineup');
  if (ids.some(id => !r.accounts[id] || r.accounts[id].token <= 0)) throw new Error('exhausted_lineup');
  const allCards = (options.deck || defaultDeck).map((code, i) => ({ id: `${id}_c${i + 1}`, code, born: 0 }));
  const deck = allCards.filter(c => !defs[c.code].owner || ids.includes(defs[c.code].owner));
  return { id, roster: r, entered: balances(r), turn: 0, hp: options.hp ?? 26, baseDamage: options.damage ?? 4,
    targetOrder: options.targets || ids, attacks: [], seed: 42, stage: 'between', result: 'ongoing',
    draw: deck, hand: [], discard: [], consumed: [], sealed: [], total: deck.length, actions: [], log: [],
    actors: ids.map(id => ({ id, role: r.accounts[id].role, account: r.accounts[id], online: true, acted: false,
      shield: 0, streak: 0, counter: false, rice: 0, protected: null, records: [] })) };
}
function actor(s, id) { const a = s.actors.find(a => a.id === id); if (!a) throw new Error('not_in_battle'); return a; }
function verify(s) {
  const cards = [...s.draw, ...s.hand, ...s.discard, ...s.consumed, ...s.sealed, ...s.actors.flatMap(a => a.records)];
  eq(cards.length, s.total, 'card entity count conserved');
  eq(new Set(cards.map(c => c.id)).size, s.total, 'one card in one zone');
  for (const a of Object.values(s.roster.accounts)) ok(a.token >= 0 && a.token <= a.maxToken, 'individual account range');
  for (const a of s.actors) { ok(a.shield >= 0, 'nonnegative personal shield'); ok(a.records.length <= 2, 'private records bounded'); }
}
function shuffle(s) {
  s.draw = s.discard.splice(0);
  for (let i = s.draw.length - 1; i > 0; i--) {
    s.seed ^= s.seed << 13; s.seed ^= s.seed >>> 17; s.seed ^= s.seed << 5;
    const j = (s.seed >>> 0) % (i + 1); [s.draw[i], s.draw[j]] = [s.draw[j], s.draw[i]];
  }
}
function begin(s) {
  if (s.stage !== 'between' || s.result !== 'ongoing') throw new Error('invalid_start');
  s.turn++; s.stage = 'actions'; s.actions = [];
  for (const a of s.actors) { a.acted = false; a.shield = 0; a.protected = null; }
  while (s.hand.length < 5) {
    if (!s.draw.length) shuffle(s);
    if (!s.draw.length) break;
    s.hand.push(s.draw.shift());
  }
  const offset = (s.turn - 1) % s.targetOrder.length;
  const order = [...s.targetOrder.slice(offset), ...s.targetOrder.slice(0, offset)];
  const target = order.find(id => s.actors.some(a => a.id === id && a.online));
  s.attacks = target ? [{ target, raw: s.baseDamage + Math.floor((s.turn - 1) / 3) }] : [];
  verify(s);
}
function act(s, id, code, options = {}) {
  const a = actor(s, id);
  if (!a.online || a.acted || s.stage !== 'actions' || s.result !== 'ongoing') throw new Error('action_unavailable');
  const basic = code === 'basic' || code === 'guard';
  const index = basic ? -1 : s.hand.findIndex(c => c.code === code);
  if (!basic && index < 0) throw new Error(`not_in_hand_${id}_${s.turn}_${code}`);
  const c = basic ? null : s.hand[index];
  const d = basic ? (code === 'basic' ? { name: '基础攻击', kind: 'attack', cost: 0, damage: 3 }
    : { name: '基础防御', kind: 'guard', cost: 0, shield: 3 }) : defs[code];
  if (d.owner && d.owner !== id) throw new Error('wrong_owner');
  let target = a;
  if (['guard', 'supply', 'transfer'].includes(d.kind)) {
    target = actor(s, options.target || id);
    if (!target.online) throw new Error('offline_target');
    if (basic && target !== a) throw new Error('basic_guard_is_self');
  }
  if (d.kind === 'transfer' && (target === a || target.account.maxToken - target.account.token < 2)) throw new Error('invalid_transfer');
  let record = null;
  if (options.record) {
    if (id !== 'Kimi' || d.owner !== id || !d.tag) throw new Error('private_records_only');
    record = a.records.find(c => c.id === options.record && c.born < s.turn && defs[c.code].tag === prior[d.tag]);
    if (!record) throw new Error('record_unavailable');
  }
  const cost = Math.max(0, d.cost - Number(Boolean(record && d.tag === '分析')));
  if (a.account.token - cost < 1) throw new Error('insufficient_personal_token');
  let damage = d.damage || 0, bonus = 0;
  if (id === 'GPT') {
    if (!basic && d.kind === 'attack') { bonus += a.streak * 2; a.streak = Math.min(2, a.streak + 1); }
    else a.streak = 0;
  }
  if (id === 'Claude' && d.kind === 'attack' && a.counter) { bonus += 4; a.counter = false; }
  if (id === 'DeepSeek' && !basic && d.kind === 'attack' && d.cost >= 2 && a.rice === 3) { bonus += 6; a.rice = 0; }
  if (record && d.tag === '生成') bonus += 3;
  damage += bonus;
  a.account.token -= cost;
  let actualHeal = 0;
  if (d.heal) { actualHeal = Math.min(d.heal, target.account.maxToken - target.account.token); target.account.token += actualHeal; }
  if (record && d.tag === '校验') { const heal = Math.min(1, a.account.maxToken - a.account.token); a.account.token += heal; actualHeal += heal; }
  if (d.shield) { target.shield += d.shield; a.protected = target.id; }
  s.hp = Math.max(0, s.hp - damage);
  if (record) { a.records.splice(a.records.indexOf(record), 1); s.consumed.push(record); }
  if (c) {
    s.hand.splice(index, 1);
    if (d.consume) s.consumed.push(c);
    else if (d.owner === 'Kimi' && d.tag) {
      c.born = s.turn; a.records.push(c); while (a.records.length > 2) s.discard.push(a.records.shift());
    } else s.discard.push(c);
  }
  a.acted = true;
  s.actions.push({ actor: id, action: d.name, target: d.kind === 'attack' ? 'enemy' : target.id, cost, damage, bonus, actualHeal });
  if (!s.hp) s.result = 'win';
  verify(s);
}
function offline(s, a) {
  a.online = false; a.shield = 0; a.streak = 0; a.counter = false; a.rice = 0; a.protected = null;
  for (const zone of ['draw', 'hand', 'discard']) {
    const kept = [];
    for (const c of s[zone]) (defs[c.code].owner === a.id ? s.sealed : kept).push(c);
    s[zone] = kept;
  }
  s.sealed.push(...a.records.splice(0));
  if (!s.actors.some(a => a.online)) s.result = 'loss';
}
function hit(s, id, raw) {
  const a = actor(s, id);
  if (!a.online) return { target: id, raw, absorbed: 0, lost: 0, skipped: true };
  const absorbed = Math.min(raw, a.shield);
  a.shield -= absorbed;
  const lost = Math.min(a.account.token, raw - absorbed);
  a.account.token -= lost;
  if (!a.account.token) offline(s, a);
  verify(s);
  return { target: id, raw, absorbed, lost, skipped: false };
}
function finish(s) {
  const events = [];
  if (s.result === 'ongoing') {
    for (const intent of s.attacks) {
      if (s.result !== 'ongoing') break;
      events.push(hit(s, intent.target, intent.raw));
    }
  }
  for (const a of s.actors) {
    if (!a.online) continue;
    if (a.id === 'GPT' && !a.acted) a.streak = 0;
    if (s.result === 'ongoing') {
      if (a.id === 'Claude' && a.protected && events.some(e => e.target === a.protected && e.absorbed > 0)) a.counter = true;
      if (a.id === 'DeepSeek') a.rice = Math.min(3, a.rice + 1);
    }
  }
  s.discard.push(...s.hand.splice(0));
  for (const a of s.actors) a.shield = 0;
  s.stage = 'between';
  s.log.push({ turn: s.turn, actions: s.actions, enemyEvents: events, enemyHp: s.hp, balances: balances(s.roster),
    online: s.actors.filter(a => a.online).map(a => a.id), result: s.result });
  verify(s);
}
function settle(s) {
  if (s.result !== 'win') throw new Error('no_victory');
  if (s.roster.settled.has(s.id)) return false;
  const before = balances(s.roster);
  for (const a of Object.values(s.roster.accounts)) if (a.token > 0) a.token = Math.min(a.maxToken, a.token + 3);
  s.roster.settled.add(s.id);
  s.settlement = { before, after: balances(s.roster) };
  return true;
}
function rest(r, nodeId, id) {
  if (r.usedServices.has(nodeId)) throw new Error('rest_already_used');
  const a = r.accounts[id];
  a.token = Math.min(a.maxToken, a.token + 6); r.usedServices.add(nodeId);
}
function play(s, plan) {
  for (const actions of plan) {
    if (s.result !== 'ongoing') break;
    begin(s);
    for (const [id, code, target] of actions) { if (s.result !== 'ongoing') break; act(s, id, code, { target }); }
    finish(s);
  }
  return s;
}
const protectPlan = [ [['GPT', 'A'], ['Claude', 'D', 'GPT']], [['GPT', 'A'], ['Claude', 'A']], [['GPT', 'A']] ];
const r = roster();
const first = play(start(r, 'route_1'), protectPlan);
eq([first.result, first.turn, balances(r)], ['win', 3, { GPT: 9, Claude: 7 }], 'first fight personal budget');
settle(first); eq(balances(r), { GPT: 12, Claude: 10 }, 'first victory capped personal recovery');
const second = start(r, 'route_2', ['GPT', 'Claude'], { targets: ['Claude', 'GPT'] });
eq(second.entered, { GPT: 12, Claude: 10 }, 'next battle does not refill');
play(second, [ [['GPT', 'A'], ['Claude', 'D', 'Claude']], [['GPT', 'A'], ['Claude', 'A']], [['GPT', 'A']] ]);
eq([second.result, balances(r)], ['win', { GPT: 5, Claude: 9 }], 'second fight carries injured balance');
settle(second); eq(balances(r), { GPT: 8, Claude: 12 }, 'attrition shifts between individuals');
const beforeDuplicate = balances(r);
eq(settle(second), false, 'same victory cannot recover twice'); eq(balances(r), beforeDuplicate, 'no duplicate gain');
throws(() => start(r, 'route_2'), 'already_settled');

const rr = roster();
const rush = play(start(rr, 'rush'), [ [['GPT', 'A'], ['Claude', 'H']], [['GPT', 'A'], ['Claude', 'basic']] ]);
eq([rush.result, rush.turn, balances(rr)], ['win', 2, { GPT: 6, Claude: 10 }], 'faster attack route');
settle(rush); eq(balances(rr), { GPT: 9, Claude: 12 }, 'rush preserves a different actor');

const independent = start(roster({ GPT: 1, Claude: 12 }), 'personal'); begin(independent);
const ledgerBefore = balances(independent.roster);
throws(() => act(independent, 'GPT', 'A'), 'insufficient_personal_token');
eq(balances(independent.roster), ledgerBefore, 'cannot borrow teammate token implicitly');
eq(actor(independent, 'GPT').acted, false, 'illegal payment consumes no action');
act(independent, 'GPT', 'D', { target: 'Claude' });
eq([actor(independent, 'GPT').shield, actor(independent, 'Claude').shield], [0, 4], 'defense belongs to recipient');
const twoHits = [hit(independent, 'Claude', 3), hit(independent, 'Claude', 3)];
eq(twoHits.map(e => [e.absorbed, e.lost]), [[3, 0], [1, 2]], 'shield consumed once across multiple hits');
eq(balances(independent.roster), { GPT: 1, Claude: 10 }, 'damage only affects target');

const tr = start(roster({ GPT: 3, Claude: 7 }), 'transfer'); begin(tr);
const totalBefore = Object.values(balances(tr.roster)).reduce((a, b) => a + b, 0);
act(tr, 'GPT', 'T', { target: 'Claude' });
eq(balances(tr.roster), { GPT: 1, Claude: 9 }, 'explicit equal transfer');
eq(Object.values(balances(tr.roster)).reduce((a, b) => a + b, 0), totalBefore, 'transfer creates no token');

const supply = start(roster({ GPT: 5, Claude: 8 }), 'supply'); begin(supply);
act(supply, 'GPT', 'R', { target: 'Claude' });
eq(balances(supply.roster), { GPT: 5, Claude: 10 }, 'supply recovers recipient only');
eq(supply.consumed.filter(c => c.code === 'R').length, 1, 'supply is consumed');
finish(supply); begin(supply);
ok(![...supply.draw, ...supply.hand, ...supply.discard].some(c => c.code === 'R'), 'supply cannot reshuffle');

const downRoster = roster({ GPT: 2, Claude: 9, DeepSeek: 0 });
const down = start(downRoster, 'one_down', ['GPT', 'Claude'], { hp: 3, deck: [...defaultDeck, 'GA', 'CD'] }); begin(down);
actor(down, 'GPT').streak = 2;
hit(down, 'GPT', 2);
eq([down.result, actor(down, 'GPT').online, actor(down, 'GPT').streak], ['ongoing', false, 0], 'one down is not party defeat');
ok(down.sealed.some(c => c.code === 'GA'), 'offline exclusive cards are sealed');
ok(![...down.draw, ...down.hand, ...down.discard].some(c => c.code === 'GA'), 'offline cards no longer drawable');
throws(() => act(down, 'Claude', 'R', { target: 'GPT' }), 'offline_target');
eq(hit(down, 'GPT', 99).skipped, true, 'locked attack does not retarget after down');
act(down, 'Claude', 'basic'); finish(down); settle(down);
eq(balances(downRoster), { GPT: 0, Claude: 12, DeepSeek: 0 }, 'exhausted actors do not revive for free');
throws(() => start(downRoster, 'before_rescue', ['GPT']), 'exhausted_lineup');
rest(downRoster, 'rescue_node', 'GPT');
const revived = start(downRoster, 'after_down', ['GPT']);
eq(actor(revived, 'GPT').account.token, 6, 'rest revives to its stated amount, not full 12');

const lostRoster = roster({ GPT: 1, Claude: 12 });
const lost = start(lostRoster, 'loss', ['GPT']); begin(lost); hit(lost, 'GPT', 1);
eq(lost.result, 'loss', 'all active down fails despite healthy reserve');
throws(() => settle(lost), 'no_victory');
eq(balances(lostRoster), { GPT: 0, Claude: 12 }, 'failure gives no recovery');
throws(() => start(lostRoster, 'zero_start', ['GPT']), 'exhausted_lineup');

const soloRoster = roster({ base: 12 });
const soloPlan = [[['base', 'A']], [['base', 'D']], [['base', 'H']], [['base', 'A']]];
const solo = play(start(soloRoster, 'solo_1', ['base'], { hp: 18, damage: 2 }), soloPlan);
eq([solo.result, balances(soloRoster)], ['win', { base: 4 }], 'single actor fight without records');
settle(solo); eq(balances(soloRoster), { base: 7 }, 'single actor has finite attrition');
const withoutRestRoster = roster({ base: 7 });
const withoutRest = play(start(withoutRestRoster, 'solo_no_rest', ['base'], { hp: 18, damage: 2 }), soloPlan);
eq([withoutRest.result, withoutRest.turn], ['loss', 3], 'same low-budget sequence fails without rest');
rest(soloRoster, 'rest_A', 'base'); eq(balances(soloRoster), { base: 12 }, 'rest targets an account and caps');
throws(() => rest(soloRoster, 'rest_A', 'base'), 'rest_already_used');
const rested = play(start(soloRoster, 'solo_2', ['base'], { hp: 18, damage: 2 }), soloPlan);
eq(rested.result, 'win', 'rest restores budget for the same sequence'); settle(rested);

// No automatic per-turn healing and no infinite free basic defense.
const turtle = start(roster({ base: 12 }), 'turtle', ['base'], { hp: 99, damage: 3 });
for (let i = 0; i < 20 && turtle.result === 'ongoing'; i++) {
  begin(turtle); act(turtle, 'base', 'guard'); finish(turtle);
}
eq([turtle.result, turtle.turn], ['loss', 10], 'enemy schedule defeats indefinite free guard');

// A fresh battle resets personal ability state; only account balances persist.
const fresh = start(r, 'new_state');
eq(fresh.actors.map(a => [a.streak, a.counter, a.rice, a.records.length]), [[0, false, 0, 0], [0, false, 0, 0]], 'no ability state leaks between battles');
const capRoster = roster({ GPT: 11, Claude: 6, DeepSeek: 0 });
const cap = start(capRoster, 'caps', ['GPT'], { hp: 1 }); begin(cap); act(cap, 'GPT', 'basic'); finish(cap); settle(cap);
eq(balances(capRoster), { GPT: 12, Claude: 9, DeepSeek: 0 }, 'recovery caps positive reserves but does not revive zero');

// A full-rice mid-battle boundary: only DeepSeek pays for its own enhanced card.
const deep = start(roster({ DeepSeek: 5, GPT: 11 }), 'deep_personal', ['DeepSeek', 'GPT'], { hp: 99 }); begin(deep);
actor(deep, 'DeepSeek').rice = 3;
act(deep, 'DeepSeek', 'H');
eq([balances(deep.roster), deep.actions[0].damage, actor(deep, 'DeepSeek').rice],
  [{ DeepSeek: 3, GPT: 11 }, 16, 0], 'DeepSeek cost and charge remain private');

// Two actual rounds produce a Kimi source, then test self-only refund while shielding a teammate.
const kr = roster({ Kimi: 5, GPT: 9 });
const kimi = start(kr, 'kimi_personal', ['Kimi', 'GPT'], { hp: 99,
  deck: ['KG', 'KA', 'A', 'D', 'R', 'KV', 'A', 'D', 'H', 'T', 'KV', 'KA'] });
begin(kimi); act(kimi, 'Kimi', 'KG'); act(kimi, 'GPT', 'D', { target: 'Kimi' }); finish(kimi);
eq(balances(kr), { Kimi: 4, GPT: 9 }, 'only Kimi paid for its source card');
const recordId = actor(kimi, 'Kimi').records[0].id;
begin(kimi); act(kimi, 'Kimi', 'KV', { target: 'GPT', record: recordId });
eq(balances(kr), { Kimi: 5, GPT: 9 }, 'record refund heals Kimi, not shield recipient or whole party');
eq(actor(kimi, 'GPT').shield, 4, 'shield still goes to the explicitly chosen ally');
finish(kimi);
hit(kimi, 'Kimi', 5);
ok(kimi.consumed.some(c => c.id === recordId), 'consumed source remains consumed after down');
ok(kimi.sealed.some(c => c.code === 'KV'), 'unconsumed private record sealed after down');

// Giving protection creates an effect on the recipient, which survives the caster going offline.
const protectedAfterDown = start(roster(), 'shield_after_down'); begin(protectedAfterDown);
act(protectedAfterDown, 'Claude', 'D', { target: 'GPT' }); hit(protectedAfterDown, 'Claude', 12);
eq(hit(protectedAfterDown, 'GPT', 4).absorbed, 4, 'ally shield persists for this round after caster down');
eq(actor(protectedAfterDown, 'Claude').counter, false, 'offline caster does not earn counter');

function summary(s) { return { id: s.id, entered: s.entered, result: s.result, turns: s.turn,
  settlement: s.settlement || null, log: s.log }; }
const report = { fixtureVersion: 'v0.4', checks,
  scope: '独立个人账户、两场连续战斗、定向防护、支援、下线封存、恢复幂等与单人休息夹具；含DeepSeek预置满层边界和Kimi两回合个人回复片段；固定牌序及洗牌种子42；非可玩游戏，未验证完整地图经济、随机胜率、完整DeepSeek/Kimi专属卡或Boss',
  scenarios: [first, second, rush, solo, withoutRest, rested, turtle, down].map(summary),
  finalRouteBalances: balances(r), finalSoloBalances: balances(soloRoster) };
fs.writeFileSync(path.join(__dirname, '..', 'docs', '独立Token验算结果.json'), JSON.stringify(report, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ checks, route: report.scenarios.map(({ log, ...s }) => s), finalRouteBalances: report.finalRouteBalances }, null, 2));
