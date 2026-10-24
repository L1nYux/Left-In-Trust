// Narrow deterministic design fixture; this is not the game's combat engine.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const types = {
  A: { name: '检索脉冲', tag: '分析', cost: 1, damage: 3 },
  G: { name: '定稿输出', tag: '生成', cost: 1, damage: 5 },
  V: { name: '一致性校验', tag: '校验', cost: 0, damage: 0, reduction: 2 },
  S: { name: '孤注一掷', tag: '生成', cost: 3, damage: 14, strong: true },
};
const requiredSource = { 分析: '校验', 生成: '分析', 校验: '生成' };
const fixtureDeck = () => Array.from({ length: 12 }, (_, i) => ({
  id: `card_${i + 1}`, type: ['A', 'G', 'V'][i % 3], born: null,
}));
let assertions = 0;
function check(value, message) { assert.ok(value, message); assertions++; }
function equal(actual, expected, message) { assert.deepEqual(actual, expected, message); assertions++; }
function verifyZones(s) {
  const all = [...s.deck, ...s.window, ...s.cache, ...s.forgotten];
  equal(all.length, s.total, 'entity count conserved');
  equal(new Set(all.map(c => c.id)).size, s.total, 'entity belongs to one zone');
  check(s.cache.length <= 4, 'cache bounded');
  check(s.token >= 0 && s.token <= s.maxToken, 'token bounds');
}
function init(hp = 22, token = 6) {
  const deck = fixtureDeck();
  return { hp, token, maxToken: 6, turn: 0, total: deck.length, deck,
    window: [], cache: [], forgotten: [], log: [], result: 'ongoing' };
}
function sourceFor(s, tag) {
  return s.cache.find(c => types[c.type].tag === requiredSource[tag] && c.born < s.turn);
}
function step(s, action, comboEnabled = true) {
  check(s.result === 'ongoing', 'battle is ongoing');
  s.turn++;
  s.window = s.deck.splice(0, 5);
  let damage = 0, reduction = 0, overloaded = false;
  let cost = 0, heal = 0, source = null, card = null;
  const high = action.temp === 'high';
  if (action.type === 'basic') damage = 2;
  else if (action.type === 'defend') reduction = 1;
  else {
    const index = s.window.findIndex(c => c.type === action.type);
    check(index >= 0, `requested ${action.type} is actually in the loaded window`);
    card = s.window[index];
    const def = types[card.type];
    source = comboEnabled && action.combo !== false ? sourceFor(s, def.tag) : null;
    cost = Math.max(0, def.cost - (source && def.tag === '分析' ? 1 : 0));
    if (s.token - cost < 1) {
      // Opening the window was legal; no payment, source consumption, or card effect occurred.
      s.deck.push(...s.window.splice(0));
      s.result = 'illegal_payment';
      s.log.push({ turn: s.turn, action: def.name, result: s.result, token: s.token });
      verifyZones(s);
      return;
    }
    s.token -= cost;
    s.window.splice(index, 1);
    if (source) {
      s.cache.splice(s.cache.indexOf(source), 1);
      s.forgotten.push(source);
    }
    damage = def.damage + (source && def.tag === '生成' ? 3 : 0);
    reduction = def.reduction || 0;
    heal = source && def.tag === '校验' ? 1 : 0;
    s.token = Math.min(s.maxToken, s.token + heal);
    overloaded = high && def.tag === '生成' && damage > 0;
    if (overloaded) damage += 2;
    card.born = s.turn;
    (def.strong ? s.forgotten : s.cache).push(card);
    while (s.cache.length > 4) s.forgotten.push(s.cache.shift());
  }
  s.hp = Math.max(0, s.hp - damage);
  // An enemy intent schedule, using the existing turn counter rather than a new meter.
  const rawEnemyDamage = s.turn < 6 ? 1 : 2 + Math.floor((s.turn - 6) / 3);
  const incoming = s.hp > 0 ? Math.max(0, rawEnemyDamage + Number(overloaded) - reduction) : 0;
  s.token = Math.max(0, s.token - incoming);
  if (s.hp === 0) s.result = 'win';
  else if (s.token === 0) s.result = 'loss';
  s.deck.push(...s.window.splice(0));
  s.log.push({ turn: s.turn, action: card ? types[card.type].name : action.type,
    temp: high ? '高温' : '低温', source: source ? source.id : null,
    cost, damage, heal, rawEnemyDamage, incoming, enemyHp: s.hp, token: s.token,
    cache: s.cache.map(c => `${c.id}:${types[c.type].tag}`), result: s.result });
  verifyZones(s);
}
function run(name, hp, actions, comboEnabled = true) {
  const s = init(hp);
  for (const a of actions) {
    if (s.result !== 'ongoing') break;
    step(s, typeof a === 'string' ? { type: a } : a, comboEnabled);
  }
  return { name, initialHp: hp, result: s.result, turns: s.turn,
    token: s.token, enemyHp: s.hp, forgotten: s.forgotten.length, log: s.log };
}
const cycle = ['A', 'G', 'V', 'A', 'G', 'V', 'A', 'G'];
const cases = [
  run('低温接力对22生命', 22, cycle),
  run('全程基础攻击对22生命', 22, Array(12).fill('basic')),
  run('连续生成强攻对22生命', 22, Array(4).fill('G')),
  run('相同序列关闭接力对22生命', 22, cycle, false),
  run('高温提前击杀13生命', 13, ['A', { type: 'G', temp: 'high' }]),
  run('低温击杀13生命', 13, ['A', 'G', 'basic']),
  run('过早高温对22生命', 22, ['A', { type: 'G', temp: 'high' }, 'V', 'A', 'G']),
  run('全程基础防御不能无限等待', 22, Array(20).fill('defend')),
];
equal([cases[0].result, cases[0].turns, cases[0].token], ['win', 5, 1], 'five-turn sample');
equal(cases[0].forgotten, 4, 'four distinct source cards were forgotten');
equal([cases[1].result, cases[1].turns], ['loss', 6], 'basic spam cannot win this fixture');
equal([cases[2].result, cases[2].turns], ['loss', 3], 'generator spam cannot win this fixture');
equal([cases[3].result, cases[3].turns], ['loss', 4], 'same sequence without combos loses');
equal([cases[4].result, cases[4].turns, cases[4].token], ['win', 2, 3], 'high temp can finish earlier');
equal([cases[5].result, cases[5].turns, cases[5].token], ['win', 3, 2], 'low temp alternative');
equal([cases[6].result, cases[6].turns, cases[6].token], ['illegal_payment', 5, 1], 'early high temp has a later cost');
equal([cases[7].result, cases[7].turns, cases[7].enemyHp], ['loss', 10, 22], 'defending forever loses to scheduled damage');

