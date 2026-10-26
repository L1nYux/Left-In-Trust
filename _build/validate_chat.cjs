#!/usr/bin/env node
/**
 * validate_chat.cjs — 校验「重复游玩 · 日常闲聊台词」。
 *
 * 用法：
 *   node _build/validate_chat.cjs --file <文件> [...]          # 校验给定文件（合并后的成品或单份草稿）
 *   node _build/validate_chat.cjs                            # 校验三份草稿并查全覆盖
 *   node _build/validate_chat.cjs --draft                     # 只查格式，不查覆盖
 *   node _build/validate_chat.cjs --json docs/剧情/日常闲聊台词.json   # 顺带导出机器可读文件
 *
 * 退出码：0 通过；1 有错误；2 文件缺失/参数错误。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const CHARACTERS = ['GPT', 'Claude', 'DeepSeek'];
const CONTEXTS = ['open', 'brief', 'check', 'accept', 'battle', 'rest', 'shop', 'event', 'boss', 'ending', 'idle'];
const DEFAULT_FILES = ['GPT.md', 'Claude_pool.md', 'DeepSeek.md'].map((f) =>
  path.join('_build', 'chat_drafts', f)
);

const FORBIDDEN_TEXT = [
  [/（|\(/, '括号动作'],
  [/\p{Extended_Pictographic}/u, 'emoji/符号'],
  [/yyds|绝绝子|栓Q|破防|awsl|笑死|emoji|作为\s*AI|作为一个?\s*AI/i, '网络梗或自称 AI'],
];
const PLOT_WARN = ['阿澄', '阿栖', '合照', '纪念册', '邀请', '聚会', 'work_value', 'someone_waiting'];

function parseArgs(argv) {
  const opts = { files: [], draft: false, json: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--file') {
      const v = argv[++i];
      if (!v) throw new Error('--file 缺少路径');
      opts.files.push(v);
    } else if (a === '--draft') {
      opts.draft = true;
    } else if (a === '--json') {
      opts.json = argv[++i];
      if (!opts.json) throw new Error('--json 缺少输出路径');
    } else if (a === '--help' || a === '-h') {
      console.log(require('fs').readFileSync(__filename, 'utf8').split('*/')[0]);
      process.exit(0);
    } else {
      throw new Error('未知参数：' + a);
    }
  }
  return opts;
}

function readText(p) {
  if (!fs.existsSync(p)) {
    console.error('缺少文件：' + p);
    process.exit(2);
  }
  return fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
}

/**
 * 解析一份聊天文件。
 * 返回 { blocks: [{heading, character, context, target, tags, lines:[{line,text}], src, offset}], errors, warnings }
 */
function parseFile(file) {
  const lines = readText(file).split('\n');
  const blocks = [];
  let cur = null;
  let inHeader = false;
  let headerLines = [];

  function flush() {
    if (!cur) return;
    blocks.push(cur);
    cur = null;
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const h = /^###\s*(.+?)\s*$/.exec(line);
    if (h && /^闲聊\s*·/.test(h[1])) {
      flush();
      cur = { heading: h[1], character: null, context: null, target: null, tags: [], lines: [], src: file, offset: i + 1, errors: [], warnings: [] };
      inHeader = false;
      headerLines = [];
      continue;
    }
    if (!cur) continue;
    if (/^<!--\s*chat\s*$/.test(line)) {
      inHeader = true;
      headerLines = [];
      continue;
    }
    if (inHeader) {
      if (/^-->\s*$/.test(line)) {
        inHeader = false;
        for (const hl of headerLines) {
          const m = /^([a-z_]+)\s*:\s*(.*)$/.exec(hl);
          if (!m) continue;
          const [, k, vRaw] = m;
          const v = vRaw.trim();
          if (k === 'character') cur.character = v;
          else if (k === 'context') cur.context = v;
          else if (k === 'target') cur.target = v;
          else if (k === 'tags') cur.tags = v.split(/[,，]/).map((s) => s.trim()).filter(Boolean);
        }
        continue;
      }
      headerLines.push(line);
      continue;
    }
    const m = /^-\s*([^：:]{1,12})[：:]\s*(.+)$/.exec(line);
    if (m) {
      cur.lines.push({ line: i + 1, speaker: m[1].trim(), text: m[2].trim() });
    } else if (/^\s*##\s/.test(line) || /^#\s/.test(line)) {
      flush();
      continue;
    }
  }
  flush();
  return blocks;
}

