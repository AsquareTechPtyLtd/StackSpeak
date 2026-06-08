// Tests for scripts/build-books.js. Run with: `node --test scripts/build-books.test.js`
// Uses Node's built-in test runner — no npm dependencies (matches CLAUDE.md "no SPM deps"
// spirit on the engineering side).

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  parseMarkdown,
  parseInline,
  parseChapterFile,
  parseMetadataLines,
  buildAllBooks,
  hasMarkdownSource,
  validateCategories,
  validateFreshnessFields,
  BOOK_CATEGORIES,
  REFRESH_CADENCES,
  SOURCE_FORMATS
} = require('./build-books.js');

test('parseInline — plain text becomes a single run with no marks', () => {
  assert.deepEqual(parseInline('hello world'), [{ text: 'hello world' }]);
});

test('parseInline — bold + italic + code + link in one paragraph', () => {
  const runs = parseInline('an **agent** *decides* what to `run` and links to [docs](https://x.example).');
  assert.deepEqual(runs, [
    { text: 'an ' },
    { text: 'agent', marks: ['bold'] },
    { text: ' ' },
    { text: 'decides', marks: ['italic'] },
    { text: ' what to ' },
    { text: 'run', marks: ['code'] },
    { text: ' and links to ' },
    { text: 'docs', marks: ['link'], href: 'https://x.example' },
    { text: '.' }
  ]);
});

test('parseMarkdown — heading levels 2 and 3', () => {
  const blocks = parseMarkdown('## Two\n\n### Three');
  assert.deepEqual(blocks, [
    { type: 'heading', level: 2, text: 'Two' },
    { type: 'heading', level: 3, text: 'Three' }
  ]);
});

test('parseMarkdown — h1 is rejected (reserved for card title)', () => {
  assert.throws(() => parseMarkdown('# Top'), /top-level heading/);
});

test('parseMarkdown — paragraph collects continuation lines and parses inline marks', () => {
  const blocks = parseMarkdown('First **line**\nstill same paragraph.');
  assert.deepEqual(blocks, [
    {
      type: 'paragraph',
      runs: [
        { text: 'First ' },
        { text: 'line', marks: ['bold'] },
        { text: ' still same paragraph.' }
      ]
    }
  ]);
});

test('parseMarkdown — bulleted list with - and *', () => {
  const blocks = parseMarkdown('- one\n- two\n* three');
  assert.equal(blocks.length, 1);
  assert.equal(blocks[0].type, 'list');
  assert.equal(blocks[0].style, 'bulleted');
  assert.equal(blocks[0].items.length, 3);
  assert.deepEqual(blocks[0].items[0], [{ text: 'one' }]);
  assert.deepEqual(blocks[0].items[2], [{ text: 'three' }]);
});

test('parseMarkdown — numbered list', () => {
  const blocks = parseMarkdown('1. first\n2. second');
  assert.equal(blocks.length, 1);
  assert.deepEqual(blocks[0], {
    type: 'list',
    style: 'numbered',
    items: [
      [{ text: 'first' }],
      [{ text: 'second' }]
    ]
  });
});

test('parseMarkdown — fenced code block with language', () => {
  const blocks = parseMarkdown('```python\ndef step():\n    pass\n```');
  assert.deepEqual(blocks, [
    { type: 'code', language: 'python', code: 'def step():\n    pass' }
  ]);
});

test('parseMarkdown — fenced code block with no language', () => {
  const blocks = parseMarkdown('```\nplain code\n```');
  assert.deepEqual(blocks, [{ type: 'code', language: '', code: 'plain code' }]);
});

test('parseMarkdown — unterminated fenced code is rejected', () => {
  assert.throws(() => parseMarkdown('```py\nno close'), /Unterminated/);
});

test('parseMarkdown — info callout', () => {
  const blocks = parseMarkdown('> [!info] watch for **drift**');
  assert.deepEqual(blocks, [
    {
      type: 'callout',
      variant: 'info',
      runs: [
        { text: 'watch for ' },
        { text: 'drift', marks: ['bold'] }
      ]
    }
  ]);
});

test('parseMarkdown — tip and warning callout variants', () => {
  const tip = parseMarkdown('> [!tip] go light');
  const warn = parseMarkdown('> [!warning] danger');
  assert.equal(tip[0].variant, 'tip');
  assert.equal(warn[0].variant, 'warning');
});

test('parseMarkdown — multiline callout joins follow-on > lines', () => {
  const blocks = parseMarkdown('> [!info] one\n> two');
  assert.equal(blocks.length, 1);
  assert.equal(blocks[0].runs[0].text, 'one two');
});

