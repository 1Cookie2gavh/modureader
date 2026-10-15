import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
const book = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
const setStyle = book.slice(book.indexOf('const setStyle ='), book.indexOf('const onRelocated ='));

test('chapter scroll preference defaults on and preserves script/vertical safety guards', () => {
  for (const enabled of [undefined, true, false])
    for (const allowScript of [false, true])
      for (const writingMode of ['horizontal-tb', 'vertical-rl']) {
        const attrs = new Map();
        runInNewContext(`${setStyle};setStyle()`, {
          style: {continuousScroll: enabled, allowScript, writingMode, pageTurnStyle:'scroll'},
          document: {documentElement: {style:{}}},
          reader: {view:{renderer:{setAttribute:(k,v)=>attrs.set(k,v),setStyles(){}}}},
          applyReaderMotion(){},applyVerticalPageChrome(){},getCSS(){},
          highlightWarnings:new Set(),updateCustomHighlights(){},
        });
        assert.equal(attrs.get('continuous-scroll'),
          String(enabled !== false && !allowScript && writingMode === 'horizontal-tb'));
        assert.equal(attrs.get('flow'), 'scrolled');
      }
});

test('live toggle restores pre-render CFI without navigation history; paginated mode stays put', () => {
  for (const pageTurnStyle of ['scroll','slide','noAnimation']) {
    const navigations = [], view = {lastLocation:{cfi:'before-render'},
      goTo:(...args)=>navigations.push(args),renderer:{
        setAttribute(){view.lastLocation.cfi='after-render'},removeAttribute(){},setStyles(){},
      }};
    runInNewContext(`${setStyle};setStyle({continuousScroll:true,pageTurnStyle})`, {
      style:{continuousScroll:false,pageTurnStyle},pageTurnStyle,reader:{view},
      document:{documentElement:{style:{}}},applyReaderMotion(){},
      applyVerticalPageChrome(){},getCSS(){},highlightWarnings:new Set(),updateCustomHighlights(){},
    });
    assert.equal(navigations.length, pageTurnStyle === 'scroll' ? 1 : 0);
    if (navigations.length) {
      assert.equal(navigations[0][0],'before-render');
      assert.equal(navigations[0][1].recordHistory,false);
    }
  }
});
