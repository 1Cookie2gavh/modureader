import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = new URL('../', import.meta.url);
const source = readFileSync(new URL(
  'ohos/entry/src/main/ets/plugins/ReaderCutoutPlugin.ets', root), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import [\s\S]*?;\n/gm, '')
  .replace('export default class', 'class')) + '\nReaderCutoutPlugin;';
const empty = { left: 0, top: 0, width: 0, height: 0 };

function harness({ area = {}, fail = false, wait } = {}) {
  const types = [];
  const Plugin = vm.runInNewContext(code, {
    MethodChannel: class { setMethodCallHandler() {} },
    window: {
      AvoidAreaType: { TYPE_CUTOUT: 1, TYPE_SYSTEM: 0 },
      async getLastWindow() {
        if (wait) await wait;
        if (fail) throw Error('private detail');
        return {
          getWindowAvoidArea(type) {
            types.push(type);
            return { leftRect: empty, topRect: empty, rightRect: empty,
              bottomRect: empty, ...area };
          },
          getWindowProperties: () => ({ windowRect: { width: 1200, height: 2400 } }),
        };
      },
    },
  });
  const plugin = new Plugin();
  plugin.onAttachedToEngine({ getBinaryMessenger: () => ({}) });
  plugin.onAttachedToAbility({ getAbility: () => ({ context: {} }) });
  const invoke = (method = 'getInsets') => new Promise(resolve =>
    plugin.onMethodCall({ method }, {
      success: v => resolve(Array.from(v)),
      error: (code, message) => resolve({ code, message }),
      notImplemented: () => resolve('notImplemented'),
    }));
  return { plugin, invoke, types };
}

test('registered Harmony bridge reads hardware cutout including offset below edge', async () => {
  const entry = readFileSync(new URL('ohos/entry/src/main/ets/entryability/EntryAbility.ets', root), 'utf8');
  assert.match(entry, /getPlugins\(\)\?\.add\(new ReaderCutoutPlugin\(\)\)/);
  const h = harness({ area: { topRect: { left: 450, top: 20, width: 300, height: 100 } } });
  assert.deepEqual(await h.invoke(), [0, 120, 0, 0]);
  assert.deepEqual(h.types, [1]);
});

test('landscape side cutouts and no-cutout windows return physical insets', async () => {
  assert.deepEqual(await harness().invoke(), [0, 0, 0, 0]);
  const h = harness({ area: {
    leftRect: { left: 10, top: 500, width: 90, height: 100 },
    rightRect: { left: 1090, top: 500, width: 90, height: 100 },
  } });
  assert.deepEqual(await h.invoke(), [100, 0, 110, 0]);
});

test('detaching during lookup discards stale window', async () => {
  let finish;
  const h = harness({ wait: new Promise(resolve => { finish = resolve; }) });
  const result = h.invoke();
  h.plugin.onDetachedFromEngine({});
  finish();
  assert.equal((await result).code, 'unavailable');
  assert.deepEqual(h.types, []);
});

test('errors are sanitized and unknown methods do not access window', async () => {
  const h = harness({ fail: true });
  assert.equal(await h.invoke('other'), 'notImplemented');
  assert.deepEqual(await h.invoke(), {
    code: 'cutout_unavailable', message: 'Could not read reader cutout area',
  });
});
