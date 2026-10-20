import 'package:flutter/material.dart';

/// The outlined grouping used by reading menus, including their submenus.
/// Deliberately leaves typography, scrolling and control behaviour to the child.
class ReaderMenuGroup extends StatelessWidget {
  const ReaderMenuGroup({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Card.outlined(
        surfaceTintColor: Colors.transparent,
        margin: margin,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}
