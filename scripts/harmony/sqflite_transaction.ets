import relationalStore from '@ohos.data.relationalStore';

// RdbStore.querySql can read a different connection from beginTransaction's
// writer. Route every statement through the explicit transaction instead.
export class ModuTransactions {
  private static active: WeakMap<relationalStore.RdbStore, relationalStore.Transaction> = new WeakMap();

  static connection(db: relationalStore.RdbStore): relationalStore.RdbStore | relationalStore.Transaction {
    return ModuTransactions.active.get(db) ?? db;
  }

  static async begin(db: relationalStore.RdbStore, exclusive: boolean): Promise<void> {
    if (ModuTransactions.active.has(db)) {
      throw new Error('Nested Harmony database transaction');
    }
    const transaction = await db.createTransaction({
      transactionType: exclusive ? relationalStore.TransactionType.EXCLUSIVE : relationalStore.TransactionType.IMMEDIATE
    });
    ModuTransactions.active.set(db, transaction);
  }

  static async commit(db: relationalStore.RdbStore): Promise<void> {
    const transaction = ModuTransactions.active.get(db);
    if (transaction === undefined) {
      throw new Error('No active Harmony database transaction');
    }
    await transaction.commit();
    ModuTransactions.active.delete(db);
  }

  static async rollback(db: relationalStore.RdbStore): Promise<void> {
    const transaction = ModuTransactions.active.get(db);
    if (transaction !== undefined) {
      await transaction.rollback();
      ModuTransactions.active.delete(db);
    }
  }
}
