import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The wordmark, used as a lightweight screen header.
///
/// Set in the headline serif at its natural case. It used to be tracked-out
/// small caps, which is how you set a *label*; a product's name is set like a
/// name.
class Wordmark extends StatelessWidget {
  const Wordmark(this.text, {super.key, this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Text(text, textAlign: align, style: AstraTextStyles.wordmark),
  );
}

/// The standard surface: a bordered, rounded panel.
class AstraCard extends StatelessWidget {
  const AstraCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.raised = false,
    this.borderColor,
    this.dashed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Raised cards carry a subtle gradient — reserved for the one thing on a
  /// screen that should be tapped first.
  final bool raised;
  final Color? borderColor;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    // White paper on a coloured wash. Borders are opt-in now rather than
    // default: on a gradient, an outlined box reads as a hole cut in the
    // background, while a shadow reads as something resting on it.
    final decoration = BoxDecoration(
      color: raised ? AstraColors.cardRaised : AstraColors.card,
      border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
      borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      boxShadow: raised ? AstraColors.liftedShadow : AstraColors.softShadow,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}

/// Primary action. Aubergine, pill-shaped, one per screen.
class AstraButton extends StatelessWidget {
  const AstraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AstraColors.accentGradient,
                borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
                boxShadow: enabled ? AstraColors.liftedShadow : null,
              ),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AstraColors.onAccent,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            const SizedBox(width: 2),
                            Icon(icon, size: 18, color: AstraColors.onAccent),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              color: AstraColors.onAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — the visible way out of any screen that asks for money.
class AstraGhostButton extends StatelessWidget {
  const AstraGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
          boxShadow: AstraColors.softShadow,
        ),
        child: Text(
          label,
          style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ),
  );
}

/// A selectable pill. Used for intentions, filters and inline badges.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AstraColors.accent;

    // Unselected chips are white paper, not outlines. On the wash a row of
    // outlined pills disappears; a row of little white tablets does not, and
    // selection then only has to change one thing — the fill — rather than
    // inventing contrast the resting state never had.
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color : AstraColors.card,
        borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
        boxShadow: AstraColors.softShadow,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: selected ? AstraColors.onAccent : AstraColors.text,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
        child: pill,
      ),
    );
  }
}

/// Thin progress rail, used for onboarding steps and the monthly practice meter.
class AstraProgressBar extends StatelessWidget {
  const AstraProgressBar({super.key, required this.value, this.height = 4});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      backgroundColor: AstraColors.line,
      valueColor: const AlwaysStoppedAnimation(AstraColors.accent),
    ),
  );
}

/// Circular glyph badge — the recurring marker for a story or an action.
class GlyphDot extends StatelessWidget {
  const GlyphDot({
    super.key,
    required this.glyph,
    this.size = 38,
    this.color = AstraColors.accent,
    this.background,
  });

  final String glyph;
  final double size;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background ?? AstraColors.card,
      shape: BoxShape.circle,
      boxShadow: AstraColors.softShadow,
    ),
    child: Text(
      glyph,
      style: TextStyle(color: color, fontSize: size * 0.42),
    ),
  );
}

/// Shown when a list has nothing in it yet — states what to do, not just that
/// the list is empty.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.glyph,
    required this.title,
    required this.body,
    this.action,
  });

  final String glyph;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphDot(glyph: glyph, size: 56),
          const SizedBox(height: AstraSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AstraTextStyles.display(20),
          ),
          const SizedBox(height: AstraSpacing.sm),
          Text(body, textAlign: TextAlign.center, style: AstraTextStyles.bodyDim),
          if (action != null) ...[
            const SizedBox(height: AstraSpacing.xl),
            action!,
          ],
        ],
      ),
    ),
  );
}
