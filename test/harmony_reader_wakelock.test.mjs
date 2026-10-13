import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = new URL('../', import.meta.url);
const source = readFileSync(new URL(
  'ohos/entry/src/main/ets/plugins/ReaderWakelockPlugin.ets', root), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import [\s\S]*?;\n/gm, '')
  .replace('export default class', 'class')) + '\nReaderWakelockPlugin;';

function harness({ fail, wait, setWait } = {}) {
  const values = [];
  const target = { async setWindowKeepScreenOn(enabled) {
    values.push(enabled);
    if (enabled && setWait) await setWait;
    if (fail === 'set') throw Error('private data');
  } };
  const Plugin = vm.runInNewContext(code, {
    MethodChannel: class { setMethodCallHandler() {} },
    window: { async getLastWindow() {
      if (wait) await wait;
      if (fail === 'window') throw Error('private data');
      return target;
    } },
  });
  const plugin = new Plugin();
  plugin.onAttachedToEngine({ getBinaryMessenger: () => ({}) });
  plugin.onAttachedToAbility({ getAbility: () => ({ context: {} }) });
  const invoke = (enabled, method = 'toggle') => new Promise(resolve =>
    plugin.onMethodCall({ method, args: new Map([['enabled', enabled]]) }, {
      success: () => resolve('ok'),
      error: (code, message) => resolve({ code, message }),
      notImplemented: () => resolve('notImplemented'),
    }));
  return { plugin, invoke, values };
}

test('registered native bridge enables and releases the current reader window', async () => {
  const entry = readFileSync(new URL(
    'ohos/entry/src/main/ets/entryability/EntryAbility.ets', root), 'utf8');
  assert.match(entry, /getPlugins\(\)\?\.add\(new ReaderWakelockPlugin\(\)\)/);
  const h = harness();
  assert.equal(await h.invoke(true), 'ok');
  assert.equal(await h.invoke(false), 'ok');
  assert.deepEqual(h.values, [true, false]);
});

test('detach releases held window and rejects further requests', async () => {
  const h = harness();
  await h.invoke(true);
  h.plugin.onDetachedFromEngine({});
  assert.deepEqual(h.values, [true, false]);
  assert.equal((await h.invoke(true)).code, 'unavailable');
});

test('detach while finding a window cannot enable a stale window', async () => {
  let finish;
  const h = harness({ wait: new Promise(resolve => { finish = resolve; }) });
  const pending = h.invoke(true);
  h.plugin.onDetachedFromAbility();
  finish();
  assert.equal((await pending).code, 'unavailable');
  assert.deepEqual(h.values, []);
});

test('detach during native enable releases again after its completion', async () => {
  let finish;
  const h = harness({ setWait: new Promise(resolve => { finish = resolve; }) });
  const pending = h.invoke(true);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(h.values, [true]);
  h.plugin.onDetachedFromAbility();
  finish();
  assert.equal((await pending).code, 'unavailable');
  assert.deepEqual(h.values, [true, false, false]);
});

test('rejects invalid arguments and unknown methods', async () => {
  const h = harness();
  for (const value of [null, undefined, 1, 'true']) {
    assert.equal((await h.invoke(value)).code, 'invalid_arguments');
  }
  assert.equal(await h.invoke(true, 'other'), 'notImplemented');
  assert.deepEqual(h.values, []);
});

for (const fail of ['window', 'set']) {
  test(`${fail} failure returns sanitized error`, async () => {
    const h = harness({ fail });
    const result = await h.invoke(true);
    assert.equal(result.code, 'wakelock_failed');
    assert.doesNotMatch(result.message, /private data/);
    h.plugin.onDetachedFromAbility();
  });
}
