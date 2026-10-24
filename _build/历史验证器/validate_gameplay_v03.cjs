// Deterministic design fixture, not a playable game or a complete combat engine.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
let checks = 0;
const eq = (a, b, msg) => { assert.deepEqual(a, b, msg); checks++; };
const ok = (v, msg) => { assert.ok(v, msg); checks++; };
const defs = {
  A: { name: '标准指令', kind: 'attack', cost: 1, damage: 6 },
  D: { name: '防护指令', kind: 'guard', cost: 0, shield: 4 },
  H: { name: '强力指令', kind: 'attack', cost: 2, damage: 10 },
  R: { name: '额度回收', kind: 'support', cost: 0, heal: 3 },
  KA: { name: '通读', owner: 'Kimi', kind: 'attack', tag: '分析', cost: 1, damage: 4 },
  KG: { name: '落笔', owner: 'Kimi', kind: 'attack', tag: '生成', cost: 1, damage: 6 },
  KV: { name: '校稿', owner: 'Kimi', kind: 'guard', tag: '校验', cost: 0, shield: 4 },
};
const prior = { 分析: '校验', 生成: '分析', 校验: '生成' };
function create(roles = ['base'], codes = Array.from({ length: 12 }, (_, i) => ['A', 'D', 'R', 'H'][i % 4])) {
  const deck = codes.map((code, i) => ({ id: `c${i + 1}`, code, born: 0 }));
  const maxToken = { 1: 12, 2: 16, 3: 20 }[roles.length];
  return { turn: 0, maxToken, token: maxToken, hp: 22, shield: 0, draw: deck, hand: [], discard: [],
    consumed: [], total: deck.length, result: 'ongoing', stage: 'between', seed: 42, log: [], roundActions: [],
    actors: roles.map(role => ({ role, acted: false, streak: 0, counter: false, rice: 0,
      defended: false, records: [] })) };
}
function zones(s) {
  const cards = [...s.draw, ...s.hand, ...s.discard, ...s.consumed, ...s.actors.flatMap(a => a.records)];
  eq(cards.length, s.total, 'card entities conserved');
  eq(new Set(cards.map(c => c.id)).size, s.total, 'card zones mutually exclusive');
  ok(s.token >= 0 && s.token <= s.maxToken, 'token bounds');
  for (const actor of s.actors) {
    ok(actor.records.length <= 2, 'private cache cap');
    if (actor.role !== 'Kimi') eq(actor.records.length, 0, 'no records outside Kimi');
  }
}
function shuffle(s) {
  s.draw = s.discard.splice(0);
  for (let i = s.draw.length - 1; i > 0; i--) {
    s.seed ^= s.seed << 13; s.seed ^= s.seed >>> 17; s.seed ^= s.seed << 5;
    const j = (s.seed >>> 0) % (i + 1);
    [s.draw[i], s.draw[j]] = [s.draw[j], s.draw[i]];
  }
}
function begin(s) {
  ok(s.result === 'ongoing' && s.stage === 'between', 'legal round start');
  s.turn++; s.shield = 0; s.roundActions = []; s.stage = 'actions';
  for (const a of s.actors) { a.acted = false; a.defended = false; }
  while (s.hand.length < 5) {
    if (s.draw.length === 0) shuffle(s);
    if (s.draw.length === 0) break;
    s.hand.push(s.draw.shift());
  }
  zones(s);
}
function source(s, a, tag, id) {
  if (a.role !== 'Kimi') throw new Error('private_records_only');
  const c = a.records.find(c => c.id === id && defs[c.code].tag === prior[tag] && c.born < s.turn);
  if (!c) throw new Error('record_unavailable');
  return c;
}
function act(s, role, code, recordId = null) {
  const a = s.actors.find(a => a.role === role);
  if (!a || a.acted || s.stage !== 'actions' || s.result !== 'ongoing') throw new Error('action_unavailable');
  const basic = code === 'basic' || code === 'guard';
  const index = basic ? -1 : s.hand.findIndex(c => c.code === code);
  if (!basic && index < 0) throw new Error(`not_in_hand: ${role} turn ${s.turn}, requested ${code}, available ${s.hand.map(c => c.code).join(',')}`);
  const c = basic ? null : s.hand[index];
  const d = basic ? (code === 'basic' ? { name: '基础攻击', kind: 'attack', cost: 0, damage: 3 }
    : { name: '基础防御', kind: 'guard', cost: 0, shield: 3 }) : defs[code];
  if (d.owner && d.owner !== role) throw new Error('wrong_owner');
  if (recordId && (!d.tag || d.owner !== 'Kimi' || role !== 'Kimi')) throw new Error('private_records_only');
  const record = recordId ? source(s, a, d.tag, recordId) : null;
  const cost = Math.max(0, d.cost - (record && d.tag === '分析' ? 1 : 0));
  if (s.token - cost < 1) throw new Error('illegal_payment');
  let damage = d.damage || 0;
  let bonus = 0;
  if (role === 'GPT') {
    if (!basic && d.kind === 'attack') { bonus += a.streak * 2; a.streak = Math.min(2, a.streak + 1); }
    else a.streak = 0;
  }
  if (role === 'Claude' && d.kind === 'attack' && a.counter) { bonus += 4; a.counter = false; }
  if (role === 'DeepSeek' && !basic && d.kind === 'attack' && d.cost >= 2 && a.rice === 3) {
    bonus += 6; a.rice = 0;
  }
  if (record && d.tag === '生成') bonus += 3;
  damage += bonus;
  s.token -= cost;
  s.token = Math.min(s.maxToken, s.token + (d.heal || 0) + Number(Boolean(record && d.tag === '校验')));
  s.shield += d.shield || 0;
  if (d.kind === 'guard' && d.shield > 0) a.defended = true;
  s.hp = Math.max(0, s.hp - damage);
  if (record) { a.records.splice(a.records.indexOf(record), 1); s.consumed.push(record); }
  if (c) {
    s.hand.splice(index, 1);
    if (d.owner === 'Kimi' && d.tag) {
      c.born = s.turn; a.records.push(c);
      while (a.records.length > 2) s.discard.push(a.records.shift());
    } else s.discard.push(c);
  }
  a.acted = true;
  s.roundActions.push({ role, action: d.name, cost, damage, bonus, record: record ? record.id : null });
  if (s.hp === 0) s.result = 'win';
  zones(s);
}
function finish(s) {
  const raw = s.hp > 0 ? 3 + Math.floor((s.turn - 1) / 3) : 0;
  const absorbed = Math.min(raw, s.shield);
  const incoming = raw - absorbed;
  s.token = Math.max(0, s.token - incoming);
  if (s.result === 'ongoing' && s.token === 0) s.result = 'loss';
  for (const a of s.actors) {
    if (a.role === 'GPT' && !a.acted) a.streak = 0;
    if (s.result === 'ongoing') {
      if (a.role === 'Claude' && a.defended && absorbed > 0) a.counter = true;
      if (a.role === 'DeepSeek') a.rice = Math.min(3, a.rice + 1);
    }
  }
  s.discard.push(...s.hand.splice(0));
  s.shield = 0; s.stage = 'between';
  s.log.push({ turn: s.turn, actions: s.roundActions, raw, absorbed, incoming, token: s.token, enemyHp: s.hp,
    states: s.actors.map(a => ({ role: a.role, streak: a.streak, counter: a.counter, rice: a.rice,
      records: a.records.map(c => ({ id: c.id, tag: defs[c.code].tag, born: c.born })) })), result: s.result });
  zones(s);
}
function run(name, role, plan) {
  const s = create([role]);
  for (let code of plan) {
    if (s.result !== 'ongoing') break;
    begin(s);
    if (code === 'recover_or_guard') code = s.hand.some(c => c.code === 'R') ? 'R' : 'guard';
    act(s, role, code); finish(s);
  }
  return { name, role, result: s.result, turns: s.turn, token: s.token, enemyHp: s.hp, log: s.log };
}
const cases = [
  run('无角色被动的公共攻防', 'base', ['A', 'D', 'H', 'A']),
  run('GPT连续进攻', 'GPT', ['A', 'A', 'H']),
  run('Claude防守反击', 'Claude', ['D', 'A', 'D', 'H']),
  run('DeepSeek运营后爆发', 'DeepSeek', ['A', 'D', 'R', 'H']),
  run('单靠基础攻击', 'base', Array(15).fill('basic')),
  run('单靠基础防御', 'base', Array(15).fill('guard')),
  run('反复回收或防御', 'base', Array(30).fill('recover_or_guard')),
];
eq(cases.slice(0, 4).map(c => [c.result, c.turns, c.token]),
  [['win', 4, 2], ['win', 3, 2], ['win', 4, 6], ['win', 4, 6]], 'four hand-calculated sequences');
