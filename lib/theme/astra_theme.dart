import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Mayow palette: a violet sky with one loud button.
///
/// This replaces the near-black night-sky palette. That one was built for a
/// person lying in bed with the lights off, and it read as a settings screen
/// everywhere else — quiet to the point of being forgettable on a paywall or a
/// first launch. This one is bright, saturated and friendly, with one rule
/// that keeps it readable: **white text only ever sits on something dark
/// enough to carry it.**
///
/// That is why the cards are deep indigo glass rather than white paper. A white
/// card would want dark text, and half the app (every secondary line, every
/// translucent panel) is written for light text; dark glass over a violet
/// gradient keeps white type above 4.5:1 on every surface, which
/// `palette_test.dart` asserts rather than hopes.
///
/// Three colours do all the work:
///  - violet → indigo for the page,
///  - hot pink for the one thing to press ([cta]),
///  - warm yellow for everything that is selected, active or highlighted
///    ([accent]).
class AstraColors {
  const AstraColors._();

  /// The page where no gradient reaches — behind a transparent route, or for
  /// the frame before the background paints. Deep indigo, close to the bottom
  /// of the gradient so the seam never shows.
  static const canvas = Color(0xFF2E2092);

  /// Sheets, dialogs, the nav bar and the player bar. Opaque on purpose: a
  /// sheet that let the gradient through would put moving colour behind a
  /// paragraph somebody is trying to read.
  static const canvasRaised = Color(0xFF241A78);

  /// The page gradient, top to bottom. The top is the darkest orchid that
  /// still looks pink: any lighter and secondary text on the bare background
  /// falls under 4.5:1.
  static const auraTop = Color(0xFF9438BE);
  static const auraMid = Color(0xFF6C3FD6);
  static const auraBottom = Color(0xFF3B2AAE);

  /// Cards are deep indigo glass over the gradient — darker than the page, so
  /// light text on them is always safe, and translucent so the colour still
  /// shows through at the edges.
  static const card = Color(0x59150C5C);
  static const cardRaised = Color(0x73150C5C);

  /// A pale rule at low opacity: an edge catching light, not a drawn border.
  static const line = Color(0x59FFFFFF);

  /// Pure white. On violet there is no glare problem to design around.
  static const text = Color(0xFFFFFFFF);

  /// Secondary type — a white with a trace of lavender, picked against the
  /// bare gradient (the hardest surface), not against a card.
  static const dim = Color(0xFFF1E8FF);

  /// The highlight: selected chips, the active nav item, slider tracks, links,
  /// eyebrows. Warm yellow, because it is the one hue that does not exist in
  /// the page gradient, so a selected thing is never confusable with the
  /// background.
  static const accent = Color(0xFFFFD84D);
  static const accentDeep = Color(0xFFFFC21F);

  /// What sits on a yellow fill — deep indigo, not black.
  static const onAccent = Color(0xFF24135F);

  /// A tint for selected rows and quiet fills.
  static const accentWash = Color(0x33FFD84D);

  /// The primary call to action. One per screen, always this colour, always
  /// white-labelled. [ctaEdge] is the darker underside that makes it read as a
  /// physical button rather than a flat pill.
  static const cta = Color(0xFFF0457F);
  static const ctaEdge = Color(0xFFB82F62);
  static const onCta = Color(0xFFFFFFFF);

  /// Kept because widgets reference them.
  static const violet = Color(0xFFB9A5FF);
  static const good = Color(0xFF7BE0A8);

  /// Confetti and decoration — never text.
  static const mint = Color(0xFF7BE0A8);
  static const sky = Color(0xFF7FD1FF);
  static const blush = Color(0xFFFFA6C9);

  /// Used wherever a button, ring or thumb wants a fill. A gradient only to
  /// stay API-compatible with callers written for the monochrome version.
  static const accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cta, cta],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF14084A).withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: const Color(0xFF14084A).withValues(alpha: 0.38),
      blurRadius: 24,
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

  /// Rounder than before: soft, toy-like corners are most of what makes the
  /// new look read as friendly. Everything round, nothing sharp.
  static const cardRadius = 28.0;
  static const pillRadius = 999.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: 20);
}

class AstraTextStyles {
  const AstraTextStyles._();

  /// One rounded, heavy family for everything. The old serif/sans pairing was
  /// quiet and literary; this is chunky and warm, and the weight does what the
  /// italic emphasis used to.
  static TextStyle display(double size, {Color? color}) => GoogleFonts.nunito(
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 1.12,
    letterSpacing: -0.5,
    color: color ?? AstraColors.text,
  );

  static TextStyle displayItalic(double size, {Color? color}) =>
      display(size, color: color ?? AstraColors.accent)
          .copyWith(fontStyle: FontStyle.italic);

  /// The app's name, set heavy.
  static TextStyle get wordmark => GoogleFonts.nunito(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: AstraColors.text,
  );

  static TextStyle get eyebrow => GoogleFonts.nunito(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.4,
    color: AstraColors.accent,
  );

  static TextStyle get body => GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.42,
    color: AstraColors.text,
  );

  static TextStyle get bodyDim => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.48,
    color: AstraColors.dim,
  );

  static TextStyle get small => GoogleFonts.nunito(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AstraColors.dim,
  );

  static TextStyle get label => GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AstraColors.text,
  );

  static TextStyle get price => GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: AstraColors.text,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get quote => GoogleFonts.nunito(
    fontSize: 18,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AstraColors.text,
  );
}

ThemeData buildAstraTheme() {
  // Dark base, even though the page is bright violet. Material picks its own
  // defaults for anything the app does not name — dialogs, menus, text
  // selection handles — and a dark base hands back light-on-dark there, which
  // is what every surface in this app is written for.
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AstraColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: AstraColors.accent,
      onPrimary: AstraColors.onAccent,
      secondary: AstraColors.cta,
      onSecondary: AstraColors.onCta,
      // Opaque, unlike [AstraColors.card]: this is what Material paints
      // dialogs and menus with.
      surface: AstraColors.canvasRaised,
      onSurface: AstraColors.text,
      outline: AstraColors.line,
      error: Color(0xFFFF9AA2),
    ),
    textTheme: GoogleFonts.nunitoTextTheme(
      base.textTheme,
    ).apply(bodyColor: AstraColors.text, displayColor: AstraColors.text),
    dividerColor: AstraColors.line,
    splashColor: AstraColors.accent.withValues(alpha: 0.12),
    highlightColor: AstraColors.accent.withValues(alpha: 0.06),
    // Every dialog, everywhere, opaque and legible without each call site
    // having to remember to say so. Several of them used to ask for the
    // translucent card colour and came out as text floating over whatever was
    // behind the alert.
    dialogTheme: DialogThemeData(
      backgroundColor: AstraColors.canvasRaised,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AstraTextStyles.display(21),
      contentTextStyle: AstraTextStyles.bodyDim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AstraColors.canvasRaised,
      surfaceTintColor: Colors.transparent,
      textStyle: AstraTextStyles.label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AstraColors.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AstraColors.canvasRaised,
      surfaceTintColor: Colors.transparent,
    ),
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
