import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

const { JSDOM } = createRequire(`${process.env.MODU_JSDOM_ROOT}/package.json`)('jsdom');
const base = new URL('../assets/foliate-js/src/', import.meta.url);
const viewSource = await readFile(new URL('view.js', base), 'utf8');
const bookSource = await readFile(new URL('book.js', base), 'utf8');
const cfiSource = await readFile(new URL('epubcfi.js', base), 'utf8');
const CFI = await import(`data:text/javascript;base64,${Buffer.from(cfiSource).toString('base64')}`);
const init = viewSource.slice(viewSource.indexOf('  async init('), viewSource.indexOf('\n  #emit('));

function cfiAt(length, offset) {
  const doc = new JSDOM(`<p>${'x'.repeat(length)}</p>`).window.document;
  const range = doc.createRange();
  range.setStart(doc.querySelector('p').firstChild, offset);
  range.collapse(true);
  return CFI.fromRange(range);
}
function fixture({ textAnchor = true, resourceError, anchorError } = {}) {
  const doc = new JSDOM(`<p>${'x'.repeat(211)}</p>`).window.document;
  const warnings = [], visits = [];
  const View = runInNewContext(`(class {
    history = {clear: value => this.historyValue = value};
    renderer = {goTo: async target => {
      if (resourceError) throw resourceError;
      const anchor = target.anchor(doc);
      visits.push({index: target.index, anchor});
      const range = typeof anchor === 'number' ? doc.createRange() : anchor;
      if (typeof anchor === 'number') {
        range.setStart(doc.querySelector('p').firstChild, 0); range.collapse(true);
      }
      this.lastLocation = {cfi: CFI.fromRange(range)};
    }};
    resolveNavigation(cfi) {return {index: 8, textAnchor, anchor: document => {
      if (anchorError) throw anchorError;
      return CFI.toRange(document, CFI.parse(cfi));
    }}}
    ${init}
  })`, {doc, CFI, textAnchor, resourceError, anchorError, visits,
    console: {warn: message => warnings.push(message)}});
  return {view: new View(), doc, warnings, visits};
}

test('1099 offset in a 211-character node recovers in the same chapter once', async () => {
  const saved = cfiAt(1200, 1099);
  const {view, doc, warnings, visits} = fixture();
  assert.throws(() => CFI.toRange(doc, CFI.parse(saved)), {name: 'IndexSizeError'});
  await view.init({lastLocation: saved});
  assert.equal(visits.length, 1);
  assert.equal(visits[0].index, 8);
  assert.equal(visits[0].anchor, 0);
  assert.equal(view.historyValue, cfiAt(211, 0));
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /index=8, reason=IndexSizeError/);
  assert.ok(!warnings[0].includes(saved), 'diagnostics do not expose book locations or text');
  // An invalid annotation must not be silently painted at a different location.
  assert.throws(() => CFI.toRange(doc, CFI.parse(saved)), {name: 'IndexSizeError'});
});

test('valid note-entry location remains exact with no fallback', async () => {
  const saved = cfiAt(211, 103);
  const {view, warnings, visits} = fixture();
  await view.init({lastLocation: saved});
  assert.equal(visits[0].anchor.startOffset, 103);
  assert.equal(view.historyValue, saved);
  assert.equal(warnings.length, 0);
});

test('missing text nodes recover, but resource, font and non-text errors still fail', async () => {
  const missing = fixture({anchorError: new TypeError('Missing CFI text node')});
  await missing.view.init({lastLocation: 'stale'});
  assert.equal(missing.visits[0].anchor, 0);
  for (const options of [
    {resourceError: new Error('Reader font loading failed')},
    {resourceError: Object.assign(new Error('document failed'), {name: 'ReaderChapterDocumentError'})},
    {anchorError: new Error('unexpected rendering bug')},
    {textAnchor: false},
  ]) {
    const {view, warnings} = fixture(options);
    await assert.rejects(view.init({lastLocation: cfiAt(1200, 1099)}));
    assert.equal(warnings.length, 0);
  }
});

test('recovered startup reaches the actual ready, TOC and annotation callbacks', async () => {
  const {view, doc} = fixture();
  const calls = [];
  const note = doc.createRange();
  note.setStart(doc.querySelector('p').firstChild, 12);
  note.setEnd(doc.querySelector('p').firstChild, 20);
  const noteCFI = CFI.fromRange(note);
  const open = bookSource.slice(bookSource.indexOf('const open = async (file, cfi) =>'),
    bookSource.indexOf('\nconst callFlutter ='));
  class Reader { async open(_file, cfi) {await view.init({lastLocation: cfi})} }
  await runInNewContext(`${open};open({}, saved)`, {
    importing: false, Reader, saved: cfiAt(1200, 1099),
    style: {codeHighlightTheme: 'off'},
    onSetToc: () => calls.push('toc'),
    callFlutter: name => {
      calls.push(name);
      if (name === 'renderAnnotations') {
        assert.equal(CFI.toRange(doc, CFI.parse(noteCFI)).toString(), 'xxxxxxxx');
      }
    },
  });
  assert.deepEqual(calls, ['onLoadEnd', 'toc', 'renderAnnotations']);
});

test('parsed TOC is sent before initial navigation as well as after successful layout', () => {
  const open = bookSource.slice(bookSource.indexOf('  async open(file, cfi)'),
    bookSource.indexOf('\n  setView(view)'));
  assert.ok(open.indexOf('onSetToc()') >= 0);
  assert.ok(open.indexOf('onSetToc()') < open.indexOf('await this.view.init('));
});
