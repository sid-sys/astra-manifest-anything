import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The night sky every screen sits on.
///
/// It was paper — a flat warm off-white, chosen when Maya wrote stories and
/// the reading was the point. It writes manifestations now, which are listened
/// to with the eyes closed, usually in bed, usually with the lights off. A
/// bright screen is the wrong object for that; it is the thing you put down.
///
/// One image rather than a painted gradient. A real long-exposure sky has
/// thousands of stars at every brightness and a haze that is not a smooth ramp,
/// and every attempt to draw that in code lands somewhere between a smear and a
/// screensaver.
///
/// The scrim under the child is what makes it usable. Text over an
/// unmodified photograph is unreadable wherever the photograph happens to be
/// bright, and "happens to be" is not a thing type can be laid out against — so
/// the bottom two thirds are darkened toward black, which is where the words
/// and the controls live.
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// Ignored. Kept so callers that turned the old wash down still compile.
  final double intensity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AstraColors.canvas,
      image: DecorationImage(
        image: AssetImage('assets/brand/night_sky.jpg'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x0D000000),
            Color(0x66000000),
            Color(0xE6050510),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    ),
  );
}
