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
 *
 * 2026-10-27 补强（T-B 数据文本卫生）：
 *   - 事件头字段白名单（HEADER_FIELDS），未知键 error（防止 export 透传任意键）。
 *   - 旁白断言同时看 kind:text 与 kind:line；reality error、ending 先 warning。
 *   - 演出段 staging 字数/句数硬区间（30–200 字 / 2–8 句）。
 *   - 标题泄漏：源码侧聚合 warning；默认完整校验额外检查 game/data/story.json，
 *     会进 pages 的 section 里出现以 `#` 开头的 text 即 error（根因防复发）。
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
/**
 * 事件头字段白名单（契约来源：00_创作基准 §8 + 现有 117 个事件头实测键集合）。
 * export_story_runtime.cjs 的 parseHeader 会把事件头里任意 `key: value` 原样透传到
 * runtime JSON，所以未登记的键（例如 `presentation: theater`）必须在这里硬拦。
 * 新增键时连同导出层/运行时一起改，不要偷偷加。
 */
const HEADER_FIELDS = new Set([
  'id', 'chapter', 'task', 'stage', 'node', 'type', 'facts', 'knowledge',
  'focus', 'boss', 'branch', 'see',
]);
/**
 * 会进入运行时 pages 的 section（对照 game/scripts/story_db.gd:41-64 compose_event 与
 * :99-102 compose_repeat）：fixed/narration → 旁白页；scene → 场景页；staging → 画面页
 * （仅 reality）；branch → 分支页；repeat → 再次路过页。main/partner/closing 靠台词行，
 * 标题脏数据不会进 pages，但导出层会一并过滤。
 */
const PAGE_SECTIONS = new Set(['scene', 'fixed', 'staging', 'narration', 'branch', 'repeat']);
const RUNTIME_STORY = path.join('game', 'data', 'story.json');

