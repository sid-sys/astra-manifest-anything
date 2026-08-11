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
  career('Career', '✦', AstraColors.text),
  abundance('Abundance', '✧', AstraColors.text),
  love('Love', '♡', AstraColors.text),
  health('Health', '☘', AstraColors.text),
  confidence('Confidence', '△', AstraColors.text),
  peace('Peace', '☾', AstraColors.text);

  const Intention(this.label, this.glyph, this.accent);

  final String label;
  final String glyph;
  final Color accent;

  static Intention fromName(String name) => Intention.values.firstWhere(
    (i) => i.name == name,
    orElse: () => Intention.career,
  );
}
