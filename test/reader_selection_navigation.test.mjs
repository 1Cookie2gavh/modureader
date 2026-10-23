import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';

const require = createRequire(process.env.MODU_JSDOM_ROOT
  ? `${process.env.MODU_JSDOM_ROOT}/package.json`
  : new URL('../assets/foliate-js/package.json', import.meta.url));
const { JSDOM } = require('jsdom');
const source = await readFile(new URL('../assets/foliate-js/src/selection-navigation.js', import.meta.url), 'utf8');
const { installSelectionNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const geometry = await readFile(new URL('../assets/foliate-js/src/annotation-geometry.js', import.meta.url), 'utf8');
const smart = (await readFile(new URL('../assets/foliate-js/src/smart-selection.js', import.meta.url), 'utf8'))
  .replace('./annotation-geometry.js', `data:text/javascript;base64,${Buffer.from(geometry).toString('base64')}`);
const { installSmartSelection } = await import(`data:text/javascript;base64,${Buffer.from(smart).toString('base64')}`);

function fixture({ scrolled = false, vertical = false, initial = false, safeInsets } = {}) {
  const dom = new JSDOM('<body><p>abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789</p></body>');
  const { document: doc, Event, CustomEvent } = dom.window, node = doc.querySelector('p').firstChild;
  const rect = { left: 0, top: 0, right: 400, bottom: 600, width: 400, height: 600 };
  let scroll = 0, turns = 0, clock = 0, id = 0, hit = 20, blockedTurn;
  const tasks = new Map(), distances = [];
  const range = (start, end) => { const r = doc.createRange(); r.setStart(node, start); r.setEnd(node, end); return r; };
  const frame = { getBoundingClientRect: () => scrolled
    ? vertical ? { left: -1400 + scroll, right: 400 + scroll, top: 0, bottom: 600 }
      : { left: 0, right: 400, top: -scroll, bottom: 2000 - scroll }
    : { ...rect } };
  Object.defineProperty(dom.window, 'frameElement', { value: frame });
  if (vertical) doc.body.style.writingMode = 'vertical-rl';
  const renderer = new dom.window.EventTarget();
  const container = Object.assign(new dom.window.EventTarget(), { getBoundingClientRect: () => rect });
  Object.assign(renderer, { scrolled, vertical, page: 1, pages: 5,
    shadowRoot: { querySelector: () => container },
    async next() { if (blockedTurn) await blockedTurn; this.page++; turns++; relocate(); },
    async prev() { this.page--; turns++; relocate(); },
    scrollBy(dx, dy) { const distance = vertical ? -dx : dy; distances.push(distance); scroll += distance; hit = Math.min(60, 20 + Math.floor(scroll / 10)); },
  });
  const view = { renderer, isFixedLayout: false, lastLocation: { range: range(0, 20) } };
  function relocate(reason = 'page') {
    view.lastLocation.range = range((renderer.page - 1) * 20, renderer.page * 20);
    renderer.dispatchEvent(new CustomEvent('relocate', { detail: { reason } }));
  }
  doc.caretPositionFromPoint = () => ({ offsetNode: node, offset: hit });
  const controller = installSelectionNavigation(doc, { view, isInitialSelection: () => initial,
    safeInsets,
    setTimer: (fn, ms) => { const key = ++id; tasks.set(key, { fn, at: clock + ms }); return key; },
    clearTimer: key => tasks.delete(key),
  });
  const send = (type, props = {}, target = doc.querySelector('p')) => {
    const event = new Event(type, { bubbles: true, cancelable: true, composed: true });
    Object.assign(event, { clientX: 200, clientY: 300, button: 0, pointerId: 1, ...props });
    target.dispatchEvent(event); return event;
  };
  const select = (start, end, backwards = false) => {
    doc.getSelection().setBaseAndExtent(node, backwards ? end : start, node, backwards ? start : end);
    send('selectionchange');
  };
  const advance = async ms => {
    const until = clock + ms;
    for (;;) {
      const ready = [...tasks].filter(([, task]) => task.at <= until).sort((a, b) => a[1].at - b[1].at)[0];
      if (!ready) break;
      clock = ready[1].at; tasks.delete(ready[0]); ready[1].fn(); await Promise.resolve(); await Promise.resolve();
    }
    clock = until;
  };
  const begin = (anchor = 5, backwards = false) => controller.begin({ anchor: { node, offset: anchor }, backwards,
    point: vertical ? { x: 200, y: 300 } : { x: 200, y: 300 } });
  const edge = () => controller.move(vertical ? { x: 1 - (scrolled ? -1400 + scroll : 0), y: 300 } : { x: 200, y: 599 + scroll });
  return { doc, dom, node, renderer, view, controller, select, send, advance, begin, edge, tasks, distances,
    turns: () => turns, scroll: () => scroll, offset: () => doc.getSelection().getRangeAt(0).endOffset,
    blockTurn: promise => { blockedTurn = promise; },
    hit: offset => { hit = offset; },
    close: () => { controller.destroy(); dom.window.close(); } };
}

test('handle safe bounds follow rotation without hiding text outside the safe area', () => {
  let safe = { top: 62, bottom: 34 };
  const f = fixture({ safeInsets: () => safe });
  Object.defineProperty(f.dom.window, 'innerWidth', { value: 400 });
  Object.defineProperty(f.dom.window, 'innerHeight', { value: 600 });
  let bounds = f.controller.handleBounds();
  assert.equal(bounds.top, 0);
  assert.deepEqual(bounds.safe, { left: 0, right: 400, top: 62, bottom: 566 });
  safe = { left: 62, right: 62, bottom: 21 };
  bounds = f.controller.handleBounds();
  assert.deepEqual(bounds.safe, { left: 62, right: 338, top: 0, bottom: 579 });
  safe = { top: NaN, bottom: -1 };
  assert.deepEqual(f.controller.handleBounds().safe, { left: 0, right: 400, top: 0, bottom: 600 });
  f.close();
});

test('page dwell flips once, fixes the anchor and freezes stationary or inward movement until a new drag', async () => {
  const f = fixture();
  f.select(5, 15); f.begin(); f.select(5, 20); f.edge();
  await f.advance(749); assert.equal(f.turns(), 0);
  await f.advance(1); assert.equal(f.turns(), 1);
  f.select(5, 39); assert.equal(f.offset(), 20, 'late native update must not select page two');
  assert.equal(f.doc.getSelection().anchorOffset, 5);
  assert.equal(f.controller.move({ x: 200, y: 590 }), true);
  assert.equal(f.controller.move({ x: 200, y: 300 }), true);
  await f.advance(3000); assert.equal(f.turns(), 1);
  f.controller.stop(); f.select(5, 39); assert.equal(f.offset(), 20, 'late update after release stays frozen');
  f.begin(); f.select(5, 25); assert.equal(f.offset(), 25, 'fresh handle drag can extend precisely');
  f.close();
});

test('leading endpoint extends backwards with its opposite anchor fixed', async () => {
  const f = fixture(); f.renderer.page = 2; f.view.lastLocation.range.setStart(f.node, 20); f.view.lastLocation.range.setEnd(f.node, 40);
  f.select(20, 35, true); f.begin(35, true); f.controller.move({ x: 100, y: 1 });
  await f.advance(750);
  assert.equal(f.renderer.page, 1); assert.equal(f.doc.getSelection().anchorOffset, 35);
  assert.equal(f.doc.getSelection().focusOffset, 20);
  f.close();
});

for (const action of ['release', 'cancel', 'leave', 'collapse', 'quickMark', 'resize', 'destroy']) {
  test(`pending page turn is cancelled by ${action}`, async () => {
    const f = fixture(); f.select(5, 20); f.begin(); f.edge();
    if (action === 'release') f.send('pointerup');
    if (action === 'cancel') f.send('pointercancel');
    if (action === 'leave') f.controller.move({ x: 200, y: 250 });
    if (action === 'collapse') f.select(5, 5);
    if (action === 'quickMark') f.doc.__moduQuickMarkEnabled = true;
    if (action === 'resize') f.dom.window.dispatchEvent(new f.dom.window.Event('resize'));
    if (action === 'destroy') f.controller.destroy();
    await f.advance(1000); assert.equal(f.turns(), 0); f.close();
  });
}

test('initial long press and stationary selections never turn, including chapter boundaries', async () => {
  for (const options of [{ initial: true }, {}, { lastPage: true }, { fixed: true }]) {
    const f = fixture(options); f.select(5, 20);
    if (options.lastPage) f.renderer.page = 3;
    if (options.fixed) f.view.isFixedLayout = true;
    if (Object.keys(options).length) { f.begin(); f.edge(); }
    await f.advance(2000); assert.equal(f.turns(), 0); f.close();
  }
});

test('vertical pagination uses the left text edge rather than the bottom of the screen', async () => {
  const f = fixture({ vertical: true }); f.select(5, 20); f.begin();
  f.controller.move({ x: 200, y: 599 }); await f.advance(1000); assert.equal(f.turns(), 0);
  f.edge(); await f.advance(750); assert.equal(f.turns(), 1); f.close();
});

for (const vertical of [false, true]) {
  test(`continuous ${vertical ? 'vertical text' : 'horizontal text'} scroll expands slowly and stops on release`, async () => {
    const f = fixture({ scrolled: true, vertical }); f.select(5, 20); f.begin(); f.edge();
    await f.advance(320);
    assert.ok(f.scroll() > 40 && f.scroll() <= 71);
    assert.ok(f.offset() > 20); assert.equal(f.doc.getSelection().anchorOffset, 5);
    assert.equal(f.turns(), 0); assert.equal(f.doc.__moduSelectionDragging, true);
    const previous = f.scroll(); f.controller.stop(); await f.advance(1000);
    assert.equal(f.scroll(), previous); assert.equal(f.doc.__moduSelectionDragging, false);
    f.close();
  });
}

test('scroll speed increases towards edge, cannot pass chapter end and cancels on exit', async () => {
  const f = fixture({ scrolled: true }); f.select(5, 20); f.begin();
  f.controller.move({ x: 200, y: 562 }); await f.advance(320); const slow = f.scroll();
  f.edge(); await f.advance(320); const fast = f.scroll() - slow;
  assert.ok(fast > slow * 2);
  f.controller.move({ x: 200, y: 300 + f.scroll() });
  const before = f.scroll(); await f.advance(1000); assert.equal(f.scroll(), before);
  f.edge(); await f.advance(10000); assert.ok(f.scroll() <= 1400); assert.equal(f.turns(), 0);
  f.close();
});

test('continuous scroll preserves the custom handle finger-to-text offset on every tick', async () => {
  const f = fixture({ scrolled: true });
  f.select(5, 20);
  const hits = [];
  f.controller.begin({ anchor: { node: f.node, offset: 5 }, point: { x: 200, y: 300 },
    extend: point => hits.push({ ...point, scroll: f.scroll() }) });
  f.controller.move({ x: 195, y: 550 }, { x: 200, y: 580 });
  await f.advance(96);
  assert.equal(hits.length, 4);
  for (const hit of hits) {
    assert.equal(hit.x, 195);
    assert.equal(hit.y - hit.scroll, 550);
  }
  f.close();
});

test('mouseup during the page animation preserves the boundary without restarting timers', async () => {
  const f = fixture(); let finish;
  f.blockTurn(new Promise(resolve => { finish = resolve; }));
  f.select(5, 20); f.begin(); f.edge(); await f.advance(750); f.controller.stop();
  finish(); await Promise.resolve(); await Promise.resolve();
  assert.equal(f.offset(), 20); await f.advance(2000); assert.equal(f.turns(), 1);
  assert.equal(f.tasks.size, 0); f.close();
});

test('clearing selection during navigation cannot resurrect it when the page finishes', async () => {
  const f = fixture(); let finish;
  f.blockTurn(new Promise(resolve => { finish = resolve; }));
  f.select(5, 20); f.begin(); f.edge(); await f.advance(750);
  f.doc.getSelection().removeAllRanges(); f.send('selectionchange');
  finish(); await Promise.resolve(); await Promise.resolve();
  assert.equal(f.doc.getSelection().rangeCount, 0); assert.equal(f.tasks.size, 0); f.close();
});

test('scrolling towards the top extends backwards without moving the trailing anchor', async () => {
  const f = fixture({ scrolled: true }); f.renderer.scrollBy(0, 100);
  f.select(15, 35, true); f.begin(35, true);
  f.controller.move({ x: 200, y: 101 }); await f.advance(320);
  assert.ok(f.scroll() < 60); assert.equal(f.doc.getSelection().anchorOffset, 35);
  assert.ok(f.doc.getSelection().focusOffset < 35); f.close();
});

test('inner-column bottom without reaching the visible spread end does not flip', async () => {
  const f = fixture(); f.select(5, 10); f.begin(); f.edge();
  await f.advance(1000); assert.equal(f.turns(), 0);
  f.select(5, 20); await f.advance(750); assert.equal(f.turns(), 1); f.close();
});

test('ordinary mouse drag uses the same guarded page turn controller', async () => {
  const f = fixture(); f.send('pointerdown'); f.select(5, 10);
  f.send('pointermove', { clientY: 599 }); f.select(5, 20);
  await f.advance(750); assert.equal(f.turns(), 1);
  f.select(5, 40); assert.equal(f.offset(), 20);
  f.send('pointerup'); assert.equal(f.doc.__moduSelectionDragging, false); f.close();
});

test('paginated touch handles stay inside the visible page away from system back gestures', async () => {
  const f = fixture();
  f.dom.window.frameElement.getBoundingClientRect = () => ({ left: -800, top: 0, right: 3200, bottom: 600 });
  f.dom.window.Range.prototype.getClientRects = () => [{ left: 810, right: 830, top: 80, bottom: 100 }];
  const smart = installSmartSelection(f.doc, { nativeTouchSelection: true, selectionNavigation: f.controller });
  f.send('pointerdown', { pointerType: 'touch' }); f.select(5, 8); f.send('pointerup');
  await smart.beforeSelection();
  const handles = [...f.doc.querySelector('[data-modu-selection-handles]').shadowRoot.querySelectorAll('span')];
  assert.ok(handles.every(handle => handle.style.left === '832px'));
  f.dom.window.Range.prototype.getClientRects = () => [{ left: 410, right: 430, top: 80, bottom: 100 }];
  f.send('scroll');
  assert.ok(handles.every(handle => handle.style.display === 'none'), 'previous-page handles are not exposed');
  smart.destroy(); f.close();
});

for (const nativeTouchSelection of [true, false]) for (const elementBoundary of [false, true]) {
  test(`${nativeTouchSelection ? 'Android' : 'Apple/Harmony'} reader handles survive ${elementBoundary ? 'paragraph' : 'text'} page boundary and allow a fresh precise drag`, async () => {
    const f = fixture();
    f.node.data = 'aaaa bbb cccc dddd eee ffff gggg hhhh iiii jjjj kkkk llll mmmm nnnn';
    f.view.lastLocation.range.setEnd(f.node, 20);
    f.dom.window.Range.prototype.getClientRects = function () {
      return [{ left: 50, right: 150, top: 280, bottom: 300, width: 100, height: 20 }];
    };
    const smart = installSmartSelection(f.doc, { nativeTouchSelection, selectionNavigation: f.controller });
    if (elementBoundary) {
      const paragraph = f.doc.createElement('p');
      paragraph.innerHTML = '<b>next page</b>';
      f.doc.body.append(paragraph);
      f.renderer.addEventListener('relocate', () => {
        const range = f.doc.createRange();
        range.selectNodeContents(paragraph);
        f.view.lastLocation.range = range;
      });
    }
    f.send('pointerdown', { pointerType: 'touch' }); f.select(5, 8); f.send('pointerup');
    await smart.beforeSelection();
    const handle = () => f.doc.querySelector('[data-modu-selection-handles]')?.shadowRoot.querySelector('[data-selection-handle="end"]');
    assert.ok(handle());
    f.send('pointerdown', { pointerType: 'touch', clientX: 150, clientY: 310 }, handle());
    f.hit(19); // The leading half of the final glyph, not its trailing caret.
    f.send('pointermove', { pointerType: 'touch', clientX: 150, clientY: 570 });
    await f.advance(750);
    assert.equal(f.turns(), 1); assert.equal(f.offset(), elementBoundary ? 0 : 20); assert.ok(handle());
    assert.equal(handle().style.display, 'block', 'new page endpoint remains available to grab');
    assert.equal(handle().style.left, '50px', 'boundary handle uses first glyph on new page, not previous-page glyph');
    f.hit(39); f.send('pointermove', { pointerType: 'touch', clientX: 150, clientY: 619 });
    assert.equal(f.offset(), elementBoundary ? 0 : 20);
    f.send('pointerup', { pointerType: 'touch' });
    assert.ok(handle(), 'handle remains after release');
    if (elementBoundary) f.renderer.dispatchEvent(new f.dom.window.CustomEvent('relocate', {
      detail: { reason: 'anchor' },
    })); // A late relocation must not make a paragraph-start endpoint ungrabbable.
    f.send('pointerdown', { pointerType: 'touch', clientX: 150, clientY: 310 }, handle());
    f.hit(23); f.send('pointermove', { pointerType: 'touch', clientX: 150, clientY: 400 });
    f.send('pointerup', { pointerType: 'touch' });
    assert.equal(f.offset(), 23); assert.equal(f.doc.getSelection().anchorOffset, 5);
    assert.equal(f.doc.__moduSelectionDragging, false);
    smart.destroy(); f.close();
  });
}
