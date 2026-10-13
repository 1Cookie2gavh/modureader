import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

// Execute the actual native handler with mocked OHOS APIs, not a Dart replica.
const root = new URL('../', import.meta.url);
const source = readFileSync(new URL(
  'ohos/entry/src/main/ets/plugins/FileExportPlugin.ets', root), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import [\s\S]*?;\n/gm, '')
  .replace('export default class', 'class')) + '\nFileExportPlugin;';

function harness({ uris = ['file://docs/中文.txt'], failure, pickerWait } = {}) {
  const events = [];
  let count = 0;
  const fs = {
    OpenMode: { READ_ONLY: 0, READ_WRITE: 2 },
    async open(path) {
      events.push(['open', path]);
      if (failure === 'open' && ++count === 2) throw Error('private/path');
      return { fd: path };
    },
    async copyFile(from, to) {
      events.push(['copy', from, to]);
      if (failure === 'copy') throw Error('private/log/contents');
    },
    async close(file) { events.push(['close', file.fd]); },
  };
  const picker = {
    DocumentSaveOptions: class {},
    DocumentViewPicker: class {
      async save(options) {
        events.push(['picker', options.newFileNames]);
        if (failure === 'picker') throw Error('private/path');
        if (pickerWait) await pickerWait;
        return uris;
      }
    },
  };
  const Plugin = vm.runInNewContext(code, { fs, picker,
    MethodChannel: class { setMethodCallHandler() {} },
  });
  const plugin = new Plugin();
  plugin.onAttachedToEngine({ getBinaryMessenger: () => ({}),
    getApplicationContext: () => ({ cacheDir: '/cache' }) });
  // Native path_provider uses the engine application context, not this cache.
  plugin.onAttachedToAbility({ getAbility: () => ({ context: { cacheDir: '/haps/entry/cache' } }) });
  const invoke = (overrides = {}) => new Promise(resolve => plugin.onMethodCall({
    method: 'saveFile',
    args: new Map(Object.entries({
      sourcePath: '/cache/modu-export-123/log.txt', fileName: 'log.txt', ...overrides,
    })),
  }, {
    success: value => resolve({ value }),
    error: (error, message) => resolve({ error, message }),
  }));
  return { events, plugin, invoke };
}

test('native export registered independently of generated plugins', () => {
  const entry = readFileSync(new URL(
    'ohos/entry/src/main/ets/entryability/EntryAbility.ets', root), 'utf8');
  assert.match(entry, /getPlugins\(\)\?\.add\(new FileExportPlugin\(\)\)/);
});

test('success returns unmodified URI only after copy and both closes', async () => {
  const h = harness();
  assert.deepEqual(await h.invoke(), { value: 'file://docs/中文.txt' });
  assert.deepEqual(h.events.map(e => e[0]), ['picker', 'open', 'open', 'copy', 'close', 'close']);
});

test('rejects ability cache and detached engine rather than widening file access', async () => {
  const h = harness();
  assert.equal((await h.invoke({ sourcePath: '/haps/entry/cache/modu-export-123/log.txt' })).error,
    'invalid_arguments');
  h.plugin.onDetachedFromEngine({});
  assert.equal((await h.invoke()).error, 'unavailable');
  assert.equal(h.events.length, 0);
});

test('cancel neither opens files nor reports success with a path', async () => {
  const h = harness({ uris: [] });
  assert.deepEqual(await h.invoke(), { value: null });
  assert.deepEqual(h.events.map(e => e[0]), ['picker']);
});

for (const failure of ['picker', 'open', 'copy']) {
  test(`${failure} error closes opened handles, is sanitized, permits retry`, async () => {
    const h = harness({ failure });
    const result = await h.invoke();
    assert.equal(result.error, 'export_failed');
    assert.doesNotMatch(JSON.stringify(result), /private/);
    assert.equal(h.events.filter(e => e[0] === 'close').length,
      failure === 'picker' ? 0 : failure === 'open' ? 1 : 2);
    assert.notEqual((await h.invoke()).error, 'unavailable');
  });
}

test('rejects unsafe input, detached ability and overlapping export', async () => {
  let finish;
  const h = harness({ pickerWait: new Promise(resolve => { finish = resolve; }) });
  for (const args of [
    { sourcePath: '/data/private/log.txt' }, { fileName: '../log.txt' },
    { sourcePath: '/cache/modu-export-x/../private' },
  ]) assert.equal((await h.invoke(args)).error, 'invalid_arguments');
  assert.equal(h.events.length, 0);
  const first = h.invoke();
  assert.equal((await h.invoke()).error, 'unavailable');
  finish();
  assert.ok((await first).value);
  h.plugin.onDetachedFromAbility();
  assert.equal((await h.invoke()).error, 'unavailable');
});
