import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';

const require = createRequire(process.env.MODU_JSDOM_ROOT
  ? `${process.env.MODU_JSDOM_ROOT}/package.json`
  : new URL('../assets/foliate-js/package.json', import.meta.url));
const { JSDOM } = require('jsdom');
const moduleURL = async name => {
  let source = await readFile(new URL(`../assets/foliate-js/src/${name}.js`, import.meta.url), 'utf8');
  if (name === 'smart-selection') source = source.replace('./annotation-geometry.js', await moduleURL('annotation-geometry'));
  return `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
};
const load = async name => import(await moduleURL(name));
const { wordBounds, smartSelectionRange, installSmartSelection, isInitialSmartSelection } = await load('smart-selection');
const { installSettledSelection } = await load('settled-selection');
const { installSelectionNavigation } = await load('selection-navigation');

function fixture(html = '<p>我喜欢中国文化。</p>', options = {}) {
  const dom = new JSDOM(`<body>${html}</body>`);
  const doc = dom.window.document, target = doc.querySelector('p') || doc.body;
  let clock = 0, id = 0, hit = { node: target.firstChild, offset: 3 };
  const tasks = new Map(), adjusted = [];
  doc.caretPositionFromPoint = () => ({ offsetNode: hit.node, offset: hit.offset });
  dom.window.Range.prototype.getClientRects = function () {
    const left = this.startOffset * 10, right = this.endOffset * 10;
    return right > left ? [{ left, right, top: 0, bottom: 20 }] : [];
  };
  const send = (type, props = {}, element = target) => {
    const e = new dom.window.Event(type, { bubbles: true, cancelable: true, composed: true });
    Object.defineProperties(e, Object.fromEntries(Object.entries({
      clientX: hit.offset * 10 + 1, clientY: 10, button: 0, pointerType: 'touch', ...props,
    }).map(([k, value]) => [k, { value }])));
    element.dispatchEvent(e);
    return e;
  };
  const select = (start, end, node = hit.node, endNode = node) => {
    const range = doc.createRange(); range.setStart(node, start); range.setEnd(endNode, end);
    const selection = doc.getSelection(); selection.removeAllRanges(); selection.addRange(range);
    send('selectionchange', {}, doc);
    return range;
  };
  const advance = ms => {
    const until = clock + ms;
    for (;;) {
      const ready = [...tasks].filter(([, t]) => t.at <= until).sort((a, b) => a[1].at - b[1].at)[0];
      if (!ready) break;
      clock = ready[1].at; tasks.delete(ready[0]); ready[1].fn();
    }
    clock = until;
  };
  const control = installSmartSelection(doc, { now: () => clock,
    setTimer: (fn, ms) => { const token = ++id; tasks.set(token, { fn, at: clock + ms }); return token; },
    clearTimer: token => tasks.delete(token), onAdjusted: range => adjusted.push(range.toString()), ...options });
  return { doc, dom, send, select, advance, control, adjusted, tasks,
    text: () => doc.getSelection().toString(), hit: (node, offset) => { hit = { node, offset }; },
    close: () => { control.destroy(); dom.window.close(); } };
}

test('local word boundaries handle Chinese, English and other scripts without selecting punctuation', () => {
  for (const [text, offset, locale, expected] of [
    ['中国。', 1, 'zh-CN', '中国'], ['hello world', 2, 'en', 'hello'],
    ["don't stop", 3, 'en', "don't"], ['bonjour', 4, 'fr', 'bonjour'],
    ['привет мир', 2, 'ru', 'привет'], ['مرحبا بالعالم', 2, 'ar', 'مرحبا'],
    ['hello', 5, 'not_a_locale', 'hello'],
  ]) {
    const bounds = wordBounds(text, offset, locale);
    assert.equal(text.slice(...bounds), expected);
  }
  for (const [text, offset] of [['中国。', 2], ['a b', 1], ['', 0], ['word', -1], ['word', 9], ['word', NaN]])
    assert.equal(wordBounds(text, offset, 'zh'), null);
});

test('older engines use native CJK selection rather than expanding an entire sentence', () => {
  const saved = Intl.Segmenter;
  try {
    Intl.Segmenter = undefined;
    assert.equal(wordBounds('中国文化', 1), null);
    assert.deepEqual(wordBounds('hello world', 2), [0, 5]);
    assert.equal(wordBounds('😀 hello', 0), null);
    assert.deepEqual(wordBounds('😀 hello', 5), [3, 8]);
  } finally { Intl.Segmenter = saved; }
});

test('words join inline emphasis, ruby bases and highlight wrappers but never cross paragraphs', () => {
  const f = fixture('<p>我爱<span>中</span><em>国</em>。</p><p>人民</p>');
  const node = f.doc.querySelector('span').firstChild;
  assert.equal(smartSelectionRange(f.doc, { node, offset: 0 }, { locale: 'zh' }).toString(), '中国');
  assert.equal(smartSelectionRange(f.doc, { node, offset: 0 }, { paragraph: true }).toString(), '我爱中国。');
  f.close();
  const ruby = fixture('<p><ruby>中<rt>zhōng</rt><rp>(</rp></ruby>国。</p>');
  const range = smartSelectionRange(ruby.doc, { node: ruby.doc.querySelector('ruby').firstChild, offset: 0 }, { locale: 'zh' });
  assert.equal(range.startContainer.data, '中');
  assert.equal(range.endContainer.data, '国。');
  assert.equal(range.endOffset, 1);
  ruby.close();
});

test('paragraph mode trims indentation, includes inline markup and respects DIV/BR boundaries', () => {
  const f = fixture('<p>  一段<strong>正文</strong><br>续行。 \n</p><p>下一段</p>');
  assert.equal(smartSelectionRange(f.doc, { node: f.doc.querySelector('strong').firstChild, offset: 1 },
    { paragraph: true }).toString(), '一段正文续行。');
  f.close();
  const br = fixture('<div>第一段<br><span>第二段</span><br>第三段</div>');
  const node = br.doc.querySelector('span').firstChild;
  assert.equal(smartSelectionRange(br.doc, { node, offset: 1 }, { paragraph: true }).toString(), '第二段');
  br.close();
});

test('links, input fields, hidden text and overlarge content retain native behavior', () => {
  const f = fixture('<p>中国<span hidden>隐藏</span>文化<a href="#note">注</a><input value="test"></p>');
  const link = f.doc.querySelector('a');
  assert.equal(smartSelectionRange(f.doc, { node: link.firstChild, offset: 0 }), null);
  assert.equal(smartSelectionRange(f.doc, { node: f.doc.querySelector('[hidden]').firstChild, offset: 0 }), null);
  f.send('pointerdown', {}, link); f.advance(700);
  assert.equal(f.text(), '');
  assert.equal(f.send('click', {}, link).defaultPrevented, false);
  f.close();
  const big = fixture(`<p>${'中'.repeat(66000)}</p>`);
  assert.equal(smartSelectionRange(big.doc, { node: big.doc.querySelector('p').firstChild, offset: 3 }), null);
  big.close();
});

test('Android native single-character selection expands once; handle adjustments stay authoritative', () => {
  const f = fixture();
  f.send('pointerdown'); f.advance(300); f.select(3, 4);
  assert.equal(f.text(), '中国');
  assert.deepEqual(f.adjusted, ['中国']);
  const initial = f.doc.getSelection().getRangeAt(0);
  assert.equal(isInitialSmartSelection(f.doc, initial), true);
  const changed = f.select(2, 6);
  assert.equal(f.text(), '欢中国文');
  assert.equal(isInitialSmartSelection(f.doc, changed), false);
  f.advance(1000);
  assert.deepEqual(f.adjusted, ['中国']);
  f.close();
});

const handlesHost = f => f.doc.querySelector('[data-modu-selection-handles]');
const handleAt = (f, side) => handlesHost(f)?.shadowRoot.querySelector(`[data-selection-handle="${side}"]`);

test('aligned Android selections paint glyph height and restore native painting on dismissal', async () => {
  const f = fixture('<p><modu-page-run>中国文化</modu-page-run></p>',
    { nativeTouchSelection: true, enabled: () => false });
  const run = f.doc.querySelector('modu-page-run'), node = run.firstChild;
  run.__moduPageRun = true;
  f.dom.window.Range.prototype.getClientRects = function () {
    return [{ left: 10, right: 50, top: 40, bottom: 60, width: 40, height: 20 }];
  };
  f.hit(node, 1); f.send('pointerdown'); f.select(0, 2, node);
  await f.control.beforeSelection();
  const box = f.doc.querySelector('[data-selection-highlight]').shadowRoot.querySelector('i');
  assert.equal(box.style.height, '20px'); assert.equal(box.style.top, '40px');
  assert.equal(f.text(), '中国');
  assert.equal(run.style.cssText, '');
  assert.match(f.doc.head.textContent, /background-color:transparent/);
  assert.match(f.doc.head.textContent, /-webkit-touch-callout:none/);
  f.select(0, 0, node);
  assert.equal(handlesHost(f), null);
  assert.equal(f.doc.head.querySelector('style'), null);
  f.close();
});

test('native pen selections paint text height before takeover without including paragraph leading', () => {
  for (const markup of ['<span>中国</span><em>文化</em>',
    '<modu-page-run>中国</modu-page-run><modu-page-run>文化</modu-page-run>']) {
    const f = fixture(`<p style="line-height:60px">${markup}</p>`,
      { nativeTouchSelection: true, enabled: () => false });
    const p = f.doc.querySelector('p'), first = p.firstChild.firstChild, last = p.lastChild.firstChild;
    for (const run of f.doc.querySelectorAll('modu-page-run')) run.__moduPageRun = true;
    f.dom.window.Range.prototype.getClientRects = function () {
      if (this.startContainer !== this.endContainer)
        return [{ left: 0, right: 80, top: 0, bottom: 60, width: 80, height: 60 }];
      const left = this.startContainer === first ? 0 : 40;
      return [{ left, right: left + 40, top: 20, bottom: 40, width: 40, height: 20 }];
    };
    f.hit(first, 0); f.send('pointerdown', { pointerType: 'pen' });
    f.send('pointermove', { pointerType: 'pen', clientX: 75 });
    f.select(0, 2, first, last);
    assert.equal(handlesHost(f), null); // Native selection has not been taken over.
    const boxes = [...f.doc.querySelector('[data-selection-highlight]').shadowRoot.querySelectorAll('i')];
    assert.equal(boxes.length, 1);
    assert.equal(boxes[0].style.top, '20px');
    assert.equal(boxes[0].style.height, '20px');
    assert.equal(boxes[0].style.width, '80px');
    assert.equal(p.style.lineHeight, '60px');
    assert.equal(f.text(), '中国文化');
    f.select(0, 0, first);
    assert.equal(f.doc.querySelector('[data-selection-highlight]'), null);
    assert.equal(f.doc.head.querySelector('style'), null);
    f.close();
  }
});

test('fixed-layout PDF retains its own selection paint while using reader handles', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true,
    enabled: () => false, textSelectionHighlight: false });
  f.send('pointerdown'); f.select(3, 5);
  await f.control.beforeSelection();
  assert.ok(handlesHost(f));
  assert.equal(f.doc.querySelector('[data-selection-highlight]'), null);
  assert.equal(f.doc.head.querySelector('style'), null);
  assert.equal(f.text(), '中国');
  f.close();
});

test('Android automatic word and paragraph expansion immediately displays two draggable handles', async () => {
  for (const paragraph of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true, paragraph: () => paragraph });
    f.send('pointerdown'); f.send('pointercancel'); f.select(3, 4);
    await f.control.beforeSelection();
    assert.equal(f.text(), paragraph ? '我喜欢中国文化。' : '中国');
    for (const side of ['start', 'end']) {
      assert.ok(handleAt(f, side), side);
      assert.equal(handleAt(f, side).style.display, 'block');
    }
    assert.equal(handlesHost(f).textContent, ''); // Never changes extracted book text.
    f.close();
    assert.equal(handlesHost(f), null);
  }
});

test('native word selection with unchanged bounds adopts the same blue handles only once', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true });
  let resets = 0;
  const selection = f.doc.getSelection(), clear = selection.removeAllRanges.bind(selection);
  selection.removeAllRanges = () => { resets++; clear(); };
  f.select(3, 5); await f.control.beforeSelection();
  assert.equal(f.text(), '中国');
  assert.ok(handleAt(f, 'start')); assert.ok(handleAt(f, 'end'));
  assert.equal(resets, 2); // Native creation, then explicit native-UI dismissal.
  const host = handlesHost(f);
  await f.control.beforeSelection();
  assert.equal(handlesHost(f), host);
  assert.equal(resets, 2);
  f.close();
});

test('Android unexpanded text/PDF selections get blue handles without changing their text', async () => {
  for (const paragraph of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true, enabled: () => false,
      paragraph: () => paragraph });
    f.send('pointerdown'); f.select(2, 6); await f.control.beforeSelection();
    assert.equal(f.text(), '欢中国文'); assert.equal(f.adjusted.length, 0);
    const control = handleAt(f, 'end');
    assert.ok(control);
    assert.match(handlesHost(f).shadowRoot.querySelector('style').textContent, /background:#1976d2/);
    for (const type of ['touchstart', 'touchmove', 'touchend', 'contextmenu'])
      assert.equal(f.send(type, {}, control).defaultPrevented, true);
    f.send('pointerdown', { pointerId: 1 }, control);
    f.hit(f.doc.querySelector('p').firstChild, 7);
    f.send('pointermove', { pointerId: 1 }); f.send('pointerup', { pointerId: 1 });
    await f.control.beforeSelection();
    assert.equal(f.text(), '欢中国文化');
    f.close();
  }
});

test('Android mouse and keyboard selections do not acquire touch handles', async () => {
  for (const input of ['mouse', 'keyboard']) {
    const f = fixture(undefined, { nativeTouchSelection: true });
    if (input === 'mouse') f.send('pointerdown', { pointerType: 'mouse' });
    else f.send('keydown', { key: 'ArrowRight' });
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(handlesHost(f), null); assert.equal(f.text(), '中');
    f.close();
  }
});

test('Android pen drag retains its exact range and adopts reader handles after moving', async () => {
  for (const selectBeforeMove of [false, true]) {
    const f = fixture(undefined, {nativeTouchSelection:true, paragraph:() => true});
    f.send('pointerdown', {pointerType:'pen'});
    f.send('touchstart'); // Compatibility event must not overwrite the pen kind.
    if (selectBeforeMove) f.select(2, 6);
    f.send('pointermove', {pointerType:'pen', clientX:80});
    f.select(2, 6);
    f.send('pointerup', {pointerType:'pen', clientX:80});
    await f.control.beforeSelection();
    assert.equal(f.text(), '欢中国文');
    assert.equal(f.adjusted.length, 0, 'manual pen selection must not expand to a paragraph');
    assert.ok(handleAt(f, 'start')); assert.ok(handleAt(f, 'end'));
    f.close();
  }
});

test('finger scrolling and pen multi-touch do not re-enable reader handles', async () => {
  for (const pointerType of ['touch', 'pen']) {
    const f = fixture(undefined, {nativeTouchSelection:true});
    f.send('pointerdown', {pointerType});
    f.send('pointermove', {pointerType, clientX:80,
      ...(pointerType === 'pen' ? {touches:[{clientX:80,clientY:10},{}]} : {})});
    f.select(2, 6);
    await f.control.beforeSelection();
    assert.equal(handlesHost(f), null);
    assert.equal(f.text(), '欢中国文');
    f.close();
  }
});

test('native scroll-to-selection after a pen drag keeps takeover, but navigation cancels it', async () => {
  for (const navigate of [false, true]) {
    const f = fixture(undefined, {nativeTouchSelection:true, paragraph:() => true});
    f.send('pointerdown', {pointerType:'pen'});
    f.send('pointermove', {pointerType:'pen', clientX:80});
    f.select(2, 6);
    f.send('scroll', {}, f.doc);
    f.control.nativeLongPress();
    f.send('pointerup', {pointerType:'pen', clientX:80});
    if (navigate) f.control.cancel();
    await f.control.beforeSelection();
    assert.equal(f.text(), '欢中国文');
    assert.equal(f.adjusted.length, 0);
    assert.equal(!!handlesHost(f), !navigate);
    f.close();
  }
});

test('expanded handles drag either endpoint and cross without snapping back to the word', async () => {
  for (const [side, destination, expected] of [
    ['start', 1, '喜欢中国'], ['end', 7, '中国文化'],
    ['end', 2, '欢'], ['start', 6, '文'],
  ]) {
    const f = fixture(undefined, { nativeTouchSelection: true });
    f.select(3, 4); await f.control.beforeSelection();
    const control = handleAt(f, side), node = f.doc.querySelector('p').firstChild;
    let bubbled = 0;
    f.doc.addEventListener('pointerdown', () => bubbled++);
    assert.equal(f.send('pointerdown', { pointerId: 1 }, control).defaultPrevented, true);
    assert.equal(bubbled, 0);
    f.hit(node, destination);
    assert.equal(f.send('pointermove', { pointerId: 1 }).defaultPrevented, true);
    f.send('pointerup', { pointerId: 1 });
    f.send('scroll', {}, f.doc); // Native scroll-to-selection keeps the handles.
    f.control.nativeLongPress(); await f.control.beforeSelection();
    assert.equal(f.text(), expected, side);
    assert.equal(f.adjusted.length, 1);
    assert.ok(handlesHost(f));
    assert.equal(f.send('click', {}, control).defaultPrevented, true);
    f.close();
  }
});

test('handle drag can extend across inline markup and paragraphs without moving the other endpoint', async () => {
  const f = fixture('<p>我爱<span>中</span><em>国</em>文化。</p><p>下一段</p>', {
    nativeTouchSelection: true, segmentWord: async () => [2, 4],
  });
  f.select(0, 1, f.doc.querySelector('span').firstChild); await f.control.beforeSelection();
  f.send('pointerdown', { pointerId: 1 }, handleAt(f, 'end'));
  f.hit(f.doc.querySelectorAll('p')[1].firstChild, 2);
  f.send('pointermove', { pointerId: 1 }); f.send('pointerup', { pointerId: 1 });
  await f.control.beforeSelection();
  assert.equal(f.text(), '中国文化。下一');
  assert.equal(f.doc.getSelection().getRangeAt(0).startContainer, f.doc.querySelector('span').firstChild);
  f.close();
});

test('clearing/replacing selection, leaving the page or handing back to native UI removes expanded handles', async () => {
  for (const action of ['clear', 'replace', 'pagehide', 'visibility', 'press', 'destroy']) {
    const f = fixture(undefined, { nativeTouchSelection: true });
    f.select(3, 4); await f.control.beforeSelection();
    assert.ok(handlesHost(f));
    if (action === 'clear') f.select(3, 3);
    if (action === 'replace') f.select(1, 7);
    if (action === 'pagehide') f.dom.window.dispatchEvent(new f.dom.window.Event('pagehide'));
    if (action === 'visibility') f.send('visibilitychange', {}, f.doc);
    if (action === 'press') f.send('pointerdown');
    if (action === 'destroy') f.control.destroy();
    assert.equal(handlesHost(f), null, action);
    f.close();
  }
});

test('late segmentation after the selection changed cannot resurrect expanded handles', async () => {
  let finish;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentWord: () => new Promise(resolve => { finish = resolve; }) });
  f.select(3, 4);
  const pending = f.control.beforeSelection();
  assert.ok(handlesHost(f));
  f.select(2, 6); finish([3, 5]); await pending;
  assert.equal(handlesHost(f), null);
  assert.equal(f.text(), '欢中国文'); f.close();
});

test('expanded handle positions support horizontal RTL and vertical text and refresh on resize', async () => {
  for (const [style, startX, startY, endX, endY] of [
    ['', '32px', '30px', '50px', '30px'],
    ['direction:rtl', '40px', '30px', '40px', '30px'],
    ['writing-mode:vertical-rl', '32px', '18px', '32px', '20px'],
  ]) {
    const f = fixture(`<p style="${style}">我喜欢中国文化。</p>`, { nativeTouchSelection: true });
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(handleAt(f, 'start').style.left, startX);
    assert.equal(handleAt(f, 'start').style.top, startY);
    assert.equal(handleAt(f, 'end').style.left, endX);
    assert.equal(handleAt(f, 'end').style.top, endY);
    f.dom.window.Range.prototype.getClientRects = () => [{ left: 100, right: 120, top: 100, bottom: 120 }];
    f.dom.window.dispatchEvent(new f.dom.window.Event('resize'));
    assert.notEqual(handleAt(f, 'start').style.left, startX);
    f.close();
  }
});

test('top-page handles stay draggable below the iOS safe area without moving the range', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, selectionNavigation: {
    handleBoundary: () => undefined,
    handleBounds: () => ({ left: 0, right: 400, top: 0, bottom: 800,
      safe: { left: 0, right: 400, top: 62, bottom: 766 } }),
    begin() {}, move: () => false, stop() {},
  } });
  f.select(3, 4); await f.control.beforeSelection();
  assert.equal(handleAt(f, 'end').style.top, '98px');
  assert.equal(handleAt(f, 'end').style.display, 'block');
  const initial = f.text();
  f.send('pointerdown', { pointerId: 1, clientY: 98 }, handleAt(f, 'end'));
  assert.equal(f.text(), initial);
  f.hit(f.doc.querySelector('p').firstChild, 7);
  f.send('pointermove', { pointerId: 1, clientY: 120 });
  f.send('pointerup', { pointerId: 1 });
  assert.equal(f.text(), '中国文化');
  f.close();
});

test('pointer cancellation, a second finger and invalid caret hits never corrupt the expanded range', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true });
  f.select(3, 4); await f.control.beforeSelection();
  f.send('pointerdown', { pointerId: 1 }, handleAt(f, 'end'));
  f.hit(f.doc.querySelector('p').firstChild, 7);
  f.send('pointermove', { pointerId: 2 }); assert.equal(f.text(), '中国');
  f.doc.caretPositionFromPoint = () => { throw Error('no caret'); };
  f.send('pointermove', { pointerId: 1 }); assert.equal(f.text(), '中国');
  f.send('pointercancel', { pointerId: 1 });
  assert.ok(handlesHost(f));
  assert.equal(handlesHost(f).style.visibility, '');
  f.close();
});

test('mobile long press creates the word selection even when WebView sends no native range', () => {
  for (const start of ['pointerdown', 'touchstart']) {
    const f = fixture();
    const touches = start === 'touchstart' ? [{ clientX: 31, clientY: 10 }] : undefined;
    f.send(start, { touches }); f.advance(599);
    assert.equal(f.text(), ''); f.advance(1);
    assert.equal(f.text(), '中国', start);
    assert.deepEqual(f.adjusted, ['中国']);
    f.send(start === 'touchstart' ? 'touchend' : 'pointerup');
    assert.equal(f.send('click').defaultPrevented, true);
    f.select(2, 6); f.advance(700);
    assert.equal(f.text(), '欢中国文');
    assert.equal(f.adjusted.length, 1);
    f.close();
  }
});

test('mobile long press selects the paragraph without depending on native word selection', () => {
  const f = fixture(undefined, { paragraph: () => true });
  f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
  f.advance(600);
  assert.equal(f.text(), '我喜欢中国文化。');
  assert.equal(isInitialSmartSelection(f.doc, f.doc.getSelection().getRangeAt(0)), true);
  f.close();
});

test('early native pointer takeover can still normalize the later native range', () => {
  const f = fixture();
  f.send('pointerdown'); f.advance(100); f.send('pointercancel');
  f.advance(300); f.select(3, 4);
  assert.equal(f.text(), '中国');
  assert.equal(f.adjusted.length, 1);
  f.close();
});

test('a cancelled touch never creates a synthetic selection without a native range', () => {
  for (const elapsed of [100, 300]) {
    const f = fixture();
    f.send('pointerdown'); f.advance(elapsed); f.send('pointercancel');
    f.advance(1200);
    assert.equal(f.text(), ''); assert.equal(f.adjusted.length, 0);
    f.close();
  }
});

test('native selection UI may blur the chapter before publishing its initial range', () => {
  const f = fixture();
  f.send('pointerdown'); f.advance(300);
  f.dom.window.dispatchEvent(new f.dom.window.Event('blur'));
  f.advance(100); f.select(3, 4);
  assert.equal(f.text(), '中国');
  assert.equal(f.adjusted.length, 1);
  f.close();
});

test('mouse blur and a hidden reader cancel a pending long press', () => {
  const mouse = fixture();
  mouse.send('pointerdown', { pointerType: 'mouse' }); mouse.advance(300);
  mouse.dom.window.dispatchEvent(new mouse.dom.window.Event('blur'));
  mouse.advance(1000);
  assert.equal(mouse.text(), ''); mouse.close();
  const f = fixture();
  f.send('pointerdown'); f.advance(300); f.send('pointercancel');
  f.send('visibilitychange', {}, f.doc); f.advance(100); f.select(3, 4);
  assert.equal(f.text(), '中'); assert.equal(f.adjusted.length, 0);
  f.close();
});

test('coexisting pointer and touch events do not restart the long-press timer', () => {
  const f = fixture();
  f.send('pointerdown'); f.advance(10);
  f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
  f.advance(590);
  assert.equal(f.text(), '中国'); assert.equal(f.adjusted.length, 1);
  f.send('pointerup'); f.send('touchend');
  assert.equal(f.send('click').defaultPrevented, true);
  f.close();
});

const withLegacyEngine = async action => {
  const saved = Intl.Segmenter;
  try { Intl.Segmenter = undefined; await action(); }
  finally { Intl.Segmenter = saved; }
};
const flushBridge = () => new Promise(resolve => setImmediate(resolve));

test('Android prewarms one paragraph and immediately selects cached words across repeated presses', () => withLegacyEngine(async () => {
  const requests = [];
  const f = fixture(undefined, { nativeTouchSelection: true, locale: () => 'zh-CN',
    segmentParagraph: async request => { requests.push(request); return [[0, 1], [1, 3], [3, 5], [5, 7]]; } });
  f.send('pointerdown'); await flushBridge();
  assert.equal(f.text(), '');
  assert.deepEqual(requests, [{ text: '我喜欢中国文化。', locale: 'zh-CN' }]);
  f.advance(600); f.select(3, 4);
  assert.equal(f.text(), '中国'); // No menu debounce or asynchronous bridge wait.
  assert.ok(handleAt(f, 'end'));
  f.select(0, 0); f.advance(100);
  f.hit(f.doc.querySelector('p').firstChild, 5);
  f.send('pointerdown'); f.select(5, 6);
  assert.equal(f.text(), '文化');
  await flushBridge(); assert.equal(requests.length, 1);
  f.close();
}));

test('a fresh long press on text replaces the previous selection without a blank-area tap', async () => {
  for (const collapse of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => [[3, 5], [5, 7]] });
    f.send('pointerdown'); f.select(3, 4);
    assert.equal(f.text(), '中国');
    f.send('pointerup'); f.advance(700);
    f.hit(f.doc.querySelector('p').firstChild, 5); f.send('pointerdown');
    f.send('selectionchange', {}, f.doc); // Old selection may be reported while still held.
    assert.equal(f.text(), '中国');
    if (collapse) f.select(5, 5);
    f.advance(600); f.select(5, 6);
    assert.equal(f.text(), '文化', `collapse=${collapse}`);
    f.select(5, 6); f.control.nativeLongPress();
    assert.equal(f.text(), '文'); // Later adjustment must not expand again.
    f.close();
  }
});

test('a fresh long press on the same manually narrowed glyph can select its word again', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => [[3, 5]] });
  f.send('pointerdown'); f.select(3, 4); f.select(3, 4);
  assert.equal(f.text(), '中');
  f.send('pointerup'); f.advance(700); f.send('pointerdown');
  f.control.nativeLongPress(); assert.equal(f.text(), '中'); // Not a long press yet.
  f.advance(600); f.control.nativeLongPress();
  assert.equal(f.text(), '中国'); f.close();
});

test('short taps, blank-area presses and dragging cannot re-arm expansion of an old selection', async () => {
  for (const action of ['tap', 'blank', 'swipe', 'pen', 'handle']) {
    const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => [[3, 5]] });
    f.send('pointerdown'); f.select(3, 4); f.send('pointerup'); f.advance(700);
    if (action === 'handle') {
      f.send('pointerdown', { pointerId: 1 }, handleAt(f, 'end'));
      f.hit(f.doc.querySelector('p').firstChild, 4);
      f.send('pointermove', { pointerId: 1 }); f.send('pointerup', { pointerId: 1 });
    } else {
      f.select(3, 4);
      f.send('pointerdown', { clientY: action === 'blank' ? 100 : 10,
        pointerType: action === 'pen' ? 'pen' : 'touch' });
      if (action === 'tap') { f.advance(50); f.send('pointerup'); }
      if (action === 'pen' || action === 'swipe') f.send('pointermove', { clientX: 80 });
    }
    f.advance(600); f.control.nativeLongPress(); await f.control.beforeSelection();
    assert.equal(f.text(), '中', action); f.close();
  }
});

test('pressing the right half of a glyph uses the hit word rather than a native range prefix', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => [[3, 5], [5, 7]] });
  f.hit(f.doc.querySelector('p').firstChild, 5);
  f.send('pointerdown', { clientX: 48 }); // caret is after 国, but finger is on 国.
  f.select(0, 5); // Some native engines initially select a larger fragment.
  assert.equal(f.text(), '中国'); f.close();
});

test('late paragraph cache never changes a manual round-handle selection or its menu payload', async () => {
  let resolve;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentParagraph: () => new Promise(done => { resolve = done; }) });
  f.send('pointerdown'); await flushBridge(); f.select(3, 4);
  assert.equal(f.text(), '中国'); // Synchronous local segmentation while ICU is pending.
  const handle = handleAt(f, 'end'); assert.ok(handle);
  f.send('pointerdown', { pointerId: 1 }, handle);
  f.hit(f.doc.querySelector('p').firstChild, 6);
  f.send('pointermove', { pointerId: 1 }); f.send('pointerup', { pointerId: 1 });
  const manual = f.text(); assert.equal(manual, '中国文');
  resolve([[0, 7]]); await flushBridge();
  await f.control.beforeSelection(); f.control.nativeLongPress();
  assert.equal(f.text(), manual);
  assert.deepEqual(f.adjusted, ['中国']);
  f.close();
});

test('cached UTF-16 boundaries map across inline nodes and survive paragraph DOM replacement', () => withLegacyEngine(async () => {
  const requests = [];
  const f = fixture('<p>😀我爱<span>中</span><em>国</em>文化。</p><p>下一段不预取。</p>', {
    nativeTouchSelection: true,
    segmentParagraph: async request => { requests.push(request); return [[2, 3], [3, 4], [4, 6], [6, 8]]; },
  });
  let node = f.doc.querySelector('span').firstChild;
  f.hit(node, 0); f.send('pointerdown'); await flushBridge(); f.select(0, 1, node);
  assert.equal(f.text(), '中国');
  f.select(0, 0, node);
  f.doc.querySelector('p').innerHTML = '😀我爱<b>中国</b>文化。';
  node = f.doc.querySelector('b').firstChild;
  f.hit(node, 1); f.advance(100); f.send('pointerdown'); f.select(1, 2, node);
  assert.equal(f.text(), '中国'); await flushBridge();
  assert.equal(requests.length, 1); assert.equal(requests[0].text, '😀我爱中国文化。');
  f.close();
}));

test('legacy WebView caches late results for the next press without moving the current range', () => withLegacyEngine(async () => {
  let resolve;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentParagraph: () => new Promise(done => { resolve = done; }) });
  f.send('pointerdown'); await flushBridge(); f.select(3, 4);
  assert.equal(f.text(), '中'); assert.ok(handleAt(f, 'end'));
  resolve([[3, 5]]); await flushBridge(); await f.control.beforeSelection();
  assert.equal(f.text(), '中');
  f.select(0, 0); f.advance(100); f.send('pointerdown'); f.select(3, 4);
  assert.equal(f.text(), '中国'); f.close();
}));

test('paragraph cache invalidates on text or locale changes and ignores stale replies', () => withLegacyEngine(async () => {
  let language = 'zh-CN';
  const requests = [], resolves = [];
  const f = fixture(undefined, { nativeTouchSelection: true, locale: () => language,
    segmentParagraph: request => { requests.push(request); return new Promise(done => resolves.push(done)); } });
  f.send('pointerdown'); await flushBridge();
  language = 'zh-TW'; f.advance(100); f.send('pointerdown'); await flushBridge();
  resolves[1]([[3, 5]]); resolves[0]([[0, 7]]); await flushBridge();
  f.select(3, 4); assert.equal(f.text(), '中国');
  f.select(0, 0); f.doc.querySelector('p').firstChild.data = '我喜欢中华文化。';
  f.advance(100); f.send('pointerdown'); await flushBridge();
  assert.deepEqual(requests.map(r => [r.text, r.locale]), [
    ['我喜欢中国文化。', 'zh-CN'], ['我喜欢中国文化。', 'zh-TW'], ['我喜欢中华文化。', 'zh-TW']]);
  resolves[2]([[3, 5]]); await flushBridge(); f.select(3, 4);
  assert.equal(f.text(), '中华'); f.close();
}));

test('paragraph cache rejects malformed boundaries and does not recreate selection after disposal', () => withLegacyEngine(async () => {
  for (const words of [null, [[-1, 5]], [[3, 99]], [[3, 3]], [[3.5, 5]], [[3, 5], [4, 7]], [[5, 7], [3, 5]]]) {
    const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => words });
    f.send('pointerdown'); await flushBridge(); f.select(3, 4);
    assert.equal(f.text(), '中'); f.close();
  }
  let calls = 0;
  const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => { calls++; return [[3, 5]]; } });
  f.send('pointerdown'); f.control.destroy(); await flushBridge();
  assert.equal(calls, 0); assert.equal(handlesHost(f), null); f.close();
}));

test('cached boundaries do not expand pen drag, mouse, keyboard or multi-touch selections', async () => {
  for (const mode of ['pen', 'mouse', 'keyboard', 'multitouch']) {
    const f = fixture(undefined, { nativeTouchSelection: true, segmentParagraph: async () => [[3, 5]] });
    f.send('pointerdown', { pointerType: mode === 'mouse' ? 'mouse' : mode === 'pen' ? 'pen' : 'touch' });
    if (mode === 'pen') f.send('pointermove', { pointerType: 'pen', clientX: 70 });
    if (mode === 'keyboard') f.send('keydown');
    if (mode === 'multitouch') f.send('touchmove', { touches: [{ clientX: 31, clientY: 10 }, {}] });
    await flushBridge(); f.select(3, 4); await f.control.beforeSelection();
    assert.equal(f.text(), '中', mode); assert.equal(f.adjusted.length, 0); f.close();
  }
});

test('Android reader handles appear before a slow word lookup completes', async () => {
  let resolve;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentWord: () => new Promise(done => { resolve = done; }) });
  f.send('pointerdown'); f.select(3, 4);
  const pending = f.control.beforeSelection();
  assert.ok(handleAt(f, 'start')); assert.ok(handleAt(f, 'end'));
  assert.equal(f.text(), '中');
  resolve([3, 5]); await pending;
  assert.equal(f.text(), '中国');
  assert.ok(handleAt(f, 'start')); assert.ok(handleAt(f, 'end'));
  f.close();
});

test('stalled Android bridge has a deadline and cannot change the selection after fallback', async () => {
  for (const legacy of [false, true]) {
    const saved = Intl.Segmenter;
    let resolve;
    try {
      if (legacy) Intl.Segmenter = undefined;
      const f = fixture(undefined, { nativeTouchSelection: true,
        segmentWord: () => new Promise(done => { resolve = done; }) });
      f.select(3, 4);
      const pending = f.control.beforeSelection();
      f.advance(120); await pending;
      const expected = legacy ? '中' : '中国';
      assert.equal(f.text(), expected);
      assert.equal(f.tasks.size, 0);
      resolve([2, 7]); await flushBridge();
      assert.equal(f.text(), expected);
      f.close();
    } finally { Intl.Segmenter = saved; }
  }
});

test('reader handles retain round blue dots and the original drag hit area at different text sizes', async () => {
  for (const height of [12, 20, 32]) {
    const f = fixture(undefined, { nativeTouchSelection: true, enabled: () => false });
    f.dom.window.Range.prototype.getClientRects = () =>
      [{ left: 100, right: 112, top: 100, bottom: 100 + height }];
    f.select(3, 4); await f.control.beforeSelection();
    const start = handleAt(f, 'start'), end = handleAt(f, 'end');
    const css = handlesHost(f).shadowRoot.querySelector('style').textContent;
    assert.match(css, /width:36px; height:36px/);
    assert.match(css, /width:16px; height:16px/);
    assert.match(css, /border-radius:50%; background:#1976d2/);
    for (const control of [start, end]) {
      assert.equal(parseFloat(control.style.top), 100 + height + 10);
      assert.equal(control.style.getPropertyValue('--handle-width'), '');
    }
    assert.equal(start.style.left, '100px');
    assert.equal(end.style.left, '112px');
    assert.equal(f.text(), '中');
    f.close();
  }
});

test('reader handle dragging during word lookup cancels the late expansion', async () => {
  let resolve;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentWord: () => new Promise(done => { resolve = done; }) });
  f.select(3, 4);
  const pending = f.control.beforeSelection();
  const control = handleAt(f, 'end');
  assert.ok(control);
  f.send('pointerdown', { pointerId: 1 }, control);
  f.hit(f.doc.querySelector('p').firstChild, 7);
  f.send('pointermove', { pointerId: 1 });
  f.send('pointerup', { pointerId: 1 });
  const manual = f.text();
  resolve([3, 5]); await pending;
  assert.equal(f.text(), manual);
  assert.equal(f.adjusted.length, 0);
  assert.ok(handleAt(f, 'end'));
  f.close();
});

test('Android normalizes the native single character even without pointer events or a caret hit', async () => {
  for (const paragraph of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true, paragraph: () => paragraph });
    f.doc.caretPositionFromPoint = () => null;
    f.doc.caretRangeFromPoint = () => null;
    f.select(3, 4);
    await f.control.beforeSelection?.();
    assert.equal(f.text(), paragraph ? '我喜欢中国文化。' : '中国');
    assert.equal(f.adjusted.length, 1);
    f.close();
  }
});

test('a real touch event on the glyph is normalized from native selection, not inter-word coordinates', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, paragraph: () => true });
  f.doc.querySelector('p').dispatchEvent(new f.dom.window.TouchEvent('touchstart', {
    bubbles: true, touches: [{ identifier: 1, clientX: 35, clientY: 10 }],
  }));
  f.select(3, 4);
  await f.control.beforeSelection?.();
  assert.equal(f.text(), '我喜欢中国文化。');
  f.close();
});

test('Android waits for native selection instead of creating a competing range on a held touch', () => {
  const f = fixture(undefined, { nativeTouchSelection: true });
  f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
  f.advance(900);
  assert.equal(f.text(), ''); assert.equal(f.adjusted.length, 0);
  f.close();
});

test('Android menu recreation never re-expands a manually selected seed character', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true });
  f.select(3, 4); await f.control.beforeSelection?.();
  assert.equal(f.text(), '中国');
  f.select(3, 4);
  f.control.nativeLongPress?.();
  await f.control.beforeSelection?.();
  assert.equal(f.text(), '中');
  assert.equal(f.adjusted.length, 1);
  f.select(2, 6);
  f.control.nativeLongPress();
  await f.control.beforeSelection();
  assert.equal(f.text(), '欢中国文');
  assert.equal(f.adjusted.length, 1);
  f.close();
});

test('native scroll-to-selection preserves pending expansion; explicit navigation discards it', async () => {
  for (const preserve of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true });
    f.select(3, 4); f.send('scroll');
    f.control.cancel({ preserveActiveSelection: preserve });
    await f.control.beforeSelection?.();
    assert.equal(f.text(), preserve ? '中国' : '中');
    f.close();
  }
});

test('Android handle collapse and menu callbacks cannot re-arm word or paragraph expansion', async () => {
  for (const paragraph of [false, true]) {
    const f = fixture(undefined, { nativeTouchSelection: true, paragraph: () => paragraph });
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(f.adjusted.length, 1);
    f.doc.getSelection().removeAllRanges(); f.send('selectionchange', {}, f.doc);
    f.select(3, 4); f.control.nativeLongPress(); await f.control.beforeSelection();
    assert.equal(f.text(), '中');
    assert.equal(f.adjusted.length, 1);
    f.doc.getSelection().removeAllRanges(); f.send('selectionchange', {}, f.doc);
    f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(f.text(), paragraph ? '我喜欢中国文化。' : '中国');
    assert.equal(f.adjusted.length, 2);
    f.close();
  }
});

test('Android native selection uses system word bounds even if browser segmentation exists', async () => {
  const requests = [];
  const f = fixture(undefined, { nativeTouchSelection: true, locale: () => 'zh-CN',
    segmentWord: async request => { requests.push(request); return [3, 5]; } });
  f.select(4, 5); await f.control.beforeSelection?.();
  assert.equal(f.text(), '中国');
  assert.deepEqual(requests, [{ text: '我喜欢中国文化。', offset: 4, locale: 'zh-CN' }]);
  f.close();
});

test('Android keeps later manual handle changes, including a single-character range', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true });
  f.select(3, 4); await f.control.beforeSelection?.();
  assert.equal(f.text(), '中国');
  for (const [start, end, text] of [[3, 4, '中'], [2, 6, '欢中国文']]) {
    f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
    f.select(start, end); await f.control.beforeSelection?.();
    assert.equal(f.text(), text); assert.equal(f.adjusted.length, 1);
  }
  f.close();
});

test('native word lookup cannot overwrite handle changes, new selection, settings changes or disposal', async () => {
  for (const action of ['handles', 'clear', 'destroy', 'locale', 'paragraph', 'text', 'quickmark']) {
    let resolve, paragraph = false, locale = 'zh-CN';
    const f = fixture(undefined, { nativeTouchSelection: true,
      paragraph: () => paragraph, locale: () => locale,
      segmentWord: () => new Promise(done => { resolve = done; }) });
    f.select(3, 4);
    const pending = f.control.beforeSelection?.();
    await flushBridge();
    assert.equal(typeof resolve, 'function');
    if (action === 'handles') f.select(2, 6);
    if (action === 'clear') { f.doc.getSelection().removeAllRanges(); f.send('selectionchange', {}, f.doc); }
    if (action === 'destroy') f.control.destroy();
    if (action === 'locale') locale = 'en';
    if (action === 'paragraph') paragraph = true;
    if (action === 'text') f.doc.querySelector('p').firstChild.data = '更改后的正文。';
    if (action === 'quickmark') f.doc.__moduQuickMarkEnabled = true;
    resolve([3, 5]); await pending;
    assert.equal(f.adjusted.length, 0, action);
    f.close();
  }
});

test('Android native normalization does not expand links, keyboard selection or swipe selections', async () => {
  for (const action of ['link', 'keyboard', 'swipe', 'quickmark', 'disabled']) {
    const f = fixture('<p>我喜欢中国文化。<a href="#note">注释</a></p>', {
      nativeTouchSelection: true, enabled: () => action !== 'disabled',
    });
    if (action === 'keyboard') f.send('keydown', { key: 'ArrowRight' });
    if (action === 'swipe') { f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] });
      f.send('touchmove', { touches: [{ clientX: 85, clientY: 10 }] }); }
    if (action === 'quickmark') f.doc.__moduQuickMarkEnabled = true;
    f.select(action === 'link' ? 0 : 3, action === 'link' ? 1 : 4,
      action === 'link' ? f.doc.querySelector('a').firstChild : undefined);
    await f.control.beforeSelection?.();
    assert.equal(f.adjusted.length, 0, action); f.close();
  }
});

test('repeated unchanged Android notifications cannot starve the selection toolbar', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, enabled: () => false });
  const emitted = [];
  const stop = installSettledSelection(f.doc, { delay: 15,
    getRange: () => f.doc.getSelection().isCollapsed ? null : f.doc.getSelection().getRangeAt(0),
    beforeSelection: () => f.control.beforeSelection(), onSelection: () => emitted.push(f.text()) });
  try {
    f.select(3, 4);
    for (let i = 0; i < 15; i++) {
      await new Promise(done => setTimeout(done, 5));
      f.send('selectionchange', {}, f.doc);
    }
    assert.deepEqual(emitted, ['中']);
  } finally { stop(); f.close(); }
});

test('Android toolbar appears after bridge deadline and never republishes a late result', async () => {
  let resolve;
  const f = fixture(undefined, { nativeTouchSelection: true,
    segmentWord: () => new Promise(done => { resolve = done; }) });
  const emitted = [];
  const stop = installSettledSelection(f.doc, { delay: 5,
    getRange: () => f.doc.getSelection().isCollapsed ? null : f.doc.getSelection().getRangeAt(0),
    beforeSelection: () => f.control.beforeSelection(), onSelection: () => emitted.push(f.text()) });
  try {
    f.select(3, 4);
    await new Promise(done => setTimeout(done, 25));
    assert.equal(typeof resolve, 'function');
    f.advance(120);
    await new Promise(done => setTimeout(done, 25));
    assert.deepEqual(emitted, ['中国']);
    resolve([2, 7]);
    await new Promise(done => setTimeout(done, 25));
    assert.deepEqual(emitted, ['中国']);
    assert.equal(f.text(), '中国');
  } finally { stop(); f.close(); }
});

test('Android toolbar publishes the final expanded range once, then preserves handle edits', async () => {
  const f = fixture(undefined, { nativeTouchSelection: true, segmentWord: async () => [3, 5] });
  const emitted = [];
  const stop = installSettledSelection(f.doc, { delay: 5,
    getRange: () => f.doc.getSelection().isCollapsed ? null : f.doc.getSelection().getRangeAt(0),
    beforeSelection: () => f.control.beforeSelection?.(), onSelection: () => emitted.push(f.text()) });
  f.select(3, 4); f.select(3, 4); // The native engine reports the character twice.
  await new Promise(resolve => setTimeout(resolve, 40));
  assert.deepEqual(emitted, ['中国']);
  f.send('touchstart', { touches: [{ clientX: 31, clientY: 10 }] }); f.select(3, 4);
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.deepEqual(emitted, ['中国', '中']);
  stop(); f.close();
});

test('Android pointer takeover and native-menu creation before selection do not lose the touch range', async () => {
  for (const end of ['pointercancel', 'touchcancel', 'pointerup', 'touchend', 'blur', 'menu']) {
    const f = fixture(undefined, { nativeTouchSelection: true, paragraph: () => true });
    f.doc.caretPositionFromPoint = () => null;
    f.send('touchstart', { touches: [{ clientX: 35, clientY: 10 }] });
    if (end === 'blur') f.dom.window.dispatchEvent(new f.dom.window.Event('blur'));
    else if (end === 'menu') f.control.nativeLongPress();
    else f.send(end);
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(f.text(), '我喜欢中国文化。', end); f.close();
  }
});

test('Android native words span inline marks, while paragraph selection stays inside its block', async () => {
  for (const paragraph of [false, true]) {
    const f = fixture('<p>我爱<span>中</span><em>国</em>文化。</p><p>下一段</p>', {
      nativeTouchSelection: true, paragraph: () => paragraph, segmentWord: async () => [2, 4],
    });
    f.select(0, 1, f.doc.querySelector('span').firstChild);
    await f.control.beforeSelection();
    assert.equal(f.text(), paragraph ? '我爱中国文化。' : '中国'); f.close();
  }
});

test('a failing local Android bridge falls back to browser segmentation without any network access', async () => {
  for (const segmentWord of [async () => null, async () => { throw Error('unavailable'); }]) {
    const f = fixture(undefined, { nativeTouchSelection: true, segmentWord });
    f.select(3, 4); await f.control.beforeSelection();
    assert.equal(f.text(), '中国'); f.close();
  }
});

test('a late system bridge cannot open a stale toolbar after disposal or selection replacement', async () => {
  for (const action of ['dispose', 'collapse', 'replace']) {
    const doc = new EventTarget(), emitted = [];
    let resolve, range = { startContainer: doc, startOffset: 3, endContainer: doc, endOffset: 4,
      cloneRange() { return { ...this }; } };
    const stop = installSettledSelection(doc, { getRange: () => range, delay: 1,
      beforeSelection: () => new Promise(done => { resolve = done; }), onSelection: () => emitted.push(range.endOffset) });
    doc.dispatchEvent(new Event('selectionchange'));
    await new Promise(done => setTimeout(done, 5));
    const finish = resolve;
    if (action === 'dispose') stop();
    else {
      range = action === 'collapse' ? null : { ...range, endOffset: 6 };
      doc.dispatchEvent(new Event('selectionchange'));
    }
    finish(); await new Promise(done => setTimeout(done, 5));
    assert.deepEqual(emitted, [], action); stop();
  }
});

test('Apple native handle changes refresh text, CFI and annotations without pointerup', async () => {
  const source = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
  const handler = source.slice(source.indexOf('const setSelectionHandler ='), source.indexOf('const isZip ='));
  const publish = source.slice(source.indexOf('const handleSelection ='), source.indexOf('const setSelectionHandler'));
  for (const navigator of [
    { platform: 'iPhone', userAgent: 'iPhone', maxTouchPoints: 5 },
    { platform: 'iPad', userAgent: 'iPad', maxTouchPoints: 5 },
    { platform: 'MacIntel', userAgent: 'Macintosh', maxTouchPoints: 5 },
    { platform: 'MacIntel', userAgent: 'Macintosh', maxTouchPoints: 0 },
  ]) {
    const f = fixture('<p>我喜欢中国文化。</p><p>第二段文字。</p>'); f.control.destroy();
    const maps = { smartSelectionDocuments: new WeakMap(), settledSelectionDocuments: new WeakMap(), selectionNavigationDocuments: new WeakMap() };
    const emitted = [], cleared = [], interaction = [];
    const view = { isFixedLayout: false, renderer: new f.dom.window.EventTarget(),
      getCFI: (index, range) => `${index}:${range.startOffset}:${range.endOffset}:${range.endContainer.parentNode.tagName}`,
      getSelectionAnnotationIds: cfi => cfi.includes(':3:4:') ? [42] : [],
    };
    const setup = runInNewContext(`${publish}\n${handler}\nsetSelectionHandler;`, {
      ...maps, navigator, style: {}, installSmartSelection,
      installSettledSelection: (doc, options) => installSettledSelection(doc, { ...options, delay: 5 }),
      getSelectionRange: sel => sel?.rangeCount && !sel.isCollapsed ? sel.getRangeAt(0) : null,
      getPosition: range => ({ left: range.startOffset, right: range.endOffset }),
      buildRangeContextText: range => range.commonAncestorContainer.textContent,
      onSelectionEnd: selection => emitted.push(selection),
      installSelectionNavigation, isInitialSmartSelection,
      callFlutter: (name, value) => name === 'onReaderTextInteraction'
        ? interaction.push(value) : cleared.push(name),
    });
    const settle = () => new Promise(done => setTimeout(done, 30));
    try {
      setup(view, f.doc, 7);
      assert.deepEqual(interaction, navigator.maxTouchPoints === 0 ? [] : [false],
        'only Apple touch readers disable native handles before the initial press');
      if (navigator.maxTouchPoints > 0) {
        const fixedDom = new JSDOM('<p>fixed layout</p>');
        const fixed = fixedDom.window.document;
        const fixedView = { ...view, isFixedLayout: true };
        setup(fixedView, fixed, 0);
        assert.deepEqual(interaction, [false, true], 'fixed-layout readers keep native text interaction');
        maps.settledSelectionDocuments.get(fixed)?.();
        maps.smartSelectionDocuments.get(fixed)?.destroy();
        maps.selectionNavigationDocuments.get(fixed)?.destroy();
        fixedDom.window.close();
      }
      if (navigator.maxTouchPoints === 0) {
        f.select(3, 5); await settle();
        assert.equal(emitted.length, 0, 'desktop mouse keeps pointerup timing');
        f.send('pointerup');
        assert.equal(emitted.at(-1).text, '中国');
        f.select(3, 7); await settle();
        assert.equal(emitted.length, 1);
        f.send('pointerup');
        assert.equal(emitted.at(-1).text, '中国文化');
        continue;
      }
      f.select(3, 5); f.send('pointerup'); await settle();
      assert.equal(emitted.at(-1).text, '中国');
      const firstCFI = emitted.at(-1).cfi;
      // System handle movement sends only selectionchange; intermediate
      // ranges must not leave the toolbar with the old single-word payload.
      f.select(3, 6); f.select(3, 7); await settle();
      assert.equal(emitted.length, 2);
      assert.equal(emitted.at(-1).text, '中国文化');
      assert.notEqual(emitted.at(-1).cfi, firstCFI);
      assert.equal(emitted.at(-1).pos.right, 7);
      // A handle can shrink back to one character without automatic expansion.
      f.select(3, 4); await settle();
      assert.equal(f.text(), '中');
      assert.equal(emitted.at(-1).text, '中');
      assert.deepEqual(Array.from(emitted.at(-1).annotationIds), [42]);
      const second = f.doc.querySelectorAll('p')[1].firstChild;
      f.select(3, 4, f.doc.querySelector('p').firstChild, second); await settle();
      assert.equal(emitted.at(-1).text, '中国文化。第二段文');
      assert.ok(emitted.at(-1).contextText.includes('第二段文字'));
      const count = emitted.length;
      f.send('selectionchange', {}, f.doc); f.send('pointerup'); await settle();
      assert.equal(emitted.length, count, 'unchanged range is not republished');
      f.select(0, 3); f.doc.getSelection().removeAllRanges();
      f.send('selectionchange', {}, f.doc); await settle();
      assert.equal(emitted.length, count, 'collapse cancels pending publication');
      assert.ok(cleared.includes('onSelectionCleared'));
      f.doc.__moduQuickMarkEnabled = true;
      f.select(0, 3); await settle();
      assert.equal(emitted.length, count, 'quick mark keeps its own menu lifecycle');
    } finally {
      maps.settledSelectionDocuments.get(f.doc)?.();
      maps.smartSelectionDocuments.get(f.doc)?.destroy(); f.close();
    }
  }
});

test('actual Android reader wiring expands a glyph selection before sending it to Flutter', async () => {
  const source = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
  const handler = source.slice(source.indexOf('const setSelectionHandler ='), source.indexOf('const isZip ='));
  const menu = source.slice(source.indexOf('window.onNativeReaderLongPress ='), source.indexOf('window.getSelection ='));
  for (const paragraph of [false, true]) {
    const f = fixture(); f.control.destroy();
    f.doc.caretPositionFromPoint = () => null;
    const maps = { smartSelectionDocuments: new WeakMap(), settledSelectionDocuments: new WeakMap(), selectionNavigationDocuments: new WeakMap() };
    const requests = [], emitted = [], bridgeWindow = { isFootNoteOpen: () => false };
    const view = { isFixedLayout: false,
      renderer: Object.assign(new f.dom.window.EventTarget(), { getContents: () => [{ doc: f.doc }] }) };
    const setup = runInNewContext(`${handler}\n${menu}\nsetSelectionHandler;`, {
      ...maps, navigator: { platform: 'Linux armv8l', userAgent: 'Android 14', maxTouchPoints: 5 },
      style: { longPressSelectParagraph: paragraph, selectionLocale: 'zh-CN' },
      installSmartSelection, installSettledSelection: (doc, options) => installSettledSelection(doc, { ...options, delay: 5 }),
      getSelectionRange: selection => selection?.rangeCount && !selection.isCollapsed ? selection.getRangeAt(0) : null,
      handleSelection: () => emitted.push(f.text()), installSelectionNavigation,
      isInitialSmartSelection, window: bridgeWindow, reader: { view }, isPdf: false,
      callFlutter: async (name, request) => {
        assert.equal(name, 'onReaderParagraphWords'); requests.push(request); return [[3, 5]];
      },
    });
    setup(view, f.doc, 0);
    f.send('touchstart', { touches: [{ clientX: 35, clientY: 10 }] });
    f.send('pointercancel'); f.select(3, 4);
    bridgeWindow.onNativeReaderLongPress();
    await new Promise(done => setTimeout(done, 40));
    assert.deepEqual(emitted, [paragraph ? '我喜欢中国文化。' : '中国']);
    assert.equal(requests.length, paragraph ? 0 : 1);
    maps.settledSelectionDocuments.get(f.doc)(); maps.smartSelectionDocuments.get(f.doc).destroy(); f.close();
  }
});

test('older Android WebViews use local system bounds across inline nodes, not a whole chapter', () => withLegacyEngine(async () => {
  const requests = [];
  const f = fixture('<p>我爱<span>中</span><em>国</em>文化。</p><p>别的段落不发送。</p>', {
    locale: () => 'zh-CN', segmentWord: async request => { requests.push(request); return [2, 4]; },
  });
  f.hit(f.doc.querySelector('span').firstChild, 0);
  f.send('pointerdown'); await flushBridge();
  assert.deepEqual(requests, [{ text: '我爱中国文化。', offset: 2, locale: 'zh-CN' }]);
  assert.equal(f.text(), ''); f.advance(600);
  assert.equal(f.text(), '中国');
  assert.deepEqual(f.adjusted, ['中国']);
  f.close();
}));

test('late system bounds may finish a full long press after release, never a short tap or cancelled touch', () => withLegacyEngine(async () => {
  for (const end of ['full', 'tap', 'scroll', 'cancel', 'destroy', 'multitouch']) {
    let resolve;
    const f = fixture(undefined, { segmentWord: () => new Promise(done => { resolve = done; }) });
    f.send('pointerdown'); await flushBridge();
    f.advance(end === 'full' ? 610 : 100);
    if (end === 'full' || end === 'tap') f.send('pointerup');
    if (end === 'scroll') f.send('scroll');
    if (end === 'cancel') f.send('pointercancel');
    if (end === 'destroy') f.control.destroy();
    if (end === 'multitouch') f.send('touchmove', { touches: [{ clientX: 31, clientY: 10 }, {}] });
    resolve([3, 5]); await flushBridge(); f.advance(1200);
    assert.equal(f.text(), end === 'full' ? '中国' : '', end);
    f.close();
  }
}));

test('asynchronous system word bounds cannot overwrite a manually changed native range', () => withLegacyEngine(async () => {
  let resolve;
  const f = fixture(undefined, { segmentWord: () => new Promise(done => { resolve = done; }) });
  f.send('pointerdown'); await flushBridge(); f.advance(300); f.select(3, 4);
  f.select(2, 6);
  resolve([3, 5]); await flushBridge(); f.advance(1000);
  assert.equal(f.text(), '欢中国文'); assert.equal(f.adjusted.length, 0);
  f.close();
}));

test('invalid system bounds, changed paragraph text or a failed bridge leave native selection intact', () => withLegacyEngine(async () => {
  for (const result of [null, [0, 1], [-1, 5], [3, 99], [3, 3], [3.5, 5], [3, 5, 6]]) {
    const f = fixture(undefined, { segmentWord: async () => result });
    f.send('pointerdown'); await flushBridge(); f.advance(300); f.select(3, 4); f.advance(1000);
    assert.equal(f.text(), '中'); assert.equal(f.adjusted.length, 0); f.close();
  }
  let resolve;
  const changed = fixture(undefined, { segmentWord: () => new Promise(done => { resolve = done; }) });
  changed.send('pointerdown'); await flushBridge();
  changed.doc.querySelector('p').firstChild.data = '更改后的正文。';
  resolve([3, 5]); await flushBridge(); changed.advance(700);
  assert.equal(changed.text(), ''); changed.close();
  const failed = fixture(undefined, { segmentWord: async () => { throw new Error('unavailable'); } });
  failed.send('pointerdown'); await flushBridge(); failed.advance(300); failed.select(3, 4); failed.advance(700);
  assert.equal(failed.text(), '中'); assert.equal(failed.adjusted.length, 0); failed.close();
}));

test('modern engines and paragraph mode never request system word segmentation', async () => {
  let calls = 0;
  const f = fixture(undefined, { segmentWord: () => { calls++; } });
  f.send('pointerdown'); await flushBridge(); f.advance(600);
  assert.equal(f.text(), '中国'); assert.equal(calls, 0); f.close();
  await withLegacyEngine(async () => {
    const p = fixture(undefined, { paragraph: () => true, segmentWord: () => { calls++; } });
    p.send('pointerdown'); await flushBridge(); p.advance(600);
    assert.equal(p.text(), '我喜欢中国文化。'); assert.equal(calls, 0); p.close();
  });
});

for (const end of ['pointercancel', 'touchcancel', 'pointerup', 'touchend']) {
  test(`late native selection after ${end} still selects the whole word`, () => {
    const f = fixture();
    f.send('pointerdown'); f.advance(300); f.send(end); f.advance(50); f.select(3, 4);
    assert.equal(f.text(), '中国'); assert.equal(f.adjusted.length, 1);
    f.close();
  });
}

test('long press can select a paragraph without swallowing later manual changes', () => {
  const f = fixture('<p>第一段中国。</p><p>第二段。</p>', { paragraph: () => true });
  f.send('pointerdown'); f.advance(300); f.select(3, 4);
  assert.equal(f.text(), '第一段中国。');
  assert.equal(isInitialSmartSelection(f.doc, f.doc.getSelection().getRangeAt(0)), true);
  f.send('pointerup'); f.select(3, 5);
  assert.equal(f.text(), '中国'); assert.equal(f.adjusted.length, 1);
  f.close();
});

test('switching word/paragraph mode takes effect on the next press without reopening the book', () => {
  let paragraph = false;
  const f = fixture(undefined, { paragraph: () => paragraph });
  f.send('pointerdown'); f.advance(300); f.select(3, 4);
  assert.equal(f.text(), '中国'); f.send('pointerup');
  f.doc.getSelection().removeAllRanges(); paragraph = true; f.advance(700);
  f.send('pointerdown'); f.advance(300); f.select(3, 4);
  assert.equal(f.text(), '我喜欢中国文化。');
  f.close();
});

test('desktop long press selects a word, ordinary mouse drag/double click/right click are untouched', () => {
  const f = fixture('<p>hello world</p>');
  f.send('pointerdown', { pointerType: 'mouse' }); f.advance(599);
  assert.equal(f.text(), ''); f.advance(1);
  assert.equal(f.text(), 'hello');
  assert.equal(f.send('click').defaultPrevented, true);
  f.close();
  for (const props of [{ button: 2 }, { detail: 2 }, { ctrlKey: true }]) {
    const g = fixture('<p>hello world</p>');
    g.send('pointerdown', { pointerType: 'mouse', ...props }); g.advance(700);
    assert.equal(g.adjusted.length, 0); g.close();
  }
  const drag = fixture('<p>hello world</p>');
  drag.send('pointerdown', { pointerType: 'mouse' }); drag.send('pointermove', { clientX: 80 });
  drag.select(1, 9); drag.advance(700);
  assert.equal(drag.text(), 'ello wor'); assert.equal(drag.adjusted.length, 0);
  drag.close();
});

test('short taps, scrolling, multi-touch, selection handles and chapter cleanup do not expand', () => {
  for (const scenario of ['tap', 'scroll', 'multitouch', 'handle', 'cleanup', 'disabled', 'quickmark', 'moved']) {
    const f = fixture(undefined, { enabled: () => scenario !== 'disabled' });
    if (scenario === 'quickmark') f.doc.__moduQuickMarkEnabled = true;
    if (scenario === 'handle') f.select(3, 5);
    f.send('pointerdown'); f.advance(100);
    if (scenario === 'tap') f.send('pointerup');
    if (scenario === 'scroll') f.send('scroll');
    if (scenario === 'multitouch') f.send('touchmove', { touches: [{ clientX: 31, clientY: 10 }, {}] });
    if (scenario === 'moved') f.send('pointermove', { clientX: 51 });
    if (scenario === 'cleanup') f.control.cancel();
    f.advance(300); f.select(3, 4); f.advance(1000);
    assert.equal(f.text(), '中', scenario); assert.equal(f.adjusted.length, 0, scenario);
    f.close();
  }
});

test('a pending gesture expires and cannot replace an unrelated native range', () => {
  const f = fixture();
  f.send('pointerdown'); f.advance(300); f.send('pointercancel'); f.advance(1200); f.select(3, 4);
  assert.equal(f.text(), '中'); assert.equal(f.adjusted.length, 0); f.close();
  const unrelated = fixture();
  unrelated.send('pointerdown'); unrelated.advance(300); unrelated.select(0, 2); unrelated.advance(400);
  assert.equal(unrelated.text(), '我喜'); assert.equal(unrelated.adjusted.length, 0); unrelated.close();
});

test('caret right half targets the previous glyph, but blank margins do not start selection', () => {
  const f = fixture('<p>中国。</p>');
  const node = f.doc.querySelector('p').firstChild; f.hit(node, 2);
  f.send('pointerdown', { clientX: 19 }); f.advance(300); f.select(1, 2);
  assert.equal(f.text(), '中国'); f.close();
  const margin = fixture(); margin.send('pointerdown', { clientX: 150 }); margin.advance(700); margin.select(3, 4);
  assert.equal(margin.adjusted.length, 0); margin.close();
});

test('settled toolbar receives expanded selection once, then receives manual handle changes', async () => {
  const f = fixture(), emitted = [];
  const stop = installSettledSelection(f.doc, { delay: 5,
    getRange: () => f.doc.getSelection().isCollapsed ? null : f.doc.getSelection().getRangeAt(0),
    onSelection: () => emitted.push(f.text()) });
  f.send('pointerdown'); f.advance(300); f.select(3, 4); f.send('pointerup');
  await new Promise(resolve => setTimeout(resolve, 30));
  assert.deepEqual(emitted, ['中国']);
  f.select(2, 6); await new Promise(resolve => setTimeout(resolve, 30));
  assert.deepEqual(emitted, ['中国', '欢中国文']);
  stop(); f.close();
});

test('reader integration resolves settings live and guards automatic cross-page extension', async () => {
  const book = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
  assert.match(book, /enabled: \(\) => !view\.isFixedLayout/);
  assert.match(book, /paragraph: \(\) => style\.longPressSelectParagraph === true/);
  assert.match(book, /locale: \(\) => style\.selectionLocale/);
  assert.match(book, /segmentWord: navigator\.userAgent\.includes\('Android'\)/);
  assert.match(book, /callFlutter\('onReaderWordBounds', request\)/);
  assert.match(book, /isInitialSelection: range => isInitialSmartSelection\(doc, range\)/);
  assert.match(book, /nativeTouchSelection: navigator\.userAgent\.includes\('Android'\)/);
  assert.match(book, /beforeSelection: \(\) => smartSelectionDocuments\.get\(doc\)\?\.beforeSelection\?\.\(\)/);
  assert.match(book, /preserveActiveSelection: detail\.reason === 'scroll'\s*\|\| selectionNavigationDocuments\.get\(doc\)\?\.active/);
  assert.match(book, /window\.onNativeReaderLongPress =/);
  assert.match(book, /smartSelectionDocuments\.get\(doc\)\?\.nativeLongPress\?\.\(\)/);
  for (const name of ['lib/utils/webView/webview_initial_variable.dart', 'lib/page/book_player/epub_player.dart']) {
    const dart = await readFile(new URL(`../${name}`, import.meta.url), 'utf8');
    assert.match(dart, /longPressSelectParagraph: \$\{Prefs\(\)\.longPressSelectParagraph\}/);
    assert.match(dart, /selectionLocale: \$\{jsonEncode\(Prefs\(\)\.effectiveLocale\.toLanguageTag\(\)\)\}/);
    if (name.endsWith('epub_player.dart'))
      assert.match(dart, /onCreateContextMenu:[\s\S]*window\.onNativeReaderLongPress\?\.\(\)/);
  }
});
