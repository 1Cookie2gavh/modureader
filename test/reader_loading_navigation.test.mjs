import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';

const source = await readFile(new URL('../assets/foliate-js/src/paginator.js', import.meta.url), 'utf8');
const methods = source.slice(source.indexOf('  async goTo(target)'), source.indexOf('  #scrollPrev(distance)'));
const Harness = runInNewContext(`class Harness {
  #locked = false; #destroyed = false; #navigationVersion = 0;
  #navigationWaiters = new Set(); #pendingViews = new Set(); #lastNavigation;
  visits = []; active = 0; peak = 0; blocked = true; broken = false; current = 0;
  get locked() {return this.#locked}
  #canGoToIndex(index) {return Number.isInteger(index) && index >= 0 && index < 10}
  async #goTo({index}) {
    this.#lastNavigation = {index}; this.visits.push(index);
    this.active++; this.peak = Math.max(this.peak, this.active);
    let view;
    try {
      if (index === 1 && this.blocked) await new Promise((resolve, reject) => {
        this.release = resolve;
        view = {cancelLoad: () => reject(Object.assign(Error('cancelled'), {name:'AbortError'}))};
        this.#pendingViews.add(view);
      });
      if (this.broken) throw Error('Reader font loading failed');
      this.current = index;
    } finally {this.active--; this.#pendingViews.delete(view)}
  }
  ${methods}
}; Harness`);
const tick = () => new Promise(r => setImmediate(r));

test('TOC replaces a font wait after rollback; a late font cannot restore old chapter', async () => {
  const r = new Harness();
  const old = r.goTo({index:1}); await tick();
  const next = r.goTo({index:2});
  assert.equal(await old, false);
  assert.equal(await next, true);
  r.release(); await tick();
  assert.equal(r.current, 2);
  assert.equal(r.peak, 1, 'never race two foreground commits');
  assert.equal(r.locked, false);
});

test('rapid directory clicks only commit the newest requested chapter', async () => {
  const r = new Harness();
  const old = r.goTo({index:1}); await tick();
  const middle = r.goTo({index:2});
  const latest = r.goTo({index:3});
  assert.deepEqual(await Promise.all([old,middle,latest]), [false,false,true]);
  assert.deepEqual(Array.from(r.visits), [1,3]);
  assert.equal(r.current,3);
});

test('real font errors unlock navigation and retry the same chapter', async () => {
  const r = new Harness(); r.blocked = false; r.broken = true;
  await assert.rejects(r.goTo({index:1}), /font loading failed/);
  assert.equal(r.current,0);
  assert.equal(r.locked,false);
  r.broken = false;
  assert.equal(await r.retryNavigation(),true);
  assert.equal(r.current,1);
});

test('chapter failures report the target and safe reason; cancellation is not logged as failure', async () => {
  const start = source.indexOf('  async #goTo({ index, anchor, select })');
  const end = source.indexOf('  async #loadSection(', start);
  const warnings = [];
  const Reporter = runInNewContext(`class Reporter {
    #lastNavigation; events = []; error;
    dispatchEvent(event) {this.events.push(event.detail)}
    async #loadSection() {if (this.error) throw this.error}
    goTo(target) {return this.#goTo(target)}
    ${source.slice(start, end)}
  }; Reporter`, {
    console: {warn: message => warnings.push(message)},
    CustomEvent: class {constructor(type, {detail}) {this.detail = detail}},
  });
  for (const [error, reason, state] of [
    [Object.assign(Error('resource detail'), {name:'ReaderChapterDocumentError'}), 'document', 'failed'],
    [Error('Reader font loading failed'), 'font', 'failed'],
    [Error('resource detail'), 'chapter', 'failed'],
    [Object.assign(Error('cancelled'), {name:'AbortError'}), 'chapter', 'cancelled'],
  ]) {
    const r = new Reporter(); r.error = error;
    const count = warnings.length;
    await assert.rejects(r.goTo({index:3}), e => e === error);
    assert.equal(r.events[0].state, 'loading');
    assert.equal(r.events[1].state, state);
    assert.ok(Number.isInteger(r.events[1].durationMs) && r.events[1].durationMs >= 0);
    assert.equal(r.events[1].index, 3); assert.equal(r.events[1].reason, reason);
    if (state === 'cancelled') assert.equal(warnings.length, count);
    else assert.equal(warnings.at(-1), `Reader chapter load failed: index=3, reason=${reason}`);
    r.error = null; await r.goTo({index:3});
    assert.equal(r.events.at(-1).state, 'ready');
    assert.ok(Number.isInteger(r.events.at(-1).durationMs) && r.events.at(-1).durationMs >= 0);
  }
});
