import 'package:flutter/material.dart';

/// Sliding pages and Cupertino sheets expose the area behind the Navigator.
/// Keep it opaque and themed instead of revealing the native window's black
/// backing while routes move, scale, or round their corners.
class AppRouteSurface extends StatelessWidget {
  const AppRouteSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
}
