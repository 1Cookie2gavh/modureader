import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
const book = await readFile(new URL('../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
const setStyle = book.slice(book.indexOf('const setStyle ='), book.indexOf('const onRelocated ='));

test('reader commits geometry as one batch when the paginator supports it', () => {
  const batches = [], individual = [];
  runInNewContext(`${setStyle};setStyle()`, {
    style:{pageTurnStyle:'noAnimation', eInkMode:true, sideMargin:5},
    reader:{view:{renderer:{
      setLayoutAttributes: attrs => batches.push(attrs),
      setAttribute: name => individual.push(name), setStyles(){},
    }}},
    document:{documentElement:{style:{}}}, applyReaderMotion(){},
    applyVerticalPageChrome(){}, getCSS(){}, highlightWarnings:new Set(), updateCustomHighlights(){},
  });
  assert.equal(batches.length, 1);
  assert.equal(batches[0].flow, 'paginated');
  assert.equal(batches[0].animated, null);
  assert.equal(batches[0].gap, '5%');
  assert.ok(!individual.includes('flow') && !individual.includes('gap'));
});

test('ebook night palette bypasses geometry and highlight rescans, but typography never does', () => {
  for (const change of [
    {fontColor:'#ddd',backgroundColor:'#111',readingNightMode:true,backgroundImage:'none',verticalPageChrome:{}},
    {fontSize:24}, {spacing:2}, {customCSS:'p{margin:2em}'}, {sideMargin:10},
  ]) {
    const oldStyle={fontSize:20,spacing:1.6,sideMargin:5,pageTurnStyle:'slide',useBookStyles:true};
    const attrs=new Map(), options=[], highlights=[];
    runInNewContext(`${setStyle};setStyle(oldStyle)`, {
      oldStyle, style:{...oldStyle,...change},
      reader:{view:{renderer:{setAttribute:(k,v)=>attrs.set(k,v),
        setStyles:(_,o)=>options.push(o),getContents:()=>[{doc:{}}]}}},
      document:{documentElement:{style:{}}},applyReaderMotion(){},applyVerticalPageChrome(){},
      getCSS(){},highlightWarnings:new Set(),updateCustomHighlights:()=>highlights.push(true),
    });
    const paintOnly='fontColor' in change;
    assert.equal(options[0].paintOnly,paintOnly);
    assert.equal(attrs.has('flow'),!paintOnly);
    assert.equal(attrs.has('gap'),!paintOnly);
    assert.equal(attrs.has('max-column-count'),!paintOnly);
    assert.equal(highlights.length,paintOnly?0:1);
  }
});

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
