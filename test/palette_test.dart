import 'dart:math' as math;

import 'package:astra/models/intention.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette's legibility, asserted rather than eyeballed.
///
/// The app has now moved worlds twice — dark to daylight, and daylight back to
/// a night sky — and each move broke every contrast assumption at once. These
/// are the regressions that survive a screenshot review, because pale-on-pale
/// and dim-on-dark both look intentional.
///
/// The night palette adds a wrinkle the paper one did not have: the cards are
/// *translucent*, so the colour behind a word is not the card's own value but
/// the card composited over whatever is beneath it. Measuring the raw ARGB
/// would flatter every card by pretending the sky is not there, so every
/// surface is flattened onto the canvas first.
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

  // AA for large text and for graphics — what an accent used as a 10px
  // all-caps eyebrow or a 32px glyph actually has to clear.
  const aaLarge = 3.0;

  group('the night palette', () {
      /// Every surface a piece of text can land on, each flattened onto the
      /// canvas so a translucent card is measured as it is actually seen.
      ///
      /// The sky image sits between the canvas and the card in real life. It is
      /// not modelled here because it is a photograph rather than a colour —
      /// what keeps text off its bright parts is the scrim in `AuraBackground`,
      /// which darkens toward black exactly where the words are.
      Map<String, Color> surfaces() => {
        'page': AstraColors.canvas,
        'card': _over(AstraColors.card, AstraColors.canvas),
        'raised card': _over(AstraColors.cardRaised, AstraColors.canvas),
        'sheet': AstraColors.canvasRaised,
        'aura top': AstraColors.auraTop,
        'aura bottom': AstraColors.auraBottom,
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
          // The one that broke. Subtitles sit directly on the gradient, so the
          // wash — not the card — is what this colour has to survive.
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

      test('the accent is readable as text on a card', () {
        expect(
          _ratio(AstraColors.accent, _over(AstraColors.card, AstraColors.canvas)),
          greaterThanOrEqualTo(aa),
        );
      });

      test('every intention accent holds up as a label', () {
        for (final intention in Intention.values) {
          // These are used for eyebrows and glyphs, not paragraphs, so the
          // large-text threshold is the honest one to hold them to — but they
          // all clear AA proper anyway, and it is worth knowing if one stops.
          expect(
            _ratio(
              intention.accent,
              _over(AstraColors.card, AstraColors.canvas),
            ),
            greaterThanOrEqualTo(aaLarge),
            reason: '${intention.label} on a card',
          );
        }
      });

      test('a card is visible against the sky it sits on', () {
        // A translucent card separates from the background by being lighter
        // than it, and only by that — there is no border and the shadow is
        // invisible on a dark ground. Measured composited, because a card that
        // is 12% white over near-black is what the eye actually gets.
        expect(
          _ratio(_over(AstraColors.card, AstraColors.canvas), AstraColors.canvas),
          greaterThan(1.1),
        );
      });

      test('the cards are translucent, so the sky shows through', () {
        // The decision this scheme is built on. An opaque card would be a grey
        // rectangle pasted over a photograph; the whole reason the background
        // is a photograph is that things float in it.
        expect(AstraColors.card.a, lessThan(0.5));
        expect(AstraColors.cardRaised.a, lessThan(0.5));

        // A sheet is the exception and must stay opaque: stars moving behind a
        // list somebody is reading is not depth, it is noise.
        expect(AstraColors.canvasRaised.a, 1.0);
      });

      test('the page is night rather than grey', () {
        // Cold and very dark: blue above red, and dark enough that the sky
        // image is the brightest thing on screen. A palette edit that lightens
        // this would pass every contrast test above and quietly turn the app
        // back into a grey one.
        expect(AstraColors.canvas.b, greaterThan(AstraColors.canvas.r));
        expect(_luminance(AstraColors.canvas), lessThan(0.02));
      });
    });
}
