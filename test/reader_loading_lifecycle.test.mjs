import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';

const fontSource = await readFile(new URL('../assets/foliate-js/src/reader-font-ready.js', import.meta.url), 'utf8');
const {waitForReaderFonts} = await import(`data:text/javascript;base64,${Buffer.from(fontSource).toString('base64')}`);
const source = await readFile(new URL('../assets/foliate-js/src/paginator.js', import.meta.url), 'utf8');
const method = source.slice(source.indexOf('  async load(src,'), source.indexOf('\n  render(layout, timing) {'));

function inlineStyle() {
  const values = new Map(), priorities = new Map();
  return {
    setProperty(k,v,p) { values.set(k,v); priorities.set(k,p); },
    getPropertyValue: k => values.get(k) ?? '',
    getPropertyPriority: k => priorities.get(k) ?? '',
    removeProperty(k) {values.delete(k); priorities.delete(k);},
  };
}

function fixture(ready = Promise.resolve(), waitForFonts = waitForReaderFonts) {
  const timers = new Map(); let id = 0;
  const Harness = runInNewContext(`class Harness {
    #destroyed = false; #cancelLoad; #cleanup = [];
    #iframe; #vertical; #rtl; #writingMode; #layout = {};
    #contentRange = {selectNodeContents(){}}; #observer = {observe(){}};
    constructor(doc) {
      this.#iframe = new EventTarget(); this.#iframe.style = {};
      this.doc = doc; this.renders = 0; this.expansions = 0;
    }
    get document() {return this.doc} get frame() {return this.#iframe}
    render() {this.renders++} expand() {this.expansions++} setImageSize() {}
    close() {this.#destroyed = true; this.#cancelLoad?.(); this.#cleanup.forEach(f => f());}
    ${method}
  }; Harness`, {
    EventTarget, CustomEvent, AbortController, waitForReaderFonts: waitForFonts, getDirection: () => ({}),
    console: {warn(){}},
    setTimeout: (fn, ms) => {timers.set(++id, {fn, ms}); return id;},
    clearTimeout: id => timers.delete(id),
  });
  const doc = new EventTarget(); doc.body = {getBoundingClientRect(){}, style:inlineStyle()};
  doc.fonts = new EventTarget(); doc.fonts.ready = ready;
  return {reader: new Harness(doc), doc, timers};
}

test('chapter timings separate document, preparation, fonts and layout without recording content', async () => {
  const {reader} = fixture();
  const events = [];
  reader.container = {dispatchEvent: event => events.push(event.detail)};
  const pending = reader.load('blob:private-book', () => {}, () => ({}));
  reader.frame.dispatchEvent(new Event('load'));
  await pending;
  assert.deepEqual(events.map(e => e.stage),
    ['chapter_document', 'chapter_prepare', 'chapter_fonts', 'layout_viewport', 'chapter_layout']);
  for (const event of events) {
    assert.deepEqual(Object.keys(event).sort(), ['durationMs', 'stage', 'state']);
    assert.equal(event.state, 'timing');
    assert.ok(Number.isInteger(event.durationMs) && event.durationMs >= 0);
  }
  assert.equal(reader.renders, 1, 'diagnostics do not request additional layout');
  assert.ok(!JSON.stringify(events).includes('private-book'));
  reader.close();
});

test('layout phase diagnostics preserve one synchronous render and are optional on later refits', () => {
  const calls = [];
  const methods = source.slice(source.indexOf('  render(layout, timing) {'),
    source.indexOf('\n  setImageSize() {')).replaceAll('this.#', 'this.');
  const Harness = runInNewContext(`class Harness {
    element = {}; document = {documentElement: {}, body: {}};
    vertical = false; rtl = false;
    setImageSize() {calls.push('images')}
    expand() {calls.push('expand')}
    ${methods}
  }; Harness`, {
    calls,
    resetPageAlignment: () => calls.push('reset'),
    setStylesImportant() {},
    fitTextLineSpacing: () => calls.push('spacing'),
    alignPaginatedText: (_doc, _layout, _vertical, timing) => {
      calls.push('align');
      for (const stage of ['layout_runs', 'layout_geometry', 'layout_offsets']) timing?.(stage, Date.now());
    },
  });
  for (const flow of ['paginated', 'scrolled']) {
    const view = new Harness(), stages = [];
    calls.length = 0;
    const layout = {flow, width: 600, height: 800, gap: 20, columnWidth: 580, topMargin: 20, bottomMargin: 20};
    view.render(layout, (stage, since) => {
      assert.ok(Number.isFinite(since) && since <= Date.now());
      stages.push(stage);
    });
    const expected = flow === 'paginated'
      ? ['reset', 'images', 'spacing', 'align', 'expand'] : ['reset', 'images', 'spacing', 'expand'];
    assert.deepEqual(calls, expected);
    assert.deepEqual(stages, ['layout_reset', 'layout_styles', 'layout_spacing',
      ...(flow === 'paginated' ? ['layout_runs', 'layout_geometry', 'layout_offsets'] : []), 'layout_expand']);
    calls.length = 0;
    view.render(layout);
    assert.deepEqual(calls, expected);
  }
});

