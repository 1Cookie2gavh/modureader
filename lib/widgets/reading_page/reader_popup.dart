import 'package:anx_reader/utils/app_motion.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:anx_reader/widgets/common/app_scroll_behavior.dart';

/// Shared geometry for reader query and settings panels.
class ReaderPopup extends StatelessWidget {
  const ReaderPopup({super.key, required this.child});
  final Widget child;

  static BoxConstraints constraints(BuildContext context) =>
      Theme.of(context).bottomSheetTheme.constraints ??
      BoxConstraints(
          maxWidth: Theme.of(context).useMaterial3 ? 640 : double.infinity);

  static double height(BuildContext context) {
    final media = MediaQuery.of(context);
    return math.max(
        0.0,
        math.min(media.size.height * 0.8,
            media.size.height - media.viewInsets.bottom - media.padding.top));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: PointerInterceptor(
        child: SizedBox(
          key: const ValueKey('reader-popup-body'),
          width: double.infinity,
          height: height(context),
          // This container already consumes the keyboard inset. Nested chat
          // Scaffolds must not resize by that same inset a second time.
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: RepaintBoundary(
              child: ScrollConfiguration(
                  behavior: const AppScrollBehavior(symmetricGutter: true),
                  child: Padding(
                      padding: const EdgeInsets.only(top: 8), child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep quick settings compact without moving the toolbar offscreen.
class ReaderQuickStylePanel extends StatelessWidget {
  const ReaderQuickStylePanel(
      {super.key, required this.content, required this.toolbar});

  final Widget content;
  final Widget toolbar;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
      behavior: const AppScrollBehavior(symmetricGutter: true),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: ReaderPopup.height(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Flexible(child: content), toolbar],
        ),
      ));
}

Future<void> showReaderPopup(BuildContext context,
    {required WidgetBuilder builder, bool enableDrag = true}) async {
  ModalRoute<dynamic>? route;
  // Keep the content widget stable while the bottom-sheet route responds to
  // keyboard metrics; build it below the consumed-inset MediaQuery.
  final content = Builder(builder: builder);
  await showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.style,
    context: context,
    constraints: ReaderPopup.constraints(context),
    isScrollControlled: true,
    enableDrag: enableDrag,
    showDragHandle: false,
    clipBehavior: Clip.hardEdge,
    builder: (context) {
      route = ModalRoute.of(context);
      return ReaderPopup(child: content);
    },
  );
  // Native reader views must not regain focus during the reverse animation.
  await route?.completed;
}
