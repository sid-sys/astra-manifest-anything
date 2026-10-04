import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import 'astra_widgets.dart';

/// The streak, as a thing worth looking at rather than a number in a corner.
///
/// A streak only motivates if it is visible enough to feel like something you
/// would be sorry to break, and legible enough to see where the gap is. The
/// week strip does the second job: it shows which day was missed rather than
/// only that the count reset.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.week,
    required this.name,
    required this.since,
  });

  /// Consecutive days ending today.
  final int streak;

  /// Monday to Sunday, true where something was made.
  final List<bool> week;

  final String name;

  /// When the user joined. Days before this are drawn blank rather than
  /// missed — someone who installed on Saturday did not fail Monday through
  /// Friday, and greeting them with five crosses is both wrong and bleak.
  final DateTime since;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    // Monday is 1, so today's index is weekday - 1.
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: todayIndex));
    final joined = DateTime(since.year, since.month, since.day);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AstraColors.cardRaised, AstraColors.card],
        ),
        border: Border.all(color: AstraColors.line),
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AstraColors.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: AstraColors.accent.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: const AstraIcon('ui_flame', size: 64),
            ),
            const SizedBox(height: AstraSpacing.md),
            Text(
              '$streak',
              style: AstraTextStyles.display(38),
            ),
            Text(
              'day streak',
              style: AstraTextStyles.label.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              streak == 0
                  ? 'Write one story and it starts today, $name.'
                  : 'Keep it going, $name.',
              textAlign: TextAlign.center,
              style: AstraTextStyles.small,
            ),
            const SizedBox(height: AstraSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayDot(
                    label: _labels[i],
                    done: week[i],
                    // A miss needs a day that has passed *and* that the user
                    // was around for.
                    missed: !week[i] &&
                        i < todayIndex &&
                        !monday.add(Duration(days: i)).isBefore(joined),
                    isToday: i == todayIndex,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.done,
    required this.missed,
    required this.isToday,
  });

  final String label;
  final bool done;
  final bool missed;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final (background, border, icon, iconColor) = switch ((done, missed)) {
      (true, _) => (
        AstraColors.accent.withValues(alpha: 0.14),
        AstraColors.accent,
        null,
        AstraColors.accent,
      ),
      (false, true) => (
        Colors.transparent,
        AstraColors.line,
        Icons.close_rounded,
        AstraColors.dim,
      ),
      _ => (Colors.transparent, AstraColors.line, null, AstraColors.dim),
    };

    return Semantics(
      label: '$label: ${done ? 'done' : (missed ? 'missed' : 'not yet')}',
      child: Column(
        children: [
          Text(
            label,
            style: AstraTextStyles.small.copyWith(
              fontSize: 11,
              color: isToday ? AstraColors.text : AstraColors.dim,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: Border.all(
                color: isToday && !done ? AstraColors.accent : border,
                width: isToday ? 1.6 : 1,
              ),
            ),
            child: done
                ? const AstraIcon('ui_flame', size: 24)
                : (icon == null ? null : Icon(icon, size: 17, color: iconColor)),
          ),
        ],
      ),
    );
  }
}
