import 'package:shared_preferences/shared_preferences.dart';

/// Device-local intent; positions themselves remain in the revisioned database.
class PendingAutoSync {
  PendingAutoSync(this.preferences);
  final SharedPreferences Function() preferences;
  static const requestedKey = 'pendingAutoSyncRequested';
  static const completedKey = 'pendingAutoSyncCompleted';
  Future<void>? _ready;

  int get revision => preferences().getInt(requestedKey) ?? 0;
  bool get pending => revision > (preferences().getInt(completedKey) ?? 0);
  Future<void> get ready => _ready ?? Future.value();

  Future<void> request({Future<void>? savedReading}) {
    final saved = preferences().setInt(requestedKey, revision + 1);
    // Include a previous reader's writes when books are closed in quick succession.
    return _ready = Future.wait<void>([
      if (_ready != null) _ready!,
      saved.then((ok) {
        if (!ok) throw StateError('Could not persist pending sync');
      }),
      if (savedReading != null) savedReading,
    ]).then((_) {});
  }

  Future<void> acknowledge(int syncedRevision) async {
    // An older upload must never acknowledge a newer exit/resume request.
    if (syncedRevision > (preferences().getInt(completedKey) ?? 0)) {
      final ok = await preferences().setInt(completedKey, syncedRevision);
      if (!ok) throw StateError('Could not persist completed sync');
    }
  }
}
