import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Maya palette: ink on paper.
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
/// One world, rendered well. A light/dark switch was built and taken back out:
/// two palettes is two designs to keep honest, and this is a book you read
/// rather than a console you operate.
///
/// The page is paper — warm, faintly toasted, the colour of a paperback left
/// out in the sun — rather than white or grey. Ink on paper is the whole idea,
/// and a neutral grey page made the app read as a settings screen.
class AstraColors {
  const AstraColors._();

  /// The page. Everything else is an object sitting on it.
  ///
  /// Warm enough to read as paper and deep enough that a white card lifts off
  /// it.
  ///
  /// Deep, cold and almost black. It is only visible where the sky image does
  /// not reach — behind a sheet, or for the frame before the asset decodes —
  /// so it is chosen to disappear into the photograph rather than to stand on
  /// its own.
  static const canvas = Color(0xFF05060F);

  /// Sheets and bars above the page: bottom sheets, the player bar.
  ///
  /// Opaque, unlike the cards. A sheet that let the stars through would put
  /// moving light behind a list somebody is trying to read.
  static const canvasRaised = Color(0xFF0D1020);

  /// Three steps of the same night, for the few places that shade one surface
  /// against another.
  static const auraTop = Color(0xFF0A0C18);
  static const auraMid = Color(0xFF05060F);
  static const auraBottom = Color(0xFF02030A);

  /// Cards are a lift off the sky rather than a sheet laid over it.
  ///
  /// Translucent on purpose: at 12% white the stars still show through, which
  /// is the difference between a card floating in the sky and a grey rectangle
  /// pasted on top of it. Text sits on the card's own darkness, not on whatever
  /// the photograph is doing underneath.
  static const card = Color(0x1FFFFFFF);
  static const cardRaised = Color(0x2EFFFFFF);

  /// Hairline, for shapes that need definition without a shadow. A pale rule
  /// at low opacity, so it reads as an edge catching light rather than as a
  /// border drawn around something.
  static const line = Color(0x33FFFFFF);

  /// Off-white, not pure white. #FFF on a dark ground glares and leaves an
  /// afterimage, which is the opposite of what a screen read at night should
  /// do.
  static const text = Color(0xFFF2F1F6);

  /// Secondary type. Picked against the *sky*, not against a card: a grey that
  /// clears on a card is the one that fails over the bright part of the
  /// photograph, which is exactly where the small print under a heading sits.
  static const dim = Color(0xFFA9AAC0);

  /// The accent is light now, because the ink is. Buttons, the active nav
  /// item, every "press this".
  static const accent = Color(0xFFF2F1F6);
  static const accentDeep = Color(0xFFFFFFFF);

  /// What sits on top of an accent-coloured button — dark, since the button is
  /// pale.
  static const onAccent = Color(0xFF0A0B14);

  /// A tint for selected chips and quiet fills.
  static const accentWash = Color(0x24FFFFFF);

  /// Kept because widgets reference them. A violet that belongs to the sky
  /// rather than a second brand hue.
  static const violet = Color(0xFF8E86C8);
  static const good = Color(0xFF8FD3B6);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent],
  );

  /// Neutral shadow. A tinted one would look like dirt on paper.
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
  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: -0.4,
        color: color ?? AstraColors.text,
      );

  static TextStyle displayItalic(double size, {Color? color}) =>
      display(size, color: color ?? AstraColors.accent)
          .copyWith(fontStyle: FontStyle.italic);

  /// Wordmark: the app's name, set in the headline face rather than tracked-out
  /// caps. "Maya" in serif is a logo; "A S T R A" in a small sans is a label.
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
  // Dark, because the app is a night sky now. Getting this wrong is not
  // cosmetic: Material picks its own defaults for anything the app does not
  // name — dialog surfaces, dropdown menus, the text-selection handles — and a
  // light base would hand back white panels on black in exactly the places
  // nobody remembers to style.
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AstraColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: AstraColors.accent,
      onPrimary: AstraColors.onAccent,
      secondary: AstraColors.violet,
      // Opaque, unlike [AstraColors.card]: this is what Material paints
      // dialogs and menus with, and a translucent one would show the sky
      // through an alert.
      surface: AstraColors.canvasRaised,
      onSurface: AstraColors.text,
      outline: AstraColors.line,
      // Brightened for a dark ground. The old #B3261E is a red for white
      // backgrounds and reads as brown against the sky.
      error: Color(0xFFFF8A80),
    ),
    textTheme: GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AstraColors.text, displayColor: AstraColors.text),
    dividerColor: AstraColors.line,
    splashColor: AstraColors.accent.withValues(alpha: 0.07),
    highlightColor: AstraColors.accent.withValues(alpha: 0.04),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AstraColors.canvasRaised,
      contentTextStyle: AstraTextStyles.body.copyWith(
        color: AstraColors.text,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      ),
    ),
  );
}
