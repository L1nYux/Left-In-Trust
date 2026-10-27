#!/usr/bin/env node
/**
 * Export the validated Markdown story and repeat-chat pools into one runtime file.
 *
 * Usage:
 *   node _build/export_story_runtime.cjs
 *   node _build/export_story_runtime.cjs --check
 */
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const checkOnly = process.argv.slice(2).includes('--check');
const storyPath = path.join('docs', 'Demo剧情脚本.md');
const chatPath = path.join('docs', '剧情', '日常闲聊台词.json');
const outputPath = path.join('game', 'data', 'story.json');

function canonSection(name) {
  const value = name.trim();
  if (value.startsWith('场景')) return 'scene';
  if (value.startsWith('主句')) return 'main';
  if (value.startsWith('搭档')) return 'partner';
  if (value.startsWith('固定')) return 'fixed';
  if (value.startsWith('演出')) return 'staging';
  if (value.startsWith('旁白')) return 'narration';
  if (value.startsWith('收束')) return 'closing';
  if (value.startsWith('重复')) return 'repeat';
  if (value.startsWith('分支')) return 'branch';
  return null;
}

function parseHeader(raw) {
  const result = {};
  for (const line of raw.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$/);
    if (match) result[match[1]] = match[2];
  }
  return result;
}

function nearestHeading(source, before) {
  const lines = source.slice(0, before).split(/\r?\n/);
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const match = lines[index].match(/^#{2,4}\s+(.+?)\s*$/);
    if (match) return match[1];
  }
  return '';
}

/**
 * 数据卫生：`**场景**：` 等段落正文偶尔会把 Markdown 标题行（`#` / `##` / `###` 开头）
 * 一起吞进来。根因是事件块的 body 一直延伸到下一个 `<!-- event` 标记，而拼装器会在
 * 每个事件末尾附上下一个事件的标题；导出后它变成上一个事件某个 section 里的
 * `{kind:"text", text:"### xxx"}`，运行时会当作正文渲染（固定/场景/分支页可见）。
 * 这里只删「去空白后以 # 开头的 kind:text 项」，kind:"line" 与其它正文一概不动。
 */
function isMarkdownHeadingText(value) {
  return typeof value === 'string' && value.trim().startsWith('#');
}

function stripHeadingTextItems(events) {
  let removed = 0;
  for (const event of events) {
    for (const items of Object.values(event.sections)) {
      for (let index = items.length - 1; index >= 0; index -= 1) {
        const item = items[index];
        if (item.kind === 'text' && isMarkdownHeadingText(item.text)) {
          items.splice(index, 1);
          removed += 1;
        }
      }
    }
  }
  return removed;
}

function parseEvents(source) {
  const marker = /<!--\s*event\r?\n([\s\S]*?)-->/g;
  const marks = [];
  let match;
  while ((match = marker.exec(source)) !== null) {
    marks.push({ header: match[1], start: match.index, end: marker.lastIndex });
  }
  return marks.map((mark, index) => {
    const bodyEnd = index + 1 < marks.length ? marks[index + 1].start : source.length;
    const body = source.slice(mark.end, bodyEnd);
    const sections = {};
    const sectionOrder = [];
    let current = null;
    for (const rawLine of body.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line) continue;
      const sectionMatch = line.match(/^\*\*([^*]+?)\*\*\s*[：:]?\s*(.*)$/);
      if (sectionMatch) {
        const key = canonSection(sectionMatch[1]);
        if (key) {
          current = key;
          if (!sections[key]) {
            sections[key] = [];
            sectionOrder.push(key);
          }
          if (sectionMatch[2]) sections[key].push({ kind: 'text', text: sectionMatch[2] });
          continue;
        }
        current = null;
        continue;
      }
      if (current && /^[-*]\s+/.test(line)) {
        const lineMatch = line.replace(/^[-*]\s+/, '').match(/^([^：:]{1,12})[：:]\s*(.+)$/);
        if (lineMatch) {
          sections[current].push({
            kind: 'line',
            speaker: lineMatch[1].trim(),
            text: lineMatch[2].trim(),
          });
          continue;
        }
      }
      if (current) sections[current].push({ kind: 'text', text: line });
    }
    return {
      ...parseHeader(mark.header),
      title: nearestHeading(source, mark.start),
      sectionOrder,
      sections,
    };
  });
}

if (!fs.existsSync(storyPath) || !fs.existsSync(chatPath)) {
  console.error('Missing story source files.');
  process.exit(2);
}

const storyRaw = fs.readFileSync(storyPath, 'utf8').replace(/\r\n/g, '\n');
const chatRaw = fs.readFileSync(chatPath, 'utf8').replace(/\r\n/g, '\n');
const events = parseEvents(storyRaw);
const strippedHeadingItems = stripHeadingTextItems(events);
const chat = JSON.parse(chatRaw);
const sourceHash = crypto.createHash('sha256').update(storyRaw).update('\0').update(chatRaw).digest('hex');
const runtime = {
  version: '1.0',
  sourceHash,
  generatedFrom: [storyPath, chatPath],
  supportedStoryStages: ['student', 'employee'],
  events,
  chatPools: chat.pools || [],
};

if (events.length !== 117) {
  console.error(`Expected 117 story events, found ${events.length}.`);
  process.exit(1);
}

if (strippedHeadingItems > 0) {
  // 现状 127 条（fixed 15 / scene 28 / branch 9 / partner 26 / closing 21 / repeat 28），
  // 属源码结构噪声；拼装器修好后此计数应自然归零。
  console.log(`Filtered ${strippedHeadingItems} markdown-heading text item(s) from story sections.`);
}

if (checkOnly) {
  if (!fs.existsSync(outputPath)) {
    console.error(`Missing generated runtime story: ${outputPath}`);
    process.exit(1);
  }
  let current;
  try {
    current = JSON.parse(fs.readFileSync(outputPath, 'utf8'));
  } catch (error) {
    console.error(`Invalid runtime story JSON (${outputPath}): ${error.message}`);
    process.exit(1);
  }
  // 结构比对：sourceHash 只反映输入文档，不反映导出逻辑（例如标题过滤/分段规则）的变更，
  // 所以必须同时比较完整产物，否则改了导出规则而 `--check` 仍会谎报 current。
  const stale = current.sourceHash !== sourceHash
    || !Array.isArray(current.events) || current.events.length !== 117
    || JSON.stringify(current) !== JSON.stringify(runtime);
  if (stale) {
    console.error('Runtime story is stale. Run node _build/export_story_runtime.cjs');
    process.exit(1);
  }
  console.log(`Runtime story is current (${events.length} events, ${sourceHash})`);
  process.exit(0);
}

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(runtime, null, 2)}\n`, 'utf8');
console.log(`Wrote ${outputPath}: ${events.length} events, ${runtime.chatPools.length} chat pools`);
console.log(`SHA256 ${sourceHash}`);
