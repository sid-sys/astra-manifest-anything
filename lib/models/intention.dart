import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The life areas a user can manifest toward. Stories, library filters and the
/// daily pick are all keyed on these.
/// Accents are chosen to hold their own *as text on white*, not just as a dot.
/// The old set was tuned for a dark background and every one of them fell
/// below 3:1 once the app moved into daylight — a card eyebrow in pastel pink
/// on white is decoration, not a label.
enum Intention {
  career('Career', '✦', Color(0xFF9A6410)),
  abundance('Abundance', '✧', AstraColors.violet),
  love('Love', '♡', Color(0xFFB63E67)),
  health('Health', '☘', AstraColors.good),
  confidence('Confidence', '△', Color(0xFF1F6698)),
  peace('Peace', '☾', Color(0xFF5C4E9E));

  const Intention(this.label, this.glyph, this.accent);

  final String label;
  final String glyph;
  final Color accent;

  static Intention fromName(String name) => Intention.values.firstWhere(
    (i) => i.name == name,
    orElse: () => Intention.career,
  );
}
