import relationalStore from '@ohos.data.relationalStore';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';
import { Operation } from './operation/Operation';
import { DatabaseHelper } from './DatabaseHelper';
import { Constant } from './Constant';

// Runs inside SqfliteWorker's FIFO and Dart's database lock. Do not open/close
// a second handle or bypass the pre-merge backup on native errors.
export async function backupModuSnapshot(operation: Operation,
  db: relationalStore.RdbStore): Promise<void> {
  try {
    const args: Object[] = operation.getSqlCommand().getRawSqlArguments();
    const destination: Object = args[0];
    if (args.length !== 1 || typeof destination !== 'string' ||
      !/^\/data\/storage\/el[12]\/base\/cache\/modu-snapshot-[A-Za-z0-9_-]+\/snapshot\.db$/.test(destination)) {
      operation.error(Constant.SQLITE_ERROR, 'Invalid Harmony snapshot destination', null);
      return;
    }
    const id: number = operation.getArgument<number>(Constant.PARAM_ID);
    const name: string | undefined = DatabaseHelper.dbIdMap.get(id);
    if (name !== 'app_database.db' || DatabaseHelper.isDatabaseInTransaction(name)) {
      operation.error(Constant.SQLITE_ERROR, 'Harmony snapshot requires an idle library handle', null);
      return;
    }
    if (await fs.access(destination)) {
      operation.error(Constant.SQLITE_ERROR, 'Harmony snapshot destination already exists', null);
      return;
    }
    // RdbStore.backup includes committed WAL changes and supports absolute paths.
    await db.backup(destination);
    operation.success(null);
  } catch (error) {
    const code: number = (error as BusinessError).code;
    // Do not echo SQL arguments, account names, paths or native messages.
    operation.error(Constant.SQLITE_ERROR,
      `Harmony snapshot failed; code=${typeof code === 'number' ? code : 0}`, null);
  }
}