test('parseMarkdown — unknown callout variant throws', () => {
  assert.throws(() => parseMarkdown('> [!banana] nope'), /variant/);
});

test('parseMarkdown — plain blockquote (without [!variant]) is rejected', () => {
  assert.throws(() => parseMarkdown('> just a quote'), /blockquote/);
});

test('parseMarkdown — image with caption', () => {
  const blocks = parseMarkdown('![A diagram](diagram.png)');
  assert.deepEqual(blocks, [
    { type: 'image', asset: 'diagram.png', caption: 'A diagram' }
  ]);
});

test('parseMarkdown — image without caption (empty alt) returns null caption', () => {
  const blocks = parseMarkdown('![](diagram.png)');
  assert.deepEqual(blocks, [
    { type: 'image', asset: 'diagram.png', caption: null }
  ]);
});

test('parseMarkdown — tables are rejected with a clear error', () => {
  assert.throws(() => parseMarkdown('| a | b |\n| - | - |\n| 1 | 2 |'), /tables/i);
});

test('parseMarkdown — raw HTML is rejected', () => {
  assert.throws(() => parseMarkdown('<div>nope</div>'), /HTML/);
});

test('parseMetadataLines — coerces ints and strips quotes', () => {
  const meta = parseMetadataLines([
    'id: aiadg-ch01-c001',
    'order: 3',
    'title: "Hello, world"',
    "summary: 'with single quotes'",
    'freeForAll: true'
  ]);
  assert.deepEqual(meta, {
    id: 'aiadg-ch01-c001',
    order: 3,
    title: 'Hello, world',
    summary: 'with single quotes',
    freeForAll: true
  });
});

test('parseChapterFile — parses chapter + cards with explanation/feynman blocks', () => {
  const text = [
    '@chapter',
    'id: ch01',
    'order: 1',
    'title: First Chapter',
    'summary: A chapter.',
    'icon: book',
    '',
    '@card',
    'id: c001',
    'order: 1',
    'title: First Card',
    'teaser: A teaser.',
    '',
    '@explanation',
    '',
    'A paragraph in the **explanation**.',
    '',
    '@feynman',
    '',
    'An analogy.',
    '',
    '@card',
    'id: c002',
    'order: 2',
    'title: Second Card',
    'teaser: Another teaser.',
    '',
    '@explanation',
    '',
    'Second card explanation.',
    '',
    '@feynman',
    '',
    'Second analogy.',
  ].join('\n');

  const { chapter, cards } = parseChapterFile(text);
  assert.equal(chapter.id, 'ch01');
  assert.equal(chapter.title, 'First Chapter');
  assert.equal(cards.length, 2);
  assert.equal(cards[0].id, 'c001');
  assert.equal(cards[0].title, 'First Card');
  assert.equal(cards[0].explanation[0].type, 'paragraph');
  assert.equal(cards[0].feynman[0].type, 'paragraph');
  assert.equal(cards[1].id, 'c002');
});

test('parseChapterFile — rejects card missing required fields', () => {
  const text = [
    '@chapter',
    'id: ch01',
    'title: T',
    '',
    '@card',
    'id: c001',
    '@explanation',
    'body'
  ].join('\n');
  assert.throws(() => parseChapterFile(text), /required metadata/);
});

test('parseChapterFile — rejects file without @chapter', () => {
  const text = '@card\nid: x\ntitle: y\nteaser: z';
  assert.throws(() => parseChapterFile(text), /@chapter/);
});

test('parseChapterFile — preserves card order from `order:` field', () => {
  const text = [
    '@chapter',
    'id: ch01',
    'title: T',
    '',
    '@card',
    'id: a',
    'order: 5',
    'title: A',
    'teaser: t',
    '',
    '@explanation',
    'x',
    '',
    '@card',
    'id: b',
    'order: 1',
    'title: B',
    'teaser: t',
    '',
    '@explanation',
    'y'
  ].join('\n');
  const { cards } = parseChapterFile(text);
  // parseChapterFile preserves declared order; sorting happens at build time.
  assert.deepEqual(cards.map(c => c.id), ['a', 'b']);
  assert.equal(cards[0].order, 5);
});

test('parseMarkdown — mixed document smoke test', () => {
  const md = [
    '## Tool-Use Loop',
    '',
    'An agent **decides**, *acts*, observes.',
    '',
    '- think',
    '- act',
    '',
    '```ts',
    'const x = 1;',
    '```',
    '',
    '> [!tip] keep loops short'
  ].join('\n');
  const blocks = parseMarkdown(md);
  assert.equal(blocks.length, 5);
  assert.equal(blocks[0].type, 'heading');
  assert.equal(blocks[1].type, 'paragraph');
  assert.equal(blocks[2].type, 'list');
  assert.equal(blocks[3].type, 'code');
  assert.equal(blocks[4].type, 'callout');
});

