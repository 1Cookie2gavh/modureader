import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anx_reader/models/narration_position.dart';
import 'package:anx_reader/service/book_player/reader_progress_session.dart';
import 'package:anx_reader/service/sync/row_sync_engine.dart';
import 'package:anx_reader/service/sync/row_sync_record.dart';
import 'package:anx_reader/service/sync/row_sync_store.dart';
import 'row_sync_test.dart' show fixture, bookRow, MemorySyncClient;
import 'suspended_reader_sync_diagnostic_test.dart' show IsolatedBookDao;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  const first = 'epubcfi(/6/2!/4/2, /1:0,/1:10)';
  const second = 'epubcfi(/6/4!/4/2,/1:0,/1:12)';

  for (final conflict in [false, true]) {
    test(
        'sync keeps live speech without publishing stale data, conflict=$conflict',
        () async {
      final db = await fixture();
      addTearDown(db.close);
      final dao = IsolatedBookDao(db);
      final session = ReaderProgressSession(dao, 1);
      await session.refresh();
      await session.record(first, .4,
          generation: session.generation,
          narration: const NarrationPosition(first, 'playing'));
      await dao.updateReadingPosition(1, second, .8,
          narration: const NarrationPosition(second, 'paused'));
      final remote = await dao.readReadingPosition(1);
      if (conflict) {
        expect(
            await session.recordNarration(
                const NarrationPosition(first, 'paused'),
                generation: session.generation),
            false);
      }
      final live = await session.refresh(preservePosition: () => true);
      expect(live.position, first);
      expect(live.percentage, .4);
      expect(live.narration?.state, 'playing');
      expect(live.revision, remote.revision);
      await session.flush();
      final unchanged = await dao.readReadingPosition(1);
      expect(unchanged.position, second);
      expect(unchanged.revision, remote.revision);
      // Only a genuine subsequent media action publishes the local cursor.
      expect(
          await session.recordNarration(
              const NarrationPosition(first, 'paused'),
              generation: session.generation),
          true);
      final saved = await dao.readReadingPosition(1);
      expect(saved.position, first);
      expect(saved.percentage, .4);
      expect(saved.narration?.cfi, first);
      expect(saved.narration?.state, 'paused');
    });
  }

  test(
      'speech protection is checked after reading the database and never revives a deleted book',
      () async {
    final db = await fixture();
    addTearDown(db.close);
    final dao = IsolatedBookDao(db),
        session = ReaderProgressSession(IsolatedBookDao(db), 1);
    await session.refresh();
    await session.record(first, .4,
        generation: session.generation,
        narration: const NarrationPosition(first, 'playing'));
    await dao.updateReadingPosition(1, second, .8,
        narration: const NarrationPosition(second, 'paused'));
    var playing = false;
    final refresh = session.refresh(preservePosition: () => playing);
    playing = true;
    expect((await refresh).position, first);
    // A newly opened/idle reader still imports the remote cursor normally.
    expect((await session.refresh()).position, second);
    await db.update('tb_books', {'is_deleted': 1},
        where: 'id=?', whereArgs: [1]);
    expect((await session.refresh(preservePosition: () => true)).deleted, true);
    expect(
        await session.record(first, .4, generation: session.generation), false);
  });

  test(
      'optional speech envelope validates without changing legacy position payload',
      () {
    const r = RowSyncRecord('position', 'md5:book', 20, 'rev', false,
        {'last_read_position': first, 'reading_percentage': .4},
        narration: NarrationPosition(first, 'playing'));
    RowSyncStore.validate(r);
    final roundTrip = RowSyncRecord.fromMap(r.toMap());
    expect(roundTrip.narration?.cfi, first);
    expect(roundTrip.narration?.canResume, true);
    final legacy = RowSyncRecord.fromMap({...r.toMap()}..remove('narration'));
    expect(legacy.data, r.data);
    RowSyncStore.validate(legacy);
    for (final records in [
      [r, legacy],
      [legacy, r]
    ]) {
      expect(mergeSyncRecords([records[0]], [records[1]]).single.narration?.cfi,
          first);
    }
    final newerLegacy =
        RowSyncRecord(legacy.kind, legacy.id, 21, 'newer', false, legacy.data);
    expect(mergeSyncRecords([r], [newerLegacy]).single.narration, isNull);
    for (final invalid in [
      '',
      '{}',
      '{"cfi":"x","state":"playing"}',
      '{"cfi":"epubcfi(x)","state":"unknown"}'
    ]) {
      expect(() => NarrationPosition.decode(invalid), throwsFormatException);
    }
  });

  test('pause queued behind a speech cursor cannot roll reading progress back',
      () async {
    final db = await fixture();
    addTearDown(db.close);
    final session = ReaderProgressSession(IsolatedBookDao(db), 1);
    await session.refresh();
    final moving = session.record(second, .8,
        generation: session.generation,
        narration: const NarrationPosition(second, 'playing'));
    final pausing = session.recordNarration(
        const NarrationPosition(second, 'paused'),
        generation: session.generation);
    expect(await moving, true);
    expect(await pausing, true);
    final latest = await session.refresh();
    expect(latest.position, second);
    expect(latest.percentage, .8);
    expect(latest.narration?.state, 'paused');
    final revision = latest.revision;
    await session.recordNarration(const NarrationPosition(second, 'paused'),
        generation: session.generation);
    expect((await session.refresh()).revision, revision);
  });

  for (final etag in [true, false]) {
    test('speech cursor/state sync across book IDs, etag=$etag', () async {
      final a = await fixture();
      final b = await fixture(bookId: 91);
      final dir = await Directory.systemTemp.createTemp('modu-narration-test-');
      addTearDown(() async {
        await a.close();
        await b.close();
        await dir.delete(recursive: true);
      });
      await a.insert('tb_books', bookRow(2, md5: 'another-book'));
      final client = MemorySyncClient()..atomic = etag;
      final syncA = RowSyncEngine(
          store: RowSyncStore(a),
          client: client,
          cache: await Directory('${dir.path}/a').create());
      final syncB = RowSyncEngine(
          store: RowSyncStore(b),
          client: client,
          cache: await Directory('${dir.path}/b').create());
      final session = ReaderProgressSession(IsolatedBookDao(a), 1);
      await session.refresh();
      await session.record(first, .4,
          generation: session.generation,
          narration: const NarrationPosition(first, 'playing'));
      await syncA.synchronize();
      await syncB.synchronize();
      final receiver = IsolatedBookDao(b);
      final restored = await receiver.readReadingPosition(91);
      expect(restored.position, first);
      expect(restored.narration?.state, 'playing');
      expect(restored.narration?.canResume, true);
      expect(
          (await IsolatedBookDao(a).readReadingPosition(2)).narration, isNull);
      await receiver.updateReadingPosition(91, second, .8,
          expectedRevision: restored.revision,
          narration: const NarrationPosition(second, 'paused'));
      await syncB.synchronize();
      await syncA.synchronize();
      // Stale open reader cannot overwrite the newly received speech cursor.
      expect(
          await session.recordNarration(
              const NarrationPosition(first, 'paused'),
              generation: session.generation),
          false);
      final back = await session.refresh();
      expect(back.narration?.cfi, second);
      expect(back.narration?.state, 'paused');
    });
  }

  test('v8 narration migration preserves metadata and is idempotent', () async {
    final db = await fixture();
    addTearDown(db.close);
    final before = await RowSyncStore(db).snapshot();
    await db.execute('ALTER TABLE $syncRecordsTable DROP COLUMN narration');
    await RowSyncStore.installNarration(db);
    await RowSyncStore.installNarration(db);
    expect(sameSyncRecords(before, await RowSyncStore(db).snapshot()), true);
  });
}