test('expansion reuses only this alignment pass extent; later image/resize updates measure afresh', () => {
  const methods = source.slice(source.indexOf('  #measureColumnExtent() {'),
    source.indexOf('\n  set overlayer(')).replaceAll('this.#', 'this.').replace('#measureColumnExtent()', 'measureColumnExtent()');
  let reads = 0, notified = 0;
  const doc = {body: {}, documentElement: {style: {}, getBoundingClientRect: () => ({left: 0, right: 600})}};
  const range = {selectNodeContents() {}, getBoundingClientRect: () => {
    reads++; return {left: 20, right: 2400, width: 2380, height: 1000};
  }};
  const Harness = runInNewContext(`class Harness {
    destroyed = false; column = true; vertical = false; rtl = false; size = 600;
    iframe = {style: {}}; element = {style: {}}; document = doc; contentRange = range;
    onExpand() {notify()}
    ${methods}
  }; Harness`, {doc, range, notify: () => notified++});
  const view = new Harness();
  view.expand(true, 1800);
  assert.equal(reads, 0);
  assert.equal(view.iframe.style.width, '1800px');
  assert.equal(view.element.style.width, '3000px');
  view.expand();
  assert.equal(reads, 1);
  assert.equal(view.iframe.style.width, '2400px');
  view.expand(false);
  assert.equal(reads, 2);
  assert.equal(notified, 2);
  view.vertical = true; view.size = 500;
  view.expand();
  assert.equal(view.iframe.style.height, '1000px');
  view.destroyed = true; view.expand();
  assert.equal(reads, 3, 'destroyed views never read their native document');
});

test('null or body-less iframe documents fail before chapter hooks and layout run', async () => {
  for (const invalid of [null, {head: null}]) {
    const {reader} = fixture(); reader.doc = invalid;
    let hooks = 0;
    const pending = reader.load('blob:chapter', () => hooks++, () => ({}));
    const rejected = assert.rejects(pending, {name: 'ReaderChapterDocumentError'});
    reader.frame.dispatchEvent(new Event('load'));
    await rejected;
    assert.equal(hooks, 0); assert.equal(reader.renders, 0);
    reader.close();
  }
});

test('initial blank iframe load waits for the chapter and duplicate load events do not reenter', async () => {
  let release;
  const {reader, doc} = fixture(new Promise(r => release = r));
  let hooks = 0;
  reader.doc = {URL: 'about:blank', body: {}};
  const pending = reader.load('blob:chapter', () => hooks++, () => ({}));
  reader.frame.dispatchEvent(new Event('load'));
  assert.equal(hooks, 0); assert.equal(reader.renders, 0);
  reader.doc = doc;
  reader.frame.dispatchEvent(new Event('load'));
  reader.frame.dispatchEvent(new Event('load'));
  assert.equal(hooks, 1);
  release(); await pending;
  assert.equal(reader.renders, 1);
  reader.frame.dispatchEvent(new Event('error'));
  reader.close();
});

test('waiting for the real chapter after a blank load remains cancellable', async () => {
  const {reader} = fixture(); reader.doc = {URL: 'about:blank', body: {}};
  const pending = reader.load('blob:chapter', () => assert.fail('blank document hook'), () => ({}));
  const rejected = assert.rejects(pending, {name: 'AbortError'});
  reader.frame.dispatchEvent(new Event('load')); reader.close(); await rejected;
  reader.frame.dispatchEvent(new Event('load'));
  assert.equal(reader.renders, 0);
});

test('iframe errors and documents replaced during font loading fail without rendering', async () => {
  for (const event of ['error', 'replacement']) {
    let release;
    const {reader} = fixture(new Promise(r => release = r));
    const pending = reader.load('blob:chapter', () => {}, () => ({}));
    const rejected = assert.rejects(pending, {name: 'ReaderChapterDocumentError'});
    reader.frame.dispatchEvent(new Event('load'));
    if (event === 'error') reader.frame.dispatchEvent(new Event('error'));
    else reader.doc = null;
    release(); await rejected;
    assert.equal(reader.renders, 0); reader.close();
  }
});

test('slow fonts remain hidden beyond 250ms and reveal only after readiness', async () => {
  let release;
  const {reader, doc, timers} = fixture(new Promise(r => release = r));
  const pending = reader.load('blob:chapter', () => {}, () => ({}));
  reader.frame.dispatchEvent(new Event('load'));
  await new Promise(resolve => setTimeout(resolve, 300));
  assert.equal(reader.frame.style.visibility, 'hidden');
  assert.equal(reader.renders, 0, 'no layout using a temporary font');
  release();
  await pending;
  assert.equal(reader.frame.style.visibility, '');
  assert.equal(reader.renders, 1);
  assert.equal(timers.size, 0);
  doc.fonts.dispatchEvent(new Event('loadingdone'));
  assert.equal(reader.renders, 2, 'font metrics trigger a complete layout before repaint');
  reader.close();
  doc.fonts.dispatchEvent(new Event('loadingdone'));
  assert.equal(reader.renders, 2, 'closed views must not resize');
});

