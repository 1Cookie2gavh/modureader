import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const require = createRequire(`${process.env.MODU_JSDOM_ROOT || '/private/tmp/modu-129-js-deps'}/package.json`);
const {JSDOM} = require('jsdom');
const source = await readFile(new URL('../assets/foliate-js/src/pdf-zoom-input.js', import.meta.url), 'utf8');
const {attachPdfZoomInput} = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
function setup() {
  const dom = new JSDOM('<body>page</body>');
  const doc = dom.window.document;
  let taps = 0, pans = 0;
  attachPdfZoomInput(doc, {active: () => true, zoom: () => 2,
    setZoom() {}, pan() {pans++}, boxMode: () => false, box() {}});
  doc.addEventListener('click', () => taps++);
  const mouse = (type, x=100, y=100) => doc.dispatchEvent(new dom.window.MouseEvent(type,
    {bubbles:true, cancelable:true, button:0, buttons:type==='mouseup'?0:1,
      clientX:x, clientY:y, screenX:x, screenY:y}));
  const touch = (type, points) => {
    const event = new dom.window.Event(type, {bubbles:true, cancelable:true});
    Object.defineProperty(event, 'touches', {value:points.map(([x,y])=>({screenX:x,screenY:y}))});
    doc.dispatchEvent(event);
  };
  return {dom, mouse, touch, get taps(){return taps}, get pans(){return pans}};
}
test('enlarged page mouse tap reaches page turning; a drag does not', () => {
  const h=setup();
  try {
    h.mouse('mousedown'); h.mouse('mouseup'); h.mouse('click');
    assert.equal(h.taps,1); assert.equal(h.pans,0);
    h.mouse('mousedown'); h.mouse('mousemove',100,150); h.mouse('mouseup',100,150); h.mouse('click');
    assert.equal(h.taps,1); assert.equal(h.pans,1);
  } finally {h.dom.window.close()}
});
test('enlarged page short touch reaches click; drag suppresses synthetic click', () => {
  const h=setup();
  try {
    h.touch('touchstart',[[100,100]]); h.touch('touchend',[]); h.mouse('click');
    assert.equal(h.taps,1);
    h.touch('touchstart',[[100,100]]); h.touch('touchmove',[[100,150]]);
    h.touch('touchend',[]); h.mouse('click');
    assert.equal(h.taps,1); assert.equal(h.pans,1);
  } finally {h.dom.window.close()}
});
