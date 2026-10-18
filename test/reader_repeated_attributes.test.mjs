import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../assets/foliate-js/src/paginator.js', import.meta.url), 'utf8');
const method = source.slice(source.indexOf('  #updatingAttributes ='), source.indexOf('  open(book)'));
const Renderer = runInNewContext(`class Renderer {
  #background = true;
  writes = 0; renders = 0; paints = 0;
  style = {setProperty: () => this.writes++};
  #top = {style: this.style};
  attributes = new Map(); layouts = [];
  setAttribute(name, value) {
    const previous = this.attributes.get(name) ?? null;
    this.attributes.set(name, String(value));
    this.attributeChangedCallback(name, previous, String(value));
  }
  removeAttribute(name) {this.attributes.delete(name)}
  render() {this.renders++; this.layouts.push(Object.fromEntries(this.attributes))}
  #applyBackground() {this.paints++}
  ${method}
}; Renderer`);

test('replaying unchanged settings does not repeatedly paginate a chapter', () => {
  const renderer = new Renderer();
  for (const name of ['flow', 'top-margin', 'bottom-margin', 'gap',
    'max-column-count', 'column-threshold', 'max-inline-size', 'background-color', 'bgimg-url']) {
    renderer.attributeChangedCallback(name, '20', '20');
  }
  assert.equal(renderer.renders, 0);
  assert.equal(renderer.writes, 0);
  assert.equal(renderer.paints, 0);
  renderer.attributeChangedCallback('flow', 'paginated', 'scrolled');
  renderer.attributeChangedCallback('bottom-margin', '20', '30');
  assert.equal(renderer.renders, 2, 'real layout changes still repaginate');
  renderer.attributeChangedCallback('bgimg-url', 'old', 'new');
  assert.equal(renderer.paints, 1);
});

test('a settings batch renders once with the final flow, margins and scroll policy', () => {
  const renderer = new Renderer();
  const attributes = {flow:'scrolled', 'continuous-scroll':'false',
    'top-margin':'10px', 'bottom-margin':'20px', gap:'5%',
    'max-column-count':2, 'column-threshold':'600px', animated:null};
  renderer.setLayoutAttributes(attributes);
  assert.equal(renderer.renders, 1);
  assert.equal(renderer.layouts[0]['continuous-scroll'], 'false');
  assert.equal(renderer.layouts[0]['bottom-margin'], '20px');
  assert.equal(renderer.layouts[0]['column-threshold'], '600px');
  renderer.setLayoutAttributes(attributes);
  assert.equal(renderer.renders, 1, 'unchanged batches do not paginate');
  renderer.setAttribute('gap', '8%');
  assert.equal(renderer.renders, 2, 'standalone changes still render synchronously');
});

test('a failed attribute update releases the batch for subsequent changes', () => {
  const renderer = new Renderer();
  const attributes = {flow:'scrolled'};
  Object.defineProperty(attributes, 'gap', {enumerable:true, get() {throw Error('invalid')}});
  assert.throws(() => renderer.setLayoutAttributes(attributes), /invalid/);
  renderer.setAttribute('gap', '8%');
  assert.equal(renderer.renders, 1);
});
