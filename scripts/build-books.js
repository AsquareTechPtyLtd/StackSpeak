#!/usr/bin/env node
// Build tool: walk `content/books/` and emit the structured ContentBlock JSON
// the iOS app consumes under `shared/`.
//
// Authoring format (per chapter file):
//   @chapter
//   id: <chapter-id>
//   order: <int>
//   title: <string>
//   summary: <string>
//   icon: <SF Symbol name>
//
//   @card
//   id: <card-id>
//   order: <int>
//   title: <string>
//   teaser: <string>
//
//   @explanation
//   <markdown body — block vocabulary v1: paragraph/heading/list/code/callout/image>
//
//   @feynman
//   <markdown body>
//
//   @card
//   ...
//
// Block vocabulary v1: paragraph, heading, list, code, callout, image.
// Inline marks v1: bold, italic, code, link.
//
// Dependency-free — Node 18+ stdlib only.

'use strict';

const CALLOUT_VARIANTS = new Set(['info', 'tip', 'warning']);

// Locked taxonomy of book categories. Every `book.json` MUST carry `categories: [...]`
// with each entry drawn from this set. See `.planning/library-expansion-phase-4-2026-05-03.md`
// → "Locked: Library Categories" for the contract behind these IDs.
const BOOK_CATEGORIES = new Set([
  'ai-ml',
  'architecture',
  'code-craft',
  'cloud',
  'data',
  'testing',
  'people'
]);

function validateCategories(bookMeta) {
  const cats = bookMeta.categories;
  if (!Array.isArray(cats) || cats.length === 0) {
    throw new Error(
      `Book "${bookMeta.id}" is missing required field "categories" (non-empty string array). ` +
      `Allowed IDs: ${[...BOOK_CATEGORIES].sort().join(', ')}.`
    );
  }
  for (const c of cats) {
    if (typeof c !== 'string' || !BOOK_CATEGORIES.has(c)) {
      throw new Error(
        `Book "${bookMeta.id}" has unknown category "${c}". ` +
        `Allowed: ${[...BOOK_CATEGORIES].sort().join(', ')}.`
      );
    }
  }
  if (new Set(cats).size !== cats.length) {
    throw new Error(`Book "${bookMeta.id}" has duplicate categories: ${cats.join(', ')}.`);
  }
}

// ─────────────────────────────────────────────────────────────────
// Markdown → ContentBlock parser (preserves the Phase 1 API)
// ─────────────────────────────────────────────────────────────────

function parseMarkdown(text) {
  const lines = text.split('\n');
  const blocks = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === '') { i++; continue; }

    // Heading: "## …" or "### …"
    const heading = line.match(/^(#{2,3})\s+(.+?)\s*$/);
    if (heading) {
      blocks.push({ type: 'heading', level: heading[1].length, text: heading[2] });
      i++;
      continue;
    }

    if (/^#\s+/.test(line)) {
      throw new Error(`Unsupported markdown: top-level heading (#) at line ${i + 1}. Use ## or ###.`);
    }

    // Fenced code: ```lang\n…\n```
    if (line.startsWith('```')) {
      const language = line.slice(3).trim();
      const code = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        code.push(lines[i]);
        i++;
      }
      if (i >= lines.length) {
        throw new Error('Unterminated fenced code block.');
      }
      i++;
      blocks.push({ type: 'code', language, code: code.join('\n') });
      continue;
    }

    // Image: "![alt](path)"
    const image = line.match(/^!\[([^\]]*)\]\(([^)]+)\)\s*$/);
    if (image) {
      const caption = image[1] === '' ? null : image[1];
      blocks.push({ type: 'image', asset: image[2], caption });
      i++;
      continue;
    }

    // Callout: "> [!info|tip|warning] text…" with optional "> …" follow-on
    const callout = line.match(/^>\s*\[!([a-z]+)\]\s*(.*)$/i);
    if (callout) {
      const variant = callout[1].toLowerCase();
      if (!CALLOUT_VARIANTS.has(variant)) {
        throw new Error(`Unsupported callout variant "${variant}" at line ${i + 1}. Use info, tip, or warning.`);
      }
      const buf = [callout[2]];
      i++;
      while (i < lines.length && lines[i].startsWith('>')) {
        buf.push(lines[i].replace(/^>\s?/, ''));
        i++;
      }
      blocks.push({
        type: 'callout',
        variant,
        runs: parseInline(buf.join(' ').trim())
      });
      continue;
    }

    if (line.startsWith('>')) {
      throw new Error(`Unsupported markdown: plain blockquote at line ${i + 1}. Use callouts: "> [!info] …".`);
    }

    if (/^[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i])) {
        items.push(parseInline(lines[i].replace(/^[-*]\s+/, '')));
        i++;
      }
      blocks.push({ type: 'list', style: 'bulleted', items });
      continue;
    }

    if (/^\d+\.\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
        items.push(parseInline(lines[i].replace(/^\d+\.\s+/, '')));
        i++;
      }
      blocks.push({ type: 'list', style: 'numbered', items });
      continue;
    }

    if (line.startsWith('|')) {
      throw new Error(`Unsupported markdown: tables at line ${i + 1}. Tables are not in block vocabulary v1.`);
    }
    if (line.startsWith('<')) {
      throw new Error(`Unsupported markdown: raw HTML at line ${i + 1}.`);
    }

    // Paragraph: collect until blank or block-starter
    const para = [line];
    i++;
    while (i < lines.length && lines[i].trim() !== '' && !isBlockStart(lines[i])) {
      para.push(lines[i]);
      i++;
    }
    blocks.push({ type: 'paragraph', runs: parseInline(para.join(' ')) });
  }

  return blocks;
}