function isHeadingText(value) {
  return typeof value === 'string' && value.trim().startsWith('#');
}

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

  // 事件头字段白名单（防止 export 透传的未知键静默进入 runtime JSON）。
  for (const key of Object.keys(h)) {
    if (!HEADER_FIELDS.has(key)) {
      err(file, id, `事件头出现未知字段 ${key}（只允许 ${[...HEADER_FIELDS].join('/')}）`);
    }
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
  // 旁白既可能写成 `**旁白**：文本`（导出为 kind:"text"）也可能写成 bullet 行（kind:"line"），
  // 断言必须两种都覆盖。
  const narrationItems = (ev.sections.narration || [])
    .filter((x) => x.kind === 'text' || x.kind === 'line');

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
  }

  // 旁白约束（00_创作基准 §8.4：现实片段旁白 ≤2 句、每句 ≤14 字）。
  // 旧实现只统计 bullet 行，而 `**旁白**：文本` 导出为 kind:"text"，导致该断言长期是死代码。
  // 分级：reality = error（现状 20 条全部 1 条且 ≤14 字）；ending 先降级 warning
  // （现状违反 2 条：ch2.*.ending.eligible 的 18 字旁白，待文案润色后再升 error）。
  const narrationLevel = h.type === 'reality' ? 'error' : h.type === 'ending' ? 'warn' : null;
  if (narrationLevel && narrationItems.length > 0) {
    const report = narrationLevel === 'error' ? err : warn;
    if (narrationItems.length > 2) {
      report(file, id, `旁白最多两句，当前 ${narrationItems.length} 条`);
    }
    for (const item of narrationItems) {
      if (charLen(item.text) > 14) {
        report(file, id, `旁白超过 14 字（${charLen(item.text)} 字）：${item.text}`);
      }
    }
  }

  // 演出段（staging）区间：实测 25 条 42–127 字 / 3–7 句，取 30–200 字、2–8 句为硬区间。
  // 演出是现实片段唯一的画面承载：过短撑不起镜头，过长则超出 8–18 秒的可演长度。
  for (const item of (ev.sections.staging || [])) {
    if (item.kind !== 'text') continue;
    const len = charLen(item.text);
    const sentences = sentenceCount(item.text);
    if (len < 30 || len > 200) {
      err(file, id, `演出段字数 ${len} 超出 30–200：${item.text.slice(0, 20)}…`);
    } else if (sentences < 2 || sentences > 8) {
      err(file, id, `演出段句数 ${sentences} 超出 2–8：${item.text.slice(0, 20)}…`);
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

/**
 * 根因防复发守卫（源码侧，warning）：统计 Markdown 源里「被段落吞进去的标题行」。
 * 现状（2026-10-27 实测）：127 条标题 text，其中 52 条落在会进 pages 的 section
 * （fixed 15 / scene 28 / branch 9，另有 partner/closing/repeat 不进 pages）。
 * 根因是拼装器把下一个事件的标题附在上一个事件末尾；docs/ 文案冻结、本任务不能改，
 * 故先发 1 条聚合 warning（而不是刷 52 条 error）；拼装器修好后计数自然归零再升 error。
 */
function warnSourceHeadingLeaks() {
  let leaks = 0;
  const bySection = {};
  for (const ev of allEvents) {
    for (const key of PAGE_SECTIONS) {
      for (const item of (ev.sections[key] || [])) {
        if (item.kind === 'text' && isHeadingText(item.text)) {
          leaks += 1;
          bySection[key] = (bySection[key] || 0) + 1;
        }
      }
    }
  }
  if (leaks > 0) {
    warn(files[0] || 'story', '<源码结构>',
      `源码有 ${leaks} 条 Markdown 标题行落在 pages 段（${JSON.stringify(bySection)}），根因：拼装器把下一个事件标题粘在上一个事件末尾；导出层已过滤，修拼装器后此警告消失`);
  }
  return leaks;
}

/**
 * 运行时产物守卫（硬 error）：game/data/story.json 里任何会进 pages 的 section
 * 出现以 `#` 开头的 text，即为标题泄漏复发（导出层过滤器被绕过或回退）。
 * 只在默认完整校验跑：`--file`/`--draft` 草稿模式与 story.json 无关。
 */
function checkRuntimeHeadingLeaks() {
  if (!fs.existsSync(RUNTIME_STORY)) {
    console.log(`\n[运行时守卫] 未找到 ${RUNTIME_STORY}，跳过标题泄漏检查`);
    return 0;
  }
  let data;
  try {
    data = JSON.parse(fs.readFileSync(RUNTIME_STORY, 'utf8'));
  } catch (error) {
    err(RUNTIME_STORY, '<parse>', `无法解析运行时 story.json：${error.message}`);
    return 0;
  }
  let leaks = 0;
  for (const event of (data.events || [])) {
    const eventId = String(event.id || '<无 id>');
    for (const [key, items] of Object.entries(event.sections || {})) {
      if (!PAGE_SECTIONS.has(key)) continue;
      for (const item of (items || [])) {
        if (item && item.kind === 'text' && isHeadingText(item.text)) {
          leaks += 1;
          err(RUNTIME_STORY, eventId, `${key} 段把 Markdown 标题当正文：${item.text}`);
        }
      }
    }
  }
  console.log(`[运行时守卫] ${RUNTIME_STORY}：${(data.events || []).length} 事件，pages 段标题泄漏 ${leaks} 条`);
  return leaks;
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
  // 标题泄漏：源码侧聚合 warning（docs 文案冻结、拼装器不在本任务范围）；
  // 运行时产物侧硬 error（导出过滤器回退会立刻红灯）。
  const sourceHeadingLeaks = warnSourceHeadingLeaks();
  const isCanonicalRun = !draft && files.length === 1
    && path.resolve(files[0]) === path.resolve(path.join('docs', 'Demo剧情脚本.md'));
  let runtimeHeadingLeaks = null;
  if (isCanonicalRun) runtimeHeadingLeaks = checkRuntimeHeadingLeaks();

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
  console.log(`标题泄漏：源码 ${sourceHeadingLeaks} 条（聚合 warning，根因在拼装器），`
    + `运行时 ${runtimeHeadingLeaks === null ? '未检查' : `${runtimeHeadingLeaks} 条（error）`}`);
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
