import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supplies hardware cutout insets only to the Harmony reader's AppBar.
/// Hiding system bars must not erase the physical camera exclusion area.
class HarmonyReaderToolbar extends StatefulWidget {
  const HarmonyReaderToolbar({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<HarmonyReaderToolbar> createState() => _HarmonyReaderToolbarState();
}

class _HarmonyReaderToolbarState extends State<HarmonyReaderToolbar>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('modu/reader_cutout');
  EdgeInsets _physicalInsets = EdgeInsets.zero;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant HarmonyReaderToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Also refresh when reopening the toolbar after immersive mode changes.
    _refresh();
  }

  @override
  void didChangeMetrics() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    if (!widget.enabled) return;
    try {
      final values = await _channel.invokeListMethod<num>('getInsets');
      if (!mounted ||
          request != _request ||
          values == null ||
          values.length != 4) {
        return;
      }
      if (values.any((v) => !v.isFinite || v < 0)) return;
      final insets = EdgeInsets.fromLTRB(values[0].toDouble(),
          values[1].toDouble(), values[2].toDouble(), values[3].toDouble());
      if (insets != _physicalInsets) setState(() => _physicalInsets = insets);
    } on PlatformException {
      // Keep Flutter's normal safe area if the native window is unavailable.
    } on MissingPluginException {
      // Older Harmony builds may not yet include the native bridge.
    }
  }

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final media = MediaQuery.of(context);
    final cutout = _physicalInsets / media.devicePixelRatio;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          left: math.max(media.padding.left, cutout.left),
          top: math.max(media.padding.top, cutout.top),
          right: math.max(media.padding.right, cutout.right),
        ),
      ),
      child: widget.child,
    );
  }
}
