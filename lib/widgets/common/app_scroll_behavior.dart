import 'package:flutter/material.dart';

/// Use each scrollable's own controller, including nested lists and dialogs.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior({this.symmetricGutter = false});
  final bool symmetricGutter;

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    final vertical = axisDirectionToAxis(details.direction) == Axis.vertical;
    if (!vertical) return child;
    return _ScrollableScrollbar(
      child: Padding(
        // Keep the drag lane off sliders, checkboxes and text selection.
        padding: symmetricGutter
            ? const EdgeInsets.symmetric(horizontal: 14)
            : const EdgeInsets.only(right: 14),
        child: child,
      ),
    );
  }
}

// A route can share its primary controller between side-by-side lists. Bind the
// decoration to this Scrollable's position only, without changing that contract.
class _ScrollableScrollbar extends StatefulWidget {
  const _ScrollableScrollbar({required this.child});
  final Widget child;
  @override
  State<_ScrollableScrollbar> createState() => _ScrollableScrollbarState();
}

class _ScrollableScrollbarState extends State<_ScrollableScrollbar> {
  final _controller = ScrollController();
  ScrollPosition? _position;

  @override
  Widget build(BuildContext context) {
    final position =
        context.findAncestorStateOfType<ScrollableState>()?.position;
    if (position != _position) {
      if (_position != null) _controller.detach(_position!);
      _position = position;
      if (position != null) _controller.attach(position);
    }
    return AppScrollbar(controller: _controller, child: widget.child);
  }

  @override
  void dispose() {
    if (_position != null) _controller.detach(_position!);
    _controller.dispose();
    super.dispose();
  }
}

class AppScrollbar extends StatelessWidget {
  const AppScrollbar(
      {super.key, required this.child, required this.controller});

  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => RawScrollbar(
        controller: controller,
        thumbVisibility: false,
        trackVisibility: false,
        interactive: true,
        thumbColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: .46),
        thickness: 8,
        radius: const Radius.circular(4),
        minThumbLength: 48,
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        scrollbarOrientation: ScrollbarOrientation.right,
        timeToFade: const Duration(milliseconds: 1200),
        fadeDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: child,
      );
}
