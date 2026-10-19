import 'package:flutter/material.dart';

/// Keep both reader elements in place when rotating or toggling comparison.
/// In particular, never recreate the source WebView to show the original page.
class DocumentComparisonView extends StatelessWidget {
  const DocumentComparisonView({
    super.key,
    required this.original,
    this.reflow,
    this.compare = false,
    required this.onOriginalInteraction,
    required this.onReflowInteraction,
  });

  final Widget original;
  final Widget? reflow;
  final bool compare;
  final VoidCallback onOriginalInteraction, onReflowInteraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final split = compare && reflow != null;
        final horizontal = size.maxWidth > size.maxHeight;
        final width = size.maxWidth;
        final height = size.maxHeight;
        final sourceWidth = split && horizontal ? (width - 1) / 2 : width;
        final sourceHeight = split && !horizontal ? (height - 1) / 2 : height;
        return Stack(children: [
          Positioned(
            left: 0,
            top: 0,
            width: sourceWidth,
            height: sourceHeight,
            child: Visibility(
              visible: reflow == null || split,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: ClipRect(
                child: Listener(
                  onPointerDown: (_) => onOriginalInteraction(),
                  onPointerSignal: (_) => onOriginalInteraction(),
                  child: original,
                ),
              ),
            ),
          ),
          if (reflow != null)
            Positioned(
              left: split && horizontal ? sourceWidth + 1 : 0,
              top: split && !horizontal ? sourceHeight + 1 : 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: Listener(
                  onPointerDown: (_) => onReflowInteraction(),
                  onPointerSignal: (_) => onReflowInteraction(),
                  child: reflow!,
                ),
              ),
            ),
          if (split)
            Positioned(
              left: horizontal ? sourceWidth : 0,
              top: horizontal ? 0 : sourceHeight,
              width: horizontal ? 1 : width,
              height: horizontal ? height : 1,
              child: ColoredBox(color: Theme.of(context).dividerColor),
            ),
        ]);
      });
}
