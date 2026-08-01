import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The life areas a user can manifest toward. Stories, library filters and the
/// daily pick are all keyed on these.
enum Intention {
  career('Career', '✦', Color(0xFFE4B454)),
  abundance('Abundance', '✧', AstraColors.violet),
  love('Love', '♡', Color(0xFFE88FA8)),
  health('Health', '☘', AstraColors.good),
  confidence('Confidence', '△', Color(0xFF7FB8E8)),
  peace('Peace', '☾', Color(0xFFB8A9E8));

  const Intention(this.label, this.glyph, this.accent);

  final String label;
  final String glyph;
  final Color accent;

  static Intention fromName(String name) => Intention.values.firstWhere(
    (i) => i.name == name,
    orElse: () => Intention.career,
  );
}
