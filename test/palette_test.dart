import 'dart:math' as math;

import 'package:astra/models/intention.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette's legibility, asserted rather than eyeballed.
///
/// Moving the app from a dark world into daylight broke every contrast
/// assumption at once — six intention accents tuned for near-black all fell
/// under 3:1 on white, and a secondary grey that looked fine on a card failed
/// on the wash behind it. Those are exactly the regressions that survive a
/// screenshot review, because pastel-on-pastel looks intentional.
double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _ratio(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  // WCAG AA for body text.
  const aa = 4.5;

  // AA for large text and for graphics — what an accent used as a 10px
  // all-caps eyebrow or a 32px glyph actually has to clear.
  const aaLarge = 3.0;

  /// Every surface a piece of text can land on: white paper, and the three
  /// stops of the wash it floats over.
  const surfaces = <String, Color>{
    'card': AstraColors.card,
    'aura top': AstraColors.auraTop,
    'aura mid': AstraColors.auraMid,
    'aura bottom': AstraColors.auraBottom,
  };

  group('primary text is readable on every surface', () {
    surfaces.forEach((name, surface) {
      test('body text on $name', () {
        expect(_ratio(AstraColors.text, surface), greaterThanOrEqualTo(aa));
      });

      test('secondary text on $name', () {
        // The one that broke. Subtitles sit directly on the gradient, so the
        // wash — not white — is what this colour has to survive.
        expect(_ratio(AstraColors.dim, surface), greaterThanOrEqualTo(aa));
      });
    });
  });

  test('the accent carries white text', () {
    expect(
      _ratio(AstraColors.onAccent, AstraColors.accent),
      greaterThanOrEqualTo(aa),
    );
    expect(
      _ratio(AstraColors.onAccent, AstraColors.accentDeep),
      greaterThanOrEqualTo(aa),
    );
  });

  test('the accent is readable as text on paper', () {
    expect(
      _ratio(AstraColors.accent, AstraColors.card),
      greaterThanOrEqualTo(aa),
    );
  });

  group('every intention accent holds up as a label', () {
    for (final intention in Intention.values) {
      test('${intention.label} on a card', () {
        // These are used for eyebrows and glyphs, not paragraphs, so the
        // large-text threshold is the honest one to hold them to — but they
        // all clear AA proper anyway, and it is worth knowing if one stops.
        expect(
          _ratio(intention.accent, AstraColors.card),
          greaterThanOrEqualTo(aaLarge),
        );
      });
    }
  });

  test('the wash never collides with the paper on it', () {
    // A card has no border any more; it is told apart from the background by
    // being lighter. If the wash ever drifts close to white, cards stop being
    // objects and the whole layout flattens.
    for (final stop in [
      AstraColors.auraTop,
      AstraColors.auraMid,
      AstraColors.auraBottom,
    ]) {
      expect(_ratio(AstraColors.card, stop), greaterThan(1.1));
    }
  });
}
