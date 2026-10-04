import 'package:flutter/material.dart';

import '../models/story_preferences.dart';
import '../theme/astra_theme.dart';
import 'astra_widgets.dart';

/// The switch that decides whether Mayow writes from what it knows about you.
///
/// One switch, not a row of chips. The chips put every answer on the front page,
/// which made the commonest action — type something, press the button — look
/// like a form with a set of decisions attached. The choice people actually
/// make is binary: use what Mayow knows about me, or use only what I just
/// typed. Which answers, for the minority who care, is one tap further in.
///
/// Shared between Home and the affirmations tab because it is the same decision
/// in both places, and two arrangements of one decision are two things to learn.
class PersonaliseToggle extends StatelessWidget {
  const PersonaliseToggle({
    super.key,
    required this.on,
    required this.busy,
    required this.inUse,
    required this.total,
    required this.onChanged,
    required this.onChoose,
  });

  final bool on;
  final bool busy;

  /// Answers in use and answers available, both counting the name.
  final int inUse;
  final int total;

  final ValueChanged<bool> onChanged;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use my answers', style: AstraTextStyles.label),
                const SizedBox(height: 2),
                Text(
                  on
                      ? '$inUse of $total in use · tap to choose'
                      : 'Written only from what you type',
                  style: AstraTextStyles.small,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: AstraColors.onAccent,
            activeTrackColor: AstraColors.accent,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
      if (on) ...[
        const SizedBox(height: AstraSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : onChoose,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Choose which answers',
              style: AstraTextStyles.small.copyWith(
                color: AstraColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Opens the sheet that picks between the onboarding answers.
///
/// Mutates [chosen] in place and returns when the sheet closes; the caller
/// rebuilds. A callback per change would fire on every tap inside the sheet,
/// which is noise — the decision is made when it is dismissed.
Future<void> showAnswerSheet(
  BuildContext context, {
  required String name,
  required List<ManifestFactor> available,
  required Set<String> chosen,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AstraColors.canvasRaised,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheetContext) => StatefulBuilder(
    builder: (sheetContext, setSheetState) => SafeArea(
      child: Padding(
        padding: AstraSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AstraSpacing.lg),
            Text('WRITE IT FROM', style: AstraTextStyles.eyebrow),
            const SizedBox(height: AstraSpacing.xs),
            Text(
              'Your answers, as Mayow will use them.',
              style: AstraTextStyles.bodyDim,
            ),
            const SizedBox(height: AstraSpacing.lg),

            // Always on, and deliberately not a switch. Everything Mayow writes
            // says the name out loud; there is no version of this that works
            // without one.
            AnswerRow(
              label: 'Your name',
              value: name,
              on: true,
              onChanged: null,
            ),
            for (final factor in available)
              AnswerRow(
                label: factor.label,
                value: factor.value,
                on: chosen.contains(factor.key),
                onChanged: (on) => setSheetState(() {
                  on ? chosen.add(factor.key) : chosen.remove(factor.key);
                }),
              ),

            const SizedBox(height: AstraSpacing.lg),
            AstraButton(
              label: 'Save',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: AstraSpacing.lg),
          ],
        ),
      ),
    ),
  ),
);

/// One answer in the sheet: what it is, what it says, and whether it is used.
class AnswerRow extends StatelessWidget {
  const AnswerRow({
    super.key,
    required this.label,
    required this.value,
    required this.on,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool on;

  /// Null for the name, which cannot be turned off.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AstraTextStyles.label),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: AstraTextStyles.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Switch(
          value: on,
          activeThumbColor: AstraColors.onAccent,
          activeTrackColor: AstraColors.accent,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
