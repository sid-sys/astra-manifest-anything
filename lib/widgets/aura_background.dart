import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The violet sky every screen sits on.
///
/// Drawn in code rather than shipped as an image: a gradient, a soft pink glow
/// near the top, a set of concentric rings that radiate from just above the
/// middle, and a scatter of small stars, triangles and diamonds. It replaces
/// the long-exposure photograph the app used to sit on — that was right for a
/// screen read in the dark, and wrong for everything else.
///
/// Two rules keep it from fighting the content:
///  - the decoration is faint and lives in the margins (alpha is low, shapes
///    are small), so a paragraph over it is still on the gradient, not on a
///    confetti shape;
///  - the gradient itself is dark enough at the top that white secondary text
///    clears 4.5:1 on the bare background (see `palette_test.dart`).
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// Ignored. Kept so callers that turned the old wash down still compile.
  final double intensity;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const RepaintBoundary(
        child: CustomPaint(painter: _SkyPainter(), isComplex: true),
      ),
      child,
    ],
  );
}

class _Shape {
  const _Shape(this.x, this.y, this.size, this.kind, this.color, this.turn);

  /// Position as a fraction of the screen, so the layout survives any size.
  final double x;
  final double y;
  final double size;
  final int kind; // 0 star, 1 triangle, 2 diamond, 3 ring, 4 dot
  final Color color;
  final double turn;
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  // Hand-placed rather than random, so the picture is the same on every launch
  // and every device. Kept off the vertical centre where the text lives.
  static const _shapes = <_Shape>[
    _Shape(0.10, 0.07, 22, 0, AstraColors.accent, 0.1),
    _Shape(0.88, 0.05, 15, 2, AstraColors.mint, 0.3),
    _Shape(0.80, 0.16, 12, 4, AstraColors.blush, 0),
    _Shape(0.06, 0.24, 14, 1, AstraColors.sky, 0.6),
    _Shape(0.93, 0.31, 18, 0, AstraColors.blush, 0.2),
    _Shape(0.04, 0.46, 10, 4, AstraColors.accent, 0),
    _Shape(0.95, 0.52, 13, 1, AstraColors.mint, 0.9),
    _Shape(0.08, 0.63, 20, 2, AstraColors.blush, 0.5),
    _Shape(0.90, 0.70, 16, 3, AstraColors.sky, 0),
    _Shape(0.14, 0.80, 12, 0, AstraColors.accent, 0.4),
    _Shape(0.84, 0.86, 22, 0, AstraColors.accent, 0.15),
    _Shape(0.50, 0.97, 11, 4, AstraColors.mint, 0),
    _Shape(0.30, 0.03, 9, 4, AstraColors.text, 0),
    _Shape(0.66, 0.92, 14, 1, AstraColors.blush, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AstraColors.auraTop,
            AstraColors.auraMid,
            AstraColors.auraBottom,
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // The glow: a soft pink bloom behind where a header sits. Low alpha, so it
    // brightens the page without lowering the contrast the palette test
    // measured on the bare gradient.
    final glowCentre = Offset(size.width * 0.5, size.height * 0.10);
    canvas.drawCircle(
      glowCentre,
      size.width * 0.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AstraColors.blush.withValues(alpha: 0.16),
            AstraColors.blush.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCentre, radius: size.width * 0.9)),
    );

    // Concentric rings, widening and fading outward.
    final ringCentre = Offset(size.width * 0.5, size.height * 0.40);
    for (var i = 1; i <= 7; i++) {
      canvas.drawCircle(
        ringCentre,
        size.width * 0.22 * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.10 - i * 0.01),
      );
    }

    for (final shape in _shapes) {
      _paintShape(canvas, size, shape);
    }
  }

  void _paintShape(Canvas canvas, Size size, _Shape s) {
    final centre = Offset(s.x * size.width, s.y * size.height);
    final paint = Paint()
      ..color = s.color.withValues(alpha: 0.55)
      ..style = s.kind == 3 ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(s.turn * math.pi);

    final r = s.size / 2;
    switch (s.kind) {
      case 0: // five-point star
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? r : r * 0.45;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), paint);
      case 1: // triangle
        canvas.drawPath(
          Path()
            ..moveTo(0, -r)
            ..lineTo(r, r * 0.8)
            ..lineTo(-r, r * 0.8)
            ..close(),
          paint,
        );
      case 2: // diamond
        canvas.drawPath(
          Path()
            ..moveTo(0, -r)
            ..lineTo(r * 0.75, 0)
            ..lineTo(0, r)
            ..lineTo(-r * 0.75, 0)
            ..close(),
          paint,
        );
      case 3: // ring
        canvas.drawCircle(Offset.zero, r, paint);
      default: // dot
        canvas.drawCircle(Offset.zero, r * 0.5, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
