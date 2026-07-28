import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The night sky every screen sits on: a warm glow at the top fading into ink,
/// with a fixed scatter of stars.
///
/// The star positions come from a seeded generator so they stay put between
/// rebuilds — a sky that reshuffles on every setState reads as a glitch.
class Starfield extends StatelessWidget {
  const Starfield({super.key, required this.child, this.seed = 7});

  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.15),
          radius: 1.1,
          colors: [Color(0xFF1A2048), AstraColors.ink],
          stops: [0, 0.72],
        ),
      ),
      child: CustomPaint(
        painter: _StarPainter(seed: seed),
        child: child,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint();

    for (var i = 0; i < 46; i++) {
      final dx = random.nextDouble() * size.width;
      // Stars thin out toward the bottom, where content lives.
      final dy = random.nextDouble() * size.height * 0.62;
      final radius = random.nextDouble() * 1.1 + 0.4;
      final opacity = (1 - dy / size.height) * random.nextDouble() * 0.7;

      paint.color = i % 7 == 0
          ? AstraColors.gold.withValues(alpha: opacity)
          : Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.seed != seed;
}
