// Tests for scripts/build-books.js. Run with: `node --test scripts/build-books.test.js`
// Uses Node's built-in test runner — no npm dependencies (matches CLAUDE.md "no SPM deps"
// spirit on the engineering side).

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { parseMarkdown, parseInline, parseChapterFile, parseMetadataLines } = require('./build-books.js');

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