eq(cases.slice(4).map(c => c.result), ['loss', 'loss', 'loss'], 'no indefinite basic or recovery spam');

function throws(f, expected) {
  assert.throws(f, new RegExp(expected)); checks++;
}
const pay = create(); begin(pay); pay.token = 1;
const beforePay = JSON.stringify([pay.hand, pay.draw, pay.discard, pay.consumed, pay.actors]);
throws(() => act(pay, 'base', 'A'), 'illegal_payment');
eq(JSON.stringify([pay.hand, pay.draw, pay.discard, pay.consumed, pay.actors]), beforePay, 'illegal payment does not consume anything');
const g = create(['GPT']); begin(g); act(g, 'GPT', 'A');
throws(() => act(g, 'GPT', 'D'), 'action_unavailable'); finish(g);
begin(g); act(g, 'GPT', 'basic'); eq(g.actors[0].streak, 0, 'basic attack does not extend streak'); finish(g);
const noHit = create(['Claude']); begin(noHit); act(noHit, 'Claude', 'D'); noHit.hp = 0; noHit.result = 'win'; finish(noHit);
eq(noHit.actors[0].counter, false, 'no counter without actual enemy damage');
eq(cases[3].log[2].states[0].rice, 3, 'rice only ready after third round');
eq(cases[3].log[3].actions[0].bonus, 6, 'fourth-round heavy consumes rice');
const short = create(['base'], ['A']); begin(short);
eq(short.hand.length, 1, 'small deck draws fewer cards safely');
act(short, 'base', 'basic'); finish(short); begin(short);
eq(short.hand.length, 1, 'discard reshuffles on demand');
const empty = create(['base'], []); begin(empty); act(empty, 'base', 'basic'); finish(empty);
eq(empty.hp, 19, 'empty deck still allows basic attack');