function textOk(text) {
  const problems = [];
  for (const [re, name] of FORBIDDEN_TEXT) {
    if (re.test(text)) problems.push('含' + name);
  }
  const plain = text.replace(/……/g, '').replace(/\.{3,}/g, '');
  const sentenceCount = plain.split(/[。！？!?]/).map((s) => s.trim()).filter(Boolean).length;
  const maxLen = Math.max(...plain.split(/[。！？!?]/).map((s) => s.trim().length), 0);
  if (maxLen > 24) problems.push(`单句 ${maxLen} 字（上限 24）`);
  if (sentenceCount > 2) problems.push(`单条 ${sentenceCount} 句（上限 2）`);
  return problems;
}

function normalize(text) {
  return text.replace(/\s+/g, '').replace(/[。！？!?…]+$/g, '');
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(e.message);
    process.exit(2);
  }
  const files = opts.files.length ? opts.files : DEFAULT_FILES;
  const errors = [];
  const warnings = [];
  const blocks = [];
  const seenText = new Map(); // normalized text -> {file, line}
  const seenBlockKey = new Set();

  for (const file of files) {
    for (const b of parseFile(file)) {
      const where = `${file}:${b.offset}`;
      if (!b.character || !CHARACTERS.includes(b.character)) {
        errors.push(`${where} 未知/缺失 character：${b.character}`);
        continue;
      }
      const expect = /^闲聊\s*·\s*([^·→]+?)\s*(?:→\s*([^·]+?))?\s*·\s*(自言自语|同伴互动)\s*$/.exec(b.heading);
      if (expect) {
        if (expect[1].trim() !== b.character) errors.push(`${where} 标题角色 ${expect[1].trim()} 与 character ${b.character} 不一致`);
        if (expect[2]) {
          const t = expect[2].trim();
          if (b.target && b.target !== 'none' && t !== b.target) errors.push(`${where} 标题 target ${t} 与头 ${b.target} 不一致`);
          if (!b.target || b.target === 'none') b.target = t;
        }
      }
      const interaction = b.target && b.target !== 'none';
      if (interaction) {
        if (!CHARACTERS.includes(b.target)) errors.push(`${where} 未知 target：${b.target}`);
        else if (b.target === b.character) errors.push(`${where} target 不能是自己`);
      } else {
        if (b.context === 'any') errors.push(`${where} 自言自语不能用 context: any`);
      }
      if (!b.context || !(CONTEXTS.includes(b.context) || b.context === 'any')) {
        errors.push(`${where} 未知 context：${b.context}`);
      }
      if (interaction && b.context !== 'any') warnings.push(`${where} 同伴互动建议 context: any（当前 ${b.context}）`);
      if (!b.lines.length) errors.push(`${where} 没有任何台词`);

      for (const ln of b.lines) {
        if (ln.speaker !== b.character) errors.push(`${file}:${ln.line} 说话者 ${ln.speaker} 与块角色 ${b.character} 不一致`);
        const problems = textOk(ln.text);
        for (const p of problems) errors.push(`${file}:${ln.line} ${p}：「${ln.text}」`);
        for (const w of PLOT_WARN) {
          if (ln.text.includes(w)) warnings.push(`${file}:${ln.line} 出现剧情词「${w}」，确认不是点暗线`);
        }
        const key = normalize(ln.text);
        if (seenText.has(key)) {
          const prev = seenText.get(key);
          errors.push(`${file}:${ln.line} 与 ${prev.file}:${prev.line} 重复：「${ln.text}」`);
        } else {
          seenText.set(key, { file, line: ln.line });
        }
      }
      const key = `${b.character}|${b.context}|${interaction ? b.target : 'none'}`;
      if (seenBlockKey.has(key)) warnings.push(`${where} 同一角色/情境的分块，将合并为一个池：${key}`);
      seenBlockKey.add(key);
      blocks.push({ ...b, interaction, source: file });
    }
  }

  // 聚合池
  const pools = new Map();
  for (const b of blocks) {
    const key = `${b.character}|${b.context}|${b.interaction ? b.target : 'none'}`;
    if (!pools.has(key)) {
      pools.set(key, {
        id: `chat.${b.character}.${b.context}${b.interaction ? '.to.' + b.target : ''}`,
        character: b.character,
        context: b.context,
        target: b.interaction ? b.target : null,
        tags: [],
        lines: [],
      });
    }
    const p = pools.get(key);
    for (const t of b.tags) if (!p.tags.includes(t)) p.tags.push(t);
    for (const ln of b.lines) p.lines.push({ speaker: b.character, text: ln.text });
  }
  for (const p of pools.values()) {
    p.lines = p.lines.map((ln, i) => ({ id: `${p.id}.${String(i + 1).padStart(2, '0')}`, ...ln }));
    p.see = p.id;
  }
  const poolList = [...pools.values()];

  // 覆盖
  if (!opts.draft) {
    for (const c of CHARACTERS) {
      for (const ctx of CONTEXTS) {
        const p = poolList.find((x) => x.character === c && x.context === ctx && !x.target);
        const n = p ? p.lines.length : 0;
        if (n < 2) errors.push(`覆盖不足：${c} / ${ctx} 自白 ${n} 条（至少 2 条）`);
      }
      for (const other of CHARACTERS) {
        if (other === c) continue;
        const p = poolList.find((x) => x.character === c && x.target === other);
        const n = p ? p.lines.length : 0;
        if (n < 3) errors.push(`覆盖不足：${c} → ${other} 互动 ${n} 条（至少 3 条）`);
      }
    }
  }

  // 导出
  if (opts.json) {
    const out = {
      version: '1.0',
      generatedFrom: files,
      characters: CHARACTERS,
      contexts: CONTEXTS,
      playRules: {
        firstPlayShowsScene: true,
        repeatUsesChat: true,
        maxLinesPerNode: 2,
        battleMaxLines: 1,
        grantsFacts: false,
        affectsRules: false,
      },
      pools: poolList,
    };
    fs.mkdirSync(path.dirname(opts.json), { recursive: true });
    fs.writeFileSync(opts.json, JSON.stringify(out, null, 2) + '\n', 'utf8');
    console.log(`已导出 ${opts.json}`);
  }

  // 统计输出
  console.log('=== 闲聊台词校验 ===');
  console.log('文件：' + files.join(', '));
  console.log('模式：' + (opts.draft ? '格式（单文件）' : '格式 + 覆盖'));
  console.log('块数：' + blocks.length + '，池数：' + poolList.length + '，台词条数：' + poolList.reduce((s, p) => s + p.lines.length, 0));
  const dist = {};
  for (const p of poolList) {
    const k = p.character + (p.target ? '→' + p.target : '');
    dist[k] = (dist[k] || 0) + p.lines.length;
  }
  console.log('分布：' + JSON.stringify(dist));
  for (const w of warnings) console.log('警告：' + w);
  for (const e of errors) console.log('错误：' + e);
  console.log('');
  if (errors.length) {
    console.log(`结果：FAIL（错误 ${errors.length}，警告 ${warnings.length}）`);
    process.exit(1);
  }
  console.log(`结果：PASS（错误 0，警告 ${warnings.length}）`);
}

main();
