import 'package:flutter/material.dart';

/// Keep unsupported reader settings visible without allowing hidden changes.
class ReaderSettingAvailability extends StatelessWidget {
  const ReaderSettingAvailability(
      {super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return Semantics(
        enabled: false,
        child: ExcludeFocus(
            child: AbsorbPointer(
                child: Opacity(
                    opacity: .38,
                    child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          .2126,
                          .7152,
                          .0722,
                          0,
                          0,
                          .2126,
                          .7152,
                          .0722,
                          0,
                          0,
                          .2126,
                          .7152,
                          .0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: child)))));
  }
}
