// Run against a local repository server; PLAYWRIGHT_MODULE selects installed Playwright.
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  const page = await browser.newPage();
  await page.goto(process.argv[2] || 'http://127.0.0.1:8874');
  const results = await page.evaluate(async () => {
    const { alignPaginatedText, resetPageAlignment, fitTextLineSpacing } =
      await import('/assets/foliate-js/src/text-page-layout.js');
    const results = [];
    for (const [width, height] of [[360, 800], [480, 640], [768, 1024], [1264, 1680]])
      for (const size of [16, 24, 32, 48]) for (const spacing of [1.2, 1.8]) {
        const frame = document.createElement('iframe');
        frame.style.cssText = `width:${width}px;height:${height}px;border:0`;
        document.body.append(frame);
        const doc = frame.contentDocument;
        // Keep several prose-only columns even on a large screen at small font sizes.
        const paragraphs = Math.max(12, Math.ceil(width * height / (size * size * 192) * 3));
        doc.open();
        doc.write(`<style>
          html{--modu-align-pages:1;font:${size}px serif}
          body{margin:0;padding:20px;box-sizing:border-box;height:${height}px;
            column-width:${width - 40}px;column-gap:40px;column-fill:auto}
          p{line-height:${spacing};margin:0 0 .5em}
          h4{font-size:1em;line-height:1.3;margin:1em 1em 1em 2.6em}
          .num{float:left;line-height:1.3;border-right:2px solid gray;
            padding-right:10px;margin:0 .5em 0 -2.6em}
          </style><p>${'普通正文用于校验分页。'.repeat(8)}</p>
          <h4><span class="num">035</span>带浮动编号和竖线的多行标题排版测试</h4>
          ${`<p>${'其他页面的正文继续自动上下对齐。'.repeat(12)}</p>`.repeat(paragraphs)}`);
        doc.close();
        const heading = doc.querySelector('h4'), number = doc.querySelector('.num');
        const originalMarkup = heading.innerHTML;
        fitTextLineSpacing(doc, height - 40);
        const measure = () => {
          const range = doc.createRange();
          range.selectNodeContents(heading.lastChild);
          const r = range.getClientRects()[0], n = number.getBoundingClientRect();
          return [r.left, r.top, n.left, n.top, n.height];
        };
        const before = measure();
        const layout = { height, topMargin: 20, bottomMargin: 20, columnWidth: width - 40, gap: 40 };
        alignPaginatedText(doc, layout, false);
        const after = measure();
        const shiftedProse = [...doc.querySelectorAll('p modu-page-run')]
          .some(el => Math.abs(parseFloat(el.style.top)) > .01);
        resetPageAlignment(doc);
        fitTextLineSpacing(doc, height - 40);
        alignPaginatedText(doc, layout, false);
        const again = measure();
        results.push({ width, height, size, spacing, before, after, again, shiftedProse,
          intact: heading.innerHTML === originalMarkup,
          lines: heading.getClientRects().length });
        frame.remove();
      }
    return results;
  });
  for (const row of results) {
    assert.equal(row.intact, true, JSON.stringify(row));
    assert.deepEqual(row.after, row.before, JSON.stringify(row));
    assert.deepEqual(row.again, row.before, JSON.stringify(row));
    assert.equal(row.shiftedProse, true, JSON.stringify(row));
  }
  console.log(`PASS: ${results.length} screen/font/spacing combinations; headings stay intact and ordinary prose still aligns.`);
} finally {
  await browser.close();
}
