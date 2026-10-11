import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {JSDOM}=createRequire(`${process.env.MODU_JSDOM_ROOT || '/private/tmp/modu-119-js-tests'}/package.json`)('jsdom');
const dom=new JSDOM('<body></body>',{pretendToBeVisual:true});globalThis.document=dom.window.document;globalThis.devicePixelRatio=1;
const uri=code=>`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`;
const source=name=>readFile(new URL(`../assets/foliate-js/src/${name}.js`,import.meta.url),'utf8');
const geometry=uri(await source('document-regions'));
const viewport=uri((await source('pdf-reading-viewport')).replace("'./document-regions.js'",JSON.stringify(geometry))
    .replace("'./document-reading-options.js'", JSON.stringify(uri(await source('document-reading-options'))))
    .replace("'./document-image-processing.js'",JSON.stringify(uri(await source('document-image-processing')))));
const layout=uri((await source('pdf-reading-layout')).replace("'./document-regions.js'",JSON.stringify(geometry)));
const scrollLayout=uri((await source('pdf-scroll-layout')).replace("'./pdf-reading-viewport.js'",JSON.stringify(viewport))
    .replace("'./document-regions.js'",JSON.stringify(geometry)));
const {scrollPagePlan,scrollVisibleRegion,scrollSourcePoint}=await import(scrollLayout);
const {PdfScrollReader}=await import(uri((await source('pdf-scroll-reader'))
    .replace("'./pdf-reading-layout.js'",JSON.stringify(layout)).replace("'./pdf-scroll-layout.js'",JSON.stringify(scrollLayout))));
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-6,`${a} != ${b}`);
const rect=(left,top,width,height)=>({left,top,right:left+width,bottom:top+height,width,height});
const children=[];
function harness(config={version:1,all:{preset:'single'},pages:{}}) {
    const loaded=[],states=[],locations=[],announced=[];
    const bounds={width:800,height:600};
    const book={sections:Array.from({length:60},(_,index)=>({load:async()=>{loaded.push(index);return String(index)}})),
        readingRegionRenderer:{render:async()=>({blob:new Blob(['png'])})}};
    const flow=new PdfScrollReader({book,layout:config,view:{zoom:1,fit:'width',rotation:0,mode:'scroll'},bounds:()=>bounds,
        onLoad:doc=>announced.push(doc),onRelocate:reason=>locations.push({reason,location:flow.location}),onState:s=>states.push(s),
        createFrame:async(index,src,parent,before)=>{
            const element=document.createElement('div');element.style.position='absolute';parent.insertBefore(element,before);
            const child=new JSDOM('<img><div class="textLayer"><span>Original text</span></div>');children.push(child);
            child.window.HTMLImageElement.prototype.decode=async()=>{};
            Object.defineProperty(element,'offsetTop',{get(){let y=0;for(const node of parent.children){
                if(node===element)break;if(node.style.position!=='absolute')y+=parseFloat(node.style.height)+16;}return y}});
            element.getBoundingClientRect=()=>rect(Math.max(0,(bounds.width-parseFloat(element.style.width))/2)-parent.scrollLeft,
                element.offsetTop-parent.scrollTop,parseFloat(element.style.width),parseFloat(element.style.height));
            return {index,element,width:600,height:800,iframe:{style:{},contentDocument:child.window.document}};
        }});
    document.body.append(flow.element);flow.element.getBoundingClientRect=()=>rect(0,0,bounds.width,bounds.height);
    Object.defineProperty(flow.element,'clientWidth',{get:()=>bounds.width});
    return {flow,book,loaded,states,locations,announced,bounds,close:()=>flow.destroy()};
}
test('rotated continuous geometry maps visible strips to bounded source rectangles',()=>{
    for(const rotation of [0,90,180,270]){
        const crop={x:.1,y:.1,width:.8,height:.8};
        const plan=scrollPagePlan({pageWidth:600,pageHeight:800,width:390,height:844,crop,view:{zoom:15,fit:'width',rotation}});
        assert.ok(plan.height>844);near(plan.width,5850);
        const region=scrollVisibleRegion(plan,crop,rect(-100,-200,plan.width,plan.height),rect(0,0,390,844));
        assert.ok(region.x>=.1-1e-9&&region.y>=.1-1e-9&&region.width<.2&&region.height<.3);
        const p=scrollSourcePoint(plan,crop,100,200);assert.ok(p.x>=.1-1e-9&&p.y>=.1-1e-9);
        assert.equal(scrollVisibleRegion(plan,crop,rect(0,900,plan.width,plan.height),rect(0,0,390,844)),null);
    }
});
test('prepending and recycling preserve source viewport; frames stay bounded in both directions',async()=>{
    const h=harness();try{
        await h.flow.open(20,0);h.flow.activate();const before=h.flow.location;
        await h.flow.ensureNeighbors();near(h.flow.location.center.y,before.center.y);assert.equal(h.flow.location.page,20);
        for(let i=0;i<30;i++){h.flow.pan(0,650);await h.flow.ensureNeighbors();assert.ok(h.flow.entries.length<=7)}
        const forward=h.flow.location.page;assert.ok(forward>25);
        for(let i=0;i<30;i++){h.flow.pan(0,-650);await h.flow.ensureNeighbors();assert.ok(h.flow.entries.length<=7)}
        assert.ok(h.flow.location.page<forward);
        for(let i=1;i<h.flow.entries.length;i++)assert.equal(h.flow.entries[i].index,h.flow.entries[i-1].index+1);
        assert.ok(h.loaded.length<60);
    }finally{h.close()}
});
test('neighbor failure retains current content, blocks repeated retries, and explicit retry recovers',async()=>{
    const h=harness();try{
        await h.flow.open(0,0);h.flow.activate();const doc=h.flow.getContents()[0].doc;
        let attempts=0;h.book.sections[1].load=async()=>{attempts++;throw Error('injected')};
        await h.flow.ensureNeighbors();await h.flow.ensureNeighbors();
        assert.equal(attempts,1);assert.equal(h.flow.getContents()[0].doc,doc);assert.deepEqual(h.states,['failed']);
        h.book.sections[1].load=async()=> '1';assert.equal(await h.flow.retry(),true);
        assert.ok(h.flow.getContents().some(e=>e.index===1));assert.equal(h.states.at(-1),'ready');
        const count=h.announced.length;h.flow.suspend();h.flow.activate();assert.equal(h.announced.length,count);
    }finally{h.close()}
});
test('close during neighbor loading cannot reattach pages or publish late events',async()=>{
    const h=harness();try{
        await h.flow.open(0,0);let release,started;
        const entered=new Promise(r=>started=r);
        h.book.sections[1].load=()=>{started();return new Promise(r=>release=r)};
        h.flow.activate();const pending=h.flow.ensureNeighbors();await entered;
        const count=h.announced.length;h.close();release('1');await pending;
        assert.equal(h.flow.entries.length,0);assert.equal(h.announced.length,count);assert.deepEqual(h.states,[]);
    }finally{h.close()}
});
test('scroll touch gestures do not become page swipes, while selected text keeps its gesture',async()=>{
    const h=harness();try{
        await h.flow.open(0,0);h.flow.activate();await h.flow.ensureNeighbors();
        const doc=h.flow.getContents()[0].doc;const seen=[];
        for(const type of ['touchstart','touchmove','touchend']) doc.addEventListener(type,()=>seen.push(type));
        const send=(type,y)=>{
            const event=new doc.defaultView.Event(type,{bubbles:true,cancelable:true});
            Object.defineProperty(event,'touches',{value:y===null?[]:[{screenX:100,screenY:y}]});
            doc.dispatchEvent(event);return event.defaultPrevented;
        };
        const before=h.flow.element.scrollTop;
        send('touchstart',200);assert.equal(send('touchmove',150),true);assert.equal(send('touchend',null),true);
        assert.equal(h.flow.element.scrollTop,before+50);assert.deepEqual(seen,['touchstart']);
        const range=doc.createRange();range.selectNodeContents(doc.querySelector('span'));
        doc.getSelection().addRange(range);
        send('touchstart',200);assert.equal(send('touchmove',100),false);assert.equal(send('touchend',null),false);
        assert.equal(h.flow.element.scrollTop,before+50);
    }finally{h.close()}
});
test('grid traversal keeps original page numbers and region order, including parity overrides',async()=>{
    const h=harness({version:1,all:{preset:'four',order:'column-rtl'},even:{preset:'vertical2'},pages:{}});try{
        await h.flow.open(0,2);h.flow.activate();await h.flow.ensureNeighbors();
        for(let i=0;i<8;i++){h.flow.pan(0,450);await h.flow.ensureNeighbors()}
        for(let i=1;i<h.flow.entries.length;i++){
            const a=h.flow.entries[i-1],b=h.flow.entries[i],target=h.flow.adjacent(a,1);
            assert.deepEqual({page:b.index,panel:b.panel},target);
        }
        assert.ok(h.flow.location.page>0);
    }finally{h.close()}
});
test('zoom and window resize keep the normalized current point; saved point reopens there',async()=>{
    const h=harness();try{
        await h.flow.open(10,0,null,{x:.5,y:.6});h.flow.activate();await h.flow.ensureNeighbors();
        const before=h.flow.location;
        h.flow.resize({...h.flow.view,zoom:3});near(h.flow.location.center.y,before.center.y);
        const e=h.flow.current;assert.ok(e.plan.height>2000);
        h.bounds.width=390;h.bounds.height=844;h.flow.resize();near(h.flow.location.center.y,before.center.y);
    }finally{h.close()}
});
function momentumClock() {
    const host=dom.window,request=host.requestAnimationFrame,cancel=host.cancelAnimationFrame;
    const pending=new Map();let next=0,now=0;
    host.requestAnimationFrame=fn=>{pending.set(++next,fn);return next};
    host.cancelAnimationFrame=id=>pending.delete(id);
    return {pending,step(ms=16){now+=ms;const callbacks=[...pending.values()];pending.clear();callbacks.forEach(fn=>fn(now))},
        close(){host.requestAnimationFrame=request;host.cancelAnimationFrame=cancel}};
}
function touch(doc,type,y,time,count=1) {
    const event=new doc.defaultView.Event(type,{bubbles:true,cancelable:true});
    Object.defineProperties(event,{timeStamp:{value:time},touches:{value:y===null?[]:
        Array.from({length:count},()=>({screenX:100,screenY:y}))}});
    doc.dispatchEvent(event);
}
test('touch release coasts with decaying velocity across PDF pages and saves the final position',async()=>{
    const h=harness(),clock=momentumClock();try{
        await h.flow.open(0,0);h.flow.activate();await h.flow.ensureNeighbors();
        const doc=h.flow.getContents()[0].doc;
        touch(doc,'touchstart',200,0);touch(doc,'touchmove',150,16);touch(doc,'touchend',null,20);
        const released=h.flow.element.scrollTop;
        assert.equal(clock.pending.size,1);
        clock.step();const first=h.flow.element.scrollTop-released;
        clock.step();const second=h.flow.element.scrollTop-released-first;
        assert.ok(first>second&&second>0);
        for(let i=0;i<200&&clock.pending.size;i++){clock.step();await h.flow.ensureNeighbors()}
        assert.equal(clock.pending.size,0,'coasting naturally stops');
        assert.ok(h.flow.element.scrollTop>released+500);
        assert.ok(h.flow.entries.length<=7);
        near(h.flow.savedLocation.center.y,h.flow.location.center.y);
        await new Promise(r=>setTimeout(r,120));
        assert.equal(h.locations.at(-1).reason,'viewport');
    }finally{h.close();clock.close()}
});
test('new touch, wheel, selection, resize, suspension and close stop coasting; disabled motion stays still',async()=>{
    const h=harness(),clock=momentumClock();try{
        await h.flow.open(0,0);h.flow.activate();await h.flow.ensureNeighbors();
        const doc=h.flow.getContents()[0].doc;
        for(const stop of [
            ()=>touch(doc,'touchstart',100,10),
            ()=>h.flow.wheel({deltaX:0,deltaY:0,deltaMode:0,preventDefault(){},stopImmediatePropagation(){}}),
            ()=>h.flow.resize(),()=>h.flow.suspend(),
        ]) {
            h.flow.activate();h.flow.startMomentum(0,1);stop();
            const top=h.flow.element.scrollTop;clock.step();assert.equal(h.flow.element.scrollTop,top);
            assert.equal(clock.pending.size,0);
        }
        h.flow.activate();h.flow.startMomentum(0,1);
        const range=doc.createRange();range.selectNodeContents(doc.querySelector('span'));
        doc.getSelection().addRange(range);const top=h.flow.element.scrollTop;clock.step();
        assert.equal(h.flow.element.scrollTop,top);assert.equal(clock.pending.size,0);
        doc.getSelection().removeAllRanges();
        h.flow.canAnimate=()=>false;h.flow.startMomentum(0,1);assert.equal(clock.pending.size,0);
        h.flow.canAnimate=()=>true;h.flow.startMomentum(0,1);h.flow.canAnimate=()=>false;
        clock.step();assert.equal(clock.pending.size,0);
        h.flow.canAnimate=()=>true;h.flow.startMomentum(0,1);h.close();assert.equal(clock.pending.size,0);
    }finally{h.close();clock.close()}
});
test('paused finger, touch cancellation and finger-count changes do not launch stale momentum',async()=>{
    const h=harness(),clock=momentumClock();try{
        await h.flow.open(0,0);h.flow.activate();await h.flow.ensureNeighbors();
        const doc=h.flow.getContents()[0].doc;
        for(const type of ['touchend','touchcancel']) {
            touch(doc,'touchstart',200,0);touch(doc,'touchmove',150,16);
            touch(doc,type,null,type==='touchend'?200:20);
            assert.equal(clock.pending.size,0);
        }
        touch(doc,'touchstart',200,300,2);touch(doc,'touchmove',150,316,2);
        touch(doc,'touchend',150,320,1);touch(doc,'touchend',null,325);
        assert.equal(clock.pending.size,0);
        h.flow.startMomentum(0,1);clock.step();const top=h.flow.element.scrollTop;
        clock.step(500);assert.equal(h.flow.element.scrollTop,top);assert.equal(clock.pending.size,0);
        let bounded=100;
        Object.defineProperty(h.flow.element,'scrollTop',{configurable:true,get:()=>bounded,set:v=>{bounded=Math.max(0,Math.min(100,v))}});
        h.flow.startMomentum(0,1);clock.step();assert.equal(clock.pending.size,0,'stops at the scroll boundary');
    }finally{h.close();clock.close()}
});
test.after(()=>{children.forEach(child=>child.window.close());dom.window.close()});
