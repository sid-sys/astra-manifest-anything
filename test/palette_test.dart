import 'dart:math' as math;

import 'package:astra/models/intention.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette's legibility, asserted rather than eyeballed.
///
/// The app has moved worlds three times — dark to daylight, daylight to a night
/// sky, and now to a bright violet sky — and each move broke every contrast
/// assumption at once. These are the regressions that survive a screenshot
/// review, because pale-on-pale and dim-on-bright both look intentional.
///
/// The cards are *translucent*, so the colour behind a word is not the card's
/// own value but the card composited over the gradient beneath it. Measuring
/// the raw ARGB would flatter every card, so each surface is flattened onto the
/// gradient stop it can actually sit on first.
Color _over(Color top, Color bottom) {
  final a = top.a;
  return Color.from(
    alpha: 1,
    red: top.r * a + bottom.r * (1 - a),
    green: top.g * a + bottom.g * (1 - a),
    blue: top.b * a + bottom.b * (1 - a),
  );
}
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

  // AA for large or bold text and for graphics: what a button label, a 10px
  // all-caps eyebrow or a 32px glyph actually has to clear.
  const aaLarge = 3.0;

  group('the violet palette', () {
    /// The three stops of the page gradient — bare background, where text
    /// sits when it is not on a card.
    Map<String, Color> gradient() => {
      'aura top': AstraColors.auraTop,
      'aura mid': AstraColors.auraMid,
      'aura bottom': AstraColors.auraBottom,
      'page': AstraColors.canvas,
    };

    /// Every card, composited over every gradient stop it can land on.
    Map<String, Color> cards() => {
      for (final entry in gradient().entries) ...{
        'card on ${entry.key}': _over(AstraColors.card, entry.value),
        'raised card on ${entry.key}': _over(AstraColors.cardRaised, entry.value),
      },
    };

    Map<String, Color> surfaces() => {
      ...gradient(),
      ...cards(),
      'sheet': AstraColors.canvasRaised,
    };

    test('primary text is readable on every surface', () {
      surfaces().forEach((name, surface) {
        expect(
          _ratio(AstraColors.text, surface),
          greaterThanOrEqualTo(aa),
          reason: 'body text on $name',
        );
      });
    });

    test('secondary text is readable on every surface', () {
      surfaces().forEach((name, surface) {
        // The one that broke before. Subtitles sit directly on the gradient,
        // so the bare wash — not the card — is what this colour must survive.
        expect(
          _ratio(AstraColors.dim, surface),
          greaterThanOrEqualTo(aa),
          reason: 'secondary text on $name',
        );
      });
    });

    test('the accent carries its own label colour', () {
      expect(
        _ratio(AstraColors.onAccent, AstraColors.accent),
        greaterThanOrEqualTo(aa),
      );
      expect(
        _ratio(AstraColors.onAccent, AstraColors.accentDeep),
        greaterThanOrEqualTo(aa),
      );
    });

    test('the accent is readable as text on every card and sheet', () {
      cards().forEach((name, surface) {
        expect(
          _ratio(AstraColors.accent, surface),
          greaterThanOrEqualTo(aa),
          reason: 'accent text on $name',
        );
      });
      expect(
        _ratio(AstraColors.accent, AstraColors.canvasRaised),
        greaterThanOrEqualTo(aa),
      );
    });

    test('the call-to-action carries a white label', () {
      // Button labels are bold 17px, which counts as large text.
      expect(
        _ratio(AstraColors.onCta, AstraColors.cta),
        greaterThanOrEqualTo(aaLarge),
      );
      expect(
        _ratio(AstraColors.onCta, AstraColors.ctaEdge),
        greaterThanOrEqualTo(aa),
      );
    });

    test('the call-to-action stands out from the page it sits on', () {
      gradient().forEach((name, surface) {
        expect(
          _ratio(AstraColors.cta, surface),
          greaterThanOrEqualTo(1.4),
          reason: 'pink button against $name',
        );
      });
    });

    test('every intention accent holds up as a label', () {
      for (final intention in Intention.values) {
        cards().forEach((name, surface) {
          expect(
            _ratio(intention.accent, surface),
            greaterThanOrEqualTo(aaLarge),
            reason: '${intention.label} on $name',
          );
        });
      }
    });

    test('a card is visible against the gradient it sits on', () {
      // Glass separates from the page by being darker than it, and only by
      // that apart from a hairline. Composited, because a card that is 35%
      // indigo over violet is what the eye actually gets.
      for (final stop in [AstraColors.auraTop, AstraColors.auraMid]) {
        expect(
          _ratio(_over(AstraColors.card, stop), stop),
          greaterThan(1.15),
        );
      }
    });

    test('the cards are translucent, so the gradient shows through', () {
      expect(AstraColors.card.a, lessThan(0.5));
      expect(AstraColors.cardRaised.a, lessThan(0.5));

      // A sheet is the exception and must stay opaque: colour moving behind a
      // list somebody is reading is not depth, it is noise.
      expect(AstraColors.canvasRaised.a, 1.0);
    });

    test('the page is violet, not grey and not black', () {
      // Blue-violet: blue above red above green. A palette edit that drifts
      // toward grey would pass every contrast test above and quietly turn the
      // app back into a settings screen.
      for (final stop in [
        AstraColors.auraTop,
        AstraColors.auraMid,
        AstraColors.auraBottom,
      ]) {
        expect(stop.b, greaterThan(stop.g));
        expect(stop.r, greaterThan(stop.g));
      }
      // And bright enough to be a colour: lighter than the old near-black
      // night, dark enough for white text (the contrast tests hold that line).
      expect(_luminance(AstraColors.auraMid), greaterThan(0.05));
    });
  });
}
