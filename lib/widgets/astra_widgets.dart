import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The wordmark, used as a lightweight screen header.
class Wordmark extends StatelessWidget {
  const Wordmark(this.text, {super.key, this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Text(
      text.toUpperCase(),
      textAlign: align,
      style: AstraTextStyles.wordmark,
    ),
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
    final decoration = BoxDecoration(
      color: raised ? null : AstraColors.card,
      gradient: raised
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AstraColors.cardRaised, AstraColors.card],
            )
          : null,
      border: Border.all(color: borderColor ?? AstraColors.line),
      borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
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

/// Primary action. Gold, pill-shaped, one per screen.
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
                gradient: AstraColors.goldGradient,
                borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
              ),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF14101F),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: const Color(0xFF14101F)),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF14101F),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
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
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AstraColors.line),
          borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
        ),
        child: Text(label, style: AstraTextStyles.bodyDim),
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
    final color = accent ?? AstraColors.gold;

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.09) : Colors.transparent,
        border: Border.all(color: selected ? color : AstraColors.line),
        borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: selected ? color : AstraColors.dim,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
      valueColor: const AlwaysStoppedAnimation(AstraColors.gold),
    ),
  );
}

/// Circular glyph badge — the recurring marker for a story or an action.
class GlyphDot extends StatelessWidget {
  const GlyphDot({
    super.key,
    required this.glyph,
    this.size = 38,
    this.color = AstraColors.gold,
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
      color: background ?? AstraColors.cardRaised,
      shape: BoxShape.circle,
      border: Border.all(color: AstraColors.line),
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