// Isolation of the optional Kimi subsystem in a shared party hand.
const k = create(['Kimi', 'GPT'], ['KA', 'KG', 'KV', 'A', 'D', 'KG', 'KV', 'KA', 'A', 'D', 'R', 'H']);
begin(k); act(k, 'Kimi', 'KA');
const firstRecord = k.actors[0].records[0].id;
throws(() => source(k, k.actors[0], '生成', firstRecord), 'record_unavailable');
throws(() => act(k, 'GPT', 'A', firstRecord), 'private_records_only');
throws(() => act(k, 'GPT', 'KG'), 'wrong_owner');
act(k, 'GPT', 'A'); finish(k);
begin(k); act(k, 'Kimi', 'KG', firstRecord); act(k, 'GPT', 'D'); finish(k);
eq(k.consumed.map(c => c.id), [firstRecord], 'only the selected Kimi card consumed');
eq(k.log[1].actions[0].damage, 9, 'Kimi analysis into generation bonus');
eq(k.actors[1].records.length, 0, 'teammate has no private records');
eq(k.actors[0].records.length, 1, 'current Kimi card replaces consumed source');
const overflow = create(['Kimi'], Array(9).fill('KA'));
for (let i = 0; i < 3; i++) { begin(overflow); act(overflow, 'Kimi', 'KA'); finish(overflow); }
eq(overflow.actors[0].records.map(c => c.born), [2, 3], 'private cache retains two newest');
ok(overflow.discard.some(c => c.born === 1), 'overflow goes to normal discard');
eq(overflow.consumed.length, 0, 'overflow does not consume a card');
const kimiCase = { name: 'Kimi私有记录与队友隔离', roles: ['Kimi', 'GPT'], result: k.result,
  turns: k.turn, token: k.token, enemyHp: k.hp, log: k.log };
const report = { fixtureVersion: 'v0.3', checks,
  scope: '四种公共卡，单人序列与Kimi双人隔离片段；固定初始牌序和洗牌种子42；不含完整角色专属牌、插件、身份、Boss、招募或整局平衡；非可玩游戏',
  cases, kimiIsolation: kimiCase };
fs.writeFileSync(path.join(__dirname, '..', 'docs', '角色玩法验算结果.json'), JSON.stringify(report, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ checks, cases: cases.map(({ log, ...c }) => c), kimiIsolation: { turns: k.turn, token: k.token } }, null, 2));
