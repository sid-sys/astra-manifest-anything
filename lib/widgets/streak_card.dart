import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

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
  });

  /// Consecutive days ending today.
  final int streak;

  /// Monday to Sunday, true where something was made.
  final List<bool> week;

  final String name;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    // Monday is 1, so today's index is weekday - 1.
    final todayIndex = DateTime.now().weekday - 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                color: AstraColors.gold.withValues(alpha: 0.10),
                border: Border.all(
                  color: AstraColors.gold.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 42,
                color: AstraColors.gold,
              ),
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
                    // Only a day that has actually passed can be a miss.
                    missed: !week[i] && i < todayIndex,
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
        AstraColors.gold.withValues(alpha: 0.14),
        AstraColors.gold,
        Icons.local_fire_department_rounded,
        AstraColors.gold,
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
                color: isToday && !done ? AstraColors.gold : border,
                width: isToday ? 1.6 : 1,
              ),
            ),
            child: icon == null
                ? null
                : Icon(icon, size: 17, color: iconColor),
          ),
        ],
      ),
    );
  }
}
