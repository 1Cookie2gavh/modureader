import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source = readFileSync(new URL('../scripts/harmony/sqflite_snapshot.ets', import.meta.url), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import .*;\n/gm, '')
  .replace('export async function', 'async function')) + '\nbackupModuSnapshot;';
const destination = '/data/storage/el2/base/cache/modu-snapshot-ABC123/snapshot.db';

function harness({ name = 'app_database.db', transaction = false, exists = false, fail, wait } = {}) {
  const calls = [];
  const backup = vm.runInNewContext(code, {
    DatabaseHelper: { dbIdMap: new Map([[7, name]]), isDatabaseInTransaction: () => transaction },
    Constant: { SQLITE_ERROR: 'sqlite_error', PARAM_ID: 'id' },
    fs: { access: async () => exists },
  });
  return { calls, async invoke(args = [destination]) {
    let result;
    await backup({
      getSqlCommand: () => ({ getRawSqlArguments: () => args }),
      getArgument: () => 7,
      success: () => { result = 'success'; },
      error: (code, message) => { result = { code, message }; },
    }, { async backup(path) {
      calls.push(path);
      if (wait) await wait;
      if (fail) throw { code: 14800029, message: 'PRIVATE_KEY /private/path' };
    } });
    return result;
  } };
}

test('backs up existing handle and waits for completion before success', async () => {
  let finish;
  const h = harness({ wait: new Promise(resolve => { finish = resolve; }) });
  let done = false;
  const pending = h.invoke().then(value => { done = true; return value; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(done, false);
  finish();
  assert.equal(await pending, 'success');
  assert.deepEqual(h.calls, [destination]);
  assert.doesNotMatch(source, /\.close\(|getRdbStore|VACUUM|wal_checkpoint|copyFile/);
});

test('native failure is not swallowed or exposed verbatim', async () => {
  const result = await harness({ fail: true }).invoke();
  assert.equal(result.code, 'sqlite_error');
  assert.match(result.message, /code=14800029/);
  assert.doesNotMatch(result.message, /PRIVATE|private/);
});

for (const options of [{ transaction: true }, { name: 'other.db' }, { name: null }, { exists: true }]) {
  test(`rejects unavailable/transactional handle or existing file ${JSON.stringify(options)}`, async () => {
    const h = harness(options);
    assert.equal((await h.invoke()).code, 'sqlite_error');
    assert.deepEqual(h.calls, []);
  });
}

test('rejects paths outside request-owned cache directory', async () => {
  for (const args of [[], [null], [1], [destination, destination],
    ['/data/storage/el2/database/rdb/app_database.db'],
    ['/data/storage/el2/base/cache/modu-snapshot-a/../snapshot.db'],
    ['/tmp/snapshot.db'], [destination + '\0']]) {
    const h = harness();
    assert.equal((await h.invoke(args)).code, 'sqlite_error');
    assert.deepEqual(h.calls, []);
  }
});
