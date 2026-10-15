// Run with a local repository server and PLAYWRIGHT_MODULE pointing to Playwright.
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright');
const book = await readFile(new URL('../../assets/foliate-js/src/book.js', import.meta.url), 'utf8');
const styling = book.slice(book.indexOf('const setStyle ='), book.indexOf('const onRelocated ='));
const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  for (const long of [false, true]) {
    const page = await browser.newPage();
    await page.goto(`${process.argv[2] || 'http://127.0.0.1:8874'}/test/fixtures/continuous-reader.html${long ? '?long' : ''}`);
    await page.waitForFunction(() => window.ready);
    const result = await page.evaluate(async styling => {
      const { view, r, nav } = window.fixture;
      // Exercise the app's actual style bridge with the fixture's real renderer.
      const change = new Function('view', `
        let pending;
        const reader = { view: { renderer: view.renderer,
          get lastLocation() { return view.lastLocation },
          goTo(...args) { view.requestedCfi = args[0]; return pending = view.goTo(...args) } } };
        let style = { pageTurnStyle: 'scroll', continuousScroll: true, topMargin: 0,
          bottomMargin: 0, sideMargin: 5, maxColumnCount: 1, columnThreshold: 600,
          backgroundColor: '#faf8ef', useBookStyles: true };
        const applyReaderMotion = () => {}, applyVerticalPageChrome = () => {},
          updateCustomHighlights = () => {}, highlightWarnings = new Set();
        const getCSS = () => 'html{font:18px/1.5 sans-serif}h1{font-size:22px}p{margin:1em 0}';
        ${styling}
        return async enabled => { const oldStyle = style;
          style = { ...style, continuousScroll: enabled }; setStyle(oldStyle); await pending; };
      `)(view);
      await nav.start();
      const tts = view.tts, doc = tts.doc;
      const before = view.lastLocation.cfi;
      await change(false);
      const off = { continuous: r.continuous, count: r.getContents().length,
        target: view.requestedCfi, sameDoc: r.getContents()[0].doc === doc, sameTts: view.tts === tts };
      const container = r.shadowRoot.querySelector('#container');
      container.scrollTop = container.scrollHeight;
      await new Promise(resolve => setTimeout(resolve, 400));
      const atEnd = { count: r.getContents().length, index: r.getContents()[0].index };
      // The TTS cursor remains usable after changing the layout.
      const speech = await nav.move(1);
      await r.goTo({ index: 2, anchor: () => 1 });
      await r.next();
      const next = r.getContents()[0].index;
      await r.prev();
      const previous = r.getContents()[0].index;
      await change(true);
      const on = r.continuous;
      await change(false);
      const again = !r.continuous && r.getContents().length === 1;
      return { before, off, atEnd, next, previous, on, again, speech: !!speech };
    }, styling);
    assert.equal(result.off.continuous, false);
    assert.equal(result.off.count, 1);
    // Short chapters fit in one viewport: the visible range expands, but the restore target must not change.
    assert.equal(result.off.target, result.before, JSON.stringify(result));
    assert.equal(result.off.sameDoc, true);
    assert.equal(result.off.sameTts, true);
    assert.deepEqual(result.atEnd, { count: 1, index: 2 });
    assert.equal(result.next, 3);
    assert.equal(result.previous, 2);
    assert.equal(result.on, true);
    assert.equal(result.again, true);
    assert.equal(result.speech, true);
    console.log(`PASS: ${long ? 'long' : 'short'} chapters: retained position/TTS, isolated scroll, boundary navigation and repeated toggling.`);
    await page.close();
  }
} finally { await browser.close(); }
