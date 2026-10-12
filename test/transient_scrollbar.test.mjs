import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {JSDOM} = createRequire(`${process.env.MODU_JSDOM_ROOT || '/private/tmp/modu-pdf-js-tests'}/package.json`)('jsdom');
const source = await readFile(new URL('../assets/foliate-js/src/transient-scrollbar.js', import.meta.url), 'utf8');

function fixture(options = {}) {
  const dom = new JSDOM('<html><body><div id="content"></div></body></html>', {runScripts: 'outside-only'});
  const {window: w} = dom;
  const timers = new Map(); let id = 0;
  w.setTimeout = fn => { timers.set(++id, fn); return id; };
  w.clearTimeout = key => timers.delete(key);
  w.eval(source);
  const content = w.document.getElementById('content');
  Object.defineProperties(content, {
    clientHeight: {value: 200, configurable: true}, scrollHeight: {value: 1000, configurable: true},
    clientWidth: {value: 200}, scrollWidth: {value: 1000},
  });
  content.getBoundingClientRect = () => ({top: 0, left: 0, right: 200, bottom: 200});
  const bar = w.moduAttachScrollbar(content, w.document.body, options);
  const track = w.document.querySelector('[data-modu-scrollbar]');
  const thumb = track.firstChild;
  thumb.setPointerCapture = () => {};
  const pointer = (type, x, y) => {
    const e = new w.MouseEvent(type, {clientX: x, clientY: y, bubbles: true, cancelable: true});
    Object.defineProperty(e, 'pointerId', {value: 1}); thumb.dispatchEvent(e);
  };
  return {dom, w, content, bar, track, thumb, pointer, timers,
    scroll() { content.dispatchEvent(new w.Event('scroll')); },
    idle() { for (const fn of [...timers.values()]) fn(); }};
}

test('web scrollbar is translucent, starts hidden, drags only its scroller and hides after idle', () => {
  const f = fixture();
  try {
    assert.equal(f.track.style.opacity, '0');
    assert.match(f.thumb.style.background, /0.46/);
    f.scroll(); assert.equal(f.track.style.opacity, '1');
    assert.equal(f.thumb.style.pointerEvents, 'auto');
    f.pointer('pointerdown', 194, 10);
    f.pointer('pointermove', 194, 90);
    assert.ok(f.content.scrollTop > 300);
    f.idle(); assert.equal(f.track.style.opacity, '1'); // no hiding mid-drag
    f.pointer('pointerup', 194, 90);
    f.idle(); assert.equal(f.track.style.opacity, '0');
    assert.equal(f.thumb.style.pointerEvents, 'none');
    f.bar.destroy();
    assert.equal(f.w.document.querySelector('[data-modu-scrollbar]'), null);
    assert.equal(f.timers.size, 0);
  } finally { f.dom.window.close(); }
});

test('no bar for fitting content or pagination; E-Ink skips fade', () => {
  let enabled = false;
  const f = fixture({enabled: () => enabled, reducedMotion: () => true});
  try {
    f.scroll(); assert.equal(f.track.style.opacity, '0');
    enabled = true; f.scroll(); assert.equal(f.track.style.transition, 'none');
    Object.defineProperty(f.content, 'scrollHeight', {value: 200});
    f.bar.update(); assert.equal(f.track.style.opacity, '0');
  } finally { f.bar.destroy(); f.dom.window.close(); }
});

test('horizontal overflow has no bar and preserves horizontal scrolling', () => {
  const f = fixture();
  try {
    Object.defineProperty(f.content, 'scrollHeight', {value: 200});
    f.content.style.direction = 'rtl'; f.content.scrollLeft = -200;
    f.scroll();
    assert.equal(f.track.style.opacity, '0');
    assert.equal(f.content.scrollLeft, -200);
    f.pointer('pointerdown', 100, 194);
    f.pointer('pointermove', 60, 194);
    assert.equal(f.content.scrollLeft, -200);
    assert.equal(f.track.style.opacity, '0');
  } finally { f.bar.destroy(); f.dom.window.close(); }
});

test('keyboard navigation is bounded and does not bubble into reader shortcuts', () => {
  const f = fixture();
  try {
    let parentKey = false;
    f.w.document.body.addEventListener('keydown', () => { parentKey = true; });
    f.scroll();
    f.thumb.dispatchEvent(new f.w.KeyboardEvent('keydown', {key: 'End', bubbles: true, cancelable: true}));
    assert.equal(f.content.scrollTop, 800);
    assert.equal(parentKey, false);
  } finally { f.bar.destroy(); f.dom.window.close(); }
});

test('web panel nested scrollers are decorated once and disposed together', () => {
  const f = fixture();
  try {
    f.bar.destroy();
    const panel = f.w.moduAttachDocumentScrollbars(f.w.document);
    f.scroll(); f.scroll();
    const tracks = f.w.document.querySelectorAll('[data-modu-scrollbar]');
    assert.equal(tracks.length, 2); // document and the inner viewport
    assert.equal(tracks[1].style.opacity, '1');
    panel.destroy();
    assert.equal(f.w.document.querySelectorAll('[data-modu-scrollbar]').length, 0);
    f.scroll();
    assert.equal(f.w.document.querySelectorAll('[data-modu-scrollbar]').length, 0);
  } finally { f.dom.window.close(); }
});
