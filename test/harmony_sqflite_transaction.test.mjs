import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source = readFileSync(new URL('../scripts/harmony/sqflite_transaction.ets', import.meta.url), 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import .*;\n/gm, '')
  .replace('export class', 'class')) + '\nModuTransactions;';
function harness() {
  const adapter = vm.runInNewContext(code, {
    relationalStore: { TransactionType: { IMMEDIATE: 1, EXCLUSIVE: 2 } },
  });
  let committed = 0;
  let commitFailure = false;
  let rollbackFailure = false;
  const modes = [];
  const db = {
    querySql: async () => committed,
    async createTransaction(options) {
      modes.push(options.transactionType);
      let pending = committed;
      return {
        execute: async value => { pending = value; },
        querySql: async () => pending,
        async commit() {
          if (commitFailure) throw Error('commit failed');
          committed = pending;
        },
        async rollback() { if (rollbackFailure) throw Error('rollback failed'); },
      };
    },
  };
  return { adapter, db, modes, failCommit: () => { commitFailure = true; },
    failRollback: () => { rollbackFailure = true; } };
}

test('read-after-write sees new revision before commit (stale store reproducer)', async () => {
  const { adapter, db, modes } = harness();
  await adapter.begin(db, false);
  await adapter.connection(db).execute(1);
  assert.equal(await db.querySql(), 0);
  assert.equal(await adapter.connection(db).querySql(), 1);
  await adapter.commit(db);
  assert.equal(adapter.connection(db), db);
  assert.equal(await db.querySql(), 1);
  assert.deepEqual(modes, [1]);
});

test('rollback discards writes and exclusive begin is not a no-op', async () => {
  const { adapter, db, modes } = harness();
  await adapter.begin(db, true);
  await adapter.connection(db).execute(2);
  await adapter.rollback(db);
  assert.equal(await adapter.connection(db).querySql(), 0);
  assert.deepEqual(modes, [2]);
  await adapter.rollback(db);
});

test('stores stay isolated and nested begin cannot replace active transaction', async () => {
  const { adapter, db } = harness();
  const second = harness().db;
  await adapter.begin(db, false);
  await adapter.begin(second, false);
  await adapter.connection(db).execute(3);
  await assert.rejects(adapter.begin(db, false), /Nested/);
  assert.equal(await adapter.connection(second).querySql(), 0);
  await adapter.commit(db);
  assert.notEqual(adapter.connection(second), second);
  await adapter.rollback(second);
});

test('commit and rollback failures propagate without silently losing transaction', async () => {
  const h = harness();
  await assert.rejects(h.adapter.commit(h.db), /No active/);
  await h.adapter.begin(h.db, false);
  const active = h.adapter.connection(h.db);
  h.failCommit();
  await assert.rejects(h.adapter.commit(h.db), /commit failed/);
  assert.equal(h.adapter.connection(h.db), active);
  h.failRollback();
  await assert.rejects(h.adapter.rollback(h.db), /rollback failed/);
  assert.equal(h.adapter.connection(h.db), active);
});
