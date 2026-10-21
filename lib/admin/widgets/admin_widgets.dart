import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/astra_theme.dart';
import '../../widgets/astra_widgets.dart';
import '../admin_config.dart';
import '../admin_models.dart';

/// Side padding for every admin screen.
const adminPadding = EdgeInsets.symmetric(horizontal: 16);

String money(double value) {
  final text = NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(value.abs());
  return value < 0 ? '-$text' : text;
}

String shortDate(DateTime time) => DateFormat('d MMM').format(time.toLocal());

String timeOfDay(DateTime time) => DateFormat('h:mm a').format(time.toLocal());

/// "Tue 14 Oct", for list titles. [day] is a UTC calendar day.
String dayTitle(DateTime day) => DateFormat('EEE d MMM').format(day);

/// "just now", "3h ago", "5d ago".
String ago(DateTime time, [DateTime? now]) {
  final gap = (now ?? DateTime.now()).difference(time);
  if (gap.inMinutes < 2) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  if (gap.inDays < 30) return '${gap.inDays}d ago';
  return shortDate(time);
}

/// The back button, the small logo, a title, and anything on the right.
class AdminBar extends StatelessWidget {
  const AdminBar({super.key, required this.title, this.actions = const [], this.logo = false});

  final String title;
  final List<Widget> actions;
  final bool logo;

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
                color: AdminColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.cardEdge),
              ),
              child: const AstraIcon('ui_back', size: 26),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (logo) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/brand/splash_icon.png', width: 30, height: 30),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AstraTextStyles.display(21),
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
          color: AdminColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AdminColors.cardEdge),
        ),
        child: const Icon(Icons.refresh_rounded, size: 20, color: AdminColors.text),
      ),
    ),
  );
}

/// The panel's card: a shade off the background, with a hairline edge.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.cardEdge),
        ),
        child: child,
      ),
    ),
  );
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

/// A number with a title and a sub-line. Tapping opens the people behind it.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.value,
    required this.sub,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String value;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AdminCard(
    onTap: onTap,
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
                    color: AdminColors.link,
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

/// Two cards to a row, whatever the screen width.
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

/// A filter chip in the primary colour when chosen.
class AdminChip extends StatelessWidget {
  const AdminChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AdminColors.primary : AdminColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AdminColors.primary : AdminColors.cardEdge,
          ),
        ),
        child: Text(
          label,
          style: AstraTextStyles.label.copyWith(color: AdminColors.text),
        ),
      ),
    ),
  );
}

/// A two-option switch for the top of a card.
class AdminToggle extends StatelessWidget {
  const AdminToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              label: options[i],
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selected ? AdminColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      options[i],
                      style: AstraTextStyles.label.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// One row of the funnel: label, count, share of the top, and a bar.
class FunnelRow extends StatelessWidget {
  const FunnelRow({
    super.key,
    required this.step,
    required this.top,
    this.stopsHere = false,
  });

  final FunnelStep step;
  final int top;

  /// The biggest drop in the funnel: where most people stop.
  final bool stopsHere;

  @override
  Widget build(BuildContext context) {
    final share = top == 0 ? 0.0 : step.count / top;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AstraTextStyles.label,
                ),
              ),
              const SizedBox(width: 8),
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
                  child: Container(
                    height: 10,
                    color: stopsHere ? AdminColors.highlight : AdminColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (stopsHere)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Most people stop after this step',
                style: AstraTextStyles.small.copyWith(color: AdminColors.highlight),
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
      color: AdminColors.primary.withValues(alpha: 0.3),
      border: Border.all(color: AdminColors.primary.withValues(alpha: 0.8)),
    ),
    child: Text(initials, style: AstraTextStyles.display(size * 0.38)),
  );
}

/// A small outlined label.
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.color = AdminColors.dim});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(text, style: AstraTextStyles.label.copyWith(color: color, fontSize: 12)),
  );
}

/// "Monthly", "Yearly", "Ended" or "Free", coloured.
class PlanPill extends StatelessWidget {
  const PlanPill({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (user.plan) {
      AdminPlan.monthly => ('Monthly', AdminColors.good),
      AdminPlan.yearly => ('Yearly', const Color(0xFF7FD1FF)),
      AdminPlan.none when user.churned => ('Ended', const Color(0xFFFFB38A)),
      AdminPlan.none => ('Free', AdminColors.dim),
    };
    return TagPill(label, color: color);
  }
}

/// A person in a list: real name, real email, plan, joined, last seen, tags.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.entry, required this.onTap, this.reason});

  final PersonEntry entry;
  final VoidCallback onTap;

  /// Set on the "hidden accounts" list: why they are left out.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final user = entry.user;
    final now = DateTime.now();
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminAvatar(initials: user.initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
                ),
                if (user.displayName != user.email)
                  Text(
                    user.email.isEmpty ? 'No email' : user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AstraTextStyles.small,
                  ),
                Text(
                  entry.time != null
                      ? '${entry.note ?? ''}${entry.note == null ? '' : ' · '}'
                            '${shortDate(entry.time!)}, ${timeOfDay(entry.time!)}'
                      : 'Joined ${shortDate(user.joinedAt)} · Seen ${ago(user.lastSeen, now)}',
                  maxLines: 2,
                  style: AstraTextStyles.small,
                ),
                if (reason != null || user.isGuest || user.testPurchase) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (reason != null)
                        TagPill('Hidden: $reason', color: AdminColors.highlight),
                      if (user.isGuest) const TagPill('Guest'),
                      if (user.testPurchase)
                        const TagPill('Test purchase', color: AdminColors.highlight),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PlanPill(user: user),
        ],
      ),
    );
  }
}

/// What a list says when nobody is on it.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(text, textAlign: TextAlign.center, style: AstraTextStyles.bodyDim),
    ),
  );
}