// Edge checks apply to the fixture only, not unimplemented production features.
const sameTurn = init();
sameTurn.turn = 2;
sameTurn.cache.push({ id: 'same_turn', type: 'A', born: 2 });
equal(sourceFor(sameTurn, '生成'), undefined, 'new record unavailable in same turn');
sameTurn.cache[0].born = 1;
check(Boolean(sourceFor(sameTurn, '生成')), 'prior-turn record available');
const pay = init(22, 3);
pay.deck[0].type = 'S';
step(pay, { type: 'S' });
equal([pay.result, pay.token, pay.forgotten.length], ['illegal_payment', 3, 0], 'no suicide payment or effect');
const strong = init(99);
strong.deck[0].type = 'S';
step(strong, { type: 'S' });
equal([strong.cache.length, strong.forgotten.length], [0, 1], 'strong card creates no record');
const overflow = init(99);
for (const type of ['A', 'G', 'V', 'A', 'G']) {
  // Raised token is just to reach overflow independently of survival balance.
  overflow.token = 6;
  step(overflow, { type, combo: false });
}
equal([overflow.cache.length, overflow.forgotten.length], [4, 1], 'oldest cache card forgotten on overflow');
equal(overflow.forgotten[0].born, 1, 'FIFO chooses oldest record');

const report = { fixtureVersion: 'v0.2', assertions, scope: '单角色，无身份技能、插件、随机洗牌、测试条件或Boss；12实体卡，窗口5；只验证文中指定序列，非策略穷举或平衡完成', cases };
const output = path.join(__dirname, '..', 'docs', '玩法验算结果.json');
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ assertions, cases: cases.map(({ log, ...summary }) => summary) }, null, 2));