// ─────────────────────────────────────────────────────────────────
// validateCategories — book.json must carry valid categories
// ─────────────────────────────────────────────────────────────────

test('validateCategories — accepts a valid single-category book', () => {
  validateCategories({ id: 'b1', categories: ['code-craft'] });
});

test('validateCategories — accepts multi-category books', () => {
  validateCategories({ id: 'b2', categories: ['code-craft', 'ai-ml'] });
  validateCategories({ id: 'b3', categories: ['data', 'people'] });
});

test('validateCategories — taxonomy contains the 7 locked IDs', () => {
  assert.deepEqual(
    [...BOOK_CATEGORIES].sort(),
    ['ai-ml', 'architecture', 'cloud', 'code-craft', 'data', 'people', 'testing']
  );
});

test('validateCategories — missing categories field throws', () => {
  assert.throws(() => validateCategories({ id: 'b4' }), /missing required field "categories"/);
});

test('validateCategories — empty array throws', () => {
  assert.throws(() => validateCategories({ id: 'b5', categories: [] }), /missing required field "categories"/);
});

test('validateCategories — non-array value throws', () => {
  assert.throws(() => validateCategories({ id: 'b6', categories: 'code-craft' }), /missing required field "categories"/);
});

test('validateCategories — unknown category id throws', () => {
  assert.throws(
    () => validateCategories({ id: 'b7', categories: ['code-craft', 'frontend'] }),
    /unknown category "frontend"/
  );
});

test('validateCategories — duplicate categories throws', () => {
  assert.throws(
    () => validateCategories({ id: 'b8', categories: ['code-craft', 'code-craft'] }),
    /duplicate categories/
  );
});

test('validateCategories — non-string entry throws', () => {
  assert.throws(
    () => validateCategories({ id: 'b9', categories: ['code-craft', 42] }),
    /unknown category/
  );
});

// ─────────────────────────────────────────────────────────────────
// validateFreshnessFields — Phase 4 freshness signal validation
// ─────────────────────────────────────────────────────────────────

test('validateFreshnessFields — accepts a book with all fields absent (existing 15 books)', () => {
  validateFreshnessFields({ id: 'b1' }, []);
});

test('validateFreshnessFields — accepts asOfDate + refreshCadence pair', () => {
  validateFreshnessFields(
    { id: 'b1', asOfDate: '2026-05', refreshCadence: '18mo' },
    []
  );
});

test('validateFreshnessFields — refresh cadence enum has the 5 locked values', () => {
  assert.deepEqual([...REFRESH_CADENCES].sort(), ['12mo', '18mo', '24mo', '6mo', '9mo']);
});

test('validateFreshnessFields — source format enum has the 3 locked values', () => {
  assert.deepEqual([...SOURCE_FORMATS].sort(), ['book', 'course', 'syllabus']);
});

test('validateFreshnessFields — invalid asOfDate format throws', () => {
  for (const bad of ['2026/05', '26-05', '2026-13', '2026-1', 'May 2026']) {
    assert.throws(
      () => validateFreshnessFields({ id: 'b1', asOfDate: bad, refreshCadence: '9mo' }, []),
      /invalid asOfDate/
    );
  }
});

test('validateFreshnessFields — asOfDate without refreshCadence throws', () => {
  assert.throws(
    () => validateFreshnessFields({ id: 'b1', asOfDate: '2026-05' }, []),
    /asOfDate but no refreshCadence/
  );
});

test('validateFreshnessFields — invalid refreshCadence enum throws', () => {
  assert.throws(
    () => validateFreshnessFields({ id: 'b1', refreshCadence: '3mo' }, []),
    /invalid refreshCadence/
  );
});

test('validateFreshnessFields — volatileChapters references real chapter IDs', () => {
  validateFreshnessFields(
    {
      id: 'b1',
      asOfDate: '2026-05',
      refreshCadence: '18mo',
      volatileChapters: [
        { chapterId: 'ch13', asOfDate: '2026-05', refreshCadence: '9mo', reason: 'AI' }
      ]
    },
    ['ch01', 'ch13']
  );
});

test('validateFreshnessFields — volatileChapters with unknown chapterId throws', () => {
  assert.throws(
    () => validateFreshnessFields(
      {
        id: 'b1',
        volatileChapters: [
          { chapterId: 'ch99', asOfDate: '2026-05', refreshCadence: '9mo' }
        ]
      },
      ['ch01']
    ),
    /unknown chapterId "ch99"/
  );
});

