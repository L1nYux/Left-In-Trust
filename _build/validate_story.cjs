#!/usr/bin/env node
/**
 * validate_story.cjs — 《未尽之托》Demo 剧情脚本校验器
 *
 * 用法：
 *   node _build/validate_story.cjs                       # 校验 docs/Demo剧情脚本.md（完整覆盖）
 *   node _build/validate_story.cjs --file a.md --file b.md   # 校验多个文件（完整覆盖）
 *   node _build/validate_story.cjs --file draft.md --draft   # 草稿模式：只查格式/重复/单文件，不查全量覆盖
 *   node _build/validate_story.cjs --json out.json       # 结果同时写 JSON
 *
 * 契约来源：docs/剧情/00_创作基准.md §8。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const files = [];
let draft = false;
let jsonOut = null;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--draft') draft = true;
  else if (a === '--file') files.push(args[++i]);
  else if (a === '--json') jsonOut = args[++i];
  else if (a === '--help' || a === '-h') {
    console.log('usage: node _build/validate_story.cjs [--file <path>]... [--draft] [--json <out>]');
    process.exit(0);
  } else {
    console.error(`未知参数：${a}`);
    process.exit(2);
  }
}
if (files.length === 0) files.push(path.join('docs', 'Demo剧情脚本.md'));

const NODES = new Set([
  'prologue', 'open', 'N1', 'N2', 'N3', 'B1', 'B2', 'rest', 'shop', 'event',
  'boss', 'stageBoss', 'hidden', 'close', 'recruit', 'success', 'prepFail',
  'acceptFail', 'ending', 'recap', 'appendix',
]);
const TYPES = new Set([
  'story', 'brief', 'check', 'accept', 'battle', 'rest', 'shop', 'event',
  'reality', 'ending', 'recap', 'appendix',
]);
const NODE_TYPE = {
  prologue: 'story', open: 'story', close: 'story', recruit: 'story',
  N1: 'brief', N2: 'check', N3: 'accept',
  B1: 'battle', B2: 'battle', boss: 'battle', stageBoss: 'battle', hidden: 'battle',
  rest: 'rest', shop: 'shop', event: 'event',
  success: 'reality', prepFail: 'reality', acceptFail: 'reality',
  ending: 'ending', recap: 'recap', appendix: 'appendix',
};
const TASKS = new Set(['report', 'slides', 'invite', 'photos', 'none']);
const STAGES = new Set(['student', 'employee', 'none']);
const SPEAKERS = new Set(['GPT', 'Claude', 'DeepSeek', '旁白', '终端', '我', '敌人', '系统']);
const ROLES = ['GPT', 'Claude', 'DeepSeek'];
const FACTS = new Set(['work_value', 'someone_waiting']);
const BOSSES = new Set(['submit', 'recipient', 'stage_student', 'stage_employee', 'hidden', 'none']);

const errors = [];
const warnings = [];

function err(file, id, msg) { errors.push({ file, id, msg }); }
function warn(file, id, msg) { warnings.push({ file, id, msg }); }

function canonSection(name) {
  const n = name.trim();
  if (n.startsWith('场景')) return 'scene';
  if (n.startsWith('主句')) return 'main';
  if (n.startsWith('搭档')) return 'partner';
  if (n.startsWith('固定')) return 'fixed';
  if (n.startsWith('演出')) return 'staging';
  if (n.startsWith('旁白')) return 'narration';
  if (n.startsWith('收束')) return 'closing';
  if (n.startsWith('重复')) return 'repeat';
  if (n.startsWith('分支')) return 'branch';
  return null;
}

/** 解析一个文件里的全部事件块。 */
function parseFile(file) {
  if (!fs.existsSync(file)) {
    console.error(`找不到文件：${file}`);
    process.exit(2);
  }
  const src = fs.readFileSync(file, 'utf8');
  const re = /<!--\s*event\r?\n([\s\S]*?)-->/g;
  const marks = [];
  let m;
  while ((m = re.exec(src)) !== null) {
    marks.push({ header: m[1], start: m.index, end: re.lastIndex });
  }
  const events = [];
  for (let i = 0; i < marks.length; i++) {
    const header = {};
    for (const line of marks[i].header.split(/\r?\n/)) {
      const km = line.match(/^\s*([A-Za-z][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$/);
      if (km) header[km[1].toLowerCase()] = km[2];
    }
    const bodyEnd = i + 1 < marks.length ? marks[i + 1].start : src.length;
    const body = src.slice(marks[i].end, bodyEnd);
    const sections = {};
    let cur = null;
    for (const raw of body.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line) continue;
      const sm = line.match(/^\*\*([^*]+?)\*\*\s*[：:]?\s*(.*)$/);
      if (sm) {
        const key = canonSection(sm[1]);
        if (key) {
          cur = key;
          if (!sections[key]) sections[key] = [];
          if (sm[2]) sections[key].push({ kind: 'text', text: sm[2] });
          continue;
        }
        cur = null;
        continue;
      }
      if (cur && /^[-*]\s+/.test(line)) {
        const lm = line.replace(/^[-*]\s+/, '').match(/^([^：:]{1,12})[：:]\s*(.+)$/);
        if (lm) {
          (sections[cur] = sections[cur] || []).push({
            kind: 'line', speaker: lm[1].trim(), text: lm[2].trim(),
          });
          continue;
        }
      }
      if (cur) (sections[cur] = sections[cur] || []).push({ kind: 'text', text: line });
    }
    const lineNo = src.slice(0, marks[i].start).split('\n').length;
    events.push({ file, header, sections, lineNo });
  }
  return events;
}

function texts(ev, key) {
  return (ev.sections[key] || []).filter((x) => x.kind === 'text').map((x) => x.text);
}
function lines(ev, key) {
  return (ev.sections[key] || []).filter((x) => x.kind === 'line');
}
function speakersOf(ev, key) {
  return lines(ev, key).map((x) => x.speaker);
}
function charLen(s) {
  return Array.from(s || '').length;
}
function sentenceCount(s) {
  return (String(s).match(/[。！？!?；;]/g) || []).length + (String(s).trim() ? 1 : 0);
}

const allEvents = [];

function checkEvent(ev) {
  const h = ev.header;
  const id = (h.id || '').trim();
  const file = ev.file;
  if (!id) { err(file, '<无 id>', `第 ${ev.lineNo} 行附近的事件块缺少 id`); return; }
  if (!/^(global\.[A-Za-z0-9_.]+|ch[12]\.[A-Za-z0-9_.]+)$/.test(id)) {
    err(file, id, 'id 必须为 global.* 或 ch1.*/ch2.*');
  }

  const required = ['id', 'chapter', 'task', 'stage', 'node', 'type', 'facts', 'see'];
  for (const k of required) {
    if (h[k] === undefined || h[k] === '') err(file, id, `事件头缺少字段 ${k}`);
  }
  const chapter = h.chapter;
  if (!['0', '1', '2'].includes(chapter)) err(file, id, `chapter 非法：${chapter}`);
  if (!TASKS.has(h.task)) err(file, id, `task 非法：${h.task}`);
  if (!STAGES.has(h.stage)) err(file, id, `stage 非法：${h.stage}`);
  const node = h.node;
  if (!NODES.has(node)) err(file, id, `node 非法：${node}`);
  if (!TYPES.has(h.type)) err(file, id, `type 非法：${h.type}`);
  if (NODE_TYPE[node] && h.type !== NODE_TYPE[node]) {
    err(file, id, `node=${node} 应为 type=${NODE_TYPE[node]}，实际 ${h.type}`);
  }

  // id 与 chapter 前缀一致
  if (id.startsWith('ch') && chapter !== '0') {
    const prefix = id.slice(0, 3);
    if (prefix !== `ch${chapter}`) err(file, id, `id 前缀与 chapter=${chapter} 不符`);
  }
  if (id.startsWith('global.') && chapter !== '0') {
    err(file, id, 'global.* 事件的 chapter 必须为 0（或不参与章节判定时用 0）');
  }

  // facts
  const facts = (h.facts || 'none').split(',').map((s) => s.trim()).filter(Boolean);
  const expectFact = chapter === '1' ? 'work_value' : chapter === '2' ? 'someone_waiting' : null;
  for (const f of facts) {
    if (f !== 'none' && !FACTS.has(f)) err(file, id, `facts 非法值：${f}`);
  }
  if (node === 'success') {
    if (!facts.includes(expectFact) || facts.length !== 1) {
      err(file, id, `success 必须且只能给 facts: ${expectFact}`);
    }
  } else if (node === 'acceptFail') {
    const bad = facts.filter((f) => f !== 'none' && f !== expectFact);
    if (bad.length) err(file, id, `acceptFail 不能授予 ${bad.join(',')}（本章应为 none 或 ${expectFact}）`);
  } else if (node === 'prepFail' || node === 'ending' || node === 'recap' || node === 'appendix') {
    if (facts.some((f) => f !== 'none')) err(file, id, `${node} 不应授予事实`);
  } else if (facts.some((f) => f !== 'none')) {
    err(file, id, `${node} 不应授予事实`);
  }

  if (h.see && h.see !== id) warn(file, id, `see=${h.see} 与 id 不一致（一般应相同）`);

  // boss 字段
  if (['boss', 'stageBoss', 'hidden'].includes(node)) {
    if (!h.boss || h.boss === 'none') err(file, id, `node=${node} 缺少 boss 字段`);
    else if (!BOSSES.has(h.boss)) err(file, id, `boss 非法：${h.boss}`);
    if (node === 'boss' && chapter === '1' && h.boss !== 'submit') err(file, id, '第一章 boss 必须为 submit');
    if (node === 'boss' && chapter === '2' && h.boss !== 'recipient') err(file, id, '第二章 boss 必须为 recipient');
    if (node === 'stageBoss' && h.stage === 'student' && h.boss !== 'stage_student') err(file, id, '学生版阶段 Boss 必须为 stage_student');
    if (node === 'stageBoss' && h.stage === 'employee' && h.boss !== 'stage_employee') err(file, id, '员工版阶段 Boss 必须为 stage_employee');
    if (node === 'hidden' && h.boss !== 'hidden') err(file, id, '隐藏 Boss 必须为 hidden');
  } else if (h.boss && h.boss !== 'none' && h.boss !== '') {
    warn(file, id, `node=${node} 通常不需要 boss 字段（当前 ${h.boss}）`);
  }

  if (node === 'ending') {
    if (!['eligible', 'not_eligible'].includes(h.branch)) {
      err(file, id, 'ending 必须带 branch: eligible 或 not_eligible');
    }
  }

  const main = speakersOf(ev, 'main');
  const partner = speakersOf(ev, 'partner');
  const fixed = speakersOf(ev, 'fixed');
  const closing = speakersOf(ev, 'closing');
  const narration = lines(ev, 'narration');

  // 发言人合法性
  for (const key of ['main', 'partner', 'fixed', 'narration', 'closing']) {
    for (const sp of speakersOf(ev, key)) {
      if (!SPEAKERS.has(sp)) err(file, id, `${key} 中出现非法发言人「${sp}」`);
      if (sp === '我' && !['ending', 'hidden'].includes(node)) err(file, id, `「我」只能在 ending/hidden 发言（${key}）`);
      if (sp === '敌人' && !['battle'].includes(h.type)) err(file, id, `「敌人」只能出现在战斗事件（${key}）`);
      if (sp === '终端' && h.type === 'reality') err(file, id, `现实片段不能出现「终端」（${key}）`);
    }
  }

  const needMain = ['story', 'brief', 'check', 'accept', 'rest', 'shop', 'event', 'battle', 'ending'].includes(h.type);
  const dialogueNodes = ['open', 'N1', 'N2', 'N3', 'B1', 'B2', 'rest', 'shop', 'event', 'boss', 'close'].includes(node);

  if (!texts(ev, 'scene').length && !texts(ev, 'staging').length) {
    err(file, id, '缺少 **场景** 或 **演出** 段落');
  }

  if (needMain) {
    for (const r of ROLES) {
      if (!main.includes(r)) err(file, id, `主句缺少角色 ${r}`);
    }
    const outside = main.filter((s) => !ROLES.includes(s));
    if (outside.length) err(file, id, `主句出现非角色发言人：${outside.join(',')}`);
  }

  if (dialogueNodes) {
    for (const r of ROLES) {
      if (!partner.includes(r)) err(file, id, `搭档回应缺少角色 ${r}`);
    }
    for (const sp of partner) {
      if (!ROLES.includes(sp)) err(file, id, `搭档回应出现非角色发言人：${sp}`);
    }
  } else if (['N1', 'N2', 'N3'].includes(node) === false && partner.length === 0) {
    // 其余节点不强制搭档
  }

  if (h.type === 'battle' && fixed.length === 0) {
    err(file, id, '战斗事件缺少 **固定台词**（敌人/终端/旁白至少一条）');
  }

  if (h.type === 'reality') {
    if (!texts(ev, 'staging').length) err(file, id, '现实片段缺少 **演出** 段落');
    for (const r of ROLES) {
      if (!closing.includes(r)) err(file, id, `收束缺少角色 ${r}`);
    }
    if (closing.some((s) => !ROLES.includes(s))) err(file, id, '收束只能由 GPT/Claude/DeepSeek 说话');
    if (narration.length > 2) err(file, id, `旁白最多两句，当前 ${narration.length} 条`);
    for (const n of narration) {
      if (charLen(n.text) > 14) warn(file, id, `旁白过长（${charLen(n.text)} 字）：${n.text}`);
    }
  }

  if (h.type === 'ending') {
    if (fixed.length === 0) err(file, id, '结局缺少 **固定台词**（终端/我/旁白）');
  }

  // 长度检查
  for (const key of ['main', 'partner', 'fixed', 'narration', 'closing']) {
    for (const l of lines(ev, key)) {
      const n = charLen(l.text);
      if (n > 60) warn(file, id, `${key} 台词过长（${n} 字）：${l.text.slice(0, 24)}…`);
      else if (key === 'main' && n > 40) warn(file, id, `主句偏长（${n} 字）`);
      if (sentenceCount(l.text) > 3) warn(file, id, `${key} 台词句数偏多：${l.text}`);
    }
  }
  // 重复的相同台词（同一事件内）
  const seen = new Map();
  for (const key of ['main', 'partner', 'fixed', 'closing']) {
    for (const l of lines(ev, key)) {
      const k = l.speaker + '|' + l.text;
      if (seen.has(k)) warn(file, id, `同一事件内出现重复台词：${l.speaker}：${l.text.slice(0, 20)}…`);
      else seen.set(k, true);
    }
  }

  allEvents.push(ev);
}

function checkCoverage() {
  const byId = new Map();
  for (const ev of allEvents) {
    const id = (ev.header.id || '').trim();
    if (!id) continue;
    if (byId.has(id)) err(ev.file, id, `id 重复（另一处在 ${byId.get(id).file}:${byId.get(id).lineNo}）`);
    else byId.set(id, ev);
  }

  const stages = ['student', 'employee'];
  const tasks = { 1: ['report', 'slides'], 2: ['invite', 'photos'] };
  const required = [];
  for (const ch of [1, 2]) {
    for (const task of tasks[ch]) {
      for (const st of stages) {
        for (const node of ['open', 'N1', 'N2', 'N3', 'success', 'acceptFail']) {
          required.push(`ch${ch}.${task}.${st}.${node}`);
        }
      }
    }
    for (const st of stages) {
      for (const node of ['B1', 'B2', 'boss', 'prepFail', 'rest', 'shop', 'event', 'close']) {
        required.push(`ch${ch}.${st}.${node}`);
      }
    }
  }
  for (const st of stages) {
    required.push(`ch1.${st}.recruit`);
    required.push(`ch2.${st}.stageBoss`);
    required.push(`ch2.${st}.hidden`);
  }
  required.push('global.prologue');
  for (let i = 1; i <= 6; i++) required.push(`global.future.0${i}`);

  for (const id of required) {
    if (!byId.has(id)) err(files[0] || 'story', id, '缺少必需事件');
  }

  // 每个现实片段都要有一条 recap
  for (const [id, ev] of byId) {
    const node = ev.header.node;
    if (['success', 'prepFail', 'acceptFail'].includes(node)) {
      const rid = `global.recap.${id}`;
      if (!byId.has(rid)) err(ev.file, id, `缺少收藏回顾事件 ${rid}`);
    }
  }

  // 结局分支
  for (const st of stages) {
    const base = `ch2.${st}.ending`;
    const branches = new Set();
    for (const [id, ev] of byId) {
      if (ev.header.node === 'ending' && id.startsWith(base)) branches.add(ev.header.branch);
    }
    for (const b of ['eligible', 'not_eligible']) {
      if (!branches.has(b)) err(files[0] || 'story', base, `缺少 branch=${b} 的结局事件`);
    }
  }

  // Boss 映射已在单事件检查中完成；额外确认每个任务×阶段的存在性已覆盖。
  return byId;
}

function main() {
  for (const f of files) {
    for (const ev of parseFile(f)) checkEvent(ev);
  }
  let byId = null;
  if (!draft) byId = checkCoverage();

  const grouped = new Map();
  for (const e of errors) {
    const k = `${e.file} ${e.id}`;
    if (!grouped.has(k)) grouped.set(k, []);
    grouped.get(k).push(e.msg);
  }
  if (grouped.size) {
    console.log('\n=== 错误 ===');
    for (const [k, msgs] of grouped) {
      console.log(`\n[${k}]`);
      for (const msg of msgs) console.log(`  ✗ ${msg}`);
    }
  }
  if (warnings.length) {
    console.log(`\n=== 警告（${warnings.length}） ===`);
    for (const w of warnings.slice(0, 120)) console.log(`  ! ${w.file} ${w.id}: ${w.msg}`);
    if (warnings.length > 120) console.log(`  … 其余 ${warnings.length - 120} 条省略`);
  }

  const nodeCounts = {};
  for (const ev of allEvents) nodeCounts[ev.header.node] = (nodeCounts[ev.header.node] || 0) + 1;
  console.log('\n=== 统计 ===');
  console.log(`文件：${files.join(' , ')}`);
  console.log(`模式：${draft ? '草稿（格式）' : '完整（格式+覆盖）'}`);
  console.log(`事件总数：${allEvents.length}`);
  console.log(`节点分布：${JSON.stringify(nodeCounts)}`);
  console.log(`错误：${errors.length}，警告：${warnings.length}`);

  if (jsonOut) {
    fs.writeFileSync(jsonOut, JSON.stringify({
      files, draft, events: allEvents.length, nodeCounts,
      errors, warnings,
    }, null, 2), 'utf8');
    console.log(`JSON 已写入：${jsonOut}`);
  }
  if (errors.length) {
    console.log('\n结果：FAIL');
    process.exit(1);
  }
  console.log('\n结果：PASS');
}

main();
