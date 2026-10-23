import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';

typedef BatteryLevelLoader = Future<int> Function();

/// Reads a usable battery percentage, or returns `null` when the current
/// device does not expose a battery.
///
/// On macOS, battery_plus 6.x reports the native string `UNAVAILABLE` on
/// machines without a battery. Its Dart method-channel implementation expects
/// an integer, so that response surfaces as a [TypeError]. Treating it as an
/// unavailable reading keeps desktop readers from producing uncaught errors.
Future<int?> readBatteryLevelSafely({BatteryLevelLoader? loader}) async {
  try {
    final level = await (loader ?? () => Battery().batteryLevel)();
    if (level < 0 || level > 100) return null;
    return level;
  } catch (_) {
    return null;
  }
}

/// One battery read shared by all visible reader metadata slots, not per page.
class ReadingBatteryLevel extends ValueNotifier<int?>
    with WidgetsBindingObserver {
  ReadingBatteryLevel({BatteryLevelLoader? loader})
      : _loader = loader,
        super(null);

  final BatteryLevelLoader? _loader;
  Timer? _timer;
  bool _loading = false;
  bool _disposed = false;

  @override
  void addListener(VoidCallback listener) {
    final wasListening = hasListeners;
    super.addListener(listener);
    if (!wasListening) {
      WidgetsBinding.instance.addObserver(this);
      _start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  void _start() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    unawaited(_refresh());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading || _disposed || !hasListeners) return;
    _loading = true;
    try {
      final level = await readBatteryLevelSafely(loader: _loader);
      if (!_disposed && hasListeners) value = level;
    } finally {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    _timer = null;
    if (state == AppLifecycleState.resumed && hasListeners) _start();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }
}