test('validateFreshnessFields — volatileChapters without required asOfDate throws', () => {
  assert.throws(
    () => validateFreshnessFields(
      {
        id: 'b1',
        volatileChapters: [{ chapterId: 'ch01', refreshCadence: '9mo' }]
      },
      ['ch01']
    ),
    /invalid asOfDate/
  );
});

test('validateFreshnessFields — inspiredBy with valid book format passes', () => {
  validateFreshnessFields(
    { id: 'b1', inspiredBy: { title: 'Refactoring', format: 'book', year: 2018 } },
    []
  );
});

test('validateFreshnessFields — inspiredBy with course format passes', () => {
  validateFreshnessFields(
    { id: 'b1', inspiredBy: { title: 'GenAI for QA', format: 'course', year: 2025 } },
    []
  );
});

test('validateFreshnessFields — inspiredBy without title throws', () => {
  assert.throws(
    () => validateFreshnessFields(
      { id: 'b1', inspiredBy: { title: '', format: 'book' } },
      []
    ),
    /inspiredBy.title/
  );
});

test('validateFreshnessFields — inspiredBy with unknown format throws', () => {
  assert.throws(
    () => validateFreshnessFields(
      { id: 'b1', inspiredBy: { title: 'X', format: 'magazine' } },
      []
    ),
    /inspiredBy.format/
  );
});

test('validateFreshnessFields — inspiredBy.year non-number throws', () => {
  assert.throws(
    () => validateFreshnessFields(
      { id: 'b1', inspiredBy: { title: 'X', format: 'book', year: '2018' } },
      []
    ),
    /inspiredBy.year/
  );
});

// ─────────────────────────────────────────────────────────────────
// buildAllBooks — resilience (Option A): never abort or drop books that
// lack a buildable .md source; pass their existing shared/ output through.
// ─────────────────────────────────────────────────────────────────

function makeFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'bb-fixture-'));
  const content = path.join(root, 'content');
  const shared = path.join(root, 'shared');

  // 1) A normal book with a real .md source (gets built).
  const goodCh = path.join(content, 'books', 'good', 'chapters');
  fs.mkdirSync(goodCh, { recursive: true });
  fs.writeFileSync(path.join(content, 'books', 'good', 'book.json'), JSON.stringify({
    id: 'good', title: 'Good Book', summary: 'a', categories: ['architecture'],
    coverIcon: 'book', tags: ['x'], freeForAll: true, manifestVersion: 1
  }));
  fs.writeFileSync(path.join(goodCh, '01-intro.md'),
    '@chapter\nid: good-ch01\norder: 1\ntitle: Intro\n\n@card\nid: good-ch01-c1\norder: 1\ntitle: T\nteaser: ts\n\n@explanation\n\nHello world.\n');

  // 2) A legacy book: content dir holds a .json shard (no .md) — must pass through.
  const legacyCh = path.join(content, 'books', 'legacy', 'chapters');
  fs.mkdirSync(legacyCh, { recursive: true });
  fs.writeFileSync(path.join(content, 'books', 'legacy', 'book.json'), JSON.stringify({
    id: 'legacy', title: 'Legacy', summary: 's', categories: ['architecture'],
    volatileChapters: [{ chapterId: 'legacy-ch01', asOfDate: '2026-05', refreshCadence: '6mo' }],
    asOfDate: '2026-05', refreshCadence: '12mo', manifestVersion: 1
  }));
  fs.writeFileSync(path.join(legacyCh, 'legacy-ch01.json'), JSON.stringify({ chapterId: 'legacy-ch01', shardIndex: 1, cards: [] }));

  // 3) A shared-only book: exists in shared/ but has no content/ dir at all.
  for (const id of ['legacy', 'sharedonly']) {
    const sdir = path.join(shared, 'books', id, 'chapters');
    fs.mkdirSync(sdir, { recursive: true });
    fs.writeFileSync(path.join(shared, 'books', id, 'manifest.json'), JSON.stringify({
      id, version: 1, title: id === 'legacy' ? 'Legacy' : 'Shared Only', author: null,
      summary: 's', categories: ['architecture'],
      chapters: [{ id: id + '-ch01', order: 1, title: 'C1', summary: '', icon: 'book', cardCount: 2, cardIds: ['a', 'b'], shards: ['chapters/' + id + '-ch01.json'] }]
    }));
    fs.writeFileSync(path.join(sdir, id + '-ch01.json'), JSON.stringify({ chapterId: id + '-ch01', shardIndex: 1, cards: [] }));
  }

  // Prior catalog with exact metadata for the pass-through books.
  fs.writeFileSync(path.join(shared, 'books-catalog.json'), JSON.stringify({
    version: 1, updatedAt: '2026-01-01T00:00:00.000Z', books: [
      { id: 'legacy', title: 'Legacy', author: null, summary: 's', coverIcon: 'book', accentHex: '#111', tags: ['t'], categories: ['architecture'], chapterCount: 1, cardCount: 2, manifestVersion: 1, manifestPath: 'books/legacy/manifest.json', freeForAll: false, sizeBytes: 123 },
      { id: 'sharedonly', title: 'Shared Only', author: null, summary: 's', coverIcon: 'book', accentHex: '#222', tags: ['t2'], categories: ['architecture'], chapterCount: 1, cardCount: 2, manifestVersion: 1, manifestPath: 'books/sharedonly/manifest.json', freeForAll: false, sizeBytes: 456 }
    ]
  }));

  return { root, content, shared };
}

