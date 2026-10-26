#!/usr/bin/env node
/**
 * assemble_chat.cjs — 把 `_build/chat_drafts/` 下三份闲聊草稿拼成
 * `docs/剧情/日常闲聊台词.md`（导言 + 三章角色池 + 统计 + 校验记录）。
 *
 * 用法：node _build/assemble_chat.cjs
 * 说明：先跑 assemble_chat → validate_chat（写日志）→ 再跑一次 assemble_chat，让校验记录落入成品。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const DRAFT_DIR = path.join('_build', 'chat_drafts');
const OUT = path.join('docs', '剧情', '日常闲聊台词.md');
const LOG = path.join('_build', 'chat_validation.log');
const FILES = [
  { character: 'GPT', file: 'GPT.md', line: '计划、步骤、兜底。小毛病：急着把完整方案交出去。' },
  { character: 'Claude', file: 'Claude_pool.md', line: '确认、清单、最小改动。小毛病：把检查全揽下来。' },
  { character: 'DeepSeek', file: 'DeepSeek.md', line: '省步骤、白饭、小鲸鱼。小毛病：太简洁，漏掉别人要的说明。' },
];
const CTX_ORDER = ['open', 'brief', 'check', 'accept', 'battle', 'rest', 'shop', 'event', 'boss', 'ending', 'idle'];
const CTX_MAP = {
  章首: 'open', 接单: 'brief', 接单看材料: 'brief', 核对: 'check', 核对途中: 'check',
  验收: 'accept', 验收前后: 'accept', 战斗整备: 'battle', 战前整备: 'battle',
  休息站: 'rest', 补给站: 'shop', 补给商店: 'shop', 路上事件: 'event',
  关底: 'boss', 章底前后: 'boss', 结局收束: 'ending', 收束: 'ending',
  等候: 'idle', 通用候场: 'idle', 空闲: 'idle',
};

function readText(p) {
  return fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
}

/** PowerShell 的 Tee-Object 可能写 UTF-16LE，这里按 BOM 解码。 */
function readLog(p) {
  const b = fs.readFileSync(p);
  let s;
  if (b[0] === 0xff && b[1] === 0xfe) s = b.toString('utf16le');
  else if (b[0] === 0xef && b[1] === 0xbb && b[2] === 0xbf) s = b.slice(3).toString('utf8');
  else s = b.toString('utf8');
  return s.replace(/\r\n/g, '\n').replace(/^\uFEFF/, '');
}

function parseBlocks(character, file) {
  const text = readText(path.join(DRAFT_DIR, file));
  const lines = text.split('\n');
  const blocks = [];
  let cur = null;
  for (const line of lines) {
    const h = /^###\s*(闲聊.*)$/.exec(line);
    if (h) {
      if (cur) blocks.push(cur);
      cur = { heading: h[1].trim(), lines: [line], header: {} };
      continue;
    }
    if (cur) cur.lines.push(line);
  }
  if (cur) blocks.push(cur);

  for (const b of blocks) {
    let inHeader = false;
    for (const ln of b.lines) {
      if (/^<!--\s*chat\s*$/.test(ln)) { inHeader = true; continue; }
      if (inHeader) {
        if (/^-->\s*$/.test(ln)) { inHeader = false; continue; }
        const m = /^([a-z_]+)\s*:\s*(.*)$/.exec(ln);
        if (m) b.header[m[1]] = m[2].trim();
      }
    }
    if (b.header.character !== character) throw new Error(`${file}: 块角色 ${b.header.character} ≠ ${character}`);
    const target = b.header.target && b.header.target !== 'none' ? b.header.target : null;
    b.character = character;
    b.target = target;
    b.context = target ? 'any' : b.header.context;
    if (!target) {
      // 标题里的中文语境名 → 英文枚举；若标题无法识别则以头里的 context 为准
      const parts = b.heading.split('·').map((s) => s.trim());
      if (parts.length >= 4 && CTX_MAP[parts[2]]) b.context = CTX_MAP[parts[2]];
      if (!b.context || !CTX_ORDER.includes(b.context)) throw new Error(`${file}: 无法确定 context：${b.heading}`);
    }
  }
  return blocks;
}

function main() {
  const groups = [];
  const counts = [];
  for (const spec of FILES) {
    const blocks = parseBlocks(spec.character, spec.file);
    const self = blocks.filter((b) => !b.target);
    const inter = blocks.filter((b) => b.target);
    self.sort((a, b) => CTX_ORDER.indexOf(a.context) - CTX_ORDER.indexOf(b.context));
    inter.sort((a, b) => a.target.localeCompare(b.target));
    for (const b of blocks) {
      b.canonical = b.target
        ? `### 闲聊 · ${b.character} → ${b.target} · 同伴互动`
        : `### 闲聊 · ${b.character} · ${b.context} · 自言自语`;
    }
    groups.push({ spec, self, inter, all: [...self, ...inter] });
    counts.push({
      character: spec.character,
      self: self.reduce((n, b) => n + b.lines.filter((l) => /^-\s*[^：:]{1,12}[：:]/.test(l)).length, 0),
      to: inter.reduce((n, b) => n + b.lines.filter((l) => /^-\s*[^：:]{1,12}[：:]/.test(l)).length, 0),
      pools: blocks.length,
    });
  }

  const totalSelf = counts.reduce((n, c) => n + c.self, 0);
  const totalTo = counts.reduce((n, c) => n + c.to, 0);
  const statsTable = [
    '| 角色 | 自言自语 | 同伴互动 | 合计 | 池数 |',
    '|---|---:|---:|---:|---:|',
    ...counts.map((c) => `| ${c.character} | ${c.self} | ${c.to} | ${c.self + c.to} | ${c.pools} |`),
    `| 合计 | ${totalSelf} | ${totalTo} | ${totalSelf + totalTo} | ${counts.reduce((n, c) => n + c.pools, 0)} |`,
  ].join('\n');

  let validation = '（尚未运行校验。运行 `node _build/validate_chat.cjs` 后重新拼装。）';
  if (fs.existsSync(LOG)) {
    const log = readLog(LOG).trim().split('\n');
    const keep = log.filter((l) => /^(文件|模式|块数|分布|结果)/.test(l));
    if (keep.length) validation = '```\n' + keep.join('\n') + '\n```';
  }

  const intro = readText(path.join(DRAFT_DIR, '00_导言.md'))
    .replace('<!-- STATS_TABLE -->', statsTable)
    .replace('<!-- VALIDATION_RECORD -->', validation);

  const body = groups.map((g) => {
    const blocks = g.all
      .map((b) => [b.canonical, ...b.lines.slice(1)].join('\n').replace(/\n{3,}/g, '\n\n').trim())
      .join('\n\n');
    return `## ${g.spec.character}\n\n> ${g.spec.line}\n\n${blocks}`;
  });

  const doc = [intro.trim(), ...body].join('\n\n') + '\n';
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, doc, 'utf8');
  console.log(`已拼装 ${OUT}`);
  console.log(`角色 ${counts.length} 个，块 ${counts.reduce((n, c) => n + c.pools, 0)} 个，台词 ${totalSelf + totalTo} 条（自白 ${totalSelf} / 互动 ${totalTo}）`);
}

main();
