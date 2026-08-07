import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Astra palette.
///
/// The app used to live in a dark cosmic world. It now sits in daylight: a
/// pink-to-peach wash with white cards floating on it and deep plum type. The
/// reason is not fashion. A manifestation app is asking someone to picture a
/// better morning, and a black screen is the colour of the thing they are
/// trying to leave — soft light does the persuading before a word is read.
///
/// There is still no light/dark switch. One committed world, rendered well,
/// beats two rendered adequately.
class AstraColors {
  const AstraColors._();

  /// Page background. The wash in [AuraBackground] sits on top of it; this is
  /// what shows where the gradient has faded out.
  static const canvas = Color(0xFFFDF4F8);
  static const canvasRaised = Color(0xFFFFFFFF);

  /// The three stops of the wash, top to bottom: blossom, lilac, peach.
  static const auraTop = Color(0xFFF9C8DF);
  static const auraMid = Color(0xFFE9C9F2);
  static const auraBottom = Color(0xFFFBDCC6);

  /// Cards are white and lean on shadow rather than borders. On a coloured
  /// wash a border reads as a cut-out; a shadow reads as paper.
  static const card = Color(0xFFFFFFFF);
  static const cardRaised = Color(0xFFFFFBFD);

  /// Hairline, used where a shape needs definition without a shadow — chips,
  /// inputs, dividers.
  static const line = Color(0xFFF0DCE7);

  /// Deep plum rather than black. Pure black on a pink wash reads as a
  /// printing error; this shares the background's hue and still clears 14:1.
  static const text = Color(0xFF2B1B27);

  /// Secondary type. Chosen against the *wash*, not against white: subtitles
  /// sit directly on the gradient, and the obvious lighter plum cleared AA on
  /// a card at 6.2:1 while failing it at 4.2:1 on lilac — which is exactly
  /// where most of this app's secondary text lives. This clears 4.9:1 there
  /// and 7.3:1 on white.
  static const dim = Color(0xFF665060);

  /// The accent: aubergine. Carries the primary button, the active nav item
  /// and every "this is the thing to press".
  static const accent = Color(0xFF6D2E4F);
  static const accentDeep = Color(0xFF4C1E37);

  /// What sits on top of [accent]. White, at 9.4:1.
  static const onAccent = Color(0xFFFFFFFF);

  /// A tint of the accent for selected chips and quiet fills.
  static const accentWash = Color(0xFFFBEAF2);

  /// Secondary accent, for anything that should read as distinct from the
  /// primary action. Darkened from the wash's own lilac so it can hold text.
  static const violet = Color(0xFF7B4BB0);
  static const good = Color(0xFF2F7D5B);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7E3A5C), accent],
  );

  /// The shadow every card and button shares. Tinted plum rather than black,
  /// so it sits in the wash instead of dirtying it.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF6D2E4F).withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: const Color(0xFF6D2E4F).withValues(alpha: 0.13),
      blurRadius: 26,
      offset: const Offset(0, 10),
    ),
  ];
}

class AstraSpacing {
  const AstraSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Rounder than before. The reference language is soft-cornered throughout,
  /// and a 14px radius beside a 999px pill looks like two design systems.
  static const cardRadius = 22.0;
  static const pillRadius = 999.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: 20);
}

class AstraTextStyles {
  const AstraTextStyles._();

  /// Headlines are serif, and the app leans on one trick: the emphasised word
  /// in a heading goes italic. It is the whole reason the type has personality
  /// without a second family.
  static TextStyle display(double size, {Color color = AstraColors.text}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle displayItalic(double size, {Color? color}) =>
      display(size, color: color ?? AstraColors.accent)
          .copyWith(fontStyle: FontStyle.italic);

  /// Wordmark: the app's name, set in the headline face rather than tracked-out
  /// caps. "Astra" in serif is a logo; "A S T R A" in a small sans is a label.
  static TextStyle get wordmark => GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AstraColors.text,
  );

  static TextStyle get eyebrow => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: AstraColors.accent,
  );

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14.5, height: 1.45, color: AstraColors.text);

  static TextStyle get bodyDim =>
      GoogleFonts.inter(fontSize: 13.5, height: 1.5, color: AstraColors.dim);

  static TextStyle get small =>
      GoogleFonts.inter(fontSize: 12, height: 1.4, color: AstraColors.dim);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: AstraColors.text,
  );

  static TextStyle get price => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AstraColors.text,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get quote => GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AstraColors.text,
  );
}

ThemeData buildAstraTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AstraColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AstraColors.accent,
      onPrimary: AstraColors.onAccent,
      secondary: AstraColors.violet,
      surface: AstraColors.card,
      onSurface: AstraColors.text,
      outline: AstraColors.line,
      error: Color(0xFFB3261E),
    ),
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AstraColors.text, displayColor: AstraColors.text),
    dividerColor: AstraColors.line,
    splashColor: AstraColors.accent.withValues(alpha: 0.07),
    highlightColor: AstraColors.accent.withValues(alpha: 0.04),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AstraColors.text,
      contentTextStyle: AstraTextStyles.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      ),
    ),
  );
}
