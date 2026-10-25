#!/usr/bin/env node
/**
 * assemble_story.cjs — 把导言与三份章节草稿拼装为 docs/Demo剧情脚本.md v1.0。
 * 顺序：导言 → 序章 → 第一章（学生/员工）→ 第二章（学生/员工）→ 挑战与长期附录 → 收藏回顾。
 * 用法：node _build/assemble_story.cjs
 */
'use strict';

const fs = require('fs');
const path = require('path');

const DIR = path.join('_build', 'story_drafts');
const OUT = path.join('docs', 'Demo剧情脚本.md');

function read(name) {
  const p = path.join(DIR, name);
  if (!fs.existsSync(p)) throw new Error('缺少草稿：' + p);
  return fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
}

/** 按 `## ` 切分，返回 { pre, sections }。 */
function splitH2(src) {
  const lines = src.split('\n');
  const pre = [];
  const sections = [];
  let cur = null;
  for (const line of lines) {
    if (/^## /.test(line)) {
      if (cur) sections.push(cur);
      cur = { title: line.replace(/^## /, '').trim(), body: [] };
    } else if (cur) {
      cur.body.push(line);
    } else {
      pre.push(line);
    }
  }
  if (cur) sections.push(cur);
  return { pre: pre.join('\n').trim(), sections };
}

/** 按 `### ` 继续切分。 */
function splitH3(bodyLines) {
  const groups = [];
  let cur = null;
  for (const line of bodyLines) {
    if (/^### /.test(line)) {
      if (cur) groups.push(cur);
      cur = { title: line.replace(/^### /, '').trim(), body: [line] };
    } else if (cur) {
      cur.body.push(line);
    }
  }
  if (cur) groups.push(cur);
  return groups.map((g) => ({ title: g.title, body: g.body.join('\n').trim() }));
}

function find(sections, title) {
  const s = sections.find((x) => x.title === title);
  if (!s) throw new Error('找不到小节：' + title);
  return s;
}

function section(title, body) {
  return `## ${title}\n\n${body.trim()}\n`;
}

function group(title, parts) {
  return `# ${title}\n\n${parts.join('\n')}`;
}

const introMd = read('00_导言.md')
  .split('\n')
  .map((line) => {
    if (/^### /.test(line)) return '#### ' + line.slice(4);
    if (/^## /.test(line)) return '### ' + line.slice(3);
    if (/^# /.test(line)) return '## ' + line.slice(2);
    return line;
  })
  .join('\n')
  // 导言里的示例事件头不能被校验器当作真实事件解析
  .replace(/<!--\s*event\r?\n/g, '<!-- event（示例，不参与校验）\n');

const c = splitH2(read('序章章间结局.md'));
const a = splitH2(read('第一章.md'));
const b = splitH2(read('第二章.md'));

const parts = [];

parts.push(`# 《未尽之托》Demo 剧情脚本 v1.0

- 版本：v1.0（2026-10-25）
- 上一版：[Demo 剧情脚本 v0.5](历史/旧版本/Demo剧情脚本_v0_5.md)（已归档，仅作节点事实溯源）
- 上游依据：[剧情大纲](../剧情大纲.md)（根目录）、[创作基准](剧情/00_创作基准.md)、[Demo 范围](Demo范围.md)、[首批内容数据](首批内容.json)
- 本版范围：Demo 两章四任务（report / slides / invite / photos）× 大学生 / 公司员工，117 个事件块；单/双人变体按在场成员抽取。
- 机器可读：事件头由 \`_build/validate_story.cjs\` 校验，校验记录见文末。
- 本版不包含：真实模型 API、配音、美术替换、游戏内接入代码；文本尚未接入 \`game/\`。

---

## 怎么读这份脚本

1. 每个事件块先看 \`<!-- event ... -->\` 头：\`id\` 决定它属于哪章、哪任务、哪阶段、哪节点；\`facts\` 决定它是否给语境事实；\`focus\` 是本节点的关键发现者。
2. 正文中「主句」按在场角色抽取一句；「搭档回应」是接话，只取主句角色之外的在队者一句；单人局没有搭档回应。
3. 「固定台词」「演出」「旁白」「收束」不参与随机抽取，按类型整段播放。
4. 现实片段只属于对应人生阶段，不与其他任务的对白混拼。
5. 写作与数据契约详见 \`docs/剧情/00_创作基准.md\`；本导言是它的压缩版。

---

${introMd.trim()}

`);

// 序章
const prologue = find(c.sections, '序章');
parts.push(group('序章', [prologue.body.join('\n')]));

// 第一章：学生 / 员工，各自 任务一 → 任务二 → 章间
function chapterOne(stage) {
  const taskReport = find(a.sections, `第一章 · 任务「把本周做成一页」· ${stage}版`);
  const taskSlides = find(a.sections, `第一章 · 任务「最后一页」· ${stage}版`);
  const interlude = find(c.sections, `第一章 · 章间站点 · ${stage}版`);
  return [
    section(taskReport.title, taskReport.body.join('\n')),
    section(taskSlides.title, taskSlides.body.join('\n')),
    section(interlude.title, interlude.body.join('\n')),
  ];
}

parts.push(group('第一章 · 纸页旷野', [
  '**本章：** 接「把本周做成一页」与「最后一页」两个委托；章末 Boss 为「本次提交版」。学生版与员工版是同一章的两套人生阶段文本，不可混拼。\n',
  '**学生版**\n',
  ...chapterOne('学生'),
  '**员工版**\n',
  ...chapterOne('员工'),
]));

// 第二章：学生 / 员工，各自 invite → photos → 章间 → 普通战与章底 → 结局
function chapterTwo(stage) {
  const invite = find(b.sections, `第二章 · 任务「请留一个座位」· ${stage}版`);
  const photos = find(b.sections, `第二章 · 任务「把那一天找回来」· ${stage}版`);
  const interlude = find(c.sections, `第二章 · 章间站点 · ${stage}版`);
  const battle = find(b.sections, `第二章 · 普通战与章底 · ${stage}版`);
  const groups = splitH3(interlude.body);
  const interludeGroups = groups.filter((g) => !g.title.includes('结局'));
  const endingGroups = groups.filter((g) => g.title.includes('结局'));
  return [
    section(invite.title, invite.body.join('\n')),
    section(photos.title, photos.body.join('\n')),
    ...interludeGroups.map((g) => g.body),
    section(battle.title, battle.body.join('\n')),
    ...endingGroups.map((g) => g.body),
  ];
}

parts.push(group('第二章 · 收件站', [
  '**本章：** 接「请留一个座位」与「把那一天找回来」两个委托；章末 Boss 为「请确认收件人」。章间末尾是「暂存明天」结局的两个分支。\n',
  '**学生版**\n',
  ...chapterTwo('学生'),
  '**员工版**\n',
  ...chapterTwo('员工'),
]));

// 挑战与长期附录
const stageBoss = find(b.sections, '附录 · 阶段专属 Boss（挑战配置，默认关闭）');
const hidden = find(b.sections, '附录 · 隐藏 Boss「我」');
const future = find(c.sections, '长期附录 · 六个结局方向');
parts.push(group('挑战附录与长期方向', [
  '**说明：** 以下内容默认不出现；阶段专属 Boss 需开启挑战，隐藏「我」需常规通关且 D > T（Demo 阈值 T=1）。长期六结局只记录方向，不是本轮实现文本。\n',
  section(stageBoss.title, stageBoss.body.join('\n')),
  section(hidden.title, hidden.body.join('\n')),
  section(future.title, future.body.join('\n')),
]));

// 收藏回顾
const recap1 = find(a.sections, '收藏回顾 · 第一章');
const recap2 = find(b.sections, '收藏回顾');
parts.push(group('收藏回顾', [
  section(recap1.title, recap1.body.join('\n')),
  section(recap2.title, recap2.body.join('\n')),
]));

const out = parts.join('\n').replace(/\n{4,}/g, '\n\n\n') + '\n';

// 统一事件小标题口径（不同写手用过中英混排）
const headingMap = [
  [/^### SUCCESS · /gm, '### 成功 · '],
  [/^### ACCEPT FAIL · /gm, '### 验收失败 · '],
  [/^### PREP FAIL · /gm, '### 准备失败 · '],
  [/^### STAGE BOSS · /gm, '### 阶段 Boss · '],
  [/^### HIDDEN · /gm, '### 隐藏「我」 · '],
  [/^### RECAP · /gm, '### 回顾 · '],
  [/^### BOSS · /gm, '### Boss · '],
  [/^### 章开 · /gm, '### 章首 · '],
  [/^### B1 一战 · /gm, '### B1 战斗 · '],
  [/^### B2 二战 · /gm, '### B2 战斗 · '],
];
let finalOut = out;
for (const [re, rep] of headingMap) finalOut = finalOut.replace(re, rep);

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, finalOut, 'utf8');

const events = (finalOut.match(/<!--\s*event\r?\n/g) || []).length;
console.log(`已写入 ${OUT}`);
console.log(`字符数：${finalOut.length}，事件块：${events}`);
if (events !== 117) {
  console.error(`事件数异常：期望 117，实际 ${events}`);
  process.exit(1);
}
