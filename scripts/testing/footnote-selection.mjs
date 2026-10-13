// Serve the repository locally; use the same PLAYWRIGHT_MODULE as text-layout-matrix.mjs.
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const base = process.argv[2] || 'http://127.0.0.1:8768';
const page = await browser.newPage(), errors = [];
page.on('pageerror', error => errors.push(error.message));
let notes = 0, selections = 0;
try {
  await mkdir('output/playwright', { recursive: true });
  for (const [width, height] of [[390,844], [1024,768], [1600,1068]]) {
    await page.setViewportSize({ width, height });
    for (const font of [16,32]) for (const long of [0,1]) for (const vertical of [0,1]) {
      await page.goto(`${base}/test/fixtures/footnote-orientation.html?desktop=0&duokan=1&font=${font}&long=${long}&vertical=${vertical}`);
      await page.waitForFunction(() => window.ready);
      const result = await page.evaluate(async () => {
        const {doc} = fixture, win = doc.defaultView, list = doc.querySelector('ol'), item = list.firstElementChild;
        const samples = [];
        for (let i = 0; i < 30; i++) {
          await new Promise(resolve => requestAnimationFrame(resolve));
          const box = document.querySelector('#note').getBoundingClientRect();
          samples.push([box.width, box.height, win.getComputedStyle(item).lineHeight]);
        }
        const css = win.getComputedStyle(list), body = doc.body.getBoundingClientRect(), rect = list.getBoundingClientRect();
        return { samples, align: win.getComputedStyle(doc.documentElement).getPropertyValue('--modu-align-pages').trim(),
          padding: [css.paddingInlineStart,css.paddingInlineEnd],
          margins: [rect.left-body.left,body.right-rect.right], inlineLineHeight: item.style.lineHeight };
      });
      assert.equal(result.align, '0');
      assert.equal(result.inlineLineHeight, '', 'popup layout must not rewrite line height');
      assert.deepEqual(result.padding, ['0px','0px']);
      for (const sample of result.samples) assert.equal(parseFloat(sample[2]), font*1.5);
      for (const sample of result.samples.slice(-10)) assert.deepEqual(sample, result.samples.at(-1), 'popup must settle');
      if (!vertical) assert.ok(Math.abs(result.margins[0]-result.margins[1]) < 1, JSON.stringify(result));
      if (!vertical && long && font === 32)
        await page.screenshot({path:`output/playwright/footnote-${width}.png`});
      notes++;
    }
    await page.goto(`${base}/test/fixtures/text-layout-matrix.html`);
    await page.waitForFunction(() => window.ready);
    for (const font of [20,40]) for (const spacing of [1.2,2.4]) {
      await page.evaluate(config => matrix.open({...config, paragraphCount:8, production:true}), {font,spacing});
      const result = await page.evaluate(async () => {
        const { installSmartSelection } = await import('/assets/foliate-js/src/smart-selection.js');
        const { annotationRangeRects } = await import('/assets/foliate-js/src/annotation-geometry.js');
        const doc = matrix.renderer.getContents()[0].doc;
        const control = installSmartSelection(doc, {nativeTouchSelection:true,enabled:()=>false});
        const runs = [...doc.querySelectorAll('modu-page-run')];
        const range = doc.createRange();
        const startTop = runs[10].getBoundingClientRect().top;
        const nextLine = runs.findIndex((run,i)=>i>10 && run.getBoundingClientRect().top>startTop+1);
        const end = runs[Math.max(35,nextLine+8)];
        range.setStart(runs[10].firstChild,0); range.setEnd(end.firstChild,end.textContent.length);
        const expectedText = range.toString(), before = doc.body.innerHTML;
        doc.getSelection().removeAllRanges(); doc.getSelection().addRange(range);
        await control.beforeSelection();
        const host = doc.querySelector('[data-modu-selection-handles]');
        const expected = annotationRangeRects(range).map(r=>[r.left,r.top,r.width,r.height]);
        const actual = [...host.shadowRoot.querySelectorAll('[data-selection-highlight] i')].map(el=>
          ['left','top','width','height'].map(name=>parseFloat(el.style[name])));
        const sameText = doc.getSelection().toString() === expectedText;
        const sameLayout = before === doc.body.innerHTML;
        const background = doc.defaultView.getComputedStyle(runs[10],'::selection').backgroundColor;
        window.selectionControl=control;
        return {expected,actual,sameText,sameLayout,background};
      });
      assert.ok(result.expected.length > 0);
      assert.equal(result.actual.length,result.expected.length);
      result.actual.forEach((rect,i)=>rect.forEach((value,j)=>
        assert.ok(Math.abs(value-result.expected[i][j])<.01, 'CSS pixel serialization stays within 0.01px')));
      assert.ok(result.sameText && result.sameLayout);
      assert.equal(result.background, 'rgba(0, 0, 0, 0)');
      await page.screenshot({path:`output/playwright/selection-${width}.png`});
      const restored = await page.evaluate(() => {
        selectionControl.destroy();
        const doc=matrix.renderer.getContents()[0].doc;
        return {host:!!doc.querySelector('[data-modu-selection-handles]'),
          background:doc.defaultView.getComputedStyle(doc.querySelector('modu-page-run'),'::selection').backgroundColor};
      });
      assert.equal(restored.host,false);
      assert.equal(restored.background,'rgba(64, 156, 255, 0.35)');
      selections++;
    }
  }
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({notes,selections,errors}));
} finally { await browser.close(); }
