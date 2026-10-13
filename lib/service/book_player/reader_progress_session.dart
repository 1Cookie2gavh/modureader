import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/models/reading_position_snapshot.dart';
import 'package:anx_reader/models/narration_position.dart';

/// Serializes real reading actions and database refreshes for one open reader.
/// Lifecycle saves merely drain work; they never invent a new reading action.
class ReaderProgressSession {
  ReaderProgressSession(this.dao, this.bookId);
  final BookDao dao;
  final int bookId;
  ReadingPositionSnapshot? current;
  ReadingPositionSnapshot? _positionBeforeConflict;
  int generation = 0;
  Future<void> _pending = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<ReadingPositionSnapshot> refresh(
          {bool Function()? preservePosition}) =>
      _serial(() async {
        final next = await dao.readReadingPosition(bookId);
        if (current?.revision != next.revision) generation++;
        final live = _positionBeforeConflict ?? current;
        _positionBeforeConflict = null;
        // Keep an active speech cursor, but accept the revision for its next
        // real progress write. Refresh itself must never publish a local edit.
        if (preservePosition?.call() == true && live != null && !next.deleted) {
          return current = ReadingPositionSnapshot(
              live.position, live.percentage, next.revision,
              narration: live.narration);
        }
        return current = next;
      });

  Future<bool> record(String position, double percentage,
          {required int generation, NarrationPosition? narration}) =>
      _serial(() async {
        if (current == null || generation != this.generation) return false;
        final next = await dao.updateReadingPosition(
            bookId, position, percentage,
            expectedRevision: current!.revision, narration: narration);
        if (next == null) {
          _positionBeforeConflict ??= current;
          current = await dao.readReadingPosition(bookId);
          this.generation++;
          return false;
        }
        current = next;
        _positionBeforeConflict = null;
        return true;
      });

  Future<void> flush() => _pending;

  Future<bool> recordNarration(NarrationPosition narration,
          {required int generation}) =>
      _serial(() async {
        final latest = current;
        if (latest == null || generation != this.generation) return false;
        final next = await dao.updateReadingPosition(
            bookId, latest.position, latest.percentage,
            expectedRevision: latest.revision, narration: narration);
        if (next == null) {
          _positionBeforeConflict ??= current;
          current = await dao.readReadingPosition(bookId);
          this.generation++;
          return false;
        }
        current = next;
        _positionBeforeConflict = null;
        return true;
      });
}
