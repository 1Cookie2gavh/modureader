import 'dart:convert';
import 'dart:io';

/// Current-process diagnostics only. No free-form messages or persisted history.
enum RuntimeEvent {
  sessionStart,
  lifecycle,
  reader,
  indexCheckpoint,
  error,
  syncStart,
  syncComplete,
  syncPending,
  syncFailed,
  ttsPlay,
  ttsPause,
  ttsStop,
  ttsFailed,
}

class RuntimeDiagnostics {
  static final _events = <Map<String, Object>>[];
  static final _clock = Stopwatch();
  static String _version = 'unknown';
  static const _states = {
    'resumed',
    'inactive',
    'hidden',
    'paused',
    'detached',
    'create',
    'load',
    'loading',
    'failed',
    'cancelled',
    'ready',
    'toc',
    'chapter',
    'dispose_pending',
    'closing_jobs',
    'closing_readers',
    'closing_window',
    'close_failed',
  };

  static void start(String version) {
    _events.clear();
    _clock
      ..reset()
      ..start();
    _version = RegExp(r'^[a-zA-Z0-9.+-]{1,60}$').hasMatch(version)
        ? version
        : 'unknown';
    record(RuntimeEvent.sessionStart);
  }

  static void record(RuntimeEvent event, {String? state, int? durationMs}) {
    if (!_clock.isRunning) return;
    final entry = <String, Object>{
      'elapsedMs': _clock.elapsedMilliseconds,
      'event': event.name,
      if (_states.contains(state)) 'state': state!,
      if (durationMs != null && durationMs >= 0) 'durationMs': durationMs,
    };
    try {
      entry['rssMiB'] = ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {}
    _events.add(entry);
    if (_events.length > 300) _events.removeAt(0);
  }

  static String preview() =>
      'Modu: $_version\nPlatform: ${Platform.operatingSystem}\n'
      'Current session only; last 300 events. Cleared on every app restart.\n'
      'Elapsed time, operation states, duration and sampled RSS; no content, paths, URLs or credentials.\n'
      '${_events.map(jsonEncode).join('\n')}';
}
