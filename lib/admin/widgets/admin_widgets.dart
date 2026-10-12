import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/astra_theme.dart';
import '../../widgets/astra_widgets.dart';
import '../admin_models.dart';

/// Soft tints for the dashboard cards. Washed over the app's violet, so they
/// read as pastel without leaving the app's own look.
class AdminTints {
  const AdminTints._();

  static const mint = Color(0xFF7BE0A8);
  static const pink = Color(0xFFFFA6C9);
  static const yellow = Color(0xFFFFD84D);
  static const sky = Color(0xFF7FD1FF);
  static const lilac = Color(0xFFC9B6FF);
  static const peach = Color(0xFFFFB38A);
}

/// Side padding for every admin screen.
const adminPadding = EdgeInsets.symmetric(horizontal: 16);

String money(double value) {
  final negative = value < 0;
  final text = NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(value.abs());
  return negative ? '-$text' : text;
}

String shortDate(DateTime time) => DateFormat('d MMM').format(time);

String timeOfDay(DateTime time) => DateFormat('h:mm a').format(time);

/// "just now", "3h ago", "5d ago".
String ago(DateTime time, [DateTime? now]) {
  final gap = (now ?? DateTime.now()).difference(time);
  if (gap.inMinutes < 2) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  if (gap.inDays < 30) return '${gap.inDays}d ago';
  return shortDate(time);
}

/// The back button, a title, and anything the screen wants on the right.
class AdminBar extends StatelessWidget {
  const AdminBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AstraColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AstraColors.line),
              ),
              child: const AstraIcon('ui_back', size: 26),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AstraTextStyles.display(22),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

/// A small round button for the bar (refresh).
class AdminIconButton extends StatelessWidget {
  const AdminIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AstraColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AstraColors.line),
        ),
        child: Icon(icon, size: 20, color: AstraColors.text),
      ),
    ),
  );
}

/// Marks the screen as running on made-up data.
class MockTag extends StatelessWidget {
  const MockTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AdminTints.yellow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AdminTints.yellow.withValues(alpha: 0.7)),
    ),
    child: Text(
      'MOCK DATA',
      style: AstraTextStyles.eyebrow.copyWith(color: AdminTints.yellow, fontSize: 11),
    ),
  );
}

/// A card tinted one pastel, used for everything on the dashboard.
class TintCard extends StatelessWidget {
  const TintCard({
    super.key,
    required this.tint,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Color tint;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint.withValues(alpha: 0.16), AstraColors.cardRaised),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tint.withValues(alpha: 0.45)),
        ),
        child: child,
      ),
    ),
  );
}

/// A number with a title, a sub-line and an emoji.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.value,
    required this.sub,
    required this.tint,
  });

  final String emoji;
  final String title;
  final String value;
  final String sub;
  final Color tint;

  @override
  Widget build(BuildContext context) => TintCard(
    tint: tint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two lines reserved for the title, so a long one never changes the
        // card's height.
        SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AstraTextStyles.label.copyWith(
                    color: tint,
                    height: 1.15,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(emoji, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AstraTextStyles.display(30)),
          ),
        ),
        const SizedBox(height: 4),
        // Three lines reserved for the sub-line, for the same reason.
        SizedBox(
          height: 52,
          child: Text(
            sub,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AstraTextStyles.small.copyWith(height: 1.25),
          ),
        ),
      ],
    ),
  );
}

/// Two cards to a row, whatever the screen width. Every [MetricCard] reserves
/// the same height for its title and its sub-line, so the cards in a row match
/// without measuring them against each other.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 12.0;
      final width = (box.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

/// The daily-active-users bars: fourteen days, today in yellow, the count above
/// each bar.
class DauChart extends StatelessWidget {
  const DauChart({super.key, required this.days});

  final List<({DateTime day, int count})> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(1, (m, d) => d.count > m ? d.count : m);
    const barArea = 110.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Scaled down rather than wrapped, so a big system font on a
                  // narrow phone shrinks the number instead of growing the bar
                  // area past its box.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${days[i].count}',
                      softWrap: false,
                      style: AstraTextStyles.small.copyWith(fontSize: 10, height: 1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: (barArea * days[i].count / peak).clamp(3, barArea),
                    decoration: BoxDecoration(
                      color: i == days.length - 1
                          ? AdminTints.yellow
                          : AdminTints.lilac.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('d').format(days[i].day),
                      softWrap: false,
                      style: AstraTextStyles.small.copyWith(
                        fontSize: 10,
                        height: 1,
                        color: i == days.length - 1 ? AdminTints.yellow : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One row of the funnel: label, count, share of those who joined, and a bar.
class FunnelRow extends StatelessWidget {
  const FunnelRow({
    super.key,
    required this.step,
    required this.joined,
    required this.tint,
  });

  final FunnelStep step;
  final int joined;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final share = joined == 0 ? 0.0 : step.count / joined;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AstraTextStyles.label,
                ),
              ),
              Text(
                '${step.count} · ${(share * 100).round()}%',
                style: AstraTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.white.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  widthFactor: share.clamp(0.0, 1.0),
                  child: Container(height: 10, color: tint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round badge with the person's initials.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.initials, this.size = 44});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AdminTints.lilac.withValues(alpha: 0.28),
      border: Border.all(color: AdminTints.lilac.withValues(alpha: 0.7)),
    ),
    child: Text(
      initials,
      style: AstraTextStyles.display(size * 0.38, color: AstraColors.text),
    ),
  );
}

/// "Monthly", "Yearly", "Lifetime", "Free" or "Ended", coloured.
class PlanPill extends StatelessWidget {
  const PlanPill({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch (user.plan) {
      AdminPlan.monthly => ('Monthly', AdminTints.mint),
      AdminPlan.yearly => ('Yearly', AdminTints.sky),
      AdminPlan.lifetime => ('Lifetime', AdminTints.yellow),
      AdminPlan.none when user.churned => ('Ended', AdminTints.peach),
      AdminPlan.none => ('Free', AdminTints.lilac),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.7)),
      ),
      child: Text(label, style: AstraTextStyles.label.copyWith(color: tint, fontSize: 12)),
    );
  }
}

/// A section title.
class AdminHeading extends StatelessWidget {
  const AdminHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AstraTextStyles.display(19))),
        ?trailing,
      ],
    ),
  );
}