test('a real font rejection displays generic text and completes chapter loading', async () => {
    let fail;
    const ready = new Promise((_, reject) => fail = reject);
    const {reader, doc, timers} = fixture(ready);
    const pending = reader.load('blob:chapter', () => {}, () => ({}));
    reader.frame.dispatchEvent(new Event('load'));
    fail(Error('bad font'));
    await pending;
    assert.equal(doc.body.style.getPropertyValue('font-family'), 'serif');
    assert.equal(reader.frame.style.visibility, '');
    assert.equal(reader.renders, 1);
    assert.equal(timers.size, 0);
    doc.fonts.dispatchEvent(new Event('loadingdone'));
    assert.equal(reader.renders, 2, 'the recovered view stays interactive');
    reader.close();
});

test('fonts can complete after 8, 15 and 30 seconds without fallback or failure', async t => {
  t.mock.timers.enable({apis: ['setTimeout']});
  let release;
  const {reader, doc, timers} = fixture(new Promise(r => release = r));
  let done = false;
  const pending = reader.load('blob:slow-font', () => {}, () => ({})).then(() => done = true);
  reader.frame.dispatchEvent(new Event('load'));
  t.mock.timers.tick(31000);
  await Promise.resolve();
  assert.equal(done, false);
  assert.equal(reader.renders, 0);
  assert.equal(reader.frame.style.visibility, 'hidden');
  assert.equal(timers.size, 0);
  release(); await pending;
  assert.equal(reader.renders, 1);
  assert.equal(reader.frame.style.visibility, '');
  reader.close();
});

function textDocument({reject = false, hidden = false} = {}) {
  const requests = [];
  const el = {closest: () => null, getClientRects: () => hidden ? [] : [{}], style:inlineStyle()};
  const nodes = [{parentElement: el, textContent: '正文 中文 ABC'},
    {parentElement: el, textContent: '正文 DEF'}];
  const fonts = [{family: 'UnusedBrokenFace', status: 'error'}];
  fonts.ready = new Promise(() => {}); // An unrelated font must not block text.
  fonts.load = async (font, text) => {
    requests.push({font, text});
    if (reject) throw Error('used font broken');
    return [{status:'loaded'}];
  };
  const doc = {fonts, body:{getBoundingClientRect(){}},
    createTreeWalker: () => {let i=0; return {nextNode:()=>nodes[i++]};},
    defaultView:{getComputedStyle:()=>({fontStyle:'normal',fontWeight:'400',fontSize:'24px',
      fontFamily:'"Body", "English"',display:'block',visibility:'visible'})}};
  return {doc,requests,el};
}

test('only actual text faces are requested, with Chinese and Latin coverage', async () => {
  const {doc,requests} = textDocument();
  assert.equal(await waitForReaderFonts(doc), true);
  assert.equal(requests.length, 1, 'one request per font, not per text node');
  assert.equal(requests[0].font, 'normal 400 24px "Body", "English"');
  for (const char of '正文中ABCDEF') assert.ok(requests[0].text.includes(char));
});

test('a genuinely used broken font falls back; hidden text fonts do not block', async () => {
  const broken = textDocument({reject:true});
  assert.equal(await waitForReaderFonts(broken.doc), true);
  assert.equal(broken.el.style.getPropertyValue('font-family'), 'serif');
  const {doc,requests} = textDocument({hidden:true,reject:true});
  assert.equal(await waitForReaderFonts(doc), true);
  assert.equal(requests.length, 0);
});

test('font failure arriving after cancellation cannot alter the old page', async () => {
  const {doc,el} = textDocument();
  let fail;
  doc.fonts.load = () => new Promise((_, reject) => fail = reject);
  const controller = new AbortController();
  const pending = waitForReaderFonts(doc, controller.signal);
  controller.abort();
  assert.equal(await pending, false);
  fail(Error('late error'));
  await Promise.resolve();
  assert.equal(el.style.getPropertyValue('font-family'), '');
});

test('unused faces do not block successfully loaded requested fonts', async () => {
  const fonts = [{status: 'loaded'}, {status: 'unloaded'}];
  fonts.ready = Promise.resolve();
  assert.equal(await waitForReaderFonts({fonts}), true);
});

test('a slow iframe has no fatal deadline; cancellation ignores a late load event', async () => {
  const {reader, timers} = fixture();
  const pending = reader.load('blob:chapter', () => {}, () => ({}));
  const rejected = assert.rejects(pending, /closed/);
  assert.equal(timers.size, 0, 'publisher fonts may delay the native load event');
  reader.close();
  await rejected;
  reader.frame.dispatchEvent(new Event('load'));
  await Promise.resolve();
  assert.equal(reader.renders, 0);
  assert.equal(timers.size, 0);
});

test('closing during font discovery rejects once and never exposes the old view', async () => {
  let release;
  const {reader, timers} = fixture(new Promise(r => release = r));
  const pending = reader.load('blob:chapter', () => {}, () => ({}));
  const rejected = assert.rejects(pending, /closed/);
  reader.frame.dispatchEvent(new Event('load'));
  reader.close(); release();
  await rejected; await Promise.resolve();
  assert.equal(reader.renders, 0);
  assert.equal(timers.size, 0);
});
