import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

/// OHOS RdbStore rejects VACUUM INTO and wal_checkpoint via the SQL wrapper.
/// The OHOS-only adapter handles this command on the existing sqflite worker,
/// using the live handle's native backup API, not a second database connection.
Future<String> createHarmonyDatabaseSnapshot(
    Database database, Directory cache) async {
  final staging = await cache.createTemp('modu-snapshot-');
  final file = File(p.join(staging.path, 'snapshot.db'));
  try {
    await database.execute('MODU_BACKUP_DATABASE', [file.path]);
    // Never let a missing/partial native result authorize a merge. No header
    // rewriting: the native API must supply a standalone SQLite backup.
    final handle = await file.open();
    try {
      final header = await handle.read(100);
      if (header.length != 100 ||
          String.fromCharCodes(header.take(16)) != 'SQLite format 3\u0000') {
        throw const FormatException('Harmony database snapshot is invalid');
      }
      final bytes = ByteData.sublistView(header);
      final rawSize = bytes.getUint16(16);
      final pageSize = rawSize == 1 ? 65536 : rawSize;
      final pageCount = bytes.getUint32(28);
      if (pageSize < 512 ||
          pageSize > 65536 ||
          (pageSize & (pageSize - 1)) != 0 ||
          pageCount == 0 ||
          await handle.length() != pageSize * pageCount) {
        throw const FormatException('Harmony database snapshot is incomplete');
      }
    } finally {
      await handle.close();
    }
    final wal = File('${file.path}-wal');
    if (await wal.exists() && await wal.length() > 0) {
      throw const FormatException(
          'Harmony database snapshot is not standalone');
    }
    final completed = p.join(cache.path, '${p.basename(staging.path)}.db');
    await file.rename(completed);
    return completed;
  } finally {
    // Only this request's private staging directory; never the live database.
    await staging.delete(recursive: true);
  }
}
