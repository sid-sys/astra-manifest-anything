import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The wash every screen sits on: a near-flat sweep of greys with light
/// falling from the top right.
///
/// Two gradients rather than one. A single ramp reads as a flat swatch; a soft
/// off-centre bloom over a vertical ramp gives the light somewhere to come
/// from. In greyscale that matters more, not less — the difference between
/// "paper" and "the renderer forgot the background" is entirely in the
/// gradient.
///
/// [intensity] fades the whole thing toward white. Screens that are mostly
/// cards — a settings list, the library — turn it down so the paper reads as
/// paper rather than as tiles on wallpaper.
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final t = intensity.clamp(0.0, 1.0);

    Color wash(Color color) => Color.lerp(AstraColors.canvas, color, t)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            wash(AstraColors.auraTop),
            wash(AstraColors.auraMid),
            wash(AstraColors.auraBottom),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.75),
            radius: 1.15,
            colors: [
              Colors.white.withValues(alpha: 0.55 * t),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
