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
      border: Border.all(
        color: borderColor ?? const Color(0x33FFFFFF),
        width: borderColor == null ? 1 : 2,
      ),
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

/// Primary action. Hot pink, pill-shaped, one per screen.
///
/// The darker underside is a hard shadow, not a blur: it is what makes the
/// button read as a thing with thickness that can be pressed, and it sinks by
/// the same distance while a finger is on it.
class AstraButton extends StatefulWidget {
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
  State<AstraButton> createState() => _AstraButtonState();
}

class _AstraButtonState extends State<AstraButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    const edge = 5.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: EdgeInsets.only(top: _down ? edge : 0, bottom: _down ? 0 : edge),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AstraColors.cta,
              borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
              boxShadow: [
                if (!_down)
                  const BoxShadow(
                    color: AstraColors.ctaEdge,
                    offset: Offset(0, edge),
                  ),
              ],
            ),
            child: widget.busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: AstraColors.onCta,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        const SizedBox(width: 2),
                        Icon(widget.icon, size: 20, color: AstraColors.onCta),
                        const SizedBox(width: 8),
                      ],
                      // Shrinks rather than overflows.
                      //
                      // The label is not a fixed string: the paywall's reads
                      // "Start Mayow Plus — ₹6,999 / year" in one currency and
                      // something longer in the next, and a Row of natural-width
                      // children on a 375pt phone ran 43 points off the right
                      // edge of the button. Scaled down rather than wrapped or
                      // ellipsised: the pill is a fixed height so a second line
                      // has nowhere to go, and a call to action that ends in
                      // "…" is a call to action nobody can read.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AstraColors.onCta,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
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
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
          border: Border.all(color: AstraColors.line, width: 1.5),
        ),
        child: Text(
          label,
          style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
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
        border: Border.all(
          color: selected ? color : AstraColors.line,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          color: selected ? AstraColors.onAccent : AstraColors.text,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
      valueColor: AlwaysStoppedAnimation(AstraColors.accent),
    ),
  );
}

/// Circular glyph badge — the recurring marker for a story or an action.
class GlyphDot extends StatelessWidget {
  const GlyphDot({
    super.key,
    required this.glyph,
    this.size = 38,
    this.color,
    this.background,
  });

  final String glyph;
  final double size;

  /// Null means the ink of whichever world is being rendered. It cannot be a
  /// default argument any more: the palette is a getter now, and a default has
  /// to be a compile-time constant.
  final Color? color;
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
      style: TextStyle(color: color ?? AstraColors.accent, fontSize: size * 0.42),
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
    this.mascot,
  });

  final String glyph;

  /// A mascot pose to show instead of the glyph disc, e.g. `mascot_sleep`.
  final String? mascot;
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
          if (mascot != null)
            AstraMascot(mascot!, size: 170)
          else
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

/// Asks before something is deleted for good. True only on an explicit yes.
///
/// Every colour is named explicitly rather than left to the ambient
/// [AlertDialog] defaults — those defaults are what made an earlier version
/// of this dialog unreadable, so nothing here is left for Material to guess.
Future<bool> confirmDelete(BuildContext context, String title) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // Opaque, unlike [AstraColors.card] — a translucent dialog over the
      // starfield background is what made this hard to read.
      backgroundColor: AstraColors.canvasRaised,
      title: Text(title, style: AstraTextStyles.display(20)),
      content: Text('This cannot be undone.', style: AstraTextStyles.bodyDim),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep',
            style: AstraTextStyles.small.copyWith(color: AstraColors.text),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Delete',
            style: AstraTextStyles.small.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// One of the app's glossy 3D icons (`assets/icons/<name>.png`).
///
/// Drawn from pictures rather than from the icon font, so they are full
/// colour and cannot be tinted: a state that used to be "grey versus gold" is
/// now "faded versus full", which is what [opacity] is for. Decorative —
/// excluded from the accessibility tree, since every place that uses one
/// already has a tooltip or a label next to it.
class AstraIcon extends StatelessWidget {
  const AstraIcon(this.name, {super.key, this.size = 24, this.opacity = 1});

  /// The file name without folder or extension, e.g. `ui_play`.
  final String name;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/$name.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
    opacity: AlwaysStoppedAnimation(opacity),
  );
}

/// The streak flame: Google's animated fire emoji (Noto Emoji, CC BY 4.0).
///
/// Loops on its own, so it is drawn still where motion is switched off and
/// wherever a screen shows many of them at once (the calendar), where a grid
/// of moving flames would be noise.
class AnimatedFire extends StatelessWidget {
  const AnimatedFire({super.key, this.size = 64, this.still = false});

  final double size;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Image.asset(
      still || reduce
          ? 'assets/animated/fire_still.png'
          : 'assets/animated/fire.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// Mayow, the moon cat — the app's mascot (`assets/mascot/<name>.png`).
///
/// Floats up and down a few pixels on a slow loop, which is enough to make
/// the screen feel inhabited without being a distraction. Pass [still] where
/// motion would fight something else on screen. The pictures are in
/// `design/mascot/` at full size if a larger one is ever needed.
class AstraMascot extends StatefulWidget {
  const AstraMascot(this.name, {super.key, this.size = 160, this.still = false});

  /// Which pose: `mascot_wave`, `mascot_cheer`, `mascot_sleep`,
  /// `mascot_listen`, `mascot_think` or `mascot_gift`.
  final String name;
  final double size;
  final bool still;

  @override
  State<AstraMascot> createState() => _AstraMascotState();
}

class _AstraMascotState extends State<AstraMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didUpdateWidget(AstraMascot old) {
    super.didUpdateWidget(old);
    if (old.still != widget.still) didChangeDependencies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still when asked to be, and still for anyone who has turned animations
    // off in their phone's settings — a bobbing picture is exactly the kind of
    // motion that setting exists to remove.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.still || reduce) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -6 * Curves.easeInOut.transform(_controller.value)),
      child: child,
    ),
    child: Image.asset(
      'assets/mascot/${widget.name}.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