test('hasMarkdownSource — true only when chapters/ has a .md file', () => {
  const { content } = makeFixture();
  assert.equal(hasMarkdownSource(path.join(content, 'books', 'good'), fs, path), true);
  assert.equal(hasMarkdownSource(path.join(content, 'books', 'legacy'), fs, path), false);
});

test('buildAllBooks — builds .md books, passes through legacy + shared-only, never aborts', () => {
  const { content, shared } = makeFixture();

  // Must not throw even though `legacy` has volatileChapters but no .md source.
  assert.doesNotThrow(() => buildAllBooks(content, shared));

  const catalog = JSON.parse(fs.readFileSync(path.join(shared, 'books-catalog.json'), 'utf8'));
  const ids = catalog.books.map(b => b.id).sort();
  assert.deepEqual(ids, ['good', 'legacy', 'sharedonly'], 'all three books present — none dropped');

  // Built book reflects freshly parsed content.
  const good = catalog.books.find(b => b.id === 'good');
  assert.equal(good.chapterCount, 1);
  assert.equal(good.cardCount, 1);

  // Pass-through books keep their exact prior catalog metadata.
  const legacy = catalog.books.find(b => b.id === 'legacy');
  assert.equal(legacy.accentHex, '#111');
  assert.equal(legacy.sizeBytes, 123);
  const sharedonly = catalog.books.find(b => b.id === 'sharedonly');
  assert.equal(sharedonly.accentHex, '#222');
  assert.equal(sharedonly.sizeBytes, 456);
});

test('passThroughSummary fallback — synthesizes from manifest when no prior catalog entry', () => {
  const { content, shared } = makeFixture();
  // Remove the prior catalog so pass-through must synthesize from the manifest.
  fs.rmSync(path.join(shared, 'books-catalog.json'));
  assert.doesNotThrow(() => buildAllBooks(content, shared));
  const catalog = JSON.parse(fs.readFileSync(path.join(shared, 'books-catalog.json'), 'utf8'));
  const sharedonly = catalog.books.find(b => b.id === 'sharedonly');
  assert.ok(sharedonly, 'shared-only book still present without a prior catalog');
  assert.equal(sharedonly.chapterCount, 1);
  assert.equal(sharedonly.cardCount, 2);  // from manifest chapter cardCount
  assert.equal(sharedonly.manifestPath, 'books/sharedonly/manifest.json');
});

// ─────────────────────────────────────────────────────────────────
// parseInline — backslash escapes (lets authored text contain literal
// *, `, [ ] that would otherwise be parsed as markup).
// ─────────────────────────────────────────────────────────────────

test('parseInline — escaped asterisk is literal, not emphasis', () => {
  assert.deepEqual(parseInline('a \\* b'), [{ text: 'a * b' }]);
});

test('parseInline — bold whose content ends in an escaped asterisk', () => {
  // Markdown: **feature/\***  ->  bold "feature/*"
  assert.deepEqual(parseInline('**feature/\\***'), [{ text: 'feature/*', marks: ['bold'] }]);
});

test('parseInline — escaped brackets are literal, not a link', () => {
  assert.deepEqual(parseInline('\\[not a link\\]'), [{ text: '[not a link]' }]);
});

test('parseInline — code spans are verbatim (no un-escaping inside)', () => {
  // Backslashes inside a code span are preserved as-is.
  assert.deepEqual(parseInline('`a\\b`'), [{ text: 'a\\b', marks: ['code'] }]);
});

test('parseInline — non-escaped emphasis behavior is unchanged', () => {
  assert.deepEqual(parseInline('a*b*c'), [
    { text: 'a' },
    { text: 'b', marks: ['italic'] },
    { text: 'c' }
  ]);
});
