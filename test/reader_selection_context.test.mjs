import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

const { JSDOM } = createRequire(`${process.env.MODU_JSDOM_ROOT}/package.json`)('jsdom');
const book = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
const context = runInNewContext(book.slice(book.indexOf('const CONTEXT_WINDOW_CHARS'),
  book.indexOf('const handleSelection =')) + '\nbuildRangeContextText');
const layout = await readFile(new URL('../assets/foliate-js/src/text-page-layout.js', import.meta.url), 'utf8');
const { preparePageRuns } = await import(`data:text/javascript;base64,${Buffer.from(layout).toString('base64')}`);

function select(doc, text) {
  const walker = doc.createTreeWalker(doc.body, 4), nodes = [];
  let full = '';
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    nodes.push({ node, offset: full.length });
    full += node.data;
  }
  const start = full.indexOf(text), end = start + text.length;
  assert.ok(start >= 0);
  const first = nodes.find(x => x.offset + x.node.length > start);
  const last = nodes.find(x => x.offset + x.node.length >= end);
  const range = doc.createRange();
  range.setStart(first.node, start - first.offset);
  range.setEnd(last.node, end - last.offset);
  return range;
}

test('context is identical before/after real page-run preparation, without altering selection or layout', () => {
  const paragraph = '绍兴三十二年，高宗退位，孝宗即位。新君希望整顿吏治，恢复中原，但朝廷内部意见并不一致。';
  for (const html of [paragraph, paragraph.replace('孝宗', '<em>孝</em><strong>宗</strong>')]) {
    const doc = new JSDOM(`<p>${html}</p><p>不应发送的其他段落</p>`).window.document;
    assert.equal(context(select(doc, '孝宗')), paragraph);
    preparePageRuns(doc);
    const range = select(doc, '孝宗'), before = doc.body.innerHTML;
    assert.equal(context(range), paragraph);
    assert.equal(range.toString(), '孝宗');
    assert.equal(doc.body.innerHTML, before);
  }
});

test('context window remains 120 characters on each side and at most 600 total', () => {
  const doc = new JSDOM(`<p>${'前'.repeat(200)}孝宗${'后'.repeat(200)}</p>`).window.document;
  for (const aligned of [false, true]) {
    if (aligned) preparePageRuns(doc);
    assert.equal(context(select(doc, '孝宗')), '前'.repeat(120) + '孝宗' + '后'.repeat(120));
  }
  const long = new JSDOM(`<p>${'长'.repeat(800)}</p>`).window.document;
  assert.equal(context(select(long, '长'.repeat(800))).length, 600);
  assert.equal(context(null), '');
});

test('cross-paragraph and element-boundary selections do not duplicate selected text', () => {
  const doc = new JSDOM('<p>前文甲乙</p><p>丙丁后文</p>').window.document;
  for (const aligned of [false, true]) {
    if (aligned) preparePageRuns(doc);
    assert.equal(context(select(doc, '乙丙')), '前文甲乙丙丁后文');
    const range = doc.createRange();
    range.selectNodeContents(doc.querySelector('p'));
    assert.equal(context(range), '前文甲乙');
  }
});
