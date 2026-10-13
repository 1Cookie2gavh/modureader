// Run with PLAYWRIGHT_MODULE pointing to an installed playwright module.
// Serve the repository locally, then optionally pass its base URL as argv[2].
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { writeFile, mkdir } from 'node:fs/promises';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({channel:'chrome',headless:true});
const compact=process.argv.includes('--compact');
const production=process.argv.includes('--production');
const paginatedOnly=process.argv.includes('--paginated-only');
const legado=process.argv.includes('--legado');
const page = await browser.newPage({deviceScaleFactor:compact?2.625:1});
const errors=[];
page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',route=>route.continue());
const results=[];
try {
  await page.goto(`${process.argv[2] || 'http://127.0.0.1:8768'}/test/fixtures/text-layout-matrix.html`);
  await page.waitForFunction(()=>window.ready);
  const sizes=legado?[[320,568],[844,390],[390,844],[768,1024],[1366,768]]:production?[[360,800],[390,844],[430,932],[768,1024]]:compact?[[844,390],[586,522]]:process.argv.includes('--quick')?[[320,568],[1366,768]]:[[320,568],[390,844],[430,932],[768,1024],[1024,768],[1366,768]];
  for(const [width,height] of sizes) {
    await page.setViewportSize({width,height});
    for(const font of legado?[20,40,56]:production?[20,28,40]:[14,20,28,40]) for(const spacing of production||legado?[0,1.8,3]:[0,1.2,1.8])
      for(const paragraph of legado?[0,3]:production?[3,5]:[0,.6]) for(const flow of paginatedOnly||legado?['paginated']:['paginated','scrolled'])
      for(const markup of production||legado?['p','div']:['p']) {
        const config={font,spacing,paragraph,flow,production:production||legado,markup,top:font===28?80:45,bottom:font===28?55:30,gap:font===40?10:5,
          ...(legado?{paragraphCount:8,mixed:true}:{} )};
        const result=await page.evaluate(async config=>{
          const state=await matrix.open(config),failures=[];
          const c=matrix.renderer.shadowRoot.querySelector('#container');
          const cut=(y,lines)=>lines.some(r=>y>r.top+.75&&y<r.bottom-.75);
          let tested=0,maxError=0,singleLinePages=0;
          if(config.flow==='paginated') {
            if(config.production) {
              const doc=matrix.renderer.getContents()[0].doc, style=doc.defaultView.getComputedStyle(doc.querySelector(config.markup));
              if(Math.abs(parseFloat(style.marginBlockStart)-config.paragraph/2*config.font)>.1)
                failures.push({kind:'paragraph-style-lost',margin:style.marginBlockStart});
            }
            const pages=new Map();
            for(const rect of state.rects) {
              const index=Math.floor((rect.left+1)/state.width);
              if(!pages.has(index))pages.set(index,[]);pages.get(index).push(rect);
            }
            const last=Math.max(...pages.keys());
            for(const [index,rects] of pages) {
              if(index===last)continue;
              const top=Math.min(...rects.map(r=>r.top)),bottom=Math.max(...rects.map(r=>r.bottom));
              if(rects.every(r=>r.top<top+1)) {singleLinePages++;continue;}
              const error=Math.max(Math.abs(top-config.top),Math.abs(bottom-(state.height-config.bottom)));
              maxError=Math.max(maxError,error);tested++;
              if(error>1)failures.push({index,top,bottom,error});
            }
            matrix.watch();await matrix.turn(1);await matrix.turn(1);await matrix.turn(-1);
          } else {
            // Cache coordinates before input, measuring all text independently of the cache.
            const doc=matrix.renderer.getContents()[0].doc;
            const offset=doc.defaultView.frameElement.getBoundingClientRect().top-c.getBoundingClientRect().top+c.scrollTop;
            const lines=state.rects.map(r=>({top:r.top+offset,bottom:r.bottom+offset}));
            const initialLines=state.lines.length;
            if(initialLines<state.rects.length*.9)failures.push({merged:initialLines,rects:state.rects.length});
            matrix.watch();
            for(const direction of [1,1,1,-1]) {
              await matrix.turn(direction);const y=c.scrollTop+(direction>0?c.clientHeight:0);tested++;
              if(cut(y,lines))failures.push({kind:'page',direction,y});
            }
            for(const direction of [1,-1]) {
              // Stop halfway through a line, away from paragraph boundaries.
              const row=lines[Math.floor(lines.length*(direction>0?.6:.3))];
              const target=(row.top+row.bottom)/2-(direction>0?c.clientHeight:0);
              c.scrollTop=target-direction*60;
              await new Promise(resolve=>requestAnimationFrame(resolve));
              await matrix.scroll(target);const y=c.scrollTop+(direction>0?c.clientHeight:0);tested++;
              if(cut(y,lines))failures.push({kind:'settle',direction,y});
              const settled=c.scrollTop;await new Promise(r=>setTimeout(r,260));
              if(Math.abs(c.scrollTop-settled)>.5)failures.push({kind:'unstable'});
            }
          }
          if(matrix.mutations)failures.push({mutations:matrix.mutations});
          return {failures:failures.slice(0,5),tested,maxError,singleLinePages,lineHeight:state.lineHeight};
        },config);
        results.push({width,height,...config,...result});
      }
    console.log(JSON.stringify({size:[width,height],cases:results.length,failed:results.filter(r=>r.failures.length).length}));
  }
  await mkdir('output/playwright',{recursive:true});
  if(legado) {
    // Exercise resizing the existing document, not just reopening at a new size.
    const edges=(columns=1)=>page.evaluate(columns=>{
      const s=matrix.inspect(),pages=new Map();
      for(const r of s.rects) {
        const i=Math.floor((r.left+1)/(s.width/columns));
        if(!pages.has(i))pages.set(i,[]);pages.get(i).push(r);
      }
      return [...pages].map(([index,rows])=>({index,top:Math.min(...rows.map(r=>r.top)),bottom:Math.max(...rows.map(r=>r.bottom))}));
    },columns);
    await page.setViewportSize({width:390,height:844});
    await page.evaluate(()=>matrix.open({font:28,spacing:1.8,paragraph:3,production:true,paragraphCount:8,top:50,bottom:35,forcedBreak:true}));
    const forced=await edges();
    assert.ok(forced[0].bottom<600,'explicit short page must not stretch');
    assert.ok(Math.abs(forced[1].bottom-809)<1);
    await page.screenshot({path:'output/playwright/legado-forced-break.png'});
    await page.evaluate(async()=>{
      await matrix.open({font:40,spacing:1.8,paragraph:3,production:true,paragraphCount:8,top:50,bottom:35});
      window.originalLayoutDoc=matrix.renderer.getContents()[0].doc;
      window.originalTextNode=originalLayoutDoc.querySelector('modu-page-run').firstChild;
    });
    for(const [width,height] of [[390,844],[844,390],[390,844]]) {
      await page.setViewportSize({width,height});
      await page.waitForFunction(h=>matrix.inspect().height===h,height);
      await page.waitForTimeout(300);
      const rows=await edges();
      for(const r of rows.slice(0,-1))
        assert.ok(Math.abs(r.top-50)<1&&Math.abs(r.bottom-(height-35))<1,JSON.stringify({width,height,...r}));
      if(height===844)assert.ok(rows.at(-1).bottom<809,'chapter end retains natural whitespace');
      assert.ok(await page.evaluate(()=>matrix.renderer.getContents()[0].doc===originalLayoutDoc&&originalTextNode.isConnected));
      await page.screenshot({path:`output/playwright/legado-alignment-${width}x${height}.png`});
      const mutations=await page.evaluate(async()=>{
        matrix.watch();await matrix.turn(1);await matrix.turn(1);await matrix.turn(-1);return matrix.mutations;
      });
      assert.equal(mutations,0,'turns after resizing must reuse completed layout');
    }
    await page.setViewportSize({width:1366,height:768});
    await page.evaluate(()=>matrix.renderer.setAttribute('max-column-count','2'));
    await page.waitForTimeout(300);
    const columns=await edges(2);
    assert.ok(columns.length>2);
    for(const r of columns.slice(0,-1))
      assert.ok(Math.abs(r.top-50)<1&&Math.abs(r.bottom-733)<1,JSON.stringify(r));
    await page.screenshot({path:'output/playwright/legado-alignment-two-columns.png'});
    const mutations=await page.evaluate(async()=>{
      matrix.watch();await matrix.turn(1);await matrix.turn(-1);return matrix.mutations;
    });
    assert.equal(mutations,0);
    console.log('Forced-break, chapter-end and same-document portrait/landscape/portrait checks passed.');
  }
  await writeFile(`output/playwright/text-layout-matrix${legado?'-legado':production?'-production':compact?'-compact':''}${paginatedOnly?'-pages':''}.json`,JSON.stringify({errors,results},null,2));
  const failed=results.filter(r=>r.failures.length);
  console.log(JSON.stringify({cases:results.length,checks:results.reduce((n,r)=>n+r.tested,0),failed:failed.length,errors,examples:failed.slice(0,4)},null,2));
  if(failed.length||errors.length)process.exitCode=1;
} finally {await browser.close()}
