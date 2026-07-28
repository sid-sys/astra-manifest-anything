import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Astra palette. The app commits to a single dark "cosmic" world, so
/// there is no light variant — see design/mockup.html.
class AstraColors {
  const AstraColors._();

  static const ink = Color(0xFF0B0E1F);
  static const inkRaised = Color(0xFF10142B);
  static const card = Color(0xFF161B36);
  static const cardRaised = Color(0xFF1C2244);
  static const line = Color(0xFF262D52);
  static const text = Color(0xFFF2EFFF);
  static const dim = Color(0xFF9AA0C2);
  static const gold = Color(0xFFE4B454);
  static const goldDeep = Color(0xFFB8892F);
  static const violet = Color(0xFF8F7BF0);
  static const good = Color(0xFF6FCF97);

  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gold, goldDeep],
  );
}

class AstraSpacing {
  const AstraSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const cardRadius = 14.0;
  static const pillRadius = 999.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: 20);
}

class AstraTextStyles {
  const AstraTextStyles._();

  static TextStyle display(double size, {Color color = AstraColors.text}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      );

  /// Wordmark and section eyebrows: wide-tracked uppercase gold.
  static TextStyle get wordmark => GoogleFonts.playfairDisplay(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 4.2,
    color: AstraColors.gold,
  );

  static TextStyle get eyebrow => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AstraColors.gold,
  );

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14, height: 1.45, color: AstraColors.text);

  static TextStyle get bodyDim =>
      GoogleFonts.inter(fontSize: 13, height: 1.45, color: AstraColors.dim);

  static TextStyle get small =>
      GoogleFonts.inter(fontSize: 11.5, height: 1.4, color: AstraColors.dim);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AstraColors.text,
  );

  static TextStyle get price => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AstraColors.text,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get quote => GoogleFonts.ebGaramond(
    fontSize: 17,
    fontStyle: FontStyle.italic,
    height: 1.4,
    color: AstraColors.text,
  );
}

ThemeData buildAstraTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AstraColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: AstraColors.gold,
      onPrimary: Color(0xFF14101F),
      secondary: AstraColors.violet,
      surface: AstraColors.card,
      onSurface: AstraColors.text,
      outline: AstraColors.line,
      error: Color(0xFFE87F7F),
    ),
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AstraColors.text, displayColor: AstraColors.text),
    dividerColor: AstraColors.line,
    splashColor: AstraColors.gold.withValues(alpha: 0.08),
    highlightColor: AstraColors.gold.withValues(alpha: 0.05),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AstraColors.cardRaised,
      contentTextStyle: AstraTextStyles.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      ),
    ),
  );
}
