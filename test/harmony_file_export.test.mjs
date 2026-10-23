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

function harness({ uris = ['file://docs/中文.txt'], failure, pickerWait, shareWait } = {}) {
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
    fileUri: { getUriFromPath: path => `file://com.modu.reader${path}` },
    uniformTypeDescriptor: { UniformDataType: { FILE: 'general.file' },
      getUniformDataTypeByFilenameExtension: ext => ext === '.epub' ? 'general.ebook' : 'general.file' },
    systemShare: {
      SharedData: class { constructor(record) { this.record = record; } },
      ShareController: class {
        constructor(data) { this.data = data; }
        async show(context) {
          events.push(['share', this.data.record, context.cacheDir]);
          if (failure === 'share') throw Error('private/path');
          if (shareWait) await shareWait;
        }
      },
    },
  });
  const plugin = new Plugin();
  plugin.onAttachedToEngine({ getBinaryMessenger: () => ({}),
    getApplicationContext: () => ({ cacheDir: '/cache' }) });
  // Native path_provider uses the engine application context, not this cache.
  plugin.onAttachedToAbility({ getAbility: () => ({ context: { cacheDir: '/haps/entry/cache' } }) });
  const invoke = (overrides = {}, method = 'saveFile') => new Promise(resolve => plugin.onMethodCall({
    method,
    args: new Map(Object.entries({
      sourcePath: '/cache/modu-export-123/log.txt', fileName: 'log.txt', ...overrides,
    })),
  }, {
    success: value => resolve({ value }),
    error: (error, message) => resolve({ error, message }),
  }));
  return { events, plugin, invoke };
}

const shareArgs = { sourcePath: '/cache/modu-share-123/中文.epub', fileName: '中文.epub' };
test('OHOS share opens system sheet with a file URI, not a path or file bytes', async () => {
  const h = harness();
  assert.deepEqual(await h.invoke(shareArgs, 'shareFile'), { value: null });
  assert.equal(h.events.length, 1);
  assert.equal(h.events[0][0], 'share');
  assert.equal(h.events[0][1].uri, 'file://com.modu.reader/cache/modu-share-123/中文.epub');
  assert.equal(h.events[0][1].utd, 'general.ebook');
  assert.equal(h.events[0][1].title, '中文.epub');
});

test('share rejects traversal, arbitrary files and detached ability', async () => {
  const h = harness();
  for (const sourcePath of ['/private/book.epub', '/cache/modu-share-../中文.epub',
    '/cache/modu-share-123/../中文.epub', '/cache/modu-share-123/another.epub']) {
    assert.equal((await h.invoke({ ...shareArgs, sourcePath }, 'shareFile')).error, 'invalid_arguments');
  }
  h.plugin.onDetachedFromAbility();
  assert.equal((await h.invoke(shareArgs, 'shareFile')).error, 'unavailable');
  assert.equal(h.events.length, 0);
});

test('share failures are sanitized and release the busy state', async () => {
  const h = harness({ failure: 'share' });
  for (let i = 0; i < 2; i++) {
    const result = await h.invoke(shareArgs, 'shareFile');
    assert.equal(result.error, 'share_failed');
    assert.doesNotMatch(JSON.stringify(result), /private/);
  }
});

test('share waits for the sheet and prevents overlapping native operations', async () => {
  let finish;
  const h = harness({ shareWait: new Promise(resolve => { finish = resolve; }) });
  const first = h.invoke(shareArgs, 'shareFile');
  assert.equal((await h.invoke(shareArgs, 'shareFile')).error, 'unavailable');
  assert.equal((await h.invoke()).error, 'unavailable');
  finish();
  assert.deepEqual(await first, { value: null });
});

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
