import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The life areas a user can manifest toward. Stories, library filters and the
/// daily pick are all keyed on these.
/// Every intention is ink now.
///
/// They used to be six colours, re-picked from scratch each time the
/// background moved, and the differences were never load-bearing: the glyph
/// and the label already say which is which, and nobody was reading meaning
/// out of the particular shade of blue on Confidence. Six accents in a
/// monochrome app would be the exception that undoes the rule.
enum Intention {
  career('Career', '✦'),
  abundance('Abundance', '✧'),
  love('Love', '♡'),
  health('Health', '☘'),
  confidence('Confidence', '△'),
  peace('Peace', '☾');

  const Intention(this.label, this.glyph);

  final String label;
  final String glyph;

  /// A getter rather than a stored colour, because the palette moved when dark
  /// mode arrived and an enum can only hold compile-time constants. Every
  /// intention is ink either way; which ink depends on the paper.
  Color get accent => AstraColors.text;

  static Intention fromName(String name) => Intention.values.firstWhere(
    (i) => i.name == name,
    orElse: () => Intention.career,
  );
}
