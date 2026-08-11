import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Astra palette: ink on paper.
///
/// Monochrome, and deliberately so. The pink version was a copy of a
/// competitor's screenshot, which meant every judgement call had already been
/// made by someone else — and a colour scheme borrowed wholesale is the part
/// users notice first and trust least. Black and white makes the type and the
/// spacing do the work, which is the part that is actually ours.
///
/// It also survives contact with content. Six intention colours had to be
/// re-picked every time the background moved; a greyscale system has nothing
/// to clash with, and a photograph or a piece of artwork dropped into a card
/// later becomes the only colour on the screen.
///
/// There is no light/dark switch. One committed world, rendered well, beats
/// two rendered adequately.
class AstraColors {
  const AstraColors._();

  /// Page background — warm off-white rather than pure white, which glares on
  /// an OLED phone at night, and this is an app people open in bed.
  static const canvas = Color(0xFFF7F7F6);
  static const canvasRaised = Color(0xFFFFFFFF);

  /// The wash: three barely-there greys. Almost flat, but not quite — a dead
  /// flat background makes white cards vanish into it.
  static const auraTop = Color(0xFFEDEDEB);
  static const auraMid = Color(0xFFF4F4F3);
  static const auraBottom = Color(0xFFE9E9E7);

  /// Cards are white and lean on shadow rather than borders.
  static const card = Color(0xFFFFFFFF);
  static const cardRaised = Color(0xFFFFFFFF);

  /// Hairline, for shapes that need definition without a shadow.
  static const line = Color(0xFFE2E2DF);

  /// Near-black, not pure black. #000 against white is a harsh edge that
  /// reads as unrendered; this is soft enough to look printed and still
  /// clears 17:1.
  static const text = Color(0xFF121212);

  /// Secondary type. Picked against the *darkest* stop of the wash, not
  /// against white: the obvious mid-grey cleared 5.4:1 on a card and failed at
  /// 4.46:1 on the bottom of the gradient, which is exactly where the small
  /// print under a button sits. This clears 4.9:1 there and 5.9:1 on paper.
  static const dim = Color(0xFF646462);

  /// The accent is the ink. Buttons, the active nav item, every "press this".
  static const accent = Color(0xFF121212);
  static const accentDeep = Color(0xFF000000);

  static const onAccent = Color(0xFFFFFFFF);

  /// A tint for selected chips and quiet fills.
  static const accentWash = Color(0xFFEFEFED);

  /// Kept because widgets reference them, and mapped into the greyscale: a
  /// second colour would be the whole point of this palette, undone.
  static const violet = Color(0xFF3A3A38);
  static const good = Color(0xFF2E2E2C);

  /// Flat ink. Buttons used to carry a gradient; in monochrome a gradient
  /// reads as a rendering artefact rather than as depth.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent],
  );

  /// Neutral shadow. The plum tint existed to sit inside a pink wash; on grey
  /// it would just look like dirt.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
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

  /// Soft-cornered throughout: a 14px radius beside a 999px pill looks like
  /// two design systems. Everything round, nothing sharp.
  static const cardRadius = 24.0;
  static const pillRadius = 999.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: 20);
}

class AstraTextStyles {
  const AstraTextStyles._();

  /// Headlines are serif, and the app leans on one trick: the emphasised word
  /// in a heading goes italic. It is the whole reason the type has personality
  /// without a second family.
  ///
  /// Heavier than it was. With the colour gone, weight is what makes a heading
  /// read as a heading — the pink version could lean on an accent hue to do
  /// that, and this one cannot.
  static TextStyle display(double size, {Color color = AstraColors.text}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle displayItalic(double size, {Color? color}) =>
      display(size, color: color ?? AstraColors.accent)
          .copyWith(fontStyle: FontStyle.italic);

  /// Wordmark: the app's name, set in the headline face rather than tracked-out
  /// caps. "Astra" in serif is a logo; "A S T R A" in a small sans is a label.
  static TextStyle get wordmark => GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
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