function isBlockStart(line) {
  return (
    /^(#{1,6})\s/.test(line) ||
    line.startsWith('```') ||
    /^!\[[^\]]*\]\(/.test(line) ||
    /^>\s/.test(line) ||
    /^[-*]\s+/.test(line) ||
    /^\d+\.\s+/.test(line) ||
    line.startsWith('|') ||
    line.startsWith('<')
  );
}

function parseInline(text) {
  const runs = [];
  let cursor = 0;
  let plainStart = 0;

  const flushPlain = (end) => {
    if (end > plainStart) {
      runs.push({ text: text.slice(plainStart, end) });
    }
  };

  while (cursor < text.length) {
    const ch = text[cursor];

    if (ch === '*' && text[cursor + 1] === '*') {
      const end = text.indexOf('**', cursor + 2);
      if (end > -1) {
        flushPlain(cursor);
        runs.push({ text: text.slice(cursor + 2, end), marks: ['bold'] });
        cursor = end + 2;
        plainStart = cursor;
        continue;
      }
    }

    if (ch === '*' && text[cursor + 1] !== '*' && (cursor === 0 || text[cursor - 1] !== '*')) {
      let end = text.indexOf('*', cursor + 1);
      while (end > -1 && text[end + 1] === '*') {
        end = text.indexOf('*', end + 2);
      }
      if (end > -1) {
        flushPlain(cursor);
        runs.push({ text: text.slice(cursor + 1, end), marks: ['italic'] });
        cursor = end + 1;
        plainStart = cursor;
        continue;
      }
    }

    if (ch === '`') {
      const end = text.indexOf('`', cursor + 1);
      if (end > -1) {
        flushPlain(cursor);
        runs.push({ text: text.slice(cursor + 1, end), marks: ['code'] });
        cursor = end + 1;
        plainStart = cursor;
        continue;
      }
    }

    if (ch === '[') {
      const labelEnd = text.indexOf(']', cursor + 1);
      if (labelEnd > -1 && text[labelEnd + 1] === '(') {
        const hrefEnd = text.indexOf(')', labelEnd + 2);
        if (hrefEnd > -1) {
          flushPlain(cursor);
          runs.push({
            text: text.slice(cursor + 1, labelEnd),
            marks: ['link'],
            href: text.slice(labelEnd + 2, hrefEnd)
          });
          cursor = hrefEnd + 1;
          plainStart = cursor;
          continue;
        }
      }
    }

    cursor++;
  }

  flushPlain(text.length);
  return runs;
}

// ─────────────────────────────────────────────────────────────────
// Chapter file (@chapter / @card / @explanation / @feynman) parser
// ─────────────────────────────────────────────────────────────────

/** Splits a chapter file into `@<kind>` sections. Each section keeps its
 *  body lines verbatim so parseMarkdown sees clean markdown. */
const SECTION_DIRECTIVES = new Set(['chapter', 'card', 'explanation', 'feynman']);

function tokenizeSections(text) {
  const lines = text.split('\n');
  const sections = [];
  let current = null;
  let inFence = false;
  for (const line of lines) {
    if (line.startsWith('```')) {
      inFence = !inFence;
      if (current) current.lines.push(line);
      continue;
    }
    const m = line.match(/^@(\w+)\s*$/);
    if (m && !inFence && SECTION_DIRECTIVES.has(m[1].toLowerCase())) {
      if (current) sections.push(current);
      current = { kind: m[1].toLowerCase(), lines: [] };
    } else if (current) {
      current.lines.push(line);
    } else if (line.trim() !== '') {
      throw new Error(`Content before first @-marker: ${JSON.stringify(line)}`);
    }
  }
  if (current) sections.push(current);
  return sections;
}

/** Simple key:value metadata parser. Strips quotes; coerces integers. */
function parseMetadataLines(lines) {
  const meta = {};
  for (const raw of lines) {
    const line = raw.trim();
    if (line === '') continue;
    const m = line.match(/^([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$/);
    if (!m) {
      throw new Error(`Invalid metadata line (expected "key: value"): ${JSON.stringify(raw)}`);
    }
    const key = m[1];
    let value = m[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (/^-?\d+$/.test(value)) {
      meta[key] = parseInt(value, 10);
    } else if (value === 'true' || value === 'false') {
      meta[key] = value === 'true';
    } else {
      meta[key] = value;
    }
  }
  return meta;
}

/** Returns { chapter, cards: [BookCard] } from a chapter markdown file. */
function parseChapterFile(text) {
  const sections = tokenizeSections(text);
  let chapter = null;
  const cards = [];
  let i = 0;

  while (i < sections.length) {
    const section = sections[i];
    if (section.kind === 'chapter') {
      chapter = parseMetadataLines(section.lines);
      i++;
      continue;
    }
    if (section.kind === 'card') {
      const meta = parseMetadataLines(section.lines);
      let explanation = [];
      let feynman = [];
      i++;
      while (i < sections.length && sections[i].kind !== 'card') {
        const body = sections[i].lines.join('\n').trim();
        if (sections[i].kind === 'explanation') {
          explanation = parseMarkdown(body);
        } else if (sections[i].kind === 'feynman') {
          feynman = parseMarkdown(body);
        } else {
          throw new Error(`Unknown section "@${sections[i].kind}" inside card "${meta.id}".`);
        }
        i++;
      }
      if (meta.id == null || meta.title == null || meta.teaser == null) {
        throw new Error(`Card missing required metadata (id/title/teaser): ${JSON.stringify(meta)}`);
      }
      cards.push({
        id: String(meta.id),
        order: meta.order ?? cards.length + 1,
        title: String(meta.title),
        teaser: String(meta.teaser),
        explanation,
        feynman
      });
      continue;
    }
    // Skip any unknown top-level section — forward-compatible.
    i++;
  }

  if (!chapter) {
    throw new Error('Chapter file is missing a @chapter section.');
  }
  if (chapter.id == null || chapter.title == null) {
    throw new Error('Chapter @chapter section is missing required keys (id/title).');
  }
  return { chapter, cards };
}

// ─────────────────────────────────────────────────────────────────
// Build pipeline: content/books/<id>/  →  shared/books/<id>/  + catalog
// ─────────────────────────────────────────────────────────────────

function buildBook(bookDir, sharedRoot, fs, path) {
  const bookMetaPath = path.join(bookDir, 'book.json');
  if (!fs.existsSync(bookMetaPath)) {
    throw new Error(`Missing book.json at ${bookMetaPath}`);
  }
  const bookMeta = JSON.parse(fs.readFileSync(bookMetaPath, 'utf8'));
  validateCategories(bookMeta);
  const chaptersSrc = path.join(bookDir, 'chapters');
  if (!fs.existsSync(chaptersSrc)) {
    throw new Error(`Missing chapters/ directory at ${chaptersSrc}`);
  }

  const chapterFiles = fs.readdirSync(chaptersSrc)
    .filter(f => f.endsWith('.md'))
    .sort();

  const bookSharedDir = path.join(sharedRoot, 'books', bookMeta.id);
  fs.rmSync(bookSharedDir, { recursive: true, force: true });
  fs.mkdirSync(path.join(bookSharedDir, 'chapters'), { recursive: true });

  const chapters = [];
  let totalCards = 0;
  let totalSize = 0;

  for (const file of chapterFiles) {
    const text = fs.readFileSync(path.join(chaptersSrc, file), 'utf8');
    const { chapter: chapterMeta, cards } = parseChapterFile(text);

    cards.sort((a, b) => a.order - b.order);

    const shardName = `${chapterMeta.id}.json`;
    const shard = {
      chapterId: chapterMeta.id,
      shardIndex: 1,
      cards
    };
    const shardJson = JSON.stringify(shard, null, 2);
    fs.writeFileSync(path.join(bookSharedDir, 'chapters', shardName), shardJson);
    totalSize += Buffer.byteLength(shardJson, 'utf8');
    totalCards += cards.length;

    chapters.push({
      id: chapterMeta.id,
      order: chapterMeta.order ?? chapters.length + 1,
      title: chapterMeta.title,
      summary: chapterMeta.summary ?? '',
      icon: chapterMeta.icon ?? 'book',
      cardCount: cards.length,
      cardIds: cards.map(c => c.id),
      shards: [`chapters/${shardName}`]
    });
  }

  chapters.sort((a, b) => a.order - b.order);

  const manifest = {
    id: bookMeta.id,
    version: bookMeta.manifestVersion ?? 1,
    title: bookMeta.title,
    author: bookMeta.author ?? null,
    summary: bookMeta.summary,
    categories: [...bookMeta.categories],
    chapters
  };
  const manifestJson = JSON.stringify(manifest, null, 2);
  fs.writeFileSync(path.join(bookSharedDir, 'manifest.json'), manifestJson);
  totalSize += Buffer.byteLength(manifestJson, 'utf8');

  return {
    id: bookMeta.id,
    title: bookMeta.title,
    author: bookMeta.author ?? null,
    summary: bookMeta.summary,
    coverIcon: bookMeta.coverIcon ?? 'book',
    accentHex: bookMeta.accentHex ?? null,
    tags: Array.isArray(bookMeta.tags) ? bookMeta.tags : [],
    categories: [...bookMeta.categories],
    chapterCount: chapters.length,
    cardCount: totalCards,
    manifestVersion: manifest.version,
    manifestPath: `books/${bookMeta.id}/manifest.json`,
    freeForAll: !!bookMeta.freeForAll,
    sizeBytes: totalSize
  };
}

function buildAllBooks(contentRoot, sharedRoot) {
  const fs = require('node:fs');
  const path = require('node:path');
  const booksRoot = path.join(contentRoot, 'books');
  if (!fs.existsSync(booksRoot)) {
    console.log(`No content/books/ at ${booksRoot} — nothing to build.`);
    return;
  }
  fs.mkdirSync(sharedRoot, { recursive: true });

  const summaries = [];
  for (const name of fs.readdirSync(booksRoot).sort()) {
    const dir = path.join(booksRoot, name);
    if (!fs.statSync(dir).isDirectory()) continue;
    const summary = buildBook(dir, sharedRoot, fs, path);
    summaries.push(summary);
    console.log(`  ✓ ${summary.id} — ${summary.chapterCount} chapter(s), ${summary.cardCount} card(s)`);
  }

  // Free book first, then alphabetical by title — gives the catalog a stable order.
  summaries.sort((a, b) => {
    if (a.freeForAll !== b.freeForAll) return a.freeForAll ? -1 : 1;
    return a.title.localeCompare(b.title);
  });

  const catalog = {
    version: 1,
    updatedAt: new Date().toISOString(),
    books: summaries
  };
  fs.writeFileSync(
    path.join(sharedRoot, 'books-catalog.json'),
    JSON.stringify(catalog, null, 2)
  );
  console.log(`✓ Wrote ${summaries.length} book(s) and catalog at ${sharedRoot}/books-catalog.json`);
}

module.exports = {
  parseMarkdown,
  parseInline,
  parseChapterFile,
  parseMetadataLines,
  tokenizeSections,
  buildAllBooks,
  buildBook,
  validateCategories,
  BOOK_CATEGORIES
};

// CLI:
//   node scripts/build-books.js                   → build content/ → shared/
//   node scripts/build-books.js parse <file.md>   → print parsed blocks for a single body file
//   node scripts/build-books.js chapter <file.md> → print parsed chapter (cards + metadata)
if (require.main === module) {
  const fs = require('node:fs');
  const path = require('node:path');
  const args = process.argv.slice(2);
  const mode = args[0] ?? 'build';

  const repoRoot = path.resolve(__dirname, '..');

  if (mode === 'build') {
    buildAllBooks(
      path.join(repoRoot, 'content'),
      path.join(repoRoot, 'shared')
    );
  } else if (mode === 'parse') {
    const file = path.resolve(args[1]);
    const md = fs.readFileSync(file, 'utf8');
    process.stdout.write(JSON.stringify(parseMarkdown(md), null, 2) + '\n');
  } else if (mode === 'chapter') {
    const file = path.resolve(args[1]);
    const text = fs.readFileSync(file, 'utf8');
    process.stdout.write(JSON.stringify(parseChapterFile(text), null, 2) + '\n');
  } else {
    console.error(`Unknown mode "${mode}". Use: build | parse <file> | chapter <file>`);
    process.exit(1);
  }
}
