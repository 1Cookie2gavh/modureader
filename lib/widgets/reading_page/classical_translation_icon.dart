import 'package:flutter/material.dart';

/// Keep Material's exact 文 glyph; replace only its Latin A with a matching 白.
class ClassicalTranslationIcon extends StatelessWidget {
  const ClassicalTranslationIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final color = theme.color ?? Theme.of(context).colorScheme.onSurface;
    final opacity = theme.opacity ?? 1;
    return SizedBox.square(
      dimension: size,
      child: FittedBox(
        child: SizedBox.square(
          dimension: 24,
          child: Stack(children: [
            ClipPath(
              clipper: const _TranslationSourceGlyph(),
              child: Icon(Icons.translate_outlined, size: 24, color: color),
            ),
            CustomPaint(
              size: const Size.square(24),
              painter:
                  _VernacularGlyph(color.withValues(alpha: color.a * opacity)),
            ),
          ]),
        ),
      ),
    );
  }
}

// Remove the original A without changing 文 or painting a background rectangle.
class _TranslationSourceGlyph extends CustomClipper<Path> {
  const _TranslationSourceGlyph();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(24, 0)
    ..lineTo(24, 9.5)
    ..lineTo(16, 9.5)
    ..lineTo(11, 23)
    ..lineTo(0, 24)
    ..close();

  @override
  bool shouldReclip(_TranslationSourceGlyph oldClipper) => false;
}

class _VernacularGlyph extends CustomPainter {
  const _VernacularGlyph(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // Match Material translate's two-unit stems and geometric, square edges.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawLine(const Offset(18, 10), const Offset(17, 13), paint);
    canvas.drawRect(const Rect.fromLTRB(15, 13, 22, 21), paint);
    canvas.drawLine(const Offset(15, 17), const Offset(22, 17), paint);
  }

  @override
  bool shouldRepaint(_VernacularGlyph oldDelegate) =>
      oldDelegate.color != color;
}
